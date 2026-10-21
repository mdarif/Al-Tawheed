#!/usr/bin/env python3
"""Play Store gate for the release workflow: read Play, decide, act, verify.

A versionCode Play has seen can never be reused, so everything that can be
decided from Play's own state is decided BEFORE anything is written, and what
was written is proven afterwards.

The decision is a pure function over a snapshot of Play state:

    decide(play_state, version_code, aab_sha256) -> upload | assign | skip | conflict

Play state keeps "a bundle was uploaded" (edits.bundles) separate from "a
release is on a track" (edits.tracks). A bundle-only or already-completed
versionCode is treated as OURS only when the SHA-256 Play reports for it equals
the SHA-256 of the AAB this workflow built; anything else is a conflict, because
a versionCode match alone does not prove it is the same artifact.

Subcommands (all but `manifest` talk to Play; only `assign` writes, and the
upload itself is done by r0adkll/upload-google-play in the workflow):

    manifest   FOREGROUND_SERVICE_MEDIA_PLAYBACK declaration gate (no network)
    snapshot   read-only, hash-independent pre-build check (used by `prepare`)
    decide     read-only; prints/exports upload | assign | skip, fails on conflict
    assign     assign an already-uploaded bundle to the track, ONE committed edit
    verify     fail unless our exact AAB is `completed` on the internal track

Ported from the sibling alquran-app pipeline; the JWT plumbing is unchanged.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable, Mapping, NamedTuple

ANDROID_NS = "{http://schemas.android.com/apk/res/android}"
ANDROID_PUBLISHER_SCOPE = "https://www.googleapis.com/auth/androidpublisher"
API_BASE = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
INTERNAL = "internal"


# --------------------------------------------------------------------------- #
# Errors
# --------------------------------------------------------------------------- #
class PlayApiError(RuntimeError):
    """A Play API call failed. `status` is the HTTP status (0 if none)."""

    def __init__(self, status: int, body: str):
        super().__init__(f"Play API call failed with HTTP {status}: {body}")
        self.status = status
        self.body = body


class PlayStateError(RuntimeError):
    """Play's state is not what the release needs (conflict or not landed)."""


# --------------------------------------------------------------------------- #
# Pure model + decision
# --------------------------------------------------------------------------- #
@dataclass(frozen=True)
class TrackRelease:
    track: str
    status: str
    version_codes: tuple[int, ...]


@dataclass(frozen=True)
class PlayState:
    """`bundles`: versionCode -> SHA-256 Play reports. `releases`: per-track."""

    bundles: Mapping[int, str]
    releases: tuple[TrackRelease, ...]


class Decision(NamedTuple):
    action: str
    reason: str


def _norm(sha: str | None) -> str | None:
    return sha.strip().lower() if sha else None


def _all_codes(state: PlayState) -> set[int]:
    codes = set(state.bundles)
    for release in state.releases:
        codes.update(release.version_codes)
    return codes


def parse_state(bundles_payload: Mapping[str, Any], tracks_payload: Mapping[str, Any]) -> PlayState:
    """Build a PlayState from the edits.bundles.list / edits.tracks.list JSON."""
    bundles: dict[int, str] = {}
    for bundle in bundles_payload.get("bundles", []) or []:
        if "versionCode" in bundle:
            bundles[int(bundle["versionCode"])] = _norm(bundle.get("sha256")) or ""
    releases: list[TrackRelease] = []
    for track in tracks_payload.get("tracks", []) or []:
        for release in track.get("releases", []) or []:
            codes = tuple(int(c) for c in release.get("versionCodes", []) or [])
            releases.append(TrackRelease(track["track"], release.get("status", ""), codes))
    return PlayState(bundles=bundles, releases=tuple(releases))


def _internal_has_newer(state: PlayState, version_code: int) -> bool:
    return any(
        r.track == INTERNAL and any(c > version_code for c in r.version_codes)
        for r in state.releases
    )


