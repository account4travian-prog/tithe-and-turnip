# Sprint 8 - Skills, foraging & the commons

**Size:** M. **Markers:** DESKTOP (one autoload registration, ~2 minutes),
AMENDMENT.
**ADRs:** ADR-021 (life skills), ADR-022 (foraging) - both Proposed, both
need acceptance before work opens; neither needs a CLAUDE.md scope-list
edit beyond noting the new system (life skills and foraging aren't on the
out-of-scope list at all - accepting the ADR is the whole gate here, there
is no larger amendment to negotiate the way Sprint 11/12/13/14 will need).
**Prerequisite:** Sprints 6 and 7 complete (this sprint reads `FarmGrid`
through the same injection convention Sprint 6 established, and its skill-
level display belongs in Sprint 7's `HudPanel`).

See [README.md](README.md) for shared conventions, in particular the
"FarmGrid and ToolManager are not autoloads" section - this sprint adds
calls into `FarmGrid` from `ToolManager` (already legal, they're both
non-autoload scene objects reached through the existing
`Player.set_farm_grid` wiring) and calls into the new `SkillManager`
*autoload* from both (legal in the other direction - `SkillManager` is a
real `/root/`-reachable singleton once registered).

## DESKTOP steps (do this first - everything else depends on it)

1. Open the project in the Godot editor.
2. Project -> Project Settings -> Autoload tab.
3. Path: `res://scripts/autoloads/skill_manager.gd` (create the script file
   first via the spec below, or point at it once the agent has written it -
   either order works, but the autoload entry must exist before the game
   can run with `SkillManager` referenced anywhere).
4. Node Name: `SkillManager` (must match exactly - every `get_node_or_null
   ("/root/SkillManager")` call in this guide depends on that exact name).
5. Save. Confirm it appears in the autoload list above the existing seven
   (order relative to the others doesn't matter - `SkillManager` has no
   `_ready()` dependency on any other autoload's boot order).
6. Run `--headless --path . --import` once to confirm the new script
   compiles and the project still imports clean.

This is the only editor-dependent step in this sprint. Every other change
below is a plain script edit.

## Objective

Add a life-skills layer (farming / foraging / combat / labor) that
modifies existing systems' costs and yields by level, and a foraging
system that gives the 88% of the map that isn't loamy (per Sprint 6's
`farm_map.json` v2) a reason to be visited.

## `data/skills.json` (new)

```json
{
	"version": 1,
	"skills": {
		"farming": {
			"xp_thresholds": [0, 80, 200, 400, 700, 1100],
			"xp_sources": { "till_tile": 1, "water_tile": 1, "harvest_common": 3, "harvest_fine": 5, "harvest_choice": 8 },
			"level_effects": [
				{ "tool_energy_cost_mult": 1.0, "quality_choice_bonus": 0 },
				{ "tool_energy_cost_mult": 0.95, "quality_choice_bonus": 1 },
				{ "tool_energy_cost_mult": 0.9, "quality_choice_bonus": 2 },
				{ "tool_energy_cost_mult": 0.85, "quality_choice_bonus": 3 },
				{ "tool_energy_cost_mult": 0.8, "quality_choice_bonus": 4 },
				{ "tool_energy_cost_mult": 0.75, "quality_choice_bonus": 6 }
			]
		},
		"foraging": {
			"xp_thresholds": [0, 60, 150, 300, 550, 900],
			"xp_sources": { "gather": 4 },
			"level_effects": [
				{ "gather_energy_cost_mult": 1.0, "yield_bonus": 0 },
				{ "gather_energy_cost_mult": 0.9, "yield_bonus": 0 },
				{ "gather_energy_cost_mult": 0.85, "yield_bonus": 1 },
				{ "gather_energy_cost_mult": 0.75, "yield_bonus": 1 },
				{ "gather_energy_cost_mult": 0.65, "yield_bonus": 2 },
				{ "gather_energy_cost_mult": 0.55, "yield_bonus": 2 }
			]
		},
		"combat": {
			"xp_thresholds": [0, 100, 250, 450, 700, 1050],
			"xp_sources": { "hit_enemy": 2, "defeat_enemy": 10 },
			"level_effects": [
				{ "damage_mult": 1.0, "energy_cost_mult": 1.0 },
				{ "damage_mult": 1.05, "energy_cost_mult": 0.95 },
				{ "damage_mult": 1.1, "energy_cost_mult": 0.9 },
				{ "damage_mult": 1.15, "energy_cost_mult": 0.85 },
				{ "damage_mult": 1.2, "energy_cost_mult": 0.8 },
				{ "damage_mult": 1.3, "energy_cost_mult": 0.7 }
			]
		},
		"labor": {
			"xp_thresholds": [0, 70, 180, 350, 600, 950],
			"xp_sources": { "chore_complete": 5 },
			"level_effects": [
				{ "credit_bonus": 0, "daily_cap_bonus": 0 },
				{ "credit_bonus": 0, "daily_cap_bonus": 2 },
				{ "credit_bonus": 1, "daily_cap_bonus": 2 },
				{ "credit_bonus": 1, "daily_cap_bonus": 4 },
				{ "credit_bonus": 2, "daily_cap_bonus": 4 },
				{ "credit_bonus": 2, "daily_cap_bonus": 6 }
			]
		}
	}
}
```

`level_effects[i]` is the **absolute** effect at level `i` (index 0 =
unskilled baseline), not an increment - a lookup, never a running sum.
`xp_thresholds[i]` is the cumulative XP required to **reach** level `i`
(so `xp_thresholds[0]` is always `0`). Max level is `xp_thresholds.size() -
1` (5, here).

`GameData` additions: `SKILL_INT_KEYS` cast for `xp_thresholds` (every
entry) and, per skill, the integer-typed `level_effects` fields
(`quality_choice_bonus`, `yield_bonus`, `credit_bonus`, `daily_cap_bonus`) -
the `*_mult` and `damage_mult` fields stay float. Add:

```gdscript
var skills: Dictionary = {}
# in load_all():
skills = _read_json("skills.json").get("skills", {})
# in _cast_nested_ints():
for skill_id: Variant in skills:
	var skill := skills[skill_id] as Dictionary
	var thresholds: Array = skill.get("xp_thresholds", [])
	for i in range(thresholds.size()):
		thresholds[i] = int(thresholds[i])
	var effects: Array = skill.get("level_effects", [])
	for level: Variant in effects:
		var e := level as Dictionary
		for key: String in ["quality_choice_bonus", "yield_bonus", "credit_bonus", "daily_cap_bonus"]:
			if e.has(key):
				e[key] = int(e[key])


func get_skill(skill_id: String) -> Dictionary:
	return skills.get(skill_id, {})


func get_skill_xp_thresholds(skill_id: String) -> Array:
	return get_skill(skill_id).get("xp_thresholds", [0])


func get_skill_xp_source(skill_id: String, source_id: String) -> float:
	return float(get_skill(skill_id).get("xp_sources", {}).get(source_id, 0))


func get_skill_level_effects(skill_id: String, level: int) -> Dictionary:
	var effects: Array = get_skill(skill_id).get("level_effects", [])
	if level < 0 or level >= effects.size():
		return {}
	return effects[level]
```

## `SkillManager` autoload (`scripts/autoloads/skill_manager.gd`)

```gdscript
extends Node

signal xp_gained(skill_id: String, amount: float, total: float)
signal leveled_up(skill_id: String, new_level: int)

const SKILL_IDS: Array[String] = ["farming", "foraging", "combat", "labor"]

var _xp: Dictionary = {"farming": 0.0, "foraging": 0.0, "combat": 0.0, "labor": 0.0}
var _test_game_data: Node = null


func configure_for_test(game_data: Node) -> void:
	_test_game_data = game_data


func add_xp(skill_id: String, amount: float) -> void:
	if amount <= 0.0 or not _xp.has(skill_id):
		return
	var before := get_level(skill_id)
	_xp[skill_id] = float(_xp.get(skill_id, 0.0)) + amount
	xp_gained.emit(skill_id, amount, _xp[skill_id])
	var after := get_level(skill_id)
	if after > before:
		leveled_up.emit(skill_id, after)


func add_xp_for(skill_id: String, source_id: String) -> void:
	var gd := _game_data()
	if gd == null:
		return
	add_xp(skill_id, gd.get_skill_xp_source(skill_id, source_id))


func get_xp(skill_id: String) -> float:
	return float(_xp.get(skill_id, 0.0))


func get_level(skill_id: String) -> int:
	var gd := _game_data()
	if gd == null:
		return 0
	var thresholds := gd.get_skill_xp_thresholds(skill_id)
	var xp := get_xp(skill_id)
	var level := 0
	for i in range(thresholds.size()):
		if xp >= float(thresholds[i]):
			level = i
	return level


func get_xp_to_next(skill_id: String) -> float:
	var gd := _game_data()
	if gd == null:
		return -1.0
	var thresholds := gd.get_skill_xp_thresholds(skill_id)
	var level := get_level(skill_id)
	if level + 1 >= thresholds.size():
		return -1.0
	return float(thresholds[level + 1]) - get_xp(skill_id)


func get_effect(skill_id: String, key: String, default: Variant = 0) -> Variant:
	var gd := _game_data()
	if gd == null:
		return default
	return gd.get_skill_level_effects(skill_id, get_level(skill_id)).get(key, default)


func to_dict() -> Dictionary:
	return {"xp": _xp.duplicate()}


func from_dict(data: Dictionary) -> void:
	var xp: Dictionary = data.get("xp", {})
	for skill_id: String in _xp.keys():
		_xp[skill_id] = float(xp.get(skill_id, 0.0))


func _game_data() -> Node:
	if _test_game_data != null:
		return _test_game_data
	return get_node_or_null("/root/GameData")
```

`get_xp_to_next` returns `-1.0` at max level (not `0.0`, not `INF`) -
callers (the HUD skill display) must check for `-1.0` and show "MAX"
rather than a countdown.

## Foraging - lives on `FarmGrid`, not a second manager

Foraging state is per-tile and `FarmGrid` already owns every tile - adding
a second manager to track "what's growing wild where" would duplicate the
grid `FarmGrid` already has. This also keeps this sprint's DESKTOP burden
at exactly one autoload (`SkillManager`) rather than two.

### `data/forage.json` (new)

```json
{
	"version": 1,
	"gather_energy_cost": 2,
	"spawn_chance_per_tile_per_day": 0.03,
	"max_concurrent_spawns": 40,
	"spawns": {
		"rocky": [
			{ "item_id": "wild_herb", "weight": 60, "yield_min": 1, "yield_max": 2 },
			{ "item_id": "flint", "weight": 40, "yield_min": 1, "yield_max": 1 }
		],
		"sandy": [
			{ "item_id": "wild_onion", "weight": 70, "yield_min": 1, "yield_max": 2 },
			{ "item_id": "wild_herb", "weight": 30, "yield_min": 1, "yield_max": 1 }
		],
		"loamy": [
			{ "item_id": "wild_berry", "weight": 50, "yield_min": 1, "yield_max": 3 },
			{ "item_id": "wild_herb", "weight": 50, "yield_min": 1, "yield_max": 1 }
		]
	}
}
```

`GameData` additions: `forage_cfg: Dictionary = _read_json("forage.json")`
in `load_all()`; `FORAGE_INT_KEYS` cast for `gather_energy_cost`,
`max_concurrent_spawns`, and every `weight`/`yield_min`/`yield_max` inside
`spawns.*[]`; `get_forage_config() -> Dictionary` returning `forage_cfg`.

### New items (`data/items.json` v2 -> v3)

```json
{ "id": "wild_herb", "type": "food", "name": "Wild Herb", "price": 0, "stackable": true, "energy_base": 3 },
{ "id": "wild_onion", "type": "food", "name": "Wild Onion", "price": 0, "stackable": true, "energy_base": 4 },
{ "id": "wild_berry", "type": "food", "name": "Wild Berry", "price": 0, "stackable": true, "energy_base": 4 },
{ "id": "flint", "type": "material", "name": "Flint", "price": 0, "stackable": true }
```

`flint` has no `energy_base` and `type: "material"` - `PlayerState.eat()`
already rejects non-`"food"` items (`player_state.gd:155`), so no guard
change is needed; `flint` exists now so Sprint 9's building costs have a
gatherable material to spend, not to be used this sprint.

### `FarmGrid` additions

Cell shape gains three fields, defaulted in `_default_cell()`
(`farm_grid.gd:289-296`): `"forage_item_id": ""`, `"forage_yield": 0`.
(No age/decay field needed - despawn isn't modeled; a forage node persists
until gathered, which is simpler and fine at this scale.)

New signal `signal forage_gathered(pos: Vector2i, item_id: String, count: int)`.

```gdscript
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
```

`advance_day()` gains a forage-spawn pass, folded into the existing
per-cell loop (`farm_grid.gd:130-166`) rather than a second scan - only for
**untilled** cells, since ADR-022 specifies wild growth on untilled tiles:

```gdscript
func advance_day(rain: bool, overcast: bool = false) -> void:
	var active_forage := _count_active_forage()
	var cfg := _forage_config()
	var chance := float(cfg.get("spawn_chance_per_tile_per_day", 0.0))
	var cap := int(cfg.get("max_concurrent_spawns", 0))
	var changed: Array[Vector2i] = []
	for y in range(_grid_height):
		for x in range(_grid_width):
			var cell: Dictionary = _cells[y][x]
			if str(cell.get("soil", "")).is_empty():
				continue
			# ... existing tilled/crop/moisture logic unchanged ...
			if not bool(cell.get("tilled", false)) and str(cell.get("forage_item_id", "")).is_empty():
				if chance > 0.0 and active_forage < cap and randf() < chance:
					var picked := _pick_forage_item(str(cell.get("soil", "")), cfg)
					if not picked.is_empty():
						cell["forage_item_id"] = str(picked.get("item_id", ""))
						cell["forage_yield"] = randi_range(
							int(picked.get("yield_min", 1)), int(picked.get("yield_max", 1)))
						active_forage += 1
			changed.append(Vector2i(x, y))
	for p: Vector2i in changed:
		tile_changed.emit(p)


func _count_active_forage() -> int:
	var count := 0
	for y in range(_grid_height):
		for x in range(_grid_width):
			if not str(_cells[y][x].get("forage_item_id", "")).is_empty():
				count += 1
	return count


func _pick_forage_item(soil: String, cfg: Dictionary) -> Dictionary:
	var entries: Array = cfg.get("spawns", {}).get(soil, [])
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
```

`_test_forage_cfg: Dictionary = {}` alongside the other `_test_*` vars;
extend `configure_for_test`'s signature with a fifth optional parameter
`forage_cfg: Dictionary = {}` so every existing call site (Sprint 6's
`test_season_sim.gd` included) keeps compiling.

`to_dict()`/`from_dict()` (`farm_grid.gd:224-262`) gain
`forage_item_id`/`forage_yield` per cell, defaulted empty/`0` for saves
that predate this sprint - same additive-and-defaulted pattern as Sprint
6's `days_mature`.

### `ToolManager` - gathering with bare hands

`use_tool`'s empty-hand branch (`tool_manager.gd:21-30`) currently only
checks `is_harvestable`. Add a forage branch after it:

```gdscript
func use_tool(target_pos: Vector2i) -> bool:
	var tool_id := _equipped_tool_id()
	if tool_id.is_empty():
		if _farm_grid.is_harvestable(target_pos):
			var yields: Array = _farm_grid.harvest(target_pos)
			for entry: Variant in yields:
				var result := entry as Dictionary
				_player_state.add_item(str(result.get("item_id", "")), int(result.get("count", 0)))
			return true
		if _farm_grid.has_forage(target_pos):
			return _gather_forage(target_pos)
		return false
	...  # unchanged tool/seed/weapon dispatch


func _gather_forage(target_pos: Vector2i) -> bool:
	var game_data := _game_data()
	var base_cost := 2.0
	if game_data != null:
		base_cost = float(game_data.get_forage_config().get("gather_energy_cost", 2))
	var skill := get_node_or_null("/root/SkillManager")
	var mult := 1.0
	if skill != null:
		mult = float(skill.get_effect("foraging", "gather_energy_cost_mult", 1.0))
	if not _player_state.consume_energy(base_cost * mult):
		return false
	var result: Dictionary = _farm_grid.gather_forage(target_pos)
	if result.is_empty():
		return false
	var count := int(result.get("count", 0))
	if skill != null:
		count += int(skill.get_effect("foraging", "yield_bonus", 0))
	_player_state.add_item(str(result.get("item_id", "")), count)
	if skill != null:
		skill.add_xp_for("foraging", "gather")
	return true
```

`get_node_or_null("/root/SkillManager")` is correct here (not the bug
class from Sprint 6/README) - `SkillManager` genuinely is an autoload once
the DESKTOP step above registers it, exactly like the existing
`get_node_or_null("/root/GameData")` calls throughout `ToolManager`.

## XP hooks into existing systems

- **Till/water** (`ToolManager._use_tool_item`, `tool_manager.gd:76-96`):
  inside the hoe and watering-can branches' `for off: Vector2i in offsets`
  loops, on each successful `till_tile`/`water_tile` call, also call
  `get_node_or_null("/root/SkillManager")?.add_xp_for("farming",
  "till_tile")` (or `"water_tile"`) - GDScript has no `?.` operator, so
  write it as the usual `var skill := get_node_or_null(...); if skill !=
  null: skill.add_xp_for(...)` guard, matching every other autoload lookup
  in this codebase.
- **Farming energy cost**: multiply `energy_cost` by `SkillManager.
  get_effect("farming", "tool_energy_cost_mult", 1.0)` before calling
  `_player_state.consume_energy(...)` in `_use_tool_item`
  (`tool_manager.gd:73, 77, 88`).
- **Harvest** (`FarmGrid.harvest`, `farm_grid.gd:97-127`): pass a
  farming-skill choice-quality bonus into `_roll_quality`. Widen
  `_roll_quality`'s signature to `_roll_quality(crop_data: Dictionary,
  soil_props: Dictionary, extra_choice_weight: int = 0) -> String` and add
  `extra_choice_weight` to `choice_w`'s computation
  (`farm_grid.gd:338-342`). `harvest()` computes the bonus via
  `get_node_or_null("/root/SkillManager")` the same guarded way as above,
  then after computing `quality`, awards
  `add_xp_for("farming", "harvest_%s" % quality)`.
- **Chores** (`TitheManager.do_chore`, `tithe_manager.gd:165-186`): after a
  successful chore, `add_xp_for("labor", "chore_complete")`. Also apply the
  labor skill's `credit_bonus`/`daily_cap_bonus` - `do_chore`'s `credit :=
  float(chore.get("credit", 0))` gains `+ get_effect("labor",
  "credit_bonus", 0)`, and `_daily_labor_cap()` (`tithe_manager.gd:283-287`)
  gains `+ get_effect("labor", "daily_cap_bonus", 0)`.
- **Combat** (`CombatManager`, deferred detail to Sprint 12 but the hook
  point is worth wiring now since it's a one-line change each): in
  `_on_melee_hitbox_entered` and the `Projectile` hit path
  (`combat_manager.gd:110-119, 166-173`), multiply outgoing `damage` by
  `SkillManager.get_effect("combat", "damage_mult", 1.0)` and award
  `add_xp_for("combat", "hit_enemy")`; award `add_xp_for("combat",
  "defeat_enemy")` on the existing `enemy_defeated` signal (`combat_manager
  .gd:11`, currently emitted - confirm where; if not yet emitted anywhere,
  connect it in `RaidManager._on_raid_enemy_resolved`, which already knows
  when an enemy died vs fled).

## Save schema

`SkillManager.to_dict()`/`from_dict()` follow the `to_dict`/`from_dict`
convention (state-holding node, matching `FarmGrid`/`TimeManager`, not the
`serialize`/`deserialize` convention `TitheManager` uses). `SaveManager`
gains a sixth block, `SAVE_VERSION -> 7`:

```gdscript
# build_payload()
var skills = get_node_or_null("/root/SkillManager")
if skills != null:
	payload["skills"] = skills.to_dict()

