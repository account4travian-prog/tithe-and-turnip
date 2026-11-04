
extends SceneTree

## Offline v2 dimetric-rig resolver. Godot is the only process that converts
## grid coordinates into source pixels: Python composition consumes this
## manifest verbatim and never reproduces the projection formula.

const IsoProjectionRef := preload("res://scripts/globals/iso_projection.gd")

const CATALOG_PATH := "res://asset_studio/asset_rig_catalog_v2.json"
const DEFAULT_OUTPUT_DIR := "res://asset_studio/rigs_v2"
const PADDING_PX := 64

const GUIDE_COLORS := {
	"floor": "#4e7088",
	"wall_south": "#db7640",
	"wall_east": "#4394db",
	"wall_north": "#b972ca",
	"wall_west": "#7eb06a",
	"roof": "#a658bf",
	"slot": "#f2c13b",
	"contact": "#54c5a9",
}


func _initialize() -> void:
	var output_dir := DEFAULT_OUTPUT_DIR
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--out":
		output_dir = args[1]
	elif not args.is_empty():
		printerr("Usage: godot --headless --path . --script asset_studio/generate_asset_rigs.gd -- [--out res://asset_studio/rigs_v2]")
		quit(2)
		return
	var catalog := _load_catalog()
	var errors := _validate_catalog(catalog)
	if not errors.is_empty():
		for error_text: String in errors:
			printerr("CATALOG ERROR: %s" % error_text)
		quit(1)
		return
	var absolute_output := ProjectSettings.globalize_path(output_dir)
	if DirAccess.make_dir_recursive_absolute(absolute_output) != OK:
		printerr("Could not create output directory: %s" % absolute_output)
		quit(1)
		return
	var output := {
		"version": 2,
		"catalog_version": int(catalog.get("version", 0)),
		"projection_source": str(catalog.get("projection_source", "")),
		"source_scale": int(catalog.get("source_scale", 0)),
		"assets": [],
	}
	for item: Variant in catalog.get("assets", []):
		var resolved := _resolve_asset(item as Dictionary, int(catalog.get("source_scale", 4)))
		(output["assets"] as Array).append(resolved)
		_write_svg_guide(resolved, absolute_output)
	var manifest_path := absolute_output.path_join("resolved_rig_manifest.json")
	var manifest_file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest_file == null:
		printerr("Could not write manifest: %s" % manifest_path)
		quit(1)
		return
	manifest_file.store_string(JSON.stringify(output, "\t") + "\n")
	manifest_file.close()
	print("Resolved %d v2 rigs in %s" % [(output["assets"] as Array).size(), absolute_output])
	quit(0)


func _load_catalog() -> Dictionary:
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {}