def decide_detailed(state: PlayState, version_code: int, aab_sha256: str) -> Decision:
    ours = _norm(aab_sha256)
    reported = _norm(state.bundles.get(version_code))

    elsewhere = sorted(
        {r.track for r in state.releases if r.track != INTERNAL and version_code in r.version_codes}
    )
    if elsewhere:
        return Decision(
            "conflict",
            f"versionCode {version_code} is already used on track(s) {elsewhere}; "
            "this pipeline only ever releases to the internal track.",
        )

    on_internal = [r for r in state.releases if r.track == INTERNAL and version_code in r.version_codes]
    if on_internal or reported is not None:
        # The code is known to Play; it is ours only if the artifact is.
        if reported is None:
            return Decision(
                "conflict",
                f"versionCode {version_code} is on the {INTERNAL} track but Play reports no "
                "bundle SHA-256 for it, so it cannot be proven to be this build.",
            )
        if reported != ours:
            return Decision(
                "conflict",
                f"versionCode {version_code} exists on Play with SHA-256 {reported}, but this "
                f"workflow built SHA-256 {ours}. It is a different artifact; bump the build number.",
            )
        statuses = {r.status for r in on_internal}
        if "completed" in statuses:
            return Decision("skip", f"versionCode {version_code} is already completed on {INTERNAL} (same SHA-256).")
        if on_internal and statuses != {"draft"}:
            return Decision(
                "conflict",
                f"versionCode {version_code} is on {INTERNAL} with status {sorted(statuses)}, "
                "which this pipeline will not overwrite.",
            )
        if _internal_has_newer(state, version_code):
            return Decision(
                "conflict",
                f"the {INTERNAL} track already carries a higher versionCode than {version_code}; "
                "assigning this one would downgrade it.",
            )
        return Decision(
            "assign",
            f"bundle {version_code} is uploaded (same SHA-256) but not completed on {INTERNAL}; assigning it.",
        )

    known = _all_codes(state)
    if known and version_code <= max(known):
        return Decision(
            "conflict",
            f"versionCode {version_code} is not above the highest code Play knows ({max(known)}); "
            "Play would reject the upload. Raise the build number.",
        )
    return Decision("upload", f"versionCode {version_code} is new to Play; uploading.")


def decide(state: PlayState, version_code: int, aab_sha256: str) -> str:
    return decide_detailed(state, version_code, aab_sha256).action


def precheck(state: PlayState, version_code: int) -> Decision:
    """Hash-independent pre-build check: fail early on what no artifact can fix.

    A versionCode already on Play is fine here: a resumed release legitimately
    finds its own bundle, and whether it IS ours is decided after the build.
    """
    if any(r.track != INTERNAL and version_code in r.version_codes for r in state.releases):
        return Decision("conflict", f"versionCode {version_code} is already used on another track.")
    known = _all_codes(state)
    if version_code not in known and known and version_code <= max(known):
        return Decision(
            "conflict",
            f"versionCode {version_code} is not above the highest code Play knows ({max(known)}).",
        )
    return Decision("ok", f"versionCode {version_code} is not blocked by Play state.")


def resolve_after_api_conflict(
    fetch_state: Callable[[], PlayState], version_code: int, aab_sha256: str
) -> str:
    """After a write error, re-query Play ONCE before deciding success or failure.

    The write may have committed despite the error (timeout, 409 on a retry).
    Success only if our exact artifact is now completed on the track.
    """
    decision = decide_detailed(fetch_state(), version_code, aab_sha256)
    if decision.action == "skip":
        return "skip"
    raise PlayStateError(f"after the API error Play shows '{decision.action}': {decision.reason}")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


# --------------------------------------------------------------------------- #
# Thin, mockable Play API surface
# --------------------------------------------------------------------------- #
def base64url(data: bytes) -> bytes:
    return base64.urlsafe_b64encode(data).rstrip(b"=")


