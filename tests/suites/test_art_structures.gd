extends RefCounted
## Coverage for ADR-041 Sprint 16 WS-B (structures): the real manifest
## entries in data/sprites_structures.json, SpriteManifest's static-sprite
## math against those real entries (texture load, frame crop, anchor, scale,
## per-entry filter), StructureVisual's textured-child path with the
## primitive extruded-box as the automatic fallback, and BuildingRenderer
## wiring the building id through to the visual while the ghost stays
## primitive.
##
## Mirrors test_art_foundation.gd's off-tree pattern: suites run from
## run_tests.gd's _initialize, where /root/GameData is not reliably
## available, so the manifest boundary is driven through a real GameData
## instance and StructureVisual consumes the parsed entry directly (the
## caller-owned lookup pattern BuildingRenderer uses - no absolute-path
## get_node reach). The BuildingRenderer assertions exercise the real
## textured path end-to-end against the live GameData instance.

const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")
const BUILDING_MANAGER_SCRIPT := preload("res://scripts/autoloads/building_manager.gd")
const PLAYER_STATE_SCRIPT := preload("res://scripts/autoloads/player_state.gd")

const COTTAGE_TEXTURE := "res://assets/sprites/structures/home1pixelstyle/exterior.png"
const SHED_TEXTURE := "res://assets/sprites/structures/workshop1/Exterior_house.png"


func suite_name() -> String:
	return "art_structures"


func run(t: Object) -> void:
	_test_cottage_upgrade_manifest_entry(t)
	_test_drying_shed_manifest_entry(t)
	_test_manifest_files_exist(t)
	_test_manifest_entries_are_real_building_ids(t)
	_test_apply_static_cottage_entry(t)
	_test_apply_static_drying_shed_entry(t)
	_test_apply_static_empty_fails_soft(t)
	_test_structure_visual_textured_child(t)
	_test_structure_visual_textured_in_progress_modulate(t)
	_test_structure_visual_primitive_fallback(t)
	_test_building_renderer_passes_building_id(t)
	_test_building_renderer_ghost_stays_primitive(t)
	t.completed(72)


func _make_game_data() -> Object:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	return gd


## The flagship pick: the player's cottage upgrade (3x3 in buildings.json)
## backed by Home1PixelStyle's exterior sheet. The sheet is a vertical strip
## of separate sprites; the first sprite (rows 0-318) is a complete cottage,
## so frame_h 319 crops the lower unrelated sprites out and anchor_y 319
## plants its feet on the footprint's projected corner.
func _test_cottage_upgrade_manifest_entry(t: Object) -> void:
	var gd := _make_game_data()
	var entry: Dictionary = gd.get_sprite("cottage_upgrade")
	t.not_ok(entry.is_empty(), "cottage_upgrade has a manifest entry")
	t.eq(str(entry.get("id")), "cottage_upgrade", "manifest id matches the lookup key")
	t.eq(str(entry.get("kind")), "static", "cottage_upgrade is a static sprite")
	t.eq(str(entry.get("texture")), COTTAGE_TEXTURE, "cottage_upgrade points at Home1PixelStyle's exterior sheet")
	t.eq(int(entry.get("frame_w")), 240, "cottage frame width covers the sheet's full width")
	t.eq(int(entry.get("frame_h")), 319, "cottage frame height crops the first whole-house sprite")
	t.eq(int(entry.get("anchor_x")), 120, "cottage anchor x centres the sprite on the footprint corner")
	t.eq(int(entry.get("anchor_y")), 319, "cottage anchor y plants the sprite's feet at the frame bottom")
	t.eq(float(entry.get("height_tiles")), 2.5, "cottage renders 2.5 tiles tall (120px at TILE_H 48)")
	t.eq(int(entry.get("footprint_w")), 3, "cottage manifest footprint matches buildings.json")
	t.eq(int(entry.get("footprint_h")), 3, "cottage manifest footprint height matches buildings.json")
	t.eq(str(entry.get("filter")), "nearest", "pixel-art Home1PixelStyle uses nearest filtering")
	gd.free()
	t.section_done("cottage_upgrade manifest entry")


