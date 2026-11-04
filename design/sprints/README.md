# Sprint implementation guides

One file per sprint (`sprint_06_*.md` .. `sprint_14_*.md`), each a
complete, standalone spec an agent can implement from without re-deriving
design decisions or re-reading the whole codebase. `design/roadmap.md` is
the index and stays the source of truth for scope, sizing, and sequencing;
these files are the "how," not the "why" - read the roadmap entry and the
linked ADR in `design/decisions.md` first, then this file for the mechanics.

**Authority reminder:** every sprint marked AMENDMENT in the roadmap needs
its ADR moved from Proposed to Accepted (and CLAUDE.md section 2 edited)
before work opens. Implementing against a Proposed ADR is implementing
out-of-scope content - stop and confirm the amendment landed first.

## Shared conventions

These are established by Sprints 1-5 and apply to every guide below without
restating. Deviating from them is a defect, not a style choice.

### Data files (`data/*.json`, loaded by `GameData`)

- Every file carries `"version": N`. Bump on shape changes.
- `GameData._read_json(file)` reads it; JSON numbers arrive as floats.
  Any field that is semantically an integer (counts, days, prices, costs)
  must be listed in an `*_INT_KEYS: Array[String]` constant near the top of
  `game_data.gd` and cast via `_cast_ints()` / `_cast_nested_ints()` - see
  `game_data.gd:9-31` and `:294-338` for the existing pattern. A new data
  file needs its own `_load_id_file(name, list_key, int_keys)` (for an
  array of `{id: ...}` objects, see `crops`/`items`/`chores`) or
  `_load_flat_file(name, int_keys)` (for a single top-level object, see
  `tithe_cfg`/`player_cfg`) call added to `load_all()`.
- Every lookup is a typed accessor on `GameData` (`get_crop`, `get_item`,
  `is_market_day`, ...). Nothing outside `GameData` reads `data/*.json`
  directly (CLAUDE.md rule 10 / section 6).
- Keys are snake_case; never key a lookup on a display `name`.

### Autoloads (`scripts/autoloads/*.gd`)

- `extends Node`, **no `class_name`** matching the autoload's singleton
  name (Godot 4.7 rejects it as hiding the singleton - CLAUDE.md rule 3.2).
- Cross-autoload access is always `get_node_or_null("/root/X")`, never the
  bare singleton name, inside a script that might also compile under the
  headless test harness (`--script`).
- Every manager that touches `PlayerState`/`GameData` exposes a
  `configure_for_test(...)` method that swaps in injected instances and
  sets a `_test_mode` flag, so suites can construct it with `Autoload.new()`
  off the scene tree. See `tithe_manager.gd:31-35` or
  `reputation_manager.gd:128-136` for the pattern.
- Persistence is `to_dict()`/`from_dict()` (world/state nodes:
  `FarmGrid`, `TimeManager`, `WeatherManager`) or `serialize()`/
  `deserialize()` (economy nodes: `TitheManager`). New managers with save
  state pick whichever name matches their category and wire it into
  `SaveManager.build_payload()` / `apply_payload()`.
- Signals are the only cross-system notification path; nothing polls
  another autoload's private state from `_process`.

### `FarmGrid` and `ToolManager` are not autoloads - do not `/root/`-look them up

