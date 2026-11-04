class_name ToolManager
extends Node

## Mediates tool usage (hoe, watering can, spade, seeds, compost, bare-hand
## harvest). Reads the equipped item from PlayerState, consumes energy, and
## forwards actions to the FarmGrid. Watering-can water level is ephemeral
## (not saved).
## E12: the spade digs untilled cells via FarmGrid.dig_cell() - energy cost
## comes from the spade's own items.json entry, the same generic path every
## other tool already uses, not a separate forage.json lookup.
## E2: compost is type "material" (not "tool"), applied via
## FarmGrid.apply_compost() - the fertilize_amount comes from compost's own
## items.json entry.
## ADR-040 (spatial demesne chores): on tiles inside the stewards_demesne
## rect, the hoe and watering can only act as lord-tithe chores - gated by
## TitheManager.can_demesne_chore_at, forced through FarmGrid.till_tile's
## ownership bypass, and completed through
## TitheManager.complete_demesne_tool_chore (which grants the chore credit,
## reputation, and labor XP). Demesne tiles grant no farming XP and never
## act outside the chore gate; ineligible demesne tiles are skipped so the
## player cannot till/water the lord's land for free or waste water on a
## rain-saturated field.

signal water_level_changed(current: float, capacity: float)

var _player_state: Node
var _farm_grid: Node
var _current_water: float = 0.0


func init(player_state: Node, farm_grid: Node) -> void:
	_player_state = player_state
	_farm_grid = farm_grid
	_refill_water_if_can()


## Sprint 15b: live re-wire used on zone crossings. Deliberately does NOT
## re-run init() - PlayerState and the current water level survive a
## transition; only the target grid changes.
func set_farm_grid(farm_grid: Node) -> void:
	_farm_grid = farm_grid


func use_tool(target_pos: Vector2i) -> bool:
	var tool_id := _equipped_tool_id()
	if tool_id.is_empty():
		if _farm_grid.is_harvestable(target_pos):
			var yields: Array = _farm_grid.harvest(target_pos)
			for entry: Variant in yields:
				var result := entry as Dictionary
				_player_state.add_item(str(result.get("item_id", "")), int(result.get("count", 0)))
			return true
		if _farm_grid.has_forage(target_pos):
			return _gather_forage(target_pos)
		return false
	var item: Dictionary = _item(tool_id)
	if item.is_empty():
		return false
	match str(item.get("type", "")):
		"tool":
			return _use_tool_item(item, target_pos)
		"seed":
			return _use_seed_item(item, target_pos)
		"material":
			return _use_material_item(item, target_pos)
		"weapon":
			return false
		_:
			return false


func refill_watering_can() -> bool:
	var tool_id := _equipped_tool_id()
	if tool_id.is_empty():
		return false
	var item: Dictionary = _item(tool_id)
	if item.is_empty() or str(item.get("tool_category", "")) != "watering_can":
		return false
	_current_water = float(item.get("capacity", 0))
	water_level_changed.emit(_current_water, float(item.get("capacity", 0)))
	return true


## Playtest fix: read-only mirror of refill_watering_can()'s precondition -
## whether a watering can is equipped at all (refilling to full is always
## valid regardless of the current level). Used by Player.get_interaction_info()
## so the "Fill Watering Can" text/highlight agree with what interacting would
## actually do - previously the text showed unconditionally at any well
## regardless of the equipped tool, while refill_watering_can() silently
## no-opped for anything else equipped.
func can_refill_watering_can() -> bool:
	var tool_id := _equipped_tool_id()
	if tool_id.is_empty():
		return false
	return str(_item(tool_id).get("tool_category", "")) == "watering_can"


func get_current_water() -> float:
	return _current_water


func get_current_capacity() -> float:
	var tool_id := _equipped_tool_id()
	if tool_id.is_empty():
		return 0.0
	var item: Dictionary = _item(tool_id)
	if item.is_empty() or str(item.get("tool_category", "")) != "watering_can":
		return 0.0
	return float(item.get("capacity", 0))


