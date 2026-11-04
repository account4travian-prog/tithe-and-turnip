extends Node

## Manages market transactions, lord tithe (coin / crops / labor), and church
## donations. All economic tunables come from GameData and PlayerState; this
## autoload is the single authority for spending money, consuming energy, and
## moving items for tithe-church-market actions. AUTOLOAD - no class_name.
## ADR-038 (X13, superseding ADR-017's per-tilled-tile axis): the tithe goal
## scales with held acreage - a flat per-strip surcharge on top of the base,
## counted from BuildingManager's rented-strip state rather than FarmGrid's
## tilled-tile count, so working land harder no longer raises what is owed.
## A recurring upkeep coin sink still lands on interval days. ADR-009/ADR-010: buy
## and sell both route through shared price helpers so the toll and standing
## adjustment cannot drift apart. ADR-025: also owns the manor court
## (scheduled fines), corvee (short-notice mandatory labor), black market
## (no-toll premium sales against a detection roll), and market-day price
## drift - the "grey economy" folds in here rather than adding an autoload.
## ADR-037 (E6): owns the supply-pressure curve (player sales accumulate
## per-crop pressure; prices are locked at market open to a 0.5x-1.5x band
## and decay nightly) and the town board (1-3 in-season fetch-quest orders
## generated on market days, capped at 3 active, fulfilling against any
## quality mix). Both fold in here for the same reason the grey economy did:
## a new autoload needs a Project Settings -> Autoload registration only a
## human can land, and this file already owns every market transaction.
## ADR-040 (spatial demesne chores, superseding ADR-013's abstract shape):
## the labor chores are real FarmGrid/tool actions - no "Do" buttons, no
## non-spatial do_chore(). Till/water complete through ToolManager calling
## complete_demesne_tool_chore(); harvest (clearing stored sheaves) and carry
## (delivery to the tithe chest) complete through the player's bare-hand
## interaction calling complete_demesne_interaction(). This file still owns
## every credit/energy/cap/corvee/reputation/XP bookkeeping side effect, and
## the one piece of carry state (carrying_sheaves, persisted, cleared on day
## rollover - sleeping is the work-shift boundary).

signal tithe_updated(paid: float, goal: int)
signal market_status_changed(is_open: bool)
signal daily_labor_limit_reached
signal chore_completed(chore_id: String, credit: float, energy_cost: float)
signal donation_made(type: String, value: float)
signal transaction_completed(transaction_type: String, net_amount: int)
signal offense_recorded(kind: String)
signal court_held(total_fine: int, offenses: Array)
signal corvee_announced(day: int)
signal corvee_started
signal black_market_status_changed(is_open: bool)
signal order_fulfilled(order_id: String, reward_money: int)
signal demesne_status_changed

## Structural epsilon for pressure decay - once a crop's pressure rounds to
## this close to zero the entry is dropped so the save dict stays clean. Not
## a gameplay tunable (economy.json owns those), so it stays a constant.
const PRESSURE_EPSILON := 0.0001

var _tithe_paid: float = 0.0
var _daily_labor_credit: float = 0.0
var _church_donations: float = 0.0
## ADR-040: the load of stored sheaves the player is currently carrying from
## the demesne to the tithe chest. 0 = not carrying; delivery clears it, day
## rollover clears it (the steward collects an undelivered load back into the
## backlog), and save/load persists it - a physical load should not vanish
## when the player quits.
var _carrying_sheaves: int = 0

var _test_player: Node = null
var _test_game_data: Node = null
var _test_get_day: Callable = Callable()
var _test_mode := false
var _test_farm_grid: Node = null
var _test_rep: Node = null
var _farm_grid_ref: Node = null  # set by main.gd via set_farm_grid_ref
var _test_held_strips := 0
var _pending_offenses: Array[String] = []
var _corvee_day := -1
var _corvee_active := false
var _corvee_chore_done := false
var _todays_price_drift := 1.0
var _crop_pressure: Dictionary = {}
var _active_orders: Array[Dictionary] = []
var _todays_supply_multipliers: Dictionary = {}
var _order_seq := 0


func _ready() -> void:
	var tm := get_node_or_null("/root/TimeManager")
	if tm != null and not tm.day_passed.is_connected(_on_day_passed):
		tm.day_passed.connect(_on_day_passed)
	var rep := get_node_or_null("/root/ReputationManager")
	if rep != null and not rep.action_applied.is_connected(_on_reputation_action):
		rep.action_applied.connect(_on_reputation_action)


## Court offenses are queued from reputation actions, never from combat code:
## attacking a villager fires action_applied ("attack_villager") and becomes a
## witnessed-violence fine; a false theft accusation ("accuse_falsely", ADR-026)
## becomes a false_accusation fine at the next court day.
func _on_reputation_action(action_id: String) -> void:
	if action_id == "attack_villager":
		record_offense("witnessed_violence")
	elif action_id == "accuse_falsely":
		record_offense("false_accusation")


func record_offense(kind: String) -> void:
	_pending_offenses.append(kind)
	offense_recorded.emit(kind)