**Confirmed defect, found while writing these guides (2026-08-05):**
`save_manager.gd:40` and `:59-61` resolve the farm grid via
`get_node_or_null("/root/FarmGrid")`. `docs/bootstrap_project.gd:129,133`
names `main.tscn`'s root node `"Main"` and adds `FarmGrid` as *that* node's
child - so the live path is `/root/Main/FarmGrid`, never `/root/FarmGrid`.
`get_node_or_null` on a path that doesn't resolve returns `null` silently
(no error, no warning), so `build_payload()`'s `if farm != null:
payload["farm"] = farm.to_dict()` (`save_manager.gd:40-42`) is almost
certainly never true in a real running game - **farm tile state (tilled/
planted/moisture/growth) is likely never written to any save file**, and
`apply_payload()`'s matching lookup (`save_manager.gd:59-61`) means it's
never restored either. `test_save_roundtrip.gd` doesn't catch this because
it exercises `FarmGrid.to_dict()`/`from_dict()` directly on a manually
constructed instance, off the scene tree, never through the live-path
lookup that's actually broken.

**Fix this in Sprint 6** (it already touches `save_manager.gd` for the
`SAVE_VERSION` bump) - see that guide's section 9. **The general rule for
every sprint after Sprint 6:** `FarmGrid` and `ToolManager` are children of
the main scene (`Player.set_farm_grid`, `main.gd:32`), not autoloads. Any
autoload that needs a live reference to either **must receive it by
explicit injection** - a `set_x_ref(node)` call from `main.gd._ready()`,
mirroring the existing `player.set_farm_grid(farm_grid)` pattern - never
`get_node_or_null("/root/FarmGrid")` or `"/root/ToolManager"`. A test suite
constructing a manager off-tree already does the equivalent through
`configure_for_test(..., farm_grid)`; that convention is correct and
should keep being used - only the live-game `/root/` lookup is the bug.

### Save versioning (`scripts/autoloads/save_manager.gd`)

- Bump `SAVE_VERSION`. Add `migrate_to_v{N}(payload) -> Dictionary` that
  sets `payload["version"] = N` and fills in defaults for every new field,
  then chain it into `read_payload()`'s `if version <= {N-1}:` ladder
  (`save_manager.gd:97-105`). Never skip a rung - a v2 save must still load
  after five version bumps.
- `build_payload()` / `apply_payload()` each get one new block reading the
  new autoload's `serialize()`/`to_dict()` (mirror the existing five).

### Runtime scenes (no editor access assumed unless marked DESKTOP)

- New world objects are plain scripts instantiated in code and
  `add_child()`-ed at runtime (see `main.gd:417-427` spawning `NPC`, or
  `combat_manager.gd:90-107` building a melee hitbox `Area2D` from scratch).
  This is how Sprints 2-5 shipped without any `.tscn` authoring.
- New input actions register themselves in `InputManager._ready()` via
  `InputMap.add_action` / `action_add_event` (`input_manager.gd:29-59`) -
  never edit `project.godot` by hand or via script for this.
- Geometric primitives only (`_draw()` with `draw_rect`/`draw_circle`) -
  CLAUDE.md section 2 out-of-scope list bars sprite/art assets.

### Tests (`tests/suites/*.gd`, run by `tests/run_tests.gd`)

- One `RefCounted` script per suite: `func suite_name() -> String` and
  `func run(t: Object) -> void`, calling `t.ok(cond, msg)`, `t.eq(actual,
  expected, msg)`, `t.not_ok(cond, msg)`, `t.fail(msg)`,
  `t.section_done(name)` (organizational, no-op), `t.completed(n)` (no-op).
  See `tests/suites/test_market.gd` for the full shape, including the
  "mutable day holder" trick (`Array` boxing an `int` so a lambda can see
  later mutations - GDScript lambdas capture locals by value).
- Register the new suite in `tests/run_tests.gd`'s `SUITES` array
  (`preload("res://tests/suites/test_X.gd")`), in the order it should run.
- A suite that needs `GameData` constructs a real one (`GAME_DATA_SCRIPT.
  new(); gd.load_all()`) rather than mocking JSON - the data files ARE the
  fixture.

## Index

| Sprint | Guide | Roadmap entry |
|---|---|---|
| 6 | [sprint_06_core_loop.md](sprint_06_core_loop.md) | Core loop closure & balance |
| 7 | [sprint_07_ui_layer.md](sprint_07_ui_layer.md) | UI & interaction layer |
| 8 | [sprint_08_skills_foraging.md](sprint_08_skills_foraging.md) | Skills, foraging & the commons |
| 9 | [sprint_09_buildings_tenure.md](sprint_09_buildings_tenure.md) | Buildings, storage & land tenure |
| 10 | [sprint_10_village_life.md](sprint_10_village_life.md) | Village life: schedules, gifting, requests |
| 11 | [sprint_11_manor_politics.md](sprint_11_manor_politics.md) | Manor politics & the grey economy |
| 12 | [sprint_12_combat_investigation.md](sprint_12_combat_investigation.md) | Dynamic combat & the thief investigation |
| 13 | [sprint_13_crafting_cooking.md](sprint_13_crafting_cooking.md) | Crafting, cooking & preservation |
| 14 | [sprint_14_livestock.md](sprint_14_livestock.md) | Livestock |
| 15 | [sprint_15_regions.md](sprint_15_regions.md) | Regions & zone-keyed world state (ADR-034) |

## Verification baseline

As of Sprint 5 complete (2026-08-05): headless import clean, 244/244 test
checks pass, boot smoke exit 0, `SAVE_VERSION = 5`. Every sprint's gates
section states the expected new total - if the actual count after
implementation doesn't match, a suite failed to register or a test was
silently dropped; treat that as a blocking defect before moving on.
