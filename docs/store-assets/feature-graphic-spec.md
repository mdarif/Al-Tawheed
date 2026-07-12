# Feature graphic spec (1024 × 500 px)

Google Play **requires** a feature graphic. It appears at the top of your store listing (not the app icon).

## Dimensions

| Property | Value |
|----------|--------|
| Size | **1024 × 500** pixels |
| Format | PNG or JPEG (24-bit, no alpha) |
| Safe zone | Keep text/logo inside center **80%** — edges may crop on some devices |

## Design direction (match v2 app)

**Background:** horizontal gradient  
- Left: `#FAF8F5` (cream)  
- Right: `#FBF3E0` (brand subtle) or soft gold tint `#E8C75A` at 15% opacity

**Left third:** Book cover  
- Source: `assets/tawheed.png`  
- Rounded corners ~12px, subtle shadow  
- Height ~380px, centered vertically

**Right two-thirds (text):**

1. **English title** — “Sharah Kitab at-Tawheed”  
   - Font: serif or elegant sans (e.g. Playfair Display, Cormorant)  
   - Color: `#1C1C1E`  
   - Size: ~48–56px

2. **Arabic subtitle** — `شرح کتاب التوحید`  
   - Color: `#D4AF37` (gold)  
   - Size: ~36–40px

3. **Tagline** — `50 Audio Lectures · 15 Classes`  
   - Color: `#6C6256`  
   - Size: ~22px

4. **Small line** — `Fazilat Shaikh Abdullah Nasir Rahmani حفظه الله`  
   - Size: ~16px, secondary color

5. **Website bar (bottom)** — `kitabattawheed.com`  
   - Full-width dark green bar (~56px tall) with gold accent line above  
   - URL in white, bold serif, centered — must be clearly readable at thumbnail size

**Optional:** Small headphone icon or waveform line in gold (minimal, not cluttered).

**Do not include:** “Download on Google Play” badge (Play adds its own), QR codes, pricing, or outdated “YouTube videos” wording.

## Tools

- **Canva:** custom size 1024×500, template “Google Play Feature Graphic”
- **Figma:** frame 1024×500, export @1x PNG
- **Photoshop / Affinity**

## Checklist before upload

- [ ] Exactly **1024 × 500** pixels (verify with Preview or `sips -g pixelWidth -g pixelHeight`)
- [ ] `kitabattawheed.com` visible in bottom branding bar
- [ ] No spelling “Sheikh” — use **Shaikh**
- [ ] Says **audio lectures**, not video
- [ ] File under 1 MB if possible (JPEG quality 85%)
