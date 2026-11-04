
"""Compose a v2 dimetric rig from flat materials and flat-front modules.

The resolved rig manifest is the geometry authority. This program only fills
or projects supplied source art into those resolved polygons; it never derives
dimetric coordinates itself. `--synthetic` creates disposable paint sources
for geometry testing and does not call a model.
"""

import argparse
import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageOps


HERE = Path(__file__).resolve().parent
DEFAULT_MANIFEST = HERE / "rigs_v2" / "resolved_rig_manifest.json"
PAD = 8
MATERIAL_EDGE_INSET = 2


def read_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def find_asset(manifest: dict, asset_id: str) -> dict:
    for asset in manifest["assets"]:
        if asset["id"] == asset_id:
            return asset
    raise ValueError(f"asset '{asset_id}' is absent from {manifest}")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def points(raw: list[list[int]]) -> list[tuple[int, int]]:
    return [(int(point[0]), int(point[1])) for point in raw]


def mask_for_polygon(size: tuple[int, int], polygon: list[list[int]]) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon(points(polygon), fill=255)
    return mask


def tiled(source: Image.Image, size: tuple[int, int]) -> Image.Image:
    result = Image.new("RGBA", size, (0, 0, 0, 0))
    source = source.convert("RGBA")
    for y in range(0, size[1], source.height):
        for x in range(0, size[0], source.width):
            result.alpha_composite(source, (x, y))
    return result


def prepare_material_source(material: Image.Image, record: dict, semantic: str) -> Image.Image:
    """Prepare paint separately from deterministic exterior wall framing."""
    metadata_path = record.get("metadata_path")
    if not metadata_path:
        return material
    metadata = read_json(Path(metadata_path))
    prepared = material.convert("RGBA")
    if semantic in {"wall_south", "wall_east"} and metadata.get("exterior_framing_mode") == "perimeter":
        raw_rect = metadata.get("plaster_sample_rect_px")
        if not isinstance(raw_rect, list) or len(raw_rect) != 4:
            raise ValueError(f"material metadata {metadata_path} plaster_sample_rect_px must be [x, y, width, height]")
        x, y, width, height = (int(value) for value in raw_rect)
        if x < 0 or y < 0 or width <= 0 or height <= 0 or x + width > prepared.width or y + height > prepared.height:
            raise ValueError(f"material metadata {metadata_path} plaster_sample_rect_px lies outside the source image")
        prepared = prepared.crop((x, y, x + width, y + height))
    raw_size = metadata.get("tile_size_px")
    if raw_size is None:
        return prepared
    if not isinstance(raw_size, list) or len(raw_size) != 2:
        raise ValueError(f"material metadata {metadata_path} tile_size_px must be [width, height]")
    tile_size = (int(raw_size[0]), int(raw_size[1]))
    if tile_size[0] <= 0 or tile_size[1] <= 0:
        raise ValueError(f"material metadata {metadata_path} tile_size_px must be positive")
    return ImageOps.fit(prepared, tile_size, method=Image.Resampling.LANCZOS)


def uses_perimeter_framing(record: dict, semantic: str) -> bool:
    """Return whether one resolved exterior plane owns structural edge posts."""
    metadata_path = record.get("metadata_path")
    if not metadata_path or semantic not in {"wall_south", "wall_east"}:
        return False
    return read_json(Path(metadata_path)).get("exterior_framing_mode") == "perimeter"


def solve(matrix: list[list[float]], values: list[float]) -> list[float]:
    size = len(values)
    rows = [row[:] + [values[index]] for index, row in enumerate(matrix)]
    for column in range(size):
        pivot = max(range(column, size), key=lambda row: abs(rows[row][column]))
        if abs(rows[pivot][column]) < 1e-10:
            raise ValueError("slot does not define a valid perspective transform")
        rows[column], rows[pivot] = rows[pivot], rows[column]
        divisor = rows[column][column]
        rows[column] = [value / divisor for value in rows[column]]
        for row in range(size):
            if row == column:
                continue
            factor = rows[row][column]
            rows[row] = [rows[row][index] - factor * rows[column][index] for index in range(size + 1)]
    return [rows[index][-1] for index in range(size)]


