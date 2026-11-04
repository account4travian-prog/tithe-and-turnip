"""Compose a detailed dimetric structure from a resolved rig and kit profile.

The kit is an offline compositor, not a second runtime coordinate system. It
uses Godot-resolved wall, roof, and fixture polygons verbatim. Wall framing is
painted before roof planes, so roof occlusion is deterministic and no timber
can leak through an eave.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

from compose_asset_rig import (
    alpha_safe_resize,
    crop_part,
    find_asset,
    mask_for_polygon,
    material_trim_colors,
    prepare_material_source,
    read_json,
    sha256,
    source_file,
    warp_material,
    warp_module,
)


HERE = Path(__file__).resolve().parent
DEFAULT_MANIFEST = HERE / "rigs_v2" / "resolved_rig_manifest.json"
DEFAULT_KIT = HERE / "structure_kit_v1.json"


def canonical_digest(value: dict) -> str:
    payload = json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def point_lerp(start: tuple[float, float], end: tuple[float, float], ratio: float) -> tuple[float, float]:
    return (
        start[0] + (end[0] - start[0]) * ratio,
        start[1] + (end[1] - start[1]) * ratio,
    )


def surface_mask(canvas_size: tuple[int, int], surfaces: list[dict], semantics: set[str]) -> Image.Image:
    mask = Image.new("L", canvas_size, 0)
    for surface in surfaces:
        if str(surface.get("semantic", "")) in semantics:
            mask = ImageChops.lighter(mask, mask_for_polygon(canvas_size, surface["polygon_px"]))
    return mask


def draw_line(draw: ImageDraw.ImageDraw, start: tuple[float, float], end: tuple[float, float], outer: tuple[int, int, int, int], inner: tuple[int, int, int, int], outer_width: int, inner_width: int) -> None:
    draw.line((start, end), fill=outer, width=max(1, outer_width))
    draw.line((start, end), fill=inner, width=max(1, inner_width))


def draw_wall_frame(canvas: Image.Image, surfaces: list[dict], profile: dict, wall_material: Image.Image) -> None:
    """Create logically spaced posts and rails, then let roof planes occlude them."""
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    outer, inner = material_trim_colors(wall_material)
    cross_ratio = float(profile["crossbeam_height_ratio"])
    for surface in surfaces:
        semantic = str(surface.get("semantic", ""))
        polygon = surface["polygon_px"]
        if semantic not in {"wall_south", "wall_east"}:
            continue
        if len(polygon) == 3:
            if bool(profile.get("gable_center_post", False)):
                base_midpoint = point_lerp(tuple(polygon[0]), tuple(polygon[1]), 0.5)
                draw_line(draw, base_midpoint, tuple(polygon[2]), outer, inner, 14, 7)
            for index in range(3):
                draw_line(draw, tuple(polygon[index]), tuple(polygon[(index + 1) % 3]), outer, inner, 10, 4)
            continue
        if len(polygon) != 4:
            continue
        face = "south" if semantic == "wall_south" else "east"
        bays = int(profile["wall_bays"][face])
        lower_left, lower_right, upper_right, upper_left = (tuple(point) for point in polygon)
        for index in range(bays + 1):
            ratio = float(index) / float(bays)
            base = point_lerp(lower_left, lower_right, ratio)
            top = point_lerp(upper_left, upper_right, ratio)
            outer_width = 20 if index in {0, bays} else 14
            inner_width = 9 if index in {0, bays} else 6
            draw_line(draw, base, top, outer, inner, outer_width, inner_width)
        rail_left = point_lerp(lower_left, upper_left, cross_ratio)
        rail_right = point_lerp(lower_right, upper_right, cross_ratio)
        draw_line(draw, rail_left, rail_right, outer, inner, 16, 7)
    layer.putalpha(ImageChops.multiply(layer.getchannel("A"), surface_mask(canvas.size, surfaces, {"wall_south", "wall_east"})))
    canvas.alpha_composite(layer)


def draw_roof_trim(canvas: Image.Image, surfaces: list[dict], profile: dict, roof_material: Image.Image) -> None:
    """Finish roof edges above the walls; the shared ridge is intentionally strongest."""
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    outer, inner = material_trim_colors(roof_material)
    outline_width = int(profile["roof_outline_width_source_px"])
    eave_width = int(profile["roof_eave_width_source_px"])
    ridge_width = int(profile["roof_ridge_width_source_px"])
    roof_surfaces = [surface for surface in surfaces if str(surface.get("semantic", "")) == "roof"]
    for surface in roof_surfaces:
        polygon = [tuple(point) for point in surface["polygon_px"]]
        if len(polygon) != 4:
            continue
        for index in range(4):
            draw_line(
                draw,
                polygon[index],
                polygon[(index + 1) % 4],
                outer,
                inner,
                outline_width,
                max(1, outline_width // 2),
            )
    if len(roof_surfaces) == 2:
        first = [tuple(point) for point in roof_surfaces[0]["polygon_px"]]
        second = [tuple(point) for point in roof_surfaces[1]["polygon_px"]]
        shared = sorted(set(first).intersection(second))
        if len(shared) == 2:
            draw_line(draw, shared[0], shared[1], outer, inner, ridge_width, max(1, ridge_width // 3))
    # The lowest edge of each roof plane reads as an eave. It is painted last
    # so the separation of roof and wall stays unambiguous at runtime scale.
    for surface in roof_surfaces:
        polygon = [tuple(point) for point in surface["polygon_px"]]
        if len(polygon) == 4:
            draw_line(draw, polygon[0], polygon[1], outer, inner, eave_width, max(1, eave_width // 3))
    layer.putalpha(ImageChops.multiply(layer.getchannel("A"), surface_mask(canvas.size, surfaces, {"roof"})))
    canvas.alpha_composite(layer)


def output_record(asset: dict, output_path: Path, runtime_path: Path, anchor: list[int], crop: list[int]) -> dict:
    source_scale = int(asset["source_scale"])
    source = Image.open(output_path).convert("RGBA")
    runtime = Image.open(runtime_path).convert("RGBA")
    return {
        "part": "final",
        "file": output_path.name,
        "frame_w": source.width,
        "frame_h": source.height,
        "anchor_x": anchor[0],
        "anchor_y": anchor[1],
        "crop_rect_px": crop,
        "draw_scale": asset["runtime"]["draw_scale"],
        "sha256": sha256(output_path),
        "runtime_file": runtime_path.name,
        "runtime_frame_w": runtime.width,
        "runtime_frame_h": runtime.height,
        "runtime_anchor_x": anchor[0] // source_scale,
        "runtime_anchor_y": anchor[1] // source_scale,
        "runtime_draw_scale": 1.0,
        "runtime_sha256": sha256(runtime_path),
    }


def compose(asset: dict, kit: dict, source_root: Path, out_dir: Path, manifest_path: Path) -> dict:
    if asset.get("kind") != "structure" or len(asset.get("parts", [])) != 1:
        raise ValueError("structure-kit composition requires a single-part exterior structure")
    profile = kit.get("profiles", {}).get(asset["id"])
    if not isinstance(profile, dict):
        raise ValueError(f"kit has no profile for asset '{asset['id']}'")
    canvas_size = tuple(asset["canvas_size_px"])
    canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    surfaces: list[dict] = list(asset["surfaces"])
    slots: list[dict] = list(asset["slots"])
    sources: list[dict] = []
    source_images: dict[str, Image.Image] = {}

    def material_for(surface: dict) -> Image.Image:
        material_id = str(surface["material"])
        if material_id not in source_images:
            raw, record = source_file(source_root, "materials", material_id, False, out_dir / "_synthetic")
            source_images[material_id] = raw
            sources.append(record)
        return prepare_material_source(source_images[material_id], next(record for record in sources if record["id"] == material_id), str(surface["semantic"]))

    wall_surfaces = [surface for surface in surfaces if str(surface["semantic"]).startswith("wall_")]
    roof_surfaces = [surface for surface in surfaces if str(surface["semantic"]) == "roof"]
    for surface in wall_surfaces:
        canvas.alpha_composite(warp_material(material_for(surface), surface["polygon_px"], canvas_size))

    wall_material_id = str(kit["shared_modules"]["wall_material"])
    draw_wall_frame(canvas, wall_surfaces, profile, source_images[wall_material_id])

    for surface in roof_surfaces:
        canvas.alpha_composite(warp_material(material_for(surface), surface["polygon_px"], canvas_size))
    roof_material_id = str(kit["shared_modules"]["roof_material"])
    draw_roof_trim(canvas, roof_surfaces, profile, source_images[roof_material_id])

    for slot in slots:
        module_id = str(slot["module"])
        module, record = source_file(source_root, "modules", module_id, False, out_dir / "_synthetic")
        sources.append(record)
        canvas.alpha_composite(warp_module(module, slot["polygon_px"], canvas_size))

    source_scale = int(asset["source_scale"])
    cropped, anchor, crop = crop_part(canvas, asset["parts"][0]["anchor_px"], source_scale)
    out_dir.mkdir(parents=True, exist_ok=True)
    source_output = out_dir / "final.png"
    cropped.save(source_output)
    runtime_output = out_dir / "final_runtime.png"
    alpha_safe_resize(cropped, (cropped.width // source_scale, cropped.height // source_scale)).save(runtime_output)
    recipe = {
        "version": 1,
        "pipeline": "structure_kit",
        "asset_id": asset["id"],
        "kind": asset["kind"],
        "kit_path": str(DEFAULT_KIT),
        "kit_sha256": sha256(DEFAULT_KIT),
        "resolved_manifest_path": str(manifest_path),
        "resolved_manifest_sha256": sha256(manifest_path),
        "resolved_asset_sha256": canonical_digest(asset),
        "resolved_rig": asset,
        "outputs": [output_record(asset, source_output, runtime_output, anchor, crop)],
        "sources": sources,
    }
    (out_dir / "recipe.json").write_text(json.dumps(recipe, indent=2) + "\n", encoding="utf-8")
    return recipe


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--asset", required=True)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--kit", type=Path, default=DEFAULT_KIT)
    parser.add_argument("--source-root", type=Path, default=HERE / "sources_v2")
    parser.add_argument("--out-dir", type=Path, required=True)
    arguments = parser.parse_args()
    try:
        manifest = read_json(arguments.manifest)
        recipe = compose(find_asset(manifest, arguments.asset), read_json(arguments.kit), arguments.source_root, arguments.out_dir, arguments.manifest)
    except (KeyError, OSError, ValueError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}")
        return 2
    output = recipe["outputs"][0]
    print(f"Composed structure kit {arguments.asset}: {output['runtime_frame_w']}x{output['runtime_frame_h']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
