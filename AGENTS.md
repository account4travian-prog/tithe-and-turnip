<!-- GENERATED FROM CLAUDE.md - do not edit. Run docs/make_agents.gd. -->
# AGENTS.md - Tithe & Turnip (2D Farming Sim)

**Version 0.23** - Engineering contract for a 2D medieval farming sim built in
Godot 4.7.1 (standard build). Read this file before touching any other file in
this project.

### Where things are written down

| Document | Answers |
|---|---|
| `AGENTS.md` | **The contract.** Pins, scope, style rules, data rules, architecture requirements. Read first, every session |
| `design/decisions.md` | **The ADR log.** Why a design ruling was made and what it overturned. Append-only |
| `DEVELOPMENT_STATE.md` | **The handoff.** What is built, what is next, what has bitten |
| `data/*.json` | The tunables. Crops, items, villagers, time, dialogue |
| `tests/` | The characterization harnesses. Hand-rolled, run headless |

`AGENTS.md` and `DEEPSEEK.md` are **generated** from this file. Never edit them
by hand; run `docs/make_agents.gd` / `docs/make_deepseek.gd` and commit the
regenerated files together with any change to `AGENTS.md`. The contract-sync
suites fail the test run if they drift.

### Design authority order

1. **This file** - the engineering contract. A design ruling that contradicts
   it is blocked until the contract is amended.
2. **`design/decisions.md`** - the ADR log. Outranks every design body below
   it. Check a record's status line before acting on it.
3. **Design notes in `design/`** - rulings that have not yet reached the
   contract.
4. **The plan in `DEVELOPMENT_STATE.md`** - the only forward plan there is.

---

## 1. Pinned Versions

| Thing | Pin |
|---|---|
| Engine | **Godot 4.7.1 stable, standard build** (NOT .NET/Mono) |
| Language | **GDScript only** |
| C# / GDExtension / third-party addons | **Forbidden** - this includes test frameworks. GUT and gdUnit4 are out; tests are hand-rolled `SceneTree --script` harnesses in `tests/` |
| Target platform (this phase) | **Windows desktop only** - no Android export config yet |
| Renderer | Forward+ (desktop default) |
| `physics/common/physics_ticks_per_second` | **60** - load-bearing, see section 4 |
| Viewport | Base `1280 x 720`, stretch mode `canvas_items`, aspect `expand` |
| Projection (ADR-032, amended ADR-043) | **Standard isometric, `64 x 32` screen tile** (2:1). Simulation grid stays axis-aligned; projection is presentation-only |
| Logical cell | `32` - the grid unit physics and collision run in. Unchanged by the projection |

### API confidence rule

Reliably-verified Godot knowledge covers the 4.0-4.4 API surface. Everything
specified here is long-stable core API, but **4.5 / 4.6 / 4.7 deltas are not
verifiable from memory.**

- **Never emit Godot 3.x API.** (`update()` -> `queue_redraw()`,
  `instance()` -> `instantiate()`, `KinematicBody2D` -> `CharacterBody2D`,
  `yield` -> `await`, `export var` -> `@export var`, `onready` -> `@onready`,
  `Directory`/`File` -> `DirAccess`/`FileAccess`,
  `connect("sig", self, "m")` -> `sig.connect(m)`.)
- **Flag, don't guess.** Any method, property, signal, enum, or project setting
  that is less than fully confident for 4.7 is called out in the response that
  introduces it, with what is expected and what to check if it errors. These
  also go in `DEVELOPMENT_STATE.md`.

---

## 2. Scope

### Vision

A 2D dimetric farming sim about medieval peasant life: survive, thrive, and
build a meaningful life through the seasons under the shadow of the manor.
Realistic enough to feel consequential (soil, seasons, hunger, tithes), fun
enough to keep a player for an evening (clear goals, visible progression,
small triumphs). Inspirations: Stardew Valley (approachable loop), Harvest
Moon (time urgency, relationships), Rune Factory (crafting light, life
skills).

Those three inspirations are orthogonal 3/4 top-down, not isometric. The
isometric projection (ADR-032, amended ADR-043) is a deliberate departure
from them, taken for the depth structures and terrain read with; the loop,
pacing, and tone they inform are unchanged. **Only the presentation is
isometric** - see section 8's projection invariant.

### Vertical slice (the current body of work)

**In scope:**

- Project harness (this contract, generators, rules, sync tests).
- Isometric presentation (ADR-032, amended ADR-043): a single projection seam
  converts the axis-aligned simulation grid into `64 x 32` screen diamonds
  (standard 2:1 isometric; changed from the original `64 x 48` dimetric
  aspect by ADR-043 so commercial/found modular art packs have a realistic
  integration path); renderers draw projected geometry, actors and structures
  depth-sort by grid depth, and the render layer culls to the visible rect so
  the property map can grow past the current 30x20 without a rewrite.
  Simulation, physics, collision, and saves stay axis-aligned and are
  untouched by it.
- Title screen -> farm scene flow; pause menu.
- Player movement (keyboard/gamepad via `InputManager`) with input mapped
  screen-relative and facing resolved 8-way (ADR-032): the raw movement vector
  is rotated into grid space so "up" always means visually up on screen, never
  a grid diagonal. Facing widened from 4-way to 8-way as a direct consequence
  - under the rotation the four screen cardinals land on grid diagonals, so a
  4-way facing would leave half the neighbouring tiles untargetable.
- Day/time/season/year system with HUD: 14-real-minute day (0.78 s per
  game-minute), 28-day seasons. The vertical slice covers Spring only
  (days 1-28), ending with a season-end summary screen (Restart/Quit). All
  four seasons remain defined in data but are unreachable in the slice.
