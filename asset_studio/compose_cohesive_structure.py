"""Align one cohesively painted structure to an existing dimetric rig.

The source remains a single finished painting. Three annotated ground-contact
landmarks receive one affine correction so the whole silhouette keeps a
consistent hand while its South and East foundation edges exactly match the
resolved footprint. This lane is deliberately limited to guide-conditioned
sources that are already close to the target; it is not a rescue transform for
arbitrary whole-building renders.
"""

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

from compose_asset_rig import alpha_safe_resize, affine_coefficients, crop_part, find_asset, read_json, sha256


HERE = Path(__file__).resolve().parent
DEFAULT_MANIFEST = HERE / "rigs_v2" / "resolved_rig_manifest.json"
CONTROL_NAMES = ("south", "near", "east")
CANVAS_MARGIN = 512


def canonical_digest(value: dict) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest()


def ground_controls(asset: dict) -> dict[str, list[int]]:
    south = next(surface for surface in asset["surfaces"] if surface["semantic"] == "wall_south")
    east = next(surface for surface in asset["surfaces"] if surface["semantic"] == "wall_east" and len(surface["polygon_px"]) == 4)
    return {
        "south": [int(value) for value in south["polygon_px"][0]],
        "near": [int(value) for value in south["polygon_px"][1]],
        "east": [int(value) for value in east["polygon_px"][0]],
    }


def source_record(source_path: Path, metadata_path: Path, metadata: dict) -> dict:
    required = ("backend", "model", "prompt", "license", "ground_control_px")
    missing = [key for key in required if not metadata.get(key)]
    if missing:
        raise ValueError(f"source metadata {metadata_path} is missing: {', '.join(missing)}")
    controls = metadata["ground_control_px"]
    if not isinstance(controls, dict) or any(name not in controls for name in CONTROL_NAMES):
        raise ValueError("ground_control_px must define south, near, and east")
    return {
        "id": source_path.stem,
        "path": str(source_path),
        "sha256": sha256(source_path),
        "metadata_path": str(metadata_path),
        "metadata_sha256": sha256(metadata_path),
        "backend": str(metadata["backend"]),
        "model": str(metadata["model"]),
        "prompt": str(metadata["prompt"]),
        "license": str(metadata["license"]),
        "synthetic": bool(metadata.get("synthetic", False)),
    }


def validate_source_controls(source: Image.Image, raw_controls: dict) -> dict[str, list[int]]:
    controls: dict[str, list[int]] = {}
    for name in CONTROL_NAMES:
        raw = raw_controls[name]
        if not isinstance(raw, list) or len(raw) != 2:
            raise ValueError(f"ground control '{name}' must be [x, y]")
        point = [int(raw[0]), int(raw[1])]
        if not (0 <= point[0] < source.width and 0 <= point[1] < source.height):
            raise ValueError(f"ground control '{name}' lies outside the source image")
        controls[name] = point
    signed_area = (
        (controls["near"][0] - controls["south"][0]) * (controls["east"][1] - controls["south"][1])
        - (controls["near"][1] - controls["south"][1]) * (controls["east"][0] - controls["south"][0])
    )
    if abs(signed_area) < 16:
        raise ValueError("ground controls are collinear or too close together")
    return controls


def transform_premultiplied(source: Image.Image, size: tuple[int, int], coefficients: tuple[float, ...]) -> Image.Image:
    premultiplied = source.convert("RGBa")
    transformed = premultiplied.transform(
        size,
        Image.Transform.AFFINE,
        coefficients,
        Image.Resampling.BICUBIC,
        fillcolor=(0, 0, 0, 0),
    )
    return transformed.convert("RGBA")


def compress_elevation(source: Image.Image, controls: dict[str, list[int]], scale: float) -> Image.Image:
    """Reduce painted height while leaving the exact ground polyline fixed.

    Each visible face uses its own affine half-plane. Both transformations are
    continuous at the near corner, so the building remains one cohesive image
    while an over-tall generated elevation can be corrected without moving any
    foundation landmark or changing the logical footprint.
    """
    if scale == 1.0:
        return source
    if not 0.65 <= scale <= 1.0:
        raise ValueError("elevation_scale must be between 0.65 and 1.0")

    result = source.copy()
    near_x = int(controls["near"][0])
    segments = (("south", "near", 0, near_x), ("near", "east", near_x, source.width))
    for start_name, end_name, x_min, x_max in segments:
        start = controls[start_name]
        end = controls[end_name]
        run = float(end[0] - start[0])
        if abs(run) < 1.0:
            raise ValueError("ground control segment is too narrow for elevation compression")
        slope = float(end[1] - start[1]) / run
        intercept = float(start[1]) - slope * float(start[0])
        inverse = (
            1.0,
            0.0,
            0.0,
            -((1.0 - scale) * slope / scale),
            1.0 / scale,
            -((1.0 - scale) * intercept / scale),
        )
        compressed = transform_premultiplied(source, source.size, inverse)
        mask = Image.new("L", source.size, 0)
        ground_min = round(slope * float(x_min) + intercept)
        ground_max = round(slope * float(x_max) + intercept)
        ImageDraw.Draw(mask).polygon(
            ((x_min, 0), (x_max, 0), (x_max, ground_max), (x_min, ground_min)),
            fill=255,
        )
        result = Image.composite(compressed, result, mask)
    return result