## reputation (optional) injects a real ReputationManager for tests that must
## exercise the live reputation path - the headless harness runs suites in
## SceneTree._initialize(), where /root lookups cannot resolve, so the seam
## is the only way to drive those branches without mounting nodes.
func configure_for_test(
	player_state: Node, game_data: Node, get_day: Callable,
	farm_grid: Node = null, reputation: Node = null, held_strips: int = 0
) -> void:
	_test_player = player_state
	_test_game_data = game_data
	_test_get_day = get_day
	_test_farm_grid = farm_grid
	_test_rep = reputation
	_test_held_strips = held_strips
	_test_mode = true


func set_farm_grid_ref(farm_grid: Node) -> void:
	_farm_grid_ref = farm_grid


func is_market_open() -> bool:
	var gd := _game_data()
	if gd == null:
		return false
	return gd.is_market_day(_current_day())


func can_buy(item_id: String, quantity: int) -> bool:
	var gd := _game_data()
	if gd == null or gd.get_item(item_id).is_empty():
		return false
	return _player().money >= _compute_buy_total(item_id, quantity)


func buy_item(item_id: String, quantity: int) -> bool:
	if not can_buy(item_id, quantity):
		return false
	var total := _compute_buy_total(item_id, quantity)
	if not _player().spend_money(total):
		return false
	_player().add_item(item_id, quantity)
	transaction_completed.emit("buy", -total)
	_apply_reputation("market_trade")
	return true


func can_sell(item_id: String, quantity: int, quality: String) -> bool:
	if not is_market_open():
		return false
	var gd := _game_data()
	if gd == null or gd.get_market_buy_price(item_id) < 0:
		return false
	return _player().has_item(item_id, quantity, quality)


func sell_crop(item_id: String, quantity: int, quality: String) -> int:
	if not can_sell(item_id, quantity, quality):
		return 0
	var net := _compute_sell_net(item_id, quantity, quality)
	_player().remove_item(item_id, quantity, quality)
	_player().add_money(net)
	# E6/ADR-037: every unit sold at the stall gluts that item's local
	# market - pressure accrues per item and only affects the NEXT market
	# day's price (today's multiplier was already locked at market open).
	_crop_pressure[item_id] = float(_crop_pressure.get(item_id, 0.0)) + float(quantity)
	transaction_completed.emit("sell", net)
	_apply_reputation("market_trade")
	return net


## Sprint 7 addition: a price preview for the shop panel, ahead of committing
## to `buy_item`. Delegates to `_compute_buy_total` (Sprint 6) so the preview
## can never drift from what `buy_item` actually charges.
func get_buy_price(item_id: String, quantity: int = 1) -> int:
	return _compute_buy_total(item_id, quantity)


## Sprint 7 addition: a price preview for the shop panel's sell rows.
## Delegates to `_compute_sell_net` (Sprint 6) so the preview can never drift
## from what `sell_crop` actually pays.
func get_sell_price(item_id: String, quantity: int, quality: String) -> int:
	return _compute_sell_net(item_id, quantity, quality)


func can_pay_tithe_coin(amount: int) -> bool:
	var needed := _tithe_goal() - _tithe_paid
	return needed > 0.0 and _player().money >= mini(amount, int(needed))


func pay_tithe_coin(amount: int) -> bool:
	var goal := _tithe_goal()
	var needed := goal - _tithe_paid
	if needed <= 0.0:
		return false
	var to_pay := mini(amount, int(needed))
	if to_pay <= 0:
		return false
	if not _player().spend_money(to_pay):
		return false
	_tithe_paid += to_pay
	tithe_updated.emit(_tithe_paid, goal)
	transaction_completed.emit("tithe_coin", -to_pay)
	if _tithe_paid >= goal:
		_apply_reputation("pay_tithe_fully")
	else:
		_apply_reputation("pay_tithe_partial")
	return true


func can_deposit_tithe_crops(item_id: String, quantity: int, quality: String) -> bool:
	return _player().has_item(item_id, quantity, quality)


func deposit_tithe_crops(item_id: String, quantity: int, quality: String) -> float:
	if not can_deposit_tithe_crops(item_id, quantity, quality):
		return 0.0
	var gd := _game_data()
	var base: int = gd.get_market_buy_price(item_id)
	var mult: float = (gd.get_quality_tier(quality) as Dictionary).get("price_mult", 1.0)
	var value := float(quantity) * float(base) * mult
	var goal := _tithe_goal()
	var remaining := goal - _tithe_paid
	# Crops are consumed even when the tithe is already fully paid.
	_player().remove_item(item_id, quantity, quality)
	if remaining <= 0.0:
		return 0.0
	var credit := minf(value, remaining)
	_tithe_paid += credit
	tithe_updated.emit(_tithe_paid, goal)
	return credit


func get_available_chores() -> Array[String]:
	var out: Array[String] = []
	var gd := _game_data()
	if gd == null:
		return out
	var ids: Array = gd.get_tithe_data().get("labor", {}).get("chore_ids", [])
	for id: Variant in ids:
		out.append(str(id))
	return out


## Bookkeeping eligibility for a chore: valid id, enough energy for the
## chore's listed cost, room under the daily credit cap, and the ADR-040
## type gates that are not tile-dependent (harvest needs stored sheaves and
## a free carry slot; carry needs an active load). This is the panel-facing
## gate and the first half of every spatial gate - the tile/position checks
## live in can_demesne_chore_at, where the action actually happens.
func can_do_chore(chore_id: String) -> bool:
	var gd := _game_data()
	if gd == null:
		return false
	var chore: Dictionary = gd.get_chore(chore_id)
	if chore.is_empty():
		return false
	if not _can_accept_chore(chore_id):
		return false
	var energy_cost := float(chore.get("energy_cost", 0))
	return _player().energy >= energy_cost


