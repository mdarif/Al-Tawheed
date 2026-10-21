"""Tests for tool/play_release_preflight.py.

The Play decision is the part of the release that cannot be undone: a
versionCode Play has consumed is gone for good. So the decision is a pure
function (`decide`) over a snapshot of Play state, and the artifact identity
check is the AAB's SHA-256 as reported by Play, never just the version code.

No network: the Play API client is a fake with the same surface as PlayClient.
"""

import hashlib
import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

_spec = importlib.util.spec_from_file_location(
    "play_release_preflight", REPO / "tool" / "play_release_preflight.py"
)
assert _spec is not None and _spec.loader is not None
prp = importlib.util.module_from_spec(_spec)
sys.modules[_spec.name] = prp
_spec.loader.exec_module(prp)

N = 24
OURS = "ab" * 32
OTHER = "cd" * 32


def state(*, bundles=None, internal=(), other=()):
    """Build a PlayState. `internal` is (status, [codes]); `other` is (track, status, [codes])."""
    releases = [prp.TrackRelease("internal", s, tuple(c)) for s, c in internal]
    releases += [prp.TrackRelease(t, s, tuple(c)) for t, s, c in other]
    return prp.PlayState(bundles=dict(bundles or {}), releases=tuple(releases))


class DecideTest(unittest.TestCase):
    def test_absent_uploads(self):
        self.assertEqual(prp.decide(state(), N, OURS), "upload")

    def test_absent_with_older_codes_uploads(self):
        s = state(bundles={N - 1: OTHER}, internal=[("completed", [N - 1])])
        self.assertEqual(prp.decide(s, N, OURS), "upload")

    def test_absent_but_not_above_highest_known_code_conflicts(self):
        s = state(bundles={N + 1: OTHER}, internal=[("completed", [N + 1])])
        self.assertEqual(prp.decide(s, N, OURS), "conflict")

    def test_bundle_only_with_matching_sha_assigns(self):
        self.assertEqual(prp.decide(state(bundles={N: OURS}), N, OURS), "assign")

    def test_bundle_only_sha_comparison_ignores_case(self):
        self.assertEqual(prp.decide(state(bundles={N: OURS.upper()}), N, OURS), "assign")

    def test_bundle_only_with_other_sha_conflicts(self):
        self.assertEqual(prp.decide(state(bundles={N: OTHER}), N, OURS), "conflict")

    def test_completed_on_internal_with_matching_sha_skips(self):
        s = state(bundles={N: OURS}, internal=[("completed", [N])])
        self.assertEqual(prp.decide(s, N, OURS), "skip")

    def test_completed_on_internal_with_other_sha_conflicts(self):
        s = state(bundles={N: OTHER}, internal=[("completed", [N])])
        self.assertEqual(prp.decide(s, N, OURS), "conflict")

    def test_completed_on_internal_without_a_reported_sha_conflicts(self):
        # Identity cannot be proven, so it is not ours.
        s = state(internal=[("completed", [N])])
        self.assertEqual(prp.decide(s, N, OURS), "conflict")

    def test_draft_on_internal_with_matching_sha_assigns(self):
        s = state(bundles={N: OURS}, internal=[("draft", [N])])
        self.assertEqual(prp.decide(s, N, OURS), "assign")

    def test_draft_on_internal_with_other_sha_conflicts(self):
        s = state(bundles={N: OTHER}, internal=[("draft", [N])])
        self.assertEqual(prp.decide(s, N, OURS), "conflict")

    def test_halted_on_internal_conflicts_even_with_matching_sha(self):
        s = state(bundles={N: OURS}, internal=[("halted", [N])])
        self.assertEqual(prp.decide(s, N, OURS), "conflict")

    def test_used_by_another_track_conflicts_even_with_matching_sha(self):
        s = state(bundles={N: OURS}, other=[("production", "completed", [N])])
        self.assertEqual(prp.decide(s, N, OURS), "conflict")

    def test_assign_would_not_downgrade_the_internal_track(self):
        s = state(bundles={N: OURS, N + 1: OTHER}, internal=[("completed", [N + 1])])
        self.assertEqual(prp.decide(s, N, OURS), "conflict")

    def test_every_outcome_carries_a_reason(self):
        for st, want in (
            (state(), "upload"),
            (state(bundles={N: OURS}), "assign"),
            (state(bundles={N: OURS}, internal=[("completed", [N])]), "skip"),
            (state(bundles={N: OTHER}), "conflict"),
        ):
            with self.subTest(want=want):
                d = prp.decide_detailed(st, N, OURS)
                self.assertEqual(d.action, want)
                self.assertTrue(d.reason)

    def test_conflict_reason_names_both_hashes(self):
        d = prp.decide_detailed(state(bundles={N: OTHER}), N, OURS)
        self.assertIn(OTHER, d.reason)
        self.assertIn(OURS, d.reason)


