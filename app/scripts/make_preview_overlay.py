#!/usr/bin/env python3
"""Renders the closing line of the app preview as a transparent PNG.

The overlay is drawn here rather than with ffmpeg's `drawtext` because the
ffmpeg on this machine is built without libfreetype, so that filter does not
exist. Pillow and the app's own font are already used to caption the store
screenshots, so this keeps one text-rendering path instead of adding a
dependency.

Usage: python3 scripts/make_preview_overlay.py <de|en> <width> <height> <out.png>
"""
from __future__ import annotations

import sys

from PIL import Image, ImageDraw, ImageFont

# Matches the store screenshots, so the preview and the stills read as one set.
FONT_PATH = "/System/Library/Fonts/SFNSRounded.ttf"
TEXT_PRIMARY = (255, 255, 255, 255)
ACCENT = (227, 179, 84, 255)

LINES = {
    "de": ("Kein Abo. Kein Konto.", "Transkription auf dem Gerät."),
    "en": ("No subscription. No account.", "Transcription on your device."),
}


def font(size: int, weight: str) -> ImageFont.FreeTypeFont:
    face = ImageFont.truetype(FONT_PATH, size)
    try:
        face.set_variation_by_name(weight)
    except Exception:  # noqa: BLE001 - the static face is fine
        pass
    return face


def main() -> int:
    if len(sys.argv) != 5:
        print(__doc__)
        return 2
    lang, width, height, out = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
    if lang not in LINES:
        print(f"unknown language: {lang}")
        return 2
    first, second = LINES[lang]

    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)

    unit = width / 886
    primary = font(int(46 * unit), "Bold")
    secondary = font(int(38 * unit), "Medium")

    gap = int(16 * unit)
    first_box = draw.textbbox((0, 0), first, font=primary)
    second_box = draw.textbbox((0, 0), second, font=secondary)
    block_height = (first_box[3] - first_box[1]) + gap + (second_box[3] - second_box[1])

    # Sits in the lower third, where the library list has the least detail, with
    # a scrim so the text stays readable over whatever is behind it.
    top = int(height * 0.66)
    padding = int(44 * unit)
    draw.rectangle(
        [(0, top - padding), (width, top + block_height + padding)],
        fill=(18, 15, 13, 200),
    )

    y = top - first_box[1]
    draw.text(((width - (first_box[2] - first_box[0])) / 2, y), first,
              font=primary, fill=TEXT_PRIMARY)
    y += (first_box[3] - first_box[1]) + gap - second_box[1]
    draw.text(((width - (second_box[2] - second_box[0])) / 2, y), second,
              font=secondary, fill=ACCENT)

    canvas.save(out)
    print(f"  overlay: {out} ({width}x{height})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
