# ADR-002: Remote Content & Configuration Strategy

**Status:** Accepted  
**Date:** 2026-06-01  
**Branch:** current multi-series app

---

## Problem

Several things in the Al-Tawheed app are hardcoded in Dart source code that should be remotely configurable:

- Contact email, Play Store URL, website URL, share message text (all in `settings_screen.dart`)
- Feature flags for rollout controls (downloads, study mode, etc.)
- In-app announcements and notifications
- Daily benefits supplied by the catalog (the app tolerates an empty list)

Any change to these requires a new Play Store / App Store release. This ADR defines the strategy to make the app a **stable shell** where content and configuration are driven from Cloudflare Pages JSON files.

---

## Architecture

```
Al-Tawheed-Content (GitHub)
  └── Cloudflare Pages → https://content.kitabattawheed.com
        ├── tawheed/catalog.json          ← lectures, chapters, benefits (exists)
        ├── tawheed/app-config.json       ← links, contact, share text
        ├── tawheed/feature-flags.json    ← remote feature toggles
        ├── tawheed/announcements.json    ← in-app banners/notices
        └── series.json                   ← edition manifest and catalog URLs
```

Audio files remain on Cloudflare R2 (unchanged).  
All JSON files are public, static, read-only. **No secrets ever in the content repo.**

---

## Content Repository Structure

```
Al-Tawheed-Content/
├── _headers
├── tawheed/
│   ├── catalog.json           # EXISTS — lectures, chapters, benefits
│   ├── cover.jpg              # EXISTS — book cover
│   ├── app-config.json        # links and branding
│   ├── feature-flags.json     # rollout flags
│   ├── announcements.json     # optional notices
│   └── audio/
│       └── lec-001.mp3 … lec-050.mp3   # on R2, not in Pages
```

**Naming convention:** kebab-case, versioned via `version` field inside each JSON. URLs never change — content inside evolves.

`series.json` is fetched from the CDN root. Each entry names an edition,
language, storage prefix, capabilities (`hasBook`/`hasStudyMode`), and its
catalog URL. The active edition's catalog is fetched separately; catalog cache
keys are namespaced by series id (with the legacy Urdu `catalog` key retained
for upgrade compatibility). The manifest itself uses the `series_manifest`
cache key and the same stale-while-revalidate policy.

---

## JSON Schemas

### app-config.json

Controls all links, contact details, and static text currently hardcoded in Dart.

```json
{
  "version": 1,
  "updatedAt": "2026-06-01T00:00:00Z",
  "links": {
    "playStore": "https://play.google.com/store/apps/details?id=com.almarfa.tawheed",
    "appStore": null,
    "website": "https://kitabattawheed.com",
    "youtube": "https://www.youtube.com/channel/UCCCp4iPyMgqduVahr2gmLVw"
  },
  "contact": {
    "email": "arif.mohammed@gmail.com",
    "subject": "Sharah Kitab at-Tawheed — Feedback"
  },
  "share": {
    "message": "The *Sharah Kitab at-Tawheed* app — 50 audio lectures of Fazilat Shaikh Abdullah Nasir Rahmani Hafizahullah.\n\nDownload: https://play.google.com/store/apps/details?id=com.almarfa.tawheed"
  },
  "about": {
    "appName": "Sharah Kitab at-Tawheed",
    "lecturer": "Fazilat Shaikh Abdullah Nasir Rahmani Hafizahullah",
    "lectureCount": 50,
    "totalDuration": "27h 7m"
  }
}
```

### feature-flags.json

Controls which features are visible. Evaluated client-side only.  
Safe defaults (stable = `true`, experimental = `false`) are hardcoded in Dart as fallback.

```json
{
  "version": 1,
  "updatedAt": "2026-06-01T00:00:00Z",
  "features": {
    "bookmarks": true,
    "downloads": true,
    "studyMode": false,
    "dailyBenefits": true,
    "announcements": true,
    "shareButton": true,
    "shareLectureRow": true,
    "playbackSpeed": true,
    "continueListening": true,
    "language": true,
    "appLinks": false
  },
  "experimental": {
    "arabicTranslations": false,
    "crossDeviceSync": false,
    "searchLectures": false,
    "multiSeries": false
  }
}
```

### announcements.json

Time-gated, platform-filtered in-app banners displayed on the lectures surface.

```json
{
  "version": 1,
  "updatedAt": "2026-06-01T00:00:00Z",
  "announcements": [
    {
      "id": "ann-001",
      "type": "info",
      "title": "iOS App Coming Soon",
      "body": "The app will be available on the App Store shortly. JazakAllahu Khayran for your patience.",
      "ctaLabel": null,
      "ctaUrl": null,
      "validFrom": "2026-06-01T00:00:00Z",
      "validUntil": "2026-12-31T00:00:00Z",
      "platforms": ["android"]
    }
  ]
}
```

---

## Caching Strategy

| File | Cloudflare TTL | App-side TTL | Behaviour |
|---|---|---|---|
| `catalog.json` | 1 hour | 1 hour | Stale-while-revalidate |
| `app-config.json` | 1 hour | 1 hour | Stale-while-revalidate |
| `feature-flags.json` | 5 min | 5 min | Stale-while-revalidate |
| `announcements.json` | 30 min | 30 min | Stale-while-revalidate |
| `series.json` | 1 hour | 1 hour | Stale-while-revalidate; cache key `series_manifest` |
| `audio/*.mp3` | Immutable | Forever | Never expire |