class PrecheckTest(unittest.TestCase):
    """Before the build there is no AAB hash, so only hash-independent facts."""

    def test_clean_state_is_ok(self):
        self.assertEqual(prp.precheck(state(bundles={N - 1: OTHER}), N).action, "ok")

    def test_existing_bundle_is_ok_because_identity_is_checked_after_the_build(self):
        # A resumed release legitimately finds its own bundle already there.
        self.assertEqual(prp.precheck(state(bundles={N: OURS}), N).action, "ok")

    def test_absent_and_not_above_highest_conflicts(self):
        self.assertEqual(prp.precheck(state(bundles={N + 3: OTHER}), N).action, "conflict")

    def test_used_by_another_track_conflicts(self):
        s = state(other=[("production", "completed", [N])])
        self.assertEqual(prp.precheck(s, N).action, "conflict")


class ParseStateTest(unittest.TestCase):
    def test_parses_api_shaped_payloads(self):
        bundles = {
            "bundles": [
                {"versionCode": 23, "sha256": OTHER.upper()},
                {"versionCode": "24", "sha256": OURS},
            ]
        }
        tracks = {
            "tracks": [
                {"track": "internal", "releases": [{"status": "completed", "versionCodes": ["23"]}]},
                {"track": "production", "releases": [{"status": "completed", "versionCodes": ["20", "21"]}]},
            ]
        }
        s = prp.parse_state(bundles, tracks)
        self.assertEqual(s.bundles, {23: OTHER, 24: OURS})
        self.assertIn(prp.TrackRelease("internal", "completed", (23,)), s.releases)
        self.assertIn(prp.TrackRelease("production", "completed", (20, 21)), s.releases)

    def test_empty_payloads_are_an_empty_state(self):
        s = prp.parse_state({}, {})
        self.assertEqual((s.bundles, s.releases), ({}, ()))


class FakeClient:
    """Same surface as PlayClient; records every call.

    `states` is the Play state seen by each successive edit (the last repeats).
    """

    def __init__(self, states, commit_error=None):
        self.states = list(states)
        self.commit_error = commit_error
        self.calls = []
        self._edits = 0

    def _current(self):
        return self.states[min(self._edits, len(self.states)) - 1]

    def insert_edit(self):
        self._edits += 1
        self.calls.append(("insert_edit",))
        return f"edit{self._edits}"

    def bundles(self, edit_id):
        self.calls.append(("bundles", edit_id))
        st = self._current()
        return {"bundles": [{"versionCode": c, "sha256": h} for c, h in st.bundles.items()]}

    def tracks(self, edit_id):
        self.calls.append(("tracks", edit_id))
        by_track = {}
        for r in self._current().releases:
            by_track.setdefault(r.track, []).append(
                {"status": r.status, "versionCodes": [str(c) for c in r.version_codes]}
            )
        return {"tracks": [{"track": t, "releases": rel} for t, rel in by_track.items()]}

    def update_track(self, edit_id, track, body):
        self.calls.append(("update_track", edit_id, track, body))

    def commit(self, edit_id):
        self.calls.append(("commit", edit_id))
        if self.commit_error:
            raise self.commit_error

    def delete_edit(self, edit_id):
        self.calls.append(("delete_edit", edit_id))


NOTES = [{"language": "en-US", "text": "What's new"}]


class ResolveAfterConflictTest(unittest.TestCase):
    def test_returns_skip_when_play_now_shows_our_release_completed(self):
        done = state(bundles={N: OURS}, internal=[("completed", [N])])
        self.assertEqual(prp.resolve_after_api_conflict(lambda: done, N, OURS), "skip")

    def test_raises_when_play_shows_a_different_artifact(self):
        other = state(bundles={N: OTHER}, internal=[("completed", [N])])
        with self.assertRaises(prp.PlayStateError):
            prp.resolve_after_api_conflict(lambda: other, N, OURS)

    def test_raises_when_the_release_never_landed(self):
        with self.assertRaises(prp.PlayStateError):
            prp.resolve_after_api_conflict(lambda: state(bundles={N: OURS}), N, OURS)

    def test_requeries_exactly_once(self):
        calls = []

        def fetch():
            calls.append(1)
            return state(bundles={N: OURS}, internal=[("completed", [N])])

        prp.resolve_after_api_conflict(fetch, N, OURS)
        self.assertEqual(len(calls), 1)


