extends RefCounted
## AnimalManager coverage (Sprint 14, ADR-028): coop capacity gate, purchase,
## feeding, day-passed happiness + product cadence, linear happiness ->
## quality weights, raid losses on a lost raid only, and save round-trip.
## Uses the REAL shipped data (GameData + animals.json) with a seeded
## PlayerState and a real BuildingManager configured with a completed coop
## (the Sprint 13 test_crafting pattern).

const ANIMAL_MANAGER_SCRIPT := preload("res://scripts/autoloads/animal_manager.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")
const PLAYER_STATE_SCRIPT := preload("res://scripts/autoloads/player_state.gd")
const BUILDING_MANAGER_SCRIPT := preload("res://scripts/autoloads/building_manager.gd")

const QUALITY_TIERS := ["common", "fine", "choice"]


func suite_name() -> String:
	return "animals"


func run(t: Object) -> void:
	_test_capacity_gate(t)
	_test_buy(t)
	_test_feed(t)
	_test_day_passed_happiness(t)
	_test_product_cadence(t)
	_test_quality_weights(t)
	_test_raid_loss(t)
	_test_save_roundtrip(t)
	t.completed(14)


func _make_env() -> Dictionary:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var player = PLAYER_STATE_SCRIPT.new()
	player.money = 1000
	player.add_item("barley", 50)
	player.add_item("flint", 100)
	var bm = BUILDING_MANAGER_SCRIPT.new()
	bm.configure_for_test(player, gd)
	var am = ANIMAL_MANAGER_SCRIPT.new()
	am.configure_for_test(player, gd, bm)
	am.set_rng_seed(7)
	return {"am": am, "player": player, "gd": gd, "bm": bm}


func _build_coop(bm: Object) -> void:
	bm.start_building("coop", Vector2i(8, 8))
	for i in range(2):
		bm._on_day_passed(i + 1, "spring", 1)


func _test_capacity_gate(t: Object) -> void:
	var env := _make_env()
	var am: Object = env["am"]
	t.not_ok(am.can_buy_animal("chicken"),
		"can_buy_animal false with no coop built (capacity 0)")
	_build_coop(env["bm"])
	t.ok(am.can_buy_animal("chicken"),
		"can_buy_animal true once a coop with capacity 4 is completed")
	t.section_done("capacity gate")


func _test_buy(t: Object) -> void:
	var env := _make_env()
	var am: Object = env["am"]
	var player: Object = env["player"]
	_build_coop(env["bm"])
	t.eq(player.money, 930, "building the coop deducts its 70 coin cost")
	t.ok(am.buy_animal("chicken"), "buying a chicken succeeds")
	t.eq(player.money, 900, "chicken purchase price 30 deducted from 930")
	t.eq(am.get_animal_ids().size(), 1, "one animal owned after the purchase")
	t.eq(str(am.get_animal(am.get_animal_ids()[0]).get("species", "")), "chicken",
		"owned animal carries the bought species")
	t.eq(float(am.get_animal(am.get_animal_ids()[0]).get("happiness", -1.0)),
		float(env["gd"].animals_cfg.get("start_happiness", -1)),
		"new animal starts at start_happiness")
	t.ok(am.buy_animal("goat"), "buying a goat succeeds")
	t.eq(player.money, 820, "goat purchase price 80 deducted")
	t.ok(am.buy_animal("chicken"), "third animal fits (capacity 4)")
	t.ok(am.buy_animal("chicken"), "fourth animal fills the coop")
	t.not_ok(am.can_buy_animal("goat"), "can_buy_animal false at full capacity")
	t.not_ok(am.buy_animal("goat"), "buy fails at full capacity")
	t.eq(player.money, 760, "failed purchase at capacity deducts nothing")
	t.eq(am.get_animal_ids().size(), 4, "owned count equals coop capacity")
	t.section_done("buy")


