"""Offline: build the 16 dual-grid transition tiles between two seamless
base materials, with an irregular (not diamond-shaped) boundary.

Why this exists
----------------
ADR-042 / the art director's consult was explicit that a transition tile
must NOT look like "a hard diamond outline recolored" - the boundary
between grass and dirt needs to read as broken, organic ground, not a
clean geometric split. This script never asks a generator for that (an
AI transition tile would look different for every material pair and
break dual-grid's whole point, which is that the SAME 16 boundary shapes
work for any material pair). Instead the boundary shape is authored once,
deterministically, and reused for every pair - only the pixel content
inside it changes.

Two mask conventions - PICK THE ONE YOUR RENDERER ACTUALLY USES
------------------------------------------------------------------
2026-08-08 bug, caught before shipping: this script originally only
implemented true corner-based dual-grid masks (TL/TR/BR/BL corners
belong to material B, offset half-cell grid). But farm_renderer.gd's
ADR-042 implementation deliberately does NOT use half-cell dual-grid -
it samples the cell's own 4 EDGE-ADJACENT neighbours (N/E/S/W - see
FarmRenderer.NEIGHBOR_OFFSETS and transition_lookup()) and asks for a
tile per "which edges border a different material," not "which corners
are the other material." Same 16-value range (4 bits), COMPLETELY
different geometry per index - corner config "1000" is a tiny wedge in
one corner; edge config "1000" is material B intruding from one whole
side. Shipping corner tiles against an edge-consuming renderer produces
transition art that doesn't match what's actually being requested.

`--mode edge` (default - matches this project's FarmRenderer) treats
each bit as one of the 4 orthogonal edges (N,E,S,W - the exact order of
FarmRenderer.NEIGHBOR_OFFSETS / transition_lookup()'s mask string) and
blends material B in from every SET edge, fading toward the center.
`--mode corner` keeps the original true dual-grid corner behaviour for
any future half-cell-offset renderer that might want it.

The boundary mask
------------------
For each config, a base gradient (edge-influence or corner-bilinear,
per --mode) is perturbed by ONE shared irregular noise field (generated
once, reused for every config and every material pair so tiles from the
same pack stay visually coherent) before being thresholded with a soft
edge. This turns what would otherwise be a straight or diagonal seam
into a broken, natural-looking boundary - the actual fix for the
"recolored diamond outline" problem, not a cosmetic filter on top of one.

Usage:
    python dual_grid_pack.py --a grass_0.png --b tilled_0.png \
        --out-dir out/grass_tilled --size 256 --mode edge
"""

import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

CORNERS = ["TL", "TR", "BR", "BL"]
BITS = {"TL": 8, "TR": 4, "BR": 2, "BL": 1}


def _shared_noise(size: int, seed: int = 1337) -> np.ndarray:
    """One tileable noise field, reused across every config/pair so a
    whole transition pack reads as one consistent hand-drawn boundary
    style rather than a different random wobble per tile."""
    rng = np.random.default_rng(seed)
    # Low-res random field, upscaled + blurred = cheap organic noise
    # without a third-party Perlin dependency (stdlib/Pillow/numpy only).
    small = rng.random((size // 16, size // 16)).astype(np.float32)
    img = Image.fromarray((small * 255).astype(np.uint8)).resize(
        (size, size), Image.BICUBIC)
    img = img.filter(ImageFilter.GaussianBlur(radius=size * 0.02))
    arr = np.asarray(img, dtype=np.float32) / 255.0
    return (arr - arr.mean())  # centred, so it can push a boundary either way


def _corner_gradient(size: int, config: int) -> np.ndarray:
    vals = {c: (1.0 if config & BITS[c] else 0.0) for c in CORNERS}
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / (size - 1)
    top = vals["TL"] * (1 - xx) + vals["TR"] * xx
    bot = vals["BL"] * (1 - xx) + vals["BR"] * xx
    return top * (1 - yy) + bot * yy


# Edge bit order N,E,S,W matches FarmRenderer.NEIGHBOR_OFFSETS /
# transition_lookup()'s mask string exactly - char 0 = N (0,-1) up, char 1 =
# E (1,0) right, char 2 = S (0,1) down, char 3 = W (-1,0) left.
EDGE_BITS = {"N": 8, "E": 4, "S": 2, "W": 1}


def _edge_gradient(size: int, config: int) -> np.ndarray:
    """Material B intrudes from every SET edge, fading toward the center.
    nx/ny in [0,1]: (0,0) is the top-left pixel."""
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / (size - 1)
    influences = []
    if config & EDGE_BITS["N"]:
        influences.append(1.0 - yy)
    if config & EDGE_BITS["S"]:
        influences.append(yy)
    if config & EDGE_BITS["W"]:
        influences.append(1.0 - xx)
    if config & EDGE_BITS["E"]:
        influences.append(xx)
    if not influences:
        return np.zeros((size, size), dtype=np.float32)
    return np.maximum.reduce(influences)


def build_mask(size: int, config: int, noise: np.ndarray, softness: float = 0.10,
               mode: str = "edge") -> np.ndarray:
    grad = _edge_gradient(size, config) if mode == "edge" else _corner_gradient(size, config)
    perturbed = np.clip(grad + noise * 0.35, 0.0, 1.0)
    # Soft threshold around 0.5 for a blended (not hard-edged) boundary.
    mask = np.clip((perturbed - (0.5 - softness)) / (2 * softness), 0.0, 1.0)
    return mask


def load_tileable(path: str, size: int) -> np.ndarray:
    img = Image.open(path).convert("RGB").resize((size, size), Image.LANCZOS)
    return np.asarray(img, dtype=np.float32)


def main(argv) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--a", required=True, help="material A seamless tile (e.g. grass)")
    ap.add_argument("--b", required=True, help="material B seamless tile (e.g. dirt)")
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--size", type=int, default=256)
    ap.add_argument("--noise-seed", type=int, default=1337,
                     help="keep the SAME seed across every material pair in one project "
                          "so all transition packs share one boundary style")
    ap.add_argument("--mode", choices=["edge", "corner"], default="edge",
                     help="edge = matches this project's FarmRenderer (same-grid N/E/S/W "
                          "neighbor bitmask); corner = true half-cell dual-grid (TL/TR/BR/BL)")
    args = ap.parse_args(argv)

    os.makedirs(args.out_dir, exist_ok=True)
    a = load_tileable(args.a, args.size)
    b = load_tileable(args.b, args.size)
    noise = _shared_noise(args.size, args.noise_seed)

    written = []
    for config in range(16):
        mask = build_mask(args.size, config, noise, mode=args.mode)[..., None]
        blended = a * (1 - mask) + b * mask
        out = Image.fromarray(np.clip(blended, 0, 255).astype(np.uint8))
        name = f"{config:04b}.png"
        path = os.path.join(args.out_dir, name)
        out.save(path)
        written.append(name)

    print(f"wrote {len(written)} transition tiles to {args.out_dir}")
    print("corner bit order: TL=8 TR=4 BR=2 BL=1 (filename is the 4-bit binary config)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
