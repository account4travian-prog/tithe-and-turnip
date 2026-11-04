# Sprint 6 - Core loop closure & balance

**Size:** S-M. **Markers:** none - fully agent-assignable, unblocked now.
**ADRs:** ADR-015, ADR-016, ADR-017, ADR-018, ADR-019 (all Proposed - accept
before merging, per `design/decisions.md`; none require a CLAUDE.md
amendment, only ADR acceptance).
**Prerequisite:** Sprint 5 complete (confirmed: 244/244 checks, `SAVE_VERSION
= 5`).
**Baseline before this sprint:** headless import clean, 244/244 checks,
`SAVE_VERSION = 5`.
**Expected after this sprint:** headless import clean, **300/300 checks**
(244 existing, minus test edits noted below, plus new suites - exact count
worked out in the Tests section), `SAVE_VERSION = 6`.

See [README.md](README.md) for the shared GameData/autoload/test/save
conventions this guide assumes without restating.

## Objective

Close the gap between what CLAUDE.md/the ADR log promise and what the
Sprint 1-5 code actually does, and fix five balance defects found in the
2026-08-05 design review. No new systems - every item below is either an
unimplemented contract clause or a bug in existing logic.

## File change manifest

| File | Change |
|---|---|
| `data/player.json` | v1 -> v2: sleep/exhaustion tunables |
| `data/tithe.json` | v1 -> v2: acreage scaling + upkeep |
| `data/crops.json` | v2 -> v3: rebalance + `spoil_after_days` |
| `data/soil_types.json` | v1 -> v2: retuned decay/growth |
| `data/farm_map.json` | v1 -> v2: fragmented soil, relocated features |
| `data/market.json` | v1 -> v2: standing price adjustment |
| `data/reputation.json` | add `fail_upkeep` action |
| `data/dialogue.json` | v2 -> v3: full threshold-band coverage |
| `scripts/autoloads/game_data.gd` | new INT_KEYS, nested-int casts |
| `scripts/autoloads/time_manager.gd` | `forced_collapse` signal, `advance_hours()` |
| `scripts/autoloads/player_state.gd` | exhaustion, `sleep_restore()`, data-driven pass-out |
| `scripts/autoloads/weather_manager.gd` | `is_overcast()` |
| `scripts/world/farm_grid.gd` | plant-time clamp, overwater penalty, overcast decay, spoilage |
| `scripts/autoloads/tithe_manager.gd` | acreage tithe, upkeep, buy-side toll, standing prices |
| `scripts/autoloads/save_manager.gd` | `SAVE_VERSION = 6`, `migrate_to_v6`, **fix the `/root/FarmGrid` save bug (see 0 below)** |
| `scripts/main.gd` | sleep interaction, inject `FarmGrid` refs into `SaveManager`/`TitheManager` |
| `tests/suites/test_market.gd` | fix assertions broken by toll/standing changes |
| `tests/suites/test_farm_moisture.gd` | fix/extend for overwater + overcast |
| `tests/suites/test_sleep_cycle.gd` | new |
| `tests/suites/test_season_sim.gd` | new |
| `tests/run_tests.gd` | register the two new suites |

---

## 0. Fix the pre-existing farm-save bug (not an ADR item - a defect)

**This was found while grounding this guide, not by design review, and is
unrelated to any ADR.** `save_manager.gd:40` and `:59-61` fetch the farm
grid with `get_node_or_null("/root/FarmGrid")`. `docs/bootstrap_project.gd:
129,133` names `main.tscn`'s root `"Main"` and adds `FarmGrid` as its
child, so the live path is `/root/Main/FarmGrid` - the lookup as written
returns `null` in every real play session, `payload["farm"]` is never set,
and farm tile state is never actually saved or restored.
`test_save_roundtrip.gd` doesn't catch it because it drives
`FarmGrid.to_dict()`/`from_dict()` directly, off-tree, never through the
broken live-path lookup. See [README.md](README.md)'s "FarmGrid and
ToolManager are not autoloads" section for the general rule this violates.

Fix by explicit injection instead of a `/root/` guess:

```gdscript
# save_manager.gd - add near the top
var _farm_grid_ref: Node = null


func set_farm_grid_ref(farm_grid: Node) -> void:
	_farm_grid_ref = farm_grid


func _farm_grid() -> Node:
	if _farm_grid_ref != null:
		return _farm_grid_ref
	return get_node_or_null("/root/Main/FarmGrid")
```

Replace both existing lookups:

- `build_payload()` (`save_manager.gd:40-42`): `var farm = _farm_grid()`.
- `apply_payload()` (`save_manager.gd:59-61`): `var farm = _farm_grid()`.

The `/root/Main/FarmGrid` fallback exists only for defensiveness (e.g. a
future scene rename would silently reintroduce the bug if the injection
call were ever removed) - the **primary** mechanism is the injection call
added to `main.gd._ready()` in section 1 below. Do not treat the fallback
path as sufficient on its own; it hardcodes the same fragility this fix is
removing.

---

## 1. Sleep, exhaustion, and forced collapse (ADR-016)

### `data/player.json` v2

```json
{
	"version": 2,
	"move_speed": 220.0,
	"max_energy": 100.0,
	"max_health": 50,
	"tool_energy_cost": 4.0,
	"start_money": 8,
	"plant_energy_cost": 1,
	"sleep_energy_restore_fraction": 0.6,
	"sleep_health_regen": 15,
	"exhaustion_recover_hours": 2,
	"exhaustion_recover_energy": 20,
	"pass_out_money_loss_pct": 0.2,
	"pass_out_health_floor": 10,
	"starter_items": {
		"hoe_wood": 1,
		"can_wood": 1,
		"turnip_seed": 5,
		"arrow": 5
	}
}
```