## Text-only wrapper over get_action_info() (playtest fix) - kept for the
## existing HUD call site. Superseded as the read-only seam by
## get_action_info(), which also reports validity and the affected tile(s)
## so the HUD text and the target indicator's highlight can never drift
## from each other or from use_tool()'s real branches.
func describe_action(target_pos: Vector2i) -> String:
	return str(get_action_info(target_pos).get("text", ""))


## Single read-only interaction dispatch (VSA-2, extended) - same priority
## chain and category checks use_tool() has, never mutates FarmGrid/
## PlayerState. Returns { "text": String, "valid": bool,
## "tiles": Array[Vector2i], "tile_valid": Dictionary (Vector2i -> bool) }.
## "valid" is the aggregate (would use_tool() actually do something);
## "tile_valid" is per-tile, since a multi-tile tool area (the iron hoe's
## line_3x1) can have some eligible tiles and some not.
func get_action_info(target_pos: Vector2i) -> Dictionary:
	var empty := {"text": "", "valid": false, "tiles": [] as Array[Vector2i], "tile_valid": {}}
	if _farm_grid == null:
		return empty
	var tool_id := _equipped_tool_id()
	if tool_id.is_empty():
		if _farm_grid.is_harvestable(target_pos):
			var crop_name: String = _farm_grid.get_crop_name(target_pos)
			var text := "Harvest %s" % crop_name if not crop_name.is_empty() else "Harvest"
			return {"text": text, "valid": true, "tiles": [target_pos] as Array[Vector2i], "tile_valid": {target_pos: true}}
		if _farm_grid.has_forage(target_pos):
			var text := "Gather %s" % _forage_name_at(target_pos)
			return {"text": text, "valid": true, "tiles": [target_pos] as Array[Vector2i], "tile_valid": {target_pos: true}}
		return {"text": "", "valid": false, "tiles": [target_pos] as Array[Vector2i], "tile_valid": {target_pos: false}}
	var item: Dictionary = _item(tool_id)
	if item.is_empty():
		return empty
	match str(item.get("type", "")):
		"tool":
			return _tool_item_info(item, target_pos)
		"seed":
			return _seed_item_info(item, target_pos)
		"material":
			return _material_item_info(item, target_pos)
		_:
			return {"text": "", "valid": false, "tiles": [target_pos] as Array[Vector2i], "tile_valid": {target_pos: false}}


func _tool_item_info(item: Dictionary, target_pos: Vector2i) -> Dictionary:
	match str(item.get("tool_category", "")):
		"hoe":
			return _hoe_info(item, target_pos)
		"watering_can":
			return _watering_can_info(item, target_pos)
		"spade":
			var ok: bool = _farm_grid.can_dig(target_pos)
			var text := "Dig" if ok else "Cannot Dig Here"
			var afford := float(_player_state.get("energy")) >= _energy_cost(item)
			return {"text": text, "valid": ok and afford, "tiles": [target_pos] as Array[Vector2i], "tile_valid": {target_pos: ok}}
		_:
			return {"text": "", "valid": false, "tiles": [target_pos] as Array[Vector2i], "tile_valid": {target_pos: false}}


## ADR-040-aware: mirrors _use_hoe's demesne/normal split per tile so a
## line_3x1 swing across a demesne boundary highlights each tile by what it
## will actually do, not one aggregate guess.
func _hoe_info(item: Dictionary, target_pos: Vector2i) -> Dictionary:
	var tiles: Array[Vector2i] = []
	var tile_valid: Dictionary = {}
	var any_valid := false
	for off: Vector2i in _area_offsets(str(item.get("area_shape", "single"))):
		var t := target_pos + off
		tiles.append(t)
		var ok: bool = _can_demesne_chore("till_demesne", t) if _is_demesne_tile(t) else _farm_grid.can_till(t)
		tile_valid[t] = ok
		any_valid = any_valid or ok
	var afford := float(_player_state.get("energy")) >= _energy_cost(item)
	return {"text": "Till the Soil", "valid": any_valid and afford, "tiles": tiles, "tile_valid": tile_valid}


