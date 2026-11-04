extends RefCounted
## Coverage for Sprint 16 WS-A (world dressing, ADR-041): the manifest
## entries in data/sprites_world_dressing.json and FarmRenderer's forage
## spawn-point texturing (scripts/world/farm_renderer.gd). The real spawn
## site for world dressing is ADR-022's forage cells - there is no separate
## decorative tree/bush placement mechanism in this codebase (farm_map.json
## feature tiles are all fixed fixtures, and feature_renderer.gd renders
## those) - so this suite proves the forage mapping is complete, the
## manifest entries point at real staged textures, and the StaticPropVisual
## lifecycle (create on spawn, free on gather, rebuild on zone change, no
## prop == primitive fallback) stays correct.

const FARM_RENDERER_SCRIPT := preload("res://scripts/world/farm_renderer.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")

const ROCK_ID := "world_dressing_rock_flint"
const HERB_ID := "world_dressing_plant_herb"
const BERRY_ID := "world_dressing_plant_berry"
const ONION_ID := "world_dressing_plant_onion"
const WOOD_ID := "world_dressing_tree_broken"

const ALL_IDS: Array[String] = [ROCK_ID, HERB_ID, BERRY_ID, ONION_ID, WOOD_ID]


## A minimal FarmGrid-shaped node: 4x4 cells, tile_changed, and the exact
## method surface FarmRenderer's prop management reads (get_grid_size,
## has_forage, get_cell). Forage cells are injected via set_forage(), which
## emits tile_changed exactly like the real grid's gather/spawn paths.
class _MockFarmGrid extends Node:
	signal tile_changed(pos: Vector2i)

	var size := Vector2i(4, 4)
	var cells: Dictionary = {}

	func _init() -> void:
		for y in range(size.y):
			for x in range(size.x):
				cells[Vector2i(x, y)] = {"forage_item_id": "", "forage_yield": 0}

	func get_grid_size() -> Vector2i:
		return size

	func has_forage(pos: Vector2i) -> bool:
		return cells.has(pos) \
			and not str(cells[pos].get("forage_item_id", "")).is_empty()

	func get_cell(pos: Vector2i) -> Dictionary:
		return cells.get(pos, {})

	func set_forage(pos: Vector2i, item_id: String) -> void:
		cells[pos]["forage_item_id"] = item_id
		cells[pos]["forage_yield"] = 1 if not item_id.is_empty() else 0
		tile_changed.emit(pos)


## A GameData-shaped node with no sprite lookup - the headless/mock path
## that must fail soft to the primitive glyph rather than crash.
class _MockGameDataNoSprites extends Node:
	func get_map_width() -> int:
		return 4

	func get_map_height() -> int:
		return 4

	func get_soil_properties(_soil: String) -> Dictionary:
		return {"color": "#8B7355"}


func suite_name() -> String:
	return "art_dressing"


func run(t: Object) -> void:
	_test_manifest_entries_are_complete(t)
	_test_manifest_ints_cast_at_boundary(t)
	_test_forage_sprite_mapping(t)
	_test_forage_sprite_id_unknown(t)
	_test_has_forage_texture_gates_on_manifest(t)
	_test_no_props_without_world_visuals(t)
	_test_prop_lifecycle(t)
	t.completed(50)