def perspective_coefficients(destination: list[tuple[float, float]], source: list[tuple[float, float]]) -> tuple[float, ...]:
    matrix: list[list[float]] = []
    values: list[float] = []
    for (x, y), (u, v) in zip(destination, source, strict=True):
        matrix.append([x, y, 1.0, 0.0, 0.0, 0.0, -u * x, -u * y])
        values.append(u)
        matrix.append([0.0, 0.0, 0.0, x, y, 1.0, -v * x, -v * y])
        values.append(v)
    return tuple(solve(matrix, values))


def affine_coefficients(destination: list[tuple[float, float]], source: list[tuple[float, float]]) -> tuple[float, ...]:
    matrix: list[list[float]] = []
    values: list[float] = []
    for (x, y), (u, v) in zip(destination, source, strict=True):
        matrix.append([x, y, 1.0, 0.0, 0.0, 0.0])
        values.append(u)
        matrix.append([0.0, 0.0, 0.0, x, y, 1.0])
        values.append(v)
    return tuple(solve(matrix, values))


def warp_material_triangle(material: Image.Image, polygon: list[list[int]], canvas_size: tuple[int, int]) -> Image.Image:
    if len(polygon) != 3:
        raise ValueError("triangle material mapping requires a three-corner polygon")
    polygon_points = points(polygon)
    width = max(8, round(math.dist(polygon_points[0], polygon_points[1])))
    height = max(8, round(max(math.dist(polygon_points[1], polygon_points[2]), math.dist(polygon_points[2], polygon_points[0]))))
    source_plane = tiled(material, (width, height))
    destination = [(float(x), float(y)) for x, y in polygon_points]
    # Sample slightly inside the opaque material plane. Sampling exactly on
    # its boundary lets bicubic interpolation mix transparent fill into a
    # shared surface edge, which produced the dotted dark gable seam seen in
    # the first live proof.
    inset = float(MATERIAL_EDGE_INSET)
    source = [
        (inset, inset),
        (source_plane.width - 1.0 - inset, inset),
        (source_plane.width - 1.0 - inset, source_plane.height - 1.0 - inset),
    ]
    coefficients = affine_coefficients(destination, source)
    image = source_plane.transform(canvas_size, Image.Transform.AFFINE, coefficients, Image.Resampling.BICUBIC, fillcolor=(0, 0, 0, 0))
    # Surface materials are contractually opaque. Use the exact resolved mask
    # as alpha instead of carrying transform-edge transparency into the final
    # composition.
    image.putalpha(mask_for_polygon(canvas_size, polygon))
    return image


def warp_to_quad(source_image: Image.Image, polygon: list[list[int]], canvas_size: tuple[int, int], trim: bool,
                 edge_inset: int = 0) -> Image.Image:
    if len(polygon) != 4:
        raise ValueError("projective mapping requires a four-corner polygon")
    source_image = source_image.convert("RGBA")
    if trim:
        bbox = source_image.getchannel("A").getbbox()
        if bbox is None:
            raise ValueError("source is fully transparent")
        source_image = source_image.crop(bbox)
    destination = [(float(x), float(y)) for x, y in reversed(points(polygon))]
    inset = float(edge_inset)
    source_points = [
        (inset, inset),
        (source_image.width - 1.0 - inset, inset),
        (source_image.width - 1.0 - inset, source_image.height - 1.0 - inset),
        (inset, source_image.height - 1.0 - inset),
    ]
    coefficients = perspective_coefficients(destination, source_points)
    image = source_image.transform(canvas_size, Image.Transform.PERSPECTIVE, coefficients, Image.Resampling.BICUBIC, fillcolor=(0, 0, 0, 0))
    warped_alpha = source_image.getchannel("A").transform(canvas_size, Image.Transform.PERSPECTIVE, coefficients, Image.Resampling.BICUBIC, fillcolor=0)
    image.putalpha(warped_alpha)
    return image


