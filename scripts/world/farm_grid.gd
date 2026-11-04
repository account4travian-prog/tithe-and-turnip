class_name FarmGrid
extends Node2D

## Farm tile state and crop growth (v2): till/plant/water/harvest with
## per-cell moisture (0-100), soil-aware moisture decay, moisture-gated growth
## on advance_day, quality roll + seed recovery on harvest. Data comes from
## GameData (or a test mock via configure_for_test); never per-tick growth.
## ADR-015: planting clamps moisture to the crop's max; overwatering halves
## growth instead of blocking it. ADR-018: mature crops age (days_mature) and
## rot in two stages - quality degrades past spoil_after_days, yield is
## destroyed past 2 * spoil_after_days, and (as of E2) the rotted cell leaves
## behind a spoiled_crop pickup on the same tile, gathered through the
## existing forage pipeline rather than granted directly (FarmGrid never
## touches inventory).
## E2 (soil fertility): every cell carries a fertility 0-100, initialised
## from soil_types.fertility_init, depleted by harvest (or restored, for
## cover crops with a negative fertility_depletion), recovered by fallow
## days or compost, and gating both planting (fertility_min) and a quality
## bonus at soil.high_fertility_threshold.
## E12 (foraging 2.0): a spade digs untilled cells for a dedicated dig_loot
## table (mostly buried forageables, rare finds well-throttled), separate
## from the passive wild-spawn system - see dig_cell().
## ADR-040 (spatial demesne chores): FarmGrid also owns the demesne rect
## (the lord's land is a real feature on this same grid) and the stored
## sheaf markers that make harvest_demesne a real per-tile action - cleared
## sheaves are stored on untilled demesne tiles, never on the tithe-chest
## anchor tile, replenished on a data-driven cadence. Tilling under a sheaf
## is refused, and planting on any demesne tile is refused (the demesne
## never becomes the player's field).

signal tile_changed(pos: Vector2i)
signal crop_harvested(crop_id: String, item_id: String, quality: String, count: int, seeds: int)
signal crop_matured(pos: Vector2i)
signal crop_spoiled(pos: Vector2i)
signal forage_gathered(pos: Vector2i, item_id: String, count: int)
signal fertility_changed(pos: Vector2i, new_value: float)

const GROWTH_EPSILON: float = 0.01
const DEFAULT_ZONE_ID := "fallowfield"

var _test_mode: bool = false
var _test_grid_size: Vector2i = Vector2i(30, 20)
var _test_soil_map: Dictionary = {}
var _test_crop_db: Dictionary = {}
var _test_soil_properties: Dictionary = {}
var _test_forage_cfg: Dictionary = {}
var _test_owned_rects: Array[Rect2i] = []
## Test seam for the zone-aware ownership gate: suites may inject a real
## BuildingManager so rent_strip flips tillability live, exactly as it does
## in the running game (off-tree, /root/BuildingManager never resolves).
var _test_building_manager: Node = null

## ADR-034: which zone this grid instance simulates. Set by ZoneManager (or
## main.gd at boot) BEFORE the node enters the tree so _ready() can build the
## right zone's grid; empty reads as DEFAULT_ZONE_ID (the scene's original
## single FarmGrid, and the live active zone for all of Sprint 15a).
var _zone_id: String = ""

var _grid_width: int = 30
var _grid_height: int = 20
var _cells: Array[Array] = []
var _daily_dig_count: int = 0
## ADR-040: the lord's demesne footprint and chores.json's demesne block.
## Empty rect (-1,-1,0,0) = no demesne configured (all pre-ADR-040 suites).
var _demesne_rect := Rect2i(-1, -1, 0, 0)
var _demesne_cfg: Dictionary = {}


func _ready() -> void:
	if _test_mode:
		_build_test_grid()
	else:
		var game_data := _game_data()
		if game_data != null:
			_grid_width = game_data.get_map_width(_resolved_zone_id())
			_grid_height = game_data.get_map_height(_resolved_zone_id())
			# ADR-034 note: stewards_demesne lives in the manor zone's feature
			# list, not fallowfield's - only the manor zone's own FarmGrid
			# instance resolves a non-empty rect here. Every other zone
			# (including fallowfield, the only zone reachable before Sprint
			# 15b ships zone transitions) correctly gets the empty rect, so
			# the spatial demesne chores are inert until the player can
			# physically reach the manor - see DEVELOPMENT_STATE.md's
			# post-merge reconciliation entry.
			_demesne_rect = game_data.get_feature_rect("stewards_demesne", _resolved_zone_id())
			_demesne_cfg = game_data.get_demesne_config()
		_build_live_grid()


