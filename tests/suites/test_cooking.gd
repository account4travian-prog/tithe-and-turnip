extends RefCounted
## Cooking balance guard (Sprint 13): crafted food is just another "food"
## item through PlayerState.eat() - no special-casing needed - and the best
## crafted food must restore at least double the energy of the best raw crop.
## That comparison is the regression guard so a future data edit cannot
## quietly erase cooking's value proposition.

const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")
const PLAYER_STATE_SCRIPT := preload("res://scripts/autoloads/player_state.gd")


func suite_name() -> String:
	return "cooking"


func run(t: Object) -> void:
	_test_raw_turnip(t)
	_test_crafted_stew(t)
	_test_crafted_beats_raw(t)
	t.completed(6)


func _make_player() -> Array:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var player = PLAYER_STATE_SCRIPT.new()
	player.set_game_data_ref(gd)
	return [player, gd]


func _test_raw_turnip(t: Object) -> void:
	var parts := _make_player()
	var player: Object = parts[0]
	player.energy = 50.0
	player.add_item("turnip", 1)
	t.ok(player.eat("turnip"), "raw turnip is edible")
	t.eq(player.energy, 55.0,
		"raw turnip restores exactly energy_base 5 (common x1)")
	t.section_done("raw turnip")


func _test_crafted_stew(t: Object) -> void:
	var parts := _make_player()
	var player: Object = parts[0]
	player.energy = 50.0
	player.add_item("pottage", 1)
	t.ok(player.eat("pottage"), "crafted pottage is edible")
	t.eq(player.energy, 68.0,
		"pottage restores exactly its energy_base 18 (common x1)")
	t.section_done("crafted stew")


func _test_crafted_beats_raw(t: Object) -> void:
	var parts := _make_player()
	var gd: Object = parts[1]
	var best_raw := 0.0
	var best_crafted := 0.0
	# E1/E12 added four more recipe outputs (carrot_stew, pea_soup, leek_pie,
	# morel_stew) - this list is every food item that's a recipe
	# output_item_id in recipes.json, not a raw crop/forage item.
	var crafted_ids := [
		"dried_turnip", "dried_barley", "barley_ale", "pottage", "berry_pie",
		"carrot_stew", "pea_soup", "leek_pie", "morel_stew"]
	for item_id: String in gd.get_all_item_ids():
		var def: Dictionary = gd.get_item(item_id)
		if str(def.get("type", "")) != "food":
			continue
		var energy := float(def.get("energy_base", 0.0))
		if item_id in crafted_ids:
			if energy > best_crafted:
				best_crafted = energy
		elif energy > best_raw:
			best_raw = energy
	t.eq(best_crafted, 24.0, "best crafted food is leek_pie at 24 energy")
	t.ok(best_crafted >= best_raw * 2.0,
		"best crafted food restores at least double the best raw crop (%.1f vs %.1f)"
		% [best_crafted, best_raw])
	t.section_done("crafted beats raw")
