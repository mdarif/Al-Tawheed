"""Structure tests for the CI/release toolchain pin.

The repo pins exactly one Flutter SDK, in `pubspec.yaml` (`environment:
flutter:`), and every workflow reads it from there via
`subosito/flutter-action`'s `flutter-version-file`. A literal `flutter-version:`
in a workflow reintroduces the drift where CI/release build with a different SDK
than the one the tests ran on. Stdlib only (no PyYAML) so it runs anywhere
`make test-tooling` does.
"""

import re
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
WORKFLOWS = sorted((REPO / ".github" / "workflows").glob("*.y*ml"))
PUBSPEC = (REPO / "pubspec.yaml").read_text()

# subosito/flutter-action only understands an exact version in the pubspec.
EXACT_VERSION = re.compile(r"^\d+\.\d+\.\d+$")


def _active_lines(path: Path):
    """Yield (lineno, line) for non-comment lines."""
    for n, line in enumerate(path.read_text().splitlines(), 1):
        if not line.lstrip().startswith("#"):
            yield n, line


def _environment_block(pubspec: str) -> dict:
    m = re.search(r"^environment:[ \t]*\n((?:[ \t]+.*\n|\n)+)", pubspec, re.M)
    assert m, "pubspec.yaml has no environment: block"
    out = {}
    for line in m.group(1).splitlines():
        kv = re.match(r"^\s+([A-Za-z_]+):\s*(.+?)\s*$", line)
        if kv:
            out[kv.group(1)] = kv.group(2).strip("'\"")
    return out


class WorkflowSdkPinTest(unittest.TestCase):
    def test_workflows_found(self):
        self.assertGreaterEqual(len(WORKFLOWS), 6)

    def test_no_literal_flutter_version_key(self):
        offenders = [
            f"{w.name}:{n}: {line.strip()}"
            for w in WORKFLOWS
            for n, line in _active_lines(w)
            if re.match(r"^\s*flutter-version\s*:", line)
        ]
        self.assertEqual(offenders, [], "literal flutter-version: found")

    def test_every_flutter_action_uses_version_file(self):
        offenders = []
        for w in WORKFLOWS:
            lines = [line for _, line in _active_lines(w)]
            uses = sum(1 for l in lines if "uses: subosito/flutter-action" in l)
            files = [
                l
                for l in lines
                if re.match(r"^\s*flutter-version-file\s*:\s*pubspec\.yaml\s*$", l)
            ]
            if uses != len(files):
                offenders.append(
                    f"{w.name}: {uses} flutter-action step(s), "
                    f"{len(files)} flutter-version-file: pubspec.yaml"
                )
        self.assertEqual(offenders, [])

    def test_pubspec_pins_one_exact_flutter_version(self):
        env = _environment_block(PUBSPEC)
        self.assertIn("flutter", env, "pubspec environment: has no flutter pin")
        self.assertRegex(
            env["flutter"],
            EXACT_VERSION,
            "flutter-action needs an exact version, not a range",
        )

    def test_setup_doc_states_the_pinned_version(self):
        pinned = _environment_block(PUBSPEC).get("flutter", "<none>")
        self.assertIn(pinned, (REPO / "docs" / "setup.md").read_text())


class MigratorOutputsCommittedTest(unittest.TestCase):
    """Flutter 3.47.4 rewrites these files on any `flutter` command unless the
    migrator outputs are already committed (otherwise every run dirties the
    tree)."""

    def test_analyzer_excludes_build_and_platform_dirs(self):
        text = (REPO / "analysis_options.yaml").read_text()
        block = re.search(r"^analyzer:[ \t]*\n((?:[ \t]+.*\n|\n)+)", text, re.M)
        self.assertIsNotNone(block, "no analyzer: block")
        ex = re.search(
            r"^[ ]{2}exclude:[ \t]*\n((?:[ ]{4}-[ ]+.*\n)+)", block.group(1), re.M
        )
        self.assertIsNotNone(ex, "analyzer: has no exclude: list")
        excludes = {
            l.strip()[1:].strip().strip("'\"") for l in ex.group(1).splitlines()
        }
        expected = {"build/**"} | {
            f"{d}/**"
            for d in ("android", "ios", "web", "windows", "macos", "linux")
            if (REPO / d).is_dir()
        }
        self.assertEqual(expected - excludes, set())

    def test_gradle_properties_disables_builtin_kotlin(self):
        lines = [l.strip() for _, l in _active_lines(REPO / "android" / "gradle.properties")]
        self.assertIn("android.builtInKotlin=false", lines)


if __name__ == "__main__":
    unittest.main()
