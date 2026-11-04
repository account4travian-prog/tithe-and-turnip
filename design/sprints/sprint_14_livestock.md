# Sprint 14 - Livestock

**Size:** M-L. **Markers:** DESKTOP (one autoload registration, ~2 minutes
- same steps as Sprint 8's, substituting `AnimalManager`), AMENDMENT.
**ADR:** ADR-028 - Proposed ("Livestock/animals" is on CLAUDE.md's
out-of-scope list; confirm Accepted + the list amended before starting).
**Prerequisite:** Sprint 9 (animals need a completed coop to be housed).

## Correction to the roadmap's DESKTOP scope

Same correction as every prior DESKTOP sprint: animal "scenes" are
runtime-built markers exactly like `NPC` (Sprint 1) - no `.tscn` needed.
Only the `AnimalManager` autoload registration requires the editor.

## Objective

Two species - chickens and one goat, keeping the small-cast principle that
already governs villagers - with daily feed/water, a coop (Sprint 9
building) for shelter and capacity, product cycles (eggs/milk), happiness
driving product quality via the existing `quality_tiers.json` tiers, and
raid vulnerability so Sprint 12's deterrence has one more thing at stake.

## `data/animals.json` (new)

```json
{
	"version": 1,
	"max_happiness": 100,
	"start_happiness": 60,
	"happiness_fine_weight_scale": 15,
	"happiness_choice_weight_scale": 20,
	"raid_loss_chance_per_animal": 0.25,
	"species": {
		"chicken": {
			"name": "Chicken", "purchase_price": 30,
			"feed_item_id": "barley", "feed_amount": 1,
			"product_item_id": "egg", "product_cycle_days": 1,
			"happiness_gain_fed": 10, "happiness_loss_unfed": 20,
			"quality_weights": { "common": 70, "fine": 25, "choice": 5 }
		},
		"goat": {
			"name": "Goat", "purchase_price": 80,
			"feed_item_id": "barley", "feed_amount": 2,
			"product_item_id": "milk", "product_cycle_days": 2,
			"happiness_gain_fed": 8, "happiness_loss_unfed": 15,
			"quality_weights": { "common": 60, "fine": 30, "choice": 10 }
		}
	}
}
```

Quality scales with happiness **linearly**, not via thresholds - a
`happiness_frac := happiness / max_happiness` shifts weight toward
`fine`/`choice` proportionally (see `AnimalManager._roll_quality` below).
This mirrors `FarmGrid._roll_quality`'s soil-bonus pattern
(`farm_grid.gd:338-351`) closely enough to be recognizable, but is its own
function - animals don't have soil, they have a happiness float, and
forcing the two into one shared helper would need a parameter that means
different things in each caller, which is worse than two small, honest
functions.

`GameData`: `ANIMAL_INT_KEYS` casts `max_happiness`,
`happiness_fine_weight_scale`, `happiness_choice_weight_scale`, and per
species: `purchase_price`, `feed_amount`, `product_cycle_days`,
`happiness_gain_fed`, `happiness_loss_unfed`, and every `quality_weights`
value (`raid_loss_chance_per_animal`/`start_happiness` stay float).
`animals_cfg: Dictionary` from `animals.json`. `get_animal_species(id: 
String) -> Dictionary` returning `animals_cfg.get("species", {}).get(id,
{})`.

## New items (`data/items.json` v4 -> v5)

```json
{ "id": "egg", "type": "food", "name": "Egg", "price": 0, "stackable": true, "energy_base": 6 },
{ "id": "milk", "type": "food", "name": "Milk", "price": 0, "stackable": true, "energy_base": 8 }
```

Add to `market.json`'s `buy_prices`: `"egg": 4, "milk": 7`.

## New building (`data/buildings.json` v2 -> v3)

```json
"coop": { "name": "Animal Coop", "footprint_w": 2, "footprint_h": 2, "cost_coin": 70, "cost_materials": { "flint": 8 }, "build_days": 2, "animal_capacity": 4 }
```

`BUILDING_INT_KEYS` (already extended in Sprint 9) needs `animal_capacity`
added.

## `AnimalManager` autoload (`scripts/autoloads/animal_manager.gd`)

```gdscript
extends Node

signal animal_purchased(animal_id: String, species: String)
signal product_ready(animal_id: String, item_id: String, quality: String)
signal animal_lost(animal_id: String, reason: String)

var _animals: Dictionary = {}  # animal_id -> {species, happiness, fed_today, days_since_product}
var _next_id := 1

var _test_player: Node = null
var _test_game_data: Node = null
var _test_building: Node = null
var _test_mode := false


func _ready() -> void:
	var tm := get_node_or_null("/root/TimeManager")
	if tm != null and not tm.day_passed.is_connected(_on_day_passed):
		tm.day_passed.connect(_on_day_passed)
	var rm := get_node_or_null("/root/RaidManager")
	if rm != null and not rm.raid_resolved.is_connected(_on_raid_resolved):
		rm.raid_resolved.connect(_on_raid_resolved)


func configure_for_test(player_state: Node, game_data: Node, building_manager: Node = null) -> void:
	_test_player = player_state
	_test_game_data = game_data
	_test_building = building_manager
	_test_mode = true


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


func to_dict() -> Dictionary:
	return {"animals": _animals.duplicate(true), "next_id": _next_id}


func from_dict(data: Dictionary) -> void:
	_animals = (data.get("animals", {}) as Dictionary).duplicate(true)
	_next_id = int(data.get("next_id", 1))


func _on_day_passed(_day: int, _season: String, _year: int) -> void:
	var gd := _game_data()
	if gd == null:
		return
	var cfg := gd.animals_cfg
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


func _on_raid_resolved(win: bool) -> void:
	if win or _test_mode:
		return
	var gd := _game_data()
	if gd == null:
		return
	var loss_chance := float(gd.animals_cfg.get("raid_loss_chance_per_animal", 0.0))
	for id: String in get_animal_ids():
		if randf() < loss_chance:
			_animals.erase(id)
			animal_lost.emit(id, "raid")


func _roll_quality(def: Dictionary, happiness: float, max_happy: float, cfg: Dictionary) -> String:
	var weights: Dictionary = def.get("quality_weights", {})
	var frac := happiness / max_happy
	var common_w := maxi(0, int(weights.get("common", 70)))
	var fine_w := maxi(0, int(weights.get("fine", 25)) + int(frac * float(cfg.get("happiness_fine_weight_scale", 0))))
	var choice_w := maxi(0, int(weights.get("choice", 5)) + int(frac * float(cfg.get("happiness_choice_weight_scale", 0))))
	var total := float(common_w + fine_w + choice_w)
	if total <= 0.0:
		return "common"
	var roll := randf() * total
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
```

`_on_raid_resolved` connects to `/root/RaidManager` - a real autoload, so
this is legal per the README's rule; note it's guarded the same
`is_connected` way every other cross-autoload wiring in this codebase is.
An animal is lost only on a **lost** raid (`win == false`), independently
per animal at `raid_loss_chance_per_animal` - a coop full of four animals
isn't wiped out or spared as a block, each rolls separately.

## Interaction and UI

`Player`'s station dispatch (added in Sprint 13 for `drying_shed`/
`hearth`) gains `"coop"` to the same check:

