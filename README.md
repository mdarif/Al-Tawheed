# Sharah Kitab al-Tawheed — شرح کتاب التوحید

[![CI](https://github.com/mdarif/Al-Tawheed/actions/workflows/flutter-ci.yml/badge.svg)](https://github.com/mdarif/Al-Tawheed/actions/workflows/flutter-ci.yml)
[![codecov](https://codecov.io/gh/mdarif/Al-Tawheed/graph/badge.svg)](https://codecov.io/gh/mdarif/Al-Tawheed)

**Al Marfa Duroos** — a free offline-first audio app for the complete Sharah Kitab al-Tawheed lecture series by Shaikh Abdullah Nasir Rahmani Hafizahullah. Stream or download all 50 lectures, follow the structured study programme class by class, and listen with full lock-screen and notification controls.

**[kitabattawheed.com](https://kitabattawheed.com)** &nbsp;·&nbsp;
**[Play Store](https://play.google.com/store/apps/details?id=com.almarfa.tawheed)** &nbsp;·&nbsp;
**[YouTube — Al Marfa Duroos](https://www.youtube.com/@almarfaduroos)** &nbsp;·&nbsp;
**[Al Marfa Technologies](http://almarfa.co)**

---

<p align="center">
  <img src="docs/play-store/Phone%20Screenshots%20/v2-thin-bezel/01-welcome-framed.png" width="30%" alt="Welcome screen" />
  &nbsp;&nbsp;
  <img src="docs/play-store/Phone%20Screenshots%20/v2-thin-bezel/03-player-framed.png" width="30%" alt="Audio player" />
  &nbsp;&nbsp;
  <img src="docs/play-store/Phone%20Screenshots%20/v2-thin-bezel/04-home-framed.png" width="30%" alt="Home screen" />
</p>

---

## Features

- **50 lectures · 27+ hours** — the complete Sharah Kitab al-Tawheed series
- **Offline playback** — download any lecture for listening without a connection
- **Study Mode** — 15 structured classes to work through the series systematically
- **Background audio** — lock-screen controls and notification transport on Android and iOS
- **Multilingual** — English, Urdu, and Roman Urdu interface
- **Daily Benefit** — a rotating Quranic reminder on the home screen
- **Bookmarks** — save any lecture to revisit later
- **Variable speed** — 0.75× to 2.0× playback

---

## Architecture

UI screens never talk to services directly — all shared state flows through
`provider`/`ChangeNotifier` providers, which wrap the services that do
networking, persistence, and playback. `lib/app.dart` wires the full provider
tree with explicit dependency ordering.

```
lib/
  app.dart, app_config.dart, main.dart   # App shell, remote config, entry point
  screens/                               # Routed pages (home, player, library, settings …)
  widgets/                               # Reusable UI pieces (lecture tiles, offline sheet …)
  providers/                             # ChangeNotifier state: catalog, downloads, progress,
                                         #   connectivity, language, theme, feature flags …
  services/                              # Networking, persistence, downloads, notifications
  audio/                                 # just_audio / audio_service integration
  models/                                # Data classes (lecture/catalog, announcements …)
  theme/                                 # AppColors, ThemeData, Typography
  l10n/                                  # Localization resources (ARB files)
```

**Remote config** — all brand strings, feature flags, and content URLs are driven
from a CDN JSON file (`app-config.json`). Branding and feature changes require no
app release.

**Offline-first** — `ConnectivityProvider` and `DownloadsProvider` drive download
state. `RemoteContentService` serves the catalog with a stale-while-revalidate
strategy so the app always opens instantly.

**Singletons** — `PreferencesService`, `CatalogService`, and
`DownloadNotificationService` are singletons (`.instance`) rather than
constructor-injected. They must be initialised synchronously before the
`MultiProvider` tree is built — this is a deliberate exception, not an oversight.

---

## Local Setup

```bash
flutter pub get
flutter run -d <device-id>
```

Android release signing requires `android/key.properties` (gitignored).
See [docs/setup.md](docs/setup.md) for the full environment setup including
signing and platform-specific notes.

---

## Testing

```bash
flutter test                                         # unit + widget tests
flutter test integration_test/app_test.dart -d <id> # end-to-end on device
```

---

## Documentation

| | |
|---|---|
| [Setup](docs/setup.md) | Environment, dependencies, signing |
| [CI/CD](docs/ci-cd.md) | Pipelines, pre-push hook, release workflow |
| [Deployment](docs/deployment.md) | Store listings, release process |
| [Git workflow](docs/git-workflow.md) | Branching, commits, PRs |
| [Testing](docs/testing.md) | Running and writing tests |
| [i18n architecture](docs/i18n-architecture.md) | Multilingual content strategy |
| [Remote content strategy](docs/remote-content-strategy.md) | Catalog/announcement caching |
| [Troubleshooting](docs/troubleshooting.md) | Common errors and fixes |

---

<p align="center">
  Built by <a href="http://almarfa.co">Al Marfa Technologies</a> &nbsp;·&nbsp;
  <a href="https://kitabattawheed.com">kitabattawheed.com</a>
</p>