func configure_for_test(
	crop_db: Dictionary, soil_map: Dictionary, soil_properties: Dictionary, grid_size: Vector2i,
	forage_cfg: Dictionary = {}, owned_rects: Array[Rect2i] = [], zone_id := "",
	demesne_rect := Rect2i(-1, -1, 0, 0), demesne_cfg: Dictionary = {}
) -> void:
	_test_mode = true
	_zone_id = zone_id
	_test_grid_size = grid_size
	_test_crop_db = crop_db
	_test_soil_map = soil_map
	_test_soil_properties = soil_properties
	_test_forage_cfg = forage_cfg
	_test_owned_rects = owned_rects
	_demesne_rect = demesne_rect
	_demesne_cfg = demesne_cfg
	_build_test_grid()


func set_zone_id(zone_id: String) -> void:
	_zone_id = zone_id


func get_zone_id() -> String:
	return _zone_id


func get_grid_size() -> Vector2i:
	return Vector2i(_grid_width, _grid_height)


func till_tile(pos: Vector2i, force := false) -> bool:
	if not _is_within_bounds(pos):
		return false
	# ADR-023: tenure gates tilling only. force bypasses ownership for the
	# rare call sites that must work regardless (none today, but the seam is
	# cheap and keeps force's historical semantics intact). ADR-040 uses the
	# same bypass for the lord's demesne: the steward's land is not owned by
	# the player, yet the till_demesne chore must till it.
	if not force and not _is_owned(pos):
		return false
	var cell: Dictionary = _cells[pos.y][pos.x]
	if bool(cell.get("tilled", false)):
		return false
	if str(cell.get("soil", "")).is_empty():
		return false
	if not force and not _test_mode and _get_weather_manager() != null \
			and _get_weather_manager().is_snowing():
		return false
	# ADR-040: a stored sheaf occupies the tile - the player must clear it
	# (harvest_demesne) before tilling the lord's field under it.
	if bool(cell.get("demesne_sheaf", false)):
		return false
	cell["tilled"] = true
	cell["moisture"] = 0.0
	tile_changed.emit(pos)
	return true


## Playtest fix: read-only mirror of till_tile()'s precondition chain (the
## same documented-mirror-pair convention as can_dig()/dig_cell() above) -
## used by ToolManager.get_action_info() to preview a hoe swing's per-tile
## validity for the target indicator without actually tilling anything.
## Kept in sync by hand; any till_tile() gate change must be mirrored here.
func can_till(pos: Vector2i, force := false) -> bool:
	if not _is_within_bounds(pos):
		return false
	if not force and not _is_owned(pos):
		return false
	var cell: Dictionary = _cells[pos.y][pos.x]
	if bool(cell.get("tilled", false)):
		return false
	if str(cell.get("soil", "")).is_empty():
		return false
	if not force and not _test_mode and _get_weather_manager() != null \
			and _get_weather_manager().is_snowing():
		return false
	if bool(cell.get("demesne_sheaf", false)):
		return false
	return true


func plant(pos: Vector2i, crop_id: String) -> int:
	## Returns 0=ok, 1=not tilled, 2=already planted, 3=wrong season,
	## 4=unknown crop, 5=fertility too low (E2), 6=demesne (ADR-040 - the
	## lord's land is never the player's field).
	if not _is_within_bounds(pos):
		return 4
	if is_demesne_tile(pos):
		return 6
	var cell: Dictionary = _cells[pos.y][pos.x]
	if not bool(cell.get("tilled", false)):
		return 1
	if not str(cell.get("crop_id", "")).is_empty():
		return 2
	var crop_data := _crop_lookup(crop_id)
	if crop_data.is_empty():
		return 4
	var season := _current_season()
	if not (crop_data.get("seasons", []) as Array).has(season):
		return 3
	if float(cell.get("fertility", 100.0)) < float(crop_data.get("fertility_min", 0)):
		return 5
	cell["crop_id"] = crop_id
	cell["growth_progress"] = 0.0
	cell["days_mature"] = 0
	# Clamp rain-soaked soil to the crop's moisture max - a bare tilled cell
	# that caught rain sits at 100, and planting into it must not leave the
	# cell unrecoverably over-max (ADR-015).
	cell["moisture"] = minf(float(cell.get("moisture", 0.0)), float(crop_data.get("moisture_max", 100)))
	tile_changed.emit(pos)
	return 0


