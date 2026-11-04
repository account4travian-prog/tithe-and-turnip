extends RefCounted
## Request coverage: offers from requests.json templates, the max_active cap,
## completion (items/coin/opinion), expiry when days_left reaches zero, and
## the reputation save block roundtrip.

const REPUTATION_SCRIPT := preload("res://scripts/autoloads/reputation_manager.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")
const PLAYER_STATE_SCRIPT := preload("res://scripts/autoloads/player_state.gd")


func suite_name() -> String:
	return "requests"


func run(t: Object) -> void:
	_test_offer(t)
	_test_max_active(t)
	_test_completion(t)
	_test_expiry(t)
	_test_save_roundtrip(t)
	t.completed(5)


func _make() -> Array:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	# Force an offer on every day-passed so the tests are deterministic.
	gd.requests_cfg["new_request_chance_per_day"] = 1.0
	var ps = PLAYER_STATE_SCRIPT.new()
	var rm = REPUTATION_SCRIPT.new()
	rm.configure_for_test(gd, ps)
	rm.reset_all()
	return [rm, ps, gd]


func _test_offer(t: Object) -> void:
	seed(2026)
	var parts := _make()
	var rm = parts[0]
	var offered: Array = []
	rm.request_offered.connect(func(request_id: String, _npc_id: String) -> void:
		offered.append(request_id))
	rm._maybe_offer_request()
	var active: Array = rm.get_active_requests()
	t.eq(active.size(), 1, "one request offered when chance is 1.0")
	t.eq(offered.size(), 1, "request_offered emitted")
	var req: Dictionary = active[0]
	t.ok(not str(req.get("id", "")).is_empty(), "request carries an id")
	t.eq(int(req.get("days_left", -1)), int(req.get("days_to_complete", -1)),
		"days_left starts at days_to_complete")
	t.section_done("offer")


func _test_max_active(t: Object) -> void:
	seed(2027)
	var parts := _make()
	var rm = parts[0]
	rm._maybe_offer_request()
	rm._maybe_offer_request()
	t.eq(rm.get_active_requests().size(), 2, "second offer fills max_active_requests")
	rm._maybe_offer_request()
	t.eq(rm.get_active_requests().size(), 2, "no offer past max_active_requests")
	t.section_done("max active")


func _test_completion(t: Object) -> void:
	seed(2028)
	var parts := _make()
	var rm = parts[0]
	var ps = parts[1]
	rm._maybe_offer_request()
	var req: Dictionary = rm.get_active_requests()[0]
	var req_id := str(req.get("id", ""))
	var item_id := str(req.get("item_id", ""))
	var quantity := int(req.get("quantity", 0))
	var quality := str(req.get("quality", "common"))
	t.not_ok(rm.can_complete_request(req_id), "request incomplete when inventory is short")
	ps.add_item(item_id, quantity - 1, quality)
	t.not_ok(rm.can_complete_request(req_id), "request incomplete one item short")
	ps.add_item(item_id, 1, quality)
	t.ok(rm.can_complete_request(req_id), "request completable with the right item/quality/count")
	var npc_id := str(req.get("npc_id", ""))
	var opinion_before: float = rm.get_opinion(npc_id)
	var money_before: int = ps.money
	var completed: Array = []
	rm.request_completed.connect(func(request_id: String) -> void:
		completed.append(request_id))
	t.ok(rm.complete_request(req_id), "completion succeeds")
	t.eq(completed.size(), 1, "request_completed emitted")
	t.eq(rm.get_active_requests().size(), 0, "completed request leaves the active list")
	t.eq(int(ps.money - money_before), int(req.get("reward_coin", 0)), "reward coin granted")
	t.eq(rm.get_opinion(npc_id), opinion_before + float(req.get("reward_opinion", 0)),
		"reward opinion granted to the right NPC")
	t.not_ok(ps.has_item(item_id, quantity, quality), "requested items consumed")
	t.section_done("completion")


func _test_expiry(t: Object) -> void:
	seed(2029)
	var parts := _make()
	var rm = parts[0]
	rm._maybe_offer_request()
	var req: Dictionary = rm.get_active_requests()[0]
	var req_id := str(req.get("id", ""))
	var expired: Array = []
	rm.request_expired.connect(func(request_id: String) -> void:
		expired.append(request_id))
	for _i in range(int(req.get("days_to_complete", 1))):
		rm._on_day_passed_village(1, "spring", 1)
	t.ok(expired.has(req_id), "request_expired fired when days_left hit zero")
	var still_there := false
	for entry: Dictionary in rm.get_active_requests():
		if str(entry.get("id", "")) == req_id:
			still_there = true
	t.not_ok(still_there, "expired request is removed")
	t.not_ok(rm.can_complete_request(req_id), "expired request cannot be completed")
	t.section_done("expiry")


func _test_save_roundtrip(t: Object) -> void:
	seed(2030)
	var parts := _make()
	var rm = parts[0]
	var gd = parts[2]
	rm._maybe_offer_request()
	var saved: Dictionary = rm.get_save_data()
	t.ok(saved.has("active_requests"), "active_requests rides in the reputation save block")
	t.ok(saved.has("daily_gift_count"), "daily_gift_count rides in the reputation save block")
	var fresh = REPUTATION_SCRIPT.new()
	fresh.configure_for_test(gd)
	fresh.reset_all()
	fresh.load_save_data(saved)
	t.eq(fresh.get_active_requests().size(), 1, "active requests restored from save")
	t.section_done("save roundtrip")
