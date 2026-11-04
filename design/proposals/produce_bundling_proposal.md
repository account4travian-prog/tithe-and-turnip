# Produce Bundling - Design Proposal (not an ADR)

**Status:** proposal for human review, intended to become an ADR later.
**Date:** 2026-08-07. **No code, item entry, or recipe was written for this.**

## Why this exists

Playtest feedback asked: *"I am also wondering if produce bundling should be
a thing (that may sometimes require other equipment like rope, or sacks, or
other containers)."*

The codebase has no container or bundle concept today, confirmed against the
three places such a thing would have to live:

- `data/items.json` v8 - every item is a flat `id/type/name/price` entry with
  stackable flags; nothing is a container and nothing bundles another item.
- `data/recipes.json` v2 - all eleven recipes turn raw goods into food,
  preserve, or compost; none consume rope, sack, or any container input.
- `scripts/autoloads/player_state.gd` - inventory is a flat
  `item_id -> {quality: count}` map with no nesting, no container slots, and
  no bundle shape. Saves carry a `farm.storage` list, and
  `storage_chest.capacity` (50) exists in `buildings.json`, but
  `BuildingManager.get_storage_capacity_bonus()` has no consumer - storage
  capacity is defined but not yet enforced.

So bundling is net-new across `GameData` loaders, the item schema, inventory
handling, `TitheManager` (market, board, and tithe paths), possibly the
crafting path, and the save format. That is too large to ride along with a
display-name fix; this proposal scopes the decision space.

## Concept

Container items - basket, sack, bag, satchel, and rope/twine - are bought at
the market stall or made at the Drying Shed. At a storage point, N units of
one raw crop bundle into a single bundle item: e.g. a "Sack of Turnips"
holding 10 turnips. The bundle has its own id, display name, and price; the
raw crop stays unchanged. Period diction (world_bible Section IX) favours
Satchel over "backpack" and keeps the words plain: basket, sack, bag, hand,
sheaf already fit the game's register.

## Where bundles would plug into existing systems

- **Market sell rows.** The stall sells raw counts today and `TitheManager`
  prices them by assize x quality x supply pressure. Bundles need either an
  un-bundle step at the stall or a per-bundle sell price, and a decision
  about whether selling a bundle adds that crop's supply pressure or a
  separate bundle pressure.
- **Board orders.** Orders currently request raw counts, displayed as
  "Deliver 4 bushels of peas" after this task's naming fix. The cleanest
  shape is to keep orders raw-only: it preserves the uniform 1.7x-2.0x
  reward band (Part A ruling) and leaves order templates untouched. If a
  later pass wants bundle requests, templates need a bundle flag, a new
  fulfillment path, and the naming helper would format bundle-item names
  rather than crop measures - a deliberate change to Part B, not an accident.
- **Tithe deposits.** In-kind payments value raw crops by market value x
  quality. Accepting bundles requires a conversion rule (or an un-bundle at
  the assessment roll) so the tithe's value math never double-counts the
  container.
- **Storage capacity.** A bundle-as-one-item is the natural unit for the
  dormant `storage_chest.capacity` field. Bundling could ship as pure
  inventory compression first and capacity enforcement can wait, or the two
  land together.

## Open questions a human must decide

1. **Which containers?** Basket, sack, bag, satchel, rope - all, or a
   starter subset? Bought at market, made at the Drying Shed, or both, and
   at what cost?
2. **Per-crop bundle sizes.** Data-driven `bundle_size` per crop (5, 10, 20)
   fits the project's JSON-tunable rule, but the values need a balance pass.
3. **Consumed or returned?** One-way bundling (container consumed, simplest
   inventory shape) vs returned/reusable containers (container persists,
   inventory needs an owned-containers shape).
4. **Quality.** Do bundles carry the crop's quality tier through, or do they
   collapse to common? The current quality-keyed stacks can hold a bundle
   item's tiers, but the sell/tithe math changes either way.
5. **Spring slice or later?** Recommendation: defer explicitly to a future
   season pass (autumn storage/preservation is the natural home). The
   playtest complaint this task fixes is display-only; bundling is an
   economy feature that needs a save-version bump and tuning it does not
   deserve as a side effect.

**Recommended scope for a future ADR:** containers as market goods, one-way
consumption, per-crop data-driven sizes, quality collapsed or carried as the
owner decides, board orders stay raw, and no capacity enforcement until
storage itself is built.
