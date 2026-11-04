"""Create a checkerboard-and-geometry review sheet for a v2 candidate."""

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw


CHECK_A = (224, 224, 224, 255)
CHECK_B = (188, 188, 188, 255)
GUIDE = (244, 194, 59, 255)
PANEL_BG = (35, 40, 47, 255)


def checker(size: tuple[int, int], step: int = 16) -> Image.Image:
    image = Image.new("RGBA", size, CHECK_A)
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], step):
        for x in range(0, size[0], step):
            if (x // step + y // step) % 2:
                draw.rectangle((x, y, x + step - 1, y + step - 1), fill=CHECK_B)
    return image


def polygons(asset: dict, part: str, crop: list[int]) -> list[list[tuple[int, int]]]:
    result: list[list[tuple[int, int]]] = []
    for group_index, group in enumerate((asset["surfaces"], asset["slots"])):
        for item in group:
            if item["part"] != part:
                continue
            if group_index == 1 and item.get("kind") == "contact":
                continue
            if "polygon_px" in item:
                result.append([(point[0] - crop[0], point[1] - crop[1]) for point in item["polygon_px"]])
    return result


def panel(image: Image.Image, asset: dict, output: dict, overlay: bool) -> Image.Image:
    result = checker(image.size)
    result.alpha_composite(image)
    if overlay:
        draw = ImageDraw.Draw(result)
        for polygon in polygons(asset, output["part"], output["crop_rect_px"]):
            draw.line(polygon + [polygon[0]], fill=GUIDE, width=3)
        for slot in asset["slots"]:
            if slot["part"] != output["part"] or slot.get("kind") != "contact":
                continue
            center = slot["contact_center_px"]
            size = slot["contact_size_px"]
            crop = output["crop_rect_px"]
            cx, cy = center[0] - crop[0], center[1] - crop[1]
            rx, ry = size[0] / 2, size[1] / 2
            draw.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), outline=(84, 197, 169, 255), width=3)
        draw.ellipse((output["anchor_x"] - 4, output["anchor_y"] - 4, output["anchor_x"] + 4, output["anchor_y"] + 4), fill=(255, 255, 255, 255), outline=(20, 20, 20, 255), width=2)
    return result


def runtime_panel(runtime_image: Image.Image, asset: dict, output: dict) -> Image.Image:
    """Show the candidate at its real runtime scale; props also show one tile."""
    width, height = 280, 210
    result = Image.new("RGBA", (width, height), PANEL_BG)
    draw = ImageDraw.Draw(result)
    scale = float(output["draw_scale"])
    rendered = runtime_image
    root = (width // 2, 156)
    part_anchor = next(part["anchor_px"] for part in asset["parts"] if part["id"] == output["part"])
    ground = [
        (root[0] + round((point[0] - part_anchor[0]) * scale), root[1] + round((point[1] - part_anchor[1]) * scale))
        for point in asset["ground_polygon_px"]
    ]
    contact_ellipse: tuple[int, int, int, int] | None = None
    if asset["kind"] == "freestanding_prop":
        for slot in asset["slots"]:
            if slot.get("kind") != "contact":
                continue
            contact = slot["contact_center_px"]
            cx = root[0] + round((contact[0] - part_anchor[0]) * scale)
            cy = root[1] + round((contact[1] - part_anchor[1]) * scale)
            rx = round(slot["contact_size_px"][0] * scale / 2)
            ry = round(slot["contact_size_px"][1] * scale / 2)
            contact_ellipse = (cx - rx, cy - ry, cx + rx, cy + ry)
    left = root[0] - int(output["runtime_anchor_x"])
    top = root[1] - int(output["runtime_anchor_y"])
    result.alpha_composite(rendered, (left, top))
    draw.line(ground + [ground[0]], fill=(118, 161, 178, 255), width=2)
    if contact_ellipse is not None:
        draw.ellipse(contact_ellipse, outline=(84, 197, 169, 255), width=2)
    envelope = asset.get("alpha_envelope_rect_px", [])
    if asset["kind"] == "freestanding_prop" and isinstance(envelope, list) and len(envelope) == 4:
        envelope_left = root[0] + round((envelope[0] - part_anchor[0]) * scale)
        envelope_top = root[1] + round((envelope[1] - part_anchor[1]) * scale)
        envelope_right = envelope_left + round(envelope[2] * scale)
        envelope_bottom = envelope_top + round(envelope[3] * scale)
        draw.rectangle((envelope_left, envelope_top, envelope_right, envelope_bottom), outline=(211, 109, 214, 255), width=2)
    draw.ellipse((root[0] - 3, root[1] - 3, root[0] + 3, root[1] + 3), fill=(255, 255, 255, 255), outline=(20, 20, 20, 255), width=1)
    draw.text((8, 8), "actual runtime scale", fill=(245, 245, 245, 255))
    if asset["kind"] == "freestanding_prop":
        draw.text((8, 26), "blue: tile / green: ground contact", fill=(180, 208, 218, 255))
        draw.text((8, 44), "white: sort / magenta: max alpha", fill=(221, 166, 223, 255))
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate", type=Path)
    args = parser.parse_args()
    recipe = json.loads((args.candidate / "recipe.json").read_text(encoding="utf-8"))
    asset = recipe["resolved_rig"]
    rows: list[tuple[dict, Image.Image, Image.Image, Image.Image]] = []
    for output in recipe["outputs"]:
        image = Image.open(args.candidate / output["file"]).convert("RGBA")
        runtime_image = Image.open(args.candidate / output["runtime_file"]).convert("RGBA")
        rows.append((output, panel(image, asset, output, False), panel(image, asset, output, True),
                     runtime_panel(runtime_image, asset, output)))
    width = max(left.width + right.width + runtime.width for _, left, right, runtime in rows) + 52
    height = sum(max(left.height, right.height, runtime.height) + 34 for _, left, right, runtime in rows) + 20
    sheet = Image.new("RGBA", (width, height), PANEL_BG)
    draw = ImageDraw.Draw(sheet)
    y = 12
    for output, left, right, runtime in rows:
        draw.text((12, y), f"{output['part']}  |  source crop / exact rig overlay / in-game scale", fill=(245, 245, 245, 255))
        y += 20
        sheet.alpha_composite(left, (12, y))
        sheet.alpha_composite(right, (24 + left.width, y))
        sheet.alpha_composite(runtime, (36 + left.width + right.width, y))
        y += max(left.height, right.height, runtime.height) + 14
    path = args.candidate / "review.png"
    sheet.save(path)
    print(f"Wrote {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