func _validate_catalog(catalog: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if int(catalog.get("version", 0)) != 2:
		errors.append("catalog version must be 2")
	if str(catalog.get("projection_source", "")) != "res://scripts/globals/iso_projection.gd":
		errors.append("projection_source must name IsoProjection")
	var source_scale := int(catalog.get("source_scale", 0))
	if source_scale <= 0:
		errors.append("source_scale must be positive")
	var material_ids: Dictionary = {}
	for item: Variant in catalog.get("materials", []):
		var material := item as Dictionary
		var material_id := str(material.get("id", ""))
		if material_id.is_empty() or material_ids.has(material_id):
			errors.append("material id is missing or duplicated: %s" % material_id)
		material_ids[material_id] = true
	var module_ids: Dictionary = {}
	for item: Variant in catalog.get("modules", []):
		var module := item as Dictionary
		var module_id := str(module.get("id", ""))
		if module_id.is_empty() or module_ids.has(module_id):
			errors.append("module id is missing or duplicated: %s" % module_id)
		if str(module.get("source_orientation", "")) != "flat_front":
			errors.append("module %s must be flat_front" % module_id)
		module_ids[module_id] = true
	var asset_ids: Dictionary = {}
	for item: Variant in catalog.get("assets", []):
		var asset := item as Dictionary
		var asset_id := str(asset.get("id", ""))
		if asset_id.is_empty() or asset_ids.has(asset_id):
			errors.append("asset id is missing or duplicated: %s" % asset_id)
		asset_ids[asset_id] = true
		match str(asset.get("kind", "")):
			"structure":
				_validate_structure(asset, material_ids, module_ids, errors)
			"interior":
				_validate_interior(asset, material_ids, module_ids, errors)
			"freestanding_prop":
				_validate_prop(asset, errors)
			_:
				errors.append("asset %s has unknown kind" % asset_id)
	return errors


func _validate_cells(raw: Variant, label: String, errors: PackedStringArray) -> void:
	var cells: Array = raw as Array
	if cells.size() != 2 or int(cells[0]) <= 0 or int(cells[1]) <= 0:
		errors.append("%s must be two positive integers" % label)


func _validate_rect(raw: Variant, label: String, errors: PackedStringArray) -> void:
	var rect: Array = raw as Array
	if rect.size() != 4 or float(rect[0]) < 0.0 or float(rect[1]) < 0.0 or int(rect[2]) <= 0 or int(rect[3]) <= 0:
		errors.append("%s must be [nonnegative x, nonnegative y, positive width, positive height]" % label)


func _validate_positive_pair(raw: Variant, label: String, errors: PackedStringArray) -> void:
	var pair: Array = raw as Array
	if pair.size() != 2 or float(pair[0]) <= 0.0 or float(pair[1]) <= 0.0:
		errors.append("%s must contain two positive values" % label)


func _validate_structure(asset: Dictionary, material_ids: Dictionary, module_ids: Dictionary, errors: PackedStringArray) -> void:
	var asset_id := str(asset.get("id", ""))
	_validate_cells(asset.get("footprint_cells", []), "%s footprint_cells" % asset_id, errors)
	var entrance_side := str(asset.get("entrance_side", ""))
	if entrance_side != "south" and entrance_side != "east" and entrance_side != "none":
		errors.append("%s has invalid entrance_side" % asset_id)
	var body_ids: Dictionary = {}
	for item: Variant in asset.get("components", []):
		var component := item as Dictionary
		var component_id := str(component.get("id", ""))
		if component_id.is_empty() or body_ids.has(component_id):
			errors.append("%s has missing or duplicate component id" % asset_id)
		body_ids[component_id] = true
		if str(component.get("kind", "")) == "prism":
			_validate_rect(component.get("footprint_rect_cells", []), "%s prism rect" % component_id, errors)
			if float(component.get("wall_height_tiles", 0.0)) <= 0.0:
				errors.append("%s prism must have positive wall height" % component_id)
			for material_key: String in ["south_material", "east_material"]:
				if not material_ids.has(str(component.get(material_key, ""))):
					errors.append("%s references unknown %s" % [component_id, material_key])
		elif str(component.get("kind", "")) == "gable_roof":
			if not body_ids.has(str(component.get("body_id", ""))):
				errors.append("%s roof must follow its body" % component_id)
			if not material_ids.has(str(component.get("material", ""))):
				errors.append("%s roof references unknown material" % component_id)
			if float(component.get("rise_tiles", 0.0)) <= 0.0 or float(component.get("rise_tiles", 0.0)) >= 0.95:
				errors.append("%s roof rise must be greater than 0 and below 0.95 tile heights" % component_id)
			var overhang: Array = component.get("overhang_cells", [0.0, 0.0]) as Array
			if overhang.size() != 2:
				errors.append("%s roof overhang_cells must contain end and eave values" % component_id)
			elif float(overhang[0]) < 0.0 or float(overhang[0]) > 0.5 \
					or float(overhang[1]) < 0.0 or float(overhang[1]) > 0.5:
				errors.append("%s roof overhang values must stay within 0..0.5 cells" % component_id)
		else:
			errors.append("%s has unknown component kind" % component_id)
	var primary_count := 0
	for item: Variant in asset.get("slots", []):
		var slot := item as Dictionary
		var module_id := str(slot.get("module", ""))
		if not module_ids.has(module_id):
			errors.append("%s slot references unknown module %s" % [asset_id, module_id])
		var surface := str(slot.get("surface", ""))
		if not surface.ends_with(".south") and not surface.ends_with(".east"):
			errors.append("%s slot surface must be south/east" % asset_id)
		if float(slot.get("u_center", -1.0)) < 0.0 or float(slot.get("u_center", 2.0)) > 1.0:
			errors.append("%s slot u_center outside 0..1" % asset_id)
		if float(slot.get("width_cells", 0.0)) <= 0.0 or float(slot.get("height_ratio", 0.0)) <= 0.0:
			errors.append("%s slot size must be positive" % asset_id)
		if str(slot.get("id", "")) == "door_primary" or str(slot.get("id", "")) == "gate_primary":
			primary_count += 1
			if not surface.ends_with("." + entrance_side):
				errors.append("%s primary entry must target entrance_side" % asset_id)
	if entrance_side != "none" and primary_count != 1:
		errors.append("%s must have exactly one primary entry" % asset_id)


func _validate_interior(asset: Dictionary, material_ids: Dictionary, module_ids: Dictionary, errors: PackedStringArray) -> void:
	var asset_id := str(asset.get("id", ""))
	_validate_cells(asset.get("room_cells", []), "%s room_cells" % asset_id, errors)
	if asset.get("visible_wall_sides", []) != ["north", "west"]:
		errors.append("%s must expose North then West walls" % asset_id)
	if asset.get("cutaway_sides", []) != ["south", "east"]:
		errors.append("%s must cut away South then East walls" % asset_id)
	if not material_ids.has(str(asset.get("floor_material", ""))) or not material_ids.has(str(asset.get("wall_material", ""))):
		errors.append("%s references unknown interior material" % asset_id)
	for item: Variant in asset.get("fixtures", []):
		var fixture := item as Dictionary
		var side := str(fixture.get("side", ""))
		if side != "north" and side != "south" and side != "east" and side != "west":
			errors.append("%s has invalid fixture side" % asset_id)
		if not module_ids.has(str(fixture.get("module", ""))):
			errors.append("%s fixture references unknown module" % asset_id)
		if float(fixture.get("span_cells", 0.0)) <= 0.0 or float(fixture.get("height_ratio", 0.0)) <= 0.0:
			errors.append("%s fixture size must be positive" % asset_id)


func _validate_prop(asset: Dictionary, errors: PackedStringArray) -> void:
	_validate_cells(asset.get("footprint_cells", []), "%s footprint_cells" % str(asset.get("id", "")), errors)
	var contact: Dictionary = asset.get("contact_region", {}) as Dictionary
	if str(contact.get("kind", "")) != "ellipse":
		errors.append("prop %s contact_region must be ellipse" % str(asset.get("id", "")))
	_validate_positive_pair(contact.get("size_cells", []), "prop contact size_cells", errors)
	if float(asset.get("max_height_tiles", 0.0)) <= 0.0:
		errors.append("prop %s max_height_tiles must be positive" % str(asset.get("id", "")))
	var overhang: Array = asset.get("max_overhang_cells", []) as Array
	if overhang.size() != 4:
		errors.append("prop %s max_overhang_cells must contain north/east/south/west" % str(asset.get("id", "")))
	else:
		for value: Variant in overhang:
			if float(value) < 0.0:
				errors.append("prop %s max_overhang_cells cannot be negative" % str(asset.get("id", "")))


func _resolve_asset(asset: Dictionary, source_scale: int) -> Dictionary:
	match str(asset.get("kind", "")):
		"structure":
			return _resolve_structure(asset, source_scale)
		"interior":
			return _resolve_interior(asset, source_scale)
		_:
			return _resolve_prop(asset, source_scale)


func _resolve_structure(asset: Dictionary, source_scale: int) -> Dictionary:
	var footprint := _cells(asset.get("footprint_cells", []))
	var surfaces: Array = []
	var slots: Array = []
	var bodies: Dictionary = {}
	for item: Variant in asset.get("components", []):
		var component := item as Dictionary
		if str(component.get("kind", "")) != "prism":
			continue
		var rect_origin := component.get("footprint_rect_cells", []) as Array
		var rect := Vector2i(int(rect_origin[2]), int(rect_origin[3]))
		var origin := Vector2(float(rect_origin[0]), float(rect_origin[1]))
		var base := _footprint_points(origin, rect, footprint, source_scale)
		var up := Vector2(0.0, -float(component.get("wall_height_tiles", 1.0)) * IsoProjectionRef.TILE_H * source_scale)
		var body_id := str(component.get("id", ""))
		bodies[body_id] = {
			"base": base,
			"up": up,
			"east_material": str(component.get("east_material", "")),
		}
		surfaces.append(_surface_record("%s.south" % body_id, "wall_south", str(component.get("south_material", "")), [base[3], base[2], base[2] + up, base[3] + up], "final"))
		surfaces.append(_surface_record("%s.east" % body_id, "wall_east", str(component.get("east_material", "")), [base[1], base[2], base[2] + up, base[1] + up], "final"))
	for item: Variant in asset.get("components", []):
		var component := item as Dictionary
		var component_kind := str(component.get("kind", ""))
		if component_kind == "prism":
			continue
		var body: Dictionary = bodies.get(str(component.get("body_id", "")), {}) as Dictionary
		var roof_surfaces := _roof_surfaces(component, body, source_scale)
		for roof_surface: Dictionary in roof_surfaces:
			surfaces.append(roof_surface)
	for item: Variant in asset.get("slots", []):
		var slot := item as Dictionary
		var surface_name := str(slot.get("surface", ""))
		var split := surface_name.split(".")
		var body: Dictionary = bodies.get(str(split[0]), {}) as Dictionary
		var face := str(split[1])
		slots.append(_structure_slot(slot, body, face, footprint, source_scale, "final"))
	var ground := _footprint_points(Vector2.ZERO, footprint, footprint, source_scale)
	return _finalize_resolved(asset, source_scale, surfaces, slots, [{"id": "final", "anchor_origin": "footprint_end", "anchor_point": Vector2.ZERO}], ground)


func _resolve_interior(asset: Dictionary, source_scale: int) -> Dictionary:
	var room := _cells(asset.get("room_cells", []))
	var floor: Array[Vector2] = [
		_grid_px(Vector2.ZERO, source_scale), _grid_px(Vector2(room.x, 0.0), source_scale),
		_grid_px(Vector2(room.x, room.y), source_scale), _grid_px(Vector2(0.0, room.y), source_scale)
	]
	var up := Vector2(0.0, -float(asset.get("wall_height_tiles", 1.0)) * IsoProjectionRef.TILE_H * source_scale)
	var surfaces: Array = [
		_surface_record("floor", "floor", str(asset.get("floor_material", "")), floor, "shell"),
		_surface_record("north", "wall_north", str(asset.get("wall_material", "")), [floor[0], floor[1], floor[1] + up, floor[0] + up], "shell"),
		_surface_record("west", "wall_west", str(asset.get("wall_material", "")), [floor[3], floor[0], floor[0] + up, floor[3] + up], "shell"),
	]
	var slots: Array = []
	var parts: Array = [{"id": "shell", "anchor_origin": "room_origin", "anchor_point": Vector2.ZERO}]
	for item: Variant in asset.get("fixtures", []):
		var fixture := item as Dictionary
		var anchor_grid := _interior_fixture_grid(str(fixture.get("side", "")), int(fixture.get("index", 0)), room)
		var part_id := "fixture:%s" % str(fixture.get("id", ""))
		parts.append({"id": part_id, "anchor_origin": "fixture_perimeter", "anchor_point": _grid_px(anchor_grid, source_scale)})
		slots.append(_interior_slot(fixture, room, up, source_scale, part_id))
	return _finalize_resolved(asset, source_scale, surfaces, slots, parts, floor)


func _resolve_prop(asset: Dictionary, source_scale: int) -> Dictionary:
	var footprint := _cells(asset.get("footprint_cells", []))
	var base := _footprint_points(Vector2.ZERO, footprint, footprint, source_scale)
	var contact: Dictionary = asset.get("contact_region", {}) as Dictionary
	var center: Array = contact.get("center", []) as Array
	var contact_center := _grid_px(Vector2(float(center[0]), float(center[1])), source_scale) - _grid_px(Vector2(float(footprint.x), float(footprint.y)), source_scale)
	var size: Array = contact.get("size_cells", []) as Array
	var contact_size := [float(size[0]) * IsoProjectionRef.TILE_W * source_scale, float(size[1]) * IsoProjectionRef.TILE_H * source_scale]
	var surfaces: Array = [_surface_record("tile", "floor", "", base, "final")]
	var slots: Array = [{"id": "contact", "kind": "contact", "_points": base, "_contact_center": contact_center, "contact_size_px": contact_size, "part": "final"}]
	var overhang: Array = asset.get("max_overhang_cells", []) as Array
	var anchor_grid := Vector2(float(footprint.x), float(footprint.y))
	var expanded_origin := Vector2(-float(overhang[3]), -float(overhang[0]))
	var expanded_end := Vector2(float(footprint.x) + float(overhang[1]), float(footprint.y) + float(overhang[2]))
	var expanded_ground: Array[Vector2] = [
		_grid_px(expanded_origin, source_scale) - _grid_px(anchor_grid, source_scale),
		_grid_px(Vector2(expanded_end.x, expanded_origin.y), source_scale) - _grid_px(anchor_grid, source_scale),
		_grid_px(expanded_end, source_scale) - _grid_px(anchor_grid, source_scale),
		_grid_px(Vector2(expanded_origin.x, expanded_end.y), source_scale) - _grid_px(anchor_grid, source_scale),
	]
	var rise := Vector2(0.0, -float(asset.get("max_height_tiles", 0.0)) * IsoProjectionRef.TILE_H * source_scale)
	var envelope_points: Array = expanded_ground.duplicate()
	for point: Vector2 in expanded_ground:
		envelope_points.append(point + rise)
	return _finalize_resolved(asset, source_scale, surfaces, slots, [{"id": "final", "anchor_origin": "footprint_end", "anchor_point": Vector2.ZERO}], base, envelope_points)


func _roof_surfaces(component: Dictionary, body: Dictionary, source_scale: int) -> Array:
	var base: Array = body.get("base", []) as Array
	var up: Vector2 = body.get("up", Vector2.ZERO) as Vector2
	var roof_base: Array[Vector2] = [base[0] + up, base[1] + up, base[2] + up, base[3] + up]
	var rise := Vector2(0.0, -float(component.get("rise_tiles", 1.0)) * IsoProjectionRef.TILE_H * source_scale)
	var material := str(component.get("material", ""))
	var roof_id := str(component.get("id", "roof"))
	var out: Array = []
	if str(component.get("kind", "")) == "gable_roof":
		var ridge_a := roof_base[0].lerp(roof_base[3], 0.5) + rise
		var ridge_b := roof_base[1].lerp(roof_base[2], 0.5) + rise
		# The gable remains on the wall plane. Roof planes may overhang it,
		# but extending the plaster triangle would make the wall itself float
		# outside the exact gameplay footprint.
		out.append(_surface_record("%s.east_gable" % roof_id, "wall_east",
			str(body.get("east_material", "")), [roof_base[1], roof_base[2], ridge_b], "final"))
		var overhang: Array = component.get("overhang_cells", [0.0, 0.0]) as Array
		var end_overhang := float(overhang[0])
		var eave_overhang := float(overhang[1])
		var west := _grid_px(Vector2(-end_overhang, 0.0), source_scale)
		var east := _grid_px(Vector2(end_overhang, 0.0), source_scale)
		var north := _grid_px(Vector2(0.0, -eave_overhang), source_scale)
		var south := _grid_px(Vector2(0.0, eave_overhang), source_scale)
		out.append(_surface_record("%s.north_plane" % roof_id, "roof", material,
			[roof_base[0] + north + west, roof_base[1] + north + east,
			ridge_b + east, ridge_a + west], "final"))
		out.append(_surface_record("%s.south_plane" % roof_id, "roof", material,
			[roof_base[3] + south + west, roof_base[2] + south + east,
			ridge_b + east, ridge_a + west], "final"))
	else:
		var peak := (roof_base[0] + roof_base[1] + roof_base[2] + roof_base[3]) / 4.0 + rise
		out.append(_surface_record("%s.a" % roof_id, "roof", material, [roof_base[0], roof_base[1], peak], "final"))
		out.append(_surface_record("%s.b" % roof_id, "roof", material, [roof_base[1], roof_base[2], peak], "final"))
		out.append(_surface_record("%s.c" % roof_id, "roof", material, [roof_base[2], roof_base[3], peak], "final"))
		out.append(_surface_record("%s.d" % roof_id, "roof", material, [roof_base[3], roof_base[0], peak], "final"))
	return out

func _structure_slot(slot: Dictionary, body: Dictionary, face: String, footprint: Vector2i, source_scale: int, part: String) -> Dictionary:
	var base: Array = body.get("base", []) as Array
	var up: Vector2 = body.get("up", Vector2.ZERO) as Vector2
	var local_rect: Array = []
	var unused := footprint
	if face == "south":
		local_rect = [base[3], base[2]]
	else:
		local_rect = [base[1], base[2]]
	var width := float(slot.get("width_cells", 0.0))
	var denominator := 1.0
	if face == "south":
		denominator = _edge_grid_length(base[3], base[2], source_scale)
	else:
		denominator = _edge_grid_length(base[1], base[2], source_scale)
	var edge_fraction := width / denominator
	var center := float(slot.get("u_center", 0.5))
	var lower_a: Vector2 = (local_rect[0] as Vector2).lerp(local_rect[1] as Vector2, clampf(center - edge_fraction / 2.0, 0.0, 1.0))
	var lower_b: Vector2 = (local_rect[0] as Vector2).lerp(local_rect[1] as Vector2, clampf(center + edge_fraction / 2.0, 0.0, 1.0))
	var low_offset := up * float(slot.get("bottom_ratio", 0.0))
	var high_offset := up * (float(slot.get("bottom_ratio", 0.0)) + float(slot.get("height_ratio", 0.0)))
	return _slot_record(slot, face, [lower_a + low_offset, lower_b + low_offset, lower_b + high_offset, lower_a + high_offset], part)


func _interior_slot(fixture: Dictionary, room: Vector2i, up: Vector2, source_scale: int, part: String) -> Dictionary:
	var side := str(fixture.get("side", ""))
	var index := float(int(fixture.get("index", 0))) + 0.5
	var span := float(fixture.get("span_cells", 0.0))
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	match side:
		"north":
			a = Vector2(index - span / 2.0, 0.0)
			b = Vector2(index + span / 2.0, 0.0)
		"south":
			a = Vector2(index - span / 2.0, float(room.y))
			b = Vector2(index + span / 2.0, float(room.y))
		"west":
			a = Vector2(0.0, index - span / 2.0)
			b = Vector2(0.0, index + span / 2.0)
		_:
			a = Vector2(float(room.x), index - span / 2.0)
			b = Vector2(float(room.x), index + span / 2.0)
	var lower_a := _grid_px(a, source_scale)
	var lower_b := _grid_px(b, source_scale)
	var low_offset := up * float(fixture.get("bottom_ratio", 0.0))
	var high_offset := up * (float(fixture.get("bottom_ratio", 0.0)) + float(fixture.get("height_ratio", 0.0)))
	return _slot_record(fixture, side, [lower_a + low_offset, lower_b + low_offset, lower_b + high_offset, lower_a + high_offset], part)


func _finalize_resolved(asset: Dictionary, source_scale: int, surfaces: Array, slots: Array, parts: Array, ground_points: Array, alpha_envelope_points: Array = []) -> Dictionary:
	var points: Array[Vector2] = []
	for surface: Dictionary in surfaces:
		points.append_array(surface.get("_points", []) as Array)
	for slot: Dictionary in slots:
		for point: Variant in slot.get("_points", []):
			points.append(point as Vector2)
	for part: Dictionary in parts:
		points.append(part.get("anchor_point", Vector2.ZERO) as Vector2)
	for point: Variant in ground_points:
		points.append(point as Vector2)
	for point: Variant in alpha_envelope_points:
		points.append(point as Vector2)
	var bounds := _bounds(points)
	var offset := Vector2(float(PADDING_PX) - bounds.position.x, float(PADDING_PX) - bounds.position.y)
	for surface: Dictionary in surfaces:
		surface["polygon_px"] = _points_json(_offset_points(surface.get("_points", []) as Array, offset))
		surface.erase("_points")
	for slot: Dictionary in slots:
		var raw_points: Array = slot.get("_points", []) as Array
		if not raw_points.is_empty():
			slot["polygon_px"] = _points_json(_offset_points(raw_points, offset))
			slot.erase("_points")
		if slot.has("_contact_center"):
			slot["contact_center_px"] = _point_json((slot["_contact_center"] as Vector2) + offset)
			slot.erase("_contact_center")
	for part: Dictionary in parts:
		part["anchor_px"] = _point_json((part.get("anchor_point", Vector2.ZERO) as Vector2) + offset)
		part.erase("anchor_point")
	var width := ceili(bounds.size.x) + PADDING_PX * 2
	var height := ceili(bounds.size.y) + PADDING_PX * 2
	var ground_polygon := _points_json(_offset_points(ground_points, offset))
	var envelope_rect: Array = []
	if not alpha_envelope_points.is_empty():
		var envelope_bounds := _bounds(alpha_envelope_points)
		envelope_rect = [
			floori(envelope_bounds.position.x + offset.x),
			floori(envelope_bounds.position.y + offset.y),
			ceili(envelope_bounds.size.x),
			ceili(envelope_bounds.size.y),
		]
	var layers: Array = []
	for surface: Dictionary in surfaces:
		layers.append({"id": str(surface.get("id", "")), "kind": "surface", "part": str(surface.get("part", ""))})
	for slot: Dictionary in slots:
		if str(slot.get("kind", "")) != "contact":
			layers.append({"id": str(slot.get("id", "")), "kind": "slot", "part": str(slot.get("part", ""))})
	var resolved := {
		"id": str(asset.get("id", "")),
		"kind": str(asset.get("kind", "")),
		"source_scale": source_scale,
		"canvas_size_px": [width, height],
		"crop_rect_px": [0, 0, width, height],
		"ground_polygon_px": ground_polygon,
		"runtime": {"draw_scale": 1.0 / float(source_scale), "footprint_cells": asset.get("footprint_cells", asset.get("room_cells", []))},
		"surfaces": surfaces,
		"slots": slots,
		"parts": parts,
		"layers": layers,
	}
	if not envelope_rect.is_empty():
		resolved["alpha_envelope_rect_px"] = envelope_rect
	return resolved


func _surface_record(id: String, semantic: String, material: String, points: Array, part: String) -> Dictionary:
	return {"id": id, "semantic": semantic, "material": material, "part": part, "_points": points}


func _slot_record(slot: Dictionary, face: String, points: Array, part: String) -> Dictionary:
	return {"id": str(slot.get("id", "")), "kind": str(slot.get("kind", "")), "face": face, "module": str(slot.get("module", "")), "part": part, "_points": points}


func _footprint_points(origin: Vector2, size: Vector2i, anchor_size: Vector2i, source_scale: int) -> Array[Vector2]:
	var anchor := Vector2(float(anchor_size.x), float(anchor_size.y))
	return [
		_grid_px(origin, source_scale) - _grid_px(anchor, source_scale),
		_grid_px(origin + Vector2(size.x, 0.0), source_scale) - _grid_px(anchor, source_scale),
		_grid_px(origin + Vector2(size.x, size.y), source_scale) - _grid_px(anchor, source_scale),
		_grid_px(origin + Vector2(0.0, size.y), source_scale) - _grid_px(anchor, source_scale),
	]


func _grid_px(grid: Vector2, source_scale: int) -> Vector2:
	return IsoProjectionRef.grid_to_screen(grid) * float(source_scale)


func _interior_fixture_grid(side: String, index: int, room: Vector2i) -> Vector2:
	match side:
		"north":
			return Vector2(float(clampi(index, 0, room.x - 1)) + 0.5, 0.0)
		"south":
			return Vector2(float(clampi(index, 0, room.x - 1)) + 0.5, float(room.y))
		"east":
			return Vector2(float(room.x), float(clampi(index, 0, room.y - 1)) + 0.5)
		_:
			return Vector2(0.0, float(clampi(index, 0, room.y - 1)) + 0.5)


func _edge_grid_length(a: Vector2, b: Vector2, source_scale: int) -> float:
	var pixel_length := a.distance_to(b)
	var x_step := _grid_px(Vector2(1.0, 0.0), source_scale).length()
	return pixel_length / x_step


func _cells(raw: Variant) -> Vector2i:
	var cells: Array = raw as Array
	return Vector2i(int(cells[0]), int(cells[1]))


func _bounds(points: Array[Vector2]) -> Rect2:
	var min_point := points[0]
	var max_point := points[0]
	for point: Vector2 in points:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point)


