"""Tests for tool/release_git.py.

These are the decisions the release workflow must get right and cannot take
back: whether a half-finished release may be resumed, what gets pushed (and
that it is ONE atomic push), whether `develop` may be moved, and what the
GitHub Release claims about verification.

The git behaviour is exercised against REAL git: a bare "origin" and a working
clone in a temp dir, so atomicity and fast-forward rules are git's own, not a
mock's. Nothing here touches the network, GitHub, or the Play API.
"""

import contextlib
import importlib.util
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

_spec = importlib.util.spec_from_file_location("release_git", REPO / "tool" / "release_git.py")
assert _spec is not None and _spec.loader is not None
rg = importlib.util.module_from_spec(_spec)
sys.modules[_spec.name] = rg
_spec.loader.exec_module(rg)

SOURCE = "a" * 40
OTHER = "b" * 40
NEW = "2.4.2+21"


# --------------------------------------------------------------------------- #
# Pure decisions
# --------------------------------------------------------------------------- #
class ResumeDecisionTest(unittest.TestCase):
    def decide(self, **overrides):
        facts = dict(
            tag_commit="c" * 40,
            tag_parent=SOURCE,
            tag_version=NEW,
            master_contains_tag=True,
            source_sha=SOURCE,
            new_version=NEW,
        )
        facts.update(overrides)
        return rg.resume_decision(**facts)

    def test_tag_absent_creates(self):
        d = self.decide(tag_commit=None, tag_parent=None, tag_version=None, master_contains_tag=None)
        self.assertEqual(d.action, "create")

    def test_tag_matching_everything_resumes(self):
        self.assertEqual(self.decide().action, "resume")

    def test_wrong_version_aborts(self):
        d = self.decide(tag_version="2.4.2+99")
        self.assertEqual(d.action, "abort")
        self.assertIn("2.4.2+99", d.reason)
        self.assertIn(NEW, d.reason)

    def test_unreadable_version_aborts(self):
        self.assertEqual(self.decide(tag_version=None).action, "abort")

    def test_wrong_parent_aborts(self):
        d = self.decide(tag_parent=OTHER)
        self.assertEqual(d.action, "abort")
        self.assertIn("parent", d.reason)

    def test_tag_commit_without_a_single_parent_aborts(self):
        self.assertEqual(self.decide(tag_parent=None).action, "abort")

    def test_master_missing_the_tag_aborts(self):
        d = self.decide(master_contains_tag=False)
        self.assertEqual(d.action, "abort")
        self.assertIn("master", d.reason)

    def test_every_abort_says_what_to_do_not_just_what_is_wrong(self):
        for overrides in ({"tag_version": "0.0.0+1"}, {"tag_parent": OTHER}, {"master_contains_tag": False}):
            with self.subTest(**overrides):
                self.assertIn("Do not", self.decide(**overrides).reason)


class SyncDecisionTest(unittest.TestCase):
    def test_develop_already_contains_the_tag_is_a_noop(self):
        d = rg.sync_decision(develop_sha=OTHER, source_sha=SOURCE, develop_contains_tag=True)
        self.assertEqual(d.action, "noop")

    def test_develop_still_at_source_fast_forwards(self):
        d = rg.sync_decision(develop_sha=SOURCE, source_sha=SOURCE, develop_contains_tag=False)
        self.assertEqual(d.action, "fast-forward")

    def test_develop_moved_fails_with_merge_instructions(self):
        d = rg.sync_decision(develop_sha=OTHER, source_sha=SOURCE, develop_contains_tag=False)
        self.assertEqual(d.action, "fail")
        self.assertIn("git merge", d.reason)

    def test_missing_develop_fails(self):
        d = rg.sync_decision(develop_sha=None, source_sha=SOURCE, develop_contains_tag=False)
        self.assertEqual(d.action, "fail")


# --------------------------------------------------------------------------- #
# Real-git fixtures
# --------------------------------------------------------------------------- #
PUBSPEC = "name: myapp\nversion: 2.4.1+20\n\nenvironment:\n  sdk: ^3.9.0\n"


