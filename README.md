# Sharah Kitab al-Tawheed

A native Android/iOS mobile app consolidating the Sharah Kitaab al-Tawheed YouTube lectures of Fazilat Shaikh Abdullah Nasir Rahmani Hafizahullah.

**Play Store:** https://play.google.com/store/apps/details?id=com.almarfa.tawheed  
**YouTube Channel:** https://www.youtube.com/channel/UCCCp4iPyMgqduVahr2gmLVw

---

## Project Structure

```
lib/
  main.dart                  # App entry point, routes, AppTheme wiring
  theme/
    app_colors.dart          # Single source of truth for brand colours
    app_theme.dart           # ThemeData (AppBar, ElevatedButton styles)
  screens/
    welcome.dart             # Splash/landing screen
    home_video_screen.dart   # Video list (fetches from YouTube API)
    video_screen.dart        # YouTube player with auto-advance
    main_drawer.dart         # Side drawer (contact, rate, share, YouTube card)
  models/
    channel_model.dart
    video_model.dart
  services/
    api_service.dart         # YouTube Data API v3 calls
  utilities/
    keys.dart                # ← GITIGNORED — must be created locally
```

---

## Local Setup

### 1. YouTube API Key

Create `lib/utilities/keys.dart` (gitignored — never commit):

```dart
const String API_KEY = 'YOUR_YOUTUBE_DATA_API_V3_KEY';
```

### 2. Android signing (release builds only)

Create `android/key.properties` (gitignored):

```
storePassword=...
keyPassword=...
keyAlias=...
storeFile=path/to/keystore.jks
```

### 3. Install dependencies

```bash
flutter pub get
```

### 4. Run

```bash
flutter run -d <device-id>
```

---

## Theming

All brand colours live in `lib/theme/app_colors.dart` as **getters** (not `static final` — getters are re-evaluated on every access, enabling hot reload to pick up colour changes immediately):

```dart
static Color get primary => Colors.limeAccent.shade700;
```

To change the brand colour across the entire app, edit that one line.

`AppTheme.light` (in `lib/theme/app_theme.dart`) wires AppBar background, button colours, and title style into `ThemeData` so individual screens need no colour arguments.

---

## Android Build Notes

| Setting | Value | File |
|---|---|---|
| Gradle | 8.14 | `gradle-wrapper.properties` |
| AGP | 8.11.1 | `settings.gradle` |
| Kotlin | 2.2.20 | `settings.gradle` |
| compileSdk | 36 | `app/build.gradle` |
| targetSdk | 35 | `app/build.gradle` |
| NDK | 28.2.13676358 | `app/build.gradle` |
| Java/Kotlin JVM target | 21 | `app/build.gradle` |

**Built-in Kotlin** is enabled (`android.builtInKotlin=true` in `gradle.properties`). Flutter's Gradle plugin manages Kotlin compilation — do **not** add `id "org.jetbrains.kotlin.android"` to `app/build.gradle`.

**Kotlin incremental compilation is disabled** (`kotlin.incremental=false`) to avoid a Windows-specific crash that occurs when the project is on a different drive (e.g. `D:`) from the Pub cache (`C:`). The Kotlin daemon cannot compute relative paths across drive roots.

**KGP warnings** for `share_plus` and `url_launcher_android` are third-party plugin issues and cannot be fixed from this project. They are warnings only and do not block builds.

---

## Known Warnings (not actionable from this project)

- `share_plus` and `url_launcher_android` apply Kotlin Gradle Plugin directly — plugin authors need to migrate.
- A few transitive packages (`meta`, `matcher`, `vector_math`, `test_api`) have newer versions with constraints incompatible with our direct deps — no action needed.

---

## Documentation

Full guides are in [docs/](docs/README.md).

| | |
|---|---|
| [Setup](docs/setup.md) | Environment, dependencies, API key |
| [CI/CD](docs/ci-cd.md) | Pipelines, pre-push hook, release workflow |
| [Git workflow](docs/git-workflow.md) | Branching, commits, PRs |
| [Testing](docs/testing.md) | Running and writing tests |
| [Troubleshooting](docs/troubleshooting.md) | Common errors and fixes |

---

## Lecture Info

کل مدت : ستائیس گھنٹے سات منٹ ہے
