extends RefCounted
## Approved Spring crop art: each growable Spring crop has three static atlas
## stages, GameData indexes its presentation-only stage set, and FarmRenderer
## resolves the correct entry without changing FarmGrid state.

const FARM_RENDERER_SCRIPT := preload("res://scripts/world/farm_renderer.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")
const CROP_IDS: Array[String] = [
	"turnip", "barley", "carrot", "pea", "onion", "leek", "oat", "flax",
]


func suite_name() -> String:
	return "crop_stage_art"


func run(t: Object) -> void:
	_test_stage_sets_and_textures(t)
	_test_stage_threshold_selection(t)
	t.completed(112)


func _test_stage_sets_and_textures(t: Object) -> void:
	var game_data := GAME_DATA_SCRIPT.new()
	game_data.load_all()
	for crop_id: String in CROP_IDS:
		var stage_set: Dictionary = game_data.get_crop_stage_set(crop_id)
		t.eq(str(stage_set.get("kind", "")), "crop_stage_set",
			"%s has a presentation stage set" % crop_id)
		var stages: Array = stage_set.get("stages", [])
		t.eq(stages.size(), 3, "%s has seedling/growing/ripe stages" % crop_id)
		for stage: Variant in stages:
			var stage_data := stage as Dictionary
			var entry: Dictionary = game_data.get_sprite(str(stage_data.get("sprite_id", "")))
			t.eq(str(entry.get("kind", "")), "static",
				"%s stage resolves a static sprite" % crop_id)
			t.ok(FileAccess.file_exists(str(entry.get("texture", ""))),
				"%s stage texture exists in runtime assets" % crop_id)
			var sprite := Sprite2D.new()
			t.ok(SpriteManifest.apply_static(sprite, entry),
				"%s stage atlas region applies" % crop_id)
			sprite.free()
	game_data.free()
	t.section_done("approved crop stage sets")


func _test_stage_threshold_selection(t: Object) -> void:
	var game_data := GAME_DATA_SCRIPT.new()
	game_data.load_all()
	var renderer := FARM_RENDERER_SCRIPT.new()
	renderer.configure(null, game_data, null)
	for crop_id: String in CROP_IDS:
		var stage_set: Dictionary = game_data.get_crop_stage_set(crop_id)
		t.eq(SpriteManifest.get_stage_sprite_id(stage_set, 0.49),
			"crop_%s_stage_1" % crop_id,
			"%s selects seedling before the mid threshold" % crop_id)
		t.eq(SpriteManifest.get_stage_sprite_id(stage_set, 0.5),
			"crop_%s_stage_2" % crop_id,
			"%s selects growing art at the mid threshold" % crop_id)
		t.eq(str(renderer._crop_sprite_entry(crop_id, 1.0).get("id", "")),
			"crop_%s_stage_3" % crop_id,
			"%s resolves ripe art through FarmRenderer" % crop_id)
	renderer.free()
	game_data.free()
	t.section_done("stage thresholds and renderer seam")
