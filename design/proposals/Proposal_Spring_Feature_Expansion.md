# Proposal: Spring Feature Expansion Plan - Tithe & Turnip

**Status:** Draft for owner review. Design only - no code was written to
produce this document.
**Date:** 2026-08-06
**Produced by:** DeepSeek V4 Pro (planning/reasoning, maximum effort, seven
calls across four rounds) with the Codex orchestrator (evidence gathering,
critical review, corrections, compilation).
**Authority:** this is a design note under `design/`, below `CLAUDE.md`
(contract v0.12) and `design/decisions.md` (34 ADRs). Nothing here is
approved merely by being written down. Every implementation item carries its
ADR/contract implications in section 9.

---

## 0. How this proposal was produced

Four rounds of a Pro/orchestrator design session, all Pro calls at maximum
reasoning effort with the project harness attached:

| Round | Task | Output |
|---|---|---|
| R1 | Bare-bones audit + 18-candidate expansion menu | `proposal_r1_out.md` (25.9k chars) |
| R2a | Deep design: E2, E3, E4, E6 (truncated mid-E4, then continued) | `proposal_r2a_out.md` + `proposal_r2a_cont_out.md` |
| R2b | Deep design: E5, E7, E12, E1 + integration note | `proposal_r2b_out.md` (38.9k chars) |
| R3a | Adversarial review: keep/trim/cut verdicts | `proposal_r3a_out.md` |
| R3b | Delivery plan, ADRs, migration, risks, gates | `proposal_r3b_out.md` |

All task files live in `.deepseek/tasks/proposal_r*.md`; all outputs and
receipts live in `.deepseek/outputs/proposal_r*.md`. The orchestrator
verified Pro's file references against the repo and applied the corrections
listed in section 14. Raw round outputs are the appendices to this
document; this file is the curated, corrected, decision-ready plan.

## 1. Executive summary

The shipped Spring slice is a skeleton: every system exists, none of them
have enough to do. The expansion package recommended here keeps the slice
small but makes the daily loop varied and the season worth replaying:

**In-slice package (5 items):**

1. **E1 - Spring Crop Pack** (S) - four new Spring crops (carrot, pea,
   onion, leek) with distinct growth/moisture/yield profiles, feeding
   recipes, requests, board orders, and gift likes.
2. **E2-trim - Soil Fertility** (S-M) - per-cell fertility that depletes
   with crops, recovers with fallow and peas, and gates planting; yields
   and quality respond to land care. Compost is deferred.
3. **E4+E5 - Dialogue Engine 2.0 + Festivals** (M, one merged workstream) -
   the condition-driven dialogue engine (fixing the lines[0] dead-content
   bug and adding time/weather/season/event/trait conditions) plus the
   ADR-030 Spring festival as its first showcase.
4. **E6-trim - Market Board Orders** (S) - 1-3 deadline contracts per
   market day for in-season goods; price locked at market open. The supply-
   pressure curve is deferred.
5. **E12 - Foraging 2.0** (S-M) - seasonal spawn tables, rare finds
   (morels), and a spade tool for root digging, with event hooks dialogue
   can react to.

**Deferred (with reasons):** E3 Skill Perks & Active Abilities (a 28-day
slice cannot pay them off), E7 Livestock Expansion (exceeds ADR-028's
letter; needs an amendment; the base loop is already functional), E2's
compost bin (spoilage volume does not justify the UI), E6's supply-pressure
system (board orders deliver 80% of the fun at a fraction of the code).

**One save bump:** a single consolidated SAVE_VERSION 13 -> 14 migration.

