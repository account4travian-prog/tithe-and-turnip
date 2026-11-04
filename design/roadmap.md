# Roadmap - Sprints 6 to 14

Forward plan for the phase after the Spring vertical slice (Sprints 1-5,
complete 2026-08-05). `DEVELOPMENT_STATE.md` remains the handoff record and
points here; this file carries the detail.

**Authority:** this is a design note under `design/`, below `CLAUDE.md` and
`design/decisions.md` in the authority order. Nothing here is approved merely
by being written down. Sprints marked AMENDMENT require a contract change plus
an accepted ADR **before** work opens; the Proposed ADR stubs are recorded in
`design/decisions.md` (ADR-015..028).

**Implementation guides:** each sprint now has a full, code-level
implementation guide under [`design/sprints/`](sprints/README.md) - exact data
schemas, exact autoload APIs, exact integration points against the current
code, save-version deltas, and concrete test assertions. This file stays the
index (scope, sizing, sequencing, the ADR references); `design/sprints/
sprint_NN_*.md` is where an implementing agent should actually work from.
Several DESKTOP markers below were corrected during that pass - see each
sprint's guide for the specifics; the table here reflects the corrected
markers.

## Goal

Raise the slice toward end-game **system** fidelity while holding **content**
restricted: Spring only, six villagers, geometric primitives. Every system is
built as the shipping version would be; only the content tables are short.
Unlocking Summer/Autumn/Winter later should be a data change, not a rewrite,
so every system below is written season-aware from the start.

## Markers

| Marker | Meaning |
|---|---|
| DESKTOP | Needs a human in the Godot editor. Assign accordingly. |
| AMENDMENT | Touches the CLAUDE.md section 2 out-of-scope list. Needs a contract change + accepted ADR before work opens. |

**What DESKTOP actually covers.** Under `.deepseek/rules/godot-files.md` an
agent may not write `project.godot` or `.tscn`. So a human is required to:

1. Register a new autoload (Project Settings -> Autoload).
2. Create or edit any `.tscn` scene.
3. Change project settings (physics layer names, window, rendering).
4. Author TileSet / TileMapLayer resources.

**What it does not cover** - precedent is already set for doing these in code:

- New input actions (`InputManager` registers them at runtime via InputMap).
- Nodes built at runtime in `_ready()` (NPCs, `FarmRenderer`, HUD labels,
  melee hitboxes, arrow projectiles - all Sprints 2-5 shipped this way).
- New scripts, new `data/*.json`, new test suites.

Sprints 1-5 avoided the editor entirely by building at runtime. That kept
velocity high and has now accumulated real debt: `main.gd` constructs the HUD
in code and drives every menu off number keys, combat has no scene assets, and
the season-end summary is a HUD message rather than a panel. Sprint 7 is where
that debt gets paid; deferring it means building five more number-key menus.

## Overview

| # | Sprint | Size | Markers | Guide |
|---|---|---|---|---|
| 6 | Core loop closure & balance | S-M | - | [sprint_06_core_loop.md](sprints/sprint_06_core_loop.md) |
| 7 | UI & interaction layer | M | AMENDMENT (save slots) | [sprint_07_ui_layer.md](sprints/sprint_07_ui_layer.md) |
| 8 | Skills, foraging & the commons | M | DESKTOP (1 autoload) | [sprint_08_skills_foraging.md](sprints/sprint_08_skills_foraging.md) |
| 9 | Buildings, storage & land tenure | M-L | DESKTOP (1 autoload) | [sprint_09_buildings_tenure.md](sprints/sprint_09_buildings_tenure.md) |
| 10 | Village life: schedules, gifting, requests | M | AMENDMENT | [sprint_10_village_life.md](sprints/sprint_10_village_life.md) |
| 11 | Manor politics & the grey economy | M-L | AMENDMENT | [sprint_11_manor_politics.md](sprints/sprint_11_manor_politics.md) |
| 12 | Dynamic combat & the thief investigation | L | DESKTOP (1 autoload), AMENDMENT | [sprint_12_combat_investigation.md](sprints/sprint_12_combat_investigation.md) |
| 13 | Crafting, cooking & preservation | M-L | DESKTOP (1 autoload), AMENDMENT | [sprint_13_crafting_cooking.md](sprints/sprint_13_crafting_cooking.md) |
| 14 | Livestock | M-L | DESKTOP (1 autoload), AMENDMENT | [sprint_14_livestock.md](sprints/sprint_14_livestock.md) |
| 15 | Regions & zone-keyed world state (ADR-034) | L | AMENDMENT (CLAUDE.md section 2 Region bullet + sections 5/9.5 single-map wording) | [sprint_15_regions.md](sprints/sprint_15_regions.md) |

