"""Extract a combined palette + tone stats from inspiration images.

Usage:
    python inspire.py ref1.png [ref2.png ...]

Writes style_reference.json (palette, average saturation/brightness, sources)
so the palette can be copied into config.json's allowed_palette.
"""

import json
import os
import sys
from collections import Counter

from PIL import Image, ImageStat


def palette_from_image(path: str, top_n: int) -> Counter:
    img = Image.open(path).convert("RGB")
    img.thumbnail((256, 256))  # palette extraction does not need full res
    colors = img.getcolors(maxcolors=2_000_000)
    if colors is None:
        return Counter()
    return Counter({color: count for count, color in colors})


def tone_stats(path: str) -> dict:
    img = Image.open(path).convert("HSV")
    stat = ImageStat.Stat(img)
    sat = stat.mean[1] / 255.0
    val = stat.mean[2] / 255.0
    return {"avg_saturation": round(sat, 3), "avg_brightness": round(val, 3)}


def main(argv: list) -> int:
    if not argv:
        print(__doc__)
        return 1
    top_n = 12
    merged = Counter()
    stats = []
    for path in argv:
        if not os.path.isfile(path):
            print(f"SKIP (not a file): {path}")
            continue
        merged.update(palette_from_image(path, top_n))
        stats.append({"file": os.path.basename(path), **tone_stats(path)})
    palette = [
        {"hex": "#{:02x}{:02x}{:02x}".format(*color), "weight": count}
        for color, count in merged.most_common(top_n)
    ]
    result = {"sources": [os.path.basename(p) for p in argv], "tone": stats, "palette": palette}
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "style_reference.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2)
    print("Palette (by weight):")
    for entry in palette:
        print(f"  {entry['hex']}  weight {entry['weight']}")
    print(f"-> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