def git(cwd, *args, check=True):
    env = {
        **os.environ,
        "GIT_AUTHOR_NAME": "t",
        "GIT_AUTHOR_EMAIL": "t@example.com",
        "GIT_COMMITTER_NAME": "t",
        "GIT_COMMITTER_EMAIL": "t@example.com",
        "GIT_CONFIG_GLOBAL": os.devnull,
        "GIT_CONFIG_SYSTEM": os.devnull,
    }
    proc = subprocess.run(
        ["git", *args], cwd=cwd, env=env, capture_output=True, text=True, check=False
    )
    if check and proc.returncode != 0:
        raise AssertionError(f"git {' '.join(args)} failed: {proc.stderr}")
    return proc.stdout.strip()


def _quiet(case):
    """Swallow the tool's progress output so test runs stay readable."""
    stack = contextlib.ExitStack()
    stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
    stack.enter_context(contextlib.redirect_stderr(io.StringIO()))
    case.addCleanup(stack.close)


class GitFixture(unittest.TestCase):
    """origin (bare) with master == develop == SRC, and a clone detached at SRC."""

    def setUp(self):
        _quiet(self)
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        tmp = Path(self._tmp.name)
        self.origin = tmp / "origin.git"
        git(tmp, "init", "--bare", "-b", "master", str(self.origin))
        self.work = tmp / "work"
        git(tmp, "clone", str(self.origin), str(self.work))
        git(self.work, "checkout", "-b", "master")
        (self.work / "pubspec.yaml").write_text(PUBSPEC)
        git(self.work, "add", ".")
        git(self.work, "commit", "-m", "feat: base")
        git(self.work, "push", "origin", "master")
        git(self.work, "push", "origin", "master:develop")
        self.src = git(self.work, "rev-parse", "HEAD")
        git(self.work, "checkout", "--detach", self.src)
        # The git wrapper release_git uses must see the same identity.
        self._env = dict(os.environ)
        os.environ.update(
            GIT_AUTHOR_NAME="t",
            GIT_AUTHOR_EMAIL="t@example.com",
            GIT_COMMITTER_NAME="t",
            GIT_COMMITTER_EMAIL="t@example.com",
            GIT_CONFIG_GLOBAL=os.devnull,
            GIT_CONFIG_SYSTEM=os.devnull,
        )
        self.addCleanup(self._restore_env)

    def _restore_env(self):
        os.environ.clear()
        os.environ.update(self._env)

    # helpers ---------------------------------------------------------------
    def remote(self, *args):
        return git(self.origin, *args)

    def remote_ref(self, ref):
        return git(self.origin, "rev-parse", "--verify", "-q", ref, check=False)

    def advance_remote(self, branch, name="x.txt"):
        """Land an unrelated commit on origin/<branch> (as another pusher would)."""
        other = Path(self._tmp.name, f"other-{branch}")
        if not other.exists():
            git(self._tmp.name, "clone", str(self.origin), str(other))
        git(other, "fetch", "origin")
        git(other, "checkout", "-B", branch, f"origin/{branch}")
        (other / name).write_text(branch)
        git(other, "add", ".")
        git(other, "commit", "-m", f"feat: landed on {branch}")
        git(other, "push", "origin", f"{branch}:{branch}")
        return git(other, "rev-parse", "HEAD")

    def finalize(self, **overrides):
        kwargs = dict(source_sha=self.src, tag="2.4.2", new_version=NEW)
        kwargs.update(overrides)
        return rg.finalize(self.work, **kwargs)