`PLAYER_INT_KEYS` in `game_data.gd:20` gains `"sleep_health_regen"`,
`"exhaustion_recover_hours"`, `"exhaustion_recover_energy"`,
`"pass_out_health_floor"` (four new ints; the two fractions stay float).

### `TimeManager` changes

Add signal `signal forced_collapse`.

Split the existing `_advance_minute()` (`time_manager.gd:79-89`) so the
hour-24 rollover can optionally skip the collapse signal - required so
`advance_hours()` (below) can cross midnight during an exhaustion recovery
without stacking a second penalty on top of the one already applied:

```gdscript
func _advance_minute() -> void:
	_advance_minute_step(true)


func advance_hours(hours: int, trigger_collapse_penalty: bool = true) -> void:
	var steps := hours * int(_cfg.get("minutes_per_hour", 60))
	for _i in range(steps):
		_advance_minute_step(trigger_collapse_penalty)


func _advance_minute_step(trigger_collapse: bool) -> void:
	minute += 1
	var minutes_per_hour := int(_cfg.get("minutes_per_hour", 60))
	if minute >= minutes_per_hour:
		minute = 0
		hour += 1
		if hour >= 24:
			hour = 0
			if trigger_collapse:
				forced_collapse.emit()
			_advance_day()
	minute_passed.emit(hour, minute)
```

`sleep_to_next_day()` is unchanged - it sets `hour`/`minute` directly and
calls `_advance_day()` itself, never going through `_advance_minute_step`,
so it never emits `forced_collapse`. This is the mechanism that makes
sleeping the safe path and reaching hour 24 unslept the punished one.

`advance_hours()` will emit `minute_passed` up to 120 times for a 2-hour
call. That is intentional and cheap (a `Label.text` set per HUD listener) -
do not attempt to batch/suppress it into a single emit; the existing
`_on_minute_passed` HUD handler is idempotent.

### `PlayerState` changes

Extract the two hardcoded pass-out constants (`player_state.gd:140-147`,
currently `0.2` and `10` inline) to read from `player.json`:

```gdscript
func apply_pass_out_penalty(cause: String) -> void:
	pass_out_count += 1
	var game_data = get_node_or_null("/root/GameData")
	var loss_pct := 0.2
	var health_floor := 10
	if game_data != null:
		loss_pct = float(game_data.player_cfg.get("pass_out_money_loss_pct", 0.2))
		health_floor = int(game_data.player_cfg.get("pass_out_health_floor", 10))
	var lost := int(money * loss_pct)
	money -= lost
	health = health_floor
	money_changed.emit(money)
	health_changed.emit(health, max_health)
	knocked_out.emit(cause)
```

Gate energy consumption through a single choke point - `consume_energy` is
already called by every energy-spending action (`tool_manager.gd:77,88,113`,
`combat_manager.gd:80`, and the new chore/upkeep paths), so this one change
implements the exhaustion trigger everywhere at once:

```gdscript
func consume_energy(amount: float) -> bool:
	if energy < amount:
		trigger_exhaustion()
		return false
	energy -= amount
	energy_changed.emit(energy, max_energy)
	return true


func trigger_exhaustion() -> void:
	_exhaustion_count_today += 1
	apply_pass_out_penalty("exhaustion")
	var game_data = get_node_or_null("/root/GameData")
	var recover_hours := 2
	var recover_energy := 20.0
	if game_data != null:
		recover_hours = int(game_data.player_cfg.get("exhaustion_recover_hours", 2))
		recover_energy = float(game_data.player_cfg.get("exhaustion_recover_energy", 20))
	var tm = get_node_or_null("/root/TimeManager")
	if _exhaustion_count_today >= 2:
		if tm != null:
			tm.sleep_to_next_day()
		_exhaustion_count_today = 0
	elif tm != null:
		tm.advance_hours(recover_hours, false)
	energy = clampf(recover_energy, 0.0, max_energy)
	energy_changed.emit(energy, max_energy)


func sleep_restore() -> void:
	var game_data = get_node_or_null("/root/GameData")
	var fraction := 0.6
	var regen := 15
	if game_data != null:
		fraction = float(game_data.player_cfg.get("sleep_energy_restore_fraction", 0.6))
		regen = int(game_data.player_cfg.get("sleep_health_regen", 15))
	energy = clampf(energy + max_energy * fraction, 0.0, max_energy)
	energy_changed.emit(energy, max_energy)
	heal(regen)
```

Add `var _exhaustion_count_today: int = 0` near the other private-ish vars.
`heal()` already emits `health_changed` (`player_state.gd:121-123`) - do not
emit it again in `sleep_restore`.

Wire the two `TimeManager` signals in `_ready()` (after the existing
`game_data.player_cfg` block, `player_state.gd:31-43`):

```gdscript
	var tm = get_node_or_null("/root/TimeManager")
	if tm != null:
		if not tm.day_passed.is_connected(_on_day_passed):
			tm.day_passed.connect(_on_day_passed)
		if not tm.forced_collapse.is_connected(_on_forced_collapse):
			tm.forced_collapse.connect(_on_forced_collapse)


func _on_day_passed(_day: int, _season: String, _year: int) -> void:
	_exhaustion_count_today = 0


func _on_forced_collapse() -> void:
	apply_pass_out_penalty("exhausted_day")
```

### `main.gd` - the sleep action

`player.gd:78-83` already emits `interacted_with("player_house", pos)` for
any feature tile it doesn't special-case (well is the only current
special-case; `player_house` is a plain feature and falls through to the
generic `interacted_with.emit(...)` at line 82). No `player.gd` change is
needed - only `main.gd`'s dispatch (`main.gd:98-110`) gains a case:

```gdscript
	match feature:
		"market_zone":
			...
		"chapel":
			...
		"stewards_demesne":
			...
		"player_house":
			_sleep()
		_:
			pass


func _sleep() -> void:
	PlayerState.sleep_restore()
	TimeManager.sleep_to_next_day()
	SaveManager.save_game("autosave")
	_show_message("You sleep... a new day begins.")
```