## ADR-040 spatial gate: would a chore of this type be a real, valid action
## at this exact tile right now? Till needs an untilled, unoccupied demesne
## tile; water needs a tilled demesne tile below the needs-water threshold;
## harvest needs a stored-sheaf tile (never the chest anchor); carry needs
## the tithe-chest anchor tile with a load in hand. Energy is deliberately
## NOT checked here for till/water - the tool consumes it through
## ToolManager, and the tile checks must hold at the moment the tool swings.
func can_demesne_chore_at(chore_id: String, pos: Vector2i) -> bool:
	if not _can_accept_chore(chore_id):
		return false
	var farm := _farm_grid()
	if farm == null:
		return false
	match chore_id:
		"till_demesne":
			return farm.is_demesne_tile(pos) and not farm.is_tilled(pos) \
				and not farm.is_demesne_sheaf_tile(pos)
		"water_demesne":
			return farm.is_demesne_tile(pos) and farm.is_tilled(pos) \
				and farm.get_cell_moisture(pos) < _needs_water_threshold()
		"harvest_demesne":
			# The chest anchor never stores sheaves, so A (field) and B
			# (chest) can never be the same tile - the carry is always a real
			# walk, even if a short one.
			return farm.is_demesne_sheaf_tile(pos) and pos != _delivery_tile()
		"carry_produce":
			return pos == _delivery_tile()
		_:
			return false


## Completion path for the tool chores (till/water): ToolManager already
## consumed the tool's energy and already changed the tile (tilled, watered),
## so this re-verifies the bookkeeping gate and post-action tile facts and
## then runs the unchanged credit/energy bookkeeping. `tool_energy_cost` is
## what the HUD should report - the actual tool spend, split per successful
## tile when an area tool covers several.
func complete_demesne_tool_chore(chore_id: String, pos: Vector2i, tool_energy_cost: float) -> bool:
	if chore_id != "till_demesne" and chore_id != "water_demesne":
		return false
	if not _can_accept_chore(chore_id):
		return false
	var farm := _farm_grid()
	# Post-action proof: the tile is inside the demesne and tilled (till just
	# tilled it; water requires tilled ground). For water the pre-action
	# moisture gate was checked by the caller before watering - single-
	# threaded, and the only production caller is ToolManager.
	if farm == null or not farm.is_demesne_tile(pos) or not farm.is_tilled(pos):
		return false
	_grant_chore_credit(chore_id, tool_energy_cost)
	return true


## Completion path for the bare-hand chores (harvest/carry): the interaction
## is the action, so this verifies the full spatial gate, consumes the
## chore's own energy cost (there is no tool), mutates the tile/carry state,
## and runs the unchanged bookkeeping. Harvest removes one stored sheaf and
## picks it up in the same interaction (one carry at a time); delivery clears
## the carry and grants carry_produce.
func complete_demesne_interaction(chore_id: String, pos: Vector2i) -> bool:
	if chore_id != "harvest_demesne" and chore_id != "carry_produce":
		return false
	if not can_demesne_chore_at(chore_id, pos):
		return false
	var gd := _game_data()
	if gd == null:
		return false
	var energy_cost := float(gd.get_chore(chore_id).get("energy_cost", 0))
	if not _player().consume_energy(energy_cost):
		return false
	var farm := _farm_grid()
	if chore_id == "harvest_demesne":
		if not farm.take_demesne_sheaf(pos):
			return false
		_carrying_sheaves += int(_demesne_config().get("sheaves_per_action", 1))
		demesne_status_changed.emit()
	else:
		_carrying_sheaves = 0
		demesne_status_changed.emit()
	_grant_chore_credit(chore_id, energy_cost)
	return true


## Live status for the tithe panel's chores board: how many stored sheaves
## are ready on the demesne, whether the player is carrying a load, and where
## the delivery point is (the tithe-chest anchor tile).
func get_demesne_status() -> Dictionary:
	var farm := _farm_grid()
	# Explicit int, not := - farm is typed Node and the method returns
	# Variant through the base-class reference (project trap 12.1).
	var sheaves: int = farm.count_demesne_sheaves() if farm != null else 0
	return {
		"sheaves_available": sheaves,
		"carrying_sheaves": _carrying_sheaves,
		"delivery_tile": _delivery_tile(),
	}


func can_donate_coin(amount: int) -> bool:
	return amount > 0 and _player().money >= amount


func donate_coin(amount: int) -> bool:
	if not can_donate_coin(amount):
		return false
	_player().spend_money(amount)
	_church_donations += amount
	donation_made.emit("coin", amount)
	transaction_completed.emit("donate", -amount)
	_apply_reputation("church_donation_large" if amount >= _church_large_threshold() else "church_donation_small")
	return true


func can_donate_crops(item_id: String, quantity: int, quality: String) -> bool:
	return _player().has_item(item_id, quantity, quality)


