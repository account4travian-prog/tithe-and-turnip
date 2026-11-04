# Sprint 9 - Buildings, storage & land tenure

**Size:** M-L. **Markers:** DESKTOP (one autoload registration, ~2 minutes
- same steps as Sprint 8's, substituting `BuildingManager` for
`SkillManager`; see [sprint_08_skills_foraging.md](sprint_08_skills_foraging.md)'s
DESKTOP section for the exact steps).
**ADR:** ADR-023 - Proposed, needs acceptance (no CLAUDE.md scope-list edit;
ADR-007 already covers "the whole property is eligible for field or
building," this ADR is the tenure ruling specifically).
**Prerequisite:** Sprint 6 complete (this sprint restricts tilling to owned
land, which must not retroactively break Sprint 6's `test_season_sim.gd` -
see the tenure section for why it doesn't).

## Correction to the roadmap's DESKTOP scope

`design/roadmap.md` describes this sprint's DESKTOP work as "autoload +
placement UI + a building render layer." On reflection, only the autoload
registration needs the editor - placement UI and the building render layer
are both runtime-built, exactly like Sprint 7's panels and
`FarmRenderer`'s `_draw()`-based rendering. Update the roadmap table when
this sprint starts.

## Objective

Buildings (storage, drying shed, extra well, fence, cottage upgrade) with
footprint placement and multi-day construction, plus land tenure: the
player starts owning a modest home plot and must rent additional strips
from the manor to till the rest of the map - the first real risk/reward
decision in the economy (more land, more coin potential, and a recurring
rent that raises the failure stakes).

## `data/buildings.json` (new)

```json
{
	"version": 1,
	"buildings": {
		"storage_chest": { "name": "Storage Chest", "footprint_w": 1, "footprint_h": 1, "cost_coin": 40, "cost_materials": { "flint": 5 }, "build_days": 1, "capacity": 50 },
		"drying_shed": { "name": "Drying Shed", "footprint_w": 2, "footprint_h": 2, "cost_coin": 90, "cost_materials": { "flint": 10 }, "build_days": 2 },
		"well_extra": { "name": "Extra Well", "footprint_w": 1, "footprint_h": 1, "cost_coin": 60, "cost_materials": { "flint": 8 }, "build_days": 1 },
		"fence": { "name": "Fence Section", "footprint_w": 1, "footprint_h": 1, "cost_coin": 5, "cost_materials": { "flint": 2 }, "build_days": 0, "deterrence_bonus": 1 },
		"cottage_upgrade": { "name": "Cottage Upgrade", "footprint_w": 3, "footprint_h": 3, "cost_coin": 200, "cost_materials": { "flint": 20 }, "build_days": 3, "sleep_bonus_fraction": 0.15 }
	}
}
```

**Honesty about what's functional this sprint:** `well_extra` and
`cottage_upgrade` have real, immediate effects (see integration points
below). `fence`'s `deterrence_bonus` is forward-declared infrastructure
that Sprint 12's raid deterrence will consume - it's inert until then,
same pattern as Sprint 6's `crop_spoiled` signal existing before anything
rendered it. `storage_chest`'s `capacity` is **also inert this sprint** -
`PlayerState` has no inventory cap at all right now, so there's nothing
for extra capacity to raise. Do not invent a cap just to give it meaning;
expose `BuildingManager.get_storage_capacity_bonus()` (sum of completed
chests' `capacity`) so a future sprint can wire it, and say so plainly if
asked whether storage does anything yet - it reserves the tile and nothing
else. `drying_shed` intentionally has **no effect field this sprint** -
its purpose (pausing inventory spoilage) needs Sprint 13's preservation
system to exist first; adding a no-op field now would be worse than
omitting it.

`GameData`: `BUILDING_INT_KEYS` casts `footprint_w`, `footprint_h`,
`cost_coin`, `build_days`, `deterrence_bonus`, `capacity`, and every value
inside `cost_materials`. `buildings: Dictionary` loaded via
`_load_id_file`-equivalent (buildings.json is keyed by id already, like
`enemies.json` - use the same `_load_enemies`-style loader, not
`_load_id_file` which expects a `list_key` array). Accessors:
`get_building(id) -> Dictionary`, `get_all_building_ids() -> Array[String]`.

## `data/tenure.json` (new)

```json
{
	"version": 1,
	"default_owned_rect": { "x": 0, "y": 0, "width": 10, "height": 10 },
	"rent_interval_days": 7,
	"strips": [
		{ "id": "strip_north", "name": "Northern Strip", "rent_per_interval": 5, "rect": { "x": 10, "y": 0, "width": 20, "height": 10 } },
		{ "id": "strip_southwest", "name": "Southwestern Strip", "rent_per_interval": 4, "rect": { "x": 0, "y": 10, "width": 15, "height": 10 } },
		{ "id": "strip_southeast", "name": "Southeastern Strip", "rent_per_interval": 5, "rect": { "x": 15, "y": 10, "width": 15, "height": 10 } }
	]
}
```

These four rectangles exactly partition the 30x20 map (100 + 200 + 150 +
150 = 600 tiles, no gaps, no overlaps) - verify this the same way Sprint
6's soil-rectangle checksum works, by summing areas before moving on.

**Coverage check against Sprint 6's `farm_map.json` v2 loamy rectangles**
(this is why this sprint doesn't retroactively break Sprint 6/8's tests):
loamy rect 1 (0-4, 0-3) is fully inside `default_owned_rect` - the tiles
`test_season_sim.gd` already plants on remain tillable with zero rent
paid. Loamy rect 2 (20-25, 11-15) is fully inside `strip_southeast`. Loamy
rect 4 (25-28, 1-3) is fully inside `strip_north`. Loamy rect 3 (7-10, 5-7)
**straddles** `default_owned_rect` and `strip_north` (columns 7-9 owned by
default, column 10 requires `strip_north`) - accepted as-is, a small
extra incentive to rent early, not a bug.

**Tenure gates tilling only - not movement, foraging, or feature
interaction.** The manor's wells, chapel, and market stall remain usable
on any tile regardless of who holds the tenure (they're the manor's
infrastructure, not the player's private tillage), and foraging - per
ADR-022, "gathering rights on the lord's waste" - stays free everywhere.
This is also what keeps Sprint 6's two `well` features (at (8,16) in
`strip_southwest` and (22,13) in `strip_southeast` - **neither inside the
default rect**) reachable and usable from day one, before any rent is
paid. Do not gate `FarmGrid.has_forage`/`gather_forage`, `Player`
movement, or `GameData.get_feature_at` interactions on ownership - only
`FarmGrid.till_tile` checks it.

`GameData`: `TENURE_INT_KEYS` casts `default_owned_rect`'s
`x`/`y`/`width`/`height`, `rent_interval_days`, and per-strip
`rent_per_interval` + its `rect`'s four fields. `tenure_cfg: Dictionary`
loaded via `_read_json("tenure.json")`. Accessor: `get_tenure_data() ->
Dictionary` returning `tenure_cfg`.

**API-confidence flag:** this guide uses `Rect2i.has_point(Vector2i) ->
bool` for the ownership containment check below. That method's exact name
is expected to be correct for 4.7 but is not independently re-verified
here per CLAUDE.md's API confidence rule (4.5-4.7 deltas aren't
verifiable from memory) - if it errors, the fallback is a manual bounds
check (`p.x >= rect.x and p.x < rect.x + rect.width and p.y >= rect.y and
p.y < rect.y + rect.height`), which is what to fall back to immediately
rather than debugging the built-in further.

## `BuildingManager` autoload (`scripts/autoloads/building_manager.gd`)

Owns both buildings and tenure - one autoload, not two, keeping this
sprint's DESKTOP burden at one registration.

```gdscript
extends Node

signal building_started(building_id: String, pos: Vector2i)
signal building_completed(building_id: String, pos: Vector2i)
signal strip_rented(strip_id: String)
signal strip_evicted(strip_id: String)
signal rent_charged(total: int)

var _placed: Array[Dictionary] = []   # {building_id, x, y, w, h, days_remaining, complete}
var _rented: Dictionary = {}          # strip_id -> bool

var _test_player: Node = null
var _test_game_data: Node = null
var _test_mode := false


func _ready() -> void:
	var tm := get_node_or_null("/root/TimeManager")
	if tm != null and not tm.day_passed.is_connected(_on_day_passed):
		tm.day_passed.connect(_on_day_passed)


func configure_for_test(player_state: Node, game_data: Node) -> void:
	_test_player = player_state
	_test_game_data = game_data
	_test_mode = true


func is_land_owned(pos: Vector2i) -> bool:
	var gd := _game_data()
	if gd == null:
		return true
	var tenure := gd.get_tenure_data()
	if _rect_from(tenure.get("default_owned_rect", {})).has_point(pos):
		return true
	for strip_id: Variant in _rented:
		if not bool(_rented[strip_id]):
			continue
		var strip := _find_strip(str(strip_id), tenure)
		if not strip.is_empty() and _rect_from(strip.get("rect", {})).has_point(pos):
			return true
	return false


func rent_strip(strip_id: String) -> bool:
	if bool(_rented.get(strip_id, false)):
		return false
	var gd := _game_data()
	if gd == null or _find_strip(strip_id, gd.get_tenure_data()).is_empty():
		return false
	_rented[strip_id] = true
	strip_rented.emit(strip_id)
	return true


func is_strip_rented(strip_id: String) -> bool:
	return bool(_rented.get(strip_id, false))


func can_place_building(building_id: String, pos: Vector2i) -> bool:
	var gd := _game_data()
	if gd == null:
		return false
	var def: Dictionary = gd.get_building(building_id)
	if def.is_empty():
		return false
	var w := int(def.get("footprint_w", 1))
	var h := int(def.get("footprint_h", 1))
	if not gd.is_within_farm(pos.x, pos.y) or not gd.is_within_farm(pos.x + w - 1, pos.y + h - 1):
		return false
	for entry: Variant in _placed:
		var b := entry as Dictionary
		if _footprints_overlap(pos, w, h, Vector2i(int(b.get("x", 0)), int(b.get("y", 0))),
				int(b.get("w", 1)), int(b.get("h", 1))):
			return false
	return true


func start_building(building_id: String, pos: Vector2i) -> bool:
	if not can_place_building(building_id, pos):
		return false
	var gd := _game_data()
	var def: Dictionary = gd.get_building(building_id)
	var cost_coin := int(def.get("cost_coin", 0))
	var materials: Dictionary = def.get("cost_materials", {})
	var player := _player()
	if player == null or int(player.money) < cost_coin:
		return false
	for mat_id: Variant in materials:
		if not player.has_item(str(mat_id), int(materials[mat_id])):
			return false
	player.spend_money(cost_coin)
	for mat_id: Variant in materials:
		player.remove_item(str(mat_id), int(materials[mat_id]))
	var build_days := int(def.get("build_days", 0))
	_placed.append({
		"building_id": building_id, "x": pos.x, "y": pos.y,
		"w": int(def.get("footprint_w", 1)), "h": int(def.get("footprint_h", 1)),
		"days_remaining": build_days, "complete": build_days <= 0,
	})
	building_started.emit(building_id, pos)
	if build_days <= 0:
		building_completed.emit(building_id, pos)
	return true


func get_completed_buildings() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Variant in _placed:
		var b := entry as Dictionary
		if bool(b.get("complete", false)):
			out.append(b)
	return out


func is_well_at(pos: Vector2i) -> bool:
	for b: Dictionary in get_completed_buildings():
		if str(b.get("building_id", "")) == "well_extra" \
				and Vector2i(int(b.get("x", 0)), int(b.get("y", 0))) == pos:
			return true
	return false


func get_sleep_bonus_fraction() -> float:
	var best := 0.0
	for b: Dictionary in get_completed_buildings():
		if str(b.get("building_id", "")) == "cottage_upgrade":
			var gd := _game_data()
			if gd != null:
				best = maxf(best, float(gd.get_building("cottage_upgrade").get("sleep_bonus_fraction", 0.0)))
	return best


func get_storage_capacity_bonus() -> int:
	var total := 0
	var gd := _game_data()
	if gd == null:
		return 0
	for b: Dictionary in get_completed_buildings():
		if str(b.get("building_id", "")) == "storage_chest":
			total += int(gd.get_building("storage_chest").get("capacity", 0))
	return total


func get_deterrence_bonus() -> int:
	var total := 0
	var gd := _game_data()
	if gd == null:
		return 0
	for b: Dictionary in get_completed_buildings():
		if str(b.get("building_id", "")) == "fence":
			total += int(gd.get_building("fence").get("deterrence_bonus", 0))
	return total


func to_dict() -> Dictionary:
	return {"placed": _placed.duplicate(true), "rented": _rented.duplicate()}


func from_dict(data: Dictionary) -> void:
	_placed = []
	for entry: Variant in data.get("placed", []):
		_placed.append((entry as Dictionary).duplicate())
	_rented = (data.get("rented", {}) as Dictionary).duplicate()


func _on_day_passed(day: int, _season: String, _year: int) -> void:
	_advance_construction()
	_charge_rent_if_due(day)


func _advance_construction() -> void:
	for entry: Variant in _placed:
		var b := entry as Dictionary
		if bool(b.get("complete", false)):
			continue
		b["days_remaining"] = int(b.get("days_remaining", 0)) - 1
		if int(b["days_remaining"]) <= 0:
			b["complete"] = true
			building_completed.emit(str(b.get("building_id", "")), Vector2i(int(b.get("x", 0)), int(b.get("y", 0))))


func _charge_rent_if_due(day: int) -> void:
	var gd := _game_data()
	if gd == null:
		return
	var tenure := gd.get_tenure_data()
	var interval := int(tenure.get("rent_interval_days", 7))
	if interval <= 0 or day % interval != 0:
		return
	var total := 0
	for strip_id: Variant in _rented:
		if not bool(_rented[strip_id]):
			continue
		var strip := _find_strip(str(strip_id), tenure)
		total += int(strip.get("rent_per_interval", 0))
	if total <= 0:
		return
	var player := _player()
	if player != null and player.spend_money(total):
		rent_charged.emit(total)
	else:
		_evict_cheapest_strip(tenure)


func _evict_cheapest_strip(tenure: Dictionary) -> void:
	var cheapest_id := ""
	var cheapest_rent := 999999
	for strip_id: Variant in _rented:
		if not bool(_rented[strip_id]):
			continue
		var strip := _find_strip(str(strip_id), tenure)
		var rent := int(strip.get("rent_per_interval", 0))
		if rent < cheapest_rent:
			cheapest_rent = rent
			cheapest_id = str(strip_id)
	if cheapest_id.is_empty():
		return
	_rented[cheapest_id] = false
	strip_evicted.emit(cheapest_id)
	if not _test_mode:
		var rep = get_node_or_null("/root/ReputationManager")
		if rep != null:
			rep.apply_action("fail_rent")


func _find_strip(strip_id: String, tenure: Dictionary) -> Dictionary:
	for entry: Variant in tenure.get("strips", []):
		var s := entry as Dictionary
		if str(s.get("id", "")) == strip_id:
			return s
	return {}


func _footprints_overlap(pos_a: Vector2i, w_a: int, h_a: int, pos_b: Vector2i, w_b: int, h_b: int) -> bool:
	return pos_a.x < pos_b.x + w_b and pos_a.x + w_a > pos_b.x \
		and pos_a.y < pos_b.y + h_b and pos_a.y + h_a > pos_b.y


func _rect_from(r: Dictionary) -> Rect2i:
	return Rect2i(int(r.get("x", 0)), int(r.get("y", 0)), int(r.get("width", 0)), int(r.get("height", 0)))


func _player() -> Node:
	if _test_player != null:
		return _test_player
	return get_node_or_null("/root/PlayerState")


func _game_data() -> Node:
	if _test_game_data != null:
		return _test_game_data
	return get_node_or_null("/root/GameData")
```

Add `fail_rent: { "manor": -3, "village": 0, "church": 0 }` to
`data/reputation.json`'s `actions`.

## Integration points

- **`FarmGrid.till_tile`** (`farm_grid.gd:48-62`) - add an ownership check
  right after the bounds check, before the "already tilled" check:

  ```gdscript
  if not force and not _is_owned(pos):
  	return false
  ```

  ```gdscript
  func _is_owned(pos: Vector2i) -> bool:
  	if _test_mode:
  		return _test_owned_rects.is_empty() or _rect_list_contains(_test_owned_rects, pos)
  	var bm := get_node_or_null("/root/BuildingManager")
  	if bm == null:
  		return true  # Sprint 6/7/8 saves and tests predate BuildingManager - don't retroactively block tilling
  	return bm.is_land_owned(pos)
  ```

  `_test_owned_rects: Array[Rect2i] = []` alongside the other `_test_*`
  vars, injected via a sixth optional `configure_for_test` parameter (add
  after Sprint 8's `forage_cfg` parameter, still defaulted, so every prior
  call site keeps compiling). Empty array means "unrestricted" for suites
  that don't care about tenure (every suite before this sprint).
- **`Player`** - the well-refill special-case (`player.gd:78-80`) currently
  only checks `GameData.get_feature_at(target.x, target.y) == "well"`.
  Widen it to also accept a player-built well:

  ```gdscript
  var bm = get_node_or_null("/root/BuildingManager")
  if feature == "well" or (bm != null and bm.is_well_at(target)):
  	_tool_manager.refill_watering_can()
  	return
  ```
- **`PlayerState.sleep_restore`** (added in Sprint 6) - add the cottage
  bonus on top of the base fraction:

  ```gdscript
  var fraction := float(game_data.player_cfg.get("sleep_energy_restore_fraction", 0.6))
  var bm = get_node_or_null("/root/BuildingManager")
  if bm != null:
  	fraction += bm.get_sleep_bonus_fraction()
  ```
- **Rendering** - a `BuildingRenderer` (`scripts/world/building_renderer.gd`,
  `class_name BuildingRenderer extends Node2D`) mirroring `FarmRenderer`
  exactly: `configure(building_manager, game_data)`, connects to
  `building_started`/`building_completed`, `queue_redraw()` on either,
  `_draw()` iterates `building_manager.get_completed_buildings()` plus
  in-progress entries (drawn dimmer/hatched to distinguish from complete),
  one flat color per `building_id` (geometric primitives only - no art).
  `main.gd` instantiates it the same way it instantiates `FarmRenderer`
  today (`main.gd:37-40`).
- **Placement UI** - a `BuildingPanel` (Sprint 7 pattern: runtime
  `CanvasLayer`, no `.tscn`), opened on a new `open_build_menu` action
  (`InputManager` registers `KEY_B`). Selecting a building enters a
  "placement mode" where a semi-transparent ghost rect follows
  `Player.get_faced_tile()` (Sprint 7 added that method) sized to the
  building's footprint, colored green/red by
  `BuildingManager.can_place_building(...)`; confirming with `interact`
  calls `BuildingManager.start_building(...)`. A second panel or a tab
  within the same panel lists tenure strips with rent and a "Rent" button
  calling `BuildingManager.rent_strip(strip_id)`.
- **Tile tooltip** (Sprint 7's `HudPanel`) - add "Not owned - rent from the
  manor" when `FarmGrid._is_owned` (or a new public `FarmGrid.is_owned(pos)`
  wrapper - add one, tooltips shouldn't call a private method) is false for
  the faced tile.

## Save schema

`SAVE_VERSION -> 8`. `BuildingManager` uses `to_dict()`/`from_dict()`
(structural placement data, matching `FarmGrid`'s convention rather than
`TitheManager`'s counter-based one):

```gdscript
# build_payload()
var buildings = get_node_or_null("/root/BuildingManager")
if buildings != null:
	payload["buildings"] = buildings.to_dict()

# apply_payload()
var buildings = get_node_or_null("/root/BuildingManager")
if buildings != null and payload.has("buildings"):
	buildings.from_dict(payload["buildings"] as Dictionary)
```

```gdscript
func migrate_to_v8(payload: Dictionary) -> Dictionary:
	payload["version"] = 8
	if not payload.has("buildings"):
		payload["buildings"] = {"placed": [], "rented": {}}
	return payload
```

Chain: `if version <= 7: parsed = migrate_to_v8(parsed)`.

## Tests

### New: `tests/suites/test_buildings.gd`

Construct `BUILDING_MANAGER_SCRIPT.new()`, a real `GameData`, and a
`PlayerState` seeded with enough money/materials. Assert:

1. `can_place_building("storage_chest", pos)` true on empty, in-bounds
   ground; false when `pos` would place any part of the footprint outside
   `GameData.is_within_farm`.
2. Placing two buildings with overlapping footprints - second
   `can_place_building` returns false.
3. `start_building` deducts both coin and every material in
   `cost_materials`, and fails (no deduction) if either is insufficient -
   check money/inventory unchanged on the failure path.
4. A building with `build_days > 0` is not in `get_completed_buildings()`
   immediately after `start_building`; after the right number of
   `_on_day_passed` calls (test-mode: call it directly, mirroring Sprint
   6/8's suites), it is.
5. A `build_days: 0` building (`fence`) is complete immediately.
6. `to_dict()`/`from_dict()` round-trip both in-progress and completed
   buildings exactly, including `days_remaining`.

Target: 10+ checks.

### New: `tests/suites/test_tenure.gd`

1. `is_land_owned` true everywhere inside `default_owned_rect`, false
   everywhere inside an unrented strip.
2. `rent_strip("strip_north")` then `is_land_owned` true for a point inside
   that strip's rect, still false for a point inside a *different*,
   unrented strip.
3. `rent_strip` on an unknown id returns false, no state change.
4. `rent_strip` on an already-rented strip returns false (no double-charge
   semantics to worry about since renting itself is free - only the
   recurring interval charge costs money, but idempotency still matters).
5. Rent charging: with one strip rented and `_on_day_passed(7, ...)`
   called on a `PlayerState` with enough money, money decreases by exactly
   that strip's `rent_per_interval`; `_on_day_passed(3, ...)` (not a
   multiple of the interval) charges nothing.
6. Eviction: rent two strips, set money below the combined rent, call
   `_on_day_passed(7, ...)` - the cheaper strip becomes unrented
   (`is_strip_rented` false), the more expensive one stays rented (this
   sprint charges the *total* up front and only evicts on failure, so
   assert the exact behavior as implemented - do not assume partial
   payment is attempted, it isn't).
7. `FarmGrid.till_tile` on an owned tile succeeds; on an unowned,
   unrented-strip tile fails, and succeeds after renting that strip -
   this is the integration test, not just a `BuildingManager` unit test;
   construct `FarmGrid` with `configure_for_test`'s new owned-rects
   parameter matching a real `BuildingManager`'s `is_land_owned` output
   for at least one representative tile in each region.

Target: 12+ checks.

### `tests/run_tests.gd`

Register `test_buildings.gd` and `test_tenure.gd`.

## Manual test checklist

1. Confirm the DESKTOP autoload registration - F5 runs with no
   `BuildingManager` errors in Output.
2. Try tilling a tile far from spawn (inside an unrented strip) - fails
   silently (or shows the Sprint 7 tooltip's "Not owned" message).
3. Open the build/tenure panel, rent that strip, confirm the tile is now
   tillable.
4. Place a fence - completes instantly, visible on the building render
   layer.
5. Place a storage chest or drying shed - shown as in-progress (dimmer/
   hatched); after the right number of sleeps, shown as complete.
6. Build a cottage upgrade, sleep, confirm energy restore is visibly
   higher than before the upgrade (compare against Sprint 6's base
   `sleep_energy_restore_fraction`).
7. Build an extra well away from the two manor wells, confirm interacting
   with it refills the watering can.
8. Let a rent interval pass (day 7/14/21/28) with insufficient money -
   confirm the cheaper rented strip is evicted and manor standing drops.
9. Save, reload - buildings (including in-progress ones) and rented strips
   persist exactly.
10. Resize the window - build panel and tile tooltip remain legible.

## Divergences to record

- `storage_chest` capacity and `fence` deterrence are inert this sprint
  (no inventory cap exists yet; Sprint 12 hasn't landed to consume
  deterrence) - both expose a getter for the future consumer rather than
  faking an effect now. `drying_shed` has no effect field at all until
  Sprint 13.
- Rent charging is all-or-nothing per interval (pay the full combined rent
  or the cheapest strip is evicted) - no partial-payment logic. Simpler
  and defensible; revisit only if playtesting shows it's too punishing.
- Land tenure gates `till_tile` only. Once a tile is tilled, it keeps
  functioning (growth, harvest) even if its strip's rent later lapses and
  the strip is evicted - eviction does not retroactively untill anything.
  Deliberate: punitive retroactive removal would need its own design pass
  and isn't in ADR-023's scope.

## Status & remaining work (2026-08-05)

Implemented by an agent (all code + tests landed; see DEVELOPMENT_STATE.md
"Sprint 9 implemented" for the full record): `BuildingManager` autoload
script, `data/buildings.json` + `data/tenure.json` + `fail_rent` rep action,
GameData accessors, the `FarmGrid.till_tile` tenure gate + `is_owned`,
player well / sleep-bonus / save-v8 integration, `BuildingRenderer` +
`BuildingPanel` (B key), the HUD "NOT OWNED" tooltip, and the
`test_buildings` / `test_tenure` suites. Headless verification: import clean,
full runner 404/404 checks pass, boot smoke exit 0.

Remaining to finish this sprint - no design decisions, pure pickups:

1. **DESKTOP (human, ~2 min):** register `BuildingManager` in Project
   Settings -> Autoload. Node Name `BuildingManager`, path
   `res://scripts/autoloads/building_manager.gd`, listed **after**
   `TimeManager` (its `_ready` connects `TimeManager.day_passed`, so boot
   order matters). Until registered, live tilling is unrestricted and the
   build panel shows a "not registered" hint - graceful, but the tenure
   decision only exists once it lands.
2. **DESKTOP (human, ~2 min):** Sprint 8's `SkillManager` is **still not
   registered** in project.godot as of this sprint (same Autoload tab, path
   `res://scripts/autoloads/skill_manager.gd`). Without it, F5 play has no
   skills/XP.
3. **Editor verification (human, after the registrations):** walk the manual
   test checklist above (items 1-10). None of it has been exercised in a
   live editor session - the headless suites cover the model layer only.
4. **No action now, but know why:** `storage_chest` capacity and `fence`
   deterrence are forward-declared getters (inert until an inventory cap or
   Sprint 12's raid deterrence consumes them); `drying_shed` has no effect
   field until Sprint 13's preservation system. Do not invent effects to
   make them "do something" this sprint.