```gdscript
	if station_id == "drying_shed" or station_id == "hearth" or station_id == "coop":
		station_interacted.emit(station_id, target)
		return
```

`main.gd`'s `station_interacted` handler routes `"coop"` to a new
`AnimalPanel` (Sprint 7 pattern) instead of `CraftingPanel`. The panel
shows: two "Buy" rows (chicken/goat) disabled when `can_buy_animal` is
false (insufficient coin or coop at capacity - show which), and one row
per owned animal (species, happiness as a bar or percentage, "Fed today"
y/n) with a "Feed" button calling `AnimalManager.feed_animal(id)`.

## Save schema

`SAVE_VERSION -> 13`.

```gdscript
# build_payload()
var animals = get_node_or_null("/root/AnimalManager")
if animals != null:
	payload["animals"] = animals.to_dict()

# apply_payload()
var animals = get_node_or_null("/root/AnimalManager")
if animals != null and payload.has("animals"):
	animals.from_dict(payload["animals"] as Dictionary)
```

```gdscript
func migrate_to_v13(payload: Dictionary) -> Dictionary:
	payload["version"] = 13
	if not payload.has("animals"):
		payload["animals"] = {"animals": {}, "next_id": 1}
	return payload
```

Chain: `if version <= 12: parsed = migrate_to_v13(parsed)`.