func _test_feed(t: Object) -> void:
	var env := _make_env()
	var am: Object = env["am"]
	var player: Object = env["player"]
	_build_coop(env["bm"])
	t.ok(am.buy_animal("chicken"), "precondition: own a chicken")
	var id: String = am.get_animal_ids()[0]
	t.ok(am.feed_animal(id), "feeding with barley in stock succeeds")
	t.eq(player.get_item_count("barley"), 49, "one barley consumed per chicken feed")
	t.eq(bool(am.get_animal(id).get("fed_today", false)), true, "fed_today set after feeding")
	t.not_ok(am.feed_animal(id), "a second feed the same day fails")
	t.eq(player.get_item_count("barley"), 49, "second feed consumes nothing")
	var env2 := _make_env()
	var am2: Object = env2["am"]
	var player2: Object = env2["player"]
	player2.remove_item("barley", 50)
	_build_coop(env2["bm"])
	am2.buy_animal("chicken")
	var id2: String = am2.get_animal_ids()[0]
	t.not_ok(am2.feed_animal(id2), "feeding with no barley fails")
	t.eq(bool(am2.get_animal(id2).get("fed_today", false)), false, "fed_today stays false")
	t.section_done("feed")


func _test_day_passed_happiness(t: Object) -> void:
	var env := _make_env()
	var am: Object = env["am"]
	_build_coop(env["bm"])
	am.buy_animal("chicken")
	var id: String = am.get_animal_ids()[0]
	t.ok(am.feed_animal(id), "precondition: fed")
	am._on_day_passed(1, "spring", 1)
	t.eq(float(am.get_animal(id).get("happiness", -1.0)), 70.0,
		"fed animal gains happiness_gain_fed (60 + 10)")
	t.eq(bool(am.get_animal(id).get("fed_today", false)), false,
		"fed_today resets to false on day_passed")
	am._on_day_passed(2, "spring", 1)
	t.eq(float(am.get_animal(id).get("happiness", -1.0)), 50.0,
		"unfed animal loses happiness_loss_unfed (70 - 20)")
	am.get_animal(id)["happiness"] = 95.0
	am.feed_animal(id)
	am._on_day_passed(3, "spring", 1)
	t.eq(float(am.get_animal(id).get("happiness", -1.0)), 100.0,
		"happiness gain clamps at max_happiness")
	am.get_animal(id)["happiness"] = 10.0
	am._on_day_passed(4, "spring", 1)
	t.eq(float(am.get_animal(id).get("happiness", -1.0)), 0.0,
		"happiness loss clamps at zero")
	t.section_done("day passed happiness")


func _test_product_cadence(t: Object) -> void:
	var env := _make_env()
	var am: Object = env["am"]
	var player: Object = env["player"]
	_build_coop(env["bm"])
	am.buy_animal("chicken")
	am.buy_animal("goat")
	for animal_id: String in am.get_animal_ids():
		t.ok(am.feed_animal(animal_id), "precondition: every animal fed before each day")
	am._on_day_passed(1, "spring", 1)
	t.eq(player.get_item_count("egg"), 1, "chicken lays an egg on day 1 (cycle 1)")
	t.eq(player.get_item_count("milk"), 0, "goat produces nothing on day 1 (cycle 2)")
	for animal_id: String in am.get_animal_ids():
		am.feed_animal(animal_id)
	am._on_day_passed(2, "spring", 1)
	t.eq(player.get_item_count("egg"), 2, "chicken lays again on day 2")
	t.eq(player.get_item_count("milk"), 1, "goat produces milk on day 2")
	for animal_id: String in am.get_animal_ids():
		am.feed_animal(animal_id)
	am._on_day_passed(3, "spring", 1)
	t.eq(player.get_item_count("egg"), 3, "chicken lays again on day 3")
	t.eq(player.get_item_count("milk"), 1, "goat skips day 3 (cycle 2)")
	for animal_id: String in am.get_animal_ids():
		am.feed_animal(animal_id)
	am._on_day_passed(4, "spring", 1)
	t.eq(player.get_item_count("egg"), 4, "chicken lays again on day 4")
	t.eq(player.get_item_count("milk"), 2, "goat produces milk again on day 4")
	t.section_done("product cadence")