**App-side:** Raw JSON strings cached in `SharedPreferences` with `_fetched_at` timestamp.  
On startup: serve cache immediately → fetch in background → update UI silently.

**SharedPreferences keys:**
```
cache_catalog_json            cache_catalog_fetched_at (legacy Urdu)
cache_catalog_<series>_json   cache_catalog_<series>_fetched_at
cache_app_config_json         cache_app_config_fetched_at
cache_feature_flags_json      cache_feature_flags_fetched_at
cache_announcements_json      cache_announcements_fetched_at
cache_series_manifest_json    cache_series_manifest_fetched_at
```

---

## Offline Strategy

| Scenario | Behaviour |
|---|---|
| First launch, no network and no cache | Clear error state with retry button |
| Returning user, no network | Load cached catalog/config instantly |
| Network lost mid-session | Already-loaded content works; audio may pause |
| Fetch fails, cache fresh | Serve cache silently; no user-facing error |

---

## Feature Flag Strategy

- `FeatureFlagsProvider extends ChangeNotifier` — same pattern as `CatalogProvider`
- Hardcoded safe defaults applied first; remote flags overlay on fetch
- Gate: `context.watch<FeatureFlagsProvider>().features.bookmarks`
- Flags use safe defaults while fetching; series-aware welcome content may wait
  for definitive flags/manifest resolution to avoid an incorrect first frame.

---

## Versioning

- Catalog, app-config, feature-flags, and announcements JSON each have
  `"version": N` and a corresponding `maxSupported*Version` constant in
  `lib/app_config.dart`.
- The series manifest is currently unversioned and unchecked.
- Breaking changes (rename/remove field) → increment version. An unsupported
  catalog version becomes a catalog update error; unsupported app-config and
  feature-flag versions keep safe defaults, while unsupported announcements are
  ignored. A malformed or empty series manifest falls back to the bundled Urdu
  edition so onboarding is not blocked.
- Additive changes (new optional field) → no version bump needed
- Audio files on R2: never mutate in-place; use a new filename if content changes

---

## Flutter Provider Architecture

```
main()
  └── PreferencesService.init()
        └── runApp(MyApp)
              └── MultiProvider
                    ├── CatalogProvider          (exists)  — catalog.json
                    ├── AppConfigProvider         (shipped) — app-config.json
                    ├── FeatureFlagsProvider      (shipped) — feature-flags.json
                    ├── AnnouncementsProvider     (shipped) — announcements.json
                    ├── ProgressProvider          (exists)  — SharedPreferences
                    └── PlayerNotifier            (exists)  — audio
```

Each provider: **cache → fetch in background → notify**. Initial flags and
series resolution are the exception: WelcomeScreen may wait until they are
definitive to prevent painting the wrong edition for one frame. A cached or
fallback manifest still keeps onboarding available offline.

---

## Website Sharing

The mobile app consumes the custom HTTPS CDN domain below (the website may use
the content repo at build time):

```
https://content.kitabattawheed.com/tawheed/catalog.json
https://content.kitabattawheed.com/tawheed/app-config.json
```

Website fetches at build time (SSG) or at runtime (client-side). No backend. The content repo is the shared content layer for both surfaces.

---

## Phased Rollout

### Historical rollout (complete)
1. Create `app-config.json` and `feature-flags.json` in Al-Tawheed-Content
2. Add `AppConfigProvider` and `FeatureFlagsProvider` to Flutter app
3. Replace all hardcoded links/email/text in `settings_screen.dart` with provider reads
4. Gate all planned-but-not-built features behind `FeatureFlagsProvider`

**Outcome:** All links and contact info updatable without a Play Store/App Store release.

### Phase 2 — Catalog Enrichment + Caching (~2 days, medium)
1. Add 30+ daily benefits to `catalog.json`
2. Add `textArabic` to `DailyBenefit` Dart model (field already in JSON)
3. Add lecture descriptions for key lectures
4. Implement stale-while-revalidate cache layer across all providers

**Outcome:** App works fully offline; daily benefits rotate meaningfully.

### Phase 3 — Announcements + Website Foundation (~2 days)
1. ~~Create `announcements.json`; build `AnnouncementsProvider`; add banner~~ (shipped)
2. Implement date-range and platform filtering
3. Define shared content contract for the future website

**Outcome:** Can push in-app notices without any app release.

---

## Security

- All JSON files are public read-only static assets — no auth needed
- **Never put secrets, API keys, or private data in the content repo**
- Cloudflare provides automatic HTTPS — no mixed content possible
- Feature flags are client-side only — they hide UI, they do not protect server resources

---

## Risks

| Risk | Mitigation |
|---|---|
| Flag fetch delayed → wrong UI state | Hardcoded safe defaults always apply first |
| Cloudflare Pages outage | Cache serves stale content; app still functional |
| Breaking schema without version bump | Code review rule: always bump version on rename/remove |
| Secrets accidentally committed | Documented policy: no secrets in content repo, ever |
| Cache size growth | Raw JSON is < 50 KB total; not a concern for SharedPreferences |