def compose(asset: dict, source_path: Path, out_dir: Path, manifest_path: Path) -> dict:
    if asset.get("kind") != "structure" or len(asset.get("parts", [])) != 1:
        raise ValueError("cohesive structure lane requires a single-part structure rig")
    metadata_path = source_path.with_suffix(".json")
    if not source_path.is_file() or not metadata_path.is_file():
        raise ValueError("cohesive source PNG and matching JSON metadata are required")
    metadata = read_json(metadata_path)
    source = Image.open(source_path).convert("RGBA")
    source_controls = validate_source_controls(source, metadata["ground_control_px"])
    target_controls = ground_controls(asset)

    # Work on a generous transparent canvas so roof/eave overhang is never
    # clipped. The crop later removes this implementation margin.
    offset = [CANVAS_MARGIN, CANVAS_MARGIN]
    shifted_targets = {
        name: [target_controls[name][0] + offset[0], target_controls[name][1] + offset[1]]
        for name in CONTROL_NAMES
    }
    destination = [tuple(float(value) for value in shifted_targets[name]) for name in CONTROL_NAMES]
    source_points = [tuple(float(value) for value in source_controls[name]) for name in CONTROL_NAMES]
    coefficients = affine_coefficients(destination, source_points)
    canvas_size = (source.width + CANVAS_MARGIN * 2, source.height + CANVAS_MARGIN * 2)
    transformed = transform_premultiplied(source, canvas_size, coefficients)
    elevation_scale = float(metadata.get("elevation_scale", 1.0))
    transformed = compress_elevation(transformed, shifted_targets, elevation_scale)

    source_scale = int(asset["source_scale"])
    near_anchor = shifted_targets["near"]
    cropped, anchor, crop = crop_part(transformed, near_anchor, source_scale)
    out_dir.mkdir(parents=True, exist_ok=True)
    source_output = out_dir / "final.png"
    cropped.save(source_output)
    runtime = alpha_safe_resize(cropped, (cropped.width // source_scale, cropped.height // source_scale))
    runtime_output = out_dir / "final_runtime.png"
    runtime.save(runtime_output)

    local_controls = {
        name: [shifted_targets[name][0] - crop[0], shifted_targets[name][1] - crop[1]]
        for name in CONTROL_NAMES
    }
    output = {
        "part": asset["parts"][0]["id"],
        "file": source_output.name,
        "frame_w": cropped.width,
        "frame_h": cropped.height,
        "anchor_x": anchor[0],
        "anchor_y": anchor[1],
        "crop_rect_px": crop,
        "draw_scale": asset["runtime"]["draw_scale"],
        "sha256": sha256(source_output),
        "runtime_file": runtime_output.name,
        "runtime_frame_w": runtime.width,
        "runtime_frame_h": runtime.height,
        "runtime_anchor_x": anchor[0] // source_scale,
        "runtime_anchor_y": anchor[1] // source_scale,
        "runtime_draw_scale": 1.0,
        "runtime_sha256": sha256(runtime_output),
        "ground_controls_local_px": local_controls,
    }
    recipe = {
        "version": 3,
        "pipeline": "cohesive_structure",
        "asset_id": asset["id"],
        "kind": asset["kind"],
        "resolved_manifest_path": str(manifest_path),
        "resolved_manifest_sha256": sha256(manifest_path),
        "resolved_asset_sha256": canonical_digest(asset),
        "resolved_rig": asset,
        "outputs": [output],
        "sources": [source_record(source_path, metadata_path, metadata)],
        "source_ground_controls_px": source_controls,
        "target_ground_controls_px": target_controls,
        "elevation_scale": elevation_scale,
        "transform": {
            "kind": "affine" if elevation_scale == 1.0 else "affine_plus_elevation_compression",
            "destination_to_source_coefficients": [round(value, 12) for value in coefficients],
        },
    }
    (out_dir / "recipe.json").write_text(json.dumps(recipe, indent=2) + "\n", encoding="utf-8")
    return recipe


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--asset", required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()
    try:
        asset = find_asset(read_json(args.manifest), args.asset)
        recipe = compose(asset, args.source, args.out_dir, args.manifest)
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}")
        return 2
    output = recipe["outputs"][0]
    print(
        f"Composed cohesive {recipe['asset_id']} into {args.out_dir} "
        f"({output['runtime_frame_w']}x{output['runtime_frame_h']}, "
        f"anchor {output['runtime_anchor_x']},{output['runtime_anchor_y']})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