class FinalizeTest(GitFixture):
    def test_creates_release_commit_and_tag_on_master(self):
        result = self.finalize()
        self.assertFalse(result.resumed)
        self.assertEqual(self.remote_ref("refs/heads/master"), result.release_sha)
        self.assertEqual(self.remote_ref("refs/tags/2.4.2^{commit}"), result.release_sha)
        self.assertEqual(git(self.work, "rev-parse", f"{result.release_sha}^"), self.src)
        self.assertIn(
            "version: 2.4.2+21", git(self.work, "show", f"{result.release_sha}:pubspec.yaml")
        )
        self.assertEqual(
            git(self.work, "log", "-1", "--format=%s", result.release_sha), "chore: release 2.4.2"
        )
        changed = git(self.work, "diff", "--name-only", f"{self.src}", result.release_sha)
        self.assertEqual(changed, "pubspec.yaml")

    def test_promotes_develop_to_master_in_the_same_push(self):
        # develop is ahead of master: the promote and the release land together.
        git(self.work, "checkout", "-q", "--detach", self.src)
        ahead = self.advance_remote("develop")
        git(self.work, "fetch", "origin")
        git(self.work, "checkout", "-q", "--detach", ahead)
        self.assertNotEqual(self.remote_ref("refs/heads/master"), ahead)
        result = self.finalize(source_sha=ahead)
        self.assertEqual(self.remote_ref("refs/heads/master"), result.release_sha)
        self.assertEqual(git(self.work, "rev-parse", f"{result.release_sha}^"), ahead)

    def test_exactly_one_push_and_it_is_atomic_for_branch_and_tag(self):
        pushes = []
        real = rg.git

        def spy(repo, *args, **kwargs):
            if args and args[0] == "push":
                pushes.append(args)
            return real(repo, *args, **kwargs)

        rg.git = spy
        try:
            self.finalize()
        finally:
            rg.git = real
        self.assertEqual(len(pushes), 1, pushes)
        (push,) = pushes
        self.assertIn("--atomic", push)
        self.assertTrue(any("refs/heads/master" in a for a in push), push)
        self.assertTrue(any("refs/tags/2.4.2" in a for a in push), push)
        self.assertNotIn("--force", push)
        self.assertFalse(any(a.startswith("--force-with-lease") for a in push), push)

    def test_a_rejected_master_update_leaves_no_tag_on_origin(self):
        # A per-ref `update` hook (not pre-receive, which is all-or-nothing by
        # itself): without `push --atomic` the tag would still land.
        hook = self.origin / "hooks" / "update"
        hook.write_text(
            "#!/bin/sh\n"
            '[ "$1" = refs/heads/master ] && { echo "master locked" >&2; exit 1; }\n'
            "exit 0\n"
        )
        hook.chmod(0o755)
        with self.assertRaises(rg.ReleaseAbort):
            self.finalize()
        self.assertEqual(self.remote_ref("refs/tags/2.4.2"), "")
        self.assertEqual(self.remote_ref("refs/heads/master"), self.src)

    def test_rerun_after_success_resumes_without_a_second_commit(self):
        first = self.finalize()
        # A fresh runner re-run: checkout at the same source SHA again.
        git(self.work, "checkout", "-q", "--detach", self.src)
        git(self.work, "tag", "-d", "2.4.2")
        before = self.remote_ref("refs/heads/master")
        second = self.finalize()
        self.assertTrue(second.resumed)
        self.assertEqual(second.release_sha, first.release_sha)
        self.assertEqual(self.remote_ref("refs/heads/master"), before)

    def test_resume_aborts_when_tag_has_a_different_parent(self):
        git(self.work, "commit", "--allow-empty", "-m", "feat: elsewhere 1")
        git(self.work, "commit", "--allow-empty", "-m", "feat: elsewhere 2")
        stray = git(self.work, "rev-parse", "HEAD")  # its parent is NOT the source SHA
        git(self.work, "tag", "2.4.2", stray)
        git(self.work, "push", "origin", "refs/tags/2.4.2")
        git(self.work, "checkout", "-q", "--detach", self.src)
        before = self.remote_ref("refs/heads/master")
        with self.assertRaises(rg.ReleaseAbort) as ctx:
            self.finalize()
        self.assertIn("parent", str(ctx.exception))
        self.assertEqual(self.remote_ref("refs/heads/master"), before)

    def test_resume_aborts_when_tagged_pubspec_has_another_version(self):
        (self.work / "pubspec.yaml").write_text(PUBSPEC.replace("2.4.1+20", "2.4.2+77"))
        git(self.work, "commit", "-am", "chore: release 2.4.2")
        wrong = git(self.work, "rev-parse", "HEAD")
        git(self.work, "tag", "2.4.2")
        git(self.work, "push", "origin", "HEAD:master", "refs/tags/2.4.2")
        git(self.work, "checkout", "-q", "--detach", self.src)
        with self.assertRaises(rg.ReleaseAbort) as ctx:
            self.finalize()
        self.assertIn("2.4.2+77", str(ctx.exception))
        self.assertEqual(self.remote_ref("refs/heads/master"), wrong)

    def test_resume_aborts_when_master_does_not_contain_the_tag(self):
        # Right parent, right version, but only the tag reached origin.
        (self.work / "pubspec.yaml").write_text(PUBSPEC.replace("2.4.1+20", NEW))
        git(self.work, "commit", "-am", "chore: release 2.4.2")
        git(self.work, "tag", "2.4.2")
        git(self.work, "push", "origin", "refs/tags/2.4.2")
        git(self.work, "checkout", "-q", "--detach", self.src)
        with self.assertRaises(rg.ReleaseAbort) as ctx:
            self.finalize()
        self.assertIn("master", str(ctx.exception))
        self.assertEqual(self.remote_ref("refs/heads/master"), self.src)

    def test_aborts_without_pushing_when_master_moved_since_dispatch(self):
        moved = self.advance_remote("master")
        with self.assertRaises(rg.ReleaseAbort) as ctx:
            self.finalize()
        self.assertIn("master", str(ctx.exception))
        self.assertEqual(self.remote_ref("refs/heads/master"), moved)
        self.assertEqual(self.remote_ref("refs/tags/2.4.2"), "")

    def test_aborts_when_checkout_is_not_the_source_sha(self):
        with self.assertRaises(rg.ReleaseAbort):
            self.finalize(source_sha=OTHER)

    def test_aborts_on_a_dirty_tree(self):
        (self.work / "stray.txt").write_text("x")
        git(self.work, "add", "stray.txt")
        with self.assertRaises(rg.ReleaseAbort):
            self.finalize()
        self.assertEqual(self.remote_ref("refs/tags/2.4.2"), "")

    def test_refuses_a_new_version_that_is_not_ahead_of_the_checkout(self):
        with self.assertRaises(rg.ReleaseAbort):
            self.finalize(new_version="2.4.2+20")
        self.assertEqual(self.remote_ref("refs/tags/2.4.2"), "")


