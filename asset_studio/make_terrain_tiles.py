"""Offline: turn a big seamless material swatch into game-ready terrain TILES.

Why this exists (a real bug this fixes)
----------------------------------------
The first ADR-042 texture drop shipped the raw 1254x1254 seamless swatches
straight into data/terrain_manifest.json. That was wrong in three separate
ways, all of which showed up the moment the game was actually loaded:

1. **Opaque squares.** farm_renderer.gd's `_draw_textured_cell` documents
   its authoring contract explicitly: a tile is drawn into the cell's
   TILE_W x TILE_H bounding rect, and *adjacent cells' rects overlap at
   their corners*, so anything opaque outside the inscribed diamond paints
   over the neighbouring cell. The swatches were RGB with no alpha at all,
   so every cell stamped an opaque rectangle over its neighbours.
2. **Ruinous minification.** Drawing a 1.5-megapixel texture into a 64x48
   rect, ~600 visible cells per redraw, with no mipmaps, thrashes the GPU
   texture cache badly enough to make the game unplayable.
3. **Wasted seamlessness, zero variation.** With the whole swatch as the
   source rect, every cell showed the ENTIRE grass field squashed into one
   tile - so all cells looked identical, the fine detail turned to mush,
   and the carefully-blended seamless edges were never sampled as tiles at
   all.

So the swatch is source MATERIAL, not a tile. This script crops
tile-sized windows out of it (which is what makes the seamlessness
matter, and gives the renderer's variant system real variety for free),
scales them to the tile's aspect, and applies the diamond alpha mask the
renderer actually requires.

Detail scale is set by --crop: a smaller crop window means fewer, larger
grass blades per tile. It is the one knob worth eyeballing.
"""

import argparse
import os
import sys

from PIL import Image

# Authored at 2x the 64x48 screen tile for a little zoom headroom; linear
# filtering handles the 2x minification cleanly, and staying this small is
# what keeps the per-cell draw cheap (problem 2 above).
TILE_W = 128
TILE_H = 96


def diamond_alpha(w: int, h: int, feather: float = 1.0) -> Image.Image:
    """Alpha mask: opaque inside the inscribed diamond, transparent outside.

    The renderer draws this into the cell's bounding rect, and the diamond
    inscribed in that rect is exactly the cell. |dx|/hw + |dy|/hh <= 1 is
    the diamond; the feather softens the 1px staircase so adjacent tiles
    don't show a hard sawtooth seam where they meet.
    """
    mask = Image.new("L", (w, h), 0)
    px = mask.load()
    hw, hh = w / 2.0, h / 2.0
    for y in range(h):
        dy = abs((y + 0.5) - hh) / hh
        for x in range(w):
            dx = abs((x + 0.5) - hw) / hw
            d = dx + dy
            if d <= 1.0:
                # Feather only the outermost sliver, in normalized units.
                edge = (1.0 - d) * min(hw, hh)
                px[x, y] = 255 if edge >= feather else int(255 * (edge / feather))
    return mask


def make_tiles(src: str, out_dir: str, prefix: str, count: int, crop: int) -> list:
    img = Image.open(src).convert("RGB")
    w, h = img.size
    if crop > min(w, h):
        raise ValueError(f"--crop {crop} exceeds source {w}x{h}")
    os.makedirs(out_dir, exist_ok=True)
    mask = diamond_alpha(TILE_W, TILE_H)

    # Spread crop windows across the swatch so variants differ. The source
    # is seamless, so a window may wrap past the edge without a visible cut.
    written = []
    for i in range(count):
        fx = (i * 0.37) % 1.0          # irrational-ish stride, avoids reuse
        fy = (i * 0.61) % 1.0
        ox, oy = int(fx * w), int(fy * h)
        # Wrap-aware crop: paste the (possibly wrapped) window into a canvas.
        # The wrapped copies go at +w/+h, not -w/-h: a window starting at ox
        # near the right edge needs the image repeated to its RIGHT to fill
        # the overhang. Getting this backwards leaves the overhang as unpasted
        # black, which showed up as black triangles once the tiles were laid
        # out in the dimetric lattice.
        window = Image.new("RGB", (crop, crop))
        for dy in (0, h):
            for dx in (0, w):
                window.paste(img, (-ox + dx, -oy + dy))
        tile = window.resize((TILE_W, TILE_H), Image.LANCZOS).convert("RGBA")
        tile.putalpha(mask)
        path = os.path.join(out_dir, f"{prefix}_{i}.png")
        tile.save(path)
        written.append(path)
    return written


def mask_existing(src: str, dest: str) -> None:
    """Tile-size + diamond-mask an already-composited tile (transitions)."""
    img = Image.open(src).convert("RGB").resize((TILE_W, TILE_H), Image.LANCZOS)
    rgba = img.convert("RGBA")
    rgba.putalpha(diamond_alpha(TILE_W, TILE_H))
    rgba.save(dest)


def main(argv) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", help="seamless material swatch")
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--prefix", default="tile")
    ap.add_argument("--count", type=int, default=4, help="variant tiles to cut")
    ap.add_argument("--crop", type=int, default=320,
                     help="source-pixel window per tile; smaller = larger detail")
    ap.add_argument("--mask-dir", help="instead: diamond-mask every PNG in this dir in place")
    args = ap.parse_args(argv)

    if args.mask_dir:
        os.makedirs(args.out_dir, exist_ok=True)
        n = 0
        for f in sorted(os.listdir(args.mask_dir)):
            if not f.lower().endswith(".png"):
                continue
            mask_existing(os.path.join(args.mask_dir, f), os.path.join(args.out_dir, f))
            n += 1
        print(f"masked {n} tiles -> {args.out_dir} ({TILE_W}x{TILE_H}, diamond alpha)")
        return 0

    if not args.src:
        ap.error("--src required unless --mask-dir is used")
    written = make_tiles(args.src, args.out_dir, args.prefix, args.count, args.crop)
    print(f"wrote {len(written)} tiles ({TILE_W}x{TILE_H}, diamond alpha) -> {args.out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