func donate_crops(item_id: String, quantity: int, quality: String) -> bool:
	if not can_donate_crops(item_id, quantity, quality):
		return false
	var gd := _game_data()
	var base: int = gd.get_market_buy_price(item_id)
	var mult: float = (gd.get_quality_tier(quality) as Dictionary).get("price_mult", 1.0)
	var value := float(quantity) * float(base) * mult
	_player().remove_item(item_id, quantity, quality)
	_church_donations += value
	donation_made.emit("crops", value)
	_apply_reputation("church_donation_large" if value >= _church_large_threshold() else "church_donation_small")
	return true


func get_tithe_progress() -> Dictionary:
	return {"paid": _tithe_paid, "goal": _tithe_goal(), "remaining": maxf(0.0, _tithe_goal() - _tithe_paid)}


func get_daily_labor_remaining() -> float:
	return maxf(0.0, _daily_labor_cap() - _daily_labor_credit)


func get_market_info() -> Dictionary:
	var day := _current_day()
	var open := is_market_open()
	return {"open": open, "next_day": _find_next_market_day(day)}


## E6/ADR-037: accumulated supply surplus for an item (positive = oversupply,
## the only direction player sales can push it; the negative/undersupply side
## of the formula is reserved for future systems, the clamp keeps it safe).
func get_crop_pressure(item_id: String) -> float:
	return float(_crop_pressure.get(item_id, 0.0))


## The day's locked supply multiplier for an item (1.0 when the item has no
## pressure or today is not a market day). Fixed at market open per the
## proposal's open-question #2 ruling - repeated mid-day sales never move it.
func get_supply_multiplier(item_id: String) -> float:
	return float(_todays_supply_multipliers.get(item_id, 1.0))


func get_active_orders() -> Array[Dictionary]:
	return _active_orders.duplicate(true)


## Board orders are quality-agnostic: any mix of common/fine/choice counts
## toward the requested quantity, checked across all quality stacks.
func can_fulfill_order(order_id: String) -> bool:
	var order := _find_order(order_id)
	if order.is_empty():
		return false
	var player := _player()
	return player != null and player.get_item_count(
		str(order.get("crop_id", ""))) >= int(order.get("quantity", 0))


func fulfill_order(order_id: String) -> bool:
	var order := _find_order(order_id)
	if order.is_empty() or not can_fulfill_order(order_id):
		return false
	var gd := _game_data()
	if gd == null or not _remove_item_any_quality(
			gd, str(order.get("crop_id", "")), int(order.get("quantity", 0))):
		return false
	_apply_order_reward(order)
	var reward := int(order.get("reward_money", 0))
	_active_orders.erase(order)
	order_fulfilled.emit(order_id, reward)
	transaction_completed.emit("order_fulfilled", reward)
	return true


func serialize() -> Dictionary:
	return {
		"tithe_paid": _tithe_paid,
		"daily_labor_credit": _daily_labor_credit,
		"church_donations": _church_donations,
		"carrying_sheaves": _carrying_sheaves,
		"pending_offenses": _pending_offenses,
		"corvee_day": _corvee_day,
		"corvee_active": _corvee_active,
		"corvee_chore_done": _corvee_chore_done,
		"price_drift": _todays_price_drift,
		"crop_pressure": _crop_pressure.duplicate(),
		"active_orders": _active_orders.duplicate(true),
	}


func deserialize(data: Dictionary) -> void:
	_tithe_paid = float(data.get("tithe_paid", 0.0))
	_daily_labor_credit = float(data.get("daily_labor_credit", 0.0))
	_church_donations = float(data.get("church_donations", 0.0))
	_carrying_sheaves = int(data.get("carrying_sheaves", 0))
	_pending_offenses.clear()
	for offense: Variant in data.get("pending_offenses", []):
		_pending_offenses.append(str(offense))
	_corvee_day = int(data.get("corvee_day", -1))
	_corvee_active = bool(data.get("corvee_active", false))
	_corvee_chore_done = bool(data.get("corvee_chore_done", false))
	_todays_price_drift = float(data.get("price_drift", 1.0))
	_crop_pressure.clear()
	var pressure: Dictionary = data.get("crop_pressure", {})
	for crop_id: Variant in pressure:
		_crop_pressure[str(crop_id)] = float(pressure[crop_id])
	_active_orders.clear()
	for entry: Variant in data.get("active_orders", []):
		_active_orders.append((entry as Dictionary).duplicate(true))
	_rebuild_todays_multipliers()


func _on_day_passed(day: int, _season: String, _year: int) -> void:
	_daily_labor_credit = 0.0
	# ADR-040: the day is the work unit. An undelivered load is collected
	# back into the backlog by the steward at the shift boundary - no
	# carry_produce credit, and no carrying a load across a daily cap reset.
	if _carrying_sheaves > 0:
		_carrying_sheaves = 0
		demesne_status_changed.emit()
	market_status_changed.emit(is_market_open())
	_apply_upkeep_if_due(day)
	# Corvee penalty is assessed at the rollover AFTER the corvee day: active
	# during day N means the check here on N+1 catches an unworked day.
	if _corvee_active and not _corvee_chore_done:
		_apply_reputation("fail_corvee")
	_corvee_active = (day == _corvee_day)
	if _corvee_active:
		corvee_started.emit()
	_corvee_chore_done = false
	_maybe_announce_corvee(day)
	_maybe_run_court(day)
	# E6/ADR-037: nightly supply-pressure decay, then (on market days) the
	# price lock - drift and the supply multiplier are both snapshotted at
	# market open so repeated sales cannot move today's prices. Orders expire
	# daily and the board tops up to its cap on market days.
	_decay_crop_pressure()
	_update_price_drift(day)
	_update_todays_supply_multipliers(day)
	_expire_orders(day)
	_refresh_board_orders(day, _season)
	black_market_status_changed.emit(is_black_market_open())