## The second pick: the drying shed (2x2) backed by Workshop1's exterior
## sheet. The sheet holds two buildings side by side; the left sprite (x
## 1-255, y 10-205) is a complete workshop, so frame 256x206 crops the right
## building out and its feet land at the frame bottom.
func _test_drying_shed_manifest_entry(t: Object) -> void:
	var gd := _make_game_data()
	var entry: Dictionary = gd.get_sprite("drying_shed")
	t.not_ok(entry.is_empty(), "drying_shed has a manifest entry")
	t.eq(str(entry.get("id")), "drying_shed", "manifest id matches the lookup key")
	t.eq(str(entry.get("kind")), "static", "drying_shed is a static sprite")
	t.eq(str(entry.get("texture")), SHED_TEXTURE, "drying_shed points at Workshop1's exterior sheet")
	t.eq(int(entry.get("frame_w")), 256, "shed frame width crops the left workshop sprite")
	t.eq(int(entry.get("frame_h")), 206, "shed frame height covers the workshop sprite's content")
	t.eq(int(entry.get("anchor_x")), 128, "shed anchor x centres the sprite on the footprint corner")
	t.eq(int(entry.get("anchor_y")), 206, "shed anchor y plants the sprite's feet at the frame bottom")
	t.eq(float(entry.get("height_tiles")), 2.0, "shed renders 2.0 tiles tall (96px at TILE_H 48)")
	t.eq(int(entry.get("footprint_w")), 2, "shed manifest footprint matches buildings.json")
	t.eq(int(entry.get("footprint_h")), 2, "shed manifest footprint height matches buildings.json")
	t.eq(str(entry.get("filter")), "linear", "painted Workshop1 uses linear filtering")
	gd.free()
	t.section_done("drying_shed manifest entry")


func _test_manifest_files_exist(t: Object) -> void:
	t.ok(FileAccess.file_exists(COTTAGE_TEXTURE), "cottage texture path resolves to a real file")
	t.ok(FileAccess.file_exists(SHED_TEXTURE), "shed texture path resolves to a real file")
	t.section_done("manifest files exist")


## Guards against manifest/buildings drift: every manifest entry WS-B ships
## must name a building the game can actually spawn.
func _test_manifest_entries_are_real_building_ids(t: Object) -> void:
	var gd := _make_game_data()
	t.not_ok(gd.get_building("cottage_upgrade").is_empty(), "cottage_upgrade exists in buildings.json")
	t.not_ok(gd.get_building("drying_shed").is_empty(), "drying_shed exists in buildings.json")
	gd.free()
	t.section_done("manifest entries are real building ids")


func _test_apply_static_cottage_entry(t: Object) -> void:
	var gd := _make_game_data()
	var entry: Dictionary = gd.get_sprite("cottage_upgrade")
	var sprite := Sprite2D.new()
	var applied := SpriteManifest.apply_static(sprite, entry)
	t.ok(applied, "apply_static succeeds for the real cottage entry")
	t.ok(sprite.visible, "cottage sprite is visible after apply_static")
	t.ok(sprite.texture != null, "cottage sprite carries the loaded texture")
	t.eq(sprite.region_enabled, true, "cottage sprite region mode is on")
	t.eq(sprite.region_rect, Rect2(0.0, 0.0, 240.0, 319.0), "cottage region is the whole-house crop")
	var scale := SpriteManifest.get_scale(entry)
	t.ok(sprite.scale.is_equal_approx(Vector2(scale, scale)), "cottage sprite scale matches height_tiles math")
	t.ok(sprite.position.is_equal_approx(-SpriteManifest.get_anchor(entry) * scale),
		"cottage sprite anchor pixel lands on the node origin")
	t.eq(sprite.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "cottage sprite uses nearest filtering")
	sprite.free()
	gd.free()
	t.section_done("apply_static cottage entry")


