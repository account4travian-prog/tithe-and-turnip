extends RefCounted
## Player-home interior art is a presentation-only composition: one clean
## shell texture plus independent fixtures defined in zones.json. These tests
## exercise the data and grid-space seam without needing a live CanvasItem.

const FARM_RENDERER_SCRIPT := preload("res://scripts/world/farm_renderer.gd")
const FEATURE_RENDERER_SCRIPT := preload("res://scripts/world/feature_renderer.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")
const WORLD_VISUALS_SCRIPT := preload("res://scripts/world/world_visuals.gd")

const HOME_ZONE_ID := "player_home_interior"
const SHELL_ID := "interior_player_home_shell"
const DOOR_ID := "interior_player_home_door_south"
const WINDOW_ID := "interior_player_home_window_north"


func suite_name() -> String:
	return "interior_visuals"


func run(t: Object) -> void:
	_test_home_shell_and_fixture_data(t)
	_test_interior_sprite_entries(t)
	_test_cutaway_wall_convention(t)
	_test_fixture_grid_positions(t)
	_test_collision_edges_stay_outside_room(t)
	_test_feature_renderer_builds_live_interior_sprites(t)
	t.completed(39)


func _test_home_shell_and_fixture_data(t: Object) -> void:
	var gd := GAME_DATA_SCRIPT.new()
	gd.load_all()
	var visual: Dictionary = gd.get_zone_interior_visual(HOME_ZONE_ID)
	t.eq(str(visual.get("shell_sprite_id", "")), SHELL_ID,
		"home interior selects the clean shell sprite")
	var fixtures: Array = visual.get("fixtures", [])
	t.eq(fixtures.size(), 2, "home interior has independent door + window records")
	var door := fixtures[0] as Dictionary
	var window := fixtures[1] as Dictionary
	t.eq(str(door.get("sprite_id", "")), DOOR_ID, "south door is an overlay sprite")
	t.eq(str(door.get("side", "")), "south", "door keeps the farmhouse south orientation")
	t.eq(typeof(door.get("index", -1)), TYPE_INT, "door index is int-cast at GameData boundary")
	t.eq(str(window.get("sprite_id", "")), WINDOW_ID, "north window is an overlay sprite")
	t.eq(str(window.get("side", "")), "north", "window is attached to the visible north wall")
	t.eq(typeof(window.get("index", -1)), TYPE_INT, "window index is int-cast at GameData boundary")
	gd.free()
	t.section_done("home shell + fixtures")


func _test_interior_sprite_entries(t: Object) -> void:
	var gd := GAME_DATA_SCRIPT.new()
	gd.load_all()
	for sprite_id: String in [SHELL_ID, DOOR_ID, WINDOW_ID]:
		var entry: Dictionary = gd.get_sprite(sprite_id)
		t.eq(str(entry.get("kind", "")), "static", "%s is a static presentation sprite" % sprite_id)
		t.ok(FileAccess.file_exists(str(entry.get("texture", ""))),
			"%s texture is staged in runtime assets" % sprite_id)
		t.ok(SpriteManifest.get_static_texture(entry) != null,
			"%s texture loads through SpriteManifest" % sprite_id)
		t.ok(SpriteManifest.get_draw_scale(entry) > 0.0,
			"%s has a positive manifest draw scale" % sprite_id)
	t.eq(SpriteManifest.get_draw_scale({"frame_h": 96.0, "height_tiles": 1.0}), 1.0 / 3.0,
		"ordinary sprites retain height_tiles scale fallback (ADR-043: TILE_H 32)")
	t.eq(SpriteManifest.get_draw_scale({"draw_scale": 0.4}), 0.4,
		"interior entries can opt into explicit composition scale")
	gd.free()
	t.section_done("interior sprite manifest")


func _test_cutaway_wall_convention(t: Object) -> void:
	t.eq(FARM_RENDERER_SCRIPT.interior_visible_wall_sides(), ["north", "west"],
		"only north + west walls remain visible in an interior")
	t.not_ok(FARM_RENDERER_SCRIPT.interior_visible_wall_sides().has("east"),
		"east wall stays cut away")
	t.not_ok(FARM_RENDERER_SCRIPT.interior_visible_wall_sides().has("south"),
		"south wall stays cut away")
	t.section_done("cutaway wall convention")


func _test_fixture_grid_positions(t: Object) -> void:
	t.eq(FARM_RENDERER_SCRIPT.interior_fixture_grid_position("north", 6, 10, 7), Vector2(6.5, 0.0),
		"north window rests on the north perimeter in grid space")
	t.eq(FARM_RENDERER_SCRIPT.interior_fixture_grid_position("south", 5, 10, 7), Vector2(5.5, 7.0),
		"south door rests on the south perimeter in grid space")
	t.eq(FARM_RENDERER_SCRIPT.interior_fixture_grid_position("west", 3, 10, 7), Vector2(0.0, 3.5),
		"west fixtures resolve to the west perimeter")
	t.eq(FARM_RENDERER_SCRIPT.interior_fixture_grid_position("east", 2, 10, 7), Vector2(10.0, 2.5),
		"east fixtures resolve to the east perimeter")
	t.eq(FARM_RENDERER_SCRIPT.interior_fixture_grid_position("north", 99, 10, 7), Vector2(9.5, 0.0),
		"fixture indices clamp within the room extent")
	t.section_done("fixture grid positions")


func _test_collision_edges_stay_outside_room(t: Object) -> void:
	const WIDTH := 10
	const HEIGHT := 7
	const THICKNESS := 6.0
	t.eq(FEATURE_RENDERER_SCRIPT.interior_collision_wall_origin("north", WIDTH, HEIGHT, THICKNESS),
		Vector2(0.0, -THICKNESS), "north collision begins outside the rendered perimeter")
	t.eq(FEATURE_RENDERER_SCRIPT.interior_collision_wall_origin("west", WIDTH, HEIGHT, THICKNESS),
		Vector2(-THICKNESS, 0.0), "west collision begins outside the rendered perimeter")
	t.eq(FEATURE_RENDERER_SCRIPT.interior_collision_wall_origin("south", WIDTH, HEIGHT, THICKNESS),
		Vector2(0.0, 224.0), "south collision begins at the room's outer tile edge")
	t.eq(FEATURE_RENDERER_SCRIPT.interior_collision_wall_origin("east", WIDTH, HEIGHT, THICKNESS),
		Vector2(320.0, 0.0), "east collision begins at the room's outer tile edge")
	t.section_done("interior collision edge placement")


func _test_feature_renderer_builds_live_interior_sprites(t: Object) -> void:
	var gd := GAME_DATA_SCRIPT.new()
	gd.load_all()
	var world_visuals := WORLD_VISUALS_SCRIPT.new()
	var renderer := FEATURE_RENDERER_SCRIPT.new()
	renderer.configure(gd, world_visuals)
	renderer.set_active_zone(HOME_ZONE_ID)
	var visuals := world_visuals.get_children()
	t.eq(visuals.size(), 3, "interior builds shell plus independent door and window sprites")
	t.eq(str(visuals[0].name), "InteriorShellVisual", "shell is on the live WorldVisuals layer")
	t.ok((visuals[0] as Node).get_child(0) is Sprite2D,
		"shell root contains a Sprite2D")
	t.eq(str(visuals[1].name), "InteriorFixture_%s" % DOOR_ID,
		"south door remains an independently placed sprite")
	t.eq(str(visuals[2].name), "InteriorFixture_%s" % WINDOW_ID,
		"north window remains an independently placed sprite")
	renderer.free()
	world_visuals.free()
	gd.free()
	t.section_done("live interior WorldVisuals composition")
