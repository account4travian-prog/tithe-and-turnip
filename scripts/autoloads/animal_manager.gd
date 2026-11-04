extends Node

## AnimalManager autoload (Sprint 14, ADR-028): chickens and one goat under
## the small-cast principle. Daily feed (a single feed resource - barley -
## per the guide's divergence note, not separate feed + water), happiness
## driving product quality linearly through the existing quality tiers, and
## raid vulnerability: on a LOST raid each animal independently rolls
## raid_loss_chance_per_animal. AUTOLOAD - no class_name.

signal animal_purchased(animal_id: String, species: String)
signal product_ready(animal_id: String, item_id: String, quality: String)
signal animal_lost(animal_id: String, reason: String)

var _animals: Dictionary = {}  # animal_id -> {species, happiness, fed_today, days_since_product}
var _next_id := 1

var _test_player: Node = null
var _test_game_data: Node = null
var _test_building: Node = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var tm := get_node_or_null("/root/TimeManager")
	if tm != null and not tm.day_passed.is_connected(_on_day_passed):
		tm.day_passed.connect(_on_day_passed)
	var rm := get_node_or_null("/root/RaidManager")
	if rm != null and not rm.raid_resolved.is_connected(_on_raid_resolved):
		rm.raid_resolved.connect(_on_raid_resolved)


## Explicit-injection seam for off-tree test suites (the same pattern every
## other autoload uses). Live games resolve /root autoloads normally.
func configure_for_test(player_state: Node, game_data: Node, building_manager: Node = null) -> void:
	_test_player = player_state
	_test_game_data = game_data
	_test_building = building_manager


## Seeded RNG seam (mirrors RaidManager.set_rng_seed) so raid-loss and
## quality rolls are deterministic in tests.
func set_rng_seed(seed_value: int) -> void:
	_rng.seed = seed_value


func can_buy_animal(species: String) -> bool:
	var gd := _game_data()
	if gd == null:
		return false
	var def: Dictionary = gd.get_animal_species(species)
	if def.is_empty():
		return false
	var player := _player()
	if player == null or int(player.money) < int(def.get("purchase_price", 0)):
		return false
	return _animals.size() < _coop_capacity()


func buy_animal(species: String) -> bool:
	if not can_buy_animal(species):
		return false
	var gd := _game_data()
	var def: Dictionary = gd.get_animal_species(species)
	var player := _player()
	if not player.spend_money(int(def.get("purchase_price", 0))):
		return false
	var id := "animal_%d" % _next_id
	_next_id += 1
	_animals[id] = {
		"species": species,
		"happiness": float(gd.animals_cfg.get("start_happiness", 60)),
		"fed_today": false,
		"days_since_product": 0,
	}
	animal_purchased.emit(id, species)
	return true


func feed_animal(animal_id: String) -> bool:
	if not _animals.has(animal_id):
		return false
	var a: Dictionary = _animals[animal_id]
	if bool(a.get("fed_today", false)):
		return false
	var gd := _game_data()
	var def: Dictionary = gd.get_animal_species(str(a.get("species", "")))
	var feed_id := str(def.get("feed_item_id", ""))
	var feed_amount := int(def.get("feed_amount", 1))
	var player := _player()
	if player == null or not player.has_item(feed_id, feed_amount):
		return false
	player.remove_item(feed_id, feed_amount)
	a["fed_today"] = true
	return true


func get_animal_ids() -> Array[String]:
	var out: Array[String] = []
	for id: Variant in _animals.keys():
		out.append(str(id))
	return out


func get_animal(animal_id: String) -> Dictionary:
	return _animals.get(animal_id, {})


func get_owned_count() -> int:
	return _animals.size()


func get_coop_capacity() -> int:
	return _coop_capacity()


func to_dict() -> Dictionary:
	return {"animals": _animals.duplicate(true), "next_id": _next_id}


func from_dict(data: Dictionary) -> void:
	_animals = (data.get("animals", {}) as Dictionary).duplicate(true)
	_next_id = int(data.get("next_id", 1))


