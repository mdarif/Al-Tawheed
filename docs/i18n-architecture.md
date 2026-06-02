# ADR-003: Multilingual Architecture

**Status:** Accepted  
**Date:** 2026-06-01  
**Applies to:** Al-Tawheed Flutter app + Al-Tawheed-Content repo

---

## Context

The app serves learners from India, Pakistan, Bangladesh, and Gulf countries. Many users understand spoken Urdu but cannot read Nastaliq script fluently — **Roman Urdu is a first-class language**, not a transliteration fallback. Content is static and hosted remotely on Cloudflare Pages. The architecture must allow content translations to be published without app releases.

---

## Two-Layer Localization Model

The most important architectural decision: UI strings and content strings are separate problems solved by separate tools.

```
┌─────────────────────────────────────────────────────────┐
│  Layer 1 — UI Strings                                   │
│  Buttons, labels, headers, error messages, tab names    │
│  Source: Flutter ARB files bundled in the app           │
│  Update: Requires app release                           │
│  Tool:   flutter_localizations + intl package           │
├─────────────────────────────────────────────────────────┤
│  Layer 2 — Content Strings                              │
│  Lecture titles, chapter titles, benefits, announcements│
│  Source: Multilingual JSON on Cloudflare Pages          │
│  Update: Push to GitHub → no app release needed         │
│  Tool:   LanguageProvider.resolve() at render time      │
└─────────────────────────────────────────────────────────┘
```

Never mix these layers. UI strings belong in ARB files. Content strings belong in remote JSON.

---

## Language Codes

| Language     | ARB locale | JSON key | Notes |
|---|---|---|---|
| English      | `en`       | `en`     | Source of truth, always present |
| Urdu (script)| `ur`       | `ur`     | Nastaliq, RTL |
| Roman Urdu   | `ur_roman` | `roman`  | Custom locale, Latin script |
| Hindi        | `hi`       | `hi`     | Phase 3, Devanagari |
| Arabic       | `ar`       | `ar`     | Phase 4, RTL |

`roman` is the JSON key because it is self-documenting and avoids confusion with BCP 47 script subtags like `ur-Latn`.

---

## Layer 1 — Flutter UI Localization

### ARB File Structure

```
lib/l10n/
  app_en.arb          ← English (source of truth — all keys must exist here)
  app_ur.arb          ← Urdu script (human-translated)
  app_ur_roman.arb    ← Roman Urdu (human-written, NEVER auto-generated) — Phase 2
  app_hi.arb          ← Phase 3
  app_ar.arb          ← Phase 4
```

