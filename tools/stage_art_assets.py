#!/usr/bin/env python3
"""Sprint 16 Phase 0.5 (ADR-041): stage purchased/found art packs from
SourceArtAssets/ (outside the repo) into res://assets/sprites/<category>/<pack>/.

Run once from the repo root:
    python tools/stage_art_assets.py [--source PATH] [--dest PATH] [--dry-run]

What it does, per design/sprints/sprint_16_art_integration.md section 4:
  1. Skips reference-only material that ships alongside the PNGs: .import
     sidecars, AI/EPS vector masters, Tiled *.tmx exports (and their PNG
     copies - Tiled_files/ duplicates PNG/ file-for-file in every pack that
     has both), .scml Spriter projects, license/readme .txt, OS junk.
  2. Picks exactly one shadow/background variant per logical asset - prefers
     a "without_shadow" file/folder over a same-named "with_shadow"/"_shadow"
     one; a bare "PNG Sequences" folder is skipped only when a sibling
     "Spritesheets" folder covers the same content (Bandits1), never when it
     is the only source of frames (NPC1 has no Spritesheets alternative).
  3. Routes each surviving file to a destination category directory. Most
     packs are 1:1; Building1 and Workshop1 are genuinely mixed (building
     exteriors AND named-citizen/customer/master characters in the same
     PNG/ folder) and are split by a filename keyword check.
  4. Never overwrites a hand-curated file on a second run - safe to re-run
     after SourceArtAssets gains new packs.

This is a one-time staging tool, not gameplay code - no CLAUDE.md typed-
GDScript rules apply to it. It never touches data/sprites_*.json; picking
which staged file backs which sprite id is each workstream's own job.
"""

import argparse
import os
import shutil
import sys

# (source subpath under SOURCE_ROOT, destination "<category>/<pack>" dir)
PACKS = [
    ("Male1/PNG", "actors/male1"),
    ("Female1/PNG", "actors/female1"),
    ("Animals1/PNG", "actors/animals1"),
    ("FarmAnimalsOption1/PNG", "actors/farm_animals1"),
    ("Bandits1/Assassin/PNG", "actors/bandits1/assassin"),
    ("Bandits1/Robber/PNG", "actors/bandits1/robber"),
    ("Bandits1/Thug/PNG", "actors/bandits1/thug"),
    ("NPC1/Artist/PNG", "actors/npc1/artist"),
    ("NPC1/Astrologer/PNG", "actors/npc1/astrologer"),
    ("NPC1/Citizen/PNG", "actors/npc1/citizen"),
    ("NPC1/Artist/popup/PNG", "ui/npc1_popup/artist"),
    ("NPC1/Astrologer/popup/PNG", "ui/npc1_popup/astrologer"),
    ("NPC1/Citizen/popup/PNG", "ui/npc1_popup/citizen"),
    ("TreesOption1/Assets_separately", "world_dressing/trees1"),
    ("BushesOption1", "world_dressing/bushes1"),
    ("RocksAndStones/Objects_separately", "world_dressing/rocks1"),
    ("FarmPlantsPixelStyle", "world_dressing/farm_plants"),
    ("Home1PixelStyle", "structures/home1pixelstyle"),
    ("Building1/PNG", "MIXED_building1"),  # split by keyword, see route_mixed()
    ("Workshop1/PNG", "MIXED_workshop1"),
    ("UI2", "ui/ui2"),
    ("AdventureUI/Vector", "ui/adventure_ui/vector"),
    ("AdventureUI/Spritesheet", "ui/adventure_ui/spritesheet"),
]

# Filename keywords (case-insensitive substring) that route a Building1/
# Workshop1 file to actors/<pack> instead of structures/<pack>.
ACTOR_KEYWORDS = [
    "citizen", "fighter", "mage", "reader", "talking", "guildmaster",
    "manequin", "customer", "seller", "master",
]

# Longest suffix first: TreesOption1/BushesOption1 name their shadow
# variants as a suffix on a shared base ("Trees" / "Trees_shadow" /
# "Trees_texture_shadow" / "Trees_texture_shadow_dark") rather than as a
# separate With_shadow/Without_shadow sibling pair - skip a suffixed
# variant whenever its unsuffixed base exists as a literal sibling.
SHADOW_SUFFIXES = ("_texture_shadow_dark", "_texture_shadow", "_with_shadow", "_shadow")
SKIP_DIR_NAMES = {"ai", "eps", "tiled_files", "tiled", "__pycache__", ".git"}
SKIP_EXTS = {".import", ".ai", ".eps", ".scml", ".tmx", ".txt", ".autosave"}
KEEP_EXTS = {".png", ".svg", ".xml"}  # .xml: AdventureUI's atlas coordinate index