func is_corvee_active() -> bool:
	return _corvee_active


func is_black_market_open() -> bool:
	var gd := _game_data()
	if gd == null:
		return false
	var visit_days: Array = gd.get_manor_data().get("black_market", {}).get("visit_days", [])
	return visit_days.has(_current_day())


func can_black_market_sell(item_id: String, quantity: int, quality: String) -> bool:
	if not is_black_market_open():
		return false
	var gd := _game_data()
	if gd == null or gd.get_market_buy_price(item_id) < 0:
		return false
	var player := _player()
	return player != null and player.has_item(item_id, quantity, quality)


## Preview wrapper for the shop panel's black-market rows. Pure calculation -
## no detection roll, no item movement - so the UI can never drift from what
## black_market_sell actually pays.
func get_black_market_price(item_id: String, quantity: int, quality: String) -> int:
	var gd := _game_data()
	if gd == null:
		return 0
	var base: int = gd.get_market_buy_price(item_id)
	if base < 0:
		return 0
	var mult: float = (gd.get_quality_tier(quality) as Dictionary).get("price_mult", 1.0)
	var premium := float(gd.get_manor_data().get("black_market", {}).get("price_premium_pct", 0.0))
	return int(float(quantity) * float(base) * mult * (1.0 + premium))


## Black market: above-assize, no toll, and deliberately NOT routed through
## _compute_sell_net (no standing/drift adjustment either) - it is a distinct
## channel with its own risk. Detection only rolls in live play; tests drive
## the branch deterministically via base_detection_chance 1.0/0.0.
func black_market_sell(item_id: String, quantity: int, quality: String) -> int:
	if not can_black_market_sell(item_id, quantity, quality):
		return 0
	var net := get_black_market_price(item_id, quantity, quality)
	_player().remove_item(item_id, quantity, quality)
	_player().add_money(net)
	_roll_black_market_detection()
	transaction_completed.emit("black_market_sell", net)
	return net


func _maybe_announce_corvee(day: int) -> void:
	if _corvee_day != -1 and day <= _corvee_day:
		return  # one still pending or active - don't stack a second
	if day % 7 != 0:
		return
	var gd := _game_data()
	if gd == null:
		return
	var cfg: Dictionary = gd.get_manor_data().get("corvee", {})
	if randf() < float(cfg.get("chance_per_week", 0.0)):
		_corvee_day = day + int(cfg.get("notice_days", 1))
		corvee_announced.emit(_corvee_day)


func _maybe_run_court(day: int) -> void:
	var gd := _game_data()
	if gd == null:
		return
	var court_days: Array = gd.get_manor_data().get("court_days", [])
	if not court_days.has(day):
		return
	if _pending_offenses.is_empty():
		court_held.emit(0, [])
		return
	var fines: Dictionary = gd.get_manor_data().get("fines", {})
	var total := 0
	for offense: String in _pending_offenses:
		total += int(fines.get(offense, 0))
	var offenses_copy := _pending_offenses.duplicate()
	_pending_offenses.clear()
	var player := _player()
	if player != null and not player.spend_money(total):
		player.spend_money(int(player.money))
		_apply_reputation("fail_court_fine")
	court_held.emit(total, offenses_copy)


func _update_price_drift(day: int) -> void:
	var gd := _game_data()
	if gd == null or not gd.is_market_day(day):
		return
	var swing := float(gd.get_manor_data().get("price_drift", {}).get("market_day_price_swing_pct", 0.0))
	_todays_price_drift = 1.0 + randf_range(-swing, swing)


## E6/ADR-037: pressure drifts toward zero every night by a fixed fraction
## (economy.json pressure_decay_per_day). Entries that round to zero are
## dropped so the save dict never carries float dust.
func _decay_crop_pressure() -> void:
	var gd := _game_data()
	if gd == null:
		return
	var decay := float(gd.get_economy_data().get("pressure_decay_per_day", 0.0))
	for crop_id: Variant in _crop_pressure.keys():
		var next := float(_crop_pressure[crop_id]) * (1.0 - decay)
		if absf(next) < PRESSURE_EPSILON:
			_crop_pressure.erase(crop_id)
		else:
			_crop_pressure[crop_id] = next


## Locks each item's supply multiplier at market open from the pressure that
## survived the night - the "price is fixed mid-day" ruling (proposal open
## question #2). Rebuilt fresh every market day; sales later that day only
## shape the NEXT market day.
func _update_todays_supply_multipliers(day: int) -> void:
	var gd := _game_data()
	if gd == null or not gd.is_market_day(day):
		return
	_todays_supply_multipliers.clear()
	for crop_id: Variant in _crop_pressure:
		_todays_supply_multipliers[str(crop_id)] = \
			_compute_supply_multiplier(float(_crop_pressure[crop_id]))


