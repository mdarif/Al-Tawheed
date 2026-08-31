#!/usr/bin/env python3
"""Inspect and smoke-test the production-signed APK the release build produced.

Debug-mode CI proves nothing about a release build: R8, resource shrinking and
asset packaging only run for `--release`, and the signed artifact this repo
ships to the Play Store has, until now, never been installed by any machine
before users get it. This runs two independent checks:

  --inspect-only   Deterministic, no device. Asserts the bundled book content
                   and Arabic/Urdu fonts survived packaging byte-for-byte, and
                   that the APK is signed with a real key rather than the debug
                   key Gradle silently falls back to when key.properties is
                   missing.

  --device SERIAL  Installs the APK on an emulator/device, launches it, waits
                   for the first frame, backgrounds and resumes it, then fails
                   on any crash in logcat. Screenshot + logcat are written to
                   the evidence directory whether or not it passes — evidence
                   only for green runs would be evidence for the runs that
                   need none.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import time
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]

PACKAGE = "com.almarfa.tawheed"
ACTIVITY = f"{PACKAGE}/.MainActivity"

# Flutter bundles declared assets at a stable path, so these can be checked by
# name AND by content hash against the source tree.
ASSET_PREFIX = "assets/flutter_assets/"
CONTENT_ASSETS = (
    "assets/content/book_tawheed-ar.json",
    "assets/content/book_tawheed-ur.json",
)
FONT_ASSETS = (
    "assets/fonts/NotoNaskhArabic-Regular.ttf",
    "assets/fonts/NotoNastaliqUrdu-Regular.ttf",
)
REQUIRED_ASSETS = CONTENT_ASSETS + FONT_ASSETS

# Gradle falls back to the debug signing config when android/key.properties is
# absent, producing an APK that installs fine locally and is rejected by Play.
DEBUG_SIGNER_MARKERS = ("CN=Android Debug", "O=Android, C=US")

LAUNCH_TIMEOUT_SECONDS = 90
FIRST_FRAME_PATTERN = re.compile(r"Displayed .*" + re.escape(PACKAGE))

# Pre-granted before launch. Without this the runtime permission dialog
# (GrantPermissionsActivity) sits on top of MainActivity on a fresh install, so
# the activity never logs "Displayed" and the launch looks like a hang — the
# app behind the dialog is perfectly healthy. Granting up front keeps this a
# test of the app, not of Android's permission UI.
PREGRANT_PERMISSIONS = ("android.permission.POST_NOTIFICATIONS",)


class VerificationError(RuntimeError):
    """The release artifact is not shippable."""


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def inspect_apk(apk: Path, repo: Path = REPO) -> None:
    """Assert release packaging preserved every asset the app cannot run without."""
    if not apk.is_file():
        raise VerificationError(f"APK does not exist: {apk}")

    with zipfile.ZipFile(apk) as archive:
        names = set(archive.namelist())
        missing = sorted(
            asset for asset in REQUIRED_ASSETS if f"{ASSET_PREFIX}{asset}" not in names
        )
        if missing:
            raise VerificationError(
                "APK is missing required asset(s): "
                + ", ".join(missing)
                + ". Asset shrinking or a pubspec.yaml `assets:` change is the usual cause."
            )

        for asset in REQUIRED_ASSETS:
            source = repo / asset
            if not source.is_file():
                raise VerificationError(f"Source asset is missing from the repo: {asset}")
            packaged = archive.read(f"{ASSET_PREFIX}{asset}")
            if _sha256(packaged) != _sha256(source.read_bytes()):
                raise VerificationError(
                    f"Packaged {asset} does not match the source bytes — the build "
                    "transformed or truncated it."
                )
            print(f"Asset intact: {asset} ({len(packaged)} bytes)")

        # The book is the product. A JSON asset that ships corrupt renders an
        # empty reader, which no unit test on the source tree would catch.
        for asset in CONTENT_ASSETS:
            try:
                chapters = json.loads(archive.read(f"{ASSET_PREFIX}{asset}").decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError) as error:
                raise VerificationError(f"Packaged {asset} is not valid JSON: {error}") from error
            if not chapters:
                raise VerificationError(f"Packaged {asset} decoded to an empty document.")
            print(f"Content parsed: {asset}")


def find_apksigner() -> str | None:
    """Locate apksigner, which is not on PATH on a stock GitHub runner.

    The Android SDK installs it under build-tools/<version>/, so fall back to
    globbing there before giving up.
    """
    from shutil import which

    found = which("apksigner")
    if found:
        return found
    for root_var in ("ANDROID_SDK_ROOT", "ANDROID_HOME"):
        root = os.environ.get(root_var)
        if not root:
            continue
        candidates = sorted((Path(root) / "build-tools").glob("*/apksigner"))
        if candidates:
            return str(candidates[-1])  # highest build-tools version
    return None


def verify_signature(apk: Path, *, required: bool) -> None:
    """Refuse an APK signed with the debug key.

    Gradle falls back to the debug signing config when key.properties is
    absent, producing an APK that installs fine locally and that Play rejects.
    In CI this check is REQUIRED: silently skipping it would retire the one
    guard that catches an unsigned release, which is exactly the failure a
    missing apksigner would accompany. Locally it degrades to a warning.
    """
    apksigner = find_apksigner()
    if apksigner is None:
        message = (
            "apksigner not found. Install Android build-tools or set "
            "ANDROID_SDK_ROOT so the debug-key guard can run."
        )
        if required:
            raise VerificationError(message)
        print(f"::warning::{message} Skipping signature check.", file=sys.stderr)
        return

    result = subprocess.run(
        (apksigner, "verify", "--print-certs", str(apk)),
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    if result.returncode != 0:
        # Could not RUN the check (no JRE, broken SDK) — distinct from the
        # check reporting a debug key. In CI that ambiguity is unacceptable;
        # locally it is just a missing tool.
        message = f"apksigner could not verify the APK:\n{result.stdout}"
        if required:
            raise VerificationError(message)
        print(f"::warning::{message}", file=sys.stderr)
        return
    if any(marker in result.stdout for marker in DEBUG_SIGNER_MARKERS):
        raise VerificationError(
            "APK is signed with the ANDROID DEBUG key. The release signing config did "
            "not apply — android/key.properties was missing or the keystore secrets "
            "were empty. Play will reject this."
        )
    print(f"Signature check: signed with a non-debug key ({apksigner}).")


def _adb(device: str, *args: str, check: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ("adb", "-s", device, *args),
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )


def smoke_test(*, apk: Path, device: str, evidence: Path) -> bool:
    """Install, launch, background and resume the real release APK."""
    evidence.mkdir(parents=True, exist_ok=True)
    ok = True

    print(f"Installing {apk.name} on {device}…")
    install = _adb(device, "install", "-r", "-d", str(apk))
    if "Success" not in install.stdout:
        print(f"::error::adb install failed:\n{install.stdout}", file=sys.stderr)
        return False

    for permission in PREGRANT_PERMISSIONS:
        granted = _adb(device, "shell", "pm", "grant", PACKAGE, permission)
        # Older API levels do not know the permission; that is not a failure.
        if granted.stdout.strip():
            print(f"pm grant {permission}: {granted.stdout.strip()}")

    _adb(device, "logcat", "-c")
    _adb(device, "shell", "am", "force-stop", PACKAGE)
    launch = _adb(device, "shell", "am", "start", "-W", "-n", ACTIVITY)
    if "Error" in launch.stdout:
        print(f"::error::Launch failed:\n{launch.stdout}", file=sys.stderr)
        ok = False
    print(f"am start -W:\n{launch.stdout.strip()}")

    # Wait for the framework's own "Displayed" marker rather than a fixed
    # sleep: emulator start-up time varies by an order of magnitude between a
    # warm local machine and a cold CI runner.
    #
    # Two accepted signals, because one is not enough. "Displayed" is the
    # honest first-frame marker but is suppressed whenever something else owns
    # the foreground; `am start -W` blocks until the launch completes and
    # reports its own status. Requiring only the first turned a healthy app
    # behind a permission dialog into a 90s "hang".
    deadline = time.monotonic() + LAUNCH_TIMEOUT_SECONDS
    displayed = False
    while time.monotonic() < deadline:
        if FIRST_FRAME_PATTERN.search(_adb(device, "logcat", "-d").stdout):
            displayed = True
            break
        time.sleep(2)

    launched_ok = "Status: ok" in launch.stdout
    if not displayed and not launched_ok:
        print(
            f"::error::App did not report a first frame within {LAUNCH_TIMEOUT_SECONDS}s "
            "and `am start -W` did not report Status: ok.",
            file=sys.stderr,
        )
        ok = False
    elif not displayed:
        print(
            "::warning::No 'Displayed' marker seen, but `am start -W` reported "
            "Status: ok — continuing to the resume check."
        )

    # Background/resume: a release-only plugin registration or audio-service
    # binding fault typically surfaces on resume, not on cold start.
    _adb(device, "shell", "input", "keyevent", "KEYCODE_HOME")
    time.sleep(3)
    _adb(device, "shell", "am", "start", "-n", ACTIVITY)
    time.sleep(5)

    try:
        subprocess.run(
            ("adb", "-s", device, "exec-out", "screencap", "-p"),
            check=True,
            stdout=(evidence / "final.png").open("wb"),
        )
    except (OSError, subprocess.CalledProcessError) as error:
        print(f"::warning::Could not capture screenshot: {error}", file=sys.stderr)

    logcat = _adb(device, "logcat", "-d", "-v", "brief").stdout
    (evidence / "logcat.txt").write_text(logcat, encoding="utf-8")
    if "FATAL EXCEPTION" in logcat:
        print("::error::Crash in release APK logcat — see logcat.txt.", file=sys.stderr)
        ok = False

    # A process that died leaves no pid, even when nothing logged FATAL.
    if not _adb(device, "shell", "pidof", PACKAGE).stdout.strip():
        print(f"::error::{PACKAGE} is not running after resume.", file=sys.stderr)
        ok = False

    return ok


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--device")
    parser.add_argument(
        "--inspect-only",
        action="store_true",
        help="Run the deterministic APK checks without needing a device.",
    )
    parser.add_argument("--evidence-dir", type=Path, default=REPO / "verify-evidence")
    parser.add_argument(
        "--require-signature-check",
        action="store_true",
        help="Fail if apksigner is unavailable (CI uses this; local runs warn instead).",
    )
    args = parser.parse_args(argv)

    try:
        inspect_apk(args.apk)
        verify_signature(args.apk, required=args.require_signature_check)
    except (VerificationError, OSError, zipfile.BadZipFile) as error:
        print(f"::error::{error}", file=sys.stderr)
        return 1

    if args.inspect_only:
        print("Inspection passed.")
        return 0
    if not args.device:
        parser.error("--device is required unless --inspect-only is used")
    return 0 if smoke_test(apk=args.apk, device=args.device, evidence=args.evidence_dir) else 1


if __name__ == "__main__":
    raise SystemExit(main())
