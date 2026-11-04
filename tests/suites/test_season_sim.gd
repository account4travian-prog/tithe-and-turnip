extends RefCounted
## Sprint 6 balance regression guard: a deterministic 28-day headless
## playthrough on the REAL shipped data (GameData + farm_map v4 + crops v3).
## Sprint 15a re-expressed the playthrough against fallowfield's layout: the
## 12 planted tiles sit in its loamy north-west corner (the old 30x20 map's
## loamy rect 1), which is the best soil on every axis.
## Asserts the acreage tithe is payable by a diligent-but-not-obsessive player
## AND that a tool upgrade remains affordable after paying it. This suite must
## keep passing on every future data edit - if the economy drifts, it is the
## first suite to say so. The playthrough script (tiles, weather, policies)
## lives in the named constants below so a future rebalance can see exactly
## what assumptions it must keep satisfying.

const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")
const FARM_GRID_SCRIPT := preload("res://scripts/world/farm_grid.gd")
const PLAYER_STATE_SCRIPT := preload("res://scripts/autoloads/player_state.gd")
const TITHE_SCRIPT := preload("res://scripts/autoloads/tithe_manager.gd")

const SIM_SEED := 2026
const WATER_AMOUNT := 25.0  # wooden can water_amount

## 8 turnip + 4 barley tiles, all inside loamy rect 1 of farm_map v2
## (x 0-4, y 0-3), so the soil is the best on every axis - this is the
## "diligent player farms the good land" baseline.
const TURNIP_POSITIONS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
	Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
]
const BARLEY_POSITIONS: Array[Vector2i] = [
	Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3),
]

## Fixed 28-day spring weather as {rain, overcast} pairs: 8 rain / 3 overcast
## / 17 sunny, matching the shipped 30%/10% spring chances without rng.
const WEATHER: Array = [
	[true, false], [false, false], [false, false], [true, false], [false, true],
	[false, false], [false, false], [true, false], [false, false], [false, false],
	[false, true], [true, false], [false, false], [false, false], [false, false],
	[true, false], [false, false], [false, true], [false, false], [true, false],
	[false, false], [false, false], [true, false], [false, false], [false, false],
	[false, false], [true, false], [false, false],
]


func suite_name() -> String:
	return "season_sim"


func run(t: Object) -> void:
	var sim := _run_simulation()
	t.eq(int(sim.get("farm_width", -1)), 24, "playthrough uses fallowfield's 24-wide grid")
	t.eq(int(sim.get("farm_height", -1)), 16, "playthrough uses fallowfield's 16-tall grid")
	t.ok(bool(sim.get("all_loamy", false)), "playthrough tiles are loamy in fallowfield")
	t.eq(int(sim.get("rain_days", -1)), 8, "weather script is the fixed 8-rain-day sequence")
	t.eq(int(sim.get("tithe_goal", -1)), 20, "ADR-038 held-acreage goal is base 20 (no strips rented in this sim)")
	t.ok(float(sim.get("remaining", 1.0)) <= 0.0, "tithe is payable by a diligent playthrough")
	t.ok(int(sim.get("money", -1)) >= 84,
		"a tool upgrade (can_iron, 80 + 5% toll) is still affordable after the tithe")
	t.ok(int(sim.get("exhaustions", 99)) <= 2,
		"playthrough needs no more than 2 knock-outs (got %d)" % int(sim.get("exhaustions", -1)))
	t.ok(float(sim.get("min_energy", -1.0)) >= 0.0, "energy never went negative")
	t.ok(int(sim.get("coins_earned", -1)) > 0, "the playthrough actually earned coin")
	t.completed(7)


