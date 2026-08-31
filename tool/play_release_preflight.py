#!/usr/bin/env python3
"""Fail fast before a Play upload can burn a doomed version code.

A versionCode Play has seen can never be reused, so every check that can be
made from the manifest and the Play API belongs BEFORE the upload rather
than in a rejection email afterwards.

Ported from the sibling alquran-app pipeline; the JWT/androidpublisher
plumbing below is unchanged. Al-Tawheed declares
FOREGROUND_SERVICE_MEDIA_PLAYBACK (audio playback) but not USE_EXACT_ALARM,
so only the foreground-service declaration gate is carried over.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any


ANDROID_NS = "{http://schemas.android.com/apk/res/android}"
ANDROID_PUBLISHER_SCOPE = "https://www.googleapis.com/auth/androidpublisher"


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


def api_request(token: str, method: str, url: str) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        data=b"{}" if method == "POST" else None,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        method=method,
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.loads(response.read().decode() or "{}")
    except urllib.error.HTTPError as error:
        body = error.read().decode()
        raise RuntimeError(f"{method} {url} failed with HTTP {error.code}: {body}") from error


def create_edit(token: str, package_name: str) -> str:
    url = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{package_name}/edits"
    payload = api_request(token, "POST", url)
    return payload["id"]


def delete_edit(token: str, package_name: str, edit_id: str) -> None:
    url = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{package_name}/edits/{edit_id}"
    api_request(token, "DELETE", url)


def listed_version_codes(token: str, package_name: str) -> set[int]:
    edit_id = create_edit(token, package_name)
    try:
        base = (
            "https://androidpublisher.googleapis.com/androidpublisher/v3/"
            f"applications/{package_name}/edits/{edit_id}"
        )
        bundles = api_request(token, "GET", f"{base}/bundles").get("bundles", [])
        bundle_codes = {int(bundle["versionCode"]) for bundle in bundles if "versionCode" in bundle}

        tracks = api_request(token, "GET", f"{base}/tracks").get("tracks", [])
        track_codes: set[int] = set()
        for track in tracks:
            for release in track.get("releases", []):
                track_codes.update(int(code) for code in release.get("versionCodes", []))
        return bundle_codes | track_codes
    finally:
        delete_edit(token, package_name, edit_id)


def manifest_permissions(manifest: Path) -> set[str]:
    tree = ET.parse(manifest)
    permissions: set[str] = set()
    for element in tree.getroot().findall("uses-permission"):
        name = element.attrib.get(f"{ANDROID_NS}name")
        if name:
            permissions.add(name)
    return permissions


def version_code_from_pubspec(pubspec: Path) -> int:
    match = re.search(r"^version:\s+\d+\.\d+\.\d+\+(\d+)\s*$", pubspec.read_text(), re.MULTILINE)
    if not match:
        raise RuntimeError(f"Could not read Flutter build number from {pubspec}")
    return int(match.group(1))


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


def require_unused_version_code(package_name: str, version_code: int) -> None:
    service_account = os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT", "")
    if not service_account.strip():
        print("Play version-code preflight: GOOGLE_PLAY_SERVICE_ACCOUNT is absent; skipping.")
        return

    token = access_token(service_account)
    used = listed_version_codes(token, package_name)
    if not used:
        print(f"Play version-code preflight: no existing bundle version codes found; target={version_code}.")
        return

    max_used = max(used)
    if version_code in used or version_code <= max_used:
        raise RuntimeError(
            f"Version code {version_code} is not publishable. Play already knows about "
            f"{sorted(used)}; highest is {max_used}. Bump pubspec.yaml to a build number "
            f"greater than {max_used} before uploading."
        )
    print(f"Play version-code preflight: target={version_code}, highest known={max_used}.")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--package-name", default="com.almarfa.tawheed")
    parser.add_argument("--manifest", default="android/app/src/main/AndroidManifest.xml", type=Path)
    parser.add_argument("--pubspec", default="pubspec.yaml", type=Path)
    args = parser.parse_args()

    require_foreground_service_media_declaration(args.manifest)
    require_unused_version_code(args.package_name, version_code_from_pubspec(args.pubspec))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as error:
        print(f"::error::{error}")
        raise SystemExit(1)
