extends Node

## Versioned JSON saves in user://. Autosave on sleep; versioned from day one
## (CLAUDE.md section 7). v4 adds the reputation block, v5 the combat block,
## v6 the farm-cell days_mature field, v7 the skills block + farm-cell forage
## fields, v8 the buildings/tenure block, v9 the reputation block's
## active_requests/daily_gift_count fields (Sprint 10), v10 the tithe block's
## manor-politics fields (pending offenses, corvee, price drift - Sprint 11),
## v11 the investigation block + player.wound_days_remaining (Sprint 12),
## v12 the crafting block's pending recipes (Sprint 13), v13 the animals
## block (Sprint 14), v14 farm-cell fertility + farm.daily_dig_count +
## player.event_flags (E1/E2/E12 - Phase 1 of the Spring Feature Expansion),
## v15 the dialogue block's once-per-day history (E4 - Phase 2, ADR-035),
## v16 the tithe block's crop_pressure + active_orders (E6 - Phase 3,
## ADR-037 - full supply-pressure pricing + town board orders), v17 the
## marriage block (ADR-031 realized) + the reputation block's
## pairwise_opinions/spouse_gift_count fields, v18 the tithe block's
## carrying_sheaves + each farm cell's demesne_sheaf (ADR-040 - spatial
## demesne chores; old saves default to no sheaf markers and the next day
## rollover replenishes the backlog), v19 the farm block's zone-keyed shape
## (ADR-034: current_zone/player_tile/zones wrapping every existing cell
## under fallowfield - developed in parallel with ADR-040 and renumbered
## from a colliding v18 to v19 at merge time).
## Migrations run in sequence.
## FarmGrid is NOT an autoload (it lives at /root/Main/FarmGrid) - the live
## reference arrives by explicit injection from main.gd, never a /root/ guess.

signal game_loaded

const SAVE_VERSION := 19

var _farm_grid_ref: Node = null

## Set by the title screen's "Return to the Farm" before changing scene;
## main.gd consumes it at the end of its _ready so the autosave applies after
## the farm grid exists. Empty = no pending load.
var pending_load := ""


func set_farm_grid_ref(farm_grid: Node) -> void:
	_farm_grid_ref = farm_grid


func _farm_grid() -> Node:
	if _farm_grid_ref != null:
		return _farm_grid_ref
	return get_node_or_null("/root/Main/FarmGrid")


func autosave_path() -> String:
	return "user://save_autosave.json"


func save_game(slot := "autosave") -> bool:
	return write_payload(build_payload(), "user://save_%s.json" % slot)


func load_game(slot := "autosave") -> bool:
	var path := "user://save_%s.json" % slot
	if not FileAccess.file_exists(path):
		return false
	var payload := read_payload(path)
	if payload.is_empty():
		return false
	apply_payload(payload)
	game_loaded.emit()
	return true


func build_payload() -> Dictionary:
	var payload := {"version": SAVE_VERSION}
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager != null:
		payload["time"] = time_manager.to_dict()
	var player = get_node_or_null("/root/PlayerState")
	if player != null:
		payload["player"] = player.to_dict()
	# ADR-034: when ZoneManager is registered, it owns the farm payload
	# (per-zone grids + current_zone/player_tile); the injected single-grid
	# fallback stays for off-tree tests and pre-15b boot orderings.
	var zone_manager = get_node_or_null("/root/ZoneManager")
	if zone_manager != null:
		payload["farm"] = zone_manager.to_dict()
	else:
		var farm = _farm_grid()
		if farm != null:
			payload["farm"] = farm.to_dict()
	var tithe = get_node_or_null("/root/TitheManager")
	if tithe != null:
		payload["tithe"] = tithe.serialize()
	var reputation = get_node_or_null("/root/ReputationManager")
	if reputation != null:
		payload["reputation"] = reputation.get_save_data()
	var skills = get_node_or_null("/root/SkillManager")
	if skills != null:
		payload["skills"] = skills.to_dict()
	var buildings = get_node_or_null("/root/BuildingManager")
	if buildings != null:
		payload["buildings"] = buildings.to_dict()
	var investigation = get_node_or_null("/root/InvestigationManager")
	if investigation != null:
		payload["investigation"] = investigation.to_dict()
	var crafting = get_node_or_null("/root/CraftingManager")
	if crafting != null:
		payload["crafting"] = crafting.to_dict()
	var animals = get_node_or_null("/root/AnimalManager")
	if animals != null:
		payload["animals"] = animals.to_dict()
	var dialogue = get_node_or_null("/root/DialogueManager")
	if dialogue != null:
		payload["dialogue"] = dialogue.to_dict()
	var marriage = get_node_or_null("/root/MarriageManager")
	if marriage != null:
		payload["marriage"] = marriage.serialize()
	return payload