## Playtest fix: read-only mirror of plant()'s precondition chain - same
## return codes, no mutation. Used by ToolManager.get_action_info() to
## preview a seed planting without consuming the seed or touching cell
## state. Kept in sync by hand; any plant() gate change must be mirrored
## here.
func can_plant(pos: Vector2i, crop_id: String) -> int:
	if not _is_within_bounds(pos):
		return 4
	if is_demesne_tile(pos):
		return 6
	var cell: Dictionary = _cells[pos.y][pos.x]
	if not bool(cell.get("tilled", false)):
		return 1
	if not str(cell.get("crop_id", "")).is_empty():
		return 2
	var crop_data := _crop_lookup(crop_id)
	if crop_data.is_empty():
		return 4
	var season := _current_season()
	if not (crop_data.get("seasons", []) as Array).has(season):
		return 3
	if float(cell.get("fertility", 100.0)) < float(crop_data.get("fertility_min", 0)):
		return 5
	return 0


func water_tile(pos: Vector2i, amount: float) -> bool:
	if not _is_within_bounds(pos):
		return false
	var cell: Dictionary = _cells[pos.y][pos.x]
	if not bool(cell.get("tilled", false)):
		return false
	cell["moisture"] = clampf(float(cell.get("moisture", 0.0)) + amount, 0.0, 100.0)
	tile_changed.emit(pos)
	return true


## Applies a fertilizer amount (compost's effect) to a tilled cell.
## FarmGrid has no knowledge of items.json - ToolManager reads
## compost's fertilize_amount and passes it in, the same way water_tile
## takes its amount rather than looking up the watering can itself.
func apply_compost(pos: Vector2i, amount: float) -> bool:
	if not _is_within_bounds(pos):
		return false
	var cell: Dictionary = _cells[pos.y][pos.x]
	if not bool(cell.get("tilled", false)):
		return false
	var new_fertility := clampf(float(cell.get("fertility", 100.0)) + amount, 0.0, 100.0)
	cell["fertility"] = new_fertility
	fertility_changed.emit(pos, new_fertility)
	tile_changed.emit(pos)
	return true


func harvest(pos: Vector2i) -> Array[Dictionary]:
	if not is_harvestable(pos):
		return []
	var cell: Dictionary = _cells[pos.y][pos.x]
	var crop_id := str(cell.get("crop_id", ""))
	var crop_data := _crop_lookup(crop_id)
	if crop_data.is_empty():
		return []
	var soil := str(cell.get("soil", ""))
	var soil_props := _soil_properties(soil)
	var skill := get_node_or_null("/root/SkillManager")
	var choice_bonus := int(skill.get_effect("farming", "quality_choice_bonus", 0)) if skill != null else 0
	# E2: fertility at or above the soil's threshold adds extra choice weight,
	# rewarding sustained land care the same way skill perks already do.
	var fertility := float(cell.get("fertility", 100.0))
	if fertility >= float(soil_props.get("high_fertility_threshold", 60)):
		choice_bonus += int(soil_props.get("high_fertility_quality_bonus", 0))
	var quality := _roll_quality(crop_data, soil_props, choice_bonus)
	var spoil_after := int(crop_data.get("spoil_after_days", 0))
	if spoil_after > 0 and int(cell.get("days_mature", 0)) > spoil_after:
		quality = "common"
	var yield_count := randi_range(int(crop_data.get("yield_min", 1)), int(crop_data.get("yield_max", 1)))
	var seed_count := randi_range(
		int(crop_data.get("seed_recovery_min", 1)), int(crop_data.get("seed_recovery_max", 1)))
	cell["crop_id"] = ""
	cell["growth_progress"] = 0.0
	cell["days_mature"] = 0
	# E2: harvest depletes fertility (a negative fertility_depletion, e.g.
	# peas, restores it instead - the cover-crop case).
	var new_fertility := clampf(fertility - float(crop_data.get("fertility_depletion", 0)), 0.0, 100.0)
	cell["fertility"] = new_fertility
	fertility_changed.emit(pos, new_fertility)
	var results: Array[Dictionary] = []
	if yield_count > 0:
		results.append({
			"item_id": str(crop_data.get("yield_item_id", crop_id)),
			"quality": quality,
			"count": yield_count,
		})
	if seed_count > 0:
		results.append({
			"item_id": str(crop_data.get("seed_item_id", "")),
			"quality": "common",
			"count": seed_count,
		})
	crop_harvested.emit(crop_id, str(crop_data.get("yield_item_id", crop_id)), quality, yield_count, seed_count)
	tile_changed.emit(pos)
	if skill != null:
		skill.add_xp_for("farming", "harvest_%s" % quality)
	return results


