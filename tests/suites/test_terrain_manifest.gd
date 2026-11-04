extends RefCounted
## ADR-042 coverage for the terrain rendering system
## (scripts/world/farm_renderer.gd + scripts/autoloads/game_data.gd +
## data/terrain_manifest.json): deterministic variant/scatter selection, the
## pure transition-lookup math, moisture-as-material, the empty-manifest
## fallback routing (today's exact flat-color path must be what _draw()
## reaches when no texture resolves), the partial-manifest degrade rules, and
## the material-family schema. Never invokes _draw() - the same headless
## limitation every renderer suite documents; the public static functions
## and terrain_cell_plan() (exit_line_grid_points pattern) are the testable
## surface _draw() itself consumes.

const FARM_RENDERER_SCRIPT := preload("res://scripts/world/farm_renderer.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")
## A real staged asset used as the fake terrain texture so the plan tests can
## exercise the has_texture=true path without generating art (ADR-042's
## "build against the data shape" rule - the shipped manifest itself stays
## texture-free and exercises the fallback path).
const ROCK_TEXTURE := "res://assets/sprites/world_dressing/rocks1/Rock1_1.png"


## A FarmRenderer whose neighbour sampling is fixed, so terrain_cell_plan()
## can be driven without a live FarmGrid - the same override pattern
## test_iso_terrain.gd's _MockCamera uses for get_visible_screen_rect().
class _PlanRenderer extends FarmRenderer:
	var fixed_neighbors: Array[String] = [
		"loamy_tilled", "loamy_tilled", "loamy_tilled", "loamy_tilled",
	]

	func _neighbor_materials(pos: Vector2i) -> Array[String]:
		return fixed_neighbors


## GameData stand-in exposing exactly the ADR-042 terrain accessors, driven
## by hand-built manifests (the test_art_foundation pattern of driving entry
## Dictionaries rather than autoload lookups).
class _MockTerrainGameData extends Node:
	var materials: Dictionary = {}
	var transitions: Dictionary = {}
	var scatter: Dictionary = {}

	func get_terrain_material(material_id: String, _season: String = "") -> Dictionary:
		return materials.get(material_id, {})

	func get_terrain_transition(pair_key: String, mask_key: String, _season: String = "") -> Dictionary:
		return transitions.get(pair_key, {}).get("entries", {}).get(mask_key, {})

	func get_terrain_scatter(material_id: String, _season: String = "") -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for entry: Variant in scatter.get(material_id, []):
			out.append(entry as Dictionary)
		return out


## A GameData without any terrain accessor - the pre-ADR-042 interface the
## legacy mocks in the iso suites use; the plan must fail soft through it.
class _LegacyGameData extends Node:
	pass


func suite_name() -> String:
	return "terrain_manifest"


func run(t: Object) -> void:
	_test_game_data_manifest_wiring(t)
	_test_manifest_int_casting(t)
	_test_material_id_mapping(t)
	_test_moisture_math(t)
	_test_variant_determinism(t)
	_test_transition_lookup(t)
	_test_empty_manifest_fallback_plan(t)
	_test_partial_manifest_plan(t)
	_test_scatter_determinism(t)
	_test_material_family_completeness(t)
	_test_seasonal_material_resolution(t)
	t.completed(11)


