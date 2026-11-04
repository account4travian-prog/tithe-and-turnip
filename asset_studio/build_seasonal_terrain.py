"""Build the season-aware terrain tile set used by ADR-042.

This is intentionally deterministic: a single generated Spring source sheet
supplies sandy and rocky material families, while Summer/Autumn/Winter are
palette treatments of the exact same masked Spring tiles.  That keeps all
four seasons visually related and lets the existing tile/transition pipeline
own seams and diamond alpha.
"""

import argparse
import os
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageOps

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_seamless import make_seamless
from make_terrain_tiles import TILE_H, TILE_W, diamond_alpha, make_tiles
from make_terrain_transitions import edge_gradient, shared_noise, tile_rgb


SOILS = ("loamy", "sandy", "rocky")
SURFACES = ("grass", "tilled", "tilled_wet")
SEASONS = ("summer", "autumn", "winter")
SHEET_MATERIALS = (
    "sandy_grass", "sandy_tilled", "sandy_tilled_wet",
    "rocky_grass", "rocky_tilled", "rocky_tilled_wet",
)
VARIANT_COUNTS = {"grass": 4, "tilled": 3, "tilled_wet": 3}
PALETTES = {
    "summer": {
        "grass": ("#52673b", "#b0b85d"),
        "tilled": ("#52351f", "#b27842"),
        "tilled_wet": ("#2e2a22", "#6b5a3d"),
    },
    "autumn": {
        "grass": ("#665130", "#c29b4d"),
        "tilled": ("#4f2f21", "#9b5932"),
        "tilled_wet": ("#302521", "#6d4938"),
    },
    "winter": {
        "grass": ("#56636a", "#ced6d1"),
        # Frozen earth stays muted and cool, but remains recognizably soil.
        # The previous blue-gray range made worked Winter plots read as slush.
        "tilled": ("#4b4033", "#98856b"),
        "tilled_wet": ("#39342c", "#6c6254"),
    },
}


def _write_transition_tiles(source_a: Path, source_b: Path, out_dir: Path, crop: int) -> None:
    """Write the edge-mask transition family matching FarmRenderer exactly."""
    import numpy as np

    out_dir.mkdir(parents=True, exist_ok=True)
    a = np.asarray(tile_rgb(str(source_a), crop), dtype=np.float32)
    b = np.asarray(tile_rgb(str(source_b), crop), dtype=np.float32)
    noise = shared_noise(TILE_W, TILE_H)
    alpha = diamond_alpha(TILE_W, TILE_H)
    for config in range(16):
        gradient = edge_gradient(TILE_W, TILE_H, config)
        perturbed = np.clip(gradient + noise * 0.35, 0.0, 1.0)
        mask = np.clip((perturbed - 0.36) / 0.28, 0.0, 1.0)[..., None]
        tile = Image.fromarray(np.clip(a * (1.0 - mask) + b * mask, 0, 255).astype(np.uint8))
        tile = tile.convert("RGBA")
        tile.putalpha(alpha)
        tile.save(out_dir / f"{config:04b}.png")