Order matters: restore energy/health first, advance the day second (this
fires `day_passed`, which cascades into `WeatherManager.advance_day()` +
`farm_grid.advance_day()` + `TitheManager._on_day_passed()` +
`PlayerState._on_day_passed()`, all already wired), save last so the
autosave captures the new day's state.

Also add, in `main.gd._ready()`, right after the existing
`player.set_farm_grid(farm_grid)` (`main.gd:32`) - this is what makes both
the section 0 save fix and section 7's acreage-tithe lookup below actually
resolve to a live `FarmGrid` instead of `null`:

```gdscript
	SaveManager.set_farm_grid_ref(farm_grid)
	TitheManager.set_farm_grid_ref(farm_grid)
```

---

## 2. Moisture: plant-time clamp and overwater-as-penalty (ADR-015)

`FarmGrid.plant()` (`farm_grid.gd:65-83`) - clamp moisture to the crop's
max at the moment of planting, immediately after `cell["crop_id"] =
crop_id`:

```gdscript
	cell["crop_id"] = crop_id
	cell["growth_progress"] = 0.0
	cell["moisture"] = minf(float(cell.get("moisture", 0.0)), float(crop_data.get("moisture_max", 100)))
```

This is the actual bug fix - a bare tilled cell that caught rain sits at
100 moisture; planting a turnip (max 85 after the rebalance below) into it
must not leave the cell unrecoverably over-max.

`FarmGrid.advance_day()` (`farm_grid.gd:151-163`) - the growth gate
currently requires `moisture` inside `[min, max]` or nothing grows. Change
it to: **below min still hard-blocks growth** (underwatering is
unrecoverable this tick, unchanged), **above max halves the increment
instead of blocking it** (overwatering is a penalty, not a wall):

```gdscript
	if not crop_data.is_empty():
		var min_m := float(crop_data.get("moisture_min", 0))
		var max_m := float(crop_data.get("moisture_max", 100))
		var moisture := float(cell.get("moisture", 0.0))
		if moisture >= min_m - GROWTH_EPSILON:
			var props2 := _soil_properties(soil)
			var increment := (1.0 / float(crop_data.get("growth_days", 1))) \
				* float(props2.get("growth_speed_mult", 1.0))
			if moisture > max_m + GROWTH_EPSILON:
				increment *= 0.5
			var was_mature := float(cell.get("growth_progress", 0.0)) >= 1.0
			cell["growth_progress"] = clampf(
				float(cell.get("growth_progress", 0.0)) + increment, 0.0, 1.0)
			if not was_mature and float(cell.get("growth_progress", 0.0)) >= 1.0:
				crop_matured.emit(Vector2i(x, y))
```

## 3. Overcast weather halves decay

`WeatherManager` - add an accessor mirroring `is_raining`/`is_snowing`
(`weather_manager.gd:46-51`):

```gdscript
func is_overcast() -> bool:
	return _weather_today == "overcast"
```

`FarmGrid.advance_day()` signature gains a second parameter with a default,
so the one existing call site plus every test call site that doesn't pass
it keep compiling:

```gdscript
func advance_day(rain: bool, overcast: bool = false) -> void:
```

Inside the non-rain decay branch (`farm_grid.gd:147-150`):

```gdscript
		else:
			var props := _soil_properties(soil)
			var decay := float(props.get("moisture_decay_per_day", 0.0))
			if overcast:
				decay *= 0.5
			cell["moisture"] = maxf(0.0, float(cell.get("moisture", 0.0)) - decay)
```

`main.gd:92-95` (`_on_day_passed`) call site:

```gdscript
	farm_grid.advance_day(WeatherManager.is_raining(), WeatherManager.is_overcast())
```

## 4. Crop spoilage (ADR-018)

New per-cell field `days_mature: int`, added to `_default_cell()`
(`farm_grid.gd:289-296`) with default `0`, and to the `to_dict()`/
`from_dict()` cell shape (`farm_grid.gd:224-262`) - `to_dict` writes
`"days_mature": int(c.get("days_mature", 0))`, `from_dict` reads
`cell["days_mature"] = int(e.get("days_mature", 0))` (defaults to 0 for
pre-Sprint-6 saves, so no dedicated migration step is required for this
field specifically - see the save-version note below for why the version
bump still happens).

New signal `signal crop_spoiled(pos: Vector2i)`.

In `advance_day()`, after the growth-progress update, track maturity age
and apply the two-stage rot (stage 1 at `spoil_after_days`: quality
degrades at harvest; stage 2 at `2 * spoil_after_days`: the crop is
destroyed with no yield):

```gdscript
			if float(cell.get("growth_progress", 0.0)) >= 1.0:
				cell["days_mature"] = int(cell.get("days_mature", 0)) + 1
				var spoil_after := int(crop_data.get("spoil_after_days", 0))
				if spoil_after > 0 and int(cell["days_mature"]) > spoil_after * 2:
					cell["crop_id"] = ""
					cell["growth_progress"] = 0.0
					cell["days_mature"] = 0
					crop_spoiled.emit(Vector2i(x, y))
			else:
				cell["days_mature"] = 0
```

In `harvest()` (`farm_grid.gd:97-127`), force `quality = "common"` when the
crop is in stage-1 spoilage (mature past `spoil_after_days` but not yet
destroyed):

```gdscript
	var quality := _roll_quality(crop_data, _soil_properties(soil))
	var spoil_after := int(crop_data.get("spoil_after_days", 0))
	if spoil_after > 0 and int(cell.get("days_mature", 0)) > spoil_after:
		quality = "common"
```

`CROP_INT_KEYS` in `game_data.gd:9-12` gains `"spoil_after_days"`.

## 5. Crop rebalance + seed recovery (`data/crops.json` v3)