def warp_module(module: Image.Image, polygon: list[list[int]], canvas_size: tuple[int, int]) -> Image.Image:
    return warp_to_quad(module, polygon, canvas_size, True)


def warp_material(material: Image.Image, polygon: list[list[int]], canvas_size: tuple[int, int]) -> Image.Image:
    if len(polygon) == 3:
        return warp_material_triangle(material, polygon, canvas_size)
    if len(polygon) != 4:
        raise ValueError("surface material requires a three- or four-corner polygon")
    polygon_points = points(polygon)
    width = max(8, round(max(math.dist(polygon_points[0], polygon_points[1]), math.dist(polygon_points[3], polygon_points[2]))))
    height = max(8, round(max(math.dist(polygon_points[0], polygon_points[3]), math.dist(polygon_points[1], polygon_points[2]))))
    source_plane = tiled(material, (width, height))
    warped = warp_to_quad(source_plane, polygon, canvas_size, False, MATERIAL_EDGE_INSET)
    # Clip resampling back to the exact surface; fixture warps receive their
    # separate one-source-pixel tolerance in validation.
    warped.putalpha(ImageChops.multiply(warped.getchannel("A"), mask_for_polygon(canvas_size, polygon)))
    return warped


def synthetic_material(material_id: str) -> Image.Image:
    colors = {
        "whitewash_timber": ((222, 204, 165, 255), (104, 67, 40, 255)),
        "gold_thatch": ((210, 157, 70, 255), (129, 83, 36, 255)),
        "oak_floorboards": ((155, 94, 46, 255), (92, 48, 25, 255)),
    }
    base, line = colors.get(material_id, ((170, 170, 170, 255), (80, 80, 80, 255)))
    image = Image.new("RGBA", (96, 96), base)
    draw = ImageDraw.Draw(image)
    if material_id == "gold_thatch":
        for y in range(-32, 128, 16):
            draw.line((0, y, 96, y + 40), fill=line, width=4)
    else:
        for y in range(0, 96, 24):
            draw.line((0, y, 96, y), fill=line, width=3)
        for x in range(0, 96, 48):
            draw.line((x, 0, x, 96), fill=line, width=2)
    return image