### Configuration (`l10n.yaml`)

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
nullable-getter: false
```

### Supported Locales

```dart
supportedLocales: [
  Locale('en'),
  Locale('ur'),
  Locale('ur', 'ROMAN'),  // Phase 2 — custom, never auto-detected
  Locale('hi'),           // Phase 3
  Locale('ar'),           // Phase 4
]
```

Roman Urdu (`ur_ROMAN`) is **never auto-detected** from device locale. The user must explicitly select it. No device reports `ur_ROMAN` as its system locale.

---

## Layer 2 — Remote Content Localization

### Inline Multilingual JSON

All multilingual content fields use an inline object keyed by language code. The `LanguageProvider.resolve()` method picks the correct value at render time.

**Why inline (not per-language files)?**

- Single file = atomic updates — no synchronisation between files needed
- Additive changes (new language key) are ignored by old app versions
- Total catalog size with 5 languages is still small (~80 KB)
- Simpler cache strategy — one fetch, all languages cached

### Invariant — English always present

Every multilingual field in every JSON file **must** have an `en` value. All other languages are optional. The fallback chain guarantees a result because English is always the terminal fallback.

---

## JSON Schema Design

### catalog.json — Multilingual fields

```json
{
  "version": 1,
  "book": {
    "title": {
      "en": "Sharah Kitab al-Tawheed",
      "ur": "شرح کتاب التوحید",
      "roman": "Sharah Kitab al-Tawheed",
      "hi": "शरह किताब अल-तौहीद",
      "ar": "شرح كتاب التوحيد"
    },
    "speaker": {
      "en": "Fazilat Shaikh Abdullah Nasir Rahmani",
      "ur": "فضیلت شیخ عبداللہ ناصر رحمانی",
      "roman": "Fazilat Shaikh Abdullah Nasir Rahmani",
      "hi": "फ़ज़ीलत शेख़ अब्दुल्लाह नासिर रहमानी",
      "ar": "فضيلة الشيخ عبد الله ناصر الرحماني"
    }
  },
  "chapters": [
    {
      "id": "class-01",
      "title": {
        "en": "Class 01",
        "ur": "درس ۰۱",
        "roman": "Dars 01"
      }
    }
  ],
  "lectures": [
    {
      "id": "lec-001",
      "title": {
        "en": "Class 01 — Part 01",
        "ur": "درس ۰۱ — حصہ ۰۱",
        "roman": "Dars 01 — Hissa 01"
      }
    }
  ]
}
```

### benefits.json — Standalone file (extracted from catalog.json in Phase 1)

```json
{
  "version": 1,
  "updatedAt": "2026-06-01T00:00:00Z",
  "benefits": [
    {
      "id": "benefit-001",
      "text": {
        "en": "Whoever dies knowing that there is no god but Allah enters Paradise.",
        "ur": "جو شخص اس حال میں مرا کہ وہ جانتا تھا کہ اللہ کے سوا کوئی معبود نہیں، وہ جنت میں داخل ہوگا۔",
        "roman": "Jo shakhs is haal mein mara ke woh jaanta tha ke Allah ke siwa koi mabood nahi, woh jannat mein daakhil ho ga.",
        "ar": "مَنْ مَاتَ وَهُوَ يَعْلَمُ أَنَّهُ لَا إِلَهَ إِلَّا اللَّهُ دَخَلَ الْجَنَّةَ"
      },
      "source": {
        "en": "Sahih Muslim",
        "ur": "صحیح مسلم",
        "roman": "Sahih Muslim",
        "ar": "صحيح مسلم"
      }
    }
  ]
}
```

### announcements.json — Multilingual

```json
{
  "announcements": [
    {
      "id": "ann-001",
      "title": {
        "en": "iOS App Coming Soon",
        "ur": "آئی او ایس ایپ جلد آ رہی ہے",
        "roman": "iOS App Jald Aa Rahi Hai"
      },
      "body": {
        "en": "Available on App Store shortly. JazakAllahu Khayran.",
        "ur": "جلد ایپ اسٹور پر دستیاب ہوگی۔ جزاکم اللہ خیرًا۔",
        "roman": "Jald App Store Par Dastiyab Hogi. JazakAllahu Khayran."
      }
    }
  ]
}
```

### app-config.json — Multilingual share text

```json
{
  "share": {
    "message": {
      "en": "The Sharah Kitab Al-Tawheed app — 50 audio lectures...",
      "ur": "شرح کتاب التوحید ایپ — ۵۰ آڈیو دروس...",
      "roman": "Sharah Kitab al-Tawheed app — 50 audio duroos..."
    }
  }
}
```

---

## Fallback Chain

```
User selects Roman Urdu:  roman → ur → en
User selects Urdu:        ur → en
User selects Hindi:       hi → ur → en
User selects Arabic:      ar → en
User selects English:     en  (terminal — always present)
```

### Resolution Algorithm

```
function resolve(field, locale):
  if field[locale] exists and is not null → return field[locale]
  if locale == 'roman' and field['ur'] exists → return field['ur']
  if locale == 'hi'    and field['ur'] exists → return field['ur']
  return field['en']  // guaranteed to exist
```

---

## App-Wide vs Per-Content Language

**Decision: App-wide language.**

The user selects one language and everything follows — UI labels, lecture titles, benefits, announcements.

The one hardcoded exception: **Arabic Quranic and hadith text is always shown in Arabic script** regardless of app language. This is not a language setting — it is a display requirement for sacred text. The benefits card renders the `ar` (Arabic) field unconditionally when present.

---

## Roman Urdu — Critical Requirements

### What it is

Roman Urdu is Urdu written in Latin characters. It is **the primary written form** for many users in the target market who speak Urdu fluently but were educated in English-medium schools and cannot read Nastaliq script.

### Transliteration Standard

Adopt the **Urdu Dictionary Standard** — not Hindi transliteration, not academic phonetics:

| Principle | Correct | Avoid |
|---|---|---|
| Follow spoken Urdu phonology | `Tawheed` | `Tawḥīd` |
| No diacritics or special characters | `aa` for long ā | `â` |
| Established Islamic terminology | `Allah`, `Salah`, `Jannat` | Improvised variants |
| Never auto-generate | Human review mandatory | Machine transliteration |

### Maintenance

- Keep `i18n/roman-style-guide.md` in the content repo
- Document every terminology decision
- Every Roman Urdu string must be reviewed by a native Urdu speaker
- Version the style guide alongside the content

### Storage

Roman Urdu strings are plain UTF-8 text with Latin characters. No special encoding, no database, no NFC normalization required.

---

## Font Strategy

| Language | Font | When bundled |
|---|---|---|
| English / Roman Urdu | System default | Never |
| Urdu (Nastaliq script) | Noto Nastaliq Urdu | Phase 1 |
| Hindi (Devanagari) | Noto Sans Devanagari | Phase 3 |
| Arabic (Naskh) | Noto Naskh Arabic | Phase 4 |

Noto fonts are open-source (SIL OFL). Bundle only the regular/variable weight — full font families are unnecessarily large. System fonts on Android in India/Pakistan often include Nastaliq, but bundling guarantees consistent rendering.

---

## Storage Strategy

```
SharedPreferences key: 'app_language'
Values: 'en' | 'ur' | 'roman' | 'hi' | 'ar'

