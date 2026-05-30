# Troubleshooting Guide - Common Issues & Solutions

## Issue 1: "Unable to locate Android SDK"

### Symptoms
```
✗ Android toolchain - develop for Android devices
  ✗ Unable to locate Android SDK
```

### Solutions

**Solution 1: Set Android SDK Path**
```bash
flutter config --android-sdk ~/Library/Android/sdk
flutter doctor
```

**Solution 2: Install Android Studio**
```bash
brew install --cask android-studio
# Then install Android SDK through Android Studio UI
```

**Solution 3: Manual Android SDK Installation**
1. Download Android SDK Command Line Tools
2. Extract to `~/Library/Android/sdk`
3. Install required packages:
```bash
~/Library/Android/sdk/cmdline-tools/latest/bin/sdkmanager "platforms;android-34" "build-tools;34.0.0"
```

---

## Issue 2: "Xcode installation is incomplete"

### Symptoms
```
✗ Xcode - develop for iOS and macOS
  ✗ Xcode installation is incomplete
  ✗ CocoaPods not installed
```

### Solutions

**Solution 1: Install Xcode Command Line Tools**
```bash
xcode-select --install
```

**Solution 2: Configure Xcode Path**
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcode-select --reset
```

**Solution 3: Accept Xcode License**
```bash
sudo xcodebuild -license accept
```

**Solution 4: Install Full Xcode**
Visit App Store and search for "Xcode"
Or download from: https://developer.apple.com/download/

---

## Issue 3: "CocoaPods not installed"

### Symptoms
```
✗ CocoaPods not installed
  CocoaPods is a package manager for iOS or macOS platform code
```

### Solutions

**Solution 1: Homebrew Installation (Recommended)**
```bash
brew install cocoapods
```

**Solution 2: RubyGems Installation**
```bash
sudo gem install cocoapods
```

**Verification:**
```bash
pod --version
```

---

## Issue 4: "Version solving failed" (Dependency Conflict)

### Symptoms
```
Because no versions of youtube_player_flutter match >8.1.2 <9.0.0 and 
youtube_player_flutter 8.1.2 depends on flutter_inappwebview ^5.7.2+3, 
version solving failed.
```

### Solution
This is **ALREADY FIXED** in pubspec.yaml:
```yaml
flutter_inappwebview: ^5.8.0  # Downgraded to compatible version
youtube_player_flutter: ^8.1.2  # In dependencies, not dev_dependencies
```

**If you still get this error:**
```bash
flutter clean
rm pubspec.lock
flutter pub get
```

---

## Issue 5: "Pod install fails"

### Symptoms
```
Error: Pod install failed in ios/Podfile
```

### Solutions

**Solution 1: Clean and Reinstall**
```bash
cd ios
rm -rf Podfile.lock Pods
pod install
cd ..
flutter run
```

**Solution 2: Update CocoaPods**
```bash
sudo gem install cocoapods
cd ios
pod repo update
pod install
cd ..
```

**Solution 3: Fix File Permissions**
```bash
cd ios
sudo chown -R $(whoami) .
pod install
cd ..
```

---

## Issue 6: "Flutter not found in PATH"

### Symptoms
```
bash: flutter: command not found
```

### Solutions

**Solution 1: Add to PATH (Temporary)**
```bash
export PATH="$PATH:~/code/flutter/bin"
flutter --version
```

**Solution 2: Add to PATH (Permanent)**
```bash
# For zsh (modern macOS)
echo 'export PATH="$PATH:~/code/flutter/bin"' >> ~/.zshrc
source ~/.zshrc

