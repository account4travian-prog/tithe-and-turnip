# Sprint 10 - Village life: schedules, gifting & requests

**Size:** M. **Markers:** none - no editor access needed. This sprint
deliberately adds **no new autoload**; gifting and requests fold into the
existing `ReputationManager`, both because they fundamentally produce
opinion deltas and to avoid a DESKTOP step that isn't otherwise justified.
**ADR:** ADR-024 - Proposed, needs acceptance (amends the out-of-scope
list only insofar as "gifting"/"requests" aren't named there today; the
ADR text is explicit that marriage and festivals stay out).
**Prerequisite:** Sprint 7 complete (this sprint hands `DialoguePanel`
real response options for the first time - it was built in Sprint 7
specifically to take them without a rewrite).

## Objective

Villagers follow a home/work daily schedule instead of wandering forever
around their spawn point (this also produces the deterministic alibi data
Sprint 12's thief investigation will read). The player can gift liked/
disliked items to move individual opinion, and accept small fulfillment
requests from NPCs for coin and opinion. A fixed mass day gives the church
axis a second lever beyond donations.

## `data/villagers.json` v3 -> v4

Add `schedule`, `likes`, `dislikes` to every entry. `traits` stays as-is
this sprint (Sprint 12 owns populating every villager's trait list, per
ADR-026 - don't touch it here, that's a separate concern with its own
review).

```json
{
	"version": 4,
	"villagers": [
		{ "id": "steward", "name": "Steward Aldric", "role": "steward", "faction": "manor", "traits": [], "spawn": { "x": 25, "y": 15 }, "color": "#8a5a2b",
			"schedule": { "home": { "x": 25, "y": 16 }, "work": { "x": 25, "y": 15 }, "work_start_hour": 7, "work_end_hour": 20 },
			"likes": ["barley", "turnip"], "dislikes": ["wild_herb"] },
		{ "id": "priest", "name": "Father Tomas", "role": "priest", "faction": "church", "traits": [], "spawn": { "x": 10, "y": 15 }, "color": "#6a6a8a",
			"schedule": { "home": { "x": 10, "y": 16 }, "work": { "x": 10, "y": 15 }, "work_start_hour": 6, "work_end_hour": 21 },
			"likes": ["turnip", "wild_berry"], "dislikes": ["arrow"] },
		{ "id": "villager_1", "name": "Hilda", "role": "villager", "faction": "village", "traits": [], "spawn": { "x": 3, "y": 12 }, "color": "#9a6a3a",
			"schedule": { "home": { "x": 3, "y": 12 }, "work": { "x": 5, "y": 12 }, "work_start_hour": 8, "work_end_hour": 18 },
			"likes": ["wild_berry", "barley"], "dislikes": ["flint"] },
		{ "id": "villager_2", "name": "Cedric", "role": "villager", "faction": "village", "traits": [], "spawn": { "x": 8, "y": 18 }, "color": "#4a7a4a",
			"schedule": { "home": { "x": 8, "y": 18 }, "work": { "x": 8, "y": 16 }, "work_start_hour": 8, "work_end_hour": 18 },
			"likes": ["arrow", "flint"], "dislikes": ["wild_onion"] },
		{ "id": "villager_3", "name": "Marta", "role": "villager", "faction": "village", "traits": ["thief"], "spawn": { "x": 20, "y": 18 }, "color": "#7a4a5a",
			"schedule": { "home": { "x": 20, "y": 18 }, "work": { "x": 22, "y": 13 }, "work_start_hour": 8, "work_end_hour": 18 },
			"likes": ["turnip", "wild_herb"], "dislikes": ["barley"] },
		{ "id": "villager_4", "name": "Bram", "role": "villager", "faction": "village", "traits": [], "spawn": { "x": 27, "y": 8 }, "color": "#5a5a7a",
			"schedule": { "home": { "x": 27, "y": 8 }, "work": { "x": 27, "y": 6 }, "work_start_hour": 8, "work_end_hour": 18 },
			"likes": ["wild_onion", "cabbage"], "dislikes": ["wild_berry"] }
	]
}
```

`GameData`: no new INT_KEYS beyond casting `work_start_hour`/
`work_end_hour` inside each villager's `schedule` (add to
`_cast_nested_ints`'s existing villager handling, or a new small loop
alongside it). Add `get_villager_schedule(id: String) -> Dictionary`
returning `get_villager(id).get("schedule", {})`.

