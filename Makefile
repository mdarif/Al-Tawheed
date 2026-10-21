.PHONY: help setup setup-hooks setup-release-secrets clean test analyze format format-check release release-android release-ios release-apk integration-test perf patrol-test orientation-test screenshots run ci ci-logs test-tooling verify-apk

help:
	@echo "Al-Tawheed Flutter App - Available Commands"
	@echo ""
	@echo "Setup & Maintenance:"
	@echo "  make setup                 - Complete project setup (installs hooks, pub get)"
	@echo "  make setup-hooks           - Point git at .githooks (pre-push); run once after clone"
	@echo "  make setup-release-secrets - One-time: push signing + Play Store creds to GitHub secrets"
	@echo "  make clean                 - Clean build artifacts"
	@echo "  make pub-get               - Get pub dependencies"
	@echo "  make doctor                - Run flutter doctor -v"
	@echo "  make devices               - List connected devices"
	@echo "  make version               - Show project and Flutter version"
	@echo ""
	@echo "Run:"
	@echo "  make run                   - Run app on connected device"
	@echo "  make run-android           - Launch Android emulator and run on it"
	@echo "  make run-ios               - Run on iOS simulator"
	@echo ""
	@echo "Testing & Quality:"
	@echo "  make test                  - flutter test (unit + widget)"
	@echo "  make test-verbose          - flutter test with verbose output"
	@echo "  make test-goldens          - Verify golden (pixel) tests (macOS only)"
	@echo "  make goldens-update        - Re-bake golden masters after a reviewed UI change"
	@echo "  make test-tooling          - Python unittest suite in test/tool"
	@echo "  make analyze               - flutter analyze --fatal-warnings"
	@echo "  make lint                  - dart analyze"
	@echo "  make format                - dart format . (rewrites files)"
	@echo "  make format-check          - dart format --set-exit-if-changed (no rewrite)"
	@echo "  make coverage              - flutter test --coverage (report in coverage/)"
	@echo "  make ci                    - format-check, test-tooling, analyze, test, debug APK build"
	@echo ""
	@echo "On-device:"
	@echo "  make integration-test      - Validation app_test.dart on device (DEVICE required)"
	@echo "  make orientation-test      - Portrait/landscape flip suite on device (DEVICE required)"
	@echo "  make patrol-test           - Patrol native gate (DEVICE optional)"
	@echo "  make perf                  - Frame-timing benchmarks (DEVICE required; MODE=full|smoke)"
	@echo "  make cold-start-test       - Repeated Android cold-start measurement (DEVICE required)"
	@echo "  make screenshots           - Generate + frame Play Store assets (DEVICE required; not validation)"
	@echo ""
	@echo "Build & Release:"
	@echo "  make build-android         - flutter build apk --debug"
	@echo "  make build-ios             - flutter build ios"
	@echo "  make release-apk           - Local release gate: checks, integration, Patrol, release APK (DEVICE required)"
	@echo "  make verify-apk            - Inspect a signed release APK (APK=..., DEVICE optional)"
	@echo "  make release               - Trigger release workflow (MODE=master|develop|dry, BUMP=patch|minor|major)"
	@echo "  make release-android       - flutter build appbundle --release (Play Store AAB)"
	@echo "  make release-ios           - flutter build ios --release (App Store archive)"
	@echo "  make ci-logs               - Fetch latest failed GitHub Actions run logs"

# Setup
setup: setup-hooks
	@echo "Setting up Al-Tawheed project..."
	flutter pub get
	@echo "✓ Project setup complete!"

# Install git hooks — run once after cloning
setup-hooks:
	@echo "Installing git hooks..."
	git config core.hooksPath .githooks
	@echo "✓ Hooks installed (.githooks/pre-push active)"

# Clean
clean:
	@echo "Cleaning project..."
	flutter clean
	rm -rf build/ ios/Pods ios/Podfile.lock
	@echo "✓ Clean complete!"

