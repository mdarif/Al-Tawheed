# Google Play Store listing — v2 (audio lectures)

Use this when updating **Main store listing** in Play Console.  
Package: `com.almarfa.tawheed`  
Brand: gold `#D4AF37`, cream background `#FAF8F5`, book cover `assets/tawheed.png`

---

## Quick path (no Photoshop) — ~20 minutes

Greentech’s [Al Quran listing](https://play.google.com/store/apps/details?id=com.greentech.quran) uses **phone mockups + short headline on a solid colour**. You can match that without opening Photoshop.

### Fastest of all (plain screenshots)

1. Capture 6–8 PNGs from the emulator (see shot list below).  
2. Upload **directly** to Play Console → Main store listing → Phone screenshots.  

Google accepts **raw screenshots** (no frame, no captions). Less polished than Greentech, but **zero design tools**.

### Greentech-style in the browser (recommended)

Use a **store screenshot generator** — upload your raw PNGs, pick Android phone frame, set background colour, type one headline per slide, download ZIP.

| Tool | URL | Notes |
|------|-----|--------|
| **Previewed** | https://previewed.app | Templates for Google Play; bulk export |
| **Screenshot.rocks** | https://screenshot.rocks | Free, simple device frames |
| **AppMockUp** | https://app-mockup.com | Good phone angles |
| **LaunchMatic** | https://launchmatic.com | Play Store sizes built-in |

**Workflow:**

1. `flutter run --release` on a **Pixel 6** (or similar) emulator → light theme.  
2. Capture screens (Android Studio **Camera** icon, or `adb exec-out screencap -p > 01-home.png`).  
3. Open **Previewed** (or similar) → template **Google Play** / Android phone.  
4. Background: `#FAF8F5` or soft gold `#FBF3E0`.  
5. Per slide, add headline (examples):

   | Screenshot | Headline (like Greentech) |
   |------------|---------------------------|
   | Welcome | Complete Sharah of Kitab al-Tawheed |
   | Lectures | 50 Lectures · 15 Classes |
   | Player | Listen in the Background |
   | Home | Resume Where You Left Off |
   | Study | Study All Classes in Order |
   | About | By Shaikh Abdullah Nasir Rahmani |

6. Export **1080×1920** (or tool’s Play preset) → upload to Play Console.

No Photoshop; optional free account on the web tool.

### Repeatable from terminal (optional, later)

[fastlane frameit](https://docs.fastlane.tools/actions/frameit/) adds frames + titles from a config file. Worth it if you update screenshots every release; first-time setup ~30 min.

---

## 1. What to replace (old vs new)

| Asset | Old listing (likely) | New listing (v2) |
|-------|----------------------|------------------|
| Screenshots | YouTube video player, old UI | Native **audio** app: lectures, player, Home, Study, About |
| Short description | Video / YouTube focus | 50 audio lectures, offline-friendly, Urdu support |
| Full description | Outdated features | See copy below |
| Feature graphic | Old branding | New banner (see `docs/store-assets/feature-graphic-spec.md`) |
| App name | May say “At-Tawheed” | **Sharah Kitab al-Tawheed** (match welcome screen) |

---

## 2. Screenshot shot list (capture on device or emulator)

Use **light theme** for most shots (palette B — cream + gold). Add **1–2 dark theme** shots for variety.

**Phone screenshots (required):** portrait **1080×1920** or **1080×2340** (9:16). PNG or JPEG, no alpha.

| # | Screen | How to capture | Caption idea (optional overlay in Canva) |
|---|--------|----------------|------------------------------------------|
| 1 | **Welcome** | Cold start → welcome with cover + “START LISTENING” | *Complete Sharah of Kitab al-Tawheed* |
| 2 | **Lectures** | Tab: Lectures → class list expanded | *15 classes · 50 lectures* |
| 3 | **Lecture parts** | Open one class → part list | *Listen part by part* |
| 4 | **Player** | Play a lecture → full player | *Background playback · speed control* |
| 5 | **Home** | Tab: Home → Continue listening + Daily benefit | *Resume where you left off* |
| 6 | **Study Mode** | Enable `studyMode` flag or use build with flag on → Study card + hub | *Structured study through all classes* |
| 7 | **Saved** | Bookmark a lecture → Saved tab | *Save lectures for later* |
| 8 | **Settings → About** | Scroll to About card | *By Fazilat Shaikh Abdullah Nasir Rahmani حفظه الله* |

**Optional 9th:** Language set to **Urdu** or **Roman Urdu** → Lectures or Home (shows localization).

### Capture tips

```bash
# Release build on emulator (Pixel 6 API 34+)
flutter run --release
# Or: Android Studio → Device Manager → screenshot button
```

- Status bar: clean (full battery, no low-battery popup).
- No debug banner (`debugShowCheckedModeBanner: false` in release).
- Real lecture title visible (not “Test”).
- For Study screenshot: feature flag `studyMode: true` in CDN or local test.

### Tablet (optional)

7" and 10" slots are optional; skip unless you have time. Phone set is enough for most installs.

---

## 3. Feature graphic (1024 × 500)

Required for Play Store. See spec: [feature-graphic-spec.md](./store-assets/feature-graphic-spec.md).

Export as **PNG** or **JPEG**, no transparency.

---

## 4. Store listing copy (paste into Play Console)

### App name (30 chars max)

```
Sharah Kitab al-Tawheed
```

### Short description (80 chars max)

```
50 audio lectures on Kitab al-Tawheed — by Shaikh Abdullah Nasir Rahmani. Resume & study.
```

(79 characters)

**Alternate (Urdu audience):**

```
Kitab al-Tawheed ki 50 audio dars — Shaikh Abdullah Nasir Rahmani. Suno aur seekho.
```

### Full description (4000 chars max)

```
Sharah Kitab al-Tawheed brings the complete audio series explaining Kitab al-Tawheed — the foundation of Islamic monotheism (Tawheed) — into one simple app.

🎧 50 LECTURES · 15 CLASSES
Listen to the full explanation by Fazilat Shaikh Abdullah Nasir Rahmani Hafizahullah, organised by class and part. Pick up where you left off with automatic progress saving.

✨ HIGHLIGHTS
• High-quality audio lectures streamed from our CDN (works on Wi‑Fi and mobile data)
• Continue Listening on Home — resume your last lecture instantly
• Daily Benefit — a short reminder from the Sunnah each day
• Save lectures — bookmark parts you want to hear again
• Playback speed — 0.75× to 2× for comfortable listening
• Study Mode — work through all 15 classes in order at your own pace
• Light and dark themes
• English, Urdu, and Roman Urdu interface (when enabled)

📖 ABOUT THE BOOK
Kitab al-Tawheed (The Book of Monotheism) by Imam Muhammad ibn Abdul-Wahhab explains what it means to worship Allah alone — the core of Islam. This app is the audio sharah (explanation) of that book.

🔗 MORE FROM AL-MARFA
• Website: https://kitabattawheed.com
• YouTube: Al-Marfa Publications

Developed by Al-Marfa Publications. For feedback or issues, use Contact Us in Settings.

May Allah make this knowledge beneficial.
```

Adjust emoji if you prefer a plainer tone (Google allows them; some publishers remove for seriousness).

### Category

- **Primary:** Education (or Books & Reference)
- **Tags:** Islam, lectures, audio, Urdu, Tawheed (pick what Play offers)

---

## 5. Play Console upload order

1. **Grow** → **Store presence** → **Main store listing**
2. Upload **Feature graphic** (1024×500)
3. Upload **Phone screenshots** (drag to order: Welcome → Lectures → Player → Home → Study → Saved → About)
4. Paste **Short** and **Full** description
5. **Save** → review preview
6. If using **Custom store listing** per country, duplicate or localize Urdu for Pakistan

---

## 6. Promo video (optional)

YouTube link on listing is optional. If you add one, reuse the same flow as the foreground-service demo: play lecture → show background audio. Not required.

---

## 7. Files to add in repo (optional)

```
docs/store-assets/
  feature-graphic-spec.md
  screenshots/          # add exported PNGs here for version control
    01-welcome.png
    02-lectures.png
    ...
```

Keep screenshots under ~8 MB each for git; or store in Drive and link in this doc.