func _run_simulation() -> Dictionary:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var soil_map := {}
	for y in range(gd.get_map_height()):
		for x in range(gd.get_map_width()):
			soil_map[Vector2i(x, y)] = gd.get_soil_at(x, y)
	var farm = FARM_GRID_SCRIPT.new()
	farm.configure_for_test(gd.crops, soil_map, gd.soil_types,
		Vector2i(gd.get_map_width(), gd.get_map_height()))
	var ps = PLAYER_STATE_SCRIPT.new()
	ps.max_energy = float(gd.player_cfg.get("max_energy", 100.0))
	ps.energy = ps.max_energy
	ps.max_health = int(gd.player_cfg.get("max_health", 50))
	ps.health = ps.max_health
	ps.money = int(gd.player_cfg.get("start_money", 0))
	var starter: Dictionary = gd.player_cfg.get("starter_items", {})
	for item_id: Variant in starter:
		ps.add_item(str(item_id), int(starter[item_id]))
	var tm = TITHE_SCRIPT.new()
	var day_holder := [1]
	tm.configure_for_test(ps, gd, func() -> int: return day_holder[0], farm)
	seed(SIM_SEED)

	var till_cost := int(gd.player_cfg.get("tool_energy_cost", 4))
	var plant_cost := int(gd.player_cfg.get("plant_energy_cost", 1))
	var exhaustions := 0
	var min_energy: float = ps.energy

	# Day 1: till the whole 12-tile plot once (energy via PlayerState, so the
	# energy economy is part of the regression, not just the coin one).
	for pos: Vector2i in TURNIP_POSITIONS + BARLEY_POSITIONS:
		if ps.consume_energy(float(till_cost)):
			farm.till_tile(pos)
		else:
			exhaustions += 1

	for day in range(1, 29):
		day_holder[0] = day
		if day > 1:
			# Sleeping restores 60% of max energy each morning (ADR-016).
			ps.sleep_restore()
		# Plant empty designated tiles whenever a seed is on hand.
		for pos: Vector2i in TURNIP_POSITIONS:
			if _is_planted(farm, pos):
				continue
			if not ps.has_item("turnip_seed"):
				continue
			if ps.consume_energy(float(plant_cost)):
				farm.plant(pos, "turnip")
				ps.remove_item("turnip_seed", 1)
			else:
				exhaustions += 1
		for pos: Vector2i in BARLEY_POSITIONS:
			if _is_planted(farm, pos):
				continue
			if not ps.has_item("barley_seed"):
				continue
			if ps.consume_energy(float(plant_cost)):
				farm.plant(pos, "barley")
				ps.remove_item("barley_seed", 1)
			else:
				exhaustions += 1
		# Water any crop sitting below its moisture minimum.
		for pos: Vector2i in TURNIP_POSITIONS + BARLEY_POSITIONS:
			var cell: Dictionary = farm.get_cell(pos)
			var crop_id := str(cell.get("crop_id", ""))
			if crop_id.is_empty():
				continue
			var crop: Dictionary = gd.get_crop(crop_id)
			var min_m := float(crop.get("moisture_min", 0.0))
			if float(cell.get("moisture", 0.0)) < min_m \
					and ps.consume_energy(1.0):
				farm.water_tile(pos, WATER_AMOUNT)
		# Advance the farm day with the fixed weather, then run the day
		# rollover handlers (upkeep included) by hand, mirroring the day-holder
		# pattern in test_market.gd since nothing is in the scene tree.
		var weather: Array = WEATHER[day - 1]
		farm.advance_day(bool(weather[0]), bool(weather[1]))
		tm._on_day_passed(day, "spring", 1)
		# Harvest anything mature into inventory.
		for pos: Vector2i in TURNIP_POSITIONS + BARLEY_POSITIONS:
			if farm.is_harvestable(pos):
				for entry: Variant in farm.harvest(pos):
					var r := entry as Dictionary
					ps.add_item(str(r.get("item_id", "")), int(r.get("count", 0)),
						str(r.get("quality", "common")))
		# Market days: sell everything, pay the tithe when fully affordable,
		# then restock seeds for empty tiles.
		if gd.is_market_day(day):
			_sell_all(tm, ps)
			var progress: Dictionary = tm.get_tithe_progress()
			if float(progress.get("remaining", 0.0)) > 0.0 \
					and ps.money >= int(progress.get("remaining", 0.0)):
				tm.pay_tithe_coin(int(progress.get("remaining", 0.0)))
			for pos: Vector2i in TURNIP_POSITIONS:
				if not _is_planted(farm, pos) and tm.can_buy("turnip_seed", 1):
					tm.buy_item("turnip_seed", 1)
			for pos: Vector2i in BARLEY_POSITIONS:
				if not _is_planted(farm, pos) and tm.can_buy("barley_seed", 1):
					tm.buy_item("barley_seed", 1)
		min_energy = minf(min_energy, ps.energy)

	var progress: Dictionary = tm.get_tithe_progress()
	if float(progress.get("remaining", 0.0)) > 0.0 \
			and ps.money >= int(progress.get("remaining", 0.0)):
		tm.pay_tithe_coin(int(progress.get("remaining", 0.0)))
		progress = tm.get_tithe_progress()
	var all_loamy := true
	for pos: Vector2i in TURNIP_POSITIONS + BARLEY_POSITIONS:
		if str(farm.get_soil(pos)) != "loamy":
			all_loamy = false
	return {
		"farm_width": gd.get_map_width(),
		"farm_height": gd.get_map_height(),
		"all_loamy": all_loamy,
		"rain_days": _count_rain_days(),
		"tithe_goal": int(progress.get("goal", 0)),
		"remaining": float(progress.get("remaining", 0.0)),
		"money": ps.money,
		"exhaustions": exhaustions,
		"min_energy": min_energy,
		"coins_earned": ps.total_coins_earned,
	}


func _sell_all(tm: Object, ps: Object) -> void:
	for entry: Variant in ps.list_inventory():
		var e := entry as Dictionary
		var item_id := str(e.get("item_id", ""))
		var quality := str(e.get("quality", "common"))
		var qty := int(e.get("count", 0))
		if tm.can_sell(item_id, qty, quality):
			tm.sell_crop(item_id, qty, quality)


func _is_planted(farm: Object, pos: Vector2i) -> bool:
	return not str(farm.get_cell(pos).get("crop_id", "")).is_empty()


func _count_rain_days() -> int:
	var count := 0
	for entry: Variant in WEATHER:
		if bool((entry as Array)[0]):
			count += 1
	return count
