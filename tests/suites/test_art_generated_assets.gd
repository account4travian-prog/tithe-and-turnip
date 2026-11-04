

extends RefCounted
## Regression coverage for the first approved generated static-art batch.
## Well, hearth, and coop share one RGBA atlas but must each select its own
## source rectangle; chapel, player house, and alehouse are isolated
## transparent textures using their manifest frame dimensions as render regions.

const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")
const GENERATED_ATLAS := "res://assets/sprites/structures/generated_atlas_linear_0.png"
const CHAPEL_TEXTURE := "res://assets/sprites/structures/chapel_replacement_v2.png"
const TERRA_ALEHOUSE_TEXTURE := "res://assets/sprites/structures/terra_alehouse_exterior.png"
const RIGGED_COTTAGE_TEXTURE := "res://assets/sprites/structures/player_house_rig_v7.png"
const RIGGED_WELL_TEXTURE := "res://assets/sprites/structures/well_rig_v4.png"
const EXPECTED_ENTRIES := {
	"alehouse": {
		"texture": TERRA_ALEHOUSE_TEXTURE,
		"region": Rect2(0, 0, 1254, 1254),
	},
	"chapel": {
		"texture": CHAPEL_TEXTURE,
		"region": Rect2(0, 0, 1122, 1402),
	},
	"coop": {
		"texture": GENERATED_ATLAS,
		"region": Rect2(2, 2, 250, 256),
	},
	"hearth": {
		"texture": GENERATED_ATLAS,
		"region": Rect2(256, 2, 285, 256),
	},
	"player_house": {
		"texture": RIGGED_COTTAGE_TEXTURE,
		"region": Rect2(0, 0, 248, 241),
	},
	"well": {
		"texture": RIGGED_WELL_TEXTURE,
		"region": Rect2(0, 0, 60, 95),
	},
}


func suite_name() -> String:
	return "art_generated_assets"


func run(t: Object) -> void:
	_test_generated_structure_entries(t)
	t.completed(24)


func _test_generated_structure_entries(t: Object) -> void:
	var game_data := GAME_DATA_SCRIPT.new()
	game_data.load_all()
	for sprite_id: String in EXPECTED_ENTRIES:
		var expected: Dictionary = EXPECTED_ENTRIES[sprite_id]
		var entry: Dictionary = game_data.get_sprite(sprite_id)
		t.eq(str(entry.get("texture", "")), str(expected["texture"]),
			"%s uses its approved generated-art texture" % sprite_id)
		var sprite := Sprite2D.new()
		t.ok(SpriteManifest.apply_static(sprite, entry),
			"%s applies its staged texture" % sprite_id)
		t.ok(sprite.texture != null, "%s resolves a texture resource" % sprite_id)
		t.eq(sprite.region_rect, expected["region"],
			"%s selects its authored static source rectangle" % sprite_id)
		sprite.free()
	game_data.free()
	t.section_done("approved generated static assets")




