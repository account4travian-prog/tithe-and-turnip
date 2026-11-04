extends RefCounted
## Playtest fix (item 4) coverage: Player._interact_hold_step's transition
## table, UIManager._resolve_pause_action's Esc-vs-pause routing, and
## ToolManager's per-tile get_action_info() branches (hoe/watering-can/seed/
## material/spade validity) against a REAL FarmGrid via configure_for_test -
## the same off-tree pattern test_forage.gd and test_combat_weapons.gd
## already use. Does not invoke TargetIndicatorRenderer._draw() itself - no
## live CanvasItem draw context headless, same limitation test_iso_terrain.gd
## documents; the renderer's own logic is a thin read of these two chains.

const PLAYER_SCRIPT := preload("res://scripts/player/player.gd")
const UI_MANAGER_SCRIPT := preload("res://scripts/autoloads/ui_manager.gd")
const FARM_GRID_SCRIPT := preload("res://scripts/world/farm_grid.gd")
const PLAYER_STATE_SCRIPT := preload("res://scripts/autoloads/player_state.gd")
const TOOL_MANAGER_SCRIPT := preload("res://scripts/world/tool_manager.gd")

const CROP_DB := {
	"turnip": {"seasons": ["spring"], "fertility_min": 0, "moisture_max": 80},
}
const SOIL_PROPS := {
	"loamy": {"moisture_decay_per_day": 1.0, "growth_speed_mult": 1.0,
		"fine_quality_bonus": 0, "choice_quality_bonus": 0},
}
const HOE := {"id": "hoe_wood", "type": "tool", "tool_category": "hoe",
	"area_shape": "single", "energy_cost": 4}
const IRON_HOE := {"id": "hoe_iron", "type": "tool", "tool_category": "hoe",
	"area_shape": "line_3x1", "energy_cost": 4}
const CAN := {"id": "can_wood", "type": "tool", "tool_category": "watering_can",
	"area_shape": "single", "energy_cost": 2, "water_amount": 25, "capacity": 50}
const SEED := {"id": "turnip_seed", "type": "seed", "crop_id": "turnip", "name": "Turnip Seeds"}
const COMPOST := {"id": "compost", "type": "material", "name": "Compost", "fertilize_amount": 10}
## can_dig() gates on max_digs_per_day (via _forage_config, which returns
## _test_forage_cfg verbatim in test mode) - an empty {} would default it to
## 0 and make can_dig() always false regardless of tile state, so every grid
## in this suite gets a real cap.
const FORAGE_CFG := {"max_digs_per_day": 8}


func suite_name() -> String:
	return "interact_hold"


func run(t: Object) -> void:
	_test_hold_step_start(t)
	_test_hold_step_commit(t)
	_test_hold_step_stray_release_ignored(t)
	_test_hold_step_menu_open_cancels(t)
	_test_hold_step_menu_open_blocks_start(t)
	_test_hold_step_press_and_release_same_tick(t)
	_test_pause_routing(t)
	_test_farm_grid_can_till(t)
	_test_farm_grid_can_plant(t)
	_test_hoe_info_single_tile(t)
	_test_hoe_info_line_partial_validity(t)
	_test_watering_can_info(t)
	_test_seed_info(t)
	_test_material_info(t)
	_test_spade_info(t)
	_test_energy_gates_aggregate_not_per_tile(t)
	_test_mirror_drift_guard(t)
	_test_single_tile_branches_return_typed_tiles_array(t)
	t.completed(18)


func _make_player():
	return PLAYER_SCRIPT.new()


func _make_ui():
	return UI_MANAGER_SCRIPT.new()


func _make_grid(owned: Array[Rect2i] = []) -> Object:
	var grid = FARM_GRID_SCRIPT.new()
	var soil_map := {}
	for y in range(3):
		for x in range(4):
			soil_map[Vector2i(x, y)] = "loamy"
	grid.configure_for_test(CROP_DB, soil_map, SOIL_PROPS, Vector2i(4, 3), FORAGE_CFG, owned)
	return grid


