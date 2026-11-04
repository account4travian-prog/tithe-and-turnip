# Phase 1 schema draft - E1 Spring Crop Pack + E2 Soil Fertility + E12 Foraging 2.0

**Status:** Draft for owner review. No `data/*.json` file has been modified
to produce this document - every block below is what Phase 1 implementation
should write, not what's currently shipped. No code was written either.

**Scope:** per `Proposal_Spring_Feature_Expansion.md` section 7, Phase 1
covers `crops.json v4`, `items.json v8`, `forage.json v3`, `recipes.json
v2`, `soil_types.json v3`. Checking the actual repo (2026-08-07) surfaced
two more files that must move in lockstep even though neither proposal nor
addendum named them: **`market.json`** (new crops/goods are unsellable and
unbuyable without `buy_prices`/`stall_inventory` entries) and a
**content-only** pass on **`villagers.json`** (no schema/version change - E1
and E12 both promise gift likes/dislikes for the new items, which live
there). Compost's `items.json`/`recipes.json` entries were already speced
in `Compost_Spec_Addendum.md`; this document is consistent with that
addendum and doesn't repeat its rationale, only its final field shapes.

Everywhere the source proposal or R2a left a number unspecified (quality
weights, fertility depletion for the four new crops, seed prices, exact
recipe compositions), this draft picks a concrete value and **flags it as a
judgment call** in section 9 rather than presenting it as sourced from the
proposal. Flagged values are easy to retune later - none of them are
structural.

---

## 1. `crops.json` (v3 -> v4)

Existing three crops gain `fertility_depletion`/`fertility_min`; four new
Spring crops added in full, per the base proposal's E1 table.

```json
{
	"version": 4,
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
			"spoil_after_days": 3,
			"fertility_depletion": 10,
			"fertility_min": 0
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
			"spoil_after_days": 4,
			"fertility_depletion": 18,
			"fertility_min": 0
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
			"spoil_after_days": 4,
			"fertility_depletion": 15,
			"fertility_min": 0
		},
		{
			"id": "carrot",
			"name": "Carrot",
			"growth_days": 2,
			"seasons": ["spring"],
			"moisture_min": 30,
			"moisture_max": 70,
			"seed_item_id": "carrot_seed",
			"yield_item_id": "carrot",
			"yield_min": 1,
			"yield_max": 2,
			"seed_recovery_min": 1,
			"seed_recovery_max": 2,
			"quality_weights": { "common": 65, "fine": 25, "choice": 10 },
			"spoil_after_days": 5,
			"fertility_depletion": 8,
			"fertility_min": 0
		},
		{
			"id": "pea",
			"name": "Pea",
			"growth_days": 3,
			"seasons": ["spring"],
			"moisture_min": 40,
			"moisture_max": 80,
			"seed_item_id": "pea_seed",
			"yield_item_id": "pea",
			"yield_min": 1,
			"yield_max": 3,
			"seed_recovery_min": 1,
			"seed_recovery_max": 2,
			"quality_weights": { "common": 60, "fine": 30, "choice": 10 },
			"spoil_after_days": 3,
			"fertility_depletion": -8,
			"fertility_min": 0
		},
		{
			"id": "onion",
			"name": "Onion",
			"growth_days": 4,
			"seasons": ["spring"],
			"moisture_min": 20,
			"moisture_max": 50,
			"seed_item_id": "onion_seed",
			"yield_item_id": "onion",
			"yield_min": 1,
			"yield_max": 4,
			"seed_recovery_min": 0,
			"seed_recovery_max": 2,
			"quality_weights": { "common": 55, "fine": 30, "choice": 15 },
			"spoil_after_days": 7,
			"fertility_depletion": 16,
			"fertility_min": 0
		},
		{
			"id": "leek",
			"name": "Leek",
			"growth_days": 4,
			"seasons": ["spring"],
			"moisture_min": 50,
			"moisture_max": 90,
			"seed_item_id": "leek_seed",
			"yield_item_id": "leek",
			"yield_min": 1,
			"yield_max": 2,
			"seed_recovery_min": 1,
			"seed_recovery_max": 3,
			"quality_weights": { "common": 50, "fine": 35, "choice": 15 },
			"spoil_after_days": 5,
			"fertility_depletion": 12,
			"fertility_min": 0
		}
	]
}
```