class AssignBundleTest(unittest.TestCase):
    def test_assigns_and_completes_in_one_committed_edit(self):
        client = FakeClient([state(bundles={N: OURS})])
        got = prp.assign_bundle(client, version_code=N, aab_sha256=OURS, release_notes=NOTES)
        self.assertEqual(got, "assigned")
        edits = {c[1] for c in client.calls if c[0] in ("update_track", "commit")}
        self.assertEqual(len(edits), 1, "assignment and commit must share ONE edit")
        updates = [c for c in client.calls if c[0] == "update_track"]
        self.assertEqual(len(updates), 1)
        _, _, track, body = updates[0]
        self.assertEqual(track, "internal")
        self.assertEqual(
            body["releases"],
            [{"status": "completed", "versionCodes": [str(N)], "releaseNotes": NOTES}],
        )
        self.assertEqual([c for c in client.calls if c[0] == "commit"], [("commit", "edit1")])

    def test_does_not_assign_a_bundle_whose_sha_differs(self):
        client = FakeClient([state(bundles={N: OTHER})])
        with self.assertRaises(prp.PlayStateError):
            prp.assign_bundle(client, version_code=N, aab_sha256=OURS, release_notes=NOTES)
        self.assertEqual([c for c in client.calls if c[0] in ("update_track", "commit")], [])

    def test_api_conflict_then_requery_shows_it_completed_is_success(self):
        done = state(bundles={N: OURS}, internal=[("completed", [N])])
        client = FakeClient(
            [state(bundles={N: OURS}), done],
            commit_error=prp.PlayApiError(409, "edit conflict"),
        )
        got = prp.assign_bundle(client, version_code=N, aab_sha256=OURS, release_notes=NOTES)
        self.assertEqual(got, "reconciled")

    def test_api_conflict_and_requery_shows_nothing_landed_is_failure(self):
        client = FakeClient(
            [state(bundles={N: OURS})], commit_error=prp.PlayApiError(409, "edit conflict")
        )
        with self.assertRaises(prp.PlayStateError):
            prp.assign_bundle(client, version_code=N, aab_sha256=OURS, release_notes=NOTES)


class Sha256Test(unittest.TestCase):
    def test_matches_hashlib_over_the_file_bytes(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp, "a.aab")
            p.write_bytes(b"bundle-bytes" * 1000)
            self.assertEqual(prp.sha256_file(p), hashlib.sha256(b"bundle-bytes" * 1000).hexdigest())


class FetchStateTest(unittest.TestCase):
    def test_reads_state_in_a_throwaway_edit_and_deletes_it(self):
        client = FakeClient([state(bundles={N: OURS}, internal=[("completed", [N])])])
        got = prp.fetch_state(client)
        self.assertEqual(got.bundles, {N: OURS})
        kinds = [c[0] for c in client.calls]
        self.assertEqual(kinds[0], "insert_edit")
        self.assertEqual(kinds[-1], "delete_edit")
        self.assertNotIn("commit", kinds)
        self.assertNotIn("update_track", kinds)


class ReleaseNotesTest(unittest.TestCase):
    def test_reads_one_note_per_locale_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            Path(tmp, "whatsnew-en-US").write_text("Hello\n")
            Path(tmp, "whatsnew-ur").write_text("Salaam\n")
            self.assertEqual(
                prp.load_release_notes(Path(tmp)),
                [{"language": "en-US", "text": "Hello"}, {"language": "ur", "text": "Salaam"}],
            )

    def test_no_notes_is_an_error_not_an_empty_release(self):
        with tempfile.TemporaryDirectory() as tmp, self.assertRaises(prp.PlayStateError):
            prp.load_release_notes(Path(tmp))


class RunnersTest(unittest.TestCase):
    def setUp(self):
        import contextlib
        import io

        stack = contextlib.ExitStack()
        stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
        self.addCleanup(stack.close)

    def test_decide_writes_the_action_to_github_output(self):
        client = FakeClient([state(bundles={N: OURS})])
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp, "out")
            rc = prp.run_decide(client, version_code=N, aab_sha256=OURS, github_output=out)
            self.assertEqual(rc, 0)
            self.assertIn("action=assign", out.read_text())

    def test_decide_exits_nonzero_on_conflict(self):
        client = FakeClient([state(bundles={N: OTHER})])
        rc = prp.run_decide(client, version_code=N, aab_sha256=OURS, github_output=None)
        self.assertEqual(rc, 1)

    def test_decide_never_writes_to_play(self):
        client = FakeClient([state()])
        prp.run_decide(client, version_code=N, aab_sha256=OURS, github_output=None)
        kinds = {c[0] for c in client.calls}
        self.assertTrue(kinds.isdisjoint({"update_track", "commit"}))

    def test_verify_requires_our_artifact_completed_on_internal(self):
        done = state(bundles={N: OURS}, internal=[("completed", [N])])
        self.assertEqual(prp.run_verify(FakeClient([done]), version_code=N, aab_sha256=OURS), 0)
        bundle_only = state(bundles={N: OURS})
        self.assertEqual(prp.run_verify(FakeClient([bundle_only]), version_code=N, aab_sha256=OURS), 1)
        wrong = state(bundles={N: OTHER}, internal=[("completed", [N])])
        self.assertEqual(prp.run_verify(FakeClient([wrong]), version_code=N, aab_sha256=OURS), 1)

    def test_snapshot_fails_only_on_hash_independent_conflicts(self):
        self.assertEqual(prp.run_snapshot(FakeClient([state(bundles={N - 1: OTHER})]), version_code=N), 0)
        self.assertEqual(prp.run_snapshot(FakeClient([state(bundles={N + 1: OTHER})]), version_code=N), 1)


if __name__ == "__main__":
    unittest.main()