func _watering_can_info(item: Dictionary, target_pos: Vector2i) -> Dictionary:
	var tiles: Array[Vector2i] = []
	var tile_valid: Dictionary = {}
	var any_valid := false
	for off: Vector2i in _area_offsets(str(item.get("area_shape", "single"))):
		var t := target_pos + off
		tiles.append(t)
		var ok: bool = _can_demesne_chore("water_demesne", t) if _is_demesne_tile(t) else _farm_grid.is_tilled(t)
		tile_valid[t] = ok
		any_valid = any_valid or ok
	if _current_water < float(item.get("water_amount", 0)):
		return {"text": "Watering Can Empty", "valid": false, "tiles": tiles, "tile_valid": tile_valid}
	var crop_name: String = _farm_grid.get_crop_name(target_pos)
	var text := "Water %s" % crop_name if not crop_name.is_empty() else "Water the Soil"
	var afford := float(_player_state.get("energy")) >= _energy_cost(item)
	return {"text": text, "valid": any_valid and afford, "tiles": tiles, "tile_valid": tile_valid}


func _seed_item_info(item: Dictionary, target_pos: Vector2i) -> Dictionary:
	var seed_id := str(item.get("id", ""))
	var crop_id := str(item.get("crop_id", ""))
	var ok: bool = _player_state.has_item(seed_id) and _farm_grid.can_plant(target_pos, crop_id) == 0
	return {"text": "Plant %s" % str(item.get("name", "Seed")), "valid": ok,
		"tiles": [target_pos] as Array[Vector2i], "tile_valid": {target_pos: ok}}


func _material_item_info(item: Dictionary, target_pos: Vector2i) -> Dictionary:
	if not item.has("fertilize_amount"):
		return {"text": "", "valid": false, "tiles": [target_pos] as Array[Vector2i], "tile_valid": {target_pos: false}}
	var material_id := str(item.get("id", ""))
	var ok: bool = _player_state.has_item(material_id) and _farm_grid.is_tilled(target_pos)
	return {"text": "Apply %s" % str(item.get("name", "Compost")), "valid": ok,
		"tiles": [target_pos] as Array[Vector2i], "tile_valid": {target_pos: ok}}


func _forage_name_at(target_pos: Vector2i) -> String:
	var cell: Dictionary = _farm_grid.get_cell(target_pos)
	var forage_item := _item(str(cell.get("forage_item_id", "")))
	return str(forage_item.get("name", "Wild Plant"))


func _use_tool_item(item: Dictionary, target_pos: Vector2i) -> bool:
	var category := str(item.get("tool_category", ""))
	var skill := _autoload("SkillManager")
	var energy_cost := _energy_cost(item)
	var offsets := _area_offsets(str(item.get("area_shape", "single")))
	match category:
		"hoe":
			return _use_hoe(item, target_pos, offsets, energy_cost, skill)
		"watering_can":
			return _use_watering_can(item, target_pos, offsets, energy_cost, skill)
		"spade":
			if not _farm_grid.can_dig(target_pos):
				return false
			if not _player_state.consume_energy(energy_cost):
				return false
			return _dig(target_pos, skill)
		_:
			return false


## ADR-040: splits the hoe's area targets into demesne (chore-gated, forced)
## and ordinary (ownership-gated) tiles before spending energy, so a swing
## aimed entirely at ineligible demesne ground is a no-op rather than a
## wasted charge. Demesne tiles never grant farming XP - the labor XP comes
## from the chore completion itself.
func _use_hoe(item: Dictionary, target_pos: Vector2i, offsets: Array[Vector2i], energy_cost: float, skill: Node) -> bool:
	var demesne_targets: Array[Vector2i] = []
	var normal_targets: Array[Vector2i] = []
	for off: Vector2i in offsets:
		var t := target_pos + off
		if _is_demesne_tile(t):
			if _can_demesne_chore("till_demesne", t):
				demesne_targets.append(t)
		else:
			normal_targets.append(t)
	if demesne_targets.is_empty() and normal_targets.is_empty():
		return false
	if not _player_state.consume_energy(energy_cost):
		return false
	var any_success := false
	for t: Vector2i in normal_targets:
		if _farm_grid.till_tile(t):
			any_success = true
			if skill != null:
				skill.add_xp_for("farming", "till_tile")
	var demesne_done: Array[Vector2i] = []
	for t: Vector2i in demesne_targets:
		# force=true: the steward's land is not owned by the player, and
		# ADR-023's force bypass exists for exactly this call-site class.
		if _farm_grid.till_tile(t, true):
			any_success = true
			demesne_done.append(t)
	_notify_demesne_tool_chores("till_demesne", demesne_done, energy_cost)
	return any_success


