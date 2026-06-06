.PHONY: help setup setup-hooks clean test analyze format build release release-android release-ios release-apk integration-test patrol-test run ci ci-logs

help:
	@echo "Al-Tawheed Flutter App - Available Commands"
	@echo ""
	@echo "Setup & Maintenance:"
	@echo "  make setup           - Complete project setup (installs hooks)"
	@echo "  make setup-hooks     - Install git pre-push hook (run once after clone)"
	@echo "  make clean           - Clean build artifacts"
	@echo "  make pub-get         - Get pub dependencies"
	@echo "  make pub-upgrade     - Upgrade all dependencies"
	@echo "  make pub-outdated    - Check for outdated packages"
	@echo ""
	@echo "Development:"
	@echo "  make run             - Run app on connected device"
	@echo "  make run-android     - Run on Android emulator"
	@echo "  make run-ios         - Run on iOS simulator"
	@echo ""
	@echo "CI / CD:"
	@echo "  make ci              - Run full CI pipeline locally (analyze + test + build)"
	@echo "  make release-apk     - Release pipeline: pub get, tests, integration, release APK"
	@echo "  make integration-test - Run integration_test on device (DEVICE required)"
	@echo "  make patrol-test     - Run Patrol native tests on device (DEVICE optional)"
	@echo "  make ci-logs         - Fetch latest failed GitHub Actions run logs"
	@echo "  make release         - Trigger release workflow (BUMP=patch|minor|major)"
	@echo ""
	@echo "Testing & Quality:"
	@echo "  make test            - Run tests (mirrors CI)"
	@echo "  make test-verbose    - Run tests with verbose output"
	@echo "  make analyze         - Analyze code (--fatal-warnings, mirrors CI)"
	@echo "  make format          - Format all code"
	@echo "  make coverage        - Generate test coverage report"
	@echo "  make lint            - Run linter"
	@echo ""
	@echo "Building:"
	@echo "  make build-android   - Build Android APK"
	@echo "  make build-ios       - Build iOS app"
	@echo "  make build-web       - Build web version"
	@echo ""
	@echo "Release:"
	@echo "  make release-android - Create Android App Bundle for Play Store"
	@echo "  make release-ios     - Create iOS archive for App Store"
	@echo ""
	@echo "Other:"
	@echo "  make doctor          - Run flutter doctor"
	@echo "  make devices         - List connected devices"

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

pub-upgrade:
	flutter pub upgrade

pub-outdated:
	flutter pub outdated

# Development
run:
	flutter run

run-android:
	flutter emulators --launch android_emulator
	flutter run -d emulator-5554

run-ios:
	flutter run -d "iPhone 15 Pro"

run-verbose:
	flutter run -v

run-profile:
	flutter run --profile

run-release:
	flutter run --release

# Testing
test:
	flutter test --reporter=expanded

test-verbose:
	flutter test --reporter=expanded --verbose

test-units:
	flutter test test/unit_tests.dart --reporter=expanded

# Analysis & Quality
analyze:
	flutter analyze --fatal-warnings

format:
	flutter format .

coverage:
	flutter test --coverage
	@echo "✓ Coverage report generated in coverage/"

lint:
	dart analyze

check-quality: analyze lint test
	@echo "✓ All quality checks passed!"

# Device ID for on-device tests — required by integration-test and release-apk.
# Run `flutter devices` and pass e.g. DEVICE=emulator-5554
DEVICE ?=

integration-test: pub-get
	@if [ -z "$(DEVICE)" ]; then \
		echo "Error: DEVICE is required."; \
		echo "  flutter devices"; \
		echo "  make integration-test DEVICE=<device_id>"; \
		exit 1; \
	fi
	flutter test integration_test/ -d $(DEVICE) --timeout 15m

# Patrol native tests (airplane mode, notification shade, permission dialogs).
# Install CLI once: dart pub global activate patrol_cli
patrol-test:
	patrol test -t patrol_test/native_test.dart --timeout 10m \
		$(if $(DEVICE),--device $(DEVICE),)

