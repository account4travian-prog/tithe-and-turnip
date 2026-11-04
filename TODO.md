# Tithe & Turnip - Open Items & Next Work

**Compiled:** 2026-08-08 (documentation sweep across `AGENTS.md`,
`DEVELOPMENT_STATE.md`, `design/decisions.md`, `design/roadmap.md`,
`design/content_plan.md`, `design/sprints/*`, `design/world_bible.md`,
`design/setting_questionnaire.md`, proposals, tests, data, and git state).

**Verified baseline this pass:** full suite runs green - **ALL SUITES
PASSED (2117 checks)** on `feature/sprint16-art-foundation`
(WS-A/B/C/D all merged). Save version 19.

**How to use this file:** work top-down. P0 = finish what is already in
flight. P1 = design-locked work that is implementation-owed or needs an
owner ruling. P2 = verification and QA. P3 = housekeeping / stale-doc
reconciliation. Check boxes off as items land; when a design ruling is made,
record it in `design/decisions.md` (append-only) before building.

---

## 0. Project-plan inventory (where everything is written)

| Plan / document | Status |
|---|---|
| `AGENTS.md` / `CLAUDE.md` (v0.22) | Engineering contract. Regenerated via `docs/make_agents.gd` / `docs/make_deepseek.gd`; never hand-edit |
| `DEVELOPMENT_STATE.md` | The handoff + append-only session log (4,844 lines). Forward plan lives in its tail |
| `design/roadmap.md` | Sprints 6-14 index. All 9 sprints shipped; doc itself is now historical |
| `design/content_plan.md` | Content passes C1-C6. C1 (bible), C2 (dialogue engine), C5 (festivals), C6 (marriage) done; C3/C4 partial - see items 2.4-2.7 |
| `design/decisions.md` | ADR-001..041 log. All Accepted; ADR-034/ADR-041 owe "realized" follow-up entries |
| `design/sprints/sprint_06..15` | Implementation guides. Shipped; each tail has a "Status & remaining work" section |
| `design/sprints/sprint_16_art_integration.md` | **In flight** - WS-A/B/C/D merged, integration/finalization owed (section 1) |
| `design/world_bible.md` | Narrative source of truth. Appendix C = design-locked vs implementation-owed status |
| `design/setting_questionnaire.md` | Closed instrument (all 27 blocks); some status-table rows are stale (item 4.4) |
| `design/adr034_region_design.md` | Stage-1 region design; largely superseded by Sprint 15, some open questions still unclosed (item 4.5) |
| `design/IsometricConversion*.md` | ADR-032 execution docs. Work complete; status headers stale (item 4.1) |
| `design/proposals/` | Spring Feature Expansion (accepted); Compost addendum + Phase 1 schema draft (landed/superseded); produce bundling (pending owner decision, item 2.3) |
| `docs/testing/vertical_slice_test_plan.md` | Manual QA plan. Authored, **not yet run** (item 3.1) |
| `asset_studio/` (git-ignored, private) | AI art pipeline. Parked by ADR-041 narrowing; available for future polish |
| `.deepseek/tasks` + `.deepseek/outputs` | Consult archive. One task file never dispatched: `vertical_slice_test_plan_task.md` (item 3.4) |

---

## 1. P0 - Finish Sprint 16 (art asset integration, ADR-041)

- [ ] **Finalize the WS-C merge and ship to master.** The merge commit
  `501e38f` is labeled "(in progress)". Suite is green (2117 checks), but
  the guide's merge discipline says: final integration verification, then
  merge `feature/sprint16-art-foundation` -> `master` (currently 13 commits
  behind), then prune the merged `origin/art/ws-c-actors` branch.
  Source: `design/sprints/sprint_16_art_integration.md` sections 8-9.
- [ ] **Write the "ADR-041 realized" follow-up entry** in
  `design/decisions.md` (the ADR-030/036 pattern): what shipped vs the
  plan, and the owner calls made mid-sprint (shadow variants, texture
  filter defaults, `height_tiles`/anchors). This is an explicit
  Definition-of-Done item in the sprint guide.
- [ ] **Phase 2 integration test scene + live playtest.** Per the DoD:
  walk the farm, enter combat, open market/inventory/dialogue - textured
  actors/structures/dressing/UI chrome with no missing-texture placeholders
  and no `_draw()` primitive left behind for any integrated asset.
- [ ] **Eyeball the two textured buildings in-game.** `height_tiles`/anchor
  values for `cottage_upgrade` (240x319 crop, 2.5 tiles tall) and
  `drying_shed` (2.0 tiles) are data guesses flagged for an eyes-on pass.
  Source: `DEVELOPMENT_STATE.md` WS-B entry.
- [ ] **Add real NPC1 + Bandits1 `sprites.json` entries.** The code path is
  fully built and tested (`NpcVisual`/`EnemyVisual` + `test_art_actors.gd`);
  the data entries were deliberately withheld because this machine's
  checkout has no `SourceArtAssets/` tree. Requires verifying sheet
  dimensions/frame geometry against the real assets on the owner's
  machine - do not fabricate numbers.
