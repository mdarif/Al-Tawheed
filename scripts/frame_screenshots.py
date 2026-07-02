#!/usr/bin/env python3
"""Frame raw app screenshots into clean device mockups for the Play Store.

Reads raw captures from docs/play-store/v3/raw/ (produced by the
screenshots_test.dart capture harness) and composites each onto a branded
canvas: a thin-bezel phone body with rounded corners + soft shadow on a subtle
cream->gold gradient. No caption text ("clean device frames only").

Output:
  docs/play-store/v3/framed/<id>-framed.png   (Play-ready, 2:1, no alpha)
  docs/play-store/v3/preview.png              (all frames side-by-side)

Requires Pillow:  pip install Pillow
Run via:          make screenshots   (capture + frame)
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "docs/play-store/v3/raw"
OUT = ROOT / "docs/play-store/v3/framed"
PREVIEW = ROOT / "docs/play-store/v3/preview.png"

# Play Store upload order: onboarding first (the neutral welcome everyone sees,
# then the series picker), then the Arabic block, then the Urdu block. Each
# entry is (raw_capture_id, output_label); the framed file is numbered by
# position, so output name == upload order regardless of raw capture names.
# Play allows max 8 — positions 1-8 are the upload set; 9-10 are swap-ins.
ORDER = [
    ("04-welcome-ur", "welcome"),        # 1 — generic welcome (everyone's 1st screen)
    ("03-choose-series", "choose-series"),  # 2 — pick Arabic or Urdu
    ("01-welcome-ar", "welcome-ar"),     # 3 — Arabic series welcome (al-Fawzan)
    ("02-book-ar", "book-ar"),           # 4 — Arabic Book tab (new feature)
    ("08-player-ar", "player-ar"),       # 5 — Arabic player يُشغَّل الآن
    ("05-lectures-ur", "lectures-ur"),   # 6 — Urdu lectures (Class 01)
    ("06-study-ur", "study-ur"),         # 7 — Study Mode (Urdu-only)
    ("07-player-ur", "player-ur"),       # 8 — Urdu Now Playing
    # ── swap-in extras (beyond Play's 8-slot cap) ──
    ("09-lectures-ar", "lectures-ar"),   # 9 — Arabic lectures الدروس
    ("10-settings-ur", "settings-ur"),   # 10 — Settings
]

# Canvas: 2:1 (Play's max aspect), high-res. Phone content is ~2.17:1 so it sits
# with small top/bottom margins.
CANVAS = (1290, 2580)
BG_TOP = (250, 248, 245)      # cream  #FAF8F5
BG_BOTTOM = (251, 243, 224)   # soft gold #FBF3E0
BEZEL_COLOR = (17, 18, 20)    # near-black thin bezel
PHONE_W_FRAC = 0.86           # phone body width as fraction of canvas width
BEZEL = 14                    # bezel thickness (px)
SCREEN_RADIUS = 62            # screen corner radius (px)
BODY_RADIUS = 78              # phone body corner radius (px)
SHADOW_BLUR = 55
SHADOW_ALPHA = 90
SHADOW_DY = 34


def gradient_bg(size):
    w, h = size
    bg = Image.new("RGB", size)
    top, bottom = BG_TOP, BG_BOTTOM
    for y in range(h):
        t = y / (h - 1)
        r = round(top[0] + (bottom[0] - top[0]) * t)
        g = round(top[1] + (bottom[1] - top[1]) * t)
        b = round(top[2] + (bottom[2] - top[2]) * t)
        bg.paste((r, g, b), (0, y, w, y + 1))
    return bg


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return mask


def frame_one(raw_path):
    shot = Image.open(raw_path).convert("RGB")
    cw, ch = CANVAS

    # Fit the phone body within both a max width and max height (whichever
    # binds) — so a tall phone raw sits cleanly on a wider/taller tablet canvas.
    max_body_w = cw * PHONE_W_FRAC
    max_body_h = ch * 0.92
    screen_w = max_body_w - 2 * BEZEL
    screen_h = shot.height * (screen_w / shot.width)
    if screen_h + 2 * BEZEL > max_body_h:
        screen_h = max_body_h - 2 * BEZEL
        screen_w = shot.width * (screen_h / shot.height)
    screen_w, screen_h = round(screen_w), round(screen_h)
    body_w = screen_w + 2 * BEZEL
    body_h = screen_h + 2 * BEZEL

    shot = shot.resize((screen_w, screen_h), Image.LANCZOS)

    # Round the screenshot corners.
    shot_r = Image.new("RGBA", shot.size, (0, 0, 0, 0))
    shot_r.paste(shot, (0, 0), rounded_mask(shot.size, SCREEN_RADIUS))

    # Phone body (bezel) as a rounded rect.
    body = Image.new("RGBA", (body_w, body_h), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle(
        [0, 0, body_w - 1, body_h - 1], radius=BODY_RADIUS, fill=BEZEL_COLOR + (255,)
    )
    body.alpha_composite(shot_r, (BEZEL, BEZEL))

    canvas = gradient_bg(CANVAS).convert("RGBA")
    bx = (cw - body_w) // 2
    by = (ch - body_h) // 2

    # Soft drop shadow.
    shadow = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [bx, by + SHADOW_DY, bx + body_w, by + body_h + SHADOW_DY],
        radius=BODY_RADIUS,
        fill=(20, 18, 12, SHADOW_ALPHA),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(SHADOW_BLUR))
    canvas = Image.alpha_composite(canvas, shadow)

    canvas.alpha_composite(body, (bx, by))
    return canvas.convert("RGB")  # drop alpha (Play requirement)


def build_preview(frames):
    cols = len(frames)
    thumb_w = 300
    scale = thumb_w / CANVAS[0]
    thumb_h = round(CANVAS[1] * scale)
    gap = 24
    strip = Image.new(
        "RGB", (cols * thumb_w + (cols + 1) * gap, thumb_h + 2 * gap), (245, 243, 240)
    )
    for i, fr in enumerate(frames):
        t = fr.resize((thumb_w, thumb_h), Image.LANCZOS)
        strip.paste(t, (gap + i * (thumb_w + gap), gap))
    strip.save(PREVIEW)


def _apply_mode(mode):
    """Phone (default) or tablet. Tablet uses a portrait 3:4 canvas (1800x2400):
    both sides land in [1080, 3840], so ONE set satisfies both the 7-inch and
    10-inch Play slots, and 0.75 is within Play's 9:16..16:9 tablet range."""
    global RAW, OUT, PREVIEW, CANVAS
    if mode == "tablet":
        # Reuse the high-res phone captures — Play accepts phone content in the
        # tablet slots; only the aspect/size must fit. 1440x2560 is 9:16 (within
        # Play's 9:16..16:9 tablet range) and both sides land in [1080, 3840], so
        # ONE set satisfies both the 7-inch and 10-inch slots.
        RAW = ROOT / "docs/play-store/v3/raw"
        OUT = ROOT / "docs/play-store/v3/framed-tablet"
        PREVIEW = ROOT / "docs/play-store/v3/preview-tablet.png"
        CANVAS = (1440, 2560)


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "phone"
    _apply_mode(mode)
    print(f"mode: {mode}  canvas: {CANVAS[0]}x{CANVAS[1]}")
    OUT.mkdir(parents=True, exist_ok=True)
    frames = []
    missing = []
    for i, (raw_name, label) in enumerate(ORDER, start=1):
        raw = RAW / f"{raw_name}.png"
        if not raw.exists():
            missing.append(raw_name)
            continue
        framed = frame_one(raw)
        out_name = f"{i:02d}-{label}-framed.png"
        framed.save(OUT / out_name)
        frames.append(framed)
        print(f"  {out_name}  <-  {raw_name}  ({framed.size[0]}x{framed.size[1]})")
    if missing:
        print(f"WARNING: missing raws (skipped): {', '.join(missing)}", file=sys.stderr)
    if frames:
        build_preview(frames)
        print(f"preview: {PREVIEW.relative_to(ROOT)}  ({len(frames)} frames)")
    else:
        print("No raws found — run the capture first (make screenshots).", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