func has_forage(pos: Vector2i) -> bool:
	if not _is_within_bounds(pos):
		return false
	return not str(_cells[pos.y][pos.x].get("forage_item_id", "")).is_empty()


func gather_forage(pos: Vector2i) -> Dictionary:
	if not has_forage(pos):
		return {}
	var cell: Dictionary = _cells[pos.y][pos.x]
	var item_id := str(cell.get("forage_item_id", ""))
	var count := int(cell.get("forage_yield", 0))
	cell["forage_item_id"] = ""
	cell["forage_yield"] = 0
	tile_changed.emit(pos)
	forage_gathered.emit(pos, item_id, count)
	return {"item_id": item_id, "count": count}


## Whether the spade can dig this cell right now: in bounds, untilled, and
## under forage.json's max_digs_per_day (E12's anti-exploit throttle -
## digging is deliberately uncapped by tile state, only by a daily budget,
## since it doesn't mark or consume the tile the way gathering does).
func can_dig(pos: Vector2i) -> bool:
	if not _is_within_bounds(pos):
		return false
	if bool(_cells[pos.y][pos.x].get("tilled", false)):
		return false
	var max_digs := int(_forage_config().get("max_digs_per_day", 0))
	return _daily_dig_count < max_digs


## Digs an untilled cell against forage.json's dig_loot table (E12) - mostly
## buried forageables, rare finds well-throttled by weight and season. A
## dedicated table, not a gate on the passive spawns system (matches the
## "own loot table, not hidden visuals" design intent). Returns {} if
## can_dig() fails (no attempt, no counter spent); otherwise always returns a
## result dict, even a miss ("item_id": "") - a miss is still a real attempt
## and counts against the daily cap. No cell state changes: digging doesn't
## consume or mark the tile the way gathering does.
func dig_cell(pos: Vector2i) -> Dictionary:
	if not can_dig(pos):
		return {}
	var soil := str(_cells[pos.y][pos.x].get("soil", ""))
	_daily_dig_count += 1
	var picked := _pick_dig_loot(soil, _forage_config())
	var item_id := str(picked.get("item_id", ""))
	if item_id.is_empty():
		return {"item_id": "", "count": 0, "is_rare": false}
	var count := randi_range(int(picked.get("yield_min", 1)), int(picked.get("yield_max", 1)))
	return {"item_id": item_id, "count": count, "is_rare": bool(picked.get("is_rare", false))}


## ADR-040: whether a tile is inside the lord's demesne footprint. FarmGrid
## owns the rect (from GameData live, injected in tests) so every spatial
## chore gate reads one source of truth.
func is_demesne_tile(pos: Vector2i) -> bool:
	return pos.x >= _demesne_rect.position.x and pos.x < _demesne_rect.end.x \
		and pos.y >= _demesne_rect.position.y and pos.y < _demesne_rect.end.y


func get_demesne_rect() -> Rect2i:
	return _demesne_rect


func get_demesne_cfg() -> Dictionary:
	return _demesne_cfg


## A tile currently holding one stored sheaf (ADR-040): in the demesne rect,
## untilled, and marked. The chest anchor tile never holds one - see
## replenish_demesne_sheaves.
func is_demesne_sheaf_tile(pos: Vector2i) -> bool:
	if not is_demesne_tile(pos) or not _is_within_bounds(pos):
		return false
	var cell: Dictionary = _cells[pos.y][pos.x]
	return bool(cell.get("demesne_sheaf", false)) \
		and not bool(cell.get("tilled", false))


func count_demesne_sheaves() -> int:
	var count := 0
	for y in range(_grid_height):
		for x in range(_grid_width):
			if bool(_cells[y][x].get("demesne_sheaf", false)):
				count += 1
	return count


## Removes one stored sheaf marker (the harvest_demesne action). FarmGrid
## only clears tile state - TitheManager owns the chore credit and carry
## state; nothing here touches inventory.
func take_demesne_sheaf(pos: Vector2i) -> bool:
	if not is_demesne_sheaf_tile(pos):
		return false
	_cells[pos.y][pos.x]["demesne_sheaf"] = false
	tile_changed.emit(pos)
	return true