- [ ] **Record/decide held-back packs** (all have stated reasons already;
  this is the "when, not whether" list):
  - `FarmPlantsPixelStyle` (crop-stage frames) - needs a per-crop
    frame-to-stage mapping; flagged as data-guessing risk.
  - `Animals1` + `FarmAnimalsOption1` - **no map presence exists**:
    `AnimalManager` is stat-only, and there is no wildlife/fauna spawner.
    Needs a gameplay workstream (map avatars) before texturing.
  - `Male1`/`Female1` base bodies + player gender selection - no
    gender-selection system exists; `male1_walk` is the only player body.
- [ ] **Decide the `.import`/`.uid` sidecar drift policy once.** Godot
  regenerates sidecars on every `--import`; `.gitattributes` now forces LF,
  but the merge integrator should decide how to handle drift (current
  worktree has a modified tracked `.godot/uid_cache.bin`).
- [ ] (Optional, not a blocker) Vision-catalogue the ~3,600 staged assets
  via `asset_studio/catalog.py` for future frame mapping.

## 2. P1 - Design-locked, implementation-owed & owner rulings

### 2.1 Building interiors / enterable buildings (owner-remembered, undocumented)

- [ ] **Write ADR-042: building interiors.** This feature is **not present
  in any document** - it survives only as the owner's memory ("zoning into
  a separate space for the interior"). Supporting threads that exist:
  - Interactables table includes doors (`AGENTS.md`); the player house
    already has a 1-tile doorway gap in its S wall.
  - Sprint 16 held `Building1`'s interior tiles back because "no interior
    scenes exist" - the art is available the moment interiors are real.
  - Sprint 15's `ZoneManager` (active-zone swap of grid/renderers/NPCs) is
    the natural pattern to reuse for interior spaces.
  Open design questions: which buildings are enterable (player house,
    cottage upgrade, drying shed, chapel, market, manor, mill, alehouse?);
    one interior map per building vs a shared interior zone; whether NPCs
    follow the player inside (schedules already have home anchors); save
    impact (SAVE_VERSION 19 -> 20 if interior state persists).

### 2.2 Data/contract mismatches that were flagged, not fixed

- [ ] **Festival calendar mismatch.** `data/festivals.json` ships
  `springturn_blessing` on day 18 (10:00-14:00); the world bible locks
  **Ada's Feast on day 21**, merged with the chapel mass check. The other
  three festivals' days/places should also be cross-checked against the
  bible (data currently has days 15/10/1). Owner ruling + data fix +
  test updates. Sources: `design/world_bible.md` Appendix C + Section V;
  `design/adr034_region_design.md` open question 8.
