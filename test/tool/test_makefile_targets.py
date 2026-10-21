"""Behaviour tests for the Makefile's release, perf and build targets.

The recipes are executed for real, with stub `gh`, `flutter` and `git` placed
first on PATH. The stubs only log their arguments, so nothing is dispatched,
built or run on a device, and no Flutter SDK or network is needed. Stdlib only,
so it runs under `make test-tooling`.
"""

import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
MAKEFILE = (REPO / "Makefile").read_text()
REAL_GIT = shutil.which("git") or "/usr/bin/git"

# Targets retired by the Makefile thinning. None may have a rule.
REMOVED = [
    "docker-build", "firebase-config", "docs", "help-verbose", "check-quality",
    "dev-setup", "pre-commit", "build-all", "build-web", "build-android-split",
    "run-verbose", "run-profile", "run-release", "pub-upgrade", "pub-outdated",
    "dependencies", "upgrade-flutter", "open-xcode", "open-android-studio",
    "build", "release-auto", "release-dry", "perf-test", "perf-smoke",
]

LOGGING_STUB = """#!/bin/sh
echo "$(basename "$0") $*" >> "$STUB_LOG"
"""

GIT_STUB = f"""#!/bin/sh
if [ "$1" = "rev-parse" ]; then echo "$FAKE_BRANCH"; exit 0; fi
exec "{REAL_GIT}" "$@"
"""


def run_make(*args, branch="master"):
    """Run make in the repo with stubbed tools; return (rc, logged calls, output)."""
    with tempfile.TemporaryDirectory() as tmp:
        bindir = Path(tmp, "bin")
        bindir.mkdir()
        for name, body in (("gh", LOGGING_STUB), ("flutter", LOGGING_STUB), ("git", GIT_STUB)):
            stub = bindir / name
            stub.write_text(body)
            stub.chmod(0o755)
        log = Path(tmp, "calls.log")
        env = {
            **os.environ,
            "PATH": f"{bindir}{os.pathsep}{os.environ['PATH']}",
            "STUB_LOG": str(log),
            "FAKE_BRANCH": branch,
        }
        proc = subprocess.run(
            ["make", *args], cwd=REPO, env=env, capture_output=True, text=True
        )
        calls = log.read_text().splitlines() if log.exists() else []
        return proc.returncode, calls, proc.stdout + proc.stderr


def _rule_targets():
    names = set(re.findall(r"^([A-Za-z][A-Za-z0-9_.-]*)\s*:(?!=)", MAKEFILE, re.M))
    names.discard("help")
    return names


class ReleaseTests(unittest.TestCase):
    RELEASE_WORKFLOW = "gh workflow run flutter-release.yml"

    def test_default_mode_dispatches_master_release(self):
        rc, calls, out = run_make("release", "BUMP=patch", branch="master")
        self.assertEqual(rc, 0, out)
        self.assertEqual(
            calls,
            [f"{self.RELEASE_WORKFLOW} --ref master --field bump=patch"],
        )

    def test_master_mode_refuses_other_branches(self):
        rc, calls, _ = run_make("release", "MODE=master", branch="develop")
        self.assertNotEqual(rc, 0)
        self.assertEqual(calls, [])

    def test_develop_mode_promotes_from_develop(self):
        rc, calls, out = run_make("release", "MODE=develop", "BUMP=minor", branch="develop")
        self.assertEqual(rc, 0, out)
        self.assertEqual(
            calls,
            [
                f"{self.RELEASE_WORKFLOW} --ref develop --field bump=minor"
                " --field confirm_promote=true --field dry_run=false"
            ],
        )

    def test_develop_mode_dry_run_variable_is_passed_through(self):
        rc, calls, out = run_make(
            "release", "MODE=develop", "BUMP=patch", "DRY_RUN=true", branch="develop"
        )
        self.assertEqual(rc, 0, out)
        self.assertEqual(
            calls,
            [
                f"{self.RELEASE_WORKFLOW} --ref develop --field bump=patch"
                " --field confirm_promote=true --field dry_run=true"
            ],
        )

    def test_develop_mode_refuses_master(self):
        rc, calls, _ = run_make("release", "MODE=develop", branch="master")
        self.assertNotEqual(rc, 0)
        self.assertEqual(calls, [])

    def test_dry_mode_dispatches_dry_run_without_promote(self):
        rc, calls, out = run_make("release", "MODE=dry", "BUMP=patch", branch="develop")
        self.assertEqual(rc, 0, out)
        self.assertEqual(
            calls,
            [
                f"{self.RELEASE_WORKFLOW} --ref develop --field bump=patch"
                " --field dry_run=true --field confirm_promote=false"
            ],
        )

    def test_dry_mode_refuses_master(self):
        rc, calls, _ = run_make("release", "MODE=dry", branch="master")
        self.assertNotEqual(rc, 0)
        self.assertEqual(calls, [])

    def test_unknown_mode_is_rejected_before_dispatch(self):
        # On master, so a Makefile that ignores MODE would dispatch and fail this.
        rc, calls, _ = run_make("release", "MODE=bogus", branch="master")
        self.assertNotEqual(rc, 0)
        self.assertEqual(calls, [])


