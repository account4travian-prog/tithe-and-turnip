# Sprint 11 - Manor politics & the grey economy

**Size:** M-L. **Markers:** none - no editor access needed; this sprint
deliberately adds **no new autoload**, folding court/corvee/black-market/
price-drift state into the existing `TitheManager` (it already owns every
other manor-economy concern - market, tithe, upkeep).
**ADR:** ADR-025 - Proposed, **the largest amendment in the roadmap**:
CLAUDE.md section 2's out-of-scope list currently bars "manor politics
beyond the approved raids/theft." Confirm the amendment landed (contract
text edited, ADR status flipped to Accepted) before starting - this is not
a formality for this sprint the way it was for Sprints 8/10.
**Prerequisite:** Sprint 6 (extends `TitheManager`'s `_compute_sell_net`
and `_on_day_passed`) and Sprint 10 (listens to `ReputationManager.
action_applied`, which exists already, but this sprint is the first to
consume it from `TitheManager`).

## Objective

A manor court that fines witnessed violence and detected illegal sales on
scheduled court days; corvee - the steward calling a mandatory labor day on
short notice, colliding with the player's own farm plans; a black-market
trader paying above assize with no toll, at the risk of detection; and
small market-day price drift so timing a sale matters.

## `data/manor.json` (new)

```json
{
	"version": 1,
	"court_days": [12, 26],
	"fines": { "witnessed_violence": 15, "illegal_sale": 20 },
	"corvee": { "chance_per_week": 0.4, "notice_days": 1, "credit_multiplier": 1.5 },
	"black_market": {
		"visit_days": [9, 20],
		"price_premium_pct": 0.25,
		"base_detection_chance": 0.2,
		"standing_detection_reduction": 0.15
	},
	"price_drift": { "market_day_price_swing_pct": 0.05 }
}
```

`court_days` deliberately sit off the regular market-day cadence (days 3,
7, 10, 14, 17, 21, 24, 28) - court is a separate institution from
commerce. `black_market.visit_days` (9, 20) are likewise off-cycle from
both, so it reads as a distinct, secretive channel rather than a market
variant.

`GameData`: `MANOR_INT_KEYS` casts `court_days` entries, `fines.*` values,
`corvee.notice_days`, `black_market.visit_days` entries (`chance_per_week`,
`credit_multiplier`, `price_premium_pct`, `base_detection_chance`,
`standing_detection_reduction`, `price_drift.market_day_price_swing_pct`
stay float). `manor_cfg: Dictionary` from `manor.json`.
`get_manor_data() -> Dictionary` returning it.

Add two `reputation.json` actions: `fail_corvee: { "manor": -4, "village":
0, "church": 0 }`, `fail_court_fine: { "manor": -6, "village": 0, "church":
0 }`.

## `TitheManager` additions

New signals: `signal offense_recorded(kind: String)`, `signal court_held
(total_fine: int, offenses: Array)`, `signal corvee_announced(day: int)`,
`signal corvee_started`, `signal black_market_status_changed(is_open: bool)`.

New state: `var _pending_offenses: Array[String] = []`, `var _corvee_day :=
-1`, `var _corvee_active := false`, `var _corvee_chore_done := false`, `var
_todays_price_drift := 1.0`.

Wire `ReputationManager.action_applied` in `_ready()` (alongside the
existing `TimeManager.day_passed` connection at `tithe_manager.gd:25-28`) -
this is how a court fine gets queued from a combat hit **without touching
`combat_manager.gd`** (that signal already fires today, at
`reputation_manager.gd:75`, every time `apply_action` runs):

```gdscript
func _ready() -> void:
	var tm := get_node_or_null("/root/TimeManager")
	if tm != null and not tm.day_passed.is_connected(_on_day_passed):
		tm.day_passed.connect(_on_day_passed)
	var rep := get_node_or_null("/root/ReputationManager")
	if rep != null and not rep.action_applied.is_connected(_on_reputation_action):
		rep.action_applied.connect(_on_reputation_action)


func _on_reputation_action(action_id: String) -> void:
	if action_id == "attack_villager":
		record_offense("witnessed_violence")


func record_offense(kind: String) -> void:
	_pending_offenses.append(kind)
	offense_recorded.emit(kind)
```

Widen `_on_day_passed` (already widened once in Sprint 6 to take `day`) to
drive corvee/court/black-market/price-drift, after the existing upkeep
call:

```gdscript
func _on_day_passed(day: int, _season: String, _year: int) -> void:
	_daily_labor_credit = 0.0
	market_status_changed.emit(is_market_open())
	_apply_upkeep_if_due(day)
	if _corvee_active and not _corvee_chore_done:
		_apply_reputation("fail_corvee")
	_corvee_active = (day == _corvee_day)
	if _corvee_active:
		corvee_started.emit()
	_corvee_chore_done = false
	_maybe_announce_corvee(day)
	_maybe_run_court(day)
	_update_price_drift(day)
	black_market_status_changed.emit(is_black_market_open())
```