def should_skip_dir(dirname: str, dirpath: str) -> bool:
    lower = dirname.lower()
    if lower in SKIP_DIR_NAMES or lower.startswith("."):
        return True
    if lower == "with_shadow":
        # Only skip if a without_shadow sibling exists to take its place.
        parent = os.path.dirname(dirpath)
        siblings = {d.lower() for d in os.listdir(parent) if os.path.isdir(os.path.join(parent, d))}
        return "without_shadow" in siblings
    if lower == "png sequences":
        # Bandits1: redundant with a sibling Spritesheets folder. NPC1 has
        # no such sibling, so its PNG Sequences folders are kept.
        parent = os.path.dirname(dirpath)
        siblings = {d.lower() for d in os.listdir(parent) if os.path.isdir(os.path.join(parent, d))}
        return "spritesheets" in siblings
    if lower == "double":
        return True  # AdventureUI's 2x spritesheet - Default variant is enough
    parent = os.path.dirname(dirpath)
    siblings = {d.lower() for d in os.listdir(parent) if os.path.isdir(os.path.join(parent, d))}
    for suffix in SHADOW_SUFFIXES:
        if lower.endswith(suffix) and lower[: -len(suffix)] in siblings:
            return True  # an unsuffixed plain sibling covers this content already
    return False


def should_skip_file(filename: str, dirpath: str) -> bool:
    stem, ext = os.path.splitext(filename)
    ext = ext.lower()
    if filename.lower() in {".ds_store", "thumbs.db"}:
        return True
    if ext in SKIP_EXTS or ext not in KEEP_EXTS:
        return True
    lower = stem.lower()
    if lower.endswith("_with_shadow"):
        base = filename[: -len("_with_shadow.png")]
        if os.path.exists(os.path.join(dirpath, base + "_without_shadow" + ext)):
            return True  # redundant - the without_shadow twin is kept instead
    elif lower.endswith("_shadow") and not lower.endswith("_without_shadow"):
        base = filename[: -len("_shadow.png")]
        if os.path.exists(os.path.join(dirpath, base + ext)) or os.path.exists(
            os.path.join(dirpath, base + "_without_shadow" + ext)
        ):
            return True  # a plain/without_shadow twin exists - this is a shadow-only layer
    return False


def route_mixed(filename: str, pack_label: str) -> str:
    lower = filename.lower()
    category = "actors" if any(k in lower for k in ACTOR_KEYWORDS) else "structures"
    pack = pack_label.replace("MIXED_", "")
    return f"{category}/{pack}"


def stage_pack(source_root: str, dest_root: str, rel_src: str, dest_label: str, dry_run: bool) -> tuple:
    src_dir = os.path.join(source_root, rel_src.replace("/", os.sep))
    if not os.path.isdir(src_dir):
        print(f"  MISSING source dir, skipping: {src_dir}")
        return (0, 0)
    copied = 0
    skipped = 0
    for dirpath, dirnames, filenames in os.walk(src_dir):
        dirnames[:] = [d for d in dirnames if not should_skip_dir(d, os.path.join(dirpath, d))]
        for filename in filenames:
            if should_skip_file(filename, dirpath):
                skipped += 1
                continue
            rel_from_pack = os.path.relpath(os.path.join(dirpath, filename), src_dir)
            label = route_mixed(filename, dest_label) if dest_label.startswith("MIXED_") else dest_label
            dest_path = os.path.join(dest_root, label.replace("/", os.sep), rel_from_pack)
            if os.path.exists(dest_path):
                copied += 1  # already staged from a prior run - counted, not re-copied
                continue
            if not dry_run:
                os.makedirs(os.path.dirname(dest_path), exist_ok=True)
                shutil.copy2(os.path.join(dirpath, filename), dest_path)
            copied += 1
    return (copied, skipped)


def main(argv) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default=r"%USERPROFILE%\Documents\SourceArtAssets")
    parser.add_argument("--dest", default=os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "sprites"))
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)

    print(f"Source: {args.source}")
    print(f"Dest:   {args.dest}")
    print(f"Dry run: {args.dry_run}\n")

    total_copied = 0
    total_skipped = 0
    for rel_src, dest_label in PACKS:
        copied, skipped = stage_pack(args.source, args.dest, rel_src, dest_label, args.dry_run)
        total_copied += copied
        total_skipped += skipped
        print(f"{rel_src:45s} -> {dest_label:30s} kept {copied:5d}  skipped {skipped:5d}")

    print(f"\nTotal kept: {total_copied}  Total skipped: {total_skipped}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
