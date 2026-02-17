# Sharah Kitab al-Tawheed

A modern Flutter application that consolidates Sharah Kitaab al-Tawheed YouTube lectures of Fadilat Sheikh Abdullah Nasir Rahmani Hafizahullah.

**Total Duration**: 27 hours 7 minutes

## 🚀 Quick Start

### Prerequisites
- Flutter 3.0.0+
- Dart 3.0.0+
- Android SDK (API 34+) or Xcode 14.0+
- CocoaPods (for iOS development)

### One-Command Setup
```bash
bash setup.sh
```

Or step-by-step:
```bash
# 1. Clone and navigate
cd /Users/mohammadarif/code/Al-Tawheed

# 2. Get dependencies
flutter pub get

# 3. Setup iOS
cd ios && pod install && cd ..

# 4. Run the app
flutter run
```

## 📋 Project Structure

```
Al-Tawheed/
├── lib/                    # Flutter application code
│   ├── main.dart          # App entry point
│   ├── models/            # Data models (ChannelModel, VideoModel)
│   ├── screens/           # UI screens
│   ├── services/          # API services and Firebase
│   └── widgets/           # Reusable widgets
├── android/               # Android-specific configuration
├── ios/                   # iOS-specific configuration
├── test/                  # Unit and widget tests
├── assets/                # Images, videos, documents
├── pubspec.yaml          # Dependencies
├── SETUP_GUIDE.md        # Detailed setup instructions
├── TESTING_GUIDE.md      # Testing documentation
├── Makefile              # Development shortcuts
└── setup.sh              # Automated setup script
```

## ⚙️ Development Commands

### Using Make (Recommended)
```bash
make help              # Show all available commands
make setup             # Complete project setup
make run               # Run on connected device
make test              # Run all tests
make analyze           # Check code quality
make build-android     # Build Android APK
make release-android   # Build for Play Store
```

### Direct Flutter Commands
```bash
flutter run                    # Run app
flutter test                   # Run tests
flutter analyze                # Check code
flutter format .               # Format code
flutter build apk              # Build Android
flutter build appbundle        # Build for Play Store
flutter build ios --release    # Build iOS
```

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Run with coverage
flutter test --coverage

# Check code quality
flutter analyze
flutter format .
```

## 📱 Running on Devices

### Android
```bash
# On emulator
flutter emulators --launch android_emulator
flutter run -d emulator-5554

# On physical device
flutter run -d <device_id>
```

### iOS
```bash
# On simulator
flutter run -d "iPhone 15 Pro"

# On physical device
flutter run -d <device_id>
```

## 🔧 Important Configuration Changes

### ✅ Fixed: Android Compatibility Issue
The app had `minSdkVersion 24` which caused the error "This app isn't available for your device". This has been updated to:
- **minSdkVersion**: 34 (Android 14) - Required by Google Play Store
- **targetSdkVersion**: 34
- **compileSdkVersion**: 34

### ✅ Upgraded: Dart and Flutter
- **Dart SDK**: Updated from 2.12 → 3.0.0+
- **Flutter**: Compatible with 3.0.0+
- Enables modern Dart 3 features (records, patterns, etc.)

### ✅ Updated: Dependencies
All packages updated to latest compatible versions:
- firebase_analytics: ^10.8.0
- firebase_core: ^2.31.0
- firebase_database: ^10.4.0
- url_launcher: ^6.2.6
- And more...

## 🔗 Firebase Resources

Complete CD Links:
- Google Drive: http://goo.gl/iOvZnE
- Dropbox (Standard): http://goo.gl/f63eKB (685 MB)
- Dropbox (High Quality): http://goo.gl/rcVNal (1.6 GB)
- YouTube Playlist: http://goo.gl/pCo3uB

## 📚 Documentation

- **[SETUP_GUIDE.md](SETUP_GUIDE.md)** - Comprehensive setup and development guide
- **[TESTING_GUIDE.md](TESTING_GUIDE.md)** - Testing framework and best practices
- **[Makefile](Makefile)** - All available development commands

## 🐛 Troubleshooting

### "This app isn't available for your device"
✅ **FIXED**: Updated minSdkVersion to 34. Rebuild and try again.

### iOS build fails
```bash
cd ios
rm -rf Podfile.lock Pods
pod install
cd ..
flutter run
```

### Android build fails
```bash
flutter clean
flutter pub get
flutter pub upgrade
flutter run
```

### Flutter not in PATH
```bash
export PATH="$PATH:/path/to/flutter/bin"
```

## 🛠️ Build for Release

### Google Play Store (Android)
```bash
flutter build appbundle --release
# Upload build/app/outputs/bundle/release/app-release.aab to Play Store
```

### App Store (iOS)
```bash
flutter build ios --release
# Archive from Xcode and submit to App Store
```

## 📊 Code Quality

Maintain code quality with:
```bash
make check-quality  # Runs analyze, lint, and tests
make pre-commit     # Runs before git commits
```

## 🤝 Contributing

1. Ensure all tests pass: `flutter test`
2. Check code quality: `flutter analyze`
3. Format code: `flutter format .`
4. Create a descriptive commit message

## 📝 License

[Add your license information here]

## 👥 Support

For issues or questions:
1. Check documentation (SETUP_GUIDE.md, TESTING_GUIDE.md)
2. Review Flutter documentation: https://flutter.dev
3. Check Firebase documentation: https://firebase.flutter.dev

---

**Last Updated**: February 2026  
**Flutter Version**: 3.0.0+  
**Dart Version**: 3.0.0+  
**Min Android**: API 34 (Android 14)
