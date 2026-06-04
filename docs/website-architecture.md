# ADR-004: kitabattawheed.com — Website Architecture

**Status:** Accepted  
**Date:** 2026-06-03  
**Repo:** `Al-Tawheed-Web` (separate repository — website development never touches this Flutter repo)

---

## Goal

A lightweight, SEO-first website that:
1. Ranks for Tawheed lecture searches (India, Pakistan, Bangladesh, Gulf)
2. Lets visitors sample the content with a basic web audio player
3. Converts web visitors into mobile app installs

The primary metric is **app installs driven from organic search**, not web engagement.

---

## Stack

| Layer | Choice | Reason |
|---|---|---|
| Framework | **Astro** | Ships 0 JS by default; islands for audio player only; native static site generation |
| Hosting | **Cloudflare Pages** | Already in our ecosystem; free; auto-deploys on push |
| Content | `catalog.json` on Cloudflare Pages | Same source used by the Flutter app — no duplication |
| Audio | Cloudflare R2 (`pub-8a0d...r2.dev`) | Range requests supported — seeking works in browser |
| Analytics | Cloudflare Web Analytics | Free; no cookies; GDPR-compliant; zero JS overhead |
| Search | Pagefind | Runs at build time; no backend; ~30KB on demand |

---

## URL Structure

```
kitabattawheed.com/
  /                              ← Home + app download CTA
  /lectures/                     ← All 15 chapters
  /lectures/class-01/            ← Chapter page with part list
  /lectures/class-01/part-01/    ← Individual lecture + audio player
  /about/                        ← Sheikh bio + series background
  /download/                     ← Dedicated app download page
  /sitemap.xml
  /feed.xml
```

50 lecture pages + 15 chapter pages + ~5 static pages = **~70 static pages**, all pre-rendered at build time.

---

## App Download Strategy (Primary Conversion Goal)

Every page drives to the app. The hierarchy:

1. **Hero CTA on homepage** — full-width "Download Free on Google Play" above the fold
2. **Sticky banner** — persists on scroll on lecture pages: "Listen offline · Save progress · Download free"
3. **Post-play nudge** — after a visitor listens to 5+ minutes, show: "Continue on the app — offline, with progress tracking"
4. **Chapter completion card** — after listing all parts of a class, show app features comparison (web vs app)
5. **Dedicated `/download/` page** — explains app features, screenshots, Play Store link

The `links.playStore` URL comes from `app-config.json` — no hardcoding. When the iOS app launches, `links.appStore` being non-null automatically activates the iOS CTA everywhere.

---

## Content Model

Fetched at build time from:
```
https://al-tawheed-content.pages.dev/tawheed/catalog.json
https://al-tawheed-content.pages.dev/tawheed/app-config.json
```

Same JSON the Flutter app uses. Adding content (lectures, benefits) automatically updates both the app and the website on next rebuild.

---

## SEO

### Per-lecture page

```html
<title>Class 01 Part 01 — Sharah Kitab al-Tawheed | Urdu Islamic Lectures</title>
<meta name="description" content="Listen to Class 01 Part 01 of Sharah Kitab al-Tawheed by Sheikh Abdullah Nasir Rahmani. Free online and offline via the Android app.">
```

### Structured data (JSON-LD)

Each lecture page emits `AudioObject` + `BreadcrumbList`. Series home emits `Course` + `Person`.

```json
{
  "@type": "AudioObject",
  "name": "Class 01 — Part 01",
  "duration": "PT35M57S",
  "encodingFormat": "audio/mpeg",
  "contentUrl": "https://pub-8a0d...r2.dev/lec-001.mp3",
  "inLanguage": "ur"
}
```

### Entity pages (for AI search and topical authority)

These are static pages that help Google and AI systems understand what this site is about:

| Page | Targets |
|---|---|
| `/kitab-al-tawheed/` | "what is kitab al tawheed", "kitab al tawheed summary" |
| `/sheikh-rahmani/` | "Sheikh Abdullah Nasir Rahmani lectures" |
| `/tawheed/` | "what is tawheed in Islam", "types of tawheed" |

Each includes an FAQ block (`FAQPage` schema) which surfaces in AI Overviews and ChatGPT responses.

---

## Audio Player

One React island loaded only when the player scrolls into view (`client:visible`):
- HTML5 `<audio>` + the R2 URL
- Play/pause, seek bar, speed selector (0.75×–2× matching the mobile app)
- After 5 minutes of listening: show app install nudge
- No external library needed

The rest of the lecture page is plain HTML — no JavaScript penalty for crawlers.

---

## Analytics Events to Track

| Event | Tool |
|---|---|
| Page view | Cloudflare Analytics (automatic) |
| Audio play start | Custom beacon |
| Audio 50% / completion | Custom beacon |
| "Download" button click | Custom beacon |
| Play Store redirect | Custom beacon |

Cloudflare D1 (SQLite at edge, free tier) stores the custom events. No Google Analytics, no third-party tracking.

---

## AI Search Optimization

- `llms.txt` at root (analogous to `robots.txt` for AI crawlers)
- FAQ schema on every major page
- `lang` + `dir="rtl"` on all Arabic text blocks
- `<h1>` → `<h2>` hierarchy matches content structure (AI systems extract this)
- Semantic HTML: `<article>`, `<section>`, `<aside>` correctly used

---

## Build and Deploy

```
Repo:           Al-Tawheed-Web (GitHub, separate from this repo)
Hosting:        Cloudflare Pages (connected to Al-Tawheed-Web/main)
Build command:  npm run build
Output:         dist/
Rebuild trigger: Push to Al-Tawheed-Web/main (code changes)
                 Manual/webhook when catalog.json changes content
```

---

## MVP Scope

Build first:
- Home page with hero CTA
- Chapter list page
- Chapter detail page
- Individual lecture page with audio player
- `/download/` page
- Sitemap + RSS

Add shortly after:
- Entity pages (`/kitab-al-tawheed/`, `/sheikh-rahmani/`)
- Pagefind search
- Post-play app nudge
- `llms.txt`

---

## What This Repo Provides to the Website

The website consumes from this ecosystem but **never modifies it**:

| Source | Used by website |
|---|---|
| `Al-Tawheed-Content/tawheed/catalog.json` | All lecture + chapter metadata |
| `Al-Tawheed-Content/tawheed/app-config.json` | Play Store URL, contact, share text |
| `Al-Tawheed-Content/tawheed/cover.jpg` | Book cover image |
| Cloudflare R2 audio files | Audio player source URLs |
| `docs/play-store/` screenshots | Website app preview images |