## ADR-040: same split for the watering can. On a rain day every tilled
## demesne tile sits at moisture 100, so no tile clears the needs-water gate
## and the swing is a no-op - the exploit fix is structural (tile moisture),
## not a weather special case.
func _use_watering_can(item: Dictionary, target_pos: Vector2i, offsets: Array[Vector2i], energy_cost: float, skill: Node) -> bool:
	var water_usage := float(item.get("water_amount", 0))
	var demesne_targets: Array[Vector2i] = []
	var normal_targets: Array[Vector2i] = []
	for off: Vector2i in offsets:
		var t := target_pos + off
		if _is_demesne_tile(t):
			if _can_demesne_chore("water_demesne", t):
				demesne_targets.append(t)
		else:
			normal_targets.append(t)
	if demesne_targets.is_empty() and normal_targets.is_empty():
		return false
	if _current_water < water_usage:
		return false
	if not _player_state.consume_energy(energy_cost):
		return false
	_current_water -= water_usage
	water_level_changed.emit(_current_water, float(item.get("capacity", 0)))
	var any_success := false
	for t: Vector2i in normal_targets:
		if _farm_grid.water_tile(t, water_usage):
			any_success = true
			if skill != null:
				skill.add_xp_for("farming", "water_tile")
	var demesne_done: Array[Vector2i] = []
	for t: Vector2i in demesne_targets:
		if _farm_grid.water_tile(t, water_usage):
			any_success = true
			demesne_done.append(t)
	_notify_demesne_tool_chores("water_demesne", demesne_done, energy_cost)
	return any_success


## One chore completion per successfully worked demesne tile, with the
## action's energy cost split evenly across the successes so the HUD's
## "-N energy" per completion sums to what the tool actually spent.
func _notify_demesne_tool_chores(chore_id: String, positions: Array[Vector2i], energy_cost: float) -> void:
	if positions.is_empty():
		return
	var tm := _autoload("TitheManager")
	if tm == null or not tm.has_method("complete_demesne_tool_chore"):
		return
	var per_tile := energy_cost / float(positions.size())
	for pos: Vector2i in positions:
		# Explicit bool, not := - tm is typed Node and the method returns
		# Variant through the base-class reference (project trap 12.1).
		var done: bool = bool(tm.complete_demesne_tool_chore(chore_id, pos, per_tile))
		if not done:
			push_warning("[ToolManager] demesne chore completion refused after a successful %s" % chore_id)


func _dig(target_pos: Vector2i, skill: Node) -> bool:
	var result: Dictionary = _farm_grid.dig_cell(target_pos)
	if result.is_empty():
		return false
	var item_id := str(result.get("item_id", ""))
	if not item_id.is_empty():
		_player_state.add_item(item_id, int(result.get("count", 0)))
		if bool(result.get("is_rare", false)):
			var event_bus := _autoload("EventBus")
			if event_bus != null:
				event_bus.rare_item_gathered.emit(item_id)
			_player_state.set_event_flag("forage.gathered_%s" % item_id)
		if skill != null:
			skill.add_xp_for("foraging", "dig")
	return true


func _gather_forage(target_pos: Vector2i) -> bool:
	var game_data := _game_data()
	var base_cost := 2.0
	if game_data != null:
		base_cost = float(game_data.get_forage_config().get("gather_energy_cost", 2))
	var skill := _autoload("SkillManager")
	var mult := float(skill.get_effect("foraging", "gather_energy_cost_mult", 1.0)) if skill != null else 1.0
	if not _player_state.consume_energy(base_cost * mult):
		return false
	var result: Dictionary = _farm_grid.gather_forage(target_pos)
	if result.is_empty():
		return false
	var count := int(result.get("count", 0))
	if skill != null:
		count += int(skill.get_effect("foraging", "yield_bonus", 0))
		skill.add_xp_for("foraging", "gather")
	_player_state.add_item(str(result.get("item_id", "")), count)
	return true


