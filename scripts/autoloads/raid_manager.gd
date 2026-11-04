extends Node

## RaidManager autoload - orchestrates the scripted day-15 bandit raid, the
## day-19 theft event, and (ADR-026) deterrence-driven dynamic raids. Deterrence
## decays daily; raid victory adds to it. Effective deterrence = raw
## raid_deterrence + BuildingManager's fence bonus + owned defense items
## (guard dog, hired guard) - a flat presence bonus, not per-quantity.
##
## Dynamic raids evaluate once per day_passed, never against real clock hours:
## "night raid" is a flavor roll at trigger time that adds night_raid_size_bonus
## enemies, because by the time day_passed fires the clock has already rolled to
## the new day's wake hour. Do not "fix" this into minute_passed polling without
## deciding that restructure is worth it.
##
## X6 mercy path (world_bible.md Section VII): the day-19 theft is also
## suppressed when PlayerState carries "investigation.showed_mercy_<thief_id>"
## (set by InvestigationManager.show_mercy) - the same single-guard shape as
## the marriage guard below. The scripted theft is a one-time event, so this
## is forward-looking until a recurring theft mechanism exists.

signal raid_started(enemy_count: int)
signal raid_resolved(win: bool)
signal theft_occurred(coin_lost: int, message: String)
signal raid_message(text: String)
## Test/UI hook: fires as soon as a dynamic raid's composition is decided,
## before spawning (spawning needs a live scene tree, tests have none).
signal dynamic_raid_triggered(enemy_count: int)

var _player_state: Node
var _game_data: Node
var _combat_manager: Node
var _test_building_manager: Node = null
var _test_marriage_manager: Node = null
var _rng := RandomNumberGenerator.new()

var _raid_done := false
var _theft_done := false
var _raid_active := false
var _active_enemies: Array = []


func _ready() -> void:
	_player_state = get_node_or_null("/root/PlayerState")
	_game_data = get_node_or_null("/root/GameData")
	_combat_manager = get_node_or_null("/root/CombatManager")
	var time_mgr := get_node_or_null("/root/TimeManager")
	if time_mgr != null:
		time_mgr.day_passed.connect(_on_day_passed)


func set_rng_seed(seed_value: int) -> void:
	_rng.seed = seed_value


## Optional building_manager seam so tests can drive the fence-bonus branch of
## effective deterrence without mounting /root (the headless harness runs in
## SceneTree._initialize, where /root lookups cannot resolve).
func configure_for_test(
	p_player_state: Node, p_game_data: Node, p_building_manager: Node = null,
	p_marriage_manager: Node = null
) -> void:
	_player_state = p_player_state
	_game_data = p_game_data
	_test_building_manager = p_building_manager
	_test_marriage_manager = p_marriage_manager


func get_effective_deterrence() -> int:
	return _effective_deterrence()


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
		if not _thief_is_spouse() and not _thief_got_mercy():
			execute_theft()
	_maybe_trigger_dynamic_raid(day)


func execute_raid() -> void:
	var raids: Array = _game_data.get_scripted_raids("spring")
	if raids.is_empty():
		return
	_spawn_raid((raids[0] as Dictionary).get("enemies", []), false)


## Dynamic raids use the weighted enemy pool; the night roll adds flavor text
## and night_raid_size_bonus enemies (see the class docstring - flavor only).
func execute_dynamic_raid() -> void:
	var cfg: Dictionary = _game_data.raids_cfg
	var pool: Array = cfg.get("dynamic_enemy_pool", [])
	if pool.is_empty():
		return
	var is_night := _rng.randf() < float(cfg.get("night_raid_flavor_chance", 0.0))
	var size := _rng.randi_range(
		int(cfg.get("dynamic_raid_size_min", 2)),
		int(cfg.get("dynamic_raid_size_max", 4)))
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
	var total := 0
	for entry: Variant in enemies_list:
		total += int((entry as Dictionary).get("count", 0))
	dynamic_raid_triggered.emit(total)
	_spawn_raid(enemies_list, is_night)


## Shared spawn path for scripted and dynamic raids.
func _spawn_raid(enemies_list: Array, is_night: bool) -> void:
	# ADR-034 (Sprint 15b): the farm is the raid target. When the player is
	# outside Fallowfield the raid is message-only - no deferred-raid state,
	# no save impact (the guide's flagged, accepted edge case).
	var zone_manager := get_node_or_null("/root/ZoneManager")
	if zone_manager != null and zone_manager.has_method("get_active_zone_id") \
			and str(zone_manager.get_active_zone_id()) != "fallowfield":
		raid_message.emit("Bandits prowl your farm while you are away - you hear only rumours.")
		return
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
			enemy.enemy_died.connect(_on_enemy_defeated_for_xp)
	if _combat_manager != null \
			and not _combat_manager.player_knocked_out.is_connected(_on_player_knocked_out_during_raid):
		_combat_manager.player_knocked_out.connect(_on_player_knocked_out_during_raid, CONNECT_ONE_SHOT)


func _weighted_pick_enemy(pool: Array) -> String:
	var total := 0.0
	for e: Variant in pool:
		total += float((e as Dictionary).get("weight", 0))
	if total <= 0.0:
		return ""
	var roll := _rng.randf() * total
	var cumulative := 0.0
	for e: Variant in pool:
		var entry := e as Dictionary
		cumulative += float(entry.get("weight", 0))
		if roll < cumulative:
			return str(entry.get("type", ""))
	return ""