`pea`'s negative depletion is the one number taken directly from R2a (its
"beans -8" example, same nitrogen-fixer role) rather than judgment-called;
everything else in the new-crop `fertility_depletion` column is this
draft's own estimate, built to land inside the base proposal's own
"avg. crop depletion 12-18" guardrail for the two non-legume, non-fast-cash
crops (onion, leek) while carrot stays low to match its "fast cash, low
risk" framing.

## 2. `soil_types.json` (v2 -> v3)

```json
{
	"version": 3,
	"soils": {
		"loamy": { "moisture_decay_per_day": 4.0, "growth_speed_mult": 1.1, "fine_quality_bonus": 5, "choice_quality_bonus": 2, "color": "#7a5b32", "fertility_init": 70, "fertility_recovery_per_day": 1.5, "high_fertility_quality_bonus": 5 },
		"sandy": { "moisture_decay_per_day": 7.0, "growth_speed_mult": 1.3, "fine_quality_bonus": -5, "choice_quality_bonus": -5, "color": "#c2a05a", "fertility_init": 50, "fertility_recovery_per_day": 1.0, "high_fertility_quality_bonus": 3 },
		"rocky": { "moisture_decay_per_day": 1.5, "growth_speed_mult": 0.75, "fine_quality_bonus": -8, "choice_quality_bonus": -8, "color": "#6f6f6f", "fertility_init": 30, "fertility_recovery_per_day": 0.75, "high_fertility_quality_bonus": 2 }
	}
}
```

