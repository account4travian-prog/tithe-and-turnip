
"""Regression checks for the generated v2 golden-proof rig manifest."""

import json
from pathlib import Path


MANIFEST = Path(__file__).resolve().parent / "rigs_v2" / "resolved_rig_manifest.json"


def area(polygon: list[list[int]]) -> int:
    return abs(sum(a[0] * b[1] - a[1] * b[0] for a, b in zip(polygon, polygon[1:] + polygon[:1])))


def check(condition: bool, message: str, failures: list[str]) -> None:
    if not condition:
        failures.append(message)


def main() -> int:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    failures: list[str] = []
    check(data["version"] == 2, "manifest version is 2", failures)
    check(data["projection_source"] == "res://scripts/globals/iso_projection.gd", "manifest uses IsoProjection", failures)
    assets = {asset["id"]: asset for asset in data["assets"]}
    check(set(assets) == {"farmhouse", "farmhouse_wide", "player_home_interior", "well"},
        "golden proof assets are complete", failures)
    house = assets["farmhouse"]
    check(house["runtime"]["footprint_cells"] == [3, 2], "farmhouse remains 3x2", failures)
    check({slot["face"] for slot in house["slots"]} == {"south", "east"}, "farmhouse slots use South/East faces", failures)
    for surface in house["surfaces"]:
        check(area(surface["polygon_px"]) > 0, f"farmhouse surface is nondegenerate: {surface['id']}", failures)
    check(any(surface["id"] == "main_roof.east_gable" and len(surface["polygon_px"]) == 3 for surface in house["surfaces"]),
        "farmhouse gable end is an explicit opaque triangle", failures)
    wide_house = assets["farmhouse_wide"]
    check(wide_house["runtime"]["footprint_cells"] == [4, 3], "wide farmhouse is 4x3 with added North-South depth", failures)
    check({slot["face"] for slot in wide_house["slots"]} == {"south", "east"},
        "wide farmhouse slots use South/East faces", failures)
    for surface in wide_house["surfaces"]:
        check(area(surface["polygon_px"]) > 0, f"wide farmhouse surface is nondegenerate: {surface['id']}", failures)
    interior = assets["player_home_interior"]
    check(interior["runtime"]["footprint_cells"] == [10, 7], "interior remains 10x7", failures)
    parts = {part["id"]: part for part in interior["parts"]}
    check(parts["shell"]["anchor_origin"] == "room_origin", "shell anchors at room origin", failures)
    check(parts["fixture:door_south"]["anchor_origin"] == "fixture_perimeter", "door has perimeter anchor", failures)
    check(parts["fixture:window_north"]["anchor_origin"] == "fixture_perimeter", "window has perimeter anchor", failures)
    check({slot["face"] for slot in interior["slots"]} == {"south", "north"}, "interior uses South door/North window", failures)
    well = assets["well"]
    check(well["runtime"]["footprint_cells"] == [1, 1], "well remains 1x1", failures)
    check(len(well.get("alpha_envelope_rect_px", [])) == 4, "well has a resolved alpha envelope", failures)
    contact = well["slots"][0]
    check(contact["kind"] == "contact" and len(contact["polygon_px"]) == 4, "well retains contact diamond", failures)
    anchor = well["parts"][0]["anchor_px"]
    check(contact["contact_center_px"][0] - anchor[0] == 0, "well contact stays horizontally centred on its tile", failures)
    check(contact["contact_center_px"][1] - anchor[1] == -96, "well contact is one half-tile above the near anchor at source scale", failures)
    for failure in failures:
        print(f"FAIL: {failure}")
    print(f"asset rig: {len(failures)} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())