func _use_seed_item(item: Dictionary, target_pos: Vector2i) -> bool:
	var seed_id := str(item.get("id", ""))
	if not _player_state.has_item(seed_id):
		return false
	var crop_id := str(item.get("crop_id", ""))
	var result: int = _farm_grid.plant(target_pos, crop_id)
	if result == 0:
		_player_state.remove_item(seed_id, 1)
		var game_data := _game_data()
		var plant_energy := 0
		if game_data != null:
			plant_energy = int(game_data.player_cfg.get("plant_energy_cost", 0))
		_player_state.consume_energy(float(plant_energy))
		return true
	return false


## E2: only compost (a material with a fertilize_amount) is usable this way
## today. Other materials (flint, wood, spoiled_crop) can be equipped like
## any inventory item but have no cell action - this returns false for them,
## the same "swing and miss" tolerance every other tool action already has.
func _use_material_item(item: Dictionary, target_pos: Vector2i) -> bool:
	if not item.has("fertilize_amount"):
		return false
	var material_id := str(item.get("id", ""))
	if not _player_state.has_item(material_id):
		return false
	if not _farm_grid.apply_compost(target_pos, float(item.get("fertilize_amount", 0))):
		return false
	_player_state.remove_item(material_id, 1)
	return true


## Energy cost for `item`'s tool action, including the farming skill's
## tool_energy_cost_mult and the ADR-026 wound tax - extracted (playtest fix)
## so the mutation path (_use_tool_item) and the read-only preview
## (get_action_info, via _hoe_info/_watering_can_info/_tool_item_info's spade
## branch) can never compute this differently.
func _energy_cost(item: Dictionary) -> float:
	var skill := _autoload("SkillManager")
	var energy_mult := float(skill.get_effect("farming", "tool_energy_cost_mult", 1.0)) if skill != null else 1.0
	var wound_mult := 1.2 if int(_player_state.get("wound_days_remaining")) > 0 else 1.0
	return float(item.get("energy_cost", 0)) * energy_mult * wound_mult


func _area_offsets(shape: String) -> Array[Vector2i]:
	match shape:
		"line_3x1":
			return [Vector2i(-1, 0), Vector2i.ZERO, Vector2i(1, 0)]
		_:
			return [Vector2i.ZERO]


func _equipped_tool_id() -> String:
	if _player_state == null:
		return ""
	return str(_player_state.get("equipped_tool_id"))


func _game_data() -> Node:
	return _autoload("GameData")


## ADR-040: is this tile part of the lord's demesne? FarmGrid owns the rect
## (from GameData live, injected in tests), so this is a single-source query.
func _is_demesne_tile(pos: Vector2i) -> bool:
	if _farm_grid == null or not _farm_grid.has_method("is_demesne_tile"):
		return false
	return bool(_farm_grid.is_demesne_tile(pos))


func _can_demesne_chore(chore_id: String, pos: Vector2i) -> bool:
	var tm := _autoload("TitheManager")
	if tm == null or not tm.has_method("can_demesne_chore_at"):
		return false
	return bool(tm.can_demesne_chore_at(chore_id, pos))


func _refill_water_if_can() -> void:
	var tool_id := _equipped_tool_id()
	if tool_id.is_empty():
		_current_water = 0.0
		return
	var item: Dictionary = _item(tool_id)
	if item.is_empty() or str(item.get("tool_category", "")) != "watering_can":
		_current_water = 0.0
		return
	_current_water = float(item.get("capacity", 0))


func _item(item_id: String) -> Dictionary:
	var game_data := _game_data()
	if game_data == null:
		return {}
	return game_data.get_item(item_id)


## Resolves a singleton from the active SceneTree rather than from this node.
## ToolManager is intentionally instantiated off-tree by the hand-rolled test
## suites; Node.get_node_or_null("/root/...") emits an engine error from an
## off-tree node even though the desired test behavior is simply "no runtime
## autoload available." The active tree remains the canonical runtime source
## when this manager is attached during play, while tests receive a clean null.
func _autoload(name: String) -> Node:
	if not is_inside_tree():
		return null
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(name))