func _make_tool_manager(grid: Object, ps: Object) -> Object:
	var tm = TOOL_MANAGER_SCRIPT.new()
	tm.init(ps, grid)
	return tm


## --- Player._interact_hold_step ---------------------------------------

func _test_hold_step_start(t: Object) -> void:
	var player = _make_player()
	var step: Dictionary = player._interact_hold_step(false, true, false, false)
	t.ok(bool(step.get("holding")), "press while idle enters holding")
	t.eq(str(step.get("event")), "start", "press while idle reports the start event")
	t.section_done("hold step start")


func _test_hold_step_commit(t: Object) -> void:
	var player = _make_player()
	var step: Dictionary = player._interact_hold_step(true, false, true, false)
	t.not_ok(bool(step.get("holding")), "release while holding exits holding")
	t.eq(str(step.get("event")), "commit", "release while holding reports the commit event")
	t.section_done("hold step commit")


func _test_hold_step_stray_release_ignored(t: Object) -> void:
	var player = _make_player()
	var step: Dictionary = player._interact_hold_step(false, false, true, false)
	t.not_ok(bool(step.get("holding")), "a release while already idle stays idle")
	t.eq(str(step.get("event")), "none", "a stray release with no prior hold is a no-op")
	t.section_done("hold step stray release")


func _test_hold_step_menu_open_cancels(t: Object) -> void:
	var player = _make_player()
	var step: Dictionary = player._interact_hold_step(true, false, false, true)
	t.not_ok(bool(step.get("holding")), "a menu opening mid-hold clears holding")
	t.eq(str(step.get("event")), "cancel", "a menu opening mid-hold reports the cancel event")
	t.section_done("hold step menu cancels")


func _test_hold_step_menu_open_blocks_start(t: Object) -> void:
	var player = _make_player()
	var step: Dictionary = player._interact_hold_step(false, true, false, true)
	t.not_ok(bool(step.get("holding")), "a press cannot start a hold while a menu is open")
	t.eq(str(step.get("event")), "none", "press-with-menu-open is a no-op, not cancel (nothing was holding)")
	t.section_done("hold step menu blocks start")


func _test_hold_step_press_and_release_same_tick(t: Object) -> void:
	var player = _make_player()
	var step: Dictionary = player._interact_hold_step(false, true, true, false)
	t.not_ok(bool(step.get("holding")), "a same-tick press+release ends idle, not stuck holding")
	t.eq(str(step.get("event")), "commit", "a same-tick press+release still commits exactly once (a fast tap still works)")
	t.section_done("hold step same-tick tap")


## --- UIManager._resolve_pause_action -----------------------------------

func _test_pause_routing(t: Object) -> void:
	var ui = _make_ui()
	t.eq(ui._resolve_pause_action(false, false, false), "none", "no press is always none")
	t.eq(ui._resolve_pause_action(false, false, true), "open_pause", "plain Escape with nothing open opens pause")
	t.eq(ui._resolve_pause_action(false, true, true), "close_top", "Escape with a menu open closes it, hold or not")
	t.eq(ui._resolve_pause_action(true, false, true), "cancel_hold", "Escape mid-hold with no menu open cancels the hold, not pause")
	t.eq(ui._resolve_pause_action(true, true, true), "close_top",
		"a menu open always wins over a stale hold flag - Escape can never be stranded")
	t.section_done("pause routing")


## --- FarmGrid.can_till / can_plant (read-only mirrors) -----------------

func _test_farm_grid_can_till(t: Object) -> void:
	var grid := _make_grid()
	var pos := Vector2i(0, 0)
	t.ok(grid.can_till(pos), "an untilled, in-bounds, soiled cell is tillable")
	grid.till_tile(pos)
	t.not_ok(grid.can_till(pos), "an already-tilled cell is not tillable again")
	t.not_ok(grid.can_till(Vector2i(-1, 0)), "an out-of-bounds cell is never tillable")
	t.section_done("can_till")


