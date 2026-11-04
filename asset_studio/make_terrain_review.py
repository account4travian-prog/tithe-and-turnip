"""Create a small human-review contact sheet for the seasonal terrain set."""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw


SOILS = ("loamy", "sandy", "rocky")
SURFACES = ("grass", "tilled", "tilled_wet")
SEASONS = ("spring", "summer", "autumn", "winter")
TILE_W = 128
TILE_H = 96
PAD = 12
LABEL_H = 24
BACKGROUND = "#253039"


def _tile_path(root: Path, season: str, soil: str, surface: str) -> Path:
    prefix = Path() if season == "spring" else Path(season)
    return root / prefix / f"{soil}_{surface}_0.png"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    columns = len(SOILS) * len(SURFACES)
    width = PAD + columns * (TILE_W + PAD)
    height = PAD + len(SEASONS) * (LABEL_H + TILE_H + PAD)
    sheet = Image.new("RGBA", (width, height), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    for row, season in enumerate(SEASONS):
        y = PAD + row * (LABEL_H + TILE_H + PAD)
        draw.text((PAD, y), season.upper(), fill="#f1ead9")
        for soil_index, soil in enumerate(SOILS):
            for surface_index, surface in enumerate(SURFACES):
                col = soil_index * len(SURFACES) + surface_index
                x = PAD + col * (TILE_W + PAD)
                path = _tile_path(args.root, season, soil, surface)
                tile = Image.open(path).convert("RGBA")
                sheet.alpha_composite(tile, (x, y + LABEL_H))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(args.out)
    print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
