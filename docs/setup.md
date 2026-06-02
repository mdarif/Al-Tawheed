# Al-Tawheed Project Setup Guide

## Overview
This document provides complete setup instructions for the Sharah Kitab At-Tawheed Flutter application, including local development environment configuration, testing setup, and troubleshooting.

## Prerequisites
- macOS (Intel or Apple Silicon)
- Xcode 14.0+
- Android Studio 2021.3+
- Flutter SDK 3.0.0 or higher
- Dart SDK 3.0.0 or higher

## 1. Environment Setup

### 1.1 Install Flutter
```bash
# Clone Flutter repository (if not already installed)
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# Verify installation
flutter doctor
```

### 1.2 Check System Requirements
```bash
flutter doctor
```

Expected output should show:
- ✓ Flutter (Channel stable)
- ✓ Android toolchain
- ✓ Xcode
- ✓ Android Studio
- ✓ VS Code

## 2. Project Setup

### 2.1 Clone and Navigate to Project
```bash
cd /Users/mohammadarif/code/Al-Tawheed
```

### 2.2 Get Flutter Dependencies
```bash
flutter pub get
```

### 2.3 Update Android Configuration
The project has been configured with:
- **minSdkVersion**: 34 (Android 14) - Required for Google Play Store
- **targetSdkVersion**: 34 (Android 14)
- **compileSdkVersion**: 34

This resolves the "app isn't available for your device" error.

### 2.4 Configure Local Properties
Create or update `local.properties`:
```properties
flutter.sdk=/path/to/flutter/sdk
flutter.buildMode=debug
flutter.versionName=1.0.1
flutter.versionCode=5
```

### 2.5 Setup Android Signing (for Release)
Create `android/key.properties`:
```properties
storeFile=/path/to/keystore.jks
storePassword=your_keystore_password
keyAlias=your_key_alias
keyPassword=your_key_password
```

## 3. Development Setup

### 3.1 Running on iOS Simulator
```bash
flutter run
```

Or for specific device:
```bash
flutter run -d "iPhone 15 Pro"
```

### 3.2 Running on Android Emulator
```bash
# List available emulators
flutter emulators

# Launch an emulator
flutter emulators --launch <emulator_id>

# Run app
flutter run -d emulator-5554
```

### 3.3 Running on Physical Device

**iOS:**
```bash
# Connect physical device via USB
flutter run -d <device_id>
```

**Android:**
```bash
# Enable Developer Mode and USB Debugging
# Connect device
flutter devices
flutter run -d <device_id>
```

### 3.4 Development Commands
```bash
# Run with verbose output
flutter run -v

# Run in profile mode (performance testing)
flutter run --profile

# Run in release mode
flutter run --release

# Hot reload (after code changes)
# Press 'r' in terminal

# Hot restart (full restart, resets app state)
# Press 'R' in terminal
```

## 4. Testing Setup

### 4.1 Run Unit Tests
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Run with verbose output
flutter test --verbose

# Generate coverage report
flutter test --coverage
```

### 4.2 Run Widget/Integration Tests
```bash
# Widget tests
flutter test test/widget_test.dart

# Integration tests
flutter drive --target=test_driver/app.dart
```

### 4.3 Check Code Quality
```bash
# Analyze code
flutter analyze

# Format code
flutter format .

# Run linter
dart analyze
```

## 5. Package Management

### 5.1 Update Dependencies
```bash
# Check for outdated packages
flutter pub outdated

# Upgrade all packages
flutter pub upgrade

# Get latest compatible versions
flutter pub get
```

### 5.2 Add New Dependencies
```bash
flutter pub add package_name

# For dev dependencies
flutter pub add --dev package_name
```

### 5.3 Remove Dependencies
```bash
flutter pub remove package_name
```

## 6. Build & Release

### 6.1 Android Release Build
```bash
# Create release build
flutter build apk

# Create split APKs (recommended for Google Play)
flutter build apk --split-per-abi

# Create App Bundle (required for Google Play Store)
flutter build appbundle
```

### 6.2 iOS Release Build
```bash
# Create iOS build
flutter build ios --release

