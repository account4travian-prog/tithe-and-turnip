extends Node

## ReputationManager autoload - two-layer reputation system.
## Tracks manor/village/church standings (float) and individual NPC opinions.
## Values clamp to the reputation.json threshold extremes; emits signals for
## UI and save integration. AUTOLOAD - no class_name.

signal standing_changed(axis: String, new_value: float)
signal opinion_changed(npc_id: String, new_value: float)
signal action_applied(action_id: String)
signal gift_given(npc_id: String, item_id: String, delta: float)
signal request_offered(request_id: String, npc_id: String)
signal request_completed(request_id: String)
signal request_expired(request_id: String)

const DEFAULT_STANDING := 0.0
const DEFAULT_OPINION := 0.0
const FALLBACK_CLAMP_MIN := -100.0
const FALLBACK_CLAMP_MAX := 100.0
const DAILY_GIFT_CAP := 1

var standings: Dictionary = {
	"manor": DEFAULT_STANDING,
	"village": DEFAULT_STANDING,
	"church": DEFAULT_STANDING,
}
var opinions: Dictionary = {}
## ADR-031's reputation-transfer math needs directed npc-to-npc edges
## ("who does villager V think of the spouse/player"), which `opinions`
## (always relative to the player) cannot express. Keyed "from_id->to_id".
## Seeded from marriage.json's relationship_opinions - empty entries there
## mean the transfer mechanic has no effect for that pair, not an error.
var pairwise_opinions: Dictionary = {}

var _injected_game_data: Node = null
var _test_player: Node = null
var _test_marriage: Node = null
var _clamp_min: float = FALLBACK_CLAMP_MIN
var _clamp_max: float = FALLBACK_CLAMP_MAX
var _clamp_initialized: bool = false
var _daily_gift_count := 0
var _spouse_gift_count := 0
var _active_requests: Array[Dictionary] = []
var _request_seq := 0


func _ready() -> void:
	_seed_pairwise_opinions()
	var tm = get_node_or_null("/root/TimeManager")
	if tm != null and not tm.day_passed.is_connected(_on_day_passed_village):
		tm.day_passed.connect(_on_day_passed_village)


## Gift an item to an NPC. Liked items grant +10 opinion, disliked -6, any
## other item the small +2 default. Capped at DAILY_GIFT_CAP gifts/day
## shared across every ordinary villager - except the current spouse
## (ADR-031: "giftable outside the normal daily cap"), who draws from a
## separate marriage.json-tunable cap instead so a second gift to anyone
## else still correctly fails.
func gift_item(npc_id: String, item_id: String) -> bool:
	var spouse := _is_spouse(npc_id)
	var cap := _spouse_gift_cap() if spouse else DAILY_GIFT_CAP
	var used := _spouse_gift_count if spouse else _daily_gift_count
	if used >= cap:
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
	if spouse:
		_spouse_gift_count += 1
	else:
		_daily_gift_count += 1
	gift_given.emit(npc_id, item_id, delta)
	return true


## Debug-only lever (Ctrl+K cheat panel): clear today's gift caps so repeated
## gifting can be tested without waiting for the next day_passed rollover.
func reset_daily_gift_cap() -> void:
	_daily_gift_count = 0
	_spouse_gift_count = 0


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


func modify_standing(axis: String, amount: float) -> void:
	_ensure_clamp_bounds()
	var current: float = standings.get(axis, DEFAULT_STANDING)
	current = clampf(current + amount, _clamp_min, _clamp_max)
	standings[axis] = current
	standing_changed.emit(axis, current)


func modify_opinion(npc_id: String, amount: float) -> void:
	_ensure_clamp_bounds()
	var current: float = opinions.get(npc_id, DEFAULT_OPINION)
	current = clampf(current + amount, _clamp_min, _clamp_max)
	opinions[npc_id] = current
	opinion_changed.emit(npc_id, current)


func get_standing(axis: String) -> float:
	return standings.get(axis, DEFAULT_STANDING)


## Non-mutating (ADR-031 change) so opinions.has(id) can mean "an opinion
## has actually been recorded" - apply_marriage_transfer() below needs that
## distinction to skip villagers who never formed an opinion of the player.
func get_opinion(npc_id: String) -> float:
	return opinions.get(npc_id, DEFAULT_OPINION)


