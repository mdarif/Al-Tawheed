#!/usr/bin/env bash
#
# setup-release-secrets.sh — push local signing + Play Store credentials into
# GitHub Actions secrets, so the Release workflow (.github/workflows/
# flutter-release.yml) can build a signed AAB and upload it to the Play Store.
#
# This is a ONE-TIME setup — re-run it only when a credential changes (key
# rotation, a fresh Play Store service-account key, or a new machine/clone).
# The per-release command stays `make release-auto BUMP=<level>`.
#
# No secret VALUES live in this script — it reads them from the key vault and
# android/key.properties at runtime and streams them straight to `gh secret
# set` (nothing is echoed or logged).
#
# Sets these 5 repo secrets:
#   KEYSTORE_BASE64             ← base64 of the upload keystore (.jks)
#   KEY_ALIAS                   ← from android/key.properties
#   KEY_PASSWORD                ← from android/key.properties
#   STORE_PASSWORD              ← from android/key.properties
#   GOOGLE_PLAY_SERVICE_ACCOUNT ← Play Store service-account JSON
#
# Usage:
#   scripts/setup-release-secrets.sh
#   scripts/setup-release-secrets.sh --verify-only    # just list current secrets
#
# Override any path/target via environment variables:
#   REPO=owner/name \
#   KEYSTORE=/path/upload-keystore.jks \
#   SERVICE_ACCOUNT_DIR="/path/Service Account JSON" \
#   scripts/setup-release-secrets.sh

set -euo pipefail

# ── Config (override via env) ────────────────────────────────────────────────
REPO="${REPO:-mdarif/Al-Tawheed}"
VAULT="${VAULT:-$HOME/Library/CloudStorage/Dropbox/Al-Marfa/Al-Tawheed}"
KEYSTORE="${KEYSTORE:-$VAULT/Keys/upload-keystore.jks}"
SERVICE_ACCOUNT_DIR="${SERVICE_ACCOUNT_DIR:-$VAULT/Service Account JSON}"
KEY_PROPERTIES="${KEY_PROPERTIES:-android/key.properties}"

# Resolve the newest *.json in the service-account folder so a rotated key is
# picked up automatically without editing this script.
SERVICE_ACCOUNT="${SERVICE_ACCOUNT:-$(ls -t "$SERVICE_ACCOUNT_DIR"/*.json 2>/dev/null | head -1 || true)}"

# ── Helpers ──────────────────────────────────────────────────────────────────
die() { echo "✗ $*" >&2; exit 1; }

require_file() {
  [ -f "$1" ] || die "$2 not found at: $1"
}

prop() {
  # Extract a value from key.properties without printing it.
  grep "^$1=" "$KEY_PROPERTIES" | cut -d'=' -f2- | tr -d '\n'
}

# ── --verify-only short-circuit ──────────────────────────────────────────────
if [ "${1:-}" = "--verify-only" ]; then
  echo "Current secrets on $REPO:"
  gh secret list --repo "$REPO"
  exit 0
fi

# ── Preconditions ────────────────────────────────────────────────────────────
command -v gh >/dev/null 2>&1 || die "GitHub CLI (gh) not installed — see https://cli.github.com"
gh auth status >/dev/null 2>&1 || die "gh not authenticated — run: gh auth login"

require_file "$KEYSTORE" "Upload keystore"
require_file "$KEY_PROPERTIES" "key.properties"
[ -n "$SERVICE_ACCOUNT" ] || die "No *.json found in: $SERVICE_ACCOUNT_DIR"
require_file "$SERVICE_ACCOUNT" "Play Store service account JSON"

# Sanity-check the service account JSON before uploading it.
grep -q '"type": *"service_account"' "$SERVICE_ACCOUNT" \
  || die "This doesn't look like a service-account JSON: $SERVICE_ACCOUNT"

echo "Repo:            $REPO"
echo "Keystore:        $KEYSTORE"
echo "key.properties:  $KEY_PROPERTIES"
echo "Service account: $SERVICE_ACCOUNT"
echo

# ── Set the 5 secrets (values streamed via stdin — never in argv) ────────────
base64 -i "$KEYSTORE" | tr -d '\n' | gh secret set KEYSTORE_BASE64 --repo "$REPO"
echo "✓ KEYSTORE_BASE64"

printf '%s' "$(prop keyAlias)"      | gh secret set KEY_ALIAS      --repo "$REPO"; echo "✓ KEY_ALIAS"
printf '%s' "$(prop keyPassword)"   | gh secret set KEY_PASSWORD   --repo "$REPO"; echo "✓ KEY_PASSWORD"
printf '%s' "$(prop storePassword)" | gh secret set STORE_PASSWORD --repo "$REPO"; echo "✓ STORE_PASSWORD"

gh secret set GOOGLE_PLAY_SERVICE_ACCOUNT --repo "$REPO" < "$SERVICE_ACCOUNT"
echo "✓ GOOGLE_PLAY_SERVICE_ACCOUNT"

echo
echo "All 5 release secrets set. Current state:"
gh secret list --repo "$REPO"
