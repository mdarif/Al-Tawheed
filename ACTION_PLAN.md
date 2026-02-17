# ✅ Action Plan - Get Your Project Running

## Current Status
- ✅ Package dependency fixed
- ❌ Android Studio not installed
- ❌ Xcode not fully configured
- ❌ CocoaPods not installed

## What You Need to Do (In Order)

### Step 1: Install Android Studio (15 min) 🟡 CRITICAL

**Commands:**
```bash
brew install --cask android-studio
# Wait for installation to complete (5-10 min)
```

**After Installation:**
1. Launch Android Studio
2. Accept initial setup prompts
3. Go to **Preferences → Android SDK**
4. Under "SDK Platforms" tab:
   - ✅ Check: Android 14 (API 34)
   - ✅ Check: Android 13 (API 33)
5. Under "SDK Tools" tab:
   - ✅ Check: Android SDK Platform Tools
   - ✅ Check: Android SDK Build Tools 34.0.0
6. Click "Apply" → "OK"
7. Wait for downloads (usually 5-10 min)

**Verification:**
```bash
ls -la ~/Library/Android/sdk/
# Should show: platforms, build-tools, etc.
```

---

### Step 2: Install/Configure Xcode (30-60 min) 🟡 CRITICAL

**Option A: Command Line Tools Only (Faster, ~20 min)**
```bash
xcode-select --install
# Click "Install" when prompted
# Wait for installation

sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer 2>/dev/null || true
sudo xcodebuild -license accept
```

**Option B: Full Xcode (Slower, ~1 hour but recommended)**
```bash
# Method 1: App Store (easiest)
open "macappstore://apps.apple.com/app/xcode/id497799835"
# Click "Get" → "Install"
# Wait for installation

# Then configure:
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
```

---

### Step 3: Install CocoaPods (3 min) 🟡 REQUIRED

```bash
brew install cocoapods
```

**Verification:**
```bash
pod --version
# Should output version like: 1.13.0
```

---

### Step 4: Configure Flutter (5 min) 🟡 IMPORTANT

```bash
# Set Android SDK path
flutter config --android-sdk ~/Library/Android/sdk

# Accept all Android licenses
flutter doctor --android-licenses
# Type 'y' for each license (6 times)

# Verify everything
flutter doctor -v
# Should show all ✓ (except maybe Android Virtual Device)
```

---

### Step 5: Get Project Dependencies (5 min) 🟡 IMPORTANT

```bash
cd /Users/mohammadarif/code/Al-Tawheed

# Clean everything
flutter clean
rm -f pubspec.lock

# Get dependencies
flutter pub get
# Should complete without errors ✅
```

**Expected output:**
```
Running "flutter pub get" in Al-Tawheed...         
Resolving dependencies...
  ... (lots of packages)
Got dependencies!
```

---

### Step 6: Run Setup Script (10 min) ✅ FINAL

```bash
bash setup.sh
```

**When asked:**
- "Run flutter doctor?" → Answer: **y**
- "Run tests?" → Answer: **y** (optional, **n** is fine)
- "Generate coverage?" → Answer: **n** (optional)

**Expected final output:**
```
============================================
Setup Complete! 🎉
============================================

Your Al-Tawheed project is ready!

Quick Start:
  flutter run              - Run on connected device
  flutter run -d emulator  - Run on Android emulator
  make help                - See all available commands
```

---

## Alternative: Quick Path (Skip Xcode for Now)

If you want to get running **today** on Android only:

```bash
# 1. Install Android Studio
brew install --cask android-studio
# Wait and configure as above

# 2. Install CocoaPods anyway (needed later)
brew install cocoapods

# 3. Configure Flutter
flutter config --android-sdk ~/Library/Android/sdk
flutter doctor --android-licenses

# 4. Get dependencies
cd /Users/mohammadarif/code/Al-Tawheed
flutter clean && flutter pub get

# 5. Create Android Emulator
# Via Android Studio: Tools → AVD Manager → Create Virtual Device
# Select: Pixel 6 Pro + Android 14 (API 34)

# 6. Run app
flutter run
```