# Pub Management
pub-get:
	flutter pub get

# Development
run:
	flutter run

run-android:
	flutter emulators --launch android_emulator
	flutter run -d emulator-5554

run-ios:
	flutter run -d "iPhone 15 Pro"

# Testing
test:
	flutter test --reporter=expanded

test-verbose:
	flutter test --reporter=expanded --verbose

# Golden (pixel-snapshot) tests — tagged `golden`, skipped by every run above
# (see dart_test.yaml). Platform-sensitive, so generated AND verified on macOS
# only. `test-goldens` verifies; `goldens-update` re-bakes the masters after a
# REVIEWED intentional UI change — eyeball the diff before committing.
test-goldens:
	flutter test test/golden --run-skipped --reporter=expanded

goldens-update:
	flutter test test/golden --run-skipped --update-goldens

# Analysis & Quality
analyze:
	flutter analyze --fatal-warnings

format:
	dart format .

# Format-only CHECK (no rewrite). Covers lib, test, tool, integration_test and
# patrol_test. Exits non-zero if any file is unformatted; never touches files.
format-check:
	dart format --set-exit-if-changed -o none lib test tool integration_test patrol_test

coverage:
	flutter test --coverage
	@echo "✓ Coverage report generated in coverage/"

lint:
	dart analyze

# Runs `python3 -m unittest discover -s test/tool` and nothing else. The suite
# covers the release tooling (compute_release_version.py, release_git.py,
# play_release_preflight.py), the Makefile targets and the workflow structure
# (test_workflows.py); it does not yet exercise verify_release_apk.py.
# test_workflows.py parses the workflows with PyYAML, pinned in CI to 6.0.3:
# `python3 -m pip install PyYAML==6.0.3` locally if it is missing.
test-tooling:
	python3 -m unittest discover -s test/tool

# Device ID for on-device tests — required by integration-test, perf,
# cold-start-test, screenshots, orientation-test and release-apk.
# Run `flutter devices` and pass e.g. DEVICE=emulator-5554
DEVICE ?=

integration-test: pub-get
	@if [ -z "$(DEVICE)" ]; then \
		echo "Error: DEVICE is required."; \
		echo "  flutter devices"; \
		echo "  make integration-test DEVICE=<device_id>"; \
		exit 1; \
	fi
	# Validation only: screenshot capture tests are a separate asset-generation
	# target (`make screenshots`) and are intentionally not a release gate.
	flutter test integration_test/app_test.dart -d $(DEVICE) --timeout 15m

# On-device frame-timing benchmarks (lecture list + book reader scroll/paging).
# MUST be a real device in --profile mode: debug build times are inflated and a
# simulator's raster times are meaningless. Prints PERF[...] lines.
#   MODE=full (default): the strict regression gate. Build/raster ceilings are
#     enforced (PERF_ENFORCE_THRESHOLDS defaults to true in the test).
#   MODE=smoke: runs every scenario and requires nonempty timings, but passes
#     PERF_ENFORCE_THRESHOLDS=false so device-sensitive ceilings are not enforced.
#     For emulators or harness validation only; never a physical baseline.
# Usage: make perf DEVICE=<id>               (MODE=full)
#        make perf DEVICE=<id> MODE=smoke
perf: MODE ?= full
perf: pub-get
	@case "$(MODE)" in full|smoke) ;; *) echo "Error: MODE must be full or smoke (got '$(MODE)')"; exit 1 ;; esac
	@if [ -z "$(DEVICE)" ]; then \
		echo "Error: DEVICE is required (MODE=full: a real device; MODE=smoke: an emulator or device)."; \
		echo "  flutter devices"; \
		echo "  make perf DEVICE=<device_id> MODE=$(MODE)"; \
		exit 1; \
	fi
	flutter drive \
		--driver=test_driver/perf_driver.dart \
		--target=integration_test/performance_test.dart \
		--profile $(if $(filter smoke,$(MODE)),--dart-define=PERF_ENFORCE_THRESHOLDS=false,) \
		-d $(DEVICE)

