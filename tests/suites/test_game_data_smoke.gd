extends RefCounted
## Smoke coverage for GameData: every data file loads and key lookups return
## the locked Sprint 1 values. Instantiates GameData directly (no autoloads).
## ADR-040 additions: the chores.json demesne block and the feature-rect
## helpers the spatial chore gates query.

const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")


func suite_name() -> String:
	return "game_data_smoke"


func run(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	t.eq(int(gd.get_crop("turnip").get("growth_days", -1)), 3, "turnip growth days")
	t.eq(gd.get_crop("cabbage").get("seasons", []), ["summer"], "cabbage summer only")
	t.eq(int(gd.get_item("spear").get("damage", -1)), 12, "spear damage")
	t.eq(int(gd.get_item("turnip_seed").get("price", -1)), 2, "seed price")
	t.eq(gd.get_weather_chances("spring").get("rain", -1.0), 0.3, "spring rain chance")
	t.ok(gd.is_market_day(3), "day 3 is a market day")
	t.not_ok(gd.is_market_day(4), "day 4 is not a market day")
	t.eq(gd.get_market_buy_price("turnip"), 5, "turnip base buy price")
	t.eq(int(gd.get_tithe_data().get("base_amount", -1)), 20, "tithe base amount")
	t.eq(int(gd.get_chore("till_demesne").get("credit", -1)), 3, "chore credit")
	t.eq(int(gd.get_demesne_config().get("needs_water_moisture_below", -1)), 50,
		"demesne water threshold cast to int")
	t.eq(int(gd.get_demesne_config().get("sheaves_max", -1)), 12,
		"demesne sheaf cap cast to int")
	# ADR-034: stewards_demesne lives in the manor zone's feature list (Stage
	# 1's own placement - the lord's demesne belongs at his manor), not
	# fallowfield's - a caller must name the zone explicitly.
	t.eq(gd.get_feature_rect("stewards_demesne", "manor"), Rect2i(4, 6, 8, 6),
		"demesne feature rect from farm_map.json's manor zone")
	t.ok(gd.is_in_feature(Vector2i(11, 11), "stewards_demesne", "manor"),
		"rect corner tile is inside the demesne")
	t.not_ok(gd.is_in_feature(Vector2i(12, 12), "stewards_demesne", "manor"),
		"tile past the rect edge is outside the demesne")
	t.eq(gd.get_feature_rect("stewards_demesne"), Rect2i(-1, -1, 0, 0),
		"the demesne does not exist in fallowfield, the only zone reachable before Sprint 15b")
	t.eq(int(gd.get_enemy("bandit_melee").get("health", -1)), 20, "bandit health")
	t.ok(gd.get_villager("villager_3").get("traits", []).has("thief"), "villager thief trait")
	var spring_raids: Array[Dictionary] = gd.get_scripted_raids("spring")
	t.eq(int(spring_raids[0].get("day", -1)), 15, "scripted raid day")
	t.eq(int((spring_raids[0].get("enemies", [])[0] as Dictionary).get("count", -1)), 2,
		"raid enemy count")
	t.eq(gd.get_quality_tier("fine").get("energy_mult", -1.0), 1.5, "fine energy mult")
	t.eq(int(gd.get_reputation_effect("attack_villager").get("manor", -99)), -5,
		"attack reputation effect")
	t.eq(int(gd.get_building("storage_chest").get("cost_coin", -1)), 40,
		"storage chest coin cost")
	t.eq(int(gd.get_building("storage_chest").get("footprint_w", -1)), 1,
		"storage chest footprint")
	t.eq(int((gd.get_building("storage_chest").get("cost_materials", {})).get("flint", -1)), 5,
		"storage chest flint cost")
	t.eq(int(gd.get_building("fence").get("deterrence_bonus", -1)), 1,
		"fence deterrence bonus")
	t.eq((gd.get_tenure_data().get("strips", []) as Array).size(), 3,
		"three tenure strips")
	t.eq(int(gd.get_villager_schedule("steward").get("work_start_hour", -1)), 7,
		"steward work_start_hour cast to int")
	t.eq(int(gd.get_villager_schedule("steward").get("work_end_hour", -1)), 20,
		"steward work_end_hour cast to int")
	t.eq(int(gd.get_requests_config().get("max_active_requests", -1)), 2,
		"requests max_active_requests cast to int")
	var first_template: Dictionary = (gd.get_requests_config().get("templates", [])[0] as Dictionary)
	t.eq(int(first_template.get("quantity", -1)), 3,
		"request template quantity cast to int")
	t.eq((gd.get_manor_data().get("court_days", []) as Array).size(), 2,
		"two court days")
	t.eq(int((gd.get_manor_data().get("court_days", []) as Array)[0]), 12,
		"court day 12 cast to int")
	t.eq(int(gd.get_manor_data().get("fines", {}).get("witnessed_violence", -1)), 15,
		"violence fine")
	t.eq(int(gd.get_manor_data().get("corvee", {}).get("notice_days", -1)), 1,
		"corvee notice_days cast to int")
	t.eq(int((gd.get_manor_data().get("black_market", {}).get("visit_days", []) as Array)[0]), 9,
		"black-market visit day 9 cast to int")
	t.eq(float(gd.get_manor_data().get("black_market", {}).get("price_premium_pct", -1.0)), 0.25,
		"black-market premium stays float")
	t.eq(float(gd.get_manor_data().get("price_drift", {}).get("market_day_price_swing_pct", -1.0)), 0.05,
		"price drift swing")
	t.eq(int(gd.get_reputation_effect("fail_corvee").get("manor", -99)), -4,
		"fail_corvee reputation effect")
	t.eq(int(gd.get_reputation_effect("fail_court_fine").get("manor", -99)), -6,
		"fail_court_fine reputation effect")
	t.eq(int(gd.get_enemy("raid_leader").get("health", -1)), 35, "raid leader health")
	t.eq(int(gd.get_clues_config().get("clue_count", -1)), 3, "clue count cast to int")
	t.eq(int(gd.get_item("guard_dog").get("deterrence_bonus", -1)), 5,
		"guard dog deterrence cast to int")
	t.eq(str(gd.get_item("hired_guard").get("type", "")), "defense",
		"hired guard is a defense item")
	t.eq(int(gd.get_raid_settings().get("dynamic_raid_earliest_day", -1)), 16,
		"dynamic raid earliest day cast to int")
	t.eq(int((gd.raids_cfg.get("dynamic_enemy_pool", [])[0] as Dictionary).get("weight", -1)), 50,
		"dynamic enemy pool weight cast to int")
	t.eq(int(gd.get_reputation_effect("accuse_falsely").get("village", -99)), -8,
		"accuse_falsely village effect")
	t.eq(int(gd.player_cfg.get("wound_recovery_days", -1)), 1,
		"wound recovery days loaded")
	t.eq(int(gd.get_manor_data().get("fines", {}).get("false_accusation", -1)), 15,
		"false-accusation fine")
	t.eq(str(gd.get_item("wood").get("type", "")), "material", "wood is a material")
	t.ok(gd.get_item("wood").get("stackable", false), "wood is stackable")
	var forage_spawns: Dictionary = gd.get_forage_config().get("spawns", {})
	for soil: Variant in forage_spawns:
		var soil_entries: Array = forage_spawns[soil]
		var has_wood := false
		var has_flint := false
		for entry: Variant in soil_entries:
			var item_id := str((entry as Dictionary).get("item_id", ""))
			if item_id == "wood":
				has_wood = true
			if item_id == "flint":
				has_flint = true
		t.ok(has_wood, "wood spawns on %s soil" % str(soil))
		t.ok(has_flint, "flint spawns on %s soil" % str(soil))
	t.eq(int(gd.get_animal_species("chicken").get("purchase_price", -1)), 30,
		"chicken purchase price cast to int")
	t.eq(int(gd.get_animal_species("goat").get("feed_amount", -1)), 2,
		"goat feed amount cast to int")
	t.eq(int((gd.get_animal_species("chicken").get("quality_weights", {})).get("fine", -1)), 25,
		"animal quality weights cast to int")
	t.eq(int(gd.get_building("coop").get("animal_capacity", -1)), 4,
		"coop animal capacity cast to int")
	t.eq(int(gd.get_item("egg").get("energy_base", -1)), 6, "egg energy base")
	t.eq(gd.get_market_buy_price("egg"), 4, "egg market buy price")
	t.section_done("smoke")