# apply_payload()
var skills = get_node_or_null("/root/SkillManager")
if skills != null and payload.has("skills"):
	skills.from_dict(payload["skills"] as Dictionary)
```

(`get_node_or_null("/root/SkillManager")` is correct here - real autoload,
not the FarmGrid-class bug.)

```gdscript
func migrate_to_v7(payload: Dictionary) -> Dictionary:
	payload["version"] = 7
	if not payload.has("skills"):
		payload["skills"] = {"xp": {"farming": 0.0, "foraging": 0.0, "combat": 0.0, "labor": 0.0}}
	var farm: Dictionary = payload.get("farm", {})
	var cells: Array = farm.get("cells", [])
	for entry: Variant in cells:
		var c := entry as Dictionary
		if not c.has("forage_item_id"):
			c["forage_item_id"] = ""
			c["forage_yield"] = 0
	payload["farm"] = farm
	return payload
```

Chain into `read_payload()`: `if version <= 6: parsed = migrate_to_v7(parsed)`.

## HUD integration (Sprint 7's `HudPanel`)

Add a compact skills row: `"Farming Lv%d | Foraging Lv%d | Combat Lv%d |
Labor Lv%d" % [SkillManager.get_level("farming"), ...]`, refreshed on
`SkillManager.leveled_up`. A level-up should also produce a transient
message via whatever toast/message mechanism `HudPanel` inherited from
`main.gd`'s old `_show_message` (Sprint 7 ported it - reuse it, don't
build a second one).

