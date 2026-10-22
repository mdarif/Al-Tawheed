"""Structure tests for the CI/release toolchain pin.

The repo pins exactly one Flutter SDK, in `pubspec.yaml` (`environment:
flutter:`), and every workflow reads it from there via
`subosito/flutter-action`'s `flutter-version-file`. A literal `flutter-version:`
in a workflow reintroduces the drift where CI/release build with a different SDK
than the one the tests ran on.

The first classes are plain line checks (stdlib). The release-graph classes
below parse the workflows with PyYAML (pinned: `PYYAML_PIN`; every workflow job
that runs `make test-tooling` installs exactly that version, and a test here
enforces it). Locally: `python3 -m pip install PyYAML==6.0.3`.
"""

import json
import re
import unittest
from pathlib import Path

try:
    import yaml
except ImportError:  # reported by every graph test, never silently skipped
    yaml = None

PYYAML_PIN = "6.0.3"

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


# --------------------------------------------------------------------------- #
# PL2: the release workflow's job graph, parsed with PyYAML
# --------------------------------------------------------------------------- #
BOOL_TAG = "tag:yaml.org,2002:bool"


def _workflow_loader():
    """SafeLoader whose bool resolver only knows true/false.

    Plain `yaml.safe_load` follows YAML 1.1 and turns the workflow's top-level
    `on:` key into the boolean True (and `off`/`yes`/`no` likewise), which makes
    `doc["on"]` a KeyError. Here those stay strings.
    """
    if yaml is None:
        raise AssertionError(
            "PyYAML is required for the workflow graph tests: "
            f"python3 -m pip install PyYAML=={PYYAML_PIN}"
        )

    class Loader(yaml.SafeLoader):
        pass

    Loader.yaml_implicit_resolvers = {
        first: [(tag, rx) for tag, rx in resolvers if tag != BOOL_TAG]
        for first, resolvers in yaml.SafeLoader.yaml_implicit_resolvers.items()
    }
    Loader.add_implicit_resolver(BOOL_TAG, re.compile(r"^(?:true|false)$"), list("tf"))
    return Loader


def load_workflow(name: str) -> dict:
    text = (REPO / ".github" / "workflows" / name).read_text()
    return yaml.load(text, Loader=_workflow_loader())


def needs_of(job: dict) -> list:
    n = job.get("needs", [])
    return [n] if isinstance(n, str) else list(n)


def ancestors(jobs: dict, name: str) -> set:
    seen, todo = set(), needs_of(jobs[name])
    while todo:
        cur = todo.pop()
        if cur not in seen:
            seen.add(cur)
            todo.extend(needs_of(jobs[cur]))
    return seen


def run_steps(job: dict) -> list:
    return [st["run"] for st in job.get("steps", []) if "run" in st]


def job_blob(job: dict) -> str:
    return json.dumps(job)


def all_workflow_names() -> list:
    return [w.name for w in WORKFLOWS]


def all_run_texts(name: str) -> list:
    """Every `run:` body, plus android-emulator-runner `script:` bodies."""
    out = []
    for job in load_workflow(name)["jobs"].values():
        for st in job.get("steps", []):
            if "run" in st:
                out.append(st["run"])
            script = (st.get("with") or {}).get("script")
            if script:
                out.append(script)
    return out


STATUS_FN = re.compile(r"\b(always|failure|cancelled)\(\)")
# Anything that creates durable Git, Play or GitHub release state.
DURABLE = re.compile(
    r"git\s+push"
    r"|release_git\.py\s+(finalize|sync-develop|github-release)"
    r"|gh\s+release\s+(create|edit|upload)"
    r"|play_release_preflight\.py\s+assign"
    r"|upload-google-play"
)
EXPECTED_JOBS = {
    "prepare", "quality", "build-android", "verify-android", "finalize-git",
    "publish-play", "github-release", "sync-develop", "dry-run-summary",
}
GATED_ON_DRY_RUN = ("finalize-git", "publish-play", "github-release", "sync-develop")


