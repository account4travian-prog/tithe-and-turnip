extends Node

## Player progression state: quality-stacked inventory, energy, money, health,
## equipped tool/weapon, combat + season tracking. Serializable via
## to_dict/from_dict; SaveManager owns persistence.
## Energy exhaustion follows a same-day ladder (ADR-016): the first failure
## skips 2 hours and recovers a little energy; the second forces a full sleep.
## _exhaustion_count_today is intentionally NOT persisted - saves happen at
## sleep, which resets it via day_passed.

signal energy_changed(current: float, max_energy: float)
signal money_changed(amount: int)
signal inventory_changed
signal equipped_changed(tool_id: String)
signal health_changed(current: int, max_health: int)
signal weapon_changed(weapon_id: String)
signal knocked_out(cause: String)

var _exhaustion_count_today := 0
var _time_manager_ref: Node = null  # test seam; live games use the autoload
var _game_data_ref: Node = null     # test seam; live games use the autoload

var energy := 100.0
var max_energy := 100.0
var health := 50
var max_health := 50
var money := 0
var equipped_tool_id := ""
var equipped_weapon_id := ""
var arrow_count := 0
var pass_out_count := 0
var raid_deterrence := 0
## Combat injuries persist past sleep (ADR-026): a combat pass-out sets this to
## player.json's wound_recovery_days, and it ticks down once per day_passed.
var wound_days_remaining := 0
var total_crops_harvested := 0
var total_coins_earned := 0
var theft_events: Array = []
var inventory: Dictionary = {}
## Persistent flags for one-time world events (E12 rare forage finds today;
## E4's dialogue conditions read the same list later). Namespaced strings
## like "forage.gathered_morel" - set-once, never cleared.
var event_flags: Array[String] = []


func _ready() -> void:
	var game_data = get_node_or_null("/root/GameData")
	if game_data != null and not game_data.player_cfg.is_empty():
		max_energy = float(game_data.player_cfg.get("max_energy", 100.0))
		energy = max_energy
		max_health = int(game_data.player_cfg.get("max_health", 50))
		health = max_health
		money = int(game_data.player_cfg.get("start_money", 0))
		var starter: Dictionary = game_data.player_cfg.get("starter_items", {})
		for item_id: Variant in starter:
			add_item(str(item_id), int(starter[item_id]))
	if equipped_tool_id.is_empty() and get_item_count("hoe_wood") > 0:
		set_equipped_tool("hoe_wood")
	var tm = get_node_or_null("/root/TimeManager")
	if tm != null:
		if not tm.day_passed.is_connected(_on_day_passed):
			tm.day_passed.connect(_on_day_passed)
		if not tm.forced_collapse.is_connected(_on_forced_collapse):
			tm.forced_collapse.connect(_on_forced_collapse)


## Explicit-injection seam for off-tree test suites (mirrors
## SaveManager.set_farm_grid_ref). Live games resolve the autoload normally.
func set_time_manager_ref(tm: Node) -> void:
	_time_manager_ref = tm


func _time_manager() -> Node:
	if _time_manager_ref != null:
		return _time_manager_ref
	return get_node_or_null("/root/TimeManager")


## Explicit-injection seam for off-tree test suites (mirrors the time-manager
## seam above). Live games resolve the autoload normally.
func set_game_data_ref(gd: Node) -> void:
	_game_data_ref = gd


func _game_data() -> Node:
	if _game_data_ref != null:
		return _game_data_ref
	return get_node_or_null("/root/GameData")


func add_item(item_id: String, count := 1, quality := "common") -> bool:
	if count <= 0:
		return false
	var stack: Dictionary = inventory.get(item_id, {})
	stack[str(quality)] = int(stack.get(str(quality), 0)) + count
	inventory[item_id] = stack
	inventory_changed.emit()
	return true


func remove_item(item_id: String, count := 1, quality := "common") -> bool:
	var stack: Dictionary = inventory.get(item_id, {})
	var have := int(stack.get(str(quality), 0))
	if have < count:
		return false
	if have == count:
		stack.erase(str(quality))
	else:
		stack[str(quality)] = have - count
	if stack.is_empty():
		inventory.erase(item_id)
	else:
		inventory[item_id] = stack
	inventory_changed.emit()
	return true