# Repeated Android cold-start measurement. The runner clears app data before
# EVERY fresh-install sample, while returning samples preserve data and only
# force-stop the process. It consumes the native Activity.onCreate → Flutter
# interactive marker from logcat and prints a median/min/max summary.
COLD_START_COHORT ?= returning
COLD_START_SAMPLES ?= 3
COLD_START_TIMEOUT_SECONDS ?= 180
cold-start-test: pub-get
	@if [ -z "$(DEVICE)" ]; then \
		echo "Error: DEVICE is required (an Android emulator/device)."; \
		echo "  make cold-start-test DEVICE=<android_id> COLD_START_COHORT=returning"; \
		exit 1; \
	fi
	COLD_START_TIMEOUT_SECONDS="$(COLD_START_TIMEOUT_SECONDS)" \
		./scripts/cold_start_test.sh "$(DEVICE)" "$(COLD_START_COHORT)" "$(COLD_START_SAMPLES)"

# Capture + frame the Play Store screenshot set (v3, Arabic-led). Runs the
# on-device capture harness, then composites clean device frames on the brand
# background. Output: docs/play-store/v3/framed/ + preview.png. Needs DEVICE
# (an iOS sim or Android device) and python3 (Pillow installed into a
# gitignored build/ venv).
SCREENSHOT_VENV ?= build/screenshot-venv
screenshots: pub-get
	@if [ -z "$(DEVICE)" ]; then \
		echo "Error: DEVICE is required. Run 'flutter devices'."; \
		echo "  make screenshots DEVICE=<device_id>"; \
		exit 1; \
	fi
	flutter drive \
		--driver=test_driver/screenshot_driver.dart \
		--target=integration_test/screenshots_test.dart \
		-d $(DEVICE)
	@test -d $(SCREENSHOT_VENV) || python3 -m venv $(SCREENSHOT_VENV)
	@$(SCREENSHOT_VENV)/bin/pip install --quiet Pillow
	@$(SCREENSHOT_VENV)/bin/python scripts/frame_screenshots.py
	@$(SCREENSHOT_VENV)/bin/python scripts/frame_screenshots.py tablet
	@echo "✓ Phone:  docs/play-store/v3/framed/        (preview.png)"
	@echo "✓ Tablet: docs/play-store/v3/framed-tablet/ (preview-tablet.png — 7\" & 10\")"

# Portrait/landscape flip coverage across all key screens (lecture list, player,
# home, mini player, settings). Runs the same on-device harness as integration.
orientation-test: pub-get
	@if [ -z "$(DEVICE)" ]; then \
		echo "Error: DEVICE is required."; \
		echo "  flutter devices"; \
		echo "  make orientation-test DEVICE=<device_id>"; \
		exit 1; \
	fi
	flutter test integration_test/orientation_test.dart -d $(DEVICE) --timeout 15m

# Patrol native tests (airplane mode, notification shade, permission dialogs).
# The pubspec pin patrol ^4.6.1 requires patrol_cli 4.4.0. The command parses
# the final summary and requires at least one discovered test: Android 16/API
# 36 can build and instrument successfully while reporting Total: 0, which is
# not a green gate.
# Install the compatible CLI once: dart pub global activate patrol_cli 4.4.0
# Both suites, explicitly: native_test.dart (airplane mode, notification
# shade, permission dialogs) and arabic_series_test.dart (RTL/Arabic-edition
# native flows). A command that only bundles one is not release evidence —
# see the IA roadmap A5T note.
patrol-test:
	@PATROL_LOG=$$(mktemp /tmp/at-tawheed-patrol.XXXXXX); \
	trap 'rm -f "$$PATROL_LOG"' 0; \
	bash -o pipefail -c 'patrol test \
		-t patrol_test/native_test.dart \
		-t patrol_test/arabic_series_test.dart \
		$(if $(DEVICE),--device $(DEVICE),) 2>&1 | tee "$$1"' _ "$$PATROL_LOG"; \
	STATUS=$$?; \
	dart run tool/patrol_result.dart --exit-code=$$STATUS "$$PATROL_LOG"; \
	PARSE_STATUS=$$?; \
	if [ "$$STATUS" -ne 0 ]; then exit "$$STATUS"; fi; \
	exit "$$PARSE_STATUS"