- Farm grid: 30x20 property map (`farm_map.json`) with three soil types
  (loamy/sandy/rocky) affecting moisture decay, growth speed, and quality
  odds; per-cell moisture decay and per-crop moisture range from `crops.json`;
  growth advances on `day_passed` only when moisture is in range; quality
  (common/fine/choice) with seed recovery 1-3 per harvest; tools (hoe,
  watering can) with tiers bought at market; watering can refills at a
  well/pond. Cabbage stays in data but is not plantable in Spring ("in season
  later" tooltip). Four additional Spring crops - carrot, pea, onion, leek
  (the Spring Crop Pack) - each with a hearth recipe, a market price, and a
  gift-preference wire into `villagers.json`.
- Region (ADR-034, opened for implementation 2026-08-07 as Sprint 15 - see
  `design/sprints/sprint_15_regions.md`): the flat 30x20 property map
  splits into nine zones on separate maps - the player's holding
  (Fallowfield), the village of Nettleford, the manor of Harrowmere, three
  wilderness edges (the Upland Commons, Cottersward the lord's wood, the
  Nettle Brook corridor), and three neighbouring tenant lands (Edith's
  Plot, the North Strip, the South Fields carrying `tenure.json`'s
  rentable strips). The player crosses zones by walking off a map edge -
  no fast travel, no overworld map, no travel-time simulation. Each zone
  keeps its own `FarmGrid` instance; only the active zone's terrain,
  features, buildings, and NPCs exist at once. Building placement stays
  restricted to Fallowfield; tilling is possible on Fallowfield and any
  rented strip. Simulation, physics, saves, and the ADR-032 dimetric
  projection stay exactly as specified elsewhere in this contract - a
  zone is a flat plane like the single map it replaces, not a new
  coordinate space or a third axis. Landing in two internally-green
  passes (Sprint 15a: data model, `ZoneManager`, save migration; Sprint
  15b: transitions, rendering, NPC zone-awareness) - until both land, the
  "Farm grid" bullet above still describes the shipped, single-map
  reality.
- Soil fertility (the Spring Feature Expansion package, accepted-with-
  amended-scope 2026-08-07): every cell carries a `fertility` 0-100,
  initialised from `soil_types.json`, depleted on harvest by the crop's
  `fertility_depletion` (negative for cover crops like peas, which restore
  it instead), recovered by fallow days or compost, and gating both planting
  (`fertility_min`) and a quality bonus at a per-soil
  `high_fertility_threshold`. Compost is crafted from `spoiled_crop` at the
  Drying Shed - ADR-018's two-stage rot now leaves that item behind on the
  tile (gathered through the ordinary forage action) instead of destroying
  the crop with nothing produced.
- Life skills (ADR-021): a `SkillManager` tracks farming, foraging, combat,
  and labor; XP from actions, levels and effects from `skills.json`.
- Foraging & the commons (ADR-022): wild plants, rocks (flint), and lumber
  (wood) spawn on untilled tiles by soil type and season from `forage.json`,
  gathered with a dedicated action; the source of building materials. A
  spade (Foraging 2.0) digs untilled cells against a dedicated `dig_loot`
  table - mostly buried forageables (wild carrot, wild turnip), rare finds
  (morel in Spring; truffle defined in data for Autumn, unreachable this
  slice) as a throttled bonus, never a grind: energy cost, a daily dig cap,
  a genuine miss chance, and season gating all stack rather than any one of
  them carrying the whole limit.
- Inventory, energy, money; eating food restores energy (quality multiplies
  energy restored); player health (max 50) with knockout at zero, regenerates
  on sleep.
- Sleep -> next day, autosave; save/load roundtrip (versioned `user://` JSON,
  current version 16).
- Manor market stall (sole legal venue): buys crops (assize prices x quality,
  5% toll) and sells seeds, tools, and weapons; open two market days per week
  (days 3, 7, 10, 14, 17, 21, 24, 28).
- Lord tithe: assessment scaled by held acreage (base 20 coin + 10 coin per
  rented strip, ADR-038) payable in coin, in-kind crops (market value x
  quality), or energy-based labor on the steward's demesne (daily chore
  list, daily credit cap). Unpaid -> soft failure at season end.
- Church tithe: voluntary donations (coin/crops) at a chapel tithe box;
  boosts church and village standing; no legal consequence.
- Two-layer reputation: individual opinions per villager + community standing
  (manor, village, church). The steward is the first NPC; a priest and
  villagers are added for village dynamics.
- Dialogue condition evaluator (ADR-035): a `ConditionEvaluator` filters
  each NPC's `dialogue.json` lines against a per-conversation context (time,
  season, weather, market/mass day, inventory, skill levels, player stats,
  standing, opinion toward any villager, event flags), and a `DialogueManager`
  autoload picks the highest-`priority` match (random among exact ties),
  gated by `frequency` (always/once_per_conversation/once_per_day). Fixes
  the dead-content bug where dialogue selection took whichever line
  happened to be first in file order among every match, not the best one.
- NPC schedules (ADR-024): villagers follow data-driven home/work schedules
  driven by `TimeManager` hours, replacing the random wander and producing
  deterministic alibi data for future investigation.
- Gifting and requests (ADR-024): players gift liked/disliked items (daily
  cap) to move individual opinions and accept data-driven fulfillment
  requests for coin and opinion.
- Chapel mass (ADR-024): a voluntary fixed-day attendance (day 21, hour 9)
  raises church and village standing; missing it has no penalty, consistent
  with the church axis staying voluntary (ADR-012).
- Manor politics & the grey economy (ADR-025): a manor court that fines
  witnessed violence and detected illegal sales on scheduled court days
  (off the market cadence); corvee - the steward calling a mandatory labor
  day on short notice, colliding with the player's own harvest window;
  an itinerant black-market trader paying above assize with no toll against
  a detection roll scaled by village standing; and small market-day price
  drift so timing a sale matters.
- Dynamic local economy (ADR-037): the town board posts 1-3 in-season
  fetch-quest orders on each market day (capped at 3 active; each order
  carries a quantity, coin reward, optional standing, and a deadline, and
  unfulfilled orders expire silently), and the stall's crop prices respond
  to the player's own supply: every unit sold adds to that item's supply
  pressure, prices are locked at market open inside a 0.5x-1.5x band, and
  pressure decays nightly so gluts fade. Player-only supply (no AI farmers,
  no global economy); board orders are quality-agnostic and deliberately
  outside the supply-pressure system. Both fold into TitheManager - the
  town board is a farm_map.json feature tile opening a UIManager panel, not
  a new autoload (a new autoload needs a human-only Project Settings
  registration, the same DESKTOP-step constraint ADR-035 recorded).
- Weather: seasonal daily roll from `weather.json` (Spring 30% rain, Summer
  10%, Autumn 40%, Winter snow - data only); rain auto-waters all tilled
  cells; snow blocks tilling/planting (winter data only).
- Combat (approved): real-time melee + ranged combat on the main map. Weapons
  are items - fists (default), staff, spear, pitchfork, knife (melee, varying
  reach), and bow (ranged, consumes arrows). Weapon reach varies and is a key
  balance axis. Any NPC can be attacked, with witnessed-violence reputation
  outcomes. Bandit raids threaten the farm and are deterred by the player's
  own efforts (deterrence from victories). Thieves can come from within the
  village (hidden traits, clues, accusation). Spring slice proof: spear as the
  equipped weapon, one scripted bandit raid (day 15), one thief villager.
- Dynamic raids & the thief investigation (ADR-026): deterrence-driven raid
  frequency and scaling beyond the scripted day-15 raid (archer, leader, and
  night-raid variants); defenses - fences, a guard dog, a hired guard - that
  feed effective deterrence; and a full thief investigation - runtime clues,
  alibi framing from NPC schedules, accusation through dialogue responses,
  and trial at the manor court with consequences for a false accusation.
  Every villager carries a populated `traits` list. A combat pass-out inflicts
  a wound that persists past sleep and taxes tool energy until it heals.
- Crafting, cooking & preservation (ADR-027): recipes gated by farming skill
  level and executed at completed station buildings (drying shed, hearth).
  Cooked meals restore meaningfully more energy and health than raw crops;
  preservation (drying, salting, ale) converts perishable harvest into
  storable, sellable value - the sprint that delivers the vision's "survive"
  pillar and turns the economy into a production chain.
