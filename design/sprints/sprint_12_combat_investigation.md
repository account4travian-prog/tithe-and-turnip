# Sprint 12 - Dynamic combat & the thief investigation

**Size:** L. **Markers:** DESKTOP (one autoload registration, ~2 minutes -
same steps as Sprint 8's, substituting `InvestigationManager`), AMENDMENT.
**ADR:** ADR-026 - Proposed, supersedes ADR-014's deferral clause. Confirm
Accepted before starting.
**Prerequisite:** Sprints 9, 10, and 11 (consumes `BuildingManager.
get_deterrence_bonus()` from Sprint 9, `NPC` schedules for alibi framing
from Sprint 10, and `TitheManager.record_offense`/manor court from
Sprint 11 for the false-accusation consequence).

## Correction to the roadmap's DESKTOP scope

The roadmap flags "enemy/projectile scenes" as a possible DESKTOP item.
They are not - Sprint 5 already proved enemies and projectiles are fully
runtime-built (`Enemy`, and `CombatManager`'s inner `Projectile` class,
`combat_manager.gd:152-174`). The only editor-dependent step in this
sprint is registering the new `InvestigationManager` autoload. The
projectile physics layer this sprint might have worried about
(`PhysicsLayers.PROJECTILE = 6`) already exists in
`scripts/globals/physics_layers.gd:12`, added in Sprint 5 - nothing to do
there either.

## Objective

Wire the deterrence fields `raids.json` has carried since Sprint 5 but
never consumed into actual dynamic raid frequency; add enemy variety and a
"night raid" flavor; give fences (Sprint 9), a guard dog, and a hired
guard real defensive value; and replace Sprint 5's theft-as-notification
with a real investigation - clues, an accusation through Sprint 7's
dialogue response options, and consequences (including a false-accusation
path into Sprint 11's manor court) for getting it wrong.

## `data/raids.json` v1 -> v2

```json
{
	"version": 2,
	"deterrence_decay_per_day": 2,
	"deterrence_gain_per_victory": 15,
	"min_deterrence_no_raid": 30,
	"dynamic_raid_chance_per_day": 0.12,
	"dynamic_raid_earliest_day": 16,
	"dynamic_raid_size_min": 2,
	"dynamic_raid_size_max": 4,
	"night_raid_flavor_chance": 0.3,
	"night_raid_size_bonus": 1,
	"scripted_raids": [
		{ "day": 15, "season": "spring", "location": "farm", "enemies": [ { "type": "bandit_melee", "count": 2 }, { "type": "bandit_archer", "count": 1 } ] }
	],
	"dynamic_enemy_pool": [
		{ "type": "bandit_melee", "weight": 50 },
		{ "type": "bandit_archer", "weight": 30 },
		{ "type": "raid_leader", "weight": 20 }
	]
}
```

**"Night raid" is a flavor roll, not real-time hour polling.**
`RaidManager` only evaluates once per `day_passed`, and by the time that
fires the clock has already rolled to the new day's wake hour - there is
no meaningful "was it night" moment to check against inside that handler
without restructuring `RaidManager` to poll `minute_passed` continuously,
which is a materially bigger change for a cosmetic feature. Instead, when
a dynamic raid triggers, roll `night_raid_flavor_chance` separately; on a
hit, the raid is flavored as a night raid (message text, `+
night_raid_size_bonus` enemies) rather than being gated to real clock
hours. State this explicitly so nobody "fixes" it into hour-polling later
without deciding that's worth the restructure.

`GameData`: extend `RAID_INT_KEYS` (`game_data.gd:29-31`) with
`dynamic_raid_earliest_day`, `dynamic_raid_size_min`,
`dynamic_raid_size_max`, `night_raid_size_bonus`, and every
`dynamic_enemy_pool[].weight` (nested - add to `_cast_nested_ints`).
`dynamic_raid_chance_per_day` and `night_raid_flavor_chance` stay float.

## `data/enemies.json` v1 -> v2 - new enemy

```json
"raid_leader": { "id": "raid_leader", "name": "Raid Leader", "health": 35, "damage": 10, "speed": 90, "reach": 60, "cooldown": 0.9, "behavior": "melee" }
```

## Defenses

New `data/items.json` entries (type `"defense"`, a new item type -
`ToolManager.use_tool` already `match`es on `item.type` and falls through
to its `_:` default (`tool_manager.gd:34-42`) for unrecognized types, so a
`"defense"` item is inert as a hand-held tool by construction; it only
matters while owned, not while equipped):

```json
{ "id": "guard_dog", "type": "defense", "name": "Guard Dog", "price": 60, "deterrence_bonus": 5 },
{ "id": "hired_guard", "type": "defense", "name": "Hired Guard", "price": 120, "deterrence_bonus": 10 }
```

Add both to `market.json`'s `stall_inventory`. `ITEM_INT_KEYS`
(`game_data.gd:13-15`) gains `deterrence_bonus`.

`RaidManager` computes **effective deterrence** (raw `raid_deterrence` +
Sprint 9's fence bonus + owned defense items) instead of reading
`PlayerState.raid_deterrence` directly:

```gdscript
func _effective_deterrence() -> int:
	var total := int(_player_state.get("raid_deterrence"))
	var bm := get_node_or_null("/root/BuildingManager")
	if bm != null:
		total += bm.get_deterrence_bonus()
	if _game_data != null:
		for item_id: String in _game_data.get_all_item_ids():
			var item: Dictionary = _game_data.get_item(item_id)
			if str(item.get("type", "")) == "defense" and int(item.get("deterrence_bonus", 0)) > 0:
				if _player_state.get_item_count(item_id) > 0:
					total += int(item.get("deterrence_bonus", 0))
	return total
```

Owning a guard dog and a hired guard both add their bonus once each
regardless of quantity owned (presence, not count - buying two guard dogs
doesn't stack). This deliberately does not model upkeep/food for the dog
or wages for the guard - a flat one-time purchase, kept simple; revisit
only if playtesting shows defenses need an ongoing cost to stay balanced
against Sprint 6's other coin sinks.

## `RaidManager` - dynamic triggering

Refactor the shared spawn logic out of `execute_raid()`
(`raid_manager.gd:54-89`) so both the scripted and dynamic paths use it:

```gdscript
func execute_raid() -> void:
	var raids: Array = _game_data.get_scripted_raids("spring")
	if raids.is_empty():
		return
	_spawn_raid((raids[0] as Dictionary).get("enemies", []), false)


func execute_dynamic_raid() -> void:
	var cfg := _game_data.raids_cfg
	var pool: Array = cfg.get("dynamic_enemy_pool", [])
	if pool.is_empty():
		return
	var is_night := randf() < float(cfg.get("night_raid_flavor_chance", 0.0))
	var size := _rng.randi_range(
		int(cfg.get("dynamic_raid_size_min", 2)), int(cfg.get("dynamic_raid_size_max", 4)))
	if is_night:
		size += int(cfg.get("night_raid_size_bonus", 0))
	var counts: Dictionary = {}
	for _i in range(size):
		var picked := _weighted_pick_enemy(pool)
		if picked.is_empty():
			continue
		counts[picked] = int(counts.get(picked, 0)) + 1
	var enemies_list: Array = []
	for enemy_type: Variant in counts:
		enemies_list.append({"type": enemy_type, "count": counts[enemy_type]})
	_spawn_raid(enemies_list, is_night)


func _spawn_raid(enemies_list: Array, is_night: bool) -> void:
	if enemies_list.is_empty() or get_tree() == null or get_tree().current_scene == null:
		return
	var total_count := 0
	for entry: Variant in enemies_list:
		total_count += int((entry as Dictionary).get("count", 0))
	if total_count <= 0:
		return
	raid_started.emit(total_count)
	if is_night:
		raid_message.emit("A raid strikes under cover of darkness!")
	_raid_active = true
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	_active_enemies.clear()
	var spawn_positions := _generate_spawn_positions(player.global_position, total_count)
	var idx := 0
	for entry: Variant in enemies_list:
		var enemy_def := entry as Dictionary
		var enemy_type := str(enemy_def.get("type", ""))
		for _i in range(int(enemy_def.get("count", 0))):
			var enemy := Enemy.new()
			enemy.enemy_id = enemy_type
			get_tree().current_scene.add_child(enemy)
			enemy.global_position = spawn_positions[idx]
			idx += 1
			_active_enemies.append(enemy)
			enemy.enemy_died.connect(_on_raid_enemy_resolved.bind(enemy))
			enemy.enemy_fled.connect(_on_raid_enemy_resolved.bind(enemy))
	if _combat_manager != null:
		_combat_manager.player_knocked_out.connect(_on_player_knocked_out_during_raid, CONNECT_ONE_SHOT)


func _weighted_pick_enemy(pool: Array) -> String:
	var total := 0.0
	for e: Variant in pool:
		total += float((e as Dictionary).get("weight", 0))
	if total <= 0.0:
		return ""
	var roll := randf() * total
	var cumulative := 0.0
	for e: Variant in pool:
		var entry := e as Dictionary
		cumulative += float(entry.get("weight", 0))
		if roll < cumulative:
			return str(entry.get("type", ""))
	return ""
```

`_on_day_passed` (`raid_manager.gd:40-52`) gains the dynamic trigger,
using effective deterrence instead of the raw value it already reads at
the top of the function for decay:

```gdscript
func _on_day_passed(day: int, season: String, _year: int) -> void:
	var settings: Dictionary = _game_data.get_raid_settings()
	var decay := int(settings.get("deterrence_decay_per_day", 1))
	_player_state.raid_deterrence = maxi(0, int(_player_state.get("raid_deterrence")) - decay)
	if season != "spring":
		return
	if day == 15 and not _raid_done:
		_raid_done = true
		execute_raid()
	if day == 19 and not _theft_done:
		_theft_done = true
		execute_theft()
	_maybe_trigger_dynamic_raid(day)


func _maybe_trigger_dynamic_raid(day: int) -> void:
	if _raid_active:
		return
	var cfg := _game_data.raids_cfg
	if day < int(cfg.get("dynamic_raid_earliest_day", 16)):
		return
	var min_det := int(cfg.get("min_deterrence_no_raid", 30))
	var effective := _effective_deterrence()
	if effective >= min_det:
		return
	var gap_ratio := float(min_det - effective) / float(maxi(1, min_det))
	var chance := float(cfg.get("dynamic_raid_chance_per_day", 0.0)) * (0.5 + gap_ratio)
	if randf() < chance:
		execute_dynamic_raid()
```

Higher effective deterrence (raw + fence + defenses) both lowers the
chance a dynamic raid triggers at all and, once it's below the threshold,
the size of the gap scales how likely each day's roll is - a fence and a
guard dog are a real, measurable safety margin, not flavor text.

## Thief investigation

### `data/villagers.json` v4 -> v5 - populate every trait list

The current file has five empty `"traits": []` arrays and one
`["thief"]` - the culprit is identifiable by reading the JSON. Give every
villager 1-2 flavor traits, real thief hidden among decoys:

```json
{ "id": "steward", "traits": ["stern", "loyal"] },
{ "id": "priest", "traits": ["devout", "forgetful"] },
{ "id": "villager_1", "traits": ["gossip", "early_riser"] },
{ "id": "villager_2", "traits": ["gruff", "night_owl"] },
{ "id": "villager_3", "traits": ["quiet", "thief"] },
{ "id": "villager_4", "traits": ["boastful", "night_owl"] }
```

(Shown as trait-array diffs against the existing per-villager objects -
every other field from `villagers.json` v4 is unchanged.) None of
`stern`/`loyal`/`devout`/`forgetful`/`gossip`/`early_riser`/`gruff`/
`night_owl`/`quiet`/`boastful` have any mechanical effect this sprint -
they exist so `"thief"` isn't the one non-empty array in the file. A
future content pass could hook `gossip` to reveal clues faster or
`night_owl` to a schedule variant; not required here.

`RaidManager.execute_theft()` (`raid_manager.gd:91-104`) currently
hardcodes `"villager_id": "villager_3"`. Replace the hardcode with a data
lookup so the trait list in `villagers.json` is the single source of
truth, not a value duplicated in two places:

```gdscript
func execute_theft() -> void:
	var thief_id := _find_thief_id()
	var coin_stolen := 30
	var actual_lost := mini(coin_stolen, int(_player_state.get("money")))
	if actual_lost > 0:
		_player_state.spend_money(actual_lost)
	var event := {"day": 19, "villager_id": thief_id, "coin_stolen": actual_lost, "resolved": false}
	_player_state.theft_events.append(event)
	theft_occurred.emit(actual_lost, "Something was stolen overnight! You lost %d coin." % actual_lost)
	var inv := get_node_or_null("/root/InvestigationManager")
	if inv != null and not thief_id.is_empty():
		inv.start_investigation(thief_id)


func _find_thief_id() -> String:
	for id: String in _game_data.get_all_villager_ids():
		var traits: Array = _game_data.get_villager(id).get("traits", [])
		if traits.has("thief"):
			return id
	return ""
```

### `data/clues.json` (new)

```json
{ "version": 1, "clue_count": 3 }
```

Kept minimal - clue *text* is generated in code (see
`InvestigationManager._generate_clues` below), not authored per-NPC in
data, since it needs to substitute the actual suspect's name at runtime.
`GameData`: `clues_cfg: Dictionary` from `clues.json`,
`get_clues_config() -> Dictionary`. `CLUE_INT_KEYS = ["clue_count"]`.

### `InvestigationManager` autoload (`scripts/autoloads/investigation_manager.gd`)

```gdscript
extends Node

signal clues_revealed(clues: Array)
signal accusation_resolved(suspect_id: String, correct: bool)

var _true_suspect_id := ""
var _clues: Array[Dictionary] = []
var _revealed_clue_indices: Array[int] = []
var _investigation_open := false
var _resolved := false

var _test_game_data: Node = null
var _test_mode := false


func configure_for_test(game_data: Node) -> void:
	_test_game_data = game_data
	_test_mode = true


func start_investigation(true_suspect_id: String) -> void:
	_true_suspect_id = true_suspect_id
	_clues = _generate_clues(true_suspect_id)
	_revealed_clue_indices = []
	_investigation_open = true
	_resolved = false


func reveal_clue_for(_npc_id: String) -> Dictionary:
	if not _investigation_open:
		return {}
	for i in range(_clues.size()):
		if not _revealed_clue_indices.has(i):
			_revealed_clue_indices.append(i)
			clues_revealed.emit(get_revealed_clues())
			return _clues[i]
	return {}


func get_revealed_clues() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in _revealed_clue_indices:
		out.append(_clues[i])
	return out


func can_accuse() -> bool:
	return _investigation_open and not _resolved


func accuse(suspect_id: String) -> bool:
	if not can_accuse():
		return false
	_resolved = true
	_investigation_open = false
	var correct := suspect_id == _true_suspect_id
	accusation_resolved.emit(suspect_id, correct)
	if not _test_mode:
		var rep := get_node_or_null("/root/ReputationManager")
		if rep != null:
			rep.apply_action("accuse_correctly" if correct else "accuse_falsely", suspect_id)
		if not correct:
			var tithe := get_node_or_null("/root/TitheManager")
			if tithe != null:
				tithe.record_offense("false_accusation")
	return correct


func to_dict() -> Dictionary:
	return {
		"true_suspect_id": _true_suspect_id,
		"clues": _clues.duplicate(true),
		"revealed": _revealed_clue_indices.duplicate(),
		"open": _investigation_open,
		"resolved": _resolved,
	}


func from_dict(data: Dictionary) -> void:
	_true_suspect_id = str(data.get("true_suspect_id", ""))
	_clues = []
	for entry: Variant in data.get("clues", []):
		_clues.append((entry as Dictionary).duplicate())
	_revealed_clue_indices = []
	for i: Variant in data.get("revealed", []):
		_revealed_clue_indices.append(int(i))
	_investigation_open = bool(data.get("open", false))
	_resolved = bool(data.get("resolved", false))


func _generate_clues(true_suspect_id: String) -> Array[Dictionary]:
	var gd := _game_data()
	if gd == null:
		return []
	var decoys: Array = []
	for id: String in gd.get_all_villager_ids():
		if id != true_suspect_id:
			decoys.append(id)
	decoys.shuffle()
	var clue_count := int(gd.get_clues_config().get("clue_count", 3))
	var clues: Array[Dictionary] = []
	clues.append({
		"suspect_id": true_suspect_id, "true": true,
		"text": "A neighbor recalls %s was not seen at home that night." \
			% str(gd.get_villager(true_suspect_id).get("name", true_suspect_id)),
	})
	for i in range(mini(clue_count - 1, decoys.size())):
		var suspect: String = decoys[i]
		clues.append({
			"suspect_id": suspect, "true": false,
			"text": "Some say %s was acting strangely that day." \
				% str(gd.get_villager(suspect).get("name", suspect)),
		})
	clues.shuffle()
	return clues


func _game_data() -> Node:
	if _test_game_data != null:
		return _test_game_data
	return get_node_or_null("/root/GameData")
```

`reveal_clue_for` deliberately ignores which NPC it's called on and just
hands out the next unrevealed clue in shuffled order - "any villager might
have heard something," not a strict per-NPC assignment. This keeps the
system simple: the player has to talk to `clue_count` different villagers
after the theft to hear every clue, not find the "right" one to ask.

Add to `data/reputation.json`'s `actions`:

```json
"accuse_correctly": { "manor": 2, "village": 4, "church": 0, "opinion_delta": -20 },
"accuse_falsely": { "manor": -3, "village": -8, "church": 0, "opinion_delta": -10 }
```

`opinion_delta` targets the accused NPC in both cases (per the existing
`apply_action(action_id, target_npc_id)` convention, `reputation_manager
.gd:60-75`) - a correctly-accused thief's opinion of the player drops
(obviously), and a falsely-accused innocent villager's opinion of the
player *also* drops (they resent it), on top of the harsher village-wide
standing hit `accuse_falsely` carries.

## `main.gd` integration

`_on_npc_interacted` (already extended once in Sprint 10 for gifts/
requests) gains investigation awareness, appended after the request
handling:

```gdscript
	if InvestigationManager.can_accuse():
		var revealed := InvestigationManager.reveal_clue_for(npc_id)
		if not revealed.is_empty():
			line += " " + str(revealed.get("text", ""))
		responses.append({
			"text": "Accuse of theft",
			"callback": func() -> void:
				var correct := InvestigationManager.accuse(npc_id)
				dialogue_panel.show_dialogue(npc_name,
					"Accused! The village stirs." if correct else "You have no proof - the village grumbles.", []),
		})
	dialogue_panel.show_dialogue(npc_name, line, responses)
	UIManager.open_menu("dialogue")
```

The player accuses *whoever they're currently talking to* - there is no
separate suspect-picker menu. This is a deliberate simplification: the
player must walk up to and interact with the specific villager they
believe is guilty, which is consistent with how every other interaction
in this game already works (feature/NPC dispatch by tile, not by menu).

## Injury persists past sleep

`PlayerState.apply_pass_out_penalty` (`player_state.gd`, Sprint 6 made the
money/health values data-driven) gains a wound only for the `"combat"`
cause specifically - exhaustion and forced-collapse pass-outs don't wound,
only losing a fight does:

```gdscript
func apply_pass_out_penalty(cause: String) -> void:
	pass_out_count += 1
	... existing money/health logic unchanged ...
	knocked_out.emit(cause)
	if cause == "combat":
		var game_data = get_node_or_null("/root/GameData")
		wound_days_remaining = int(game_data.player_cfg.get("wound_recovery_days", 1)) if game_data != null else 1
```

New var `var wound_days_remaining: int = 0`; decrement in the existing
`_on_day_passed` handler Sprint 6 added:

```gdscript
func _on_day_passed(_day: int, _season: String, _year: int) -> void:
	_exhaustion_count_today = 0
	wound_days_remaining = maxi(0, wound_days_remaining - 1)
```

`ToolManager._use_tool_item` (already reading `SkillManager`'s
`tool_energy_cost_mult` from Sprint 8) multiplies energy cost by an
additional wound penalty:

```gdscript
	var wound_mult := 1.2 if _player_state.get("wound_days_remaining") as int > 0 else 1.0
	var energy_cost := int(item.get("energy_cost", 0)) * wound_mult
```

Add `"wound_recovery_days": 1` to `data/player.json` (a small addition to
the file Sprint 6 already versioned to v2 - bump to v3).

## Save schema

`SAVE_VERSION -> 11`.

```gdscript
# build_payload()
var investigation = get_node_or_null("/root/InvestigationManager")
if investigation != null:
	payload["investigation"] = investigation.to_dict()

# apply_payload()
var investigation = get_node_or_null("/root/InvestigationManager")
if investigation != null and payload.has("investigation"):
	investigation.from_dict(payload["investigation"] as Dictionary)
```

`player.wound_days_remaining` rides inside the existing `"player"` block
(`PlayerState.to_dict`/`from_dict` - add the field there with a `0`
default for old saves, same additive pattern as every prior sprint's
per-cell/per-block additions).

```gdscript
func migrate_to_v11(payload: Dictionary) -> Dictionary:
	payload["version"] = 11
	if not payload.has("investigation"):
		payload["investigation"] = {
			"true_suspect_id": "", "clues": [], "revealed": [], "open": false, "resolved": false,
		}
	var player: Dictionary = payload.get("player", {})
	if not player.has("wound_days_remaining"):
		player["wound_days_remaining"] = 0
	payload["player"] = player
	return payload
```

Chain: `if version <= 10: parsed = migrate_to_v11(parsed)`.

**Known gap, not fixed this sprint:** `RaidManager._raid_done`/
`_theft_done` still aren't persisted at all (a pre-existing gap, not
introduced here). Reloading a save from before day 15 after having already
fought that raid this session would let it fire again. Leave it - fixing
it means adding raid/theft-completion flags to the save payload, which is
a small, independent change better scoped on its own rather than folded
into an already-large sprint; note it in `DEVELOPMENT_STATE.md` as a known
gap if it isn't picked up here.

## Tests

### New: `tests/suites/test_raid_scaling.gd`

Construct `RAID_MANAGER_SCRIPT.new()` with `configure_for_test`, a real
`GameData`, and a `PlayerState`. Assert:

1. `_effective_deterrence()`-equivalent (expose a public
   `get_effective_deterrence()` for the test rather than reaching into the
   private method) sums raw `raid_deterrence` plus a mocked
   `BuildingManager`'s bonus plus owned defense items - test each
   contribution independently (raw only, +building only, +items only,
   then combined).
2. `_maybe_trigger_dynamic_raid` never triggers before
   `dynamic_raid_earliest_day`, however low deterrence is.
3. `_maybe_trigger_dynamic_raid` never triggers when effective deterrence
   is at or above `min_deterrence_no_raid`.
4. With `dynamic_raid_chance_per_day` forced to `1.0` and deterrence at
   `0`, a call past the earliest day always triggers
   (`execute_dynamic_raid` called - assert via a signal or a test hook,
   not by inspecting private state).
5. `_weighted_pick_enemy` over a pool with one zero-weight and one
   full-weight entry always returns the full-weight entry (deterministic
   edge case, no `randf` flakiness).
6. `execute_theft`'s `_find_thief_id` returns the villager whose `traits`
   contains `"thief"` from real `villagers.json` data (`"villager_3"` as
   shipped) - and, separately, returns `""` gracefully against a mocked
   `GameData` where no villager has that trait, rather than erroring.

Target: 12+ checks.

### New: `tests/suites/test_thief_investigation.gd`

1. `start_investigation("villager_3")` produces exactly `clue_count`
   clues, exactly one of which has `"true": true` and
   `"suspect_id" == "villager_3"`.
2. `reveal_clue_for` returns a different clue each call, in shuffled
   order, until all are revealed, then returns `{}` on further calls.
3. `can_accuse()` is true only between `start_investigation` and the first
   `accuse` call.
4. `accuse("villager_3")` (the true suspect) returns `true`; a second
   `accuse` call on anything returns `false` (already resolved).
5. A fresh investigation, `accuse("villager_1")` (a decoy) returns `false`.
6. `to_dict()`/`from_dict()` round-trip the full investigation state,
   including partially-revealed clues, exactly - construct a second
   `InvestigationManager`, `from_dict` the first's `to_dict()` output, and
   compare `get_revealed_clues()` and `can_accuse()` between the two.
7. Cross-manager check: a real `TitheManager` connected to a real
   `ReputationManager`, `accuse` called incorrectly, results in exactly
   one `"false_accusation"` offense queued (mirrors Sprint 11's
   `test_court.gd` pattern for the `attack_villager` -> offense hookup).

Target: 12+ checks.

### New: `tests/suites/test_combat_weapons.gd`

(This suite was already registered in `tests/run_tests.gd` as
`test_combat.gd` since Sprint 5 - this is a **second**, Sprint-12-specific
suite for the additions in this sprint, named distinctly so it doesn't
collide.)

1. `raid_leader` enemy data loads with the stats in `enemies.json` v2.
2. A wound (`cause == "combat"` pass-out) sets `wound_days_remaining` to
   `player.json`'s `wound_recovery_days`; an exhaustion pass-out
   (`cause == "exhaustion"`) does **not** set it - confirms the cause
   check, not just that *a* pass-out sets it.
3. `wound_days_remaining` decrements by exactly 1 per `_on_day_passed`
   call and floors at 0 (never negative).
4. Tool energy cost is multiplied by the wound penalty while
   `wound_days_remaining > 0`, and is not while it's `0` - a direct
   before/after comparison on the same `ToolManager` call.

Target: 8+ checks.

### `tests/run_tests.gd`

Register `test_raid_scaling.gd`, `test_thief_investigation.gd`,
`test_combat_weapons.gd`.

## Manual test checklist

1. Confirm the DESKTOP autoload registration - F5, no
   `InvestigationManager` errors in Output.
2. Let deterrence fall below `min_deterrence_no_raid` past day 16 (avoid
   winning raids, or wait out the daily decay) - confirm a dynamic raid
   eventually triggers, with enemy variety beyond the day-15 scripted
   composition.
3. Buy a guard dog and/or build a fence (Sprint 9), confirm dynamic raid
   frequency visibly drops relative to an unequipped playthrough (or check
   the effective-deterrence number directly via a debug overlay if one
   exists).
4. Survive to day 19 - confirm the theft event fires as before, and that
   talking to villagers afterward now surfaces clue dialogue lines
   alongside the normal line.
5. Gather all clues by talking to enough villagers, accuse the correct one
   - confirm the "Accused!" outcome and the reputation changes.
6. On a fresh investigation (reload an earlier save, or wait for a
   different playthrough), accuse the wrong villager - confirm the
   village-standing penalty, the accused NPC's opinion drop, and that the
   offense shows up as a fine at the next Sprint-11 manor court day.
7. Lose a fight (get knocked out by combat, not exhaustion) - confirm
   subsequent tool use costs visibly more energy, and that the penalty
   clears after the configured number of sleeps.
8. Save/reload mid-investigation (some clues revealed, not yet accused) -
   confirm revealed clues and accusation availability persist exactly.
9. Resize the window - dialogue/clue text remains legible.

## Divergences to record

- "Night raids" are a flavor roll at trigger time, not gated to real
  in-game clock hours - see the `raids.json` section for why the existing
  once-per-`day_passed` architecture makes true hour-gating a materially
  bigger change than this feature justifies.
- Accusation targets whoever the player is currently talking to - no
  separate suspect-picker UI. Consistent with every other interaction in
  the game being tile/NPC-dispatch driven, not menu-driven.
- `RaidManager._raid_done`/`_theft_done` remain unpersisted (pre-existing
  gap, not introduced this sprint) - flagged, not fixed, to keep this
  sprint's scope to what ADR-026 actually calls for.
- Defense items (guard dog, hired guard) are flat one-time purchases with
  no ongoing upkeep cost - simpler than modeling wages/feed; revisit only
  if playtesting shows it needs a recurring cost to stay balanced.