```gdscript
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


func is_black_market_open() -> bool:
	var gd := _game_data()
	if gd == null:
		return false
	return (gd.get_manor_data().get("black_market", {}).get("visit_days", []) as Array).has(_current_day())
```

**Price drift folds into the existing Sprint 6 helper** - add one
multiplication to `_compute_sell_net` (`tithe_manager.gd`, added in
Sprint 6's section 7):

```gdscript
func _compute_sell_net(item_id: String, quantity: int, quality: String) -> int:
	var gd := _game_data()
	if gd == null:
		return 0
	var base: int = gd.get_market_buy_price(item_id)
	var mult: float = (gd.get_quality_tier(quality) as Dictionary).get("price_mult", 1.0)
	var value := float(quantity) * float(base) * mult * _standing_price_factor(false) * _todays_price_drift
	return int(value * (1.0 - gd.get_market_toll_percent()))
```

Corvee credit multiplier - `do_chore` (`tithe_manager.gd:165-186`) gains
one line and one flag set:

```gdscript
	var credit := float(chore.get("credit", 0)) + skill_labor_bonus  # skill_labor_bonus from Sprint 8, if that sprint landed first
	if _corvee_active:
		var gd := _game_data()
		if gd != null:
			credit *= float(gd.get_manor_data().get("corvee", {}).get("credit_multiplier", 1.0))
		_corvee_chore_done = true
```

(Insert this where Sprint 8's `credit_bonus` addition already sits, if
Sprint 8 landed first - the two are independent additive/multiplicative
modifiers to the same local `credit` variable and don't conflict; apply
Sprint 8's flat bonus first, then Sprint 11's multiplier, so a skilled
player's corvee bonus is multiplied on top of their skill bonus, not
instead of it.)

Black-market trading - a new public method, deliberately **not** routed
through `_compute_sell_net` (no toll, a premium instead of standing/drift
adjustment, and it triggers detection - different enough to warrant its
own function rather than another branch inside the shared helper):

```gdscript
func can_black_market_sell(item_id: String, quantity: int, quality: String) -> bool:
	return is_black_market_open() and _player().has_item(item_id, quantity, quality)


func black_market_sell(item_id: String, quantity: int, quality: String) -> int:
	if not can_black_market_sell(item_id, quantity, quality):
		return 0
	var gd := _game_data()
	var base: int = gd.get_market_buy_price(item_id)
	var mult: float = (gd.get_quality_tier(quality) as Dictionary).get("price_mult", 1.0)
	var premium := float(gd.get_manor_data().get("black_market", {}).get("price_premium_pct", 0.0))
	var net := int(float(quantity) * float(base) * mult * (1.0 + premium))
	_player().remove_item(item_id, quantity, quality)
	_player().add_money(net)
	_roll_black_market_detection()
	transaction_completed.emit("black_market_sell", net)
	return net


func _roll_black_market_detection() -> void:
	if _test_mode:
		return
	var gd := _game_data()
	var rep := get_node_or_null("/root/ReputationManager")
	if gd == null or rep == null:
		return
	var cfg: Dictionary = gd.get_manor_data().get("black_market", {})
	var base_chance := float(cfg.get("base_detection_chance", 0.0))
	var reduction := float(cfg.get("standing_detection_reduction", 0.0))
	var village_standing := float(rep.get_standing("village"))
	var chance := clampf(base_chance - (village_standing / 100.0) * reduction, 0.0, 1.0)
	if randf() < chance:
		record_offense("illegal_sale")
```

Good village standing measurably lowers detection risk (villagers who like
you don't inform on you) - this is what makes ADR-024's gifting/requests
have a second payoff beyond opinion for its own sake.

`serialize()`/`deserialize()` (`tithe_manager.gd:236-247`) gain the six new
fields (`_pending_offenses`, `_corvee_day`, `_corvee_active`,
`_corvee_chore_done`, `_todays_price_drift`), each with the obvious
default on load (`[]`, `-1`, `false`, `false`, `1.0`).

## UI integration (Sprint 7's panels)

- `HudPanel`: a banner/message when `corvee_announced` fires ("The steward
  demands labor in %d days"), another when `corvee_started` fires ("Corvee
  today - work the demesne or answer for it"), and a message on
  `court_held` summarizing the fine and offense list (or "No offenses this
  session" when `total_fine == 0`).
- `ShopPanel` gains a "Black Market" tab, only shown/enabled when
  `TitheManager.is_black_market_open()` is true, listing the player's
  sellable stacks with `black_market_sell` in place of `sell_crop` and no
  toll line shown (there isn't one). No new world feature/NPC needed - the
  trader is represented entirely through this UI availability window, not
  a physical presence on the map (matches the "itinerant" framing without
  requiring new spawn logic).

## Save schema

`SAVE_VERSION -> 10`. No new top-level payload key - everything rides
inside the existing `"tithe"` block via the widened `serialize()`/
`deserialize()`.

```gdscript
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
```

Chain: `if version <= 9: parsed = migrate_to_v10(parsed)`.

## Tests

### New: `tests/suites/test_court.gd`

1. `record_offense("witnessed_violence")` then a day-passed call on a
   `court_days` day charges exactly `fines.witnessed_violence` and clears
   `_pending_offenses` (assert via a public getter or by confirming a
   second court day with no new offenses charges `0`).
2. Multiple offenses before a court day sum correctly.
3. A day-passed call on a **non**-court day never charges a fine, however
   many offenses are pending.
4. Insufficient money at court: player pays only what they have and
   `fail_court_fine` fires (assert via `ReputationManager`'s manor
   standing dropping by the expected amount, using a real
   `ReputationManager` instance rather than mocking the call).
5. `ReputationManager.apply_action("attack_villager", ...)` on a real,
   connected pair of instances results in exactly one queued
   `"witnessed_violence"` offense - this is the cross-manager integration
   test, not just a unit test of `record_offense`.

Target: 8+ checks.

### New: `tests/suites/test_corvee.gd`

1. Force `chance_per_week = 1.0` (via a `GameData` mock or by injecting a
   modified `manor_cfg`) - on a `day % 7 == 0`, `corvee_announced` fires
   with `day + notice_days`.
2. On the announced day, `_corvee_active` becomes true (assert via a
   public `is_corvee_active()` getter - add one, don't reach into the
   private var from a test) and a chore's credit is multiplied by
   `credit_multiplier`.
3. Completing at least one chore on the corvee day sets the "done" flag
   such that the *next* day-passed call does **not** apply
   `fail_corvee`.
4. Not completing any chore on the corvee day - the next day-passed call
   *does* apply `fail_corvee` (assert the manor standing drop via a real
   `ReputationManager`).
5. `chance_per_week = 0.0` never announces a corvee across many simulated
   weeks (deterministic negative case, no `randf()` flakiness risk).

Target: 8+ checks. Add `func is_corvee_active() -> bool: return
_corvee_active` to `TitheManager` for test 2's assertion - a one-line
public accessor is worth it over reaching into a private field.

### New: `tests/suites/test_blackmarket.gd`

1. `is_black_market_open()` false on a non-`visit_days` day, true on one.
2. `black_market_sell` nets `quantity * base_price * quality_mult * (1 +
   price_premium_pct)` with **no** toll subtraction - contrast this
   explicitly against `_compute_sell_net`'s toll-inclusive result for the
   same inputs to confirm the two paths are genuinely different, not an
   accidental duplicate.
3. `black_market_sell` fails outside `visit_days` even with sufficient
   inventory.
4. Detection: with `base_detection_chance = 1.0`, every `black_market_sell`
   call queues an `"illegal_sale"` offense (seed `randf` or force the
   branch deterministically - do not leave this test flaky at a 1.0
   probability, which is the whole point of choosing that value).
5. Detection: with `base_detection_chance = 0.0`, no offense is ever
   queued regardless of village standing.
6. Higher village standing measurably lowers the detection roll's
   effective chance (compute the two `chance` values at two different
   standings using the same formula the implementation uses, and confirm
   they differ in the expected direction - not a randomized statistical
   test, a direct formula check).

Target: 10+ checks.

### `tests/run_tests.gd`

Register `test_court.gd`, `test_corvee.gd`, `test_blackmarket.gd`.

## Manual test checklist

1. Open the project in Godot 4.7.1 and press F5 - no errors.
2. Attack a villager, then advance to the next `court_days` entry -
   confirm a fine message and reduced money.
3. Wait through a week with `chance_per_week` at its shipped value (or
   temporarily raise it for testing) until a corvee is announced; on the
   corvee day, do at least one chore - confirm the boosted credit message
   and no penalty the next day.
4. Repeat, skipping the corvee entirely - confirm the manor standing
   penalty the following day.
5. On a `black_market.visit_days` day, open the shop's Black Market tab,
   sell something - confirm a higher net than the regular market would
   give for the same sale, and no toll line.
6. Sell repeatedly on black-market days with low village standing and
   confirm detection eventually queues an offense that shows up at the
   next court day.
7. Sell the same crop/quality on two different regular market days -
   confirm the net differs slightly (price drift), never below zero
   coin.
8. Save, reload mid-corvee-notice (after `corvee_announced`, before the
   corvee day) - confirm the countdown/state survives.
9. Resize the window - all new messages/panels remain legible.

## Divergences to record

- No physical black-market trader NPC or world presence - represented
  entirely as a UI-availability window on `visit_days`. Revisit only if a
  future sprint wants a visible, walk-up-to trader for its own sake; the
  economic behavior doesn't need one.
- Corvee can only have one announcement pending/active at a time
  (`_maybe_announce_corvee` skips the weekly roll while `_corvee_day !=
  -1 and day <= _corvee_day`) - simpler than a queue, and a second
  simultaneous corvee call would be indistinguishable from the first in
  play anyway.
- Court fines for a shortfall are paid to zero rather than going negative
  or blocking other spending - a `fail_court_fine` reputation penalty
  covers the "you couldn't pay" consequence instead of debt mechanics,
  keeping this consistent with Sprint 6's upkeep-shortfall handling
  (`fail_upkeep`, same pattern).