## Every soil family now has Spring art, and each later season resolves its
## own art family. These checks pin the accessor contracts: a known material
## resolves in its requested season; unknown ids still fail soft to {} / [].
func _test_game_data_manifest_wiring(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	t.ok(bool(gd.get_terrain_material("sandy_grass").get("variants", []).size() > 0),
		"sandy_grass resolves authored Spring variants")
	t.ok(bool(gd.get_terrain_material("loamy_grass").get("variants", []).size() > 0),
		"loamy_grass now resolves real authored variants")
	t.eq(gd.get_terrain_material("does_not_exist"), {},
		"unknown material id fails soft to {}")
	t.ok(not gd.get_terrain_transition("sandy_grass|sandy_tilled", "0000").is_empty(),
		"sandy transition pair resolves a real tile entry")
	t.ok(not gd.get_terrain_transition("loamy_grass|loamy_tilled", "0000").is_empty(),
		"authored transition pair resolves a real tile entry")
	t.eq(gd.get_terrain_scatter("loamy_grass"), [],
		"empty scatter dict fails soft to []")
	gd.free()
	t.section_done("game_data manifest wiring")


## JSON numbers arrive as floats; variant/transition/scatter sprite entries
## must be int-cast at the GameData boundary (section 6.2) while scatter
## density stays a float.
func _test_manifest_int_casting(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.terrain_manifest = {
		"materials": {
			"loamy_tilled": {"variants": [{"id": "v0", "frame_w": 64.0, "frame_h": 48.0}]},
		},
		"transitions": {
			"loamy_grass|loamy_tilled": {"entries": {"1000": {"id": "tr0", "frame_w": 64.0}}},
		},
		"scatter": {
			"loamy_grass": [{"id": "s0", "frame_w": 32.0, "density": 0.08}],
		},
	}
	gd._cast_terrain_manifest_ints(gd.terrain_manifest)
	var material_entry: Dictionary = gd.get_terrain_material("loamy_tilled")
	var variants: Array = material_entry.get("variants", [])
	var variant: Dictionary = variants[0]
	t.eq(typeof(variant.get("frame_w")), TYPE_INT, "variant frame_w cast to int")
	t.eq(variant.get("frame_w"), 64, "variant frame_w value preserved")
	var transition: Dictionary = gd.get_terrain_transition("loamy_grass|loamy_tilled", "1000")
	t.eq(typeof(transition.get("frame_w")), TYPE_INT, "transition frame_w cast to int")
	var scatter_entry: Dictionary = gd.get_terrain_scatter("loamy_grass")[0]
	t.eq(typeof(scatter_entry.get("frame_w")), TYPE_INT, "scatter frame_w cast to int")
	t.eq(typeof(scatter_entry.get("density")), TYPE_FLOAT, "scatter density stays float")
	t.eq(scatter_entry.get("density"), 0.08, "scatter density value preserved")
	gd.free()
	t.section_done("manifest int casting")


## The soil -> material composition: untilled is grass, tilled is tilled,
## tilled at/above the wet threshold is tilled_wet, empty soil never maps.
func _test_material_id_mapping(t: Object) -> void:
	t.eq(FARM_RENDERER_SCRIPT.terrain_material_id("loamy", false, 0.0), "loamy_grass",
		"untilled -> <soil>_grass")
	t.eq(FARM_RENDERER_SCRIPT.terrain_material_id("loamy", true, 0.0), "loamy_tilled",
		"tilled dry -> <soil>_tilled")
	t.eq(FARM_RENDERER_SCRIPT.terrain_material_id("loamy", true, 50.0), "loamy_tilled_wet",
		"tilled at the wet threshold -> <soil>_tilled_wet")
	t.eq(FARM_RENDERER_SCRIPT.terrain_material_id("sandy", true, 49.9), "sandy_tilled",
		"just below the threshold stays dry")
	t.eq(FARM_RENDERER_SCRIPT.terrain_material_id("", true, 100.0), "",
		"empty soil never maps to a material")
	t.section_done("material id mapping")


## The flat fallback wash must stay the exact pre-ADR-042 formula (that is
## the "empty manifest == today's behaviour" guarantee), and the wet-blend
## curve must be deterministic and clamped.
func _test_moisture_math(t: Object) -> void:
	t.eq(FARM_RENDERER_SCRIPT.moisture_wash_alpha(100.0), 0.35,
		"flat-path wash at full moisture (unchanged pre-ADR-042 formula)")
	t.eq(FARM_RENDERER_SCRIPT.moisture_wash_alpha(50.0), 0.175,
		"flat-path wash at half moisture")
	t.eq(FARM_RENDERER_SCRIPT.moisture_wash_alpha(0.0), 0.0,
		"flat-path wash at zero moisture")
	t.eq(FARM_RENDERER_SCRIPT.moisture_wet_blend(0.0), 0.0, "wet blend starts at zero")
	t.eq(FARM_RENDERER_SCRIPT.moisture_wet_blend(25.0), 0.5,
		"wet blend scales moisture toward the threshold")
	t.eq(FARM_RENDERER_SCRIPT.moisture_wet_blend(100.0), 1.0, "wet blend clamps at full")
	t.section_done("moisture math")


## Variant selection is a pure coordinate hash: same cell -> same variant on
## every call, and the index always lands in [0, variant_count).
func _test_variant_determinism(t: Object) -> void:
	var pos := Vector2i(3, 4)
	var first := FARM_RENDERER_SCRIPT.terrain_variant_index(pos, 4)
	t.eq(FARM_RENDERER_SCRIPT.terrain_variant_index(pos, 4), first,
		"same cell -> same variant on repeat calls")
	t.eq(FARM_RENDERER_SCRIPT.terrain_variant_index(pos, 4), first,
		"same cell -> same variant, third call")
	t.eq(FARM_RENDERER_SCRIPT.terrain_variant_index(pos, 0), 0,
		"no variants -> index 0 (never out of range)")
	t.eq(FARM_RENDERER_SCRIPT.terrain_variant_index(pos, -3), 0,
		"negative variant count -> index 0")
	var seen: Dictionary = {}
	var in_range := true
	for y in range(5):
		for x in range(5):
			var idx := FARM_RENDERER_SCRIPT.terrain_variant_index(Vector2i(x, y), 4)
			seen[idx] = true
			in_range = in_range and idx >= 0 and idx < 4
	t.ok(in_range, "every index lands inside [0, variant_count)")
	t.ok(seen.size() >= 2, "a 5x5 grid exercises more than one variant (hash distributes)")
	t.section_done("variant determinism")


## The pure transition-lookup contract: mask chars are N,E,S,W in
## NEIGHBOR_OFFSETS order; pairs are ordered center|other; ties break to
## first-seen; empty (out-of-bounds) neighbours read as same material.
func _test_transition_lookup(t: Object) -> void:
	var grass := "loamy_grass"
	var tilled := "loamy_tilled"
	var sandy := "sandy_grass"
	var same := FARM_RENDERER_SCRIPT.transition_lookup(grass, [grass, grass, grass, grass])
	t.eq(same.get("is_boundary", true), false, "uniform neighbourhood is not a boundary")
	t.eq(same.get("mask", ""), "0000", "uniform neighbourhood mask")
	t.eq(same.get("pair", "x"), "", "uniform neighbourhood has no pair")
	var north := FARM_RENDERER_SCRIPT.transition_lookup(grass, [tilled, grass, grass, grass])
	t.eq(north.get("mask", ""), "1000", "north (0,-1) neighbour is mask char 0")
	t.eq(north.get("pair", ""), "loamy_grass|loamy_tilled", "pair is center|other, ordered")
	t.eq(north.get("is_boundary", false), true, "single differing neighbour is a boundary")
	var two := FARM_RENDERER_SCRIPT.transition_lookup(grass, [tilled, tilled, grass, grass])
	t.eq(two.get("mask", ""), "1100", "north+east neighbours mask chars 0 and 1")
	var tie := FARM_RENDERER_SCRIPT.transition_lookup(grass, [tilled, sandy, tilled, sandy])
	t.eq(tie.get("pair", ""), "loamy_grass|loamy_tilled",
		"count tie breaks to first-seen in N,E,S,W order")
	var mixed := FARM_RENDERER_SCRIPT.transition_lookup(grass, [tilled, sandy, tilled, grass])
	t.eq(mixed.get("mask", ""), "1110", "every differing edge is masked, not just the dominant other")
	t.eq(mixed.get("pair", ""), "loamy_grass|loamy_tilled", "dominant other wins the pair")
	var out_of_bounds := FARM_RENDERER_SCRIPT.transition_lookup(grass, ["", grass, grass, grass])
	t.eq(out_of_bounds.get("mask", ""), "0000",
		"empty neighbour (out of bounds) reads as same material")
	t.section_done("transition lookup")


## An unknown soil still has no matching art family and must take the exact
## flat fallback path. A legacy GameData without terrain accessors must do
## the same, even now that every shipped soil/season family is textured.
func _test_empty_manifest_fallback_plan(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var fr: _PlanRenderer = _PlanRenderer.new()
	fr.configure(null, gd, null)
	var plan: Dictionary = fr.terrain_cell_plan(
		Vector2i(3, 4), "unknown_soil", {"tilled": true, "moisture": 25.0})
	t.not_ok(plan.get("has_texture", true),
		"unknown soil -> textured path off, flat-color path reached")
	t.eq(plan.get("material_id", ""), "unknown_soil_tilled",
		"material id composed from soil/tilled/moisture")
	t.eq(plan.get("wet_blend", -1.0), 0.5,
		"wet blend still reported when the flat path is chosen")
	fr.free()
	gd.free()

	var legacy = _LegacyGameData.new()
	var fr2: _PlanRenderer = _PlanRenderer.new()
	fr2.configure(null, legacy, null)
	var legacy_plan: Dictionary = fr2.terrain_cell_plan(Vector2i(0, 0), "loamy", {})
	t.not_ok(legacy_plan.get("has_texture", true),
		"a GameData without terrain accessors routes to the flat path")
	fr2.free()
	legacy.free()
	t.section_done("empty manifest fallback plan")


## With a populated mock manifest: a resolvable variant textures the cell; a
## boundary prefers its transition tile and degrades to the base variant when
## the transition is missing; partial moisture resolves the wet overlay;
## an entry with no loadable texture stays on the flat path.
func _test_partial_manifest_plan(t: Object) -> void:
	var variant_a := {"id": "terrain_loamy_tilled_0", "texture": ROCK_TEXTURE,
		"frame_w": 64.0, "frame_h": 64.0}
	var variant_wet := {"id": "terrain_loamy_tilled_wet_0", "texture": ROCK_TEXTURE,
		"frame_w": 64.0, "frame_h": 64.0}
	var no_texture := {"id": "terrain_sandy_tilled_0"}
	var gd = _MockTerrainGameData.new()
	gd.materials = {
		"loamy_tilled": {"variants": [variant_a]},
		"loamy_tilled_wet": {"variants": [variant_wet]},
		"sandy_tilled": {"variants": [no_texture]},
	}
	gd.transitions = {}
	var fr: _PlanRenderer = _PlanRenderer.new()
	fr.configure(null, gd, null)

	fr.fixed_neighbors = ["loamy_tilled", "loamy_tilled", "loamy_tilled", "loamy_tilled"]
	var no_boundary: Dictionary = fr.terrain_cell_plan(
		Vector2i(5, 6), "loamy", {"tilled": true, "moisture": 0.0})
	t.ok(no_boundary.get("has_texture", false), "resolvable variant -> textured path")
	t.eq(no_boundary.get("base_entry", {}), variant_a, "no boundary -> base variant entry")
	t.eq(no_boundary.get("pair_key", "x"), "", "no boundary -> no transition pair")

	fr.fixed_neighbors = ["loamy_grass", "loamy_grass", "loamy_grass", "loamy_grass"]
	var boundary: Dictionary = fr.terrain_cell_plan(
		Vector2i(5, 6), "loamy", {"tilled": true, "moisture": 0.0})
	t.eq(boundary.get("pair_key", ""), "loamy_tilled|loamy_grass",
		"boundary pair is center|other, ordered")
	t.eq(boundary.get("mask_key", ""), "1111",
		"all four edges bordering another material are masked")
	t.eq(boundary.get("base_entry", {}), variant_a,
		"missing transition tile degrades to the base variant, not flat color")
	t.ok(boundary.get("has_texture", false), "degraded transition still textured")

	var wet: Dictionary = fr.terrain_cell_plan(
		Vector2i(5, 6), "loamy", {"tilled": true, "moisture": 25.0})
	t.eq(wet.get("wet_blend", -1.0), 0.5, "partial moisture reports the wet blend alpha")
	t.eq(wet.get("wet_entry", {}), variant_wet,
		"wet overlay resolves to the tilled_wet variant")
	t.ok(wet.get("wet_texture", null) != null, "wet overlay texture resolves")

	var missing: Dictionary = fr.terrain_cell_plan(
		Vector2i(7, 8), "sandy", {"tilled": true, "moisture": 0.0})
	t.not_ok(missing.get("has_texture", true),
		"variant with no loadable texture -> flat path")

	fr.free()
	gd.free()
	t.section_done("partial manifest plan")


## Scatter selection and placement are coordinate hashes too - deterministic
## per cell + entry index, zero density never draws, density 1.0 always does.
func _test_scatter_determinism(t: Object) -> void:
	var pos := Vector2i(9, 2)
	t.not_ok(FARM_RENDERER_SCRIPT.scatter_should_draw(pos, 0, 0.0),
		"zero density never draws")
	var roll := FARM_RENDERER_SCRIPT.scatter_should_draw(pos, 0, 0.08)
	t.eq(FARM_RENDERER_SCRIPT.scatter_should_draw(pos, 0, 0.08), roll,
		"same cell + same entry -> same scatter decision")
	t.ok(FARM_RENDERER_SCRIPT.scatter_should_draw(pos, 0, 1.0),
		"density 1.0 always draws")
	var off := FARM_RENDERER_SCRIPT.scatter_offset(pos, 0)
	t.eq(FARM_RENDERER_SCRIPT.scatter_offset(pos, 0), off, "scatter offset is deterministic")
	t.ok(off.x >= -0.5 and off.x <= 0.5 and off.y >= -0.5 and off.y <= 0.5,
		"scatter offset stays inside the tile bounds")
	t.section_done("scatter determinism")


## The shipped manifest declares all three surfaces for every soil in
## soil_types.json - the schema's material vocabulary, so a future texture
## pass only ever fills entries, never adds new material ids to code.
func _test_material_family_completeness(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	for soil: String in ["loamy", "sandy", "rocky"]:
		t.ok(not gd.get_terrain_material("%s_grass" % soil).is_empty()
			and not gd.get_terrain_material("%s_tilled" % soil).is_empty()
			and not gd.get_terrain_material("%s_tilled_wet" % soil).is_empty(),
			"manifest declares all three surfaces for %s soil" % soil)
	var all_have_variants := true
	for soil_loop: String in ["loamy", "sandy", "rocky"]:
		for surface: String in ["grass", "tilled", "tilled_wet"]:
			all_have_variants = all_have_variants \
				and gd.get_terrain_material("%s_%s" % [soil_loop, surface]).has("variants")
	t.ok(all_have_variants,
		"every declared material entry carries a variants key (schema-valid)")
	gd.free()
	t.section_done("material family completeness")


## Seasonal art selects through GameData's manifest seam, then FarmRenderer
## refreshes only its cached rendering plans. The material id itself stays
## season-neutral, preserving the simulation/grid contract.
func _test_seasonal_material_resolution(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	for season: String in ["spring", "summer", "autumn", "winter"]:
		for soil: String in ["loamy", "sandy", "rocky"]:
			var entry: Dictionary = gd.get_terrain_material("%s_grass" % soil, season)
			t.ok(not entry.get("variants", []).is_empty(),
				"%s %s grass resolves authored variants" % [season, soil])
	var spring_entry: Dictionary = gd.get_terrain_material("loamy_grass", "spring")
	var winter_entry: Dictionary = gd.get_terrain_material("loamy_grass", "winter")
	var spring_path := str((spring_entry.get("variants", []) as Array)[0].get("texture", ""))
	var winter_path := str((winter_entry.get("variants", []) as Array)[0].get("texture", ""))
	t.ok(not spring_path.contains("/winter/"), "Spring uses the canonical Spring tile path")
	t.ok(winter_path.contains("/winter/"), "Winter resolves its dedicated tile path")
	t.eq(gd.get_terrain_material("loamy_grass", "unknown_season"), spring_entry,
		"unknown season fails soft to the declared Spring default")
	var fr: _PlanRenderer = _PlanRenderer.new()
	fr.configure(null, gd, null)
	fr.set_terrain_season("winter")
	var plan: Dictionary = fr.terrain_cell_plan(Vector2i(2, 2), "loamy", {"tilled": false})
	t.eq(plan.get("material_id", ""), "loamy_grass",
		"seasonal rendering keeps the simulation material id unchanged")
	t.ok(str((plan.get("base_entry", {}) as Dictionary).get("texture", "")).contains("/winter/"),
		"renderer selects Winter art after its presentation-only season update")
	fr.free()
	gd.free()
	t.section_done("seasonal material resolution")
