# Flutter Production Project — Setup & Audit

You are a senior Flutter engineer performing a **production-readiness audit and setup** on the current project. Work systematically through each section below. For each item: inspect the current state, state what you found, and either confirm it is already solid or implement the fix — do not just list recommendations.

---

## 1. Project Structure

Verify the `lib/` tree follows layered separation:

```
lib/
  main.dart          # bootstrap only — init singletons, run app
  app.dart           # MaterialApp + MultiProvider wiring
  screens/           # full screens (no business logic)
  widgets/           # reusable components
  providers/         # ChangeNotifier state holders
  services/          # I/O, network, persistence (no UI imports)
  models/            # pure data classes
  audio/             # domain-specific subsystem (if applicable)
  l10n/              # ARB locale files
  utils/             # pure helpers (no side effects)
```

If the tree deviates materially (e.g., services importing providers, screens reaching into services directly), flag it and propose a migration path. Do not refactor speculatively — only raise it if real coupling is found.

---

## 2. State Management

Check that state management is consistent and correctly scoped:

- **ChangeNotifier + Provider** for all shared state (audio playback, downloads, config, connectivity, theme, preferences).
- **`setState`** only for genuinely ephemeral, local UI state (e.g., a single toggle in one widget that nothing else cares about). If `setState` is used for anything shared across widgets, flag it.
- **`MultiProvider`** in `app.dart` (or equivalent) wires providers; order matters if providers depend on each other — confirm dependencies are declared top-to-bottom.
- No `BLoC`, `Riverpod`, `GetX` or other state-management libraries mixed in unless the project deliberately chose them — if so, confirm the choice is consistent throughout.

---

## 3. Linting

