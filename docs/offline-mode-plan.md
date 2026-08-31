# Offline mode — shipped design and follow-ups

**Status:** Shipped in the current app; remaining work is follow-up hardening.
**Feature flag:** `downloads` is enabled by the remote configuration (the Dart
default is also enabled).
**Goal:** Offline listening is prominent and understandable, especially when
the user loses network while in the player.

---

## 1. Problem statement

The app can play downloaded MP3s, stream from the CDN, detect connectivity,
show offline status, and manage saved lectures from the Offline Library.

### What works today

| Piece | Behaviour |
|-------|-----------|
| Storage | Per-series files under `{documents}/audio/{seriesId}/{lectureId}.mp3`; legacy Urdu keeps the unprefixed `audio/{lectureId}.mp3` layout |
| Playback | `PlayerNotifier` uses local file if downloaded, else stream |
| Catalog | Stale-while-revalidate JSON cache (offline OK if opened online before) |
| UI | Download icon on lecture row/player, chapter download, Offline Library, and Settings count/size |

### Remaining follow-ups

1. Physical-device airplane-mode QA and retry/recovery verification.
2. Analytics for download and offline-play events, if product telemetry is needed.
3. Persisting and resuming queued/chapter download jobs across process death (jobs are currently in memory).

---

## 2. Product goal

> Users can **reliably listen without network** for saved content, and **always understand** what will work offline — with clear guidance **from the player**.

User-facing name suggestion: **“Offline listening”** (not only “Downloads”).

---

## 3. Design principles

1. **Never surprise** — network loss → immediate, honest feedback + action.
2. **Offline is visible** — badges, player strip, optional app-bar pill.
3. **Prepare before you leave** — download this part / whole class from player.
4. **Graceful degradation** — disable or skip undownloaded content with clear copy.
5. **Wi‑Fi respectful** — the persisted “Download on Wi‑Fi only” setting is shipped.

---

## 4. Key user journeys

| ID | Journey | Target behaviour |
|----|---------|------------------|
| J1 | Lose network while **streaming** | Pause or finish buffer → banner: “No connection” → **Download this lecture** |
| J2 | Lose network while playing **downloaded** file | Continue seamlessly → strip: “Saved for offline” |
| J3 | Tap **Next** offline, next part not downloaded | Dialog: “Part 02 isn’t downloaded” → Download / Cancel (do not spin forever) |
| J4 | Auto-advance at end of part offline | Same as J3 — skip only if next is downloaded, else stop + prompt |
| J5 | Open app **fully offline** | Catalog from cache; only downloaded lectures playable; others muted + label |
| J6 | **Prepare** before travel | Player sheet: download this part / all parts in class (+ size estimate) |

---

## 5. UX specification

### 5.1 Player — status strip (shipped)

Place below track title or above seek bar.

| State | Strip |
|-------|--------|
| Streaming, online | `Streaming` · optional size · tap → offline sheet |
| Streaming, offline | `No connection` · playback may stop · **Download when online** |
| Local file | `Saved for offline` · check icon |
| Downloading | Progress bar + “Downloading… 42%” |

**Tap strip** → **Offline sheet** (modal bottom sheet):

- Download this lecture (~X MB)
- Download all parts in this class (~Y MB)
- Cancel download (if in progress)
- Remove download (if saved)
- Link: “Manage offline library” → Settings / Offline Library

Replace icon-only `DownloadButton` in app bar as primary entry; keep icon as secondary or remove.

### 5.2 Lecture list (shipped)

- Downloaded: gold check or dot on tile.
- Offline + not downloaded: muted row, tap → snackbar: “Download on Wi‑Fi to listen offline.”
- Class header action (P1): “Download class” (~N MB).

### 5.3 Offline Library — Settings (shipped)

Rename/enhance **Downloads** section:

- Grouped by class, list downloaded parts.
- Total storage used.
- Chapter-wide downloads are supported; a global “download all lectures” action is not shipped.
- Clear all (existing).

### 5.4 App shell (follow-up)

- When offline: subtle **Offline** chip in app bar (optional).
- Pull-to-refresh messaging on the lectures surface (if product requires it).

### 5.5 Copy & i18n (shipped)

Offline strings are present in all four ARB locales: `app_en.arb`, `app_ar.arb`,
`app_ur.arb`, and `app_ur_roman.arb`.

---

