#!/usr/bin/env python3
"""Composes the App Store **creative asset** — the product page header.

This is a different animal from `compose_store_screenshots.py`. A store
screenshot is a portrait phone screen with a caption above it. A creative asset
is a wide landscape image that sits across the top of the product page and, in
the same size, inside search results. Apple accepts 16:9 at 5244 x 2950 for
*both* placements, so one file per language covers the pair rather than two.

Nothing in the asset library fits: every one of the app's 115 confirmed assets
is a portrait screenshot or preview, and App Store Connect reports those as
working with "App-Bildschirmfoto" only. Hence a separate composer.

The app screen used here is a real capture, placed unaltered. Only the
surrounding canvas and the caption are drawn — the same rule the store
screenshots follow.

Usage: python3 scripts/compose_creative_asset.py [de|en ...]
"""
from __future__ import annotations

import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

RAW_ROOT = "Screenshots"
OUT_ROOT = "assets/creative"
CAPTIONS = "Screenshots/captions.json"
DEVICE = "iPhone 17 Pro Max"
MOTIF = "01-transcript"

# Apple's 16:9 creative asset, accepted for the product page header and for
# search results. PNG without an alpha channel — transparency is rejected.
WIDTH, HEIGHT = 5244, 2950

# Same type and colours as the app and the store screenshots, so the header
# reads as part of one set rather than as an advert bolted on.
FONT_PATH = "/System/Library/Fonts/SFNSRounded.ttf"
BACKGROUND = (18, 15, 13)
TEXT_PRIMARY = (255, 255, 255)
ACCENT = (227, 179, 84)
# The warm cast the app's own background carries. Kept far below the text in
# contrast so the headline stays the brightest thing in the frame.
GLOW = (74, 56, 30)

MARGIN = 300
GAP = 200
# The transcript list inside the raw capture, measured on the 1320 x 2868
# screenshot: the first timestamp down to the last line. Cropping to it and
# scaling the crop to the full canvas height is what makes the app's own text
# readable here. A whole phone screen placed in a 16:9 frame ends up about a
# fifth of the width, and at search-result size its content is a grey smudge.
LIST_TOP, LIST_BOTTOM = 930, 2760
# The crop sits as a rounded card on the canvas, the same treatment the store
# screenshots give the device shot. A soft fade was tried first and dimmed the
# timestamp column, which read as a rendering fault rather than as styling.
CARD_MARGIN = 190
CARD_RADIUS = 76


def font(size: int, weight: str) -> ImageFont.FreeTypeFont:
    face = ImageFont.truetype(FONT_PATH, size)
    try:
        face.set_variation_by_name(weight)
    except Exception:  # noqa: BLE001 - static fallback is fine
        pass
    return face


def wrap(draw: ImageDraw.ImageDraw, text: str, face, max_width: int) -> list[str]:
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


def fit(draw: ImageDraw.ImageDraw, text: str, max_width: int, max_lines: int,
        high: int, low: int, weight: str) -> tuple[ImageFont.FreeTypeFont, list[str]]:
    """Largest size at which the text still fits within `max_lines`.

    Searched rather than fixed because the German and English headlines differ
    in length, and a size tuned to one of them either overflows or leaves the
    other looking undersized.
    """
    for size in range(high, low - 1, -4):
        face = font(size, weight)
        lines = wrap(draw, text, face, max_width)
        if len(lines) <= max_lines:
            return face, lines
    face = font(low, weight)
    return face, wrap(draw, text, face, max_width)


def background() -> Image.Image:
    """Dark canvas with a soft warm glow behind the screen.

    Drawn small and scaled up: a radial falloff evaluated per pixel over 15.5
    million pixels is slow in pure Python, and the upscale of a 240-wide source
    is smooth enough that no banding survives the resize.
    """
    small_w, small_h = 240, 135
    small = Image.new("RGB", (small_w, small_h), BACKGROUND)
    pixels = small.load()
    # Centred on the screen's side of the canvas, so the glow lifts the device
    # out of the background instead of washing out the headline.
    cx, cy = small_w * 0.30, small_h * 0.48
    radius = small_w * 0.46
    for y in range(small_h):
        for x in range(small_w):
            dx, dy = (x - cx) / radius, (y - cy) / radius
            d = (dx * dx + dy * dy) ** 0.5
            k = max(0.0, 1.0 - d) ** 2
            pixels[x, y] = tuple(
                int(b + (g - b) * k) for b, g in zip(BACKGROUND, GLOW)
            )
    return small.resize((WIDTH, HEIGHT), Image.LANCZOS)


def rounded(shot: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([(0, 0), shot.size], radius=radius, fill=255)
    return mask


def compose(lang: str, headline: str, subline: str) -> str:
    src = f"{RAW_ROOT}/{lang}/{DEVICE}/{MOTIF}.png"
    shot = Image.open(src).convert("RGB")

    canvas = background()
    draw = ImageDraw.Draw(canvas)

    # The transcript panel: cropped to the list, scaled, and set as a rounded
    # card. It fixes how much width the text may claim.
    panel = shot.crop((0, LIST_TOP, shot.width, LIST_BOTTOM))
    panel_h = HEIGHT - 2 * CARD_MARGIN
    panel_w = int(panel.width * panel_h / panel.height)
    panel = panel.resize((panel_w, panel_h), Image.LANCZOS)
    panel_x = WIDTH - CARD_MARGIN - panel_w
    canvas.paste(panel, (panel_x, CARD_MARGIN), rounded(panel, CARD_RADIUS))

    text_width = panel_x - GAP - MARGIN
    headline_font, headline_lines = fit(
        draw, headline, text_width, 2, 360, 140, "Bold")
    subline_font, subline_lines = fit(
        draw, subline, text_width, 2, int(headline_font.size * 0.46),
        int(headline_font.size * 0.3), "Medium")

    line_h = int(headline_font.size * 1.14)
    sub_line_h = int(subline_font.size * 1.26)
    block_h = len(headline_lines) * line_h + int(headline_font.size * 0.42) \
        + len(subline_lines) * sub_line_h
    y = (HEIGHT - block_h) // 2

    for line in headline_lines:
        draw.text((MARGIN, y), line, font=headline_font, fill=TEXT_PRIMARY)
        y += line_h
    y += int(headline_font.size * 0.42)
    for line in subline_lines:
        draw.text((MARGIN, y), line, font=subline_font, fill=ACCENT)
        y += sub_line_h

    dst = f"{OUT_ROOT}/default/{lang}/header-16x9.png"
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    canvas.save(dst)  # RGB throughout, so the file carries no alpha channel
    print(f"  {dst}  {canvas.size}  Panel {panel_w}px  headline {headline_font.size}px "
          f"({len(headline_lines)} Zeilen)")
    return dst


def main() -> int:
    captions = json.load(open(CAPTIONS, encoding="utf-8"))
    langs = sys.argv[1:] or ["de", "en"]
    for lang in langs:
        entry = captions[lang][MOTIF]
        compose(lang, entry["headline"], entry["subline"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