class PerfTests(unittest.TestCase):
    @staticmethod
    def _drives(calls):
        return [c for c in calls if c.startswith("flutter drive ")]

    def test_default_mode_is_full_and_keeps_thresholds(self):
        rc, calls, out = run_make("perf", "DEVICE=dev1")
        self.assertEqual(rc, 0, out)
        drives = self._drives(calls)
        self.assertEqual(len(drives), 1, calls)
        self.assertIn("--profile", drives[0])
        self.assertIn("-d dev1", drives[0])
        self.assertNotIn("PERF_ENFORCE_THRESHOLDS", drives[0])

    def test_full_mode_keeps_thresholds(self):
        rc, calls, out = run_make("perf", "MODE=full", "DEVICE=dev1")
        self.assertEqual(rc, 0, out)
        drives = self._drives(calls)
        self.assertEqual(len(drives), 1, calls)
        self.assertNotIn("PERF_ENFORCE_THRESHOLDS", drives[0])

    def test_smoke_mode_disables_threshold_enforcement(self):
        rc, calls, out = run_make("perf", "MODE=smoke", "DEVICE=dev1")
        self.assertEqual(rc, 0, out)
        drives = self._drives(calls)
        self.assertEqual(len(drives), 1, calls)
        self.assertIn("--dart-define=PERF_ENFORCE_THRESHOLDS=false", drives[0])
        self.assertIn("-d dev1", drives[0])

    def test_requires_device(self):
        rc, calls, _ = run_make("perf", "MODE=smoke")
        self.assertNotEqual(rc, 0)
        self.assertEqual(self._drives(calls), [])

    def test_unknown_mode_is_rejected(self):
        rc, calls, _ = run_make("perf", "MODE=bogus", "DEVICE=dev1")
        self.assertNotEqual(rc, 0)
        self.assertEqual(self._drives(calls), [])


class BuildTests(unittest.TestCase):
    def test_build_android_is_a_debug_apk(self):
        rc, calls, out = run_make("build-android")
        self.assertEqual(rc, 0, out)
        self.assertEqual(calls, ["flutter build apk --debug"])


def _phony():
    return set(re.search(r"^\.PHONY:(.*)$", MAKEFILE, re.M).group(1).split())


class MakefileShapeTests(unittest.TestCase):
    def test_removed_targets_have_no_rule(self):
        # `make docs` resolves to the docs/ directory ("Nothing to be done"), so
        # the proof is: no rule in the Makefile, not in .PHONY, and no recipe runs.
        for name in REMOVED:
            with self.subTest(target=name):
                self.assertNotIn(name, _rule_targets())
                self.assertNotIn(name, _phony())
                _, _, out = run_make("-B", "-n", name)
                # Make's own messages ("make[1]: ...", "make: ...") are allowed;
                # any other output line would mean a recipe ran.
                self.assertNotRegex(out, r"(?m)^(?!make(\[\d+\])?: )\S", out)

    def test_phony_lists_only_real_targets(self):
        self.assertEqual(sorted(_phony() - _rule_targets() - {"help"}), [])

    def test_help_lists_exactly_the_real_targets(self):
        rc, _, out = run_make("help")
        self.assertEqual(rc, 0, out)
        listed = set(re.findall(r"^\s+make (\S+)\s+-", out, re.M))
        self.assertEqual(sorted(listed), sorted(_rule_targets()))


if __name__ == "__main__":
    unittest.main()
