
"""Pad an exact rig candidate into a model-ready structure control image.

The output keeps every rig pixel at its authored source scale and records the
nominal South/near/East foundation controls after padding. AI output remains a
review candidate: the recorded points are controls to preserve, not evidence
that a model actually preserved them.
"""

import argparse
import json
from pathlib import Path

from PIL import Image

from compose_asset_rig import find_asset, read_json, sha256
from compose_cohesive_structure import ground_controls


HERE = Path(__file__).resolve().parent
DEFAULT_MANIFEST = HERE / "rigs_v2" / "resolved_rig_manifest.json"


def parse_hex_color(value: str) -> tuple[int, int, int, int]:
    normalized = value.removeprefix("#")
    if len(normalized) != 6:
        raise ValueError("background must be a six-digit RGB hex color")
    try:
        return (
            int(normalized[0:2], 16),
            int(normalized[2:4], 16),
            int(normalized[4:6], 16),
            255,
        )
    except ValueError as error:
        raise ValueError("background must be a six-digit RGB hex color") from error


def prepare(source_path: Path, asset_id: str, manifest_path: Path, recipe_path: Path | None,
            output_path: Path, canvas_size: int, background: str) -> dict:
    if canvas_size <= 0:
        raise ValueError("canvas size must be positive")
    manifest = read_json(manifest_path)
    asset = find_asset(manifest, asset_id)
    resolved_recipe_path = recipe_path or source_path.parent / "recipe.json"
    recipe = read_json(resolved_recipe_path)
    if recipe.get("asset_id") != asset_id:
        raise ValueError("candidate recipe asset does not match --asset")
    if recipe.get("resolved_manifest_sha256") != sha256(manifest_path):
        raise ValueError("candidate recipe does not match the current resolved manifest")
    matching_outputs = [
        output for output in recipe.get("outputs", [])
        if output.get("file") == source_path.name
    ]
    if len(matching_outputs) != 1:
        raise ValueError("candidate recipe must identify the source output exactly once")
    candidate_output = matching_outputs[0]
    if candidate_output.get("sha256") != sha256(source_path):
        raise ValueError("candidate source hash does not match its recipe")
    expected_size = (
        int(candidate_output["frame_w"]),
        int(candidate_output["frame_h"]),
    )
    with Image.open(source_path) as opened:
        source = opened.convert("RGBA")
    if source.size != expected_size:
        raise ValueError(
            f"source size {source.size} does not match the candidate recipe {expected_size}"
        )
    if source.width > canvas_size or source.height > canvas_size:
        raise ValueError("resolved rig does not fit the requested square model canvas")

    offset = ((canvas_size - source.width) // 2, (canvas_size - source.height) // 2)
    canvas = Image.new("RGBA", (canvas_size, canvas_size), parse_hex_color(background))
    canvas.alpha_composite(source, offset)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(output_path)

    crop_rect = [int(value) for value in candidate_output["crop_rect_px"]]
    nominal_controls = ground_controls(asset)
    padded_controls = {
        name: [
            point[0] - crop_rect[0] + offset[0],
            point[1] - crop_rect[1] + offset[1],
        ]
        for name, point in nominal_controls.items()
    }
    record = {
        "version": 1,
        "purpose": "guide-preserving img2img control; AI result still requires conformance review",
        "asset_id": asset_id,
        "resolved_manifest_path": str(manifest_path),
        "resolved_manifest_sha256": sha256(manifest_path),
        "candidate_recipe_path": str(resolved_recipe_path),
        "candidate_recipe_sha256": sha256(resolved_recipe_path),
        "source_path": str(source_path),
        "source_sha256": sha256(source_path),
        "output_path": str(output_path),
        "output_sha256": sha256(output_path),
        "canvas_size_px": [canvas_size, canvas_size],
        "source_offset_px": [offset[0], offset[1]],
        "background": "#" + background.removeprefix("#").lower(),
        "nominal_ground_control_px": padded_controls,
    }
    metadata_path = output_path.with_suffix(".json")
    metadata_path.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    return record


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--asset", required=True)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--recipe", type=Path, default=None)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--canvas-size", type=int, default=1024)
    parser.add_argument("--background", default="ff00ff")
    args = parser.parse_args()
    try:
        record = prepare(
            args.source,
            args.asset,
            args.manifest,
            args.recipe,
            args.output,
            args.canvas_size,
            args.background,
        )
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}")
        return 2
    print(f"Prepared {record['asset_id']} detail control at {record['output_path']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


