"""Offline: turn a purchased 4-direction animation sheet into a sprite-manifest entry.

Usage:
    python make_actor_manifest.py --preview male1
    python make_actor_manifest.py --write male1

Why this exists
---------------
The purchased actor packs (Male1, Female1, Bandits1, NPC1) already ship
complete animation sets - Idle/Walk/Run/Hurt/Death, and Attack for the
armed variants - as uniform 64px grids, 4 rows = 4 directions. Diffusion
generation cannot produce frame-to-frame-consistent animation, so these
packs are the right source for ANIMATED ACTORS; generated art is for
STATIC subjects (crops, tools, items, structures, icons).

The one hard part is the crop. Each 64x64 cell is mostly transparent
padding - the drawn character occupies roughly 15x25 px. Naively pointing
the manifest at the full cell makes the character render tiny (this
actually happened: see data/sprites_actors.json's male1_walk history).
So we measure the UNION opaque bounding box across every frame of the
sheet and crop to that.

Union, not per-frame: a per-frame bbox would shrink-wrap each frame
individually and make the character jitter and change size during
playback. One union box for the whole sheet keeps scale and footing
stable across the cycle.

The anchor is bottom-centre of that union box - the character's feet -
which is the point SpriteManifest places on the proxy's origin and which
WorldVisuals y-sorts against.
"""

import argparse
import io
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
ASSETS = os.path.join(REPO, "assets", "sprites", "actors")
MANIFEST = os.path.join(REPO, "data", "sprites_actors.json")

CELL = 64
# Row index -> the grid-space facings that row serves. Row order is the
# pack's own convention (row 0 front/south, 1 left/west, 2 right/east,
# 3 back/north) - VERIFY VISUALLY before trusting; it is data, not code.
ROW_FACINGS = {
    0: ["0,1", "1,1"],
    1: ["-1,0", "-1,1"],
    2: ["1,0", "1,-1"],
    3: ["0,-1", "-1,-1"],
}

# Sheets to ingest per actor: (state_name, relative path, fps).
# fps values follow the pack's own Tiled timing where known (walk was
# 150ms/frame => ~6.67fps); idle is deliberately slower.
ACTORS = {
    "male1": {
        "dir": "male1/Unarmed/Without_shadow",
        "prefix": "Unarmed_",
        "states": [
            ("idle", "Unarmed_Idle_without_shadow.png", 5.0),
            ("walk", "Unarmed_Walk_without_shadow.png", 6.67),
            ("run", "Unarmed_Run_without_shadow.png", 10.0),
            ("hurt", "Unarmed_Hurt_without_shadow.png", 8.0),
            ("death", "Unarmed_Death_without_shadow.png", 8.0),
        ],
    },
    "male1_sword": {
        "dir": "male1/Sword/Without_shadow",
        "prefix": "Sword_",
        "states": [
            ("attack", "Sword_attack_without_shadow.png", 12.0),
        ],
    },
    "female1": {
        "dir": "female1/Unarmed/Without_shadow",
        "prefix": "Unarmed_",
        "states": [
            ("idle", "Unarmed_Idle_without_shadow.png", 5.0),
            ("walk", "Unarmed_Walk_without_shadow.png", 6.67),
            ("run", "Unarmed_Run_without_shadow.png", 10.0),
        ],
    },
}


def union_opaque_box(img: Image.Image, cols: int, rows: int) -> tuple:
    """Union of every frame's opaque bbox, expressed INSIDE one cell."""
    minx, miny, maxx, maxy = CELL, CELL, -1, -1
    for r in range(rows):
        for c in range(cols):
            cell = img.crop((c * CELL, r * CELL, c * CELL + CELL, r * CELL + CELL))
            bb = cell.getbbox()  # alpha-aware on RGBA
            if bb is None:
                continue
            minx = min(minx, bb[0]); miny = min(miny, bb[1])
            maxx = max(maxx, bb[2]); maxy = max(maxy, bb[3])
    if maxx < 0:
        raise ValueError("sheet is fully transparent")
    return minx, miny, maxx, maxy