## Deterrence gate: below min_deterrence_no_raid, the gap ratio scales each
## day's trigger chance, so defenses are a measurable safety margin.
func _maybe_trigger_dynamic_raid(day: int) -> void:
	if _raid_active:
		return
	var cfg: Dictionary = _game_data.raids_cfg
	if day < int(cfg.get("dynamic_raid_earliest_day", 0)):
		return
	var min_det := int(cfg.get("min_deterrence_no_raid", 30))
	var effective := _effective_deterrence()
	if effective >= min_det:
		return
	var gap_ratio := float(min_det - effective) / float(maxi(1, min_det))
	var chance := float(cfg.get("dynamic_raid_chance_per_day", 0.0)) * (0.5 + gap_ratio)
	if _rng.randf() < chance:
		execute_dynamic_raid()


func execute_theft() -> void:
	var thief_id := _find_thief_id()
	var coin_stolen := 30
	var actual_lost := mini(coin_stolen, int(_player_state.get("money")))
	if actual_lost > 0:
		_player_state.spend_money(actual_lost)
	var event := {
		"day": 19,
		"villager_id": thief_id,
		"coin_stolen": actual_lost,
		"resolved": false,
	}
	_player_state.theft_events.append(event)
	theft_occurred.emit(actual_lost, "Something was stolen overnight! You lost %d coin." % actual_lost)
	var inv := get_node_or_null("/root/InvestigationManager")
	if inv != null and not thief_id.is_empty():
		inv.start_investigation(thief_id)


## villagers.json traits are the single source of truth for who the thief is.
func _find_thief_id() -> String:
	for id: String in _game_data.get_all_villager_ids():
		var traits: Array = _game_data.get_villager(id).get("traits", [])
		if traits.has("thief"):
			return id
	return ""


## world_bible.md Block 8.4: "if the player marries Marta, the thefts end
## silently... no reputation tick, no court record." The scripted day-19
## theft (execute_theft, above) is a one-time event, not a recurring roll,
## so this is a single guard rather than a per-day check.
func _thief_is_spouse() -> bool:
	var thief_id := _find_thief_id()
	if thief_id.is_empty():
		return false
	var mm: Node = _test_marriage_manager
	if mm == null:
		mm = get_node_or_null("/root/MarriageManager")
	return mm != null and mm.has_method("is_spouse") and mm.is_spouse(thief_id)


## Mercy path guard: InvestigationManager.show_mercy sets
## "investigation.showed_mercy_<thief_id>" on PlayerState. Mirrors the
## marriage guard above - a single boolean check, no new simulation layer.
func _thief_got_mercy() -> bool:
	var thief_id := _find_thief_id()
	if thief_id.is_empty():
		return false
	return _player_state != null and _player_state.has_method("has_event_flag") \
		and _player_state.has_event_flag("investigation.showed_mercy_%s" % thief_id)


## Effective deterrence: raw value + Sprint 9's fence bonus + owned defense
## items (presence, not quantity - two guard dogs don't stack).
func _effective_deterrence() -> int:
	var total := int(_player_state.get("raid_deterrence"))
	var bm := _test_building_manager
	if bm == null:
		bm = get_node_or_null("/root/BuildingManager")
	if bm != null:
		total += int(bm.get_deterrence_bonus())
	if _game_data != null:
		for item_id: String in _game_data.get_all_item_ids():
			var item: Dictionary = _game_data.get_item(item_id)
			if str(item.get("type", "")) == "defense" and int(item.get("deterrence_bonus", 0)) > 0:
				if int(_player_state.get_item_count(item_id)) > 0:
					total += int(item.get("deterrence_bonus", 0))
	return total


func _generate_spawn_positions(center: Vector2, count: int) -> Array:
	var positions: Array = []
	for _i in range(count):
		var angle := _rng.randf_range(0.0, TAU)
		var dist := _rng.randf_range(300.0, 500.0)
		positions.append(center + Vector2.RIGHT.rotated(angle) * dist)
	return positions


func _on_raid_enemy_resolved(_enemy: Enemy) -> void:
	_active_enemies.erase(_enemy)
	_check_raid_resolution()


func _on_enemy_defeated_for_xp() -> void:
	var skill := get_node_or_null("/root/SkillManager")
	if skill != null:
		skill.add_xp_for("combat", "defeat_enemy")


func _on_player_knocked_out_during_raid(_cause: String) -> void:
	if not _raid_active:
		return
	_raid_active = false
	raid_resolved.emit(false)
	_cleanup_enemies()


func _check_raid_resolution() -> void:
	if not _raid_active:
		return
	if not _active_enemies.is_empty():
		return
	_raid_active = false
	var gain := int(_game_data.get_raid_settings().get("deterrence_gain_per_victory", 0))
	_player_state.raid_deterrence = int(_player_state.get("raid_deterrence")) + gain
	raid_resolved.emit(true)
	_cleanup_enemies()


func _cleanup_enemies() -> void:
	for enemy: Variant in _active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_active_enemies.clear()


## Sprint 15b (DeepSeek Pro consult recommendation): if the player walks off
## the farm mid-raid, the spawned enemies must not leak into another zone.
## Despawns them and resolves message-only - no deterrence reward, no
## penalty, no deferred state - the same accepted edge-case policy as raids
## that fire while the player is elsewhere. Returns true if an active raid
## was dismissed.
func dismiss_raid_if_active() -> bool:
	if not _raid_active:
		return false
	_raid_active = false
	_cleanup_enemies()
	raid_message.emit("The bandits scatter as you leave the farm.")
	return true