```json
{
	"version": 3,
	"crops": [
		{
			"id": "turnip",
			"name": "Turnip",
			"growth_days": 3,
			"seasons": ["spring"],
			"moisture_min": 15,
			"moisture_max": 85,
			"seed_item_id": "turnip_seed",
			"yield_item_id": "turnip",
			"yield_min": 1,
			"yield_max": 3,
			"seed_recovery_min": 0,
			"seed_recovery_max": 1,
			"quality_weights": { "common": 65, "fine": 25, "choice": 10 },
			"spoil_after_days": 3
		},
		{
			"id": "barley",
			"name": "Barley",
			"growth_days": 5,
			"seasons": ["spring", "summer"],
			"moisture_min": 35,
			"moisture_max": 65,
			"seed_item_id": "barley_seed",
			"yield_item_id": "barley",
			"yield_min": 2,
			"yield_max": 3,
			"seed_recovery_min": 0,
			"seed_recovery_max": 1,
			"quality_weights": { "common": 60, "fine": 30, "choice": 10 },
			"spoil_after_days": 4
		},
		{
			"id": "cabbage",
			"name": "Cabbage",
			"growth_days": 6,
			"seasons": ["summer"],
			"moisture_min": 40,
			"moisture_max": 60,
			"seed_item_id": "cabbage_seed",
			"yield_item_id": "cabbage",
			"yield_min": 1,
			"yield_max": 2,
			"seed_recovery_min": 0,
			"seed_recovery_max": 2,
			"quality_weights": { "common": 50, "fine": 35, "choice": 15 },
			"spoil_after_days": 4
		}
	]
}
```

Design intent, stated so nobody "corrects" these numbers back toward the
old ones: **turnip is now the fast, forgiving crop** - 3-day cycle, a wide
15-85 moisture band that tolerates missed waterings, spoils fastest (3
days) so it rewards frequent harvesting rather than stockpiling. **Barley
is the deliberate, high-attention crop** - unchanged 5-day cycle, a
*narrower* 35-65 band than before (was 30-70) that punishes neglect, yield
variance reduced (2-3, was 2-4) so its edge is reliability, not swing.
Neither dominates the other on every axis anymore. **Seed recovery on both
now averages 0.5 per harvest** (0-1, down from turnip's 1-2 and barley's
1-3) - seed stock now nets *negative* on average, so the market's seed
inventory stays a real, recurring cost instead of a one-time purchase.

## 6. Soil retuning + map redraw (ADR-019)

### `data/soil_types.json` v2

```json
{
	"version": 2,
	"soils": {
		"loamy": { "moisture_decay_per_day": 4.0, "growth_speed_mult": 1.1, "fine_quality_bonus": 5, "choice_quality_bonus": 2, "color": "#7a5b32" },
		"sandy": { "moisture_decay_per_day": 7.0, "growth_speed_mult": 1.3, "fine_quality_bonus": -5, "choice_quality_bonus": -5, "color": "#c2a05a" },
		"rocky": { "moisture_decay_per_day": 1.5, "growth_speed_mult": 0.75, "fine_quality_bonus": -8, "choice_quality_bonus": -8, "color": "#6f6f6f" }
	}
}
```

Loamy's decay rises from 0.5 to 4.0 - watering it is now a real, if easy,
chore instead of a once-per-crop no-op. Sandy trades punishing decay (7.0)
for the fastest growth in the game (1.3x, was 0.9x) - a genuine "high
maintenance, high throughput" tile instead of strictly-worst. Rocky trades
poor quality odds and slow growth (0.75x) for the *lowest* decay (1.5) -
the "plant and forget" tile for a player who is energy- or time-starved
that day.

### `data/farm_map.json` v2 - soil layout

The current map is three 10-column vertical stripes repeated across all 20
rows (200 contiguous loamy tiles). Replace it with rocky as the base fill
and sandy/loamy painted on as **non-edge-to-edge rectangles**, so no soil
type reads as "the whole left/right/top/bottom of the map." Paint order:
rocky base -> sandy rectangles -> loamy rectangles (loamy painted last;
none of the rectangles below overlap, so paint order has no actual effect,
but keep it in case a future edit introduces one).

All coordinates are 0-indexed, inclusive, `(x, y)` with `x` = column 0-29,
`y` = row 0-19, matching `farm_map.json`'s existing `grid[y][x]` shape.

**Sandy rectangles:**

| # | x range | y range | Tiles |
|---|---|---|---|
| 1 | 2-9 | 14-18 | 40 |
| 2 | 18-23 | 2-7 | 36 |
| 3 | 12-16 | 10-13 | 20 |

**Loamy rectangles:**

| # | x range | y range | Tiles | Purpose |
|---|---|---|---|---|
| 1 | 0-4 | 0-3 | 20 | around `player_house` at (1,1) |
| 2 | 20-25 | 11-15 | 30 | a second, distant homestead zone |
| 3 | 7-10 | 5-7 | 12 | small pocket |
| 4 | 25-28 | 1-3 | 12 | corner pocket |

Everything else is rocky. Verification checksum once the grid is built:
**loamy 74 tiles (12.3%), sandy 96 tiles (16.0%), rocky 430 tiles (71.7%),
total 600.** If your tile counts don't match this, re-check the rectangle
bounds before moving on - a silent off-by-one here defeats the whole point
of the fix.

Generate the `grid` array (20 rows of 30 strings) by, for each `(x, y)`:
default `"rocky"`; if inside any sandy rectangle, `"sandy"`; if inside any
loamy rectangle (checked after sandy so it would win on a hypothetical
overlap), `"loamy"`.

### `data/farm_map.json` v2 - features