func _offset_points(points: Array, offset: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for point: Variant in points:
		out.append((point as Vector2) + offset)
	return out


func _points_json(points: Array) -> Array:
	var out: Array = []
	for point: Variant in points:
		out.append(_point_json(point as Vector2))
	return out


func _point_json(point: Vector2) -> Array:
	return [roundi(point.x), roundi(point.y)]


func _write_svg_guide(resolved: Dictionary, output_dir: String) -> void:
	var canvas: Array = resolved.get("canvas_size_px", []) as Array
	var lines := PackedStringArray([
		"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\">" % [int(canvas[0]), int(canvas[1]), int(canvas[0]), int(canvas[1])],
		"<rect width=\"100%\" height=\"100%\" fill=\"#20262c\"/>"
	])
	for surface: Variant in resolved.get("surfaces", []):
		var item: Dictionary = surface as Dictionary
		var semantic := str(item.get("semantic", "floor"))
		lines.append("<polygon points=\"%s\" fill=\"%s\" fill-opacity=\"0.42\" stroke=\"#f5f5f5\" stroke-width=\"2\"/>" % [_svg_points(item.get("polygon_px", []) as Array), str(GUIDE_COLORS.get(semantic, "#ffffff"))])
	for slot: Variant in resolved.get("slots", []):
		var item: Dictionary = slot as Dictionary
		if str(item.get("kind", "")) == "contact":
			var center: Array = item.get("contact_center_px", []) as Array
			var size: Array = item.get("contact_size_px", []) as Array
			lines.append("<ellipse cx=\"%d\" cy=\"%d\" rx=\"%d\" ry=\"%d\" fill=\"none\" stroke=\"%s\" stroke-width=\"3\"/>" % [int(center[0]), int(center[1]), int(float(size[0]) / 2.0), int(float(size[1]) / 2.0), str(GUIDE_COLORS["contact"])])
		else:
			lines.append("<polygon points=\"%s\" fill=\"%s\" fill-opacity=\"0.30\" stroke=\"%s\" stroke-width=\"3\"/>" % [_svg_points(item.get("polygon_px", []) as Array), str(GUIDE_COLORS["slot"]), str(GUIDE_COLORS["slot"])])
	for part: Variant in resolved.get("parts", []):
		var item: Dictionary = part as Dictionary
		var anchor: Array = item.get("anchor_px", []) as Array
		lines.append("<circle cx=\"%d\" cy=\"%d\" r=\"6\" fill=\"#ffffff\" stroke=\"#111111\" stroke-width=\"2\"/>" % [int(anchor[0]), int(anchor[1])])
	lines.append("</svg>")
	var path := output_dir.path_join("%s.svg" % str(resolved.get("id", "asset")))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()


func _svg_points(points: Array) -> String:
	var terms := PackedStringArray()
	for point: Variant in points:
		var pair: Array = point as Array
		terms.append("%d,%d" % [int(pair[0]), int(pair[1])])
	return " ".join(terms)