# Archive for App Store
xcode_project_path=$(find . -name "Runner.xcworkspace" -type d)
xcodebuild -workspace "$xcode_project_path" -scheme Runner -configuration Release -archivePath build/Runner.xcarchive archive
```

## 7. Firebase Configuration

### 7.1 Android Firebase Setup
```bash
# The project includes Firebase dependencies:
# - firebase_core: ^2.31.0
# - firebase_analytics: ^10.8.0
# - firebase_database: ^10.4.0

# Ensure google-services.json is in android/app/
# This file should be downloaded from Firebase Console
```

### 7.2 iOS Firebase Setup
```bash
# Run pod install to get Firebase pods
cd ios
pod install
cd ..
```

## 8. Troubleshooting

### Issue: "This app isn't available for your device"
**Solution**: Ensure minSdkVersion is 34 (FIXED in this setup)

### Issue: Pod install fails on iOS
**Solution**: 
```bash
cd ios
rm Podfile.lock
pod install
cd ..
```

### Issue: Gradle build fails
**Solution**:
```bash
flutter clean
flutter pub get
flutter pub upgrade
flutter run
```

### Issue: Flutter not found in PATH
**Solution**:
```bash
# Add to ~/.zshrc
export PATH="$PATH:/path/to/flutter/bin"
source ~/.zshrc
```

### Issue: Android SDK not found
**Solution**:
```bash
flutter config --android-sdk /path/to/android-sdk
flutter doctor
```

## 9. Project Structure
```
Al-Tawheed/
├── lib/                          # Flutter app code
│   ├── main.dart                # App entry point
│   ├── models/                  # Data models
│   ├── screens/                 # UI screens
│   └── services/                # API and services
├── android/                      # Android-specific code
│   ├── app/
│   │   ├── build.gradle         # Gradle config (minSdkVersion: 34)
│   │   └── google-services.json # Firebase config
│   └── gradle.properties        # Gradle properties
├── ios/                          # iOS-specific code
│   ├── Podfile                  # CocoaPods dependencies
│   └── Runner/                  # iOS app project
├── test/                         # Unit tests
├── pubspec.yaml                 # Flutter dependencies (Dart 3.0+)
└── assets/                       # App resources
```

## 10. Important Changes Made

### Android Configuration
- **minSdkVersion**: Updated from 24 → 34 (required for Google Play)
- **compileSdkVersion**: Confirmed 34
- **targetSdkVersion**: Confirmed 34

### Dart/Flutter Version
- **SDK**: Updated from `>=2.12.0 <3.0.0` → `>=3.0.0 <4.0.0`
- Dart 3.0+ features available (records, patterns, etc.)

### Dependencies Updated
- `firebase_analytics`: ^10.4.4 → ^10.8.0
- `firebase_core`: ^2.15.0 → ^2.31.0
- `firebase_database`: ^10.2.4 → ^10.4.0
- `url_launcher`: ^6.1.12 → ^6.2.6
- `cupertino_icons`: ^1.0.5 → ^1.0.8
- Added: `flutter_inappwebview`: ^6.0.0
- Added: `flutter_lints`: ^4.0.0 (for code quality)

## 11. Continuous Integration Tips

### Local Testing Before Commit
```bash
# Run complete test suite
flutter analyze && flutter test && flutter build apk
```

### Firebase Emulator (Optional)
```bash
# Install Firebase emulator
npm install -g firebase-tools

# Start emulator
firebase emulators:start
```

## 12. Useful Commands Reference

| Command | Purpose |
|---------|---------|
| `flutter doctor` | Check environment setup |
| `flutter pub get` | Install dependencies |
| `flutter run` | Run on connected device |
| `flutter test` | Run unit tests |
| `flutter analyze` | Check code quality |
| `flutter format .` | Format code |
| `flutter clean` | Clean build artifacts |
| `flutter build apk` | Build Android release |
| `flutter build ios` | Build iOS release |
| `flutter pub outdated` | Check for updates |

## 13. Support & Documentation

- Flutter Docs: https://flutter.dev/docs
- Firebase Flutter: https://firebase.flutter.dev
- Dart Documentation: https://dart.dev/guides
- Android Developer: https://developer.android.com

---

**Last Updated**: February 2026
**Flutter Version**: 3.0.0+
**Dart Version**: 3.0.0+
**Min Android Version**: 34 (Android 14)