def build_entry(actor: str, state: str, path: str, fps: float, height_tiles: float) -> dict:
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    if w % CELL or h % CELL:
        raise ValueError(f"{path}: {w}x{h} is not a whole multiple of {CELL}")
    cols, rows = w // CELL, h // CELL
    if rows != 4:
        raise ValueError(f"{path}: expected 4 direction rows, got {rows}")
    minx, miny, maxx, maxy = union_opaque_box(img, cols, rows)
    fw, fh = maxx - minx, maxy - miny

    frames = []
    for r in range(rows):
        for c in range(cols):
            frames.append({
                "x": c * CELL + minx,
                "y": r * CELL + miny,
                "w": fw,
                "h": fh,
            })
    directions = {}
    for r in range(rows):
        for facing in ROW_FACINGS[r]:
            directions[facing] = {"start": r * cols, "count": cols, "flip_h": False}

    rel = os.path.relpath(path, REPO).replace("\\", "/")
    return {
        "id": f"{actor}_{state}",
        "kind": "animated",
        "texture": f"res://{rel}",
        "sheet_w": w,
        "sheet_h": h,
        "frame_w": fw,
        "frame_h": fh,
        "anchor_x": fw // 2,
        "anchor_y": fh,
        "height_tiles": height_tiles,
        "fps": fps,
        "filter": "linear",
        "frames": frames,
        "directions": directions,
    }


def main(argv) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("actors", nargs="*", default=[], help="actor keys; default all")
    ap.add_argument("--write", action="store_true", help="merge into data/sprites_actors.json")
    ap.add_argument("--height-tiles", type=float, default=1.2)
    args = ap.parse_args(argv)

    keys = args.actors or list(ACTORS)
    entries = []
    # One scale per actor family, not per state. SpriteManifest computes
    # scale as height_tiles * TILE_H / frame_h, i.e. height_tiles is a
    # TARGET height - so giving every state the same height_tiles would
    # force a 22px idle crop and a 43px sword-raise crop to render at the
    # SAME on-screen height. The character would visibly shrink/grow when
    # switching state and the sword-raise would be flattened away.
    # Instead: pick a reference state (walk), and scale every other state
    # proportionally to its own crop height, so one constant px-per-source-
    # pixel scale applies across the whole actor.
    ref_h = {}
    for key in keys:
        spec = ACTORS.get(key)
        if spec is None:
            print(f"unknown actor '{key}'; known: {', '.join(ACTORS)}", file=sys.stderr)
            return 2
        family = key.split("_")[0]
        for state, fname, fps in spec["states"]:
            path = os.path.join(ASSETS, spec["dir"].replace("/", os.sep), fname)
            if not os.path.isfile(path):
                print(f"  SKIP {key}_{state}: missing {os.path.relpath(path, REPO)}")
                continue
            try:
                e = build_entry(key, state, path, fps, args.height_tiles)
            except ValueError as exc:
                print(f"  SKIP {key}_{state}: {exc}")
                continue
            if state == "walk":
                ref_h[family] = e["frame_h"]
            entries.append((family, e))

    # Second pass: rescale against each family's reference walk height.
    out = []
    for family, e in entries:
        ref = ref_h.get(family)
        if ref:
            e["height_tiles"] = round(args.height_tiles * e["frame_h"] / ref, 4)
        else:
            print(f"  NOTE {e['id']}: no walk reference for '{family}', "
                  f"height_tiles left at {e['height_tiles']} - verify in-game")
        px = round(e["height_tiles"] * 48.0, 1)
        out.append(e)
        print(f"  {e['id']}: crop {e['frame_w']}x{e['frame_h']} "
              f"anchor=({e['anchor_x']},{e['anchor_y']}) "
              f"h_tiles={e['height_tiles']} (~{px}px) "
              f"{len(e['frames'])} frames, {len(e['directions'])} facings")
    entries = out

    if not args.write:
        print("\n(preview only - pass --write to merge into data/sprites_actors.json)")
        return 0

    doc = {"version": 1, "sprites": []}
    if os.path.isfile(MANIFEST):
        doc = json.load(io.open(MANIFEST, encoding="utf-8"))
    by_id = {s["id"]: s for s in doc.get("sprites", [])}
    for e in entries:
        by_id[e["id"]] = e
    doc["sprites"] = [by_id[k] for k in sorted(by_id)]
    json.dump(doc, io.open(MANIFEST, "w", encoding="utf-8"), indent=2)
    print(f"\nwrote {len(entries)} entries into {os.path.relpath(MANIFEST, REPO)} "
          f"({len(doc['sprites'])} total)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
