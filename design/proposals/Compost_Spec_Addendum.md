# Addendum: Compost Bin — pulled from R2a for the amended Spring package

**Status:** Draft for owner review. Extracted, not authored - the mechanics
below are DeepSeek V4 Pro's R2a deep design (`.deepseek/outputs/
proposal_r2a_out.md`, "E2 - Soil Fertility & Rotation", lines 414-613),
reconciled against the final curated proposal's corrections and against the
actual shipped code. No code was written to produce this document.

**Why this file exists:** `Proposal_Spring_Feature_Expansion.md` trimmed the
compost bin out of E2 ("Compost is deferred"), so the shipped proposal's
data schema and migration spec (sections 5 and 10) don't cover it. The
2026-08-07 decision note in `design/decisions.md` restored compost against
Pro's recommendation, which means Phase 1 needs the design R2a already did
but the curated proposal cut - this pulls it back out and corrects it
against what's actually in the repo today.

**Authority:** a design note under `design/`, below `CLAUDE.md` and
`design/decisions.md`. Nothing here is approved by being written down.

---

## 1. Design intent (unchanged from R2a)

Compost is the recovery half of E2's fertility system: fallow recovers
fertility passively and slowly, compost recovers it in a lump sum at the
cost of crafting time and a station trip. It gives spoilage - previously a
pure loss - a productive use, and gives the farming skill (crafting at a
station) a reason to interact with soil stewardship.

## 2. Mechanics spec (from R2a, unchanged)

- **Compost** is a new item. Applying one unit to a **tilled** cell adds a
  flat `+20` fertility (capped at 100). Application is a tool-action ("use
  compost on cell"); applying to an untilled cell is blocked.
- **Crafted** from `2 × spoiled_crop -> 1 × compost` at the Drying Shed
  (existing station, no new building).
- Cover crops (negative `fertility_depletion`, e.g. peas/beans) restore
  fertility on harvest directly - compost and cover-cropping are separate,
  stacking recovery paths.
- Skills hook (E3, deferred): farming perks could later reduce depletion,
  boost fallow recovery, or increase compost yield - not built now, just
  noted as a non-conflicting future hook.

## 3. Data schema - corrected against the live repo

R2a's original schema targeted `items.json v6->v7` and a **new**
`crafting.json`. Neither matches the repo as it stands (checked
2026-08-07): `items.json` is already **v7** (the compost package bumps it to
**v8**, same file the base E1/E12 changes already touch) and there is no
`crafting.json` - recipes live in **`recipes.json` (currently v1)**, per the
final proposal's own section 14 correction. The schema below reflects that.

#### `items.json` (v7 -> v8, additive with E1/E12's other new items)

```json
{ "id": "compost", "type": "material", "name": "Compost", "price": 0, "stackable": true, "fertilize_amount": 20 },
{ "id": "spoiled_crop", "type": "food", "name": "Spoiled Crop", "price": 0, "stackable": true, "energy_base": 1 }
```

**Correction (2026-08-07, checked against the live schema):** R2a's sketch
used `"sellable": false` and a nested `"effect": { "fertilize": 20 }`.
Neither matches how `items.json` actually works: there is no `sellable`
field anywhere in the file or its loader - sellability is determined purely
by whether an item id is a key in `market.json`'s `buy_prices` (see
`game_data.gd`'s `get_market_buy_prices()`); an item simply absent from
`buy_prices` can't be sold, no flag needed. And every existing item uses
flat top-level fields (`price`, `energy_cost`, `capacity`, ...), never a
nested `effect` object - so compost's fertilizing amount is a flat
`fertilize_amount` field instead, consistent with the rest of the file and
addable to `ITEM_INT_KEYS` the same way every other int field is.
`spoiled_crop` is typed `food` with a token `energy_base: 1` rather than
inventing an `edible` flag that doesn't exist elsewhere either - matches
R2a's aside that it's technically edible but not worth eating, using fields
the schema already has.

#### `recipes.json` (v1 -> v2, shared bump with E1's carrot_stew/pea_soup/leek_pie)

```json
{ "id": "compost", "station": "drying_shed", "inputs": { "spoiled_crop": 2 }, "output_item_id": "compost", "output_count": 1, "energy_cost": 2, "craft_days": 0, "skill_id": "farming", "skill_level_required": 2 }
```

Field names matched to the shipped `recipes.json` shape (`output_item_id`,
`output_count`, `energy_cost`, `craft_days`, `skill_id`,
`skill_level_required`) rather than R2a's own `output`/`inputs`-only sketch,
which predates the file existing.

**No change needed to `crops.json` or `soil_types.json` beyond what the base
fertility package (proposal section 5, E2-trim) already specifies** -
compost only adds items and a recipe.

## 4. Integration points

| Script / Autoload | What changes |
|---|---|
| `FarmGrid` | New method `apply_compost(pos: Vector2i) -> bool` - validates tilled, adds 20 fertility clamped to 100, consumes one `compost` from inventory (via `PlayerState`), emits the same `fertility_changed(pos, new_value)` signal the base fertility work already adds. Blocks with a message on an untilled cell. |
| `GameData` | Loads the two new `items.json` entries and the new `recipes.json` entry - no new loader, same boundary the base package's E1 items already go through. |
| Recipe/crafting UI | Compost recipe appears at the Drying Shed panel alongside `dried_turnip`/`dried_barley` - no new UI surface, existing recipe list. |
| `PlayerState` | Tracks `compost`/`spoiled_crop` as ordinary inventory items - no new state. |
| `ToolManager` (or wherever "use item on cell" already resolves) | New use-action target: compost applied to a farm cell. Check `tool_manager.gd` for the existing pattern before adding a new one. |

**Untouched:** `TimeManager`, `WeatherManager`, reputation, combat, the
ADR-032 projection seam.

## 5. Balance guardrails (unchanged from R2a)

| Parameter | Value | Rationale |
|---|---|---|
| Compost restore | +20 fertility | Equivalent to ~10-15 fallow days; a real opportunity-cost choice against just waiting. |
| Compost recipe cost | 2 spoiled_crop, 2 energy, farming skill 2 | Gates it slightly above the base crafting tier (dried goods are skill 1). |

## 6. Save impact - corrected, smaller than R2a assumed

R2a's own save section conflated fields from multiple systems (including
E3's `player.perks`, which is deferred and out of scope here) and implied
compost needed its own save block. It doesn't: **compost and spoiled_crop
are ordinary inventory items**, already covered by the existing
`player.inventory` serialization (CLAUDE.md section 7). The only save
surface this addendum touches is nothing beyond what the base E2 fertility
work already adds (`farm.cells[].fertility`, part of the shared v14
migration). **No new field, no new migration rung, beyond the base
package's.** This corrects the 2026-08-07 decision note's assumption that
compost needed additional v14 migration fields - it doesn't; only the
supply-pressure curve (E6) does.

## 7. Test plan

Extends the base package's `test_soil_fertility` suite rather than needing
its own file:
1. Applying compost to a tilled cell adds +20 fertility, clamped at 100.
2. Applying compost to an untilled cell is blocked with the expected error.
3. Applying compost with zero `compost` in inventory fails cleanly.
4. Crafting `compost` from 2 `spoiled_crop` at the Drying Shed succeeds and
   consumes the inputs (extends the existing recipe-crafting test pattern
   used for `dried_turnip` etc. in `test_crafting` or equivalent).
5. Round-trips through save/load with compost/spoiled_crop sitting in
   inventory (covered by the existing generic inventory save test - no new
   assertion needed if that coverage already exists).

## 8. Implementation gap found in the live code - needs a decision before Phase 1

R2a's design assumes spoiled crops already exist as an inventory item
("already in data? If not, add `spoiled_crop` item"). **They don't, and the
gap is deeper than a missing item.** Checked against
`scripts/world/farm_grid.gd:223-232` (the shipped ADR-018 two-stage rot):
when an unharvested crop sits past `2 * spoil_after_days`, the cell is
simply cleared (`crop_id = ""`, `growth_progress = 0.0`) and a
`crop_spoiled` signal fires - **no item is produced, nothing goes into
inventory.** There is also no inventory-level decay anywhere in the
codebase; once a crop is harvested it never spoils. `crops.json`'s
`spoil_after_days` is exclusively a field mechanic today.

This means compost's stated input (`spoiled_crop`) currently has **no
production source**. Two ways to close the gap, neither of which R2a
considered because it assumed the item already existed:

- **(a) Change ADR-018's field-spoilage to produce an item.** When a crop
  rots past `2 * spoil_after_days`, spawn one `spoiled_crop` into the
  player's inventory (or drop it on the tile for pickup) instead of just
  clearing the cell. Real behavior change to a shipped, tested mechanic -
  `farm_grid.gd`'s existing spoilage tests need updating, and the fiction
  changes slightly (rot becomes a recoverable resource, not pure loss).
- **(b) Pick a different compost input that already exists** - e.g. a flat
  "sacrifice N harvested crops of any type" recipe, or route it through
  foraged material instead of introducing dependency on changing spoilage
  behavior at all.

**Decided (2026-08-07, owner ruling): option (a).** ADR-018's field-spoilage
gets a behavior change as part of Phase 1: past `2 * spoil_after_days`, the
cell spawns one `spoiled_crop` (into inventory, or dropped on the tile for
pickup - an implementation detail for whoever builds this, not decided
here) instead of just clearing with nothing produced. This is a real change
to a shipped, tested ADR-018 mechanic, not purely additive - scope it into
Phase 1 alongside the rest of compost:

- `farm_grid.gd`'s rot branch (`scripts/world/farm_grid.gd:223-232`) gains
  the item-spawn; `crop_spoiled` signal payload may need to carry the
  spawned item for UI/pickup wiring, or the spawn can happen directly on
  `PlayerState.inventory` - implementer's call.
- Existing spoilage coverage (wherever ADR-018's two-stage rot is tested
  today) needs a new assertion that a `spoiled_crop` appears, in addition to
  whatever it already asserts about the cell clearing.
- Fiction note for content writers: rot is no longer pure loss - "even your
  mistakes feed the land" is now literally true, worth a dialogue/tooltip
  beat if C1-C6 wants one, not required.

No ADR supersession recorded yet - ADR-018 stays as written in
`design/decisions.md` until Phase 1 actually implements this change, at
which point the implementation commit should append a short superseding
note there (per the append-only convention: never edit ADR-018's closed
record, add a new one).

## 9. ADR/contract note

R2a's own draft asked for a standalone "ADR-035: Soil Fertility &
Rotation." That number is now taken - the accepted proposal's section 9
reserves **ADR-035 for the dialogue condition evaluator**. Compost doesn't
need a separate ADR of its own: it folds into the general Spring package's
contract amendment to `CLAUDE.md` section 2's in-scope list (adding soil
fertility, described in the base proposal) alongside the rest of E2 - no
new record needed beyond that amendment, once it's written.

## 10. Anti-bloat check (unchanged from R2a)

- **Never become:** a fertilizer-type system (multiple fertilizer items
  with different effects), a compost-quality tier, or a timed
  compost-maturation mechanic. One item, one flat effect, one recipe.
- **First cut under scope pressure:** since compost was already the first
  thing trimmed once, if Phase 1 runs long, re-defer it rather than
  reworking it - the base fertility system (depletion, fallow recovery,
  planting block) delivers the core "farming becomes a stewardship puzzle"
  goal on its own.

## 11. Open questions from R2a - status

1. *Should fertility affect quality directly?* - answered by the base
   proposal already (§5 E2-trim: `high_fertility_quality_bonus` at
   fertility >= 60). Not compost-specific; no action needed here.
2. *Should livestock manure be a later compost variant?* - still open,
   correctly deferred behind E7 (livestock expansion), which is itself
   deferred behind its own ADR-028 amendment per the 2026-08-07 decision
   note. No action needed now.
3. *Exact vs. tinted fertility display* - a Phase-1 UI/UX call, not
   compost-specific; carried into the base E2 implementation, not this
   addendum.
4. *Does fertility decay while a crop is growing?* - R2a recommends no
   (depletion only at harvest). Matches the base proposal. Not
   compost-specific.

---

*End of addendum. No code was modified in producing it. Item 8's spoilage-
source gap is decided (option a); the whole addendum is implementation-
ready for Phase 1.*