class LoaderTest(unittest.TestCase):
    def test_on_stays_a_string_key_and_true_false_stay_booleans(self):
        doc = load_workflow("flutter-release.yml")
        self.assertIn("on", doc)
        self.assertNotIn(True, doc)
        dry = doc["on"]["workflow_dispatch"]["inputs"]["dry_run"]
        self.assertIs(dry["default"], False)

    def test_yes_no_off_are_not_coerced(self):
        loader = _workflow_loader()
        self.assertEqual(
            yaml.load("a: yes\nb: off\nc: no\nd: on", Loader=loader),
            {"a": "yes", "b": "off", "c": "no", "d": "on"},
        )


class ReleaseGraphTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.doc = load_workflow("flutter-release.yml")
        cls.jobs = cls.doc["jobs"]

    def test_job_set(self):
        self.assertEqual(set(self.jobs), EXPECTED_JOBS)

    def test_the_pipeline_is_one_chain_in_the_planned_order(self):
        chain = [
            "prepare", "quality", "build-android", "verify-android", "finalize-git",
            "publish-play", "github-release", "sync-develop",
        ]
        for prev, cur in zip(chain, chain[1:]):
            with self.subTest(job=cur):
                self.assertIn(prev, needs_of(self.jobs[cur]))

    def test_sync_develop_is_last(self):
        everyone_else = EXPECTED_JOBS - {"sync-develop", "dry-run-summary"}
        self.assertEqual(ancestors(self.jobs, "sync-develop"), everyone_else)
        for name, job in self.jobs.items():
            self.assertNotIn("sync-develop", needs_of(job), name)

    def test_publish_play_needs_finalize_git(self):
        self.assertIn("finalize-git", needs_of(self.jobs["publish-play"]))

    def test_github_release_needs_publish_play(self):
        # The release page advertises a shipped build, so it only appears once
        # Play has the exact artifact.
        self.assertIn("publish-play", needs_of(self.jobs["github-release"]))

    def test_nothing_durable_happens_in_a_job_that_does_not_need_verify_android(self):
        durable_jobs = set()
        for name, job in self.jobs.items():
            if DURABLE.search(job_blob(job)):
                durable_jobs.add(name)
                self.assertIn(
                    "verify-android",
                    ancestors(self.jobs, name),
                    f"{name} creates durable release state without needing verify-android",
                )
        # The detector must not be vacuous.
        self.assertTrue(set(GATED_ON_DRY_RUN) <= durable_jobs, durable_jobs)

    def test_no_raw_git_push_anywhere_all_pushes_go_through_release_git(self):
        for name, job in self.jobs.items():
            for body in run_steps(job):
                self.assertIsNone(re.search(r"git\s+push", body), f"{name}: {body[:80]}")

    def test_finalize_git_performs_exactly_one_finalize_and_only_it_does(self):
        calls = {
            name: sum(len(re.findall(r"release_git\.py\s+finalize\b", b)) for b in run_steps(job))
            for name, job in self.jobs.items()
        }
        self.assertEqual({n: c for n, c in calls.items() if c}, {"finalize-git": 1})

    def test_sync_develop_is_the_only_job_that_syncs_develop(self):
        calls = {
            name: sum(len(re.findall(r"release_git\.py\s+sync-develop\b", b)) for b in run_steps(job))
            for name, job in self.jobs.items()
        }
        self.assertEqual({n: c for n, c in calls.items() if c}, {"sync-develop": 1})


class DryRunTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.jobs = load_workflow("flutter-release.yml")["jobs"]

    def skipped_on_dry_run(self, name):
        cond = str(self.jobs[name].get("if", ""))
        if re.search(r"inputs\.dry_run\s*!=\s*true|!\s*inputs\.dry_run", cond):
            return True
        if STATUS_FN.search(cond):
            return False  # always()/failure() ignore skipped needs
        return any(self.skipped_on_dry_run(n) for n in needs_of(self.jobs[name]))

    def test_each_gated_job_carries_the_dry_run_condition_itself(self):
        for name in GATED_ON_DRY_RUN:
            with self.subTest(job=name):
                cond = str(self.jobs[name].get("if", ""))
                self.assertRegex(cond, r"inputs\.dry_run\s*!=\s*true")
                self.assertIsNone(STATUS_FN.search(cond), "a status function would defeat the skip")

    def test_a_dry_run_cannot_reach_any_state_changing_job(self):
        running = {n for n in self.jobs if not self.skipped_on_dry_run(n)}
        self.assertTrue(running.isdisjoint(GATED_ON_DRY_RUN), running)

    def test_a_dry_run_still_builds_and_verifies(self):
        running = {n for n in self.jobs if not self.skipped_on_dry_run(n)}
        self.assertTrue({"prepare", "quality", "build-android", "verify-android"} <= running, running)

    def test_a_real_release_does_not_run_the_dry_run_summary(self):
        self.assertRegex(str(self.jobs["dry-run-summary"]["if"]), r"inputs\.dry_run\s*==\s*true")

    def test_play_credentials_are_only_demanded_outside_a_dry_run(self):
        self.assertIn("inputs.dry_run != true", job_blob(self.jobs["prepare"]))


class VersionAndSourceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.jobs = load_workflow("flutter-release.yml")["jobs"]

    def test_version_is_computed_exactly_once_in_prepare_and_exported(self):
        hits = {
            n: sum(b.count("compute_release_version.py") for b in run_steps(j))
            for n, j in self.jobs.items()
        }
        self.assertEqual({n: c for n, c in hits.items() if c}, {"prepare": 1})
        outs = self.jobs["prepare"]["outputs"]
        for key in ("new_version", "source_sha", "tag", "apk", "aab", "build_number"):
            self.assertIn(key, outs)

    def test_bump_is_only_ever_read_by_prepare(self):
        for n, j in self.jobs.items():
            if n == "prepare":
                continue
            self.assertNotIn("inputs.bump", job_blob(j), n)
            self.assertNotIn("--bump", job_blob(j), n)

    def test_build_stamps_asserts_and_rebuilds_nothing_from_the_bump(self):
        steps = self.jobs["build-android"]["steps"]
        runs = [st.get("run", "") for st in steps]
        stamp = next(i for i, r in enumerate(runs) if "release_git.py stamp" in r)
        build = next(i for i, r in enumerate(runs) if "flutter build appbundle" in r)
        after = [i for i, r in enumerate(runs) if "release_git.py assert-version" in r and i > build]
        self.assertLess(stamp, build)
        self.assertTrue(after, "build-android must re-assert the version after building")
        self.assertIn("needs.prepare.outputs.new_version", steps[stamp]["run"])
        self.assertIn("release_git.py assert-build", "\n".join(runs))

    def test_finalize_git_uses_the_exact_new_version_and_source_sha(self):
        blob = job_blob(self.jobs["finalize-git"])
        self.assertIn("needs.prepare.outputs.new_version", blob)
        self.assertIn("needs.prepare.outputs.source_sha", blob)

    def test_build_records_the_aab_sha256_and_publish_play_checks_it(self):
        self.assertIn("aab_sha256", self.jobs["build-android"]["outputs"])
        self.assertIn("needs.build-android.outputs.aab_sha256", job_blob(self.jobs["publish-play"]))

    def test_every_checkout_is_pinned_to_an_immutable_sha_output(self):
        allowed = {
            "prepare": {"${{ github.sha }}"},
            "quality": {"${{ needs.prepare.outputs.source_sha }}"},
            "build-android": {"${{ needs.prepare.outputs.source_sha }}"},
            "verify-android": {"${{ needs.prepare.outputs.source_sha }}"},
            "finalize-git": {"${{ needs.prepare.outputs.source_sha }}"},
            "publish-play": {"${{ needs.finalize-git.outputs.release_sha }}"},
            "github-release": {"${{ needs.finalize-git.outputs.release_sha }}"},
            "sync-develop": {"${{ needs.finalize-git.outputs.release_sha }}"},
        }
        checkouts = 0
        for name, job in self.jobs.items():
            for st in job.get("steps", []):
                if str(st.get("uses", "")).startswith("actions/checkout@"):
                    checkouts += 1
                    with self.subTest(job=name):
                        self.assertIn((st.get("with") or {}).get("ref"), allowed[name])
        self.assertGreaterEqual(checkouts, 8)

    def test_prepare_rejects_unsupported_refs_and_unconfirmed_promotes(self):
        blob = job_blob(self.jobs["prepare"])
        self.assertIn("confirm_promote", blob)
        self.assertIn("refs/heads/develop", blob)
        self.assertIn("refs/heads/master", blob)

    def test_prepare_has_a_yq_preflight_and_a_read_only_play_snapshot(self):
        runs = "\n".join(run_steps(self.jobs["prepare"]))
        self.assertIn("yq --version", runs)
        self.assertIn("play_release_preflight.py snapshot", runs)
        self.assertNotIn("play_release_preflight.py assign", runs)


class QualityJobTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.jobs = load_workflow("flutter-release.yml")["jobs"]

    def test_runs_the_make_gates_in_order_without_rewriting_anything(self):
        runs = "\n".join(run_steps(self.jobs["quality"]))
        order = [runs.find(f"make {t}") for t in ("format-check", "analyze", "test", "test-tooling")]
        self.assertNotIn(-1, order, runs)
        self.assertEqual(order, sorted(order))
        self.assertNotRegex(runs, r"make format(\s|$)")

    def test_build_waits_for_quality(self):
        self.assertIn("quality", needs_of(self.jobs["build-android"]))

    def test_build_no_longer_repeats_the_quality_gates(self):
        runs = "\n".join(run_steps(self.jobs["build-android"]))
        for gate in ("flutter analyze", "flutter test", "dart format", "unittest discover"):
            self.assertNotIn(gate, runs)


class PlayPublishJobTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.jobs = load_workflow("flutter-release.yml")["jobs"]
        cls.steps = cls.jobs["publish-play"]["steps"]

    def idx(self, needle):
        for i, st in enumerate(self.steps):
            if needle in json.dumps(st):
                return i
        self.fail(f"no publish-play step mentions {needle!r}")

    def test_decides_then_acts_then_verifies(self):
        decide = self.idx("play_release_preflight.py decide")
        upload = self.idx("upload-google-play")
        assign = self.idx("play_release_preflight.py assign")
        verify = self.idx("play_release_preflight.py verify")
        self.assertLess(decide, min(upload, assign))
        self.assertLess(max(upload, assign), verify)

    def test_upload_and_assign_are_gated_on_the_decision(self):
        upload = self.steps[self.idx("upload-google-play")]
        assign = self.steps[self.idx("play_release_preflight.py assign")]
        self.assertRegex(upload["if"], r"steps\.\w+\.outputs\.action\s*==\s*'upload'")
        self.assertRegex(assign["if"], r"steps\.\w+\.outputs\.action\s*==\s*'assign'")

    def test_upload_failure_is_reconciled_against_play_not_trusted(self):
        # A failed-looking upload can still have committed; verify re-queries.
        self.assertIs(self.steps[self.idx("upload-google-play")].get("continue-on-error"), True)

    def test_still_targets_the_internal_track_only(self):
        blob = job_blob(self.jobs["publish-play"])
        self.assertIn('"track": "internal"', blob)
        self.assertNotIn("production", blob)


class ReleaseNotesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = (REPO / ".github" / "workflows" / "flutter-release.yml").read_text()
        cls.jobs = load_workflow("flutter-release.yml")["jobs"]

    def test_verification_claim_is_computed_not_hardcoded(self):
        self.assertNotIn("Verified", self.text)
        blob = job_blob(self.jobs["github-release"])
        self.assertIn("needs.verify-android.outputs.verified", blob)
        self.assertIn("verify-android", needs_of(self.jobs["github-release"]))

    def test_verified_output_is_only_set_by_a_step_that_ran_the_device_check(self):
        job = self.jobs["verify-android"]
        self.assertIn("verified", job["outputs"])
        setters = [st for st in job["steps"] if "verified=true" in st.get("run", "")]
        self.assertEqual(len(setters), 1)
        self.assertIn("inputs.skip_verify != true", setters[0]["if"])
        # ...and it comes after the emulator step.
        names = [st.get("name", "") for st in job["steps"]]
        emu = next(i for i, n in enumerate(names) if "Install, launch" in n)
        self.assertGreater(job["steps"].index(setters[0]), emu)

    def test_github_release_is_create_or_edit_with_clobber_via_the_tool(self):
        runs = "\n".join(run_steps(self.jobs["github-release"]))
        self.assertIn("release_git.py github-release", runs)
        self.assertNotIn("gh release create", runs)


class PlayWhatsNewWiringTest(unittest.TestCase):
    """The Play "What's new" text is the curated docs/release-notes/<version>.md
    block, produced and size-checked by tool/release_git.py. A blind byte
    truncation of the changelog (`head -c`) can cut mid-line or mid-UTF-8
    character, and a dry run never reaches publish-play, so the curated text is
    also validated in `prepare`, which a dry run does run."""

    @classmethod
    def setUpClass(cls):
        cls.text = (REPO / ".github" / "workflows" / "flutter-release.yml").read_text()
        cls.jobs = load_workflow("flutter-release.yml")["jobs"]

    @staticmethod
    def index_of(steps, needle):
        for i, st in enumerate(steps):
            if needle in json.dumps(st):
                return i
        raise AssertionError(f"no step mentions {needle!r}")

    def test_nothing_in_the_workflow_truncates_with_head_c(self):
        self.assertNotIn("head -c", self.text)

    def test_the_play_notes_step_uses_the_tool_and_writes_the_notes_file(self):
        steps = self.jobs["publish-play"]["steps"]
        step = steps[self.index_of(steps, "release_git.py play-notes")]
        run = step["run"]
        self.assertIn("--version", run)
        self.assertIn("--out play-store-notes.txt", run)
        self.assertIn("--changelog-file", run)  # git-cliff text is only the fallback

    def test_the_changelog_still_reaches_the_tool_through_env_not_inline(self):
        steps = self.jobs["publish-play"]["steps"]
        step = steps[self.index_of(steps, "release_git.py play-notes")]
        self.assertIn("steps.cliff.outputs.content", json.dumps(step.get("env", {})))
        self.assertNotIn("steps.cliff.outputs.content", step["run"])

    def test_notes_are_made_before_they_are_fanned_out_and_before_any_play_action(self):
        steps = self.jobs["publish-play"]["steps"]
        make = self.index_of(steps, "release_git.py play-notes")
        fan_out = self.index_of(steps, "distribution/whatsnew/whatsnew-")
        decide = self.index_of(steps, "play_release_preflight.py decide")
        self.assertLess(make, fan_out)
        self.assertLess(fan_out, decide)

    # The Play listing's default (and only) language is en-GB. Notes uploaded
    # under any other code attach to nothing, and the production promotion
    # form then shows "Release notes provided for 0 language" (2.4.2/2.4.3).
    PLAY_LISTING_LOCALES = ("en-GB",)

    def _whatsnew_locales(self):
        steps = self.jobs["publish-play"]["steps"]
        run = steps[self.index_of(steps, "distribution/whatsnew/whatsnew-")]["run"]
        m = re.search(r"for LOCALE in ([^;]+);", run)
        self.assertIsNotNone(m, "the whatsnew fan-out loop must stay greppable")
        return tuple(m.group(1).split())

    def test_notes_go_to_the_listing_default_language_en_gb(self):
        self.assertIn("en-GB", self._whatsnew_locales())

    def test_notes_go_only_to_languages_the_listing_has(self):
        self.assertEqual(self._whatsnew_locales(), self.PLAY_LISTING_LOCALES)

    def test_prepare_validates_the_curated_text_before_anything_is_built(self):
        steps = self.jobs["prepare"]["steps"]
        step = steps[self.index_of(steps, "release_git.py play-notes")]
        self.assertIn("--check", step["run"])
        self.assertIn("steps.version.outputs.new_semver", step["run"])
        self.assertLess(
            self.index_of(steps, "compute_release_version.py"),
            steps.index(step),
            "it needs the version, so it runs after the version is computed",
        )
        for later in ("verify-android", "build-android", "quality", "finalize-git", "publish-play"):
            self.assertIn("prepare", needs_of(self.jobs[later]) + sorted(ancestors(self.jobs, later)))

    def test_the_validation_is_not_skipped_on_a_dry_run(self):
        steps = self.jobs["prepare"]["steps"]
        step = steps[self.index_of(steps, "release_git.py play-notes")]
        self.assertNotIn("if", step, "a step-level condition could skip it on a dry run")
        # ...and `prepare` itself runs on a dry run (it has no job-level `if`).
        self.assertNotIn("if", self.jobs["prepare"])
        self.assertIn("prepare", ancestors(self.jobs, "verify-android"))

    def test_the_github_release_body_prefers_the_curated_section(self):
        runs = "\n".join(run_steps(self.jobs["github-release"]))
        self.assertIn("--release-notes-version", runs)
        self.assertIn("new_semver", runs)