## effective price = base x quality x (1.0 - supply_factor), where
## supply_factor = clamp(pressure / scale, -(cap - 1), 1 - floor), so the
## multiplier can never leave the economy.json price band (0.5x-1.5x by
## default) no matter how extreme the pressure gets.
func _compute_supply_multiplier(pressure: float) -> float:
	var gd := _game_data()
	if gd == null:
		return 1.0
	var economy: Dictionary = gd.get_economy_data()
	var scale := maxf(float(economy.get("supply_scale", 0.0)), 1.0)
	var floor_mult := float(economy.get("price_floor_mult", 0.5))
	var cap_mult := float(economy.get("price_cap_mult", 1.5))
	var factor := clampf(pressure / scale, -(cap_mult - 1.0), 1.0 - floor_mult)
	return 1.0 - factor


## After a load, today's multipliers are rebuilt from the restored pressure
## so a save loaded ON a market day shows the same prices the player was
## trading at before sleeping. Off-market days are unaffected - sell prices
## are unreachable while the stall is shut.
func _rebuild_todays_multipliers() -> void:
	_todays_supply_multipliers.clear()
	for crop_id: Variant in _crop_pressure:
		_todays_supply_multipliers[str(crop_id)] = \
			_compute_supply_multiplier(float(_crop_pressure[crop_id]))


func _supply_multiplier_for(item_id: String) -> float:
	return float(_todays_supply_multipliers.get(item_id, 1.0))


## Unfulfilled orders vanish silently once their deadline day has passed -
## no penalty, per the board-orders design.
func _expire_orders(day: int) -> void:
	var still_active: Array[Dictionary] = []
	for entry: Variant in _active_orders:
		var order := entry as Dictionary
		if int(order.get("deadline_day", 0)) < day:
			continue
		still_active.append(order)
	_active_orders = still_active


## On each market day the board tops up with 1-3 fresh orders drawn from
## in-season templates, capped at economy.json's max_active_orders total.
## Orders persist until their deadline (the "overlaps with market days keep
## options constant" ruling), so old orders survive into the next market day.
func _refresh_board_orders(day: int, season: String) -> void:
	var gd := _game_data()
	if gd == null or not gd.is_market_day(day):
		return
	var economy: Dictionary = gd.get_economy_data()
	var max_active := int(economy.get("max_active_orders", 3))
	var min_new := int(economy.get("orders_per_market_day_min", 1))
	var max_new := int(economy.get("orders_per_market_day_max", 3))
	var room := maxi(0, max_active - _active_orders.size())
	if room <= 0:
		return
	var templates := _in_season_templates(gd, season)
	if templates.is_empty():
		return
	var to_generate := mini(randi_range(min_new, max_new), room)
	for i in range(to_generate):
		_active_orders.append(_generate_order(gd, templates, day))