## 6. Technical plan

### Phase 1 — shipped

| Task | Details |
|------|---------|
| `ConnectivityProvider` | `connectivity_plus`; expose `isOnline` / `isOffline`; debounce flapping |
| `PlaybackSource` | `stream` \| `local` on `PlayerNotifier`; drive player strip |
| Guard `loadAndPlay` | If offline && !downloaded → return error state, don’t start stream |
| Smart `playNext` / `_onCompleted` | Offline: only advance to downloaded parts; else show dialog |
| Network error handling | No direct `just_audio` error/retry surface is shipped; stuck-buffering and connectivity recovery are surfaced, while direct error/retry handling remains open |
| Player strip + offline sheet | New widgets; wire to `DownloadsProvider` |
| Lecture tile states | Disable + message when offline && !downloaded |
| Catalog offline launch | If cache exists, load without error screen |

**Estimate:** 3–5 dev days + QA.

### Phase 2 — shipped

| Task | Details |
|------|---------|
| `downloadChapter(chapterId)` | Queue all lectures in a chapter |
| Download queue | Serial jobs with cancellation |
| Offline Library screen | Full list UI in Settings |
| Wi‑Fi only setting | Persisted preference blocks cellular downloads (shipped) |

### Phase 3 — Later (P2)

- Download progress in system notification (Android, shipped)
- “Download Continue Listening + next 2 parts” suggestion on the lectures surface
- Study Mode offline rules (document which parts count if mixed)
- iOS background download behaviour audit

---

## 7. Architecture

```
ConnectivityProvider ──┬── PlayerNotifier (guard load/advance)
                       ├── Player strip / sheet
                       └── Lecture tiles (disable undownloaded)

DownloadsProvider ─────┬── PlayerNotifier (localPathIfDownloaded)
                       ├── Offline sheet
                       └── Offline Library

CatalogProvider ──────── Lecture list (cached metadata offline)
```

### `loadAndPlay` rules (pseudocode)

```
if (!connectivity.isOnline && !downloads.isDownloaded(lecture.id)) {
  emit OfflinePlaybackBlocked;
  return;
}
path = downloads.localPathIfDownloaded(lecture.id);
await handler.loadLecture(lecture, localFilePath: path, ...);
playbackSource = path != null ? local : stream;
```

---

## 8. Product decisions (need sign-off)

| Decision | Recommendation |
|----------|----------------|
| Next part not downloaded offline | **Stop + dialog** (Study Mode needs explicit user choice) |
| Bulk “download all lectures” | **Not shipped** — chapter downloads are the available bulk action |
| Stream buffer then offline | **Pause at buffer end** + banner (don’t fake continuity) |
| Delete download while playing | **Confirm + stop playback** |
| First install never online | Block lectures with message: connect once to load catalog |

---

## 9. QA matrix

| Scenario | Expected |
|----------|----------|
| Airplane mode during stream | Banner within ~2s; no infinite spinner |
| Airplane mode during local play | Uninterrupted playback |
| Next offline, next not saved | Dialog, no crash |
| End-of-part auto-advance offline | Same as Next |
| Download from player sheet | Progress visible; completes; strip → “Saved” |
| Launch offline with cache | Lectures list visible |
| Launch offline without cache | Clear empty state + “Connect to load lectures” |
| Delete file while marked downloaded | Reconcile on launch (existing) |

---

## 10. Release checklist

- [x] `feature-flags.json`: `"downloads": true`
- [x] Play Store listing mentions offline listening
- [x] l10n complete for offline strings
- [ ] QA on physical device (airplane mode)
- [ ] Optional: analytics events (download_started, offline_play)

---

## 11. Implementation order

1. ~~`ConnectivityProvider` + tests~~ (shipped)
2. ~~`PlayerNotifier` guards + `PlaybackSource`~~ (shipped)
3. ~~Player status strip + offline sheet~~ (shipped)
4. ~~Smart next / auto-advance~~ (shipped)
5. ~~Lecture tile offline states~~ (shipped)
6. ~~Offline Library and chapter downloads~~ (shipped)
7. ~~Wi‑Fi-only policy~~ (shipped)

---

## 12. Out of scope for the shipped slice

- Syncing downloads across devices  
- Streaming quality selection / adaptive bitrate  
- Rotating daily benefits (the catalog currently supplies one benefit)
- Website offline PWA
