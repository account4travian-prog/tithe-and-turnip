extends Node

## BuildingManager autoload - owns both buildings (footprint placement,
## material + coin cost, multi-day construction) and land tenure (rented
## strips from the manor). One autoload, not two, so this sprint's editor
## burden stays at a single registration (ADR-023). AUTOLOAD - no class_name.
##
## Tenure gates tilling ONLY (FarmGrid.till_tile); movement, foraging, and
## feature interaction stay free everywhere - the manor's wells/chapel/
## market are its own infrastructure, not the player's tillage.
##
## Renting a strip is a one-time, uncosted claim (tenure.json v2, follow-up
## to ADR-038/X13): a rented strip was previously ALSO billed a recurring
## per-interval coin charge with eviction on non-payment, which double-priced
## the exact same fact TitheManager's coin_per_held_strip already charges for
## every season. Owner ruling: keep the seasonal tithe axis, retire the
## weekly rent/eviction mechanic entirely rather than reconciling the two -
## see design/decisions.md's dated follow-up entry to ADR-038.

signal building_started(building_id: String, pos: Vector2i)
signal building_completed(building_id: String, pos: Vector2i)
signal strip_rented(strip_id: String)

## ADR-034: ownership and building placement are zone-qualified; the default
## zone is the player's holding, where every tile is owned and buildings may
## be placed. Rented strips are arable-only (allow_buildings stays false).
const DEFAULT_ZONE_ID := "fallowfield"

var _placed: Array[Dictionary] = []   # {building_id, x, y, w, h, days_remaining, complete}
var _rented: Dictionary = {}          # strip_id -> bool

var _test_player: Node = null
var _test_game_data: Node = null
var _test_mode := false


func _ready() -> void:
	# Registered AFTER TimeManager in the autoload list (boot order matters
	# here - this is the one autoload whose _ready depends on another's).
	var tm := get_node_or_null("/root/TimeManager")
	if tm != null and not tm.day_passed.is_connected(_on_day_passed):
		tm.day_passed.connect(_on_day_passed)


func configure_for_test(player_state: Node, game_data: Node) -> void:
	_test_player = player_state
	_test_game_data = game_data
	_test_mode = true


## Backward-compatible alias for pre-ADR-034 call sites (the HUD tooltip and
## older fixtures): they ask about the default zone, the player's holding.
func is_land_owned(pos: Vector2i) -> bool:
	return is_land_owned_in_zone(DEFAULT_ZONE_ID, pos)


## ADR-034: ownership is zone-qualified. Every tile of Fallowfield (the
## holding) is owned; elsewhere only the tiles inside a rented strip whose
## tenure.json zone matches are owned. Rented strips stay arable-only.
func is_land_owned_in_zone(zone_id: String, pos: Vector2i) -> bool:
	if zone_id == DEFAULT_ZONE_ID:
		return true
	var gd := _game_data()
	if gd == null:
		return false
	var tenure: Dictionary = gd.get_tenure_data()
	for strip_id: Variant in _rented:
		if not bool(_rented[strip_id]):
			continue
		var strip := _find_strip(str(strip_id), tenure)
		if strip.is_empty() or str(strip.get("zone", "")) != zone_id:
			continue
		if _rect_contains(_rect_from(strip.get("rect", {})), pos):
			return true
	return false


func rent_strip(strip_id: String) -> bool:
	if bool(_rented.get(strip_id, false)):
		return false
	var gd := _game_data()
	if gd == null or _find_strip(strip_id, gd.get_tenure_data()).is_empty():
		return false
	_rented[strip_id] = true
	strip_rented.emit(strip_id)
	return true


func is_strip_rented(strip_id: String) -> bool:
	return bool(_rented.get(strip_id, false))