## Board orders are raw-crop fetch quests: only templates whose crop's
## `seasons` list contains the current season can be posted.
func _in_season_templates(gd: Node, season: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Variant in gd.get_board_orders_templates():
		var template := entry as Dictionary
		var crop_id := str(template.get("crop_id", ""))
		var crop: Dictionary = gd.get_crop(crop_id)
		if crop.is_empty():
			continue
		if not (crop.get("seasons", []) as Array).has(season):
			continue
		out.append(template)
	return out


func _generate_order(gd: Node, templates: Array[Dictionary], day: int) -> Dictionary:
	var chosen := _weighted_pick(templates)
	var days_per_season := int(gd.get_time_config().get("days_per_season", 28))
	var deadline_days := int(chosen.get("deadline_days", 3))
	_order_seq += 1
	return {
		"id": "board_%d_%d" % [Time.get_ticks_msec(), _order_seq],
		"crop_id": str(chosen.get("crop_id", "")),
		"quantity": randi_range(
			int(chosen.get("min_quantity", 1)), int(chosen.get("max_quantity", 1))),
		"reward_money": int(chosen.get("base_reward_money", 0)),
		"reward_standing": str(chosen.get("reward_standing", "")),
		"standing_amount": int(chosen.get("standing_amount", 0)),
		# Deadlines never spill past the season - an order that outlives the
		# slice would be unfillable-but-unexpirable, a dead UI row.
		"deadline_day": mini(day + deadline_days, days_per_season),
	}


func _weighted_pick(templates: Array[Dictionary]) -> Dictionary:
	var total_weight := 0
	for template: Dictionary in templates:
		total_weight += maxi(int(template.get("weight", 1)), 1)
	var roll := randi() % maxi(total_weight, 1)
	var cumulative := 0
	for template: Dictionary in templates:
		cumulative += maxi(int(template.get("weight", 1)), 1)
		if roll < cumulative:
			return template
	return templates[0]


func _find_order(order_id: String) -> Dictionary:
	for entry: Variant in _active_orders:
		var order := entry as Dictionary
		if str(order.get("id", "")) == order_id:
			return order
	return {}


## Deducts a quantity across quality stacks (common first, then fine, then
## choice) - board orders are quality-agnostic, so a player holding only
## fine/choice carrots can still fulfill a carrot order.
func _remove_item_any_quality(gd: Node, item_id: String, count: int) -> bool:
	var player := _player()
	if player == null or player.get_item_count(item_id) < count:
		return false
	var remaining := count
	for tier: Variant in gd.quality_tiers:
		var quality := str(tier)
		# Explicit int, not := - _player() is typed Node, and GDScript cannot
		# infer a return type through a generic base-class reference.
		var have: int = player.get_quality_count(item_id, quality)
		if have <= 0:
			continue
		var take := mini(have, remaining)
		player.remove_item(item_id, take, quality)
		remaining -= take
		if remaining <= 0:
			return true
	return remaining <= 0


func _apply_order_reward(order: Dictionary) -> void:
	var player := _player()
	var reward := int(order.get("reward_money", 0))
	if player != null and reward > 0:
		player.add_money(reward)
	var axis := str(order.get("reward_standing", ""))
	var amount := int(order.get("standing_amount", 0))
	if axis.is_empty() or amount == 0:
		return
	var rep := _reputation_manager()
	if rep != null and rep.has_method("modify_standing"):
		rep.modify_standing(axis, float(amount))


## Village standing scales detection down: villagers who like you don't inform
## on you, which gives ADR-024's gifting/requests a second payoff. The roll
## itself is live-only; tests exercise the formula directly instead.
func _roll_black_market_detection() -> void:
	if _test_mode and _test_rep == null:
		return
	var gd := _game_data()
	var rep := _reputation_manager()
	if gd == null or rep == null:
		return
	var cfg: Dictionary = gd.get_manor_data().get("black_market", {})
	var base_chance := float(cfg.get("base_detection_chance", 0.0))
	var reduction := float(cfg.get("standing_detection_reduction", 0.0))
	var village_standing := float(rep.get_standing("village"))
	var chance := clampf(base_chance - (village_standing / 100.0) * reduction, 0.0, 1.0)
	if randf() < chance:
		record_offense("illegal_sale")


func _apply_upkeep_if_due(day: int) -> void:
	var gd := _game_data()
	if gd == null:
		return
	var upkeep: Dictionary = gd.get_tithe_data().get("upkeep", {})
	if not bool(upkeep.get("enabled", false)):
		return
	var interval := int(upkeep.get("interval_days", 7))
	if interval <= 0 or day % interval != 0:
		return
	var amount := int(upkeep.get("amount", 0))
	if _player().spend_money(amount):
		transaction_completed.emit("upkeep", -amount)
	else:
		_apply_reputation("fail_upkeep")


func _player() -> Node:
	if _test_player != null:
		return _test_player
	return get_node_or_null("/root/PlayerState")


func _game_data() -> Node:
	if _test_game_data != null:
		return _test_game_data
	return get_node_or_null("/root/GameData")


func _farm_grid() -> Node:
	if _test_farm_grid != null:
		return _test_farm_grid
	return _farm_grid_ref


func _current_day() -> int:
	if _test_get_day.is_valid():
		return _test_get_day.call()
	var tm := get_node_or_null("/root/TimeManager")
	if tm != null:
		return int(tm.get("day"))
	return 1


func _tithe_goal() -> int:
	var gd := _game_data()
	if gd == null:
		return 0
	var data: Dictionary = gd.get_tithe_data()
	var base := int(data.get("base_amount", 0))
	var per_strip := float(data.get("coin_per_held_strip", 0.0))
	return base + int(per_strip * float(_held_strip_count()))


## ADR-038: held acreage is the owned home plot (implicit, always held) plus
## one unit per strip currently rented from BuildingManager - a parcel count,
## not a tile count, matching how tenure.json already prices strips as
## discrete units.
func _held_strip_count() -> int:
	if _test_mode:
		return _test_held_strips
	var bm := get_node_or_null("/root/BuildingManager")
	var gd := _game_data()
	if bm == null or gd == null:
		return 0
	var count := 0
	for strip: Variant in gd.get_tenure_data().get("strips", []):
		var strip_id := str((strip as Dictionary).get("id", ""))
		if bm.is_strip_rented(strip_id):
			count += 1
	return count


## Standing swings prices up to +/-max_pct over the configured range. Test
## mode short-circuits to 1.0 (no ReputationManager injected by suites).
func _standing_price_factor(is_buy: bool) -> float:
	if _test_mode:
		return 1.0
	var rep := get_node_or_null("/root/ReputationManager")
	var gd := _game_data()
	if rep == null or gd == null:
		return 1.0
	var cfg: Dictionary = gd.market_cfg.get("standing_price_adjustment", {})
	var range_val := maxf(1.0, float(cfg.get("standing_range", 100)))
	var max_pct := float(cfg.get("max_pct", 0.10))
	var standing := clampf(float(rep.get_standing("manor")), -range_val, range_val)
	var swing := (standing / range_val) * max_pct
	return (1.0 - swing) if is_buy else (1.0 + swing)


func _compute_buy_total(item_id: String, quantity: int) -> int:
	var gd := _game_data()
	if gd == null:
		return 0
	var item: Dictionary = gd.get_item(item_id)
	if item.is_empty():
		return 0
	var unit := float(item.get("price", 0)) * _standing_price_factor(true)
	var subtotal := unit * float(quantity)
	return int(ceil(subtotal * (1.0 + gd.get_market_toll_percent())))


func _compute_sell_net(item_id: String, quantity: int, quality: String) -> int:
	var gd := _game_data()
	if gd == null:
		return 0
	var base: int = gd.get_market_buy_price(item_id)
	var mult: float = (gd.get_quality_tier(quality) as Dictionary).get("price_mult", 1.0)
	# E6/ADR-037: the supply multiplier rides alongside drift and standing as
	# a plain multiplicative factor, locked at market open (see
	# _update_todays_supply_multipliers). The 5% toll applies last, on the
	# final value, per the R2a spec's interaction-with-quality ruling.
	var value := float(quantity) * float(base) * mult \
		* _standing_price_factor(false) * _todays_price_drift * _supply_multiplier_for(item_id)
	return int(value * (1.0 - gd.get_market_toll_percent()))


func _daily_labor_cap() -> float:
	var gd := _game_data()
	if gd == null:
		return 0.0
	var cap := float(gd.get_tithe_data().get("labor", {}).get("daily_credit_cap", 0))
	var skill = get_node_or_null("/root/SkillManager")
	if skill != null:
		cap += float(skill.get_effect("labor", "daily_cap_bonus", 0))
	return cap


func _find_next_market_day(from_day: int) -> int:
	var gd := _game_data()
	if gd == null:
		return 1
	for i in range(from_day + 1, from_day + 29):
		var d := i if i <= 28 else i - 28
		if gd.is_market_day(d):
			return d
	return 1


func _church_large_threshold() -> int:
	var gd := _game_data()
	if gd == null:
		return 0
	return int(gd.get_church_data().get("large_donation_threshold", 0))


func _apply_reputation(action_id: String) -> void:
	if _test_mode and _test_rep == null:
		return
	var reputation := _reputation_manager()
	if reputation != null:
		reputation.apply_action(action_id)


func _reputation_manager() -> Node:
	if _test_rep != null:
		return _test_rep
	return get_node_or_null("/root/ReputationManager")


## ADR-040: the shared non-spatial half of every chore gate - valid id, room
## under the daily cap, and the type gates that live in this file (harvest:
## stored sheaves exist and no carry is already in hand; carry: a load is in
## hand). Energy is deliberately absent: till/water pay through the tool and
## harvest/carry pay at completion, so "would this completion be accepted"
## is the only question here.
func _can_accept_chore(chore_id: String) -> bool:
	var gd := _game_data()
	if gd == null or gd.get_chore(chore_id).is_empty():
		return false
	if _daily_labor_credit >= _daily_labor_cap():
		return false
	if chore_id == "harvest_demesne":
		var farm := _farm_grid()
		if farm == null or farm.count_demesne_sheaves() <= 0 or _carrying_sheaves > 0:
			return false
	elif chore_id == "carry_produce":
		if _carrying_sheaves <= 0:
			return false
	return true


## ADR-040: the unchanged bookkeeping core of the old do_chore - daily cap
## clamping, corvee 1.5x multiplier and day-done mark, tithe credit, signals,
## reputation, and labor XP. Only the energy consumption moved out (to the
## tool for till/water, to complete_demesne_interaction for harvest/carry).
func _grant_chore_credit(chore_id: String, energy_cost: float) -> void:
	var gd := _game_data()
	if gd == null:
		return
	var chore: Dictionary = gd.get_chore(chore_id)
	var skill = get_node_or_null("/root/SkillManager")
	var credit := float(chore.get("credit", 0))
	if skill != null:
		credit += float(skill.get_effect("labor", "credit_bonus", 0))
	# Corvee days pay 1.5x credit and count as the day's required labor.
	if _corvee_active:
		if gd != null:
			credit *= float(gd.get_manor_data().get("corvee", {}).get("credit_multiplier", 1.0))
		_corvee_chore_done = true
	var room := _daily_labor_cap() - _daily_labor_credit
	var actual := minf(credit, room)
	_daily_labor_credit += actual
	var goal := _tithe_goal()
	var remaining := goal - _tithe_paid
	if remaining > 0.0:
		_tithe_paid += minf(actual, remaining)
	chore_completed.emit(chore_id, actual, energy_cost)
	tithe_updated.emit(_tithe_paid, goal)
	_apply_reputation("complete_labor_day")
	if skill != null:
		skill.add_xp_for("labor", "chore_complete")
	if _daily_labor_credit >= _daily_labor_cap():
		daily_labor_limit_reached.emit()


func _demesne_config() -> Dictionary:
	var gd := _game_data()
	if gd == null:
		return {}
	return gd.get_demesne_config()


func _needs_water_threshold() -> float:
	return float(_demesne_config().get("needs_water_moisture_below", 50))


## The delivery point for carry_produce: the stewards_demesne feature anchor
## tile, where FeatureRenderer already draws the manor tithe chest. Data-
## driven through chores.json's delivery_feature + farm_map.json's feature
## list - no new feature id, no hardcoded coordinate.
## Sprint 15b (flagged deviation from 15a's no-touch scope, one line): the
## lookup is zone-qualified through the connected farm grid's zone id.
## ADR-040 wrote this before the region split, so it read the default zone
## (fallowfield), which carries no demesne - carry_produce could never
## deliver at the manor chest once 15b made the Manor reachable. The spatial
## chore methods themselves are untouched; only this data lookup gained its
## zone.
func _delivery_tile() -> Vector2i:
	var gd := _game_data()
	if gd == null:
		return Vector2i(-1, -1)
	var farm := _farm_grid()
	var zone_id := str(farm.get_zone_id()) if farm != null and farm.has_method("get_zone_id") else ""
	if zone_id.is_empty():
		zone_id = "fallowfield"
	return gd.get_feature_tile(
		str(_demesne_config().get("delivery_feature", "stewards_demesne")), zone_id)