func _test_farm_grid_can_plant(t: Object) -> void:
	var grid := _make_grid()
	var pos := Vector2i(1, 0)
	t.eq(grid.can_plant(pos, "turnip"), 1, "planting an untilled cell returns code 1 (not tilled)")
	grid.till_tile(pos)
	t.eq(grid.can_plant(pos, "turnip"), 0, "planting a tilled, in-season, empty cell returns code 0 (ok)")
	t.eq(grid.can_plant(pos, "nonexistent_crop"), 4, "an unknown crop id returns code 4")
	t.section_done("can_plant")


## --- ToolManager.get_action_info branches -------------------------------

func _test_hoe_info_single_tile(t: Object) -> void:
	var grid := _make_grid()
	var ps = PLAYER_STATE_SCRIPT.new()
	ps.energy = 100.0
	var tm = _make_tool_manager(grid, ps)
	var target := Vector2i(0, 0)
	var info: Dictionary = tm._hoe_info(HOE, target)
	t.ok(bool(info.get("valid")), "an untilled tile is a valid hoe target")
	t.eq((info.get("tiles") as Array).size(), 1, "a single-shape hoe reports exactly one tile")
	t.ok(bool((info.get("tile_valid") as Dictionary).get(target)), "the single tile's own validity matches the aggregate")
	grid.till_tile(target)
	var info_after: Dictionary = tm._hoe_info(HOE, target)
	t.not_ok(bool(info_after.get("valid")), "an already-tilled tile is not a valid hoe target")
	t.eq(str(info_after.get("text")), "Till the Soil", "hoe text names the action regardless of validity")
	t.section_done("hoe info single tile")


func _test_hoe_info_line_partial_validity(t: Object) -> void:
	var grid := _make_grid()
	var centre := Vector2i(1, 1)
	grid.till_tile(centre)  # the middle of the 3-wide row is already tilled
	var ps = PLAYER_STATE_SCRIPT.new()
	ps.energy = 100.0
	var tm = _make_tool_manager(grid, ps)
	var info: Dictionary = tm._hoe_info(IRON_HOE, centre)
	var tile_valid: Dictionary = info.get("tile_valid", {})
	t.eq((info.get("tiles") as Array).size(), 3, "the iron hoe's line_3x1 reports three tiles")
	t.not_ok(bool(tile_valid.get(centre)), "the already-tilled middle tile is invalid")
	t.ok(bool(tile_valid.get(Vector2i(0, 1))), "the untilled left tile is valid")
	t.ok(bool(tile_valid.get(Vector2i(2, 1))), "the untilled right tile is valid")
	t.ok(bool(info.get("valid")),
		"the aggregate is valid because at least one tile in the row is tillable - a partial row is not a total miss")
	t.section_done("hoe info line partial validity")


func _test_watering_can_info(t: Object) -> void:
	var grid := _make_grid()
	var target := Vector2i(0, 0)
	grid.till_tile(target)
	var ps = PLAYER_STATE_SCRIPT.new()
	ps.energy = 100.0
	var tm = _make_tool_manager(grid, ps)
	tm._current_water = 50.0
	var info: Dictionary = tm._watering_can_info(CAN, target)
	t.ok(bool(info.get("valid")), "a tilled tile with enough water is a valid watering-can target")
	tm._current_water = 5.0
	var empty_info: Dictionary = tm._watering_can_info(CAN, target)
	t.not_ok(bool(empty_info.get("valid")), "an empty can cannot water even a tilled tile")
	t.eq(str(empty_info.get("text")), "Watering Can Empty", "an empty can reports its own distinct text")
	t.section_done("watering can info")


func _test_seed_info(t: Object) -> void:
	var grid := _make_grid()
	var target := Vector2i(0, 0)
	grid.till_tile(target)
	var ps = PLAYER_STATE_SCRIPT.new()
	var tm = _make_tool_manager(grid, ps)
	var no_seed_info: Dictionary = tm._seed_item_info(SEED, target)
	t.not_ok(bool(no_seed_info.get("valid")), "planting without holding the seed is invalid")
	ps.add_item("turnip_seed", 1)
	var with_seed_info: Dictionary = tm._seed_item_info(SEED, target)
	t.ok(bool(with_seed_info.get("valid")), "planting a held, in-season seed on an empty tilled tile is valid")
	t.section_done("seed info")