def sign_rs256(unsigned_jwt: bytes, private_key: str) -> bytes:
    with tempfile.NamedTemporaryFile("w", delete=False) as key_file:
        key_file.write(private_key)
        key_path = key_file.name
    try:
        result = subprocess.run(
            ("openssl", "dgst", "-sha256", "-sign", key_path),
            input=unsigned_jwt,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        return result.stdout
    finally:
        Path(key_path).unlink(missing_ok=True)


def access_token(service_account_json: str) -> str:
    account = json.loads(service_account_json)
    now = int(time.time())
    header = {"alg": "RS256", "typ": "JWT"}
    claims = {
        "iss": account["client_email"],
        "scope": ANDROID_PUBLISHER_SCOPE,
        "aud": "https://oauth2.googleapis.com/token",
        "iat": now,
        "exp": now + 3600,
    }
    unsigned = b".".join(
        (
            base64url(json.dumps(header, separators=(",", ":")).encode()),
            base64url(json.dumps(claims, separators=(",", ":")).encode()),
        )
    )
    signature = sign_rs256(unsigned, account["private_key"])
    assertion = b".".join((unsigned, base64url(signature))).decode()
    body = urllib.parse.urlencode(
        {
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": assertion,
        }
    ).encode()
    request = urllib.request.Request(
        "https://oauth2.googleapis.com/token",
        data=body,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        payload = json.loads(response.read().decode())
    return payload["access_token"]


def api_request(token: str, method: str, url: str, body: Mapping[str, Any] | None = None) -> dict[str, Any]:
    data = json.dumps(body).encode() if body is not None else (b"{}" if method == "POST" else None)
    request = urllib.request.Request(
        url,
        data=data,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        method=method,
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.loads(response.read().decode() or "{}")
    except urllib.error.HTTPError as error:
        raise PlayApiError(error.code, error.read().decode()) from error
    except urllib.error.URLError as error:
        raise PlayApiError(0, str(error.reason)) from error


class PlayClient:
    """The only code that speaks HTTP to Play. Tests substitute a fake."""

    def __init__(self, token: str, package_name: str):
        self._token = token
        self._base = f"{API_BASE}/{package_name}/edits"

    def insert_edit(self) -> str:
        return api_request(self._token, "POST", self._base)["id"]

    def delete_edit(self, edit_id: str) -> None:
        api_request(self._token, "DELETE", f"{self._base}/{edit_id}")

    def bundles(self, edit_id: str) -> dict[str, Any]:
        return api_request(self._token, "GET", f"{self._base}/{edit_id}/bundles")

    def tracks(self, edit_id: str) -> dict[str, Any]:
        return api_request(self._token, "GET", f"{self._base}/{edit_id}/tracks")

    def update_track(self, edit_id: str, track: str, body: Mapping[str, Any]) -> None:
        api_request(self._token, "PUT", f"{self._base}/{edit_id}/tracks/{track}", body)

    def commit(self, edit_id: str) -> None:
        api_request(self._token, "POST", f"{self._base}/{edit_id}:commit")


def _delete_quietly(client: Any, edit_id: str) -> None:
    try:
        client.delete_edit(edit_id)
    except PlayApiError:
        pass


def fetch_state(client: Any) -> PlayState:
    """Read Play state in a throwaway edit (never committed, always deleted)."""
    edit_id = client.insert_edit()
    try:
        return parse_state(client.bundles(edit_id), client.tracks(edit_id))
    finally:
        _delete_quietly(client, edit_id)


def assign_bundle(
    client: Any,
    *,
    version_code: int,
    aab_sha256: str,
    release_notes: list[dict[str, str]],
    track: str = INTERNAL,
) -> str:
    """Assign an already-uploaded bundle to `track` and complete it: ONE edit.

    Re-checks Play inside the same edit that is committed, so the decision and
    the write see the same state. Returns "assigned", "skipped" (it was already
    completed) or "reconciled" (an API error, but a re-query shows our release
    completed). Raises PlayStateError otherwise.
    """
    edit_id = client.insert_edit()
    committed = False
    try:
        state = parse_state(client.bundles(edit_id), client.tracks(edit_id))
        decision = decide_detailed(state, version_code, aab_sha256)
        if decision.action == "skip":
            return "skipped"
        if decision.action != "assign":
            raise PlayStateError(f"cannot assign: Play says '{decision.action}': {decision.reason}")
        client.update_track(
            edit_id,
            track,
            {
                "track": track,
                "releases": [
                    {
                        "status": "completed",
                        "versionCodes": [str(version_code)],
                        "releaseNotes": release_notes,
                    }
                ],
            },
        )
        client.commit(edit_id)
        committed = True
        return "assigned"
    except PlayApiError as error:
        try:
            resolve_after_api_conflict(lambda: fetch_state(client), version_code, aab_sha256)
        except PlayStateError as state_error:
            raise PlayStateError(f"{error}; {state_error}") from error
        return "reconciled"
    finally:
        if not committed:
            _delete_quietly(client, edit_id)


def load_release_notes(directory: Path) -> list[dict[str, str]]:
    """Read `whatsnew-<locale>` files (the r0adkll layout) into Play releaseNotes."""
    notes = []
    for path in sorted(directory.glob("whatsnew-*")):
        notes.append({"language": path.name[len("whatsnew-"):], "text": path.read_text().strip()})
    if not notes:
        raise PlayStateError(f"no whatsnew-<locale> files in {directory}")
    return notes


# --------------------------------------------------------------------------- #
# Subcommand runners (take a client, so they are testable)
# --------------------------------------------------------------------------- #
def _write_output(github_output: Path | None, key: str, value: str) -> None:
    if github_output:
        with github_output.open("a", encoding="utf-8") as handle:
            handle.write(f"{key}={value}\n")


def run_snapshot(client: Any, *, version_code: int) -> int:
    state = fetch_state(client)
    internal = [r for r in state.releases if r.track == INTERNAL]
    print(f"Play snapshot: bundles={sorted(state.bundles)} internal={[(r.status, list(r.version_codes)) for r in internal]}")
    decision = precheck(state, version_code)
    print(f"Play snapshot: {decision.action} - {decision.reason}")
    return 0 if decision.action == "ok" else 1


def run_decide(client: Any, *, version_code: int, aab_sha256: str, github_output: Path | None) -> int:
    decision = decide_detailed(fetch_state(client), version_code, aab_sha256)
    print(f"Play decision for versionCode {version_code}: {decision.action} - {decision.reason}")
    _write_output(github_output, "action", decision.action)
    return 1 if decision.action == "conflict" else 0


def run_verify(client: Any, *, version_code: int, aab_sha256: str) -> int:
    decision = decide_detailed(fetch_state(client), version_code, aab_sha256)
    if decision.action == "skip":
        print(f"Play verified: {decision.reason}")
        return 0
    print(f"::error::Play does not show this release as completed on {INTERNAL}: {decision.action} - {decision.reason}")
    return 1


# --------------------------------------------------------------------------- #
# Manifest gate (no network)
# --------------------------------------------------------------------------- #
def manifest_permissions(manifest: Path) -> set[str]:
    tree = ET.parse(manifest)
    permissions: set[str] = set()
    for element in tree.getroot().findall("uses-permission"):
        name = element.attrib.get(f"{ANDROID_NS}name")
        if name:
            permissions.add(name)
    return permissions


def require_foreground_service_media_declaration(manifest: Path) -> None:
    """Play stops an upload declaring FGS media until the console form is filled."""
    permissions = manifest_permissions(manifest)
    if "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" not in permissions:
        print("Foreground service preflight: FOREGROUND_SERVICE_MEDIA_PLAYBACK not declared.")
        return

    declared = os.environ.get("PLAY_FGS_MEDIA_DECLARED", "").strip().lower()
    if declared == "bootstrap":
        print(
            "::warning::Foreground service preflight: bootstrap mode enabled. "
            "This upload may be stopped by Play so the foreground-service "
            "permissions declaration form can be completed. After the "
            "declaration is accepted, set PLAY_FGS_MEDIA_DECLARED=true."
        )
        return

    if declared not in {"1", "true", "yes"}:
        raise RuntimeError(
            "AndroidManifest.xml declares FOREGROUND_SERVICE_MEDIA_PLAYBACK, but "
            "PLAY_FGS_MEDIA_DECLARED is not true. If Play Console is not showing "
            "the declaration form yet (App content -> Permissions declaration -> "
            "Foreground service permissions), set PLAY_FGS_MEDIA_DECLARED=bootstrap "
            "for one release attempt so Play can surface the form. After the "
            "declaration is accepted, set the repository secret "
            "PLAY_FGS_MEDIA_DECLARED=true. Refusing to upload an AAB that Play "
            "will reject after burning its version code."
        )
    print("Foreground service preflight: declaration flag is present.")


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
def _client(package_name: str) -> PlayClient:
    service_account = os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT", "")
    if not service_account.strip():
        raise RuntimeError("GOOGLE_PLAY_SERVICE_ACCOUNT is not set.")
    return PlayClient(access_token(service_account), package_name)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    def common(p: argparse.ArgumentParser, *, aab: bool) -> None:
        p.add_argument("--package-name", default="com.almarfa.tawheed")
        p.add_argument("--version-code", type=int, required=True)
        if aab:
            p.add_argument("--aab", type=Path, required=True)

    p_manifest = sub.add_parser("manifest", help="FGS media declaration gate (no network)")
    p_manifest.add_argument("--manifest", type=Path, default=Path("android/app/src/main/AndroidManifest.xml"))

    p_snapshot = sub.add_parser("snapshot", help="read-only hash-independent pre-build check")
    common(p_snapshot, aab=False)
    p_snapshot.add_argument(
        "--optional", action="store_true", help="skip (exit 0) when no service account is configured"
    )

    p_decide = sub.add_parser("decide", help="read-only: upload | assign | skip (fails on conflict)")
    common(p_decide, aab=True)
    p_decide.add_argument("--github-output", type=Path)

    p_assign = sub.add_parser("assign", help="assign an uploaded bundle to the internal track (one edit)")
    common(p_assign, aab=True)
    p_assign.add_argument("--notes-dir", type=Path, required=True)

    p_verify = sub.add_parser("verify", help="fail unless our exact AAB is completed on internal")
    common(p_verify, aab=True)

    args = parser.parse_args(argv)

    if args.command == "manifest":
        require_foreground_service_media_declaration(args.manifest)
        return 0

    if args.command == "snapshot" and args.optional and not os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT", "").strip():
        print("Play snapshot: no service account configured; skipping (dry run).")
        return 0

    client = _client(args.package_name)
    if args.command == "snapshot":
        return run_snapshot(client, version_code=args.version_code)

    sha = sha256_file(args.aab)
    print(f"AAB SHA-256: {sha}")
    if args.command == "decide":
        return run_decide(client, version_code=args.version_code, aab_sha256=sha, github_output=args.github_output)
    if args.command == "verify":
        return run_verify(client, version_code=args.version_code, aab_sha256=sha)
    outcome = assign_bundle(
        client,
        version_code=args.version_code,
        aab_sha256=sha,
        release_notes=load_release_notes(args.notes_dir),
    )
    print(f"Play assign: {outcome}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as error:
        print(f"::error::{error}")
        raise SystemExit(1)
