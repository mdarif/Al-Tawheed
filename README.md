# Sharah Kitab al-Tawheed

A native Android/iOS audio lecture player for the Sharah Kitaab al-Tawheed
series by Fazilat Shaikh Abdullah Nasir Rahmani Hafizahullah — offline-first,
multilingual (English / Urdu / Roman Urdu), with background playback and
download management.

**Play Store:** https://play.google.com/store/apps/details?id=com.almarfa.tawheed
**YouTube Channel:** https://www.youtube.com/channel/UCCCp4iPyMgqduVahr2gmLVw

---

## Architecture

UI screens never talk to services directly — they read shared state through
`provider`/`ChangeNotifier` providers, which in turn wrap the services that
do networking, persistence, and playback. `lib/app.dart` wires the full
provider tree with explicit dependency ordering.

```
lib/
  app.dart, app_config.dart, main.dart   # App shell, config, entry point
  screens/                               # Routed pages (home, player, library, settings, ...)
  widgets/                               # Reusable UI pieces (lecture tiles, offline sheet, ...)
  providers/                             # ChangeNotifier state: catalog, downloads, progress,
                                         #   connectivity, language, theme, feature flags, ...
  services/                              # Networking, persistence, downloads, notifications
  audio/                                 # just_audio / audio_service integration (handler,
                                         #   playback orchestration, queue/source modelling)
  models/                                # Data classes (lecture/catalog, announcements, i18n fields)
  data/                                  # Bundled/overlay content (e.g. client-side i18n overlays)
  theme/                                 # AppColors, ThemeData
  utils/, utilities/                     # Small pure helpers
  l10n/                                  # Localization resources
```

A few services (`PreferencesService`, `CatalogService`,
`DownloadNotificationService`) are exposed as singletons via `.instance`
rather than constructor-injected. They need to be initialised synchronously
*before* the `MultiProvider` tree exists (see `lib/main.dart`), which
Provider-based DI cannot express — this is a deliberate exception, not an
oversight.

State management is Provider/`ChangeNotifier` throughout; `setState` is used
only for genuinely ephemeral local widget state (e.g. dismiss animations,
in-progress async UI flags).

Offline-first is a first-class concern: `ConnectivityProvider` and
`DownloadsProvider` drive download state and an offline UI (offline library
screen, offline player strip, offline sheet), and `RemoteContentService`
serves cached catalog/announcement content with a stale-while-revalidate
strategy.

---

## Local Setup

```bash
flutter pub get
flutter run -d <device-id>
```

Android release signing requires `android/key.properties` (gitignored — see
[docs/setup.md](docs/setup.md) for the full local environment setup,
including signing and platform-specific notes).

---

## Documentation

Full guides live in [docs/](docs/README.md):

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

## Lecture Info

کل مدت : ستائیس گھنٹے سات منٹ ہے
