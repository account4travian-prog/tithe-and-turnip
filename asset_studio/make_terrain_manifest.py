"""Write the ADR-042 season-aware terrain manifest from generated tile paths."""

import argparse
import json
from pathlib import Path


SOILS = ("loamy", "sandy", "rocky")
SURFACES = ("grass", "tilled", "tilled_wet")
SEASONS = ("spring", "summer", "autumn", "winter")
VARIANT_COUNTS = {"grass": 4, "tilled": 3, "tilled_wet": 3}


def _texture_path(season: str, relative: str) -> str:
    prefix = "" if season == "spring" else f"{season}/"
    return f"res://assets/sprites/terrain/{prefix}{relative}"


def _entry(season: str, relative: str) -> dict:
    return {"texture": _texture_path(season, relative), "frame_w": 128, "frame_h": 96}


def _season_entry(season: str) -> dict:
    materials = {}
    transitions = {}
    for soil in SOILS:
        for surface in SURFACES:
            material_id = f"{soil}_{surface}"
            materials[material_id] = {
                "variants": [
                    _entry(season, f"{material_id}_{index}.png")
                    for index in range(VARIANT_COUNTS[surface])
                ]
            }
        for center, other in (("grass", "tilled"), ("tilled", "grass")):
            pair = f"{soil}_{center}|{soil}_{other}"
            directory = f"{soil}_{center}__{soil}_{other}"
            transitions[pair] = {
                "entries": {
                    f"{index:04b}": _entry(season, f"{directory}/{index:04b}.png")
                    for index in range(16)
                }
            }
    return {"materials": materials, "transitions": transitions, "scatter": {}}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    manifest = {
        "version": 2,
        "default_season": "spring",
        "seasons": {season: _season_entry(season) for season in SEASONS},
    }
    args.out.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
