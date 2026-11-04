"""Offline: build the 16 edge-transition TILES between two terrain materials.

Companion to make_terrain_tiles.py, and the tile-space counterpart of
dual_grid_pack.py. The difference matters: dual_grid_pack blends two
full-size seamless swatches into square images, which is the wrong output
for this renderer twice over - wrong aspect (tiles are 128x96, not
square) and wrong detail scale (a transition tile's grass blades must be
the same size as the variant tiles' blades, or boundaries visibly change
zoom level). So transitions are blended from TILE-sized material, not
from the big swatches.

Mask convention is the renderer's, not true dual-grid: each of the 4 bits
is one edge-adjacent neighbour in FarmRenderer.NEIGHBOR_OFFSETS order
(N, E, S, W), and material B intrudes from every set edge. See
dual_grid_pack.py's header for why this project uses edge masks rather
than corner masks.
"""

import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_terrain_tiles import TILE_W, TILE_H, diamond_alpha  # noqa: E402

EDGE_BITS = {"N": 8, "E": 4, "S": 2, "W": 1}


def tile_rgb(src: str, crop: int) -> Image.Image:
    """One tile-sized RGB patch, same crop/scale pipeline as the variants."""
    img = Image.open(src).convert("RGB")
    w, h = img.size
    window = Image.new("RGB", (crop, crop))
    for dy in (0, h):
        for dx in (0, w):
            window.paste(img, (dx, dy))
    return window.resize((TILE_W, TILE_H), Image.LANCZOS)


def shared_noise(w: int, h: int, seed: int = 1337) -> np.ndarray:
    rng = np.random.default_rng(seed)
    small = rng.random((max(2, h // 12), max(2, w // 12))).astype(np.float32)
    img = Image.fromarray((small * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    img = img.filter(ImageFilter.GaussianBlur(radius=max(w, h) * 0.02))
    arr = np.asarray(img, dtype=np.float32) / 255.0
    return arr - arr.mean()


def edge_gradient(w: int, h: int, config: int) -> np.ndarray:
    """Return influence from selected edges without flooding the tile center.

    A plain max() of the four edge distances makes the center of a tile read
    as the neighbouring material whenever multiple edges are selected: with
    all four bits set, every pixel has a distance of at least 0.5 from one of
    those edges. Subtracting the centerline keeps the selected material near
    the requested edges while preserving the center material.
    """
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    yy /= (h - 1)
    xx /= (w - 1)
    infl = []
    if config & EDGE_BITS["N"]:
        infl.append(1.0 - yy)
    if config & EDGE_BITS["S"]:
        infl.append(yy)
    if config & EDGE_BITS["W"]:
        infl.append(1.0 - xx)
    if config & EDGE_BITS["E"]:
        infl.append(xx)
    if not infl:
        return np.zeros((h, w), dtype=np.float32)
    return np.clip(np.maximum.reduce(infl) - 0.5, 0.0, 1.0)


def main(argv) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--a", required=True, help="material A (the cell's own material)")
    ap.add_argument("--b", required=True, help="material B (the neighbouring material)")
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--crop", type=int, default=320)
    ap.add_argument("--softness", type=float, default=0.14)
    ap.add_argument("--noise-seed", type=int, default=1337)
    args = ap.parse_args(argv)

    os.makedirs(args.out_dir, exist_ok=True)
    a = np.asarray(tile_rgb(args.a, args.crop), dtype=np.float32)
    b = np.asarray(tile_rgb(args.b, args.crop), dtype=np.float32)
    noise = shared_noise(TILE_W, TILE_H, args.noise_seed)
    alpha = diamond_alpha(TILE_W, TILE_H)

    for config in range(16):
        grad = edge_gradient(TILE_W, TILE_H, config)
        perturbed = np.clip(grad + noise * 0.35, 0.0, 1.0)
        s = args.softness
        mask = np.clip((perturbed - (0.5 - s)) / (2 * s), 0.0, 1.0)[..., None]
        blended = a * (1.0 - mask) + b * mask
        out = Image.fromarray(np.clip(blended, 0, 255).astype(np.uint8)).convert("RGBA")
        out.putalpha(alpha)
        out.save(os.path.join(args.out_dir, f"{config:04b}.png"))

    print(f"wrote 16 transition tiles ({TILE_W}x{TILE_H}, diamond alpha) -> {args.out_dir}")
    print("bit order N=8 E=4 S=2 W=1, matching FarmRenderer.NEIGHBOR_OFFSETS")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