func has_item(item_id: String, count := 1, quality := "common") -> bool:
	return get_quality_count(item_id, quality) >= count


func get_item_count(item_id: String) -> int:
	var total := 0
	var stack: Dictionary = inventory.get(item_id, {})
	for quality: Variant in stack:
		total += int(stack[quality])
	return total


func get_quality_count(item_id: String, quality: String) -> int:
	var stack: Dictionary = inventory.get(item_id, {})
	return int(stack.get(quality, 0))


func list_inventory() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item_id: Variant in inventory:
		var stack: Dictionary = inventory[item_id]
		for quality: Variant in stack:
			out.append({
				"item_id": str(item_id),
				"quality": str(quality),
				"count": int(stack[quality]),
			})
	return out


func consume_energy(amount: float) -> bool:
	if energy < amount:
		trigger_exhaustion()
		return false
	energy -= amount
	energy_changed.emit(energy, max_energy)
	return true


## Same-day exhaustion ladder: the first knock-out skips ahead 2 hours and
## grants the data-driven recovery energy; a second one the same day forces a
## full sleep to the next morning instead of another skip.
func trigger_exhaustion() -> void:
	_exhaustion_count_today += 1
	apply_pass_out_penalty("exhaustion")
	var game_data = get_node_or_null("/root/GameData")
	var recover_hours := 2
	var recover_energy := 20.0
	if game_data != null:
		recover_hours = int(game_data.player_cfg.get("exhaustion_recover_hours", 2))
		recover_energy = float(game_data.player_cfg.get("exhaustion_recover_energy", 20))
	var tm = _time_manager()
	if _exhaustion_count_today >= 2:
		if tm != null:
			tm.sleep_to_next_day()
		_exhaustion_count_today = 0
	elif tm != null:
		tm.advance_hours(recover_hours, false)
	energy = clampf(recover_energy, 0.0, max_energy)
	energy_changed.emit(energy, max_energy)


## Sleep restores a data-driven FRACTION of max energy (not a full refill) and
## regenerates health. heal() emits health_changed itself - do not re-emit.
func sleep_restore() -> void:
	var game_data = get_node_or_null("/root/GameData")
	var fraction := 0.6
	var regen := 15
	if game_data != null:
		fraction = float(game_data.player_cfg.get("sleep_energy_restore_fraction", 0.6))
		regen = int(game_data.player_cfg.get("sleep_health_regen", 15))
	# ADR-023: a completed cottage upgrade adds a data-driven fraction on top
	# of the base restore (0.15 from buildings.json - same unit as the base).
	var bm = get_node_or_null("/root/BuildingManager")
	if bm != null:
		fraction += bm.get_sleep_bonus_fraction()
	energy = clampf(energy + max_energy * fraction, 0.0, max_energy)
	energy_changed.emit(energy, max_energy)
	heal(regen)


func restore_energy(amount: float) -> void:
	energy = clampf(energy + amount, 0.0, max_energy)
	energy_changed.emit(energy, max_energy)


func take_damage(amount: int) -> void:
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)


func heal(amount: int) -> void:
	health = mini(max_health, health + amount)
	health_changed.emit(health, max_health)


func set_equipped_tool(tool_id: String) -> void:
	equipped_tool_id = tool_id
	equipped_changed.emit(tool_id)


func set_equipped_weapon(weapon_id: String) -> void:
	equipped_weapon_id = weapon_id
	weapon_changed.emit(weapon_id)


func record_harvest(count: int) -> void:
	total_crops_harvested += count


func apply_pass_out_penalty(cause: String) -> void:
	pass_out_count += 1
	var game_data = get_node_or_null("/root/GameData")
	var loss_pct := 0.2
	var health_floor := 10
	if game_data != null:
		loss_pct = float(game_data.player_cfg.get("pass_out_money_loss_pct", 0.2))
		health_floor = int(game_data.player_cfg.get("pass_out_health_floor", 10))
	var lost := int(money * loss_pct)
	money -= lost
	health = health_floor
	money_changed.emit(money)
	health_changed.emit(health, max_health)
	knocked_out.emit(cause)
	# Only losing a fight wounds you - exhaustion and forced collapse don't.
	if cause == "combat":
		var recovery_days := 1
		if game_data != null:
			recovery_days = int(game_data.player_cfg.get("wound_recovery_days", 1))
		wound_days_remaining = recovery_days