## Tests

### New: `tests/suites/test_skills.gd`

Construct `SKILL_MANAGER_SCRIPT.new()` and a real `GameData` (`.new();
load_all()`), call `configure_for_test(gd)`. Assert:

1. `get_level("farming")` starts at `0`.
2. `add_xp("farming", 80.0)` brings `get_level("farming")` to `1` (matches
   `xp_thresholds[1] = 80`); `leveled_up` fired once with `("farming", 1)`.
3. `add_xp("farming", 1100.0)` more (well past the last threshold) caps at
   the max level (`5`, `xp_thresholds.size() - 1`) - no error, no overflow
   past the array.
4. `get_xp_to_next("farming")` at max level returns `-1.0`.
5. `get_effect("farming", "tool_energy_cost_mult")` at level 0 is `1.0`;
   at level 3 matches `level_effects[3].tool_energy_cost_mult` (`0.85`).
6. `add_xp_for("labor", "chore_complete")` adds exactly
   `gd.get_skill_xp_source("labor", "chore_complete")` (`5.0`).
7. `to_dict()`/`from_dict()` round-trip all four skills' XP values exactly.

Target: 10+ checks.

### New: `tests/suites/test_forage.gd`

Use a small synthetic fixture (mirroring `test_farm_moisture.gd`'s
`_make_grid()` shape) with a forced `spawn_chance_per_tile_per_day = 1.0`
and a single-entry `spawns` table per soil so spawn outcomes are
deterministic. Assert:

