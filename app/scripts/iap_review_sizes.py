#!/usr/bin/env python3
"""Derives IAP review screenshots in alternative App Store Connect sizes.

The 6.9" paywall shot from `scripts/paywall_shot.sh` is a valid screenshot size,
but the in-app purchase upload field can reject it. This produces the same image
at other accepted sizes, scaled to fit and padded with the app's background so
nothing (product name, price, restore) is cropped away.

Usage: python3 scripts/iap_review_sizes.py
"""
import os

from PIL import Image

SIZES = [(1290, 2796), (1242, 2208), (640, 920)]
OUT = "Screenshots/iap-review"


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for lang in ("de", "en"):
        src = f"Screenshots/{lang}/iPhone 17 Pro Max/iap-paywall.png"
        if not os.path.exists(src):
            print(f"missing source: {src} — run scripts/paywall_shot.sh first")
            continue
        image = Image.open(src).convert("RGB")  # convert drops any alpha
        background = image.getpixel((5, image.height // 2))
        for width, height in SIZES:
            scaled = image.copy()
            scaled.thumbnail((width, height), Image.LANCZOS)
            canvas = Image.new("RGB", (width, height), background)
            canvas.paste(
                scaled,
                ((width - scaled.width) // 2, (height - scaled.height) // 2),
            )
            path = f"{OUT}/paywall-{lang}-{width}x{height}.png"
            canvas.save(path)
            print(path)


if __name__ == "__main__":
    main()