def _slice_material_sheet(sheet_path: Path, source_dir: Path) -> dict[str, Path]:
    sheet = Image.open(sheet_path).convert("RGB")
    width, height = sheet.size
    if width % 2 != 0 or height % 3 != 0:
        raise ValueError(f"Expected a 2x3 source sheet, got {width}x{height}")
    source_dir.mkdir(parents=True, exist_ok=True)
    cell_w, cell_h = width // 2, height // 3
    out: dict[str, Path] = {}
    for index, material_id in enumerate(SHEET_MATERIALS):
        x = (index % 2) * cell_w
        y = (index // 2) * cell_h
        material = sheet.crop((x, y, x + cell_w, y + cell_h))
        seamless = make_seamless(material)
        path = source_dir / f"{material_id}.png"
        seamless.save(path)
        out[material_id] = path
    return out


def _west_east_rows(source: Path, destination: Path) -> Path:
    """Shear vertical furrows onto the projected West->East axis.

    In this dimetric view grid East runs down-right on screen. Shifting each
    scanline by one complete source width over its height turns source-vertical
    rows into that down-right diagonal while wrapping exactly at the top/bottom
    seam, so the resulting material stays tileable.
    """
    image = Image.open(source).convert("RGB")
    width, height = image.size
    oriented = Image.new("RGB", image.size)
    for y in range(height):
        shift = int(float(y) / float(height) * float(width))
        row = image.crop((0, y, width, y + 1))
        oriented.paste(ImageChops.offset(row, shift, 0), (0, y))
    destination.parent.mkdir(parents=True, exist_ok=True)
    oriented.save(destination)
    return destination


def _season_tile(src: Path, dest: Path, season: str, surface: str) -> None:
    image = Image.open(src).convert("RGBA")
    alpha = image.getchannel("A")
    low, high = PALETTES[season][surface]
    rgb = ImageOps.colorize(ImageOps.grayscale(image.convert("RGB")), low, high)
    rgb.putalpha(alpha)
    dest.parent.mkdir(parents=True, exist_ok=True)
    rgb.save(dest)


def _spring_paths(runtime_dir: Path) -> list[tuple[Path, str]]:
    paths: list[tuple[Path, str]] = []
    for soil in SOILS:
        for surface in SURFACES:
            count = VARIANT_COUNTS[surface]
            for index in range(count):
                paths.append((runtime_dir / f"{soil}_{surface}_{index}.png", surface))
        for pair in (f"{soil}_grass__{soil}_tilled", f"{soil}_tilled__{soil}_grass"):
            for index in range(16):
                paths.append((runtime_dir / pair / f"{index:04b}.png", "grass"))
    return paths


def build(sheet_path: Path, source_dir: Path, runtime_dir: Path) -> None:
    sources = _slice_material_sheet(sheet_path, source_dir)
    # The first approved loamy source generation remains the grass reference;
    # only cultivated material is re-authored for the requested row direction.
    sources["loamy_grass"] = Path("asset_studio/terrain_test/grass_seamless.png")
    sources["loamy_tilled"] = Path("asset_studio/terrain_test/tilled_seamless.png")
    sources["loamy_tilled_wet"] = Path("asset_studio/terrain_test/dirt_seamless.png")
    oriented_sources: dict[str, Path] = {}
    for material_id, source in sources.items():
        if material_id.endswith("_grass"):
            oriented_sources[material_id] = source
            continue
        oriented_sources[material_id] = _west_east_rows(
            source, source_dir / f"{material_id}_west_east.png")

    for soil in SOILS:
        for surface in SURFACES:
            material_id = f"{soil}_{surface}"
            if material_id == "loamy_grass":
                continue
            make_tiles(str(oriented_sources[material_id]), str(runtime_dir), material_id,
                       VARIANT_COUNTS[surface], 320)
        _write_transition_tiles(oriented_sources[f"{soil}_grass"], oriented_sources[f"{soil}_tilled"],
                                runtime_dir / f"{soil}_grass__{soil}_tilled", 320)
        _write_transition_tiles(oriented_sources[f"{soil}_tilled"], oriented_sources[f"{soil}_grass"],
                                runtime_dir / f"{soil}_tilled__{soil}_grass", 320)

    for src, surface in _spring_paths(runtime_dir):
        if not src.exists():
            raise FileNotFoundError(f"Missing approved Spring terrain tile: {src}")
        relative = src.relative_to(runtime_dir)
        for season in SEASONS:
            _season_tile(src, runtime_dir / season / relative, season, surface)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sheet", required=True, type=Path)
    parser.add_argument("--source-dir", required=True, type=Path)
    parser.add_argument("--runtime-dir", required=True, type=Path)
    args = parser.parse_args(argv)
    build(args.sheet, args.source_dir, args.runtime_dir)
    print("built West-East tilled terrain and Summer/Autumn/Winter tile variants")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
