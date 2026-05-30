# Android Studio & Xcode Setup Guide

## Prerequisites Checklist

- ✅ Flutter 3.41.1 (already installed)
- ✅ Dart 3.11.0 (already installed)
- ❌ Android Studio (need to install)
- ❌ Android SDK (need to install)
- ❌ Xcode (need to install)
- ❌ CocoaPods (need to install)

---

## Part 1: Setup Android Studio & Android SDK

### Step 1: Install Android Studio

**Option A: Using Homebrew (Recommended)**
```bash
brew install android-studio
```

**Option B: Manual Download**
1. Visit: https://developer.android.com/studio
2. Download Android Studio for macOS
3. Drag to Applications folder
4. Launch Android Studio

### Step 2: Complete Android Studio Setup

After launching Android Studio:

1. **Accept License Agreements**
   - Android Studio will prompt you to accept licenses
   - Click "Accept" for all

2. **Install Android SDK Components**
   - Open Android Studio
   - Go to: **Android Studio → Preferences** (or **Android Studio → Settings** on newer versions)
   - Navigate to: **Appearance & Behavior → System Settings → Android SDK**
   - Under "SDK Platforms" tab, ensure you have:
     - ✅ Android 14 (API 34) - Required for our app
     - ✅ Android 13 (API 33)
   - Click "Apply" and "OK"

3. **Install SDK Tools**
   - In Android SDK settings, click "SDK Tools" tab
   - Ensure these are checked:
     - ✅ Android SDK Platform Tools (latest)
     - ✅ Android SDK Build Tools (34.0.0 or higher)
     - ✅ Android Emulator
     - ✅ Google Play Services (optional but recommended)
   - Click "Apply" and "OK"

### Step 3: Set Flutter Android SDK Path

After Android Studio setup:

```bash
flutter config --android-sdk /Users/mohammadarif/Library/Android/sdk
```

### Step 4: Verify Android Setup

```bash
flutter doctor --android-licenses
# Accept all licenses by typing 'y'
```

Then run:
```bash
flutter doctor
```

Expected output:
```
[✓] Android toolchain - develop for Android devices
```

---

## Part 2: Setup Xcode & iOS Development

### Step 1: Install Xcode

**Option A: App Store (Recommended)**
```bash
# Open App Store and search for "Xcode"
# Or use this shortcut:
open "macappstore://apps.apple.com/app/xcode/id497799835"
```