func _test_material_info(t: Object) -> void:
	var grid := _make_grid()
	var target := Vector2i(0, 0)
	grid.till_tile(target)
	var ps = PLAYER_STATE_SCRIPT.new()
	var tm = _make_tool_manager(grid, ps)
	var no_compost_info: Dictionary = tm._material_item_info(COMPOST, target)
	t.not_ok(bool(no_compost_info.get("valid")), "applying compost without holding it is invalid")
	ps.add_item("compost", 1)
	var with_compost_info: Dictionary = tm._material_item_info(COMPOST, target)
	t.ok(bool(with_compost_info.get("valid")), "applying held compost to a tilled tile is valid")
	t.section_done("material info")


func _test_spade_info(t: Object) -> void:
	var grid := _make_grid()
	var target := Vector2i(0, 0)  # untilled - can_dig requires untilled + under the daily cap
	var ps = PLAYER_STATE_SCRIPT.new()
	ps.energy = 100.0
	var tm = _make_tool_manager(grid, ps)
	var spade := {"id": "spade", "type": "tool", "tool_category": "spade", "energy_cost": 4}
	var info: Dictionary = tm._tool_item_info(spade, target)
	t.ok(bool(info.get("valid")), "digging an untilled cell within the daily cap is valid")
	grid.till_tile(target)
	var tilled_info: Dictionary = tm._tool_item_info(spade, target)
	t.not_ok(bool(tilled_info.get("valid")), "a tilled cell cannot be dug")
	t.section_done("spade info")


## The aggregate `valid` (energy affordability) must gate the whole action
## without falsifying the per-tile gate list itself - the target indicator
## relies on this split to color a tile red for "can't afford it right now"
## the same way it would for "wrong tile", while ToolManager.use_tool()'s
## own energy check (consume_energy) still runs on the mutation path
## unchanged.
func _test_energy_gates_aggregate_not_per_tile(t: Object) -> void:
	var grid := _make_grid()
	var target := Vector2i(0, 0)
	var ps = PLAYER_STATE_SCRIPT.new()
	ps.energy = 1.0  # below HOE's energy_cost (4)
	var tm = _make_tool_manager(grid, ps)
	var info: Dictionary = tm._hoe_info(HOE, target)
	t.not_ok(bool(info.get("valid")), "insufficient energy makes the aggregate invalid")
	t.ok(bool((info.get("tile_valid") as Dictionary).get(target)),
		"the tile's own gate (tillable) still reports true - energy is an aggregate-only gate, not a tile gate")
	t.section_done("energy gates aggregate only")