# Local release gate, run in this order: pub get → format-check → test-tooling →
# analyze → unit/widget tests → validation integration test (DEVICE) → Patrol
# (must discover tests) → `flutter build apk --release`.
# Screenshot generation is not part of this gate; use `make screenshots DEVICE=<id>`.
# Requires android/key.properties for signing and a connected DEVICE.
release-apk: pub-get
	$(MAKE) format-check
	$(MAKE) test-tooling
	flutter analyze --fatal-warnings
	flutter test --reporter=expanded
	@if [ -z "$(DEVICE)" ]; then \
		echo "Error: DEVICE is required for integration tests."; \
		echo "  flutter devices"; \
		echo "  make release-apk DEVICE=<device_id>"; \
		exit 1; \
	fi
	flutter test integration_test/app_test.dart -d $(DEVICE) --timeout 15m
	$(MAKE) patrol-test DEVICE=$(DEVICE)
	flutter build apk --release
	@echo "✓ Release APK: build/app/outputs/flutter-apk/app-release.apk"

# Inspect (and optionally on-device smoke-test) a signed release APK, exactly
# like the `verify-android` CI job does. APK defaults to the standard release
# APK output path if unset. With DEVICE unset it's the deterministic,
# no-device --inspect-only path (asset hashes + JSON validity + rejects a
# debug-signed APK); with DEVICE set it installs/launches/backgrounds/resumes
# it and writes screenshot+logcat evidence to verify-evidence/.
APK ?= build/app/outputs/flutter-apk/app-release.apk
verify-apk:
	@if [ ! -f "$(APK)" ]; then \
		echo "Error: APK does not exist: $(APK)"; \
		echo "  Build one first: flutter build apk --release"; \
		echo "  Or pass an existing one: make verify-apk APK=<path>"; \
		exit 1; \
	fi
	@if [ -z "$(DEVICE)" ]; then \
		python3 tool/verify_release_apk.py --apk $(APK) --inspect-only; \
	else \
		python3 tool/verify_release_apk.py --apk $(APK) --device $(DEVICE) --evidence-dir verify-evidence; \
	fi

# Local CI approximation: runs, in order, format-check, test-tooling, analyze,
# unit/widget tests and a debug APK build, on this machine. It does NOT run the
# on-device, Patrol or release-signing gates (see release-apk), and it is not
# the GitHub Actions run itself (CI uses its own runners and workflow files).
ci: format-check test-tooling
	@echo "Running CI pipeline locally..."
	flutter analyze --fatal-warnings
	flutter test --reporter=expanded
	flutter build apk --debug
	@echo "✓ CI pipeline passed."

# Pull the latest failed CI run logs from GitHub Actions
ci-logs:
	@RUN_ID=$$(gh run list --repo mdarif/Al-Tawheed --limit 1 --json databaseId --jq '.[0].databaseId'); \
	echo "Fetching logs for run $$RUN_ID..."; \
	gh run view $$RUN_ID --log-failed

# Building
# build-android is a DEBUG APK. The signed release APK is `make release-apk`
# (local gate) or the release workflow; the Play bundle is `make release-android`.
build-android:
	flutter build apk --debug

build-ios:
	flutter build ios