System locale mapping on first launch:
  Locale('en', *)  →  'en'
  Locale('ur', *)  →  'ur'
  Locale('hi', *)  →  'hi'  (Phase 3)
  Locale('ar', *)  →  'ar'  (Phase 4)
  anything else    →  'en'
  
Roman Urdu ('roman') is NEVER auto-detected — user must explicitly select it.
```

---

## Language Selection UX

### First Launch

After the welcome screen on first install:
1. Detect system locale and pre-select the closest supported language
2. Show a compact language picker (Phase 1: English + Urdu)
3. Selection is optional — defaults to English if dismissed
4. Screen never shown again after first explicit selection

### Settings Screen

```
Language
  ◉ English
  ○ اردو
  ○ Roman Urdu    ← Phase 2
```

Language change takes effect immediately — no restart needed. All providers re-resolve from the updated locale. No re-fetch of remote content is needed (already in memory, re-resolved at render time).

---

## Migration Plan

### Phase 1 — English + Urdu

**App:**
- Add `flutter_localizations` + `intl` to pubspec
- Create `app_en.arb` (extract all UI strings)
- Create `app_ur.arb` (human-translated Urdu)
- Add `LanguageProvider` with `resolve()` helper
- Add language section to Settings (gated by `language` in `feature-flags.json`)
- Register Noto Nastaliq Urdu font

**Content (Al-Tawheed-Content):**
- Add `ur` keys to `catalog.json` chapter + lecture titles
- Add `ur` keys to `benefits.json`
- Add `ur` keys to `announcements.json`
- Add `ur` key to `app-config.json` share message

**State after:** Users switch between English and Urdu. UI and content both localise.

### Phase 2 — Roman Urdu

**Prerequisite:** `roman-style-guide.md` reviewed and approved by native speaker.

**App:**
- Add `app_ur_roman.arb` (human-written)
- Register `Locale('ur', 'ROMAN')` in `supportedLocales`
- Add Roman Urdu to language picker

**Content:** Add `roman` keys to all JSON files.

### Phase 3 — Hindi

- Add `app_hi.arb` + translations
- Add `hi` keys to all JSON
- Bundle Noto Sans Devanagari font

### Phase 4 — Arabic

- Add `app_ar.arb` + translations
- Add `ar` keys to all JSON
- Audit all custom layouts for RTL correctness
- Arabic font already in use for hadith text in benefits

---

## Risks and Trade-offs

| Risk | Mitigation |
|---|---|
| Roman Urdu inconsistency across contributors | Style guide in repo; mandatory native-speaker review |
| Missing JSON key shows blank UI | `resolve()` always falls back to English; never returns null |
| Arabic RTL breaks custom Row/Stack layouts | Audit all non-standard layouts during Phase 4 |
| Noto Nastaliq adds ~500 KB to APK | Acceptable; only regular weight needed |
| Machine transliteration attempted for Roman Urdu | Explicitly prohibited; documented in contributing guide |
| Old app versions receive new JSON with extra language keys | Additive changes are safe — unknown keys are ignored |
| Translator delivers inconsistent Islamic terminology | Maintain glossary (`i18n/glossary.md`) alongside style guide |

---

## Files Changed Per Phase

### Phase 1

**App repo (`v2` branch):**
- `pubspec.yaml` — add flutter_localizations, intl, Noto font
- `l10n.yaml` — new
- `lib/l10n/app_en.arb` — new
- `lib/l10n/app_ur.arb` — new
- `lib/providers/language_provider.dart` — new
- `lib/utils/l10n_helper.dart` — new (resolve() utility)
- `lib/services/preferences_service.dart` — add language persistence
- `lib/app.dart` — add delegates, supportedLocales, LanguageProvider
- `lib/screens/settings_screen.dart` — language section
- `assets/fonts/NotoNastaliqUrdu-Regular.ttf` — download and add

**Content repo (`Al-Tawheed-Content`):**
- `tawheed/catalog.json` — add `ur` keys to chapters + lectures
- `tawheed/benefits.json` — add `ur` keys (file already exists)
- `tawheed/announcements.json` — add `ur` key
- `tawheed/app-config.json` — add `ur` key to share message