| Feature | Old | New | Why |
|---|---|---|---|
| `player_house` | (1,1) | (1,1), unchanged | already inside loamy rect 1 |
| `well` | (5,5) | **(8,16)** | was trivially inside the old loamy stripe; now inside sandy rect 1, where the 7.0 decay makes proximity to water actually matter |
| *(new)* `well` | - | **(22,13)** | second well, inside loamy rect 2, so the distant homestead zone isn't a two-well walk from spawn |
| `chapel` | (10,15) | unchanged | already outside every new soil rectangle (neutral rocky tile) - no change needed |
| `market_zone` | (25,15) | unchanged | falls inside loamy rect 2's corner - keeping it there puts the market next to the second farmable zone, which is a reasonable design outcome, not a bug |
| `stewards_demesne` | (15,5), 6x6 | unchanged | spans (15-20, 5-10); overlaps the edge of sandy rect 2 but demesne chores don't read `get_soil_at`, so this is harmless |

`features` array gets a second `well` entry added (features are not
unique-by-type; `get_feature_at` returns the first match by bounding-box
containment, and the two wells never overlap in footprint, so both resolve
correctly).

## 7. Acreage-scaled tithe + upkeep (ADR-017) and buy-side toll / standing
prices (ADR-009 / ADR-010 gaps)

### `data/tithe.json` v2

```json
{
	"version": 2,
	"base_amount": 20,
	"coin_per_tilled_tile": 1.5,
	"upkeep": { "enabled": true, "interval_days": 7, "amount": 8 },
	"in_kind_valuation_source": "market_buy_prices",
	"quality_mult_source": "quality_tiers",
	"labor": {
		"daily_credit_cap": 10,
		"chore_ids": ["till_demesne", "water_demesne", "harvest_demesne", "carry_produce"]
	}
}
```

`TITHE_INT_KEYS` (`game_data.gd:22`) becomes `["base_amount"]` (renamed
from `"amount"`). `_cast_nested_ints()` (`game_data.gd:302-338`) gains:

```gdscript
	var upkeep: Dictionary = tithe_cfg.get("upkeep", {})
	upkeep["interval_days"] = int(upkeep.get("interval_days", 7))
	upkeep["amount"] = int(upkeep.get("amount", 0))
```

### `data/market.json` v2 - standing price adjustment

Add one key to the existing file:

```json
	"standing_price_adjustment": { "standing_range": 100, "max_pct": 0.10 }
```

(Both values are floats - no INT_KEYS change needed.)

### `data/reputation.json` - new action

Add to `actions`:

```json
	"fail_upkeep": { "manor": -2, "village": 0, "church": 0 }
```

### `TitheManager` changes

Add a farm-grid accessor mirroring the existing `_player()`/`_game_data()`
pair. **Do not use `get_node_or_null("/root/FarmGrid")`** - per
[README.md](README.md)'s "FarmGrid and ToolManager are not autoloads"
section, that path never resolves in the live game (this is the same class
of bug fixed in section 0). Use the same explicit-injection convention:

```gdscript
var _farm_grid_ref: Node = null  # set by main.gd via set_farm_grid_ref
var _test_farm_grid: Node = null  # alongside the other _test_* vars


func set_farm_grid_ref(farm_grid: Node) -> void:
	_farm_grid_ref = farm_grid


func _farm_grid() -> Node:
	if _test_farm_grid != null:
		return _test_farm_grid
	return _farm_grid_ref
```

