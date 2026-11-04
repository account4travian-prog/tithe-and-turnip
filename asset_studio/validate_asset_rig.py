"""Fail-closed validator for v2 dimetric-rig candidates."""

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


HERE = Path(__file__).resolve().parent
DEFAULT_MANIFEST = HERE / "rigs_v2" / "resolved_rig_manifest.json"


def read_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical_digest(value: dict) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest()


def find_asset(manifest: dict, asset_id: str) -> dict:
    for asset in manifest.get("assets", []):
        if asset.get("id") == asset_id:
            return asset
    raise ValueError(f"asset '{asset_id}' is absent from independent manifest")


def structure_ground_controls(asset: dict) -> dict[str, list[int]]:
    south = next(surface for surface in asset["surfaces"] if surface["semantic"] == "wall_south")
    east = next(surface for surface in asset["surfaces"] if surface["semantic"] == "wall_east" and len(surface["polygon_px"]) == 4)
    return {
        "south": [int(value) for value in south["polygon_px"][0]],
        "near": [int(value) for value in south["polygon_px"][1]],
        "east": [int(value) for value in east["polygon_px"][0]],
    }


def validate_cohesive_controls(recipe: dict, asset: dict, output: dict, image: Image.Image, errors: list[str]) -> None:
    if asset.get("kind") != "structure" or len(asset.get("parts", [])) != 1:
        errors.append("cohesive pipeline is only valid for a single-part structure")
        return
    expected_target = structure_ground_controls(asset)
    if recipe.get("target_ground_controls_px") != expected_target:
        errors.append("cohesive target controls differ from independent rig geometry")
    source_records = recipe.get("sources", [])
    if len(source_records) != 1:
        errors.append("cohesive pipeline requires exactly one painted source")
        return
    metadata_path = Path(source_records[0].get("metadata_path", ""))
    if metadata_path.is_file():
        metadata = read_json(metadata_path)
        if recipe.get("source_ground_controls_px") != metadata.get("ground_control_px"):
            errors.append("cohesive source controls differ from source metadata")
        expected_elevation_scale = float(metadata.get("elevation_scale", 1.0))
        if float(recipe.get("elevation_scale", 1.0)) != expected_elevation_scale:
            errors.append("cohesive elevation scale differs from source metadata")
        if not 0.65 <= expected_elevation_scale <= 1.0:
            errors.append("cohesive elevation scale is outside the bounded correction range")

    anchor = [int(output.get("anchor_x", -1)), int(output.get("anchor_y", -1))]
    near = expected_target["near"]
    expected_local = {
        name: [anchor[0] + point[0] - near[0], anchor[1] + point[1] - near[1]]
        for name, point in expected_target.items()
    }
    if output.get("ground_controls_local_px") != expected_local:
        errors.append("cohesive output ground controls do not match its rig-relative anchor")
        return
    alpha = image.getchannel("A")
    for name, point in expected_local.items():
        if not (0 <= point[0] < image.width and 0 <= point[1] < image.height):
            errors.append(f"cohesive {name} ground control lies outside output")
        elif alpha.getpixel(tuple(point)) == 0:
            errors.append(f"cohesive {name} ground control is transparent")

    # A guide-conditioned repaint may carry eaves, ridge trim, and foundation
    # beyond the bare prism polygons. It may not, however, expand into an
    # unbounded scene or hide a second coordinate system in oversized margins.
    canvas = asset.get("canvas_size_px", [0, 0])
    if image.width > int(canvas[0]) * 2 or image.height > int(canvas[1]) * 2:
        errors.append("cohesive output exceeds the bounded structure envelope")


def mask_for_part(asset: dict, part: str, crop: list[int]) -> Image.Image:
    size = (crop[2], crop[3])
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    left, top = crop[0], crop[1]
    for surface in asset["surfaces"]:
        if surface["part"] == part:
            draw.polygon([(point[0] - left, point[1] - top) for point in surface["polygon_px"]], fill=255)
    for slot in asset["slots"]:
        if slot["part"] == part and slot["kind"] != "contact":
            draw.polygon([(point[0] - left, point[1] - top) for point in slot["polygon_px"]], fill=255)
    return mask


