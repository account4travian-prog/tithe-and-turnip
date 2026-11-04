# Sprint 13 - Crafting, cooking & preservation

**Size:** M-L. **Markers:** DESKTOP (one autoload registration, ~2 minutes
- same steps as Sprint 8's, substituting `CraftingManager`), AMENDMENT.
**ADR:** ADR-027 - Proposed ("full crafting, cooking recipes" is on
CLAUDE.md's out-of-scope list; confirm Accepted + the list amended before
starting).
**Prerequisite:** Sprint 8 (recipes are skill-gated), Sprint 9 (recipes are
station-gated by completed buildings).

## Correction to the roadmap's DESKTOP scope

Same correction as Sprints 7/9/12: the crafting UI is a runtime-built
Sprint-7-pattern panel, not a `.tscn`. Only the `CraftingManager` autoload
registration needs the editor.

## Objective

Recipes that turn raw crops (and Sprint 8's forage items) into higher-
value food, gated by farming skill level and by having the right building
completed. This is the sprint that actually delivers the vision
document's "survive" pillar - cooked/preserved food restores meaningfully
more energy than anything raw, and it converts the economy from
raw-crop-only into a small production chain.

**Simplification stated up front:** crafting recipes only consume and
produce `"common"`-quality stacks. There is no quality-propagation logic
anywhere else in this codebase (every other system that touches quality -
harvest, sell, tithe deposit - operates on one caller-specified quality at
a time, never blends several), and inventing one here for crafting alone
would be new complexity nothing else needs. If a player wants to craft
from `fine`/`choice` stock, they'd need it to already be `common` - not
supported this sprint. Note this plainly rather than quietly restricting
UI options with no explanation.

## `data/recipes.json` (new)

```json
{
	"version": 1,
	"recipes": [
		{ "id": "dried_turnip", "station": "drying_shed", "inputs": { "turnip": 3 }, "output_item_id": "dried_turnip", "output_count": 1, "energy_cost": 3, "craft_days": 0, "skill_id": "farming", "skill_level_required": 1 },
		{ "id": "dried_barley", "station": "drying_shed", "inputs": { "barley": 3 }, "output_item_id": "dried_barley", "output_count": 1, "energy_cost": 3, "craft_days": 0, "skill_id": "farming", "skill_level_required": 1 },
		{ "id": "barley_ale", "station": "hearth", "inputs": { "barley": 4 }, "output_item_id": "barley_ale", "output_count": 1, "energy_cost": 4, "craft_days": 1, "skill_id": "farming", "skill_level_required": 2 },
		{ "id": "herb_stew", "station": "hearth", "inputs": { "wild_herb": 2, "turnip": 1 }, "output_item_id": "herb_stew", "output_count": 1, "energy_cost": 3, "craft_days": 0, "skill_id": "", "skill_level_required": 0 },
		{ "id": "berry_pie", "station": "hearth", "inputs": { "wild_berry": 3, "barley": 1 }, "output_item_id": "berry_pie", "output_count": 1, "energy_cost": 4, "craft_days": 0, "skill_id": "", "skill_level_required": 0 }
	]
}
```

`skill_id: ""` means the recipe has no skill gate (the two cooked meals,
`herb_stew`/`berry_pie`, are available from day one - only the
*preservation* recipes and the ale need Farming level 1-2, matching the
"cooking is basic, preservation is a skill" framing). `craft_days: 1` on
`barley_ale` means it's the one recipe that isn't instant - it ferments
overnight.

`GameData`: `RECIPE_INT_KEYS` casts `output_count`, `energy_cost`,
`craft_days`, `skill_level_required`, and every value inside `inputs`
(nested, add to `_cast_nested_ints`). `recipes: Dictionary` loaded via
the same `_load_enemies`-style id-keyed loader Sprint 9 used for
`buildings.json` (recipes.json is keyed by `id` under a `recipes` object -
match whichever shape you actually write; the schema above keys by array
with an `id` field per entry, so use `_load_id_file("recipes.json",
"recipes", RECIPE_INT_KEYS)` instead, consistent with `crops.json`/
`items.json`'s shape - **use `_load_id_file`, not the enemies-style
loader**, since this file's top-level `recipes` key holds an array, not an
already-id-keyed object). `get_recipe(id) -> Dictionary`,
`get_all_recipe_ids() -> Array[String]`.

## New items (`data/items.json` v3 -> v4)

```json
{ "id": "dried_turnip", "type": "food", "name": "Dried Turnip", "price": 6, "stackable": true, "energy_base": 12 },
{ "id": "dried_barley", "type": "food", "name": "Dried Barley", "price": 8, "stackable": true, "energy_base": 14 },
{ "id": "barley_ale", "type": "food", "name": "Barley Ale", "price": 14, "stackable": true, "energy_base": 20 },
{ "id": "herb_stew", "type": "food", "name": "Herb Stew", "price": 5, "stackable": true, "energy_base": 18 },
{ "id": "berry_pie", "type": "food", "name": "Berry Pie", "price": 10, "stackable": true, "energy_base": 22 }
```

Compare to raw: turnip `energy_base: 5`, barley `7` (from `items.json`
today). Every crafted food roughly doubles-to-quadruples the energy of its
raw input - this is the actual mechanism that makes cooking matter, not
just a content addition. Add all five to `market.json`'s `buy_prices` so
`TitheManager` can sell them: `"dried_turnip": 9, "dried_barley": 12,
"barley_ale": 18, "herb_stew": 7, "berry_pie": 13` (a real markup over
the raw ingredients' combined assize value, rewarding the conversion).

## New building (`data/buildings.json` v1 -> v2)

`drying_shed` already exists (Sprint 9, inert until now - it's a
`station` value in `recipes.json` above, so it's now functional with zero
changes to its own definition). Add a second station:

```json
"hearth": { "name": "Hearth", "footprint_w": 1, "footprint_h": 1, "cost_coin": 50, "cost_materials": { "flint": 6 }, "build_days": 1 }
```

## `BuildingManager` addition

One small getter for the interaction layer below:

```gdscript
func get_building_id_at(pos: Vector2i) -> String:
	for b: Dictionary in get_completed_buildings():
		var w := int(b.get("w", 1))
		var h := int(b.get("h", 1))
		var bx := int(b.get("x", 0))
		var by := int(b.get("y", 0))
		if pos.x >= bx and pos.x < bx + w and pos.y >= by and pos.y < by + h:
			return str(b.get("building_id", ""))
	return ""
```

## `CraftingManager` autoload (`scripts/autoloads/crafting_manager.gd`)

```gdscript
extends Node

signal crafting_started(recipe_id: String)
signal item_crafted(recipe_id: String, output_item_id: String, count: int)

var _pending: Array[Dictionary] = []  # {recipe_id, days_remaining}

var _test_player: Node = null
var _test_game_data: Node = null
var _test_skill: Node = null
var _test_building: Node = null
var _test_mode := false


func _ready() -> void:
	var tm := get_node_or_null("/root/TimeManager")
	if tm != null and not tm.day_passed.is_connected(_on_day_passed):
		tm.day_passed.connect(_on_day_passed)


func configure_for_test(player_state: Node, game_data: Node, skill_manager: Node = null, building_manager: Node = null) -> void:
	_test_player = player_state
	_test_game_data = game_data
	_test_skill = skill_manager
	_test_building = building_manager
	_test_mode = true


func can_craft(recipe_id: String) -> bool:
	var gd := _game_data()
	if gd == null:
		return false
	var recipe: Dictionary = gd.get_recipe(recipe_id)
	if recipe.is_empty():
		return false
	if not _station_available(str(recipe.get("station", ""))):
		return false
	var skill_id := str(recipe.get("skill_id", ""))
	if not skill_id.is_empty():
		var skill := _skill_manager()
		if skill != null and skill.get_level(skill_id) < int(recipe.get("skill_level_required", 0)):
			return false
	var player := _player()
	if player == null:
		return false
	var inputs: Dictionary = recipe.get("inputs", {})
	for item_id: Variant in inputs:
		if not player.has_item(str(item_id), int(inputs[item_id]), "common"):
			return false
	return player.energy >= float(recipe.get("energy_cost", 0))


func craft(recipe_id: String) -> bool:
	if not can_craft(recipe_id):
		return false
	var gd := _game_data()
	var recipe: Dictionary = gd.get_recipe(recipe_id)
	var player := _player()
	if not player.consume_energy(float(recipe.get("energy_cost", 0))):
		return false
	var inputs: Dictionary = recipe.get("inputs", {})
	for item_id: Variant in inputs:
		player.remove_item(str(item_id), int(inputs[item_id]), "common")
	var craft_days := int(recipe.get("craft_days", 0))
	if craft_days <= 0:
		_finish_craft(recipe)
	else:
		_pending.append({"recipe_id": recipe_id, "days_remaining": craft_days})
		crafting_started.emit(recipe_id)
	return true


func get_pending() -> Array[Dictionary]:
	return _pending.duplicate(true)


func to_dict() -> Dictionary:
	return {"pending": _pending.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	_pending = []
	for entry: Variant in data.get("pending", []):
		_pending.append((entry as Dictionary).duplicate())


func _finish_craft(recipe: Dictionary) -> void:
	var player := _player()
	var count := int(recipe.get("output_count", 1))
	player.add_item(str(recipe.get("output_item_id", "")), count)
	item_crafted.emit(str(recipe.get("id", "")), str(recipe.get("output_item_id", "")), count)


func _on_day_passed(_day: int, _season: String, _year: int) -> void:
	var still: Array[Dictionary] = []
	for entry: Variant in _pending:
		var p := entry as Dictionary
		p["days_remaining"] = int(p.get("days_remaining", 0)) - 1
		if int(p["days_remaining"]) <= 0:
			var gd := _game_data()
			if gd != null:
				_finish_craft(gd.get_recipe(str(p.get("recipe_id", ""))))
		else:
			still.append(p)
	_pending = still


func _station_available(station_id: String) -> bool:
	if station_id.is_empty():
		return true
	var bm := _building_manager()
	if bm == null:
		return true  # BuildingManager not present (older save / Sprint 9 not applied) - don't hard-block
	for b: Dictionary in bm.get_completed_buildings():
		if str(b.get("building_id", "")) == station_id:
			return true
	return false


func _player() -> Node:
	if _test_player != null:
		return _test_player
	return get_node_or_null("/root/PlayerState")


func _game_data() -> Node:
	if _test_game_data != null:
		return _test_game_data
	return get_node_or_null("/root/GameData")


func _skill_manager() -> Node:
	if _test_skill != null:
		return _test_skill
	return get_node_or_null("/root/SkillManager")


func _building_manager() -> Node:
	if _test_building != null:
		return _test_building
	return get_node_or_null("/root/BuildingManager")
```

`_station_available` checks **existence anywhere on the map**, not
proximity - proximity is handled one layer up, at the interaction/UI
level, described next. Keeping it that way means `CraftingManager` never
needs a live `Player` reference (which, per [README.md](README.md)'s
"FarmGrid and ToolManager are not autoloads" section, it couldn't safely
reach via `/root/` anyway).

## Interaction and UI

`Player`'s interact dispatch (`player.gd:74-89`) gains a station check
alongside the existing well/feature checks:

```gdscript
	var bm = get_node_or_null("/root/BuildingManager")
	var station_id := bm.get_building_id_at(target) if bm != null else ""
	if station_id == "drying_shed" or station_id == "hearth":
		station_interacted.emit(station_id, target)
		return
```

New signal `signal station_interacted(station_id: String, pos: Vector2i)`
alongside `interacted_with`/`npc_interacted` (`player.gd:10-11`).
`main.gd` connects it and opens a `CraftingPanel` (Sprint 7 pattern -
runtime `CanvasLayer`, no `.tscn`) filtered to `GameData.get_all_recipe_
ids()` entries whose `station` matches `station_id` - this is the
proximity gate: the panel only ever shows recipes for the station tile the
player is actually standing next to, even though `CraftingManager.
can_craft` itself doesn't check position. Each row shows the recipe's
inputs/output, greyed out when `can_craft` is false, with a tooltip-style
reason (missing skill level / missing ingredients / no energy - check in
that order and show the first failing reason) and a "Craft" button calling
`CraftingManager.craft(recipe_id)`.

## Save schema

`SAVE_VERSION -> 12`.

```gdscript
# build_payload()
var crafting = get_node_or_null("/root/CraftingManager")
if crafting != null:
	payload["crafting"] = crafting.to_dict()

# apply_payload()
var crafting = get_node_or_null("/root/CraftingManager")
if crafting != null and payload.has("crafting"):
	crafting.from_dict(payload["crafting"] as Dictionary)
```

```gdscript
func migrate_to_v12(payload: Dictionary) -> Dictionary:
	payload["version"] = 12
	if not payload.has("crafting"):
		payload["crafting"] = {"pending": []}
	return payload
```

Chain: `if version <= 11: parsed = migrate_to_v12(parsed)`.

## Tests

### New: `tests/suites/test_crafting.gd`

Construct `CRAFTING_MANAGER_SCRIPT.new()`, a real `GameData`, a
`PlayerState` seeded with ingredients, and mocked `SkillManager`/
`BuildingManager` stand-ins (simple `RefCounted` or script doubles
exposing just `get_level(id)`/`get_completed_buildings()` - or, simpler
and consistent with every other suite in this codebase, construct the
*real* `SkillManager`/`BuildingManager` scripts via `.new()` and
`configure_for_test` them the same way the suite already configures
`GameData`). Assert:

1. `can_craft` false with no station built; true once a `BuildingManager`
   mock reports the right `building_id` in `get_completed_buildings()`.
2. `can_craft` false below the recipe's `skill_level_required`; true at or
   above it.
3. `can_craft` false with insufficient ingredients or insufficient energy,
   independently (two separate cases, not conflated).
4. `craft` on a `craft_days: 0` recipe (e.g. `dried_turnip`) immediately
   deducts inputs/energy and adds the output - `get_pending()` stays
   empty throughout.
5. `craft` on `barley_ale` (`craft_days: 1`) deducts inputs/energy
   immediately but does **not** add the output until one `_on_day_passed`
   call later; confirm `get_pending()` shows exactly one entry with
   `days_remaining: 1` right after `craft`, and zero entries with the
   output present after the day passes.
6. `to_dict()`/`from_dict()` round-trip a pending (not-yet-finished)
   craft exactly.

Target: 12+ checks.

### New: `tests/suites/test_cooking.gd`

A narrower suite focused specifically on the "cooking delivers the
survive pillar" claim, using `PlayerState.eat()` (unchanged since Sprint
1, `player_state.gd:150-166`) rather than `CraftingManager` directly:

1. `PlayerState.eat("turnip")` (raw) restores exactly `items.json`'s raw
   `energy_base` (`5.0`, times the quality multiplier - use `"common"`,
   multiplier `1.0`).
2. `PlayerState.eat("herb_stew")` restores its `energy_base` (`18.0`) -
   confirms crafted food doesn't need any special-case in `eat()`, it's
   just another `type: "food"` item, which is why no `PlayerState` change
   was needed for this sprint at all.
3. A direct numeric comparison: the best crafted food's energy-per-item
   is at least double the best raw crop's - a regression guard so a
   future data edit can't quietly erase cooking's actual value proposition
   by nerfing the crafted items back toward raw-crop parity.

Target: 5+ checks - this suite is intentionally small; its job is to
protect one specific balance claim, not to re-test `eat()`'s mechanics
(already covered by Sprint 1's suites).

### `tests/run_tests.gd`

Register `test_crafting.gd` and `test_cooking.gd`.

## Manual test checklist

1. Confirm the DESKTOP autoload registration - F5, no `CraftingManager`
   errors in Output.
2. Build a drying shed and a hearth (Sprint 9's build panel).
3. Stand next to the hearth, open the crafting panel - confirm only
   hearth recipes are listed, not drying-shed ones.
4. Craft `herb_stew` (no skill gate) with sufficient wild herb/turnip -
   confirm inventory and energy update, item appears.
5. Try crafting `dried_turnip` before reaching Farming level 1 - confirm
   it's shown but disabled with a clear reason; reach the level (Sprint 8)
   and confirm it becomes craftable.
6. Craft `barley_ale` - confirm it does *not* appear immediately, appears
   the next day (sleep or let the day roll over).
7. Eat a crafted food item and compare the energy restored on the HUD
   against eating a raw crop of similar cost - confirm the crafted item
   is meaningfully better.
8. Sell a crafted item at the market - confirm it nets more coin than
   selling its raw ingredients would have.
9. Save mid-fermentation (after starting `barley_ale`, before the day
   passes), reload, let the day pass - confirm the ale still completes.
10. Resize the window - crafting panel remains legible.

## Divergences to record

- Crafting only operates on `"common"`-quality stacks - no quality
  propagation into crafted output. See the objective section for why.
- `CraftingManager._station_available` checks existence anywhere on the
  map, not proximity - proximity is enforced one layer up, by which
  station tile the player is actually standing next to when the panel
  opens. `CraftingManager` never needs a live `Player` reference this way.