# For bash (older macOS)
echo 'export PATH="$PATH:~/code/flutter/bin"' >> ~/.bashrc
source ~/.bashrc
```

**Verification:**
```bash
which flutter
flutter --version
```

---

## Issue 7: "Emulator won't start"

### Symptoms
```
Error: Emulator failed to start
QEMU process not responding
```

### Solutions

**Solution 1: Kill and Restart**
```bash
killall qemu-system-x86_64
sleep 2
flutter emulators --launch <name>
```

**Solution 2: Clear Emulator Data**
```bash
rm -rf ~/.android/avd/*
flutter emulators
flutter emulators --launch <name>
```

**Solution 3: Create New Emulator**
```bash
# Via Android Studio: Tools → AVD Manager → Create Virtual Device
# Select: Pixel 6 Pro
# Select: Android 14 (API 34)
# Click: Finish
# Click: Play button
```

**Solution 4: Check CPU Virtualization**
- Intel Mac: Check BIOS for VT-x enabled
- Apple Silicon: Not needed (already enabled)

---

## Issue 8: "Tests fail to run"

### Symptoms
```
Error: flutter test failed
Failed to run tests
```

### Solutions

**Solution 1: Clean and Try Again**
```bash
flutter clean
flutter pub get
flutter test
```

**Solution 2: Run with Verbose Output**
```bash
flutter test --verbose
```

**Solution 3: Run Single Test**
```bash
flutter test test/unit_tests.dart -v
```

**Solution 4: Check for Errors**
```bash
flutter analyze
dart analyze
```

---

## Issue 9: "App won't build"

### Symptoms
```
Build failed
Gradle build failed
Swift compilation error
```

### Solutions

**Solution 1: Clean Everything**
```bash
flutter clean
flutter pub get
cd android && ./gradlew clean
cd .. && flutter build apk
```

**Solution 2: For iOS**
```bash
flutter clean
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
flutter run
```

**Solution 3: Check Dart**
```bash
flutter analyze
dart analyze
```

**Solution 4: Update Gradle (Android)**
```bash
cd android/gradle/wrapper/gradle-wrapper.properties
# Ensure gradle-7.0 or higher
cd ../..
./gradlew --version
```

---

## Issue 10: "Debugger won't connect"

### Symptoms
```
Observatory not reachable
Debugger failed to connect
```

### Solutions

**Solution 1: Use Verbose Mode**
```bash
flutter run -v
```

**Solution 2: Increase Timeout**
```bash
flutter run --verbose --target-platform=android --device-timeout=30
```

**Solution 3: Kill and Restart**
```bash
flutter run
# Press 'q' to quit
flutter run
```

**Solution 4: Check Firewall**
- macOS Firewall might block Observatory port 8181
- System Preferences → Security & Privacy → Firewall

---

## General Troubleshooting Steps

### 1. Always Start With
```bash
flutter doctor -v
```
This shows all issues clearly.

### 2. Clean Build Cache
```bash
flutter clean
rm pubspec.lock
flutter pub get
```

### 3. Check Dart/Flutter Versions
```bash
flutter --version
dart --version
```

### 4. Update Everything
```bash
flutter upgrade
flutter pub upgrade
```

### 5. Check System Requirements
```bash
uname -a                    # System info
xcode-select -p             # Xcode path
pod --version              # CocoaPods version
flutter doctor --verbose   # Full Flutter info
```

### 6. Restart Terminal
```bash
# Close and open new terminal
# This helps with PATH issues
```

---

## Quick Reference Matrix

| Issue | Quick Fix | Detailed Guide |
|-------|-----------|-----------------|
| Android SDK not found | `flutter config --android-sdk ~/Library/Android/sdk` | Section 1 |
| Xcode not found | `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer` | Section 2 |
| CocoaPods not found | `brew install cocoapods` | Section 3 |
| Dependency conflict | `flutter clean && flutter pub get` | Section 4 |
| Pod install fails | `cd ios && pod install && cd ..` | Section 5 |
| Flutter not in PATH | `export PATH="$PATH:~/code/flutter/bin"` | Section 6 |
| Emulator won't start | `killall qemu-system-x86_64 && flutter emulators --launch <name>` | Section 7 |
| Tests fail | `flutter test --verbose` | Section 8 |
| Build fails | `flutter clean && flutter pub get` | Section 9 |
| Debugger fails | `flutter run -v` | Section 10 |

---

## When All Else Fails

```bash
# Nuclear option - complete reset
flutter clean
rm -rf pubspec.lock
rm -rf ios/Pods ios/Podfile.lock
rm -rf android/.gradle android/build

# Then restart
flutter pub get
cd ios && pod install && cd ..
flutter run -v
```

---

## Getting Help

1. **Check Documentation**: SETUP_GUIDE.md, ANDROID_STUDIO_XCODE_SETUP.md
2. **Run flutter doctor**: `flutter doctor -v`
3. **Check logs**: Look for error messages carefully
4. **Search online**: Most Flutter issues have solutions on StackOverflow
5. **Ask for help**: Include full `flutter doctor -v` output

---

## Prevention Tips

1. Keep Flutter updated: `flutter upgrade`
2. Keep packages updated: `flutter pub upgrade`
3. Use version constraints in pubspec.yaml
4. Run `flutter analyze` regularly
5. Test before committing
6. Use `make pre-commit` before git commits

---

**Last Updated**: February 15, 2026
**Flutter Version**: 3.41.1+
**Dart Version**: 3.11.0+