func can_place_building(building_id: String, pos: Vector2i, zone_id := DEFAULT_ZONE_ID) -> bool:
	var gd := _game_data()
	if gd == null:
		return false
	var zone_meta: Dictionary = gd.get_zone_metadata(zone_id)
	if zone_meta.is_empty() or not bool(zone_meta.get("allow_buildings", false)):
		return false
	var def: Dictionary = gd.get_building(building_id)
	if def.is_empty():
		return false
	var w := int(def.get("footprint_w", 1))
	var h := int(def.get("footprint_h", 1))
	if not gd.is_within_farm(pos.x, pos.y, zone_id) \
			or not gd.is_within_farm(pos.x + w - 1, pos.y + h - 1, zone_id):
		return false
	for entry: Variant in _placed:
		var b := entry as Dictionary
		if str(b.get("zone_id", DEFAULT_ZONE_ID)) != zone_id:
			continue
		if _footprints_overlap(pos, w, h, Vector2i(int(b.get("x", 0)), int(b.get("y", 0))),
				int(b.get("w", 1)), int(b.get("h", 1))):
			return false
	return true


func start_building(building_id: String, pos: Vector2i, zone_id := DEFAULT_ZONE_ID) -> bool:
	if not can_place_building(building_id, pos, zone_id):
		return false
	var gd := _game_data()
	var def: Dictionary = gd.get_building(building_id)
	var cost_coin := int(def.get("cost_coin", 0))
	var materials: Dictionary = def.get("cost_materials", {})
	var player := _player()
	if player == null or int(player.money) < cost_coin:
		return false
	for mat_id: Variant in materials:
		if not player.has_item(str(mat_id), int(materials[mat_id])):
			return false
	player.spend_money(cost_coin)
	for mat_id: Variant in materials:
		player.remove_item(str(mat_id), int(materials[mat_id]))
	var build_days := int(def.get("build_days", 0))
	_placed.append({
		"building_id": building_id, "x": pos.x, "y": pos.y,
		"w": int(def.get("footprint_w", 1)), "h": int(def.get("footprint_h", 1)),
		"days_remaining": build_days, "complete": build_days <= 0,
		"zone_id": zone_id,
	})
	building_started.emit(building_id, pos)
	if build_days <= 0:
		building_completed.emit(building_id, pos)
	return true