# Full release pipeline (local):
#   pub get → analyze → unit/widget tests → integration tests → patrol tests → release APK
# Requires android/key.properties for signing and a connected DEVICE.
release-apk: pub-get
	flutter analyze --fatal-warnings
	flutter test --reporter=expanded
	@if [ -z "$(DEVICE)" ]; then \
		echo "Error: DEVICE is required for integration tests."; \
		echo "  flutter devices"; \
		echo "  make release-apk DEVICE=<device_id>"; \
		exit 1; \
	fi
	flutter test integration_test/ -d $(DEVICE) --timeout 15m
	patrol test -t patrol_test/native_test.dart --device $(DEVICE) --timeout 10m
	flutter build apk --release
	@echo "✓ Release APK: build/app/outputs/flutter-apk/app-release.apk"

# Run the exact same steps as the GitHub Actions CI pipeline locally
ci:
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
build-android:
	flutter build apk

build-android-split:
	flutter build apk --split-per-abi

build-ios:
	flutter build ios

build-web:
	flutter build web

build-all: build-android build-ios build-web
	@echo "✓ All builds complete!"

# Release
# Trigger the GitHub Actions release workflow (runs on master in CI).
# Usage: make release BUMP=patch  (or minor / major)
BUMP ?= patch
release:
	@echo "Triggering release workflow (bump=$(BUMP))..."
	@BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	if [ "$$BRANCH" != "master" ]; then \
	  echo "Error: releases must be triggered from master (you are on $$BRANCH)"; \
	  exit 1; \
	fi
	gh workflow run flutter-release.yml \
	  --ref master \
	  --field bump=$(BUMP)
	@echo "✓ Release workflow triggered — watch it at:"
	@echo "  https://github.com/mdarif/Al-Tawheed/actions/workflows/flutter-release.yml"

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

upgrade-flutter:
	flutter upgrade

version:
	@echo "Project Version Info:"
	@grep "version:" pubspec.yaml
	@flutter --version

dependencies:
	flutter pub deps

# Firebase specific
firebase-config:
	@echo "Firebase configuration:"
	@echo "Ensure google-services.json is in android/app/"
	@echo "Ensure GoogleService-Info.plist is in ios/Runner/"

# Development workflow
dev-setup: setup analyze format
	@echo "✓ Development setup complete!"

pre-commit: lint analyze test
	@echo "✓ Pre-commit checks passed!"

# Advanced
open-xcode:
	open ios/Runner.xcworkspace

open-android-studio:
	open -a "Android Studio" .

# Docker commands (if needed)
docker-build:
	docker build -t al-tawheed:latest .

# Documentation
docs:
	@echo "Documentation files:"
	@ls -la *.md

help-verbose:
	@echo "Al-Tawheed Flutter App - Complete Command Reference"
	@echo ""
	@echo "=== INITIAL SETUP ==="
	@echo "make setup              - Run this first! Sets up everything"
	@echo "make doctor             - Check your Flutter installation"
	@echo ""
	@echo "=== DEVELOPMENT ==="
	@echo "make run                - Run app on default device"
	@echo "make run-android        - Launch Android emulator and run"
	@echo "make run-ios            - Run on iOS simulator"
	@echo "make run-verbose        - Run with detailed output"
	@echo ""
	@echo "=== QUALITY ASSURANCE ==="
	@echo "make analyze            - Check code for issues"
	@echo "make format             - Auto-format code"
	@echo "make test               - Run all unit tests"
	@echo "make test-verbose       - Tests with detailed output"
	@echo "make coverage           - Generate coverage report"
	@echo "make check-quality      - Run all quality checks"
	@echo ""
	@echo "=== BUILDING ==="
	@echo "make build-android      - Build debug APK"
	@echo "make build-android-split- Build split APKs by ABI"
	@echo "make build-ios          - Build iOS app"
	@echo ""
	@echo "=== RELEASING ==="
	@echo "make release-android    - Build for Play Store"
	@echo "make release-ios        - Build for App Store"
	@echo ""
	@echo "=== MAINTENANCE ==="
	@echo "make clean              - Remove build artifacts"
	@echo "make pub-upgrade        - Update all dependencies"
	@echo "make pub-outdated       - Check for outdated packages"
	@echo "make upgrade-flutter    - Update Flutter SDK"
	@echo ""
	@echo "=== UTILITIES ==="
	@echo "make devices            - List connected devices"
	@echo "make open-xcode         - Open Xcode workspace"
	@echo "make open-android-studio- Open Android Studio"
	@echo "make version            - Show version info"
	@echo ""
	@echo "Tip: Run 'make pre-commit' before git commits!"