func _on_day_passed(_day: int, _season: String, _year: int) -> void:
	_exhaustion_count_today = 0
	wound_days_remaining = maxi(0, wound_days_remaining - 1)


func _on_forced_collapse() -> void:
	apply_pass_out_penalty("exhausted_day")


func eat(item_id: String) -> bool:
	var game_data = _game_data()
	var item_def: Dictionary = {}
	if game_data != null:
		item_def = game_data.get_item(item_id)
	if item_def.is_empty() or str(item_def.get("type", "")) != "food":
		return false
	for quality: String in ["common", "fine", "choice"]:
		if not remove_item(item_id, 1, quality):
			continue
		var mult := 1.0
		var tier: Dictionary = game_data.get_quality_tier(quality)
		if not tier.is_empty():
			mult = float(tier.get("energy_mult", 1.0))
		restore_energy(float(item_def.get("energy_base", 0.0)) * mult)
		return true
	return false


func set_event_flag(flag: String) -> void:
	if not event_flags.has(flag):
		event_flags.append(flag)


func has_event_flag(flag: String) -> bool:
	return event_flags.has(flag)


func add_money(amount: int) -> void:
	money += amount
	if amount > 0:
		total_coins_earned += amount
	money_changed.emit(money)


func spend_money(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	money_changed.emit(money)
	return true


func to_dict() -> Dictionary:
	var inventory_out: Array = []
	for item_id: Variant in inventory:
		var stack: Dictionary = inventory[item_id]
		for quality: Variant in stack:
			inventory_out.append({
				"item_id": str(item_id),
				"quality": str(quality),
				"count": int(stack[quality]),
			})
	return {
		"energy": energy,
		"max_energy": max_energy,
		"health": health,
		"max_health": max_health,
		"money": money,
		"equipped_tool_id": equipped_tool_id,
		"equipped_weapon_id": equipped_weapon_id,
		"arrow_count": arrow_count,
		"pass_out_count": pass_out_count,
		"raid_deterrence": raid_deterrence,
		"wound_days_remaining": wound_days_remaining,
		"total_crops_harvested": total_crops_harvested,
		"total_coins_earned": total_coins_earned,
		"theft_events": theft_events.duplicate(),
		"inventory": inventory_out,
		"event_flags": event_flags.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	energy = float(data.get("energy", max_energy))
	max_energy = float(data.get("max_energy", 100.0))
	health = int(data.get("health", max_health))
	max_health = int(data.get("max_health", 50))
	money = int(data.get("money", 0))
	equipped_tool_id = str(data.get("equipped_tool_id", ""))
	equipped_weapon_id = str(data.get("equipped_weapon_id", ""))
	arrow_count = int(data.get("arrow_count", 0))
	pass_out_count = int(data.get("pass_out_count", 0))
	raid_deterrence = int(data.get("raid_deterrence", 0))
	wound_days_remaining = int(data.get("wound_days_remaining", 0))
	total_crops_harvested = int(data.get("total_crops_harvested", 0))
	total_coins_earned = int(data.get("total_coins_earned", 0))
	theft_events = (data.get("theft_events", []) as Array).duplicate()
	event_flags.clear()
	for flag: Variant in (data.get("event_flags", []) as Array):
		event_flags.append(str(flag))
	inventory = {}
	var inv: Variant = data.get("inventory", {})
	if inv is Dictionary:
		for key: Variant in inv:
			add_item(str(key), int(inv[key]), "common")
	elif inv is Array:
		for entry: Variant in inv:
			var e := entry as Dictionary
			add_item(str(e.get("item_id", "")), int(e.get("count", 0)), str(e.get("quality", "common")))
	if equipped_tool_id.is_empty() and get_item_count("hoe_wood") > 0:
		equipped_tool_id = "hoe_wood"
	energy_changed.emit(energy, max_energy)
	money_changed.emit(money)
	inventory_changed.emit()
	equipped_changed.emit(equipped_tool_id)
	weapon_changed.emit(equipped_weapon_id)
	health_changed.emit(health, max_health)
