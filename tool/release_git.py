#!/usr/bin/env python3
"""Git and GitHub-release steps of the release workflow, as testable code.

Everything that changes durable release state (the release commit, the tag, the
`master` and `develop` pushes, the GitHub Release) lives here instead of inline
shell, because each has a rule that must hold and be tested:

* `finalize`      ONE atomic push of `master` + release commit + tag. Resumable:
                  an existing tag is accepted only if its commit's parent is the
                  dispatched source SHA, its pubspec version is `new_version`
                  and `master` contains it (`resume_decision`).
* `sync-develop`  no-op if `develop` has the tag; fast-forward with a lease only
                  if `develop` still equals the source SHA; otherwise fail with
                  merge instructions. Never overwrites (`sync_decision`).
* `github-release` create-or-edit the release for the validated tag, assets with
                  `--clobber`; the notes never say verification happened unless
                  it did.
* `stamp` / `assert-version` / `assert-build`  apply and re-check the EXACT
                  `new_version` computed once by `prepare`; nothing here ever
                  recomputes a version from `--bump`.

The pure decisions are separate from the git plumbing so they can be unit
tested; the plumbing is tested against real git in test/tool/test_release_git.py.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Callable, NamedTuple

sys.path.insert(0, str(Path(__file__).resolve().parent))
import compute_release_version as crv  # noqa: E402  (single source of the version format)

FULL_VERSION = re.compile(r"^\d+\.\d+\.\d+\+\d+$")


class ReleaseAbort(RuntimeError):
    """A rule was violated; stop before (or without) changing anything further."""


class Decision(NamedTuple):
    action: str
    reason: str


class FinalizeResult(NamedTuple):
    release_sha: str
    resumed: bool


# --------------------------------------------------------------------------- #
# Pure decisions
# --------------------------------------------------------------------------- #
def resume_decision(
    *,
    tag_commit: str | None,
    tag_parent: str | None,
    tag_version: str | None,
    master_contains_tag: bool | None,
    source_sha: str,
    new_version: str,
) -> Decision:
    """create | resume | abort for the release tag.

    A tag we did not make for THIS source commit and THIS version must never be
    adopted: resuming onto it would publish the wrong code under the right name.
    """
    if tag_commit is None:
        return Decision("create", "tag does not exist yet; creating the release commit and tag.")
    problems = []
    if tag_parent != source_sha:
        problems.append(
            f"its commit's parent is {tag_parent}, not the dispatched source SHA {source_sha}"
        )
    if tag_version != new_version:
        problems.append(f"its pubspec version is {tag_version}, not {new_version}")
    if not master_contains_tag:
        problems.append("master does not contain it")
    if problems:
        return Decision(
            "abort",
            f"The tag already exists (commit {tag_commit}) but " + "; ".join(problems) + ". "
            "It was not created by this release. Do not re-run: inspect the tag, and delete it "
            "only if it is a mistake, or dispatch a new release.",
        )
    return Decision("resume", f"tag exists at {tag_commit} and matches this release; resuming.")


def sync_decision(
    *, develop_sha: str | None, source_sha: str, develop_contains_tag: bool
) -> Decision:
    """noop | fast-forward | fail for syncing `develop` after a release."""
    if develop_contains_tag:
        return Decision("noop", "develop already contains the release tag; nothing to do.")
    if develop_sha is None:
        return Decision("fail", "develop does not exist on the remote; create it from master by hand.")
    if develop_sha == source_sha:
        return Decision("fast-forward", "develop still equals the release source; fast-forwarding it.")
    return Decision(
        "fail",
        f"develop has moved since this release was cut (it is at {develop_sha}, the release was "
        f"built from {source_sha}). The release HAS shipped: do not re-run it. Merge by hand, "
        "keeping the HIGHER pubspec.yaml version: git fetch origin && git checkout develop && "
        "git merge origin/master && git push origin develop",
    )


# --------------------------------------------------------------------------- #
# git plumbing
# --------------------------------------------------------------------------- #
def git(repo: Path, *args: str) -> str:
    """Run git; raise ReleaseAbort on failure. Every push goes through here."""
    proc = subprocess.run(["git", *args], cwd=repo, capture_output=True, text=True, check=False)
    if proc.returncode != 0:
        raise ReleaseAbort(f"git {' '.join(args)} failed: {proc.stderr.strip() or proc.stdout.strip()}")
    return proc.stdout.strip()


def git_ok(repo: Path, *args: str) -> bool:
    proc = subprocess.run(["git", *args], cwd=repo, capture_output=True, text=True, check=False)
    return proc.returncode == 0


def _format_version(parts: tuple[int, int, int, int]) -> str:
    return f"{parts[0]}.{parts[1]}.{parts[2]}+{parts[3]}"


def _require_full_version(version: str) -> None:
    if not FULL_VERSION.match(version or ""):
        raise ReleaseAbort(f"{version!r} is not a full X.Y.Z+BUILD version.")


def stamp_version(pubspec: Path, new_version: str) -> None:
    """Write exactly `new_version` into pubspec.yaml and prove it took."""
    _require_full_version(new_version)
    text = pubspec.read_text(encoding="utf-8")
    try:
        crv.parse_version(text)
    except crv.ReleaseVersionError as error:
        raise ReleaseAbort(str(error)) from error
    pubspec.write_text(crv.apply_version(text, new_version), encoding="utf-8")
    assert_version(pubspec, new_version)


def assert_version(pubspec: Path, expected: str) -> None:
    try:
        actual = _format_version(crv.parse_version(pubspec.read_text(encoding="utf-8")))
    except crv.ReleaseVersionError as error:
        raise ReleaseAbort(str(error)) from error
    if actual != expected:
        raise ReleaseAbort(f"pubspec.yaml says version {actual}, but this release is {expected}.")


def assert_build_metadata(root: Path, new_version: str) -> int:
    """Check every Android `output-metadata.json` under `root` against new_version.

    Returns how many were checked (0 means the build left none to check).
    """
    _require_full_version(new_version)
    name, build = new_version.split("+")
    checked = 0
    for path in sorted(root.rglob("output-metadata.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        for element in data.get("elements", []):
            if str(element.get("versionCode")) != build or element.get("versionName") != name:
                raise ReleaseAbort(
                    f"{path} was built as {element.get('versionName')}+{element.get('versionCode')}, "
                    f"but this release is {new_version}."
                )
        checked += 1
    return checked


# --------------------------------------------------------------------------- #
# finalize-git
# --------------------------------------------------------------------------- #
def _tag_facts(repo: Path, tag: str, remote: str, branch: str) -> dict[str, object] | None:
    ref = f"refs/tags/{tag}"
    if not git_ok(repo, "rev-parse", "--verify", "-q", f"{ref}^{{commit}}"):
        return None
    commit = git(repo, "rev-parse", f"{ref}^{{commit}}")
    parents = git(repo, "rev-list", "--parents", "-n", "1", commit).split()[1:]
    try:
        version: str | None = _format_version(crv.parse_version(git(repo, "show", f"{commit}:pubspec.yaml")))
    except (ReleaseAbort, crv.ReleaseVersionError):
        version = None
    return {
        "tag_commit": commit,
        "tag_parent": parents[0] if len(parents) == 1 else None,
        "tag_version": version,
        "master_contains_tag": git_ok(
            repo, "merge-base", "--is-ancestor", commit, f"refs/remotes/{remote}/{branch}"
        ),
    }


def finalize(
    repo: Path,
    *,
    source_sha: str,
    tag: str,
    new_version: str,
    remote: str = "origin",
    branch: str = "master",
) -> FinalizeResult:
    """Create (or resume) the release commit + tag and push them atomically."""
    repo = Path(repo)
    _require_full_version(new_version)
    semver, build = new_version.split("+")
    if tag != semver:
        raise ReleaseAbort(f"tag {tag!r} does not match the release version {new_version}.")
    if git(repo, "rev-parse", "HEAD") != source_sha:
        raise ReleaseAbort(f"the checkout is not at the dispatched source SHA {source_sha}.")
    if git(repo, "status", "--porcelain"):
        raise ReleaseAbort("the working tree is not clean; refusing to build a release commit on it.")

    git(repo, "fetch", "--quiet", remote, f"+refs/heads/{branch}:refs/remotes/{remote}/{branch}")
    if git(repo, "ls-remote", "--tags", remote, f"refs/tags/{tag}"):
        git(repo, "fetch", "--quiet", remote, f"+refs/tags/{tag}:refs/tags/{tag}")
    elif git_ok(repo, "rev-parse", "--verify", "-q", f"refs/tags/{tag}"):
        git(repo, "tag", "-d", tag)  # a local-only tag is not a release

    facts = _tag_facts(repo, tag, remote, branch)
    decision = resume_decision(
        tag_commit=None if facts is None else facts["tag_commit"],  # type: ignore[arg-type]
        tag_parent=None if facts is None else facts["tag_parent"],  # type: ignore[arg-type]
        tag_version=None if facts is None else facts["tag_version"],  # type: ignore[arg-type]
        master_contains_tag=None if facts is None else facts["master_contains_tag"],  # type: ignore[arg-type]
        source_sha=source_sha,
        new_version=new_version,
    )
    print(f"finalize: {decision.action} - {decision.reason}")
    if decision.action == "abort":
        raise ReleaseAbort(decision.reason)
    if decision.action == "resume":
        return FinalizeResult(str(facts["tag_commit"]) if facts else "", True)

    # create: master may only move forward from where it is to the source SHA
    # (the one-click promote) and then onto the release commit.
    if not git_ok(repo, "merge-base", "--is-ancestor", f"refs/remotes/{remote}/{branch}", source_sha):
        raise ReleaseAbort(
            f"{branch} is not an ancestor of the source SHA {source_sha}: it moved or diverged since "
            "this release was dispatched. Nothing was pushed. Reconcile by hand "
            "(docs/release-runbook.md -> Troubleshooting) and dispatch again."
        )
    pubspec = repo / "pubspec.yaml"
    current_build = crv.parse_version(pubspec.read_text(encoding="utf-8"))[3]
    if int(build) <= current_build:
        raise ReleaseAbort(
            f"release build number {build} is not above the checkout's {current_build}; "
            "the version handed to finalize is stale."
        )

    stamp_version(pubspec, new_version)
    git(repo, "add", "pubspec.yaml")
    git(repo, "commit", "--quiet", "-m", f"chore: release {tag}")
    git(repo, "tag", "-a", tag, "-m", f"Release {tag}")
    release_sha = git(repo, "rev-parse", "HEAD")
    # ONE atomic push: either master moves AND the tag appears, or neither does.
    git(
        repo,
        "push",
        "--atomic",
        remote,
        f"{release_sha}:refs/heads/{branch}",
        f"refs/tags/{tag}:refs/tags/{tag}",
    )
    return FinalizeResult(release_sha, False)


# --------------------------------------------------------------------------- #
# sync-develop
# --------------------------------------------------------------------------- #
def push_develop(repo: Path, *, remote: str, branch: str, expected_sha: str, release_sha: str) -> None:
    """Fast-forward `branch` to the release commit, only if it is still `expected_sha`."""
    try:
        git(
            repo,
            "push",
            f"--force-with-lease=refs/heads/{branch}:{expected_sha}",
            remote,
            f"{release_sha}:refs/heads/{branch}",
        )
    except ReleaseAbort as error:
        raise ReleaseAbort(
            f"{branch} moved while syncing, so it was left untouched ({error}). The release HAS "
            "shipped: do not re-run it. Merge by hand: git fetch origin && git checkout develop && "
            "git merge origin/master && git push origin develop"
        ) from error


def sync_develop(
    repo: Path,
    *,
    source_sha: str,
    release_sha: str,
    tag: str,
    remote: str = "origin",
    branch: str = "develop",
) -> Decision:
    repo = Path(repo)
    tracking = f"refs/remotes/{remote}/{branch}"
    if git(repo, "ls-remote", "--heads", remote, f"refs/heads/{branch}"):
        git(repo, "fetch", "--quiet", remote, f"+refs/heads/{branch}:{tracking}")
        develop_sha: str | None = git(repo, "rev-parse", tracking)
    else:
        develop_sha = None
    contains = develop_sha is not None and git_ok(
        repo, "merge-base", "--is-ancestor", release_sha, tracking
    )
    decision = sync_decision(
        develop_sha=develop_sha, source_sha=source_sha, develop_contains_tag=contains
    )
    print(f"sync-develop ({tag}): {decision.action} - {decision.reason}")
    if decision.action == "fail":
        raise ReleaseAbort(decision.reason)
    if decision.action == "fast-forward":
        assert develop_sha is not None
        push_develop(repo, remote=remote, branch=branch, expected_sha=develop_sha, release_sha=release_sha)
    return decision


# --------------------------------------------------------------------------- #
# GitHub Release
# --------------------------------------------------------------------------- #
def build_release_notes(
    *, changelog: str, new_version: str, apk_name: str, aab_sha256: str, verified: bool
) -> str:
    """Release body. The device-verification line is computed, never assumed."""
    changelog = changelog.strip() or "- Maintenance release"
    if verified:
        verification = (
            "**Device verification: PASSED** - installed, launched, backgrounded and resumed "
            "on an API 34 emulator"
        )
    else:
        verification = (
            "**Device verification: SKIPPED** - the `skip_verify` override was used; this build "
            "was not installed or launched on a device by CI"
        )
    return (
        "## What's changed\n\n"
        f"{changelog}\n\n"
        "---\n"
        f"**Build:** `{new_version}`\n"
        f"**APK:** release build, signed with the production key - install via `adb install {apk_name}`\n"
        f"**AAB SHA-256:** `{aab_sha256}`\n"
        f"{verification}\n"
        "**Play Store notes:** download `play-store-notes.txt` above - copy/paste into "
        "Play Console -> What's new\n"
    )


def github_release(
    run: Callable[[list[str]], subprocess.CompletedProcess],
    *,
    tag: str,
    assets: list[str],
    notes_file: str,
    title: str,
) -> str:
    """Create-or-edit the release for `tag`; assets are uploaded with --clobber.

    `run` receives the arguments after `gh`. Idempotent: a re-run after a
    partial failure edits the existing release and replaces its assets.
    """
    view = run(["release", "view", tag])
    if view.returncode == 0:
        exists = True
    elif "not found" in (view.stderr or "").lower():
        exists = False
    else:
        raise ReleaseAbort(f"could not tell whether release {tag} exists: {(view.stderr or '').strip()}")

    if exists:
        steps = [
            ["release", "edit", tag, "--title", title, "--notes-file", notes_file],
            ["release", "upload", tag, *assets, "--clobber"],
        ]
    else:
        steps = [
            ["release", "create", tag, *assets, "--title", title, "--notes-file", notes_file, "--verify-tag"]
        ]
    for args in steps:
        result = run(args)
        if result.returncode != 0:
            raise ReleaseAbort(f"gh {' '.join(args[:2])} failed: {(result.stderr or '').strip()}")
    return "updated" if exists else "created"


def _gh(args: list[str]) -> subprocess.CompletedProcess:
    proc = subprocess.run(["gh", *args], capture_output=True, text=True, check=False)
    if proc.stdout:
        print(proc.stdout, end="")
    return proc


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
def _write_outputs(path: Path | None, **values: str) -> None:
    if path:
        with path.open("a", encoding="utf-8") as handle:
            for key, value in values.items():
                handle.write(f"{key}={value}\n")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    def version_args(p: argparse.ArgumentParser) -> None:
        p.add_argument("--new-version", required=True, help="X.Y.Z+BUILD, computed once by `prepare`")
        p.add_argument("--pubspec", type=Path, default=Path("pubspec.yaml"))

    version_args(sub.add_parser("stamp", help="write new_version into pubspec.yaml"))
    version_args(sub.add_parser("assert-version", help="fail unless pubspec.yaml is new_version"))
    p_build = sub.add_parser("assert-build", help="fail if a built output-metadata.json disagrees")
    p_build.add_argument("--new-version", required=True)
    p_build.add_argument("--root", type=Path, default=Path("build/app/outputs"))

    p_fin = sub.add_parser("finalize", help="atomic push of master + release commit + tag (resumable)")
    p_fin.add_argument("--source-sha", required=True)
    p_fin.add_argument("--tag", required=True)
    p_fin.add_argument("--new-version", required=True)
    p_fin.add_argument("--github-output", type=Path)

    p_sync = sub.add_parser("sync-develop", help="fast-forward develop to the release, safely")
    p_sync.add_argument("--source-sha", required=True)
    p_sync.add_argument("--release-sha", required=True)
    p_sync.add_argument("--tag", required=True)

    p_rel = sub.add_parser("github-release", help="create-or-edit the GitHub Release for the tag")
    p_rel.add_argument("--tag", required=True)
    p_rel.add_argument("--new-version", required=True)
    p_rel.add_argument("--apk-name", required=True)
    p_rel.add_argument("--aab-sha256", required=True)
    p_rel.add_argument("--verified", required=True, choices=("true", "false"))
    p_rel.add_argument("--changelog-file", type=Path, required=True)
    p_rel.add_argument("--notes-out", type=Path, default=Path("release-notes.md"))
    p_rel.add_argument("--title", required=True)
    p_rel.add_argument("--asset", action="append", default=[], required=True)

    args = parser.parse_args(argv)
    repo = Path.cwd()
    try:
        if args.command == "stamp":
            stamp_version(args.pubspec, args.new_version)
            print(f"pubspec.yaml stamped: {args.new_version}")
        elif args.command == "assert-version":
            assert_version(args.pubspec, args.new_version)
            print(f"pubspec.yaml is {args.new_version}")
        elif args.command == "assert-build":
            checked = assert_build_metadata(args.root, args.new_version)
            if checked == 0:
                print(f"::notice::no output-metadata.json under {args.root}; build version not cross-checked.")
            else:
                print(f"{checked} build metadata file(s) agree with {args.new_version}")
        elif args.command == "finalize":
            result = finalize(repo, source_sha=args.source_sha, tag=args.tag, new_version=args.new_version)
            print(f"release commit: {result.release_sha} (resumed={result.resumed})")
            _write_outputs(
                args.github_output,
                release_sha=result.release_sha,
                resumed=str(result.resumed).lower(),
            )
        elif args.command == "sync-develop":
            sync_develop(repo, source_sha=args.source_sha, release_sha=args.release_sha, tag=args.tag)
        elif args.command == "github-release":
            args.notes_out.write_text(
                build_release_notes(
                    changelog=args.changelog_file.read_text(encoding="utf-8"),
                    new_version=args.new_version,
                    apk_name=args.apk_name,
                    aab_sha256=args.aab_sha256,
                    verified=args.verified == "true",
                ),
                encoding="utf-8",
            )
            outcome = github_release(
                _gh, tag=args.tag, assets=args.asset, notes_file=str(args.notes_out), title=args.title
            )
            print(f"GitHub Release {args.tag}: {outcome}")
    except (ReleaseAbort, OSError) as error:
        print(f"::error::{error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