## Every placed building (complete or in-progress) - the renderer draws
## in-progress entries dimmer/hatched, so it needs more than the completed set.
func get_placed_buildings(zone_id := "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Variant in _placed:
		var b := entry as Dictionary
		if not zone_id.is_empty() and str(b.get("zone_id", DEFAULT_ZONE_ID)) != zone_id:
			continue
		out.append(b.duplicate(true))
	return out


func get_completed_buildings() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Variant in _placed:
		var b := entry as Dictionary
		if bool(b.get("complete", false)):
			out.append(b)
	return out


## Sprint 15b: zone-qualified like get_building_id_at. A player-built well
## only refills from the zone it stands in - zone-local coordinates would
## otherwise collide across maps.
func is_well_at(pos: Vector2i, zone_id := DEFAULT_ZONE_ID) -> bool:
	for b: Dictionary in get_completed_buildings():
		if str(b.get("zone_id", DEFAULT_ZONE_ID)) != zone_id:
			continue
		if str(b.get("building_id", "")) == "well_extra" \
				and Vector2i(int(b.get("x", 0)), int(b.get("y", 0))) == pos:
			return true
	return false


## Station lookup for the interaction layer: returns the completed building
## id covering a tile, or "" if none. Existence-anywhere is NOT checked here -
## crafting proximity is enforced one layer up (the panel only opens for the
## station tile the player stands next to), per the Sprint 13 guide.
func get_building_id_at(pos: Vector2i, zone_id := DEFAULT_ZONE_ID) -> String:
	for b: Dictionary in get_completed_buildings():
		if str(b.get("zone_id", DEFAULT_ZONE_ID)) != zone_id:
			continue
		var w := int(b.get("w", 1))
		var h := int(b.get("h", 1))
		var bx := int(b.get("x", 0))
		var by := int(b.get("y", 0))
		if pos.x >= bx and pos.x < bx + w and pos.y >= by and pos.y < by + h:
			return str(b.get("building_id", ""))
	return ""


func get_sleep_bonus_fraction() -> float:
	var best := 0.0
	for b: Dictionary in get_completed_buildings():
		if str(b.get("building_id", "")) == "cottage_upgrade":
			var gd := _game_data()
			if gd != null:
				best = maxf(best, float(gd.get_building("cottage_upgrade").get("sleep_bonus_fraction", 0.0)))
	return best


func get_storage_capacity_bonus() -> int:
	var total := 0
	var gd := _game_data()
	if gd == null:
		return 0
	for b: Dictionary in get_completed_buildings():
		if str(b.get("building_id", "")) == "storage_chest":
			total += int(gd.get_building("storage_chest").get("capacity", 0))
	return total


func get_deterrence_bonus() -> int:
	var total := 0
	var gd := _game_data()
	if gd == null:
		return 0
	for b: Dictionary in get_completed_buildings():
		if str(b.get("building_id", "")) == "fence":
			total += int(gd.get_building("fence").get("deterrence_bonus", 0))
	return total


## Debug-only lever (Ctrl+K cheat panel): skip the remaining construction time
## on every in-progress building instead of waiting for day_passed to tick it
## down naturally.
func force_complete_all() -> void:
	for entry: Variant in _placed:
		var b := entry as Dictionary
		if bool(b.get("complete", false)):
			continue
		b["days_remaining"] = 0
		b["complete"] = true
		building_completed.emit(str(b.get("building_id", "")), Vector2i(int(b.get("x", 0)), int(b.get("y", 0))))


func to_dict() -> Dictionary:
	return {"placed": _placed.duplicate(true), "rented": _rented.duplicate()}


func from_dict(data: Dictionary) -> void:
	_placed = []
	for entry: Variant in data.get("placed", []):
		_placed.append((entry as Dictionary).duplicate())
	_rented = (data.get("rented", {}) as Dictionary).duplicate()


func _on_day_passed(_day: int, _season: String, _year: int) -> void:
	_advance_construction()


func _advance_construction() -> void:
	for entry: Variant in _placed:
		var b := entry as Dictionary
		if bool(b.get("complete", false)):
			continue
		b["days_remaining"] = int(b.get("days_remaining", 0)) - 1
		if int(b["days_remaining"]) <= 0:
			b["complete"] = true
			building_completed.emit(str(b.get("building_id", "")), Vector2i(int(b.get("x", 0)), int(b.get("y", 0))))


func _find_strip(strip_id: String, tenure: Dictionary) -> Dictionary:
	for entry: Variant in tenure.get("strips", []):
		var s := entry as Dictionary
		if str(s.get("id", "")) == strip_id:
			return s
	return {}


func _footprints_overlap(pos_a: Vector2i, w_a: int, h_a: int, pos_b: Vector2i, w_b: int, h_b: int) -> bool:
	return pos_a.x < pos_b.x + w_b and pos_a.x + w_a > pos_b.x \
		and pos_a.y < pos_b.y + h_b and pos_a.y + h_a > pos_b.y


## Manual bounds check (the guide's Rect2i.has_point fallback, used directly
## to avoid depending on an unverified 4.7 API per the API-confidence rule).
func _rect_from(r: Dictionary) -> Rect2i:
	return Rect2i(int(r.get("x", 0)), int(r.get("y", 0)), int(r.get("width", 0)), int(r.get("height", 0)))


func _rect_contains(rect: Rect2i, pos: Vector2i) -> bool:
	return pos.x >= rect.position.x and pos.x < rect.position.x + rect.size.x \
		and pos.y >= rect.position.y and pos.y < rect.position.y + rect.size.y


func _player() -> Node:
	if _test_player != null:
		return _test_player
	return get_node_or_null("/root/PlayerState")


func _game_data() -> Node:
	if _test_game_data != null:
		return _test_game_data
	return get_node_or_null("/root/GameData")