def synthetic_module(module_id: str) -> Image.Image:
    image = Image.new("RGBA", (120, 180), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    if module_id.startswith("window"):
        draw.rectangle((14, 32, 106, 130), fill=(58, 92, 115, 255), outline=(52, 35, 22, 255), width=10)
        draw.line((60, 37, 60, 126), fill=(213, 185, 122, 255), width=6)
        draw.line((19, 80, 101, 80), fill=(213, 185, 122, 255), width=6)
    else:
        draw.rectangle((10, 6, 110, 176), fill=(96, 55, 28, 255), outline=(48, 29, 18, 255), width=10)
        for y in range(26, 170, 28):
            draw.line((16, y, 104, y), fill=(156, 100, 47, 255), width=5)
        draw.ellipse((82, 96, 96, 110), fill=(220, 174, 68, 255))
    return image


def source_file(root: Path, category: str, source_id: str, synthetic: bool, synthetic_root: Path) -> tuple[Image.Image, dict]:
    path = root / category / f"{source_id}.png"
    if path.is_file():
        metadata_path = path.with_suffix(".json")
        if not metadata_path.is_file():
            raise ValueError(f"missing source metadata: {metadata_path}")
        metadata = read_json(metadata_path)
        required = ("backend", "model", "prompt", "license")
        missing = [key for key in required if not str(metadata.get(key, "")).strip()]
        if missing:
            raise ValueError(f"source metadata {metadata_path} is missing: {', '.join(missing)}")
        record = {
            "id": source_id,
            "path": str(path),
            "sha256": sha256(path),
            "metadata_path": str(metadata_path),
            "metadata_sha256": sha256(metadata_path),
            "backend": str(metadata["backend"]),
            "model": str(metadata["model"]),
            "prompt": str(metadata["prompt"]),
            "license": str(metadata["license"]),
            "synthetic": False,
        }
        return Image.open(path).convert("RGBA"), record
    if not synthetic:
        raise ValueError(f"missing source: {path}")
    synthetic_root.mkdir(parents=True, exist_ok=True)
    path = synthetic_root / f"{category}_{source_id}.png"
    image = synthetic_material(source_id) if category == "materials" else synthetic_module(source_id)
    image.save(path)
    return image, {
        "id": source_id,
        "path": str(path),
        "sha256": sha256(path),
        "backend": "synthetic",
        "model": "deterministic_test_fixture",
        "prompt": "geometry-only synthetic source",
        "license": "project-generated test fixture",
        "synthetic": True,
    }


def crop_part(image: Image.Image, anchor: list[int], alignment: int) -> tuple[Image.Image, list[int], list[int]]:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("part is fully transparent")
    # A raised North/West fixture can have its game anchor below or beside all
    # opaque pixels. Preserve a padded transparent margin around that anchor;
    # otherwise a tight crop changes the very placement the rig resolved.
    left = max(0, min(bbox[0] - PAD, anchor[0] - PAD))
    top = max(0, min(bbox[1] - PAD, anchor[1] - PAD))
    right = min(image.width, max(bbox[2] + PAD, anchor[0] + PAD + 1))
    bottom = min(image.height, max(bbox[3] + PAD, anchor[1] + PAD + 1))
    # Align the crop to the rig's integer source scale. This makes both frame
    # dimensions and anchor coordinates divide exactly when the production
    # PNG is baked to runtime resolution; Godot no longer has to place a
    # quarter-pixel anchor while simultaneously filtering a 4x texture.
    alignment = max(1, alignment)
    left = max(0, left - (-(anchor[0] - left)) % alignment)
    top = max(0, top - (-(anchor[1] - top)) % alignment)
    width = right - left
    height = bottom - top
    right += (-width) % alignment
    bottom += (-height) % alignment
    cropped = image.crop((left, top, right, bottom))
    local_anchor = [anchor[0] - left, anchor[1] - top]
    return cropped, local_anchor, [left, top, cropped.width, cropped.height]


def alpha_safe_resize(source: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Lanczos resize in premultiplied-alpha space, returned as straight RGBA.

    Pillow's ordinary RGBA resize blends RGB from fully transparent pixels.
    Generated/chroma-keyed modules commonly store black there, creating a
    dark fringe after reduction. Premultiplication removes that contribution;
    unpremultiplication restores the straight-alpha PNG Godot expects.
    """
    rgba = source.convert("RGBA")
    alpha = rgba.getchannel("A")
    resized_alpha = alpha.resize(size, Image.Resampling.LANCZOS)
    premultiplied = [
        ImageChops.multiply(rgba.getchannel(channel), alpha).resize(size, Image.Resampling.LANCZOS)
        for channel in ("R", "G", "B")
    ]
    alpha_values = list(resized_alpha.get_flattened_data())
    channel_values = [list(channel.get_flattened_data()) for channel in premultiplied]
    pixels: list[tuple[int, int, int, int]] = []
    for index, alpha_value in enumerate(alpha_values):
        if alpha_value <= 0:
            pixels.append((0, 0, 0, 0))
            continue
        pixels.append(tuple(
            min(255, round(channel[index] * 255.0 / alpha_value))
            for channel in channel_values
        ) + (alpha_value,))
    result = Image.new("RGBA", size, (0, 0, 0, 0))
    result.putdata(pixels)
    return result


def material_trim_colors(material: Image.Image) -> tuple[tuple[int, int, int, int], tuple[int, int, int, int]]:
    """Derive a two-tone structural trim from the supplied material itself."""
    sample = material.convert("RGBA").resize((64, 64), Image.Resampling.BOX)
    opaque = [pixel for pixel in sample.get_flattened_data() if pixel[3] >= 240]
    if not opaque:
        return (70, 43, 24, 255), (126, 79, 39, 255)
    opaque.sort(key=lambda pixel: pixel[0] * 0.2126 + pixel[1] * 0.7152 + pixel[2] * 0.0722)
    dark = opaque[max(0, round((len(opaque) - 1) * 0.08))]
    mid = opaque[max(0, round((len(opaque) - 1) * 0.20))]
    return (dark[0], dark[1], dark[2], 255), (mid[0], mid[1], mid[2], 255)


def draw_surface_finishes(image: Image.Image, finishes: list[tuple[list[int], list[int], Image.Image]],
                          surfaces: list[dict], source_scale: int) -> None:
    """Finish exposed gable bases after all planes have been composited."""
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    outer_width = max(2, source_scale * 2)
    inner_width = max(1, source_scale)
    for start, end, material in finishes:
        outer, inner = material_trim_colors(material)
        draw.line((tuple(start), tuple(end)), fill=outer, width=outer_width)
        draw.line((tuple(start), tuple(end)), fill=inner, width=inner_width)
    # A thick seam straddles its shared wall/gable edge by design. Clip the
    # stroke to the union of the resolved surfaces so endpoint caps cannot
    # escape the asset rig's exact alpha envelope.
    clip = Image.new("L", image.size, 0)
    clip_draw = ImageDraw.Draw(clip)
    for surface in surfaces:
        clip_draw.polygon(points(surface["polygon_px"]), fill=255)
    layer.putalpha(ImageChops.multiply(layer.getchannel("A"), clip))
    image.alpha_composite(layer)


def draw_wall_framing(image: Image.Image, frames: list[tuple[str, list[list[int]], Image.Image]],
                      surfaces: list[dict], source_scale: int) -> None:
    """Draw the canonical exterior frame with one shared southeast post."""
    if not frames:
        return
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    edge_records: dict[
        tuple[tuple[int, int], tuple[int, int]],
        tuple[tuple[int, int], tuple[int, int], Image.Image, bool],
    ] = {}
    for semantic, polygon, material in frames:
        polygon_points = points(polygon)
        edges = [
            (polygon_points[0], polygon_points[1], False),
            (polygon_points[1], polygon_points[2], True),
            (polygon_points[2], polygon_points[3], False),
        ]
        # The East face's final edge is its rear/northeast boundary. It keeps
        # the enclosing roof/wall contour, but no vertical accent post: the
        # only visible East-face support belongs at the shared southeast
        # corner. The South face retains its opposite corner support.
        if semantic == "wall_south":
            edges.append((polygon_points[3], polygon_points[0], False))
        for start, end, is_southeast in edges:
            key = tuple(sorted((start, end)))
            existing = edge_records.get(key)
            if existing is None or (is_southeast and not existing[3]):
                edge_records[key] = (start, end, material, is_southeast)
    for start, end, material, is_southeast in edge_records.values():
        outer, inner = material_trim_colors(material)
        outer_width = source_scale * (5 if is_southeast else 3)
        inner_width = source_scale * (3 if is_southeast else 2)
        draw.line((start, end), fill=outer, width=max(3, outer_width))
        draw.line((start, end), fill=inner, width=max(1, inner_width))
    # The two wall quads resolve the southeast support to the same edge. The
    # keyed records above draw it once, and this union mask keeps every stroke
    # inside the exact building envelope.
    clip = Image.new("L", image.size, 0)
    clip_draw = ImageDraw.Draw(clip)
    for surface in surfaces:
        if str(surface.get("semantic", "")) in {"wall_south", "wall_east"}:
            clip_draw.polygon(points(surface["polygon_px"]), fill=255)
    layer.putalpha(ImageChops.multiply(layer.getchannel("A"), clip))
    image.alpha_composite(layer)


def draw_roof_finishes(image: Image.Image, finishes: list[tuple[list[int], list[int], Image.Image]],
                       surfaces: list[dict], source_scale: int) -> None:
    """Draw one clean structural ridge over the repeated roof material."""
    if not finishes:
        return
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    seen: set[tuple[int, int, int, int]] = set()
    for start, end, material in finishes:
        key = (int(start[0]), int(start[1]), int(end[0]), int(end[1]))
        if key in seen:
            continue
        seen.add(key)
        outer, inner = material_trim_colors(material)
        draw.line((tuple(start), tuple(end)), fill=outer, width=max(3, source_scale * 3))
        draw.line((tuple(start), tuple(end)), fill=inner, width=max(1, source_scale))
    clip = Image.new("L", image.size, 0)
    clip_draw = ImageDraw.Draw(clip)
    for surface in surfaces:
        if str(surface.get("semantic", "")) == "roof":
            clip_draw.polygon(points(surface["polygon_px"]), fill=255)
    layer.putalpha(ImageChops.multiply(layer.getchannel("A"), clip))
    image.alpha_composite(layer)


def draw_synthetic_well(canvas: Image.Image, slot: dict) -> None:
    draw = ImageDraw.Draw(canvas)
    center = slot["contact_center_px"]
    size = slot["contact_size_px"]
    cx, cy = int(center[0]), int(center[1])
    rx, ry = int(size[0] / 2), int(size[1] / 2)
    draw.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=(93, 91, 79, 255), outline=(44, 41, 35, 255), width=8)
    draw.ellipse((cx - rx + 16, cy - ry + 10, cx + rx - 16, cy + ry - 10), fill=(48, 97, 126, 255), outline=(42, 39, 33, 255), width=5)
    draw.rectangle((cx - rx + 14, cy - ry - 88, cx - rx + 30, cy - ry + 6), fill=(77, 48, 27, 255))
    draw.rectangle((cx + rx - 30, cy - ry - 88, cx + rx - 14, cy - ry + 6), fill=(77, 48, 27, 255))
    draw.line((cx - rx + 8, cy - ry - 88, cx + rx - 8, cy - ry - 88), fill=(109, 67, 34, 255), width=12)


def place_prop(canvas: Image.Image, source: Image.Image, slot: dict, metadata: dict) -> None:
    raw_contact = metadata.get("contact_bbox_px", [])
    if not isinstance(raw_contact, list) or len(raw_contact) != 4:
        raise ValueError("prop metadata requires contact_bbox_px [x, y, width, height]")
    contact_x, contact_y, contact_w, contact_h = (float(value) for value in raw_contact)
    if contact_x < 0 or contact_y < 0 or contact_w <= 0 or contact_h <= 0 or contact_x + contact_w > source.width or contact_y + contact_h > source.height:
        raise ValueError("prop contact_bbox_px lies outside the source image")
    center = slot["contact_center_px"]
    size = slot["contact_size_px"]
    scale = min(float(size[0]) / contact_w, float(size[1]) / contact_h)
    width = max(1, round(source.width * scale))
    height = max(1, round(source.height * scale))
    resized = source.resize((width, height), Image.Resampling.LANCZOS)
    source_contact_cx = (contact_x + contact_w / 2.0) * scale
    source_contact_cy = (contact_y + contact_h / 2.0) * scale
    left = round(float(center[0]) - source_contact_cx)
    top = round(float(center[1]) - source_contact_cy)
    canvas.alpha_composite(resized, (left, top))


def compose(asset: dict, source_root: Path, out_dir: Path, synthetic: bool, manifest_path: Path) -> dict:
    canvas_size = tuple(asset["canvas_size_px"])
    source_records: list[dict] = []
    outputs: list[dict] = []
    out_dir.mkdir(parents=True, exist_ok=True)
    synthetic_root = out_dir / "_synthetic_sources"
    surfaces_by_part: dict[str, list[dict]] = {}
    slots_by_part: dict[str, list[dict]] = {}
    for surface in asset["surfaces"]:
        surfaces_by_part.setdefault(surface["part"], []).append(surface)
    for slot in asset["slots"]:
        slots_by_part.setdefault(slot["part"], []).append(slot)
    for part in asset["parts"]:
        image = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
        part_id = part["id"]
        surface_finishes: list[tuple[list[int], list[int], Image.Image]] = []
        wall_frames: list[tuple[str, list[list[int]], Image.Image]] = []
        roof_finishes: list[tuple[list[int], list[int], Image.Image]] = []
        for surface in surfaces_by_part.get(part_id, []):
            if not surface["material"]:
                continue
            raw_material, record = source_file(source_root, "materials", surface["material"], synthetic, synthetic_root)
            source_records.append(record)
            semantic = str(surface.get("semantic", ""))
            material = prepare_material_source(raw_material, record, semantic)
            image.alpha_composite(warp_material(material, surface["polygon_px"], canvas_size))
            if len(surface["polygon_px"]) == 3 and semantic.startswith("wall"):
                surface_finishes.append((surface["polygon_px"][0], surface["polygon_px"][1], raw_material))
            if len(surface["polygon_px"]) == 4 and uses_perimeter_framing(record, semantic):
                wall_frames.append((semantic, surface["polygon_px"], raw_material))
            if len(surface["polygon_px"]) == 4 and semantic == "roof":
                roof_finishes.append((surface["polygon_px"][2], surface["polygon_px"][3], raw_material))
        draw_surface_finishes(
            image,
            surface_finishes,
            surfaces_by_part.get(part_id, []),
            int(asset["source_scale"]),
        )
        draw_wall_framing(
            image,
            wall_frames,
            surfaces_by_part.get(part_id, []),
            int(asset["source_scale"]),
        )
        draw_roof_finishes(
            image,
            roof_finishes,
            surfaces_by_part.get(part_id, []),
            int(asset["source_scale"]),
        )
        for slot in slots_by_part.get(part_id, []):
            if slot["kind"] == "contact":
                if synthetic:
                    draw_synthetic_well(image, slot)
                else:
                    prop, record = source_file(source_root, "props", asset["id"], False, synthetic_root)
                    source_records.append(record)
                    place_prop(image, prop, slot, read_json(Path(record["metadata_path"])))
                continue
            module, record = source_file(source_root, "modules", slot["module"], synthetic, synthetic_root)
            source_records.append(record)
            image.alpha_composite(warp_module(module, slot["polygon_px"], canvas_size))
        source_scale = int(asset["source_scale"])
        cropped, anchor, crop = crop_part(image, part["anchor_px"], source_scale)
        safe_name = part_id.replace(":", "_")
        filename = f"{safe_name}.png"
        source_path = out_dir / filename
        cropped.save(source_path)
        runtime_filename = f"{safe_name}_runtime.png"
        runtime = alpha_safe_resize(cropped, (cropped.width // source_scale, cropped.height // source_scale))
        runtime_path = out_dir / runtime_filename
        runtime.save(runtime_path)
        outputs.append({
            "part": part_id,
            "file": filename,
            "frame_w": cropped.width,
            "frame_h": cropped.height,
            "anchor_x": anchor[0],
            "anchor_y": anchor[1],
            "crop_rect_px": crop,
            "draw_scale": asset["runtime"]["draw_scale"],
            "sha256": sha256(source_path),
            "runtime_file": runtime_filename,
            "runtime_frame_w": runtime.width,
            "runtime_frame_h": runtime.height,
            "runtime_anchor_x": anchor[0] // source_scale,
            "runtime_anchor_y": anchor[1] // source_scale,
            "runtime_draw_scale": 1.0,
            "runtime_sha256": sha256(runtime_path),
        })
    asset_hash = hashlib.sha256(json.dumps(asset, sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest()
    recipe = {
        "version": 2,
        "asset_id": asset["id"],
        "kind": asset["kind"],
        "resolved_manifest_path": str(manifest_path),
        "resolved_manifest_sha256": sha256(manifest_path),
        "resolved_asset_sha256": asset_hash,
        "resolved_rig": asset,
        "outputs": outputs,
        "sources": source_records,
    }
    (out_dir / "recipe.json").write_text(json.dumps(recipe, indent=2) + "\n", encoding="utf-8")
    return recipe


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--asset", required=True)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--source-root", type=Path, default=HERE / "sources_v2")
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--synthetic", action="store_true")
    args = parser.parse_args()
    try:
        recipe = compose(find_asset(read_json(args.manifest), args.asset), args.source_root, args.out_dir, args.synthetic, args.manifest)
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}")
        return 2
    print(f"Composed {recipe['asset_id']} into {args.out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
