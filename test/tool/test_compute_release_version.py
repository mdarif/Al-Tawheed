"""Tests for tool/compute_release_version.py.

The release pipeline derives the tag and the Play versionCode from this module
alone, and a wrong answer is expensive: a burned versionCode cannot be reused,
and a duplicate tag aborts a release mid-flight. Hence tests.
"""

import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

_spec = importlib.util.spec_from_file_location(
    "compute_release_version", REPO / "tool" / "compute_release_version.py"
)
assert _spec is not None and _spec.loader is not None
crv = importlib.util.module_from_spec(_spec)
sys.modules[_spec.name] = crv
_spec.loader.exec_module(crv)


PUBSPEC = """name: myapp
description: Al-Tawheed
publish_to: 'none'
version: 2.4.0+19

environment:
  sdk: ^3.9.0
"""


class ParseVersionTest(unittest.TestCase):
    def test_parses_semver_and_build(self):
        self.assertEqual(crv.parse_version(PUBSPEC), (2, 4, 0, 19))

    def test_rejects_version_without_build_number(self):
        with self.assertRaises(crv.ReleaseVersionError):
            crv.parse_version("version: 2.4.0\n")

    def test_rejects_missing_version_line(self):
        with self.assertRaises(crv.ReleaseVersionError):
            crv.parse_version("name: myapp\n")

    def test_ignores_a_version_key_nested_under_another_node(self):
        # `  version: 1.0.0+1` under dependencies must not be mistaken for the
        # package version — the regex is anchored to column zero.
        nested = "dependencies:\n  foo:\n    version: 9.9.9+99\n" + PUBSPEC
        self.assertEqual(crv.parse_version(nested), (2, 4, 0, 19))


class BumpVersionTest(unittest.TestCase):
    def test_patch(self):
        self.assertEqual(crv.bump_version(2, 4, 0, 19, "patch"), ("2.4.1", 20))

    def test_minor_resets_patch(self):
        self.assertEqual(crv.bump_version(2, 4, 3, 19, "minor"), ("2.5.0", 20))

    def test_major_resets_minor_and_patch(self):
        self.assertEqual(crv.bump_version(2, 4, 3, 19, "major"), ("3.0.0", 20))

    def test_build_number_always_increments(self):
        for bump in ("patch", "minor", "major"):
            with self.subTest(bump=bump):
                _, build = crv.bump_version(2, 4, 0, 19, bump)
                self.assertEqual(build, 20, "Play needs a strictly increasing versionCode")

    def test_unknown_bump_is_rejected(self):
        with self.assertRaises(crv.ReleaseVersionError):
            crv.bump_version(2, 4, 0, 19, "hotfix")


class ApplyVersionTest(unittest.TestCase):
    def test_rewrites_only_the_version_line(self):
        updated = crv.apply_version(PUBSPEC, "2.4.1+20")
        self.assertIn("version: 2.4.1+20\n", updated)
        self.assertIn("name: myapp\n", updated)
        self.assertIn("sdk: ^3.9.0\n", updated)
        self.assertEqual(len(updated.splitlines()), len(PUBSPEC.splitlines()))


class ComputeTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self._tmp.name)
        self.pubspec = self.repo / "pubspec.yaml"
        self.pubspec.write_text(PUBSPEC, encoding="utf-8")
        self.addCleanup(self._tmp.cleanup)

    def _git(self, *args):
        subprocess.run(("git", *args), cwd=self.repo, check=True, stdout=subprocess.DEVNULL)

    def _init_repo_with_tag(self, tag):
        self._git("init", "-q")
        self._git("config", "user.email", "t@example.com")
        self._git("config", "user.name", "t")
        self._git("add", "pubspec.yaml")
        self._git("commit", "-qm", "init")
        self._git("tag", tag)

    def test_outputs_every_key_the_workflow_consumes(self):
        outputs = crv.compute(
            pubspec=self.pubspec, bump="patch", repo=self.repo, write=False, check_tag=False
        )
        self.assertEqual(
            outputs,
            {
                "current": "2.4.0+19",
                "new_version": "2.4.1+20",
                "new_semver": "2.4.1",
                "build_number": "20",
                "tag": "2.4.1",
                "apk": "al-tawheed-2.4.1.apk",
                "aab": "al-tawheed-2.4.1.aab",
            },
        )

    def test_tag_has_no_v_prefix(self):
        outputs = crv.compute(
            pubspec=self.pubspec, bump="minor", repo=self.repo, write=False, check_tag=False
        )
        self.assertEqual(outputs["tag"], "2.5.0")
        self.assertFalse(outputs["tag"].startswith("v"))

    def test_write_updates_pubspec(self):
        crv.compute(
            pubspec=self.pubspec, bump="patch", repo=self.repo, write=True, check_tag=False
        )
        self.assertIn("version: 2.4.1+20", self.pubspec.read_text(encoding="utf-8"))

    def test_without_write_pubspec_is_untouched(self):
        crv.compute(
            pubspec=self.pubspec, bump="patch", repo=self.repo, write=False, check_tag=False
        )
        self.assertEqual(self.pubspec.read_text(encoding="utf-8"), PUBSPEC)

    def test_existing_tag_aborts(self):
        self._init_repo_with_tag("2.4.1")
        with self.assertRaises(crv.ReleaseVersionError) as caught:
            crv.compute(
                pubspec=self.pubspec, bump="patch", repo=self.repo, write=True, check_tag=True
            )
        self.assertIn("2.4.1", str(caught.exception))
        # A rejected release must not leave a half-bumped pubspec behind.
        self.assertEqual(self.pubspec.read_text(encoding="utf-8"), PUBSPEC)

    def test_unrelated_existing_tag_does_not_abort(self):
        self._init_repo_with_tag("2.3.9")
        outputs = crv.compute(
            pubspec=self.pubspec, bump="patch", repo=self.repo, write=False, check_tag=True
        )
        self.assertEqual(outputs["tag"], "2.4.1")


if __name__ == "__main__":
    unittest.main()
