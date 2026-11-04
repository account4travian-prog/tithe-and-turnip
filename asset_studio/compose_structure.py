"""Deterministically compose a generated structure shell with generated modules.

The guide manifest owns placement.  AI never decides where a door/window
belongs: each transparent module is trimmed, scaled to its prescribed slot
bounding box, and alpha-composited over the shell.  Preserve the original
shell and module images alongside the resulting assembled image; this script
writes a recipe JSON for exactly that reason.

Example:
    python asset_studio/compose_structure.py --asset coop --shell coop_shell.png \
        --module door_primary=coop_door.png --module ramp_primary=coop_ramp.png \
        --module window_east_1=coop_window.png --out coop_assembled.png
"""

import argparse
import json
import os
import sys
from pathlib import Path

from PIL import Image


HERE = Path(__file__).resolve().parent
DEFAULT_MANIFEST = HERE / "guides" / "guide_manifest.json"
LEGACY_MANIFEST_CANVAS = (1024, 1024)


def load_manifest(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def find_asset(manifest: dict, asset_id: str) -> dict:
    for asset in manifest.get("assets", []):
        if asset.get("id") == asset_id:
            return asset
    raise ValueError(f"asset '{asset_id}' is absent from {DEFAULT_MANIFEST}")


def parse_modules(values: list[str]) -> dict[str, Path]:
    modules: dict[str, Path] = {}
    for value in values:
        if "=" not in value:
            raise ValueError(f"module '{value}' must use anchor_id=path")
        anchor_id, raw_path = value.split("=", 1)
        if not anchor_id or not raw_path:
            raise ValueError(f"module '{value}' must use anchor_id=path")
        if anchor_id in modules:
            raise ValueError(f"module anchor '{anchor_id}' was supplied twice")
        modules[anchor_id] = Path(raw_path)
    return modules


def trim_alpha(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("module image is fully transparent")
    return image.crop(bbox)


def solve_linear_system(matrix: list[list[float]], values: list[float]) -> list[float]:
    """Solve a small square linear system with partial-pivot elimination."""
    size = len(values)
    augmented = [row[:] + [values[index]] for index, row in enumerate(matrix)]
    for column in range(size):
        pivot = max(range(column, size), key=lambda row: abs(augmented[row][column]))
        if abs(augmented[pivot][column]) < 1e-10:
            raise ValueError("module and guide corners do not define a valid perspective transform")
        augmented[column], augmented[pivot] = augmented[pivot], augmented[column]
        divisor = augmented[column][column]
        augmented[column] = [value / divisor for value in augmented[column]]
        for row in range(size):
            if row == column:
                continue
            factor = augmented[row][column]
            if factor:
                augmented[row] = [
                    augmented[row][index] - factor * augmented[column][index]
                    for index in range(size + 1)
                ]
    return [augmented[index][-1] for index in range(size)]


def perspective_coefficients(destination: list[tuple[float, float]], source: list[tuple[float, float]]) -> tuple[float, ...]:
    """Return Pillow coefficients that map guide quadrilateral pixels to source art."""
    if len(destination) != 4 or len(source) != 4:
        raise ValueError("perspective mapping needs exactly four source and destination corners")
    rows: list[list[float]] = []
    values: list[float] = []
    for (x, y), (u, v) in zip(destination, source, strict=True):
        rows.append([x, y, 1.0, 0.0, 0.0, 0.0, -u * x, -u * y])
        values.append(u)
        rows.append([0.0, 0.0, 0.0, x, y, 1.0, -v * x, -v * y])
        values.append(v)
    return tuple(solve_linear_system(rows, values))


def warp_module_to_slot(module: Image.Image, polygon: list[list[int]], canvas_size: tuple[int, int]) -> Image.Image:
    """Perspective-map a trimmed module onto the exact dimetric guide polygon."""
    if len(polygon) != 4:
        raise ValueError("guide slot polygon must contain exactly four corners")
    # Guides record corners clockwise from lower-left. PIL source art uses
    # top-left clockwise, so reverse the guide order for matching corners.
    destination = [(float(point[0]), float(point[1])) for point in (polygon[3], polygon[2], polygon[1], polygon[0])]
    source = [
        (0.0, 0.0),
        (float(module.width - 1), 0.0),
        (float(module.width - 1), float(module.height - 1)),
        (0.0, float(module.height - 1)),
    ]
    coefficients = perspective_coefficients(destination, source)
    warped = module.transform(
        canvas_size,
        Image.Transform.PERSPECTIVE,
        coefficients,
        Image.Resampling.BICUBIC,
        fillcolor=(0, 0, 0, 0),
    )
    # Pillow can emit opaque black outside an RGBA perspective transform on
    # some builds. Transform alpha separately so only the guide quadrilateral
    # can cover the shell.
    alpha = module.getchannel("A").transform(
        canvas_size,
        Image.Transform.PERSPECTIVE,
        coefficients,
        Image.Resampling.BICUBIC,
        fillcolor=0,
    )
    warped.putalpha(alpha)
    return warped


def manifest_canvas_size(manifest: dict) -> tuple[int, int]:
    raw_size = manifest.get("canvas_size_px")
    # Version-1 manifests predate this explicit field. Their generator's
    # fixed canvas was 1024 square, so preserve deterministic compatibility.
    if raw_size is None:
        return LEGACY_MANIFEST_CANVAS
    if not isinstance(raw_size, list) or len(raw_size) != 2:
        raise ValueError("guide manifest canvas_size_px must contain two integers")
    width, height = raw_size
    if not isinstance(width, int) or not isinstance(height, int) or width <= 0 or height <= 0:
        raise ValueError("guide manifest canvas_size_px must contain two positive integers")
    return width, height


def composite(manifest: dict, asset: dict, shell_path: Path, supplied: dict[str, Path]) -> tuple[Image.Image, dict]:
    shell = Image.open(shell_path).convert("RGBA")
    target_canvas = manifest_canvas_size(manifest)
    original_shell_size = shell.size
    if original_shell_size != target_canvas:
        shell = shell.resize(target_canvas, Image.Resampling.LANCZOS)
    slots = {slot["id"]: slot for slot in asset.get("slots", [])}
    expected = set(slots)
    supplied_ids = set(supplied)
    missing = sorted(expected - supplied_ids)
    extra = sorted(supplied_ids - expected)
    if missing or extra:
        messages = []
        if missing:
            messages.append("missing " + ", ".join(missing))
        if extra:
            messages.append("unknown " + ", ".join(extra))
        raise ValueError("module assignment does not match the structure guide: " + "; ".join(messages))

    recipe_layers = [{
        "role": "shell",
        "path": str(shell_path),
        "source_size_px": list(original_shell_size),
        "composite_canvas_px": list(target_canvas),
    }]
    output = shell.copy()
    for anchor_id in sorted(supplied):
        source_path = supplied[anchor_id]
        if not source_path.is_file():
            raise ValueError(f"module source does not exist: {source_path}")
        slot = slots[anchor_id]
        x, y, width, height = slot["bbox_px"]
        module = trim_alpha(Image.open(source_path).convert("RGBA"))
        fitted = warp_module_to_slot(module, slot["polygon"], target_canvas)
        output.alpha_composite(fitted)
        recipe_layers.append(
            {
                "role": "module",
                "anchor_id": anchor_id,
                "module_id": slot["module"],
                "face": slot["face"],
                "source": str(source_path),
                "target_bbox_px": [x, y, width, height],
                "target_polygon_px": slot["polygon"],
            }
        )
    return output, {"asset": asset["id"], "layers": recipe_layers}


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--asset", required=True, help="Structure id from guide_manifest.json")
    parser.add_argument("--shell", required=True, type=Path, help="Door/window-free RGBA structure shell")
    parser.add_argument("--module", action="append", default=[], help="anchor_id=transparent_module.png; repeat once per guide slot")
    parser.add_argument("--manifest", default=DEFAULT_MANIFEST, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args(argv)

    try:
        manifest = load_manifest(args.manifest)
        asset = find_asset(manifest, args.asset)
        if asset.get("guide_kind") != "structure_shell":
            raise ValueError(f"'{args.asset}' is not a structure shell")
        modules = parse_modules(args.module)
        assembled, recipe = composite(manifest, asset, args.shell, modules)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    args.out.parent.mkdir(parents=True, exist_ok=True)
    assembled.save(args.out)
    recipe_path = args.out.with_suffix(args.out.suffix + ".recipe.json")
    with recipe_path.open("w", encoding="utf-8") as handle:
        json.dump(recipe, handle, indent=2)
        handle.write("\n")
    print(f"Wrote {args.out} and {recipe_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