## ADR-031's reputation-transfer ruling, run once at the ceremony
## (MarriageManager.ceremonize()). world_bible.md's wording: "the player's
## standing with [villager V] softens toward the spouse's own standing [with
## V]... and the spouse's standing [with V] softens toward the player's in
## turn." In this project's data, "X's standing with V" always means "V's
## opinion of X" (opinions[v_id] is V's opinion of the player, by the same
## convention gift_item already uses) - so both halves of the ruling read
## off the SAME two facts about V, just nudging each toward the other:
## V's opinion of the player (opinions[v_id]) and V's opinion of the spouse
## (pairwise_opinions["V->spouse"], seeded from marriage.json's
## relationship_opinions). No second "spouse's opinion of V" fact is needed
## - the spouse never appears as the opinion-holder here, only as a target.
## Either fact missing for a given V skips that V entirely - no invented
## data. Deltas are computed from pre-transfer values so the two halves
## don't feed each other within the same run.
func apply_marriage_transfer(spouse_id: String) -> void:
	_ensure_clamp_bounds()
	var gd := _game_data()
	if gd == null or not gd.has_method("get_all_villager_ids"):
		return
	for v_id: String in gd.get_all_villager_ids():
		if v_id == spouse_id:
			continue
		var key := _opinion_key(v_id, spouse_id)
		if not opinions.has(v_id) or not pairwise_opinions.has(key):
			continue
		var v_to_player := float(opinions[v_id])
		var v_to_spouse := float(pairwise_opinions[key])
		if v_to_spouse != v_to_player:
			var delta := 25.0 if v_to_spouse > v_to_player else -25.0
			opinions[v_id] = clampf(v_to_player + delta, _clamp_min, _clamp_max)
			opinion_changed.emit(v_id, opinions[v_id])
		if v_to_player != v_to_spouse:
			var sym_delta := 25.0 if v_to_player > v_to_spouse else -25.0
			pairwise_opinions[key] = clampf(v_to_spouse + sym_delta, _clamp_min, _clamp_max)


func _opinion_key(from_id: String, to_id: String) -> String:
	return "%s->%s" % [from_id, to_id]


func _seed_pairwise_opinions() -> void:
	var gd := _game_data()
	if gd == null or not gd.has_method("get_marriage_config"):
		return
	var rel: Dictionary = gd.get_marriage_config().get("relationship_opinions", {})
	for key: Variant in rel:
		if not pairwise_opinions.has(str(key)):
			pairwise_opinions[str(key)] = float(rel[key])


func apply_action(action_id: String, target_npc_id := "") -> void:
	var game_data := _game_data()
	if game_data == null:
		return
	var effect: Dictionary = game_data.get_reputation_effect(action_id)
	if effect.is_empty():
		return
	for axis: String in ["manor", "village", "church"]:
		var delta: float = float(effect.get(axis, 0))
		if delta != 0.0:
			modify_standing(axis, delta)
	if not target_npc_id.is_empty() and effect.has("opinion_delta"):
		var opinion_delta := float(effect.get("opinion_delta", 0))
		if opinion_delta != 0.0:
			modify_opinion(target_npc_id, opinion_delta)
	action_applied.emit(action_id)


func get_standing_label(axis: String) -> String:
	var game_data := _game_data()
	if game_data == null:
		return "neutral"
	var thresholds: Dictionary = game_data.get_reputation_thresholds()
	if thresholds.is_empty():
		return "neutral"
	var standing_val := get_standing(axis)
	for label: Variant in thresholds:
		var range_dict: Dictionary = thresholds[label]
		var min_val := float(range_dict.get("min", -100.0))
		var max_val := float(range_dict.get("max", 100.0))
		if standing_val >= min_val and standing_val <= max_val:
			return str(label)
	return "neutral"


func reset_all() -> void:
	_daily_gift_count = 0
	_spouse_gift_count = 0
	_active_requests.clear()
	_request_seq = 0
	standings.clear()
	for axis: String in ["manor", "village", "church"]:
		standings[axis] = DEFAULT_STANDING
		standing_changed.emit(axis, DEFAULT_STANDING)
	opinions.clear()
	pairwise_opinions.clear()
	_seed_pairwise_opinions()


func get_save_data() -> Dictionary:
	return {
		"standings": standings.duplicate(),
		"opinions": opinions.duplicate(),
		"pairwise_opinions": pairwise_opinions.duplicate(),
		"active_requests": _active_requests.duplicate(true),
		"daily_gift_count": _daily_gift_count,
		"spouse_gift_count": _spouse_gift_count,
	}