# One-time (or key-rotation) setup: push the signing keystore + Play Store
# service-account credentials into GitHub Actions secrets so the Release
# workflow can build a signed AAB and upload it to the Play Store. Reads from
# the Dropbox key vault + android/key.properties — no secret values live in
# the repo. Override paths via env, e.g. VAULT=... make setup-release-secrets.
# Run `scripts/setup-release-secrets.sh --verify-only` to just list secrets.
setup-release-secrets:
	@scripts/setup-release-secrets.sh

# Release
# Trigger the GitHub Actions release workflow (.github/workflows/flutter-release.yml).
#   MODE=master (default)  Release from master. Usage: make release BUMP=patch
#   MODE=develop           One-click release from develop: promotes develop to
#                          master, releases, and syncs the bump back to develop.
#                          Usage: make release MODE=develop BUMP=minor
#                          Add DRY_RUN=true to validate without shipping.
#   MODE=dry               Dry run from develop: prepare/build/verify only; no tag,
#                          commit, Play upload or GitHub Release.
#                          Usage: make release MODE=dry BUMP=patch
#                          IMPORTANT: a dry run that finishes in under a minute with
#                          no artifacts is a FAILURE (needs: cascade-skip), not a pass.
# BUMP defaults to patch in every mode.
BUMP ?= patch
DRY_RUN ?= false
release: MODE ?= master
release:
	@case "$(MODE)" in \
	  master) \
	    echo "Triggering release workflow (bump=$(BUMP))..."; \
	    BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	    if [ "$$BRANCH" != "master" ]; then \
	      echo "Error: releases must be triggered from master (you are on $$BRANCH)"; \
	      exit 1; \
	    fi; \
	    gh workflow run flutter-release.yml \
	      --ref master \
	      --field bump=$(BUMP) && \
	    echo "✓ Release workflow triggered — watch it at:" && \
	    echo "  https://github.com/mdarif/Al-Tawheed/actions/workflows/flutter-release.yml" ;; \
	  develop) \
	    echo "Triggering one-click release workflow (bump=$(BUMP), dry_run=$(DRY_RUN))..."; \
	    BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	    if [ "$$BRANCH" != "develop" ]; then \
	      echo "Error: release MODE=develop must be triggered from develop (you are on $$BRANCH)"; \
	      exit 1; \
	    fi; \
	    gh workflow run flutter-release.yml \
	      --ref develop \
	      --field bump=$(BUMP) \
	      --field confirm_promote=true \
	      --field dry_run=$(DRY_RUN) && \
	    echo "✓ Release workflow triggered — watch it at:" && \
	    echo "  https://github.com/mdarif/Al-Tawheed/actions/workflows/flutter-release.yml" ;; \
	  dry) \
	    echo "Triggering release workflow dry run (bump=$(BUMP))..."; \
	    BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	    if [ "$$BRANCH" != "develop" ]; then \
	      echo "Error: release MODE=dry must be run from develop (you are on $$BRANCH)"; \
	      exit 1; \
	    fi; \
	    gh workflow run flutter-release.yml \
	      --ref develop \
	      --field bump=$(BUMP) \
	      --field dry_run=true \
	      --field confirm_promote=false && \
	    echo "✓ Dry-run release workflow triggered — watch it at:" && \
	    echo "  https://github.com/mdarif/Al-Tawheed/actions/workflows/flutter-release.yml" ;; \
	  *) echo "Error: MODE must be master, develop or dry (got '$(MODE)')"; exit 1 ;; \
	esac

release-android:
	@echo "Building Android App Bundle for Google Play Store..."
	flutter build appbundle --release
	@echo "✓ App Bundle created: build/app/outputs/bundle/release/app-release.aab"

release-ios:
	@echo "Building iOS archive for App Store..."
	flutter build ios --release
	@echo "✓ Build complete! Use Xcode for App Store submission."

# Utilities
doctor:
	flutter doctor -v

devices:
	flutter devices

version:
	@echo "Project Version Info:"
	@grep "version:" pubspec.yaml
	@flutter --version