func _test_apply_static_drying_shed_entry(t: Object) -> void:
	var gd := _make_game_data()
	var entry: Dictionary = gd.get_sprite("drying_shed")
	var sprite := Sprite2D.new()
	var applied := SpriteManifest.apply_static(sprite, entry)
	t.ok(applied, "apply_static succeeds for the real shed entry")
	t.ok(sprite.visible, "shed sprite is visible after apply_static")
	t.ok(sprite.texture != null, "shed sprite carries the loaded texture")
	t.eq(sprite.region_rect, Rect2(0.0, 0.0, 256.0, 206.0), "shed region is the left-building crop")
	var scale := SpriteManifest.get_scale(entry)
	t.ok(sprite.scale.is_equal_approx(Vector2(scale, scale)), "shed sprite scale matches height_tiles math")
	t.ok(sprite.position.is_equal_approx(-SpriteManifest.get_anchor(entry) * scale),
		"shed sprite anchor pixel lands on the node origin")
	t.eq(sprite.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR, "shed sprite uses linear filtering")
	sprite.free()
	gd.free()
	t.section_done("apply_static drying_shed entry")


func _test_apply_static_empty_fails_soft(t: Object) -> void:
	var sprite := Sprite2D.new()
	var applied := SpriteManifest.apply_static(sprite, {})
	t.not_ok(applied, "apply_static reports failure for an entry with no texture")
	t.not_ok(sprite.visible, "sprite is hidden rather than left showing an empty texture")
	var visual := StructureVisual.new()
	visual._apply_sprite_entry({})
	t.not_ok(visual._texture_active, "StructureVisual keeps the primitive path when the entry builds nothing")
	visual.free()
	sprite.free()
	t.section_done("apply_static fail-soft")


## The textured-child contract: configure() records the id, footprint, and
## position exactly as before and consumes the caller-resolved entry; the
## child's anchor pixel lands on the node origin so the y-sort origin never
## moves.
func _test_structure_visual_textured_child(t: Object) -> void:
	var gd := _make_game_data()
	var entry: Dictionary = gd.get_sprite("cottage_upgrade")
	var visual := StructureVisual.new()
	visual.configure(Rect2i(5, 5, 3, 3), Color.WHITE, IsoProjection.TILE_H * 1.3,
		StructureVisual.Accent.NONE, Color.WHITE, Color.WHITE, "cottage_upgrade", entry)
	t.eq(visual.sprite_id, "cottage_upgrade", "configure records the sprite id")
	t.eq(visual.footprint, Rect2i(5, 5, 3, 3), "configure keeps the 3x3 cottage footprint")
	t.ok(visual.position.is_equal_approx(IsoProjection.grid_to_screen(Vector2(8, 8))),
		"configure keeps the footprint's projected south-east corner as the sort origin")
	t.ok(visual._texture_active, "configure activates the textured path with the real entry")
	t.ok(visual._sprite != null, "textured path creates the Sprite2D child")
	t.ok(visual._sprite.texture != null, "textured child carries the loaded texture")
	t.ok(visual._sprite.visible, "textured child is visible")
	var scale := SpriteManifest.get_scale(entry)
	t.ok(visual._sprite.position.is_equal_approx(-SpriteManifest.get_anchor(entry) * scale),
		"textured child's anchor pixel lands on the node origin")
	t.ok(visual._sprite.position.y <= 0.0, "all textured geometry stays at local y <= 0 (sort origin fixed)")
	visual.free()
	gd.free()
	t.section_done("structure visual textured child")


func _test_structure_visual_textured_in_progress_modulate(t: Object) -> void:
	var gd := _make_game_data()
	var entry: Dictionary = gd.get_sprite("drying_shed")
	var visual := StructureVisual.new()
	visual._apply_sprite_entry(entry)
	visual.set_in_progress(true)
	t.eq(visual._sprite.modulate, Color(1.0, 1.0, 1.0, 0.65),
		"in-progress textured building dims via modulate instead of the primitive hatch")
	visual.set_in_progress(false)
	t.eq(visual._sprite.modulate, Color.WHITE, "completed textured building restores full opacity")
	visual.free()
	gd.free()
	t.section_done("textured in-progress modulate")