Extend `configure_for_test` with a fourth, optional parameter so the two
existing call sites (`test_market.gd:31`, and `test_tithe_labor.gd` /
`test_church.gd`'s equivalents) keep compiling unmodified:

```gdscript
func configure_for_test(player_state: Node, game_data: Node, get_day: Callable, farm_grid: Node = null) -> void:
	_test_player = player_state
	_test_game_data = game_data
	_test_get_day = get_day
	_test_farm_grid = farm_grid
	_test_mode = true
```

Replace `_tithe_goal()` (`tithe_manager.gd:276-281`) with the acreage
formula:

```gdscript
func _tithe_goal() -> int:
	var gd := _game_data()
	if gd == null:
		return 0
	var data := gd.get_tithe_data()
	var base := int(data.get("base_amount", 0))
	var per_tile := float(data.get("coin_per_tilled_tile", 0.0))
	var farm := _farm_grid()
	var tiles := 0
	if farm != null:
		tiles = int(farm.tile_count())
	return base + int(per_tile * float(tiles))
```

Add the standing price factor and route both buy and sell through shared
helpers, so the mismatch class of bug that motivated ADR-009/ADR-010 (two
formulas that can drift apart) can't recur:

```gdscript
func _standing_price_factor(is_buy: bool) -> float:
	if _test_mode:
		return 1.0
	var rep := get_node_or_null("/root/ReputationManager")
	var gd := _game_data()
	if rep == null or gd == null:
		return 1.0
	var cfg: Dictionary = gd.market_cfg.get("standing_price_adjustment", {})
	var range_val := maxf(1.0, float(cfg.get("standing_range", 100)))
	var max_pct := float(cfg.get("max_pct", 0.10))
	var standing := clampf(float(rep.get_standing("manor")), -range_val, range_val)
	var swing := (standing / range_val) * max_pct
	return (1.0 - swing) if is_buy else (1.0 + swing)


func _compute_buy_total(item_id: String, quantity: int) -> int:
	var gd := _game_data()
	if gd == null:
		return 0
	var item: Dictionary = gd.get_item(item_id)
	if item.is_empty():
		return 0
	var unit := float(item.get("price", 0)) * _standing_price_factor(true)
	var subtotal := unit * float(quantity)
	return int(ceil(subtotal * (1.0 + gd.get_market_toll_percent())))


func _compute_sell_net(item_id: String, quantity: int, quality: String) -> int:
	var gd := _game_data()
	if gd == null:
		return 0
	var base: int = gd.get_market_buy_price(item_id)
	var mult: float = (gd.get_quality_tier(quality) as Dictionary).get("price_mult", 1.0)
	var value := float(quantity) * float(base) * mult * _standing_price_factor(false)
	return int(value * (1.0 - gd.get_market_toll_percent()))
```

`can_buy` and `buy_item` (`tithe_manager.gd:45-66`) both call
`_compute_buy_total` instead of recomputing:

```gdscript
func can_buy(item_id: String, quantity: int) -> bool:
	var gd := _game_data()
	if gd == null or gd.get_item(item_id).is_empty():
		return false
	return _player().money >= _compute_buy_total(item_id, quantity)


func buy_item(item_id: String, quantity: int) -> bool:
	if not can_buy(item_id, quantity):
		return false
	var total := _compute_buy_total(item_id, quantity)
	if not _player().spend_money(total):
		return false
	_player().add_item(item_id, quantity)
	transaction_completed.emit("buy", -total)
	_apply_reputation("market_trade")
	return true
```

`sell_crop` (`tithe_manager.gd:78-90`) calls `_compute_sell_net` instead of
its inline formula; `can_sell` is unchanged (it only checks market-open +
inventory, not price).

Deposit-to-tithe and church-donation valuations (`deposit_tithe_crops`,
`donate_crops`) **deliberately keep the flat assize formula** - standing
affects market trading, not tithe/church valuations. Do not route those
through `_standing_price_factor`.

Add upkeep to the day-rollover handler (`tithe_manager.gd:250-252`),
widening its signature to receive `day`:

```gdscript
func _on_day_passed(day: int, _season: String, _year: int) -> void:
	_daily_labor_credit = 0.0
	market_status_changed.emit(is_market_open())
	_apply_upkeep_if_due(day)


func _apply_upkeep_if_due(day: int) -> void:
	var gd := _game_data()
	if gd == null:
		return
	var upkeep: Dictionary = gd.get_tithe_data().get("upkeep", {})
	if not bool(upkeep.get("enabled", false)):
		return
	var interval := int(upkeep.get("interval_days", 7))
	if interval <= 0 or day % interval != 0:
		return
	var amount := int(upkeep.get("amount", 0))
	if _player().spend_money(amount):
		transaction_completed.emit("upkeep", -amount)
	else:
		_apply_reputation("fail_upkeep")
```

Godot 4 lets a signal connect to a handler with fewer parameters than the
signal emits, but not more with mismatched types - `_on_day_passed` must
keep its full `(day, season, year)` signature now that it uses `day`; this
is a widening of an existing method, not a new connection.

## 8. Dialogue coverage (`data/dialogue.json` v3)

Reputation has 3 axes (manor/village/church) x 5 threshold bands
(hostile/cold/neutral/warm/friendly) x per-NPC opinion, and the shipped
file has 7 lines with exactly one condition. Required minimum for this
sprint: **every one of the 6 villagers gets at least one line per band on
its faction's axis** (steward -> manor, priest -> church, the four
villagers -> village), using the existing `conditions: { "reputation.<axis>":
{ "min": N } }` schema (`game_data.gd:257-270`) - no schema change, content
only. That is a minimum of 5 lines/NPC x 6 = 30 lines; a neutral/default
line (no `conditions`) per NPC, as today, still applies as the fallback
when no threshold matches. Use the threshold boundaries already defined in
`reputation.json`: hostile min -100, cold min -49, neutral min -9, warm min
10, friendly min 50.

Example rows for one NPC (steward, manor axis) to fix the pattern - author
the remaining 25 lines to the same shape:

```json
{ "npc_id": "steward", "text": "You're a stain on this manor. Watch yourself.", "conditions": { "reputation.manor": { "min": -100 } } },
{ "npc_id": "steward", "text": "Keep your head down and pay what's owed.", "conditions": { "reputation.manor": { "min": -49 } } },
{ "npc_id": "steward", "text": "Work hard and you may eat." },
{ "npc_id": "steward", "text": "You keep the manor in good order. I notice.", "conditions": { "reputation.manor": { "min": 10 } } },
{ "npc_id": "steward", "text": "The lord himself has heard your name spoken well.", "conditions": { "reputation.manor": { "min": 50 } } }
```

`_dialogue_conditions_pass` only ever checks `min`, and `get_dialogue_for`
returns every line whose condition passes, then `main.gd:119`
(`_on_npc_interacted`) picks `lines[0]` - so **order dialogue.json entries
per NPC from highest threshold to lowest** (friendly first, hostile/no-
condition last) so the best-matching line is always the array's first
match at a given standing. This ordering constraint is not enforced by
code; get it right by construction.

---

## 9. Save version bump

`SaveManager.SAVE_VERSION` -> `6`. Add:

```gdscript
func migrate_to_v6(payload: Dictionary) -> Dictionary:
	payload["version"] = 6
	var farm: Dictionary = payload.get("farm", {})
	var cells: Array = farm.get("cells", [])
	for entry: Variant in cells:
		var c := entry as Dictionary
		if not c.has("days_mature"):
			c["days_mature"] = 0
	payload["farm"] = farm
	return payload
```

Chain it into `read_payload()` (`save_manager.gd:97-105`):

```gdscript
	if version <= 5:
		parsed = migrate_to_v6(parsed)
```

