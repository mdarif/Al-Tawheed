# Offline mode — next release plan

**Status:** Draft for next release  
**Feature flag:** `downloads` (promote to on in production when ready)  
**Goal:** Offline listening is a **prominent**, understandable feature — especially when the user loses network **while in the player**.

---

## 1. Problem statement

Today the app **can** play downloaded MP3s and **can** stream from CDN, but offline is treated as a small download icon, not a mode.

### What works today

| Piece | Behaviour |
|-------|-----------|
| Storage | `{documents}/audio/{lectureId}.mp3` per lecture |
| Playback | `PlayerNotifier` uses local file if downloaded, else stream |
| Catalog | Stale-while-revalidate JSON cache (offline OK if opened online before) |
| UI | Download icon on lecture row + player app bar; Settings shows count/size |

### What fails UX (especially in player)

1. **No connectivity awareness** — app does not know the device went offline.
2. **Streaming + airplane mode** — playback stalls/errors with no message or recovery.
3. **Next / auto-advance** — loads next part without checking download → fails offline.
4. **Download is hidden** — icon-only in app bar; no “prepare for offline” flow while listening.
5. **No source indicator** — user cannot see “Streaming” vs “Saved on device”.
6. **Undownloaded lectures** — still tappable offline → confusing loading/error states.

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
5. **Wi‑Fi respectful** — optional “Download on Wi‑Fi only” (Phase 2).

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

### 5.1 Player — status strip (P0)

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

### 5.2 Lecture list (P0)

- Downloaded: gold check or dot on tile.
- Offline + not downloaded: muted row, tap → snackbar: “Download on Wi‑Fi to listen offline.”
- Class header action (P1): “Download class” (~N MB).

### 5.3 Offline Library — Settings (P1)

Rename/enhance **Downloads** section:

- Grouped by class, list downloaded parts.
- Total storage used.
- “Download all lectures” with strong confirm (~total MB from catalog).
- Clear all (existing).

### 5.4 App shell (P2)

- When offline: subtle **Offline** chip in app bar (optional).
- Pull-to-refresh on Home: “You’re offline — showing cached content.”

### 5.5 Copy & i18n

All new strings in `app_en.arb`, `app_ur.arb`, `app_ur_roman.arb` before release.

---

## 6. Technical plan

### Phase 1 — Must ship (P0)

| Task | Details |
|------|---------|
| `ConnectivityProvider` | `connectivity_plus`; expose `isOnline` / `isOffline`; debounce flapping |
| `PlaybackSource` | `stream` \| `local` on `PlayerNotifier`; drive player strip |
| Guard `loadAndPlay` | If offline && !downloaded → return error state, don’t start stream |
| Smart `playNext` / `_onCompleted` | Offline: only advance to downloaded parts; else show dialog |
| Network error handling | Subscribe to `just_audio` errors; map to offline UI |
| Player strip + offline sheet | New widgets; wire to `DownloadsProvider` |
| Lecture tile states | Disable + message when offline && !downloaded |
| Catalog offline launch | If cache exists, load without error screen |

**Estimate:** 3–5 dev days + QA.

### Phase 2 — Same release or fast follow (P1)

| Task | Details |
|------|---------|
| `downloadChapter(chapterId)` | Queue all lectures in class |
| Download queue | Serial jobs, cancel, persist in-progress (optional) |
| Offline Library screen | Full list UI in Settings |
| Wi‑Fi only setting | Defer cellular downloads |

### Phase 3 — Later (P2)

- Download progress in system notification (Android)
- “Download Continue Listening + next 2 parts” suggestion on Home
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
| Bulk “download all 50” in v1 | **Defer** — offer per-class first (~27 MB avg per class) |
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

- [ ] `feature-flags.json`: `"downloads": true`
- [ ] Play Store listing mentions offline listening
- [ ] l10n complete for offline strings
- [ ] QA on physical device (airplane mode)
- [ ] Optional: analytics events (download_started, offline_play)

---

## 11. Implementation order

1. `ConnectivityProvider` + tests  
2. `PlayerNotifier` guards + `PlaybackSource`  
3. Player status strip + offline sheet  
4. Smart next / auto-advance  
5. Lecture tile offline states  
6. Offline Library + class download (P1)  
7. Wi‑Fi only (P2)

---

## 12. Out of scope (this release)

- Syncing downloads across devices  
- Streaming quality selection / adaptive bitrate  
- Offline daily benefits rotation (catalog JSON still needs cache — separate)  
- Website offline PWA