class SyncDevelopTest(GitFixture):
    def release(self):
        return self.finalize()

    def sync(self, release_sha):
        return rg.sync_develop(
            self.work, source_sha=self.src, release_sha=release_sha, tag="2.4.2"
        )

    def test_fast_forwards_develop_when_it_still_equals_the_source(self):
        r = self.release()
        d = self.sync(r.release_sha)
        self.assertEqual(d.action, "fast-forward")
        self.assertEqual(self.remote_ref("refs/heads/develop"), r.release_sha)

    def test_is_a_noop_when_develop_already_contains_the_tag(self):
        r = self.release()
        self.sync(r.release_sha)
        d = self.sync(r.release_sha)
        self.assertEqual(d.action, "noop")
        self.assertEqual(self.remote_ref("refs/heads/develop"), r.release_sha)

    def test_fails_without_overwriting_when_develop_moved(self):
        r = self.release()
        moved = self.advance_remote("develop")
        with self.assertRaises(rg.ReleaseAbort) as ctx:
            self.sync(r.release_sha)
        self.assertIn("git merge", str(ctx.exception))
        self.assertEqual(self.remote_ref("refs/heads/develop"), moved)

    def test_lease_rejects_a_push_when_develop_moved_after_the_decision(self):
        r = self.release()
        moved = self.advance_remote("develop")
        with self.assertRaises(rg.ReleaseAbort):
            rg.push_develop(
                self.work,
                remote="origin",
                branch="develop",
                expected_sha=self.src,
                release_sha=r.release_sha,
            )
        self.assertEqual(self.remote_ref("refs/heads/develop"), moved)


# --------------------------------------------------------------------------- #
# GitHub Release: create-or-edit, assets with --clobber
# --------------------------------------------------------------------------- #
class FakeGh:
    def __init__(self, view_rc=0, view_err=""):
        self.calls = []
        self.view_rc = view_rc
        self.view_err = view_err

    def __call__(self, args):
        self.calls.append(list(args))
        if args[:2] == ["release", "view"]:
            return subprocess.CompletedProcess(args, self.view_rc, "", self.view_err)
        return subprocess.CompletedProcess(args, 0, "", "")