func apply_payload(payload: Dictionary) -> void:
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager != null and payload.has("time"):
		time_manager.from_dict(payload["time"] as Dictionary)
	var player = get_node_or_null("/root/PlayerState")
	if player != null and payload.has("player"):
		player.from_dict(payload["player"] as Dictionary)
	# ADR-034: zones-shape payloads route through ZoneManager's per-zone
	# grids; flat payloads (single-grid test fixtures) use the injected ref.
	var zone_manager = get_node_or_null("/root/ZoneManager")
	if zone_manager != null and payload.has("farm"):
		zone_manager.from_dict(payload["farm"] as Dictionary)
	else:
		var farm = _farm_grid()
		if farm != null and payload.has("farm"):
			farm.from_dict(payload["farm"] as Dictionary)
	var tithe = get_node_or_null("/root/TitheManager")
	if tithe != null and payload.has("tithe"):
		tithe.deserialize(payload["tithe"] as Dictionary)
	var reputation = get_node_or_null("/root/ReputationManager")
	if reputation != null and payload.has("reputation"):
		reputation.load_save_data(payload["reputation"] as Dictionary)
	var skills = get_node_or_null("/root/SkillManager")
	if skills != null and payload.has("skills"):
		skills.from_dict(payload["skills"] as Dictionary)
	var buildings = get_node_or_null("/root/BuildingManager")
	if buildings != null and payload.has("buildings"):
		buildings.from_dict(payload["buildings"] as Dictionary)
	var investigation = get_node_or_null("/root/InvestigationManager")
	if investigation != null and payload.has("investigation"):
		investigation.from_dict(payload["investigation"] as Dictionary)
	var crafting = get_node_or_null("/root/CraftingManager")
	if crafting != null and payload.has("crafting"):
		crafting.from_dict(payload["crafting"] as Dictionary)
	var animals = get_node_or_null("/root/AnimalManager")
	if animals != null and payload.has("animals"):
		animals.from_dict(payload["animals"] as Dictionary)
	var dialogue = get_node_or_null("/root/DialogueManager")
	if dialogue != null and payload.has("dialogue"):
		dialogue.from_dict(payload["dialogue"] as Dictionary)
	var marriage = get_node_or_null("/root/MarriageManager")
	if marriage != null and payload.has("marriage"):
		marriage.deserialize(payload["marriage"] as Dictionary)


