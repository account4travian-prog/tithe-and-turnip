# Sprint 7 - UI & interaction layer

**Size:** M. **Markers:** AMENDMENT (save slots only - ADR-020).
**ADRs:** ADR-020 (Proposed - accept before building the save-slot panel;
everything else in this sprint needs no amendment).
**Prerequisite:** Sprint 6 complete.
**Baseline before this sprint:** whatever Sprint 6 leaves the suite at (see
`sprint_06_core_loop.md`'s expected count).
**Expected after this sprint:** +12-18 checks across the new suites listed
below.

See [README.md](README.md) for shared conventions.

## Correction to the roadmap's DESKTOP marker

`design/roadmap.md` marks this sprint DESKTOP. On closer inspection, **it
is not** - every panel below is buildable at runtime with `CanvasLayer.new()`
+ code-built `Control` children, exactly like `main.gd`'s existing
`_make_hud_label` (`main.gd:396-400`), `NPC` spawning (`main.gd:417-427`),
and `CombatManager`'s runtime-built hitboxes/projectiles
(`combat_manager.gd:90-107, 122-144`) already do. There is no `.tscn`
authoring requirement and no autoload registration in this sprint (it
extends the existing `UIManager` autoload rather than adding a new one).
**Treat this sprint as agent-assignable, no editor access needed.** Flag
the correction in `design/roadmap.md` and `DEVELOPMENT_STATE.md`'s summary
table when this sprint starts (both currently say DESKTOP).

## Objective

Replace `main.gd`'s procedural HUD labels and number-key menu dispatch
(`Menu` enum, `_menu_select`/`_market_select`/`_tithe_select`/
`_chore_select`/`_church_select`, `main.gd:8-319`) with a structured panel
system driven by an expanded `UIManager`. Every panel is a runtime-built
`CanvasLayer`. This sprint also adds tile tooltips (moisture/growth/soil
are currently invisible to the player) and, under the ADR-020 amendment,
named save slots.

## `UIManager` v2 (extends the existing stub, `ui_manager.gd`)

The current API (`menu_open: bool`, `open_menu`/`close_menu`,
`menu_opened`/`menu_closed` signals) is consumed today by `player.gd:66-95`
(`if ui != null and bool(ui.get("menu_open")): return` - suppresses tool
use and equip shortcuts while a menu is open). **Keep `menu_open` as a
public bool with that exact semantic** - it is the one piece of the old API
other scripts already depend on. Add a stack underneath it:

```gdscript
extends Node

signal menu_opened(menu_id: String)
signal menu_closed(menu_id: String)
signal all_menus_closed

var menu_open := false
var _stack: Array[String] = []


func open_menu(menu_id: String) -> void:
	if not _stack.has(menu_id):
		_stack.append(menu_id)
	menu_open = true
	menu_opened.emit(menu_id)


func close_menu(menu_id: String) -> void:
	_stack.erase(menu_id)
	menu_open = not _stack.is_empty()
	menu_closed.emit(menu_id)
	if _stack.is_empty():
		all_menus_closed.emit()


func close_top() -> void:
	if _stack.is_empty():
		return
	close_menu(_stack[-1])


func is_open(menu_id: String) -> bool:
	return _stack.has(menu_id)


func current_menu() -> String:
	return _stack[-1] if not _stack.is_empty() else ""


func close_all() -> void:
	var ids := _stack.duplicate()
	for id: String in ids:
		close_menu(id)
```

Menu ids become plain strings: `"inventory"`, `"shop"`, `"tithe"`,
`"church"`, `"dialogue"`, `"pause"`, `"settings"`, `"season_summary"`,
`"save_slots"` - not the stringified `Menu` enum ints `main.gd` uses today.

## Panel base pattern

Every panel is `class_name XPanel extends CanvasLayer`, built like this in
`_ready()`:

1. `process_mode = Node.PROCESS_MODE_ALWAYS` (so it stays interactive under
   `get_tree().paused = true` - required for the pause menu and any panel
   that must be usable while paused).
2. `layer` staggered so stacking order is predictable: HUD panel `layer =
   1`, gameplay panels (inventory/shop/tithe/church/dialogue/settings/
   save_slots) `layer = 10`, pause and season-summary `layer = 20` (always
   on top).
3. A full-rect `ColorRect` backdrop (`Color(0, 0, 0, 0.55)`) sized to
   `get_viewport_rect().size`, added as the first child, for every panel
   except the HUD (which has no backdrop - it overlays gameplay).
4. A `VBoxContainer` or `GridContainer` content mount added after the
   backdrop; rows/buttons are built into this mount at `refresh()` time,
   not at `_ready()` time, so the panel reflects current game state every
   time it opens.
5. `visible = false` by default; `main.gd` sets `visible = true` /
   `false` in response to `UIManager.menu_opened`/`menu_closed` for that
   panel's id (or the panel connects to those signals itself and filters
   by its own id - either is acceptable, pick one convention and use it
   for all seven panels, don't mix).

`main.gd._ready()` instantiates all panels once (`HudPanel.new()`,
`InventoryPanel.new()`, ... `add_child(panel)` for each) and keeps a
`Dictionary` `_panels: Dictionary = {"inventory": inv_panel, ...}` for
lookup, replacing the `_equip_label`/`_water_label`/... field list at
`main.gd:17-25` and the `_setup_hud_labels`/`_make_hud_label` methods at
`main.gd:383-400` entirely (CLAUDE.md rule 9: full-file replacement, not a
partial diff - rewrite `main.gd` clean rather than layering panels on top
of the old label code).

## Per-panel spec

| Panel | Script | Opened by | Closed by |
|---|---|---|---|
| HUD | `scripts/ui/hud_panel.gd` | always visible | never |
| Inventory | `scripts/ui/inventory_panel.gd` | `open_inventory` action | `ui_cancel` / re-press |
| Shop | `scripts/ui/shop_panel.gd` | `market_zone` interact (market open) | `ui_cancel` |
| Tithe | `scripts/ui/tithe_panel.gd` | `stewards_demesne` interact | `ui_cancel` |
| Church | `scripts/ui/church_panel.gd` | `chapel` interact | `ui_cancel` |
| Dialogue | `scripts/ui/dialogue_panel.gd` | NPC interact | response selected / `ui_cancel` |
| Pause | `scripts/ui/pause_menu.gd` | `ui_cancel` with no other menu open | Resume button |
| Settings | `scripts/ui/settings_menu.gd` | Pause menu "Settings" button | `ui_cancel` |
| Season summary | `scripts/ui/season_summary_panel.gd` | `TimeManager.season_changed` (non-spring) | Restart/Quit buttons only |
| Save slots | `scripts/ui/save_slot_panel.gd` | Pause menu "Save As..." / title screen "Load" | `ui_cancel` |

### HudPanel

Migrates `main.gd`'s existing HUD logic verbatim: time/day/season
(`_refresh_time`), energy (`_on_energy_changed`), money
(`_on_money_changed`), equipped tool + water level (`_on_equipped_changed`,
`_on_water_changed`), tithe progress (`_on_tithe_updated`), market status
(`_on_market_status_changed`), standing (`_on_standing_changed`). `main.gd`
keeps the signal connections but forwards to `hud_panel.refresh_x(...)`
methods instead of setting `Label.text` on its own fields.

New in this sprint:

- Weather: connect `WeatherManager.weather_changed`, show
  `WeatherManager.get_today_weather()` (now including `"overcast"` from
  Sprint 6).
- **Tile tooltip.** Add `func get_faced_tile() -> Vector2i` to `Player`
  (`player.gd`) - factor the existing calculation out of `_use_tool`
  (`player.gd:71-73`) into this public method so both `_use_tool` and the
  HUD can call it without duplicating the math:

  ```gdscript
  func get_faced_tile() -> Vector2i:
  	var player_tile := Vector2i(
  		floori(global_position.x / CELL_SIZE), floori(global_position.y / CELL_SIZE))
  	return player_tile + _facing
  ```

  `HudPanel` needs live `Player` and `FarmGrid` references to do this -
  `main.gd` must inject them explicitly (`hud_panel.configure(player,
  farm_grid)`, called once in `_ready()` alongside the `SaveManager.
  set_farm_grid_ref`/`TitheManager.set_farm_grid_ref` calls Sprint 6 added).
  Per [README.md](README.md)'s "FarmGrid and ToolManager are not
  autoloads" section, `HudPanel` must **not** attempt
  `get_node_or_null("/root/FarmGrid")` - that path does not resolve in the
  live tree.

  `HudPanel` polls `get_faced_tile()` once per `_process` (cheap - it's
  arithmetic, not a query), and if `GameData.is_within_farm(tile.x, tile.y)`
  is true, shows
  soil (`FarmGrid.get_soil`), moisture (`FarmGrid.get_cell_moisture`),
  growth percent (`FarmGrid.get_cell(tile).growth_progress * 100`, one
  decimal), and - once Sprint 6's spoilage lands - "SPOILING" when
  `days_mature > crop.spoil_after_days` or "ROTTEN" is impossible to show
  (a rotten tile has already cleared `crop_id`, so there's nothing left to
  tag; showing SPOILING only is correct and sufficient).

### InventoryPanel

New input action: `InputManager._register_key_action("open_inventory",
KEY_I)` (`input_manager.gd:29-51` gains one more line - `I` is unused by
every existing action).

`refresh()` calls `PlayerState.list_inventory()` and, for each stack,
builds one row: a `ColorRect` swatch (color from a simple per-`type` map -
food green, seed yellow, tool grey, weapon red, ammo brown - geometric
placeholder, no art), a `Label` reading `"<name> (<quality>) x<count>"`
(`GameData.get_item(item_id).name`), and one `Button` whose label and
callback depend on `GameData.get_item(item_id).type`:

| Item type | Button label | Callback |
|---|---|---|
| `tool` | "Equip" | `PlayerState.set_equipped_tool(item_id)` |
| `seed` | "Equip" | `PlayerState.set_equipped_tool(item_id)` |
| `weapon` | "Equip" | `PlayerState.set_equipped_weapon(item_id)` |
| `food` | "Eat" | `PlayerState.eat(item_id)` |
| everything else (`ammo`) | *(no button)* | - |

Reconnect to `PlayerState.inventory_changed` to call `refresh()` whenever
inventory changes while the panel is open (equip/eat immediately update
the visible list).

There is no ground-item pickup system yet - do **not** add a "Drop" button
this sprint; that requires a world item entity that does not exist until a
later sprint adds one. Note this omission in the divergences section
rather than inventing a fake drop.

### ShopPanel / TithePanel / ChurchPanel

Direct replacements for `main.gd`'s `_market_select`/`_tithe_select`/
`_chore_select`/`_church_select` (`main.gd:198-267`), rebuilt as button
lists instead of number-key text. Two `TitheManager` methods are needed
that don't exist yet - **public wrappers around Sprint 6's private price
helpers**, so the shop can show a price before the player commits:

```gdscript
# tithe_manager.gd - add alongside the existing public methods
func get_buy_price(item_id: String, quantity: int = 1) -> int:
	return _compute_buy_total(item_id, quantity)


func get_sell_price(item_id: String, quantity: int, quality: String) -> int:
	return _compute_sell_net(item_id, quantity, quality)
```

ShopPanel buy column: one row per `GameData.get_stall_inventory()` entry,
showing `GameData.get_item(id).name` and `TitheManager.get_buy_price(id,
1)`, a `Button` "Buy" calling `TitheManager.buy_item(id, 1)`. Sell column:
one row per `PlayerState.list_inventory()` stack where
`GameData.get_market_buy_price(item_id) >= 0`, showing
`TitheManager.get_sell_price(item_id, count, quality)` and a "Sell All"
button calling `TitheManager.sell_crop(item_id, count, quality)`.

TithePanel: pay-coin row (amount stepper or three fixed buttons - 5/10/25
coin - your choice, not load-bearing), "Deposit Crops" rows mirroring the
shop's sell rows but calling `TitheManager.deposit_tithe_crops`, and a
"Work Chores" button opening a chores sub-list built from
`TitheManager.get_available_chores()` + `GameData.get_chore(id)`, each
calling `TitheManager.do_chore(id)`.

ChurchPanel: same shape as TithePanel's coin/crop rows, calling
`TitheManager.donate_coin`/`donate_crops`.

### DialoguePanel

Replaces the single HUD message in `main.gd._on_npc_interacted`
(`main.gd:113-124`). Public API, designed so Sprint 12's accusation flow
can hand it real branching without a panel rewrite:

```gdscript
func show_dialogue(npc_name: String, line: String, responses: Array[Dictionary] = []) -> void
```

Each entry in `responses` is `{"text": String, "callback": Callable}`. If
`responses` is empty, the panel auto-adds a single `{"text": "Leave",
"callback": Callable(UIManager, "close_menu").bind("dialogue")}` row. This
sprint's only caller passes no responses:

```gdscript
func _on_npc_interacted(npc_id: String) -> void:
	var standings := {...}  # unchanged
	var lines := GameData.get_dialogue_for(npc_id, standings)
	var npc_name := str(GameData.get_villager(npc_id).get("name", npc_id))
	if lines.is_empty():
		dialogue_panel.show_dialogue(npc_name, "%s looks at you silently." % npc_name)
	else:
		dialogue_panel.show_dialogue(npc_name, lines[0])
	UIManager.open_menu("dialogue")
```

### PauseMenu

Opens on `ui_cancel` **only when `UIManager.current_menu()` is empty** -
`ui_cancel` (built-in Escape) already closes the top menu via
`main.gd`'s existing pattern; wire pause as the fallback when there's
nothing to close:

```gdscript
# main.gd _process or a dedicated _handle_global_input
if InputManager.is_action_just_pressed("ui_cancel"):
	if UIManager.current_menu().is_empty():
		UIManager.open_menu("pause")
		get_tree().paused = true
	else:
		UIManager.close_top()
```

Buttons: Resume (`get_tree().paused = false; UIManager.close_menu("pause")`),
Settings (`UIManager.open_menu("settings")` - stacks on top, pause stays
open underneath), Save (`SaveManager.save_game("autosave")`, show a brief
confirmation), Save As... (`UIManager.open_menu("save_slots")`), Quit
(`get_tree().quit()`).

**Regression check (known trap 7):** confirm every gameplay node
(`Player`, `FarmGrid`, `NPC`, `CombatManager`, `RaidManager`) is at the
default `process_mode` (`PROCESS_MODE_INHERIT`) so `get_tree().paused =
true` actually freezes them, and confirm only the UI `CanvasLayer`s
override to `PROCESS_MODE_ALWAYS`. `CombatManager` and `RaidManager` are
autoloads at the tree root - autoloads default to
`PROCESS_MODE_PAUSABLE`-equivalent (inherit from a non-paused root, i.e.
they currently keep running under `get_tree().paused = true` unless
`SceneTree.paused` propagation is confirmed). **Verify this explicitly in
Godot** (autoload pause behavior is one of the "flag, don't guess" items
per CLAUDE.md's API confidence rule) - if `CombatManager`/`RaidManager`
keep processing while paused, add an explicit `if get_tree().paused:
return` guard at the top of their `_physics_process`.

### SettingsMenu

Window mode toggle: `get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN`
/ `Window.MODE_WINDOWED` (runtime `Window` API - does not touch
`project.godot`). Key rebinding: a fixed list `const REBINDABLE_ACTIONS :=
["move_up", "move_down", "move_left", "move_right", "interact", "attack"]`,
one row per action with a "Rebind" button that enters a one-shot
"listening" state (`set_process_input(true)`, capture the next
`InputEventKey`, then `InputMap.action_erase_events(action);
InputMap.action_add_event(action, new_event)` - the same runtime `InputMap`
API `InputManager._register_key_action` already uses). Text size: a float
multiplier (0.8/1.0/1.2/1.4) applied to a shared `Theme` resource's default
font size, created once and assigned to the main scene root's `theme`
property so every panel inherits it.

**Settings are local preferences, not game state** - persist them to a
dedicated `user://settings.json`, written directly by `SettingsMenu`, and
kept **entirely separate from `SaveManager`/`SAVE_VERSION`**:

```gdscript
const SETTINGS_PATH := "user://settings.json"

static func save_settings(data: Dictionary, path := SETTINGS_PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


static func load_settings(path := SETTINGS_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}
```

Static functions with an explicit `path` parameter so the test suite can
round-trip through a scratch path without touching the real
`user://settings.json`.

### SeasonSummaryPanel

Replaces `main.gd`'s `_season_over` flag and the `menu_9`/`menu_0` key
handling (`main.gd:80-85, 152-158`). `TimeManager.season_changed`
connects to a handler that, when `season != "spring"`, calls
`UIManager.open_menu("season_summary")` and `get_tree().paused = true`.
The panel shows the same stats `main.gd` already gathers (tithe
paid/goal, `PlayerState.total_crops_harvested`,
`PlayerState.total_coins_earned`) and two buttons: Restart
(`get_tree().paused = false; get_tree().reload_current_scene()`), Quit
(`get_tree().quit()`).

### SaveSlotPanel (ADR-020 - confirm Accepted before building)

Three fixed slots `"slot1"`, `"slot2"`, `"slot3"` (in addition to the
existing `"autosave"`, which stays out-of-band and is not shown here). One
row per slot: read `user://save_<slot>.json` via
`SaveManager.read_payload(path)` if it exists and show `"Day %d, %s, Year
%d" % [time.day, time.season, time.year]` from its `"time"` block, or
`"Empty"` if the file doesn't exist. Buttons "Save" (`SaveManager.
save_game(slot)`) and "Load" (`SaveManager.load_game(slot)`, only enabled
when the slot is non-empty).

## Save schema

No change to `SAVE_VERSION` or the versioned payload shape. `user://
settings.json` is intentionally outside that system (see SettingsMenu
above) - do not add a migration for it and do not fold it into
`SaveManager.build_payload()`.

## Tests

### New: `tests/suites/test_ui_manager.gd`

Construct `UI_MANAGER_SCRIPT.new()` off-tree. Assert:

1. `open_menu("a")` then `is_open("a")` true, `menu_open` true,
   `current_menu() == "a"`.
2. `open_menu("b")` (stacked on `"a"`) - `current_menu() == "b"`.
3. `close_top()` closes `"b"`, leaves `"a"` open, `menu_open` still true.
4. `close_top()` again closes `"a"`, `menu_open` false, and
   `all_menus_closed` fired exactly once across the whole sequence (bind a
   counter).
5. `close_menu("x")` on an id that was never opened is a no-op, no error,
   `menu_open` unchanged.
6. `close_all()` from a 3-deep stack empties it and fires
   `all_menus_closed` once.

Target: 8+ checks.

### Extend `tests/suites/test_market.gd`

Add two assertions confirming the new public wrappers match the private
helpers they wrap (construct as `_make(t)` already does, call both
`tm.get_buy_price("spear", 1)` and compare against the buy total the
existing `_test_buy` case already asserts; same for `get_sell_price`
against `_test_sell_math`'s known values). This is a thin regression check
- the wrappers are one-line delegations, but a UI bug that reads the wrong
method should still fail a test, not just look wrong on screen.

### New: `tests/suites/test_settings_persist.gd`

Call `SettingsMenu.save_settings({"window_mode": "windowed", "text_scale":
1.2}, "user://test_settings_scratch.json")`, then
`SettingsMenu.load_settings("user://test_settings_scratch.json")` and
assert the round-tripped dictionary matches. Clean up the scratch file at
the end of the suite (`DirAccess.remove_absolute` or
`FileAccess`-open-and-truncate is not needed - just leave a note that the
scratch file is harmless test litter in `user://` if cleanup is skipped,
but prefer cleaning it up).

### `tests/run_tests.gd`

Register `test_ui_manager.gd` and `test_settings_persist.gd`.

## Manual test checklist

1. Open the project in Godot 4.7.1 and press F5 - the game runs with no
   errors in Output.
2. Press `I` - inventory panel opens showing starter items with working
   Equip/Eat buttons; press `I` or Esc to close.
3. Interact with the market stall - shop panel opens with live,
   toll-and-standing-adjusted prices; buying updates money and inventory
   immediately.
4. Interact with the steward's demesne and the chapel - tithe and church
   panels open with working pay/deposit/donate/chore rows.
5. Interact with an NPC - dialogue panel shows the matched line and a
   "Leave" button that closes it.
6. Press Esc with no menu open - pause menu opens, world visibly freezes
   (player stops moving, NPCs stop wandering, an active raid enemy stops
   moving if one is on screen).
7. From pause, open Settings, toggle fullscreen/windowed, rebind `attack`
   to a different key, confirm the rebind works in gameplay after closing.
8. From pause, Save As... into slot 1, confirm the slot panel now shows
   the correct day/season/year instead of "Empty"; reload it and confirm
   state matches.
9. Stand on a farm tile and check the HUD tooltip - soil type, moisture,
   and growth percent update as you move and as days pass; a spoiling crop
   shows "SPOILING".
10. Let the season end - season summary panel opens paused with correct
    stats; Restart reloads cleanly, Quit exits.
11. Resize the window to a wide and a tall aspect - every open panel's
    backdrop and content still cover the viewport without distortion or
    gaps.

## Divergences to record

- Corrected the roadmap's DESKTOP marker for this sprint to "none required"
  - see the note at the top of this file. Update `design/roadmap.md`'s
  table and `DEVELOPMENT_STATE.md`'s summary table to match when this
  sprint starts.
- No "Drop" button in the inventory panel this sprint - there is no ground-
  item entity yet for a dropped stack to become. Add it when a sprint
  introduces world item pickups (not currently scheduled in Sprints 6-14).
- `user://settings.json` is deliberately outside `SaveManager`/
  `SAVE_VERSION` - it is local display preference, not game state.
- Record whatever the manual verification of autoload pause behavior
  (`CombatManager`/`RaidManager` under `get_tree().paused`) actually finds
  - this is an unverified 4.7 behavior per CLAUDE.md's API confidence rule
  and must be confirmed, not assumed, before calling the pause-freeze gate
  passed.