ASSETS = ["rel/a.apk#APK", "rel/a.aab#AAB", "notes.txt#Notes"]


class GithubReleaseTest(unittest.TestCase):
    def go(self, gh):
        return rg.github_release(
            gh, tag="2.4.2", assets=ASSETS, notes_file="release-notes.md", title="Al-Tawheed 2.4.2"
        )

    def test_absent_release_is_created_with_assets_for_the_validated_tag(self):
        gh = FakeGh(view_rc=1, view_err="release not found")
        self.assertEqual(self.go(gh), "created")
        create = [c for c in gh.calls if c[:2] == ["release", "create"]]
        self.assertEqual(len(create), 1)
        self.assertEqual(create[0][2], "2.4.2")
        self.assertIn("--verify-tag", create[0])
        for a in ASSETS:
            self.assertIn(a, create[0])
        self.assertFalse([c for c in gh.calls if c[:2] == ["release", "edit"]])

    def test_existing_release_is_edited_and_assets_are_clobbered(self):
        gh = FakeGh(view_rc=0)
        self.assertEqual(self.go(gh), "updated")
        edit = [c for c in gh.calls if c[:2] == ["release", "edit"]]
        upload = [c for c in gh.calls if c[:2] == ["release", "upload"]]
        self.assertEqual(len(edit), 1)
        self.assertIn("--notes-file", edit[0])
        self.assertEqual(len(upload), 1)
        self.assertIn("--clobber", upload[0])
        for a in ASSETS:
            self.assertIn(a, upload[0])
        self.assertFalse([c for c in gh.calls if c[:2] == ["release", "create"]])

    def test_an_unexpected_view_failure_does_not_fall_through_to_create(self):
        gh = FakeGh(view_rc=1, view_err="HTTP 502: bad gateway")
        with self.assertRaises(rg.ReleaseAbort):
            self.go(gh)
        self.assertFalse([c for c in gh.calls if c[:2] == ["release", "create"]])


class CliWiringTest(GitFixture):
    """The workflow calls main(); check the argument plumbing end to end."""

    def test_finalize_writes_release_sha_and_resumed_to_github_output(self):
        out = Path(self._tmp.name, "gh-output")
        cwd = os.getcwd()
        os.chdir(self.work)
        self.addCleanup(os.chdir, cwd)
        rc = rg.main(
            [
                "finalize",
                "--source-sha", self.src,
                "--tag", "2.4.2",
                "--new-version", NEW,
                "--github-output", str(out),
            ]
        )
        self.assertEqual(rc, 0)
        lines = dict(l.split("=", 1) for l in out.read_text().splitlines())
        self.assertEqual(lines["release_sha"], self.remote_ref("refs/heads/master"))
        self.assertEqual(lines["resumed"], "false")

    def test_finalize_returns_nonzero_on_abort(self):
        cwd = os.getcwd()
        os.chdir(self.work)
        self.addCleanup(os.chdir, cwd)
        rc = rg.main(["finalize", "--source-sha", OTHER, "--tag", "2.4.2", "--new-version", NEW])
        self.assertEqual(rc, 1)

    def test_github_release_builds_honest_notes_and_calls_gh(self):
        calls = []

        def fake_gh(args):
            calls.append(list(args))
            rc, err = (1, "release not found") if args[:2] == ["release", "view"] else (0, "")
            return subprocess.CompletedProcess(args, rc, "", err)

        changelog = Path(self._tmp.name, "changelog.md")
        changelog.write_text("- fix: a thing\n")
        notes = Path(self._tmp.name, "notes.md")
        real = rg._gh
        rg._gh = fake_gh
        try:
            rc = rg.main(
                [
                    "github-release",
                    "--tag", "2.4.2",
                    "--new-version", NEW,
                    "--apk-name", "a.apk",
                    "--aab-sha256", "ab" * 32,
                    "--verified", "false",
                    "--changelog-file", str(changelog),
                    "--notes-out", str(notes),
                    "--title", "Al-Tawheed 2.4.2",
                    "--asset", "a.apk#APK",
                ]
            )
        finally:
            rg._gh = real
        self.assertEqual(rc, 0)
        self.assertIn("Device verification: SKIPPED", notes.read_text())
        self.assertEqual([c[:2] for c in calls], [["release", "view"], ["release", "create"]])


