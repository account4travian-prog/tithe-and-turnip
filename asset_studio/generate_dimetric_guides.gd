extends SceneTree

## Offline production-guide generator for AI-assisted static art.
##
## This deliberately calls the game's IsoProjection seam.  It must never
## duplicate the dimetric formula: a guide drifting away from presentation
## would be worse than having no guide at all.

const IsoProjectionRef := preload("res://scripts/globals/iso_projection.gd")

const CATALOG_PATH := "res://asset_studio/asset_generation_catalog.json"
const DEFAULT_OUTPUT_DIR := "res://asset_studio/guides"
const CANVAS_SIZE := Vector2i(1024, 1024)
const RASTER_SCALE := 0.25
const RASTER_SIZE := Vector2i(256, 256)
const SAFE_RECT := Rect2i(72, 72, 880, 880)
const GRID_SCALE := 4.8
const BASE_ANCHOR := Vector2(512.0, 700.0)

const COLOR_SAFE := Color(0.18, 0.78, 0.66, 0.92)
const COLOR_GRID := Color(0.32, 0.47, 0.55, 0.78)
const COLOR_SOUTH := Color(0.92, 0.47, 0.25, 0.52)
const COLOR_EAST := Color(0.25, 0.58, 0.92, 0.52)
const COLOR_ROOF := Color(0.66, 0.31, 0.75, 0.48)
const COLOR_DOOR := Color(0.96, 0.77, 0.18, 0.96)
const COLOR_WINDOW := Color(0.26, 0.88, 0.89, 0.96)
const COLOR_RAMP := Color(0.94, 0.42, 0.55, 0.96)
const COLOR_GATE := Color(0.95, 0.62, 0.15, 0.96)
const COLOR_TEXT := Color(0.96, 0.97, 0.98, 0.96)


func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var output_dir: String = DEFAULT_OUTPUT_DIR
	if arguments.size() == 2 and arguments[0] == "--out":
		output_dir = arguments[1]
	elif not arguments.is_empty():
		printerr("Usage: godot --headless --path . --script asset_studio/generate_dimetric_guides.gd -- [--out res://asset_studio/guides]")
		quit(2)
		return

	var catalog: Dictionary = _load_catalog()
	if catalog.is_empty():
		quit(1)
		return
	var errors: PackedStringArray = _validate_catalog(catalog)
	if not errors.is_empty():
		for problem: String in errors:
			printerr("CATALOG ERROR: %s" % problem)
		quit(1)
		return

	var absolute_output: String = ProjectSettings.globalize_path(output_dir)
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(absolute_output)
	if dir_error != OK:
		printerr("Could not create guide directory '%s' (error %d)." % [absolute_output, dir_error])
		quit(1)
		return

	var output: Dictionary = {
		"version": 1,
		"projection_source": catalog.get("projection_source", ""),
		"guide_directory": output_dir,
		"canvas_size_px": [CANVAS_SIZE.x, CANVAS_SIZE.y],
		"style_references": catalog.get("style_references", []),
		"assets": [],
		"modules": []
	}
	for module_spec: Variant in catalog.get("module_library", []):
		var module_record: Dictionary = _render_module_guide(module_spec as Dictionary, absolute_output)
		(output["modules"] as Array).append(module_record)
	for asset_spec: Variant in catalog.get("assets", []):
		var asset_record: Dictionary = _render_asset_guide(asset_spec as Dictionary, absolute_output)
		(output["assets"] as Array).append(asset_record)

	var manifest_path: String = absolute_output.path_join("guide_manifest.json")
	var manifest_file: FileAccess = FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest_file == null:
		printerr("Could not write %s" % manifest_path)
		quit(1)
		return
	manifest_file.store_string(JSON.stringify(output, "\t") + "\n")
	manifest_file.close()
	print("Generated %d asset guides and %d module guides in %s" % [
		(output["assets"] as Array).size(), (output["modules"] as Array).size(), absolute_output
	])
	quit()