This migration is technically redundant with `FarmGrid.from_dict`'s
`.get("days_mature", 0)` default - it exists to keep the version ladder
honest per CLAUDE.md section 7 ("versioned saves, migrations from day
one"), and to give Sprint 7+ a clean rung to chain off rather than a gap.

---

## Tests

### New case in `tests/suites/test_save_roundtrip.gd`: the farm-save bug

Add a case that would have caught section 0's bug: construct a real
`FarmGrid` via `configure_for_test(...)` (any small fixture grid, matching
the file's existing helper), till and plant one cell, call
`SaveManager.set_farm_grid_ref(farm)`, then `SaveManager.build_payload()`
and assert `payload.has("farm")` is true and
`payload["farm"]["cells"]` is non-empty. Without the section 0 fix this
assertion fails even though every other existing save test in the file
passes - that gap is exactly why the bug went unnoticed.

### Fix `tests/suites/test_market.gd` (existing assertions now wrong)

The buy-side toll and standing-price changes change every dollar figure in
`_test_buy`. With `_standing_price_factor` returning `1.0` in test mode
(the suite never injects a `ReputationManager`, so `_test_mode` short-
circuits it - see `_standing_price_factor` above), only the toll changes
the numbers:

- Spear: base 150 -> `ceil(150 * 1.05) = 158`. Update
  `t.eq(ps.money, 50, ...)` to `t.eq(ps.money, 42, "spear costs 158 with toll")`.
- 3 turnip seeds: base 6 -> `ceil(6 * 1.05) = 7`. Update
  `t.eq(ps.money, 194, ...)` to `t.eq(ps.money, 193, "3 seeds cost 7 with toll")`.

`_test_sell_math` is unaffected (sell already had the toll; standing
factor is neutral in test mode). Re-run the full suite after editing and
confirm the new totals - do not guess further arithmetic by hand without
re-deriving from `_compute_buy_total`.

### Fix/extend `tests/suites/test_farm_moisture.gd`

- `_make_grid()`'s `FAST_CROP`/`turnip` fixtures are synthetic and
  unaffected by the `crops.json` v3 rebalance - no change needed there.
- Add a case for the plant-time clamp: till a cell, set moisture to 100 via
  `water_tile` calls or direct rain simulation, then `plant()` a crop whose
  `moisture_max` is below 100 (e.g. the fixture `turnip`, max 80) and
  assert `get_cell_moisture(pos) <= 80.0` immediately after `plant()`
  returns 0.
- Add a case for the overwater penalty: construct a cell already above
  `moisture_max`, call `advance_day(false)`, and assert growth increments
  by **half** the normal per-day amount rather than zero.
- Add a case for overcast decay: call `advance_day(false, true)` on a dry
  soil cell and assert the moisture loss is half of an `advance_day(false,
  false)` call under the same starting moisture.
- Existing `advance_day(rain_bool)` single-arg call sites keep compiling
  (the new `overcast` parameter defaults to `false`) - do not touch them
  unless they specifically need overcast coverage.

### New: `tests/suites/test_sleep_cycle.gd`

Construct `PlayerState` and `TimeManager` scripts directly (`PLAYER_STATE_
SCRIPT.new()`, `TIME_MANAGER_SCRIPT.new()`), wire the signal connections
by hand exactly as `PlayerState._ready()` would in-tree (since `.new()`
without `add_child` never fires `_ready`), and assert:

1. `consume_energy` on a `PlayerState` with `energy = 0` returns `false`,
   increments `pass_out_count`, sets `health` to `pass_out_health_floor`,
   and reduces `money` by `floor(money * pass_out_money_loss_pct)`.
2. A second `consume_energy` failure the same simulated day (drive it by
   calling `trigger_exhaustion()` twice without an intervening
   `_on_day_passed` reset) results in `energy == exhaustion_recover_energy`
   and `TimeManager.hour == TimeManager._cfg.wake_hour` /
   `TimeManager.day` having advanced by exactly one - i.e., the second
   same-day exhaustion forces a full day rollover, not just a 2-hour skip.
3. `sleep_restore()` on `energy = 40, max_energy = 100,
   sleep_energy_restore_fraction = 0.6` yields `energy == 100` (40 + 60,
   clamped) - and on `energy = 90` yields `energy == 100` (40+60 would
   overflow; confirms the `clampf`).
4. `TimeManager.advance_hours(2, false)` from `hour = 23, minute = 0` rolls
   to the next day (`day` incremented) **without** emitting
   `forced_collapse` - connect a bound counter to the signal and assert it
   stays 0.
5. `TimeManager.advance_hours` reaching hour 24 with
   `trigger_collapse_penalty = true` (the default) **does** emit
   `forced_collapse` exactly once.
6. Calling `advance_hours` twice in the same simulated day segment does not
   double-fire `day_passed` beyond what the hour math implies (sanity check
   on the refactor, not a new behavior).

Target: 10+ checks (this list implies at least 12 `ok`/`eq` calls across
the six scenarios above).

### New: `tests/suites/test_season_sim.gd`

The balance regression guard. Unlike every other suite, this one
constructs `GameData` for real (`GAME_DATA_SCRIPT.new(); gd.load_all()`)
and feeds the *actual* `crops.json`/`soil_types.json`/`farm_map.json`
content into `FarmGrid.configure_for_test`, rather than a synthetic
fixture - the whole point is to catch drift in the shipped numbers, not to
test the engine.

Construction:

```gdscript
var gd = GAME_DATA_SCRIPT.new()
gd.load_all()
var soil_map := {}
for y in range(gd.get_map_height()):
	for x in range(gd.get_map_width()):
		soil_map[Vector2i(x, y)] = gd.get_soil_at(x, y)
var farm = FARM_GRID_SCRIPT.new()
farm.configure_for_test(gd.crops, soil_map, gd.soil_types, Vector2i(gd.get_map_width(), gd.get_map_height()))
var ps = PLAYER_STATE_SCRIPT.new()
# seed ps.money / ps.inventory from gd.player_cfg by hand, mirroring PlayerState._ready()'s
# own logic, since .new() off-tree never fires _ready and never sees GameData.
var tm = TITHE_SCRIPT.new()
var day_holder := [1]
tm.configure_for_test(ps, gd, func() -> int: return day_holder[0], farm)
```

Simulation loop, `day` 1 through 28: till + plant a fixed, documented
number of turnip and barley tiles on **loamy** soil only (pick coordinates
known to be loamy under the new `farm_map.json` v2 layout, e.g. within
loamy rect 1); call `farm.water_tile(...)` when moisture is below the
crop's `moisture_min` (simulate a diligent-but-not-obsessive player, not an
optimal bot); call `farm.advance_day(rain, overcast)` using a **fixed,
seeded weather sequence** (do not call `randf()` for this - hardcode a
28-day array of `{rain, overcast}` pairs at the top of the suite so the
test is deterministic); call `tm._on_day_passed(day, "spring", 1)` by hand
each day (nothing is in the tree, so the real signal never fires - this
mirrors how `test_market.gd`'s day-holder pattern already sidesteps the
same problem for market-open checks); harvest and sell matured tiles
through `tm.sell_crop(...)` on market days
(`gd.is_market_day(day)`); track cumulative coin.

Assertions at day 28:

1. `tm.get_tithe_progress().remaining <= 0.0` given the coin earned plus at
   least one deliberate tithe payment - i.e., **the tithe is payable** by a
   moderately-attentive playthrough. This is the primary regression guard:
   if a future data edit makes the tithe unpayable under this fixed
   playthrough, this assertion catches it.
2. Total coin earned, after paying the tithe in full, still covers **at
   least one** tool or weapon upgrade from `items.json` (e.g. `hoe_iron` at
   100, or `can_iron` at 80) - i.e., the tithe does not consume the entire
   season's income. This is the upper bound: if a future edit makes the
   tithe *too* punishing, this assertion catches that direction too.
3. `ps.energy` never goes negative and the simulation never needs to call
   `PlayerState.trigger_exhaustion()` more than a documented small number
   of times (e.g. <= 2) across the full 28 days under the diligent-player
   script - if the moisture/energy economy is so punishing that a
   reasonable playthrough is knocked out repeatedly, that is itself a
   balance regression worth failing on.

Target: 3 core assertions is the floor: this suite's value is in
*existing and running on every future data edit*, not in exhaustive
coverage. Keep the simulation script (till/water/harvest schedule, weather
sequence) as named constants at the top of the file so a future sprint
that changes `crops.json` again can see exactly what assumptions it must
keep satisfying.

### `tests/run_tests.gd`

Add both new suites to `SUITES`, after `test_combat.gd`:

```gdscript
	preload("res://tests/suites/test_sleep_cycle.gd"),
	preload("res://tests/suites/test_season_sim.gd"),
```

---

## Manual test checklist

1. Open the project in Godot 4.7.1 and press F5 - the game runs with no
   errors in Output.
2. Till and plant a turnip on loamy soil near spawn - expect the tile to
   sit inside loamy rect 1's redrawn boundary (roughly the 5x4 block around
   (1,1)) and growth to advance daily while watered.