**Option B: Command Line Tools Only (if you don't want full Xcode)**
```bash
xcode-select --install
```

**Option C: Download from Apple Developer**
1. Visit: https://developer.apple.com/download/
2. Sign in with Apple ID
3. Search for "Xcode"
4. Download and install

### Step 2: Complete Xcode Setup

After installation, run:

```bash
# Switch Xcode path
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

# Accept Xcode license
sudo xcode-select --reset

# Accept all licenses
sudo xcodebuild -license accept

# Run first launch setup
sudo xcode-select --install
```

### Step 3: Install CocoaPods

**Option A: Using Homebrew (Recommended)**
```bash
brew install cocoapods
```

**Option B: Using Ruby Gems**
```bash
sudo gem install cocoapods
```

### Step 4: Verify Xcode Setup

```bash
flutter doctor
```

Expected output:
```
[✓] Xcode - develop for iOS and macOS
[✓] CocoaPods
```

---

## Part 3: Complete Flutter Setup

### Step 1: Run Flutter Doctor

```bash
flutter doctor -v
```

You should see:
```
[✓] Flutter (Channel stable)
[✓] Android toolchain
[✓] Xcode
[✓] Chrome
[✓] Connected device
[✓] Network resources
```

### Step 2: Accept Android Licenses

```bash
flutter doctor --android-licenses
# Type 'y' for each license
```

### Step 3: Get Project Dependencies

```bash
cd /Users/mohammadarif/code/Al-Tawheed
flutter clean
flutter pub get
```

You should see all packages resolving successfully.

---

## Part 4: Setup Android Emulator (Optional but Recommended)

### Create Android Emulator

```bash
# List available emulators
flutter emulators

# If you have none, create one via Android Studio:
```

**Via Android Studio GUI:**
1. Open Android Studio
2. Click: **Tools → AVD Manager**
3. Click: **Create Virtual Device**
4. Select: **Pixel 6 Pro** (or any modern device)
5. Select: **Android 14 (API 34)**
6. Click: **Finish**
7. Click: **Play** button to launch

**Via Command Line:**
```bash
# List available system images
$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager --list | grep "system-images"

# Create emulator (example)
echo "no" | $ANDROID_SDK/tools/bin/avdmanager create avd \
  -n flutter_emulator \
  -k "system-images;android-34;google_apis;x86_64" \
  -d "Pixel 6 Pro"
```

### Launch Android Emulator

```bash
flutter emulators --launch flutter_emulator
# Or use Android Studio's AVD Manager
```

---

## Part 5: Running the App

### On Android Emulator

```bash
# 1. Launch emulator first
flutter emulators --launch <emulator_name>

# 2. Wait for it to fully boot (2-3 minutes)

# 3. Run the app
cd /Users/mohammadarif/code/Al-Tawheed
flutter run
```

### On iOS Simulator

```bash
# 1. Launch iOS simulator
open -a Simulator

# 2. Wait for it to boot

# 3. Run the app
cd /Users/mohammadarif/code/Al-Tawheed
flutter run -d iPhone
```

### On Physical Device

**Android:**
1. Enable Developer Mode: Settings → About → Tap Build Number 7 times
2. Enable USB Debugging: Settings → Developer Options → USB Debugging
3. Connect via USB
4. Trust the computer when prompted
5. Run: `flutter run`

**iOS:**
1. Connect iPhone via USB
2. Trust the computer
3. Run: `flutter run -d <device_name>`

---

## Part 6: Troubleshooting

### Android Issue: "Android SDK not found"

```bash
# Find your Android SDK path
find ~ -name "android-sdk" -o -name "Android"

# Set Flutter config
flutter config --android-sdk /path/to/sdk
```

### iOS Issue: "Xcode not found"

```bash
# Fix Xcode path
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcode-select --reset
```

### CocoaPods Issue: "Pod install fails"

```bash
cd ios
rm -rf Podfile.lock Pods
pod install
cd ..
flutter run
```

### Emulator Issue: "Emulator not starting"

```bash
# Kill all emulator processes
killall qemu-system-x86_64

# Clear emulator cache
rm -rf ~/.android/avd/*

# Launch again
flutter emulators --launch <name>
```

### Package Resolution Issue: "Version solving failed"

```bash
# Clean and try again
flutter clean
rm pubspec.lock
flutter pub get
```

---

## Part 7: Running Setup Script Successfully

Once everything is installed, run:

```bash
cd /Users/mohammadarif/code/Al-Tawheed
bash setup.sh
```

Expected output:
```
========================================
Al-Tawheed Flutter App - Complete Setup
========================================

✓ Flutter found
✓ Dart found
✓ Xcode Command Line Tools found
✓ CocoaPods found

========================================
Setting Up Project
========================================
✓ Dependencies installed
✓ iOS setup complete
✓ Code analysis complete
✓ All tests passed
✓ Setup complete!
```

---

## Part 8: Verification Commands

Run these to verify everything works:

```bash
# Check all tools
flutter doctor -v

# Get dependencies
flutter pub get

# Analyze code
flutter analyze

# Run tests
flutter test

# Run on device
flutter run
```

---

## Quick Command Reference

| Task | Command |
|------|---------|
| Install Android Studio | `brew install android-studio` |
| Install Xcode CLI Tools | `xcode-select --install` |
| Install CocoaPods | `brew install cocoapods` |
| Set Android SDK path | `flutter config --android-sdk /path/to/sdk` |
| Accept Android licenses | `flutter doctor --android-licenses` |
| Fix Xcode path | `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer` |
| List emulators | `flutter emulators` |
| Launch emulator | `flutter emulators --launch <name>` |
| Create iOS simulator | `xcrun simctl create "iPhone 15" "iPhone 15" "iOS17.2"` |
| Open iOS simulator | `open -a Simulator` |
| Run app | `flutter run` |
| Check everything | `flutter doctor -v` |

---

## Estimated Time

- Android Studio + SDK: **30-45 minutes** (mostly downloading)
- Xcode: **20-60 minutes** (depending on internet speed)
- CocoaPods: **5-10 minutes**
- Total: **1-2 hours**

---

## Support

If you encounter issues:

1. **Run Flutter Doctor**: `flutter doctor -v` (shows all issues)
2. **Check Documentation**: See SETUP_GUIDE.md
3. **Clean Cache**: `flutter clean && flutter pub get`
4. **Restart Terminal**: Close and reopen terminal

---

**Next Steps:**
1. Install Android Studio & Xcode
2. Accept licenses
3. Create Android Emulator
4. Run `flutter doctor` again
5. Run `bash setup.sh`

You're almost there! 🚀