## Mirror-drift guard (consult's testability recommendation): get_action_info's
## per-tile validity must agree with what the real mutating call actually
## does. Drives _use_hoe() directly with the same hand-built item dict and
## offsets/energy_cost _use_tool_item() would compute, rather than through
## the public use_tool() entry point - use_tool() resolves the equipped item
## via GameData.get_item(), which is unreachable off-tree (get_node_or_null
## returns null with no live autoload tree), the same constraint
## test_combat_weapons.gd's _use_tool_item()-direct calls already work
## around. A fresh grid per check so a successful mutation never pollutes
## the next assertion.
func _test_mirror_drift_guard(t: Object) -> void:
	var target := Vector2i(0, 0)

	var fresh_grid := _make_grid()
	var ps_a = PLAYER_STATE_SCRIPT.new()
	ps_a.energy = 100.0
	var tm_a = _make_tool_manager(fresh_grid, ps_a)
	var predicted_valid: bool = bool(tm_a._hoe_info(HOE, target).get("valid"))
	t.ok(predicted_valid, "predicted hoe validity on a fresh untilled tile is true")
	var offsets: Array[Vector2i] = tm_a._area_offsets(str(HOE.get("area_shape", "single")))
	var energy_cost: float = tm_a._energy_cost(HOE)
	var actual_result: bool = tm_a._use_hoe(HOE, target, offsets, energy_cost, null)
	t.eq(actual_result, predicted_valid,
		"the real _use_hoe() outcome on a fresh untilled tile agrees with get_action_info's prediction (both true)")

	var pretilled_grid := _make_grid()
	pretilled_grid.till_tile(target)
	var ps_b = PLAYER_STATE_SCRIPT.new()
	ps_b.energy = 100.0
	var tm_b = _make_tool_manager(pretilled_grid, ps_b)
	var predicted_invalid: bool = bool(tm_b._hoe_info(HOE, target).get("valid"))
	t.not_ok(predicted_invalid, "predicted hoe validity on an already-tilled tile is false")
	var real_use_result: bool = tm_b._use_hoe(HOE, target, offsets, energy_cost, null)
	t.eq(real_use_result, predicted_invalid,
		"the real _use_hoe() outcome on an already-tilled tile agrees with get_action_info's prediction (both false)")
	t.section_done("mirror drift guard")


## Regression test for a reported live crash: TargetIndicatorRenderer._process
## does `info.get("tiles", []) as Array[Vector2i]` - a bare `[x]` array
## literal is an UNTYPED Array at runtime even when every element is a
## Vector2i, and casting THAT to Array[Vector2i] errors ("Trying to assign
## an array of type 'Array' to a variable of type 'Array[Vector2i]'") rather
## than silently coercing. This bit specifically on the single-tile branches
## (NPC/well/feature/spade/seed/material/bare-hands) - the multi-tile hoe/
## watering-can branches were unaffected because they build `tiles` as an
## explicitly-typed local `Array[Vector2i]` from the start. Every affected
## branch was fixed to return `[x] as Array[Vector2i]`; this asserts the
## exact cast the renderer performs still succeeds for each one reachable
## from ToolManager off-tree (the player.gd branches - NPC/well/feature -
## were confirmed via a live scripted probe against the real running scene,
## not repeated here since they need a live GameData/BuildingManager tree).
func _test_single_tile_branches_return_typed_tiles_array(t: Object) -> void:
	var grid := _make_grid()
	var target := Vector2i(0, 0)
	grid.till_tile(target)
	var ps = PLAYER_STATE_SCRIPT.new()
	ps.add_item("turnip_seed", 1)
	ps.add_item("compost", 1)
	var tm = _make_tool_manager(grid, ps)

	var seed_info: Dictionary = tm._seed_item_info(SEED, target)
	var seed_tiles: Array[Vector2i] = seed_info.get("tiles", []) as Array[Vector2i]
	t.eq(seed_tiles.size(), 1, "seed branch's tiles array casts to Array[Vector2i] without error")

	var material_info: Dictionary = tm._material_item_info(COMPOST, target)
	var material_tiles: Array[Vector2i] = material_info.get("tiles", []) as Array[Vector2i]
	t.eq(material_tiles.size(), 1, "material branch's tiles array casts to Array[Vector2i] without error")

	var spade := {"id": "spade", "type": "tool", "tool_category": "spade", "energy_cost": 4}
	var spade_info: Dictionary = tm._tool_item_info(spade, Vector2i(2, 2))
	var spade_tiles: Array[Vector2i] = spade_info.get("tiles", []) as Array[Vector2i]
	t.eq(spade_tiles.size(), 1, "spade branch's tiles array casts to Array[Vector2i] without error")

	var unknown_info: Dictionary = tm.get_action_info(Vector2i(3, 3))
	var unknown_tiles: Array[Vector2i] = unknown_info.get("tiles", []) as Array[Vector2i]
	t.eq(unknown_tiles.size(), 1, "the bare-hands/nothing-to-do branch's tiles array also casts without error")
	t.section_done("single-tile branches return typed tiles arrays")