3. Deliberately let a tilled-but-unplanted cell catch a rainy day, then
   plant a turnip on it - expect the crop to grow normally on subsequent
   days (the plant-time clamp fix), not stall forever.
4. Walk to (8,16) and (22,13) - expect a well interaction (refill) at both.
5. Interact with the player house tile at (1,1) - expect a "you sleep..."
   message, the clock jumping to the wake hour of the next day, energy and
   health increasing (not maxing out), and a new `save_autosave.json`
   timestamp.
6. Use a tool with 0 energy - expect a pass-out message, a 2-hour clock
   skip, energy at 20, and reduced money. Repeat immediately - expect a
   full forced sleep to the next morning instead of another 2-hour skip.
7. Let the in-game clock reach hour 24 without sleeping - expect the same
   pass-out penalty to fire automatically (forced collapse), distinct from
   the no-penalty rollover that happens after a deliberate sleep.
8. Buy an item at the market stall - expect the total charged to include
   the 5% toll (a 30-coin item costs 32, not 30).
9. Visit the steward, priest, and one villager at both a low and a high
   manor/village standing (use debug or repeated `market_trade`/`donate`
   actions to move standing) - expect different dialogue lines at each
   band, not the same line regardless of standing.
10. Check the HUD tithe goal on a fresh save - expect it to read
    `base_amount` plus a contribution from tilled tile count, not a flat
    20.
11. Run past day 7 (or day 14/21) - expect an automatic upkeep deduction
    message/log around those days.
12. Resize the window to a wide and a tall aspect - the play area adapts
    without distortion.
13. Till a tile, sleep (autosave fires), quit to the OS, relaunch, and load
    the autosave - expect the tile to still show as tilled. Before this
    sprint's section 0 fix, tilled/planted state was silently lost on
    every reload; this is the regression check for that.

## Divergences to record in `DEVELOPMENT_STATE.md`

Record whichever of these actually occur during implementation, plus
anything unexpected:

- Exhaustion count (`_exhaustion_count_today`) is intentionally **not**
  persisted across save/load - a save made mid-exhaustion-ladder resets the
  count to zero on load. Acceptable: the ladder is a same-day mechanic and
  saves happen at sleep, which already resets the count via `day_passed`.
- `TimeManager.advance_hours` emits `minute_passed` once per simulated
  minute (up to 120 times for a 2-hour call) rather than batching to a
  single emit - deliberate, see the TimeManager section above.
- `test_season_sim.gd` calls `TitheManager._on_day_passed` directly rather
  than relying on signal delivery, because suite scripts are constructed
  off the scene tree - consistent with the existing day-holder pattern in
  `test_market.gd`, not a new workaround.
- Fixed a pre-existing defect (not from any ADR): `SaveManager` looked up
  `FarmGrid` at `/root/FarmGrid`, which never resolves in the live scene
  tree (`FarmGrid` actually lives at `/root/Main/FarmGrid`); farm tile
  state was silently never saved or restored. Fixed by explicit injection
  from `main.gd` instead of a `/root/` path guess - see section 0. Record
  in `DEVELOPMENT_STATE.md` as a fixed defect, not a divergence from
  design intent.