This skips Xcode for now (you can install it later). You'll get warnings but can develop on Android.

---

## 🕐 Timeline

| Step | Time | Skip Possible? |
|------|------|---|
| 1. Android Studio | 15 min | ❌ NO (required) |
| 2. Xcode | 20-60 min | ⚠️ YES (skip for now) |
| 3. CocoaPods | 3 min | ⚠️ YES (but needed for iOS) |
| 4. Flutter Config | 5 min | ❌ NO (required) |
| 5. Get Dependencies | 5 min | ❌ NO (required) |
| 6. Setup Script | 10 min | ✅ Optional |
| **Total (All)** | **60-90 min** | |
| **Total (Android Only)** | **30-40 min** | |

---

## 📋 Verification Checklist

Before moving to next step, verify:

**After Android Studio:**
```bash
ls -la ~/Library/Android/sdk/platforms | grep android-34
# Should show: android-34
```

**After Xcode:**
```bash
xcode-select -p
# Should output: /Applications/Xcode.app/Contents/Developer
```

**After CocoaPods:**
```bash
pod --version
# Should output a version number
```

**After Flutter Config:**
```bash
flutter doctor
# Should show all ✓ (maybe no AVD yet)
```

**After Pub Get:**
```bash
flutter pub get
# Should complete without errors
```

---

## 🚀 Once Setup is Done

You can then:

```bash
# Run on Android emulator
flutter emulators --launch <name>
flutter run

# Run on iOS simulator
open -a Simulator
flutter run

# Or just run (auto-detects device)
flutter run

# Run tests
flutter test

# Build for release
make release-android
make release-ios
```

---

## 💡 Pro Tips

1. **Do installations in parallel**: While Android Studio is installing, download Xcode
2. **Use fast internet**: These downloads are large (3-5 GB total)
3. **Don't close terminal**: Let installations complete
4. **Accept all licenses**: Required for Flutter
5. **Read any error messages**: They usually tell you exactly what to do

---

## 🆘 If Something Goes Wrong

### Android Studio Installation Issues
```bash
# Show installation progress
brew install --cask android-studio --verbose

# If it hangs:
# Press Ctrl+C and retry
# Or download manually from https://developer.android.com/studio
```

### Xcode Installation Issues
```bash
# If xcode-select --install doesn't work:
# Download from App Store or https://developer.apple.com/download/

# If path is wrong:
sudo xcode-select --reset
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

### Dependency Issues
```bash
# If pub get fails:
flutter clean
rm pubspec.lock
flutter pub get

# Check what's wrong:
flutter pub cache repair
```

### Emulator Issues
```bash
# If emulator won't start:
killall qemu-system-x86_64
flutter emulators --launch <name>
```

---

## 📚 Documentation Reference

| Problem | Document | Section |
|---------|----------|---------|
| Need step-by-step guide | ANDROID_STUDIO_XCODE_SETUP.md | Full guide |
| Quick reference | QUICK_FIX.md | Quick steps |
| Something's broken | TROUBLESHOOTING.md | Issue solutions |
| Check your system | check-env.sh | Run script |
| Automate setup | setup-env.sh | Run script |

---

## ✨ You're Going to Make It! 

The setup looks complicated but mostly involves:
1. **Clicking "Install"** a few times ✓
2. **Waiting for downloads** ✓
3. **Accepting licenses** ✓
4. **Running a few commands** ✓

**Expected result**: A fully functional Flutter development environment 🎉

---

**Estimated Total Time: 1-2 hours** (mostly waiting for downloads)

**Next Steps:**
1. Start with Step 1 above
2. Follow each step in order
3. Ask if you get stuck (or check TROUBLESHOOTING.md)
4. Come back when you hit "Setup Complete!"

---

You've got this! 💪