## Adds stored-sheaf markers back to the demesne on the configured cadence
## (chores.json's sheaves_replenish_interval_days). One marker per tile,
## never on the tithe-chest anchor tile, never on tilled ground, capped at
## sheaves_max - the backlog is spatial and finite, so harvest_demesne can
## never be spammed past what the yard physically holds.
func replenish_demesne_sheaves(day: int) -> void:
	if _demesne_rect.size.x <= 0 or _demesne_rect.size.y <= 0:
		return
	var interval := int(_demesne_cfg.get("sheaves_replenish_interval_days", 1))
	if interval <= 0 or day % interval != 0:
		return
	var max_count := int(_demesne_cfg.get("sheaves_max", 0))
	var current := count_demesne_sheaves()
	if current >= max_count:
		return
	var amount := mini(
		int(_demesne_cfg.get("sheaves_replenish_amount", 0)), max_count - current)
	if amount <= 0:
		return
	var added := 0
	for y in range(_demesne_rect.position.y, _demesne_rect.end.y):
		for x in range(_demesne_rect.position.x, _demesne_rect.end.x):
			var pos := Vector2i(x, y)
			if pos == _demesne_rect.position:
				continue  # the tithe-chest anchor tile never stores sheaves
			if not _is_within_bounds(pos):
				continue
			var cell: Dictionary = _cells[pos.y][pos.x]
			if bool(cell.get("tilled", false)) or bool(cell.get("demesne_sheaf", false)):
				continue
			cell["demesne_sheaf"] = true
			tile_changed.emit(pos)
			added += 1
			if added >= amount:
				return


func advance_day(rain: bool, overcast: bool = false, day: int = 1) -> void:
	_daily_dig_count = 0
	# ADR-040: the steward's stored-sheaf backlog is refilled on the day
	# cadence from chores.json - the day rollover is the work-shift boundary.
	replenish_demesne_sheaves(day)
	var active_forage := _count_active_forage()
	var forage_cfg := _forage_config()
	var forage_chance := float(forage_cfg.get("spawn_chance_per_tile_per_day", 0.0))
	if not _test_mode:
		# ADR-034: per-zone forage_density scales the base daily spawn chance
		# (0.0 on occupied tenant land, low on civic margins, high on wilds).
		# Test-mode grids keep their injected forage_cfg untouched (and must
		# not hit /root lookups off-tree).
		var game_data := _game_data()
		if game_data != null:
			forage_chance *= float(game_data.get_zone_metadata(_resolved_zone_id()).get("forage_density", 1.0))
	var forage_cap := int(forage_cfg.get("max_concurrent_spawns", 0))
	var changed: Array[Vector2i] = []
	for y in range(_grid_height):
		for x in range(_grid_width):
			var cell: Dictionary = _cells[y][x]
			if str(cell.get("soil", "")).is_empty():
				continue
			var soil := str(cell.get("soil", ""))
			var soil_props := _soil_properties(soil)
			var crop_id := str(cell.get("crop_id", ""))
			var crop_data := _crop_lookup(crop_id)
			if rain:
				# Rain saturates bare soil; planted cells fill to the crop's
				# moisture max so a rain day counts as a watered growth day.
				if crop_data.is_empty():
					cell["moisture"] = 100.0
				else:
					cell["moisture"] = float(crop_data.get("moisture_max", 100))
			else:
				var decay := float(soil_props.get("moisture_decay_per_day", 0.0))
				if overcast:
					decay *= 0.5
				cell["moisture"] = maxf(
					0.0, float(cell.get("moisture", 0.0)) - decay)
			if not crop_data.is_empty():
				var min_m := float(crop_data.get("moisture_min", 0))
				var max_m := float(crop_data.get("moisture_max", 100))
				var moisture := float(cell.get("moisture", 0.0))
				if moisture >= min_m - GROWTH_EPSILON:
					var increment := (1.0 / float(crop_data.get("growth_days", 1))) \
						* float(soil_props.get("growth_speed_mult", 1.0))
					# Overwatering is a penalty, not a wall (ADR-015): above
					# the crop's max the increment is halved, never blocked.
					if moisture > max_m + GROWTH_EPSILON:
						increment *= 0.5
					var was_mature := float(cell.get("growth_progress", 0.0)) >= 1.0
					cell["growth_progress"] = clampf(
						float(cell.get("growth_progress", 0.0)) + increment, 0.0, 1.0)
					if not was_mature and float(cell.get("growth_progress", 0.0)) >= 1.0:
						crop_matured.emit(Vector2i(x, y))
			# E2: fallow recovery - tilled, unplanted land slowly regains
			# fertility every day, independent of weather.
			if bool(cell.get("tilled", false)) and crop_id.is_empty():
				var recovered := float(cell.get("fertility", 100.0)) \
					+ float(soil_props.get("fertility_recovery_per_day", 0.0))
				cell["fertility"] = clampf(recovered, 0.0, 100.0)
			# Maturity age drives the two-stage rot (ADR-018). Runs for every
			# cell so a harvested/empty tile also resets its age.
			if float(cell.get("growth_progress", 0.0)) >= 1.0:
				cell["days_mature"] = int(cell.get("days_mature", 0)) + 1
				var spoil_after := int(crop_data.get("spoil_after_days", 0))
				if spoil_after > 0 and int(cell["days_mature"]) > spoil_after * 2:
					cell["crop_id"] = ""
					cell["growth_progress"] = 0.0
					cell["days_mature"] = 0
					# E2: rot leaves a spoiled_crop pickup on the same tile,
					# gathered through the ordinary forage pipeline - not
					# granted directly (FarmGrid never touches inventory).
					cell["forage_item_id"] = "spoiled_crop"
					cell["forage_yield"] = 1
					crop_spoiled.emit(Vector2i(x, y))
			else:
				cell["days_mature"] = 0
			# Wild spawns only take root on untilled ground (ADR-022 - the
			# commons, not the player's own tillage).
			if not bool(cell.get("tilled", false)) and str(cell.get("forage_item_id", "")).is_empty():
				if forage_chance > 0.0 and active_forage < forage_cap and randf() < forage_chance:
					var picked := _pick_forage_item(soil, forage_cfg)
					if not picked.is_empty():
						cell["forage_item_id"] = str(picked.get("item_id", ""))
						cell["forage_yield"] = randi_range(
							int(picked.get("yield_min", 1)), int(picked.get("yield_max", 1)))
						active_forage += 1
			changed.append(Vector2i(x, y))
	for p: Vector2i in changed:
		tile_changed.emit(p)