func load_save_data(data: Dictionary) -> void:
	_ensure_clamp_bounds()
	for axis: String in ["manor", "village", "church"]:
		if not (data.get("standings", {}) as Dictionary).has(axis):
			standings[axis] = DEFAULT_STANDING
	if data.has("standings"):
		for axis: Variant in data["standings"]:
			var val := clampf(float(data["standings"][axis]), _clamp_min, _clamp_max)
			standings[str(axis)] = val
			standing_changed.emit(str(axis), val)
	if data.has("opinions"):
		for npc_id: Variant in data["opinions"]:
			var val := clampf(float(data["opinions"][npc_id]), _clamp_min, _clamp_max)
			opinions[str(npc_id)] = val
			opinion_changed.emit(str(npc_id), val)
	if data.has("active_requests"):
		_active_requests.clear()
		for entry: Variant in data["active_requests"]:
			_active_requests.append((entry as Dictionary).duplicate(true))
	_daily_gift_count = int(data.get("daily_gift_count", 0))
	_spouse_gift_count = int(data.get("spouse_gift_count", 0))
	if data.has("pairwise_opinions"):
		for key: Variant in data["pairwise_opinions"]:
			pairwise_opinions[str(key)] = clampf(
				float(data["pairwise_opinions"][key]), _clamp_min, _clamp_max)


## marriage_manager (optional) lets tests drive the spouse-gift-cap bypass
## deterministically, mirroring TitheManager's reputation-injection seam.
func configure_for_test(game_data: Node, player_state: Node = null, marriage_manager: Node = null) -> void:
	_injected_game_data = game_data
	_test_player = player_state
	_test_marriage = marriage_manager
	_clamp_initialized = false


func _is_spouse(npc_id: String) -> bool:
	var mm: Node = _test_marriage
	if mm == null:
		mm = get_node_or_null("/root/MarriageManager")
	return mm != null and mm.has_method("is_spouse") and mm.is_spouse(npc_id)


func _spouse_gift_cap() -> int:
	var gd := _game_data()
	if gd == null or not gd.has_method("get_marriage_config"):
		return 1
	return maxi(1, int(gd.get_marriage_config().get("spouse_daily_gift_cap", 1)))


func _game_data() -> Node:
	if _injected_game_data != null:
		return _injected_game_data
	return get_node_or_null("/root/GameData")


func _player() -> Node:
	if _test_player != null:
		return _test_player
	return get_node_or_null("/root/PlayerState")


## Day rollover: reset the gift cap, tick request deadlines (expiring any
## that hit zero), then maybe offer a new request from requests.json.
func _on_day_passed_village(_day: int, _season: String, _year: int) -> void:
	_daily_gift_count = 0
	_spouse_gift_count = 0
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
	var cfg: Dictionary = gd.get_requests_config()
	if _active_requests.size() >= int(cfg.get("max_active_requests", 2)):
		return
	if randf() >= float(cfg.get("new_request_chance_per_day", 0.0)):
		return
	var templates: Array = cfg.get("templates", [])
	if templates.is_empty():
		return
	# requests.json v2: templates tagged spouse_only only appear once the
	# player is married to that exact npc_id ("tasks the spouse is not
	# proficient at" - world_bible.md Block 23.5). Everyone else's requests
	# are unaffected by marriage state.
	var mm := get_node_or_null("/root/MarriageManager")
	var available: Array = []
	for entry: Variant in templates:
		var template := entry as Dictionary
		if bool(template.get("spouse_only", false)):
			if mm == null or not mm.has_method("get_spouse_id") \
					or str(template.get("npc_id", "")) != str(mm.get_spouse_id()):
				continue
		available.append(template)
	if available.is_empty():
		return
	var pick := (available[randi() % available.size()] as Dictionary).duplicate()
	# Time.get_ticks_msec() alone is not unique under rapid headless offers
	# (same-millisecond collisions); the per-manager sequence disambiguates.
	_request_seq += 1
	pick["id"] = "req_%d_%d" % [Time.get_ticks_msec(), _request_seq]
	pick["days_left"] = int(pick.get("days_to_complete", 3))
	_active_requests.append(pick)
	request_offered.emit(str(pick["id"]), str(pick.get("npc_id", "")))


func _find_request(request_id: String) -> Dictionary:
	for entry: Variant in _active_requests:
		if str((entry as Dictionary).get("id", "")) == request_id:
			return entry
	return {}


func _ensure_clamp_bounds() -> void:
	if _clamp_initialized:
		return
	var game_data := _game_data()
	if game_data != null and game_data.has_method("get_reputation_thresholds"):
		var thresholds: Dictionary = game_data.get_reputation_thresholds()
		if not thresholds.is_empty():
			var min_val := INF
			var max_val := -INF
			for label: Variant in thresholds:
				var range_dict: Dictionary = thresholds[label]
				if range_dict.has("min"):
					min_val = minf(min_val, float(range_dict["min"]))
				if range_dict.has("max"):
					max_val = maxf(max_val, float(range_dict["max"]))
			if min_val != INF and max_val != -INF:
				_clamp_min = min_val
				_clamp_max = max_val
	_clamp_initialized = true
