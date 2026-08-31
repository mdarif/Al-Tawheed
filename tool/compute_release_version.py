#!/usr/bin/env python3
"""Derive the next release version, tag, and artifact names from pubspec.yaml.

This is the ONLY place a release version or tag is computed. The release
workflow's `prepare` job runs it before anything expensive happens, so a
duplicate tag or an unparseable pubspec fails in seconds rather than after a
twenty-minute Gradle build.

Tag format is bare `X.Y.Z` (no `v` prefix) — matching every tag this repo has
ever cut, and what cliff.toml's changelog ranges assume.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

# pubspec.yaml carries both halves of the Android version in one line:
#   version: X.Y.Z+BUILD   ->   versionName X.Y.Z, versionCode BUILD
# `[^\S\n]*` and not `\s*` for the trailing run: under re.MULTILINE, `\s`
# matches the newline itself, so the substitution would swallow it and
# silently delete a line from pubspec.yaml.
VERSION_RE = re.compile(
    r"^version:[^\S\n]*(\d+)\.(\d+)\.(\d+)\+(\d+)[^\S\n]*$", re.MULTILINE
)

APK_PREFIX = "al-tawheed-"


class ReleaseVersionError(RuntimeError):
    """A release version could not be computed — abort before building."""


def parse_version(pubspec_text: str) -> tuple[int, int, int, int]:
    match = VERSION_RE.search(pubspec_text)
    if not match:
        raise ReleaseVersionError(
            "pubspec.yaml has no parseable 'version: X.Y.Z+BUILD' line. "
            "The release pipeline derives the tag and the Play versionCode "
            "from it, so it must be exactly that shape."
        )
    return tuple(int(group) for group in match.groups())  # type: ignore[return-value]


def bump_version(
    major: int, minor: int, patch: int, build: int, bump: str
) -> tuple[str, int]:
    """Apply the semver bump. The build number ALWAYS increments.

    Play rejects an upload whose versionCode is not strictly greater than every
    code it already knows about, including ones only ever pushed to the
    internal track. Tying the increment to the bump type would let two
    same-semver builds collide.
    """
    if bump == "major":
        major, minor, patch = major + 1, 0, 0
    elif bump == "minor":
        minor, patch = minor + 1, 0
    elif bump == "patch":
        patch += 1
    else:
        raise ReleaseVersionError(f"Unknown bump type: {bump!r} (expected major/minor/patch)")
    return f"{major}.{minor}.{patch}", build + 1


def tag_exists(tag: str, repo: Path) -> bool:
    result = subprocess.run(
        ("git", "rev-parse", "--verify", f"refs/tags/{tag}"),
        cwd=repo,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return result.returncode == 0


def apply_version(pubspec_text: str, new_version: str) -> str:
    """Rewrite only the version line, leaving the rest of the file untouched."""
    return VERSION_RE.sub(f"version: {new_version}", pubspec_text, count=1)


def compute(
    *,
    pubspec: Path,
    bump: str,
    repo: Path,
    write: bool,
    check_tag: bool,
) -> dict[str, str]:
    text = pubspec.read_text(encoding="utf-8")
    major, minor, patch, build = parse_version(text)
    current = f"{major}.{minor}.{patch}+{build}"
    new_semver, new_build = bump_version(major, minor, patch, build, bump)
    new_version = f"{new_semver}+{new_build}"
    tag = new_semver

    if check_tag and tag_exists(tag, repo):
        raise ReleaseVersionError(
            f"Tag {tag} already exists. Is this version already released? "
            "Pick a different bump, or delete the tag if it was a mistake."
        )

    if write:
        pubspec.write_text(apply_version(text, new_version), encoding="utf-8")

    return {
        "current": current,
        "new_version": new_version,
        "new_semver": new_semver,
        "build_number": str(new_build),
        "tag": tag,
        "apk": f"{APK_PREFIX}{tag}.apk",
        "aab": f"{APK_PREFIX}{tag}.aab",
    }


def main(argv: list[str] | None = None) -> int:
    repo = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bump", required=True, choices=("major", "minor", "patch"))
    parser.add_argument("--pubspec", type=Path, default=repo / "pubspec.yaml")
    parser.add_argument(
        "--write",
        action="store_true",
        help="Rewrite the version line in pubspec.yaml (the build job does this).",
    )
    parser.add_argument(
        "--no-check-tag",
        action="store_true",
        help="Skip the duplicate-tag guard (only for a shallow checkout with no tags).",
    )
    parser.add_argument(
        "--github-output",
        type=Path,
        help="Append key=value lines here (pass $GITHUB_OUTPUT in CI).",
    )
    args = parser.parse_args(argv)

    try:
        outputs = compute(
            pubspec=args.pubspec,
            bump=args.bump,
            repo=repo,
            write=args.write,
            check_tag=not args.no_check_tag,
        )
    except (ReleaseVersionError, OSError) as error:
        print(f"::error::{error}", file=sys.stderr)
        return 1

    print(f"Bumping: {outputs['current']} -> {outputs['new_version']}  (tag: {outputs['tag']})")
    if args.github_output:
        with args.github_output.open("a", encoding="utf-8") as handle:
            for key, value in outputs.items():
                handle.write(f"{key}={value}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
