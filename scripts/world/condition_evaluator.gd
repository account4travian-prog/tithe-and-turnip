class_name ConditionEvaluator
extends RefCounted

## E4 (ADR-035): stateless dialogue-condition filter. evaluate() takes a
## line's raw `conditions` dict and a context dict built by DialogueManager,
## returns whether every condition passes (AND-only - OR is two line
## entries, same convention every other data-driven filter in this project
## already uses). Never a scripting layer: the key vocabulary is closed and
## validated at load time by GameData, not interpreted here.
##
## The context dict is flattened facts, not live object references, so this
## class stays a pure function - see DialogueManager.build_context() for
## what populates each key.


static func evaluate(conditions: Dictionary, context: Dictionary) -> bool:
	for key: String in conditions:
		if not _evaluate_one(key, conditions[key], context):
			return false
	return true


static func _evaluate_one(key: String, rule: Variant, context: Dictionary) -> bool:
	match key:
		"time":
			var r := rule as Dictionary
			var hour := int(context.get("time_hour", 0))
			return hour >= int(r.get("min", 0)) and hour <= int(r.get("max", 23))
		"season":
			return str(context.get("season", "")) == str(rule)
		"weather":
			return str(context.get("weather", "")) == str(rule)
		"is_market_day":
			return bool(context.get("is_market_day", false)) == bool(rule)
		"is_mass_day":
			return bool(context.get("is_mass_day", false)) == bool(rule)
		"is_festival":
			# bool true/false = any festival active or not; a string = that
			# specific festival's id. No FestivalManager yet (Phase 3) -
			# context.is_festival is always false, festival_id always "".
			if rule is bool:
				return bool(context.get("is_festival", false)) == bool(rule)
			return str(context.get("festival_id", "")) == str(rule)
		"has_item":
			var r := rule as Dictionary
			var counts: Dictionary = context.get("item_counts", {})
			return int(counts.get(str(r.get("id", "")), 0)) >= int(r.get("min", 1))
		"skill_level":
			var r := rule as Dictionary
			var levels: Dictionary = context.get("skill_levels", {})
			return int(levels.get(str(r.get("id", "")), 0)) >= int(r.get("min", 0))
		"player_money":
			return int(context.get("money", 0)) >= int((rule as Dictionary).get("min", 0))
		"player_energy":
			return float(context.get("energy", 0.0)) >= float((rule as Dictionary).get("min", 0.0))
		"player_health":
			return int(context.get("health", 0)) >= int((rule as Dictionary).get("min", 0))
		"standing":
			var r := rule as Dictionary
			var standings: Dictionary = context.get("standings", {})
			return float(standings.get(str(r.get("axis", "")), 0.0)) >= float(r.get("min", 0.0))
		"opinion":
			var r := rule as Dictionary
			var opinions: Dictionary = context.get("opinions", {})
			return float(opinions.get(str(r.get("npc", "")), 0.0)) >= float(r.get("min", 0.0))
		"event_flag":
			var flags: Array = context.get("event_flags", [])
			return flags.has(str(rule))
		"not":
			var sub := rule as Dictionary
			for sub_key: String in sub:
				return not _evaluate_one(sub_key, sub[sub_key], context)
			return true
		_:
			# Backward compat (dialogue.json v3): the pre-ADR-035 dot-notation
			# "reputation.AXIS" keys, e.g. "reputation.manor": {"min": 50}.
			# GameData.load_all() rejects any other unrecognized key at load
			# time (ADR-035) - this fallback exists for defense in depth, not
			# as the real enforcement point.
			if key.begins_with("reputation."):
				var axis := key.substr("reputation.".length())
				var r := rule as Dictionary
				var standings: Dictionary = context.get("standings", {})
				return float(standings.get(axis, 0.0)) >= float(r.get("min", 0.0))
			return true