func is_tilled(pos: Vector2i) -> bool:
	if not _is_within_bounds(pos):
		return false
	return bool(_cells[pos.y][pos.x].get("tilled", false))


func is_harvestable(pos: Vector2i) -> bool:
	if not _is_within_bounds(pos):
		return false
	var cell: Dictionary = _cells[pos.y][pos.x]
	return not str(cell.get("crop_id", "")).is_empty() and float(cell.get("growth_progress", 0.0)) >= 1.0


func get_cell(pos: Vector2i) -> Dictionary:
	if not _is_within_bounds(pos):
		return {}
	return _cells[pos.y][pos.x]


func get_cell_moisture(pos: Vector2i) -> float:
	return float(get_cell(pos).get("moisture", 0.0))


func get_cell_fertility(pos: Vector2i) -> float:
	return float(get_cell(pos).get("fertility", 100.0))


func get_soil(pos: Vector2i) -> String:
	return str(get_cell(pos).get("soil", ""))


## Public ownership wrapper for the HUD tooltip - tooltips must not reach
## into the private _is_owned.
func is_owned(pos: Vector2i) -> bool:
	if not _is_within_bounds(pos):
		return false
	return _is_owned(pos)


func get_crop_name(pos: Vector2i) -> String:
	var crop_id := str(get_cell(pos).get("crop_id", ""))
	if crop_id.is_empty():
		return ""
	var crop_data := _crop_lookup(crop_id)
	if crop_data.is_empty():
		return crop_id
	return str(crop_data.get("name", crop_id))


func tile_count() -> int:
	var count := 0
	for y in range(_grid_height):
		for x in range(_grid_width):
			if bool(_cells[y][x].get("tilled", false)):
				count += 1
	return count


func planted_count() -> int:
	var count := 0
	for y in range(_grid_height):
		for x in range(_grid_width):
			if not str(_cells[y][x].get("crop_id", "")).is_empty():
				count += 1
	return count