func _on_day_passed(_day: int, _season: String, _year: int) -> void:
	var gd := _game_data()
	if gd == null:
		return
	var cfg: Dictionary = gd.animals_cfg
	var max_happy := maxf(1.0, float(cfg.get("max_happiness", 100)))
	for id: String in get_animal_ids():
		var a: Dictionary = _animals[id]
		var def: Dictionary = gd.get_animal_species(str(a.get("species", "")))
		if bool(a.get("fed_today", false)):
			a["happiness"] = clampf(
				float(a.get("happiness", 0.0)) + float(def.get("happiness_gain_fed", 0)), 0.0, max_happy)
		else:
			a["happiness"] = clampf(
				float(a.get("happiness", 0.0)) - float(def.get("happiness_loss_unfed", 0)), 0.0, max_happy)
		a["fed_today"] = false
		var cycle := maxi(1, int(def.get("product_cycle_days", 1)))
		a["days_since_product"] = int(a.get("days_since_product", 0)) + 1
		if int(a["days_since_product"]) >= cycle:
			a["days_since_product"] = 0
			var quality := _roll_quality(def, float(a.get("happiness", 0.0)), max_happy, cfg)
			var player := _player()
			if player != null:
				player.add_item(str(def.get("product_item_id", "")), 1, quality)
			product_ready.emit(id, str(def.get("product_item_id", "")), quality)
		_animals[id] = a


## Losses only on a LOST raid (win == false); each animal rolls independently
## at raid_loss_chance_per_animal - a full coop is neither wiped nor spared
## as a block. No _test_mode gate here (divergence, see DEVELOPMENT_STATE):
## the guide's own test #7 requires the loss path to run in test mode, and
## nothing in this handler has live-only side effects.
func _on_raid_resolved(win: bool) -> void:
	if win:
		return
	var gd := _game_data()
	if gd == null:
		return
	var loss_chance := float(gd.animals_cfg.get("raid_loss_chance_per_animal", 0.0))
	for id: String in get_animal_ids():
		if _rng.randf() < loss_chance:
			_animals.erase(id)
			animal_lost.emit(id, "raid")


## Linear happiness -> quality: happiness_frac shifts weight toward
## fine/choice proportionally (not FarmGrid's discrete soil-bonus table -
## deliberate, per the guide: soil and happiness are different inputs and a
## shared helper would need a parameter meaning different things per caller).
func _roll_quality(def: Dictionary, happiness: float, max_happy: float, cfg: Dictionary) -> String:
	var weights: Dictionary = def.get("quality_weights", {})
	var frac := happiness / max_happy
	var common_w := maxi(0, int(weights.get("common", 70)))
	var fine_w := maxi(0, int(weights.get("fine", 25)) + int(frac * float(cfg.get("happiness_fine_weight_scale", 0))))
	var choice_w := maxi(0, int(weights.get("choice", 5)) + int(frac * float(cfg.get("happiness_choice_weight_scale", 0))))
	var total := float(common_w + fine_w + choice_w)
	if total <= 0.0:
		return "common"
	var roll := _rng.randf() * total
	if roll < float(common_w):
		return "common"
	if roll < float(common_w + fine_w):
		return "fine"
	return "choice"


func _coop_capacity() -> int:
	var bm := _building_manager()
	if bm == null:
		return 0
	var gd := _game_data()
	if gd == null:
		return 0
	var capacity := 0
	for b: Dictionary in bm.get_completed_buildings():
		if str(b.get("building_id", "")) == "coop":
			capacity += int(gd.get_building("coop").get("animal_capacity", 0))
	return capacity


func _player() -> Node:
	if _test_player != null:
		return _test_player
	return get_node_or_null("/root/PlayerState")


func _game_data() -> Node:
	if _test_game_data != null:
		return _test_game_data
	return get_node_or_null("/root/GameData")


func _building_manager() -> Node:
	if _test_building != null:
		return _test_building
	return get_node_or_null("/root/BuildingManager")
