"""Offline: normalize generated PNGs (trim/scale/anchor) and pack them into
filter-grouped atlases, emitting SpriteManifest-compatible manifest entries.

Implements design/sprints/sprint16_art_architecture.md section 4/5 (the
DeepSeek-designed atlas/normalization plan).

Per-source algorithm:
1. Key the background if the source has no alpha (all current generated
   batches are flat RGB) via strip_background's corner-sample flood fill.
   Refuses non-uniform-corner sources rather than inventing alpha.
2. Crop to the opaque bounding box - the male1_walk lesson: the SUBJECT
   defines the frame, not the generator's square canvas.
3. Uniformly scale to --height (LANCZOS for linear, NEAREST for nearest -
   this pipeline's assets are all painted/cel-shaded, so linear is the
   default; nearest exists for a future genuinely pixel-art pass).
4. Anchor bottom-center by default (anchor_x = frame_w/2, anchor_y = frame_h).

Packing: shelf-pack into --atlas-size canvases, grouped by filter so no
atlas mixes sampling styles, with a 2px edge-extended bleed border so
Linear filtering at region edges doesn't sample a neighboring asset.

Usage:
    python normalize_and_pack.py --input vertical_slice_test --category world_dressing \
        --height 128 --height-tiles 0.5 --write-data
    (dry-run without --write-data: entries + atlases go to asset_studio/out/)
"""

import argparse
import io
import json
import os
import sys
import tempfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from strip_background import strip_background  # noqa: E402

BLEED = 2


