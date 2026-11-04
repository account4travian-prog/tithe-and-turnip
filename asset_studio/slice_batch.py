"""Vertical-slice asset batch runner (local SDXL lane) + free deterministic QA.

Usage:
    python slice_batch.py [--only ID[,ID...]] [--dry-run]

Generates the vertical-slice asset list through generate.py's templated
`--category`/`--subject` path, then runs the free deterministic checks on
each result BEFORE any paid/slow QA lane sees it. Writes
`vertical_slice_test/batch_report.json` so the QA lanes (Ollama coarse,
Terra art-direction) can start from "here is what already failed
mechanically" instead of re-deriving it.

Why gate deterministically first: the two failure modes we actually hit
(tiling into a repeating pattern; drifting photoreal) are partly
detectable for free. Tiling in particular puts subject matter in the
corners, which shows up as high corner-spread - the same measure
strip_background.py uses to decide if an image is keyable at all. An
asset that can't be keyed can't ship, so that check is a hard gate, not
an opinion.
"""

import argparse
import json
import os
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "vertical_slice_test")
REPORT = os.path.join(OUT_DIR, "batch_report.json")

# (asset_id, category, subject) - subjects phrased per style_bible.md's
# Round 2 findings; row-crops carry explicit anti-tile wording because
# that failure mode is subject-driven, not prompt-driven.
ASSETS = [
    # --- Spring crops still missing (cabbage is summer-only, skipped) ---
    ("onion", "item", "yellow onion bulb with dry papery skin and green shoots, one single bulb"),
    ("leek", "item", "one single harvested leek vegetable, thick white cylindrical stalk at the bottom, broad dark green flat leaves fanning from the top, root hairs visible"),
    ("oat", "item", "bundle of golden oat grain stalks tied with twine, one single bundle"),
    ("flax", "item", "one single tied bundle of harvested flax stalks lying alone, a few small blue flowers, single object only"),
    ("barley", "item", "sheaf of golden barley grain tied with twine, one single sheaf"),
    # --- Tools / weapons ---
    ("spade", "item", "digging spade with a pointed iron blade and wooden handle"),
    ("spear", "item", "exactly one single medieval spear, one wooden shaft with one iron spearhead, only one weapon in frame"),
    ("pitchfork", "item", "wooden pitchfork with three iron tines"),
    ("knife", "item", "small medieval utility knife with a wooden handle"),
    # --- Forage / materials ---
    ("flint", "item", "chunk of grey flint stone"),
    ("wood", "item", "one small neat stack of about five chopped firewood logs, single pile, isolated object"),
    ("wild_berry", "item", "cluster of red wild berries on a small leafy sprig"),
    ("morel", "item", "morel mushroom with a honeycomb-textured cap"),
    # --- Structures ---
    ("storage_chest", "structure", "a simple wooden storage chest with iron banding, closed lid"),
    ("hearth", "item", "a small stone cooking hearth with a metal cooking pot over a fire, single object, no landscape, no grass, no trees"),
    ("coop", "item", "a small wooden chicken coop hutch with a sloped roof and a little door, single object, no landscape, no grass, no trees, no fence"),
    ("fence", "item", "one short straight section of split-rail wooden fence with two posts and three rails, single object, no landscape, no grass, no field"),
]


def deterministic_checks(path: str) -> dict:
    """Free, instant gates. Anything failing `keyable` cannot ship as an
    asset regardless of how good it looks, so it is reported as a hard
    fail rather than a note."""
    img = Image.open(path).convert("RGB")
    w, h = img.size
    px = img.load()
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    spread = max(max(abs(c[i] - corners[0][i]) for i in range(3)) for c in corners)
    # Edge-band sampling: a tiled/pattern image tends to carry subject
    # matter right up to the border, so a busy border is a tiling smell
    # even when the four exact corners happen to agree.
    band = []
    step = max(1, w // 64)
    for x in range(0, w, step):
        band.append(px[x, 2])
        band.append(px[x, h - 3])
    base = corners[0]
    off = sum(1 for c in band if max(abs(c[i] - base[i]) for i in range(3)) > 40)
    border_busy_pct = round(100.0 * off / max(1, len(band)), 1)
    return {
        "size": [w, h],
        "corner_spread": spread,
        "keyable": spread <= 24,
        "border_busy_pct": border_busy_pct,
        "tiling_suspect": border_busy_pct > 25.0,
        "unique_colors": len(img.getcolors(maxcolors=1 << 24) or []),
    }


def main(argv) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--seed", type=int, default=7)
    args = ap.parse_args(argv)

    wanted = {s.strip() for s in args.only.split(",") if s.strip()}
    todo = [a for a in ASSETS if not wanted or a[0] in wanted]
    os.makedirs(OUT_DIR, exist_ok=True)

    report = {}
    if os.path.isfile(REPORT):
        with open(REPORT, encoding="utf-8") as f:
            report = json.load(f)

    for i, (aid, cat, subject) in enumerate(todo, 1):
        dest = os.path.join(OUT_DIR, f"{aid}.png")
        print(f"[{i}/{len(todo)}] {aid} ({cat})", flush=True)
        if args.dry_run:
            print(f"    would generate: {subject}")
            continue
        cmd = [
            sys.executable, os.path.join(HERE, "generate.py"),
            "--category", cat, "--subject", subject, "--seed", str(args.seed),
        ]
        proc = subprocess.run(cmd, capture_output=True, text=True)
        saved = None
        for line in proc.stdout.splitlines():
            if line.startswith("saved:"):
                saved = line.split("saved:", 1)[1].strip()
        if not saved or not os.path.isfile(saved):
            print(f"    FAILED: {proc.stdout.strip()[-300:]} {proc.stderr.strip()[-300:]}")
            report[aid] = {"status": "generation_failed"}
            continue
        # Never clobber an asset that already passed: a retry can come back
        # worse (seed 88 destroyed a passing leek on 2026-08-08). Write the
        # candidate aside and only promote it if it actually beats what's
        # there on the hard gate.
        prev_ok = report.get(aid, {}).get("keyable") is True and os.path.isfile(dest)
        target = os.path.join(OUT_DIR, f"{aid}_candidate.png") if prev_ok else dest
        Image.open(saved).save(target)
        checks = deterministic_checks(target)
        if prev_ok:
            if checks["keyable"] and not checks["tiling_suspect"]:
                Image.open(target).save(dest)
                os.remove(target)
                print("    (retry promoted over previous pass)")
            else:
                print(f"    (retry REJECTED, kept previous pass; candidate left at {os.path.basename(target)})")
                continue
        checks["status"] = "generated"
        checks["source"] = os.path.basename(saved)
        checks["category"] = cat
        checks["subject"] = subject
        report[aid] = checks
        flags = []
        if not checks["keyable"]:
            flags.append("NOT-KEYABLE")
        if checks["tiling_suspect"]:
            flags.append("TILING?")
        print(f"    {checks['size'][0]}x{checks['size'][1]} spread={checks['corner_spread']} "
              f"border={checks['border_busy_pct']}% {' '.join(flags) or 'ok'}")
        with open(REPORT, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=2)

    if not args.dry_run:
        with open(REPORT, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=2)
        hard = [k for k, v in report.items() if v.get("status") == "generated" and not v.get("keyable", True)]
        tile = [k for k, v in report.items() if v.get("tiling_suspect")]
        print(f"\nwrote {REPORT}")
        print(f"not keyable (hard fail): {hard or 'none'}")
        print(f"tiling suspects: {tile or 'none'}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