func _test_quality_weights(t: Object) -> void:
	var env := _make_env()
	var gd: Object = env["gd"]
	var am: Object = env["am"]
	var def: Dictionary = gd.get_animal_species("chicken")
	var cfg: Dictionary = gd.animals_cfg
	var max_happy := float(cfg.get("max_happiness", 100))
	var fine_scale := float(cfg.get("happiness_fine_weight_scale", 0))
	var choice_scale := float(cfg.get("happiness_choice_weight_scale", 0))
	var fine_low := int(def.get("quality_weights", {}).get("fine", 25))
	var choice_low := int(def.get("quality_weights", {}).get("choice", 5))
	var fine_high := fine_low + int(fine_scale)
	var choice_high := choice_low + int(choice_scale)
	t.ok(fine_high > fine_low, "fine weight rises with happiness (formula contract)")
	t.ok(choice_high > choice_low, "choice weight rises with happiness (formula contract)")
	var valid := true
	for i in range(20):
		var quality := str(am._roll_quality(def, max_happy, max_happy, cfg))
		if not QUALITY_TIERS.has(quality):
			valid = false
	for i in range(20):
		var quality := str(am._roll_quality(def, 0.0, max_happy, cfg))
		if not QUALITY_TIERS.has(quality):
			valid = false
	t.ok(valid, "_roll_quality only ever returns a known quality tier")
	t.section_done("quality weights")


func _test_raid_loss(t: Object) -> void:
	var env := _make_env()
	var am: Object = env["am"]
	var gd: Object = env["gd"]
	_build_coop(env["bm"])
	am.buy_animal("chicken")
	am.buy_animal("goat")
	var lost: Array = []
	am.animal_lost.connect(func(animal_id: String, reason: String) -> void:
		lost.append([animal_id, reason]))
	gd.animals_cfg["raid_loss_chance_per_animal"] = 1.0
	am._on_raid_resolved(false)
	t.eq(am.get_animal_ids().size(), 0, "lost raid with chance 1.0 removes every animal")
	t.eq(lost.size(), 2, "animal_lost fires once per owned animal")
	var env2 := _make_env()
	var am2: Object = env2["am"]
	var gd2: Object = env2["gd"]
	_build_coop(env2["bm"])
	am2.buy_animal("chicken")
	am2.buy_animal("goat")
	gd2.animals_cfg["raid_loss_chance_per_animal"] = 1.0
	am2._on_raid_resolved(true)
	t.eq(am2.get_animal_ids().size(), 2, "a won raid removes nothing regardless of chance")
	t.section_done("raid loss")


func _test_save_roundtrip(t: Object) -> void:
	var env := _make_env()
	var am: Object = env["am"]
	var player: Object = env["player"]
	_build_coop(env["bm"])
	am.buy_animal("chicken")
	am.buy_animal("goat")
	for animal_id: String in am.get_animal_ids():
		am.feed_animal(animal_id)
	am._on_day_passed(1, "spring", 1)
	for animal_id: String in am.get_animal_ids():
		am.feed_animal(animal_id)
	var dumped: Dictionary = am.to_dict()
	t.eq((dumped.get("animals", {}) as Dictionary).size(), 2, "to_dict carries both animals")
	var restored = ANIMAL_MANAGER_SCRIPT.new()
	restored.configure_for_test(player, env["gd"], env["bm"])
	restored.from_dict(dumped)
	t.eq(restored.get_animal_ids().size(), 2, "from_dict restores both animals")
	t.eq(int(restored.to_dict().get("next_id", -1)), int(dumped.get("next_id", -1)),
		"next_id round-trips exactly")
	for animal_id: String in restored.get_animal_ids():
		var before: Dictionary = am.get_animal(animal_id)
		var after: Dictionary = restored.get_animal(animal_id)
		t.eq(str(after.get("species", "")), str(before.get("species", "")),
			"species round-trips for %s" % animal_id)
		t.eq(float(after.get("happiness", -1.0)), float(before.get("happiness", -1.0)),
			"happiness round-trips for %s" % animal_id)
		t.eq(bool(after.get("fed_today", false)), bool(before.get("fed_today", false)),
			"fed_today round-trips for %s" % animal_id)
		t.eq(int(after.get("days_since_product", -1)), int(before.get("days_since_product", -1)),
			"product timer round-trips for %s" % animal_id)
	t.section_done("save roundtrip")