class FormatAndMakeTargetsTest(unittest.TestCase):
    def test_every_dart_format_invocation_is_check_only(self):
        offenders = []
        for name in all_workflow_names():
            for body in all_run_texts(name):
                for m in re.finditer(r"dart\s+format\b[^\n]*", body):
                    cmd = m.group(0)
                    if "--set-exit-if-changed" not in cmd or not re.search(
                        r"(-o\s*none|--output[= ]none)", cmd
                    ):
                        offenders.append(f"{name}: {cmd}")
                if re.search(r"make\s+format(\s|$)", body):
                    offenders.append(f"{name}: make format (rewrites files)")
        self.assertEqual(offenders, [])

    def test_no_workflow_runs_analyze_or_format_directly(self):
        # Single source of truth: the Makefile's analyze / format-check targets.
        offenders = [
            f"{name}: {body.strip().splitlines()[0]}"
            for name in all_workflow_names()
            for body in all_run_texts(name)
            if re.search(r"flutter\s+analyze|dart\s+format", body)
        ]
        self.assertEqual(offenders, [])

    def test_device_and_golden_workflows_call_make_targets_for_their_tests(self):
        expected = {
            "flutter-golden.yml": "make test-goldens",
            "flutter-regression.yml": "make integration-test",
            "flutter-android-emulator.yml": "make integration-test",
        }
        for name, target in expected.items():
            with self.subTest(workflow=name):
                bodies = "\n".join(all_run_texts(name))
                self.assertIn(target, bodies)
                self.assertNotRegex(bodies, r"flutter\s+test")

    def test_ci_runs_the_makefile_gates(self):
        ci = "\n".join(all_run_texts("flutter-ci.yml"))
        for t in ("make format-check", "make analyze", "make test-tooling"):
            self.assertIn(t, ci)

    def test_one_upload_artifact_major_version_across_all_workflows(self):
        versions = set()
        for name in all_workflow_names():
            for job in load_workflow(name)["jobs"].values():
                for st in job.get("steps", []):
                    u = str(st.get("uses", ""))
                    if u.startswith("actions/upload-artifact@"):
                        versions.add(u)
        self.assertEqual(len(versions), 1, versions)

    def test_every_job_running_test_tooling_installs_the_pinned_pyyaml_first(self):
        found = 0
        for name in all_workflow_names():
            for jname, job in load_workflow(name)["jobs"].items():
                runs = run_steps(job)
                tooling = [i for i, r in enumerate(runs) if re.search(r"make\s+test-tooling", r)]
                if not tooling:
                    continue
                found += 1
                pins = [i for i, r in enumerate(runs) if f"PyYAML=={PYYAML_PIN}" in r]
                self.assertTrue(pins, f"{name}:{jname} runs test-tooling without the pinned PyYAML")
                self.assertLess(min(pins), min(tooling), f"{name}:{jname}")
        self.assertGreaterEqual(found, 2)  # ci + release quality


class SecretsAndPermissionsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.doc = load_workflow("flutter-release.yml")
        cls.jobs = cls.doc["jobs"]

    def users_of(self, secret):
        return {n for n, j in self.jobs.items() if f"secrets.{secret}" in job_blob(j)}

    def test_secrets_are_scoped_to_the_jobs_that_need_them(self):
        self.assertEqual(self.users_of("KEYSTORE_BASE64"), {"prepare", "build-android"})
        self.assertEqual(self.users_of("GOOGLE_PLAY_SERVICE_ACCOUNT"), {"prepare", "publish-play"})
        self.assertEqual(self.users_of("DEVELOP_SYNC_TOKEN"), {"sync-develop"})
        self.assertLessEqual(self.users_of("PLAY_FGS_MEDIA_DECLARED"), {"prepare", "publish-play"})

    def test_default_permissions_are_read_only_and_writes_are_per_job(self):
        self.assertEqual(self.doc["permissions"], {"contents": "read"})
        writers = {
            n for n, j in self.jobs.items() if (j.get("permissions") or {}).get("contents") == "write"
        }
        self.assertEqual(writers, {"finalize-git", "github-release"})


class DispatchContractTest(unittest.TestCase):
    """`make release MODE=...` dispatches with these inputs; keep them working."""

    @classmethod
    def setUpClass(cls):
        cls.doc = load_workflow("flutter-release.yml")

    def test_inputs_are_unchanged(self):
        inputs = self.doc["on"]["workflow_dispatch"]["inputs"]
        self.assertEqual(set(inputs), {"bump", "confirm_promote", "dry_run", "skip_verify"})
        self.assertEqual(inputs["bump"]["options"], ["patch", "minor", "major"])
        for k in ("confirm_promote", "dry_run", "skip_verify"):
            self.assertEqual(inputs[k]["type"], "boolean")
            self.assertIs(inputs[k]["default"], False)

    def test_release_runs_never_overlap_and_are_never_cancelled(self):
        self.assertEqual(self.doc["concurrency"], {"group": "release", "cancel-in-progress": False})

    def test_workflow_is_dispatch_only(self):
        self.assertEqual(set(self.doc["on"]), {"workflow_dispatch"})


class StaleCommentsTest(unittest.TestCase):
    @staticmethod
    def header(name):
        text = (REPO / ".github" / "workflows" / name).read_text()
        head = text.split("\nname:", 1)[0]
        return re.sub(r"\s+", " ", re.sub(r"(?m)^#", " ", head))

    def test_regression_header_does_not_claim_a_nightly_run(self):
        self.assertNotRegex(self.header("flutter-regression.yml"), r"Nightly at")

    def test_golden_header_does_not_say_the_repo_has_no_prs(self):
        self.assertNotIn("does not use PRs", self.header("flutter-golden.yml"))

    def test_live_contract_does_not_reference_the_removed_nightly_regression(self):
        self.assertNotIn("after the integration regression", self.header("flutter-live-contract.yml"))

    def test_no_workflow_names_a_literal_flutter_version_in_a_comment(self):
        for w in WORKFLOWS:
            self.assertNotIn("3.41.1", w.read_text(), w.name)


if __name__ == "__main__":
    unittest.main()