## `data/requests.json` (new)

```json
{
	"version": 1,
	"max_active_requests": 2,
	"new_request_chance_per_day": 0.35,
	"templates": [
		{ "npc_id": "steward", "item_id": "barley", "quality": "fine", "quantity": 3, "days_to_complete": 5, "reward_coin": 15, "reward_opinion": 8 },
		{ "npc_id": "priest", "item_id": "turnip", "quality": "common", "quantity": 5, "days_to_complete": 4, "reward_coin": 8, "reward_opinion": 10 },
		{ "npc_id": "villager_1", "item_id": "wild_berry", "quality": "common", "quantity": 3, "days_to_complete": 3, "reward_coin": 6, "reward_opinion": 6 },
		{ "npc_id": "villager_2", "item_id": "flint", "quality": "common", "quantity": 4, "days_to_complete": 4, "reward_coin": 10, "reward_opinion": 6 },
		{ "npc_id": "villager_3", "item_id": "turnip", "quality": "fine", "quantity": 2, "days_to_complete": 4, "reward_coin": 9, "reward_opinion": 5 },
		{ "npc_id": "villager_4", "item_id": "wild_onion", "quality": "common", "quantity": 3, "days_to_complete": 3, "reward_coin": 7, "reward_opinion": 6 }
	]
}
```

`wild_berry`/`wild_onion`/`flint` are Sprint 8's forage items - requests
give foraging its first demand-side pull, not just a farming fallback.

`GameData`: `REQUEST_INT_KEYS` casts `max_active_requests` and, per
template, `quantity`, `days_to_complete`, `reward_coin`, `reward_opinion`.
`requests_cfg: Dictionary` loaded from `requests.json`.
`get_requests_config() -> Dictionary` returning it.

## `NPC` schedule behavior (`scripts/npc/npc.gd`)

The existing wander FSM (`npc.gd:31-45`) already moves toward `_target`
and re-picks a random point near `_start_pos` on idle timeout - this
sprint makes `_start_pos` (the "anchor") switch between the villager's
home and work tile based on the hour, and the existing logic handles
walking there and wandering nearby with no further change:

```gdscript
var _home_pos := Vector2.ZERO
var _work_pos := Vector2.ZERO
var _work_start_hour := 8
var _work_end_hour := 18
var _anchor := Vector2.ZERO


func _ready() -> void:
	_start_pos = position
	_target = position
	_timer = idle_time
	var game_data = get_node_or_null("/root/GameData")
	if game_data != null:
		var villager: Dictionary = game_data.get_villager(npc_id)
		_color = Color(str(villager.get("color", "#888888")))
		var schedule: Dictionary = villager.get("schedule", {})
		var home: Dictionary = schedule.get("home", villager.get("spawn", {}))
		var work: Dictionary = schedule.get("work", villager.get("spawn", {}))
		_home_pos = Vector2(int(home.get("x", 0)) * 32.0 + 16.0, int(home.get("y", 0)) * 32.0 + 16.0)
		_work_pos = Vector2(int(work.get("x", 0)) * 32.0 + 16.0, int(work.get("y", 0)) * 32.0 + 16.0)
		_work_start_hour = int(schedule.get("work_start_hour", 8))
		_work_end_hour = int(schedule.get("work_end_hour", 18))
	_anchor = _home_pos if _home_pos != Vector2.ZERO else position
	_start_pos = _anchor
	var tm = get_node_or_null("/root/TimeManager")
	if tm != null:
		tm.minute_passed.connect(_on_minute_passed)
		_update_anchor(int(tm.get("hour")))


func _on_minute_passed(hour: int, _minute: int) -> void:
	_update_anchor(hour)


func _update_anchor(hour: int) -> void:
	var new_anchor := _work_pos if (hour >= _work_start_hour and hour < _work_end_hour) else _home_pos
	if new_anchor != _anchor and new_anchor != Vector2.ZERO:
		_anchor = new_anchor
		_start_pos = _anchor
		_wandering = true
		_target = _anchor
```

