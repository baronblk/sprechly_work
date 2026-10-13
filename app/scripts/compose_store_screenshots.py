#!/usr/bin/env python3
"""Composes App Store screenshots from the raw captures.

`scripts/screenshots.sh` produces plain screen recordings of the app. The store
needs those framed with a headline, because the first one or two images decide
whether anyone taps through at all. This step adds the caption and leaves the
app itself as the main subject — no mockup chrome, no marketing clutter.

Reads the captions from `Screenshots/captions.json`, writes to
`Screenshots/store/<lang>/<device>/`. Sizes are preserved, so the output stays
within the App Store specification the raw capture already satisfied.

Usage: python3 scripts/compose_store_screenshots.py
"""
from __future__ import annotations

import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

RAW_ROOT = "Screenshots"
OUT_ROOT = "Screenshots/store"
CAPTIONS = "Screenshots/captions.json"

# SF Rounded is what the app's own design system uses (`design: .rounded`).
FONT_PATH = "/System/Library/Fonts/SFNSRounded.ttf"

# Theme.Colors, matched to the app so the caption area and the screenshot read
# as one image.
BACKGROUND = (18, 15, 13)
TEXT_PRIMARY = (255, 255, 255)
ACCENT = (227, 179, 84)


def font(size: int, weight: str) -> ImageFont.FreeTypeFont:
    face = ImageFont.truetype(FONT_PATH, size)
    try:
        face.set_variation_by_name(weight)
    except Exception:  # noqa: BLE001 - static fallback is fine
        pass
    return face


def wrap(draw: ImageDraw.ImageDraw, text: str, face, max_width: int) -> list[str]:
    """Greedy word wrap against the real rendered width."""
    words, lines, current = text.split(), [], ""
    for word in words:
        candidate = f"{current} {word}".strip()
        if draw.textlength(candidate, font=face) <= max_width or not current:
            current = candidate
        else:
            lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def trim_empty_bottom(shot: Image.Image) -> Image.Image:
    """Crops dead space off the bottom so the content can be shown larger.

    Several screens end in a tall run of empty background (a short transcript, a
    half-filled list), and scaling that into the store image wastes the area
    that decides whether anyone reads the screenshot.

    Emptiness is judged by the *spread* within each row rather than by distance
    from a sampled background colour: the app's backgrounds carry a soft
    gradient, which defeats a colour comparison but leaves each individual row
    nearly uniform. At most a third is ever removed, so a genuinely full screen
    is never cut.
    """
    grey = shot.convert("L")
    pixels = grey.load()
    width, height = grey.size
    floor = int(height * 0.66)
    step = max(1, width // 200)

    last_content = floor
    for y in range(height - 1, floor, -1):
        row = [pixels[x, y] for x in range(0, width, step)]
        if max(row) - min(row) > 16:  # text or a control, not a gradient
            last_content = y
            break

    padding = int(height * 0.025)
    cut = min(height, last_content + padding)
    return shot if cut >= height - 2 else shot.crop((0, 0, width, cut))


def compose(src: str, dst: str, headline: str, subline: str) -> None:
    shot = Image.open(src).convert("RGB")
    shot = trim_empty_bottom(shot)
    width, height = Image.open(src).size

    canvas = Image.new("RGB", (width, height), BACKGROUND)
    draw = ImageDraw.Draw(canvas)

    # Scale with the image so iPhone and iPad are composed consistently, but
    # damp it on large canvases: at full scale an iPad headline grows so much
    # that short lines wrap, splitting phrases like "5 Zeilen" across rows.
    unit = min(width / 1320, 1.25)
    margin = int(72 * unit)
    top = int(96 * unit)
    headline_font = font(int(78 * unit), "Bold")
    subline_font = font(int(46 * unit), "Medium")
    text_width = width - 2 * margin

    y = top
    for line in wrap(draw, headline, headline_font, text_width):
        draw.text((margin, y), line, font=headline_font, fill=TEXT_PRIMARY)
        y += int(headline_font.size * 1.16)

    if subline:
        y += int(18 * unit)
        for line in wrap(draw, subline, subline_font, text_width):
            draw.text((margin, y), line, font=subline_font, fill=ACCENT)
            y += int(subline_font.size * 1.22)

    # The device shot fills the rest, cropped at the bottom rather than squashed,
    # so the app keeps its real proportions.
    caption_bottom = y + int(56 * unit)
    available = height - caption_bottom
    scaled_width = width - 2 * margin
    scale = scaled_width / shot.width
    scaled_height = int(shot.height * scale)
    shot = shot.resize((scaled_width, scaled_height), Image.LANCZOS)
    if scaled_height > available:
        shot = shot.crop((0, 0, scaled_width, available))

    rounded = Image.new("L", shot.size, 0)
    ImageDraw.Draw(rounded).rounded_rectangle(
        [(0, 0), shot.size], radius=int(44 * unit), fill=255
    )
    canvas.paste(shot, (margin, caption_bottom), rounded)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    canvas.save(dst)
    print(f"  {dst}")


def main() -> int:
    if not os.path.exists(CAPTIONS):
        print(f"missing {CAPTIONS}")
        return 1
    captions = json.load(open(CAPTIONS, encoding="utf-8"))

    written = 0
    for lang, entries in captions.items():
        raw_lang_dir = os.path.join(RAW_ROOT, lang)
        if not os.path.isdir(raw_lang_dir):
            print(f"no raw captures for {lang} — run scripts/screenshots.sh")
            continue
        for device in sorted(os.listdir(raw_lang_dir)):
            raw_device_dir = os.path.join(raw_lang_dir, device)
            if not os.path.isdir(raw_device_dir):
                continue
            print(f"== {lang} / {device} ==")
            family = "iPad" if "ipad" in device.lower() else "iPhone"
            for name, caption in entries.items():
                src = os.path.join(raw_device_dir, f"{name}.png")
                if not os.path.exists(src):
                    print(f"  (missing {name}.png)")
                    continue
                # A caption may override per device family — "on your iPhone"
                # must not appear on an iPad screenshot.
                variant = caption.get(family, {})
                headline = variant.get("headline", caption["headline"])
                subline = variant.get("subline", caption.get("subline", ""))
                dst = os.path.join(OUT_ROOT, lang, device, f"{name}.png")
                compose(src, dst, headline, subline)
                written += 1

    print(f"\n{written} store screenshots written to {OUT_ROOT}/")
    return 0 if written else 1


if __name__ == "__main__":
    sys.exit(main())