def normalize_one(path: str, target_h: int, filt: str, alpha_threshold: int,
                   anchor_mode: str, corner_tol: int):
    img = Image.open(path)
    needs_keying = img.mode != "RGBA" or img.getextrema()[3][0] == 255
    if needs_keying:
        with tempfile.TemporaryDirectory() as tmp:
            keyed_path = os.path.join(tmp, "keyed.png")
            result = strip_background(path, out=keyed_path, tolerance=corner_tol)
            if result is None:
                print(f"  SKIP {path}: corners not uniform enough to key")
                return None
            img = Image.open(keyed_path)
            img.load()
    bbox = img.getchannel("A").point(lambda a: 255 if a > alpha_threshold else 0).getbbox()
    if bbox is None:
        print(f"  SKIP {path}: fully transparent after keying")
        return None
    cropped = img.crop(bbox)
    w, h = cropped.size
    scale = target_h / h
    new_w = max(1, round(w * scale))
    resample = Image.LANCZOS if filt == "linear" else Image.NEAREST
    resized = cropped.resize((new_w, target_h), resample)

    if anchor_mode == "bottom_center":
        anchor = (new_w // 2, target_h)
    elif anchor_mode == "center":
        anchor = (new_w // 2, target_h // 2)
    else:
        anchor = (0, 0)
    return resized, anchor


class Shelf:
    def __init__(self, size: int):
        self.size = size
        self.canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        self.x = 0
        self.y = 0
        self.shelf_h = 0
        self.placements = []  # (content_rect, anchor, src_name)

    def place(self, img: Image.Image, anchor, name: str):
        w, h = img.size
        bw, bh = w + BLEED * 2, h + BLEED * 2
        if self.x + bw > self.size:
            self.x = 0
            self.y += self.shelf_h
            self.shelf_h = 0
        if self.y + bh > self.size:
            return False
        # Edge-extend bleed: paste content, then stamp 1px edge strips outward.
        px = self.x + BLEED
        py = self.y + BLEED
        self.canvas.paste(img, (px, py))
        left = img.crop((0, 0, 1, h)).resize((BLEED, h))
        right = img.crop((w - 1, 0, w, h)).resize((BLEED, h))
        self.canvas.paste(left, (px - BLEED, py))
        self.canvas.paste(right, (px + w, py))
        top = self.canvas.crop((px - BLEED, py, px + w + BLEED, py + 1)).resize((w + BLEED * 2, BLEED))
        bot = self.canvas.crop((px - BLEED, py + h - 1, px + w + BLEED, py + h)).resize((w + BLEED * 2, BLEED))
        self.canvas.paste(top, (px - BLEED, py - BLEED))
        self.canvas.paste(bot, (px - BLEED, py + h))

        self.placements.append({
            "name": name, "rect": (px, py, w, h), "anchor": anchor,
        })
        self.x += bw
        self.shelf_h = max(self.shelf_h, bh)
        return True


def pack(items, atlas_size: int, out_prefix: str):
    """items: list of (name, PIL.Image, anchor). Returns (atlas_paths, entries)."""
    items = sorted(items, key=lambda it: -it[1].size[1])
    shelves = [Shelf(atlas_size)]
    for name, img, anchor in items:
        if not shelves[-1].place(img, anchor, name):
            shelves.append(Shelf(atlas_size))
            if not shelves[-1].place(img, anchor, name):
                raise ValueError(f"{name}: single image larger than atlas_size {atlas_size}")

    atlas_paths = []
    entries = {}
    for i, shelf in enumerate(shelves):
        path = f"{out_prefix}_{i}.png"
        shelf.canvas.save(path)
        atlas_paths.append(path)
        for p in shelf.placements:
            x, y, w, h = p["rect"]
            entries[p["name"]] = {
                "atlas": path, "frame": {"x": x, "y": y, "w": w, "h": h},
                "anchor": p["anchor"],
            }
    return atlas_paths, entries


def main(argv) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, help="directory of source PNGs")
    ap.add_argument("--category", required=True, help="routes to data/sprites_<category>.json")
    ap.add_argument("--filter", choices=["nearest", "linear"], default="linear")
    ap.add_argument("--height", type=int, default=128)
    ap.add_argument("--height-tiles", type=float, default=0.5)
    ap.add_argument("--atlas-size", type=int, default=2048)
    ap.add_argument("--anchor-mode", choices=["bottom_center", "center", "top_left"],
                     default="bottom_center")
    ap.add_argument("--alpha-threshold", type=int, default=8)
    ap.add_argument("--corner-tolerance", type=int, default=24)
    ap.add_argument("--write-data", action="store_true")
    args = ap.parse_args(argv)

    out_dir = os.path.join(REPO, "assets", "sprites", args.category) if args.write_data \
        else os.path.join(HERE, "out", args.category)
    os.makedirs(out_dir, exist_ok=True)

    items = []
    for fname in sorted(os.listdir(args.input)):
        if not fname.lower().endswith(".png") or fname.startswith("_"):
            continue
        result = normalize_one(os.path.join(args.input, fname), args.height, args.filter,
                                args.alpha_threshold, args.anchor_mode, args.corner_tolerance)
        if result is None:
            continue
        img, anchor = result
        name = os.path.splitext(fname)[0]
        items.append((name, img, anchor))
        print(f"  {name}: {img.size[0]}x{img.size[1]} anchor={anchor}")

    if not items:
        print("no images normalized; nothing to pack")
        return 1

    atlas_prefix = os.path.join(out_dir, f"generated_atlas_{args.filter}")
    atlas_paths, pack_entries = pack(items, args.atlas_size, atlas_prefix)
    print(f"packed {len(items)} images into {len(atlas_paths)} atlas(es)")

    sprites = []
    for name, info in pack_entries.items():
        rel = os.path.relpath(info["atlas"], REPO).replace("\\", "/")
        fr = info["frame"]
        sprites.append({
            "id": name,
            "kind": "static",
            "texture": f"res://{rel}",
            "frames": [{"x": fr["x"], "y": fr["y"], "w": fr["w"], "h": fr["h"]}],
            "frame_w": fr["w"], "frame_h": fr["h"],
            "anchor_x": info["anchor"][0], "anchor_y": info["anchor"][1],
            "height_tiles": args.height_tiles,
            "filter": args.filter,
        })

    manifest_path = os.path.join(REPO, "data", f"sprites_{args.category}.json") if args.write_data \
        else os.path.join(HERE, "out", f"sprites_{args.category}.json")
    doc = {"version": 1, "sprites": []}
    if os.path.isfile(manifest_path):
        doc = json.load(io.open(manifest_path, encoding="utf-8"))
    by_id = {s["id"]: s for s in doc.get("sprites", [])}
    for s in sprites:
        by_id[s["id"]] = s
    doc["sprites"] = [by_id[k] for k in sorted(by_id)]
    doc["version"] = max(int(doc.get("version", 1)), 2)
    json.dump(doc, io.open(manifest_path, "w", encoding="utf-8"), indent=2)
    print(f"{'wrote' if args.write_data else 'dry-run wrote'} "
          f"{len(sprites)} entries -> {manifest_path} ({len(doc['sprites'])} total)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