**Note on DESKTOP markers:** every DESKTOP sprint above needs *only* a
one-time autoload registration (~2 minutes, exact steps in Sprint 8's guide)
- not scene authoring, not a render layer, not a placement UI. Every panel,
renderer, and world object across Sprints 6-14 is built at runtime, the same
way Sprints 1-5 already built NPCs, hitboxes, and the farm renderer. The
original pass through this roadmap over-assigned DESKTOP to Sprints 7, 9, 12,
13, and 14; the corrected, narrower scope is documented in each sprint's
guide under a "Correction to the roadmap's DESKTOP scope" heading.

**Critical path:** 6 -> 7 -> 9. Sprint 8 gates 9 (materials) and 13 (recipe
gates). Sprint 10 gates 12 (alibi data). Sprints 10 and 11 can overlap. 12,
13, and 14 are independent of each other and can run in any order or in
parallel.

---

# Phase A - make the slice real

## Sprint 6 - Core loop closure & balance (S-M)

**Markers:** none. Fully assignable to an agent, unblocked today.
**Full guide:** [sprints/sprint_06_core_loop.md](sprints/sprint_06_core_loop.md)
- also documents and fixes a pre-existing defect found while writing it:
`SaveManager` has looked up `FarmGrid` at a path that never resolves in the
live game since Sprint 3, so farm tile state has likely never actually been
saved. Worth fixing on its own if Sprint 6 as a whole doesn't start soon.

Closes the gaps between the contract and the shipped code. Adds no scope - every
item below is either an unimplemented contract promise or a balance defect
found in the 2026-08-05 design review.

### Scope

- **Sleep.** `player_house` -> sleep prompt -> `TimeManager.sleep_to_next_day()`
  + energy restore (a data-driven fraction, not a free refill) + health regen +
  `SaveManager.save_game()`. Today `sleep_to_next_day()` has no gameplay caller,
  energy is set once at boot and never restored, `heal()` is never called, and
  autosave never fires. Contract sections 2 and 7 promise all four.
- **Forced day end.** Collapse at hour 24 if the player has not slept, with a
  penalty. The clock currently rolls to the next day on its own with no
  player-facing event.
- **Exhaustion.** Implement ADR-008's ladder, or supersede it to match the
  penalty already coded in `apply_pass_out_penalty` (20% coin, health 10).
  Both currently exist and neither fires from energy exhaustion. Pick one.
- **Moisture.** Clamp moisture to `moisture_max` in `plant()` - today rain sets
  a bare tilled cell to 100, and planting a turnip (max 80) into it produces a
  crop that can never grow, with no drain action and no re-till. Make
  overwatering a growth penalty rather than a hard stop; make `overcast` halve
  decay (it is currently 10% of Spring days with zero effect).
- **Map.** Redraw `farm_map.json`. It is presently 20 identical rows of three
  vertical stripes - 200 contiguous loamy tiles (best on every axis) with the
  well inside them and the house adjacent, so 400 tiles are unreachable content
  and soil type never becomes a decision. Fragment the patches, move the well
  out, add a second water source, give sandy and rocky a compensating upside.
- **Economy.** Acreage-scaled tithe (30 coin is roughly three turnip plants
  today); seed recovery below 1.0 average or quality-gated (it currently
  compounds, so seeds are free forever after the starter five); turnip/barley
  differentiation (barley dominates on every axis); buy-side toll per ADR-009;
  standing-adjusted prices per ADR-010; a recurring coin sink; crop spoilage
  after N days at maturity.
- **Dialogue.** Fill out five threshold bands x six NPCs. Reputation has three
  axes, five bands, and per-NPC opinions, and exactly seven lines with one
  condition to express itself through.

### Data

`player.json` v2, `tithe.json` v2, `crops.json` v3, `soil_types.json` v2,
`farm_map.json` v2, `market.json` v2, `weather.json` v2, `dialogue.json` v3.

### ADRs

ADR-015 (overwater as penalty), ADR-016 (sleep + exhaustion), ADR-017 (tithe
scaling + upkeep), ADR-018 (spoilage), ADR-019 (soil scarcity).

### Tests

`test_sleep_cycle`; extend `test_farm_moisture` with the rain -> till -> plant
trap; and the important one - **`test_season_sim`**, a headless scripted 28-day
playthrough asserting the tithe is *just* affordable alongside one tool
upgrade. That becomes the balance regression guard for every sprint after this
one, and is the only practical way to keep an economy honest without a QA pass.

### Gates

Import clean; existing 244 checks still green; `test_season_sim` passes; manual
full-day loop ends in sleep with an autosave on disk.

## Sprint 7 - UI & interaction layer (M)

**Markers:** AMENDMENT (save slots only) - **no DESKTOP work**, corrected
from the original pass through this roadmap. Every panel below is a
runtime-built `CanvasLayer` (the same pattern Sprints 1-5 already used for
NPCs, hitboxes, and the farm renderer), so this sprint is fully
agent-assignable. See [sprints/sprint_07_ui_layer.md](sprints/sprint_07_ui_layer.md)
for the full guide, including why the correction is safe.

### Scope

- HUD scene replacing the runtime labels: time/day/season, energy, health,
  money, tithe progress, weather, equipped tool + water level, standing.
- Inventory: grid, quality tiers visible, equip / eat / drop.
- Shop: buy and sell with the toll itemized and standing-adjusted prices shown.
- Dialogue panel with **response options**. Sprint 12's accusation flow -
  deferred out of Sprint 5 for exactly this reason - depends on it existing.
- Season-end summary as a real panel. Sprint 5 shipped it as a HUD message
  with 9-to-restart / 0-to-quit.
- Pause menu. Verify `get_tree().paused = true` genuinely freezes everything;
  known trap 7 has never been exercised.
- Settings: window mode, key rebinding through `InputManager`, text size.
- **Tile tooltips: moisture value, growth percent, soil type.** Moisture is
  presently invisible to the player, which makes the central farming mechanic
  unreadable and overwatering undiagnosable.
- AMENDMENT: save-slot UI ("Multiple save slots UI" is explicitly out of
  scope). Small amendment; `SaveManager` already supports named slots.

### Tests

Model layer only - `UIManager` focus stack, shop price calculation, rebind
persistence. Do not attempt headless assertions on rendered controls.

### Gates

Every screen reachable by keyboard **and** gamepad; pause-freeze regression;
wide and tall resize without distortion.

---

# Phase B - depth inside the current premise

## Sprint 8 - Skills, foraging & the commons (M)

**Markers:** DESKTOP (one-time autoload registration, ~2 min). No CLAUDE.md
amendment needed - life skills and foraging aren't on the out-of-scope list
at all, so ADR-021/ADR-022 acceptance is the whole gate, unlike Sprints
10-14's larger amendments.
**Full guide:** [sprints/sprint_08_skills_foraging.md](sprints/sprint_08_skills_foraging.md)
- contains the exact DESKTOP steps every later DESKTOP sprint's guide refers
back to.

### Scope

- **SkillManager** autoload: farming / foraging / combat / labor. XP from
  actions, levels from `skills.json`, effects on energy cost, quality odds,
  tool area, weapon reach, and the daily chore credit cap.
- **Foraging:** wild spawns on untilled tiles by soil type from `forage.json`,
  a gather action, respawn timers. Thematically this is gathering on the lord's
  waste; mechanically it is the first reason to walk onto the non-loamy two
  thirds of the property.
- Skill-gated unlocks so progression has visible rungs.

**Data:** `skills.json`, `forage.json`. **ADRs:** ADR-021, ADR-022.
**Tests:** `test_skills` (XP curve, level effects), `test_forage` (spawn
distribution, respawn).

## Sprint 9 - Buildings, storage & land tenure (M-L)

**Markers:** DESKTOP (one autoload registration only - placement UI and the
building render layer are runtime-built, corrected from the original pass
through this roadmap). **Full guide:**
[sprints/sprint_09_buildings_tenure.md](sprints/sprint_09_buildings_tenure.md).

Buildings are already in scope - ADR-007 states the whole property is eligible
for field or building. Land tenure is the new ruling (ADR-023).

### Scope

- **BuildingManager:** footprint validation, material + coin cost, multi-day
  construction.
- **Buildings:** storage chest, drying shed (counters Sprint 6 spoilage),
  second well, fence (feeds raid deterrence), cottage upgrade (better sleep
  restore).
- **Land tenure:** rent additional strips from the manor. Expands tillable area
  *and* raises the acreage-scaled tithe from Sprint 6 - the first genuine
  risk/reward decision in the economy, and historically exactly right for
  villeinage.

This is also the answer to the slice's missing coin sink: today roughly 530
coins buys every purchasable item in the game and money then accumulates with
nothing to do.

**Data:** `buildings.json`, `tenure.json`. **ADR:** ADR-023.
**Tests:** `test_buildings` (placement, cost, build timer), `test_tenure`
(rent -> tilled area -> tithe scaling).

## Sprint 10 - Village life: schedules, gifting & requests (M)

**Markers:** AMENDMENT. No editor work - NPCs stay runtime-spawned and this
sprint deliberately adds no new autoload (gifting/requests fold into the
existing `ReputationManager`). **Full guide:**
[sprints/sprint_10_village_life.md](sprints/sprint_10_village_life.md).

### Scope

- **Schedules** from `villagers.json`, driven by `TimeManager` hours: home ->
  field -> chapel -> home. Replaces the current random wander, and generates
  the alibi data Sprint 12's investigation needs.
- **Gifting:** per-NPC likes and dislikes, opinion deltas, a daily cap.
- **Requests:** data-driven asks ("bring me 5 fine barley by day 12") for coin
  and opinion. This is the Harvest Moon relationship hook, and the first thing
  in the game to create demand for a specific *quality* tier.
- **Mass on a fixed day:** attendance moves church standing. Cheap, thematic,
  and reuses the chapel that already exists.
- Marriage and festivals stayed out of scope for Sprint 10. **Superseded
  2026-08-06:** CLAUDE.md v0.11 moved both into scope by owner ruling; they
  are planned as passes C5/C6 in `design/content_plan.md` under ADR-030 and
  ADR-031. This line is left in place as the record of Sprint 10's own
  boundary.

**Data:** `villagers.json` v4 (schedules, likes, home/work tiles),
`requests.json`, `dialogue.json` v4. **ADR:** ADR-024.
**Tests:** `test_schedules` (position at a given hour), `test_gifting` (caps,
deltas), `test_requests` (accept / complete / expire).

---

# Phase C - requires a scope amendment first

## Sprint 11 - Manor politics & the grey economy (M-L)

**Markers:** AMENDMENT. The largest in the plan, and the one that most
directly delivers the "under the shadow of the manor" premise. No new
autoload - folds into `TitheManager`. **Full guide:**
[sprints/sprint_11_manor_politics.md](sprints/sprint_11_manor_politics.md).

### Scope

- **Manor court:** scheduled court days, fines for violence, unpaid tithe, and
  illegal sale.
- **Corvee:** the steward calls mandatory labor days on short notice, colliding
  with the player's own harvest window. Real tension, built almost entirely on
  the existing chore system.
- **Black market:** an itinerant trader paying above assize with no toll, with
  a detection roll scaled by village standing and witnesses. This weaponizes
  ADR-009's "sole legal venue" rule instead of leaving it as flavour text.
- **Price drift** so market-day timing becomes a decision.

**Data:** `manor.json`, `court.json`, `blackmarket.json`, `market.json` v3.
**ADR:** ADR-025. **Tests:** `test_court`, `test_corvee`, `test_blackmarket`
(detection odds, reputation fallout).

## Sprint 12 - Dynamic combat & the thief investigation (L)

**Markers:** AMENDMENT (ADR-014 explicitly defers these), DESKTOP (one
autoload registration for `InvestigationManager` - enemy/projectile scenes
are already code-only since Sprint 5 and need no editor work; corrected
from the original pass through this roadmap). **Full guide:**
[sprints/sprint_12_combat_investigation.md](sprints/sprint_12_combat_investigation.md).

### Scope

- **Dynamic raids.** `raids.json` already carries `deterrence_decay_per_day`,
  `deterrence_gain_per_victory`, and `min_deterrence_no_raid`; only the single
  scripted day-15 raid consumes them. Wire the scaling.
- **Enemy variety.** `bandit_archer` is defined in `enemies.json` and never
  spawns outside the scripted raid. Add a raid leader and night raids.
- **Defenses:** fences from Sprint 9, a hired guard, dogs.
- **Thief investigation:** clues (missing items, tracks, alibis from Sprint 10
  schedules) -> accusation through Sprint 7's response options -> trial at
  Sprint 11's manor court, with real consequences for a false accusation. Sprint
  5 shipped the thief as a notification plus a 30-coin loss and explicitly
  deferred the accusation flow; this closes it.
- Give **every** villager a populated `traits` list. Marta is currently the
  only villager with a non-empty array and it literally reads `["thief"]`, so
  the culprit is identifiable by reading the data file.
- **Injury:** wounds that persist past sleep.

**Data:** `raids.json` v2, `enemies.json` v2, `clues.json`. **ADR:** ADR-026.
**Tests:** `test_raid_scaling`, `test_thief_investigation`,
`test_combat_weapons`.
**Check first:** confirm the projectile physics layer landed in
`scripts/globals/physics_layers.gd` during Sprint 5.

## Sprint 13 - Crafting, cooking & preservation (M-L)

**Markers:** AMENDMENT ("full crafting, cooking recipes" explicitly out),
DESKTOP (one autoload registration for `CraftingManager` - the crafting UI
is runtime-built, corrected from the original pass through this roadmap).
**Full guide:** [sprints/sprint_13_crafting_cooking.md](sprints/sprint_13_crafting_cooking.md).

### Scope

- Recipes gated by Sprint 8 skills, executed at Sprint 9 stations.
- **Cooking:** meals returning more energy and health than raw crops. This is
  what turns food into a system rather than an optional top-up, and it is the
  only item in the plan that delivers the vision's "survive" pillar.
- **Preservation:** drying, salting, ale from barley. Converts perishable
  harvest into storable value - the direct answer to Sprint 6's spoilage clock,
  and it turns the economy into a production chain instead of raw-crop
  arbitrage.

**Data:** `recipes.json`, `items.json` v3. **ADR:** ADR-027.
**Tests:** `test_crafting`, `test_cooking`.

## Sprint 14 - Livestock (M-L)

**Markers:** AMENDMENT ("Livestock/animals" explicitly out), DESKTOP (one
autoload registration for `AnimalManager` - animals are runtime-built
markers like `NPC`, corrected from the original pass through this
roadmap). **Full guide:** [sprints/sprint_14_livestock.md](sprints/sprint_14_livestock.md).

The small-cast principle applies to animals too: **chickens and one goat.**
Daily feed and water, shelter from Sprint 9, products on a cycle, happiness
driving product quality (reuses the existing quality tiers), and animals as
raid targets - bandits driving off the goat is both a real medieval threat and
a clean way to make Sprint 12's deterrence matter.

**Data:** `animals.json`, `buildings.json` v2. **ADR:** ADR-028.
**Tests:** `test_animals`.

---

## Deliberately not in this plan

Summer / Autumn / Winter (the content restriction being held - every system
above is written season-aware, so unlocking is a data change), aging, disease,
art, audio, and export configuration. Those belong to a shipping track, not a
slice track, and several depend on decisions that have not been made.

**Marriage and festivals were on this list until 2026-08-06**, when an owner
ruling moved both into scope (CLAUDE.md v0.11, ADR-030 festivals, ADR-031
marriage). They are not part of *this* systems roadmap, which is complete
through Sprint 14 - they are planned as content passes C5 and C6 in
`design/content_plan.md`.

## Assignment summary

Every sprint 6-14 has at least one Proposed ADR that must be flipped to
Accepted before that sprint's work opens (per the authority order in
`design/decisions.md`) - that step applies universally and isn't a useful
differentiator on its own. What actually varies:

| Assign to | Sprints |
|---|---|
| Agent, no editor step at all | 6, 7, 10, 11 |
| Agent + a ~2-minute human autoload registration | 8, 9, 12, 13, 14 |

| Needs a CLAUDE.md section 2 amendment (not just ADR acceptance) | Sprints |
|---|---|
| Yes - out-of-scope list must be edited | 10, 11 (largest), 12, 13, 14 |
| Small, narrow amendment only (one feature, not the whole sprint) | 7 (save slots only, ADR-020) |
| No amendment - ADR acceptance alone is sufficient | 6, 8 (neither life skills nor foraging is on the out-of-scope list), 9 (ADR-007 already covers buildings; ADR-023 only adds the tenure ruling) |

Corrected after writing the per-sprint implementation guides: no sprint in
this plan needs a human for anything beyond the ~2-minute autoload
registration - there is no "human editor work is a real portion" category
anymore.

**Recommended start:** Sprint 6 immediately - it is unblocked, needs no
decisions, and the `test_season_sim` harness it produces guards every sprint
after it. In parallel, decide the Sprint 11 amendment, since manor politics is
where this stops being a generic farming sim.
