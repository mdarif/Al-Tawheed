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

## 2. Screenshot shot list

### v3 — both series, automated (current)

Fully automated — capture + clean device framing in one command:

```sh
make screenshots DEVICE=<id>     # flutter devices to find <id> (iOS sim is fine)
```

This runs `integration_test/screenshots_test.dart` (drives a fresh install
through onboarding, picks Arabic, then switches to Urdu via Settings — capturing
**both** the Arabic-chrome and English/Urdu-chrome experiences via `AppFlow` +
`takeScreenshot`) → raws in `docs/play-store/v3/raw/`, then
`scripts/frame_screenshots.py` composites clean thin-bezel device frames on the
cream→gold brand gradient (no captions) → `docs/play-store/v3/framed/` +
`preview.png`. Output is **1290×2580 (2:1), RGB, no alpha** — Play-compliant.

10 frames captured; **Play allows max 8** — upload `01`–`08` (below); `09`–`10`
are framed as swap-ins. The key point: the Urdu series shows **English chrome**
(Now Playing, Study Mode, Settings) while Arabic shows **Arabic chrome** — both
must be represented.

| # | File (`docs/play-store/v3/framed/`) | Screen | Chrome |
|---|-------------------------------------|--------|--------|
| 1 | `01-welcome-ar-framed.png`     | Arabic welcome — al-Fawzan (**lead**)     | Arabic |
| 2 | `02-book-ar-framed.png`        | Book tab الكتاب — full Arabic text (new)   | Arabic |
| 3 | `03-choose-series-framed.png`  | Choose-Series picker (both)               | English |
| 4 | `04-welcome-ur-framed.png`     | Urdu welcome — "START LISTENING"          | English |
| 5 | `05-lectures-ur-framed.png`    | Urdu lectures — Class 01, Study tab       | English |
| 6 | `06-study-ur-framed.png`       | Study Mode — Urdu-only feature            | English |
| 7 | `07-player-ur-framed.png`      | Now Playing                               | English |
| 8 | `08-player-ar-framed.png`      | Player يُشغَّل الآن (chrome contrast)       | Arabic |
| 9 | `09-lectures-ar-framed.png`    | Arabic lectures الدروس (swap-in)          | Arabic |
| 10 | `10-settings-ur-framed.png`   | Settings (swap-in)                        | English |

**Tablet slots (7-inch + 10-inch, both required).** `make screenshots` also
emits `docs/play-store/v3/framed-tablet/` — the same captures reframed onto a
**1440×2560 (9:16)** canvas (Play's tablet range is 9:16..16:9; the phone 2:1
frames are too elongated to reuse). One set satisfies **both** the 7-inch and
10-inch slots — upload `01`–`08` from `framed-tablet/` to each. These are the
phone captures on a tablet-aspect canvas, not native iPad/Android-tablet layouts
(the iOS app isn't iPad-native; the Android-tablet emulator flag load was flaky)
— which Play accepts (only aspect/size are checked, not tablet-optimised UI).

To re-capture next release: `make screenshots DEVICE=<id>`, review `preview.png`
+ `preview-tablet.png`, re-upload. Tune framing (bezel/shadow/gradient/canvas)
in `scripts/frame_screenshots.py`.

---

### Legacy manual shot list (v2, superseded)

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

> **Updated for 2.3.0 (both series).** The old copy below the divider was
> Urdu-only; this version covers the new Arabic series (al-Fawzan) + Book tab.

### App name (30 chars max)

```
Sharah Kitab at-Tawheed
```

### Short description (80 chars max)

```
Kitab at-Tawheed audio Sharh in Arabic & Urdu — offline, Book, Study Mode
```

(73 characters)

### Full description (4000 chars max)

```
Sharah Kitab at-Tawheed is a complete audio companion for studying the foundational Islamic text Kitab at-Tawheed — now with TWO full lecture series to choose from.

📚 TWO SERIES, ONE APP
• Arabic — the explanation by Shaikh Salih al-Fawzan (hafizahullah), with the complete Arabic text of the book built in.
• Urdu — the detailed 50-lecture series by Fazilat Shaikh Abdullah Nasir Rahmani (hafizahullah).
Choose your series when you open the app, and switch anytime from Settings.

📖 READ THE BOOK (ARABIC SERIES)
The Arabic series includes the full text of Kitab at-Tawheed in a dedicated Book tab — read the chapters (abwab) alongside the audio, with clear verse and hadith highlighting.

📈 STUDY MODE (URDU SERIES)
Go beyond listening. Study Mode tracks your progress class by class across all 15 classes, so you always know where you left off and how far you've come.

🎧 LISTEN ANYTIME, ANYWHERE
Stream every lecture, organised by chapter, or save it for offline listening — perfect for commutes, travel, or low-connectivity areas.

📥 OFFLINE MODE
Download individual lectures or whole chapters with one tap. Choose Wi‑Fi‑only downloads to manage your data, and reach everything you've saved from your Offline Library — no internet required.

🔖 BOOKMARKS & CONTINUE LISTENING
Pick up right where you stopped, and bookmark key moments in any lecture to revisit whenever you like.

⏩ VARIABLE SPEED
Listen at 0.75× to 2× to match your pace.

🌙 LIGHT & DARK THEMES
A clean, distraction-free design with full dark mode for comfortable listening day or night.

🔔 LOCK-SCREEN & NOTIFICATION CONTROLS
Play, pause, and skip straight from your lock screen or notification shade — even with the app in the background.

Whether you're beginning your journey with Kitab at-Tawheed or returning for deeper study — in Arabic or Urdu — Sharah Kitab at-Tawheed puts these teachings in your pocket, online or off.

🔗 MORE FROM AL-MARFA
• Website: https://kitabattawheed.com
• YouTube: Al-Marfa Duroos

Developed by Al-Marfa. For feedback or issues, use Contact Us in Settings.

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

---

## 8. Release notes ("What's new") — per version

Paste into Play Console → the release → **Release notes**, inside the language
tags. Limit: **500 chars per language**. The `<ar>` block is only valid once
Arabic is added as a **store-listing** language (Store presence → Main store
listing → Manage translations → Add Arabic) — otherwise Play Console rejects it.
The auto-generated notes from the release pipeline are a raw changelog; prefer
these human-readable versions for production.

### 2.3.0 — Arabic series

English (`en-GB`, the current default listing language):

```
<en-GB>
New in this version:
• Arabic series — the complete Kitab at-Tawheed explained in Arabic by Shaikh Salih al-Fawzan, including the full Arabic text of the book in a new Book tab.
• Switch series and language anytime from Settings.
• Faster loading, smoother offline downloads, and improved stability.
• Bug fixes and refinements.

JazakumAllahu khayran for using the app.
</en-GB>
```

Arabic (`ar`, only after adding Arabic as a store-listing language):

```
<ar>
الجديد في هذا الإصدار:
• سلسلة عربية — شرح كتاب التوحيد كاملًا باللغة العربية لفضيلة الشيخ صالح الفوزان حفظه الله، مع النص الكامل للكتاب في تبويب «الكتاب».
• بدّل السلسلة واللغة في أي وقت من الإعدادات.
• تحميل أسرع، وتنزيل أفضل للاستماع بلا إنترنت، وثبات محسّن.
• إصلاحات وتحسينات متنوعة.

جزاكم الله خيرًا على استخدام التطبيق.
</ar>
```