## Tests

### New: `tests/suites/test_animals.gd`

Construct `ANIMAL_MANAGER_SCRIPT.new()`, a real `GameData`, a
`PlayerState`, and a `BuildingManager` configured with a completed `coop`
(reuse the pattern Sprint 13's `test_crafting.gd` established for
mocking/constructing a real `BuildingManager` in test mode). Assert:

1. `can_buy_animal` false with a coop at capacity `0` (no coop built);
   true once a coop with `animal_capacity: 4` is completed and no animals
   are owned yet.
2. `buy_animal` deducts `purchase_price`, adds an entry to
   `get_animal_ids()`, and fails once `_animals.size()` reaches the
   coop's total capacity.
3. `feed_animal` consumes the species' `feed_item_id`/`feed_amount` and
   sets `fed_today`; a second `feed_animal` call the same day fails
   without double-consuming feed.
4. `_on_day_passed`: a fed animal's `happiness` rises by
   `happiness_gain_fed` (clamped at `max_happiness`); an unfed animal's
   falls by `happiness_loss_unfed` (clamped at `0`); `fed_today` resets to
   `false` either way.
5. Product cycle: a chicken (`product_cycle_days: 1`) produces an egg
   every single day-passed call; a goat (`product_cycle_days: 2`)
   produces milk only every other call - assert the exact cadence, not
   just "eventually produces something."
6. Quality scales with happiness: two otherwise-identical animals, one at
   happiness `0` and one at `max_happiness`, produce different quality
   distributions over many rolls (or, to avoid statistical flakiness,
   directly compare the computed `fine_w`/`choice_w` weights the two
   happiness values produce via the same formula the implementation uses,
   the same "check the formula, not a random sample" approach Sprint
   11's price-drift test uses).
7. Raid loss: `_on_raid_resolved(false)` with `raid_loss_chance_per_animal
   = 1.0` removes every owned animal and fires `animal_lost` once per
   animal; `_on_raid_resolved(true)` (a won raid) removes none regardless
   of chance.
8. `to_dict()`/`from_dict()` round-trip every animal's full state
   (species, happiness, fed_today, days_since_product) and `_next_id`
   exactly.

Target: 14+ checks.

### `tests/run_tests.gd`

Register `test_animals.gd`.

## Manual test checklist

1. Confirm the DESKTOP autoload registration - F5, no `AnimalManager`
   errors in Output.
2. Try to open the animal panel with no coop built - not reachable (no
   `station_interacted` fires for a tile that isn't a completed coop).
3. Build a coop, interact with it, buy a chicken and a goat.
4. Feed both, skip feeding one of them on a later day, compare happiness
   trends over several days on the HUD/panel.
5. Confirm eggs appear daily and milk every other day, landing in
   inventory with a visible quality tier.
6. Keep an animal's happiness low for a while (skip feeding), then high
   (feed consistently), and compare the quality distribution of products
   received - confirm high happiness visibly skews toward `fine`/`choice`.
7. Trigger and lose a raid (or use test hooks to force
   `raid_loss_chance_per_animal` high) - confirm an animal can be lost,
   with a clear message, and that this only happens on a lost raid.
8. Save, reload - every animal's species/happiness/feed state/product
   timer persists exactly.
9. Resize the window - animal panel remains legible.

## Divergences to record

- Quality-from-happiness uses a linear weight scale, not
  `FarmGrid._roll_quality`'s discrete soil-bonus table - a separate
  function rather than a forced shared abstraction between two
  conceptually different inputs (soil type vs. a happiness float). See
  the `animals.json` section for the reasoning.
- No "water" resource separate from feed - the roadmap description
  mentions "feed/water" together; this guide models a single feed
  resource (`feed_item_id`/`feed_amount`) rather than two independently
  tracked needs, to avoid doubling every piece of per-animal state for a
  distinction that wouldn't play differently in practice at this scale.
  Revisit only if playtesting specifically wants water as a separate
  lever (e.g. tied to the well system) rather than folded into feeding.