**Addition beyond both proposal and R2a: `fertility_init`.** Neither
document's schema section lists it, but both narrate "at map generation,
fertility is initialised from soil_types.json: loamy=70, sandy=50,
rocky=30" - those three numbers have to live somewhere, and `CLAUDE.md`
rule 3.5 ("no magic numbers in gameplay code... every tunable comes from
JSON") rules out hardcoding them in `FarmGrid._init_cell`. `fertility_init`
closes that gap; without it, the fertility system's own stated design
can't be built without violating the contract's own style rule.

`fertility_recovery_per_day` stays a float (fallow recovery is meant to be
gradual, ~1-2/day per the base proposal's balance table) and is **not**
added to `SOIL_INT_KEYS`. `fertility_init` and `high_fertility_quality_bonus`
are both ints and do need adding there (section 8).

## 3. `items.json` (v7 -> v8)

New entries only - append to the existing `items` array. Groups match the
systems that need them.

**E1 crop yield + seed items:**
```json
{ "id": "carrot", "type": "food", "name": "Carrot", "price": 0, "stackable": true, "energy_base": 5 },
{ "id": "pea", "type": "food", "name": "Pea", "price": 0, "stackable": true, "energy_base": 6 },
{ "id": "onion", "type": "food", "name": "Onion", "price": 0, "stackable": true, "energy_base": 6 },
{ "id": "leek", "type": "food", "name": "Leek", "price": 0, "stackable": true, "energy_base": 7 },
{ "id": "carrot_seed", "type": "seed", "name": "Carrot Seeds", "price": 2, "stackable": true, "crop_id": "carrot" },
{ "id": "pea_seed", "type": "seed", "name": "Pea Seeds", "price": 3, "stackable": true, "crop_id": "pea" },
{ "id": "onion_seed", "type": "seed", "name": "Onion Seeds", "price": 3, "stackable": true, "crop_id": "onion" },
{ "id": "leek_seed", "type": "seed", "name": "Leek Seeds", "price": 4, "stackable": true, "crop_id": "leek" }
```
(`price: 0` on yield items matches `turnip`/`barley`/`cabbage` exactly -
real sell price lives in `market.json.buy_prices`, not here. Seed prices
are this draft's judgment call, scaled the same way `turnip_seed`(2) <
`barley_seed`/`cabbage_seed`(3) already are.)

**E1 cooked-dish items (feeds the `recipes.json` additions in section 5):**
```json
{ "id": "carrot_stew", "type": "food", "name": "Carrot Stew", "price": 7, "stackable": true, "energy_base": 20 },
{ "id": "pea_soup", "type": "food", "name": "Pea Soup", "price": 6, "stackable": true, "energy_base": 16 },
{ "id": "leek_pie", "type": "food", "name": "Leek Pie", "price": 12, "stackable": true, "energy_base": 24 },
{ "id": "morel_stew", "type": "food", "name": "Morel Stew", "price": 9, "stackable": true, "energy_base": 20 }
```

**E12 foraging items:**
```json
{ "id": "wild_carrot", "type": "food", "name": "Wild Carrot", "price": 0, "stackable": true, "energy_base": 4 },
{ "id": "wild_turnip", "type": "food", "name": "Wild Turnip", "price": 0, "stackable": true, "energy_base": 4 },
{ "id": "morel", "type": "food", "name": "Morel", "price": 25, "stackable": true, "energy_base": 8 },
{ "id": "truffle", "type": "food", "name": "Truffle", "price": 80, "stackable": true, "energy_base": 10 },
{ "id": "spade", "type": "tool", "name": "Spade", "price": 20, "tool_category": "spade", "tier": 1, "energy_cost": 4, "area_shape": "single" }
```
(`morel`/`truffle` prices are the two numbers the proposal states directly
- 25 and 80 - carried over unchanged. `spade` follows the existing tool
shape exactly; `tool_category: "spade"` is a new category value, same
pattern as `"hoe"`/`"watering_can"`.)

**E2 compost items** - already speced in `Compost_Spec_Addendum.md`
section 3 (corrected there to drop the nonexistent `sellable`/`effect`
fields R2a's sketch used):
```json
{ "id": "compost", "type": "material", "name": "Compost", "price": 0, "stackable": true, "fertilize_amount": 20 },
{ "id": "spoiled_crop", "type": "food", "name": "Spoiled Crop", "price": 0, "stackable": true, "energy_base": 1 }
```

## 4. `forage.json` (v2 -> v3)

**Revised 2026-08-07 - option B chosen (see section 9.3).** Digging is a
dedicated action with its own loot table, not a gate on the passive spawn
system. `wild_carrot`/`wild_turnip` are removed from `spawns` entirely -
they're dig-only now - and the original three soils' passive weights are
restored to their pre-draft values (nothing else about passive foraging
changes in Phase 1 beyond what E12's base proposal already specified).

```json
{
	"version": 3,
	"gather_energy_cost": 2,
	"dig_energy_cost": 4,
	"max_digs_per_day": 8,
	"spawn_chance_per_tile_per_day": 0.03,
	"max_concurrent_spawns": 40,
	"spawns": {
		"rocky": [
			{ "item_id": "wild_herb", "weight": 50, "yield_min": 1, "yield_max": 2 },
			{ "item_id": "flint", "weight": 35, "yield_min": 1, "yield_max": 1 },
			{ "item_id": "wood", "weight": 15, "yield_min": 1, "yield_max": 1 }
		],
		"sandy": [
			{ "item_id": "wild_onion", "weight": 55, "yield_min": 1, "yield_max": 2 },
			{ "item_id": "wild_herb", "weight": 20, "yield_min": 1, "yield_max": 1 },
			{ "item_id": "wood", "weight": 20, "yield_min": 1, "yield_max": 1 },
			{ "item_id": "flint", "weight": 5, "yield_min": 1, "yield_max": 1 }
		],
		"loamy": [
			{ "item_id": "wild_berry", "weight": 40, "yield_min": 1, "yield_max": 3 },
			{ "item_id": "wild_herb", "weight": 25, "yield_min": 1, "yield_max": 1 },
			{ "item_id": "wood", "weight": 30, "yield_min": 1, "yield_max": 1 },
			{ "item_id": "flint", "weight": 5, "yield_min": 1, "yield_max": 1 }
		]
	},
	"dig_loot": {
		"rocky": [
			{ "item_id": "", "weight": 55, "yield_min": 0, "yield_max": 0 },
			{ "item_id": "flint", "weight": 25, "yield_min": 1, "yield_max": 1 },
			{ "item_id": "wild_turnip", "weight": 15, "yield_min": 1, "yield_max": 1 },
			{ "item_id": "morel", "weight": 3, "yield_min": 1, "yield_max": 1, "season": ["spring"], "is_rare": true },
			{ "item_id": "truffle", "weight": 2, "yield_min": 1, "yield_max": 1, "season": ["autumn"], "is_rare": true }
		],
		"sandy": [
			{ "item_id": "wild_carrot", "weight": 50, "yield_min": 1, "yield_max": 1 },
			{ "item_id": "", "weight": 30, "yield_min": 0, "yield_max": 0 },
			{ "item_id": "wild_turnip", "weight": 15, "yield_min": 1, "yield_max": 1 },
			{ "item_id": "morel", "weight": 3, "yield_min": 1, "yield_max": 1, "season": ["spring"], "is_rare": true },
			{ "item_id": "truffle", "weight": 2, "yield_min": 1, "yield_max": 1, "season": ["autumn"], "is_rare": true }
		],
		"loamy": [
			{ "item_id": "wild_turnip", "weight": 45, "yield_min": 1, "yield_max": 1 },
			{ "item_id": "", "weight": 30, "yield_min": 0, "yield_max": 0 },
			{ "item_id": "wild_carrot", "weight": 15, "yield_min": 1, "yield_max": 1 },
			{ "item_id": "morel", "weight": 7, "yield_min": 1, "yield_max": 1, "season": ["spring"], "is_rare": true },
			{ "item_id": "truffle", "weight": 3, "yield_min": 1, "yield_max": 1, "season": ["autumn"], "is_rare": true }
		]
	}
}
```

**Reading the table, per soil (in-season, so morel counted, truffle
excluded):** rocky - 55% nothing, 25% flint, 15% wild_turnip, 5% rare.
sandy - 65% a buried forageable (50 carrot + 15 turnip), 30% nothing, 5%
rare. loamy - 60% a buried forageable (45 turnip + 15 carrot), 30% nothing,
10% rare (loamy is the "best soil" already in every other system - richest
dig odds fits that established fiction). Forageables dominate the two
soils where root vegetables make fictional sense; rocky is the deliberate
poor-odds outlier, consistent with its existing harsh profile everywhere
else in the game. Rare weights (2-7 depending on soil) are pinned at or
below the passive spawn table's own morel/truffle weights from the prior
draft - digging doesn't make rares *more* likely per attempt, only
*repeatable* per attempt, which is why the caps below matter more than the
weights do.

**`item_id: ""` is the miss outcome** (`yield_min`/`yield_max: 0`) - not a
real item, just an explicit "nothing" entry so misses are data, not an
implicit fallback. The implementer checks for an empty `item_id` after the
weighted pick and grants nothing (still consuming the energy and the daily
attempt) rather than needing a dummy `items.json` row.

**Anti-exploitation design - four independent, stacking throttles**
(per your ask: a real bonus, not a grind path):
1. **Energy cost** (`dig_energy_cost: 4`, a real chunk of the 100 max) -
   the same baseline throttle every tool action already has.
2. **`max_digs_per_day: 8`** (new) - a hard cap, same pattern as
   `reputation_manager.gd`'s existing `DAILY_GIFT_CAP`. Without this, a
   player devoting an entire day's energy to digging could attempt ~25
   times; capped at 8 (32 energy), digging is a real daily activity, not an
   energy-dump strategy that crowds out farming/watering/foraging.
3. **A genuine miss chance** (25-55% depending on soil) - not every dig
   pays off, so the *expected* value of a dig session is well below "free
   items," which is what actually discourages using it as a primary income
   loop over normal farming.
4. **Season gating** on morel/truffle halves the calendar window each rare
   is obtainable at all (and truffle is fully unreachable this slice), on
   top of already-low weights.

No per-tile tracking, no cooldown, no new save field for "which tiles were
already dug" - digging doesn't consume or mark the tile (unlike gathering,
which clears `forage_item_id`), so there's no per-cell state to persist.
The only new persisted value is the daily counter itself (section 12).

**Design choice made (see section 9.3): option B, a dedicated `dig_loot`
table, not a gate on existing spawns.** This matches the base proposal's
own anti-bloat line for E12 ("Spade uses its own loot table, not hidden
visuals") more literally than the prior draft's option A did - flagged and
corrected here rather than left as shipped.

## 5. `recipes.json` (v1 -> v2)

```json
{
	"version": 2,
	"recipes": [
		{ "id": "dried_turnip", "station": "drying_shed", "inputs": { "turnip": 3 }, "output_item_id": "dried_turnip", "output_count": 1, "energy_cost": 3, "craft_days": 0, "skill_id": "farming", "skill_level_required": 1 },
		{ "id": "dried_barley", "station": "drying_shed", "inputs": { "barley": 3 }, "output_item_id": "dried_barley", "output_count": 1, "energy_cost": 3, "craft_days": 0, "skill_id": "farming", "skill_level_required": 1 },
		{ "id": "barley_ale", "station": "hearth", "inputs": { "barley": 4 }, "output_item_id": "barley_ale", "output_count": 1, "energy_cost": 4, "craft_days": 1, "skill_id": "farming", "skill_level_required": 2 },
		{ "id": "herb_stew", "station": "hearth", "inputs": { "wild_herb": 2, "turnip": 1 }, "output_item_id": "herb_stew", "output_count": 1, "energy_cost": 3, "craft_days": 0, "skill_id": "", "skill_level_required": 0 },
		{ "id": "berry_pie", "station": "hearth", "inputs": { "wild_berry": 3, "barley": 1 }, "output_item_id": "berry_pie", "output_count": 1, "energy_cost": 4, "craft_days": 0, "skill_id": "", "skill_level_required": 0 },
		{ "id": "carrot_stew", "station": "hearth", "inputs": { "carrot": 2, "barley": 1 }, "output_item_id": "carrot_stew", "output_count": 1, "energy_cost": 3, "craft_days": 0, "skill_id": "", "skill_level_required": 0 },
		{ "id": "pea_soup", "station": "hearth", "inputs": { "pea": 3 }, "output_item_id": "pea_soup", "output_count": 1, "energy_cost": 3, "craft_days": 0, "skill_id": "", "skill_level_required": 0 },
		{ "id": "leek_pie", "station": "hearth", "inputs": { "leek": 2, "barley": 1 }, "output_item_id": "leek_pie", "output_count": 1, "energy_cost": 4, "craft_days": 0, "skill_id": "farming", "skill_level_required": 1 },
		{ "id": "morel_stew", "station": "hearth", "inputs": { "morel": 1, "wild_herb": 1 }, "output_item_id": "morel_stew", "output_count": 1, "energy_cost": 3, "craft_days": 0, "skill_id": "farming", "skill_level_required": 1 },
		{ "id": "compost", "station": "drying_shed", "inputs": { "spoiled_crop": 2 }, "output_item_id": "compost", "output_count": 1, "energy_cost": 2, "craft_days": 0, "skill_id": "farming", "skill_level_required": 2 }
	]
}
```

Recipe compositions (which inputs, which station) are this draft's own
judgment call - neither the proposal nor R2a specified them beyond naming
the dishes. Kept `herb_stew`/`berry_pie`'s no-skill-gate pattern for the
two simplest new stews (`carrot_stew`, `pea_soup`); gated `leek_pie` and
`morel_stew` at farming level 1 since they're closer to `dried_turnip`'s
tier than the unlocked starter recipes.

## 6. `market.json` - not in the original file list, but required

New crops/goods are unsellable and unbuyable without these. No version
bump needed (content-only, no shape change).

**`buy_prices` additions:**
```json
"carrot": 8, "pea": 10, "onion": 12, "leek": 15,
"carrot_stew": 11, "pea_soup": 9, "leek_pie": 17, "morel_stew": 14,
"morel": 25, "truffle": 80
```
The four crop prices (8/10/12/15) are the proposal's own "Buy price"
column, carried over unchanged - checked against the shipped architecture
first (`market.json.buy_prices` is where crop sell price actually lives,
not `items.json.price`, which is 0 for every existing crop yield item) so
they land in the right file. `morel`/`truffle` likewise use the proposal's
stated 25/80. The four cooked-dish prices are this draft's judgment call,
following the existing `herb_stew`(7)/`berry_pie`(13) spread.

**`stall_inventory` additions** (unlimited stock, matching every existing
entry's `"stock": -1`):
```json
{ "item_id": "carrot_seed", "stock": -1 },
{ "item_id": "pea_seed", "stock": -1 },
{ "item_id": "onion_seed", "stock": -1 },
{ "item_id": "leek_seed", "stock": -1 },
{ "item_id": "spade", "stock": -1 }
```
(`morel`/`truffle`/`compost`/`spoiled_crop` are gathered or crafted, not
bought - no stall entry, same as `flint`/`wood` today.)

## 7. `villagers.json` - content-only, no version bump

Adding item ids to existing `likes`/`dislikes` arrays doesn't change the
file's shape (`CLAUDE.md` section 6.4 only requires a version bump on shape
changes), so this is a content edit, not a schema change. Per the base
proposal's per-crop notes:

| Villager | Change |
|---|---|
| Hilda (`villager_1`) | `likes` += `"carrot"` |
| Marta (`villager_3`) | `likes` += `"pea"` |
| Father Tomas (`priest`) | `dislikes` += `"onion"`; `likes` += `"morel"` |
| Steward Aldric (`steward`) | `likes` += `"leek"`; `likes` += `"truffle"` |

Steward liking `truffle` is data-complete but functionally inert this
slice (truffle is autumn-gated in `forage.json`) - included anyway so
nothing needs revisiting when Autumn unlocks, matching the season-aware-
from-the-start convention `CLAUDE.md` section 2 already commits to.

## 8. `GameData` INT_KEYS updates needed

| Constant | Addition |
|---|---|
| `CROP_INT_KEYS` | `"fertility_depletion"`, `"fertility_min"` |
| `SOIL_INT_KEYS` | `"fertility_init"`, `"high_fertility_quality_bonus"` |
| `ITEM_INT_KEYS` | `"fertilize_amount"` |
| `FORAGE_INT_KEYS` | `"dig_energy_cost"`, `"max_digs_per_day"` |

`FORAGE_SPAWN_ENTRY_INT_KEYS` needs **no addition** - `season` is a string
array and `is_rare` a bool; neither has JSON's float-vs-int ambiguity
(CLAUDE.md section 6.2), which only applies to numbers. The loader applies
the same `FORAGE_SPAWN_ENTRY_INT_KEYS` cast to `dig_loot`'s entries as it
already does to `spawns`' entries (`weight`/`yield_min`/`yield_max` are
identical fields in both tables) - one more iteration of the existing loop
in `game_data.gd`, not a new constant. `fertility_recovery_per_day` stays a
float and is deliberately absent from `SOIL_INT_KEYS`.

## 9. Judgment calls made in this draft (flagged, not hidden)

1. **New-crop `fertility_depletion` values** (carrot 8, onion 16, leek 12)
   - only `pea`'s -8 is sourced directly from R2a; the other three are this
   draft's estimate against the base proposal's stated 12-18 guardrail.
2. **New-crop `quality_weights`** - not specified anywhere upstream; chosen
   to echo the closest existing crop by growth profile (carrot ~ turnip,
   pea ~ barley, onion/leek ~ cabbage).
3. **Resolved 2026-08-07: option B.** Digging is a dedicated action with
   its own `dig_loot` table (section 4), not a tool-gate on the passive
   `spawns` table. Chosen for two reasons: it matches the base proposal's
   own anti-bloat line ("Spade uses its own loot table, not hidden
   visuals") more literally than the originally-drafted option A did, and
   it delivers what was actually asked for - mostly buried forageables,
   with rare finds as a genuine but well-throttled bonus, not a lockbox on
   an already-rare passive spawn. The throttle design (energy cost + a new
   daily cap + a real miss chance + season gating, all stacking) is this
   draft's own judgment call on how to keep it from being an exploitable
   income loop, since neither the proposal nor R2a specified an anti-grind
   rule at all.
4. **Rare-item gift bonus simplified to the existing flat model.** The
   proposal names "priest +15" (morel) and "steward +20" (truffle); the
   shipped gift system (`reputation_manager.gd`) only supports a flat
   +10/-6/+2 model keyed off binary `likes`/`dislikes` membership - no
   per-item bonus override exists. This draft puts morel/truffle in the
   ordinary `likes` arrays (flat +10), not a new bonus tier. Building a
   per-item override is a code change beyond a data schema, and is flagged
   here rather than assumed.
5. **Seed prices, recipe compositions, cooked-dish prices** - not specified
   upstream at all; chosen to sit inside the existing price/energy spreads.
   None of these are structural; retune freely without touching schema
   shape.

## 10. Integration points needed beyond this data draft (Phase 1 code, not yet written)

- `FarmGrid`: `fertility: float` per cell, initialised from
  `soil_types.fertility_init`; `plant()` checks `fertility_min`;
  `harvest()` subtracts `fertility_depletion` (clamped 0-100); `advance_day()`
  recovers fallow cells by `fertility_recovery_per_day`; `apply_compost(pos)`
  per the addendum; `fertility_changed(pos, new_value)` signal. New method
  `dig_cell(pos: Vector2i) -> Dictionary` - validates the cell is untilled,
  the player owns a `spade`, and `daily_dig_count < max_digs_per_day`;
  charges `dig_energy_cost`; weighted-picks from `dig_loot[soil]`, filtered
  first to entries with no `season` field or whose `season` array contains
  the current season (excludes truffle entirely this slice, excludes morel
  outside spring); grants the rolled item unless `item_id` is empty (a
  miss); increments
  `daily_dig_count`. No cell state changes - digging doesn't consume or
  mark the tile. `is_rare` results fire `EventBus.rare_item_gathered(item_id)`
  and set a persistent `player.event_flags` entry (e.g.
  `forage.gathered_morel`), same as any other rare find per E12's spec in
  the base proposal. `daily_dig_count` resets to 0 on `day_passed`,
  alongside whatever else `FarmGrid` already resets daily.
- ADR-018's rot branch (`farm_grid.gd:223-232`) spawns `spoiled_crop` on
  rot, per the addendum's resolved decision.
- `ToolManager` (or wherever tool-use-on-cell already resolves): new
  `spade` tool_category branch that calls `FarmGrid.dig_cell()`; new
  compost-application branch.
- ADR-018 gets a superseding note in `design/decisions.md` once the rot
  behavior change actually lands (not before - it's still just written
  down as intent right now).

## 11. Test plan - cross-reference, nothing new to design here

Already specified: `test_crop_pack` (base proposal section 5, E1),
`test_soil_fertility` (base proposal section 5, E2-trim, extended per the
addendum's section 7 for compost), `test_foraging_expansion` (base
proposal section 5, E12). This draft doesn't add new test scope, only the
concrete data those suites assert against.

## 12. Save impact - one addition beyond what was already planned

`farm.cells[].fertility` (base proposal's v14 spec, defaulting to 100 on
existing saves, soil defaults for new grids) is unchanged. Compost,
spoiled_crop, spade, and all new crop/forage items are ordinary inventory
items - covered by existing `player.inventory` serialization, no migration
rung needed for any of them.

**New field required by the dig mechanic's daily cap:** `farm.daily_dig_count`
(int, default `0`), same shape as `reputation.daily_gift_count` already has
today. Needed because `max_digs_per_day` has to survive a save/load within
the same in-game day (sleeping before hitting the cap and reloading
shouldn't reset it) - add it to the consolidated v14 migration table
alongside `fertility`, `event_flags`, `dialogue_history`, and
`board_orders`. This is the one place this draft's design diverges from
"no new save fields beyond fertility," flagged here rather than left
implicit.

---

*End of draft. No code or `data/*.json` file was modified in producing it.
Ready for owner review; sections 9 and 10 are the parts most likely to want
a second opinion before implementation starts.*