func to_dict() -> Dictionary:
	var cells: Array = []
	for y in range(_grid_height):
		for x in range(_grid_width):
			var c: Dictionary = _cells[y][x]
			cells.append({
				"x": x,
				"y": y,
				"tilled": bool(c.get("tilled", false)),
				"crop_id": str(c.get("crop_id", "")),
				"growth_progress": float(c.get("growth_progress", 0.0)),
				"moisture": float(c.get("moisture", 0.0)),
				"days_mature": int(c.get("days_mature", 0)),
				"forage_item_id": str(c.get("forage_item_id", "")),
				"forage_yield": int(c.get("forage_yield", 0)),
				"fertility": float(c.get("fertility", 100.0)),
				"demesne_sheaf": bool(c.get("demesne_sheaf", false)),
			})
	return {"cells": cells, "daily_dig_count": _daily_dig_count}


func from_dict(data: Dictionary) -> void:
	for y in range(_grid_height):
		for x in range(_grid_width):
			var cell: Dictionary = _cells[y][x]
			cell["tilled"] = false
			cell["crop_id"] = ""
			cell["growth_progress"] = 0.0
			cell["moisture"] = 0.0
			cell["forage_item_id"] = ""
			cell["forage_yield"] = 0
			cell["demesne_sheaf"] = false
	var cells: Array = data.get("cells", data.get("tiles", []))
	for entry: Variant in cells:
		var e := entry as Dictionary
		var pos := Vector2i(int(e.get("x", -1)), int(e.get("y", -1)))
		if not _is_within_bounds(pos):
			continue
		var cell: Dictionary = _cells[pos.y][pos.x]
		cell["tilled"] = bool(e.get("tilled", false))
		cell["crop_id"] = str(e.get("crop_id", ""))
		cell["days_mature"] = int(e.get("days_mature", 0))
		cell["forage_item_id"] = str(e.get("forage_item_id", ""))
		cell["forage_yield"] = int(e.get("forage_yield", 0))
		# ADR-040: a restored save's sheaf markers survive the roundtrip;
		# old saves default to none (replenishment refills on the next day).
		cell["demesne_sheaf"] = bool(e.get("demesne_sheaf", false))
		# E2: fertility survives regardless of tilled state (it's a property
		# of the land, not the crop); 100.0 default matches the v14
		# migration's "existing saves get full fertility" rule even when
		# this runs outside SaveManager's own migration path.
		cell["fertility"] = float(e.get("fertility", 100.0))
		if bool(cell["tilled"]):
			cell["growth_progress"] = float(e.get("growth_progress", 0.0))
			cell["moisture"] = float(e.get("moisture", 0.0))
	_daily_dig_count = int(data.get("daily_dig_count", 0))
	for y in range(_grid_height):
		for x in range(_grid_width):
			tile_changed.emit(Vector2i(x, y))


func _build_live_grid() -> void:
	_cells.clear()
	var game_data := _game_data()
	for y in range(_grid_height):
		var row: Array = []
		for x in range(_grid_width):
			var soil := ""
			if game_data != null:
				soil = game_data.get_soil_at(x, y, _resolved_zone_id())
			row.append(_default_cell(soil))
		_cells.append(row)


func _build_test_grid() -> void:
	_cells.clear()
	_grid_width = _test_grid_size.x
	_grid_height = _test_grid_size.y
	for y in range(_grid_height):
		var row: Array = []
		for x in range(_grid_width):
			row.append(_default_cell(str(_test_soil_map.get(Vector2i(x, y), ""))))
		_cells.append(row)


func _default_cell(soil: String) -> Dictionary:
	# E2: fertility starts from the soil's own fertility_init - a bare,
	# untilled cell already carries the land's condition, tilling doesn't
	# change it.
	var fertility := 100.0
	if not soil.is_empty():
		fertility = float(_soil_properties(soil).get("fertility_init", 70))
	return {
		"tilled": false,
		"crop_id": "",
		"growth_progress": 0.0,
		"moisture": 0.0,
		"days_mature": 0,
		"soil": soil,
		"forage_item_id": "",
		"forage_yield": 0,
		"fertility": fertility,
		"demesne_sheaf": false,
	}


func _is_within_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < _grid_width and pos.y >= 0 and pos.y < _grid_height


## Live path asks BuildingManager; test mode uses the injected owned rects
## (empty array = unrestricted, so every pre-Sprint-9 suite keeps compiling
## and passing without tenure fixtures).
func _is_owned(pos: Vector2i) -> bool:
	if _test_mode:
		if _test_building_manager != null:
			return _test_building_manager.is_land_owned_in_zone(_resolved_zone_id(), pos)
		return _test_owned_rects.is_empty() or _rect_list_contains(_test_owned_rects, pos)
	var bm := get_node_or_null("/root/BuildingManager")
	if bm == null:
		return true  # Sprint 6/7/8 saves and tests predate BuildingManager - don't retroactively block tilling
	return bm.is_land_owned_in_zone(_resolved_zone_id(), pos)


