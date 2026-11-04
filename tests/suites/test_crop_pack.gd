extends RefCounted
## E1 (Spring Crop Pack) coverage: the four new crops (carrot, pea, onion,
## leek) are plantable and harvestable in season using the real shipped
## data, quality/seed-recovery stay within the declared ranges, and the
## gift/market/recipe wiring the proposal promised is actually present in
## villagers.json/market.json/recipes.json - not just crops.json/items.json.
## Uses real GameData (mirrors test_crafting.gd's pattern) rather than a
## synthetic fixture, since most of what this suite checks IS the data.

const FARM_GRID_SCRIPT := preload("res://scripts/world/farm_grid.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")

const NEW_CROPS: Array[String] = ["carrot", "pea", "onion", "leek"]


func suite_name() -> String:
	return "crop_pack"


func run(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	_test_crops_defined_for_spring(t, gd)
	_test_seed_and_yield_items_wired(t, gd)
	_test_plant_and_harvest_cycle(t, gd)
	_test_seed_recovery_in_range(t, gd)
	_test_market_prices_present(t, gd)
	_test_recipes_present(t, gd)
	_test_gift_wiring(t, gd)
	t.completed(24)


func _test_crops_defined_for_spring(t: Object, gd: Object) -> void:
	for crop_id: String in NEW_CROPS:
		var crop: Dictionary = gd.get_crop(crop_id)
		t.ok(not crop.is_empty(), "%s is defined in crops.json" % crop_id)
		t.ok((crop.get("seasons", []) as Array).has("spring"),
			"%s is plantable in spring" % crop_id)
	t.section_done("crops defined")


func _test_seed_and_yield_items_wired(t: Object, gd: Object) -> void:
	for crop_id: String in NEW_CROPS:
		var crop: Dictionary = gd.get_crop(crop_id)
		var seed_id := str(crop.get("seed_item_id", ""))
		var seed_item: Dictionary = gd.get_item(seed_id)
		t.ok(not seed_item.is_empty(), "%s's seed item %s exists in items.json" % [crop_id, seed_id])
		t.eq(str(seed_item.get("crop_id", "")), crop_id,
			"%s's seed item points back to the crop" % crop_id)
		var yield_item: Dictionary = gd.get_item(str(crop.get("yield_item_id", crop_id)))
		t.ok(not yield_item.is_empty(), "%s's yield item exists in items.json" % crop_id)
	t.section_done("items wired")


func _make_grid(gd: Object) -> Object:
	var grid = FARM_GRID_SCRIPT.new()
	var soil_map := {Vector2i(0, 0): "loamy"}
	grid.configure_for_test(gd.crops, soil_map, gd.soil_types, Vector2i(1, 1))
	return grid


## Waters once to the crop's own moisture_max (matching test_crop_growth.gd's
## proven idiom) then advances exactly growth_days - real loamy soil decays
## 4.0/day, well inside every new crop's moisture band over its growth
## window, so a single generous watering is sufficient.
func _grow_to_harvest(grid: Object, pos: Vector2i, crop: Dictionary) -> void:
	grid.water_tile(pos, float(crop.get("moisture_max", 100)))
	for _i in range(int(crop.get("growth_days", 1))):
		grid.advance_day(false)


func _test_plant_and_harvest_cycle(t: Object, gd: Object) -> void:
	for crop_id: String in NEW_CROPS:
		var grid := _make_grid(gd)
		var pos := Vector2i(0, 0)
		var crop: Dictionary = gd.get_crop(crop_id)
		t.ok(grid.till_tile(pos), "%s: till succeeds" % crop_id)
		t.eq(grid.plant(pos, crop_id), 0, "%s: plant succeeds in spring on fresh loamy soil" % crop_id)
		_grow_to_harvest(grid, pos, crop)
		t.ok(grid.is_harvestable(pos), "%s: harvestable after growth_days advance_day calls" % crop_id)
		var results: Array = grid.harvest(pos)
		var yield_item_id := str(crop.get("yield_item_id", crop_id))
		var found_yield := false
		for entry: Variant in results:
			var r := entry as Dictionary
			if str(r.get("item_id", "")) == yield_item_id:
				found_yield = true
				var count := int(r.get("count", 0))
				t.ok(count >= int(crop.get("yield_min", 1)) and count <= int(crop.get("yield_max", 1)),
					"%s: yield count %d within declared [%d, %d]" % [
						crop_id, count, int(crop.get("yield_min", 1)), int(crop.get("yield_max", 1))])
				t.ok(["common", "fine", "choice"].has(str(r.get("quality", ""))),
					"%s: quality is a valid tier" % crop_id)
		t.ok(found_yield, "%s: harvest produced the declared yield item" % crop_id)
	t.section_done("plant and harvest")


func _test_seed_recovery_in_range(t: Object, gd: Object) -> void:
	for crop_id: String in NEW_CROPS:
		var crop: Dictionary = gd.get_crop(crop_id)
		var seed_id := str(crop.get("seed_item_id", ""))
		var min_r := int(crop.get("seed_recovery_min", 0))
		var max_r := int(crop.get("seed_recovery_max", 0))
		var all_in_range := true
		for _trial in range(10):
			var grid := _make_grid(gd)
			var pos := Vector2i(0, 0)
			grid.till_tile(pos)
			grid.plant(pos, crop_id)
			_grow_to_harvest(grid, pos, crop)
			var results: Array = grid.harvest(pos)
			for entry: Variant in results:
				var r := entry as Dictionary
				if str(r.get("item_id", "")) == seed_id:
					var count := int(r.get("count", 0))
					if count < min_r or count > max_r:
						all_in_range = false
		t.ok(all_in_range, "%s: seed recovery stayed within [%d, %d] across 10 harvests" % [
			crop_id, min_r, max_r])
	t.section_done("seed recovery")


func _test_market_prices_present(t: Object, gd: Object) -> void:
	var prices: Dictionary = gd.get_market_buy_prices()
	for crop_id: String in NEW_CROPS:
		t.ok(prices.has(crop_id), "%s has a market buy price" % crop_id)
		t.ok(int(prices.get(crop_id, 0)) > 0, "%s's market buy price is positive" % crop_id)
	t.section_done("market prices")


func _test_recipes_present(t: Object, gd: Object) -> void:
	var expected := {"carrot_stew": "carrot", "pea_soup": "pea", "leek_pie": "leek"}
	for recipe_id: String in expected:
		var recipe: Dictionary = gd.get_recipe(recipe_id)
		t.ok(not recipe.is_empty(), "%s recipe is defined" % recipe_id)
		var inputs: Dictionary = recipe.get("inputs", {})
		t.ok(inputs.has(expected[recipe_id]), "%s recipe consumes %s" % [recipe_id, expected[recipe_id]])
		var output_item: Dictionary = gd.get_item(str(recipe.get("output_item_id", "")))
		t.ok(not output_item.is_empty(), "%s's output item is defined in items.json" % recipe_id)
	t.section_done("recipes")


func _test_gift_wiring(t: Object, gd: Object) -> void:
	var hilda: Dictionary = gd.get_villager("villager_1")
	t.ok((hilda.get("likes", []) as Array).has("carrot"), "Hilda likes carrot")
	var marta: Dictionary = gd.get_villager("villager_3")
	t.ok((marta.get("likes", []) as Array).has("pea"), "Marta likes pea")
	var priest: Dictionary = gd.get_villager("priest")
	t.ok((priest.get("dislikes", []) as Array).has("onion"), "the priest dislikes onion")
	var steward: Dictionary = gd.get_villager("steward")
	t.ok((steward.get("likes", []) as Array).has("leek"), "the steward likes leek")
	t.section_done("gift wiring")