**Bottom line (Pro's summary verdict):** the five-item package, delivered in
three engineering phases alongside ADR-032 Phase 1 and content passes
C1-C6, transforms the Spring slice from a narrow crop-and-tithe treadmill
into a varied, reactive farming life - without breaking the project's scope
discipline.

## 2. Context and constraints

The plan operates under the binding contract pins (CLAUDE.md v0.12): Godot
4.7.1 standard build, GDScript only, geometric primitives only (no art,
audio, shaders), no elevation, no third-party addons, data-driven tunables,
hand-rolled headless tests (33 suites, 717/717 checks green), save version
13, 60 Hz tick, `_process` presentation-only, input through InputManager
only. ADR-032 (dimetric, presentation-only, save must stay 13 until an ADR
says otherwise) has Phase 0 complete; Phase 1 (WS-A..D) is pending and runs
alongside this package with zero hard conflicts. ADR-033's cast amendment
(X10) is owed but not landed - nothing here depends on new named NPCs.
ADR-034 (multi-zone region) is accepted in principle and deferred - nothing
here requires multiple maps. ADR-030 (festivals) and ADR-031 (marriage) are
in scope; festivals are implemented by E5, marriage remains a separate
future pass.

## 3. Bare-bones audit (what the player actually has)

| System | What exists | The fun gap |
|---|---|---|
| Farming | 3 crops (2 Spring-plantable), 3 soils, moisture, quality tiers, 2 tool tiers, spoilage | Planting is decided once per soil type and forgotten; the loop is water -> harvest -> sell |
| Economy | Market (8 days, 5% toll, 15 stall items), tithe, church, court, corvee, black market | Obligations are numeric quotas; no speculative selling, no hard choices |
| Skills | 4 skills, 6 levels, passive stat effects | "Numbers go up" with no visible unlock or player agency |
| Foraging | Soil-keyed random spawns, 3% per tile/day | A chore with no discovery, no rare finds |
| NPCs | 6 villagers, schedules, gifting, 6 request templates, 36 dialogue lines | Dialogue is 1 line per reputation band; villagers are vending machines |
| Combat/raids | 6 weapons, 4 enemies, scripted + dynamic raids, deterrence, thief investigation | Attack-in-range only; raids are a punishment, not a challenge |
| Crafting/buildings/livestock | 5 recipes, 7 buildings, chicken + goat | Recipes are conversions, animals are item factories |
| Weather/time | Seasonal rolls, rain auto-water | A passive humidity knob; nothing reacts to it |

## 4. The expansion menu (all 18 candidates from R1)

| ID | Candidate | Scope | Prio |
|---|---|---|---|
| E1 | Spring Crop Pack | S | 5 |
| E2 | Soil Fertility & Rotation | M | 5 |
| E3 | Skill Perks & Active Abilities | L | 5 |
| E4 | Dialogue Engine 2.0 | M | 4 |
| E5 | Festivals (ADR-030) | M | 4 |
| E6 | Dynamic Market & Supply/Demand | M | 4 |
| E7 | Livestock Expansion | M | 4 |
| E8 | Relationship (heart) events | L | 3 |
| E9 | Tool & Weapon Crafting | M | 3 |
| E10 | Tithe & obligation dynamics | M | 3 |
| E11 | Advanced raid & defense | M | 2 |
| E12 | Foraging 2.0 | S-M | 4 |
| E13 | Herbalism & medicine | S-M | 3 |
| E14 | Community quests & requests overhaul | M | 3 |
| E15 | Farm construction & customization | M | 2 |
| E16 | Weather impact & forecasting | M | 2 |
| E17 | Fishing minigame | M | 2 |
| E18 | Player morale/rumination | S-M | 3 |

Full pitch/fun/systems/dependencies per candidate are in R1's output.
E8-E18 are not in this package: they are either dependents of E4 (E8, E10,
E14), pre-Phase-1 visual work (E15), tone-sensitive (E16, E18), or breadth
over depth (E17, E9, E11, E13). They remain available for a post-slice pass.

## 5. The recommended package (deep designs)

Each item carries the ten-section spec from the round outputs; the sections
below are the curated essentials. Full fidelity (including worked JSON
examples and complete test lists) is in the round output files.

### E1 - Spring Crop Pack (S, data-only)

**Intent:** four Spring-plantable crops that make "what do I grow today?" a
real choice with different profit/risk profiles.

| Crop | Days | Moisture | Yield | Seed recov. | Spoil | Buy price | Notes |
|---|---|---|---|---|---|---|---|
| carrot | 2 | 30-70 | 1-2 | 1-2 | 5 | 8 | fast cash; Hilda likes |
| pea | 3 | 40-80 | 1-3 | 1-2 | 3 | 10 | nitrogen fixer: **+fertility on harvest** (E2); Marta likes |
| onion | 4 | 20-50 | 1-4 | 0-2 | 7 | 12 | slow, high yield, low seed recovery; priest dislikes |
| leek | 4 | 50-90 | 1-2 | 1-3 | 5 | 15 | moisture-hungry; steward likes |

**Schema:** crops.json v3->v4 (new entries, `seasons: ["spring"]`);
items.json v7->v8 (new harvest items + market prices); recipes.json v1->v2
(carrot_stew, pea_soup, leek_pie at hearth); request templates and E6 board
orders pick the new crops up automatically via GameData. No save impact.
**Tests:** `test_crop_pack` - each crop plantable/harvestable in season,
quality roll, seed recovery, gift-like wiring.

### E2-trim - Soil Fertility (S-M)

**Intent:** farming becomes a season-spanning stewardship puzzle - rotate,
rest, and take care of the land, and the land takes care of you. Serves
both Survive and Thrive.

**Mechanics:** every cell gains `fertility: float` 0-100, initialised from
soil_types (loamy 70 / sandy 50 / rocky 30). Harvest subtracts the crop's
`fertility_depletion` (negative = restoration, e.g. peas). Fallow (tilled,
unplanted) recovers at `soil.fertility_recovery_per_day` on `advance_day`.
Planting is blocked below the crop's `fertility_min` with a clear message
("Soil too poor for <crop>"). Fertility >= 60 adds a per-soil
`high_fertility_quality_bonus`, making quality-chasing a long-term goal.
Moisture stays an independent axis. **Trim from R2a:** the compost bin,
compost item, and spoiled-crop crafting are deferred - recovery comes only
from fallow and peas in the slice.

**Schema:** crops.json v3->v4 adds `fertility_depletion` (int) and
`fertility_min` (int, default 0); soil_types.json v2->v3 adds
`fertility_recovery_per_day` (float) and `high_fertility_quality_bonus`
(int). INT_KEYS updated at the GameData boundary.
**Save:** `farm.cells[].fertility`, default 100 on migration for existing
grids (new grids use soil defaults). Part of the consolidated v14.
**Tests:** `test_soil_fertility` - depletion per crop, fallow recovery,
pea restoration, exhaustion blocks planting, quality bonus at high
fertility, save round-trip.
**Anti-bloat:** no per-cell simulation beyond one float; fertility is the
only new axis. First cut under scope pressure: the high-fertility quality
bonus.

### E4+E5 - Dialogue Engine 2.0 + Festivals (M, one workstream)

**Intent:** the village reacts to the world. The steward remarks on
yesterday's harvest, villagers comment on the weather, the festival is the
season's positive beat. This is the social foundation every future content
pass (C2-C6, marriage, heart events) builds on, and it fixes a real bug:
`GameData.get_dialogue_for()` returns all matching lines but the caller
reads `lines[0]`, so extra dialogue can never display.

**Mechanics (E4):**
- A stateless `ConditionEvaluator` + a new `DialogueManager` autoload that
  selects lines by priority (int, default 0), random among ties, with a
  deliberate per-NPC conditionless fallback (priority -999) and
  `frequency`: always / once_per_conversation / once_per_day.
- Condition vocabulary: `time` {min,max}, `season`, `weather`,
  `is_market_day`, `is_festival`, `is_mass_day`, `has_item` {id,min},
  `skill_level` {id,min}, `player_money`/`energy`/`health` {min},
  `standing` {axis,min}, `opinion` {npc,min}, `event_flag` (namespaced
  dot-notation, e.g. `market.sold_crops`), `not`. AND-only semantics; OR is
  two line entries. No scripting, ever.
- Backward compatible: existing 36 lines (dialogue.json v3) keep working
  with missing fields defaulted.
- The caller change is confined to DialoguePanel/DialogueManager - main.gd
  (frozen until Phase 1) needs zero edits.

**Mechanics (E5, within ADR-030's boundary - no mini-games, no exclusive
items):** a `FestivalManager` autoload listens to TimeManager
`hour_passed`/`day_passed`; on festival day/hour it activates the festival,
overrides NPC schedule anchors to the festival tile, and grants standing on
attendance (once per festival). No penalty for absence. Spring festival:
"Springturn Blessing", **day 18, hours 10-14, at the chapel tile (10,15)** -
clear of market days (3/7/10/14/17/21/24/28), mass day 21, and the scripted
day-15 raid. +10 village / +8 church standing.

**Schema:** dialogue.json v3->v4 (`priority`, `frequency`, `set_flag`,
new condition shapes, validation of unknown keys at load); new
festivals.json v1 with all four seasons defined (midsummer_fair,
harvest_home, winter_feast) and Spring reachable.
**Save:** `player.event_flags: Array[String] = []` and
`player.dialogue_history: Dictionary = {}` (npc -> line ids for frequency
tracking). Part of consolidated v14.
**Tests:** `test_dialogue_engine` (each condition type, priority ordering,
fallback, backward compat, lines[0] fix), `test_festivals` (trigger on day
18 hour 10, NPC gathering, standing +10/+8, absence penalty-free, save
round-trip of attendance flag).
**Anti-bloat:** the evaluator is a flat AND filter with a closed key
vocabulary validated at load; nothing nested, no expression language. If
scope pressure hits, cut festival content first - the engine itself stays.

### E6-trim - Market Board Orders (S)

**Intent:** the market gains direction. Board orders give the player
concrete, timed goals ("deliver 3 carrots by day 12") at premium prices,
making sales tactical without a hidden economy simulation.

**Mechanics (trim from R2a):** a `BoardManager` (new autoload, or a module
inside TitheManager) refreshes 1-3 orders on each market day from
`board_orders.json` templates, restricted to in-season goods, each with
quantity, deadline, reward coin + optional standing. Fulfillment deducts
inventory at the board interactable; unfulfilled orders expire silently.
Price is locked at market open (prevents incremental-selling exploits).
Black market keeps its fixed premium and detection roll - it stays
attractive when the market is glutted. **Deferred:** the supply-pressure
curve (0.5x-1.5x band, decay) - the single most over-engineered element of
the original R2a design.

**Schema:** new board_orders.json v1 (templates: crop_id, min/max quantity,
reward money/standing, deadline_days, weight); market tunables stay in
market.json. No crop/item schema change.
**Save:** `board_orders: Array[Dictionary] = []` on the tithe/market block
(TitheManager owns the market). Part of consolidated v14.
**Tests:** `test_board_orders` - orders spawn on market days, in-season
only, fulfillment reward + removal, expiry, price frozen at open.
**Anti-bloat:** no order-book, no matching, no NPC inventories, no global
supply. Orders are fetch quests with deadlines.

### E12 - Foraging 2.0 (S-M)

**Intent:** the daily foraging walk becomes a treasure hunt - seasonal
variety, rare finds, and a reason to own a spade.

**Mechanics:** forage.json v3 entries gain `season` (optional; omitted =
all seasons) and `requires_tool` (`spade` for buried roots). Rare finds:
morel (spring, 25c, priest +15 gift, morel_stew recipe) and truffle
(autumn, 80c, steward +20 - data only in the Spring slice). A spade tool
(20c at market) digs on untilled tiles for a hidden loot table at 4 energy
per dig. Gathered rares emit `EventBus.rare_item_gathered(item_id)` and set
a persistent player event flag (e.g. `forage.gathered_morel`) that E4
dialogue conditions can read.

**Schema:** forage.json v2->v3 (season, tool, sell_price, is_rare,
gift_bonus per entry); items.json v7->v8 (spade, morel, truffle, wild
carrot, wild turnip); recipes.json v1->v2 (morel_stew).
**Save:** only `player.event_flags` (shared with E4). Part of v14.
**Tests:** `test_foraging_expansion` - seasonal filter, rare spawn signal,
flag set on gather, spade dig + energy cost + miss chance, market
registration, save round-trip.
**Anti-bloat:** three touch points only (data keys, one tool interaction,
one signal). No new buildings, no mini-game. Spade uses its own loot table,
not hidden visuals (rendering cost).

## 6. Deferred items (with reasons and "when")

| Item | Why deferred | When |
|---|---|---|
| E3 Skill Perks & Active Abilities | A perk tree pays off over seasons, not 28 days; existing passive level effects already carry progression | Post-slice (Summer), with its own ADR (perk trees/abilities exceed ADR-021) |
| E7 Livestock Expansion | Breeding/health/cheese/feathers exceed ADR-028's letter; needs an amendment and real balance work; base chicken+goat loop already works | Post-slice, behind a dedicated ADR-028 amendment |
| E2 compost bin + spoiled_crop crafting | Spoilage volume in Spring doesn't justify the UI and item plumbing | Post-slice |
| E6 supply-pressure curve | 80% of the dynamic-market fun comes from board orders at 20% of the code | Post-slice, or never if board orders carry the fantasy |

## 7. Delivery plan

Three engineering phases (content authoring runs alongside from phase 2),
all interleaved with ADR-032 Phase 1 workstreams:

**Phase 1 - Simulation core (E1, E2, E12).** Data: crops.json v4,
items.json v8, forage.json v3, recipes.json v2, soil_types.json v3. No new
autoloads; extend FarmGrid + forage logic. New suites: `test_crop_pack`,
`test_soil_fertility`, `test_foraging_expansion`. Gate: full suite green
(expect 750+ checks) + manual playtest of a full crop cycle, fertility
feedback, spade dig, and a morel find.

**Phase 2 - Dialogue engine (E4).** New: `ConditionEvaluator`,
`DialogueManager` autoload (one-time human registration - DESKTOP step),
dialogue.json v4, lines[0] fix. New suites: `test_dialogue_engine` +
condition-evaluator unit tests. Gate: full suite green (770+ checks) +
manual playtest of condition-branched dialogue with the existing 36 lines
regression-tested.

**Phase 3 - Content & economy (E5, E6).** New: `FestivalManager` autoload
(DESKTOP step), festivals.json v1, board_orders.json v1, board
interactable. New suites: `test_festivals`, `test_board_orders`. Gate: full
suite green (790+ checks) + manual playtest of the day-18 festival and a
board order.

**Phase 4 - Content authoring (C2-C6, not engineering).** Writers populate
the locked dialogue.json v4 schema, festival flavour, and order templates
the moment Phase 2 exits. C2 is gated on E4's schema; C1 and C3-C6 can
proceed on their own branches in parallel.

## 8. Parallelisation map

- **ADR-032 Phase 1 (WS-A..D)** runs concurrently in its four worktrees
  throughout all phases; simulation-layer work has zero hard conflicts.
  New visible objects (spade? festival crowd, board UI) must render through
  the WorldVisuals/ActorVisual proxy pattern - coordinate once per phase.
- **Phase 1 (core) vs Phase 2 (dialogue)** can be built in parallel
  worktrees; merge Phase 1 first, then Phase 2, resolving GameData loader
  conflicts at merge.
- **Phase 3 (E5+E6)** is strictly sequential after Phases 1 and 2 land
  (depends on the new crops and the dialogue engine).
- **Content authoring (C1-C6)** starts when Phase 2 exits, on a branch with
  the locked schema; it never blocks code.

## 9. ADR and contract amendment list

| Item | Type | Timing |
|---|---|---|
| Dialogue condition evaluator + vocabulary | **New ADR-035** (ADR-034 is taken by the region) | Accept before Phase 2 |
| Board-orders trim (no supply pressure) | Decision note in `design/decisions.md` | Record during Phase 3 |
| Foraging rare-find signal/event flags | Decision note | Record during Phase 1 |
| Spring festival specifics | Amendment note to ADR-030 | Before Phase 3 (may be in-flight) |
| SAVE_VERSION 13 -> 14 | Contract amendment (section 2/12 save pointers) | After the migration is implemented (post-Phase 3) |
| ADR-033 cast amendment (X10) | Owed today | Not blocking this package; schedule now to unblock future villager work |
| E3 perk tree / E7 livestock expansion | New ADRs when pursued | Post-slice only |

## 10. Consolidated SAVE_VERSION 14 migration spec

One v13->v14 rung in SaveManager (`migrate_to_v14`), all fields additive
with safe defaults:

| System/block | New field | Type | Default |
|---|---|---|---|
| farm.cells (each cell) | `fertility` | int | 100 (existing saves); soil defaults for new grids |
| player | `event_flags` | Array[String] | [] |
| player | `dialogue_history` | Dictionary (npc -> line ids) | {} |
| tithe/market block | `board_orders` | Array[Dictionary] | [] |

**Do NOT include:** compost state, skill perks, livestock breeding/health,
supply-pressure data - all deferred. Existing v13 saves load as valid v14
after migration; `test_save_roundtrip` extended to cover the new fields and
the v13->v14 migration defaults.

## 11. Risk register

1. **Scope creep** (compost, supply pressure sneaking back in) - owner
   freeze on the deferred list; every phase gate checks against the
   package.
2. **Balance drift** - new crops/fertility can break test_season_sim
   expectations; update the simulation early in Phase 1 and run it daily.
3. **ADR-032 Phase 1 collision** - proxy rendering must cover the new
   visuals; early smoke test of new objects through WorldVisuals.
4. **C2/E4 coupling** - writers blocked on schema; deliver locked schema +
   sample lines at Phase 2 exit; content works in its own branch.
5. **Save migration mistakes** - wrong defaults corrupt dev saves; extend
   test_save_roundtrip with the v13->v14 rung before and after each phase.
6. **"More systems, less fun"** - playtest after each phase with a
   15-minute new-player session and a subjective fun score.
7. **DESKTOP registration debt** - two new autoloads; each phase's test
   checklist must include the Project Settings -> Autoload step.
8. **Content writing volume** - C2 for six NPCs with conditions exceeds
   code time; start writing at Phase 2 exit and share the load.

## 12. Owner decision checklist

1. Accept the 5-item package? **Recommended: accept.**
2. Restore any deferred item (compost, supply pressure, perks, livestock)?
   **Recommended: none now; revisit post-slice.**
3. Save bump now vs staged? **Recommended: single v14 at Phase 3 end (or
   when the first new field lands).**
4. Board-orders-only vs full supply pressure? **Recommended:
   board-orders-only.**
5. ADR for livestock expansion now or later? **Recommended: later, behind
   an ADR-028 amendment.**
6. X10 (ADR-033 cast amendment) timing? **Recommended: schedule now.**
7. Festival contest? **Recommended: no contest mechanics in the slice
   (ADR-030 no-mini-games); a stat-only comparison later if at all.**
8. C1-C6 parallel start? **Recommended: C2 dialogue writing at Phase 2
   exit; C1/C3-C6 in parallel on their own branches.**

## 13. Definition of fun - acceptance gates

**test_season_sim assertions (headless):**
1. A player planting carrots on loamy 100-fertility soil gets a choice-
   quality harvest by day 28.
2. Peas restore at least +5 fertility on their cell by the next day;
   planting the same depleting crop repeatedly exhausts it.
3. Soil at 0 fertility fails the crop with a clear message.
4. Spring foraging yields at least two distinct table items (incl. rare)
   across 28 days.
5. All four new crops appear as board-order targets at least once across
   two market weeks.
6. Completing a board order within deadline awards coin + standing popup.
7. Festival attendance on day 18 raises village +10 and church +8.
8. A dialogue branch conditioned on `has_item: pea` triggers and differs
   from the no-pea line.

**Manual playtest checkpoints:**
1. First 5 minutes: the market offers 7+ plantable seed types - immediate
   choice.
2. Fertility feedback: the HUD/tooltip shows soil health; overplanting the
   same crop visibly hurts.
3. Foraging excitement: finding a morel feels lucky and the village reacts.
4. Dialogue surprise: the steward greets the player differently after
   planting peas.
5. Board order direction: a market-day order is a concrete goal that pays
   off.
6. Festival belonging: villagers gather at the chapel on day 18 and the
   standing reward is communicated.
7. Coherence: a full 28-day run has multiple meaningful verbs - farm,
   manage soil, forage, chat, fill orders, attend the festival - without
   feeling overwhelming.

## 14. Corrections applied by the orchestrator

Pro's outputs were reviewed against the live repo; the following fixes are
already reflected above (and in the round-output files where noted):

- R1 ranking/cut-list ID errors fixed: Dynamic Market is **E6** (not E9);
  Tool & Weapon Crafting is **E9**; Herbalism & Medicine is **E13**.
- New dialogue ADR numbered **ADR-035** (R3b said "ADR-034", which is taken
  by the region record). A future skill-perk ADR becomes **ADR-036**.
- `items.json` is **v7**, not v6; recipes live in **recipes.json v1** (there
  is no crafting.json); all bumps corrected.
- New input actions register in **InputManager at runtime** via InputMap -
  never project.godot (E3's original note corrected; moot now that E3 is
  deferred, but recorded).
- E5 references dialogue.json **v4** (not v2); festivals.json is a **new**
  file, not already v1.
- R3b's migration table used `dialogue_seen` and placed `board_orders`
  under farm; the final spec uses E4's `dialogue_history` + `event_flags`
  and places `board_orders` on the tithe/market block (TitheManager owns
  the market).
- E12's schema example uses a flat `spawns` array with `soil` arrays -
  consistent with forage.json's current shape; the final file keeps the
  existing soil-keyed structure where possible.

## 15. Source files

- This document: `design/proposals/Proposal_Spring_Feature_Expansion.md`
- Round tasks: `.deepseek/tasks/proposal_r1_audit.md`,
  `proposal_r2a_deep_design.md`, `proposal_r2a_cont.md`,
  `proposal_r2b_design.md`, `proposal_r3_synthesis.md`,
  `proposal_r3a_review.md`, `proposal_r3b_plan.md`
- Round outputs + receipts: `.deepseek/outputs/proposal_r*_out.md` (+
  `.receipt.json`)
- Contract: `CLAUDE.md` v0.12 (AGENTS.md/DEEPSEEK.md generated)
- ADR log: `design/decisions.md` (001-034)
- Conversion plan: `design/IsometricConversion.md` +
  `design/IsometricConversion_Worktrees.md`
- Handoff: `DEVELOPMENT_STATE.md`

*End of proposal. No code was modified in producing it.*