func _rect_list_contains(rects: Array[Rect2i], pos: Vector2i) -> bool:
	for rect: Rect2i in rects:
		if pos.x >= rect.position.x and pos.x < rect.position.x + rect.size.x \
				and pos.y >= rect.position.y and pos.y < rect.position.y + rect.size.y:
			return true
	return false


func _get_weather_manager() -> Node:
	return get_node_or_null("/root/WeatherManager")


func _game_data() -> Node:
	return get_node_or_null("/root/GameData")


func _resolved_zone_id() -> String:
	## The scene's $FarmGrid enters the tree before main.gd can set its zone
	## id, so an empty _zone_id reads as the default zone (Fallowfield) -
	## the same alias GameData's own accessors use. Grids built by
	## ZoneManager get their real zone id set before add_child().
	return _zone_id if not _zone_id.is_empty() else DEFAULT_ZONE_ID


func _current_season() -> String:
	if _test_mode:
		return "spring"
	var time_manager := get_node_or_null("/root/TimeManager")
	if time_manager == null:
		return "spring"
	return str(time_manager.get("season")).to_lower()


func _crop_lookup(crop_id: String) -> Dictionary:
	if _test_mode:
		return _test_crop_db.get(crop_id, {})
	var game_data := _game_data()
	if game_data == null:
		return {}
	return game_data.get_crop(crop_id)


func _soil_properties(soil: String) -> Dictionary:
	if _test_mode:
		return _test_soil_properties.get(soil, {})
	var game_data := _game_data()
	if game_data == null:
		return {}
	return game_data.get_soil_properties(soil)


func _roll_quality(crop_data: Dictionary, soil_props: Dictionary, extra_choice_weight: int = 0) -> String:
	var weights: Dictionary = crop_data.get("quality_weights", {})
	var common_w := maxi(0, int(weights.get("common", 80)))
	var fine_w := maxi(0, int(weights.get("fine", 15)) + int(soil_props.get("fine_quality_bonus", 0)))
	var choice_w := maxi(0, int(weights.get("choice", 5)) + int(soil_props.get("choice_quality_bonus", 0))
		+ extra_choice_weight)
	var total := float(common_w + fine_w + choice_w)
	if total <= 0.0:
		return "common"
	var roll := randf() * total
	if roll < float(common_w):
		return "common"
	if roll < float(common_w + fine_w):
		return "fine"
	return "choice"


func _count_active_forage() -> int:
	var count := 0
	for y in range(_grid_height):
		for x in range(_grid_width):
			if not str(_cells[y][x].get("forage_item_id", "")).is_empty():
				count += 1
	return count


func _pick_forage_item(soil: String, cfg: Dictionary) -> Dictionary:
	var entries: Array = cfg.get("spawns", {}).get(soil, [])
	return _weighted_pick(entries)


## E12: dig_loot entries may carry a season array (absent = every season);
## filtered out-of-season entries never enter the weighted pick, so an
## unreachable rare (e.g. truffle this slice) never displaces another
## outcome's odds.
func _pick_dig_loot(soil: String, cfg: Dictionary) -> Dictionary:
	var entries: Array = cfg.get("dig_loot", {}).get(soil, [])
	var season := _current_season()
	var filtered: Array = []
	for e: Variant in entries:
		var entry := e as Dictionary
		if not entry.has("season") or (entry.get("season", []) as Array).has(season):
			filtered.append(entry)
	return _weighted_pick(filtered)


func _weighted_pick(entries: Array) -> Dictionary:
	if entries.is_empty():
		return {}
	var total := 0.0
	for e: Variant in entries:
		total += float((e as Dictionary).get("weight", 0))
	if total <= 0.0:
		return {}
	var roll := randf() * total
	var cumulative := 0.0
	for e: Variant in entries:
		var entry := e as Dictionary
		cumulative += float(entry.get("weight", 0))
		if roll < cumulative:
			return entry
	return {}


func _forage_config() -> Dictionary:
	if _test_mode:
		return _test_forage_cfg
	var gd := _game_data()
	if gd == null:
		return {}
	return gd.get_forage_config()