Check whether `analysis_options.yaml` exists and activates `flutter_lints`:

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
```

If the file is missing or incomplete, create/update it. Then run:

```bash
flutter analyze --fatal-warnings
```

Fix every issue the analyzer surfaces before moving on. Do not suppress rules without a documented reason.

---

## 4. Dependency Health

Inspect `pubspec.yaml`:

- All version constraints are bounded (e.g., `^1.2.3`, not `any` or `>=1.0.0`).
- No obviously unmaintained packages (check pub.dev "discontinued" flag if uncertain).
- Dev dependencies are in `dev_dependencies`, not `dependencies`.
- Run `flutter pub outdated` and report which packages have major-version updates available. Do not auto-upgrade — surface them for the developer to decide.

---

## 5. Remote Config / Feature Flags

Check whether runtime configuration (feature flags, brand strings, URLs, API endpoints) is driven by an external JSON or similar:

- If hardcoded: propose an `AppConfigModel` + CDN JSON pattern where the app fetches config on startup and falls back to safe defaults. This lets you toggle features and update branding without an app release.
- If already externalized: confirm the model has `const defaults` so it works offline on first launch, and that the fetch is non-blocking (serve defaults immediately, update in background).

---

## 6. Offline-First Architecture

Inspect how the app behaves with no network:

- Is there a `ConnectivityProvider` (or equivalent) that exposes `isOnline`, `isWifi`, `isMobile`?
- Does the catalog/content layer use stale-while-revalidate (serve cached data immediately, refresh in background)?
- Does the UI communicate connectivity state clearly (offline banner, disabled download CTA, etc.)?
- Are downloads stored in the app's documents directory (not cache, which the OS can purge)?

Flag any path where a user with no network would hit an unhandled error or blank screen.

---

## 7. Persistence (SharedPreferences / SQLite / Hive)

Locate the persistence layer:

- Is it behind a service class (`PreferencesService`, `LocalDb`, etc.) rather than scattered `SharedPreferences.getInstance()` calls?
- Are keys stored as constants (not inline strings)?
- Is there a `resetForTest()` method or equivalent so unit tests can isolate state?

If persistence is scattered, extract it to a dedicated service class.

---

## 8. Testing Strategy

Run the full test suite:

```bash
flutter test --reporter=expanded
```

Then evaluate coverage across three tiers:

**Unit tests** (pure logic, no Flutter framework):
- Persistence service (save/load round-trips for every stored key)
- Cache strategy / freshness logic
- Any pure utility functions (`decideCacheStrategy`, `formatDuration`, etc.)
- Provider factories annotated `@visibleForTesting`

**Widget tests** (component rendering, interaction):
- Only test widgets with non-trivial logic (e.g., a card that conditionally renders based on provider state). Thin UI shells don't need widget tests.

**Integration tests** (`integration_test/`):
- At minimum: cold start → catalog loads → tap first item → audio plays.
- Ideally: download flow, offline playback, settings round-trip.

Report which critical paths have no test coverage and propose the minimal set of tests that would catch a silent regression.

---

## 9. CI/CD

Check `.github/workflows/` (or equivalent):

**Fast gate** (ubuntu, every push/PR to develop):
```yaml
- run: flutter analyze --fatal-warnings
- run: flutter test
```

**Regression gate** (macos-latest, PRs to master + nightly schedule):
```yaml
- name: Boot iOS Simulator
  run: |
    UDID=$(xcrun simctl list devices available --json | python3 -c "
    import json, sys
    data = json.load(sys.stdin)
    for runtime, devices in sorted(data['devices'].items(), reverse=True):
        if 'iOS' not in runtime:
            continue
        for d in devices:
            if 'iPhone' in d['name'] and d.get('isAvailable', False):
                print(d['udid'])
                exit()
    " 2>/dev/null)
    xcrun simctl boot "$UDID"
    echo "SIMULATOR_UDID=$UDID" >> "$GITHUB_ENV"
- run: flutter test integration_test/app_test.dart -d "$SIMULATOR_UDID" --timeout 15m
```

If either workflow is missing, create it. Confirm pub cache is keyed on `pubspec.lock` for reproducibility.

---

## 10. Secrets & Security

Confirm:

- No API keys, tokens, or credentials in `lib/` or committed to git.
- `.gitignore` excludes `key.properties`, `*.jks`, `*.keystore`, `google-services.json`, `GoogleService-Info.plist`, `keys.dart`, `.env`.
- All network endpoints use HTTPS.
- User-controlled input is never interpolated into shell commands or SQL without sanitisation.

Run:
```bash
git log --all --full-history -- "*.pem" "*.key" "*.env" key.properties
```
to confirm secrets were never committed to history.

---

## 11. Internationalisation (l10n)

If the app targets multiple locales:

- ARB files exist under `lib/l10n/` (`app_en.arb`, etc.).
- `flutter_localizations` and `intl` are in `dependencies`.
- `generate: true` is set in `pubspec.yaml` (or `l10n.yaml` exists).
- No hardcoded user-visible strings outside ARB files.
- Run `flutter gen-l10n` and confirm it succeeds with no missing keys.

---

## 12. Accessibility

Spot-check key interactive elements:

- All `IconButton` and tappable icons have a `tooltip` or `Semantics` label.
- `Image.asset` / `Image.network` calls have `semanticsLabel` set (or `excludeFromSemantics: true` for purely decorative images).
- Touch targets are at least 48×48 dp (Material minimum).
- Text does not use hardcoded `Color` values that would disappear in dark mode — colours come from `Theme.of(context)`.

Run the Flutter accessibility checker if available:
```bash
flutter test --tags=a11y
```

---

## 13. Performance Basics

Check for common performance pitfalls:

- `ListView(children: [...])` used for unbounded/large lists instead of `ListView.builder` — flag if the list can contain more than ~20 items.
- `build()` methods doing expensive work (parsing JSON, computing heavy layouts) — these should be cached in `initState` or a provider.
- `const` constructors used wherever possible (verified by the linter from step 3).
- No `print()` / `debugPrint()` in production paths (the linter catches this).

---

## 14. Branding & App Identity

Confirm configurable brand identity is not hardcoded:

- App name, publisher, YouTube/social links, support URLs → driven from remote JSON config (see §5).
- App icons generated from source assets via `flutter_launcher_icons`.
- Splash screen via `flutter_native_splash` (or equivalent).
- `pubspec.yaml` `version` follows `MAJOR.MINOR.PATCH+BUILD` (e.g., `2.1.0+21`).
- Bundle ID / package name reflects the actual app identity (not `com.example.*`).

---

## 15. Release Checklist

Before cutting a release build:

```bash
# Confirm analyzer is clean
flutter analyze --fatal-warnings

# Full test suite
flutter test

# Integration smoke test on device
flutter test integration_test/app_test.dart -d <device-id>

# Android release build
flutter build appbundle --release

# iOS release build
flutter build ipa --release
```

Confirm `android/app/build.gradle` (or `build.gradle.kts`) and `ios/Runner/Info.plist` have the correct version string and bundle ID.

---

## Summary Output

After completing the audit, output a table:

| Area | Status | Action taken / Recommendation |
|------|--------|-------------------------------|
| Project structure | ✅ / ⚠️ / ❌ | ... |
| State management | ✅ / ⚠️ / ❌ | ... |
| Linting | ✅ / ⚠️ / ❌ | ... |
| ... | | |

Legend: ✅ solid, ⚠️ minor gap (low risk), ❌ must fix before shipping.