class ReleaseNotesTest(unittest.TestCase):
    def notes(self, verified, changelog="- feat: thing"):
        return rg.build_release_notes(
            changelog=changelog,
            new_version=NEW,
            apk_name="al-tawheed-2.4.2.apk",
            aab_sha256="ab" * 32,
            verified=verified,
        )

    def test_skipped_verification_is_stated_and_never_called_verified(self):
        text = self.notes(False)
        self.assertIn("Device verification: SKIPPED", text)
        self.assertNotIn("Verified", text)
        self.assertNotIn("installed, launched", text)

    def test_ran_verification_describes_what_was_done(self):
        text = self.notes(True)
        self.assertIn("Device verification: PASSED", text)
        self.assertIn("installed, launched", text)
        self.assertNotIn("SKIPPED", text)

    def test_carries_version_changelog_and_aab_hash(self):
        text = self.notes(True)
        self.assertIn(NEW, text)
        self.assertIn("- feat: thing", text)
        self.assertIn("ab" * 32, text)

    def test_empty_changelog_falls_back_to_maintenance_release(self):
        self.assertIn("- Maintenance release", self.notes(True, changelog=""))


# --------------------------------------------------------------------------- #
# Version stamping and build assertions
# --------------------------------------------------------------------------- #
class StampTest(unittest.TestCase):
    def setUp(self):
        _quiet(self)
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.pubspec = Path(self._tmp.name, "pubspec.yaml")
        self.pubspec.write_text(PUBSPEC)

    def test_stamps_exactly_the_given_version_and_nothing_else(self):
        rg.stamp_version(self.pubspec, NEW)
        self.assertEqual(self.pubspec.read_text(), PUBSPEC.replace("2.4.1+20", NEW))

    def test_rejects_a_malformed_version(self):
        for bad in ("2.4.2", "v2.4.2+21", "2.4+21", ""):
            with self.subTest(bad=bad), self.assertRaises(rg.ReleaseAbort):
                rg.stamp_version(self.pubspec, bad)
        self.assertEqual(self.pubspec.read_text(), PUBSPEC)

    def test_assert_version_passes_and_fails(self):
        rg.assert_version(self.pubspec, "2.4.1+20")
        with self.assertRaises(rg.ReleaseAbort):
            rg.assert_version(self.pubspec, NEW)

    def test_main_stamp_writes_the_version(self):
        rc = rg.main(["stamp", "--new-version", NEW, "--pubspec", str(self.pubspec)])
        self.assertEqual(rc, 0)
        rg.assert_version(self.pubspec, NEW)

    def test_main_assert_version_returns_nonzero_on_mismatch(self):
        rc = rg.main(["assert-version", "--new-version", NEW, "--pubspec", str(self.pubspec)])
        self.assertEqual(rc, 1)


class BuildMetadataTest(unittest.TestCase):
    def meta(self, root, name_dir, code, name):
        d = Path(root, name_dir)
        d.mkdir(parents=True)
        (d / "output-metadata.json").write_text(
            json.dumps({"elements": [{"versionCode": code, "versionName": name}]})
        )

    def test_matching_metadata_is_counted(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.meta(tmp, "apk/release", 21, "2.4.2")
            self.assertEqual(rg.assert_build_metadata(Path(tmp), NEW), 1)

    def test_a_build_with_another_version_code_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.meta(tmp, "apk/release", 20, "2.4.2")
            with self.assertRaises(rg.ReleaseAbort):
                rg.assert_build_metadata(Path(tmp), NEW)

    def test_a_build_with_another_version_name_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.meta(tmp, "apk/release", 21, "2.4.1")
            with self.assertRaises(rg.ReleaseAbort):
                rg.assert_build_metadata(Path(tmp), NEW)

    def test_no_metadata_found_reports_zero(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(rg.assert_build_metadata(Path(tmp), NEW), 0)


if __name__ == "__main__":
    unittest.main()