func write_payload(payload: Dictionary, path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[SaveManager] cannot write %s" % path)
		return false
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	return true


func read_payload(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("[SaveManager] invalid save JSON in %s" % path)
		return {}
	var version := int(parsed.get("version", 0))
	if version > SAVE_VERSION:
		push_error("[SaveManager] save version %d is newer than supported %d"
			% [version, SAVE_VERSION])
		return {}
	if version == 1:
		parsed = migrate_from_v1(parsed)
	if version <= 2:
		parsed = migrate_to_v3(parsed)
	if version <= 3:
		parsed = migrate_to_v4(parsed)
	if version <= 4:
		parsed = migrate_to_v5(parsed)
	if version <= 5:
		parsed = migrate_to_v6(parsed)
	if version <= 6:
		parsed = migrate_to_v7(parsed)
	if version <= 7:
		parsed = migrate_to_v8(parsed)
	if version <= 8:
		parsed = migrate_to_v9(parsed)
	if version <= 9:
		parsed = migrate_to_v10(parsed)
	if version <= 10:
		parsed = migrate_to_v11(parsed)
	if version <= 11:
		parsed = migrate_to_v12(parsed)
	if version <= 12:
		parsed = migrate_to_v13(parsed)
	if version <= 13:
		parsed = migrate_to_v14(parsed)
	if version <= 14:
		parsed = migrate_to_v15(parsed)
	if version <= 15:
		parsed = migrate_to_v16(parsed)
	if version <= 16:
		parsed = migrate_to_v17(parsed)
	if version <= 17:
		parsed = migrate_to_v18(parsed)
	if version <= 18:
		parsed = migrate_to_v19(parsed)
	return parsed


func migrate_from_v1(payload: Dictionary) -> Dictionary:
	var player: Dictionary = payload.get("player", {})
	if not player.has("health"):
		player["health"] = 50
	if not player.has("max_health"):
		player["max_health"] = 50
	if not player.has("tool_levels"):
		player["tool_levels"] = {"hoe": 1, "watering_can": 1}
	if not player.has("equipped_weapon"):
		player["equipped_weapon"] = ""
	if not player.has("arrow_count"):
		player["arrow_count"] = 0
	if not player.has("pass_out_count"):
		player["pass_out_count"] = 0
	if not player.has("reputation"):
		player["reputation"] = {
			"manor_standing": 50,
			"village_standing": 50,
			"church_standing": 50,
			"individual_opinions": {},
		}
	if not player.has("combat"):
		player["combat"] = {"raid_deterrence": 0, "theft_events": []}
	payload["player"] = player
	var farm: Dictionary = payload.get("farm", {})
	if not farm.has("storage"):
		farm["storage"] = []
	if farm.has("tiles") and not farm.has("cells"):
		var cells: Array = []
		for entry: Variant in farm.get("tiles", []):
			var t := entry as Dictionary
			cells.append({
				"x": int(t.get("x", 0)),
				"y": int(t.get("y", 0)),
				"tilled": bool(t.get("tilled", false)),
				"crop_id": str(t.get("crop_id", "")),
				"growth_progress": 0.0,
				"moisture": 0.0,
			})
		farm["cells"] = cells
	payload["farm"] = farm
	return payload


func migrate_to_v3(payload: Dictionary) -> Dictionary:
	payload["version"] = 3
	var player: Dictionary = payload.get("player", {})
	if not player.has("health"):
		player["health"] = 50
	if not player.has("max_health"):
		player["max_health"] = 50
	var inv: Variant = player.get("inventory", {})
	var inventory_out: Array = []
	if inv is Dictionary:
		for key: Variant in inv:
			inventory_out.append({"item_id": str(key), "quality": "common", "count": int(inv[key])})
	elif inv is Array:
		for entry: Variant in inv:
			var e := entry as Dictionary
			inventory_out.append({
				"item_id": str(e.get("item_id", "")),
				"quality": str(e.get("quality", "common")),
				"count": int(e.get("count", 0)),
			})
	player["inventory"] = inventory_out
	if not player.has("equipped_tool_id"):
		player["equipped_tool_id"] = ""
	payload["player"] = player
	if not payload.has("tithe"):
		payload["tithe"] = {
			"tithe_paid": 0.0,
			"daily_labor_credit": 0.0,
			"church_donations": 0.0,
		}
	var farm: Dictionary = payload.get("farm", {})
	if not farm.has("storage"):
		farm["storage"] = []
	payload["farm"] = farm
	return payload


func migrate_to_v4(payload: Dictionary) -> Dictionary:
	payload["version"] = 4
	if not payload.has("reputation"):
		payload["reputation"] = {
			"standings": {"manor": 0.0, "village": 0.0, "church": 0.0},
			"opinions": {},
		}
	return payload


func migrate_to_v5(payload: Dictionary) -> Dictionary:
	payload["version"] = 5
	var player: Dictionary = payload.get("player", {})
	if not player.has("equipped_weapon_id"):
		player["equipped_weapon_id"] = ""
	if not player.has("arrow_count"):
		player["arrow_count"] = 0
	if not player.has("pass_out_count"):
		player["pass_out_count"] = 0
	if not player.has("raid_deterrence"):
		player["raid_deterrence"] = 0
	if not player.has("total_crops_harvested"):
		player["total_crops_harvested"] = 0
	if not player.has("total_coins_earned"):
		player["total_coins_earned"] = 0
	if not player.has("theft_events"):
		player["theft_events"] = []
	payload["player"] = player
	return payload


func migrate_to_v6(payload: Dictionary) -> Dictionary:
	payload["version"] = 6
	var farm: Dictionary = payload.get("farm", {})
	var cells: Array = farm.get("cells", [])
	for entry: Variant in cells:
		var c := entry as Dictionary
		if not c.has("days_mature"):
			c["days_mature"] = 0
	payload["farm"] = farm
	return payload


func migrate_to_v7(payload: Dictionary) -> Dictionary:
	payload["version"] = 7
	if not payload.has("skills"):
		payload["skills"] = {"xp": {"farming": 0.0, "foraging": 0.0, "combat": 0.0, "labor": 0.0}}
	var farm: Dictionary = payload.get("farm", {})
	var cells: Array = farm.get("cells", [])
	for entry: Variant in cells:
		var c := entry as Dictionary
		if not c.has("forage_item_id"):
			c["forage_item_id"] = ""
			c["forage_yield"] = 0
	payload["farm"] = farm
	return payload


func migrate_to_v8(payload: Dictionary) -> Dictionary:
	payload["version"] = 8
	if not payload.has("buildings"):
		payload["buildings"] = {"placed": [], "rented": {}}
	return payload


## v9 carries no new top-level payload key: active requests and the daily
## gift count ride inside the existing "reputation" block, and
## ReputationManager's load_save_data defaults them via .get() patterns.
func migrate_to_v9(payload: Dictionary) -> Dictionary:
	payload["version"] = 9
	return payload


## v10 carries no new top-level payload key: the manor-politics state rides
## inside the existing "tithe" block, and TitheManager.deserialize defaults
## the fields via .get() patterns.
func migrate_to_v10(payload: Dictionary) -> Dictionary:
	payload["version"] = 10
	var tithe: Dictionary = payload.get("tithe", {})
	if not tithe.has("pending_offenses"):
		tithe["pending_offenses"] = []
		tithe["corvee_day"] = -1
		tithe["corvee_active"] = false
		tithe["corvee_chore_done"] = false
		tithe["price_drift"] = 1.0
	payload["tithe"] = tithe
	return payload


func migrate_to_v11(payload: Dictionary) -> Dictionary:
	payload["version"] = 11
	if not payload.has("investigation"):
		payload["investigation"] = {
			"true_suspect_id": "",
			"clues": [],
			"revealed": [],
			"open": false,
			"resolved": false,
		}
	var player: Dictionary = payload.get("player", {})
	if not player.has("wound_days_remaining"):
		player["wound_days_remaining"] = 0
	payload["player"] = player
	return payload


func migrate_to_v12(payload: Dictionary) -> Dictionary:
	payload["version"] = 12
	if not payload.has("crafting"):
		payload["crafting"] = {"pending": []}
	return payload


func migrate_to_v13(payload: Dictionary) -> Dictionary:
	payload["version"] = 13
	if not payload.has("animals"):
		payload["animals"] = {"animals": {}, "next_id": 1}
	return payload


## E1/E2/E12 (Phase 1 of the Spring Feature Expansion). Existing farm cells
## default to full fertility (100), not soil-tiered defaults - a migrated
## save gives the player the benefit of the doubt rather than penalizing
## land they were already farming under the old rules. New grids (never
## through this migration) get soil-tiered defaults from FarmGrid's own
## _default_cell. daily_dig_count and event_flags are new, empty state.
func migrate_to_v14(payload: Dictionary) -> Dictionary:
	payload["version"] = 14
	var farm: Dictionary = payload.get("farm", {})
	var cells: Array = farm.get("cells", [])
	for entry: Variant in cells:
		var c := entry as Dictionary
		if not c.has("fertility"):
			c["fertility"] = 100.0
	if not farm.has("daily_dig_count"):
		farm["daily_dig_count"] = 0
	payload["farm"] = farm
	var player: Dictionary = payload.get("player", {})
	if not player.has("event_flags"):
		player["event_flags"] = []
	payload["player"] = player
	return payload


## E4 (Phase 2, ADR-035). dialogue_history is owned by DialogueManager, not
## PlayerState - a new top-level block, same as crafting/skills/animals
## already are, not folded into "player".
func migrate_to_v15(payload: Dictionary) -> Dictionary:
	payload["version"] = 15
	if not payload.has("dialogue"):
		payload["dialogue"] = {}
	return payload


## E6 (Phase 3, ADR-037). crop_pressure and active_orders are owned by
## TitheManager like every other market field already in the "tithe" block -
## both default to empty state (no glut, no posted orders).
func migrate_to_v16(payload: Dictionary) -> Dictionary:
	payload["version"] = 16
	var tithe: Dictionary = payload.get("tithe", {})
	if not tithe.has("crop_pressure"):
		tithe["crop_pressure"] = {}
	if not tithe.has("active_orders"):
		tithe["active_orders"] = []
	payload["tithe"] = tithe
	return payload


## ADR-031 realized (marriage system) + the reputation-transfer rework.
## Old saves get an unmarried MarriageManager block. ReputationManager's
## opinions.has() now means "recorded" rather than "every villager id
## seeded at boot" (get_opinion() became non-mutating) - a zero-valued
## opinion carried over from an old save is indistinguishable from
## untouched and is dropped here, so apply_marriage_transfer() correctly
## skips it. A player who genuinely earned exactly 0 (e.g. +10 then -10)
## loses only that "touched" bit, not the displayed value - flagged as an
## accepted edge case, not a data-loss bug.
func migrate_to_v17(payload: Dictionary) -> Dictionary:
	payload["version"] = 17
	if not payload.has("marriage"):
		payload["marriage"] = {
			"spouse_id": "",
			"pending_candidate": "",
			"merchet_paid": false,
			"last_greeting_day": -1,
		}
	var reputation: Dictionary = payload.get("reputation", {})
	if not reputation.has("pairwise_opinions"):
		reputation["pairwise_opinions"] = {}
	if not reputation.has("spouse_gift_count"):
		reputation["spouse_gift_count"] = 0
	var opinions: Dictionary = reputation.get("opinions", {})
	var touched := {}
	for npc_id: Variant in opinions:
		if float(opinions[npc_id]) != 0.0:
			touched[npc_id] = opinions[npc_id]
	reputation["opinions"] = touched
	payload["reputation"] = reputation
	return payload


## ADR-040 (spatial demesne chores). Old saves default to no active carry
## and no stored-sheaf markers; the sheaf backlog is spatial (farm cells),
## so the v18 seed keeps the payload self-consistent and the next day
## rollover's replenishment fills the demesne from chores.json's cadence.
func migrate_to_v18(payload: Dictionary) -> Dictionary:
	payload["version"] = 18
	var tithe: Dictionary = payload.get("tithe", {})
	if not tithe.has("carrying_sheaves"):
		tithe["carrying_sheaves"] = 0
	payload["tithe"] = tithe
	var farm: Dictionary = payload.get("farm", {})
	var cells: Array = farm.get("cells", [])
	for entry: Variant in cells:
		var c := entry as Dictionary
		if not c.has("demesne_sheaf"):
			c["demesne_sheaf"] = false
	payload["farm"] = farm
	return payload


## Sprint 15a / ADR-034: the farm payload becomes zone-keyed. A v18 (or
## older) save with no zone data at all has every existing farm cell wrapped
## under fallowfield (the player's plot), the player's current zone defaults
## to fallowfield, the player spawns at Fallowfield's spawn tile, every
## existing building defaults to fallowfield, and all other zones start
## empty. The wrap must not rewrite cells - only relocate them, so every
## pre-existing cell field (tilled, crop_id, growth_progress, moisture,
## days_mature, forage_item_id, forage_yield, fertility, and ADR-040's
## demesne_sheaf where present) survives untouched. Numbered v19, not v18,
## because ADR-040's spatial-chore migration independently claimed v18 the
## same day - see this file's header comment.
func migrate_to_v19(payload: Dictionary) -> Dictionary:
	payload["version"] = 19
	var farm: Dictionary = payload.get("farm", {})
	if not farm.has("zones"):
		var cells: Array = farm.get("cells", [])
		farm["zones"] = {
			"fallowfield": {
				"cells": cells,
				"daily_dig_count": int(farm.get("daily_dig_count", 0)),
			},
		}
		farm.erase("cells")
		farm.erase("daily_dig_count")
	farm["current_zone"] = "fallowfield"
	farm["player_tile"] = {"x": 12, "y": 10}
	payload["farm"] = farm
	var buildings: Dictionary = payload.get("buildings", {})
	for entry: Variant in buildings.get("placed", []):
		var b := entry as Dictionary
		if not b.has("zone_id"):
			b["zone_id"] = "fallowfield"
	return payload
