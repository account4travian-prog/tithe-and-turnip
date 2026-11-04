# Development State - Tithe & Turnip

## What is built

### Wave 0 - Harness + skeleton (2026-08-05)

- `CLAUDE.md` contract; generated `AGENTS.md`/`DEEPSEEK.md` pipeline
  (`docs/make_agents.gd`, `docs/make_deepseek.gd`, `docs/derive_deepseek.gd`).
- `.deepseek/rules/gdscript.md` + `godot-files.md`.
- Hand-rolled test runner (`tests/run_tests.gd`) and suites: contract sync x2,
  time math, crop growth, save roundtrip.
- Autoloads: `GameData`, `EventBus`, `InputManager`, `TimeManager`,
  `PlayerState`, `SaveManager`, `UIManager`.
- Data files: `crops.json`, `items.json`, `villagers.json`, `dialogue.json`,
  `time.json`, `player.json`.
- Headless project bootstrap (`docs/bootstrap_project.gd`) - the documented
  exception to the never-hand-edit rule for `project.godot`/initial scenes.

## What is next

> **Superseded - see the tail of this file for actual current state
> (2026-08-07).** The Wave 1-5 plan below is Day-0 planning text from the
> original vertical-slice design; Sprints 1-14, ADR-032 (dimetric
> projection), ADR-033 (cast tiering), ADR-034 (region, deferred), and the
> X10 contract amendment have all since shipped - see this file's most
> recent dated entries and `design/decisions.md` for what actually happened.
> The next open item as of this note is deciding what to build from the
> accepted-with-amended-scope Spring Feature Expansion package
> (`design/proposals/Proposal_Spring_Feature_Expansion.md`, decision note in
> `design/decisions.md`). Left in place below for historical record, not as
> a live plan.

The Spring slice is fully designed (CLAUDE.md v0.2, ADR-002..014). Planned
waves:

1. **Wave 1 - Data + core systems**: update data files to v2 schemas
   (time/crops/items/player/soil/farm_map/quality/tools/tithe/market/reputation/
   weather/church/chores/enemies/raids), then build `FarmGrid` (moisture, soil,
   growth), tools, and weather.
2. **Wave 2 - Economy & obligations**: manor market (two days/week, toll),
   lord tithe (three avenues), labor chore list, church tithe.
3. **Wave 3 - Reputation & NPCs**: two-layer reputation, steward dialogue,
   priest, village NPCs.
4. **Wave 4 - Combat proof**: weapons (spear slice proof + bow/arrows),
   scripted day-15 bandit raid, one thief villager.
5. **Wave 5 - Slice completion**: season-end summary screen, save v2
   roundtrip, balance pass.

Before Wave 1: open the project in the Godot editor once to confirm the
regenerated files import cleanly.

## Design interview locked (2026-08-05)

- Five-round Pro-assisted interview (deepseek-v4-pro, effort max) produced the
  Spring-slice design; all rulings recorded in ADR-002..014 and the contract
  (CLAUDE.md v0.2). AGENTS.md/DEEPSEEK.md regenerated; contract-sync suites
  pass.
- Deltas from Wave 0: 14-min days / Spring-only slice; moisture-based growth +
  soil regions; quality tiers + seed recovery; tool tiers; three-avenue lord
  tithe + voluntary church tithe; energy-based labor chore list; two-day manor
  market + toll; two-layer reputation; seasonal weather; approved combat
  (real-time melee/ranged, spear slice proof, scripted day-15 raid, one thief
  villager).

## Open questions and traps that have bitten (cont.)

- New autoloads planned (FarmGrid, WeatherManager, TitheManager,
  ReputationManager, CombatManager, RaidManager) - reflect in contract once
  built.
- Projectile collision layer (proposed layer 6) must be added to
  `scripts/globals/physics_layers.gd` when combat is implemented.
- Economy needs a tuning pass before Wave 2: seed/weapon prices in the v0.3
  schema drifted from earlier values; soil quality odds corrected so loamy is
  best and rocky worst (Pro's first pass had them inverted).
- TileMapLayer (4.3+) rendering for the 30x20 soil map is still unverified in
  4.7.1; the farm map can live in data regardless.
- Labor credit has two competing formulations in earlier Pro passes (per-energy
  vs per-chore); ADR-013 locks per-chore credit with a daily energy cap.

## Vertical slice sprint plan (locked 2026-08-05, Pro-assisted)

Full Pro output: `%USERPROFILE%\.codex\visualizations\2026\08\05\019fd15b-7632-71c0-9920-daf86e370b80\sprint_plan_out.md`.
Summary below is the working plan. Routing: CAPABLE = v4 Flash implements
directly; NOT CAPABLE = v4 Pro authors the core file first, Flash applies.
Headless Godot commands on this machine must run escalated.

### Sprint 1 - Data & infrastructure backbone (S, 1-2 wks)

- Write/update all data files to v2 schemas: crops, items, time, weather,
  soil_types (new), farm_map (new, 30x20), market (new), tithe (new),
  chores (new), church (new), reputation (new), villagers v2, enemies (new),
  raids (new), dialogue v2. INT_KEYS lists per file (contract rule 6.2).
  time.json v2: `real_seconds_per_game_minute: 0.78`, keep
  `minutes_per_hour: 60`, add `days_per_week: 7`, `weeks_per_season: 4`,
  `calendar_events` hook. Cabbage `season: "summer"` only (not plantable in
  Spring).
- Expand `GameData` loaders + typed lookups (get_crop, get_soil, weather,
  market_day, chore, etc.). CAPABLE.
- Create stub autoloads: WeatherManager, TitheManager, ReputationManager,
  CombatManager, RaidManager (script files CAPABLE; Project Settings ->
  Autoload registration = HUMAN editor work).
- Save v2: set CURRENT_VERSION = 2, document payload, `migrate_from_v1` stub.
  CAPABLE.
- Gates: headless `--import` clean; existing 45 checks pass; F5 runs, no
  new errors.

### Sprint 2 - Farm & weather mechanics (L, 3-4 wks)

- FarmGrid rewrite: cell = {tilled, crop_id, growth_progress (float),
  moisture (float)}; daily moisture decay by soil; rain sets moisture 1.0;
  growth advances on day_passed only when moisture in crop range; harvest
  rolls quality (soil-weighted) + 1-3 seeds. NOT CAPABLE (Pro authors the
  file; Flash applies).
- Tools integration: tier lookups (area/energy/water), watering-can capacity
  + well refill (well.gd; well node placed by HUMAN in editor). CAPABLE.
- WeatherManager: seasonal roll, `weather_changed` signal, snow blocks
  tilling (Spring data-only). CAPABLE.
- Season restriction tooltip ("in season later"). CAPABLE.
- New suites: test_farm_moisture.gd, test_weather.gd (follow existing suite
  shape: `run(harness)` API, registered in run_tests.gd SUITES). CAPABLE.
- Gates: import clean; >=60 checks; manual: till/water/grow/harvest with
  quality + seeds, rain day wets all, cabbage tooltip, well refill.
- Divergence (deliberate, recorded): slice farm rendering uses ColorRect /
  draw_rect instead of TileMapLayer until the 4.7 TileMapLayer API is
  verified; terrain data stays in farm_map.json regardless.

### Sprint 3 - Economy & obligations (M, 2-3 wks)

- TitheManager implements: market stall (market days, buy seeds/tools/
  weapons, sell crops at assize x quality - 5% toll), lord tithe (coin,
  in-kind crops, labor chores with daily credit cap), church donations
  (chapel tithe box). NOT CAPABLE (Pro authors the flow; Flash applies).
- HUD: tithe progress + health/energy/money labels. CAPABLE.
- Editor (HUMAN): MarketStall node, Steward NPC node, ChapelTitheBox node.
- New suites: test_market.gd, test_tithe_labor.gd, test_church.gd. CAPABLE.
- Gates: import + tests green; manual: market day buy/sell with toll, coin +
  in-kind + labor tithe paths, church standing bump, chores reset next day.

### Sprint 4 - Reputation & NPCs (M, 2-3 wks)

- ReputationManager: community standings (manor/village/church) + individual
  opinions; modify/get APIs; init from save. CAPABLE.
- Dialogue engine: reputation-aware lines from dialogue.json (threshold
  branches). NOT CAPABLE (Pro designs evaluation; Flash implements).
- NPC base scene (HUMAN editor) + villager presence (steward by manor, priest
  by chapel, villagers wander). CAPABLE.
- Reputation hooks on existing actions (market, tithe, church, attacks).
  CAPABLE.
- New suite: test_reputation.gd. CAPABLE.
- Gates: dialogue changes with standing; standing updates via debug overlay.

### Sprint 5 - Combat, season-end, slice completion (M-L, 3-4 wks)

- CombatManager: weapon reach/cooldown/energy, melee hitbox, bow projectile
  + ammo (layer 6), enemy AI, player health 50 / pass-out. NOT CAPABLE (Pro
  authors the full system; Flash applies).
- RaidManager: scripted day-15 raid (bandit_melee; spear as slice weapon),
  deterrence hooks; thief villager (scripted night, accuse via dialogue,
  reputation consequences). NOT CAPABLE for raid core; CAPABLE for thief
  event.
- Season-end summary screen (pause, stats, Restart/Quit). CAPABLE.
- Save v2 migration + roundtrip. CAPABLE.
- Editor (HUMAN): Bandit scene, arrow Projectile scene, RaidSpawnPoint,
  SeasonSummary CanvasLayer, "attack" input action.
- New suites: test_combat.gd, test_save_v2_migration.gd,
  test_season_end.gd. CAPABLE.
- Gates: import clean; >=100 checks; full 28-day manual playthrough:
  farm -> market (buy spear day 7) -> raid day 15 -> thief night -> tithe ->
  day 28 summary -> restart/quits cleanly; save/load roundtrip; window
  resize OK.

### Definition of done (whole slice)

All v2 data loads; full farm loop (till/plant/water/moisture/soil/quality/
seeds); tools + well refill; weather (rain auto-water, snow data-only);
market on scheduled days with toll; lord tithe via coin/crops/labor + HUD
progress; church donations; two-layer reputation with NPC dialogue; combat
proof (spear, day-15 raid, thief accusation); season-end summary; save v2
roundtrip + v1 migration; all suites green (>=100 checks); manual full-season
playthrough clean; DEVELOPMENT_STATE.md updated with any engine surprises.

### Estimates & concurrency

Solo dev: ~12-16 weeks total (S1 1-2, S2 3-4, S3 2-3, S4 2-3, S5 3-4).
Critical path: S1 -> S2 -> S5. S3 and S4 can partially overlap. Best
concurrency: Pro authors a core file (FarmGrid, TitheManager, CombatManager)
while Flash creates data/boilerplate and test scaffolding around it.

## Sprint spec chain (2026-08-05, 5-chain Pro session)

Five sequential Pro passes produced implementation-ready specs, one per
sprint. Files:

- Sprint 1 (data & infrastructure):
  `chain1_sprint1_out.md` in the session visualization folder.
- Sprint 2 (farm & weather):
  `chain2_sprint2_out.md`.
- Sprint 3 (economy & obligations):
  `chain3_sprint3_out.md`.
- Sprint 4 (reputation & NPCs):
  `chain4_sprint4_out.md`.
- Sprint 5 (combat, season-end, save v2):
  `chain5_sprint5_out.md`.

Review corrections to apply during implementation (specs drifted from locked
designs in places):

- Weapon stats: revert to the locked round-5 table (fists 2/20px, knife 5/30,
  staff 8/60, spear 12/90, pitchfork 15/100, bow 10 ranged, arrows ~2). Chain
  1 rebalanced (spear 80px, knife dmg 12) - rejected.
- Cabbage: `seasons: ["summer"]` only (locked). Chain 1 listed spring/summer/
  autumn - rejected.
- JSON examples must be pure JSON - strip `//` comments (Godot JSON.parse
  rejects them); the spec examples are jsonc, not json.
- `calendar_events` stays an EMPTY hook; market days come only from
  market.json, the day-15 raid only from raids.json (Chain 1 duplicated them
  into calendar_events - dual source of truth).
- Chores: locked chores.json design - demesne till/water/harvest/carry tasks
  with tile requirements and daily population. Chain 3 drifted to generic
  always-available chores (chop wood, muck stable - mucking implies livestock,
  out of scope) - rejected.
- Tool data standardized in items.json (Chain 1); Chain 2 references a
  separate tools.json - resolve to items.json.
- Chain 3 spec names `labor_chores.json`; the contract/sprint plan name is
  `chores.json` - use chores.json.

First Chain 1 attempt truncated (finish_reason=length, 0 answer chars);
rerun at --max-tokens 32768 succeeded. Subsequent chains ran at 32768 with no
truncation.

## Sprint 1 progress + wiring decision (2026-08-05)

- **Desktop-control wiring assessment:** the computer-use plugin is installed
  but this agent session does not expose the trusted node_repl/native-pipe
  runtime it requires (`Windows Computer Use Sky runtime is unavailable`).
  Editor wiring by desktop control is therefore not possible in this session.
- **Programmatic wiring (option 2) rejected:** `.deepseek/rules/godot-files.md`
  explicitly forbids script-based modification of `project.godot` and states
  the bootstrap exception must not be extended. Making it safe would require
  amending a deliberate safety rule; the user chose option 1 (human editor
  wiring with exact steps) per the conditional.
- **Done:** five Sprint 1 autoload stubs created under scripts/autoloads/
  (weather_manager, tithe_manager, reputation_manager, combat_manager,
  raid_manager) with the API contract from the Chain 1 spec. Headless import
  clean (`.uid` files generated); test suite 45/45 still green.
- **Pending (human, editor):** register the five singletons in Project
  Settings -> Autoload. Exact steps in the response that created the stubs.

## Sprint 1 implementation complete (2026-08-05)

- All 16 v2 data files written (crops, items, time, weather, soil_types,
  farm_map, market, tithe, chores, church, reputation, villagers, enemies,
  raids, quality_tiers, dialogue) per the Pro schema-lock (chain + Sprint 1
  lock pass) with review corrections.
- `GameData` rewritten: loads every file, casts INT_KEYS at the boundary
  (incl. nested market/farm/raid fields), and exposes the typed lookup API
  (get_crop, get_soil_at, is_market_day, get_scripted_raids, get_quality_tier,
  get_dialogue_for, etc.).
- `SaveManager` v2: SAVE_VERSION 2, v1->v2 migration (health/tools/weapon/
  tithe/church/reputation/combat defaults; farm tiles -> cells conversion),
  refuses newer versions.
- Tests: save roundtrip suite updated to v2 (+ migration), new
  test_game_data_smoke.gd (16 checks), runner updated. Full suite: 69 checks
  pass headless. Headless import clean.
- Divergences recorded: quality data file is `quality_tiers.json` (contract
  text says "quality" without pinning a file name); moisture scale is 0-100
  ints in crops.json with per-day decay floats in soil_types.json; reputation
  standings default to neutral 50; `opinion_delta` added to attack_villager
  for Sprint 4; iron tools normalized to same-or-lower energy cost than wood;
  water amounts 25/30 so a single watering lands inside crop moisture ranges.
- Vision bridge (computer-use): `list_apps`/`list_windows` work via the
  bundled @oai/sky, but window capture for the running Godot editor fails with
  a persistent stale-handle error (window id no longer belongs to the app) on
  every re-bind; stopped per the skill's recovery guidance. Autoload
  registration was confirmed via project.godot read-back instead.

## Sprint 1 remaining (next)

- Register the five autoloads is DONE (human, confirmed in project.godot).
- Open the project in the editor once and press F5 to confirm the new
  GameData/SaveManager boot with zero errors (editor may prompt to reload).
- Sprint 2: FarmGrid v2 (moisture/soil/quality/seed recovery), tools, weather
  manager, farm rendering - per Chain 2 spec.

## Sprint 2 complete (2026-08-05)

- FarmGrid v2 (scripts/world/farm_grid.gd): cells {tilled, crop_id,
  growth_progress 0-1, moisture 0-100, soil}; till/plant (season-checked)/
  water/harvest; soil-aware moisture decay; moisture-gated growth on
  advance_day; quality roll (crop weights + soil bonuses, clamped/normalized);
  seed recovery; to_dict/from_dict (farm.cells shape); configure_for_test
  injection. Authored by Pro (Chain 2), applied with review fixes.
- ToolManager (scripts/world/tool_manager.gd): hoe (single/3x1 areas),
  watering can (capacity + water level), seed planting (consumes seed +
  plant energy), bare-hand harvest; energy via PlayerState.
- WeatherManager (scripts/autoloads/weather_manager.gd): seasonal daily roll,
  is_raining/is_snowing, save shape, configure_for_test.
- FarmRenderer (scripts/world/farm_renderer.gd): soil colors, till darkening,
  moisture overlay, crop dots, grid lines; redraw on tile_changed.
- player.gd: facing tracking, interact -> use_tool on faced tile, equip keys
  1/2/3; main.gd: creates renderer at runtime, day rollover = weather first
  then farm advance.
- Verification: headless import clean; 126/126 checks pass (crop_growth 17,
  farm_moisture 38, weather 9 + prior suites); boot smoke (--quit-after 20)
  exit 0, no errors.
- Divergences/traps recorded: (1) equip actions (keys 1/2/3) registered at
  runtime via InputMap API so project.godot stays untouched - documented in
  input_manager.gd; (2) rain fills planted cells to the crop's moisture max
  (a plain 100 would exceed crop maxes 60-80 and block growth); (3) FarmGrid
  saves as farm.cells (save v2 shape; v1 tiles migrated by SaveManager);
  (4) test-compiled scripts must reach autoloads via get_node_or_null -
  bare singleton names fail to compile in the --script test context;
  (5) GDScript lambdas capture locals by value - the weather signal test uses
  a member callback; (6) watering-can capacities raised to 50/90 so one use
  (25/30 water) fits.

## Sprint 3 (next)

Economy & obligations per Chain 3 spec: TitheManager (manor market with two
days/week + toll, lord tithe three avenues, labor chore list, church
donations), HUD tithe progress, MarketStall/Steward/ChapelTitheBox editor
nodes, suites test_market/test_tithe_labor/test_church.

## Sprint 3 complete (2026-08-05)

- PlayerState v3: quality-stacked inventory (item_id -> {quality: count}),
  health/max_health + health_changed, list_inventory, quality-aware eat.
- SaveManager v3: tithe block in the payload; migrations v1 and v2 -> v3
  (inventory dict -> quality array; tithe defaults). Save suite updated.
- TitheManager (Pro-authored, applied with fixes): market (open days, buy
  stall items, sell crops = floor(gross * 0.95) with quality multipliers),
  lord tithe (coin capped at remaining, in-kind at market value no toll,
  labor chores with daily credit cap + tithe cap), church donations
  (coin/crops; donation_made signal; standing application deferred to
  Sprint 4), get_market_info, serialize/deserialize, configure_for_test.
- Interactions: player dispatch on faced-tile features (well -> refill,
  market_zone/chapel/stewards_demesne -> menus). Runtime menus in main.gd
  (number keys select, Esc/0 closes) + HUD labels for Tithe/Market/Message/
  Menu. InputManager registers menu_0..menu_9 runtime actions.
- Verification: headless import clean; 202/202 checks pass (market 23,
  tithe_labor 36, church 15, save 20, + prior suites); boot smoke exit 0.
- Divergences recorded: quality inventory replaces id->count (ADR-005
  enforced early); save bumped to v3; interaction uses feature tiles instead
  of editor-built MarketStall/Steward/ChapelTitheBox nodes (no scene edits);
  church standing multipliers (church.json) intentionally not applied until
  ReputationManager exists (Sprint 4); menu keys share 1-9 with equip keys
  (player suppresses equip while a menu is open).

## Sprint 4 (next)

Reputation & NPCs per Chain 4 spec: ReputationManager (individual opinions +
community standings), reputation-aware dialogue, steward/priest/villager
presence, suites test_reputation. Wire church.json standing multipliers and
combat reputation hooks.

## Sprint 4 complete (2026-08-05)

- ReputationManager (Pro-authored, applied with fixes): standings
  (manor/village/church) + per-NPC opinions, clamped to reputation.json
  threshold extremes; get_standing_label; apply_action with optional
  opinion_delta target; reset_all for tests; get/load_save_data.
- Action hooks wired in TitheManager (skipped in test mode): pay_tithe_fully/
  partial, complete_labor_day, church_donation_large/small (threshold from
  church.json), market_trade (added to reputation.json).
- NPCs: scripts/npc/npc.gd (wandering colored markers), spawned at runtime
  from villagers.json spawn/color data (no editor scenes). Interacting with an
  NPC shows a reputation-aware line via GameData.get_dialogue_for as a HUD
  message (divergence: no pause/dialogue panel; HUD message is the slice UI).
- Save v4: reputation block (standings + opinions); migrations v1/v2/v3 -> v4.
- HUD: Standing line updated on standing_changed.
- Verification: import clean; 233/233 checks pass (reputation 26, save 25, +
  prior); boot smoke exit 0.

## Sprint 5 (next)

Combat, season-end, save roundtrip polish per Chain 5 spec: CombatManager
(spear slice proof, bow/arrows), scripted day-15 bandit raid + deterrence,
thief villager, season-end summary, save v4 roundtrip. Reputation hooks for
defeat_bandit_raid/ignore_raid fire here.

## Sprint 5 complete (2026-08-05) - vertical slice done

- CombatManager (Pro-authored, applied with fixes): fists/staff/spear/
  pitchfork/bow attacks; J or left-click to attack; melee hitboxes and arrow
  projectiles spawned in code (no scene assets); cooldown/energy gates; player
  damage + pass-out penalty (20% coin loss, health 10); villager-attack
  reputation hook.
- Enemy (scripts/world/enemy.gd): seek/attack/flee FSM from enemies.json;
  melee + archer attacks; health bar; bandits and thief markers.
- RaidManager: scripted day-15 raid (2 bandits + 1 archer from raids.json),
  deterrence decay daily, victory +15 deterrence, knockout = loss; day-19
  theft event (30 coin lost + notification; accusation UI deferred/documented).
- Season-end: on leaving Spring, summary message (tithe, crops, coin earned);
  9 restarts the scene, 0 quits. Market adds bow + arrows.
- PlayerState: equipped_weapon, arrows, pass-out count, deterrence, totals,
  theft events; equip keys 4 (spear) / 5 (bow); SaveManager v5 + v4->v5
  migration; player in group "player".
- Verification: import clean; 244/244 checks pass (combat 5, save 31, + prior);
  boot smoke exit 0. Relays: all five chain specs + four authoring passes
  recorded in the session visualization folder.
- Divergences: combat/raid built code-only (no .tscn); thief is notification +
  coin loss (no accusation flow in slice); season-end is a message + keys
  rather than a UI panel.

## After the slice - roadmap Sprints 6-14 (2026-08-05)

The forward plan lives in **`design/roadmap.md`** (scope/sizing/sequencing)
with a full, code-level implementation guide per sprint under
**`design/sprints/sprint_NN_*.md`** (exact data schemas, autoload APIs,
integration points against the current code, save-version deltas, concrete
test assertions - written so an implementing agent has no open questions).
Proposed ADR stubs ADR-015..028 are appended to `design/decisions.md`.
Summary (corrected from the first pass - see below):

| # | Sprint | Size | Markers |
|---|---|---|---|
| 6 | Core loop closure & balance | S-M | - |
| 7 | UI & interaction layer | M | AMENDMENT (save slots only) |
| 8 | Skills, foraging & the commons | M | DESKTOP (1 autoload) |
| 9 | Buildings, storage & land tenure | M-L | DESKTOP (1 autoload) |
| 10 | Village life: schedules, gifting, requests | M | AMENDMENT |
| 11 | Manor politics & the grey economy | M-L | AMENDMENT |
| 12 | Dynamic combat & thief investigation | L | DESKTOP (1 autoload), AMENDMENT |
| 13 | Crafting, cooking & preservation | M-L | DESKTOP (1 autoload), AMENDMENT |
| 14 | Livestock | M-L | DESKTOP (1 autoload), AMENDMENT |

- **DESKTOP** = one ~2-minute autoload registration (Project Settings ->
  Autoload), nothing more. Writing this level of detail into each sprint's
  guide surfaced that the first pass over-assigned DESKTOP to Sprints 7, 9,
  12, 13, and 14 for scene authoring / render layers / placement UI that
  are, on inspection, all runtime-buildable the same way Sprints 1-5 already
  built NPCs, hitboxes, and the farm renderer - corrected in both
  `design/roadmap.md` and each sprint's guide.
- **AMENDMENT** = touches the CLAUDE.md section 2 out-of-scope list; needs a
  contract change plus an accepted ADR before work opens. Sprint 8's ADRs
  (life skills, foraging) do **not** need this - neither system is on the
  out-of-scope list, so ADR acceptance alone gates that sprint. Nothing in
  ADR-015..028 is accepted yet.
- **Defect found while writing the guides, fixed in Sprint 6's:**
  `SaveManager` looks up `FarmGrid` at `/root/FarmGrid`, which never
  resolves in the live scene tree (`FarmGrid` actually lives at
  `/root/Main/FarmGrid`) - farm tile state (tilled/planted/moisture/growth)
  has likely never actually been saved or restored in a real play session.
  `test_save_roundtrip.gd` doesn't catch it because it drives `FarmGrid.
  to_dict()`/`from_dict()` directly, off-tree. Fix is in
  `design/sprints/sprint_06_core_loop.md` section 0 (explicit injection
  from `main.gd`, not a `/root/` path guess) - worth doing on its own if
  Sprint 6 as a whole doesn't start soon.
- Goal is end-game **system** fidelity at restricted **content** - Spring only,
  six villagers, primitives. Systems stay season-aware so unlocking the other
  three seasons is a data change.
- Critical path 6 -> 7 -> 9. Sprint 6 is unblocked and needs no scope decision;
  it closes the contract gaps found in the slice-completion review (no sleep
  caller, no energy restore, no autosave caller, rain/plant moisture trap,
  three-stripe soil map, trivial tithe, compounding seed recovery).
- Sprint 6 also adds `test_season_sim`, a headless 28-day playthrough that
  asserts the tithe is just affordable alongside one tool upgrade - the balance
  regression guard for every later sprint.

## Open questions and traps that have bitten

- **Godot 4.7 treats two GDScript warnings as errors:** `:=` inference from a
  Variant value ("inferred_variant") and "cannot infer the type" when a helper
  has no return annotation. Use explicit types or untyped `var`; never infer
  from a Variant.
- **Autoload scripts must not declare `class_name` matching their autoload
  name** - Godot 4.7 rejects "Class X hides an autoload singleton" as a parse
  error. Autoloads are accessed by singleton name; cross-scripts use
  `get_node_or_null("/root/X")` dynamically. Recorded as CLAUDE.md rule 3.2.
- **`PackedScene.pack()` drops children whose `owner` is not set.** The
  bootstrap's `_save_scene` assigns owners recursively before packing; without
  that, `main.tscn` saved as a lone root node.
- **Headless Godot crashes in the Codex sandbox** because `user://` maps to
  AppData, which the sandbox blocks ("Could not create directory: user://logs"
  -> segfault). All headless runs on this machine must be escalated.
- **JSON numbers are floats at the boundary** - handled at `GameData` load via
  the `INT_KEYS` convention (CLAUDE.md section 6.2). The save roundtrip test
  guards that stages/money survive as ints.
- Flagged: TileMapLayer API is 4.3+; rendering wiring is deferred to editor
  work and has not been exercised in 4.7.1 headless yet.

## Verification state (2026-08-05)

- `--headless --path . --import`: exit 0, no parse errors.
- `tests/run_tests.gd`: ALL SUITES PASSED (45 checks) - contract sync (7),
  DeepSeek contract sync (8), time math (13), crop growth (7), save roundtrip
  (10). Exit 0.
- Boot smoke test: `--headless --quit-after 10` runs main scene + autoloads,
  exit 0, no errors.

## Sprint 7 implemented (2026-08-05) - UI & interaction layer

Built directly against `design/sprints/sprint_07_ui_layer.md`, **concurrently
with Sprint 6 landing in the same session** (both agents editing the repo at
once - see the merge notes below).

- `UIManager` rewritten to a stack API (`open_menu`/`close_menu`/
  `close_top`/`is_open`/`current_menu`/`close_all`, plus `all_menus_closed`);
  `menu_open` kept as a public bool for `player.gd`'s existing check.
- Ten runtime-built `CanvasLayer` panels under `scripts/ui/`: `HudPanel`
  (clock/energy/money/health/tithe/market/weather/equipped+water/standing/
  skills-row/faced-tile tooltip, replacing every procedural label
  `main.gd` used to own), `InventoryPanel` (Equip/Eat, no Drop - no ground-
  item entity exists yet), `ShopPanel`, `TithePanel` (coin/deposit/chores
  sub-view), `ChurchPanel`, `DialoguePanel` (generic `{text, callback}`
  response-option API for future sprints to hand real branching to),
  `PauseMenu` (owns the `get_tree().paused` toggle via its own open/close),
  `SettingsMenu` (window mode, `InputMap` rebinding, text scale - persisted
  to a dedicated `user://settings.json`, deliberately outside
  `SaveManager`/`SAVE_VERSION`), `SeasonSummaryPanel`, and `SaveSlotPanel`.
- **ADR-020 accepted this sprint** (user chose to amend rather than defer):
  CLAUDE.md bumped to v0.3, "Multiple save slots UI" dropped from section
  2's out-of-scope list, changelog entry added. `AGENTS.md`/`DEEPSEEK.md`
  regenerated - **by hand** (Python replicating `make_agents.gd`'s and
  `derive_deepseek.gd`'s exact `derive()` transforms byte-for-byte), since
  no Godot binary is available on this machine to run the real generator
  scripts. Verified no `CLAUDE.md` occurrences survive in either derived
  file's body (outside the DeepSeek harness's own by-design reference), and
  that both derived files are UTF-8/LF like the source. **Not verified
  against the actual `test_contract_sync`/`test_deepseek_contract_sync`
  suites** (no Godot binary) - re-run them before trusting this.
- `Player` gained `get_faced_tile()`/`get_current_tile()`, factored out of
  `_use_tool`'s inline math so the HUD tooltip and tool-use dispatch share
  one implementation.
- `TitheManager` gained public `get_buy_price`/`get_sell_price` preview
  wrappers for the shop panel. **Seam with Sprint 6:** these currently
  duplicate the pre-Sprint-6 buy/sell formula (written before Sprint 6's
  `_compute_buy_total`/`_compute_sell_net` landed); both wrappers carry a
  `TODO(Sprint 6)` comment to delegate to those private helpers instead.
  Confirmed after Sprint 6 landed that both wrapper functions are still
  present with the TODOs intact - **whoever picks this up should point them
  at `_compute_buy_total`/`_compute_sell_net` now that those exist**, this
  was left as an explicit seam rather than resolved automatically to avoid
  fighting a concurrent edit.
- Input: **no new actions registered.** `project.godot` already defines
  `inventory` (Tab/I) and `pause` (Escape) - discovered mid-implementation;
  the sprint guide's plan to runtime-register `open_inventory` and rely on
  a nonexistent `ui_cancel` action was adjusted to use the two actions that
  actually exist. No `InputManager` changes were needed at all this sprint.
- `main.gd` rewritten to wire the ten panels and replace the old `Menu`
  enum / number-key dispatch entirely. **Merged onto Sprint 6's concurrent
  additions** (`_sleep()`, `SaveManager.set_farm_grid_ref`/
  `TitheManager.set_farm_grid_ref` injection calls, the `player_house`
  interaction case, `farm_grid.advance_day(rain, overcast)`) rather than
  overwriting them - read Sprint 6's landed `main.gd` immediately before
  writing the merged version. Also widened the knockout message wiring
  from `CombatManager.player_knocked_out` (combat only) to
  `PlayerState.knocked_out` (fires for `"combat"`/`"exhaustion"`/
  `"exhausted_day"` per Sprint 6's exhaustion ladder) so all three causes
  now surface a message - the old code only ever showed one for combat.
- New suites: `test_ui_manager.gd` (8 checks), `test_settings_persist.gd`
  (2 checks - settings round-trip through a scratch path, cleaned up after).
  Registered in `tests/run_tests.gd` (targeted edit, not a full rewrite,
  since Sprint 6 had already added its own two suites there).
- **Not verified end-to-end** - no Godot binary is available on this
  machine (checked PATH, Program Files, AppData; only editor data dirs
  exist). Every file was written by hand against the established codebase
  conventions and cross-checked against the actual current state of every
  file it touches, including files Sprint 6 modified concurrently during
  this same session, but none of it has been compiled or run. **Before
  trusting this sprint's code:** run `--headless --path . --import`, then
  `--headless --path . --script res://tests/run_tests.gd`, then open the
  project in the editor and walk the manual checklist in
  `design/sprints/sprint_07_ui_layer.md`.
- Known unverified API surface this sprint touches (flag-don't-guess, none
  independently confirmed against 4.7): `Control.set_anchors_preset` +
  `Control.PRESET_FULL_RECT` resolving against the viewport when the parent
  is a `CanvasLayer` (used by every panel's backdrop/centering); `Theme.
  default_font_size`; `OS.get_keycode_string`; `Node._input`/
  `_unhandled_key_input` firing without extra opt-in on a plain
  `CanvasLayer`-derived node. None are 4.5+ deltas as far as I'm aware, but
  none have been run.

## Sprint 6 complete (2026-08-05) - core loop closure & balance

Implemented per `design/sprints/sprint_06_core_loop.md`. ADR-015..019 moved
from Proposed to Accepted in `design/decisions.md` on 2026-08-05 when the
sprint opened (none require a CLAUDE.md amendment).

- **Data:** `player.json` v2 (sleep/exhaustion tunables), `tithe.json` v2
  (acreage scaling + upkeep), `crops.json` v3 (rebalance + `spoil_after_days`),
  `soil_types.json` v2 (retune: sandy fast/fragile, rocky slow/forgiving),
  `farm_map.json` v2 (fragmented soil - checksum loamy 74 / sandy 96 / rocky
  430 of 600; second well at (22,13)), `market.json` v2
  (`standing_price_adjustment`), `reputation.json` (`fail_upkeep` action),
  `dialogue.json` v3 (36 lines: 5 threshold bands x 6 NPCs + fallback each).
- **Scripts:** `TimeManager` `forced_collapse` + `advance_hours` (hour-24
  collapse is the punished day end; sleeping stays penalty-free); `PlayerState`
  exhaustion ladder (2-hour skip then forced sleep), `sleep_restore()`
  (data-driven fraction + health regen), data-driven pass-out penalty;
  `WeatherManager.is_overcast()`; `FarmGrid` plant-time moisture clamp,
  overwater-halves-growth, overcast halves decay, two-stage spoilage via
  `days_mature`; `TitheManager` acreage tithe goal, recurring upkeep,
  shared `_compute_buy_total`/`_compute_sell_net` with toll + standing
  factor; `SaveManager` **section-0 farm-save bug fix** (explicit
  `set_farm_grid_ref` injection replaces the never-resolving
  `/root/FarmGrid` lookup) + `migrate_to_v6`; `main.gd` sleep interaction
  (`player_house`), farm-grid injection, overcast day rollover.
- **Tests:** 244 -> **286 checks**. New `test_sleep_cycle.gd` (21) and
  `test_season_sim.gd` (7; deterministic 28-day playthrough on real data -
  tithe payable, tool upgrade still affordable, <=2 knock-outs). Extended
  `test_farm_moisture` (+4), `test_save_roundtrip` (+5 incl. the farm-save
  regression case), `test_weather` (+2), `test_combat` (+1), `test_reputation`
  (+2 dialogue band/ordering). Updated `test_game_data_smoke` / `test_market`
  / `test_tithe_labor` / `test_combat` for the deliberate rule changes.
  Headless import clean; boot smoke exit 0.
- **Divergences recorded:**
  - `PlayerState` gained a `set_time_manager_ref` injection seam: under
    `--script` no node is inside the active tree during `_initialize`, so
    `/root/TimeManager` cannot resolve for off-tree suites; the seam mirrors
    `SaveManager.set_farm_grid_ref` and the live path is unchanged.
  - `dialogue.json` band lines use explicit `min` thresholds (friendly 50,
    warm 10, neutral -9, cold -49, hostile -100) ordered highest-first with a
    no-condition fallback **last**. The guide's example made the neutral line
    the no-condition line, which would swallow the cold/hostile bands under
    the code's min-only condition check (`get_dialogue_for` + `lines[0]`).
  - Save version: Sprint 6 landed v6 (`days_mature`); the concurrent Sprint 7
    implementation bumped to v7 (skills/forage) on top of it - save tests
    assert 7. The guide's "300/300" estimate was optimistic; enumerated
    coverage lands at 286.
  - `test_season_sim` calls `TitheManager._on_day_passed` by hand (day-holder
    pattern), matching `test_market.gd`.
- **Concurrent Sprint 7 work:** verified against the merged tree - the Sprint
  7 agent rewrote `main.gd` on top of Sprint 6's changes (kept `_sleep()`,
  both `set_farm_grid_ref` calls, `player_house` case, overcast rollover) and
  added `scripts/ui/*` panels + their own suites to `run_tests.gd`. The full
  shared runner currently cannot complete because their `settings_menu.gd:36`
  uses the bare autoload identifier `UIManager`, which fails to compile under
  `--script` (README convention: use `get_node_or_null("/root/UIManager")`).
  Sprint 6 was therefore verified with a temporary filtered runner
  (`tests/run_sprint6.gd`, deleted after use). **Owner of Sprint 7: fix that
  one line, then re-run `run_tests.gd`** - a Godot 4.7.1 binary is available
  at `%USERPROFILE%\Desktop\GoDot\`.

## Fixed a severe live regression in `FarmGrid.from_dict` (2026-08-05)

**Found while reading `farm_grid.gd` to add Sprint 8's forage fields - not
part of Sprint 8's own scope, fixed immediately because it was actively
breaking save/load.** Sprint 6's `days_mature` edit left the cell-restore
block mis-indented as children of `if not _is_within_bounds(pos): continue`
- i.e. nested *after* a `continue` inside the bounds-check branch, so it
only "ran" for out-of-bounds positions (where `continue` had already
exited) and never ran for in-bounds ones. **Net effect: loading any save
restored nothing on the farm grid** - every cell reverted to the empty
default set by `from_dict`'s first loop, silently. This undid Sprint 6's
own section-0 fix for the `/root/FarmGrid` save-path bug in a different
way - the payload was being read correctly, it just never got applied.
Fixed by dedenting the five lines (`var cell := ...` through the
`growth_progress`/`moisture` restore) to be siblings of the `if`, not
children of it. Verify with a manual till-sleep-reload cycle - the exact
same regression test Sprint 6's own guide specifies for the original bug.

## Sprint 8 implemented (2026-08-05) - Skills, foraging & the commons

Built against `design/sprints/sprint_08_skills_foraging.md`, concurrently
with the Sprint 6 agent continuing to iterate in the same repo (confirmed
still active - `tests/run_sprint6.gd` and repeated touches to
`player_state.gd`/`test_sleep_cycle.gd`/`test_farm_moisture.gd` appeared
mid-implementation; none of it touched Sprint 8's files, so no merge was
needed this time, unlike Sprint 7).

- `data/skills.json` (new): farming/foraging/combat/labor, XP thresholds,
  XP sources, per-level absolute effect tables.
- `data/forage.json` (new): per-soil weighted spawn tables, gather energy
  cost, daily spawn chance, concurrent-spawn cap.
- `items.json` v2 -> v3: `wild_herb`, `wild_onion`, `wild_berry` (food),
  `flint` (material, no `energy_base` - Sprint 9 building-cost fodder).
- `GameData`: `SKILL_LEVEL_EFFECT_INT_KEYS`/`FORAGE_INT_KEYS`/
  `FORAGE_SPAWN_ENTRY_INT_KEYS`, `skills`/`forage_cfg` loaded and nested-int
  cast, `get_skill*`/`get_forage_config` accessors.
- `SkillManager` autoload (new) - **DESKTOP: needs Project Settings ->
  Autoload registration, Node Name `SkillManager`, before anything that
  looks it up via `/root/SkillManager` will find it.** XP/level/effect API
  per the sprint guide; `to_dict`/`from_dict` for save.
- `FarmGrid`: `has_forage`/`gather_forage`, a forage-spawn pass folded into
  the existing `advance_day` loop (untilled cells only, respects the
  concurrent-spawn cap), `_pick_forage_item`/`_forage_config`/
  `_count_active_forage` helpers, `forage_item_id`/`forage_yield` added to
  cell shape (`_default_cell`, `to_dict`, `from_dict`), `configure_for_test`
  gained an optional 5th `forage_cfg` parameter (existing call sites, incl.
  Sprint 6's `test_season_sim.gd`, keep compiling unmodified). `harvest()`
  now reads `SkillManager`'s farming `quality_choice_bonus` into
  `_roll_quality` (widened with an `extra_choice_weight` parameter) and
  awards `harvest_<quality>` XP.
- `ToolManager`: bare-hand interact on a forage cell gathers it
  (`_gather_forage` - energy cost from `forage.json` times the foraging
  skill's `gather_energy_cost_mult`, count boosted by `yield_bonus`, awards
  `gather` XP); hoe/watering-can energy cost now multiplied by farming's
  `tool_energy_cost_mult`; successful till/water awards `till_tile`/
  `water_tile` XP.
- `TitheManager.do_chore`: labor skill's `credit_bonus` added to chore
  credit, `daily_cap_bonus` added to the daily cap (`_daily_labor_cap`),
  awards `chore_complete` XP.
- `CombatManager`: both the melee-hitbox path and the `Projectile` hit path
  now multiply damage by combat's `damage_mult` and award `hit_enemy` XP.
  `RaidManager` gained a third connection on each spawned enemy's
  `enemy_died` (alongside the two existing `_on_raid_enemy_resolved`
  bindings) to award `defeat_enemy` XP - `CombatManager.enemy_defeated`
  turned out to be a declared-but-never-emitted signal, so this hooks the
  one place that actually knows an enemy died vs fled instead.
- `SaveManager`: `SAVE_VERSION -> 7`, `skills` payload block,
  `migrate_to_v7` (defaults skills XP to zero, farm cells' forage fields to
  empty/0 for pre-Sprint-8 saves).
- `HudPanel` (Sprint 7 gap closed): `refresh_skills()` existed but was never
  called or connected, since `SkillManager` didn't exist yet when it was
  written - now connects to `leveled_up` and calls `refresh_skills()` once
  in `_ready()`, so the skills row actually populates instead of staying
  permanently blank.
- New suites: `test_skills.gd` (7 checks: threshold crossing, max-level
  clamp, `xp_to_next` at max, effect lookup against real `skills.json`,
  `add_xp_for`, save round-trip) and `test_forage.gd` (6 checks:
  untilled-only spawn, gather clears the cell, gathering an empty cell,
  `max_concurrent_spawns` cap, save round-trip) - both registered in
  `tests/run_tests.gd`.
- **Not verified end-to-end** - still no Godot binary on this machine.
  Every edit was checked for bracket balance, no duplicate function names,
  and tab-consistent indentation by hand; two multi-line `Edit` attempts on
  `combat_manager.gd` failed on tab-count mismatches (my own miscounting,
  not a tool problem) before a byte-exact Python patch confirmed the
  correct indentation and applied cleanly - recorded here as a reminder
  that whitespace-sensitive GDScript edits deserve a `cat -A`/byte check
  before trusting a guessed indentation level. Run `--headless --path .
  --import` then `--headless --path . --script res://tests/run_tests.gd`
  before trusting any of this.

## Fixed the Sprint 7 compile blocker Sprint 6 flagged (2026-08-05)

Sprint 6's completion note reported a real compile failure on
`settings_menu.gd:36`, found with an actual Godot 4.7.1 binary
(`%USERPROFILE%\Desktop\GoDot\`) - that binary is not available in this
session, so this was fixed from the report, not independently reproduced.
The line was a single-line lambda body with no `return`:
`func() -> void: UIManager.close_menu(MENU_ID)`. Pre-existing suites
(`test_church.gd`, `test_combat.gd`, `test_market.gd`, and Sprint 6's own
`test_season_sim.gd`/`test_tithe_labor.gd`) already use the single-line
form successfully - but every one of those has a `return` (`func() -> int:
return 1`). The pattern that broke is specifically the bare-statement,
no-`return` form. Swept every `scripts/ui/*.gd` file plus `main.gd` and
`hud_panel.gd` for the same shape (21 occurrences from Sprint 7's panels,
2 more in `test_ui_manager.gd`) and converted all of them to the
multi-line block form (`func() -> void:` / newline / indented statement),
which is unambiguously valid regardless of the exact single-line grammar
edge case. Also converted the one `-> String: return EXPR` single-line
lambda in `main.gd` even though that shape matches the working pattern
elsewhere, purely to remove doubt.

**Not independently verified against a real compile** - fixed from
Sprint 6's report plus the working/broken pattern comparison above, not
from running it myself. Whoever next has Godot access: re-run
`--headless --path . --script res://tests/run_tests.gd` (no more need for
the filtered `tests/run_sprint6.gd`) and confirm nothing else in
`scripts/ui/*.gd` still fails to parse.

## Sprint 9 implemented (2026-08-05) - Buildings, storage & land tenure

Implemented per `design/sprints/sprint_09_buildings_tenure.md`. ADR-023
flipped from Proposed to Accepted in `design/decisions.md` when the sprint
opened (no CLAUDE.md amendment needed - ADR-007 already covers buildings).
The roadmap table already carried the corrected DESKTOP marker (one
autoload registration only - placement UI and the render layer are
runtime-built like FarmRenderer).

- **Data:** `data/buildings.json` (storage_chest / drying_shed / well_extra /
  fence / cottage_upgrade), `data/tenure.json` (10x10 default plot + three
  strips that partition the 30x20 map exactly - the 600-tile partition is a
  test_tenure check, not just a doc claim), `data/reputation.json` gains
  `fail_rent` (-3 manor).
- **GameData:** `BUILDING_INT_KEYS` / `TENURE_INT_KEYS`; `_load_buildings`
  (enemies-style keyed-dict loader); `tenure_cfg` flat load; nested int
  casts for `cost_materials` / `default_owned_rect` / strip rects;
  accessors `get_building`, `get_all_building_ids`, `get_tenure_data`.
- **BuildingManager autoload (new; DESKTOP registration pending):**
  footprint bounds + overlap validation; coin + material deduction;
  multi-day construction advanced on `day_passed`; `build_days: 0` (fence)
  completes instantly; tenure (default rect + `rent_strip` /
  `is_strip_rented`, 7-day all-or-nothing rent, cheapest-strip eviction
  with a `fail_rent` reputation hook on non-payment); `get_placed_buildings`
  (added beyond the guide - the renderer needs in-progress entries),
  `is_well_at`, `get_sleep_bonus_fraction`, `get_storage_capacity_bonus`,
  `get_deterrence_bonus`; `to_dict`/`from_dict`.
- **Integration:** `FarmGrid.till_tile` ownership gate (ADR-023) + public
  `is_owned` wrapper + a 6th `configure_for_test` parameter `owned_rects`
  (empty = unrestricted, so every pre-Sprint-9 suite is untouched); Player
  well refill accepts a completed `well_extra` at the faced tile;
  `PlayerState.sleep_restore` adds the cottage sleep bonus on top of the
  base fraction; `SaveManager` v8 (`buildings` payload block,
  `migrate_to_v8`); `InputManager` registers `open_build_menu` (B);
  `main.gd` wires `BuildingRenderer` (world layer between soil and player)
  and `BuildingPanel`; `HudPanel` tooltip flags unowned tiles.
- **UI:** `BuildingPanel` (Build tab: select -> placement mode, ghost
  follows the faced tile, Interact places; Tenure tab: rent strips), a
  runtime CanvasLayer per the Sprint 7 pattern. `BuildingRenderer`: flat
  colors per building, in-progress dim + hatch, green/red placement ghost.
- **Tests:** `test_buildings` (33 checks), `test_tenure` (22 checks,
  including the partition checksum and the FarmGrid till-gate integration);
  save roundtrip updated to v8 (39); game_data smoke +8. **Full runner:
  404/404 checks ALL SUITES PASSED**, boot smoke `--quit-after 20` exit 0,
  headless import clean. This is also the first-ever compile/run of the
  Sprint 7/8 code - see the blockers fixed below.

**Pre-existing blockers fixed to get the runner green** (Sprints 7-8 code
was never compiled - the handoff explicitly told the next session to run
`run_tests.gd` and fix whatever failed to parse):
- `skill_manager.gd:51,64`: `var thresholds :=` inferred from a Variant
  (call through a `Node`-typed receiver) - the known Godot 4.7
  inferred-variant error. Explicit `Array` type.
- `test_skills.gd` / `test_forage.gd`: the same `:=`-from-Variant class of
  error in six places.
- `settings_menu.gd`: bare `UIManager` identifier fails to compile in the
  `--script` harness context (established trap: test-compiled scripts must
  reach autoloads via `get_node_or_null`). Replaced with guarded lookups;
  live-game behavior unchanged.
- `test_ui_manager.gd`: the `all_menus_closed` counters used lambdas that
  mutated a captured local (GDScript lambdas capture locals by value - the
  documented trap). Switched to Array-based counters; this fixed the two
  failing checks in that suite.

**Divergences / notes:**
- Rent is all-or-nothing per interval: pay the combined total or the
  cheapest rented strip is evicted; no partial-payment logic (the guide's
  explicit design).
- Eviction never untills or repossesses; tilled tiles keep functioning even
  after their strip's rent lapses (ADR-023 scope).
- `storage_chest` capacity and `fence` deterrence expose getters but are
  inert until a future consumer exists; `drying_shed` has no effect field
  until Sprint 13. Said plainly: storage reserves a tile and nothing else.
- `_rect_contains` manual bounds check used instead of `Rect2i.has_point`
  (the guide's own documented fallback - avoids depending on an unverified
  4.7 API per the API-confidence rule).
- `BuildingManager` is the first autoload whose `_ready` depends on another
  autoload's boot order (it connects `TimeManager.day_passed`) - register it
  AFTER TimeManager.
- The `Can't use get_node() with absolute paths` errors in the headless log
  are the pre-existing off-tree suite noise; `sleep_restore`'s new
  BuildingManager lookup adds one line per call. Harmless.
- `SkillManager` from Sprint 8 is **still not registered** in project.godot
  as of this sprint; F5 play has no skills/XP until it is. `BuildingManager`
  is the new pending registration.

### Sprint 9 remaining work (finish-anytime list)

Full copy lives in `design/sprints/sprint_09_buildings_tenure.md` under
"Status & remaining work"; this block is the quick reference.

1. **DESKTOP (human, ~2 min):** register `BuildingManager` in Project
   Settings -> Autoload. Node Name `BuildingManager`, path
   `res://scripts/autoloads/building_manager.gd`, listed **after**
   `TimeManager` (its `_ready` connects `TimeManager.day_passed`). Until
   registered, live tilling is unrestricted and the build panel shows a
   "not registered" hint.
2. **DESKTOP (human, ~2 min):** register Sprint 8's still-missing
   `SkillManager` (path `res://scripts/autoloads/skill_manager.gd`) - F5 play
   has no skills/XP until it lands.
3. **Editor verification (human, after registrations):** walk the manual
   checklist in the sprint guide (till-gate, rent, placement, fence,
   well_extra refill, cottage sleep bonus, rent-day eviction + rep drop,
   save/reload persistence, window resize). The headless suites cover the
   model layer only; none of the UI has been exercised in a live editor.
4. **No action now, but know why:** `storage_chest` capacity and `fence`
   deterrence are forward-declared getters (inert until an inventory cap or
   Sprint 12's raid deterrence); `drying_shed` has no effect field until
   Sprint 13. Do not invent effects to make them do something.

UI mockups for the title/HUD/pause screens (2026-08-05): the reference file
is preserved at `design/ui_mockups/tithe_and_turnip_ui_mockups.dc.html`;
the palette + layout were incorporated into the runtime UI in the follow-up
pass below.

## UI reference pass (2026-08-05) - mockups incorporated

The UI mockup file (title screen, in-game HUD, pause menu) was incorporated
into the runtime UI. Reference preserved at
`design/ui_mockups/tithe_and_turnip_ui_mockups.dc.html`.

- **UIKit theming** (`scripts/ui/ui_kit.gd`): palette constants (wood-dark
  bg, parchment, ink, border, gold, health/vigour/church accents); styled
  buttons (dark ink + gold hover, danger variant, full-width option);
  parchment `make_card`; `ProgressBar`-based `make_bar`; dark `make_pill`
  with accent dots; gold `make_toast`; backdrop darkened to the mockup's
  overlay tone. Every modal panel picks these up automatically.
- **HudPanel** rewritten to the mockup layout: top-left parchment date card
  ("Day 4 of Spring · Year 1" + "6:14 in the morning") with weather pill and
  Roman-numeral skills pill; top-right coin pill, "LORD'S TITHE" card with
  gold progress bar, and market pill; bottom-left HEALTH/VIGOUR bars plus
  Manor/Village/Church pills; bottom-center gold message toast, parchment
  tile tooltip ("LOAMY SOIL · well-watered · Turnip — 45% to harvest"),
  6-slot hotbar (equip highlight, can water bar, stack count badges), and
  key hints (I/Tab Satchel, Esc Pause, E Work the Land).
- **PauseMenu**: parchment card with "Resume Toil" / "Options" / "Keep
  Record" / "Keep As..." / "Leave the Farm" and a day/time subtitle.
- **Title screen**: dark backdrop, 72px gold "TITHE & TURNIP", tagline
  "A Peasant's Portion, Sworn to Spring", menu items "Begin a New Life" /
  "Return to the Farm" / "Leave the Manor", and the "Vertical Slice —
  Spring, Year 1" footer. "Return to the Farm" loads the autosave via a new
  `SaveManager.pending_load` seam consumed at the end of `main.gd._ready()`
  (farm-grid injection is wired by then, so the payload lands on live
  nodes); `HudPanel` refreshes on `SaveManager.game_loaded`.
- **Divergences recorded:** mockup fonts (Cinzel/Spectral) are not embedded
  - no asset import; sizes/colors carry the theme. Hotbar contents are
  data-driven (equipped tool / can / seed / weapon / bow / arrows) rather
  than the mockup's illustrative items. The other modal panels keep the dark
  backdrop + themed buttons instead of parchment cards (cards only where the
  mockup specifies them - avoids a light-on-parchment readability pass).
  "Options" is omitted from the title screen; the settings panel only exists
  inside the farm scene. ProgressBar "background"/"fill" stylebox theming
  and `get_viewport().get_visible_rect()` were verified against 4.7.1
  (`get_viewport_rect()` is gone in 4.x - caught by the compiler).
- **Verification:** headless import clean; full runner 404/404 checks pass;
  boot smoke (`--quit-after 20`) exit 0 for both `main.tscn` and
  `title_screen.tscn`, no errors/warnings. Visual layout was NOT eyeballed
  in a live editor - the manual checklist in sprint_07's guide (resize
  legibility, panel readability on the new palette) still needs one human
  pass.

## Sprint 10 implemented (2026-08-05) - Village life: schedules, gifting &
requests

Implemented per `design/sprints/sprint_10_village_life.md`. ADR-024 flipped
from Proposed to Accepted and CLAUDE.md bumped to **v0.4** (NPC schedules,
gifting, requests, and chapel mass added to section 2's in-scope list;
marriage and festivals remain out of scope; stale save-version pointer
corrected v2 -> v9). AGENTS.md/DEEPSEEK.md regenerated with the real
`docs/make_agents.gd`/`docs/make_deepseek.gd` generators - the Godot 4.7.1
binary is available at `%USERPROFILE%\Desktop\GoDot\`, so no hand
replication this time.

- **Data:** `villagers.json` v4 (every villager gains `schedule`
  home/work/start/end, `likes`, `dislikes`; Marta keeps her thief trait -
  untouched per ADR-026's ownership of traits); `requests.json` (new: 6
  templates, `max_active_requests: 2`, `new_request_chance_per_day: 0.35`);
  `reputation.json` v2 (`attend_mass`: manor 0 / village 1 / church 5).
- **GameData:** `REQUEST_INT_KEYS`, `requests_cfg` loaded + nested int casts
  (per-template quantity/days_to_complete/reward_coin/reward_opinion),
  villager schedule `work_start_hour`/`work_end_hour` cast in
  `_cast_nested_ints`, `get_villager_schedule(id)` and
  `get_requests_config()` accessors.
- **NPC** (`scripts/npc/npc.gd`): schedule-aware anchoring - `_home_pos`/
  `_work_pos` from villagers.json, `_update_anchor(hour)` switches the
  wander anchor at the work window boundary (start inclusive, end
  exclusive), driven by `TimeManager.minute_passed`. Villagers with no
  schedule fall back to their spawn as a static anchor.
- **ReputationManager:** `gift_item` (liked +10 / disliked -6 / neutral +2,
  `DAILY_GIFT_CAP` = 1, consumes the item), requests (`_maybe_offer_request`
  on day rollover, `can_complete_request`/`complete_request` for coin +
  opinion), signals (`gift_given`, `request_offered`, `request_completed`,
  `request_expired`), `_on_day_passed_village` (cap reset + deadline tick),
  `configure_for_test` widened with a `player_state` seam + `_player()`
  accessor mirroring TitheManager, and `active_requests`/
  `daily_gift_count` in the save block.
- **main.gd:** NPC interaction builds real `DialoguePanel` responses -
  request line + "Fulfill request" (only when completable) + "Give a gift"
  (opens the inventory in gift mode); mass check on day 21 at hour 9 at the
  chapel tile (one shot per day, `attend_mass` reputation action, no
  penalty for skipping); `TimeManager.minute_passed` connected.
- **InventoryPanel:** `open_for_gift(npc_id)` gift mode - every row's button
  becomes "Gift", a successful gift pops back to the dialogue panel, and
  gift mode resets when the panel closes.
- **SaveManager:** `SAVE_VERSION -> 9` + `migrate_to_v9` (reputation block
  rides inside the existing key; no structural defaults needed).
- **Tests:** new `test_schedules` (19 checks - steward full day sweep,
  priest edge hours, all-six completeness via the real `NPC._update_anchor`
  comparison), `test_gifting` (14), `test_requests` (21 - offer, cap,
  completion, expiry, save roundtrip); `test_save_roundtrip` updated to v9
  (+ active-requests survival check), `test_game_data_smoke` +4. Registered
  in `run_tests.gd`. **Full runner: 463/463 checks ALL SUITES PASSED**,
  headless import clean, boot smoke (`--quit-after 30`) exit 0 for both
  `main.tscn` and `title_screen.tscn`.
- **Divergences recorded:**
  - Request ids are `"req_%d_%d" % [Time.get_ticks_msec(), _request_seq]`,
    not the guide's bare ticks: under rapid headless offers the same
    millisecond can be returned twice, so a later offer reused an expired
    request's id and the expiry test caught a "zombie" request. The seq
    counter disambiguates within a session; ticks keep ids unique across
    sessions.
  - `reputation.json` bumped to version 2 (additive shape change; contract
    rule 6.4) even though the guide didn't call for it.
  - The guide's `main.gd` snippet called `UIManager.open_menu("dialogue")`
    redundantly - `DialoguePanel.show_dialogue` already opens it; omitted.
  - The guide's `_show_message`/`_refresh_time` context lines became
    `hud_panel.show_message` and a no-op respectively (HudPanel owns the
    clock refresh since Sprint 7).
  - `reset_all()` now also clears gift/request state and the request-id
    sequence (test isolation seam; harmless in production, where `_ready`
    seeds it).
  - No new autoload (gifting/requests fold into ReputationManager) and mass
    is a one-`if` check in `main.gd` - both deliberate per the guide, so no
    new DESKTOP registration is pending from this sprint.
- **Still pending from Sprints 8-9 (DESKTOP, human):** `SkillManager` and
  `BuildingManager` are still NOT registered in project.godot as of this
  sprint (confirmed by read-back); F5 play has no skills/XP, no build menu,
  and unrestricted tilling until both land. Sprint 10's headless suites and
  boot smokes do not depend on them.
- **Manual checklist still open (human, editor):** the guide's nine steps
  (villager movement across a day, gift opinion moves + daily cap, request
  fulfillment + expiry, mass day 21/hour 9 at the chapel, save/reload of
  active requests, resize legibility). The headless suites cover the model
  layer; the UI flows are compile- and boot-verified only.

## Sprint 11 implemented (2026-08-05) - Manor politics & the grey economy

Implemented per `design/sprints/sprint_11_manor_politics.md`. ADR-025 flipped
from Proposed to Accepted and CLAUDE.md bumped to **v0.5** (manor court,
corvee, black market, and price drift added to section 2's in-scope list; the
out-of-scope clause narrowed to deeper manor politics beyond those approved
systems; save-version pointer corrected v9 -> v10).
AGENTS.md/DEEPSEEK.md regenerated with the real Godot generators. No new
autoload - everything folds into `TitheManager` per the guide.

- **Data:** `data/manor.json` (court_days [12, 26], fines 15/20, corvee
  chance 0.4 / notice 1 / credit x1.5, black market visit days [9, 20] /
  25% premium / 0.2 base detection / 0.15 standing reduction, price drift
  5%); `reputation.json` gains `fail_corvee` (manor -4) and
  `fail_court_fine` (manor -6).
- **GameData:** `manor_cfg` loaded from manor.json; nested int casts
  (court_days, fines.*, corvee.notice_days, black_market.visit_days) inline
  in `_cast_nested_ints` (same pattern as market/raid/tenure nested casts -
  no dedicated MANOR_INT_KEYS constant); `get_manor_data()` accessor.
- **TitheManager** (ADR-025 owner): `offense_recorded`/`court_held`/
  `corvee_announced`/`corvee_started`/`black_market_status_changed` signals;
  `_pending_offenses`/`_corvee_day`/`_corvee_active`/`_corvee_chore_done`/
  `_todays_price_drift` state; `_ready` connects
  `ReputationManager.action_applied` and queues `witnessed_violence` on
  `attack_villager` (combat code untouched); `_on_day_passed` drives
  corvee fail-check -> activation -> weekly roll, court, price drift, and
  black-market status; `_maybe_run_court` charges summed fines, pays a
  shortfall to zero and fires `fail_court_fine`; `do_chore` applies the 1.5x
  corvee credit multiplier and marks the day worked; black-market sell
  (premium, no toll, no standing/drift adjustment - deliberately a separate
  path from `_compute_sell_net`) with a village-standing-scaled detection
  roll; `_todays_price_drift` folded into `_compute_sell_net`;
  `is_corvee_active()`/`is_black_market_open()`/`can_black_market_sell()`/
  `get_black_market_price()` public API; widened `serialize`/`deserialize`.
- **SaveManager:** `SAVE_VERSION -> 10`, `migrate_to_v10` defaults the five
  tithe-block fields; chain `if version <= 9`. No new top-level key.
- **UI:** HudPanel connects the four manor signals (corvee notice/start,
  court summary, black-market-day toast) plus a fifth, deliberate
  discoverability toast on `black_market_status_changed(true)`; ShopPanel
  gains a Black Market section (visible only on visit days) selling owned
  stacks at `get_black_market_price` with "no toll" labels; `main.gd` opens
  the shop panel on black-market visit days too (days 9/20 are off the
  market cadence, so without the gate the tab was unreachable).
- **Tests:** new `test_court` (15 checks), `test_corvee` (17),
  `test_blackmarket` (17) registered in run_tests.gd; game_data_smoke +9
  (manor lookups + new reputation actions); save roundtrip updated to v10
  (manor fields survive roundtrip, v4 migration defaults). **Full runner:
  527/527 checks ALL SUITES PASSED**, headless import clean, boot smokes
  (`--quit-after 30`) exit 0 for `main.tscn` and `title_screen.tscn` with
  no errors/warnings.
- **Divergences / notes:**
  - **Reputation tests cannot mount at /root.** The guide's "real
    ReputationManager mounted at /root" approach is impossible in this
    harness: suites run synchronously in `SceneTree._initialize()`, where
    nodes added to root report `is_inside_tree() == false` and
    `/root/ReputationManager` lookups throw the documented off-tree error
    and return null (verified with a throwaway diagnostic). Instead,
    `TitheManager.configure_for_test` gained an optional `reputation` seam
    (the same injection pattern every other autoload already uses) and
    `_apply_reputation`/`_roll_black_market_detection` now run whenever a
    real ReputationManager is injected, even in test mode. Pre-existing
    suites never inject one, so their behavior is unchanged. The
    attack->offense integration test wires `rep.action_applied` to
    `tm._on_reputation_action` directly (the live `_ready` wiring is
    exercised by the boot smoke, which does run the real autoloads).
  - **Black-market discoverability:** the guide's HUD section lists three
    messages; I added a fourth (`black_market_status_changed(true)` toast)
    and opened the shop gate on visit days, because a UI-only trader with
    no notice and an unreachable panel would be a silent dead feature.
  - `can_black_market_sell` also guards a null player and requires a valid
    market buy price (prevents negative nets on non-sellable items).
  - `get_black_market_price` preview wrapper added (mirrors Sprint 7's
    `get_sell_price`) so the shop rows can show the net without side
    effects; `black_market_sell` delegates to it so the two cannot drift.
  - Detection tests are deterministic by construction (1.0/0.0 base chance
    never needs a randf seed); the standing-reduction check replicates the
    implementation formula directly rather than sampling the RNG.
  - Day-28 announcement edge: `notice_days: 1` can set `_corvee_day = 29`,
    which never activates inside Spring (season ends at 28). Matches the
    guide exactly; noted, not changed.
  - The `Can't use get_node() with absolute paths` lines still in the log
    are the pre-existing off-tree harness noise (SkillManager/FarmGrid/
    BuildingManager lookups on off-tree nodes) - guarded, harmless, and
    documented since Sprint 9.
- **Manual checklist still open (human, editor):** the guide's nine steps
  (attack -> court fine, corvee worked/skipped, black-market sale + eventual
  detection at court, price-drift variance, save/reload mid-corvee-notice,
  resize legibility). The headless suites cover the model layer; the HUD
  toasts and shop tab are compile- and boot-verified only.
- **Still pending from Sprints 8-9 (DESKTOP, human):** `SkillManager` and
  `BuildingManager` remain unregistered in project.godot; F5 play still has
  no skills/XP or build menu until both land. Sprint 11's suites and boot
  smokes do not depend on them.

## Sprint 12 implemented (2026-08-05) - Dynamic combat & the thief investigation

Implemented per `design/sprints/sprint_12_combat_investigation.md`. ADR-026
flipped from Proposed to Accepted and CLAUDE.md bumped to **v0.6**
(deterrence-driven dynamic raids, archer/leader/night-raid variants, fence /
guard-dog / hired-guard defenses, the full thief investigation, and combat
injuries persisting past sleep added to section 2's in-scope list; the
deferred-dynamic-combat out-of-scope clause removed; save-version pointer
corrected v10 -> v11). AGENTS.md/DEEPSEEK.md regenerated with the real
generators. Also fixed a stale CLAUDE.md version header that still read v0.4
after the v0.5 changelog entry.

- **Data:** `raids.json` v2 (dynamic_raid_chance_per_day 0.12, earliest day
  16, size 2-4, night_raid_flavor_chance 0.3 with +1 size, weighted
  dynamic_enemy_pool); `enemies.json` v2 (raid_leader 35hp / 10 dmg / speed
  90 / reach 60); `items.json` v4 (guard_dog 60 coin / +5 deterrence,
  hired_guard 120 coin / +10, new type "defense"); `market.json` v3 (both
  defense items in stall_inventory); `villagers.json` v5 (every villager has
  1-2 flavor traits; villager_3's "thief" is no longer the only non-empty
  array); `clues.json` (new, clue_count 3); `reputation.json` v3
  (accuse_correctly +2 manor/+4 village/opinion -20, accuse_falsely
  -3 manor/-8 village/opinion -10); `player.json` v3 (wound_recovery_days 1);
  `manor.json` v2 (false_accusation fine 15 - see divergences).
- **GameData:** `ITEM_INT_KEYS` += `deterrence_bonus`; `RAID_INT_KEYS` += the
  four dynamic int fields; new `CLUE_INT_KEYS` + `clues_cfg` +
  `get_clues_config()`; `dynamic_enemy_pool[].weight` cast in
  `_cast_nested_ints`; `get_raid_settings()` extended with the typed dynamic
  fields.
- **RaidManager:** effective deterrence (raw + BuildingManager fence bonus +
  owned defense items, presence not quantity; public
  `get_effective_deterrence()`); shared `_spawn_raid` for scripted and
  dynamic paths; `execute_dynamic_raid` (weighted pool, night flavor + size
  bonus); `_maybe_trigger_dynamic_raid` (earliest-day gate, deterrence floor,
  gap-scaled chance); theft resolves the thief from `villagers.json` traits
  via `_find_thief_id` and starts the InvestigationManager; new
  `dynamic_raid_triggered` signal (test/UI hook); the
  `player_knocked_out` connection is guarded with `is_connected` so repeated
  raids don't stack handlers.
- **InvestigationManager** (new autoload script): start/reveal/accuse
  lifecycle, exactly one true clue among clue_count shuffled clues,
  accusation targets whoever the player is talking to, reputation
  consequences via `apply_action`, `to_dict`/`from_dict` for saves.
- **PlayerState:** `wound_days_remaining` set on a "combat" pass-out only
  (recovery days from player.json), decrements once per `day_passed`, floors
  at 0, rides in the existing player save block.
- **ToolManager:** tool energy cost x1.2 while wounded.
- **TitheManager:** `_on_reputation_action` maps `accuse_falsely` ->
  `false_accusation` offense (same single-wiring pattern as
  `attack_villager` -> `witnessed_violence`).
- **main.gd:** NPC dialogue gains investigation awareness (clue line + "Accuse
  of theft" response); the autoload is read via `get_node_or_null` so the
  game compiles and boots before the human registration lands.
- **SaveManager:** `SAVE_VERSION -> 11`; investigation block in
  build/apply_payload; `migrate_to_v11` defaults the block + wound field;
  chain `if version <= 10`.
- **Tests:** new `test_raid_scaling` (17), `test_thief_investigation` (26),
  `test_combat_weapons` (12); `test_save_roundtrip` updated to v11 (+5:
  wound + investigation survive the roundtrip, v4 migration defaults);
  `test_game_data_smoke` +9. **Full runner: 596/596 checks ALL SUITES
  PASSED**, headless import clean, boot smokes (`--quit-after 30`) exit 0 for
  both `main.tscn` and `title_screen.tscn` with no ERROR lines.
- **Divergences / notes:**
  - `false_accusation` fine (15 coin) added to `manor.json` - the guide's
    data list omits it, but its own manual checklist says the offense "shows
    up as a fine" at court, and without a fines entry `_maybe_run_court`
    charges 0. Manor.json bumped to v2.
  - `accuse()` side effects are reference-driven (null refs are a no-op),
    not gated on test mode; the court offense is queued exclusively through
    ReputationManager.action_applied -> TitheManager wiring. An initial
    version also called `record_offense` directly, which double-queued - the
    test caught it.
  - Dynamic-raid rolls use the seeded `_rng` rather than bare `randf()` so
    tests can be deterministic; the trigger and weighted-pick tests are
    deterministic by construction regardless.
  - "Night raids" are a flavor roll at trigger time (+size bonus + message),
    not real hour polling - exactly the guide's ruling; documented so nobody
    "fixes" it into `minute_passed` polling without deciding that
    restructure is worth it.
  - `_raid_done`/`_theft_done` remain unpersisted (pre-existing gap the guide
    flags): reloading a save from before day 15/19 after already fighting
    that raid this session can re-fire it. Noted, not fixed, per the guide.
  - Defense items are flat one-time purchases with no upkeep cost.
  - The first full test run hung ~15 min: when a suite fails to parse, the
    runner's `suite_script.new()` throws inside `_initialize` and never calls
    `quit()`, so Godot idles forever. The actual cause was the familiar
    `:=`-from-Variant parse error in `test_thief_investigation`
    (`var empty := inv.reveal_clue_for(...)` on a Node-typed receiver);
    fixed with an explicit type. The runner now completes in ~5 s.
  - The off-tree `get_node()` noise now also appears for RaidManager's
    InvestigationManager lookup during tests - guarded, harmless.
- **Pending (human, editor):** register the `InvestigationManager` autoload
  (Node name `InvestigationManager`, path
  `res://scripts/autoloads/investigation_manager.gd`; no ordering
  constraint - it has no autoload dependencies). Until registered, F5 play
  has no clue/accuse flow (the theft still fires and loses coin; main.gd
  guards the lookup so nothing errors).
- **Still pending from Sprints 8-9 (DESKTOP, human):** `SkillManager` and
  `BuildingManager` remain unregistered in project.godot.
- **Manual checklist still open (human, editor):** the guide's nine steps
  (deterrence drop -> dynamic raid with variety, defense effectiveness, day-19
  clue dialogue, correct/incorrect accusation outcomes + court fine,
  combat-wound energy penalty clearing after sleep, save/reload
  mid-investigation, resize legibility). The headless suites cover the model
  layer; the dialogue/UI flow is compile- and boot-verified only.

## Sprint 13 implemented (2026-08-05) - Crafting, cooking & preservation

Implemented per `design/sprints/sprint_13_crafting_cooking.md`. ADR-027
flipped from Proposed to Accepted and CLAUDE.md bumped to **v0.7**
(skill-gated crafting at built stations (drying shed, hearth), cooking, and
preservation added to section 2's in-scope list; the "full crafting, cooking
recipes" out-of-scope clause removed; save-version pointer corrected v11 ->
v12). AGENTS.md/DEEPSEEK.md regenerated with the real Godot generators.

- **Data:** `recipes.json` (new, v1; dried_turnip/dried_barley at the drying
  shed gated by farming 1, barley_ale at the hearth gated by farming 2 with a
  1-day ferment, herb_stew/berry_pie at the hearth ungated); `items.json`
  v4 -> v5 (dried_turnip 12 / dried_barley 14 / barley_ale 20 / herb_stew 18
  / berry_pie 22 energy; prices 6/8/14/5/10); `market.json` v3 -> v4 (five
  buy prices 9/12/18/7/13, a real markup over the combined raw assize);
  `buildings.json` v1 -> v2 (hearth, 1x1, 50 coin, 6 flint, 1 day).
- **GameData:** `RECIPE_INT_KEYS` (output_count, energy_cost, craft_days,
  skill_level_required) + recipe `inputs` values cast in `_cast_nested_ints`;
  recipes loaded via `_load_id_file("recipes.json", "recipes", RECIPE_INT_KEYS)`;
  `get_recipe(id)` / `get_all_recipe_ids()`.
- **BuildingManager:** `get_building_id_at(pos)` - completed-building station
  lookup for the interaction layer.
- **CraftingManager** (new autoload script): `crafting_started` /
  `item_crafted` signals; `can_craft` (station existence-anywhere, skill
  gate, common-quality ingredients, energy); `craft` (consumes energy +
  inputs; instant vs pending); `get_pending`/`to_dict`/`from_dict`;
  `_on_day_passed` finishes pending crafts.
- **Player:** `station_interacted(station_id, pos)` signal; `_use_tool`
  dispatches drying_shed/hearth faced tiles to it (proximity gate).
- **UI:** `crafting_panel.gd` (runtime CanvasLayer per the no-.tscn pattern;
  station-filtered rows, disabled + reason in station -> skill -> ingredients
  -> energy order, Craft button, day_passed refresh); `main.gd` connects
  `station_interacted` and opens the panel; CraftingManager read via
  `get_node_or_null` so boot works before the human registration.
- **PlayerState:** added `set_game_data_ref`/`_game_data()` test seam and
  `eat()` now reads through it - **divergence from the guide** (which claimed
  no PlayerState change): off-tree suites cannot reach `/root/GameData`, so
  the eat()-based cooking tests need the same injection pattern the
  time-manager seam already used. Production behavior unchanged.
- **SaveManager:** `SAVE_VERSION -> 12`; `crafting` block in
  build/apply_payload; `migrate_to_v12` defaults `{"pending": []}`; chain
  `if version <= 11`.
- **Tests:** `test_crafting` (32 checks: station/skill/ingredient/energy
  gates, instant craft, overnight ale, pending save round-trip),
  `test_cooking` (6 checks: raw turnip 5.0, herb_stew 18.0 via `eat()`,
  crafted-vs-raw >= 2x regression guard); `test_save_roundtrip` updated to
  v12 (+ crafting migration defaults). **Full runner: 636/636 checks ALL
  SUITES PASSED**, headless import clean, boot smokes (`--quit-after 30`)
  exit 0 for `main.tscn` and `title_screen.tscn` with no ERROR lines.
- **Divergences / notes:**
  - Version bumps corrected from the guide's stale numbers: items.json was
    already v4 (Sprint 12), so v4 -> v5; market.json v3 -> v4; buildings.json
    v1 -> v2; SAVE_VERSION 11 -> 12.
  - The guide's loader note was self-contradictory; used `_load_id_file`
    (array-of-entries shape consistent with crops/items), not the
    enemies-style id-keyed loader.
  - Crafting is common-quality only and `_station_available` checks
    existence-anywhere with proximity enforced by the panel - both per the
    guide.
  - The panel's block-reason order puts station before the guide's listed
    skill/ingredients/energy trio because station is can_craft's first gate.
- **Pending (human, editor):** register the `CraftingManager` autoload (Node
  name `CraftingManager`, path `res://scripts/autoloads/crafting_manager.gd`;
  no ordering constraint - it only connects TimeManager.day_passed in
  `_ready`). Until registered, F5 play has no crafting; the station
  interaction is a harmless no-op and main.gd guards the lookup so nothing
  errors. `SkillManager`, `BuildingManager`, and `InvestigationManager`
  remain unregistered from Sprints 8/9/12.
- **Manual checklist still open (human, editor):** the guide's ten steps
  (F5 clean after registration; build drying shed + hearth; station-filtered
  panel; herb_stew craft; dried_turnip skill gate; barley_ale overnight;
  crafted-vs-raw energy comparison; market sale markup; save/reload
  mid-fermentation; resize legibility). The headless suites cover the model
  layer; the panel UI is compile- and boot-verified only.

## ADR-021/022 accepted + forage rocks/lumber (2026-08-06)

ADR-021 (life skills) and ADR-022 (foraging & the commons) were retroactively
accepted - both systems were implemented in Sprint 8 but never formally
accepted because neither required a section 2 amendment. CLAUDE.md bumped
v0.8 -> v0.9 (both added to section 2's in-scope list; no out-of-scope change
needed); ADR status lines flipped; AGENTS.md/DEEPSEEK.md regenerated.

- **Acceptance condition on ADR-022:** rocks (flint) and lumber (wood) must
  have a chance of spawning as forage. `items.json` v5 -> v6 adds the new
  `wood` material (price 0, stackable); `forage.json` v1 -> v2 reweights the
  per-soil spawn tables so every soil can spawn both: flint 35/5/5 and wood
  15/20/30 on rocky/sandy/loamy (the rest stays wild plants, weights sum to
  100 per soil). Flint previously spawned only on rocky.
- **Divergence / note:** wood currently has no consumption sink - buildings
  still cost flint only, and the building panel shows Coin|Flint. Wood is
  stockpiled for future use (livestock shelters are a natural Sprint 14
  consumer). Noted, not built, per the narrow acceptance condition.
- **Tests:** test_game_data_smoke +8 checks (wood is a material, stackable;
  wood and flint present in every soil's spawn table), suite 45 -> 53. Full
  runner expected 644 checks.

## Sprint 14 implemented (2026-08-06) - Livestock

Implemented per `design/sprints/sprint_14_livestock.md`. ADR-028 was already
Accepted (CLAUDE.md v0.8, amended last session); this sprint ships the
system. CLAUDE.md bumped v0.9 -> v0.10 (save-version pointer corrected
v12 -> v13).

- **Data:** `animals.json` (new, v1: chickens + one goat species, feed =
  barley, product cycles 1/2 days, happiness gain/loss, quality weights,
  raid_loss_chance_per_animal 0.25); `items.json` v6 -> v7 (egg 6 energy,
  milk 8 energy, both food, price 0); `buildings.json` v2 -> v3 (coop, 2x2,
  70 coin / 8 flint, 2 days, animal_capacity 4); `market.json` v4 -> v5
  (egg buy 4, milk buy 7).
- **GameData:** `ANIMAL_INT_KEYS` + `ANIMAL_SPECIES_INT_KEYS`, nested
  quality_weights cast in `_cast_nested_ints` (in-place, like crops - the
  initial version assigned `_cast_ints`'s shallow duplicate and lost the
  weights cast; caught before commit), `animal_capacity` added to
  `BUILDING_INT_KEYS`, `animals_cfg` + `get_animal_species(id)`.
- **AnimalManager** (new autoload script): purchase/feed/happiness/product
  cycles/raid-loss per the guide. **Divergence:** the guide's
  `_on_raid_resolved` opened with `if win or _test_mode: return`, which
  contradicts its own test #7 (raid losses must run in test mode) and its
  second guard `gd == null` would swallow it off-tree anyway; dropped the
  `_test_mode` gate entirely - nothing in the handler has live-only side
  effects. Uses a seeded `_rng` (set_rng_seed seam, mirrors RaidManager)
  for raid-loss and quality rolls instead of bare `randf()`.
- **UI:** `player.gd` station dispatch + "coop"; new `AnimalPanel`
  (runtime CanvasLayer per the no-.tscn pattern): buy rows disabled with
  reason (no coop / at capacity / not enough coin), per-animal rows with
  happiness bar + fed state + Feed button; `main.gd` routes coop tiles to it.
- **Save:** SAVE_VERSION 12 -> 13; `animals` block in build/apply_payload;
  `migrate_to_v13` defaults `{"animals": {}, "next_id": 1}`; chain
  `if version <= 12`.
- **Tests:** new `test_animals` (57 checks: capacity gate, buy, feed,
  happiness day-passed clamps, exact product cadence, quality-weight formula
  contract, raid loss on lost-raid-only, save round-trip); test_game_data
  _smoke +6 (species int casts, quality weights, coop capacity, egg item +
  market price); save roundtrip updated to v13. **Full runner expected
  711/711 checks**; headless import clean; boot smokes exit 0.
- **Pending (human, editor):** register the `AnimalManager` autoload (Node
  name `AnimalManager`, path `res://scripts/autoloads/animal_manager.gd`;
  no ordering constraint - it connects TimeManager.day_passed and
  RaidManager.raid_resolved in `_ready`). Until registered, F5 play has no
  animal purchase/feed flow (the coop tile interaction is a harmless no-op
  and main.gd guards the lookup). `SkillManager`, `BuildingManager`,
  `InvestigationManager`, and `CraftingManager` also remain unregistered
  from Sprints 8/9/12/13.
- **Manual checklist still open (human, editor):** the guide's nine steps
  (F5 clean after registration; panel unreachable without a coop; build
  coop + buy chicken/goat; feed trends vs skipped feeding; daily eggs /
  every-other-day milk with quality tiers; low-vs-high happiness quality
  skew; raid loss message on a lost raid; save/reload persistence; resize
  legibility). Headless suites cover the model layer; the panel is
  compile- and boot-verified only.

## Debug cheat panel (2026-08-06) - Ctrl+K, modeled on TheAscentGoDot

Added the same permanent testing-panel pattern used in TheAscentGoDot:
**Ctrl+K while the pause menu is open** toggles `scripts/ui/debug_panel.gd`,
a workshop tool for driving live autoload state directly during manual
testing (the 66-item checklist compiled earlier this session needs exactly
this to be walkable in reasonable time). Gated behind `OS.is_debug_build()`
- `main.gd` only instantiates `DebugPanel` when true, so it can never exist
in a release export; the pause menu shows a "Ctrl+K: Cheat Options (debug
build)" hint under the same gate.

- **Why paused-only, not a free-standing global toggle:** matches the
  source pattern faithfully (Ascent's CLAUDE.md: "Ctrl+K while the pause
  menu is open") and sidesteps pause-ownership conflicts for free - the
  debug panel never touches `get_tree().paused` itself, it just rides on
  top of the pause menu's existing freeze.
- **Input:** `InputManager` gained `_register_ctrl_key_action` (mirrors
  `_register_key_action` but sets `ctrl_pressed = true` on the
  `InputEventKey`) and registers `toggle_debug_panel` -> Ctrl+K.
- **Sections:** Time (advance N days via the real `sleep_restore` +
  `sleep_to_next_day` cascade, or jump straight to a day/hour with no
  cascade), Weather (force sunny/rain/overcast/snow), Economy (add/set
  money), Player (full energy/health, clear wound), Inventory (starter kit
  button + a generic item/quality/quantity give row), Skills (+1000 XP per
  skill, max all), Reputation (+-20 per axis, reset to neutral, force
  attend_mass, reset daily gift cap), Raids & Combat (trigger scripted/
  dynamic raid, trigger theft, set deterrence), Thief Investigation (reveal
  all clues), Buildings & Crafting (force-complete constructions, finish
  pending crafts), Save (quick save/load the autosave slot).
- **Four small debug-only public methods added** to existing autoloads,
  each documented at the call site as a cheat-panel-only lever and kept
  minimal: `WeatherManager.force_weather()` (validates + sets + emits
  `weather_changed`, unlike `from_dict` which sets silently),
  `BuildingManager.force_complete_all()`, `CraftingManager.force_finish_all()`,
  `ReputationManager.reset_daily_gift_cap()`. No existing behavior changed.
- **Defensive resolution for the five sometimes-unregistered autoloads:**
  `SkillManager`/`BuildingManager`/`InvestigationManager`/`CraftingManager`/
  `AnimalManager` are read via `get_node_or_null` (matching every other
  script that touches them) and their sections show a "not registered - see
  Project Settings > Autoload" label instead of dead buttons if missing,
  rather than erroring.
- **Verified with a real Godot binary** (`%USERPROFILE%\Desktop\GoDot\
  Godot_v4.7.1-stable_win64_console.exe`, present on this machine although
  earlier sessions repeatedly reported none available): `--headless --path .
  --import` clean (DebugPanel and PauseMenu register as global classes with
  no parse errors); `--headless --path . --script res://tests/run_tests.gd`
  -> **ALL SUITES PASSED, 711/711 checks**, identical count to the
  pre-existing baseline (no suite regressed); boot smoke
  (`--quit-after 30`) exit 0 for both `main.tscn` and `title_screen.tscn`
  with no ERROR/WARNING lines beyond the pre-existing off-tree
  `get_node()` harness noise documented since Sprint 9.
- **This is the first real-binary confirmation of the entire accumulated
  codebase**, not just this change - every prior sprint from 7 onward was
  implemented and headless-tested but explicitly flagged "not verified, no
  Godot binary available" in its own completion note. That caveat is now
  resolved at the compile/headless-suite level for the whole tree as of
  this session. It does NOT resolve any sprint's open manual-checklist
  items (UI legibility, live interaction flows) - those still need a human
  editor pass; see the 66-item checklist compiled earlier this session.
- **No dedicated test suite for `debug_panel.gd` itself** - consistent with
  every other `scripts/ui/*.gd` panel (only `test_ui_manager.gd` covers the
  stack mechanics; panels themselves are compile/boot-verified only).

## Fixed: Ctrl+K never fired while paused (2026-08-06)

User report: the cheat panel didn't appear. Root cause was a real,
deterministic bug in the first cut above, not a maybe:
`_handle_global_input()` (which contained the Ctrl+K check) lived in
`main.gd._process()`, gated on `UIManager.is_open("pause")` being true. But
`main.gd` never overrides `process_mode`, so it resolves to
`PROCESS_MODE_PAUSABLE` by inheriting from the SceneTree root's default -
meaning `main.gd._process()` **stops firing the instant `get_tree().paused`
becomes true**, which is exactly the state the Ctrl+K check required to
fire. The check was gated on a precondition that guaranteed it could never
run. This also means Escape-to-close-pause (the pre-existing
`UIManager.close_top()` branch in the same function) has likely never
worked either - only the "Resume Toil" button (a UI signal, not a
`_process` poll) ever actually closed the pause menu. Nobody had hit this
before because nothing else needed to react to input while paused.

**Fix:** moved all four global menu-toggle checks (pause, inventory, build
menu, debug) out of `main.gd._process()` and into a new `UIManager._process()`,
with `UIManager.process_mode` set to `PROCESS_MODE_ALWAYS` in its `_ready()`.
This is deliberately scoped to the UIManager **autoload** rather than to
`main.gd` itself: autoloads are siblings of `current_scene` under `/root`,
not descendants of it, so making UIManager always-processing cannot cascade
`PROCESS_MODE_ALWAYS` down to Player/FarmGrid/NPCs the way setting main.gd's
own process_mode would have (CLAUDE.md Known Trap #7 - pause must freeze
gameplay nodes, and INHERIT cascades through every descendant that doesn't
override it). `main.gd._process()` now does only the camera-follow line.

**Second bug found while fixing the first:** the naive fix (referencing
`InputManager.is_action_just_pressed(...)` by bare global name inside
`ui_manager.gd`) broke `test_ui_manager.gd`, which `preload()`s
`ui_manager.gd` and calls `.new()` off-tree with no autoloads resolvable -
the exact settings_menu.gd trap from Sprint 9 ("test-compiled scripts must
reach autoloads via `get_node_or_null`; a bare singleton identifier fails to
**compile** in that context, not just to resolve at runtime"). Symptom was
stark: `SCRIPT ERROR: Invalid call. Nonexistent function 'new' in base
'GDScript'` and the suite count silently dropped from 711 to 695 checks
(test_ui_manager contributed 0 instead of 16, with no FAIL line - a
compile-failed preload doesn't fail a check, it just produces zero of them,
so watch the total count, not just "ALL SUITES PASSED"). Fixed by resolving
`InputManager` via `get_node_or_null("/root/InputManager")` with a null
guard at the top of `_process()` (off-tree instances are never added to a
tree so `_process` never actually runs on them - the guard exists purely so
the script still compiles when preloaded).
- **Verified with the real binary again:** `--headless --import` clean;
  `--headless --script res://tests/run_tests.gd` -> ALL SUITES PASSED, back
  to 711/711 (test_ui_manager now 16, up from 8 pre-fix - unrelated growth
  from concurrent VSA-1 work landed in the same session, not from this fix);
  boot smoke exit 0 for both scenes.
- **Not yet re-verified by a human in the live editor** - the headless
  checks confirm compile/signal-wiring correctness but cannot press Escape
  or Ctrl+K. Please retry: pause (Escape), then Ctrl+K - the cheat panel
  should now open. Also worth trying Escape a second time while paused (with
  the cheat panel closed) to confirm the previously-silent close-via-Escape
  path now works too.

## Content scope amendment - CLAUDE.md v0.11 (2026-08-06)

Owner ruling: **marriage and festivals are not out of scope.** That
contradicted CLAUDE.md section 2, so per the contract's own authority order
("a design ruling that contradicts it is blocked until the contract is
amended") the response was a full amendment, not a plan edit.

- **CLAUDE.md v0.10 -> v0.11:** section 2's out-of-scope list drops
  `- Marriage, festivals.`; the ADR-024 gifting/requests in-scope bullet
  drops its trailing "Marriage and festivals remain out of scope" sentence;
  two new in-scope entries describe festivals and marriage. A narrower
  boundary replaces the removed clause - children, in-laws, divorce, and
  rival suitors are the new out-of-scope line, so the amendment does not
  leave marriage open-ended.
- **`design/decisions.md` (append-only, respected):** appended ADR-029
  (setting/tone/content authority), ADR-030 (festivals), ADR-031 (marriage).
  ADR-030/031 **supersede** the marriage/festival exclusion clauses recorded
  in ADR-024 and ADR-028; **those ADRs' text was deliberately left
  unmodified** - they record what was true when written, and rewriting them
  would falsify the log. Same reasoning applied to CLAUDE.md's historical
  changelog entries (v0.4/v0.8/v0.10 still say "marriage and festivals remain
  out of scope", which was accurate at those versions).
- **Locked design shape** (owner-chosen, so the ADRs say something concrete
  rather than "in scope, TBD"): marriage = courtship **plus spouse life**
  (spouse moves into the cottage, home schedule, waking greeting, occasional
  farm chore, giftable outside the daily cap), candidates are the four
  village villagers only; festivals = **one per season, all four defined in
  data**, only Spring reachable in the slice, matching the season-aware data
  convention every other system already follows.
- **`AGENTS.md`/`DEEPSEEK.md` regenerated with the real generators**
  (`docs/make_agents.gd`, `docs/make_deepseek.gd`) via the Godot binary at
  `%USERPROFILE%\Desktop\GoDot\` - not hand-replicated as an earlier
  session had to. Wrote 28239 and 31814 bytes respectively.
- **Verification:** full runner **ALL SUITES PASSED, 711/711**, including
  `test_contract_sync` (7 checks) and `test_deepseek_contract_sync` (8) -
  which is the gate that makes the amendment real rather than aspirational.
  Grep confirms the only surviving "Marriage, festivals" strings in all three
  contract files are inside the new v0.11 changelog entry quoting what it
  removed.
- **Forward docs updated:** `design/content_plan.md` gains passes C5
  (festivals) and C6 (marriage) with dependency ordering and test lists;
  `design/roadmap.md`'s two stale scope lines now record the supersession
  rather than asserting the old boundary. `design/sprints/sprint_10_village
  _life.md:9` still states the old boundary and was left alone - it is a
  historical implementation guide for shipped work, same category as the ADR
  text.
- **Known save impact, not yet incurred:** ADR-031's implementation will need
  a `SAVE_VERSION` bump and migration (spouse id, courtship state, ceremony
  flag). The amendment itself changes no save shape; version stays 13.

## VSA-1..3 (2026-08-06) - fixed manor structures, interaction prompt, empty hands

User-requested vertical-slice augments closing a presentation gap, not a
systems gap: `player_house`, both `well` tiles, `chapel`, `market_zone`, and
`stewards_demesne` (data-driven since Sprint 1-3) had never had any visual
or physical representation - the farm rendered as soil color only, so every
daily-loop anchor (bed, water, donation, trade, tithe) was an invisible tile
flag. No CLAUDE.md amendment or new ADR - this is presentation/interaction
work for systems already Accepted (ADR-003/006/007/009/012/023), not new
scope. Plan file: `replicated-watching-garden.md`.

- **VSA-1 - `FeatureRenderer` (new, `scripts/world/feature_renderer.gd`):**
  draws the house (3x2 footprint, bed on the existing single-tile
  `player_house` anchor, walls N/W/E with a 1-tile doorway gap in the S wall
  at the bed's column), both wells (stone-rim/water circles), the chapel's
  donation box and a new Lord's-Tithe chest at the `stewards_demesne`
  rect's corner (15,5), and the market stall (canopy/counter/posts, dims
  when `TitheManager.is_market_open()`/`is_black_market_open()` are both
  false, redraws on `market_status_changed`/`black_market_status_changed`).
  Anchor positions come from a new `GameData.get_all_features()` accessor
  (thin wrapper over the existing `farm_map.features` array - no data file
  changes); footprint/color are presentation constants in the renderer,
  matching `BuildingRenderer.BUILDING_COLORS`'s precedent. Wired into
  `main.gd` between `FarmRenderer` and `BuildingRenderer` in paint order.
- **Collision (user's explicit choice over the walk-through style every
  player-built building uses):** `StaticBody2D`/`RectangleShape2D` pairs on
  `PhysicsLayers.INTERACTABLE` (layer 3) - the layer's first real usage
  since it was named in CLAUDE.md's table but never wired to anything.
  `player.gd` adds `set_collision_mask_value(PhysicsLayers.INTERACTABLE,
  true)` in `_ready()`, additive to whatever mask `main.tscn` already sets.
  Tile-based interaction (`get_faced_tile()` -> `GameData.get_feature_at()`)
  is unaffected - it's pure coordinate lookup, independent of physics
  bodies, so every existing feature interaction still fires once the player
  is standing adjacent and facing the (now-solid) tile.
- **Trap hit and fixed:** `FeatureRenderer.configure()` originally resolved
  `/root/TitheManager` via `get_node_or_null` with an absolute path, but
  `configure()` runs (matching the rest of `main.gd`'s renderer setup)
  *before* `add_child()` - absolute-path lookups fail with "Can't use
  get_node() with absolute paths from outside the active scene tree" until
  the node is actually in the tree. Moved the TitheManager resolution and
  signal connections into `_ready()`; anchor collection and collision-body
  construction (`add_child` on children of an as-yet-unparented node) stay
  in `configure()` since neither needs the tree. Caught by the
  `--quit-after 20` boot smoke, not by the headless import or the suite run
  (neither exercises the live scene tree).
- **Trap hit and fixed (recurring, documented since Sprint 6):** two
  `var crop_name := _farm_grid.get_crop_name(...)` lines in the new
  `ToolManager.describe_action`/`_describe_tool_item` inferred from a
  `Node`-typed receiver's Variant-ish return and failed to compile under
  Godot 4.7's stricter inference check. Explicit `var crop_name: String =`.
- **VSA-2 - context-sensitive interaction prompt:** `ToolManager
  .describe_action(pos)` (new, public, read-only) mirrors `use_tool()`'s
  dispatch without mutating state; `Player.get_interaction_preview()` (new,
  public, read-only) mirrors `_use_tool()`'s priority chain (well -> station
  -> feature -> NPC -> tool fallback). `HudPanel` now calls
  `get_interaction_preview()` every `_process()` tick (alongside the
  existing `_refresh_tile_tooltip()`) and shows/hides the E-hint live
  instead of the old hardcoded "Work the Land" label.
- **VSA-3 - empty hands + watering-can gauge:** new `equip_none` InputMap
  action on `KEY_0` (a second action object sharing `menu_0`'s physical key,
  same precedent as `equip_hoe`/`menu_1` both on `KEY_1`; `player.gd`'s
  existing menu-open guard keeps the two from firing together) clears
  `PlayerState.equipped_tool_id` for bare-hand harvest/forage. New "Bare
  Hands" hotbar slot 0. Watering-can gauge: `HudPanel` previously only
  learned the can's fill level from `ToolManager.water_level_changed`,
  which never fires before the can's first refill/use, so it could read
  stale on boot/load; `_on_equipped_changed` now also pulls
  `ToolManager.get_current_water()/get_current_capacity()` directly (both
  already public), and `_on_game_loaded()` already calls
  `_on_equipped_changed()` so boot/load is covered for free. Bar grew from
  58x5px to 56x9px plus a numeric `(45/90)` caption.
- **Unverified 4.7 API surface touched (flag-don't-guess):**
  `CollisionObject2D.set_collision_mask_value`/`set_collision_layer_value`
  and runtime `StaticBody2D`/`CollisionShape2D`/`RectangleShape2D`
  construction (`.new()` + `add_child`, no `.tscn` involved) - core API
  since 4.0 as far as memory serves, not independently found in this
  project's prior sprints, so flagged per the API-confidence rule. Verified
  functionally correct in a live manual playtest (see below), not just by
  compiling.
- **Verification:** `--headless --path . --import` clean; `--headless
  --path . --script res://tests/run_tests.gd` -> **ALL SUITES PASSED,
  711/711 checks**, unchanged from the pre-VSA baseline (nothing here
  touches `FarmGrid`/`TitheManager`/`SaveManager` gameplay logic, only a
  new renderer + read-only preview methods + one input action + HUD
  display); boot smoke exit 0. **Manual playtest with a real Godot binary**
  (screenshots): house/wells/chapel box/market stall/tithe chest all visible
  on sight; the house's north wall blocks movement (held toward it, player
  did not move); a well blocks movement onto its own tile the same way;
  facing a well shows "Fill Watering Can", using it fills the gauge from a
  synced `0/50` to a visible `50/50`; the E-hint changed live across "Till
  the Soil" / "Water the Soil" / "Watering Can Empty" / "Fill Watering Can"
  as the player turned to face different things; the market stall rendered
  dim/shut (correct - Day 1, market opens Day 3). The south doorway gap
  itself was verified by re-deriving its tile math against the same
  `_add_wall_body` call already proven to block (north wall test) rather
  than by also chasing it down on screen - low risk, not independently
  screenshotted.

### Contract amendment - ADR-032 dimetric projection (2026-08-06)

Design/contract work only. **No gameplay code changed in this pass**; the
conversion itself is planned, not started.

- **What changed:** `CLAUDE.md` v0.11 -> v0.12 (sections 1, 2, 5, 8, 9, 12 +
  changelog); ADR-032 appended to `design/decisions.md`; `AGENTS.md` and
  `DEEPSEEK.md` regenerated; `design/IsometricConversion.md` and
  `design/IsometricConversion_Worktrees.md` added.
- **The ruling:** the world renders dimetric at a `64 x 48` screen tile. The
  simulation stays axis-aligned at the 32-unit logical cell - projection is
  presentation-only, confined to `scripts/globals/iso_projection.gd`, and is
  now a section 8 invariant.
- **Section 9.5's `TileMapLayer` requirement is dropped.** It was specified in
  v0.1 and never built (see the Wave 1 note above deferring it pending 4.7 API
  verification); the immediate-mode `_draw()` renderers that were built
  instead are now what the contract says. An isometric `TileMapLayer` needs a
  textured `TileSet`, which the geometric-primitives-only rule cannot fill,
  and would force an editor session per terrain change - serialising work that
  is otherwise headless and parallel.
- **Took longer than expected, for one reason worth recording:** the stated
  inspirations (Stardew Valley, Harvest Moon, Rune Factory) are orthogonal 3/4
  top-down, *not* isometric, so "isometric like most farm sims" had two
  incompatible readings. Resolved by owner ruling in favour of a genuine
  dimetric projection, with the departure from the inspirations now recorded
  in section 2 so it is not mistaken later for an error.
- **Consequence found during planning, not anticipated:** screen-relative
  input maps the four screen cardinals onto grid *diagonals*, which
  `player.gd:185`'s `absf(v.x) >= absf(v.y)` tie-break resolves silently to
  west. A 4-way facing would therefore have stranded four of every tile's
  eight neighbours as untargetable - tilling a row would have run sideways.
  Facing widens to 8-way as a forced consequence; recorded in ADR-032 and
  section 2 rather than left for a workstream to discover.
- **Speed semantics change** (documented divergence, not a defect):
  `input_to_world_dir` inverse-projects the input, so apparent on-screen speed
  is constant and grid-space speed varies by heading. `player_cfg.move_speed`
  consequently reads as screen px/s rather than world units/s. Value unchanged,
  feel will differ; tuning deferred to the conversion's Phase 2.
- **Repository risk found while planning the parallel phase:** the repo has
  **zero commits** (`master` has no history, no remote, 14 untracked top-level
  entries). All fourteen sprints exist only as working-tree files. This blocks
  `git worktree` outright and, more importantly, means there is no baseline to
  revert to. Recorded as R1 in the plan and as step 0.1 of Phase 0.
- **Flagged, unverified against 4.7 (flag-don't-guess), not yet touched:**
  `CanvasItem.y_sort_enabled` (the depth-ordering mechanism the whole visual
  design rests on), `draw_colored_polygon`, and `Camera2D` limit properties.
  All are long-stable core API by memory; whoever first uses each records the
  outcome here.
- **Verification:** `docs/make_agents.gd` and `docs/make_deepseek.gd` re-run
  clean; `--headless --path . --script res://tests/run_tests.gd` -> **ALL
  SUITES PASSED, 711 checks, exit 0**, matching the pre-amendment baseline
  taken at the start of the same session. Both contract-sync suites pass, so
  `CLAUDE.md`/`AGENTS.md`/`DEEPSEEK.md` are in sync at v0.12.

### ADR-032 Phase 0 - foundation (2026-08-06)

Completed IsometricConversion.md section 4's Phase 0 in full (steps 0.1-0.9).
Sequential, single agent, in the main working directory - no worktrees yet.

- **New, frozen:** `scripts/globals/iso_projection.gd` (the projection seam -
  see its own docstring for the frozen formula/API), `scripts/world/
  world_visuals.gd` (the shared `y_sort_enabled` container, registers itself
  in the `"world_visuals"` group so a dynamically-spawned actor - an enemy,
  from `RaidManager` - can find it without main.gd wiring it directly),
  `scripts/world/actor_visual.gd` (the proxy follow/lifecycle contract),
  `scripts/world/iso_camera.gd` (replaces `main.tscn`'s `$Camera2D`, which is
  disabled rather than hand-edited out of the scene - same precedent as the
  old `$HUD` labels).
- **`main.gd` rewired and frozen:** builds the full ADR-032 node tree
  (camera, `world_visuals`, a player `ActorVisual`, one NPC `ActorVisual` per
  spawned villager), and its calls into `FarmRenderer`/`FeatureRenderer`/
  `BuildingRenderer` already pass the camera/`world_visuals` references those
  workstreams need. This required widening those three renderers'
  `configure()` signatures by one parameter each (camera for `FarmRenderer`;
  `world_visuals` for the other two) - a deliberate, minimal touch to
  otherwise WS-owned files so the frozen caller compiles; each parameter is
  stored and unused until its workstream lands. `_draw()` bodies on all three
  renderers, and on `player.gd`/`npc.gd`/`enemy.gd`, are **untouched** - the
  game still renders exactly as before except that the camera now follows the
  player's *projected* position, which is expected to look off ("broken or
  half-projected" per the plan's Phase 0 exit criteria) until WS-A/B/C land.
- **Test runner pre-wired:** six `test_iso_*` suites registered in
  `tests/run_tests.gd` - `test_iso_projection` and `test_iso_invariants` are
  real Phase 0 suites; `test_iso_terrain`/`_structures`/`_actors`/`_camera`
  are one-line placeholder stubs for WS-A/B/C/D to replace. No workstream
  needs to touch the frozen runner file.
- **`test_iso_invariants.gd`** is a static-analysis guard, not a behavioural
  test: it walks every `.gd` file under `scripts/` and fails if any of the
  projection seam's function/constant names are defined a second time outside
  `iso_projection.gd`, or if a bare `Input.*` call appears outside
  `InputManager` (CLAUDE.md 9.4). Deliberately best-effort - documented in the
  file's own docstring - a reimplementation under different names would slip
  past the name check.
- **Verified against the live 4.7.1 binary rather than flagged from memory:**
  used `ClassDB.class_get_property_list`/`class_get_method_list` and a throwaway
  instance to confirm, before writing `iso_camera.gd`, that `Camera2D` in this
  exact engine build exposes `enabled`/`set_enabled()`, `limit_left/top/right/
  bottom` (with `limit_enabled` defaulting to `true` already - no separate
  enable step needed), `make_current()`/`is_current()`, and that `Node2D`
  exposes `y_sort_enabled` (default `false`) and `draw_colored_polygon`. All
  confirmed present exactly as expected; none needed the usual flag-and-defer
  treatment. This resolves the projection-adjacent half of risk R6 in the
  plan's risk register ahead of schedule - `draw_colored_polygon` in
  particular is WS-A's, not Phase 0's, but was cheap to confirm at the same
  time.
- **Verification:** `--headless --path . --import` clean (one round-trip
  needed: `IsoCamera._recompute_limits()` initially used `:=` on
  `_game_data.get_map_width()`/`get_map_height()`, which fails to infer a
  type because `_game_data` is typed as a bare `Node` - fixed to explicit
  `var w: int = ...`/`var h: int = ...`). A headless smoke script instantiated
  `main.tscn` under the live `SceneTree` root (so autoloads resolve) and
  confirmed `_ready()` completes across two frames with no errors. Full suite:
  `--headless --path . --script res://tests/run_tests.gd` -> **ALL SUITES
  PASSED, 747 checks** (711 pre-existing + 36 new: `iso_projection` runs 30
  individual checks across 8 `_test_*` sections - `t.completed(8)` follows the
  existing convention of counting sections, not assertions, matching how
  `test_time_math.gd` and every other suite already call it - `iso_invariants`
  runs 2, and the four workstream stubs run 1 each).
- **The invariant guard caught a real bug in itself on first run**, worth
  recording as the reason it's trustworthy rather than just present:
  `_test_projection_formula_confined`'s first version used plain
  `String.contains()`, which flagged `actor_visual.gd`'s and
  `iso_camera.gd`'s entirely legitimate `IsoProjection.world_to_screen(...)`
  / `.grid_to_screen(...)` *call sites* as if they were duplicate
  *declarations*. Fixed to a `\b(func|const)\s+<token>\b` regex, which
  matches only a declaration. Re-verified both directions before trusting
  it: the fixed suite passes clean against the real Phase 0 files, and a
  throwaway `func grid_to_screen()` planted in a scratch file under
  `scripts/world/` (then deleted) was caught and failed the suite as
  expected. This is the mechanism the whole parallel phase leans on for
  catching a drifted second copy of the projection formula, so it seemed
  worth confirming by trial rather than by reading the regex.
- **Not yet done, by design:** nothing draws projected. That is Phase 1
  (WS-A/B/C/D), which begins once this commit is reviewed and the four
  worktrees described in `design/IsometricConversion_Worktrees.md` are
  created from it.

#### WS-A - Terrain (ADR-032, complete)

`scripts/world/farm_renderer.gd`'s `_draw()` is now a full-file replacement:
soil, tilled darkening, and moisture overlay draw as
`draw_colored_polygon(IsoProjection.cell_diamond(pos), ...)` instead of
`draw_rect`; crop dots move to `IsoProjection.cell_centre_screen(pos)` with a
radius sized off `IsoProjection.TILE_H` (no pixel literal). Grid lines are
drawn as a diamond lattice directly from `IsoProjection.grid_to_screen` at
constant-x / constant-y grid coordinates, not as the 4 edges of every cell's
`cell_diamond()` - the latter would double-draw every interior edge, since
each interior edge is shared by two adjacent cells (cell (x,y)'s
top-right edge is cell (x,y-1)'s bottom-left edge). Because `grid_to_screen`
is linear, the projected line between two grid points is still straight, so
one `draw_line` per grid line is correct and cheap.

**Culling:** `_draw()` iterates `get_visible_cull_rect(width, height)`, a new
public method (deliberately not underscored - see testing note below) that
calls `IsoProjection.visible_cells(_camera.get_visible_screen_rect(), width,
height)` when a camera is configured, and falls back to the full
`Rect2i(0, 0, width, height)` when `_camera` is null (test configurations,
and defensively any future camera-less caller). `width`/`height` come from
`_game_data.get_map_width()/get_map_height()` only - grepped the finished
file for `30` and `20` to confirm neither appears. The old top-down `CELL_SIZE`
constant is gone entirely; every screen-space number now flows through
`IsoProjection`.

**Redraw-on-scroll trigger:** kept the existing `tile_changed` dirty-flag
redraw, and added a second one for camera movement, since the visible cull
set now depends on where the camera is. `_process()` polls
`IsoProjection.screen_to_grid(_camera.global_position)`, floors it to a
`Vector2i` cell, and requests a redraw only when that floored cell differs
from the last one observed - not every frame. This lives in `_process()`,
not `_physics_process()`, per CLAUDE.md section 4: it reads and writes no
gameplay state, only screen-space camera position, which is exactly the kind
of presentation bookkeeping section 4 carves out (the same reasoning
`TimeManager`'s `_process`-based clock already relies on).

**API gap noted, not worked around:** `IsoCamera` (WS-D's file, frozen to me)
has no movement signal, so this polls `global_position` every frame instead
of subscribing to one. Per the plan's section 5.3 escalation protocol, I did
not add one to `iso_camera.gd` myself. The poll is cheap (one
`screen_to_grid` call plus a `Vector2i` compare per frame) and only calls
`queue_redraw()` on an actual cell-boundary crossing, so it does not
reintroduce a per-frame redraw - but if profiling ever shows the poll itself
matters, the fix is a `camera_moved` (or similar) signal on `IsoCamera` that
`FarmRenderer` connects to instead of polling. Filing this here rather than
blocking on it, per the plan's "continue with whatever else you can do
without it."

**Testing:** `_draw()` itself is never invoked by `tests/suites/test_iso_terrain.gd`
- calling it outside an active `NOTIFICATION_DRAW` pass needs a live
`CanvasItem` draw context a headless `SceneTree --script` run doesn't have
(not verified as an outright crash, just correctly out of scope for a
suite that must stay deterministic and fast). Instead the suite drives the
same public surface `_draw()` uses:
- `get_visible_cull_rect(width, height)` is public (not `_`-prefixed)
  specifically so the suite can assert cull-set correctness - no-camera
  fallback, an exact match against calling `IsoProjection.visible_cells`
  directly, and clamping at the map's top-left corner, bottom-right corner,
  and a view entirely off-map (zero-size, not negative-size - matching the
  contract `test_iso_projection.gd`'s own suite already established, not a
  bounded position; an out-of-range position paired with zero size still
  yields an empty `range()` in `_draw()`'s loops regardless of the position's
  magnitude) - 5 of the suite's 8 sections.
- `redraw_request_count`, a public test-observability counter incremented
  everywhere `queue_redraw()` is requested (`_on_tile_changed` and the
  camera-cell-crossing poll, both now routed through a shared
  `_request_redraw()` helper), lets the suite assert the tile-changed trigger
  still fires exactly once, that an in-cell camera nudge requests zero extra
  redraws, and that crossing a cell boundary requests one - without needing
  to inspect Godot's internal redraw-pending state, which has no public
  getter.
- A nested `_MockCamera extends IsoCamera` in the test file overrides
  `get_visible_screen_rect()` with a fixed value instead of the real
  implementation's `get_viewport_rect()` / `zoom` math, which requires a live
  `Viewport` this off-tree suite doesn't have. `global_position` is a plain
  `Node2D` property and works fine off-tree, so the mock only needs the one
  override.

Suite: 8 `_test_*` sections, 14 checks. Full project suite: 760 checks (up
from the 747-check Phase 0 baseline - a net +13, since the WS-A stub's 1
placeholder check is replaced, not just added to). `ALL SUITES PASSED`, exit
0, both before and after comparison run against the unmodified worktree
(confirmed the pre-existing `WARNING: 32 RIDs... leaked` /
`451 ObjectDB instances... leaked` / `35 resources still in use` lines at
exit, and the `get_node() with absolute paths` `ERROR` spam from
`investigation_manager.gd`, `player_state.gd`, and `tool_manager.gd` during
unrelated suites, are identical baseline noise unrelated to this workstream
- `git stash` back to the Phase 0 commit reproduces the exact same warnings
at 747 checks).

**4.7 API confidence:** `draw_colored_polygon(PackedVector2Array, Color)` and
`Rect2i`/`Vector2i` arithmetic (`+`, `-`, comparisons) are long-stable core
API and are expected to hold per CLAUDE.md's confidence rule, but weren't
independently verifiable from memory against 4.7 specifically before this
pass - confirmed working via the headless import + full suite run above, no
runtime errors from either call.

#### WS-B - Structures (ADR-032, complete)

- **What changed.** `scripts/world/structure_visual.gd` is a new class: one
  `StructureVisual` per structure, parented as a direct child of
  `WorldVisuals`. It draws a footprint-sized floor diamond extruded upward
  into two shaded vertical wall faces - `IsoProjection.cell_diamond`'s
  top/right/bottom/left corner formula generalises cleanly from a single
  cell to an arbitrary `Rect2i` footprint because `grid_to_screen` is linear
  (no translation term), so the same four-corner math produces a big diamond
  for a 3x2 house exactly as it does a 1x1 chest. `feature_renderer.gd` and
  `building_renderer.gd` were rewritten to construct/configure one
  `StructureVisual` per fixture/building/ghost instead of drawing everything
  from their own single `_draw()`. Neither renderer draws pixels itself any
  more; both are now pure data-to-node translators plus (for
  `FeatureRenderer`) the untouched collision builders.
- **Sort-depth convention.** A `StructureVisual`'s `position` is the screen
  point of its footprint's south-east-most grid corner (`footprint.end`) -
  the corner nearest the camera, chosen to mirror `ActorVisual`'s "track a
  single point" convention (`world_to_screen(owner.global_position)`). This
  is what makes an actor standing behind a structure sort underneath it and
  one standing in front sort on top, with zero manual `z_index` bookkeeping.
  Not explicitly pinned anywhere in `IsoProjection` or the plan, so it is
  recorded here as this workstream's specific interpretation of "positioned
  at that structure's footprint anchor."
- **Wall heights are workstream-local presentation constants**, expressed as
  multiples of `IsoProjection.TILE_H` (a house at 1.6x, a well/chest around
  0.35-0.4x, the market stall at 1.2x, placed buildings 0.25x-1.3x by type).
  These are first-pass numbers, not tuned against the running game (this
  workstream never opened the editor, per the plan's standing rules) -
  flagged as a Phase 2 tuning item, same status the plan already gives
  `move_speed` feel and camera zoom.
- **Collision is untouched**, verified by test, not just by inspection:
  `_build_collision`, `_add_wall_body`, and `_add_solid_tile` in
  `feature_renderer.gd` are byte-for-byte the pre-ADR-032 versions, still in
  logical (32-unit) space on `PhysicsLayers.INTERACTABLE`. A wall's drawn
  diamond and its collision box are deliberately different shapes on screen
  now - that is the projection invariant working as designed, not a defect.
- **Rebuild-not-diff for placed buildings.** `BuildingRenderer` rebuilds its
  entire `StructureVisual` set from `BuildingManager.get_placed_buildings()`
  on every `building_started`/`building_completed` signal, rather than
  diffing. Simpler and correct for the vertical slice's building counts
  (single digits); would need to become incremental before it scales to
  hundreds of buildings, but that is not a Phase 2 concern for this slice.
  The rebuild uses `visual.free()` (immediate), not `queue_free()`: it always
  runs from a `BuildingManager` signal, never from a visual's own callback,
  so an immediate free is safe here, and it sidesteps a real testability
  problem - the headless test runner never pumps a frame between calls, so a
  `queue_free()`'d node would still be sitting in `world_visuals.get_children()`
  when the very next assertion ran.
- **One persistent ghost, not a recreate-per-move.** The placement ghost is
  a single `StructureVisual` created once in `configure()` and
  reconfigured/toggled `.visible` on every `show_ghost()`/`hide_ghost()`
  call, so moving the ghost every frame while placing never allocates a node.
- **Test suite** (`tests/suites/test_iso_structures.gd`, 73 checks): fixed
  manor fixtures produce exactly one `StructureVisual` each, all parented
  directly under `world_visuals` and never under the renderer's own
  collision `StaticBody2D`s; collision body count/size/position is asserted
  against the exact pre-ADR-032 logical-space numbers (north wall at logical
  (48,3), size 96x6); the market stall recolours through a stub
  `TitheManager` (real `TitheManager` was not worth dragging in - it needs
  `FarmGrid`/`PlayerState` wiring this suite has no reason to touch); placed
  buildings produce one visual each with no duplication even when a single
  placement fires both `building_started` and `building_completed` in the
  same call (the `fence`'s `build_days: 0` case); in-progress buildings clear
  `in_progress` on completion; the ghost tracks footprint and placeability
  colour across moves and hides (not frees) on `hide_ghost()`.
- **Worked around one self-inflicted test bug, not an API gap:** the ghost
  "moves to a free tile" case first used `Vector2i(20, 20)`, which is
  out-of-bounds (`farm_map.json` is 30x20, valid y is 0-19) and so correctly
  came back blocked - not a `can_place_building` defect. Fixed to
  `Vector2i(20, 15)`.
- **API gaps for a future phase:** none hit. `IsoProjection`'s frozen surface
  (`grid_to_screen`, `TILE_H`) was sufficient for everything this workstream
  needed, including generalising `cell_diamond`'s corner formula to a
  multi-cell footprint without adding a new `IsoProjection` function -
  worth noting for Phase 2/a future ADR: if another workstream needs the
  same "diamond for an arbitrary footprint rect" shape, it may be worth
  promoting `StructureVisual._local_diamond`'s math into `IsoProjection`
  itself (e.g. `footprint_diamond(rect: Rect2i)`) rather than each having
  its own copy - not done here because `IsoProjection` is frozen and this
  workstream's one call site did not justify an escalation.
- **Verification:** `--headless --path . --import` clean; full suite
  (`tests/run_tests.gd`) prints `ALL SUITES PASSED (819 checks)` and exits 0
  (baseline at branch start was 747; this workstream added 73 and replaced
  the 1-check Phase 0 placeholder, net +72).
- **Not done / left for Phase 2 (per the plan, section 4's "Phase 2 -
  Integration"):** no manual visual regression pass in the editor (this
  workstream's standing rules forbid opening it); wall-height/colour tuning;
  confirming the cottage's occlusion-at-the-boundary behaviour with a real
  moving player, which needs WS-C's actor proxies merged first.

#### WS-C - Actors and input (ADR-032, complete)

**Built:** proxies for all three actor types plus the input rotation and
8-way facing.

- `scripts/player/player_visual.gd`, `scripts/npc/npc_visual.gd`,
  `scripts/world/enemy_visual.gd` - new `ActorVisual` subclasses, each
  caching a typed owner reference via an overridden `track()` and drawing
  the exact geometry the owner script used to draw itself (body rect +
  outline for player/NPC; body rect + health bar for enemy). `player.gd`,
  `npc.gd`, and `enemy.gd` no longer have `_draw()` overrides at all.
- `player.gd`: removed the `rotation = Vector2(_facing).angle() + PI / 2.0`
  line per the task brief - facing is now conveyed entirely by
  `PlayerVisual._draw()`'s face-bar triangle, which re-derives its direction
  every frame from `Player.get_facing()` (new public getter) projected
  through `IsoProjection.grid_to_screen()` (NOT `world_to_screen` - facing is
  already a grid-cell-unit `Vector2i`, not a `LOGICAL_CELL`-scaled world
  offset; using `world_to_screen` here would have silently shrunk the bar's
  direction vector by a factor of `LOGICAL_CELL`, still pointing the right
  way but for the wrong reason - worth flagging since the two functions are
  easy to reach for interchangeably and only one is dimensionally correct
  for a `Vector2i` offset).
- Input: `_physics_process` now rotates `InputManager.get_movement_vector()`
  through `IsoProjection.input_to_world_dir()` before it becomes `velocity`.
  The transform and the facing update both live in a new private method,
  `_apply_movement_input(screen_input: Vector2) -> void`, extracted
  specifically so it's unit-testable off-tree with a controlled input vector
  instead of live `Input` state (see Testing below).
- Facing widened from 4-way to 8-way per plan section 2.3:
  `_vector_to_facing(v: Vector2) -> Vector2i` now takes the already-rotated
  grid-space vector, buckets its angle into one of 8 45-degree sectors, and
  returns the matching king-move `Vector2i` neighbour from a new
  `FACING_NEIGHBOURS` constant. Tie-break at exact 22.5-degree sector
  boundaries is `floor(raw_sector + 0.5)` (explicit round-half-up), spelled
  out in code rather than delegated to `snappedf`'s rounding convention,
  specifically so the tie-break's determinism doesn't depend on recalling
  Godot's `round()`/`snappedf()` half-value behaviour correctly from memory
  (API confidence rule, CLAUDE.md section 1) - a hand-written `floor(x+0.5)`
  is unambiguous by inspection. `get_faced_tile()`'s signature and meaning
  are unchanged, so tool use / feature interaction / NPC dialogue / combat
  all keep working against it untouched.
- `npc.gd`: replaced the three remaining hardcoded `32.0` tile-to-pixel
  literals (home/work spawn conversion at the old lines ~38-39, and the
  wander-radius scale at the old line ~80) with `IsoProjection.LOGICAL_CELL`.
  These were confirmed to be the last hardcoded `32.0`s outside the
  projection seam itself in this workstream's three files.

**Escalation (plan section 5.3) - `world_visuals.gd` is not actually
group-registered:** the task brief for this workstream stated that
`WorldVisuals` is "registered in the Godot group `world_visuals`" so a
dynamically-spawned `Enemy` (spawned by `RaidManager`, outside `main.gd`) can
find it via `get_tree().get_first_node_in_group("world_visuals")`. Reading
the actual frozen `scripts/world/world_visuals.gd` (its whole body is a
3-line `_init()` that sets `y_sort_enabled = true`) and the frozen
`scripts/main.gd` (which constructs `WorldVisuals` and never calls
`add_to_group` on it) shows this registration does not exist anywhere in the
Phase 0 code actually delivered. Per the escalation protocol: this was not
worked around by duplicating `WorldVisuals`/`IsoProjection` logic locally.
Instead, `enemy.gd`'s new `_find_world_visuals()` tries
`get_first_node_in_group("world_visuals")` first (so it starts working for
free, at zero further cost, if a future Phase 0 amendment adds the missing
`add_to_group` call to `world_visuals.gd` or `main.gd`), and falls back to a
one-time recursive scan from `get_tree().root` for a node of type
`WorldVisuals` if the group lookup comes back empty. The fallback is plain
tree traversal, not a reimplementation of any projection or gameplay logic,
so it does not breach the "do not duplicate logic locally" clause of the
escalation protocol. **Requested change for a future Phase 0 amendment:**
add `add_to_group("world_visuals")` to `WorldVisuals._init()` (one line,
inside the file that already sets `y_sort_enabled` there) so every dynamic
spawner gets the O(1) group lookup instead of a tree walk. This was not
verified against a live raid in-editor (see Not independently verified,
below) - only unit-reasoned from reading both frozen files directly.

**Deliberate divergence - `player.gd`'s autoload access changed from bare
identifiers to `get_node_or_null`:** pre-existing `_physics_process` and
`_handle_equip_shortcuts` called the `InputManager`/`PlayerState` autoloads
by their bare global singleton identifiers (e.g. `InputManager.foo()`),
unlike this same file's `_ready()`/`_use_tool()`/`get_interaction_preview()`,
which already used `get_node_or_null("/root/GameData")` etc. throughout. This
turned out to be load-bearing for testability: GDScript
performs whole-script static analysis at compile time, so a single
unresolvable global identifier anywhere in the file - even in a method never
called by the test - fails the ENTIRE script's compile, which surfaces as
`preload("res://scripts/player/player.gd").new()` throwing "Invalid call.
Nonexistent function 'new' in base 'GDScript'" (a confusing symptom for what
is actually a compile error further up the log:
`Compile Error: Identifier not found: InputManager`). This only surfaced now
because no suite before this workstream ever preloaded `player.gd` directly
- `test_schedules.gd` preloads `npc.gd`, which never uses a bare autoload
identifier anywhere, so it never hit this. Since this workstream's test
brief specifically calls for driving `player.gd`'s script directly off-tree
(matching `test_time_math.gd`'s pattern), both call sites were changed to
`get_node_or_null("/root/InputManager")` / `get_node_or_null("/root/PlayerState")`,
matching the pattern this same file already used for `GameData`/`UIManager`/
`BuildingManager` elsewhere. This is behaviourally identical at runtime (the
autoload's node path IS `/root/InputManager`; a bare identifier resolves to
the exact same singleton instance) and was verified by the full suite still
passing after the change - flagged here per CLAUDE.md section 3 rule 7
("comment the why... mirrored into DEVELOPMENT_STATE.md") since it is a
change to how an existing, working method reads its autoloads, done for a
reason (testability) unrelated to ADR-032's projection work itself.

**Testing:** replaced the `test_iso_actors.gd` stub with 4 real test
functions (15 individual checks): 8-way facing resolved correctly from
screen-space input for all eight grid neighbours (each neighbour's screen
input built via `IsoProjection.grid_to_screen(neighbour)` - the exact
inverse of the rotation under test, not a hand-picked approximation); the
22.5-degree tie-break resolving identically across two independent instances
given the identical boundary input; `input_to_world_dir` proven to be wired
ahead of `velocity` (not just present in the file) by asserting the
resulting velocity is NOT the naive un-rotated `screen_input * speed` and IS
exactly `IsoProjection.input_to_world_dir(screen_input) * speed`; and the
public `get_facing()`/`get_faced_tile()` getters reflecting resolved state
correctly, including the zero-input deadzone leaving facing unchanged. All
driven through `Player`'s script directly via
`preload("res://scripts/player/player.gd").new()`, off-tree, no autoloads
required - the `get_node_or_null` change above is what makes this possible.
Full suite: **761 checks passed, 0 failed** (up from the worktree's starting
747; net +14 from replacing the 1-check placeholder with 15 real checks).
`test_schedules.gd` and `test_combat*.gd` were not modified and still pass
in full, unaffected by this workstream's changes.

**Not independently verified (API confidence rule, CLAUDE.md section 1):**
`draw_polygon(PackedVector2Array, PackedColorArray)` (used by
`PlayerVisual._draw()` for the face-bar triangle) and `Vector2.is_equal_approx`
(used only in this workstream's own test suite) are long-stable core API and
expected to hold on 4.7, but were not runtime-verified beyond "the headless
suite run didn't error and the invariant-guard suite still passed" - no
suite in this project renders anything, so `_draw()` correctness (as opposed
to compiling and type-checking correctly) was never actually exercised
headless. This is the same class of gap the plan's Phase 2 manual sweep
(design/IsometricConversion.md section 4, Phase 2 step 3) exists to catch;
an `F5` visual check of the player's face-bar direction while walking in all
8 facings, and of enemy/NPC sorting against the player, is recommended before
merge even though the full automated suite is green.

**API gaps found, for a future Phase amendment:** none beyond the
`world_visuals` group-registration gap above. `IsoProjection`'s existing API
(`grid_to_screen`, `world_to_screen`, `input_to_world_dir`) covered
everything this workstream needed with no additional helper requested.

#### WS-D - Camera and viewport (ADR-032, complete)

- **Files touched:** `scripts/world/iso_camera.gd` (full-file replacement per
  CLAUDE.md style rule 9), `tests/suites/test_iso_camera.gd` (replaced the
  Phase 0 placeholder). Nothing else - `main.gd`, `run_tests.gd`,
  `iso_projection.gd` all left untouched, as required.
- **Zoom: `BASE_ZOOM = Vector2(1.0, 1.0)`**, set explicitly in `configure()`
  rather than left as an unexamined engine default. Worked the numbers
  rather than eyeballing: at zoom 1.0 the unclamped `IsoProjection.
  visible_cells` bounding box is ~20x20 grid units (nets to ~16x16 actual
  cells once its 2-cell cull padding is backed out) - a sensible farming-sim
  field of view. The player's 12-unit collision radius (`docs/
  bootstrap_project.gd`) renders at ~48 screen px across at this zoom,
  comparable to a normal top-down character sprite; zooming out to 0.5
  would shrink that to ~24px, hard to read in combat. `TILE_W` (64) also
  divides the 1280 base viewport width evenly only at zoom 1.0 - not proof
  of anything by itself, but a coincidence worth not fighting. Verified with
  a scratch probe against the real `IsoProjection.visible_cells`, not just
  by inspection.
- **Smoothing: deliberately OFF** (`position_smoothing_enabled = false`,
  matches the engine default but now set explicitly so the decision is
  visible, not accidental). `grid_to_screen`/`world_to_screen` are pure
  linear maps with no rounding before the assignment to `global_position`,
  and plan section 2.1 already guarantees the player's on-screen speed is
  constant in every heading (the entire point of `input_to_world_dir`,
  WS-C's side of the same ADR). A camera mirroring a source with no jitter
  has nothing to smooth; adding smoothing would only add input-to-view lag,
  which actively hurts faced-tile targeting and combat aim.
- **The real work: the diamond-vs-rectangle clamp.** Camera2D's built-in
  `limit_left/right/top/bottom` are four *independent* scalar bounds - an
  axis-aligned rectangle. The projected map is a diamond inscribed in that
  rectangle, tangent to it only at the four grid corners, so there are four
  triangular gaps between the diamond's edges and the bounding rectangle's
  corners that a scalar clamp cannot see (x and y are clamped independently
  of each other). Worked out concretely for the shipped 30x20 map at zoom
  1.0, viewport 1280x720: clamping to the bounding box alone still lets the
  view show ~160px of void on each side when the camera is pushed to a map
  edge near a corner - about an eighth of the screen width, on both sides,
  not a rounding-error case. Confirmed this by hand and then by a scratch
  Godot script before writing any fix, to make sure the defect was real and
  not a misreading of the geometry.
  - **Fix:** `_clamp_target_to_map()` (new, static, pure) inverse-projects
    the viewport's own half-extent into grid space - `screen_to_grid` is
    linear with no translation, so two of the viewport's four corners are
    enough; the other two are their negations - and clamps the camera's
    *grid-space* centre so all four viewport corners land inside
    `[0, map_w] x [0, map_h]` before projecting back to screen space. That
    is the geometrically correct confiner for a rectangular viewport inside
    a linearly-projected rectangular map. Verified this is actually
    void-free (not just "runs without crashing") by reconstructing the four
    viewport corners in grid space in the test suite and asserting
    containment - at all four map corners, at both a wide (1920x1080) and a
    tall (800x1200) simulated viewport, on a map large enough (100x100
    synthetic) that a void-free position exists at all.
  - **One case this cannot fix, because no camera clamp can:** when the map
    is smaller than the viewport at the current zoom - true of *today's*
    30x20 slice map at zoom 1.0, whose projected bounding box (1600x1200)
    is comparable to the 1280x720 viewport - there is no camera position
    whose full rectangular view is void-free, because the world is littler
    than the screen. `_clamp_target_to_map` falls back to centring on the
    map in that case (verified: grid centre `(15, 10)` for the 30x20 map),
    which is the best any camera can do. This resolves itself once the map
    grows toward ADR-032's "intended final size"; it is a map-size fact,
    not a clamp defect, and is called out this explicitly so nobody
    "fixes" it again later by retuning the four scalars, which cannot work
    - the fix already applied is what makes it work everywhere the map is
    actually big enough.
  - `_recompute_limits()` (Phase 0's bounding-box computation) is kept
    unchanged as an outer safety net beneath the new clamp - it still bounds
    the camera to the map's true screen-space bounding box via Camera2D's
    own `limit_*`, so an unconfigured `_game_data` path or a future bug
    can never scroll arbitrarily far off-map. It is provably a no-op given
    an already-correctly-clamped position (the grid-space clamp's range is
    always a subset of the bounding box), so the two do not fight.
- **Testability finding, worth recording for later workstreams that touch
  Camera2D/Node2D-derived scripts under this harness:** a node added to
  `SceneTree.root` inside `_initialize()` is **not** `is_inside_tree()`
  yet - confirmed empirically against this exact 4.7.1 binary with a
  throwaway script before writing any test. `get_viewport_rect()` (and
  therefore `get_visible_screen_rect()`, and `make_current()`) hard-require
  `is_inside_tree()` and log an engine `ERROR` (not a GDScript exception) if
  called off-tree; `await process_frame` does make a node enter the tree,
  but `tests/run_tests.gd` calls `suite.run(harness)` synchronously with no
  `await`, so an `async` suite `run()` would return before `t.completed()`
  fires and silently under-report. Given `run_tests.gd` is frozen, the fix
  used here was to factor the viewport-dependent methods (`get_
  visible_screen_rect()`, `_process()`'s clamp branch) into pure static
  helpers that take already-known values as parameters
  (`_visible_rect(viewport_size, centre, zoom)`,
  `_clamp_target_to_map(target, half_extent, map_w, map_h)`), and test
  those directly instead of the Camera2D wrappers around them. The wrappers
  themselves are one-line delegations, exercised only by inspection and by
  the "How to Test This Change" checklist below, not by the automated suite.
- **`IsoProjection` API gaps hit:** none. `grid_to_screen` and
  `screen_to_grid` (both already required) were sufficient for the
  diamond-clamp fix; no new helper was needed on `IsoProjection` itself.
- **Suite:** `tests/suites/test_iso_camera.gd`, 60 checks (up from the Phase
  0 stub's 1), all passing. Full project suite: **806 checks, `ALL SUITES
  PASSED`, exit 0** (up from the pre-existing 747 - net +59, since this
  replaced the 1-check stub). No suite besides `iso_camera` was touched, and
  no new engine `ERROR`/`WARNING` lines are attributable to this file (the
  full-run log's existing `ERROR` lines all trace to unrelated suites'
  scripts, e.g. `save_manager.gd`/`farm_grid.gd`, and predate this change).
- **Escalations:** none. No file outside `scripts/world/iso_camera.gd` and
  `tests/suites/test_iso_camera.gd` was needed.

### ADR-032 Phase 2 - integration (2026-08-06)

Merged all four Phase 1 worktrees into `master` per `design/IsometricConversion.md`
section 6's order (camera, terrain, actors, structures - least blast-radius
first, heaviest/most-visual last against an otherwise-verified world), full
suite green after every single merge, not just at the end:

| Step | Branch | Commit | Suite after merge |
|---|---|---|---|
| 1 | `iso/ws-d-camera` | `4d93386` | 806 checks |
| 2 | `iso/ws-a-terrain` | `f0c3a6c` | 819 checks |
| 3 | `iso/ws-c-actors` | `9a874da` | 833 checks |
| 4 | `iso/ws-b-structures` | `1139ba6` | **905 checks** |

Each merge's check-count delta matches that branch's own isolated total
exactly (759->806 for D standalone; +13/+14/+72 for A/C/B against the
Phase 0 baseline) - confirms the four workstreams' new coverage is purely
additive with zero overlap, which is what clean file ownership predicts.

**One conflict, exactly where expected and nowhere else:** `.godot/uid_cache.bin`
(the binary UID cache) conflicted on the final merge (WS-B), since all four
branches had independently regenerated it via `--import` after adding new
`.gd`/`.uid` files. Not a real conflict - resolved by taking either side then
re-running `--headless --import` against the fully-merged source tree to
regenerate it correctly, then staging that. Every source file merged clean,
including `DEVELOPMENT_STATE.md` itself: the four pre-created workstream
subsections (Phase 0 step 0.9) landed in four different regions of the file
and merged with no conflict, confirming that contingency worked exactly as
designed. No other hotspot (`main.gd`, `tests/run_tests.gd`,
`iso_projection.gd`) was touched by any branch, so none conflicted.

**Regression sweep:** the manual sweep CLAUDE.md section 10 calls for
(movement, day advance, crop growth/harvest, energy, save/load, pause, window
resize) is covered by the full suite for everything except visual appearance,
which this environment has no way to screenshot or eyeball (headless only, no
Godot editor, no windowed run). What headless verification *can* and did
confirm, beyond the 905-check suite: a 10-frame smoke boot of the fully
merged `main.tscn` completes with no engine errors, and inspecting the live
tree afterward shows `world_visuals` populated with exactly 14 children
(6 fixed manor fixtures + 1 player proxy + 6 NPC proxies + `BuildingRenderer`'s
persistent, initially-hidden ghost visual - accounted for exactly, no
duplicates), `y_sort_enabled` true, `IsoCamera` current and following, and the
old `$Camera2D` present but disabled exactly as designed. **Actually seeing
the dimetric view rendered correctly is not verified and cannot be from this
environment** - that needs an editor/windowed session.

**Tuning explicitly NOT attempted, for the same reason:** WS-B flagged wall
height/colour constants in `feature_renderer.gd`/`building_renderer.gd` as
untuned first-pass values (documented in its own subsection above). WS-D's
zoom/smoothing pass was numbers-backed (viewport/tile-size math, not
eyeballing) and is trustworthy without a screenshot; wall proportions are not
the same kind of claim and would be guessing without seeing them. Left as a
flagged follow-up for a session with visual verification, not silently
"fixed" blind.

**Save version:** unchanged at 13, as ADR-032 requires. No migration was
written and none was needed - confirmed by `test_save_roundtrip.gd` passing
unmodified through all four merges.

**Verification:** `--headless --path . --import` clean after the cache
regeneration; `--headless --path . --script res://tests/run_tests.gd` ->
**ALL SUITES PASSED, 905 checks**, exit 0.

**Not done in this pass, by design:** the four `iso/ws-*` branches and their
worktrees are left in place (not deleted, not pruned) pending the user's own
review of the merged result - `design/IsometricConversion_Worktrees.md`
section 6 (cleanup) is the documented next step once that review lands.

**Cleanup confirmed done (2026-08-07):** `git worktree list` and `git branch
-a` show none of the four `iso/ws-*` worktrees or branches remaining - only
`master`. The section 6 cleanup this note flagged as pending has been
carried out (or the branches were removed by other means); recorded here so
this log matches the actual repo state.

### ADR-032 post-merge integration bugs - found and fixed via live-editor
### verification (2026-08-07)

The Phase 2 integration report above (905 checks, exit 0) was accurate about
automated-suite state but incomplete: it explicitly flagged that visual
correctness was unverified from a headless-only environment. Opening the
project in the actual Godot editor and running it (`F5`) surfaced two real
bugs that no suite had caught, because both left the game in a state that
compiled, ran, and passed every existing check while still being visibly
broken.

**Bug 1 - the camera never moved.** `IsoCamera._clamp_or_centre()` (WS-D)
collapsed to a single fixed point whenever a viewport axis's required
clearance exceeded half the map span, intending that as a rare "map smaller
than viewport" fallback. On the shipped 30x20 map at zoom 1.0, the required
margin (17.5 grid units) exceeds half of BOTH map dimensions (15 and 10)
simultaneously - so the fallback wasn't a rare edge case, it was the
permanent state, and the camera sat frozen at grid (15,10) forever regardless
of the player's position. `tests/suites/test_iso_camera.gd`'s own fallback
test had encoded this frozen point as the expected value, so the suite
couldn't catch it - it was asserting the bug. Diagnosed by adding a temporary
`print()` inside `IsoCamera._process()` and watching `cam_pos` stay bit-for-
bit identical across a real, confirmed player movement.

Fixed by widening `_clamp_or_centre()`'s fallback: only collapse to a fixed
point when the margin exceeds the FULL span (truly impossible to avoid void
on that axis at any position); when the margin is merely more than half the
span - today's actual case on both axes - clamp into the narrower swapped
range `[span - margin, margin]` instead, which is still valid and non-empty
and lets the camera move within it. `test_iso_camera.gd`'s fallback test
rewritten to check two different player positions and assert the resulting
camera positions differ - the load-bearing assertion the old test never made.

**Bug 2 - the player and every NPC were invisible.** `main.gd` (frozen since
Phase 0) instantiated the generic `ActorVisual` base class directly
(`ActorVisual.new()`) for both the player and every spawned NPC. Valid
GDScript - `ActorVisual` is a real, constructible class - so nothing errored
and every suite stayed green, but `ActorVisual` draws nothing by design (only
its subclasses do); WS-C built `PlayerVisual`/`NpcVisual` with real drawn
geometry but had no way to update the frozen file that was supposed to use
them. `enemy.gd`'s own docstring had already flagged the expectation
("unlike PlayerVisual/NpcVisual, which main.gd wires...") but nothing
enforced it. The result: positions tracked correctly underneath (confirmed
via a temporary print in `ActorVisual._process()`), but nothing was ever
drawn, so the well and market stall visible on screen were mistaken for the
player through several rounds of testing before the actual cause was found.

Fixed by changing the two `ActorVisual.new()` call sites in `main.gd` to
`PlayerVisual.new()` and `NpcVisual.new()` - the only change made to that
otherwise-frozen file. Added a static regression guard to
`test_iso_invariants.gd` (`_test_no_bare_actor_visual_instantiation`) that
fails the suite if `ActorVisual.new()` reappears anywhere in `scripts/`,
since a concrete subclass should always be used instead.

**Both fixes verified live in the editor, not just by the suite:** after the
fix, holding a movement key visibly pans the terrain and structures on
screen (camera bug confirmed fixed), and a distinct green square with a
directional face indicator - `PlayerVisual`'s exact drawn geometry - appears
and moves correctly, alongside colored NPC squares, neither of which
appeared in any screenshot before the fix.

**Why this matters beyond the two bugs themselves:** both were entirely
invisible to headless automated testing by construction - one because the
test asserted the buggy value as correct, the other because nothing about
"a valid but wrong class was instantiated" produces an error, a failed
assertion, or any other headless-observable signal. The 905-check green suite
after Phase 2 integration was true and not misleading, but it was not
sufficient, exactly as flagged at the time. This is the reason the plan
called for a human (or an agent with real display access) to actually look
at the running game before calling ADR-032 done - that step is not
optional and could not have been skipped without shipping a game where nothing
was visible.

**Verification:** `--headless --path . --import` clean; full suite ->
**ALL SUITES PASSED, 908 checks** (was 905; +3 net from the rewritten
fallback test's two positions plus the new regression guard), exit 0. All
temporary diagnostic `print()` statements added during this investigation
were removed before commit - confirmed via `grep` across `scripts/`.

### X10 landed - CLAUDE.md marriage-candidate amendment (2026-08-07)

ADR-033 (cast expansion and tiering) left one item owed: `CLAUDE.md` section
2's marriage entry (ADR-031) hardcoded "the four village villagers" as the
candidate set, which ADR-033's tiered cast had already superseded in spirit.
Landed as **CLAUDE.md v0.13**: the marriage entry now defines candidates as
the ADR-033 Tier 1 principal cast minus the priest and steward (excluded on
the same fiction grounds ADR-031 already gave), rather than a fixed
headcount. In practice this changes nothing playable yet - the two new Tier 1
principals (the neighbouring tenant, the miller/alewife) are not yet
authored - but it unblocks authoring them as marriage candidates without a
further contract amendment, and calls out that a ninth Tier 1 principal
would still need its own ADR before becoming a candidate (ADR-033's own
boundary).

Regenerated `AGENTS.md` and `DEEPSEEK.md` from the amended `CLAUDE.md` via
`docs/make_agents.gd` / `docs/make_deepseek.gd` (both headless, both
one-substitution transforms - no manual edits to either generated file).
`design/decisions.md` (ADR-033's "Contract impact" line) and
`design/setting_questionnaire.md` (X10's "still owed" note and the 1b intro
block) updated to record the amendment as landed rather than owed.

**Verification:** `--headless --path . --import` clean; full suite ->
**ALL SUITES PASSED, 908 checks** (unchanged - wording-only amendment, no
new tests needed), exit 0, confirming `test_contract_sync.gd` and
`test_deepseek_contract_sync.gd` still pass against the regenerated files.

### Phase 1 implemented (2026-08-07) - E1 Spring Crop Pack, E2 Soil
### Fertility (compost restored), E12 Foraging 2.0

Implements the accepted-with-amended-scope package from the 2026-08-07
decision note against `design/proposals/Proposal_Spring_Feature_Expansion.md`,
following the concrete field-level design in `Phase1_Schema_Draft.md` and
`Compost_Spec_Addendum.md` almost exactly as drafted, with the corrections
below made during implementation rather than left as drafted.

**Data:** `crops.json` v3->v4 (fertility fields on all 7 crops; carrot, pea,
onion, leek added), `soil_types.json` v2->v3 (`fertility_init`,
`fertility_recovery_per_day`, `high_fertility_quality_bonus`, and
**`high_fertility_threshold`** - a field the draft itself didn't list,
caught while writing `FarmGrid.harvest()`: the "fertility >= 60" rule is a
balance number, not a structural constant, and CLAUDE.md section 3.5
forbids a bare `60` in gameplay code), `items.json` v7->v8 (20 new
entries), `forage.json` v2->v3 (`max_digs_per_day`, `dig_loot` per soil;
**`dig_energy_cost` was drafted then removed** - `ToolManager._use_tool_item`
already computes every tool's energy cost generically from its own
`items.json.energy_cost`, so a second forage.json lookup would have been a
duplicate source of truth for the same number), `recipes.json` v1->v2 (5
new recipes), `market.json` and `villagers.json` content-only (buy
prices/stall inventory/gift likes - not in the original four-file list but
required for the new goods to be reachable at all), `skills.json` (added a
`"dig": 5` foraging xp_source - undrafted, needed once `_dig()` started
calling `add_xp_for("foraging", "dig")` and there was nothing to award).

**Code:** `GameData` gained the INT_KEYS for all the above plus a `dig_loot`
casting loop mirroring the existing `spawns` one. `PlayerState` gained
`event_flags: Array[String]` + `set_event_flag`/`has_event_flag` (shared
groundwork for E4's dialogue conditions, not yet consumed by anything but
E12's rare finds). `EventBus` gained `rare_item_gathered(item_id)`.
`FarmGrid` gained fertility init/deplete/recover, `apply_compost(pos,
amount)` (amount passed in by the caller, matching `water_tile`'s existing
shape - FarmGrid still has zero knowledge of `items.json`), `can_dig`/
`dig_cell` (a dedicated `dig_loot` table per the owner's ruling, not a gate
on the passive `spawns` table - see the compost/dig design thread in
`design/decisions.md`), and ADR-018's rot branch now spawns a
`spoiled_crop` pickup (own decisions.md entry, ADR-018 itself unedited per
the append-only rule). `ToolManager` gained a `spade` tool_category branch
and a `material`-type branch (compost) - the latter required broadening
`inventory_panel.gd`'s equip-button condition, since only `tool`/`seed`
types were equippable before and compost is neither. `SaveManager` bumped
to v14 (additive: `farm.cells[].fertility`, `farm.daily_dig_count`,
`player.event_flags`).

**Deviations from the drafts, all judgment calls made during
implementation, not silently:**
- `high_fertility_threshold` added to `soil_types.json` (see above) -
  neither `Phase1_Schema_Draft.md` nor the base proposal listed it.
- `dig_energy_cost` removed from `forage.json` (see above) - redundant with
  the spade's own `items.json.energy_cost`.
- `"dig": 5` added to `skills.json`'s foraging `xp_sources` - undrafted.

**Known gap, flagged not hidden:** `ToolManager`'s energy-cost/EventBus/
event_flag wiring around a rare dig has **no headless test coverage**.
`ToolManager` has no `GameData` test seam (unlike `FarmGrid.configure_for_test`
or `PlayerState.set_game_data_ref`) - `_item()` silently returns `{}`
off-tree, so a unit test built around it would be testing a fake, not the
real dispatch. `test_foraging_expansion.gd` says so directly in its header
rather than pretending to cover it. This is exercised by the Phase 1 gate's
manual playtest ("a spade dig, a morel find") - the same class of gap
ADR-032's postmortem already flagged for glue code no headless suite can
see, not a new kind of risk.

**One pre-existing suite broke and was fixed, not worked around:**
`test_cooking.gd`'s `_test_crafted_beats_raw` hardcoded a five-item
"crafted foods" list from Sprint 13; `leek_pie` (24 energy, a real recipe
output) fell through to the "raw" bucket and broke the
crafted->=2x-best-raw invariant the test exists to guard. Fixed by adding
the four new recipe outputs to that list - the invariant itself
(`best_crafted, 24.0` now, was `22.0`) still holds against the real data.

**Two real bugs caught by the test run itself, both in test code, not
game code:** (1) `test_soil_fertility.gd` used `var before := grid.get_cell_fertility(...)`
- `:=` can't infer a type through an `Object`-typed variable's method call
(`grid` is typed `Object`, not `FarmGrid`, matching every other suite's
`configure_for_test` pattern); fixed with an explicit `: float` annotation.
(2) `test_foraging_expansion.gd`'s save-roundtrip test asserted
`not_ok(restored.can_dig(pos), ...)` right after restoring a
`daily_dig_count` of 2 against a cap of 3 - backwards; 2 of 3 leaves one
dig *available*, so `can_dig` should be true. Rewritten to actually prove
the round-trip: confirm one dig remains, spend it, confirm the cap is
*then* exhausted - a test that would fail if `daily_dig_count` had silently
reset to 0 instead of restoring to 2.

**Verification:** `--headless --path . --import` clean; full suite ->
**ALL SUITES PASSED, 1041 checks** (was 908; +133 across three new suites
`test_crop_pack`, `test_soil_fertility`, `test_foraging_expansion`), exit
0. `AGENTS.md`/`DEEPSEEK.md` regenerated from `CLAUDE.md` v0.14.

**Not done in this pass:** the Phase 1 gate's manual-playtest half (full
crop cycle, fertility feedback, a spade dig, a morel find) - this
environment has no windowed/editor access, the same limitation ADR-032's
integration flagged. Headless verification confirms the mechanics are
correct against their own data; it cannot confirm the spade/compost are
actually reachable and legible in the running game. Recommend an editor
session before calling Phase 1 fully done, not just code-complete.

### Phase 2 implemented (2026-08-07) - E4 Dialogue Engine 2.0 (ADR-035)

Implements the E4 deep design pulled from `.deepseek/outputs/
proposal_r2a_cont_out.md` (lines 226-347 - a full restart of the section
that got truncated mid-table in `proposal_r2a_out.md`), reconciled against
the live code and recorded as ADR-035 in `design/decisions.md`.

**Data:** `dialogue.json` v3->v4, additive per line (`priority`,
`frequency`, `set_flag`). **The existing 36 lines were not left at their
implicit defaults** - each NPC's five reputation-threshold lines were
backfilled with explicit descending priority (40/30/20/10/0) and the
unconditioned line promoted to the explicit fallback marker (-999). R2a's
own "no changes needed, defaults handle it" claim doesn't hold: the five
`min`-threshold conditions per NPC aren't mutually exclusive (a standing of
60 satisfies all five `>= N` checks simultaneously), so leaving them all at
priority 0 would make the new engine pick randomly among them - a real
regression from today's `lines[0]`-of-first-match, which happens to always
land on the friendliest matching line only because the file lists
thresholds in descending order. Verified by test: `test_dialogue_engine.gd`
asserts the exact same line text the old bug returned, for three different
standing values, against the real shipped data.

**Code:** `ConditionEvaluator` (`scripts/world/condition_evaluator.gd`,
stateless, `class_name`) implements the full vocabulary from R2a (`time`,
`season`, `weather`, `is_market_day`, `is_mass_day`, `is_festival`,
`has_item`, `skill_level`, `player_money`/`energy`/`health`, `standing`,
`opinion`, `event_flag`, `not`) plus the pre-ADR-035 `"reputation.AXIS"`
dot-key form as a permanent backward-compat case, not a migrated-away
shim. `DialogueManager` (new autoload, no `class_name` per CLAUDE.md
section 3.2's autoload-name-collision rule) builds a flattened-facts
context per NPC from `TimeManager`/`WeatherManager`/`ReputationManager`/
`SkillManager`/`PlayerState`/`GameData`, runs priority selection (random
among exact ties) with `frequency` gating, and calls
`PlayerState.set_event_flag()` directly for `set_flag` - no new `EventBus`
round-trip; Phase 1 already established direct calls as this project's
flag-setting pattern. `GameData` validates dialogue.json at load
(unknown condition keys, invalid frequency, missing per-NPC fallback -
soft failures, `push_error` + continue, matching this file's existing
tolerance) and gained `get_dialogue_lines_for(npc_id)` returning raw,
unfiltered lines - `get_dialogue_for()`/`_dialogue_conditions_pass()` are
**untouched**, since `test_reputation.gd` asserts their exact current
return shape. `SaveManager` bumped to v15: a new top-level `dialogue`
block owned by `DialogueManager` (corrected from R2a's "PlayerState gains
dialogue_history" - every other autoload-owned save state in this project,
`crafting`/`skills`/`animals`/`buildings`, already gets its own top-level
block, so this follows that convention instead of a one-off exception).

**Two corrections to R2a's design made during implementation, both because
the live code didn't match what R2a assumed:**
1. **R2a claimed `main.gd` needs zero changes**, via a `DialogueUI.start()`
   abstraction that doesn't exist. The real `lines[0]` bug is inline in
   `_on_npc_interacted` at `main.gd:197`. A small, real edit was
   unavoidable.
2. **A bare `DialogueManager.get_next_line(...)` reference in `main.gd`
   would fail to even parse** until a human completes the DESKTOP
   autoload-registration step (confirmed by an isolated parse-check run,
   not assumed) - `main.gd` is too central to the game's boot to leave in
   an unparseable state pending a manual step. Fixed by reaching
   `DialogueManager` through `get_node_or_null` (matching this exact
   function's existing `InvestigationManager` check) with the old
   `get_dialogue_for()`/`lines[0]` path kept as a graceful fallback - the
   game plays exactly as it does today until the registration lands, then
   switches over with no further code change.

**DESKTOP step landed 2026-08-07** (see the Phase 3 integration entry
below) - `DialogueManager` is registered and live. Headless suites covered
the logic regardless (via `configure_for_test`, mirroring `CraftingManager`'s
multi-dependency
pattern) - this is the same class of gap Phase 1 flagged for `ToolManager`,
now flagged here for the same underlying reason (no test seam removes the
need for the live registration, only for headless coverage of the logic
behind it).

**One bug the test run itself caught, in test data, not engine code:** the
first draft of the morel-flag-gated priest line used `priority: 5`, lower
than the routine reputation-ladder lines it was meant to stand out above
(0-40) - it never actually surfaced regardless of the flag. Fixed by
raising it to `priority: 45`. A reminder that "give the special line a
priority" isn't self-checking; the number has to actually exceed what it's
competing against.

**Verification:** `--headless --path . --import` clean (also confirmed the
`ConditionEvaluator` `class_name` registers and the `DialogueManager`-
pending-autoload parse-safety fix actually works, via an isolated
load-only check before the full run); full suite -> **ALL SUITES PASSED,
1091 checks** (was 1041; +50 from `test_dialogue_engine`), exit 0.
`AGENTS.md`/`DEEPSEEK.md` regenerated from `CLAUDE.md` v0.15.

**Not done in this pass:** the DESKTOP registration itself, and the manual
playtest of condition-branched dialogue the Phase 2 gate calls for -
same environment limitation as Phase 1's own outstanding manual-playtest
item.

### Phase 3, E5 half implemented (2026-08-07) - Festivals (ADR-036)

Implements E5 from R2b's deep design (`.deepseek/outputs/proposal_r2b_out.md`
lines 94-237), recorded as ADR-036 in `design/decisions.md`. Landed
alongside a parallel E6 (dynamic market + board orders) workstream running
in its own git worktree (`../2DFarmingSim-e6-market`, branch
`phase3/e6-market`) via DeepSeek v4 Flash through the OpenAI Codex CLI -
see the "DeepSeek/Codex integration" note below for how that was set up.

**Data:** `festivals.json` v1, all four seasons defined (id, season, day,
start_hour, end_hour, location, standing_effects), only Spring's
`springturn_blessing` (day 18, hours 10-14, chapel tile) reachable this
slice - the same season-gating convention every other system already uses.

**Code:** `FestivalManager` (new autoload) is deliberately thin - a pure
`get_active_festival()`/`get_active_festival_anchor()` query over
`TimeManager.day`/`season`/`hour` against the static data, holding no
state of its own. Everything that actually *does* something reuses an
existing, already-shipped mechanism rather than building a new one:
attendance is checked in `main.gd`'s existing `_on_minute_passed`, right
alongside the mass-attendance check it already contains, using the exact
same `player.get_current_tile()`/`get_faced_tile()` predicate; the "only
once" gate is `PlayerState.event_flags` (Phase 1), not a new
`attended_festivals` array; `npc.gd`'s existing per-NPC `_update_anchor()`
gained one more override check ahead of its work/home fallback;
`DialogueManager.build_context()`'s `is_festival`/`festival_id` fields -
hardcoded placeholders left in Phase 2 for exactly this moment - now query
`FestivalManager` for real, and needed no new `ConditionEvaluator`
vocabulary since `is_festival` already existed and "has attended" is just
an ordinary `event_flag` check.

**Three corrections to R2b's design, documented in full in ADR-036:**
`TimeManager.hour_passed` doesn't exist (real signal is `minute_passed`);
`ReputationManager.apply_standing` doesn't exist (real method is
`modify_standing`); and R2b's "zero edits to main.gd" claim didn't hold,
for the same reason it didn't hold for E4 in Phase 2 - there's no
autoload-side way to ask "is the player standing on tile X", the existing
mass-attendance check already answers that question directly in `main.gd`
using the live `player` node reference only that file holds. This is now
a named pattern across three phases (E1, E4, E5): **DeepSeek's design-pull
claims about what `main.gd` needs should be verified against the live
file, never assumed** - flagged explicitly in ADR-036 so it isn't
rediscovered as a surprise a fourth time.

**No SAVE_VERSION bump.** Reusing `player.event_flags` for attendance and
keeping `FestivalManager` fully stateless means there's nothing new to
serialize - a deliberate design choice, not an oversight, made specifically
to avoid an unforced conflict with the parallel E6 workstream's own save
changes.

**Known gap, flagged not hidden (same shape as Phase 1/2's own flagged
gaps):** `main.gd`'s `_check_festival_attendance()` and `npc.gd`'s
`_festival_anchor_position()` both resolve `FestivalManager` via
`get_node_or_null` with no test-injection seam on either file - off-tree,
that's always null, so neither is headless-testable. `test_festivals.gd`
covers `FestivalManager`'s own query logic exhaustively (season/day/hour
boundaries, anchor lookup) and the `DialogueManager` integration, and says
so directly in its header rather than pretending to cover the rest.

**DESKTOP step landed 2026-08-07** (see the Phase 3 integration entry
below), alongside `DialogueManager`'s.

**Verification:** `--headless --path . --import` clean (including an
isolated parse-check of all six touched/new files before the full run,
now standard practice after Phase 1/2's parse-error history); full suite
-> **ALL SUITES PASSED, 1116 checks** (was 1091; +25 from
`test_festivals`), exit 0, first run clean - no bugs to fix this time.
`AGENTS.md`/`DEEPSEEK.md` regenerated from `CLAUDE.md` v0.16.

**DeepSeek/Codex integration set up this session:** OpenAI's Codex desktop
app was already installed and pre-configured with DeepSeek as a model
provider (a live API key in `~/.codex/config.toml`, discovered rather than
set up from scratch) - `codex exec -C <dir> -m deepseek-v4-flash -s
workspace-write "<prompt>"` runs a real agentic coding session
non-interactively, with file/tool access scoped to the given directory.
Confirmed working via a live smoke-test call before trusting it with real
work. `deepseek-v4-pro` is **not** available through Codex's model-select
yet (`"Codex integration with deepseek-v4-pro will be available starting
early August 2026"` - server-side, not a local config issue) - only
`deepseek-v4-flash` is usable this way today; Pro remains reachable only
via a raw API call (the same mechanism this repo's `.deepseek/outputs/`
history already used for the original proposal's R1-R3 rounds), not
through Codex's tool-using interface. No desktop/GUI control was needed at
any point - the whole integration is scriptable.

## 2026-08-07 - Buildings tuning: wood gains sinks (setting-questionnaire session)

Owner ruling during content pass C1 (Block 19): `wood` had **no consumer**
anywhere in data - it spawned from forage but nothing spent it. Applied:

- `data/buildings.json`: `cottage_upgrade` 200c + flint 20 -> **+ wood 20**
  (a chimney and floor are timber); `fence` 5c + flint 2 -> **wood 2** (fences
  are wood; makes wood load-bearing for the ADR-026 deterrence system).
  Tuning-only, no schema shape change, no save version bump.
- Tests: `test_buildings.gd` and `test_iso_structures.gd` helpers now grant
  wood; the fence tests assert the 2-wood deduction (one new assertion).
- **Verification:** full suite headless -> **ALL SUITES PASSED, 1117 checks**
  (was 1116; +1), exit 0. Engine found at
  `%USERPROFILE%\Desktop\GoDot\Godot_v4.7.1-stable_win64_console.exe` -
  headless runs need escalation; the suite's ERROR noise at exit (get_node
  outside a scene tree, RID leaks) is pre-existing harness behaviour, not a
  failure.
- Recorded as a standing ruling in `design/setting_questionnaire.md`;
  companion ruling: persistent trees/rock nodes on the commons deferred to
  ride with ADR-034, post-slice (Block 20's 20.4 custom becomes load-bearing).

## 2026-08-07 (same session, follow-up) - Block 20 content rulings applied

- `data/items.json` display names adopted per owner ruling (Block 20.3):
  `wild_herb` -> **Sorrel**, `wild_onion` -> **Ramsons**, `wild_berry` ->
  **Early Berries** (elderflower was the default's alternative; "Early
  Berries" keeps berry-pie coherent; soft-embedding, easy to change). Ids are
  unchanged - every system and test keys on ids, so this is UI text only.
- `data/items.json` + `data/market.json` (Block 20.4): wood is now
  **purchasable** at the market stall (price 3, unlimited stock). Wood is NOT
  in `buy_prices`, so the market and the black market won't buy it - no
  buy-low/sell-high arbitrage.
- **Verification:** full suite headless -> **ALL SUITES PASSED, 1191 checks**
  (the count jumped from 1117 because a parallel session bumped the contract
  to v0.17 mid-turn - ADR-037 local economy, save v16 - and its regenerated
  AGENTS.md/DEEPSEEK.md landed between my runs; the transient contract-sync
  failure was that drift, now regenerated and green), exit 0.

## 2026-08-07 (same session, follow-up) - Block 21 crops: oats + flax added

Owner ruling via genre research + a DeepSeek V4 Pro consult
(`.deepseek/outputs/block21_crops_out.md`):

- `data/crops.json`: added **oat** (4d, spring, moisture 30-70, yield 2-3,
  seed_recovery 0-1, spoil 4d, depletion 12, **fertility_min 20**, quality
  70/20/10) and **flax** (5d, spring, moisture 40-60, yield 1-2 flax_fibre,
  seed_recovery 0-1, spoil 6d, depletion 18, **fertility_min 30**, quality
  65/25/10). First crops with fertility_min > 0 - verified the gate is
  enforced in `farm_grid.gd` plant logic and soil fertility starts loamy
  70/sandy 50/rocky 30, so both plant everywhere at start but are
  fertility-sensitive under depletion (deliberate, Pro-authored axis).
- `data/items.json`: `oat` (food, energy 4, price 4), `oat_seed` (2),
  `flax_fibre` (material, price 18 - no energy_base, matching flint/wood),
  `flax_seed` (4). `data/market.json`: buy_prices 4/18 + seed stall entries.
- Pro review corrections: Pro claimed a "generic feed placeholder" - wrong,
  animals eat barley via `feed_item_id`; oats-as-alternative-feed is a
  **flagged follow-up** (AnimalManager accepts a single feed item today). Pro's
  flax `energy_base: 0` dropped as inconsistent with material convention.
- 21.4 confirmed by Pro: "never sell seed corn, never eat flax" stands;
  optional future hardening (limited per-market-day seed stock) deferred.
- **Verification:** full suite headless -> ALL SUITES PASSED, 1191 checks,
  exit 0. Relay facts: model=deepseek-v4-pro effort=max thinking=on
  harness=attached; connection http 200 in 87.67s; tokens prompt=15922
  completion=5095 total=21017 (reasoning=3713); truncation=no.

## 2026-08-07 (same session, final) - Block 25 framing drafted via V4 Pro; questionnaire complete

- Owner ruled 25.1/25.3 default and sent 25.2/25.4/25.5 to DeepSeek V4 Pro
  at max effort (`.deepseek/outputs/block25_framing_out.md`): opening roll
  entry, failure season-end roll + villager line, and the closing line.
  All three drafted and transcribed into `design/setting_questionnaire.md`
  with review corrections: "tithe"->"assessment" (14.1 diction), "her issue"
  ->"her kin" (4.2 parent-or-aunt), Hilda's line reworked to carry a question
  (15 voice tic), runtime item list noted for distraint, and a stricter
  alternate for the closing line offered. Previous holder named Alys Fletcher
  (Pro-authored, easily changed).
- **All 27 questionnaire blocks are CLOSED.** Next step per the document:
  write `design/world_bible.md` from it (not yet started).
- Relay facts: model=deepseek-v4-pro effort=max thinking=on harness=attached;
  connection http 200 in 61.7s; tokens prompt=15506 completion=3638 total=19144
  (reasoning=2894); truncation=no.

## 2026-08-07 (same session, deliverable) - design/world_biblePROPOSAL.md

Owner ruling: develop the world bible as a PROPOSAL through a multi-step
DeepSeek V4 Pro exchange; a human collaborator (Opus 5) will do final
creation/editing. Delivered: **`design/world_biblePROPOSAL.md`** (~62 KB,
sections I-XII + consistency check), assembled from four max-effort Pro
rounds:

1. **R1 outline** (`.deepseek/outputs/worldbible_r1_outline_out.md`) -
   refined section outline with block sourcing, LOCKED/OPEN classification,
   contradiction hunt, 3-part authoring split.
2. **R2 Part A** (r2 output) - header/status, the place, the people (six
   principals + itinerants + web), tone/register/diction.
3. **R3 Part B** (r3 output) - power & economy, the church, the year, the
   land & food.
4. **R4 Part C** (r4 output) - conflict & investigation, life milestones,
   framing, appendices, consistency check.

**Orchestrator review corrections applied at assembly:** Bram is the carter,
not the smith (Cedric is); Wat travels with a cart, not a pack; the
non-candidates are the priest and the steward, not a clerk; the two
sheet-less principals' candidacy is [OPEN]; X13's data version bump targets
`tithe.json` (tenure rework belongs to ADR-034); per-character standing bands
folded in from the questionnaire; old appendix skeleton removed; headings
normalised and sections reordered to I-XII. Encoding pitfall: PowerShell
5.1 `Get-Content` read the UTF-8 Pro outputs as ANSI (double-encoded every
non-ASCII char); recovered via CP1252 round-trip, verified 0 replacement
chars.

**Relay facts (all four calls):** model=deepseek-v4-pro effort=max thinking=on
harness=attached; R1 http 200 in 68.73s (prompt 16312 / completion 5260,
reasoning 3333); R2 104.37s (16715/8931, reasoning 5226); R3 131.09s
(16719/8324, reasoning 3448); R4 124.0s (16217/9319, reasoning 4639). No
truncation on any call. Task files: `.deepseek/tasks/worldbible_r*_task.md`.

### Phase 3 implemented (2026-08-07) - E6 Dynamic Market: supply pressure + town board orders (ADR-037)

Implements the E6 deep design pulled from `.deepseek/outputs/
proposal_r2a_cont_out.md` lines 349-457, in the **untrimmed** form the
owner's decision note restored (full supply-pressure curve, not the
board-orders-only trim), reconciled against the live code and recorded as
ADR-037 in `design/decisions.md`. Task brief: `.deepseek/tasks/
phase3_e6_market.md`.

**Data:** new `economy.json` v1 (`supply_scale` 170, `pressure_decay_per_day`
0.2, `price_floor_mult`/`price_cap_mult` 0.5/1.5, `max_active_orders` 3,
orders-per-market-day 1-3); new `board_orders.json` v1 (six Spring-eligible
templates - turnip, barley, carrot, pea, onion, leek - each with
min/max_quantity, base_reward_money, optional reward_standing +
standing_amount, deadline_days 3-5, weight); `farm_map.json` v2->v3 (one new
`town_board` feature at x:24,y:14, next to the market). No `crops.json`/
`items.json` changes, exactly as R2a's Save Impact section promised.

**Code:**
- `TitheManager` (the file the brief's verified hooks pointed at, not a new
  `BoardManager` autoload): `_crop_pressure` accrues per sold item in
  `sell_crop`, decays nightly by `pressure_decay_per_day`, and is converted
  into per-item multipliers locked at market open inside the 0.5x-1.5x band
  (`_compute_supply_multiplier`, snapshotted in `_update_todays_supply_
  multipliers`); `_compute_sell_net` multiplies the supply multiplier
  alongside the existing drift and standing factors, toll last. Board
  orders: `_refresh_board_orders` tops up 1-3 in-season orders on market
  days (capped at 3 active, weighted template pick, deadline clamped to the
  season), `_expire_orders` runs daily with no penalty, `fulfill_order`
  deducts across any quality mix and grants coin + optional standing via
  `ReputationManager.modify_standing` on the order's declared axis.
  `serialize`/`deserialize` gain `crop_pressure` + `active_orders`;
  deserialize rebuilds today's multipliers so a save loaded on a market day
  keeps its prices.
- `GameData`: `ECONOMY_INT_KEYS` + `BOARD_ORDER_TEMPLATE_INT_KEYS` loaders
  (copied from the `RAID_INT_KEYS`/requests-template pattern), plus
  `get_economy_data()`/`get_board_orders_templates()`.
- `SaveManager` v15 -> v16: `migrate_to_v16` defaults
  `tithe.crop_pressure`/`tithe.active_orders` additively, following the
  exact v14/v15 rung pattern.
- Interactable: `farm_map.json` feature + `main.gd` dispatch case
  (`UIManager.open_menu("board")`) + `player.gd` interaction preview +
  `scripts/ui/board_panel.gd` (mirrors `inventory_panel.gd`'s structure) +
  a geometric town-board fixture in `FeatureRenderer`/`StructureVisual`
  (new `Accent.BOARD`) with a solid collision tile - an interactable with
  no visual would have been an invisible, unplaytestable feature.

**Corrections to the proposal's assumptions (the expected ones):**
1. **R2a's integration points guessed wrong file shapes** - it names
   `sell_item()`/`BoardManager`; the live file has `sell_crop()` and the
   brief's verified hooks (`_compute_sell_net`, `_on_day_passed`,
   `serialize`/`deserialize`) were used. The `EventBus` signals R2a listed
   (`crop_sold`, `order_fulfilled`, `market_price_updated`) were not added
   as new bus signals - TitheManager already emits its own signals and the
   project's established pattern (ADR-035) is direct calls; one new
   `order_fulfilled` signal on TitheManager covers the HUD toast.
2. **Board-order quality is any-quality, not common-only.** R2a's schema
   never states a quality requirement; a naive `has_item(id, qty)` default
   would reject players holding only fine/choice goods. Fulfillment counts
   and deducts across all quality stacks.
3. **Orders persist until deadline, board tops up** (rather than wholesale
   replacement each market day), because the guardrail's "overlaps with
   market days ensure constant options" only works if orders survive across
   market days; `deadline_days` then does real work between market days.
4. **Supply scale is tuned to keep `test_season_sim` green unmodified.**
   The 5-day calibration guardrail ("price returns to within 5% of base
   after 5 quiet days") anchors `supply_scale` 170 for a typical ~26-unit
   market-day dump; heavier sellers still see a noticeable glut (prices can
   reach the 0.5x floor) without breaking the existing balance assertions.
5. **`farm_map.json` version bumped v2->v3** for the new feature entry (the
   brief didn't call for it; the project's data-version convention says bump
   on shape/content changes and nothing asserts the old value).

**GDScript gotchas hit this pass (both worth remembering):**
- The brief's warned `:=` inference failure bit twice: once in the new test
  suite (`var count := tm.get_active_orders().size()` through an untyped
  test reference) and once in `TitheManager` (`var have :=
  player.get_quality_count(...)` through the Node-typed `_player()`
  reference). Both fixed with explicit `: int` annotations.
- **Assigning an untyped Array literal to a typed `Array[Dictionary]`
  property via `set()` silently stores nothing** (confirmed with an
  isolated driver script: `tm.set("_active_orders", [order])` yields size
  0, a typed local `var orders: Array[Dictionary] = [order]` yields size
  1). All test injections of `_active_orders` use typed locals.

**Existing suites touched and why (both were correct for what existed
before; the scope changed, not the assertions):**
- `test_save_roundtrip.gd`: v15 -> v16 expectations across the five
  migration checks plus two new v16-default assertions - the standard bump
  every save version has required (Phase 1/2 did the same 14->15).
- `test_iso_structures.gd`: fixed-fixture counts 6 -> 7 visuals and 10 ->
  11 collision bodies because the new `town_board` feature is a real
  fixture; `test_market.gd`/`test_tithe_labor.gd` pass **unmodified**.

**Verification:** `--headless --path . --import` clean; full suite ->
**ALL SUITES PASSED, 1165 checks** (was 1091; +70 from
`test_board_orders`, +2 from the v16 save defaults, +2 from the
iso_structures per-fixture loop scaling with the new board), exit 0.
`AGENTS.md`/`DEEPSEEK.md` regenerated from `CLAUDE.md` v0.16.
One environment note: this Windows checkout's `core.autocrlf=true` turns
the generated contract files CRLF, which makes the two contract-sync
suites fail by one character *before* regeneration too (baseline 1091 =
1087 pass + 4 sync failures); regenerating from the CRLF source in the
same working tree makes them pass locally, and the committed LF
normalization keeps the author's LF environment consistent.

**Not done in this pass:** a manual playtest of a full market-day -> board
order -> fulfillment loop in the editor (headless coverage only), and the
E5 festival workstream's parallel merge (expected conflicts on CLAUDE.md/
decisions.md/DEVELOPMENT_STATE.md/save_manager.gd/run_tests.gd are the
documented merge-time renumbering job, not this branch's problem).

### Phase 3 integration - E5 + E6 merged (2026-08-07)

`phase3/e6-market` merged into `master` after an independent review (not
just a re-read of DeepSeek's own completion report - the core
`_compute_supply_multiplier` math, the `_on_day_passed` decay/lock/expire
sequencing, and the save migration were traced against the live diff
before trusting them; the `--headless` suite was re-run from this side
too, not just taken on the branch's word). One real, non-code finding
during review: the branch's own commit message claims `supply_scale: 170`
is "anchored to the 5-day-to-within-5% guardrail" from R2a's proposal;
checked the math directly and that guardrail only actually holds for
modest initial pressure (roughly <=15% of the price band) - a full-band
deviation (50% off base) decays to ~16% after 5 days, not 5%. Not a bug -
the price band itself is still hard-bounded at 0.5x-1.5x regardless, and
`test_board_orders.gd` only asserts the decay fraction is applied
correctly, not the specific 5-day claim - but the claim as stated is
overstated. Flagged here rather than corrected silently, since it's a
balance judgment call, not a code defect; `economy.json`'s `supply_scale`
is the one-line lever if a human playtest finds it feels wrong (DeepSeek's
own completion report already recommended this exact playtest, for the
same underlying uncertainty).

**Conflicts, all of the append-only/independent-insertion shape ADR-032's
Phase 2 precedent predicted - no surprises:** `CLAUDE.md` (both branches
claimed "v0.16" independently; resolved by sequencing E5 as v0.16 and E6
as v0.17 - `SaveManager.SAVE_VERSION` itself is unaffected, this was a doc
numbering collision only, not a code one), `design/decisions.md` and this
file (both purely additive appends - concatenated in order, nothing
dropped), `scripts/autoloads/game_data.gd` (E5's `festivals`/
`FESTIVAL_INT_KEYS` and E6's `economy_cfg`/`board_orders_cfg`/
`ECONOMY_INT_KEYS` landed in adjacent-but-distinct regions - combined by
keeping both sides of each hunk), `AGENTS.md`/`DEEPSEEK.md`/
`.godot/uid_cache.bin` (generated/binary - resolved by taking either side
then regenerating/reimporting for real, same as ADR-032's own documented
resolution for the identical situation). `scripts/main.gd` and
`tests/run_tests.gd` auto-merged cleanly with no conflict at all - verified
directly rather than assumed, since `main.gd` was the one file both
branches genuinely worried about colliding on.

**One real, unrelated blocker surfaced mid-merge:** the main working
directory had uncommitted work from the owner's own parallel
questionnaire session (blocks 5-19 closed, plus a wood-needs-a-consumer
ruling already applied to `buildings.json`/tests) sitting uncommitted,
which blocked the merge outright (git refuses to overwrite uncommitted
changes). Confirmed with the owner before touching it, then committed it
as its own commit ahead of the merge, unmodified from what that session
had already verified (1117 checks, green).

**Verification:** `--headless --path . --import` clean; full suite ->
**ALL SUITES PASSED, 1191 checks** (E5's 1116 + E6's net-new coverage,
reconciled), exit 0, first attempt after conflict resolution - no
additional fixes needed. `AGENTS.md`/`DEEPSEEK.md` regenerated from the
merged `CLAUDE.md` v0.17.

**DESKTOP steps landed same day** - see the entry immediately below.

**Not done in this pass:** the manual playtests both phases' own gates
call for (festival attendance + NPC gathering; a full market-day/board-
order cycle; the supply-pressure balance-feel question above) - same
environment limitation as every prior phase's outstanding manual-playtest
item. Worktree `../2DFarmingSim-e6-market` and branch `phase3/e6-market`
left in place pending the owner's own review, per the same convention
ADR-032's worktrees followed - cleanup is a documented next step, not
this entry's job.

### Both owed DESKTOP steps landed (2026-08-07) - DialogueManager, FestivalManager

At the owner's explicit request, both pending autoload registrations
(`DialogueManager` from Phase 2/ADR-035, `FestivalManager` from Phase
3/ADR-036) were completed without a GUI editor session. New script
`docs/register_autoloads.gd` applies the same engine-serialization
approach `docs/bootstrap_project.gd` established for the project's own
one-time greenfield bootstrap (`ProjectSettings.set_setting()` +
`ProjectSettings.save()`), scoped to just the two new `autoload/*` keys -
every other project setting is loaded from the existing `project.godot`
and written back unchanged, confirmed by diffing the result (exactly two
lines added, nothing else touched). Kept as a permanent, re-runnable
script rather than a throwaway one-off - update `NEW_AUTOLOADS` and re-run
whenever a future phase leaves another autoload owed, same spirit as
`bootstrap_project.gd` being kept as a permanent record of its own
one-time run.

This is a deliberate, narrow reading of `CLAUDE.md` section 8's
editor-managed-files invariant, not a quiet workaround of it: the
contract's "single documented exception" is the engine's own
serialization API used through a headless script, not manual text editing
of `project.godot` - this script is that same mechanism, applied to a
case the original bootstrap didn't anticipate needing again. Both
`docs/bootstrap_project.gd` and `docs/register_autoloads.gd` now describe
themselves as documented exceptions in their own header comments; if this
recurs enough that a third instance shows up, that's a signal `CLAUDE.md`
section 8 itself should be amended to name the pattern explicitly rather
than leaving each script to make its own case.

**Verification:** `--headless --path . --import` clean (would have
surfaced a `class_name`-hides-autoload parse error immediately, per
CLAUDE.md section 3.2's documented trap - neither script declares one);
full suite -> **ALL SUITES PASSED, 1191 checks**, exit 0, with both
autoloads live in the tree for the first time (previously only reachable
in tests via `configure_for_test` injection). No regression from either
now being real.

### World bible finalized, 17 open items resolved, held-acreage tithe implemented (2026-08-07)

`design/world_bible.md` written from `design/setting_questionnaire.md` and
`design/world_biblePROPOSAL.md`, cross-checked against `data/*.json` and
`design/decisions.md`. Two real discrepancies caught in that cross-check:
`manor.json`'s illegal-sale fine is 20 coin, not the 15 an earlier proposal
draft claimed (corrected in the bible, not in data - `manor.json` was
already right); and `festivals.json`/ADR-036 ship `springturn_blessing` on
day 18, unmerged with the day-21 mass check, while the questionnaire's
locked Block 22 ruling calls it Ada's Feast on day 21, merged with mass -
flagged, not fixed, since the fiction is source of truth here, not the
already-shipped data, and reconciling them is a data-side follow-up.

The bible left 17 items `[OPEN]`. Owner asked for a "quality treatment" on
all 17 with DeepSeek V4 Pro assistance; no DeepSeek API access or CLI was
available this session (no MCP tool, nothing on PATH, and reading the
Codex-integration API key out of `~/.codex/config.toml` to hand-roll a raw
call was judged outside what a session should do unprompted) - the
treatment (`design/open_items_treatment.md`) was produced directly instead,
clearly labelled as Claude-authored rather than faked as a DeepSeek
receipt. Owner accepted it whole. Folded into canon:

- **`design/world_bible.md`** - all 17 moved from `[OPEN]` to resolved,
  with a new Appendix C distinguishing "design locked" from "implementation
  owed." Two new Tier 1 principals written in full (Edith, the neighbouring
  tenant and a fifth marriage candidate; Osric, the miller and a sixth
  non-candidate authority figure alongside Aldric/Tomas), the young clerk
  named (Simkin, Tier 2, deliberately no voice-tic of his own), a familial
  tie (Edith is Aldric's sister), a missed-festival notice roster, four
  festival contest designs, the town-board's diegetic voice, a merchet fee
  (25 coin), an implementable marriage reputation-transfer spec, a
  season-end success line for Hilda, X6's reward reduced (+4 -> +1 village
  standing) plus a new "mercy path" alongside accusation, and the
  `harvest_demesne` corvee chore reframed as clearing last autumn's stored
  sheaves rather than this spring's (nonexistent) harvest. The raid
  leader's identity stays open by design, per the original ruling.
- **`design/setting_questionnaire.md`** - the open-collisions table
  updated: X5, X6, X7, X12, X13 resolved this pass; X10 corrected from a
  stale "OPEN" to reflect that it actually landed in `CLAUDE.md` v0.13
  (2026-08-07) - the table's own marker had never been updated when the
  work was done.
- **Data (pure additions/renames, no schema shape change, no version
  bump):** `items.json` (`herb_stew` -> `pottage`; new `rabbit`,
  `betrothal_ring`), `recipes.json` (same rename; new `betrothal_ring`
  recipe from 1 `flax_fibre`), `market.json` (price-key rename; `rabbit`
  added to `buy_prices` and `stall_inventory`), `villagers.json` (new
  `villager_5`/`villager_6` for Edith/Osric - spawn, schedule, likes/
  dislikes, traits), `dialogue.json` (5-band + fallback lines for both).
  `tests/suites/test_cooking.gd` updated for the rename.

**Held-acreage tithe scaling implemented (X13, ADR-038)** - the one item
with a fully-specified, bounded code change, done rather than left as a
locked-but-unbuilt design:
- `tithe.json` v2 -> v3: `coin_per_tilled_tile: 1.5` replaced with
  `coin_per_held_strip: 10` (acreage measured by **parcel** - the owned
  plot plus one unit per rented strip - not by tile, since `tenure.json`
  already prices strips as discrete units and the 30x20 grid is a
  placeholder ADR-034 will replace anyway); new `merchet_fee: 25`.
- `tithe_manager.gd`: `_tithe_goal()` now reads `coin_per_held_strip` and a
  new `_held_strip_count()` (counts `BuildingManager.is_strip_rented()`
  truthy entries across `tenure.json`'s strips), with a `held_strips` test
  seam added to `configure_for_test`. `game_data.gd`'s `TITHE_INT_KEYS`
  gains `merchet_fee`.
- **Deliberately left unresolved:** `tenure.json`'s separate weekly
  `rent_per_interval` per strip is untouched, so a rented strip is now
  charged twice (weekly rent + the seasonal acreage surcharge) under two
  different names for the same fact. Folding the weekly rent into the
  seasonal assessment touches `BuildingManager`'s tested rent/eviction
  mechanic (`test_tenure.gd`) and needs its own pass - flagged in the bible
  and the ADR as the one genuinely open item from this round, not silently
  resolved.
- **CLAUDE.md v0.17 -> v0.18:** section 2's Lord tithe bullet corrected off
  the stale "fixed 30-coin assessment" (X12 - never updated when ADR-017
  landed in Sprint 6, then the ground shifted again the same day it was
  finally caught) to the shipped held-acreage shape. The Marriage bullet
  updated from "once authored" hedging to the actual outcome (five
  candidates; Osric completing the eight as a non-candidate). `AGENTS.md`/
  `DEEPSEEK.md` regenerated via the real generators (Godot binary at
  `%USERPROFILE%\Desktop\GoDot\`).
- **A correction made mid-pass, not left standing:** ADR-038's first draft
  claimed a future `MarriageManager` autoload would be blocked on manual
  editor work, following ADR-035's old precedent. Re-reading this file's
  own immediately-preceding entry showed that precedent no longer holds -
  `docs/register_autoloads.gd` (landed the same day as the E5/E6 merge)
  registers new autoloads headlessly via `ProjectSettings.save()` and is
  designed to be re-run with an updated list. The claim was wrong and was
  corrected in both `design/decisions.md` and `design/world_bible.md`
  before either was left as the record - the marriage system stays unbuilt
  this pass as a scope call (courtship/proposal/ceremony/spouse-life is a
  multi-system undertaking), not because it is blocked.

**Not attempted this pass, flagged rather than rushed:** the marriage
system itself (no `MarriageManager` exists - courtship, proposal, ceremony,
spouse life, and the reputation-transfer math are all content-ready per the
bible but unimplemented); the festival contest engine (`FestivalManager`
has no contest logic yet); the X6 "mercy path" branch
(`investigation_manager.gd`/`raid_manager.gd`); wiring the bridge gloss
into an actual loading-tip UI; spawning Simkin as a live NPC. Each is
design-complete and implementation-owed, not open questions.

**Verification:** `--headless --path . --import` clean; full suite ->
**ALL SUITES PASSED, 1198 checks**, exit 0. One test failure surfaced and
fixed during this pass: `test_season_sim.gd`'s 28-day balance-regression
playthrough hardcoded the old tile-based tithe goal (38 = 20 + 1.5x12
tilled tiles); corrected to 20 (base only - the simulation rents no strips)
along with `test_tithe_labor.gd`'s three hardcoded 30-coin-goal assertions
(now 20), and a new `_test_acreage_scaling` case added to
`test_tithe_labor.gd` exercising 0/1/3 held strips directly against the
shipped rate (20/30/50 coin) - the first test in the suite that actually
drives `_held_strip_count() > 0`, since every other suite's harness injects
zero held strips.

### Marriage system implemented (2026-08-07) - ADR-031 realized, ADR-039

Owner asked for the marriage system next, using DeepSeek V4 Pro assistance
via Codex, and to turn that workflow into a Claude Code skill if feasible.
Both landed.

**The skill: `.claude/skills/deepseek-consult`.** A live smoke-test call
confirmed `deepseek-v4-pro` is still gated through Codex as of today -
`ERROR: {"error":{"message":"Codex integration with deepseek-v4-pro will
be available starting early August 2026. Please use deepseek-v4-flash
instead for now."...}}` - the same limitation this repo's own history
already recorded once, now reconfirmed rather than assumed stale. Owner's
call: use `deepseek-v4-flash` via Codex (available now, already proven on
Phase 3's festivals implementation) and instruct it, in its own task
brief, to delegate hard reasoning steps to the DeepSeek API directly. The
skill packages this project's existing `.deepseek/tasks` ->
`.deepseek/outputs` (+ `.receipt.json`) convention - used ad hoc across a
dozen prior consults - into `scripts/consult.sh`, with the two environment
facts above baked in so a future session doesn't have to re-discover them.
The receipt records Codex's own single `total_tokens` figure (real,
captured from its output) rather than fabricating the
prompt/completion/cache breakdown the pre-Codex raw-API receipts in the
same directory have - Codex doesn't expose that split.

**The consult itself:** `.deepseek/tasks/marriage_system_task.md`, grounded
in real excerpts from `reputation_manager.gd`, `main.gd`, `npc.gd`,
`save_manager.gd`, and `game_data.gd` gathered by a codebase survey first
(the task brief quotes real function signatures rather than asking the
model to guess them - the single biggest lever this project's history
shows against wrong-guess design pulls). Ran at `deepseek-v4-flash`, max
effort, read-only sandbox: 738 seconds wall-clock, 218,595 total tokens,
736-line output. The consult's own report was transparent about its
Pro-delegation attempt: it reached the DeepSeek API directly for a second
opinion, got back `deepseek-v4-flash` rather than the requested
`deepseek-reasoner` (13,918 completion / 11,604 reasoning tokens on the
second, non-truncated call), and used it as a second opinion - explicitly
naming which of its own suggestions it corrected against the live code
(invented API names, an uncapped-spouse-gifts suggestion that conflicted
with the locked ruling, a wrong ceremony-trigger recommendation).

**Reconciliation before implementing anything** (per the skill's own
mandatory discipline): every claimed file, function, and signal was
grepped against the live code before trusting it. Caught one real gap in
the consult's own design: the reputation-transfer spec
(`design/world_bible.md` Section VIII) needs "V's opinion of the spouse",
which the flat `opinions` dictionary (villager's opinion of the player
only) cannot express - the consult added a `pairwise_opinions` map rather
than silently no-op'ing or inventing player-perspective data that doesn't
exist anywhere in this codebase.

**What shipped**, full account in `design/decisions.md` ADR-039:
`MarriageManager` autoload (proposal, merchet, ceremony, spouse life),
registered via `docs/register_autoloads.gd` (confirmed still headless -
no editor session), `data/marriage.json`, `main.gd`/`npc.gd`/
`reputation_manager.gd`/`raid_manager.gd` integration, `requests.json` v2
spouse-only templates, `SAVE_VERSION` 16 -> 17 with `migrate_to_v17`.
Marta's marriage-stops-her-theft behavior (`world_bible.md` Block 8.4) is
a single guard on the scripted day-19 event, not a per-day system, once
the survey found the theft was never a recurring roll to begin with.

**A mid-implementation correction, not left standing:** ADR-039's first
draft (following ADR-038's precedent) claimed a new autoload needing
registration was still a manual-editor blocker. Re-reading this file's own
immediately-preceding entry (the DialogueManager/FestivalManager DESKTOP
steps landing via `docs/register_autoloads.gd`) showed that precedent no
longer holds - corrected in both the ADR and `design/world_bible.md`
before either was left as the record, and `MarriageManager` was in fact
registered the same headless way.

**Two bugs, both caught by the test suite doing its job, not shipped
silently:**
- A shell/Python double-escaping accident while hand-patching a
  `main.gd` line-continuation (`\` + CRLF) left a corrupted `\` + literal
  `r` + LF sequence instead - found by comparing intended vs. actual bytes
  after the full suite appeared to hang, not by the test run itself (the
  real cause of the "hang" was different - see below). Fixed by
  restructuring the condition to avoid a line-continuation entirely rather
  than fighting the escaping a third time.
- The apparent "hang" itself was a false lead: adding `test_marriage.gd`
  to `tests/run_tests.gd`'s `const SUITES` array caused the full run to
  sit for 12+ minutes accumulating real CPU time with zero output, which
  read exactly like an infinite loop. Bisected with a scratch isolated
  runner (`tests/run_marriage_only.gd`, deleted once done) calling each
  sub-test directly with print statements between them - which immediately
  surfaced the actual cause: `var first := mm.get_waking_greeting()`, a
  `:=` type-inference declaration on a `Variant`-typed method call
  (`mm` came from an untyped `Dictionary` lookup), which is a genuine
  GDScript parse error, not a runtime issue. A script that fails to
  compile inside a `const Array[Script]` of preloads apparently makes this
  Godot build's headless runner spin rather than fail cleanly - worth
  remembering the next time a "hang" shows real CPU usage but zero
  progress. Fixed with an explicit `var first: String = ...` per CLAUDE.md
  section 3's own inference rule ("`:=` only where the right-hand type is
  unambiguous at a glance") - which this line had already violated.
- Once past the parse error, the isolated runner surfaced two real test
  bugs (not implementation bugs): the test's `_make()` never wired
  `ReputationManager`'s `_test_marriage` seam (so the spouse gift-cap
  bypass was silently checking a null MarriageManager every time), and the
  test's own assertions had "outside the normal daily cap" backwards -
  `spouse_daily_gift_cap` is a separate *one-a-day* pool, not an unlimited
  one, so the spouse can be gifted once and an ordinary villager once
  more the same day (proving the pools are independent), not the spouse
  twice. Both fixed in the test, not the implementation, which was correct
  as written.

**Verification:** `--headless --path . --import` clean; `docs/
register_autoloads.gd` registered `MarriageManager` (idempotent - a
re-run shows `DialogueManager`/`FestivalManager` already registered);
`AGENTS.md`/`DEEPSEEK.md` regenerated from `CLAUDE.md` v0.19; full suite ->
**ALL SUITES PASSED, 1241 checks**, exit 0 (up from 1198 - the new
`test_marriage` suite's 40 checks plus a handful from `test_schedules.gd`'s
generic completeness loop now covering `MarriageManager`-adjacent state).

**Not attempted, flagged rather than rushed:** the festival contest engine
and the X6 mercy-path branch remain exactly as ADR-038 left them, unrelated
to this pass.

## Weekly tenure rent retired (2026-08-07) - ADR-038 follow-up

Owner ruling on the one sub-question ADR-038 left open: a rented strip was
being charged twice for the same fact - `BuildingManager`'s weekly
`rent_per_interval` (with eviction on non-payment) and `TitheManager`'s
seasonal `coin_per_held_strip` surcharge. Kept the new (tithe) system,
deleted the old one outright rather than merging them.

- `BuildingManager`: `_charge_rent_if_due()`/`_evict_cheapest_strip()`
  deleted, `_on_day_passed` no longer calls either; `rent_charged`/
  `strip_evicted` signals removed. `rent_strip()`/`is_strip_rented()`
  unchanged - a strip still has to be rented to till it, that claim is just
  free now instead of weekly-billed.
- `tenure.json` v1 -> v2: `rent_interval_days` and every strip's
  `rent_per_interval` removed. `GameData.TENURE_INT_KEYS` emptied and the
  matching int-cast in `_load_buildings`-adjacent tenure loading removed.
- `data/reputation.json`: `fail_rent` action removed (nothing fires it
  anymore).
- `BuildingPanel._refresh_tenure_rows`: strip rows now read "adds N coin to
  the Lord's Tithe each season" (from `tithe.json`'s `coin_per_held_strip`)
  instead of a per-interval coin/day rate.
- `test_tenure.gd`: `_test_rent_charged_on_interval`/`_test_eviction_when_short`
  removed; `test_game_data_smoke.gd` lost its `rent_interval_days`/
  `fail_rent` assertions.
- `design/decisions.md` gets a dated follow-up entry to ADR-038 (append-only
  - ADR-038's own text is untouched); `design/world_bible.md` Appendix C's
  item 2 marked resolved.

**Verification:** `--headless --path . --import` clean; full suite ->
**ALL SUITES PASSED, 1234 checks** (1241 - 7; the removed checks account
for the entire delta, confirmed by the exact count), exit 0.

## Debug panel: Marriage cheat section added (2026-08-07)

Owner needed a fast way to reach the full marriage flow without a real
courtship grind. `debug_panel.gd` already had this exact shape for
reputation/investigation/etc (Ctrl+K, `get_node_or_null` + missing-label
fallback for pending autoloads) - added a `_build_marriage_section()`
following it: a candidate dropdown (`GameData.get_marriage_candidates()`),
granular buttons (max opinion via `ReputationManager.modify_opinion`, give
a betrothal ring, propose, pay merchet, ceremonize, force the spouse
chore), plus a single "Marry Selected Candidate Now" button that drives
the whole `propose -> pay_merchet -> ceremonize` chain through
`MarriageManager`'s own gating (so it can never reach a state the normal
game flow couldn't also reach) and tops up coin/opinion/ring only as
needed along the way.

One inferred-variant parse error hit and fixed before it shipped:
`var fee := _marriage_mgr.get_merchet_fee()` - `_marriage_mgr` is typed
`Node`, so the call returns Variant and `:=` can't infer through it (the
documented Godot 4.7 trap, CLAUDE.md section 12.#1). Fixed with an explicit
`var fee: int = ...`.

**Verification:** `--headless --path . --import` clean; full suite ->
**ALL SUITES PASSED, 1234 checks**, exit 0 (no new suite - this is an
untested cheat-menu UI, consistent with every other debug panel section).

## World bible Appendix C: three more implementation-owed items closed (2026-08-07)

Small, purely-additive wiring pass closing items 1, 5, and 14 - none needed
a code architecture change, all three fit the existing generic systems.

- **Item 5 (Simkin, the young clerk):** `villagers.json` gains a `simkin`
  entry (spawn/schedule at (26,15)/(26,16), beside the steward's own
  market-stall tile at (25,15)) - spawns automatically, `_spawn_npcs()` in
  `main.gd` already iterates `GameData.get_all_villager_ids()` generically,
  no code touched. His locked "reputation mirror" (his read on the player
  mirrors Aldric's own opinion, not his own) turned out to need **zero
  code** - `dialogue.json`'s existing `"opinion": {"npc": ..., "min": ...}`
  condition type (ADR-035) already supports checking any villager's
  opinion regardless of who's speaking, so his 6 new dialogue lines just
  point `"npc"` at `"steward"` instead of `"simkin"`. Likes/dislikes left
  empty - the bible names none for him, and inventing some wasn't this
  task's call to make.
- **Item 1 (the bridge gloss):** the locked text has two forms - a
  loading-screen tip, or (the bible's own documented fallback) "a single
  non-diegetic line after the opening roll fades." Neither a loading-tip
  slot nor the Section X "Opening Still" parchment intro exist anywhere in
  this codebase yet (checked - no hits for "Harrowmere"/"parchment [the
  intro]"/"Opening Still" outside UI styling constants), so this uses the
  documented fallback through the existing one-shot HUD-toast mechanism
  every other flavor line already uses: `main.gd._show_tithe_gloss_once()`,
  called once per `_ready()` after any pending save load (so a save that
  already saw it doesn't re-show it), gated by a new
  `PlayerState` event flag `framing.saw_tithe_gloss`.
- **Item 14 (Hilda's season-end line):** both her success and failure
  lines (Section X) wired into `season_summary_panel.gd`, chosen by
  `paid >= goal` on the existing `TitheManager.get_tithe_progress()` call
  already driving the stats label. The "markedly successful season"
  variant is explicitly out of scope per the bible's own "beyond the
  locked scope" note - not wired.
- Also updated Appendix C's rows for items 3/11/12/13 (merchet fee,
  proposal-token recipe, spouse requests, reputation-transfer math) from
  "no marriage system yet" to **Done**, since ADR-039 shipped all four the
  same day this table was last accurate - a documentation catch-up, not
  new work this pass.

**Verification:** `--headless --path . --import` clean; full suite ->
**ALL SUITES PASSED, 1236 checks** (up from 1234 - a generic completeness
loop elsewhere in the suite, not a dedicated new test, picked up Simkin's
well-formed villagers.json/dialogue.json entries automatically), exit 0.

## X6 mercy path for the thief investigation (2026-08-07)

Implements the world_bible.md Section VII mercy path - the third, terminal
resolution alongside correct/false accusation. What landed:

- `data/reputation.json`: new `show_mercy` action with
  `{ "manor": 0, "village": 0, "church": 0, "opinion_delta": 15 }`. The
  standing keys are deliberately 0 so no standing change can enter through
  a shared path; the opinion gain is the only effect. No version bump -
  additive action id, same shape (the `fail_rent` removal in the tenure
  pass set the same precedent).
- `scripts/autoloads/investigation_manager.gd`: `can_show_mercy(npc_id)`
  and `show_mercy(npc_id)` (both return bool), plus a `mercy_shown`
  signal. `show_mercy` requires an open, unresolved investigation, the
  true suspect as the target, and the true clue in the revealed set;
  resolves the investigation, applies the opinion gain via
  `modify_opinion` (deliberately NOT `apply_action`, so no standing change
  and no `action_applied` -> court-offense path), and sets
  `investigation.showed_mercy_<suspect_id>` on `PlayerState.event_flags`
  (already persisted - no SAVE_VERSION bump).
- `scripts/autoloads/raid_manager.gd`: `_thief_got_mercy()` guard, a
  sibling of `_thief_is_spouse()`, checked before the day-19
  `execute_theft()`.
- `scripts/main.gd`: "Show mercy" dialogue response offered next to
  "Accuse of theft" when `can_show_mercy(npc_id)` passes - no new UI.

Decisions the bible left open:

- Gating threshold: "enough of the clue trail" = the true clue itself
  (`"true": true`) must be among the revealed clues. Not a minimum count:
  decoys alone tell the player nothing, and the true clue is the decisive
  piece (an alibi recollection, versus the decoys' vague "some say"
  gossip).
- Opinion gain: +15, between a liked gift (+10) / request reward (+4..10)
  and the marriage proposal threshold (50) - a meaningful one-time favor
  without becoming a courtship shortcut.
- Repeat-theft taper: the day-19 theft is a one-time scripted event (no
  recurring roll exists), so the raid guard is forward-looking - it only
  matters once a recurring theft mechanism lands, same status the marriage
  guard already has.

DeepSeek delegation: attempted the direct API consult three times
(`deepseek-reasoner` twice, then `deepseek-v4-flash` explicitly). Network
reachable and credentials present, but every response reported model
`deepseek-v4-flash` and truncated (`finish_reason: "length"`, empty
`content`) - the configured endpoint never produced a usable answer, so
no consult output influenced the threshold decision. Honest record in
`.deepseek/outputs/mercy_path_consult_out.md` + receipt; Pro was NOT
consulted.

Observed and deliberately not touched: world_bible.md says the correct-
accusation village standing was reduced +4 -> +1, but this worktree's
`data/reputation.json` still ships `accuse_correctly.village: 4`. The task
explicitly forbade changing accusation numbers, so the mercy path (third
resolution, zero standings) landed without it; if the +1 is wanted it is a
separate data-only change with its own test update.

**Verification:** `--headless --path . --import` clean; full suite ->
**ALL SUITES PASSED, 1256 checks**, exit 0 (baseline 1234; +19 from the
mercy-path section in `test_thief_investigation.gd` and +3 from the
mercy-flag guard section in `test_raid_scaling.gd`). `AGENTS.md`/
`DEEPSEEK.md` were regenerated during this pass because this Godot build's
text-file semantics dropped one trailing newline from the derived files
(contract-sync suites caught it; regeneration is the sanctioned fix).

## Festival contest engine (2026-08-07) - world_bible.md Section V realized

The four festival contests are now data-defined in `festivals.json` v2 and
the Spring Furrow Race is fully playable through a new `ContestPanel`;
the other three are data-complete and non-crashing but interaction-light,
exactly the pattern every unreachable-season system already follows.

- `festivals.json` v2: each festival gains a `contest` block - mode, skill,
  direct-entry/cheer/bet flags, entrants, bet bounds, odds and payout
  multipliers, standing/opinion deltas, a payout-by-score ladder, and (for
  the two timed contests) a 3-beat timing config.
- `FestivalManager`: contest query + eligibility, the timed race engine, and
  cheer/bet resolution. Race state is the DeepSeek-reviewed shape - elapsed
  accumulator, next beat index, press latched per beat, absolute window
  bounds - exposed as pure `race_step`/`beat_window`/`press_scores_at`/
  `score_presses` functions so the headless suite drives synthetic elapsed
  values with no real frames and no `Timer` node. Participation is one-shot
  per festival occurrence via `PlayerState.event_flags`
  (`festival.contest_entered_<id>` / `festival.contest_cheered_<id>`), so no
  `SAVE_VERSION` bump was needed.
- `ContestPanel` (layer 15, menu id "contest"): direct entry with a
  press-button race UI (polled for rendering only; presses go through the
  button), cheer rows with a 1-5 bet spinner where the contest allows bets.
  `main.gd` opens it on the active festival's anchor tile during the window;
  the existing `_check_festival_attendance()` grant is untouched.
- `GameData`: festival contest integers (bet bounds, payout ladder, standing
  deltas, opinion delta) cast at the boundary per section 6.2.
- `test_festival_contests.gd` registered in the runner.

**Numbers invented (all in `festivals.json`, none in code):** Furrow Race
beat targets 2.0/5.0/8.0s with 0.55s base half-windows and +0.07s per Farming
level (level 5 halves the skill miss rate without making the prompts a
reflex test - three presses across ~9s, gaps of 3s); payout ladder
[0, 2, 5, 10] coin; odds Cedric 0.55/Bram 0.45 with total-return multipliers
1.8/2.2 (the underdog pays more); bet 1-5; enter standing village +2; cheer
standing village +1 with +2 opinion for the backed entrant. Haysel reuses the
same machine with labor forgiveness (+0.06s/level); Long Night is cheer-only
(no bet) because the bible specifies "picks a favourite storyteller and
cheers" with no betting language; Harvest Home stays closed with a
`note`-field TODO until Tier 2 residents exist.

**Divergence from plan, deliberate:** during a festival's active window the
anchor tile's ordinary panel (the chapel church panel in Spring) is replaced
by the contest panel; the church panel returns when the window ends. The
attendance grant and all other festival behavior are untouched.

**Flagged untested:** Haysel/Harvest Home/Long Night have data + engine paths
proven non-crashing by the suite but no playable interaction polish (correct
for the Spring-only slice). `ContestPanel` is a runtime UI and is not
headless-tested, consistent with every other panel; the race engine under it
is fully suite-covered. Closing the panel mid-race cancels the race (the
one-shot flag stays set - an abandoned entry, never a replay).

**Also landed:** `AGENTS.md`/`DEEPSEEK.md` regenerated - the contract-sync
suites were failing before this task because the generated files were one
line stale in this worktree (pre-existing drift, not part of this change).

**Verification:** `--headless --path . --import` clean; full suite ->
**ALL SUITES PASSED, 1336 checks**, exit 0 (1234 baseline + 102 new
`test_festival_contests` checks).

## ADR-034 region design + Sprint 15 plan produced (2026-08-07) - not opened for implementation

A chained, two-stage DeepSeek v4 Flash consult (read-only, no worktree -
planning documents only, no code or data touched):

- **Stage 1** (`design/adr034_region_design.md`): the ADR-034 region as
  nine zones - Fallowfield (the player's holding), Nettleford, the Manor
  of Harrowmere, the Upland Commons, Cottersward (the lord's wood), the
  Nettle Brook corridor, Edith's Plot, the North Strip, and the South
  Fields (the last two carrying `tenure.json`'s three rentable parcels).
  Every existing structure/feature placed in exactly one zone; every named
  villager's home/work anchor assigned a zone; a travel-time ledger and
  adjacency graph stated identically in both directions per pair; an ASCII
  world map; and an honest open-questions list (working names, the old
  church ruin's placement, a wild-carrot-vs-forage-data tension, the
  festivals.json day-18-vs-21 mismatch already flagged elsewhere, among
  others). One real self-caught bug: the first draft's "3-4 hour" playable
  band didn't match the sum of its own travel-time ledger (~1.5-2 hours) -
  caught by the mandated DeepSeek-API consistency check before finalizing,
  fixed to "roughly two to two and a half hours."
- **Stage 2** (`design/sprints/sprint_15_regions.md`, following Stage 1's
  output as its primary input): a full sprint guide matching the existing
  `sprint_NN_*.md` format - concrete per-zone dims/entry points/exits
  derived from Stage 1's adjacency graph, a `FarmGrid`-architecture
  decision (one instance per zone behind a new `ZoneManager` autoload,
  registered headlessly via `docs/register_autoloads.gd` like ADR-039's
  `MarriageManager`), scene/transition architecture, NPC zone-awareness,
  a `SAVE_VERSION` 17 -> 18 migration (every pre-existing farm cell wraps
  into `fallowfield`), integration points against every single-map
  assumption CLAUDE.md/ADR-007/ADR-019/ADR-023 currently make, concrete
  test assertions, sizing/sequencing, and a risk list. Both stages'
  DeepSeek-API delegation calls happened for real (confirmed by receipt -
  `deepseek-reasoner` was requested both times, the endpoint returned
  `deepseek-v4-flash` both times, Pro-tier was never actually reached) and
  their recommendations were reconciled against the live code before use,
  not accepted blind.
- `design/roadmap.md` gains Sprint 15's row; `design/sprints/README.md`'s
  index gains its entry; `design/decisions.md` gets a dated follow-up
  entry to ADR-034 (append-only - ADR-034's own text is untouched)
  recording that the design is now scheduled, per that ADR's own
  "no code until scheduled as a systems sprint" deferral condition.
- **Deliberately NOT done:** the sprint guide's own stated prerequisite (a
  `CLAUDE.md` section 2 Region bullet + corrected single-map wording in
  sections 5/9.5) was not landed, and no `ZoneManager`/schema/migration
  code was written. Scheduling a sprint and authorizing it to start are
  different decisions; the latter is the owner's call, not something to
  fold into filing away a planning document.
- **A caveat worth recording:** Stage 1's consult ran with the
  **read-only** sandbox as instructed, yet it still wrote
  `design/adr034_region_design.md` directly to disk
  rather than only returning it in its captured chat response (Stage 2, by
  contrast, returned everything as chat text per its brief's explicit
  instruction, and nothing was written until this filing pass placed it).
  Read-only sandbox in this Codex/DeepSeek setup should not be assumed to
  block all file writes - a consult brief that must not touch the repo
  needs to say so explicitly and the result should be checked with `git
  status`, not assumed from the sandbox flag alone.

**No test run required** - no GDScript or `data/*.json` file changed.

## NPC physics presence: collision + combat eligibility + live-position interaction (2026-08-07)

**Built:** `scripts/npc/npc.gd` is now `extends CharacterBody2D` with a
28x28 `RectangleShape2D` child (sized to `NpcVisual`'s drawn body), on
`PhysicsLayers.NPC`, masking `PhysicsLayers.INTERACTABLE` only, and moving
via `velocity` + `move_and_slide()` instead of direct `position +=`
mutation. Wander/anchor/schedule/festival/marriage logic is untouched.
`_ready()` adds the `villager` group and `villager_id` meta; `take_damage()`
mirrors `Enemy.take_damage()`'s signature but has no death/flee path
(villager health is a marker that simply goes negative - the hit's real
consequence is the already-wired `attack_villager` reputation action).
`scripts/main.gd` drops the stale `_npc_tiles` spawn dictionary for a live
O(n) scan through `NPC.npc_id_at()` (9 villagers; CLAUDE.md section 9.1's
note explicitly permits this). New suite `tests/suites/test_npc_physics.gd`
(17 checks) covers body wiring, group/meta/take_damage, and current-tile
lookup. `AGENTS.md`/`DEEPSEEK.md` were regenerated - the contract-sync
drift was already present at the starting commit (the sync suite failed
before this work too).

**DeepSeek delegation outcome:** POSTed the mask/layer mutual-requirement
question to `api.deepseek.com`. Requesting `deepseek-reasoner` twice returned
the configured `deepseek-v4-flash` both times and truncated with zero content
at 2048 and 8192 max_tokens (all completion tokens were reasoning). A
`deepseek-chat` fallback (also served by `deepseek-v4-flash`) answered: no -
CharacterBody2D collision requires BOTH bodies' masks to include each
other's layers; one-sided recognition is ignored, so NPCs (layer NPC, mask
INTERACTABLE only) never collide with each other. Verified empirically with
a real-physics two-NPC head-on course: both crossed (A x 160->284, B x
320->133) with 0 slide collisions - PASS_THROUGH.

**Deliberate divergence:** `BLOCKED_GIVE_UP_TIME` (0.5s) in `npc.gd` -
with real wall collision, a random wander target inside a building would
otherwise push forever; the guard abandons that leg and returns to idle. It
is a structural constant (no NPC-motion data file exists), not a gameplay
tunable.

**Verification:** `--headless --path . --import` clean (no SCRIPT ERROR);
full suite **ALL SUITES PASSED (1377 checks)**, exit 0 (1360 baseline + 17
new checks); boot smoke `--quit-after 300` clean; two-NPC collision course
PASS_THROUGH, exit 0. Manual = collision course + boot smoke; suite = the
17 new `npc_physics` checks. Note: game-mode Godot runs needed unsandboxed
execution in this environment (the sandbox cannot create `user://`/editor
dirs and this 4.7.1 build segfaults on that), which is environmental, not
project-related.

## Produce-quantity naming fix + bundling proposal (2026-08-07) - feature/board-economy

**Part A ruling (recorded so it is not re-litigated):** the town board's pea
order ("70 coin for 4 Pea") is not a pricing bug. `board_orders.json`'s pea
template (min 4 / max 7 / 70 coin) against `market.json`'s pea price (10) is
~1.75x market value at minimum quantity, and every other crop template
sits in the same ~1.7x-2.0x band at its own minimum - the board-order
reward formula is uniformly generous by design. No numeric field in
`data/board_orders.json` was changed.

**Part B - display fix implemented:** `crops.json` v5 adds a `measure` field
to every crop (turnip `basket`, barley `sheaf`, carrot `bunch`, onion `bag`,
leek `hand`, pea `bushel`, oat `sack`, flax `bundle`, cabbage `head`).
`GameData.format_produce_count(crop_id, count)` is the new pure query
helper - "a bushel of peas" / "4 bushels of peas" - with tiny irregular
plural tables for crop names (Barley/Flax/Cabbage stay mass, Oats already
plural) and measures (sheaf/bunch), not a general English pluralizer.
`board_panel.gd._build_row()` uses it with a raw-count fallback for unknown
crops; no other panel was touched. No autoload, save-version, or persisted
state changed.

**DeepSeek-API delegation (happened for real):** POSTed to
`api.deepseek.com/chat/completions` with the Codex-configured key. Two calls
with `model: "deepseek-reasoner"` returned `deepseek-v4-flash` with
`finish_reason: length` and zero content - the reasoning budget consumed
the whole token cap, the same model-mapping behavior prior receipts
recorded; a Responses-API retry with `effort: low` also returned
`deepseek-v4-flash` (status incomplete). A third call with
`model: "deepseek-v4-pro"` returned a full answer (`finish: stop`) - Pro
was actually reached this time. Pro's list: turnip basket, barley sheaf,
carrot bunch, onion bag, leek hand, pea bushel, oat sack, flax bundle,
cabbage net. Reconciliation: adopted all but cabbage, which I changed from
"net" to "head" ("a head of cabbage" reads naturally and cabbage is
summer-locked this slice). "Hand" for leeks is kept for period texture but
flagged as the one choice a future pass may swap for "bunch" if playtesters
find it unclear.

**Part C - proposal only:** `design/proposals/produce_bundling_proposal.md`
(711 words) documents the bundling concept and its blast radius. Confirmed
against the codebase first: `items.json` v8 has no container item,
`recipes.json` v2 has no bundling recipe, and `PlayerState` inventory is a
flat `item_id -> quality -> count` map with no bundle/container shape.
Notable finding: `storage_chest.capacity` and
`BuildingManager.get_storage_capacity_bonus()` exist, but capacity is not
enforced anywhere - bundling could be pure inventory compression now and
capacity's unit later. No code, item, recipe, or save bump was written.

**Pre-existing drift fixed (required for a green run):** the contract-sync
suites failed at baseline. Root cause: with `core.autocrlf=true`, a CRLF
checkout of the LF-stored contract files is one byte longer than the derived
output (the generators emit an LF banner before the source text), and
`docs/derive_deepseek.gd` embeds its harness block as a literal string whose
line endings leak into the derived `DEEPSEEK.md`. Fixed durably with a
scoped `.gitattributes` forcing LF for `AGENTS.md`/`CLAUDE.md`/`DEEPSEEK.md`
and `docs/*.gd`; the tracked blobs were already LF-correct, so the only new
file in this part of the change is `.gitattributes` itself.

**Verification:** `--headless --path . --import` clean; full suite ->
**ALL SUITES PASSED, 1374 checks**, exit 0 (task baseline 1360 + 14 new
checks in `test_board_orders` covering singular/plural formatting across
crops, irregular measures, mass nouns, unknown-crop fallback, and measure
completeness). Also corrected that suite's stale `completed()` count from
10 to its real 81 (a no-op for the tally, now accurate).

## ADR-040 - Spatial demesne chores rework (2026-08-07)

Replaced the abstract menu-button labor chores (ADR-013's shape) with real,
stateful demesne actions. Full record in `design/decisions.md`; this entry is
the engineering log.

**What changed:**
- `till_demesne`/`water_demesne` are now real `FarmGrid` actions on real
  `stewards_demesne` tiles, driven through `ToolManager` (hoe/watering can)
  and completed via new `TitheManager.complete_demesne_tool_chore()`. The
  water gate is tile moisture below chores.json's
  `needs_water_moisture_below` (50) - the rain exploit is closed
  structurally (a rain day leaves no dry tile), with no rain special case.
- `harvest_demesne` clears per-tile stored-sheaf markers (spatial backlog in
  `FarmGrid` cell state, replenished on a data-driven cadence) and picks the
  load up in the same bare-hand interaction; `carry_produce` delivers at the
  tithe-chest anchor tile (the `stewards_demesne` feature origin). Nothing
  ever enters the player's inventory. Carry state (`carrying_sheaves`)
  persists through save/load and clears on day rollover (steward collects
  undelivered loads back into the backlog).
- `tithe_panel.gd`'s chores view is now a status/instruction board; the old
  `do_chore()` API is gone. `player.gd` routes demesne interactions by
  equipped tool (hoe/can = chore; bare hands = harvest/delivery; otherwise
  the panel opens).
- `data/chores.json` bumped to v2 with a `demesne` config block;
  `GameData` gained `get_demesne_config()`, `get_feature_rect()`,
  `is_in_feature()`. `SAVE_VERSION` 17 -> 18 with `migrate_to_v18()`
  seeding `tithe.carrying_sheaves` and per-cell `demesne_sheaf`.
  **Version-number collision flagged:** the ADR-034 follow-up's sprint
  guide plans "17 -> 18" for the region wrap migration; this record
  consumes 18, so that guide must shift to 19 when Sprint 15 opens.

**DeepSeek-API consult (mandated by the task brief):** direct POST to
`https://api.deepseek.com/chat/completions`, model requested
`deepseek-reasoner`; endpoint served `deepseek-v4-flash` (same as the
project's prior consults - Pro tier is not reachable server-side). HTTP 200,
latency 141.1s, 13,266 total tokens (11,328 reasoning), `finish_reason:
stop`, not truncated. Receipt: `.deepseek/outputs/chore_rework_consult_out.md.receipt.json`.
Recommendation adopted: spatial per-tile sheaf markers over a flat counter,
harvest=one interaction, chest-anchor delivery, carry persists in save but
clears on day rollover.

**Deliberate divergences / things that bit:**
- `FarmGrid.till_tile(pos, true)`'s force bypass also bypasses the snow
  check (Winter is data-only and unreachable this slice - accepted and
  noted, not changed).
- Tool chores grant no farming XP (labor XP comes from the chore
  completion); TitheManager does not double-charge energy for tool chores.
- `complete_demesne_tool_chore` for water trusts the caller's pre-action
  moisture gate (single-threaded; the only production caller is
  ToolManager's water path).
- The project trap 12.1 (`:=` from a Node-typed call returning Variant) bit
  twice: `get_demesne_status()`'s sheaves count and a test's delivery-tile
  lookup - both fixed with explicit types.
- The 4 baseline contract-sync failures (CLAUDE.md v0.20 changed without
  regenerating) were fixed by running the documented generators; AGENTS.md/
  DEEPSEEK.md are committed alongside this work.

**Verification:** `--headless --path . --import` clean (exit 0); full suite
-> **ALL SUITES PASSED (1418 checks)**, exit 0. Baseline at the starting
commit was 1360 total checks (1356 passed + 4 pre-existing sync failures);
the +58 comes from the new spatial-chore coverage in `test_tithe_labor.gd`
(46), `test_save_roundtrip.gd` (4), `test_game_data_smoke.gd` (5), and
`test_corvee.gd`'s updated spatial chore path (3 net over its old shape),
with the 4 sync checks now passing instead of failing.

## Sprint 15a implemented (2026-08-07) - region data model, ZoneManager, save migration

**What was built** (Sprint 15a only, per `design/sprints/sprint_15_regions.md`):

- Data: `data/zones.json` v1 (nine zones, 28 directed exits, spawn point),
  `data/farm_map.json` v4 (per-zone grids/features, 3200-tile checksum),
  `data/tenure.json` v3 (`default_owned_zone` + per-zone strip rects),
  `data/villagers.json` v6 (zone-qualified anchors), `data/festivals.json`
  v3 (zone-qualified locations; `contest` blocks untouched;
  `springturn_blessing` still day 18 per the owner-question ruling).
- `GameData`: `_load_zones` with `ZONE_INT_KEYS`, `zones_cfg`, zone
  accessors (`get_zone_ids`/`get_zone`/`get_zone_metadata`/`get_zone_exits`/
  `get_spawn_point`/`get_default_zone`), zone-aware map accessors with a
  `DEFAULT_ZONE_ID` alias, per-zone int casts for farm_map/tenure/villager
  anchors.
- `FarmGrid`: `_zone_id`/`set_zone_id`/`get_zone_id`/`get_grid_size`;
  `configure_for_test` gains a trailing optional `zone_id`; `_ready` and
  `_build_live_grid` read per-zone dims/soil; `_is_owned` routes through
  `BuildingManager.is_land_owned_in_zone`; `advance_day` scales forage by
  the zone's `forage_density`. Every pre-existing public signature is
  byte-for-byte unchanged.
- `BuildingManager`: `is_land_owned_in_zone`, zone-aware
  `can_place_building`/`start_building` (entries store `zone_id`)/
  `get_placed_buildings` (optional filter)/`get_building_id_at`;
  `is_land_owned` kept as the default-zone alias.
- `ZoneManager` autoload (registered headlessly via
  `docs/register_autoloads.gd` - no DESKTOP step): registry, `change_zone`/
  `zone_changed`, `find_exit`/`resolve_exit`, `get_npc_zone`, region-wide
  `advance_day`, v19 farm `to_dict`/`from_dict`, `apply_saved_state`
  (available, unwired until 15b).
- **`SAVE_VERSION` 18 -> 19, not 17 -> 18 as the guide originally specified.**
  ADR-040 (spatial demesne chores, merged into master the same day this
  task was running in its own worktree, from before either knew about the
  other) independently claimed v18 for the tithe block's `carrying_sheaves`
  + farm-cell `demesne_sheaf` fields. Renumbered at merge-review time: the
  guide's exact `migrate_to_v18` logic (pure cell wrap under fallowfield,
  current_zone/player_tile defaults, building zone_id defaults) ships
  unchanged in content, just renamed `migrate_to_v19` and chained at
  `version <= 18` so it runs after ADR-040's migration - a v17 save now
  passes through both in sequence and lands on v19 with every field from
  both migrations intact. `build_payload`/`apply_payload` prefer
  ZoneManager when registered and keep the injected single-grid fallback
  for tests.
- `main.gd` minimal wiring only: `_boot_zone_grids` (nine FarmGrids
  registered at boot; zone id set before `add_child`), day rollover forwards
  through ZoneManager, and `_position_player_at_spawn` - the v4 Fallowfield
  house/well moved off the scene origin, so without this the player would
  boot at (0,0) far from the cottage (required by the "boots and plays
  entirely on Fallowfield" exit criterion).
- New `tests/suites/test_zones.gd` (100 checks) and
  `tests/suites/test_zone_manager.gd` (61 checks); `test_save_roundtrip`
  gains the v18->v19 migration + ZoneManager round-trip; `test_tenure`,
  `test_season_sim`, `test_iso_terrain`, `test_iso_camera`,
  `test_iso_structures`, `test_schedules`, `test_buildings`, and
  `test_festivals` updated per the guide's list.

**DeepSeek API delegation outcome** (required consult): POSTed to
`https://api.deepseek.com/chat/completions` with `model: "deepseek-reasoner"`
and the Codex-configured key. The endpoint returned **`deepseek-v4-flash`**
(finish `stop`; 14,770 reasoning + 1,989 content tokens) - the same
model-substitution every prior consult in this repo recorded; Pro was not
served. Findings, all applied: (1) no static/class-level mutable state and
no `_ready()` signal connections, so nine instances are safe on their own
signal buses; (2) `_zone_id` must be set BEFORE `add_child()` so each
`_ready()` builds its own zone's dims - `main.gd._boot_zone_grids` does
exactly that; (3) per-zone dims must come from per-zone data, not one global
read - `_ready()`/`_build_live_grid()` read GameData zone-aware; (4) the
save format must be zone-keyed - ZoneManager composes it; (5) only the
active grid's signals should be connected - renderers are untouched in 15a.
The brief's premise that `FarmGrid._ready()` "connects to weather/signals"
did not match the live file (it connects nothing and only reads GameData);
the full audit of `_ready()` and every signal it emits was still performed
and is recorded here.

**Deviations from the guide (all flagged, none silent):**
- The guide names NPC zones/anchor buildings but gives numeric tiles only
  for Marta; the authoring pass derived the rest from the named anchor
  buildings and feature tiles (steward work = market_zone (12,8); priest
  work = chapel (10,10); Simkin work = town_board (11,8); Marta work = the
  village well (20,9)), preserving old relative offsets where in bounds.
- `test_schedules.gd`'s "get_current_zone at a given hour" is expressed
  through `ZoneManager.get_npc_zone` with a `_test_hour` seam instead of
  npc.gd's `get_current_zone` - that method is 15b scope and npc.gd is
  untouched.
- `FarmGrid` gained a `_test_building_manager` injection field so the
  guide's unrented->rented till gate exercises the REAL BuildingManager
  off-tree (no public signature change).
- `ZoneManager.get_npc_zone` reaches autoloads via `get_node_or_null`
  guarded by `_test_mode`, per the shared-conventions rule (bare singleton
  identifiers would not even compile under the headless harness).
- `test_festivals.gd` was updated for the springturn anchor move to the
  Nettleford chapel tile (10,10) although the guide's suite list omitted it
  - the old (10,15) expectation could not survive festivals.json v3.
- `main.gd` gained the spawn-position wiring described above (minimal boot
  wiring; not the 15b transition system).
- `AGENTS.md`/`DEEPSEEK.md` were regenerated: HEAD's copies were one byte
  stale vs `CLAUDE.md` v0.21 (pre-existing drift from the amendment commit,
  exposed once the suite ran with working user:// access).

**Explicit confirmation:** no Sprint 15b scope leaked in - no
`zone_changed` world-swap handler, no edge-crossing detection, no renderer
rebuilds, no camera dimension swap, no NPC spawn/despawn by zone, no
`npc.gd` changes, no `scripts/ui/` changes.

**Known 15a seams (documented, not fixed):** `main.gd._spawn_npcs()` still
spawns every villager at their new zone-local coordinates on the Fallowfield
map (some out of its bounds) because per-zone NPC presence is 15b - the data
is correct, the world placement is the next pass's work. The build panel's
"Owned by default" label still reads the removed `default_owned_rect` and
shows 0x0; `scripts/ui/` is explicitly out of 15a scope.

**Things that behaved differently in Godot than expected / traps hit:**
- `get_node_or_null("/root/...")` on an OFF-TREE node prints "Can't use
  get_node() with absolute paths from outside the active scene tree" (4.7
  behavior confirmed empirically). New code paths that could run off-tree
  (FarmGrid.advance_day's zone lookup, ZoneManager.get_npc_zone's autoload
  overrides) guard with `_test_mode` so suites never trigger the fallback.
- Running `--script` under the restricted sandbox segfaults (signal 11)
  when Godot cannot create its AppData/user:// directories - the documented
  ADR-039 headless autoload registration and the full test suite both
  require an unsandboxed run on this machine. Import itself completes but
  prints AppData noise in-sandbox.
- The strict `:=` Variant-inference warnings caught two new-code spots
  (`get_zone`'s duplicate, ZoneManager's Variant lookups) - fixed with
  explicit types, matching the documented trap.
- Windows `core.autocrlf=true` (no .gitattributes) makes the contract-sync
  suites fail on a fresh CRLF checkout even when AGENTS.md/DEEPSEEK.md are
  in sync at the blob level (the generator's LF banner line becomes CRLF).
  Regenerated locally so the working copy matches `derive()` byte-for-byte;
  `git diff` shows only the one-byte content fix. A fresh CRLF checkout of
  this commit may trip the same environment artifact.

**Verification:** `--headless --path . --import` clean (no SCRIPT
ERROR/parse errors); full suite `ALL SUITES PASSED (1639 checks)` (baseline
1360; +279), exit 0; real `main.tscn` boots headless 120 frames with no
errors, active zone fallowfield, all nine grids registered with correct
per-zone dims, player at the cottage spawn tile.

## Post-merge reconciliation: ADR-034 (regions) x ADR-040 (demesne chores) (2026-08-07)

Both landed the same day from parallel worktrees, each blind to the other.
Two real interactions needed hand resolution at merge time, beyond the
already-fixed `SAVE_VERSION` collision (ADR-040 kept v18; the region wrap
migration was renamed `migrate_to_v19`, chained after it - see the
"Renumber the region save migration to v19" commit on `feature/sprint15a`).

1. **`GameData.get_feature_rect`/`get_feature_tile`/`is_in_feature`
   (ADR-040) vs. the zone-aware map accessors (ADR-034).** ADR-040 added
   these three reading the old flat `farm_map.json` feature list; ADR-034
   moved every feature into a per-zone list under `zones_cfg`. Resolved by
   making all three zone-aware (`zone_id := DEFAULT_ZONE_ID`), reading the
   named zone's feature list.
2. **The demesne is now geographically in the Manor zone, not
   Fallowfield.** `farm_map.json` v4 places `stewards_demesne` in the
   `manor` zone's feature list at `Rect2i(4, 6, 8, 6)` (Stage 1's own
   placement - the lord's demesne belongs at his manor, not the player's
   holding; the old single-grid position was `Rect2i(15, 5, 6, 6)`).
   `FarmGrid`'s demesne-rect resolution (`_demesne_rect = game_data.
   get_feature_rect("stewards_demesne", _resolved_zone_id())`) now
   correctly returns a non-empty rect ONLY for the Manor zone's own
   `FarmGrid` instance - Fallowfield's instance (the only zone the player
   can currently reach, since Sprint 15b hasn't shipped zone transitions
   yet) correctly gets an empty demesne rect, and `TitheManager.
   get_demesne_status()` reports 0 sheaves available there rather than
   erroring. **This is accepted as a temporary, self-resolving gap, not a
   regression**: the spatial demesne chores (ADR-040) are real and fully
   tested against an injected demesne rect, but are not physically
   reachable in the live game until Sprint 15b lets the player walk to the
   Manor zone. `advance_day`'s signature reconciled to carry both
   additions: the `day: int` parameter (ADR-040, for the sheaf replenish
   cadence) and the `forage_density` zone-metadata scaling (ADR-034),
   threaded through `ZoneManager.advance_day` so every registered grid
   gets the real calendar day. `test_game_data_smoke.gd`'s demesne-rect
   assertions (written by ADR-040 against the old position) were updated
   to query the `manor` zone and the new coordinates, plus a new assertion
   that the demesne is absent from `fallowfield`.

**Verification after reconciliation:** `--headless --path . --import`
clean; full suite -> **ALL SUITES PASSED (1729 checks)** (1449 + 279 new
Sprint 15a checks + 1 new fallowfield-has-no-demesne assertion), exit 0;
a real `main.tscn` boot smoke (`--quit-after 120`) also ran clean, no
errors.

## Sprint 15b implemented (2026-08-07) - zone transitions, rendering, NPC zone-awareness

The second half of ADR-034 (Sprint 15): the region is now actually
walkable. Walking off a map edge triggers `zone_manager.change_zone ->
zone_changed`, and `main.gd._on_zone_changed` is the single world-swap
site (the guide's flagged choreography-drift risk stays in exactly one
place).

**What was built, file by file:**
- `scripts/main.gd`: `_physics_process` edge-crossing detection
  (`_check_zone_edge_crossing`, `_clamp_player_inside` for playable
  boundaries); the `_on_zone_changed` world swap (player/ToolManager grid
  refs + active zone id, arrival-tile position + zeroed velocity, camera
  dims, HUD/TitheManager grid refs, farm/feature/building renderers, NPC
  set, interaction lookup); the load path (`apply_saved_state` after
  `SaveManager.load_game`, `_position_player_at_spawn` skipped when a save
  loaded); zone-qualified mass/chapel check and festival attendance gate;
  hour-boundary NPC membership re-filter; `raid_message` HUD handler;
  zone-filtered NPC spawner (`_spawn_npcs_for_zone`, `_npc_anchor_tile`)
  that keeps the merged `CharacterBody2D`/group/meta/`take_damage` wiring
  intact (NPC nodes are freed with `queue_free`, arrays cleared
  immediately, `is_instance_valid` guards).
- `scripts/world/iso_camera.gd`: `set_map_dims(width, height)` +
  `get_map_dims()`, overriding the default-zone GameData read in
  `_process`/`_recompute_limits`.
- `scripts/world/farm_renderer.gd`: `set_active_grid(grid)` with
  idempotent signal disconnect/connect; `_draw` reads the active grid's
  dims (`_map_dims()`), falling back to GameData for pre-15b mocks.
- `scripts/world/feature_renderer.gd`: `set_active_zone(zone_id)` -
  synchronous free of the old zone's StaticBody2D/StructureVisual
  children (safe from the signal handler per CLAUDE.md trap 4), per-zone
  anchor collection, rebuild.
- `scripts/world/building_renderer.gd`: `set_active_zone(zone_id)` -
  rebuilds from `get_placed_buildings(zone_id)`, hides the stale ghost.
- `scripts/player/player.gd`: `set_active_farm_grid` (live re-wire that
  does NOT recreate the ToolManager), `get_farm_grid()`, and a `_zone_id`
  fed into every zone-aware GameData/BuildingManager lookup - without
  this, wells/market/chapel interactions silently died outside
  Fallowfield.
- `scripts/world/tool_manager.gd`: `set_farm_grid(grid)` live re-wire.
- `scripts/autoloads/zone_manager.gd`: `get_active_zone_npc_ids()`
  (`get_npc_zone` was already complete from 15a; no duplicate added).
- `scripts/autoloads/building_manager.gd`: `is_well_at` gained the
  `zone_id` filter (player-built wells no longer collide across zones).
- `scripts/autoloads/raid_manager.gd`: `_spawn_raid` gates world spawning
  on `active_zone_id == "fallowfield"` (message-only when elsewhere, no
  deferred state); new `dismiss_raid_if_active()` despawns a raid that is
  in progress when the player walks off the farm (Pro-consult addition).
- `scripts/autoloads/tithe_manager.gd`: `_delivery_tile()` zone-qualified
  through the connected farm grid's zone id (see divergences).
- `scripts/ui/hud_panel.gd`: `set_farm_grid(grid)` re-wire + zone-aware
  tile-tooltip bounds check.
- Tests: new `tests/suites/test_zone_transitions.gd` (51 checks) covering
  the guide's assertions - autoload state survives, arrival-tile world
  position, tool grid targeting, camera dims, renderer rebuilds without
  duplicates, NPC membership at different hours/zones, and the REAL manor
  demesne rect through TitheManager. `test_iso_structures.gd`'s mock
  gained the per-zone `get_all_features` parameter; `run_tests.gd`
  registers the new suite.

**DeepSeek-API delegation outcome** (mandated consult): POSTed twice to
`https://api.deepseek.com/chat/completions` with the Codex-configured key.
Attempt 1 with `model: "deepseek-reasoner"` was silently served by
**`deepseek-v4-flash`** with `finish_reason: length` and zero answer
content (16,384 reasoning tokens consumed the whole cap) - the same
substitution every prior consult in this repo recorded; Pro was not
consulted by that call. Attempt 2 with `model: "deepseek-v4-pro"`
returned model id **`deepseek-v4-pro`** (`finish: stop`, 7,915 total
tokens) - Pro was actually reached. Pro confirmed the planned A-K handler
order (player grid/zone -> position -> camera dims -> HUD/Tithe refs ->
renderers -> NPC set) with no sequencing bug, said C-before-D (position
before camera dims) is fine, confirmed synchronous free() from the signal
handler is safe, and added one missing-state item: a raid in progress when
the player leaves Fallowfield must be dismissed so enemies do not leak
into another zone - implemented as `RaidManager.dismiss_raid_if_active()`
and called first in the handler. Receipt:
`.deepseek/outputs/sprint15b_zone_swap_consult_out.md.receipt.json`.

**Explicit confirmation - the Manor's demesne chores are reachable and
working:** verified twice. (1) In the test suite, the REAL manor rect
`Rect2i(4,6,8,6)` through a manor-zone grid wired into TitheManager passes
till -> sheaf replenish -> harvest -> carry-to-chest end-to-end. (2) Live
headless probes of the real `main.tscn` walked Fallowfield -> North Strip
-> Nettleford -> Manor and confirmed `TitheManager.can_demesne_chore_at(
"till_demesne", (5,6)) == true` at the Manor with
`TitheManager._farm_grid_ref` re-pointed to the manor grid and the tithe
chest visual at (4,6). A saved game landing in the Manor also restores
with `demesne_till_ok == true`.

**Divergences / things that bit (all flagged, none silent):**
- `_delivery_tile()` in `tithe_manager.gd` needed a one-line zone fix
  despite the "do not touch ADR-040" scope: ADR-040 wrote it before the
  region split, so it read the default zone (fallowfield), which has no
  demesne - carry_produce could never deliver at the manor chest once the
  Manor became reachable. The spatial chore methods themselves are
  untouched; only the data lookup gained its zone (from the connected
  farm grid). Existing ADR-040 tests still pass because the old
  default-zone (-1,-1) anchor equals the fallowfield lookup's (-1,-1) -
  the previous tests were passing vacuously on delivery location.
- `main.gd` cannot be preloaded by suites (bare autoload identifiers
  fail to compile headless), so `test_zone_transitions.gd` drives the
  "main-handler equivalent" through the exact public methods the handler
  calls, in the same order - the established off-tree pattern.
- Animals: verified `AnimalManager` spawns no world nodes (state-only),
  so the guide's "hide animal visuals" step is a documented no-op, not an
  omitted mechanism.
- Edge detection runs in `main.gd._physics_process`, which as a parent
  node runs before the player's own physics step, so a crossing is caught
  one tick late at most (invisible; documented in the code).
- Raids firing outside Fallowfield are message-only with no deferred
  state, per the accepted edge case; leaving Fallowfield mid-raid
  dismisses the raid message-only (Pro-consult addition, same policy).
- `test_tithe_labor.gd`'s `DEMESNE_RECT` still uses the old (15,5,6,6)
  placement (pre-existing stale fixture, mechanics-only); the new suite
  covers the real manor rect. Not changed to keep ADR-040's suite
  untouched.

**Verification:** `--headless --path . --import` clean (exit 0, no SCRIPT
ERROR/parse errors; two `:=`-from-Node-typed-call parse errors caught by
import and fixed with explicit types - the documented trap 12.1); full
suite -> **ALL SUITES PASSED (1780 checks)** (baseline 1729 + 51 new),
exit 0. Real `main.tscn` headless probes: boot clean on Fallowfield (0
NPCs, all grids registered, camera 24x16); scripted walks across
Fallowfield's north edge (arrives North Strip (12,7), camera 24x8, grid
re-wired), into Nettleford (12,15, 6 NPCs, market anchor rebuilt), into
the Manor (12,0, tithe grid re-pointed, demesne chore gate open, chest at
(4,6)); no-exit boundary clamps back inside; a v19 save in the Manor
restores zone/tile/money/energy through `apply_saved_state` with the same
world swap.

## Local asset-generation studio (user tooling, git-ignored) (2026-08-07)

- Created `asset_studio/` (git-ignored via `.gitignore`) as a private,
  non-game pipeline: `critique.py` (deterministic palette/dimension/unique-
  color checks + Ollama `gemma3:4b` vision critique -> `reviews/*.json`),
  `inspire.py` (palette + tone extraction from inspiration images ->
  `style_reference.json`), `config.json`, `style_bible.md` template,
  `README.md`, and the persisted V4 Pro research task + output
  (`task_v4pro.md`, `pro_v4pro.md`). Nothing touches game code or saves.
- Verified live: Ollama API on localhost:11434. `gemma3:4b` vision critique
  works (~30 s/image). `qwen2.5vl:3b` image input HUNG via `/api/generate`
  twice while its text generation worked - suspected runner issue, restart
  Ollama before relying on it.
- This Codex session cannot receive image inputs (`view_image` tool blocked:
  "model does not support image inputs"), so the deterministic checks + vision
  model text act as the eyes; the user is the final visual judge.
- V4 Pro research (2026-08-07, effort max, 20,241 tokens, no truncation)
  recommended: for 3-4B vision models - fixed role/checklist prompts,
  nearest-neighbour upscale to 256-512 px before critique, describe-then-judge,
  temperature ~0, 9-11B if finer critique is needed; for style consistency -
  IP-Adapter + an existing pixel-art LoRA + Lightning/LCM sampling before any
  custom LoRA (custom: 20-100 sprites at 1024, trigger word, kohya/OneTrainer,
  dim 32/alpha 16, lr 1e-4, ~2000-4000 steps); cloud multimodal is best for
  moodboard -> style-bible synthesis (palette hexes + style description +
  prompt templates). Full output: `asset_studio/pro_v4pro.md`.
- Installed skill `asset-studio` at
  `%USERPROFILE%\.codex\skills\asset-studio`. skill-creator's
  `quick_validate.py` could not run (bundled Python lacks PyYAML; venv Python
  also lacks it) - frontmatter and structure checked manually instead.

## Local generation stack installed (user tooling, git-ignored) (2026-08-08)

- ComfyUI **v0.7.0** at `%USERPROFILE%\ComfyUI_windows_portable` (git
  checkout of the last 2025 release). Newer releases bundle/require
  `comfy_kitchen`, which needs torch >= 2.8. Torch pinned to
  **2.6.0+cu124** (the last line with GTX 10-series kernels; the bundled
  torch 2.13.0+cu130 failed with "no kernel image is available"). **Do not
  upgrade either** - verified via the Pascal GPU survival guide + kernel test.
- Models: RealVisXL_V4.0.safetensors (6.46 GB, non-gated SDXL), pixel-art LoRA
  (Hadimeeee, 177 MB), SDXL-Lightning 4-step LoRA (376 MB - emits "lora key
  not loaded" warnings for some blocks against RealVisXL; cosmetic for now).
  `qwen3.5:9b` pulled into Ollama (6.6 GB).
- Smoke test: first generation succeeded (4 steps, ~10 s sampling, 50.6 s
  prompt execution; first load of the 6.5 GB checkpoint takes several
  minutes). Deterministic critique flagged 110,786 unique colors -> pixel-art
  LoRA strength + palette quantization still needed for true pixel art.
- Thermal: 70 C under load is normal for a GTX 1070 (throttle ~83 C, max
  94 C). Added `gpu_guard.py` + `batch.py` (cooldown between batch items,
  defaults: max-temp 78 C / cool-below 62 C / rest 10 s). Guard made OPT-IN
  via `--guard` on 2026-08-08 per user request - batches run back-to-back by
  default, no GPU throttling in place. Optional hardware limiter not applied:
  `nvidia-smi -pl 120` (reset `-pl 151`).
- `generate.py` wait timeout raised 420 s -> 900 s (first-run model load
  exceeded the old value); progress prints added.
- Added `asset_studio/catalog.py` (2026-08-08, Claude session) alongside the
  existing `critique.py`/`inspire.py`: tags and describes a folder of
  downloaded (not generated) tile art in bulk, reusing `deterministic_checks`
  and `config.json`'s Ollama wiring rather than a new pipeline. Defaults to
  `gemma3:4b` per the confirmed-working note above, not `qwen2.5vl:3b` (the
  hang is still undiagnosed). Applies the V4 Pro research note
  (`pro_v4pro.md`) that was sitting unused: small pixel art is upscaled
  nearest-neighbour to 256-512px before the vision call, since 3-4B vision
  models read tiny native-res tiles poorly. Writes one incremental
  `art_catalog.json` manifest (resumable) rather than per-image reviews,
  since the use case is "what do I have" over a batch, not per-image
  accept/reject.

## Playtest punch-list items 4, 8, 9 closed (2026-08-07)

Closes the three items the second playtest-triage pass
(`.deepseek/outputs/playtest_feedback_triage_out.md`) left open after items
1-3/5-7 were resolved in earlier sessions. No CLAUDE.md amendment - all
three are polish/bugfixes inside already-approved systems (interaction
layer, gifting, foraging).

**Item 8 - gift-giving dialogue modal-stacking bug (fixed):**
`scripts/ui/dialogue_panel.gd` gained `_on_menu_opened` (hides whenever a
DIFFERENT menu opens while "dialogue" is on the `UIManager` stack) alongside
the existing `_on_menu_closed` (now reshows if "dialogue" is still open).
Mirrors `InventoryPanel`'s existing `menu_opened` subscription pattern
exactly. Confirmed via read: "Give a gift" is the only response callback
that opens a second menu on top of dialogue (propose/merchet/accuse/mercy
all just call `show_dialogue` again in place) - no other flow needed
auditing. No test suite change - this is pure `CanvasLayer` visibility
wiring with no state to assert on headless.

**Item 9 - forage tiles were invisible (fixed):** `scripts/world/
farm_renderer.gd` gained a `_draw_forage_glyph`/`_small_diamond` pass reading
each cell's `forage_item_id` (ADR-022 wild spawns, ADR-018's `spoiled_crop`
rot pickup) and drawing a category-keyed geometric glyph (plant = green
circle, flint = grey diamond, wood = brown rectangle, spoiled = dull-olive
circle, unknown = a fallback yellow circle so a future forage item added to
data without a renderer update stays visible instead of repeating this same
bug) at `IsoProjection.cell_centre_screen`. `FORAGE_GLYPH_CATEGORY` is a
local const map, not `data/*.json` - purely cosmetic, matches this file's
existing `FALLBACK_SOIL_COLOR`-style convention. New test:
`test_iso_terrain.gd`'s `_test_forage_glyph_category_completeness` asserts
every real `forage.json` spawn-table item id (plus the hardcoded
`spoiled_crop`) has a category entry - confirmed `dig_loot` items (morel,
truffle, wild_carrot, wild_turnip) never touch tile state by reading
`FarmGrid.dig_cell` (a pure roll-and-return), so they were correctly
excluded from the completeness check.

**Item 4 - faced-tile targeting/highlight + hold-to-preview (fixed, the
substantial one):** designed via a DeepSeek consult
(`.deepseek/tasks/target_indicator_task.md` ->
`.deepseek/outputs/target_indicator_out.md`, `deepseek-v4-flash`, effort
max, `finish: stop`, no truncation - Pro was not attempted for this one, the
brief did not call for the delegation-to-Pro pattern) - the multi-system
one of the three (input model + interaction dispatch + a new renderer +
Esc-vs-pause semantics), reviewed against the live code before
implementing per this project's consult discipline. Design adopted almost
verbatim; two deliberate simplifications from the raw output, both noted
inline in code:
  - Skipped the consult's separate `ToolManager.get_affected_tiles()` -
    `get_action_info()`'s own `"tiles"` field already serves that exact
    purpose, and a second overlapping accessor would risk the same kind of
    drift this whole exercise exists to close.
  - `TargetIndicatorRenderer._process()` redraws unconditionally while a
    hold is active rather than diffing the previous frame's tiles/validity
    via `Dictionary`/`Array` `==` (the consult's suggestion) - at most 3
    polygons, only while Interact is held, isn't worth relying on Godot 4's
    Array/Dictionary deep-equality semantics for.

Built:
- `scripts/autoloads/input_manager.gd`: `is_action_just_released` - the
  release twin of the existing wrapper, the only new input primitive.
- `scripts/world/farm_grid.gd`: `can_till`/`can_plant` - read-only mirrors
  of `till_tile`/`plant`'s precondition chains (same documented-mirror-pair
  convention as `can_dig`/`dig_cell`), kept in sync by hand. `water_tile`'s
  and `apply_compost`'s gates needed no new mirror - both reduce to the
  already-public `is_tilled(pos)`.
- `scripts/world/tool_manager.gd`: `_energy_cost(item)` extracted from
  `_use_tool_item` (shared by the mutation path and the new read-only path
  so skill/wound multipliers can never drift between them);
  `can_refill_watering_can()`; `get_action_info(target) -> { text, valid,
  tiles, tile_valid }` replacing `describe_action` as the read-only seam
  (`describe_action` is now a one-line text wrapper over it) - per-tile
  validity for the iron hoe's `line_3x1` area via new `_hoe_info`/
  `_watering_can_info`/`_seed_item_info`/`_material_item_info` helpers that
  mirror `_use_hoe`/`_use_watering_can`'s demesne/normal split exactly.
- `scripts/player/player.gd`: `_interact_hold_active` + pure
  `_interact_hold_step(holding, pressed, released, menu_open)` (press ->
  start, release while holding -> commit through the UNCHANGED `_use_tool`,
  a menu opening -> cancel); `is_interact_hold_active()`/
  `cancel_interact_hold()`; `_physics_process` now drives the step and
  commits on the step's `"commit"` event instead of on press directly.
  `get_interaction_preview()`'s ~40-line body became `get_interaction_info()`
  (same `{text, valid, tiles, tile_valid}` shape, one chain for the HUD text
  *and* the indicator), with `get_interaction_preview()` now a one-line
  wrapper. **Real pre-existing bug caught and fixed in the same pass:** the
  well branch used to return "Fill Watering Can" unconditionally regardless
  of the equipped tool, while `_use_tool()`'s real branch
  (`ToolManager.refill_watering_can()`) silently no-opped for anything else
  equipped - the text and the mutation had quietly disagreed since Sprint 7.
  Now gated by the new `can_refill_watering_can()` on both sides.
- `scripts/world/target_indicator_renderer.gd` (new):
  `TargetIndicatorRenderer` - polls `Player.is_interact_hold_active()`/
  `get_interaction_info()` every `_process` frame, draws a diamond per
  affected tile via `IsoProjection.cell_diamond` in the shipped
  `BuildingRenderer` placement-ghost colors verbatim (green `Color(0.2, 0.8,
  0.2, 0.55)` / red `Color(0.8, 0.2, 0.2, 0.55)`) so the two "preview before
  it commits" features read as one visual language. Per-tile color, with the
  aggregate `valid` forcing every diamond red if the swing can't fire at all
  (energy/water/inventory) even when individual tiles are otherwise
  tillable.
- `scripts/main.gd`: constructs/wires the indicator at sibling index 4 -
  deliberately above `world_visuals`, terrain, fixtures, and buildings, so
  nothing can occlude the tile the player is aiming at; `_on_zone_changed`
  calls `player.cancel_interact_hold()` so a hold never survives a zone
  swap with a now-stale previewed tile.
- `scripts/autoloads/ui_manager.gd`: `_player_ref()` (cached
  `get_first_node_in_group("player")`, the same pattern
  `CombatManager`/`RaidManager`/`Enemy` already use) and pure
  `_resolve_pause_action(hold_active, has_open_menu, pause_just_pressed)` -
  Escape while holding cancels the hold instead of opening pause (an open
  menu always wins over a stale hold flag, so Escape can never be
  permanently swallowed by either feature); `open_menu()` now cancels any
  active hold synchronously on EVERY menu open (inventory, build, dialogue,
  shop, tithe, pause, ...), not just Escape, so a later release can never
  commit into a menu the player never saw.
- `scripts/ui/hud_panel.gd`: `_refresh_interact_hint()` now reads "Release:
  <action> (Esc to cancel)" while holding, instead of the plain action text,
  so the HUD hint agrees with the on-field indicator rather than reading
  like the action already fired.
- New suite `tests/suites/test_interact_hold.gd` (17 checks): the
  `_interact_hold_step` transition table (start/commit/stray-release/
  menu-cancel/menu-blocks-start/same-tick-tap), `_resolve_pause_action`'s
  full routing table, `FarmGrid.can_till`/`can_plant`, and
  `ToolManager`'s per-tile branches (hoe single + line_3x1 partial validity,
  watering-can empty-vs-full, seed/compost inventory gating, spade,
  energy-gates-aggregate-not-per-tile) against a REAL `FarmGrid` via
  `configure_for_test` - the same off-tree pattern `test_forage.gd` uses.
  Also a "mirror-drift guard": `get_action_info`'s predicted validity is
  asserted to agree with the real `_use_hoe()` mutation outcome on both a
  fresh and a pre-tilled grid. Registered in `tests/run_tests.gd`.

**A real compile error caught by headless import, not by review:**
`ToolManager`'s new energy-affordability checks first read
`_player_state.get("energy", 0.0)` (mimicking `Dictionary.get`'s 2-arg
default-value form) - `Object.get()` only takes ONE argument in Godot 4's
static type checker (`_player_state` is declared `Node`, not `Dictionary`),
and this is a hard `SCRIPT ERROR: Parse Error` at reload, not a warning.
Every other `_player_state.get(...)` call in this file (pre-existing, e.g.
`wound_days_remaining`) already used the single-arg form - the established
convention was right there and got missed on the first pass. Fixed to
`float(_player_state.get("energy"))` in all three sites (the spade branch,
`_hoe_info`, `_watering_can_info`).

**DeepSeek delegation outcome:** POSTed via
`.claude/skills/deepseek-consult/scripts/consult.sh` (Codex CLI,
`deepseek-v4-flash`, effort max, read-only sandbox). A cheap smoke test ran
first per the skill's own guidance (`.deepseek/outputs/smoke_test_out.md`) -
reachable, no truncation. The real consult returned a complete, well-
grounded design (`finish: stop`) that correctly identified the Esc-vs-pause
double-consumer problem as the crux of the whole brief and proposed the
single-consumer resolution (`UIManager` alone reads Escape, routes by
querying `Player`) rather than a second `cancel` action - the cleaner of
the two options the task brief explicitly left open. It also caught the
well-preview/refill mismatch bug on its own initiative while writing
section 5's validity table, which the task brief never asked it to look
for.

**Verification:** a real compile error existed after the first implementation
pass (see above) - caught and fixed via headless import, not by review; a
second `--headless --path . --import` ran clean (no SCRIPT ERROR). Full
suite: `--headless --path . --script res://tests/run_tests.gd` ->
**ALL SUITES PASSED (1834 checks)** (baseline 1780 + 54 new: 17 from
`test_interact_hold`, 1 loop-driven completeness check in `test_iso_terrain`
covering 6 real forage item ids, the remainder from the pre-existing suites'
own incidental counts) - the pre-existing "Can't use get_node() with
absolute paths" noise from `test_zone_transitions.gd`'s
`_test_manor_demesne_reachable` (an off-tree `TitheManager` lookup,
documented in this file's own Sprint 15a/15b entries) is unrelated to this
session's changes. `--headless --path . scenes/main.tscn --quit-after 180`:
exit 0, no errors/warnings beyond the standard headless-script-runner RID/
ObjectDB leak noise at exit (also pre-existing and documented elsewhere in
this file). Beyond that, a throwaway live probe (`Input.action_press`/
`action_release` against the real booted `main.tscn`, deleted after use per
the Sprint 6/15b precedent for one-off verification scripts) confirmed
end-to-end: pressing Interact shows the indicator with correct per-tile
validity (`{"text": "Till the Soil", "valid": true, "tiles": [(12, 11)],
"tile_valid": {(12, 11): true}}` against the real spawn tile with the
starter hoe equipped); Escape while holding cancels without opening pause;
a second Escape opens pause normally; a fresh press after a cancel
re-enters holding correctly (not stuck); the indicator's visibility catches
up to the hold state within one frame of release - a `_process`-vs-
`_physics_process` lag of the same harmless, already-documented kind
Sprint 15b's own zone-edge detection has, not a bug.

**Not exercised:** an actual Godot editor F5 session by a human (all
verification above is headless/scripted). The manual checklist below covers
what that pass should walk.

## Vertical-slice manual QA test plan authored (2026-08-07)

- New `docs/testing/vertical_slice_test_plan.md`: a walkable manual QA
  checklist for the whole shipped slice, lean-on-the-cheat-panel throughout.
  Covers boot/shell, movement & projection, time/HUD, the farm loop
  (till/plant/water/moisture/growth/quality/seeds/fertility/soil), weather,
  foraging + spade dig, inventory/vitals/food, sleep & saves, market &
  supply pressure & board orders, tithe (incl. the spatial Manor demesne
  chores) & church, NPCs/dialogue/gifting/requests, the Springturn festival,
  combat & raids & thief investigation, buildings/crafting/livestock,
  marriage, the nine-zone tour, season end, and a 7-item regression sweep.
  Every key binding, cheat-panel button, price, growth day, and zone fact in
  the doc was verified against the live repo this session; the appendix
  records current known behaviors (F5 boots straight into the farm, NPCs
  block the world but not the player, soft first exhaustion, debug-only
  cheat panel, unsandboxed-headless requirement) so the checklist doesn't
  misreport them as bugs.
- **DeepSeek V4 Pro consult requested by the owner but NOT completed:** the
  dispatch attempt failed before reaching the API - the escalated run was
  auto-rejected by the approval reviewer (malformed review payload, not a
  policy finding), and the sandboxed retry was denied at the socket level
  (`WinError 10013`). No Pro interaction happened, so no receipt exists to
  relay; the plan above stands on orchestrator-authored content grounded in
  the verified facts. The Pro consult task file is persisted at
  `.deepseek/tasks/vertical_slice_test_plan_task.md` (self-contained brief)
  and can be dispatched with the owner's go-ahead once the escalation is
  approved.

## Live-play regressions from the item-4 hold-to-preview session (2026-08-08)

The owner's first live play session after the item 4/8/9 fixes above found
two real problems the headless verification in that session's own entry did
not catch (both are now fixed and re-verified below) - a reminder that
"1834/1846 checks pass, boot smoke clean" is not the same claim as "played
correctly," especially for anything only reachable from `_draw()` or a real
input sequence.

**Bug 1 (real crash-adjacent bug): talking to any NPC (also wells,
buildings, features) errored every frame while holding Interact.**
`TargetIndicatorRenderer._process()` (`scripts/world/
target_indicator_renderer.gd`) does `info.get("tiles", []) as Array[Vector2i]`.
Every SINGLE-tile branch in `Player.get_interaction_info()` and
`ToolManager.get_action_info()` (well, station, stewards_demesne, other
feature, NPC, spade, seed, material, and the two "nothing to do" fallbacks -
9 sites in `player.gd`, 9 in `tool_manager.gd`) returned a bare `[target]`/
`[target_pos]` array LITERAL, which GDScript creates as an untyped `Array`
at runtime even though every element is a `Vector2i` - only the multi-tile
hoe/watering-can branches built `tiles` as an explicitly-typed local
`Array[Vector2i]` from the start and were unaffected. Casting an untyped
`Array` to `Array[Vector2i]` via `as` does NOT silently coerce; it prints
`SCRIPT ERROR: Trying to assign an array of type "Array" to a variable of
type "Array[Vector2i]"` and repeats every `_process` frame while the
indicator is visible - which is exactly what holding Interact near an NPC
does. In the editor this reads as the game hanging/crashing, not as a
one-line log message. **Reproduced deterministically** with a scripted
probe against the real `main.tscn` (`Input.action_press("interact")` while
facing a live NPC) before fixing, confirmed silent after. Fixed at both
ends: every affected literal in `player.gd`/`tool_manager.gd` now reads
`[target] as Array[Vector2i]` (9+9 sites), and
`TargetIndicatorRenderer._process()` was also hardened to rebuild the typed
array by iteration regardless of what the producer returns, so the same
mistake in a future branch degrades silently instead of erroring. New
regression coverage: `test_interact_hold.gd`'s
`_test_single_tile_branches_return_typed_tiles_array` (the ToolManager-side
branches, off-tree; the player.gd branches were confirmed via the live
probe only, since they need a live GameData/BuildingManager tree).
**Why the previous session's headless suite didn't catch this:** the
existing suites never call `_process()`/`_draw()` on any renderer (no live
`CanvasItem` context headless, a documented, deliberate limitation) - the
bug lived entirely in a code path only a running scene exercises.

**Bug 2 (missing feature, not a bug in shipped code): zone-transition exits
had no visual indication at all.** Confirmed by reading every renderer -
walking off a map edge either changes zones or clamps the player back
inside (`main.gd._check_zone_edge_crossing`/`_clamp_player_inside`) with
literally nothing drawn to distinguish an edge that leads somewhere from a
dead end; a player could only find the nine zones' connections by walking
every edge of every map. Fixed in `scripts/world/farm_renderer.gd`: a new
`_draw_exit_paths()` pass (called from `_draw()`, unculled - exits are rare,
always at the map edge, cheap regardless of camera position) draws one
path-colored line (`EXIT_PATH_COLOR`, wider than the ordinary grid lines)
per `zones.json` exit entry, along that exit's real boundary segment. The
geometry is factored into a small testable helper,
`exit_line_grid_points(exit_data, map_width, map_height) -> Array[Vector2]`,
computed in grid space and projected via the existing
`IsoProjection.grid_to_screen` - the same "draw one line per boundary,
projection is linear" technique `_draw_grid_lines` already uses, extended
from data instead of a fixed lattice. New test
`test_iso_terrain.gd`'s `_test_exit_line_grid_points` covers all four edge
directions (synthetic cases) plus a cross-check against the real
`fallowfield` north exit from `zones.json`, and an unrecognised edge string
returns no points rather than guessing. Live-verified with a probe that
visited all nine zones and forced a redraw in each - including
`nettle_brook`, which has five exits, four of them on the same "west" edge
at different ranges - with no errors.

**A second real compile error, caught only by actually running
`run_tests.gd`, not by `--headless --import`:** the exit-path test's
`var real_points := fr.exit_line_grid_points(...)` hit this project's own
documented trap (CLAUDE.md's "Known Traps" / this file's own "Open
questions" section) - inferring a type with `:=` from a call that returns
`Variant` (`fr` is declared `var fr = _make_renderer() -> Object`, so any
method call through it is Variant-typed to the compiler) is a hard `Parse
Error` in this project's Godot 4.7, not a warning. **Import-check blind
spot worth recording:** `--headless --path . --import`'s "Registering
global classes" step only deeply compiles scripts that declare
`class_name` - `test_iso_terrain.gd` (`extends RefCounted`, no
`class_name`, referenced only by `preload()` path in `run_tests.gd`) was
never touched by that pass, so `--import` reported clean while
`run_tests.gd` itself failed to `.new()` the script moments later
(`SCRIPT ERROR: Invalid call. Nonexistent function 'new' in base
"GDScript"` - the generic symptom of a script that failed to compile,
printed at the CALL site, not the parse-error site; the real "Parse Error:
Cannot infer the type of 'real_points' variable" line was further up the
same log and easy to miss under the pre-existing `test_zone_transitions.gd`
off-tree noise). **Lesson for future sessions': `--import` alone is not
sufficient verification for any suite file without `class_name` - only an
actual `--script res://tests/run_tests.gd` run exercises those.** Fixed
with an explicit `Array[Vector2]` annotation in place of `:=`. Also
observed: the failed run did not exit promptly - it appears to hang/idle
after the compile failure rather than exiting non-zero right away (both
attempts before the fix ran past their 180s/240s foreground timeouts and
had to be backgrounded), so a suite run that runs unusually long is itself
now a signal to check for exactly this failure mode, not just wait longer.

**Verification after both fixes:** `--headless --path . --script
res://tests/run_tests.gd` -> **ALL SUITES PASSED (1846 checks)**, exit 0
(1838 + 8 new `_test_exit_line_grid_points` checks); `--headless --path .
scenes/main.tscn --quit-after 180` exit 0, no errors; a live probe
re-running the exact NPC-talk repro confirmed silent (no more SCRIPT
ERROR); a second live probe visited all nine zones and forced a redraw in
each, confirming `_draw_exit_paths()` handles every real exit
configuration (including nettle_brook's five, four same-edge) without
error. All probe scripts deleted after use per this project's established
one-off-verification-script convention.

## 2026-08-08 - Sprint 16 opened: art asset integration (ADR-041)

The owner supplied fifteen purchased/found sprite packs under
`SourceArtAssets/` (outside the repo) and asked for a multi-agent-
dispatchable plan to integrate them, as-is, in exchange for speed over
cross-pack visual consistency. Surveyed all fifteen packs by directory/
filename census (no vision model available - Ollama is not running on
this machine right now, and a full `asset_studio/catalog.py` pass would
cost an estimated day of wall-clock at ~30s/image across ~3,600 files, so
the manifest in `design/sprints/sprint_16_art_integration.md` section 1 is
filename-based, with vision cataloguing recorded as optional background
enrichment, not a blocker).

**Discovered mid-session, not previously known to this conversation:** a
pre-existing, private, git-ignored `asset_studio/` workspace at the repo
root (ComfyUI/SDXL local generation pipeline, `style_bible.md`, and two
prior plan drafts, the more recent informed by an actual DeepSeek v4 Pro-
routed consult, `asset_studio/pro_v4pro.md`). That prior plan's Phase 3
(LoRA training + ControlNet/IP-Adapter restyling to unify style across
packs) is superseded for this integration pass by the owner's explicit
as-is/speed-over-consistency ruling - recorded as a narrowing, not a
deletion, in ADR-041. `asset_studio/` itself is untouched.

**Contract amendment landed same session (CLAUDE.md v0.21 -> v0.22,
ADR-041 in `design/decisions.md`).** Section 2 gains an Art asset
integration bullet; the old "Sprites, art assets, audio, particles,
shaders. Geometric primitives only." out-of-scope clause is narrowed to
audio/particles/shaders - sprites are no longer excluded, terrain/soil
rendering explicitly is (out of ADR-041's scope, stays primitive - none of
the fifteen packs are farm-soil tile atlases anyway). Section 5 gains a
forward note that the sprite/animation lookup lands as a static
`class_name` helper or a `GameData` extension, not a new autoload (the
existing DESKTOP-step Project-Settings constraint ADR-035/037 already
recorded). Section 8 gains a textured-proxy invariant; section 9.5 is
restated to permit a textured child `Sprite2D`/`AnimatedSprite2D` on an
existing visual proxy and to correct ADR-032's now-outdated "geometric
primitives rule has nothing to fill" framing. `AGENTS.md`/`DEEPSEEK.md`
regenerated via the real generators (`docs/make_agents.gd`,
`docs/make_deepseek.gd`); full suite re-run after the amendment:
**ALL SUITES PASSED (1846 checks)** - unchanged from the pre-amendment
baseline, confirming the contract-sync suites accepted the new text and
nothing regressed. (The `test_zone_transitions.gd` off-tree
`get_node()`-absolute-path stderr noise during the run is the same
pre-existing, already-documented artifact as prior sessions - not a new
failure.)

**Explore-agent survey of the rendering architecture** (grounding for the
plan and the consult below) confirmed the ADR-032 visual-proxy pattern is
exactly as documented and, specifically, that **swapping a primitive
`_draw()` proxy for a textured `Sprite2D`/`AnimatedSprite2D` child will not
disturb the y-sort depth math at all** - `WorldVisuals`'s `y_sort_enabled`
sorts on each proxy's own `position`/`global_position`, never its draw
calls, so a texture is additive. Also confirmed: `project.godot` has no
`[rendering]`/`[importer_defaults]` override yet (Linear filtering is the
live default, relevant once pixel-art-styled packs land), zero existing
`Sprite2D`/`AnimatedSprite2D`/`Texture2D` usage anywhere (genuinely
greenfield), and `Player.get_facing()` already exposes reusable 8-way
`Vector2i` facing data that a future animation system can consume without
changing how facing itself is computed.

**Plan delivered:** `design/sprints/sprint_16_art_integration.md` - full
per-pack manifest/target-system table, a sequencing diagram (Phase 0.5
asset staging -> Phase 1 blocking shared foundation -> four parallel
workstreams A/B/C/D -> integration test scene -> ADR-041-realized
follow-up), an explicit ownership table per workstream, and a routing
table assigning each piece of work to DeepSeek Flash (mechanical/low-
judgment), the second Claude instance (WS-C, actors/animation - the
highest-judgment, highest-file-count workstream), or Claude directly
(the Phase 1 frozen foundation seam and the final merge/integration
pass), mirroring `design/IsometricConversion_Worktrees.md`'s already-
proven worktree runbook for parallel agents.

**DeepSeek consult fired for the Phase 1 foundation design**
(`.deepseek/tasks/art_foundation_task.md` ->
`.deepseek/outputs/art_foundation_out.md`, `deepseek-v4-flash`, effort
`max`, 668s, 229,309 tokens per its receipt) - grounded directly in the
Explore agent's file:line findings above rather than asking DeepSeek to
guess the codebase's shape. **Completed and reconciled the same session.**
The output was unusually well-grounded: it claimed to have read every
named file and verified several Godot 4.7.1 API specifics
(`SpriteFrames.add_frame`'s signature, `CanvasItem.TEXTURE_FILTER_*` enum
values, `Sprite2D`/`AnimatedSprite2D` property names) against the actual
local `Godot_v4.7.1-stable_win64_console.exe`, rather than from training-
data memory. Independently re-verified rather than trusted on its word,
per the deepseek-consult skill's mandatory reconciliation step and
CLAUDE.md's API-confidence rule (4.5-4.7 deltas are not verifiable from
memory and must be checked, not guessed):
- Grepped `GameData`'s `_load_id_file`/`_cast_ints`/`_cast_nested_ints`
  pattern and `ActorVisual`/`PlayerVisual`'s exact `track()`/`_process()`
  shape - both matched the consult's claims essentially verbatim.
- Wrote a throwaway probe script (`_probe_sprite_api.gd`, deleted after
  use per this project's established one-off-verification-script
  convention) exercising `SpriteFrames.add_frame()`,
  `CanvasItem.TEXTURE_FILTER_NEAREST/LINEAR/PARENT_NODE`, and the
  `Sprite2D`/`AnimatedSprite2D` property set against the real 4.7.1
  binary - every claim confirmed exactly (`add_frame(anim, texture,
  duration, at_position)` taking a texture not a rect was the one
  genuinely non-obvious 4.x API detail, and it was right).
- Confirmed live against `SourceArtAssets/Bandits1/` that the `.scml`
  files are skeletal Spriter part-composition projects with no composed
  frames to mine, and that the same archetypes ship complete baked frames
  twice over (`PNG Sequences/` and `Spritesheets/`) - the consult's
  recommendation to ignore `.scml` entirely holds and is stronger than
  the task brief's own assumption.

**Phase 1 implemented the same session, reconciliation to shipped code in
one pass** (see `design/sprints/sprint_16_art_integration.md`'s Phase 1
section for the full list): `data/sprites.json` (v1, empty - no assets
staged yet), `GameData` sprite loading/casting/`get_sprite()`, the new
static `SpriteManifest` helper (`scripts/globals/sprite_manifest.gd`, the
`IsoProjection` pattern - no new autoload), `scripts/world/
static_prop_visual.gd`, and an updated `scripts/player/player_visual.gd`
carrying a textured-child path that is inert today (no `male1_walk`
manifest entry exists yet, so it falls through to the exact same
primitive `_draw()` as before - confirmed zero behavior change by the
full suite staying green apart from the new suite's own additions). New
suite `test_art_foundation.gd` (15 methods, 28 checks) covers the schema/
casting boundary and every `SpriteManifest` math function with hand-built
Dictionary entries - deliberately no dependency on any staged texture
file, so it stays green through Phase 0.5 landing later. Full suite:
1846 -> **1874 checks, all green.** WS-A/B/C/D (`design/sprints/
sprint_16_art_integration.md` section 6) are now genuinely unblocked -
the frozen shared seam they all depend on exists and is tested, not just
designed.

### Sprint 16 WS-B (Structures) - textured buildings, landed (2026-08-08)

**What changed.** `data/sprites_structures.json` gains its first two real
entries (schema unchanged, still v1); `scripts/world/structure_visual.gd`
gains the sanctioned ADR-041 extension - an optional `sprite_id` on
`configure()` that builds a `Sprite2D` child through `SpriteManifest` and
skips `_draw()` when the texture is live, keeping the primitive
extruded-box as the automatic fallback for every id without a manifest
entry (the `PlayerVisual` pattern); and `scripts/world/building_renderer.gd`
passes each placed building's id plus its parsed manifest entry (resolved
through the GameData reference the renderer already holds, so no
/root/GameData absolute-path reach is needed) into the visual so a texture
can light up with zero per-building code. The placement ghost deliberately
receives no sprite id or entry - its green/red tint is the placeable/blocked
signal. `structure_visual.gd` is outside the strict WS-B ownership list but
is the shared foundation this workstream is sanctioned to extend; the other
two files are ours. `sprite_manifest.gd` was not modified.

**Asset picks (verified from disk, no vision model available).** Alpha-
bounding-box analysis of the staged sheets (not filenames alone) showed
`home1pixelstyle/exterior.png` is a vertical strip of separate sprites:
rows 0-318 are a complete cottage, so the `cottage_upgrade` entry crops
`frame_w/h = 240x319`, anchors at `(120, 319)`, renders `height_tiles 2.5`
(120 px), and uses `nearest` filtering (pixel-art pack). `workshop1/
Exterior_house.png` holds two buildings side by side; the left sprite
(x 1-255, y 10-205) is a complete workshop, so the `drying_shed` entry
crops `256x206`, anchors at `(128, 206)`, renders `height_tiles 2.0`
(96 px, almost exactly the 2x2 footprint's 128px diamond width), and uses
`linear` filtering (painted pack). Building1's exteriors are 16px tile
atlases composed across layers in their Tiled maps, so no whole-building
sprite exists there this pass; the two picks above cover the flagship
cottage upgrade and the workshop's shed without composing new assets.

**Flags for the Phase 2 test scene.** `height_tiles`/anchor values are
data, chosen to read plausibly at the 64x48 tile scale, but they are
exactly the kind of number that needs an eyeball pass - the cottage in
particular is a tall front-view sprite that may want a larger
`height_tiles` (or a different sheet crop) once seen in-game. No new
4.5-4.7 API was introduced: the textured path reuses only
`Sprite2D`/`SpriteManifest` calls already verified by the Phase 1
foundation pass.

**Coverage.** New suite `tests/suites/test_art_structures.gd` (12 test
methods, 72 checks) locks the real entries (id/kind/texture/frame/anchor/
height/filter, file existence, buildings.json cross-reference), the
`SpriteManifest` static math against those real entries (texture load,
region crop, scale, anchor, per-entry filter), `StructureVisual`'s
textured child and in-progress modulate, and `BuildingRenderer` passing
the building id/entry through - including the real textured path
end-to-end against a live GameData instance - while the ghost and unlisted
ids keep the primitive fallback. Full suite: 1874 -> **1946 checks** after
the verification run below.

## 2026-08-08 - Sprint 16 WS-A landed: world dressing at the forage spawn points

**Mechanism discovery (the brief's file-list guess was wrong, and the brief
said so).** Reading `feature_renderer.gd` and `farm_renderer.gd` in full
confirmed there is **no decorative tree/bush placement mechanism anywhere
in the codebase** - `farm_map.json` feature tiles are all fixed fixtures
(house, wells, chapel/market/tithe/board), and `FeatureRenderer` renders
those as `StructureVisual` proxies. The only real world-dressing spawn
points are ADR-022's forage cells: `FarmGrid` tracks `forage_item_id` per
untilled cell, and `farm_renderer.gd`'s `_draw()` draws a primitive glyph
(`_draw_forage_glyph`) at the cell centre. WS-A therefore scoped to those
existing spawn points per the brief's instruction 2 - no new spawn system,
no guessed tree placement.

**Ownership deviation, recorded exactly as the brief requires.** The
literal ownership list named `scripts/world/feature_renderer.gd`, but the
real spawn site is `scripts/world/farm_renderer.gd`. The brief explicitly
anticipated this ("Wire `feature_renderer.gd` (or the real spawn site you
found)"), so `farm_renderer.gd` was edited as the real spawn site and
`feature_renderer.gd` was left untouched. No other file outside the WS-A
list was modified: `static_prop_visual.gd` and `structure_visual.gd` are
reused read-only, and `main.gd` needed no change (see the sibling-lookup
note below). `tests/run_tests.gd` gained the one required registration
line.

**What shipped.**
- `data/sprites_world_dressing.json` (v1): five static entries -
  `world_dressing_rock_flint` (`rocks1/Rock1_1.png`, the foundation
  consult's worked example verbatim), `world_dressing_plant_herb`
  (`bushes1/Assets/Fern1_1.png`), `world_dressing_plant_berry`
  (`bushes1/Assets/Bush_red_flowers1.png`), `world_dressing_plant_onion`
  (`bushes1/Assets/Bush_simple1_1.png`), and
  `world_dressing_tree_broken` (`trees1/Trees/Broken_tree1.png`).
- `scripts/world/farm_renderer.gd`: a `FORAGE_SPRITE_IDS` map from forage
  item id to manifest id (flint -> rock; wild_herb/wild_berry/wild_onion ->
  plant sprites; wood -> broken tree), and a per-cell
  `StaticPropVisual` lifecycle: props are created under `WorldVisuals` at
  each forage cell's projected south-east corner (the same sort anchor
  every structure/actor proxy uses), kept in sync from `tile_changed`
  (gather frees, day-pass spawn/save restore create) and rebuilt whole-grid
  on zone change. `_draw()` skips the primitive glyph only when a prop
  exists for that cell; missing/empty manifest entry, unloadable texture,
  or absent `WorldVisuals` all fall back to the exact pre-existing glyph -
  the `SpriteManifest.apply_static` fail-soft contract, consumed the way
  `PlayerVisual` does. `WorldVisuals` is resolved once in `_ready()` via a
  sibling lookup (`../WorldVisuals`, the same lazy pattern
  `FeatureRenderer` uses for `/root/TitheManager`), so `main.gd` did not
  need its `configure()` call changed.
- `tests/suites/test_art_dressing.gd` (registered in `run_tests.gd`):
  manifest completeness against the real staged textures (including
  `apply_static` success), int-cast boundary, forage->sprite mapping
  completeness against `FORAGE_GLYPH_CATEGORY`, the `has_forage_texture`
  gate's mock/headless fallback, the no-`WorldVisuals` primitive fallback,
  and the full prop lifecycle (create on spawn, free on gather, unmapped
  item stays glyph-only, dropping `WorldVisuals` frees everything).

**Pack triage.** `RocksAndStones` (rock), `BushesOption1` (fern/bushes),
and `TreesOption1` (broken tree for the wood source) are integrated at
their real forage spawn points. `FarmPlantsPixelStyle` (`Plants.png`,
`Supplies.png`) is **held back**: the 768x432 `Plants.png` sheet is a
12x6 grid of 64x72 crop-stage frames with no verified frame-to-crop
mapping, and crop dots are growth-state rendering on tilled cells - a
different spawn point from WS-A's forage scope. Texturing crop stages
would need a per-crop frame mapping that is data-guessing, not the
"textures replacing existing primitives" boundary ADR-041 set. Recorded
for a future pass rather than guessed now.

**Verification.** `--headless --path . --import` completed (2155 assets);
full suite `--headless --path . --script res://tests/run_tests.gd` prints
**ALL SUITES PASSED (1957 checks)** - up from the 1874 baseline, +83 from
the new suite, no existing check reduced. Two environment notes, both
recorded for the integrator: (1) inside this sandbox Godot 4.7.1 segfaults
at startup because it cannot create its user-data directories under
`AppData` (even a minimal throwaway project crashed identically) - the
suite was run unsandboxed for verification; this is not a project defect.
(2) The new suite emits the same class of off-tree absolute-`get_node()`
stderr noise the project already documents for `test_zone_transitions.gd`
(`StaticPropVisual.configure`'s `SpriteManifest.get_entry` cannot resolve
`/root/GameData` until the SceneTree is active; it fails soft to the
primitive path and the suite passes - the direct texture assertions in the
same suite cover the visible-texture outcome that the harness cannot).

## 2026-08-08 - WS-D: UI chrome textured (ADR-041, Sprint 16)

WS-D (the most isolated Sprint 16 workstream) landed its first real
texture pass: `adventure_ui/vector`'s individual SVGs now skin the shared
UIKit card/button builders, and the pause menu is the proof screen - its
parchment card and all five buttons go textured through the two shared
helpers (`make_card`/`make_button`), so no `pause_menu.gd` edit was
needed. Primitives remain the fallback everywhere else, including every
other screen, exactly per ADR-041.

**Empirical SVG check (the brief's API-confidence gate), verified against
the local 4.7.1 binary:** `--headless --path . --import` rasterizes the
staged `adventure_ui/vector/*.svg` files into `CompressedTexture2D`
resources with their authored pixel sizes - `button_brown.svg` loads as
48x24 and `panel_brown.svg` as 64x64 - and `StyleBoxTexture` accepts the
result with float `texture_margin_*`/`content_margin_*` plus
`modulate_color` (verified via a throwaway probe, deleted after use per
the one-off-verification-script convention). No spritesheet/PNG fallback
was needed.

**What shipped:**
- `data/sprites_ui.json` v1 gains four entries
  (`adventure_ui_button_brown`, `adventure_ui_button_red`,
  `adventure_ui_button_grey`, `adventure_ui_panel_brown`), each
  `kind: "static"`, with the UI-only float fields `texture_margin_*`
  (protected 9-patch edges) and `content_margin_*` (text padding) - no
  GameData int cast needed because StyleBoxTexture margins are floats.
- `scripts/ui/ui_kit.gd`: new `make_textured_style(entry, flat, tint)`
  builds a 9-patch `StyleBoxTexture` from a parsed sprites_ui entry and
  returns the caller's `StyleBoxFlat` untouched when the entry or texture
  is missing (the primitive-fallback rule). `make_button`/`make_card`
  prefer textured styles, tint hover/pressed/disabled via
  `modulate_color`, switch button text to ink on the parchment button
  centers, and apply the entry's `filter` to the owning Control.
- New suite `tests/suites/test_art_ui.gd` (7 methods, 44 checks):
  GameData parses the four entries (int-cast frame dims, float margins),
  the real SVG textures load at authored sizes (the empirical check kept
  as a regression test), `make_textured_style` builds button/panel
  9-patch styles with correct margins and tint, and the fallback seam
  returns the flat style for empty/missing-texture entries.

**Verify gate:** `--headless --path . --import` then
`--headless --path . --script res://tests/run_tests.gd` -> **ALL SUITES
PASSED (1918 checks)** (baseline 1874 + 44). A 12-frame headless game run
also exercises the real autoload path (`main.gd` builds PauseMenu, whose
card and buttons go through the textured builders) with zero errors.

**Bitten / noted:**
- Godot cannot run inside this session's sandbox at all: its
  editor-settings path under `%APPDATA%` is permission-blocked, crashing
  every invocation (even `--headless --quit`) with signal 11. All engine
  commands in this workstream ran unsandboxed; `--user-data-dir` does NOT
  redirect the editor-settings path, so it is not a workaround.
- `--import` regenerates the committed `.import` sidecars (2,165 files
  showed as modified). Those were deliberately left out of the WS-D
  commit - they are Phase 0.5-owned files, not UI-chrome-owned, and the
  merge integrator should decide how to handle sidecar drift once (sprint
  guide's known trap #8).
- The pre-existing off-tree `get_node()` stderr noise in other suites
  (`test_zone_transitions` et al.) is unchanged; WS-D's suite adds none -
  it follows the foundation pattern of driving entry Dictionaries rather
  than autoload lookups.

## 2026-08-08 - Sprint 16 WS-C implemented (actors: facing-from-velocity, NPC1/Bandits1 sprite resolution)

Branched `art/ws-c-actors` off `origin/feature/sprint16-art-foundation`
(not `master` - `master` does not carry Phase 1 yet). This machine's
checkout has **no `SourceArtAssets/` tree at all** (confirmed by `find` -
the Phase 1 session's live verification against `SourceArtAssets/
Bandits1/` happened on a different machine/session), so every fact this
entry relies on either comes from `.deepseek/outputs/art_foundation_out.md`
(already reconciled and landed in Phase 1) or is explicitly flagged as
unverified rather than guessed, per CLAUDE.md's API-confidence rule and
the sprint guide's own "this project's history records DeepSeek guessing
wrong about a specific file's shape" warning.

**Owned files touched:** `scripts/world/actor_visual.gd` (additive only -
the frozen `track()`/`_process()` lifecycle contract is unchanged),
`scripts/world/enemy_visual.gd`, `scripts/npc/npc_visual.gd` (real path -
the task brief's `scripts/world/npc.gd` is stale; NPC lives under
`scripts/npc/` as of an earlier sprint), `tests/suites/test_art_actors.gd`
(new, 13 methods), this subsection. `scripts/player/player_visual.gd`
needed **zero changes** - it already is the Phase 1 worked example: added
`male1_walk` to `data/sprites.json` instead (see below), the one piece
Phase 1 deliberately left unpopulated. `scripts/npc/npc.gd` also needed
**zero changes** - `CharacterBody2D.velocity` and `npc_id` are already
public, so all facing/archetype wiring lives entirely in `npc_visual.gd`;
this is recorded explicitly because the task brief expected "visual-wiring
parts of npc.gd" to need edits and they turned out not to.

**`ActorVisual` gains `facing_from_velocity(v, current) -> Vector2i`**
(static, pure): 8-way grid-space facing bucketing for actor types with no
Player-style stored facing of their own (NPC, Enemy - neither is driven by
rotated screen input the way Player is, so there is nothing to read a
facing off except their own `velocity`). Mirrors `player.gd`'s frozen
`_vector_to_facing` sector convention exactly (same `FACING_NEIGHBOURS`
order, same `TAU/8` sector width, same round-half-up tie-break) so the
result lines up with the same `"x,y"` manifest direction keys - but it is
an independent reimplementation, not a call into the frozen original
(`_vector_to_facing` is private, Player-specific, and explicitly frozen
for this sprint). Adding this to `ActorVisual` is additive only; the
class's existing `track()`/`_process()` contract is untouched.

**`NpcVisual` and `EnemyVisual` both gain a textured-child path**,
following `PlayerVisual`'s exact shape: `track()` resolves a sprite id,
calls a new `_build_sprite_child(entry)` (split out from `track()`
specifically so it is testable with a hand-built `Dictionary` and no
scene tree/autoload - this project's headless test harness never resolves
`/root` autoload lookups at all, confirmed by `test_iso_actors.gd`'s own
docstring, so `track()`'s `SpriteManifest.get_entry()` call is
untestable end-to-end off-tree regardless of what's in
`data/sprites.json`), builds an `AnimatedSprite2D` via
`SpriteManifest.apply_animated()`, and falls back to freeing it (primitive
`_draw()` stays active) on any failure. `_process()` now updates a
per-instance `_facing: Vector2i` from `ActorVisual.facing_from_velocity()`
every frame and calls `SpriteManifest.set_facing()` when a textured child
exists.

**Sprite-id resolution (both static, pure, testable without a live node):**
- `NpcVisual.archetype_sprite_id(npc_id) -> String` - deterministic pick
  across NPC1's three archetypes (Artist/Astrologer/Citizen) via
  `posmod(npc_id.hash(), 3)`. No per-villager art direction has been made;
  this is "villager visual variety" per the sprint guide's own framing for
  this pack, trivially replaceable with a curated per-villager choice
  later without changing the proxy's contract or its callers.
- `EnemyVisual.resolve_sprite_id(enemy_id, villager_id) -> String` - a
  `thief_villager` enemy (non-empty `villager_id`) reuses its disguised
  villager's own NPC1 archetype (a thief should look like the villager it
  is, not like a bandit); every other `enemy_id` maps through
  `BANDIT_SPRITE_IDS` onto one of Bandits1's three archetypes
  (`bandit_melee` -> Robber, `bandit_archer` -> Assassin, `raid_leader` ->
  Thug) - **a thematic pick, not a verified source-asset fact**, flagged
  in-code to eyeball once real assets are staged, same as Phase 1's own
  texture-filter-default precedent. An unmapped `enemy_id` fails soft to
  `""` rather than guessing.

**`data/sprites.json` gains one real entry, `male1_walk`**, using the
exact numbers Phase 1's reconciled consult output already verified
(`Unarmed_Walk_without_shadow.png`, 384x256 sheet, 64x64 frames, anchor
(32, 44), `height_tiles` 0.9, fps 6.67, the front/left/right/back row
direction mapping) - this is the entry `player_visual.gd` has referenced
by `SPRITE_ID` since Phase 1 landed but that Phase 1 deliberately left
unpopulated. No schema/version change (`data/sprites.json` stays v1 - the
shape is unchanged, only content was added).

**Deliberately NOT added this session, with reasons (Definition of Done's
"held back with a stated reason," not a gap):**
- **NPC1 (Artist/Astrologer/Citizen) and Bandits1 (Assassin/Robber/Thug)
  `data/sprites.json` entries.** Their exact frame geometry (sheet
  dimensions, per-direction file layout) is not verified against real
  source files in *this* checkout - `SourceArtAssets/` does not exist
  here, and Phase 1's own facts for Bandits1 only confirmed one
  direction's sheet dimensions (`Front - Walking.png` = 1920x2400,
  480x480 frames), not all eight. Fabricating the rest would be exactly
  the "DeepSeek guessing wrong about a specific file's shape" trap this
  project's own history already flagged. The code path is fully built and
  tested against hand-built entries (`test_art_actors.gd`); only the real
  data entries are missing, and adding them later requires no code change
  here.
- **Male1/Female1 as a separate NPC "base body" layer.** Section 1's pack
  table lists Male1/Female1 as available for NPC use alongside NPC1, but
  NPC1 already covers "villager visual variety" more directly, and
  building a second, parallel base-body system on top would be scope
  creep this slice doesn't need. Narrowed to NPC1-only for villagers.
- **Female1 for the player.** No player-gender-selection system exists
  anywhere in this codebase to consume a second sprite choice; `male1_walk`
  is the only player body this vertical slice has ever had.
- **Animals1 (generic wildlife) and FarmAnimalsOption1 (ADR-028
  livestock).** Neither has a world `Node2D` presence to attach a visual
  proxy to as of this session - `AnimalManager` (ADR-028) is stat-only
  with no map avatar, and there is no wildlife/fauna spawner anywhere in
  `scripts/` (grepped for `wildlife`/`fauna`/a `Wildlife` class - none
  exist). Wiring either would mean creating new gameplay nodes, which is
  outside WS-C's visual-wiring-only mandate; both stay fully out of scope
  until a gameplay workstream gives them a map presence to texture.

**New suite `test_art_actors.gd`** (13 methods): `facing_from_velocity`'s
eight-way bucketing, deadzone guard, and boundary tie-break determinism;
`archetype_sprite_id`'s determinism, membership, and empty-id fallback
(and confirms the real 9-villager roster spreads across more than one
archetype); `resolve_sprite_id`'s bandit mapping, unmapped fallback, and
thief-reuses-villager-archetype case; both proxies' `_build_sprite_child`
fail-soft path against an entry shaped like a real one but with an
unresolved texture path (the exact "your data/sprites.json entries will
point at paths that don't resolve" scenario this workstream's brief
names); and `track()` wiring the typed owner with facing defaulting to
DOWN. All off-tree, no scene tree, no autoloads, matching
`test_art_foundation.gd`/`test_iso_actors.gd`'s established pattern.

**Full suite: 1874 -> 1918 checks, all green**
(`Godot_v4.7.1-stable_win64_console.exe --headless --path . --import` then
`--headless --path . --script res://tests/run_tests.gd`, this machine's
own binary at `C:\Users\user\Desktop\Godot\`, +44 - exactly this suite's
13 methods' worth of `ok`/`eq` calls, nothing else moved). Stderr noise
during the run, all non-fatal (the harness only fails on `ok`/`eq`/`fail`,
never on a `push_error`/engine `ERROR:` print - `run_tests.gd`'s own
design): the pre-existing `test_zone_transitions.gd`/`tithe_manager.gd`
"get_node() absolute path from outside the active scene tree" artifact
already documented in prior sessions, plus the same class of error from
this suite's own two `track()`-wiring tests and both fail-soft-build
tests - `SpriteManifest.get_entry()`'s `tree.root.get_node_or_null("/root/
GameData")` call and `load()` on the intentionally-nonexistent texture
path both print an `ERROR:` before returning null/failing soft, exactly
as designed. Confirmed by the pass count: all four of those call sites
sit inside tests that passed.

**API confidence note:** `String.hash()` (used by `posmod(npc_id.hash(),
3)`) and `Node.free()` cascading to children are long-stable core API
predating the 4.5-4.7 uncertainty window; not re-verified against the
local binary this session since neither is a plausible 4.x-delta
candidate, but flagged here per CLAUDE.md section 1's disclosure rule
regardless.

### Animation timing and movement follow fix (2026-08-08)

- `SpriteManifest.get_animated_frames()` now leaves each frame at
  SpriteFrames' default relative duration of `1.0`. The authored `fps` is
  already applied through `set_animation_speed()`; multiplying frame duration
  by `1 / fps` made the walk loop run at approximately `fps * fps`.
- `PlayerVisual` uses the staged `male1_idle` entry while the player is still
  and switches to `male1_walk` only when velocity is non-zero. Missing idle
  data still falls back to the existing walk-only path.
- `IsoCamera` enables presentation-only Camera2D smoothing for the fixed 60 Hz
  player target. `player.json` v5 carries `camera_smoothing_speed` (600.0),
  preventing visible stepping when display frames do not align with physics
  ticks without changing simulation position, facing, or targeting.
- Added an art-foundation regression check for the FPS/frame-duration
  separation. The Godot 4.7.1 headless suite was subsequently run locally and
  passed; the exact verification is recorded below.

### ADR-042 terrain art handoff (2026-08-08)

- Continued the terrain-rendering pass from Claude's handoff: the data-driven
  terrain manifest now wires loamy grass, tilled, and wet-tilled variants plus
  both loamy transition directions into `FarmRenderer`. Sandy and rocky
  materials remain fail-soft to their existing soil-color primitives until
  matching source art is available.
- Removed the temporary `_debug_terrain_shot()` mutation/screenshot hook from
  `Main` after validation. The headless CLI startup path does not expose a
  useful visual screenshot artifact, so an in-editor visual eyeball of the
  new loamy tile atlas and transitions remains a manual follow-up.
- Verification: Godot 4.7.1 `--headless --path . --script
  res://tests/run_tests.gd` passed all 2,183 checks; a clean headless main-scene
  startup with `--quit-after 3` also exited successfully. The test run still
  prints the established off-tree `get_node()` diagnostics, intentional
  missing-texture diagnostics, and teardown RID/resource leak warnings; none
  changed the pass result.

### Startup world disappearance fix (2026-08-08)

- Reproduced the report with a delayed 180-frame scene diagnostic. Godot's
  built-in `Camera2D.position_smoothing_enabled` eventually changed the canvas
  transform to `(nan, nan)` while the UI CanvasLayers stayed alive; this was
  the direct cause of the world disappearing after startup.
- `IsoCamera` now keeps engine smoothing disabled and applies a manual,
  presentation-only `Vector2.move_toward()` follow using the existing
  `camera_smoothing_speed` data value. Zone changes reset the interpolation so
  a new map snaps into view instead of blending from the previous zone.
- Added camera regression coverage. Full Godot 4.7.1 verification passes all
  2,186 checks, and the delayed startup diagnostic remains finite through 180
  frames with the world renderer and world-visual container visible.

### Terrain redraw, idle-sheet, and coordinate HUD follow-up (2026-08-08)

- `FarmRenderer` now caches resolved terrain plans per cell, terrain textures,
  and source rectangles. Tile changes invalidate the changed cell plus its
  four transition neighbours; zone swaps clear the plan cache. This preserves
  transition correctness while removing repeated manifest/resource work from
  camera-boundary redraws, which explains why the lag was strongest in the
  larger 24x16 zones and disappeared when the camera hit a clamped edge.
- The live OpenGL capture path rendered the current Fallowfield terrain with
  the expected green loamy texture, confirming the generated PNGs and Godot
  imports are valid. The earlier white screenshot could not be reproduced in
  the current capture after the renderer fix.
- `male1_idle`'s north and north-west sequences now use four authored frames;
  the source sheet's remaining cells are transparent padding and were causing
  the player to vanish during idle loops. Added manifest regression checks.
- HUD now shows `[X, Y - Zone]` above the health bar, with the agreed diamond
  orientation legend `N ↗ E ↘ S ↙ W ↖` (north is the top-right face, then
  clockwise).
- Full Godot 4.7.1 verification passes all 2,188 checks. Known non-fatal
  harness diagnostics and teardown leak warnings remain unchanged.

### Target assist and grid item aiming (2026-08-08)

- Normal interaction now resolves a deterministic, narrow forward cone in
  two passes: nearest eligible character first, then nearest eligible object.
  The exact faced tile remains the fallback for farming and other tile actions,
  and the HUD/target indicator read the same resolved target so the affordance
  and the committed action cannot disagree.
- Holding Interact with an equipped item freezes the player's physical motion
  and starts a separate logical aim cursor on the exact faced tile. Directional
  input advances that cursor one grid cell immediately, then repeats using the
  data-driven delay/interval in `player.json`; release commits the cursor tile.
  Bare-hand holds lock the normal assisted character/object instead.
- `TargetResolver` is a plain typed helper, not an autoload. It owns only
  deterministic forward-offset ordering and one-cell aim stepping; it does not
  touch simulation state or projection math.
- Added `test_target_assist.gd` coverage for candidate ordering, rear-cone
  exclusion, character priority, and one-cell aim stepping. Godot verification
  is pending because the 4.7.1 executable was not discoverable from the current
  shell session.

### Active-item cardinal aim and back-idle cadence follow-up (2026-08-08)

- Active-item aim now resolves raw screen controls through
  `IsoProjection.input_to_aim_grid_dir()`: W/up is grid North `(0,-1)`, S/down
  is South `(0,1)`, A/left is West, and D/right is East. Ordinary movement
  retains the existing projected input path.
- `SpriteManifest` accepts an optional per-direction `fps`. The player idle
  sheet's four-frame north and north-west rows use `1.6666667` FPS so their
  cycle duration matches the twelve-frame rows at 5 FPS instead of looping
  three times faster.

### Interaction-preview performance follow-up (2026-08-08)

- `Player.get_interaction_info()` now caches the read-only target/preview
  result for the current physics tick. HUD and world-indicator consumers share
  that result instead of independently rescanning the forward cone and
  repeating GameData/BuildingManager lookups every render frame. The cache is
  invalidated on movement ticks, zone/grid swaps, NPC lookup changes, holds,
  cancels, and equipment processing.

### Terrain redraw trigger follow-up (2026-08-08)

- `FarmRenderer` now compares the actual `IsoProjection.visible_cells()` cull
  rectangle before requesting a camera-driven redraw. The previous trigger
  compared only the camera's floored grid cell, so the 24x16 spawn map paid
  for all 384 terrain cells again whenever the camera crossed a cell even
  after the padded cull rectangle had already clamped to the full map. The
  smaller east map therefore appeared less laggy because each redundant redraw
  visited fewer cells.
- Added terrain-suite coverage for unchanged cull rectangles, changed cull
  rectangles, and a fully visible small map remaining redraw-stable while the
  camera moves across it.

### Terrain hoe transition correction (2026-08-08)

- Corrected `asset_studio/make_terrain_transitions.py`: combining all selected
  edge gradients with an unadjusted `max()` made a tile surrounded by the
  other material flood toward that material, while adjacent tiles appeared to
  receive the newly hoed surface. The edge influence now falls back to the
  centerline before blending, preserving the cell's own material in its
  interior.
- Regenerated both loamy transition families under
  `assets/sprites/terrain/`. The tilled cell now reads as tilled soil with
  grass only at its bordering edges, and the neighboring grass cells no
  longer turn into large post-hoe patches.

### Seasonal terrain families (2026-08-09)

- Completed ADR-042 terrain coverage for every shipped soil family. Spring
  now has textured loamy, sandy, and rocky grass/dry-tilled/wet-tilled
  material families, with both ordered grass-to-tilled transition directions.
- `terrain_manifest.json` is v2 and nests the same material/transition schema
  under Spring, Summer, Autumn, and Winter. `GameData` keeps v1 flat-manifest
  compatibility, while `FarmRenderer` retains season-neutral material ids and
  chooses the active season only when resolving presentation assets.
- `Main` forwards the existing `TimeManager.season_changed` signal to
  `FarmRenderer.set_terrain_season()`. That call clears render-only caches and
  redraws; it does not touch FarmGrid, saves, moisture, collision, or farming
  simulation.
- Added reproducible terrain tooling: `build_seasonal_terrain.py` slices the
  generated sandy/rocky source sheet, applies the existing seamless/diamond
  masking and transition rules, and produces palette-related summer/autumn/
  winter variants. `make_terrain_manifest.py` writes the manifest; the
  generated files themselves remain under the tracked runtime asset path.
- Added `tests/run_terrain_manifest.gd` and extended
  `test_terrain_manifest.gd` for seasonal resolution. Verification: Godot
  import succeeded; focused terrain suite passed 81/81; all 504 terrain PNGs
  were confirmed 128x96 with transparent diamond corners and every manifest
  path exists; headless startup (`--quit-after 3`) exited cleanly; `git diff
  --check` is clean. The broad `run_tests.gd` runner again produced no suite
  output and timed out at two minutes, an existing harness behavior rather
  than a terrain test failure.

### Terrain art direction follow-up (2026-08-09)

- Reworked cultivated material sources so visible furrows follow projected
  West-to-East (northwest-to-southeast on screen) with a wrap-preserving shear
  before tile cutting and transition generation. This is visual-only and
  retains the diamond alpha / seamless-material pipeline.
- Changed Winter dry and wet tilled palettes from blue-gray to muted frozen
  earth browns after the prior set read as grey slush. Rebuilt the seasonal
  review sheet at `asset_studio/terrain_test/seasonal_terrain_review.png`.
- Verification after the revision: Godot import passed, the focused terrain
  suite passed 81/81, all 504 terrain textures remain 128x96, and
  `git diff --check` is clean.

### Interior visual rule (2026-08-09)

- Owner ruling for all interior art: North and West walls render; East and
  South walls are invisible to preserve the readable open-room cutaway.
  Data-defined doors and windows still render even when located on a hidden
  near wall. Recorded in `asset_studio/visual_canon.md` before beginning the
  player-home interior integration pass.
- Interiors are intentionally allowed to be much roomier than their exterior
  footprint suggests. The existing player-home 10x7 interior behind a 3x2
  cottage is therefore a deliberate spatial convention, not a scale defect.
- Base interior art must remain furniture-free. Future beds, tables, storage,
  hearths, rugs, and decorative items belong to a player decorating system
  rather than a baked background image.
- Interior shells also cannot bake doors, windows, or wall-mounted objects.
  Those are separately placed visual overlays backed by zone data, keeping the
  continuous North/West shell intact and letting doors/windows move without
  regenerating the whole room.

### Player home interior doorway (2026-08-08)

- Added the data-driven `player_home_interior` zone (10x7) and a local door
  transition at Fallowfield `(13, 11)`, the east wall of the player cottage.
  Walking onto that door moves the player to `(8, 3)` inside; walking through
  the interior's east doorway exits via the normal edge transition and lands
  at `(14, 11)`, one tile outside the cottage, preventing an immediate
  re-entry loop.
- Feature collision now leaves the exterior east-wall doorway open and builds
  the interior perimeter with a matching east-side gap. FarmRenderer draws a
  simple interior floor/wall treatment, and StructureVisual marks the cottage
  door on its near east face.
- Extended GameData/ZoneManager with typed door lookup/resolution seams and
  updated zone/save transition coverage for the tenth registered grid.

### Offline dimetric asset-generation guides (2026-08-09)

- Added the tracked `asset_studio` catalog, Godot headless guide generator,
  modular structure compositor, and Terra/RunPod operating guide. The offline
  generator calls `IsoProjection` directly, so all generated building guides
  share the game’s `64x48` dimetric projection rather than carrying a copied
  formula. Each structure declares only South/East visible faces and a
  required primary-entry side; the generator rejects illegal face/anchor
  combinations before it writes any guide.
- Generated and parse-checked 33 target guides plus eight reusable
  door/window/ramp/gate face guides. A coop shell-plus-three-module smoke
  composition produced an auditable recipe; missing module assignments fail
  closed. This remains offline source-art tooling only: no gameplay data,
  save state, or renderer behavior changed.

### Terra village-source batch and review handoff (2026-08-09)

- Generated transparent source art for an alehouse exterior, a villager-cottage
  exterior, matching empty cottage/alehouse interiors, an empty chapel
  interior, a fallen-log prop, and a spring ground-clutter decal. The ignored
  files and their human-review/integration status are enumerated in tracked
  `asset_studio/terra_trial_manifest.json`; these are source assets only and
  are not yet scene-integrated.
- The reusable South/East module library remains the mechanical placement and
  customization contract. Direct alpha-compositing independently generated
  modules onto a painted shell was tested and rejected as a final-art method:
  it cannot reliably inherit the shell's painted material or erase guide-color
  placeholders. Finished buildings should instead use the structure guide in
  a single in-context generation/edit pass, then retain modules for future
  variants and non-destructive game overlays.
- The local asset-critic scan completed for every existing
  `vertical_slice_test` PNG and wrote ignored metadata receipts. Its Ollama
  vision service was offline, so the scan is not a visual acceptance pass.
  `goat_photoreal_drift.png` remains an explicit known reject; all other
  existing images still require human dimetric/style review before adoption.

### Asset-guide generator execution repair (2026-08-09)

- `generate_dimetric_guides.gd` now rasterizes its drawing pass at 256 square
  and nearest-upscales to the manifest's fixed 1024 square canvas. The
  projection seam, output dimensions, and slot polygon coordinates are
  unchanged; a full 33-asset + 8-module run now completes in 3.5 seconds
  rather than exceeding a five-minute headless test cap.
- The apparent Godot crash was also diagnosed: in this automation environment
  a sandboxed `--script` launch cannot create the engine's normal local
  `user://` configuration folders and terminates before script execution.
  Running the same headless command with those local permissions succeeds.
- Focused checks passed: generator (33+8 guides, 1024 canvas), the coop
  composition smoke test, Python compilation, JSON parsing, and diff hygiene.
  The full gameplay suite still hits pre-existing unrelated
  `test_interact_hold` failures (`ToolManager` queried outside an active scene
  tree, followed by an invalid suite-script instantiation); it was not altered
  by this source-art task.

### Visual-canon and fixture-seam follow-up (2026-08-09)

- The approved visual target is documented in
  `asset_studio/visual_canon.md`: dimetric `64x48` projection, a South or
  East near-face entry, two wall faces plus roof, and transparent isolated
  output. Coop, well, hearth, chapel, and cottage/alehouse are the first
  canonical subjects. Terra source files remain staged only until commercial
  terms and a human dimetric/style review are confirmed.
- `FeatureRenderer` now resolves optional sprite IDs for the fixed player
  house, wells, chapel, tithe chest, market stall, and town board through the
  shared manifest seam. Missing entries deliberately retain their primitive
  proxies, so approving one of those assets is now a data/file addition rather
  than a renderer change.
- The unused purchased building source packs were moved intact to the sibling
  archive `%USERPROFILE%\\Documents\\2DFarmingSim_ArtArchive\\purchased_structure_sources`.
  The two runtime-referenced exterior files remain under `assets/sprites/`.
- `ToolManager` now treats autoloads as unavailable while it is instantiated
  off-tree by tests, instead of issuing absolute-path node queries. The new
  `tests/run_interact_hold.gd` focused runner passes all 52 assertions without
  that engine error. Shutdown RID-leak notices originate in existing test
  fixture cleanup and do not fail the suite; a complete-suite run remains
  separately stalled/non-reporting in this automation context.

### Approved structure placement and South-entry farmhouse alignment (2026-08-09)

- The owner confirmed commercial use of all downloaded assets. The Terra
  cottage is now the `player_house` texture and the Terra alehouse is a fixed
  `alehouse` texture in Nettleford at `(15, 10)`, a 3x2 footprint near the
  market/chapel and clear of the village exits and well. The alehouse is a
  non-enterable landmark until an interior and interaction are separately
  authorized; its six cells are solid so the visual does not imply an
  unfinished walkable room.
- The farmhouse doorway moved from the East to the South face: Fallowfield's
  door is `(11, 12)`, entering at `(5, 5)` inside the 10x7 home; the return
  exit is the interior's South edge and arrives at `(11, 13)`. Feature
  collision now opens exactly the data-defined East-or-South side rather than
  retaining the former unconditional South gap, and the primitive fallback
  marks the South face as well. This keeps the South-entry Terra cottage,
  displayed door, collision, and zone transitions aligned while preserving
  the axis-aligned simulation grid.
- Added regression expectations for the South home orientation, Nettleford
  alehouse anchor, and five-visual/ten-collision village fixture rebuild.
  Godot imported the new PNGs and the focused generated-art suite passes
  24/24. JSON parsing and `git diff --check` pass. The full runner and a
  narrowed zone/structure/transition runner both still time out at 64 seconds
  without output in this host, so broader engine-run verification remains
  separately non-reporting rather than a recorded assertion failure.

### Approved Spring crop-stage integration (2026-08-09)

- The owner approved a fresh, consistent three-stage crop batch for turnip,
  barley, carrot, pea, onion, leek, oat, and flax. The 24 alpha-safe frames
  are packed into `assets/sprites/world_dressing/generated_atlas_linear_0.png`;
  `sprites_world_dressing.json` v2 carries the static atlas entries plus one
  presentation-only `crop_stage_set` for each crop at progress thresholds
  `0.0`, `0.5`, and `1.0`.
- `GameData` indexes those sets separately from `crops.json`,
  `SpriteManifest` selects the last applicable stage id, and `FarmRenderer`
  draws that texture at the old crop-dot cell anchor. Missing data/texture
  still falls back to the pre-existing unripe/ripe dot, so the change touches
  no crop mechanics, saves, grid state, or collision.
- Godot imported the atlas successfully. The focused crop-stage suite passes
  112/112 and the approved structure-art suite passes 24/24. The broad runner
  remains subject to the pre-existing non-reporting 64-second timeout.

### Modular player-home interior shell (2026-08-09)

- The player home now uses an optional interior visual recipe in `zones.json`:
  a clean, furniture-free shell plus independent South-door and North-window
  fixture records. The shell contains only continuous floor, North/far wall,
  and West/left wall; it deliberately has no baked openings, furniture, or
  wall objects. This preserves the room's intentionally roomy 10x7 gameplay
  footprint and leaves future player decorating free to add or move objects
  without regenerating base art.
- `GameData` loads and integer-casts the fixture records, while
  `FarmRenderer` draws a manifest-backed shell first and independently layers
  each fixture at a data-defined perimeter side/index. East and South walls
  remain camera-cut away. If either texture is unavailable, the existing
  immediate-mode room remains a playable fallback and draws North/West walls
  plus simple independent fixture indicators; no simulation, collision, save,
  or zone-transition data depends on the art.
- Runtime art lives in `assets/sprites/interiors/` and is registered by the
  new `data/sprites_interiors.json` manifest. The focused suite
  `tests/run_interior_visuals.gd` covers the shell/fixture data, resource
  resolution, `draw_scale` seam, North/West convention, and perimeter mapping.
  Godot imported the three PNGs and passed 30/30 checks; `git diff --check`
  remains clean. The broad runner remains separately non-reporting in this
  host and was not presented as a pass.

### Interior redraw and collision-edge correction (2026-08-09)

- The white Home Interior viewport was a renderer lifecycle regression: its
  first redraw could be queued before `FarmRenderer` entered the scene tree,
  and a zone change could then leave that cleared viewport visible until a
  later camera redraw. `FarmRenderer._ready()` now requests a post-tree redraw
  and Main defers one additional presentation-only redraw after replacing the
  active zone grid.
- Interior collision still blocks all four logical map edges (with the
  data-defined South doorway gap), but each 6px collision band now lives
  immediately *outside* the `10x7` room bounds. The inner collision edge is
  exactly the rendered room perimeter, so a player can reach the wall/edge
  without encountering an inset invisible barrier. This preserves the owner
  ruling that the cutaway East/South sides remain non-passable.
- `tests/run_interior_visuals.gd` now passes 34/34, including exact
  North/West/South/East boundary-origin coverage. A normal autoload-backed
  headless launch of `main.tscn` completed without parse/runtime errors;
  `git diff --check` remains clean.

### Runtime art-wiring correction (2026-08-09)

- The first cottage/well correction staged replacement PNGs but did not switch
  the `player_house` and `well` manifest entries, leaving the old Terra
  cottage and padded atlas well in the running game. Those entries now point
  to the alpha-safe dimetric replacements with explicit ground-anchor pixels
  and presentation `draw_scale` values; `SpriteManifest.apply_static()` now
  honours that optional scale for all static sprites.
- The white interior showed that `FarmRenderer`'s immediate-mode interior
  path was not a reliable home for a full shell texture. `FeatureRenderer`
  now builds the shell, South door, and North window as direct live
  `WorldVisuals` Sprite2D roots, the same layer proven to render actors. The
  terrain renderer draws its primitive room only if the shell texture cannot
  load, preventing double-blended art while retaining a fail-soft fallback.
- Godot imported the replacement PNGs. The focused interior suite now passes
  39/39 including the live shell/door/window construction check; the focused
  generated-structure suite passes 24/24; `git diff --check` remains clean.

### Deterministic dimetric asset-rig golden proof (2026-08-09)

- Added a parallel v2 asset-rig lane. It left the existing v1 source-art
  catalog untouched while the proof was built. `asset_rig_catalog_v2.json`
  currently covers only the player-house exterior, the roomy player-home
  interior, and the well.
- `generate_asset_rigs.gd` is the sole v2 coordinate resolver: it calls
  `IsoProjection`, emits exact wall/roof/floor/fixture polygons, derived
  anchors and draw scale, and SVG guides. Python composition consumes those
  resolved coordinates and contains no copy of projection math. A first
  synthetic run caught and fixed two geometry defects before any art was
  generated: prism rectangles were initially read with the wrong dimensions,
  and a one-tile gable rise degenerates a roof plane at the pinned dimetric
  ratio. Roof rises are now constrained below `0.95` tiles; the farmhouse
  proof uses `0.65`.
- `compose_asset_rig.py`, `validate_asset_rig.py`, and
  `make_asset_rig_review.py` compose flat materials/flat-front modules,
  preserve anchors through crop, fail closed on polygon/alpha/scale/source
  mismatches, and write checkerboard-plus-geometry review sheets. The North
  interior window specifically retains transparent space below it so its
  perimeter anchor is not lost by a tight crop. The well's near-corner sort
  anchor is correctly allowed to be transparent; the validator instead
  requires opaque art at the centred contact region. The same composer now
  accepts a real transparent `sources_v2/props/well.png`, scales its visible
  base to that contact region, and keeps its placement recipe-derived.
- The six real sources are now retained under `asset_studio/sources_v2/` with
  provenance sidecars: whitewash timber, golden thatch, oak floorboards, a
  flat oak door, a flat shuttered window, and a transparent well with an
  explicit contact landmark. Their material/module-only brief means no model
  was asked to solve final building perspective. All three real compositions
  passed compose/validate/review.
- The review sheet now includes a third, actual-runtime-scale panel. For a
  prop it shows the one-cell diamond, the allowed contact ellipse, and the
  transparent near-corner sort anchor. This makes clear that guide/grid lines
  are QA evidence only; the final game may hide ordinary grid lines without
  changing the invisible logical-grid anchors that placement, collision,
  interaction, transitions, and Y-sort still require.
- The hardening pass now maps material textures projectively onto each
  resolved wall, roof, or floor plane instead of tiling in screen space. Real
  props require an explicit `contact_bbox_px` source landmark, and every real
  source requires a hashed sidecar with backend, model, prompt, and license.
  The validator independently reloads the resolved manifest and rejects
  altered manifest hashes, resolved-asset hashes, embedded geometry, output
  scale, alpha escapes, source hashes, metadata hashes, and missing
  provenance.
- `asset_studio/test_asset_rig_pipeline.py` supplies ten deterministic
  end-to-end/negative tests. It includes simulated real flat materials,
  modules, and a transparent well with contact metadata, proving the real
  input path without a model call. All ten pass, as do the three regenerated
  golden-proof compositions and validators. Only gabled roofs are accepted in
  the proof; hipped and lean-to catalogs fail until separately implemented.
  The owner then explicitly approved promotion. The generated farmhouse, well,
  roomy interior shell, and separately placed South door/North window now live
  under `assets/sprites/`; their runtime manifest entries were updated from
  the resolved recipes. Live exterior capture verified the corrected opaque
  gable end, exact generated footprint anchor, and centred well. Focused art
  suites passed after promotion.

### Asset-rig edge-quality refinement (2026-08-09)

- The first promoted proof was geometrically correct but still left final
  reduction to Godot (`draw_scale = 0.25`). Bicubic transform boundaries and
  chroma-key RGB in transparent pixels could therefore produce a broken gable
  seam, dark fringe, and uneven one-pixel contours at runtime.
- `compose_asset_rig.py` now samples opaque material transforms inside their
  source boundary, clips exact surface alpha, aligns every crop and anchor to
  the 4x `source_scale`, derives a two-tone gable-base finish from the wall
  material itself, and writes a second production PNG through
  premultiplied-alpha Lanczos reduction. The high-resolution PNG remains the
  geometry proof; runtime uses the reduced PNG at integer anchors and
  `draw_scale = 1.0`.
- `validate_asset_rig.py` now hashes both outputs and rejects altered runtime
  art, non-integral source-scale frames/anchors, incorrect runtime dimensions,
  nontransparent corners, missing antialiased coverage, and any runtime scale
  other than 1. `make_asset_rig_review.py` displays the actual baked file in
  its runtime panel. The pipeline suite now has ten passing tests, including
  modified-runtime rejection and exact alpha-safe reduction checks.
- Promoted v4 runtime dimensions: farmhouse `165x217` anchored at `(98,214)`,
  well `60x95` at `(29,92)`, interior shell `549x485` at `(226,74)`, South
  door `32x76` at `(16,64)`, and North window `24x60` at `(12,57)`. Focused
  generated-art and interior suites remain green at 24/24 and 39/39.

### Cohesive farmhouse exterior (2026-08-09)

- The v4 farmhouse was geometrically exact but looked compressed and
  assembled because independently painted wall, roof, door, and window
  sources were visibly projected together. The production exterior lane now
  follows `visual_canon.md`: generate or paint one cohesive building from the
  exact rig plus an approved style reference, then correct only its three
  annotated ground corners.
- `compose_cohesive_structure.py` applies one bounded affine transform to the
  complete painting. It derives target South/near/East controls from the
  resolved Godot rig, preserves the near corner as the sort anchor, performs
  the same premultiplied-alpha runtime reduction as the modular compositor,
  and records hashed source metadata and transform evidence. This is not a
  projective rescue path for unrelated whole-building renders.
- `validate_asset_rig.py` independently checks cohesive target controls,
  source-sidecar controls, rig-relative output controls, painted contact at
  all three corners, bounded dimensions, provenance, hashes, scale, anchors,
  and runtime alpha. Four new negative/positive tests bring the two compositor
  suites to 14 passing tests.
- Promoted `player_house_rig_v5.png`: `178x255`, anchor `(111,252)`, South
  control `(15,180)`, East control `(175,204)`, runtime scale `1`. The live
  `1280x720` Godot capture confirms a unified stone foundation, timber frame,
  eaves, ridge, fixtures, palette, and lighting while both foundation vectors
  follow the terrain diamonds. Generated-art suite remains 24/24.

### North-South farmhouse depth proof (2026-08-09)

- The owner clarified that the desired widening is along the North-South
  axis. The player house is now a true `4x3` logical footprint at
  `Rect2i(9, 9, 4, 3)`, extending one row north while retaining the South
  doorway at `(11,12)`, the existing interior landing, and the starter well.
  Visual placement and wall collision share that footprint; the South sort
  anchor remains grid `(13,12)`.
- The refined modular v7 proof increases the South door to `0.78` cell width
  and `0.92` wall height with its center locked to the transition tile. Its
  gable roof uses a `0.55`-tile rise plus bounded end/eave overhangs
  `[0.12,0.18]`; the resolver validates overhangs within `0..0.5` cells.
- The East window was subsequently enlarged from `0.42x0.40` to
  `0.82` cell width by `0.54` wall-height ratio and moved from face position
  `0.55` to `0.40`. It now occupies the northern plaster bay without crossing
  the near-corner timber beam, while remaining a projected
  orientation-specific module.
- Material metadata can now declare `tile_size_px`. The thatch source uses a
  256px repeat instead of stretching one large generated swatch across each
  roof plane, and the compositor draws one clipped structural ridge after
  both planes. This remains the exact guide/control for the pending pod
  detail pass, not a claim that modular fill is the final painted exterior.
- Exterior timber framing is no longer inherited from arbitrary lines baked
  into the repeating whitewash swatch. That source now declares a plain
  plaster sample plus `perimeter` framing mode; the compositor fills each
  South/East plane with plaster and then draws only its resolved top plate,
  sill, and selected corner posts. The East face omits a separate vertical
  accent on its rear/North-East boundary; its one visible support is the
  heavier South-East edge shared with the South face. That edge is
  deduplicated into one explicit load-bearing corner post, so resizing a
  structure cannot move a decorative texture beam into the middle of a wall.
- Runtime v7 is `248x241`, anchored at `(140,238)`, with a `4x3` manifest
  footprint. Verification: 15 Python compositor tests, 61/61 structure
  assertions, 53/53 zone-transition assertions, and 24/24 generated-art
  assertions. Focused suites retain their existing shutdown RID/object-leak
  diagnostics despite returning success.

### Asset-method status and TRELLIS.2 experiment (2026-08-10)

- The production art decision is unchanged: retain the `64x48` dimetric game
  and use the deterministic 2D asset rig as the authority for footprints,
  anchors, fixture slots, alpha-safe runtime bakes, and provenance. The
  cohesive-exterior lane is the preferred finished-building look; the
  flat-material/module lane remains its exact geometry proof and fallback.
  Do not attempt to rescue unconditioned whole-building generations with a
  projective warp, and do not bake interior fixtures or furniture into base
  shells. `design/asset_generation_status.md` and
  `asset_studio/visual_canon.md` are the concise takeover references.
- The whitewash-and-thatch structure kit v1 now extends the accepted 4x3
  player-house proof without changing its Godot footprint, anchor, door, or
  window slots. It uses the resolved rig to layer continuous wall material,
  timber posts/rails, gable framing, roof planes, eaves/ridge, then fixtures.
  Crucially, roof planes are composited after wall framing, so a timber beam
  cannot render through the roof. The offline composer, its profile file, and
  regression coverage live under `asset_studio/`; `design/structure_kit.md`
  explains the source-module roadmap. It is a candidate only until a human
  visual review promotes its runtime PNG.
- The optional TRELLIS.2 -> GLB -> headless Blender -> fixed-camera PNG lane
  is strictly an offline feasibility experiment, not a conversion to runtime
  3D or 2.5D. Its A100 environment, compiled CUDA dependencies, and Blender
  4.5.12 headless install passed, and DINOv3 access subsequently cleared. The
  bundled official image and the approved `farmhouse_wide_4x3_southeast_post`
  source now both completed GLB export and fixed-camera Blender reopens. The
  farmhouse result preserved a coherent widened volume but hallucinated an
  extra door/window arrangement and altered the roof, so the method is a
  technical 3D/blockout proof—not a production asset generator. Keep the 2D
  rig authoritative and do not promote TRELLIS output without repeatable,
  architecture-safe normalization. Operational detail and output paths are in
  `design/trellis2_runpod_handoff.md`; no token is recorded in the project.

### Proposed standard-isometric conversion handoff (2026-08-10)

- The owner is evaluating a switch from the accepted `64x48` dimetric
  presentation to common `64x32` (2:1) isometric presentation so commercially
  available modular art has a realistic integration path. This is a **proposal,
  not an active contract change**: ADR-032 remains accepted and all current
  runtime art/tooling remains dimetric until the owner makes a formal decision.
- `design/standard_isometric_conversion_guide.md` is the execution-grade
  handoff for a future DeepSeek/Claude implementation. It pins the candidate
  formulas, preserves the logical 32-unit simulation, collisions, saves,
  WorldVisuals/Y-sort architecture, immediate-mode terrain, and screen-relative
  input, then specifies staged tests, art migration rules, rollback, and a
  copyable implementation prompt. It explicitly forbids squashing old 64x48
  art into 64x32 and requires a live representative review before further art
  promotion.

### Standard-isometric conversion Phase 0 checkpoint (2026-08-10)

- Owner authorized implementation of
  `design/standard_isometric_conversion_guide.md` ("Let's go ahead and get
  the isometric conversion going"). This landed the guide's Phase 0 decision
  checkpoint: **ADR-043** appended to `design/decisions.md` (supersedes
  ADR-032 only as to the `64x48` -> `64x32` tile aspect; every other
  ADR-032 ruling restated unchanged), `CLAUDE.md` amended to v0.23 (section
  1's projection pin, section 2's projection bullet, section 8's invariant,
  section 5's directory tree, changelog), and `AGENTS.md`/`DEEPSEEK.md`
  regenerated via `docs/make_agents.gd`/`docs/make_deepseek.gd` in the same
  pass (58909 / 62486 bytes written, no generator errors).
- **Baseline commit:** `ed203ba` ("Add standard isometric conversion
  guide") - the tip of `feature/sprint16-art-foundation` immediately before
  this checkpoint, working tree clean apart from two untracked,
  unrelated directories (`.codex-remote-attachments/`,
  `asset_studio/runpod/__pycache__/`). **Rollback point:** revert to
  `ed203ba` (or the branch below, pre-Phase-1) to fully undo the conversion;
  old `64x48` dimetric art and source metadata are untouched by this
  checkpoint and stay in place as provenance per the guide's rollback
  section.
- **Branch:** `codex/standard-isometric-conversion`, cut from `ed203ba`.
- **Target:** standard `64x32` (2:1) isometric screen diamond,
  `IsoProjection.TILE_H` 48.0 -> 32.0, `LOGICAL_CELL` (32) and `TILE_W`
  (64) unchanged. No save migration; save version stays 18.
- Full-suite baseline run was launched headless
  (`--headless --path . --script res://tests/run_tests.gd`) before any
  Phase 1 code edit; exact pass/check count to be recorded here once it
  completes (see the Phase 1 entry immediately below for the actual
  before/after counts once available - this bullet exists so the baseline
  invocation itself is on record even if the follow-up entry is what ends
  up carrying the number).

### Standard-isometric conversion Phase 1 (2026-08-10) - projection foundation

- `IsoProjection.TILE_H` changed `48.0` -> `32.0` in
  `scripts/globals/iso_projection.gd`; `TILE_W` (64) and `LOGICAL_CELL`
  (32) untouched. `cell_diamond()`'s docstring and the file's own header
  comment updated in the same change (guide requirement).
- Every encoded-pixel test value recalculated by hand (not guessed) for
  `TILE_H=32`: `tests/suites/test_iso_projection.gd` (forward formula,
  diamond corners, world round-trip) and
  `tests/suites/test_iso_camera.gd` (`_recompute_limits` bounding boxes for
  both the real 24x16 fallowfield zone and a synthetic 10x10 map, the
  30x20 fallback-clamp scenario, and the north_strip/nettle_brook
  per-zone bounding-box y-assertion). `test_iso_terrain.gd`,
  `test_iso_structures.gd`, and `test_iso_actors.gd` needed **no** numeric
  edits - they compute expected values through live `IsoProjection` calls
  rather than hardcoding pixels, exactly as the architecture intends.
- **Real finding, documented in `iso_camera.gd`'s own docstring**: at
  `BASE_ZOOM=1.0`, the grid-space margin the diamond clamp requires rises
  from 17.5 (old 64x48 aspect) to 21.25 (new 64x32 aspect) for the
  1280x720 base viewport. On the 30x20 synthetic fallback-test map this
  pushes the Y axis from "narrower swapped band" into
  `_clamp_or_centre`'s full fixed-midpoint branch - the camera's Y
  position freezes at the map's vertical centre for *any* player position,
  never following vertically, while X still tracks (its margin stays
  below the full span). The same margin math against the real, shipped
  24x16 Fallowfield zone shows the same full Y-freeze at zoom 1.0. This is
  a real, not hypothetical, consequence of the flatter aspect and is
  exactly what the guide's Phase 2 rule 5 anticipates ("64x32 makes the
  map vertically shorter, so validate zoom and clamp math ... before
  selecting a new zoom constant") - **BASE_ZOOM is deliberately left at
  1.0 for this phase**; retuning it is Phase 2 work and needs a live
  capture to judge the field-of-view tradeoff, not a guessed constant.
- Two incidental sprite-scale test literals also encoded the old TILE_H
  and needed recalculation even though neither file is on the guide's
  Phase 1 list (both are pure `IsoProjection.TILE_H`-driven arithmetic,
  the same class of fix, just in `SpriteManifest.get_scale`/
  `get_draw_scale` test callers rather than the projection suites
  themselves): `test_art_foundation.gd`'s `get_scale` unit check
  (0.5625 -> 0.375) and `test_interior_visuals.gd`'s `get_draw_scale`
  fallback check (0.5 -> 1/3). Both were only found by actually running
  the full suite - a static grep for the old literal would have missed
  the second one, since `0.5` alone is too generic to search for safely.
- Front-loaded from Phase 2 (comment-only, zero behavior change): renamed
  ~15 stale "dimetric" references to "isometric" across
  `iso_camera.gd`, `farm_renderer.gd`, `feature_renderer.gd`,
  `structure_visual.gd`, `world_visuals.gd`, `player.gd`,
  `player_visual.gd`, `npc.gd`, `npc_visual.gd`, `enemy_visual.gd`, and
  `main.gd`, each now citing "ADR-032, amended ADR-043". None of these
  files needed a functional change - every wall/prop height already
  multiplies a `HEIGHT_FACTOR` constant by a live-read `IsoProjection.TILE_H`,
  so they scale down automatically, exactly as the guide predicted
  ("existing multipliers ... should adapt automatically"). One comment in
  `feature_renderer.gd` that hardcoded the literal "48" alongside the old
  dimetric-headroom rationale was corrected to state the new 32 value and
  cite ADR-043 instead of restating a now-superseded design rationale as
  current.
- **Environment finding, unrelated to this ADR, found while getting a
  clean baseline run**: this machine was under real RAM pressure (5.5GB
  free of 16GB, several concurrent heavy apps) and this project carries
  21,406 files (1,083 under `asset_studio/`'s generated-art pipeline,
  3,087 `.import` files, 14,456 `.godot` import-cache entries) with
  Windows Defender real-time protection active and no exclusion for the
  project folder - the combination made every headless Godot launch take
  minutes before any script code even ran. Freeing RAM (owner-authorized;
  closed several background apps) measurably improved per-launch
  throughput; a Defender exclusion for the project folder is recommended
  but requires admin rights the agent does not have and does not take
  security-setting actions regardless. A **Godot MCP server**
  (`godot-mcp-enhanced`, community MIT-licensed) was registered
  project-scoped (`.claude` local config, not user-global) with an
  explicit `GODOT_MCP_ALLOWED_GODOT_PATHS` binary whitelist for future
  sessions that want live editor control/screenshots instead of
  repeated cold headless launches; its `setup_project_rules` tool must
  **never** be run in this project - it would overwrite the hand-maintained
  `CLAUDE.md`/`.claude/settings.json` - and its `run_tests` tool depends on
  the GUT plugin, which section 1 forbids, so this project's own
  `tests/run_tests.gd` stays the only test entry point.
- **Pre-existing bug, unrelated to ADR-043, found and fixed because it was
  silently crashing every full-suite run** (confirmed pre-existing: it
  reproduced identically on the very first baseline run launched before
  any Phase 1 edit, and `git log` traces it to commit `b9f02c0`, "Sprint
  16 continuation," well before this branch existed): two test files used
  `:=` type inference on a method called through an **untyped bare
  function parameter** (`gd`/`zm` with no type annotation) -
  `tests/suites/test_zones.gd:146,152` and
  `tests/suites/test_zone_manager.gd:98`. Since the parameter's static
  type is `Variant`, Godot 4.7.1 cannot infer a concrete type for `:=`
  and fails to compile the script (`GDScript::reload` "Cannot infer the
  type" parse error), which `tests/run_tests.gd`'s `suite_script.new()`
  then surfaces as an opaque `Nonexistent function 'new' in base
  'GDScript'` - and because that error unwinds `_initialize()` without
  ever reaching `quit()`, the SceneTree then idles forever, which is what
  made every full-suite attempt look like a 30+ minute hang rather than a
  fast, clean failure. Fixed by giving both variables their real
  `Array[Dictionary]` return type instead of `:=`, per section 3 rule 1's
  own "`:=` inference only where the right-hand type is unambiguous at a
  glance" - these two call sites were never unambiguous, since the
  receiver was untyped. This was the actual, dominant reason full runs
  never finished, separate from (and compounding with) the environment
  slowness above.
- **Full suite now runs to genuine completion for what is - as far as
  either this session or `git log` can show - the first time since
  `b9f02c0` landed.** 2411 checks pass; **6 failures remain, all in
  suites this ADR never touches and that could not previously run at
  all**: `zone-manager round-trip keeps all ten zone keys` (a real
  `ZoneManager` save/load bug, 10 zone keys expected vs 9 got),
  `test_target_assist`'s "a non-empty forward character target is marked
  assisted", and four failures inside `test_zone_manager.gd`'s
  `_test_resolve_exits` all tracing to the same symptom - the fallowfield
  cottage's east door resolves to an empty dict instead of
  `player_home_interior` (`ZoneManager.resolve_door`/`resolve_exit`
  logic, not anything projection-related). None reference `IsoProjection`,
  `grid_to_screen`, camera, facing, or any TILE_H/TILE_W-derived value -
  confirmed by grepping the failure list itself. Left unfixed as
  out-of-scope for ADR-043; flagged to the owner as a separate, pre-existing
  defect rather than folded into this conversion's commits.
- **Acceptance check (guide section 5):** round-trip identities hold for
  integer and fractional values (unchanged formula shape, only the
  constant differs - covered by `test_iso_projection.gd`'s existing round-trip
  suite); a 30x20 map's projected bounds are `x in [-640, 960]`,
  `y in [0, 800]` (hand-verified against the new formula, matches the
  guide's own stated acceptance number exactly); no logical coordinate,
  collision shape, feature anchor, or save migration changed.

### Standard-isometric conversion Phase 2 (2026-08-10) - camera investigation, no fix needed

- **Investigated, then reverted: a `BASE_ZOOM` retune from 1.0 to 1.1**,
  intended to fix `iso_camera.gd`'s documented Y-axis freeze
  (`_clamp_or_centre`'s fixed-midpoint fallback) on the shipped farm map.
  The Phase 1 entry above computed the freeze against the conversion
  guide's own illustrative **30x20** map (ADR-032's original flat property
  map) and found the Y margin (21.25 at zoom 1.0) exactly at that map's
  height (20) - a real freeze, and 1.1 (margin ~19.32) escapes it there.
  That 30x20 figure is stale: Sprint 15/ADR-034 already split the world
  into **per-zone** maps (`data/farm_map.json`), none of which are
  actually 30x20. Live-testing the "fix" in the running editor (launched
  via the Godot binary directly, then driven with computer-use since the
  MCP's `confirm_and_execute` elicitation flow does not complete in this
  harness - see below) showed no visible change in camera behavior on the
  real Fallowfield zone, which prompted re-deriving the check against real
  zone dimensions instead of the guide's example.
- **Real finding: checked all nine outdoor zones' width/height against
  both the old 64x48 margin (17.5) and the new 64x32 margin (21.25) at
  `BASE_ZOOM=1.0`, and every zone's frozen/non-frozen classification is
  IDENTICAL before and after ADR-043.** `fallowfield`/`nettleford`/`manor`
  (24x16), `north_strip` (24x8), `upland_commons`/`cottersward`/
  `south_fields` (~24-32 wide x14 tall) were all already Y-frozen under the
  OLD 64x48 aspect (16 and 14 and 8 are all < 17.5) - this predates
  ADR-043 and traces to how small Sprint 15 made the individual zones, not
  to this presentation-only aspect change. `ediths_plot` (16x14) and
  `nettle_brook`'s X axis (width 16) were likewise already at their
  threshold either way. None of the nine zones' dimensions fall in the
  `(17.5, 21.25)` gap the aspect change opened up, so no zone's behavior
  actually changed in kind - only the exact (already-irrelevant, since the
  branch is already the fixed-midpoint one) margin value moved.
  `BASE_ZOOM=1.1` would not have fixed any real zone (the smallest,
  `north_strip` at 8 tall, needs `zoom > 21.25/8 = 2.66` to escape - a
  field-of-view cut severe enough to hurt every other zone) while costing
  real FOV (~10%) for zero practical benefit, so it was reverted.
  `BASE_ZOOM` stays `1.0`, unchanged from Phase 1.
- **Reframing, not a bug left open:** the fixed-midpoint fallback in
  `_clamp_or_centre` is the *intended, correct* behavior for a zone
  shorter/narrower than the camera's field of view - centering is strictly
  better than showing void beyond the map edge, and per-axis independence
  already guarantees the camera keeps panning on whichever axis the zone
  *is* big enough for (proven by the existing `_test_per_zone_camera_math`
  suite, unchanged). The real, separate question - whether Sprint 15's
  individual zones should be larger - is out of scope for this
  presentation-only ADR (ADR-043 changes tile aspect, not zone
  dimensions) and is flagged to the owner rather than patched here, same
  treatment as the pre-existing `ZoneManager` door-resolution bug above.
- `iso_camera.gd`'s docstring rewritten to record this investigation in
  full (the reasoning, the real per-zone numbers, and why the retune was
  reverted) so a future session does not repeat the same illustrative-map
  mistake. `tests/suites/test_iso_camera.gd` gained
  `_test_real_zone_frozen_classification_unchanged_by_aspect_ratio` (18
  assertions, one X/Y pair per real outdoor zone) as a regression guard - a
  future margin-formula or zone-dimension change that actually crosses a
  real zone's threshold will now fail loudly. Suite count: 66 -> 81 in
  `test_iso_camera.gd`; full suite 2415 -> 2430 checks, same 6 pre-existing
  unrelated failures as the Phase 1 entry above (confirmed identical
  failure list, not just the same count).
- **Live verification method, recorded per CLAUDE.md section 11's "API
  used that could not be verified from memory" duty:** the Godot MCP
  (`godot-mcp-enhanced`)'s `runtime.launch_editor`/`run_project` actions
  require a confirmation token exchanged through the MCP "elicitation"
  protocol (`confirm_and_execute`, an out-of-band human-approval gate the
  server's own code documents as deliberately AI-proof) - this harness's
  `tools/call` round-trip does not complete that handshake and errors
  with `inputRequired.maxRounds` after 8 rounds regardless of the token.
  Root-caused by reading the installed package source directly
  (`%LOCALAPPDATA%\npm-cache\_npx\...\godot-mcp-enhanced\build\core\
  ToolDispatcher.js`) rather than guessing. The maintainer's own
  documented opt-in, `GODOT_MCP_ALLOW_UNSAFE_CONFIRM=true` in the server's
  env (`~/.claude.json`'s `mcpServers.godot.env`), was added at the
  owner's explicit request but needs the MCP connection restarted to take
  effect (not done mid-session), so this Phase 2 work instead launched the
  editor binary directly (`Godot_v4.7.1-stable_win64.exe --editor --path
  .`) via a background shell process, then drove Play/movement/inspection
  through the `computer-use` MCP (screenshots + key input) with the Godot
  window under a scoped access grant. This is a reasonable substitute for
  the guide's "live capture" requirement, not a permanent replacement for
  the Godot MCP's own tooling once the confirm flow is available.
- **Flagged for later, not fixed here (out of ADR-043 scope): the player's
  Fallowfield spawn point sits inside the player house's own collision
  footprint's bounding rect.** `feature_renderer.gd`'s house placement is
  `Rect2i(Vector2i(house_anchor - HOUSE_ANCHOR_OFFSET), HOUSE_FOOTPRINT)` =
  `Rect2i((9,9), (4,3))` for the shipped `house_anchor (11,11)` -
  i.e. collision spans grid x in [9,13), y in [9,12). The player's spawn
  tile, `(12,10)`, falls inside that same rectangle. In practice this is
  not a stuck-in-a-wall bug (the spawn tile itself is walkable - the
  rectangle is the house's overall footprint, not solid fill, and the
  player visibly stands on open grass beside the door in the live
  capture above) - but it does mean any diagonal movement test starting
  from spawn runs into a wall within 2-3 tiles, which is what produced
  the "physically blocked" observation during this session's camera live
  capture (a collision fact, not a camera or projection bug - see above).
  Worth a real look later: whether the spawn tile should be moved a
  couple tiles further from the house/well cluster, purely as a
  playtesting-ergonomics question, unrelated to ADR-043's presentation-only
  scope.

### Performance/efficiency pass (2026-08-10) - Sprint 16 actor rendering

- Owner reported consistent playtest lag. Prior perf work (2026-08-08/09,
  documented above under "Terrain redraw, idle-sheet, and coordinate HUD
  follow-up" and its follow-ups) already covers terrain redraw caching and
  `Player.get_interaction_info()` caching - neither was revisited. This
  pass targeted the one layer that had never had a perf audit: Sprint 16's
  ADR-041 textured-actor rendering (`AnimatedSprite2D` proxies for player/
  NPC/enemy), on the strength of a documented, external Godot 4 engine
  characteristic (`y_sort_enabled` recalculates every direct child every
  frame with no built-in visibility gate -
  [godotengine/godot#74478](https://github.com/godotengine/godot/issues/74478))
  plus a codebase scan (one background Explore-agent pass plus direct
  reading) that found six concrete, fixable per-frame or per-spawn costs.
  Entity counts are modest (9 villagers, 2-6 live enemies during a raid,
  ~9 fixed structure features), so none of this was a 400x400-tile-scale
  emergency - each fix below is a real, contained cost reduction, not a
  claim that any single one was single-handedly causing the reported lag.
- **Fix 1 - `SpriteManifest.get_animated_frames()` now caches its built
  `SpriteFrames` by the full entry Dictionary** (`sprite_manifest.gd`,
  new `_animated_frames_cache` static Dictionary). Previously every call
  built a brand-new `SpriteFrames` with one `AtlasTexture.new()` per frame
  per direction from scratch - harmless for NPCs/enemies (built once at
  spawn) but a real, frequent cost for `PlayerVisual`, whose
  `_switch_animation_state()` calls `apply_animated()` (and therefore
  `get_animated_frames()`) fresh on every idle<->walk transition, which
  happens constantly during ordinary play (stop to till/interact, walk,
  stop, ...). Keyed on the whole entry, not `entry["id"]`, because
  `test_art_foundation.gd`'s own `directional_entry` proves two entries
  can share an id with different `directions` content - GDScript
  Dictionary equality/hashing is by value, so this only collides for
  genuinely identical entries. Bonus effect: multiple enemies sharing one
  archetype (e.g. several `bandit_robber_walk` bandits in one raid) now
  share one built `SpriteFrames` instance too - safe, since `SpriteFrames`
  is a read-only Resource and all playback state (current animation,
  frame, playing) lives on the `AnimatedSprite2D` node, not the resource.
- **Fix 2 - `SpriteManifest.set_facing()` calls are now guarded behind a
  "did facing actually change" check** in `npc_visual.gd`,
  `enemy_visual.gd`, and `player_visual.gd` (each gained a
  `_last_set_facing` field, sentinel-initialized outside
  `FACING_NEIGHBOURS`' range so the first real call still fires). Every
  unconditional call was doing two string-format operations, a
  `StringName` construction, and rebuilding/searching a
  `PackedStringArray` of animation names every frame, for every visible
  actor, regardless of whether it was moving.
- **Fix 3 - `EnemyVisual` no longer calls `queue_redraw()` unconditionally
  every frame.** This one was NOT a copy of `NpcVisual`'s pattern (that
  would have been wrong): the class docstring explicitly documents the
  health bar as needing to "keep drawing regardless" since it is not part
  of any art pack. Replaced the unconditional call with a
  `_last_drawn_health` dirty-check (`enemy_visual.gd`) - the health bar
  stays exactly as current as before (Enemy.health only changes on
  `take_damage()`, not every frame), it just no longer pays for a
  `_draw()` call on every frame nothing changed. Docstring updated to
  describe the new behavior accurately.
- **Fix 4 - `WorldVisuals` now registers itself in the `"world_visuals"`
  group** (`world_visuals.gd`, new `_ready()`). `enemy.gd`'s own docstring
  already documented this as a known API gap: `_find_world_visuals()` was
  written to try the group first and fall back to a full recursive
  scene-tree walk from `root`, but nothing ever actually called
  `add_to_group("world_visuals")`, so the fallback fired on *every* enemy
  spawn - worst-case exactly when a raid spawns 2-6 enemies back-to-back
  (`raid_manager.gd`'s `dynamic_raid_size_min/max`) and CPU is already
  busy standing up new physics bodies. Also cached `Enemy._target` (the
  player reference) in `enemy.gd`'s `_physics_process`, re-resolving via
  `get_first_node_in_group("player")` only when the cached reference is
  invalid instead of every 60 Hz tick - there is exactly one player and it
  does not get freed mid-session.
- **Fix 5 - crop-stage and interior-sprite texture lookups now go through
  `FarmRenderer`'s existing `_cached_texture()`** instead of calling
  `SpriteManifest.get_static_texture()` directly (`farm_renderer.gd`:
  `_draw_crop_stage()`, `_is_interior_shell_managed()`,
  `_draw_interior_sprite()`). The terrain draw path already earned this
  caching discipline in the 2026-08-08 perf pass; these two draw paths
  were added afterward and never got routed through it. Lower-impact than
  fixes 1-4 since `_draw()` itself is already cull-rect-gated (infrequent),
  but a real, free-to-fix inconsistency once noticed.
- **Fix 6 - `Player._physics_process()`'s two `get_node_or_null("/root/...")`
  calls (InputManager, UIManager) are now cached** in new
  `_input_manager_ref`/`_ui_manager_ref` fields, re-resolved only when
  invalid (`player.gd`). The existing code comment explaining why
  `get_node_or_null` is used at all (a bare autoload identifier would fail
  the whole script's compile step under the headless test harness) still
  applies and is preserved verbatim - caching the *resolved Node* does not
  reintroduce that hazard, since the hazard is a bare autoload-TYPED
  identifier, not a plain `Node`-typed member variable.
- **Not touched, per the original audit's own ranking:** uncached-but-rare
  crop/interior texture lookups' sibling cost (already fixed by 5);
  one-time `SpriteFrames` construction at actor spawn (fixed as a side
  effect of fix 1's cache, not separately); `TargetIndicatorRenderer`'s
  unconditional redraw while aiming - left alone, self-documented in its
  own file as an accepted <=3-polygon cost not worth the complexity of a
  dirty-check.
- Verification: full suite run after fixes 1-4 (2430 passed, same 6
  pre-existing unrelated failures as every checkpoint above - the
  `ZoneManager`/`target_assist` bugs, untouched by this pass) and again
  after fixes 5-6 (identical: 2430 passed, same 6 failures) - no
  regressions at either checkpoint. Live-verified in the running editor
  (launched directly, driven via computer-use, same workaround as the
  camera investigation above since the Godot MCP's confirm flow is still
  unavailable this session): repeated rapid idle<->walk transitions and
  facing changes for the player render correctly with no visual
  corruption after the `SpriteFrames` caching change; the interior room's
  textured shell (which exercises the exact `_cached_texture()` call path
  fix 5 adds two more call sites to) continued to render correctly: floor,
  walls, and roof beams all textured and undistorted. Crop-stage rendering
  specifically was not visually re-confirmed live (no crop was grown
  during this session's live check) - low risk, since fix 5 is a
  behavior-preserving cache wrapper around the exact same
  `SpriteManifest.get_static_texture()` call, not a logic change.

### Pre-existing test failures fixed - full suite green (2026-08-10)

- Investigated and fixed the 6 failures that had carried unchanged through
  every checkpoint this session (Phase 1, Phase 2, and the perf pass, all
  flagged as "pre-existing, out of scope" at the time). All six turned out
  to be stale test fixtures, not real `ZoneManager`/gameplay bugs - none
  required a runtime code change.
- **The "expected 10, got 9" zone-key failure was misdiagnosed at first
  glance:** its exact wording ("zone-manager round-trip keeps all ten zone
  keys") doesn't match `test_zone_manager.gd`'s own assertion text
  ("round-trip keeps ten zone keys") - two similarly-worded but distinct
  assertions in different files. Confirmed via a temporary instrumented
  run (print statements added to `ZoneManager.to_dict()` and both test
  files, then reverted) that `test_zone_manager.gd`'s own round-trip is
  and always was correct - every `to_dict()` call inside its suite
  returned all 10 zones. The real failure was
  `test_save_roundtrip.gd:414`, inside `_test_migrates_v17`'s
  zone-manager-round-trip check. Root cause: `test_save_roundtrip.gd`'s
  `ZONE_IDS` constant is a hardcoded 9-zone list that predates
  `player_home_interior` (added to `data/zones.json` in commit b9f02c0,
  "Sprint 16 continuation... interior sprites...") and was never updated
  to match - `_make_zone_manager()` built its test fixture from this stale
  list, so it only ever registered nine grids. `test_zone_manager.gd`
  never had this problem because it builds its zone list dynamically via
  `GameData.get_zone_ids()` rather than hardcoding it. Fix: added
  `"player_home_interior"` to `ZONE_IDS`.
- **The four cottage-door failures were a genuine authoring mismatch
  introduced in a single commit, not a `ZoneManager` logic bug.** Commit
  `b9f02c0` added BOTH `data/zones.json`'s real door/exit data AND
  `test_zone_manager.gd`'s assertions for it in the same commit, but the
  two disagree: the door it actually shipped is south-facing
  (`{"x": 11, "y": 12, "to": "player_home_interior", "arrive_at": {"x":
  5, "y": 5}}`, matching the `interior_player_home_door_south` fixture
  and this session's own earlier live capture of walking through it), but
  the test assertions were written for an east-facing door at `(13, 11)`
  that was never actually implemented. This was never caught before now
  because the same commit also introduced the untyped `:=` compile bug
  (fixed in this session's Phase 1 entry above) that silently hung the
  entire test suite - these specific assertions had never actually
  executed until this session. Fix: recalculated all five related
  assertions (`resolve_door`/`resolve_exit` in `_test_resolve_exits`)
  against the real, shipped, live-verified south-facing door - not a
  guess, the exact door I walked through earlier this session during the
  camera investigation.
- **The `target_assist` failure was a test-setup mistake, not an assist-
  logic bug.** `_test_character_assist_beats_a_farther_object_shape`
  placed its test NPC at exactly the player's faced tile
  (`get_faced_tile() = get_current_tile() + facing = (5,5) + (1,0) =
  (6,5)`, the same tile the NPC was placed at), then asserted the result
  was marked `"assisted": true`. But `assisted` is defined as `target !=
  get_faced_tile()` (`player.gd`'s `_resolve_normal_target`) precisely
  because `target_indicator_renderer.gd`'s own docstring describes the
  assist indicator as existing for when the resolver redirects to a
  *nearby* tile, not the one already faced - a character sitting exactly
  on the faced tile is correctly not "assisted" under that design. Fix:
  moved the test NPC to the resolver's second forward candidate (`(6,
  4)`, `forward_offsets(RIGHT, ...)[1]` per the suite's own
  `_test_forward_candidate_order`) so the test exercises a genuine
  redirect instead of a coincidental exact-tile match.
- **Full suite: 2436 checks pass, 0 failures** - `ALL SUITES PASSED`,
  likely the first fully green run since well before `b9f02c0` landed.
  Diagnosis method worth recording: reproduction required running the
  *entire* ~85-suite battery (isolating `test_zone_manager.gd` alone, or
  even `test_zones.gd` + `test_zone_manager.gd` together, did not
  reproduce the zone-key failure) - a reminder that "pre-existing, out of
  scope" failures are still worth a real diagnostic pass rather than
  permanent deferral, since three of these four fixes turned out to be
  five-minute stale-fixture corrections once actually traced.
