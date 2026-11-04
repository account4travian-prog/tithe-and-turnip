"""Offline: turn a generated material swatch into a truly tileable texture.

Why this exists
----------------
Terra's own ADR-042 consult was explicit: AI generators cannot be trusted
to produce a genuinely seamless tile just because the prompt says
"seamless" - "terrain needs true edge compatibility, not merely a keyed-
out background." Rather than fight the generator for something it is
unreliable at, seamlessness is solved DETERMINISTICALLY here, with a
technique that is decades old and always works: the classic
offset-wrap-and-blend.

Algorithm (classic, not novel - documented so it isn't mistaken for a
guess): roll the image by half its width and half its height (wrap-
around), which moves what used to be the four separate edges into two
crossing seams through the MIDDLE of the frame. Blend a soft band across
each seam by averaging original and offset-then-mirrored content across
it. What used to be unrelated edges are now smoothly blended interior
content, so the four true edges - now untouched - already match up when
the tile repeats, because each edge is identical to the offset copy's
opposite edge by construction.

Usage:
    python make_seamless.py --input swatch.png --output grass_0.png
    python make_seamless.py --input swatch.png --output grass_0.png --tile-preview
"""

import argparse
import sys

from PIL import Image, ImageChops


def offset_wrap(img: Image.Image) -> Image.Image:
    w, h = img.size
    return ImageChops.offset(img, w // 2, h // 2)


def make_seamless(img: Image.Image, band_frac: float = 0.18) -> Image.Image:
    """Blend the offset-wrapped seams back into smooth interior content."""
    img = img.convert("RGB")
    w, h = img.size
    offset = offset_wrap(img)

    band_w = max(4, int(w * band_frac))
    band_h = max(4, int(h * band_frac))

    out = img.copy()
    px_out = out.load()
    px_off = offset.load()

    # Vertical seam band around x = w/2 (blend original vs offset).
    cx = w // 2
    for x in range(cx - band_w, cx + band_w):
        if x < 0 or x >= w:
            continue
        t = abs(x - cx) / band_w
        t = min(1.0, t)
        weight_off = 1.0 - t  # closer to seam -> more offset content
        for y in range(h):
            a = px_out[x, y]
            b = px_off[x, y]
            px_out[x, y] = tuple(
                int(a[c] * (1.0 - weight_off) + b[c] * weight_off) for c in range(3)
            )

    # Horizontal seam band around y = h/2.
    cy = h // 2
    for y in range(cy - band_h, cy + band_h):
        if y < 0 or y >= h:
            continue
        t = abs(y - cy) / band_h
        t = min(1.0, t)
        weight_off = 1.0 - t
        for x in range(w):
            a = px_out[x, y]
            b = px_off[x, y]
            px_out[x, y] = tuple(
                int(a[c] * (1.0 - weight_off) + b[c] * weight_off) for c in range(3)
            )

    return out


def tile_preview(img: Image.Image, reps: int = 3) -> Image.Image:
    w, h = img.size
    sheet = Image.new("RGB", (w * reps, h * reps))
    for r in range(reps):
        for c in range(reps):
            sheet.paste(img, (c * w, r * h))
    return sheet


def main(argv) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--output", required=True)
    ap.add_argument("--band-frac", type=float, default=0.18,
                     help="fraction of dimension blended at each seam")
    ap.add_argument("--tile-preview", action="store_true",
                     help="also write a 3x3 tiled preview next to --output")
    args = ap.parse_args(argv)

    img = Image.open(args.input)
    seamless = make_seamless(img, args.band_frac)
    seamless.save(args.output)
    print(f"wrote {args.output} ({seamless.size[0]}x{seamless.size[1]})")

    if args.tile_preview:
        prev_path = args.output.rsplit(".", 1)[0] + "_tilepreview.png"
        tile_preview(seamless).save(prev_path)
        print(f"wrote {prev_path} (3x3 tiling check - inspect for visible seams)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