1. After one `advance_day(false)` on an untilled cell, `has_forage(pos)` is
   true and the item matches the fixture's single spawn entry.
2. A **tilled** cell never gets a forage spawn, even with chance `1.0` -
   confirms the "untilled only" rule from ADR-022.
3. `gather_forage(pos)` on a spawned cell returns the right `item_id` and a
   `count` within `[yield_min, yield_max]`, and `has_forage(pos)` is false
   immediately after.
4. `gather_forage(pos)` on an empty cell returns `{}`.
5. Respect `max_concurrent_spawns`: with the cap set to `0`, no new spawns
   occur even at chance `1.0`.
6. `to_dict()`/`from_dict()` round-trip `forage_item_id`/`forage_yield`.

Target: 8+ checks.

### `tests/run_tests.gd`

Register `test_skills.gd` and `test_forage.gd`.

## Manual test checklist

1. Confirm the DESKTOP autoload registration landed - press F5, no
   "Invalid get index 'SkillManager'" or similar errors in Output.
2. Till and water several tiles, then check the HUD skills row - Farming
   XP increases per action; leveling up produces a message.
3. Walk the non-loamy 88% of the map (per Sprint 6's redraw) and find a
   forage spawn (wait a few in-game days if none visible immediately -
   spawn chance is per-tile, per-day, at 3%) - interact bare-handed to
   gather it, confirm it lands in inventory and Foraging XP increases.
4. Confirm a **tilled** tile never spawns forage, even after many days.
5. Level Farming up (repeated till/water/harvest) and confirm hoe/can
   energy cost visibly drops and higher-quality harvests become more
   frequent.
6. Save, reload, confirm skill levels and any pending forage spawns on the
   map both persist.
7. Resize the window - HUD skill row remains legible at both extremes.

## Divergences to record

- Foraging state lives on `FarmGrid`, not a dedicated `ForagingManager` -
  deliberate, to avoid a second DESKTOP autoload registration this sprint
  and because tile-keyed state belongs with the tile owner. Revisit only
  if a future sprint needs foraging state independent of farm tiles (none
  currently planned).
- Forage nodes never despawn on their own - only gathering clears them.
  Acceptable at the current map scale (`max_concurrent_spawns` bounds
  total density); revisit if it ever needs a timeout.