func _test_structure_visual_primitive_fallback(t: Object) -> void:
	var visual := StructureVisual.new()
	visual.configure(Rect2i(0, 0, 1, 1), Color.WHITE, 24.0)
	t.eq(visual.sprite_id, "", "no sprite id means the primitive path")
	t.not_ok(visual._texture_active, "no sprite id leaves the primitive fallback active")
	visual.configure(Rect2i(0, 0, 1, 1), Color.WHITE, 24.0,
		StructureVisual.Accent.NONE, Color.WHITE, Color.WHITE, "no_such_sprite")
	t.eq(visual.sprite_id, "no_such_sprite", "unknown sprite id is still recorded")
	t.not_ok(visual._texture_active, "unknown sprite id keeps the primitive fallback")
	visual.free()
	t.section_done("structure visual primitive fallback")


func _make_building_env(money: int, flint: int, wood: int) -> Dictionary:
	var gd := _make_game_data()
	var player = PLAYER_STATE_SCRIPT.new()
	player.money = money
	if flint > 0:
		player.add_item("flint", flint)
	if wood > 0:
		player.add_item("wood", wood)
	var bm = BUILDING_MANAGER_SCRIPT.new()
	bm.configure_for_test(player, gd)
	var world_visuals := WorldVisuals.new()
	var renderer := BuildingRenderer.new()
	renderer.configure(bm, gd, world_visuals)
	return {"bm": bm, "renderer": renderer, "world_visuals": world_visuals}


func _structure_children(world_visuals: WorldVisuals) -> Array[StructureVisual]:
	var out: Array[StructureVisual] = []
	for child: Node in world_visuals.get_children():
		if child is StructureVisual:
			out.append(child)
	return out


## The real spawn path: BuildingRenderer passes each building's id into
## StructureVisual.configure(), so a manifest entry can light up without any
## per-building code branch; unlisted ids still get the primitive box.
func _test_building_renderer_passes_building_id(t: Object) -> void:
	var env := _make_building_env(1000, 100, 100)
	var bm: Object = env["bm"]
	var world_visuals: WorldVisuals = env["world_visuals"]
	bm.start_building("cottage_upgrade", Vector2i(5, 5))
	bm.start_building("storage_chest", Vector2i(10, 10))
	var cottage: StructureVisual
	var chest: StructureVisual
	for v: StructureVisual in _structure_children(world_visuals):
		if v.footprint == Rect2i(5, 5, 3, 3):
			cottage = v
		elif v.footprint == Rect2i(10, 10, 1, 1):
			chest = v
	t.ok(cottage != null, "cottage_upgrade placement produces its StructureVisual")
	t.eq(cottage.sprite_id, "cottage_upgrade", "placed cottage visual receives the building id as sprite id")
	t.ok(cottage._texture_active, "cottage visual activates the textured path through the real GameData entry")
	t.ok(cottage._sprite != null, "cottage visual builds its Sprite2D child")
	t.ok(cottage._sprite.texture != null, "cottage visual's child carries the loaded texture")
	t.ok(chest != null, "storage chest placement produces its StructureVisual")
	t.eq(chest.sprite_id, "storage_chest", "untextured building id still reaches the visual")
	t.not_ok(chest._texture_active, "storage chest keeps the primitive fallback (no manifest entry)")
	t.section_done("building renderer passes building id")


func _test_building_renderer_ghost_stays_primitive(t: Object) -> void:
	var env := _make_building_env(1000, 100, 100)
	var renderer: Object = env["renderer"]
	renderer.show_ghost("cottage_upgrade", Vector2i(5, 5))
	var ghost: StructureVisual = renderer._ghost_visual
	t.ok(ghost.visible, "ghost becomes visible once show_ghost is called")
	t.eq(ghost.sprite_id, "", "ghost is never given a sprite id")
	t.not_ok(ghost._texture_active, "ghost keeps the primitive green/red placeability tint")
	t.section_done("ghost stays primitive")
