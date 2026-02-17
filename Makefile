.PHONY: help setup clean test analyze format build release run

help:
	@echo "Al-Tawheed Flutter App - Available Commands"
	@echo ""
	@echo "Setup & Maintenance:"
	@echo "  make setup           - Complete project setup"
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
	@echo "Testing & Quality:"
	@echo "  make test            - Run all tests"
	@echo "  make test-verbose    - Run tests with verbose output"
	@echo "  make analyze         - Analyze code for issues"
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
setup:
	@echo "Setting up Al-Tawheed project..."
	flutter pub get
	cd ios && pod install && cd ..
	@echo "✓ Project setup complete!"

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
	flutter test

test-verbose:
	flutter test --verbose

test-android:
	flutter test test/widget_test.dart

test-units:
	flutter test test/unit_tests.dart

# Analysis & Quality
analyze:
	flutter analyze

format:
	flutter format .

coverage:
	flutter test --coverage
	@echo "✓ Coverage report generated in coverage/"

lint:
	dart analyze

check-quality: analyze lint test
	@echo "✓ All quality checks passed!"

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