## Every WS-A sprite id must resolve through the real GameData boundary to a
## static entry whose texture file exists on disk (assets are staged under
## res://assets/sprites/world_dressing) and whose anchor/scale fields are
## sane - plus apply_static must succeed against the real staged texture,
## the end-to-end path the running game uses. Runs after the --import gate,
## so the textures are real imported resources, not hand-built stand-ins.
func _test_manifest_entries_are_complete(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	for sprite_id: String in ALL_IDS:
		var entry: Dictionary = gd.get_sprite(sprite_id)
		t.ok(not entry.is_empty(), "manifest entry exists for '%s'" % sprite_id)
		t.eq(str(entry.get("kind", "")), "static", "entry '%s' is a static sprite" % sprite_id)
		var path := str(entry.get("texture", ""))
		t.ok(not path.is_empty(), "entry '%s' has a texture path" % sprite_id)
		t.ok(FileAccess.file_exists(path), "entry '%s' texture exists at %s" % [sprite_id, path])
		t.ok(float(entry.get("frame_w", 0.0)) > 0.0 and float(entry.get("frame_h", 0.0)) > 0.0,
			"entry '%s' has positive frame dimensions" % sprite_id)
		t.ok(float(entry.get("anchor_x", -1.0)) >= 0.0 and float(entry.get("anchor_y", -1.0)) >= 0.0,
			"entry '%s' has non-negative anchor" % sprite_id)
		t.ok(float(entry.get("height_tiles", 0.0)) > 0.0,
			"entry '%s' has a positive height_tiles scale" % sprite_id)
		var sprite := Sprite2D.new()
		t.ok(SpriteManifest.apply_static(sprite, entry),
			"apply_static succeeds for real staged texture '%s'" % sprite_id)
		t.ok(sprite.visible and sprite.texture != null,
			"sprite for '%s' is visible with a loaded texture" % sprite_id)
		sprite.free()
	gd.free()
	t.section_done("manifest entries complete")


## CLAUDE.md section 6.2: JSON numbers arrive as floats; GameData casts the
## manifest's integer fields at the boundary. The renderer's scale/anchor
## math must see ints, never floats (the same contract test_art_foundation
## covers with hand-built entries - here against the real file).
func _test_manifest_ints_cast_at_boundary(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var entry: Dictionary = gd.get_sprite(ROCK_ID)
	t.eq(typeof(entry.get("frame_w")), TYPE_INT, "frame_w cast to int by GameData")
	t.eq(typeof(entry.get("frame_h")), TYPE_INT, "frame_h cast to int by GameData")
	t.eq(typeof(entry.get("anchor_x")), TYPE_INT, "anchor_x cast to int by GameData")
	t.eq(typeof(entry.get("anchor_y")), TYPE_INT, "anchor_y cast to int by GameData")
	gd.free()
	t.section_done("manifest int casting")


## Every item in FORAGE_SPRITE_IDS must (a) still have a FORAGE_GLYPH_CATEGORY
## fallback - the primitive glyph remains the no-asset path - and (b) resolve
## to a real manifest entry through GameData. Together these prove the
## textured path never silently loses the fallback the playtest fix depends
## on (test_iso_terrain's completeness test keeps guarding the glyph side).
func _test_forage_sprite_mapping(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var mapping: Dictionary = FARM_RENDERER_SCRIPT.FORAGE_SPRITE_IDS
	t.ok(mapping.size() >= 5, "rock + plant types + wood are all mapped")
	for item_id: Variant in mapping:
		t.ok(FARM_RENDERER_SCRIPT.FORAGE_GLYPH_CATEGORY.has(item_id),
			"mapped forage item '%s' keeps a primitive glyph fallback" % item_id)
		var sprite_id := str(mapping[item_id])
		t.ok(not gd.get_sprite(sprite_id).is_empty(),
			"mapped sprite id '%s' exists in GameData" % sprite_id)
	var fr = FARM_RENDERER_SCRIPT.new()
	t.eq(fr.forage_sprite_id("flint"), ROCK_ID, "flint maps to the rock sprite")
	t.eq(fr.forage_sprite_id("wild_herb"), HERB_ID, "wild_herb maps to the herb sprite")
	t.eq(fr.forage_sprite_id("wild_berry"), BERRY_ID, "wild_berry maps to the berry bush sprite")
	t.eq(fr.forage_sprite_id("wild_onion"), ONION_ID, "wild_onion maps to the simple bush sprite")
	t.eq(fr.forage_sprite_id("wood"), WOOD_ID, "wood maps to the broken tree sprite")
	fr.free()
	gd.free()
	t.section_done("forage sprite mapping")


func _test_forage_sprite_id_unknown(t: Object) -> void:
	var fr = FARM_RENDERER_SCRIPT.new()
	t.eq(fr.forage_sprite_id("spoiled_crop"), "",
		"unintegrated forage (spoiled_crop) maps to no sprite id")
	t.eq(fr.forage_sprite_id("does_not_exist"), "",
		"unknown forage item maps to no sprite id")
	fr.free()
	t.section_done("unknown forage sprite id")


## has_forage_texture() is the shared gate for prop creation and the _draw()
## glyph skip: real manifest + loadable texture -> true; missing entry ->
## false; GameData-shaped node without get_sprite -> false (mock/headless
## fallback, never a crash).
func _test_has_forage_texture_gates_on_manifest(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var fr = FARM_RENDERER_SCRIPT.new()
	fr.configure(null, gd, null)
	t.ok(fr.has_forage_texture(ROCK_ID), "real rock entry is loadable")
	t.ok(fr.has_forage_texture(HERB_ID), "real herb entry is loadable")
	t.not_ok(fr.has_forage_texture("does_not_exist"),
		"unknown sprite id fails the gate (primitive fallback)")
	fr.free()
	var mock = _MockGameDataNoSprites.new()
	var fr2 = FARM_RENDERER_SCRIPT.new()
	fr2.configure(null, mock, null)
	t.not_ok(fr2.has_forage_texture(ROCK_ID),
		"GameData-shaped node without get_sprite fails the gate safely")
	fr2.free()
	mock.free()
	gd.free()
	t.section_done("has_forage_texture gate")


## Without a WorldVisuals reference (off-tree tests, any pre-_ready path) the
## renderer must manage no props at all - _draw() then draws the primitive
## glyph exactly as before. This is the same fail-soft contract
## SpriteManifest.apply_static/PlayerVisual follow.
func _test_no_props_without_world_visuals(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var grid = _MockFarmGrid.new()
	grid.set_forage(Vector2i(1, 1), "flint")
	var fr = FARM_RENDERER_SCRIPT.new()
	fr.configure(grid, gd, null)
	t.eq(fr._forage_props.size(), 0,
		"no WorldVisuals -> no textured props, primitive glyph is the fallback")
	fr.free()
	grid.free()
	gd.free()
	t.section_done("no WorldVisuals fallback")


## The full prop lifecycle against the real manifest: props appear exactly
## on forage cells with a mapped, loadable texture; they are freed when the
## cell is gathered; a new spawn gets a new prop; an unmapped item
## (spoiled_crop) stays glyph-only; and dropping WorldVisuals frees every
## prop. The renderer and visuals stay OFF-tree: _ready() does not run for
## nodes added during the harness's _initialize(), so the test drives
## set_world_visuals() (the same public seam _ready() itself calls in the
## running game) directly, and an off-tree renderer never gets _draw()
## invoked against the mock grid. Texture visibility itself is NOT asserted
## here: StaticPropVisual.configure resolves its entry through
## SpriteManifest.get_entry()/get_node("/root/GameData"), and absolute paths
## are unusable until the SceneTree is active (after _initialize), so that
## lookup fails soft in this harness - the direct apply_static-on-real-
## texture assertions in _test_manifest_entries_are_complete cover the
## visible-texture outcome, and _test_no_props_without_world_visuals covers
## the no-asset fallback.
func _test_prop_lifecycle(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()

	var visuals := WorldVisuals.new()
	var grid = _MockFarmGrid.new()
	grid.set_forage(Vector2i(1, 1), "flint")
	grid.set_forage(Vector2i(2, 2), "wild_herb")
	var fr = FARM_RENDERER_SCRIPT.new()
	fr.set_world_visuals(visuals)
	fr.configure(grid, gd, null)

	t.eq(fr._forage_props.size(), 2, "two forage cells get two props")
	t.ok(fr._forage_props.has(Vector2i(1, 1)), "flint cell has a prop")
	t.ok(fr._forage_props.has(Vector2i(2, 2)), "herb cell has a prop")
	var prop: StaticPropVisual = fr._forage_props[Vector2i(1, 1)]
	t.eq(prop.position, IsoProjection.grid_to_screen(Vector2(2.0, 2.0)),
		"prop sits at the cell's projected south-east corner (sort anchor)")
	var sprite := prop.get_child(0) as Sprite2D
	t.ok(sprite != null, "prop carries a Sprite2D child (texture visibility is the manifest test's assertion)")

	grid.set_forage(Vector2i(1, 1), "")
	t.not_ok(fr._forage_props.has(Vector2i(1, 1)),
		"gathering the cell frees its prop")
	t.eq(fr._forage_props.size(), 1, "only the gathered cell's prop is freed")

	grid.set_forage(Vector2i(0, 0), "wood")
	t.ok(fr._forage_props.has(Vector2i(0, 0)),
		"a new day-pass spawn gets a textured prop")
	t.eq(fr._forage_props.size(), 2, "new spawn restores the prop count")

	grid.set_forage(Vector2i(3, 3), "spoiled_crop")
	t.not_ok(fr._forage_props.has(Vector2i(3, 3)),
		"unmapped forage item gets no prop - primitive glyph remains")

	fr.set_world_visuals(null)
	t.eq(fr._forage_props.size(), 0,
		"dropping WorldVisuals frees every prop (full fallback)")

	fr.free()
	visuals.free()
	grid.free()
	gd.free()
	t.section_done("prop lifecycle")