- Livestock (ADR-028): chickens and one goat - the small-cast principle
  applied to animals. Daily feed and water, shelter from built buildings,
  products on a cycle, happiness driving product quality through the existing
  quality tiers, and animals as raid targets (bandits can drive off the goat,
  giving the ADR-026 deterrence system a stake in the herd).
- Festivals (ADR-030): data-driven village gatherings on fixed calendar days
  from `festivals.json`, one per season with all four defined in data and
  only the Spring festival reachable in the slice - the same season-aware
  data convention every other system follows. Attendance at the festival's
  day/hour and place moves village and church standing; missing one has no
  legal penalty (consistent with ADR-012's voluntary church axis) but costs
  the standing on offer. Festivals reuse the existing TimeManager calendar,
  reputation axes, and NPC schedules. Each festival carries a contest -
  direct entry (a data-driven timed-press skill check against Farming or
  Labor, forgiveness widened by skill level) and/or cheering a named entrant
  with an optional coin bet - resolved by `FestivalManager`, the one true
  addition beyond reusing existing systems. Spring's Furrow Race is fully
  playable and tested this slice; the other three seasons' contests are
  data-complete and reachable only once their season is.
- Marriage (ADR-031): courtship and spouse life with candidates drawn from
  the ADR-033 Tier 1 principal cast, excluding authority figures on fiction
  grounds - the priest (celibate), the steward, and the miller (manor
  staff and manor-licensed trade respectively). Five candidates as of the
  ADR-038 amendment: Hilda, Cedric, Marta, Bram, and Edith (the
  neighbouring-tenant principal). Osric (the miller) completes ADR-033's
  eight Tier 1 principals but is not a candidate. A ninth Tier 1 principal
  is a new ADR (ADR-033's boundary) and does not by itself add a marriage
  candidate. Courtship gates on individual opinion,
  gifting, and completed requests; a proposal at a threshold; a ceremony at
  the chapel. A spouse then moves into the player's cottage, gains a
  home-based schedule, greets the player on waking, occasionally completes a
  farm chore, and is giftable outside the normal daily cap. Marriage
  consumes the existing opinion, schedule, building, and chore systems
  rather than introducing new ones. Children, in-laws, divorce, and rival
  suitors are NOT in scope.
- Art asset integration (ADR-041, opened 2026-08-08 by owner ruling):
  purchased/found sprite packs under `SourceArtAssets/` are integrated as
  textured visual proxies for structures, map features, actors (player,
  NPCs, animals, enemies), and UI chrome - replacing their primitive
  `_draw()` proxies one category at a time. Terrain/soil rendering is
  explicitly untouched by this ADR and stays immediate-mode primitives (see
  section 9.5); none of the sourced packs are farm-soil tile atlases, and
  retexturing terrain is a separate, not-yet-authorized undertaking.
  **Visual unification across packs is explicitly not required this pass**
  - styles clash (pixel-art vs. painted vs. vector-clean) and are
  integrated as-is; the owner ruling accepts this in exchange for speed,
  editing an asset only where it fails to read at all at the 64x48 tile
  scale. The existing `asset_studio/` AI-generation pipeline (LoRA
  unification, restyling) is parked, not adopted, for this pass - it
  remains available for a future polish pass but is not a dependency of
  this one. Execution guide: `design/sprints/sprint_16_art_integration.md`.

**Out of scope - do not build without explicit approval:**

- Full peasant-life simulation beyond the approved systems (disease, aging,
  deeper manor politics beyond the approved court, corvee, and black-market
  systems).
- Children, in-laws, divorce, and rival suitors (the marriage boundary set
  by ADR-031).
- Mod support, localization, audio.
- Audio, particles, and shaders remain out of scope. (Sprites and art
  assets are no longer excluded - ADR-041 opened static/animated texture
  integration; see the new Art asset integration bullet above. Geometric
  primitives remain the default wherever no art asset exists yet, including
  all of terrain/soil.)
- Elevation of any kind (the ADR-032 boundary): no height values, no z-levels,
  no terrain slopes, no multi-storey structures, no jumping or flying, no
  cliffs or bridges. The projection is a flat plane drawn at an angle. A
  request that needs a third axis in the simulation is a new ADR, not an
  extension of this one.
- Android / web export configuration.

If a task appears to require something on the out list, **stop and ask** before
building it.

---

## 3. GDScript Style Rules

1. **Typed GDScript, always.** Every variable, parameter, and return type
   annotated. `:=` inference only where the right-hand type is unambiguous at a
   glance.
2. **`class_name` on every reusable script**, PascalCase. **Exception:
   autoload scripts must NOT declare `class_name` matching their autoload
   name** - Godot 4.7 rejects "Class X hides an autoload singleton" as a parse
   error. Autoloads are reached by their singleton name (`GameData`,
   `TimeManager`, ...); other scripts cast them dynamically or via `get_node`.
3. **Naming:** files `snake_case.gd`/`.tscn` - scene nodes `PascalCase` -
   classes `PascalCase` - functions/vars `snake_case` - constants and enum
   members `SCREAMING_SNAKE_CASE` - private members `_leading_underscore` -
   signals past tense (`day_passed`, `crop_harvested`) - booleans read as
   assertions (`is_watered`, `has_seed`).
4. **Declaration order:** `class_name` -> `extends` -> docstring -> signals ->
   enums -> constants -> `@export` -> public vars -> private vars -> `@onready`
   -> engine callbacks -> public methods -> private methods.
5. **No magic numbers in gameplay code.** Every tunable comes from JSON via
   `GameData`. A literal in a gameplay script is a bug unless structural.
6. **No `get_node()` string paths in hot code.** `@onready var x: T = $Path`,
   or an `@export`ed reference.
7. **Comment the *why*.** Frame-count conversions, engine quirks, and every
   deliberate divergence must be commented **and** mirrored into
   `DEVELOPMENT_STATE.md`.
8. **No `_process` for gameplay.** See section 4.
9. **Full-file replacements** when modifying a script - no partial diffs, no
   elisions.
10. **Entity scripts hold no file I/O.** Data comes in through the systems
    layer (`GameData`, `SaveManager`).

---

## 4. The Tick Rule (load-bearing)

The game is tick-based: one physics tick == one fixed step at 60 Hz, and
in-game time is expressed in JSON as game-minutes.

- `physics/common/physics_ticks_per_second = 60`.
- **Gameplay runs in `_physics_process(delta)`** - movement, tool use,
  interaction. `delta` is a fixed `1.0 / 60.0`.
- `_process()` is for **rendering and HUD only** - label text, bar fills,
  tweening. Never mutate gameplay state there. The in-game clock itself is the
  one exception: `TimeManager` accumulates real time in `_process` because a
  wall-clock advance is not physics, and its core method
  (`advance_real_seconds`) is what tests drive.
- Per-second rates use the fractional-accumulator pattern
  (`accum += rate * delta`), not a `Timer` node.
- Frame counters are `int` and increment by 1 per tick.

Positions are `Vector2` floats throughout.

---

## 5. Node & Scene Conventions

### Directory layout

```
2DFarmingSim/
|-- AGENTS.md                  # this file - the contract
|-- AGENTS.md                  # GENERATED from AGENTS.md
|-- DEEPSEEK.md                # GENERATED from AGENTS.md
|-- DEVELOPMENT_STATE.md       # what is built, what is next, what has bitten
|-- project.godot              # EDITOR-created; bootstrap exception only (docs/bootstrap_project.gd)
|-- docs/
|   |-- make_agents.gd         # generator for AGENTS.md
|   |-- make_deepseek.gd       # generator for DEEPSEEK.md
|   |-- derive_deepseek.gd     # shared transform logic
|   `-- bootstrap_project.gd   # one-time headless project/scene bootstrap
|-- .deepseek/
|   `-- rules/
|       |-- gdscript.md
|       `-- godot-files.md
|-- design/
|   |-- decisions.md           # ADR log
|   |-- IsometricConversion.md          # ADR-032 conversion plan: workstreams, ownership, merge order
|   |-- IsometricConversion_Worktrees.md # ADR-032 parallel-agent runbook (git worktrees)
|   `-- standard_isometric_conversion_guide.md # ADR-043 phased 64x32 aspect-ratio runbook
|-- data/                      # shipped default JSON (res://data/)
|-- scenes/
|   |-- title_screen.tscn
|   |-- main.tscn
|   `-- ui/
|-- scripts/
|   |-- autoloads/             # game_data, event_bus, input_manager, time_manager,
|   |                          # player_state, save_manager, ui_manager
|   |-- globals/               # physics_layers, iso_projection (the ADR-032 seam)
|   |-- world/                 # farm_grid, crop, renderers
|   |-- player/
|   `-- ui/
|-- tests/
|   |-- run_tests.gd           # headless runner
|   `-- suites/                # hand-rolled suites
`-- assets/                    # sprites/ (ADR-041 art integration) plus any
                                # remaining placeholder geometric assets
```

### Scene flow

```
title_screen.tscn -> main.tscn
                          |
                          v
                sleep -> autosave -> next day
```

Transitions use `get_tree().change_scene_to_file()` (or `_to_packed()` where a
preloaded scene is already at hand). State crosses scene boundaries through
autoloads, never through scene-local globals. Region zone crossings (Sprint
15) are **not** a scene change - `main.tscn`'s `Main` root stays loaded and
`ZoneManager` swaps the active `FarmGrid`/renderers/NPC set in place; this
diagram's single `main.tscn` node is unaffected.

### Autoload seams

- `GameData` - loads `data/*.json` at boot, casts at the boundary, answers
  lookups. No gameplay file reads JSON itself.
- `EventBus` - global signals for decoupled events (`game_loaded`,
  `crop_harvested`, `day_passed` forwarding where needed).
- `InputManager` - the ONLY place that calls `Input.*` for gameplay. See
  section 9.4.
- `TimeManager` - day/season/year clock; emits `minute_passed`, `day_passed`,
  `season_changed`, `year_passed`.
- `PlayerState` - inventory, energy, money; serializable.
- `SaveManager` - `user://` JSON saves; autosave on sleep.
- `UIManager` - opens/closes inventory, dialogue, pause; owns focus.
- Planned for the next phase (per ADR-002..014): `FarmGrid` (farm tile state,
  soil lookup, moisture), `WeatherManager` (seasonal daily roll, rain
  auto-water), `TitheManager` (lord tithe coin/crop/labor, church donations,
  daily chore list), `ReputationManager` (individual opinions + community
  standings), `CombatManager` (attack hitboxes, projectiles, cooldowns,
  damage, knockback), `RaidManager` (bandit raids, deterrence, thief events).
- Planned for ADR-041 (art asset integration): a small data-driven
  sprite/animation lookup, exact name and API pinned by
  `design/sprints/sprint_16_art_integration.md`. Given the DESKTOP-step
  constraint on registering a *new* autoload (ADR-035, ADR-037), it lands as
  a plain `class_name` static helper (the `IsoProjection` pattern) or folds
  into `GameData`'s existing boundary - not a new autoload - unless the
  sprint guide finds a concrete reason a static lookup can't carry it.

---

## 6. Data Rules (JSON)

1. **All tunables live in `data/*.json`** and are loaded by `GameData` at boot.
   A gameplay literal is a bug.
2. **JSON has no ints at the boundary.** Godot parses JSON numbers as floats;
   integer fields (counts, days, stages, prices) are cast at the `GameData`
   boundary using the `INT_KEYS` convention: each loader declares which keys
   are integers and casts them on load. Never rely on a JSON float where an
   int is semantically required.
3. **Keys are snake_case strings.** Never key a lookup on a display name; the
   display name is a separate `name` field.
4. **Schema versioning:** each data file carries a `"version": N` key. Bump on
   shape changes; migration lives in `GameData`, not in the consumers.
5. `res://` is read-only when exported; **saves go to `user://`** and follow
   section 7.

---

## 7. Save Rules

- Save file: `user://save_autosave.json` (autosave on sleep) plus
  `user://save_<slot>.json` for manual slots.
- Payload shape (version 2): `{ "version": 2, "day": int, "season": String,
  "year": int, "player": { money, energy, health, inventory (items carry a
  quality tier), tool_levels, equipped_weapon, arrow_count, tithe_progress,
  church_donations, pass_out_count, reputation (manor/village/church standing
  + individual_opinions), combat (raid_deterrence, theft_events) }, "farm": {
  cells (x, y, tilled, crop_id, growth_progress, moisture), storage } }`.
- **Versioned saves, migrations from day one.** A `version` key is mandatory;
  `SaveManager` refuses unknown-newer versions and migrates older ones.
- Saving is atomic in intent: build the payload, validate it round-trips,
  then write.

---

## 8. Design-Locked Invariants (never change without a contract amendment)

- GDScript only; no C#, no GDExtension, no third-party addons.
- Data-driven tunables; no hardcoded crop/time/economy numbers in code.
- All gameplay input goes through `InputManager`.
- **Projection is presentation-only (ADR-032, amended ADR-043).** The
  simulation grid, physics bodies, collision shapes, weapon reach, pathing,
  and save payloads are axis-aligned and know nothing about the isometric
  view. Screen-space coordinates never enter gameplay state, and no gameplay
  decision is ever made from a projected value. Conversion lives in exactly
  one file, `scripts/globals/iso_projection.gd`; a projection or
  inverse-projection formula written anywhere else is a defect.
- **Art assets are presentation, same as the projection (ADR-041).** A
  textured visual proxy still reports its position from `IsoProjection` and
  sorts under `y_sort_enabled` exactly like a primitive one; swapping
  `_draw()` for a `Sprite2D`/`AnimatedSprite2D` child changes no gameplay
  state, no save shape, and no physics/collision geometry. Terrain/soil
  rendering is outside ADR-041's scope and stays primitive per section 9.5.
- Saves are versioned JSON in `user://`.
- Editor-managed files (`project.godot`, `.tscn`, `.tres`, `.uid`, `.import`,
  `.godot/`) are never hand-edited. The single documented exception is the
  one-time headless bootstrap: a minimal `project.godot` seed is created at
  repo bootstrap so the engine has a project to open, and
  `docs/bootstrap_project.gd` then rewrites it and builds the first scenes
  through the engine's own serialization APIs. See `docs/bootstrap_project.gd`
  header and `.deepseek/rules/godot-files.md`.
- No third-party test frameworks; suites are hand-rolled and run headless.

---

## 9. Architecture Requirements

1. **Engine-side physics.** `Area2D`/`CharacterBody2D` + layers/masks per the
   physics table; no manual O(n x m) loops where engine queries exist.
2. **Float positions.** `Vector2` everywhere, `delta`-based movement.
3. **Resolution independence.** Base viewport `1280 x 720`, stretch
   `canvas_items`, aspect `expand`. Nothing hardcodes the base size outside
   project settings; read `get_viewport_rect().size` where a live dimension is
   needed.
4. **Input abstraction layer.** Gameplay reads input **only** from
   `InputManager.get_movement_vector() -> Vector2`,
   `InputManager.is_action_just_pressed(action)`, and
   `InputManager.is_action_pressed(action)`. No gameplay script calls
   `Input.*` or `_unhandled_input()` for gameplay. **Enforced in review:** a
   direct `Input.` call under `scripts/` is a defect.
5. **World representation.** Terrain/soil is drawn in immediate mode
   (`_draw()` on `Node2D` renderers under `scripts/world/`), **not** a
   `TileMapLayer` - ADR-032 settled this and ADR-041 leaves it settled: none
   of the sourced art packs are farm-soil tile atlases, and a `TileMapLayer`
   would still require an editor session that blocks headless work
   regardless of art availability. Farm state lives in `FarmGrid` as a grid
   dictionary keyed by `Vector2i` (runtime) and serialized as a flat array.
   Crop growth advances on the `day_passed` signal, never on real-time ticks.
   Renderers cull to the visible rect and read map dimensions from
   `farm_map.json`; no script assumes 30x20. Once Sprint 15 lands (Region,
   ADR-034), this becomes **one `FarmGrid` instance per zone**, owned by a
   `ZoneManager` autoload - every rule above still applies per zone
   (immediate-mode drawing, `Vector2i` keys, `day_passed`-gated growth,
   cull-to-visible-rect, no fixed-dimension assumption); nothing in this
   section changes, it is just enforced nine times instead of once.
   **Visual proxies may be textured (ADR-041).** A structure, feature, or
   actor's `y_sort_enabled` visual proxy (section 9.7) may carry a child
   `Sprite2D`/`AnimatedSprite2D` sourced from a data-driven sprite/animation
   manifest under `data/`, instead of or alongside a primitive `_draw()`
   override. The proxy's position/anchor and the y-sort it participates in
   are unchanged either way - texturing a proxy is a rendering detail of
   that one node, never a new coordinate space, and never a reason to read
   `Input.*` or touch gameplay state from `scripts/world/` render code. Crop,
   tool, and other UI icons follow the same rule inside their own screens.
6. **UI.** One shared `ui_kit.gd` for common control construction; screens
   (`title_screen`, `hud`, `inventory`, `dialogue`, `pause`) are scenes under
   `scenes/ui/` or `CanvasLayer`s in `main.tscn`. Pause freezes everything:
   `get_tree().paused = true`; modal layers set `PROCESS_MODE_ALWAYS`.
7. **Projection and depth (ADR-032).** `IsoProjection`
   (`scripts/globals/iso_projection.gd`) is the only place a grid coordinate
   becomes a screen coordinate. Gameplay nodes keep axis-aligned positions;
   what the player sees is a **visual proxy** under a single `y_sort_enabled`
   container whose screen position the projection supplies. Depth ordering is
   therefore per object and continuous rather than per layer - a structure
   taller than one cell sorts against the actor walking past it. Terrain draws
   beneath that container and does not participate in sorting. Projection runs
   in `_process` (presentation); `_physics_process` never projects.

### Physics/collision layers

| Layer | Meaning |
|---|---|
| 1 | Player |
| 2 | NPCs |
| 3 | Interactables (bed, market stall, doors) |
| 4 | Farm tiles (tool targeting) |
| 5 | Items/pickups |

Layer constants live in `scripts/globals/physics_layers.gd`; never type layer
numbers inline in gameplay scripts.

---

## 10. Mandatory Response Format

**Every code-modifying response ends with a numbered "How to Test This Change"
checklist.** No exceptions.

Manually runnable from the Godot editor, stating the expected observable
result for each step, plus a regression sweep over: movement, day advance,
crop growth/harvest, energy, save/load, pause, window resize.

```
**How to Test This Change**
1. Open the project in Godot 4.7.1 and press F5 - the game runs with no errors in Output.
2. [Feature-specific step] - expect [observable result].
...
N. Resize the window to a wide and a tall aspect - the play area adapts without distortion.
```

---

## 11. DEVELOPMENT_STATE.md - Maintenance Duty

A running log, appended to in the **same response** as the change that warrants
it. Record:

- Anything that behaved differently in Godot than expected, and how it was
  resolved.
- Anything that took significantly longer or shorter than expected, with a
  one-line reason.
- Every API used that could not be verified against 4.7 from memory.
- Every deliberate divergence, with justification.

Short and factual. An engineering record, not a changelog.

---

## 12. Known Traps

1. **`res://` is read-only when exported.** Saves go to `user://`.
2. **JSON numbers are floats.** Cast at the `GameData` boundary (section 6.2).
3. **`Area2D` signals fire on the next physics tick**, not instantly on
   spawn. Guard the empty first frame.
4. **`queue_free()` is deferred.** A freed node remains in arrays and prior
   signal results for the rest of the tick. Always `is_instance_valid()`
   before touching a possibly-freed node.
5. **Identity is instance id, not name.** Use `get_instance_id()` or typed
   arrays with `is_instance_valid()` filtering. Never key lookups on node
   names or display names.
6. **Editor-managed files are not text.** Hand-editing `.tscn`/`.tres`/`.uid`/
   `project.godot` can silently desync references. Use the editor, or the
   documented bootstrap scripts.
7. **Pause must freeze everything.** `get_tree().paused = true`; modal
   `CanvasLayer`s set `PROCESS_MODE_ALWAYS`. Missing this on one node produces
   actors that keep moving under a modal.
8. **Headless import is not optional.** After adding scripts/assets run
   `--headless --path . --import` so `class_name` registrations and `.uid`
   associations exist before tests or the editor open the project.
9. **Two coordinate spaces exist as of ADR-032.** Logical grid space carries
   physics, collision, weapon reach, pathing, and saves; screen space is only
   what the camera shows. `global_position` on a gameplay node is *always*
   logical. Feeding a projected value back into gameplay - or comparing one
   space against the other - is the defect this trap exists to catch, and it
   fails subtly: things look almost right until a diagonal.
10. **`y_sort_enabled` sorts only direct children.** A visual parented to its
    own actor rather than to the sort container silently stops participating
    and falls back to tree order. Nesting a second `y_sort_enabled` node
    inside the first sorts that subtree as one unit, not as peers.
11. **Input is screen-relative, facing is grid-relative.** `InputManager`
    hands back a screen-space vector; the rotation into grid space happens
    once, on the way in. A facing value that was never rotated points 45
    degrees off and targets the wrong tile - which reads as "interaction is
    slightly broken", not as an input bug.

---

**Changelog**
- v0.23 (2026-08-10) - ADR-043 (standard 2:1 isometric tile aspect) opened
  by owner ruling, authorizing the proposal-only
  `design/standard_isometric_conversion_guide.md` for implementation.
  **Supersedes ADR-032 only as to the tile aspect ratio** - every other
  ADR-032 ruling (presentation-only projection, the single
  `iso_projection.gd` seam, screen-relative input, 8-way facing,
  `y_sort_enabled` depth ordering, immediate-mode terrain, no-elevation,
  no-save-impact) is restated unchanged, not reopened. Section 1's
  projection pin changes from `64 x 48` dimetric (2:1.33) to `64 x 32`
  standard isometric (2:1); `LOGICAL_CELL` (32) is untouched. Section 2's
  projection bullet and section 8's projection invariant are reworded from
  "dimetric" to "isometric" and now cite ADR-043 alongside ADR-032; no
  other section 2 scope changes. Section 5's directory tree gains
  `design/standard_isometric_conversion_guide.md`. **Why now:** ADR-032's
  shallower angle was chosen for structure headroom before this project
  had any art; ADR-041/ADR-042 have since committed the project to sourced
  and textured art, and a non-standard aspect has no realistic integration
  path against the common `2:1` isometric ground grid modular asset packs
  use. **Existing `64x48` dimetric art does not carry over** - the guide
  explicitly forbids squashing it into `64x32`, so Phase 3 (art migration)
  re-authors/re-sources art at native `2:1` and is gated on an
  owner-approved live representative capture before proceeding past its
  first asset family. Save version unchanged (18) - none is permitted
  under this ADR, identical to ADR-032's own rule. Execution stays with
  `design/standard_isometric_conversion_guide.md`'s phased plan (Phase 0
  this checkpoint; Phase 1 projection foundation; Phase 2 renderer/camera;
  Phase 3 art, owner-gated; Phase 4 integration/regression) rather than
  being duplicated here.
- v0.22 (2026-08-08) - ADR-041 (Art asset integration) opened by owner
  ruling: fifteen purchased/found sprite packs under `SourceArtAssets/`
  are integrated as textured visual proxies for structures, map features,
  actors, and UI, replacing primitive `_draw()` proxies category by
  category. Section 2 gains an Art asset integration bullet and the
  former "Sprites, art assets... geometric primitives only" out-of-scope
  clause is narrowed to audio/particles/shaders - geometric primitives
  stay the default wherever no asset exists, including all of terrain/soil,
  which this ADR explicitly does not touch. Section 5's directory tree and
  autoload-seams list gain forward-looking notes (a static sprite/animation
  lookup, not a new autoload, per the existing DESKTOP-step constraint).
  Section 8 gains a textured-proxy invariant restating that a `Sprite2D`/
  `AnimatedSprite2D` child is exactly as presentation-only as the
  projection it renders through. Section 9.5 is restated to permit
  textured visual proxies for structures/features/actors while terrain
  stays immediate-mode, and to correct ADR-032's now-outdated "geometric
  primitives rule has nothing to fill" framing. **Style unification across
  the fifteen packs is explicitly not required** - the owner ruling
  accepts visible style clash in exchange for integration speed, narrowing
  (not adopting) the existing private `asset_studio/` AI-restyling
  pipeline's own prior plan for this pass. Execution guide:
  `design/sprints/sprint_16_art_integration.md`. Save version unchanged
  (18, ADR-040) - none is permitted under this ADR.
- v0.21 (2026-08-07) - ADR-034 (Region) opened for implementation as
  Sprint 15, per the owner's explicit go-ahead. Section 2 gains a Region
  bullet describing the target nine-zone architecture (Fallowfield,
  Nettleford, the Manor of Harrowmere, the Upland Commons, Cottersward,
  the Nettle Brook corridor, Edith's Plot, the North Strip, the South
  Fields) and its two-pass landing plan (15a: data model/ZoneManager/save
  migration; 15b: transitions/rendering/NPC zone-awareness); the existing
  "Farm grid" bullet is explicitly left as the accurate description of
  today's shipped single-map reality until both passes land. Section 5's
  scene-flow diagram gains a note that zone crossings are in-scene
  (`ZoneManager` swaps world state, no `change_scene_to_file` call, no new
  scene). Section 9.5's world-representation rule is restated as applying
  per-zone once Sprint 15 lands (one `FarmGrid` instance per zone via a
  new `ZoneManager` autoload) - no rule in that section actually changes.
  This amendment is the sprint guide's own stated prerequisite; landing it
  does not itself change any code or save shape.
- v0.20 (2026-08-07) - Festival contest engine implemented (world_bible.md
  Section V realized) and the X6 mercy path implemented (world_bible.md
  Section VII), both via DeepSeek v4 Flash worktree tasks, reviewed and
  independently verified before merge. Section 2's Festivals bullet is
  corrected: it previously said festivals "add no new simulation layer,"
  which the contest engine's `FestivalManager` state machine (a timed
  3-beat press race plus cheer/bet resolution) genuinely is - the one true
  addition beyond reusing existing systems, per ADR-030's own contest
  ruling. No other section 2 wording changes; the mercy path was already
  described as owed, not newly scoped. Also lands, same day: the weekly
  tenure rent mechanic retired in favor of the seasonal held-strip tithe
  surcharge it was double-charging alongside (a dated follow-up to
  ADR-038, `tenure.json` v1 -> v2); a debug-panel Marriage cheat section;
  and three more world-bible Appendix C items closed (Simkin the young
  clerk, the bridge gloss fallback line, Hilda's season-end lines) -
  documented as append-only follow-ups in `design/decisions.md` and
  `design/world_bible.md` rather than edits to already-closed records.
  Full suite: 1234 -> 1360 checks, all green.
- v0.19 (2026-08-07) - Marriage system implemented (ADR-031 realized,
  recorded as ADR-039). New `MarriageManager` autoload (proposal -> merchet
  -> ceremony -> spouse life), registered headlessly via
  `docs/register_autoloads.gd` - no editor session needed. Courtship stays
  on the existing opinion/gifting/requests systems per ADR-031; the new
  work is the state machine and the spouse-life effects (home-based NPC
  schedule anchor, waking greeting, a farm-watering chore, a spouse-only
  gift-cap pool independent of the shared daily cap, spouse-only request
  templates, and the reputation-transfer math specified in
  `design/world_bible.md`). Save version pointer corrected 16 -> 17
  (`SaveManager.SAVE_VERSION` bumped; new `marriage` block, `reputation`
  block gains `pairwise_opinions`/`spouse_gift_count`). No section 2
  wording change - the Marriage bullet already described this shape as a
  forward-looking plan; this entry records that it is now real, the same
  pattern v0.16's Festivals entry followed. New skill
  `.claude/skills/deepseek-consult` packages this project's ad hoc
  DeepSeek-consult pattern (a dozen prior uses across the world bible and
  E1-E6) into a reusable workflow, and records that `deepseek-v4-pro` is
  still gated through Codex as of this date (confirmed live) - consults
  default to `deepseek-v4-flash` instead. Full suite: 1198 -> 1241 checks
  (new `test_marriage` suite, 40 checks; `test_save_roundtrip.gd` updated
  for the v17 migration), all green.
- v0.18 (2026-08-07) - World bible finalized (`design/world_bible.md`) and
  its 17 residual `[OPEN]` items treated and accepted the same day
  (`design/open_items_treatment.md`, X5/X6/X7/X10/X12/X13 all closed - see
  `design/decisions.md` ADR-038). Section 2's Lord tithe bullet corrected
  from the stale "fixed 30-coin assessment" (X12 - never updated when
  ADR-017 landed, then superseded again the same day it was finally caught)
  to the shipped held-acreage shape: base 20 coin + 10 coin per rented
  strip. The Marriage bullet is updated from "once authored" hedging to the
  actual outcome: five candidates (Hilda, Cedric, Marta, Bram, Edith), with
  Osric (the miller) completing ADR-033's eight Tier 1 principals as a
  sixth non-candidate authority figure alongside the priest and steward.
  No other section 2 scope change - the cast, tithe, and merchet rulings
  were already in scope; this entry only corrects and completes their
  description. `AGENTS.md`/`DEEPSEEK.md` regenerated via the real
  generators. Full suite verified green - see `DEVELOPMENT_STATE.md`.
- v0.17 (2026-08-07) - Phase 3 (E6 half) of the Spring Feature Expansion
  implemented (E6 Dynamic Market: full supply-pressure pricing + town board
  orders, ADR-037), per the delivery plan in `design/proposals/
  Proposal_Spring_Feature_Expansion.md` and the owner's restored-scope
  decision note - landed via DeepSeek v4 Flash through the OpenAI Codex CLI,
  working in parallel with the E5 half below in its own git worktree, then
  reviewed and merged. Section 2 gains a Dynamic local economy bullet. Save
  version pointer corrected 15 -> 16 (`SaveManager.SAVE_VERSION` bumped;
  migration additive: tithe.crop_pressure + tithe.active_orders, owned by
  TitheManager like every other market field - E5 needed no save bump of its
  own, so this is the version's only real increment despite both phases
  independently claiming "v0.16" before the merge reconciled the numbering).
  Supply pressure is player-only (no AI farmers), keyed per sold item,
  decayed nightly, and locked into a 0.5x-1.5x price band at market open;
  the town board posts 1-3 in-season orders on market days capped at 3
  active, with quality-agnostic fulfillment and silent expiry. Both fold
  into TitheManager rather than a new autoload (a new autoload needs a
  human-only Project Settings registration - the same DESKTOP-step
  constraint ADR-035 recorded). Two existing suites updated for the
  legitimately-changed fixture/data: test_save_roundtrip (v15 -> v16
  expectations) and test_iso_structures (6 -> 7 fixed fixtures, the new
  town_board tile). One new suite (test_board_orders). Full suite:
  1116 -> (post-merge count, see DEVELOPMENT_STATE.md) checks, all green.
- v0.16 (2026-08-07) - Phase 3 (E5 half) of the Spring Feature Expansion
  implemented (E5 Festivals, ADR-036), landed alongside the parallel E6
  workstream above. Section 2's Festivals bullet needed no wording change -
  it already described the shipped shape accurately as a forward-looking
  plan; this entry just records that the implementation is now real.
  **No save version bump** - festival attendance rides entirely on
  `player.event_flags` (Phase 1), and `FestivalManager` holds no state of
  its own to serialize. `main.gd` and `npc.gd` both needed real edits
  (attendance check mirrors the existing mass-attendance pattern exactly;
  NPC schedule anchor override), correcting R2b's "zero main.gd changes"
  claim - the third phase in a row (after E1, E4) where that specific
  category of claim didn't survive contact with the live code. One new
  suite (`test_festivals`). Full suite: 1091 -> 1116 checks, all green.
- v0.15 (2026-08-07) - Phase 2 of the Spring Feature Expansion implemented
  (E4 Dialogue Engine 2.0, ADR-035), per the delivery plan in `design/
  proposals/Proposal_Spring_Feature_Expansion.md`. Section 2 gains a new
  Dialogue condition evaluator bullet. Save version pointer corrected
  14 -> 15 (`SaveManager.SAVE_VERSION` bumped; migration additive: a new
  top-level `dialogue` block, owned by the new `DialogueManager` autoload,
  not folded into `player`). Fixes the `lines[0]`-of-first-match dead-
  content bug in `main.gd`'s `_on_npc_interacted` - `DialogueManager` is
  reached via `get_node_or_null`, not a bare reference, with the old
  code path kept as a fallback, because the autoload registration this
  needs is a **DESKTOP step still owed** (Project Settings -> Autoload;
  main.gd would fail to parse on a bare reference until it lands). The
  existing 36 dialogue lines were backfilled with explicit `priority`
  values during the v3 -> v4 schema upgrade to preserve their exact prior
  selection behavior - R2a's "no changes needed" assumption didn't hold,
  since multiple reputation-threshold lines can satisfy their `min`
  condition simultaneously and would otherwise tie at the same default
  priority. One new suite (`test_dialogue_engine`). Full suite:
  1041 -> 1091 checks, all green.
- v0.14 (2026-08-07) - Phase 1 of the Spring Feature Expansion implemented
  (E1 Spring Crop Pack, E2 Soil Fertility with compost restored, E12
  Foraging 2.0 with the spade dig mechanic), per the accepted-with-amended-
  scope decision recorded in `design/decisions.md`. Section 2's Farm grid
  bullet gains the four new crops; a new Soil fertility bullet describes
  the fertility/compost system; the Foraging & the commons bullet gains the
  spade's dig_loot mechanic. Save version pointer corrected 13 -> 14
  (`SaveManager.SAVE_VERSION` bumped, migration additive: farm-cell
  fertility, farm.daily_dig_count, player.event_flags). ADR-018's rot
  mechanic changed behavior (spawns a `spoiled_crop` pickup instead of
  destroying the crop outright) - recorded as a new decisions.md entry
  superseding ADR-018's letter, not an edit to that closed record. Three
  new suites (`test_crop_pack`, `test_soil_fertility`,
  `test_foraging_expansion`); one pre-existing suite
  (`test_cooking.gd`) updated where its hardcoded crafted-food id list
  didn't know about the four new recipes. Full suite: 908 -> 1041 checks,
  all green.
- v0.13 (2026-08-07) - X10 amendment: lands the `AGENTS.md` change ADR-033
  (cast expansion and tiering) left owed. Section 2's marriage entry (ADR-031)
  no longer names "the four village villagers" as the fixed candidate set;
  candidates are now defined as the ADR-033 Tier 1 principal cast minus the
  priest and steward, who stay excluded on the same fiction grounds ADR-031
  already gave. Today that is unchanged in practice (the two new Tier 1
  principals - the neighbouring tenant and the miller/alewife - are not yet
  authored), but the wording no longer hardcodes a headcount ADR-033 already
  superseded, and a ninth Tier 1 principal is called out as not automatically
  a marriage candidate (a new ADR per ADR-033's own boundary). No other
  section changes; save version unchanged (13) - this is a wording fix, not a
  scope or systems change.
- v0.12 (2026-08-06) - Presentation amendment (ADR-032), by owner ruling:
  **the game is dimetric, not top-down.** Section 1 pins the `64 x 48` screen
  tile and restates the logical cell as `32`. Section 2's vision line changes
  from "2D top-down" to "2D dimetric" and records that the three named
  inspirations are orthogonal 3/4 top-down, so the projection is a deliberate
  departure from them; the in-scope list gains the projection seam and
  restates player movement as screen-relative input. A new out-of-scope line
  bans elevation in every form (height values, z-levels, slopes, storeys,
  jumping, cliffs) - the projection is a flat plane drawn at an angle.
  Section 5's tree adds `scripts/globals/iso_projection.gd` and the two
  `design/IsometricConversion*` planning documents. Section 8 gains the
  presentation-only projection invariant. Section 9.5 **drops the
  `TileMapLayer` requirement** in favour of the immediate-mode renderers that
  were in fact built (the TileMapLayer was specified in v0.1 and never
  existed - see DEVELOPMENT_STATE.md), and a new 9.7 defines the projection
  seam, visual proxies, and `y_sort_enabled` depth ordering. Section 12 adds
  three traps (dual coordinate spaces, Y-sort parenting, screen-relative
  input vs grid-relative facing). Player facing widens 4-way -> 8-way, forced
  by the input rotation rather than chosen: the screen cardinals land on grid
  diagonals, so a 4-way facing would strand half of every tile's neighbours.
  Save version unchanged (13) - the
  projection touches no persisted state, and none of ADR-032's work should
  ever require a migration.
- v0.11 (2026-08-06) - Content-scope amendment (ADR-030, ADR-031), by owner
  ruling: **marriage and festivals are no longer out of scope.** Section 2's
  out-of-scope list drops the "Marriage, festivals" clause and the trailing
  "Marriage and festivals remain out of scope" sentence on the ADR-024
  gifting/requests entry; two new in-scope entries describe festivals
  (one per season in `festivals.json`, all four defined in data, Spring
  reachable in the slice) and marriage (courtship plus spouse life; the four
  village villagers are candidates). A narrower boundary replaces the removed
  clause: children, in-laws, divorce, and rival suitors are the new
  out-of-scope line. ADR-030/031 supersede the marriage/festival exclusions
  recorded in ADR-024 and ADR-028; those ADRs' text is unchanged, per the
  append-only rule. Save version unchanged (13) - no save shape change in
  this amendment, though ADR-031's implementation will require one.
- v0.10 (2026-08-06) - Sprint 14 implementation complete (ADR-028):
  AnimalManager (purchase/feed/happiness/product cycles/raid losses), coop
  building + animal panel UI, egg/milk items; save-version pointer corrected
  v12 -> v13 (SAVE_VERSION 13).
- v0.9 (2026-08-06) - Retroactive acceptance of ADR-021 (life skills) and
  ADR-022 (foraging & the commons): both Sprint 8 systems were already built
  and shipped but never formally accepted because neither required a section
  2 amendment; section 2's in-scope list now carries both. ADR-022's
  acceptance condition adds rocks (flint) and lumber (wood) as per-soil
  forage spawn chances (forage.json v2; items.json v6 adds the wood item).
  Save version unchanged (12).
- v0.8 (2026-08-06) - Sprint 14 amendment (ADR-028): livestock (chickens and
  one goat; daily feed/water, shelter, product cycles, happiness-driven
  quality, animals as raid targets) added to section 2's in-scope list; the
  out-of-scope clause narrowed to marriage and festivals. Save version
  unchanged (12) - no save shape change in this amendment.
- v0.7 (2026-08-05) - Sprint 13 amendment (ADR-027): skill-gated crafting at
  built stations (drying shed, hearth), cooking, and preservation (drying,
  salting, ale) added to section 2's in-scope list; the out-of-scope clause
  narrowed to livestock, marriage, and festivals ("full crafting, cooking
  recipes" removed). Corrected the save-version pointer in section 2 (v11 ->
  v12, current as of SaveManager SAVE_VERSION 12).
- v0.6 (2026-08-05) - Sprint 12 amendment (ADR-026): dynamic raid scaling
  (deterrence-driven frequency; archer/leader/night-raid variants; fence,
  guard-dog, and hired-guard defenses), the full thief investigation (clues,
  alibis, accusation via dialogue, manor-court false-accusation path), and
  combat injuries persisting past sleep added to section 2's in-scope list;
  the deferred-dynamic-combat out-of-scope clause removed. Corrected the
  save-version pointer (v10 -> v11, current as of SaveManager
  SAVE_VERSION 11) and the stale version header, which still read v0.4 after
  the v0.5 changelog entry.
- v0.5 (2026-08-05) - Sprint 11 amendment (ADR-025): manor court, corvee,
  black market, and price drift added to section 2's in-scope list; the
  out-of-scope clause narrowed to deeper manor politics beyond those
  approved systems. Corrected the save-version pointer (v9 -> v10, current
  as of SaveManager SAVE_VERSION 10).
- v0.4 (2026-08-05) - Sprint 10 amendment (ADR-024): NPC schedules, gifting,
  requests, and chapel mass added to section 2's in-scope list; marriage and
  festivals remain out of scope. Also corrected the stale save-version
  pointer in section 2 (v2 -> v9, current as of SaveManager SAVE_VERSION 9).
- v0.1 (2026-08-05) - Initial contract for Tithe & Turnip, greenfield.
  Modeled on TheAscentGoDot's harness pattern (generated AGENTS/DEEPSEEK,
  hand-rolled test suites, data-driven JSON). Vertical-slice scope defined.
- v0.2 (2026-08-05) - Design interview locked (5 rounds, Pro-assisted).
  Spring-only slice (14-min days, 28-day seasons, season-end summary);
  moisture/soil farming on a 30x20 property; quality tiers + seed recovery;
  tool tiers; three-avenue lord tithe + voluntary church tithe; energy-based
  labor chore list; two-day manor market with toll; two-layer reputation;
  seasonal weather; approved combat (real-time melee/ranged; spear slice
  proof; scripted day-15 bandit raid; one thief villager). ADR-002..014
  recorded in design/decisions.md.
- v0.3 (2026-08-05) - Post-slice roadmap (design/roadmap.md, Sprints 6-14)
  drafted with ADR-015..028 recorded as Proposed. ADR-020 (save-slot UI)
  accepted as part of Sprint 7: dropped "Multiple save slots UI" from the
  out-of-scope list in section 2. `SaveManager` already wrote to named
  `user://save_<slot>.json` files (section 7); this amendment authorizes
  building UI on top of that, nothing else in section 2 changed.