def validate(candidate: Path, manifest_path: Path = DEFAULT_MANIFEST) -> dict:
    errors: list[str] = []
    warnings: list[str] = []
    recipe_path = candidate / "recipe.json"
    if not recipe_path.is_file():
        return {"ok": False, "errors": ["missing recipe.json"], "warnings": []}
    recipe = read_json(recipe_path)
    is_cohesive = recipe.get("pipeline") == "cohesive_structure"
    if not manifest_path.is_file():
        return {"ok": False, "errors": [f"missing independent manifest: {manifest_path}"], "warnings": []}
    manifest = read_json(manifest_path)
    if recipe.get("resolved_manifest_sha256") != digest(manifest_path):
        errors.append("recipe manifest hash differs from independent resolved manifest")
    try:
        asset = find_asset(manifest, str(recipe.get("asset_id", "")))
    except ValueError as error:
        return {"ok": False, "errors": [str(error)], "warnings": []}
    if recipe.get("resolved_asset_sha256") != canonical_digest(asset):
        errors.append("recipe asset hash differs from independent resolved asset")
    if recipe.get("resolved_rig") != asset:
        errors.append("embedded recipe geometry differs from independent resolved asset")
    scale = float(asset.get("runtime", {}).get("draw_scale", 0.0))
    source_scale = int(asset.get("source_scale", 0))
    if source_scale <= 0 or scale != 1.0 / source_scale:
        errors.append("draw_scale is not exactly derived from source_scale")
    expected_parts = {part["id"] for part in asset.get("parts", [])}
    actual_parts = {output["part"] for output in recipe.get("outputs", [])}
    if expected_parts != actual_parts:
        errors.append("recipe output parts do not match resolved rig parts")
    for source in recipe.get("sources", []):
        path = Path(source.get("path", ""))
        if not path.is_file():
            errors.append(f"missing source file: {path}")
        elif source.get("sha256") != digest(path):
            errors.append(f"source hash mismatch: {path}")
        for key in ("backend", "model", "prompt", "license"):
            if not str(source.get(key, "")).strip():
                errors.append(f"source provenance missing {key}: {path}")
        if not bool(source.get("synthetic", False)):
            metadata_path = Path(source.get("metadata_path", ""))
            if not metadata_path.is_file():
                errors.append(f"missing source metadata: {metadata_path}")
            elif source.get("metadata_sha256") != digest(metadata_path):
                errors.append(f"source metadata hash mismatch: {metadata_path}")
    for output in recipe.get("outputs", []):
        image_path = candidate / output["file"]
        if not image_path.is_file():
            errors.append(f"missing output: {output['file']}")
            continue
        image = Image.open(image_path).convert("RGBA")
        if output.get("sha256") != digest(image_path):
            errors.append(f"output hash mismatch: {output['file']}")
        if image.size != (int(output["frame_w"]), int(output["frame_h"])):
            errors.append(f"frame dimensions mismatch: {output['file']}")
        anchor_x, anchor_y = int(output["anchor_x"]), int(output["anchor_y"])
        if not (0 <= anchor_x < image.width and 0 <= anchor_y < image.height):
            errors.append(f"anchor outside output: {output['file']}")
        if float(output["draw_scale"]) != scale:
            errors.append(f"output scale differs from rig: {output['file']}")
        alpha = image.getchannel("A")
        corners = [alpha.getpixel((0, 0)), alpha.getpixel((image.width - 1, 0)), alpha.getpixel((0, image.height - 1)), alpha.getpixel((image.width - 1, image.height - 1))]
        if any(corners):
            errors.append(f"nontransparent output corner: {output['file']}")

        runtime_file = str(output.get("runtime_file", ""))
        runtime_path = candidate / runtime_file
        if not runtime_file or not runtime_path.is_file():
            errors.append(f"missing runtime-baked output: {runtime_file or output['file']}")
        else:
            runtime = Image.open(runtime_path).convert("RGBA")
            expected_runtime_size = (image.width // source_scale, image.height // source_scale)
            if image.width % source_scale != 0 or image.height % source_scale != 0:
                errors.append(f"source output is not aligned to source_scale: {output['file']}")
            if runtime.size != expected_runtime_size:
                errors.append(f"runtime dimensions are not an exact source-scale reduction: {runtime_file}")
            if runtime.size != (int(output.get("runtime_frame_w", -1)), int(output.get("runtime_frame_h", -1))):
                errors.append(f"runtime frame dimensions mismatch: {runtime_file}")
            if int(output.get("runtime_anchor_x", -1)) != anchor_x // source_scale \
                    or int(output.get("runtime_anchor_y", -1)) != anchor_y // source_scale:
                errors.append(f"runtime anchor is not exactly source-scale derived: {runtime_file}")
            if anchor_x % source_scale != 0 or anchor_y % source_scale != 0:
                errors.append(f"source anchor is not aligned to source_scale: {output['file']}")
            if float(output.get("runtime_draw_scale", 0.0)) != 1.0:
                errors.append(f"runtime-baked output must draw at scale 1: {runtime_file}")
            if output.get("runtime_sha256") != digest(runtime_path):
                errors.append(f"runtime output hash mismatch: {runtime_file}")
            runtime_alpha = runtime.getchannel("A")
            runtime_corners = [
                runtime_alpha.getpixel((0, 0)),
                runtime_alpha.getpixel((runtime.width - 1, 0)),
                runtime_alpha.getpixel((0, runtime.height - 1)),
                runtime_alpha.getpixel((runtime.width - 1, runtime.height - 1)),
            ]
            if any(runtime_corners):
                errors.append(f"nontransparent runtime output corner: {runtime_file}")
            if not any(0 < value < 255 for value in runtime_alpha.get_flattened_data()):
                errors.append(f"runtime output has no antialiased edge coverage: {runtime_file}")
        if asset.get("kind") == "freestanding_prop":
            contact = next(slot for slot in asset["slots"] if slot["kind"] == "contact")
            contact_x = int(contact["contact_center_px"][0]) - int(output["crop_rect_px"][0])
            contact_y = int(contact["contact_center_px"][1]) - int(output["crop_rect_px"][1])
            if not (0 <= contact_x < image.width and 0 <= contact_y < image.height):
                errors.append(f"prop contact centre is outside output: {output['file']}")
            elif alpha.getpixel((contact_x, contact_y)) == 0:
                errors.append(f"prop contact centre is transparent: {output['file']}")
            envelope = asset.get("alpha_envelope_rect_px", [])
            if not isinstance(envelope, list) or len(envelope) != 4:
                errors.append(f"prop has no resolved alpha envelope: {output['file']}")
            else:
                allowed = Image.new("L", image.size, 0)
                left = int(envelope[0]) - int(output["crop_rect_px"][0])
                top = int(envelope[1]) - int(output["crop_rect_px"][1])
                right = left + int(envelope[2]) - 1
                bottom = top + int(envelope[3]) - 1
                ImageDraw.Draw(allowed).rectangle((left, top, right, bottom), fill=255)
                outside = ImageChops.subtract(alpha, allowed)
                if outside.getbbox() is not None:
                    errors.append(f"prop opaque pixels escape declared alpha envelope: {output['file']}")
            # The sort origin is the footprint's near corner, not necessarily
            # a painted pixel. A transparent sort anchor is valid and expected.
            continue
        if is_cohesive:
            validate_cohesive_controls(recipe, asset, output, image, errors)
            continue
        # Projective resampling can soften alpha one source pixel beyond an
        # otherwise exact slot edge. Allow exactly that documented raster
        # tolerance without weakening the rig's geometric envelope.
        allowed = mask_for_part(asset, output["part"], output["crop_rect_px"]).filter(ImageFilter.MaxFilter(3))
        outside = ImageChops.subtract(alpha, allowed)
        if outside.getbbox() is not None:
            errors.append(f"opaque pixels escape declared rig polygons: {output['file']}")
    return {"ok": not errors, "errors": errors, "warnings": warnings, "asset_id": recipe.get("asset_id", "")}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    args = parser.parse_args()
    result = validate(args.candidate, args.manifest)
    (args.candidate / "validation.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    for message in result["errors"]:
        print(f"ERROR: {message}")
    for message in result["warnings"]:
        print(f"WARNING: {message}")
    print(f"Validation {'passed' if result['ok'] else 'failed'}: {result.get('asset_id', '')}")
    return 0 if result["ok"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