Villagers with no `schedule` in their data (there are none after this
sprint's `villagers.json` v4, but keep the guard for robustness) fall back
to their spawn point as a static anchor, matching pre-Sprint-10 behavior.

**Alibi query for Sprint 12:** schedules are deterministic given an hour -
there is no need for `NPC` to log movement history. Sprint 12's
investigation should compute "was NPC X at home or at work at hour H" by
reading `GameData.get_villager_schedule(id)` directly and comparing
`work_start_hour`/`work_end_hour`, the same way `_update_anchor` does. Say
this explicitly here so Sprint 12 doesn't invent a redundant tracking
system.

## Gifting and requests - `ReputationManager` additions

Widen `configure_for_test` to accept a `PlayerState`, and add a `_player()`
accessor mirroring `TitheManager`'s:

```gdscript
func configure_for_test(game_data: Node, player_state: Node = null) -> void:
	_injected_game_data = game_data
	_test_player = player_state
	_clamp_initialized = false


func _player() -> Node:
	if _test_player != null:
		return _test_player
	return get_node_or_null("/root/PlayerState")
```

(`var _test_player: Node = null` alongside `_injected_game_data`.)

```gdscript
signal gift_given(npc_id: String, item_id: String, delta: float)
signal request_offered(request_id: String, npc_id: String)
signal request_completed(request_id: String)
signal request_expired(request_id: String)

const DAILY_GIFT_CAP := 1

var _daily_gift_count := 0
var _active_requests: Array[Dictionary] = []


func gift_item(npc_id: String, item_id: String) -> bool:
	if _daily_gift_count >= DAILY_GIFT_CAP:
		return false
	var player := _player()
	if player == null or not player.has_item(item_id, 1):
		return false
	var gd := _game_data()
	var villager: Dictionary = gd.get_villager(npc_id) if gd != null else {}
	var likes: Array = villager.get("likes", [])
	var dislikes: Array = villager.get("dislikes", [])
	var delta := 2.0
	if likes.has(item_id):
		delta = 10.0
	elif dislikes.has(item_id):
		delta = -6.0
	player.remove_item(item_id, 1)
	modify_opinion(npc_id, delta)
	_daily_gift_count += 1
	gift_given.emit(npc_id, item_id, delta)
	return true


func get_active_requests() -> Array[Dictionary]:
	return _active_requests.duplicate(true)


func can_complete_request(request_id: String) -> bool:
	var r := _find_request(request_id)
	if r.is_empty():
		return false
	var player := _player()
	return player != null and player.has_item(
		str(r.get("item_id", "")), int(r.get("quantity", 0)), str(r.get("quality", "common")))


func complete_request(request_id: String) -> bool:
	if not can_complete_request(request_id):
		return false
	var r := _find_request(request_id)
	var player := _player()
	player.remove_item(str(r.get("item_id", "")), int(r.get("quantity", 0)), str(r.get("quality", "common")))
	player.add_money(int(r.get("reward_coin", 0)))
	modify_opinion(str(r.get("npc_id", "")), float(r.get("reward_opinion", 0)))
	_active_requests.erase(r)
	request_completed.emit(request_id)
	return true


func _on_day_passed_village(_day: int, _season: String, _year: int) -> void:
	_daily_gift_count = 0
	var still_active: Array[Dictionary] = []
	for entry: Variant in _active_requests:
		var r := entry as Dictionary
		r["days_left"] = int(r.get("days_left", 0)) - 1
		if int(r["days_left"]) <= 0:
			request_expired.emit(str(r.get("id", "")))
		else:
			still_active.append(r)
	_active_requests = still_active
	_maybe_offer_request()


func _maybe_offer_request() -> void:
	var gd := _game_data()
	if gd == null:
		return
	var cfg := gd.get_requests_config()
	if _active_requests.size() >= int(cfg.get("max_active_requests", 2)):
		return
	if randf() >= float(cfg.get("new_request_chance_per_day", 0.0)):
		return
	var templates: Array = cfg.get("templates", [])
	if templates.is_empty():
		return
	var pick := (templates[randi() % templates.size()] as Dictionary).duplicate()
	pick["id"] = "req_%d" % Time.get_ticks_msec()
	pick["days_left"] = int(pick.get("days_to_complete", 3))
	_active_requests.append(pick)
	request_offered.emit(str(pick["id"]), str(pick.get("npc_id", "")))


func _find_request(request_id: String) -> Dictionary:
	for entry: Variant in _active_requests:
		if str((entry as Dictionary).get("id", "")) == request_id:
			return entry
	return {}
```

Connect `_on_day_passed_village` in `_ready()` alongside the existing
`_seed_opinions()` call - `ReputationManager._ready()` currently only
calls `_seed_opinions()` (`reputation_manager.gd:30-31`); add the
`TimeManager.day_passed` connection there, guarded with `is_connected`
like every other autoload's day-passed wiring.

`_active_requests` needs a save block. Extend `get_save_data()`/
`load_save_data()` (`reputation_manager.gd:104-125`) to include
`"active_requests": _active_requests.duplicate(true)` and restore it
symmetrically - this rides inside the existing `"reputation"` payload
key, so it does **not** need its own `SAVE_VERSION` bump beyond whatever
`migrate_to_v9` (below) already does for `villagers.json`'s new fields
being absent from old saves (nothing to migrate there - schedule/likes/
dislikes are static data, not save state).

## `main.gd` integration

`_on_npc_interacted` (`main.gd:113-124`, ported into `DialoguePanel` calls
per Sprint 7) gains request/gift awareness:

```gdscript
func _on_npc_interacted(npc_id: String) -> void:
	var standings := {
		"manor": ReputationManager.get_standing("manor"),
		"village": ReputationManager.get_standing("village"),
		"church": ReputationManager.get_standing("church"),
	}
	var lines := GameData.get_dialogue_for(npc_id, standings)
	var npc_name := str(GameData.get_villager(npc_id).get("name", npc_id))
	var line := lines[0] if not lines.is_empty() else "%s looks at you silently." % npc_name
	var responses: Array[Dictionary] = []
	for req: Dictionary in ReputationManager.get_active_requests():
		if str(req.get("npc_id", "")) != npc_id:
			continue
		line = "%s needs %d %s (%s)." % [
			npc_name, int(req.get("quantity", 0)), str(req.get("item_id", "")), str(req.get("quality", "common"))]
		if ReputationManager.can_complete_request(str(req.get("id", ""))):
			responses.append({
				"text": "Fulfill request",
				"callback": func() -> void: ReputationManager.complete_request(str(req.get("id", ""))),
			})
	responses.append({
		"text": "Give a gift",
		"callback": func() -> void: inventory_panel.open_for_gift(npc_id),
	})
	dialogue_panel.show_dialogue(npc_name, line, responses)
	UIManager.open_menu("dialogue")
```

`InventoryPanel.open_for_gift(npc_id: String)` is a small new mode on
Sprint 7's panel: opens the inventory list as normal, but each row's
button becomes "Gift" calling `ReputationManager.gift_item(npc_id,
item_id)` instead of Equip/Eat, and the panel closes back to the dialogue
panel afterward. This is additive to Sprint 7's `InventoryPanel`, not a
new panel.

## Mass on a fixed day

A simple, undecorated addition in `main.gd` - no new autoload, no new
system, just a scheduled check:

```gdscript
const MASS_DAY := 21
const MASS_HOUR := 9

func _on_minute_passed(hour: int, _minute: int) -> void:
	_refresh_time()
	if TimeManager.day == MASS_DAY and hour == MASS_HOUR and not _mass_checked_today:
		_mass_checked_today = true
		var chapel_tile := Vector2i(10, 15)  # GameData.get_feature_at's chapel tile, per farm_map.json
		if player.get_faced_tile() == chapel_tile or _player_tile() == chapel_tile:
			ReputationManager.apply_action("attend_mass")
			_show_message("You attended mass. The village takes notice.")
```

(`_mass_checked_today` reset to `false` in `_on_day_passed`; `_player_tile
()` is the non-faced version of `Player.get_faced_tile()` - i.e. the
player's own tile, not the tile ahead of them; add a matching `Player.
get_current_tile() -> Vector2i` if it doesn't already exist as a
byproduct of Sprint 7's `get_faced_tile` refactor.) Add `attend_mass: {
"manor": 0, "village": 1, "church": 5 }` to `data/reputation.json`'s
`actions`. No penalty for missing it - a missed opportunity, not a
punishment, consistent with the church axis staying voluntary per ADR-012.

## Save schema

`SAVE_VERSION -> 9`. No new top-level payload key - `_active_requests` and
`_daily_gift_count` ride inside the existing `"reputation"` block (see
above). Add a trivial migration rung for completeness even though nothing
structurally new needs defaulting beyond what `get_save_data()`'s existing
`.get(..., {})`/`.get(..., [])` patterns already handle:

```gdscript
func migrate_to_v9(payload: Dictionary) -> Dictionary:
	payload["version"] = 9
	return payload
```

Chain: `if version <= 8: parsed = migrate_to_v9(parsed)`.

## Tests

### New: `tests/suites/test_schedules.gd`

Construct a real `GameData`. For at least two villagers (one with a
work window spanning midday, one you pick to check an edge hour), assert
`get_villager_schedule(id)`'s `work_start_hour`/`work_end_hour` produce
the expected anchor via the same comparison `NPC._update_anchor` uses
(`hour >= start and hour < end`) - test the **logic**, not the live `NPC`
node's movement (which needs a scene tree to animate; assert the anchor
*decision*, not the walk).

1. Steward: hour `6` -> home anchor (before `work_start_hour: 7`).
2. Steward: hour `7` -> work anchor (boundary inclusive on start).
3. Steward: hour `19` -> work anchor; hour `20` -> home anchor (boundary
   exclusive on end).
4. All six villagers have both `home` and `work` populated (a data
   completeness check - catches a future villagers.json edit that adds an
   NPC without a schedule).

Target: 8+ checks (one villager fully swept through its day, plus the
completeness check across all six).

### New: `tests/suites/test_gifting.gd`

1. `gift_item` on a liked item removes it from inventory and raises
   opinion by the "liked" delta (`10.0`).
2. `gift_item` on a disliked item lowers opinion (`-6.0`).
3. `gift_item` on a neutral item (neither list) applies the small default
   delta (`2.0`).
4. Second `gift_item` call the same day (before a day-passed reset) fails
   - the daily cap.
5. After `_on_day_passed_village` fires, gifting works again.
6. `gift_item` with no matching inventory item fails, no opinion change.

Target: 8+ checks.

### New: `tests/suites/test_requests.gd`

1. `_maybe_offer_request` with `new_request_chance_per_day` forced to
   `1.0` (test-mode override, or a `GameData` mock with that value) and
   zero active requests adds exactly one request from `templates`.
2. `_maybe_offer_request` does nothing once `_active_requests.size() >=
   max_active_requests`.
3. `can_complete_request` false when inventory is short; true once the
   right item/quality/quantity is present.
4. `complete_request` removes the items, adds `reward_coin`, raises the
   right NPC's opinion by `reward_opinion`, removes the request from
   `get_active_requests()`, and fires `request_completed`.
5. A request whose `days_left` reaches `0` via repeated
   `_on_day_passed_village` calls is removed and fires `request_expired`,
   without ever being completable after expiry.

Target: 8+ checks.

### `tests/run_tests.gd`

Register `test_schedules.gd`, `test_gifting.gd`, `test_requests.gd`.

## Manual test checklist

1. Open the project in Godot 4.7.1 and press F5 - no errors.
2. Watch a villager across an in-game day - confirm it's near its home
   tile at night and its work tile during the day, walking between them
   at the schedule boundary rather than wandering randomly forever.
3. Interact with an NPC that has no active request - normal dialogue line,
   a "Give a gift" response option.
4. Give a liked item - opinion visibly rises (check the HUD/debug standing
   display); give a disliked item - opinion visibly falls; try a second
   gift the same day - rejected.
5. Wait for a request to appear (or force one via a debug hook) - interact
   with that NPC, confirm the request line and a "Fulfill request" option
   once you're carrying enough of the right item/quality.
6. Let a request's `days_left` run out without fulfilling it - confirm it
   disappears and can no longer be completed.
7. On day 21 at hour 9, stand at the chapel tile - confirm the mass
   message and a church standing bump; skip it on a different day and
   confirm no penalty.
8. Save, reload - active requests and their remaining days persist
   exactly.
9. Resize the window - dialogue/gift panels stay legible.

## Divergences to record

- Gifting and requests live on `ReputationManager` rather than a new
  autoload - deliberate, to avoid an unjustified DESKTOP step (see the
  header note).
- `NPC` schedule anchoring recomputes from the villager's static data on
  every hour tick rather than caching a "current period" enum - simpler,
  and the comparison is cheap enough (four int compares) to not matter at
  six NPCs.
- Mass attendance is checked once per `(day, hour)` via a boolean reset on
  `day_passed`, not via a dedicated `MassManager` - it's one `if` in
  `main.gd`, not a system.