func _load_catalog() -> Dictionary:
	var file: FileAccess = FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		printerr("Could not open %s" % CATALOG_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		printerr("Catalog is not a JSON object: %s" % CATALOG_PATH)
		return {}
	return parsed as Dictionary


func _validate_catalog(catalog: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var module_ids: Dictionary = {}
	var module_faces: Dictionary = {}
	for module_spec: Variant in catalog.get("module_library", []):
		if not (module_spec is Dictionary):
			errors.append("module_library contains a non-object entry")
			continue
		var module: Dictionary = module_spec as Dictionary
		var module_id: String = str(module.get("id", ""))
		var face: String = str(module.get("face", ""))
		if module_id.is_empty() or module_ids.has(module_id):
			errors.append("module id is missing or duplicated: '%s'" % module_id)
		module_ids[module_id] = true
		module_faces[module_id] = face
		if face != "south" and face != "east":
			errors.append("module '%s' must target south or east, not '%s'" % [module_id, face])

	var asset_ids: Dictionary = {}
	for asset_spec: Variant in catalog.get("assets", []):
		if not (asset_spec is Dictionary):
			errors.append("assets contains a non-object entry")
			continue
		var asset: Dictionary = asset_spec as Dictionary
		var asset_id: String = str(asset.get("id", ""))
		var kind: String = str(asset.get("guide_kind", ""))
		if asset_id.is_empty() or asset_ids.has(asset_id):
			errors.append("asset id is missing or duplicated: '%s'" % asset_id)
		asset_ids[asset_id] = true
		if kind == "structure_shell":
			var footprint: Array = asset.get("footprint_cells", []) as Array
			if footprint.size() != 2 or float(footprint[0]) <= 0.0 or float(footprint[1]) <= 0.0:
				errors.append("structure '%s' needs a positive [width, height] footprint" % asset_id)
			var faces: Array = asset.get("visible_faces", []) as Array
			if faces != ["south", "east"]:
				errors.append("structure '%s' must expose exactly [south, east] in that order" % asset_id)
			var entry_side: String = str(asset.get("entrance_side", ""))
			if entry_side != "south" and entry_side != "east" and entry_side != "none":
				errors.append("structure '%s' has invalid entrance_side '%s'" % [asset_id, entry_side])
			var has_primary_entry: bool = false
			for anchor_spec: Variant in asset.get("anchors", []):
				if not (anchor_spec is Dictionary):
					errors.append("structure '%s' has a non-object anchor" % asset_id)
					continue
				var anchor: Dictionary = anchor_spec as Dictionary
				var face: String = str(anchor.get("face", ""))
				var module_id: String = str(anchor.get("module", ""))
				var u: float = float(anchor.get("u", -1.0))
				if face != "south" and face != "east":
					errors.append("anchor '%s' on '%s' has illegal face '%s'" % [str(anchor.get("id", "")), asset_id, face])
				if not module_ids.has(module_id):
					errors.append("anchor '%s' on '%s' refers to unknown module '%s'" % [str(anchor.get("id", "")), asset_id, module_id])
				elif str(module_faces.get(module_id, "")) != face:
					errors.append("anchor '%s' on '%s' uses a module for the wrong face" % [str(anchor.get("id", "")), asset_id])
				if u < 0.0 or u > 1.0:
					errors.append("anchor '%s' on '%s' has u outside 0..1" % [str(anchor.get("id", "")), asset_id])
				if str(anchor.get("id", "")) == "door_primary" or str(anchor.get("id", "")) == "gate_primary":
					has_primary_entry = true
					if entry_side != face:
						errors.append("primary entry on '%s' must match entrance_side '%s'" % [asset_id, entry_side])
			if entry_side != "none" and not has_primary_entry:
				errors.append("structure '%s' declares an entrance but has no primary entry anchor" % asset_id)
			if entry_side == "none" and has_primary_entry:
				errors.append("structure '%s' has a primary entry despite entrance_side none" % asset_id)
	return errors


func _new_canvas() -> Image:
	var image: Image = Image.create(RASTER_SIZE.x, RASTER_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	_draw_safe_rect(image)
	return image


func _draw_safe_rect(image: Image) -> void:
	var top_left := Vector2i(SAFE_RECT.position)
	var bottom_right := Vector2i(SAFE_RECT.end)
	_draw_line(image, top_left, Vector2i(bottom_right.x, top_left.y), COLOR_SAFE, 2)
	_draw_line(image, Vector2i(bottom_right.x, top_left.y), bottom_right, COLOR_SAFE, 2)
	_draw_line(image, bottom_right, Vector2i(top_left.x, bottom_right.y), COLOR_SAFE, 2)
	_draw_line(image, Vector2i(top_left.x, bottom_right.y), top_left, COLOR_SAFE, 2)


func _render_asset_guide(spec: Dictionary, output_dir: String) -> Dictionary:
	var kind: String = str(spec.get("guide_kind", ""))
	var image: Image = _new_canvas()
	var record: Dictionary = {
		"id": str(spec.get("id", "")),
		"display_name": str(spec.get("display_name", "")),
		"guide_kind": kind,
		"reference": str(spec.get("reference", "")),
		"guide": "",
		"terra_prompt": "",
		"slots": []
	}
	if kind == "structure_shell":
		record = _draw_structure_shell(image, spec, record)
	elif kind == "freestanding_prop":
		_draw_freestanding_prop(image)
		record["terra_prompt"] = _prompt_for_freestanding(spec)
	elif kind == "ground_segment":
		_draw_ground_segment(image, str(spec.get("orientation", "")))
		record["terra_prompt"] = _prompt_for_ground_segment(spec)
	else:
		_draw_isolated_sprite(image, str(spec.get("category", "sprite")))
		record["terra_prompt"] = _prompt_for_isolated(spec)

	var file_name: String = "%s__%s.png" % [kind, str(spec.get("id", ""))]
	var absolute_path: String = output_dir.path_join(file_name)
	image.resize(CANVAS_SIZE.x, CANVAS_SIZE.y, Image.INTERPOLATE_NEAREST)
	var save_error: Error = image.save_png(absolute_path)
	if save_error != OK:
		push_error("Failed to save %s (error %d)" % [absolute_path, save_error])
	record["guide"] = "res://asset_studio/guides/%s" % file_name
	return record


func _draw_structure_shell(image: Image, spec: Dictionary, record: Dictionary) -> Dictionary:
	var footprint: Array = spec.get("footprint_cells", []) as Array
	var width: float = float(footprint[0])
	var height: float = float(footprint[1])
	var base: Array[Vector2] = [
		_grid_to_canvas(Vector2(0.0, 0.0), width, height),
		_grid_to_canvas(Vector2(width, 0.0), width, height),
		_grid_to_canvas(Vector2(width, height), width, height),
		_grid_to_canvas(Vector2(0.0, height), width, height)
	]
	_draw_polygon(image, base, Color(0.10, 0.15, 0.19, 0.25), COLOR_GRID)
	for x: int in range(int(width) + 1):
		_draw_line(image, _grid_to_canvas(Vector2(float(x), 0.0), width, height), _grid_to_canvas(Vector2(float(x), height), width, height), COLOR_GRID, 1)
	for y: int in range(int(height) + 1):
		_draw_line(image, _grid_to_canvas(Vector2(0.0, float(y)), width, height), _grid_to_canvas(Vector2(width, float(y)), width, height), COLOR_GRID, 1)

	var wall_height: float = 235.0 + 18.0 * maxf(width, height)
	var up := Vector2(0.0, -wall_height)
	var south: Array[Vector2] = [base[3], base[2], base[2] + up, base[3] + up]
	var east: Array[Vector2] = [base[1], base[2], base[2] + up, base[1] + up]
	_draw_polygon(image, south, COLOR_SOUTH, COLOR_TEXT)
	_draw_polygon(image, east, COLOR_EAST, COLOR_TEXT)
	_draw_face_marker(image, (south[0] + south[1] + south[2] + south[3]) / 4.0, "S", COLOR_SOUTH)
	_draw_face_marker(image, (east[0] + east[1] + east[2] + east[3]) / 4.0, "E", COLOR_EAST)

	var roof_base: Array[Vector2] = [base[0] + up, base[1] + up, base[2] + up, base[3] + up]
	_draw_roof_family(image, roof_base, str(spec.get("roof_family", "gable")))

	var slots: Array = []
	for anchor_spec: Variant in spec.get("anchors", []):
		var slot: Dictionary = _draw_anchor_slot(image, anchor_spec as Dictionary, width, height, wall_height)
		slots.append(slot)
	record["slots"] = slots
	record["footprint_cells"] = [width, height]
	record["visible_faces"] = ["south", "east"]
	record["entrance_side"] = str(spec.get("entrance_side", "none"))
	record["roof_family"] = str(spec.get("roof_family", ""))
	record["terra_prompt"] = _prompt_for_structure(spec)
	return record


func _draw_anchor_slot(image: Image, anchor: Dictionary, footprint_w: float, footprint_h: float, wall_height: float) -> Dictionary:
	var module_id: String = str(anchor.get("module", ""))
	var face: String = str(anchor.get("face", ""))
	var u: float = float(anchor.get("u", 0.5))
	var width_cells: float = float(anchor.get("width_cells", 0.4))
	var height_ratio: float = float(anchor.get("height_ratio", 0.5))
	var left_grid: Vector2
	var right_grid: Vector2
	if face == "south":
		left_grid = Vector2(u * footprint_w - width_cells / 2.0, footprint_h)
		right_grid = Vector2(u * footprint_w + width_cells / 2.0, footprint_h)
	else:
		left_grid = Vector2(footprint_w, u * footprint_h - width_cells / 2.0)
		right_grid = Vector2(footprint_w, u * footprint_h + width_cells / 2.0)
	var lower_left := _grid_to_canvas(left_grid, footprint_w, footprint_h)
	var lower_right := _grid_to_canvas(right_grid, footprint_w, footprint_h)
	var slot_height: float = wall_height * height_ratio
	var upper_left := lower_left + Vector2(0.0, -slot_height)
	var upper_right := lower_right + Vector2(0.0, -slot_height)
	var points: Array[Vector2] = [lower_left, lower_right, upper_right, upper_left]
	var kind: String = module_id.split("_")[0]
	var color: Color = _module_color(kind)
	if kind == "ramp":
		var exterior_delta: Vector2 = _grid_delta_to_canvas(Vector2(0.0, 0.70) if face == "south" else Vector2(0.70, 0.0))
		points = [lower_left, lower_right, lower_right + exterior_delta, lower_left + exterior_delta]
	_draw_polygon(image, points, Color(color.r, color.g, color.b, 0.30), color)
	var bounds: Rect2i = _bounds_for_points(points, 3)
	return {
		"id": str(anchor.get("id", "")),
		"module": module_id,
		"face": face,
		"u": u,
		"polygon": _points_as_json(points),
		"bbox_px": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
		"normalization": "trim transparent module art, scale to bbox_px, alpha-compose over shell; preserve the full untrimmed source beside the recipe"
	}


func _draw_roof_family(image: Image, roof_base: Array[Vector2], roof_family: String) -> void:
	match roof_family:
		"gable", "thatched_gable", "gable_tower":
			var ridge_lift: float = 115.0
			var back_ridge: Vector2 = (roof_base[0] + roof_base[1]) / 2.0 + Vector2(0.0, -ridge_lift)
			var front_ridge: Vector2 = (roof_base[3] + roof_base[2]) / 2.0 + Vector2(0.0, -ridge_lift)
			_draw_polygon(image, [roof_base[0], roof_base[3], front_ridge, back_ridge], COLOR_ROOF, COLOR_TEXT)
			_draw_polygon(image, [roof_base[1], roof_base[2], front_ridge, back_ridge], Color(0.56, 0.23, 0.68, 0.50), COLOR_TEXT)
			_draw_polygon(image, [roof_base[3], roof_base[2], front_ridge], Color(0.82, 0.48, 0.29, 0.34), COLOR_TEXT)
			if roof_family == "gable_tower":
				var tower_base: Vector2 = (back_ridge + front_ridge) / 2.0 + Vector2(0.0, -22.0)
				_draw_tower_marker(image, tower_base)
		"lean_to", "awning":
			var rise: float = 82.0 if roof_family == "lean_to" else 52.0
			var high_left: Vector2 = roof_base[0] + Vector2(0.0, -rise)
			var high_right: Vector2 = roof_base[1] + Vector2(0.0, -rise)
			_draw_polygon(image, [high_left, high_right, roof_base[2], roof_base[3]], COLOR_ROOF, COLOR_TEXT)
		"gatehouse":
			_draw_hipped_roof(image, roof_base, 92.0)
			_draw_tower_marker(image, roof_base[0] + Vector2(42.0, -58.0))
			_draw_tower_marker(image, roof_base[1] + Vector2(-42.0, -58.0))
		_:
			_draw_hipped_roof(image, roof_base, 110.0)


func _draw_hipped_roof(image: Image, roof_base: Array[Vector2], peak_lift: float) -> void:
	var roof_peak: Vector2 = (roof_base[0] + roof_base[1] + roof_base[2] + roof_base[3]) / 4.0 + Vector2(0.0, -peak_lift)
	_draw_polygon(image, [roof_base[0], roof_base[1], roof_peak], COLOR_ROOF, COLOR_TEXT)
	_draw_polygon(image, [roof_base[1], roof_base[2], roof_peak], Color(0.56, 0.23, 0.68, 0.50), COLOR_TEXT)
	_draw_polygon(image, [roof_base[2], roof_base[3], roof_peak], Color(0.75, 0.38, 0.65, 0.48), COLOR_TEXT)
	_draw_polygon(image, [roof_base[3], roof_base[0], roof_peak], Color(0.52, 0.21, 0.64, 0.48), COLOR_TEXT)


func _draw_tower_marker(image: Image, centre: Vector2) -> void:
	var half_w := 30.0
	var lower := centre + Vector2(0.0, 70.0)
	var tower: Array[Vector2] = [
		centre + Vector2(-half_w, 0.0),
		centre + Vector2(half_w, 0.0),
		lower + Vector2(half_w, 0.0),
		lower + Vector2(-half_w, 0.0)
	]
	_draw_polygon(image, tower, Color(0.31, 0.60, 0.88, 0.42), COLOR_TEXT)
	_draw_polygon(image, [tower[0], tower[1], centre + Vector2(0.0, -48.0)], COLOR_ROOF, COLOR_TEXT)


func _draw_freestanding_prop(image: Image) -> void:
	var base: Array[Vector2] = [
		_grid_to_canvas(Vector2(0.0, 0.0), 1.0, 1.0),
		_grid_to_canvas(Vector2(1.0, 0.0), 1.0, 1.0),
		_grid_to_canvas(Vector2(1.0, 1.0), 1.0, 1.0),
		_grid_to_canvas(Vector2(0.0, 1.0), 1.0, 1.0)
	]
	_draw_polygon(image, base, Color(0.20, 0.44, 0.56, 0.28), COLOR_GRID)
	_draw_crosshair(image, (base[0] + base[1] + base[2] + base[3]) / 4.0, COLOR_SAFE)


func _draw_ground_segment(image: Image, orientation: String) -> void:
	var base: Array[Vector2] = [
		_grid_to_canvas(Vector2(0.0, 0.0), 1.0, 1.0),
		_grid_to_canvas(Vector2(1.0, 0.0), 1.0, 1.0),
		_grid_to_canvas(Vector2(1.0, 1.0), 1.0, 1.0),
		_grid_to_canvas(Vector2(0.0, 1.0), 1.0, 1.0)
	]
	_draw_polygon(image, base, Color(0.20, 0.44, 0.56, 0.20), COLOR_GRID)
	var start: Vector2 = base[3] if orientation == "south" else base[1]
	var end: Vector2 = base[2]
	_draw_line(image, Vector2i(start), Vector2i(end), COLOR_DOOR, 14)
	_draw_line(image, Vector2i(start + Vector2(0.0, -76.0)), Vector2i(end + Vector2(0.0, -76.0)), COLOR_DOOR, 14)
	_draw_line(image, Vector2i(start), Vector2i(start + Vector2(0.0, -76.0)), COLOR_TEXT, 3)
	_draw_line(image, Vector2i(end), Vector2i(end + Vector2(0.0, -76.0)), COLOR_TEXT, 3)


func _draw_isolated_sprite(image: Image, _category: String) -> void:
	var centre := Vector2(CANVAS_SIZE) / 2.0
	_draw_crosshair(image, centre, COLOR_SAFE)
	_draw_line(image, Vector2i(centre.x - 210.0, centre.y + 250.0), Vector2i(centre.x + 210.0, centre.y + 250.0), COLOR_GRID, 2)


func _render_module_guide(module_spec: Dictionary, output_dir: String) -> Dictionary:
	var image: Image = _new_canvas()
	var face: String = str(module_spec.get("face", "south"))
	var p0 := Vector2(370.0, 685.0)
	var direction: Vector2 = _grid_delta_to_canvas(Vector2(1.0, 0.0) if face == "south" else Vector2(0.0, 1.0))
	direction = direction.normalized() * 250.0
	var p1: Vector2 = p0 + direction
	var p2: Vector2 = p1 + Vector2(0.0, -270.0)
	var p3: Vector2 = p0 + Vector2(0.0, -270.0)
	var kind: String = str(module_spec.get("kind", "door"))
	_draw_polygon(image, [p0, p1, p2, p3], Color(_module_color(kind).r, _module_color(kind).g, _module_color(kind).b, 0.28), _module_color(kind))
	_draw_face_marker(image, (p0 + p1 + p2 + p3) / 4.0, "S" if face == "south" else "E", _module_color(kind))
	var file_name: String = "module__%s.png" % str(module_spec.get("id", ""))
	var absolute_path: String = output_dir.path_join(file_name)
	image.resize(CANVAS_SIZE.x, CANVAS_SIZE.y, Image.INTERPOLATE_NEAREST)
	var save_error: Error = image.save_png(absolute_path)
	if save_error != OK:
		push_error("Failed to save %s (error %d)" % [absolute_path, save_error])
	return {
		"id": str(module_spec.get("id", "")),
		"kind": kind,
		"face": face,
		"guide": "res://asset_studio/guides/%s" % file_name,
		"terra_prompt": "Use the attached face-module guide as mandatory geometry. %s. Transparent surrounding space, bold outlined painted/cel-shaded Tithe & Turnip style, one module only." % str(module_spec.get("prompt", ""))
	}


func _prompt_for_structure(spec: Dictionary) -> String:
	var entry: String = str(spec.get("entrance_side", "none"))
	var slots: Array = spec.get("anchors", []) as Array
	var slot_terms: PackedStringArray = []
	for slot: Variant in slots:
		var anchor: Dictionary = slot as Dictionary
		slot_terms.append("%s on the %s face" % [str(anchor.get("id", "module slot")), str(anchor.get("face", ""))])
	var slot_text: String = ", ".join(slot_terms)
	return "Use the attached dimetric guide as the required composition. Paint the %s structure shell in the Tithe & Turnip painted cel-shaded style: exactly two adjacent wall faces, South on the screen lower-left and East on the screen lower-right; the roof silhouette and footprint remain inside the guide. Keep flat continuous wall material at the marked module positions (%s) so opaque modules can be composited later. The prescribed playable entrance side is %s. Isolated transparent-ready asset with bold dark outlines and warm material detail." % [str(spec.get("display_name", "building")), slot_text, entry]


func _prompt_for_freestanding(spec: Dictionary) -> String:
	return "Use the attached one-cell dimetric guide for the %s. Keep its base centered on the diamond and build upward from that exact footprint. Isolated transparent-ready painted cel-shaded Tithe & Turnip prop, bold dark outlines, no environment." % str(spec.get("display_name", "prop"))


func _prompt_for_ground_segment(spec: Dictionary) -> String:
	return "Use the attached %s guide as the exact dimetric orientation. Draw one repeatable fence segment aligned to that edge, with its posts rooted on the indicated tile boundary. Isolated transparent-ready painted cel-shaded Tithe & Turnip prop." % str(spec.get("display_name", "ground segment"))


func _prompt_for_isolated(spec: Dictionary) -> String:
	return "Use the art-safe guide for a single %s. Keep the object centered over the marked baseline, with a clean transparent-ready perimeter. Painted/cel-shaded Tithe & Turnip style, bold dark outlines, no scene." % str(spec.get("display_name", "sprite"))


func _grid_to_canvas(grid: Vector2, footprint_w: float, footprint_h: float) -> Vector2:
	var centered: Vector2 = grid - Vector2(footprint_w / 2.0, footprint_h / 2.0)
	return BASE_ANCHOR + IsoProjectionRef.grid_to_screen(centered) * GRID_SCALE


func _grid_delta_to_canvas(grid_delta: Vector2) -> Vector2:
	return IsoProjectionRef.grid_to_screen(grid_delta) * GRID_SCALE


func _module_color(kind: String) -> Color:
	match kind:
		"door":
			return COLOR_DOOR
		"window":
			return COLOR_WINDOW
		"ramp":
			return COLOR_RAMP
		"gate":
			return COLOR_GATE
		_:
			return COLOR_TEXT


func _draw_face_marker(image: Image, centre: Vector2, face_label: String, color: Color) -> void:
	_draw_disc(image, Vector2i(centre), 20, Color(color.r, color.g, color.b, 0.92))
	if face_label == "S":
		_draw_line(image, Vector2i(centre + Vector2(-7.0, -9.0)), Vector2i(centre + Vector2(7.0, -9.0)), COLOR_TEXT, 3)
		_draw_line(image, Vector2i(centre + Vector2(-7.0, -9.0)), Vector2i(centre + Vector2(-7.0, 0.0)), COLOR_TEXT, 3)
		_draw_line(image, Vector2i(centre + Vector2(-7.0, 0.0)), Vector2i(centre + Vector2(7.0, 0.0)), COLOR_TEXT, 3)
		_draw_line(image, Vector2i(centre + Vector2(7.0, 0.0)), Vector2i(centre + Vector2(7.0, 9.0)), COLOR_TEXT, 3)
		_draw_line(image, Vector2i(centre + Vector2(-7.0, 9.0)), Vector2i(centre + Vector2(7.0, 9.0)), COLOR_TEXT, 3)
	else:
		_draw_line(image, Vector2i(centre + Vector2(-7.0, -9.0)), Vector2i(centre + Vector2(-7.0, 9.0)), COLOR_TEXT, 3)
		_draw_line(image, Vector2i(centre + Vector2(-7.0, -9.0)), Vector2i(centre + Vector2(7.0, -9.0)), COLOR_TEXT, 3)
		_draw_line(image, Vector2i(centre + Vector2(-7.0, 0.0)), Vector2i(centre + Vector2(5.0, 0.0)), COLOR_TEXT, 3)
		_draw_line(image, Vector2i(centre + Vector2(-7.0, 9.0)), Vector2i(centre + Vector2(7.0, 9.0)), COLOR_TEXT, 3)


func _draw_crosshair(image: Image, centre: Vector2, color: Color) -> void:
	_draw_line(image, Vector2i(centre + Vector2(-26.0, 0.0)), Vector2i(centre + Vector2(26.0, 0.0)), color, 2)
	_draw_line(image, Vector2i(centre + Vector2(0.0, -26.0)), Vector2i(centre + Vector2(0.0, 26.0)), color, 2)
	_draw_disc(image, Vector2i(centre), 5, color)


func _draw_polygon(image: Image, points: Array[Vector2], fill: Color, outline: Color) -> void:
	_fill_polygon(image, points, fill)
	for index: int in points.size():
		_draw_line(image, Vector2i(points[index]), Vector2i(points[(index + 1) % points.size()]), outline, 2)


func _fill_polygon(image: Image, points: Array[Vector2], color: Color) -> void:
	var scaled_points: Array[Vector2] = []
	for point: Vector2 in points:
		scaled_points.append(point * RASTER_SCALE)
	var raster_width: int = image.get_width()
	var raster_height: int = image.get_height()
	var min_y: int = raster_height - 1
	var max_y: int = 0
	for point: Vector2 in scaled_points:
		min_y = mini(min_y, floori(point.y))
		max_y = maxi(max_y, ceili(point.y))
	min_y = clampi(min_y, 0, raster_height - 1)
	max_y = clampi(max_y, 0, raster_height - 1)
	for y: int in range(min_y, max_y + 1):
		var intersections: Array[float] = []
		for index: int in scaled_points.size():
			var a: Vector2 = scaled_points[index]
			var b: Vector2 = scaled_points[(index + 1) % scaled_points.size()]
			if (a.y <= float(y) and b.y > float(y)) or (b.y <= float(y) and a.y > float(y)):
				intersections.append(a.x + (float(y) - a.y) * (b.x - a.x) / (b.y - a.y))
		intersections.sort()
		var pair_index: int = 0
		while pair_index + 1 < intersections.size():
			var from_x: int = clampi(ceili(intersections[pair_index]), 0, raster_width - 1)
			var to_x: int = clampi(floori(intersections[pair_index + 1]), 0, raster_width - 1)
			for x: int in range(from_x, to_x + 1):
				image.set_pixel(x, y, color)
			pair_index += 2


func _draw_line(image: Image, from: Vector2i, to: Vector2i, color: Color, width: int) -> void:
	var x0: int = roundi(float(from.x) * RASTER_SCALE)
	var y0: int = roundi(float(from.y) * RASTER_SCALE)
	var x1: int = roundi(float(to.x) * RASTER_SCALE)
	var y1: int = roundi(float(to.y) * RASTER_SCALE)
	var dx: int = absi(x1 - x0)
	var sx: int = 1 if x0 < x1 else -1
	var dy: int = -absi(y1 - y0)
	var sy: int = 1 if y0 < y1 else -1
	var error: int = dx + dy
	var radius: int = maxi(0, roundi(float(width) * RASTER_SCALE) / 2)
	while true:
		_draw_disc_scaled(image, Vector2i(x0, y0), radius, color)
		if x0 == x1 and y0 == y1:
			break
		var twice_error: int = 2 * error
		if twice_error >= dy:
			error += dy
			x0 += sx
		if twice_error <= dx:
			error += dx
			y0 += sy


func _draw_disc(image: Image, centre: Vector2i, radius: int, color: Color) -> void:
	var scaled_centre := Vector2i(roundi(float(centre.x) * RASTER_SCALE), roundi(float(centre.y) * RASTER_SCALE))
	var scaled_radius: int = maxi(1, roundi(float(radius) * RASTER_SCALE))
	_draw_disc_scaled(image, scaled_centre, scaled_radius, color)


func _draw_disc_scaled(image: Image, centre: Vector2i, radius: int, color: Color) -> void:
	var min_x: int = clampi(centre.x - radius, 0, image.get_width() - 1)
	var max_x: int = clampi(centre.x + radius, 0, image.get_width() - 1)
	var min_y: int = clampi(centre.y - radius, 0, image.get_height() - 1)
	var max_y: int = clampi(centre.y + radius, 0, image.get_height() - 1)
	var radius_sq: int = radius * radius
	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			var dx: int = x - centre.x
			var dy: int = y - centre.y
			if dx * dx + dy * dy <= radius_sq:
				image.set_pixel(x, y, color)


func _bounds_for_points(points: Array[Vector2], padding: int) -> Rect2i:
	var min_x: int = CANVAS_SIZE.x - 1
	var min_y: int = CANVAS_SIZE.y - 1
	var max_x: int = 0
	var max_y: int = 0
	for point: Vector2 in points:
		min_x = mini(min_x, floori(point.x))
		min_y = mini(min_y, floori(point.y))
		max_x = maxi(max_x, ceili(point.x))
		max_y = maxi(max_y, ceili(point.y))
	min_x = clampi(min_x - padding, 0, CANVAS_SIZE.x - 1)
	min_y = clampi(min_y - padding, 0, CANVAS_SIZE.y - 1)
	max_x = clampi(max_x + padding, 0, CANVAS_SIZE.x - 1)
	max_y = clampi(max_y + padding, 0, CANVAS_SIZE.y - 1)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _points_as_json(points: Array[Vector2]) -> Array:
	var output: Array = []
	for point: Vector2 in points:
		output.append([roundi(point.x), roundi(point.y)])
	return output