- [ ] **`accuse_correctly` village standing is still +4 in
  `data/reputation.json`; the bible locked +1.** Explicitly deferred
  ("if the +1 is wanted it is a separate data-only change with its own
  test update"). Small, self-contained. Source: `DEVELOPMENT_STATE.md`
  mercy-path entry; `design/world_bible.md` Section VII.
- [ ] **Town board postings don't yet carry Simkin's voice/handwriting
  texture** (bible Section III; Appendix C row 9 still shows it as
  implementation-owed). Panel formats template strings; no diegetic
  handwriting flavor.
- [ ] **Storage capacity is defined but unenforced.** `storage_chest`
  `capacity: 50` and `BuildingManager.get_storage_capacity_bonus()` exist
  with **no consumer** - inventory is uncapped. Decide: enforce now, wire
  it with produce bundling (2.3), or document as intentionally inert.
  (Fence `deterrence_bonus` IS consumed by `RaidManager` - that one's fine.)

### 2.3 Produce bundling - owner decision pending

- [ ] **Rule on `design/proposals/produce_bundling_proposal.md`** (no ADR
  yet, no code written). Open questions: which containers, per-crop bundle
  sizes, consumed vs returned, quality collapse, board-order interaction.
  Recommendation in the proposal: defer to a future season/storage pass.
  Note: the display-side fix ("a bushel of peas") already shipped.

### 2.4 Dialogue condition vocabulary gaps vs the C2 spec

- [ ] `ConditionEvaluator` ships: time, season, weather, is_market_day,
  is_mass_day, is_festival, has_item, skill_level, player_money/energy/
  health, standing, opinion, event_flag, not, and legacy
  `reputation.*` keys. The C2 plan also specified **`day` (min/max)** and
  **`trait`** conditions - both are missing from the evaluator (and no
  `day` in `build_context`). Adding `trait` is the gate for 2.5.
  Source: `design/content_plan.md` C2; `scripts/world/condition_evaluator.gd`.

### 2.5 C3 traits are strings, not mechanics

- [ ] Every villager carries a populated `traits` list (stern, loyal,
  gossip, early_riser, night_owl, devout, forgetful, gruff, quiet, thief,
  boastful, etc.), but **nothing consumes them** except `thief`
  (`RaidManager._find_thief_id`). The C3 deliverable - a trait registry
  with real effects (early_riser/night_owl schedule offsets, gossip clue
  behavior, gift-reaction/opinion-drift modifiers, dialogue `trait`
  conditions) - is unimplemented. Needs `traits.json` (or an effects block
  on villager entries) + tests.

### 2.6 C3/C4 content volume

- [ ] **Dialogue is still ~55 lines total (~6-7/NPC)** vs C3's target of
  25-30 lines per NPC using the new condition types. The engine can now
  express time/weather/market/event/opinion-gated lines - the writing
  hasn't followed.
- [ ] **C4 reactive event text** (raid/court/corvee/black-market/theft
  surface as fixed HUD strings; no varied lines or next-day villager
  commentary) and **seasonal beats as dialogue** are largely unwritten.
- [ ] Requests/forage/recipes have grown (11 recipes; 5 spouse-only
  request templates) but remain below C4's breadth target; request text
  should read as a person asking a favour.

### 2.7 Deliberately open by design (do not close without a ruling)

- [ ] **Raid leader identity** stays unnamed past this slice. Threads
  already planted for whoever picks it up (Bram's inflated testimony,
  Cedric's night watch, "what the player might become").
  Source: `design/world_bible.md` Section VII; `design/open_items_treatment.md` item 16.
- [ ] (Optional, bible-marked "beyond locked scope") Second, "markedly
  successful season" success line for Hilda - needs an owner call to
  include.

## 3. P2 - Verification & manual QA (human, in the editor)

- [ ] **Run `docs/testing/vertical_slice_test_plan.md` end-to-end**
  (~90-120 min, cheat-panel-assisted; mark PASS/FAIL/SKIP per item). It
  covers the whole shipped slice including the nine-zone tour and the
  7-item regression sweep (~15 min, should run after every change).
  No run record exists yet.
- [ ] **Sprint 7 visual/layout pass** - mockup fidelity, resize legibility,
  panel readability on the parchment palette. Never formally eyeballed.
- [ ] **Sprint 9 editor checklist** - till-gate, rent, placement, fence,
  well_extra refill, cottage sleep bonus, save/reload persistence, window
  resize. Later live-play sessions covered much of this informally; the
  formal walkthrough is still open.
- [ ] (Optional) Dispatch the persisted DeepSeek Pro consult for the test
  plan (`.deepseek/tasks/vertical_slice_test_plan_task.md`) - the earlier
  dispatch never reached the API. Needs the owner's go-ahead.

## 4. P3 - Housekeeping: stale, abandoned, and forgotten portions

- [ ] **Superseded status headers.** These docs still read as "current"
  but their work shipped: `design/IsometricConversion.md` ("ready to
  execute" - ADR-032 is fully merged), `design/IsometricConversion_
  Worktrees.md` (worktrees cleaned; section-6 cleanup done),
  `design/proposals/Compost_Spec_Addendum.md` and `design/proposals/
  Phase1_Schema_Draft.md` (both "Draft for owner review" - their content
  landed via Phase 1/ADR-040), `design/world_biblePROPOSAL.md`
  (superseded by `design/world_bible.md`), `design/roadmap.md` and
  `design/content_plan.md` (complete), `docs/bootstrap_project.gd`
  (one-time bootstrap, by design). Add "SUPERSEDED / COMPLETE" notes so a
  future pass doesn't re-read them as live plans.
- [ ] **`design/setting_questionnaire.md` stale rows.** The open-collisions
  table's X13 row still says the weekly strip-rent question was "not
  resolved this pass" - it was retired the same day (`DEVELOPMENT_STATE.md`
  "Weekly tenure rent retired"). Appendix C row 7 ("festival system itself
  not built") is also stale - festivals shipped.
- [ ] **Close out `design/adr034_region_design.md` Stage-1 open questions.**
  Most were resolved by Sprint 15's implementation (zone names, starter
  well, forage density on tenant plots). Still live: Wat's staging point
  (black-market is UI-only today; region design suggested a roadside verge
  staging), festival day mismatch, and the brook course's canon status.
- [ ] **`world_bible.md` Appendix C row 8/15 status text** says the contest
  engine and mercy path were "queued, not yet merged" - both shipped;
  update the rows.
- [ ] **Git cleanup:** prune `origin/art/ws-c-actors` once Sprint 16 lands
  (already merged into the feature branch); decide what to do with the
  tracked-but-churning `.godot/uid_cache.bin`.
- [ ] **`asset_studio/`** stays parked per ADR-041 (LoRA unification is
  explicitly NOT a dependency of this pass) - leave untouched; note in its
  README that ADR-041 narrowed its Phase 3.

## 5. Out of scope - do not build without explicit approval

Summer/Autumn/Winter unlock (data-only by design once content exists),
children/in-laws/divorce/rival suitors, disease/aging/deeper manor
politics, audio, particles, shaders, elevation (ADR-032 boundary),
Android/web export config, TileMapLayer terrain, and terrain/soil
retexturing (explicitly outside ADR-041; would need its own ADR).
