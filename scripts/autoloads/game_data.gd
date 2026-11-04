extends Node

## Loads all data/*.json at boot and answers typed lookups. The ONLY file I/O
## owner for static game data. JSON numbers arrive as floats; integer fields
## are cast here (CLAUDE.md section 6.2), never downstream.

const DATA_DIR := "res://data"

const CROP_INT_KEYS: Array[String] = [
	"growth_days", "yield_min", "yield_max",
	"seed_recovery_min", "seed_recovery_max", "moisture_min", "moisture_max",
	"spoil_after_days", "fertility_depletion", "fertility_min",
]
const ITEM_INT_KEYS: Array[String] = [
	"price", "damage", "energy_cost", "capacity", "water_amount", "tier",
	"deterrence_bonus", "fertilize_amount",
]
const TIME_INT_KEYS: Array[String] = [
	"minutes_per_hour", "days_per_season", "days_per_week", "weeks_per_season",
	"wake_hour", "sleep_hour",
]
const PLAYER_INT_KEYS: Array[String] = [
	"start_money", "sleep_health_regen", "exhaustion_recover_hours",
	"exhaustion_recover_energy", "pass_out_health_floor",
	"interaction_assist_range",
]
const SOIL_INT_KEYS: Array[String] = [
	"fine_quality_bonus", "choice_quality_bonus", "fertility_init",
	"high_fertility_quality_bonus", "high_fertility_threshold",
]
const TITHE_INT_KEYS: Array[String] = ["base_amount", "merchet_fee"]
const CHORES_INT_KEYS: Array[String] = ["energy_cost", "credit"]
## ADR-040: chores.json v2's demesne block - the spatial-chore tunables
## (moisture threshold, sheaf stockpile size/replenishment, carry load size).
const CHORES_DEMESNE_INT_KEYS: Array[String] = [
	"needs_water_moisture_below", "sheaves_max", "sheaves_replenish_amount",
	"sheaves_replenish_interval_days", "sheaves_per_action",
]
const CHURCH_INT_KEYS: Array[String] = [
	"suggested_donation", "standing_per_coin", "large_donation_threshold",
]
const REPUTATION_INT_KEYS: Array[String] = ["manor", "village", "church", "opinion_delta"]
const ENEMY_INT_KEYS: Array[String] = ["health", "damage", "speed", "reach"]
const RAID_INT_KEYS: Array[String] = [
	"deterrence_decay_per_day", "deterrence_gain_per_victory",
	"min_deterrence_no_raid", "dynamic_raid_earliest_day",
	"dynamic_raid_size_min", "dynamic_raid_size_max", "night_raid_size_bonus",
]
const CLUE_INT_KEYS: Array[String] = ["clue_count"]
const BUILDING_INT_KEYS: Array[String] = [
	"footprint_w", "footprint_h", "cost_coin", "build_days", "deterrence_bonus",
	"capacity", "animal_capacity",
]
const DEFAULT_ZONE_ID := "fallowfield"
const ZONE_INT_KEYS: Array[String] = ["x", "y", "x_min", "x_max", "y_min", "y_max"]
const INTERIOR_FIXTURE_INT_KEYS: Array[String] = ["index"]
const TENURE_INT_KEYS: Array[String] = ["x", "y", "width", "height"]
const ANIMAL_INT_KEYS: Array[String] = [
	"max_happiness", "happiness_fine_weight_scale", "happiness_choice_weight_scale",
]
const ANIMAL_SPECIES_INT_KEYS: Array[String] = [
	"purchase_price", "feed_amount", "product_cycle_days",
	"happiness_gain_fed", "happiness_loss_unfed",
]
const SKILL_LEVEL_EFFECT_INT_KEYS: Array[String] = [
	"quality_choice_bonus", "yield_bonus", "credit_bonus", "daily_cap_bonus",
]
const FORAGE_INT_KEYS: Array[String] = [
	"gather_energy_cost", "max_concurrent_spawns", "max_digs_per_day",
]
const FORAGE_SPAWN_ENTRY_INT_KEYS: Array[String] = ["weight", "yield_min", "yield_max"]
const REQUEST_INT_KEYS: Array[String] = [
	"quantity", "days_to_complete", "reward_coin", "reward_opinion",
]
const RECIPE_INT_KEYS: Array[String] = [
	"output_count", "energy_cost", "craft_days", "skill_level_required",
]
const DIALOGUE_INT_KEYS: Array[String] = ["priority"]
const FESTIVAL_INT_KEYS: Array[String] = ["day", "start_hour", "end_hour"]
## E4/ADR-035: the closed condition-key vocabulary. "reputation.AXIS"
## (dialogue.json v3's dot-notation form) is checked separately via
## begins_with, not listed here.
const DIALOGUE_CONDITION_KEYS: Array[String] = [
	"time", "season", "weather", "is_market_day", "is_mass_day", "is_festival",
	"has_item", "skill_level", "player_money", "player_energy", "player_health",
	"standing", "opinion", "event_flag", "not",
]
const DIALOGUE_FREQUENCIES: Array[String] = ["always", "once_per_conversation", "once_per_day"]
const BOARD_ORDER_TEMPLATE_INT_KEYS: Array[String] = [
	"min_quantity", "max_quantity", "base_reward_money", "standing_amount",
	"deadline_days", "weight",
]
const ECONOMY_INT_KEYS: Array[String] = [
	"max_active_orders", "orders_per_market_day_min", "orders_per_market_day_max",
]
const MARRIAGE_INT_KEYS: Array[String] = [
	"proposal_opinion_threshold", "spouse_daily_gift_cap", "chore_water_cells",
]
## ADR-041/Sprint 16 Phase 1: data/sprites.json's shared sprite/animation
## manifest. Top-level entry ints (both static and animated kinds); nested
## `directions`/`frames` sub-dictionaries get their own key lists below and
## are cast in _cast_nested_ints(), matching every other nested-int pattern
## in this file (dialogues, festivals, forage spawns, ...).
const SPRITE_INT_KEYS: Array[String] = [
	"sheet_w", "sheet_h", "frame_w", "frame_h", "anchor_x", "anchor_y",
	"footprint_w", "footprint_h",
]
const SPRITE_DIRECTION_INT_KEYS: Array[String] = ["start", "count"]
const SPRITE_FRAME_INT_KEYS: Array[String] = ["x", "y", "w", "h"]
## ADR-042: terrain_manifest.json's variant/transition/scatter sprite entries
## reuse the sprites manifest's shape, so their int fields get the same
## boundary cast (frame/sheet dims, anchors, footprint) via the same key
## list; `density` on scatter entries is a float and is never cast.
const TERRAIN_SPRITE_INT_KEYS: Array[String] = [
	"sheet_w", "sheet_h", "frame_w", "frame_h", "anchor_x", "anchor_y",
	"footprint_w", "footprint_h",
]
## Display-measure plurals (crops.json v5): the two genuinely irregular
## measure words in use. Everything else pluralizes with a plain "s".
const MEASURE_PLURALS := {
	"sheaf": "sheaves",
	"bunch": "bunches",
}
## Crop-name plurals for format_produce_count: mass nouns and names that are
## already plural stay as-is. Cabbage reads as a mass noun under its "head"
## measure ("a head of cabbage", "3 heads of cabbage"). Deliberately a tiny
## table, not a general English pluralizer - there are only nine crops.
const CROP_NAME_PLURALS := {
	"Barley": "barley",
	"Cabbage": "cabbage",
	"Flax": "flax",
	"Oats": "oats",
}

var crops: Dictionary = {}
var items: Dictionary = {}
var villagers: Dictionary = {}
var time_cfg: Dictionary = {}
var player_cfg: Dictionary = {}
var weather_seasons: Dictionary = {}
var soil_types: Dictionary = {}
var farm_map: Dictionary = {}
var zones_cfg: Dictionary = {}
var zones_default_zone := ""
var zones_spawn: Dictionary = {}
var market_cfg: Dictionary = {}
var tithe_cfg: Dictionary = {}
var chores: Dictionary = {}
var demesne_cfg: Dictionary = {}
var church_cfg: Dictionary = {}
var reputation_actions: Dictionary = {}
var reputation_thresholds: Dictionary = {}
var enemies: Dictionary = {}
var raids_cfg: Dictionary = {}
var quality_tiers: Dictionary = {}
var dialogues: Array = []
var skills: Dictionary = {}
var forage_cfg: Dictionary = {}
var buildings: Dictionary = {}
var tenure_cfg: Dictionary = {}
var requests_cfg: Dictionary = {}
var manor_cfg: Dictionary = {}
var clues_cfg: Dictionary = {}
var recipes: Dictionary = {}
var animals_cfg: Dictionary = {}
var festivals: Dictionary = {}
var economy_cfg: Dictionary = {}
var board_orders_cfg: Dictionary = {}
var marriage_cfg: Dictionary = {}
var sprites: Dictionary = {}
## Sprint 16 crop art: presentation-only lookup from crop id to ordered
## stage sprites. Kept beside the merged manifest rather than crops.json so
## growth mechanics remain independent from rendered textures.
var crop_stage_sets: Dictionary = {}
## ADR-042: data/terrain_manifest.json - material families (variants),
## ordered transition pairs (4-bit mask -> tile), and scatter/decal entries.
## FarmRenderer is the only consumer; a missing/empty manifest fails soft to
## today's flat-color polygons, exactly like get_sprite's {} contract.
var terrain_manifest: Dictionary = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	crops = _load_id_file("crops.json", "crops", CROP_INT_KEYS)
	items = _load_id_file("items.json", "items", ITEM_INT_KEYS)
	villagers = _load_id_file("villagers.json", "villagers", [])
	time_cfg = _load_flat_file("time.json", TIME_INT_KEYS)
	player_cfg = _load_flat_file("player.json", PLAYER_INT_KEYS)
	weather_seasons = _read_json("weather.json").get("seasons", {})
	soil_types = _read_json("soil_types.json").get("soils", {})
	farm_map = _read_json("farm_map.json")
	zones_cfg = _load_zones("zones.json")
	market_cfg = _read_json("market.json")
	tithe_cfg = _load_flat_file("tithe.json", TITHE_INT_KEYS)
	chores = _load_id_file("chores.json", "chores", CHORES_INT_KEYS)
	# ADR-040: chores.json v2 splits the per-chore list (keyed by id above)
	# from the demesne block (a flat config). Two reads of a tiny file at
	# boot rather than teaching _load_id_file a second output channel.
	demesne_cfg = _cast_ints(
		_read_json("chores.json").get("demesne", {}), CHORES_DEMESNE_INT_KEYS)
	church_cfg = _load_flat_file("church.json", CHURCH_INT_KEYS)
	reputation_actions = _read_json("reputation.json").get("actions", {})
	reputation_thresholds = _read_json("reputation.json").get("thresholds", {})
	enemies = _load_enemies("enemies.json")
	raids_cfg = _load_flat_file("raids.json", RAID_INT_KEYS)
	quality_tiers = _read_json("quality_tiers.json").get("tiers", {})
	dialogues = _read_json("dialogue.json").get("dialogues", [])
	_validate_dialogue()
	skills = _read_json("skills.json").get("skills", {})
	forage_cfg = _read_json("forage.json")
	buildings = _load_buildings("buildings.json")
	tenure_cfg = _load_flat_file("tenure.json", TENURE_INT_KEYS)
	requests_cfg = _read_json("requests.json")
	manor_cfg = _read_json("manor.json")
	clues_cfg = _load_flat_file("clues.json", CLUE_INT_KEYS)
	recipes = _load_id_file("recipes.json", "recipes", RECIPE_INT_KEYS)
	animals_cfg = _read_json("animals.json")
	festivals = _load_id_file("festivals.json", "festivals", FESTIVAL_INT_KEYS)
	economy_cfg = _load_flat_file("economy.json", ECONOMY_INT_KEYS)
	board_orders_cfg = _read_json("board_orders.json")
	marriage_cfg = _load_flat_file("marriage.json", MARRIAGE_INT_KEYS)
	# Sprint 16 (ADR-041): one file per workstream (world dressing/structures/
	# actors/UI) rather than one shared sprites.json - four agents in four
	# worktrees appending to the same JSON file would conflict on every merge
	# even when their actual entries never overlap. Ids are expected unique
	# across all four; Dictionary.merge keeps first-seen on a clash rather
	# than silently overwriting, which is exactly what should surface a
	# genuine id collision as a bug instead of hiding it.
	sprites = {}
	for sprite_file: String in [
		"sprites_world_dressing.json", "sprites_structures.json",
		"sprites_actors.json", "sprites_ui.json", "sprites_interiors.json",
	]:
		sprites.merge(_load_id_file(sprite_file, "sprites", SPRITE_INT_KEYS))
	crop_stage_sets = {}
	for sprite_id: Variant in sprites:
		var entry := sprites[sprite_id] as Dictionary
		if str(entry.get("kind", "")) == "crop_stage_set":
			var crop_id := str(entry.get("crop_id", ""))
			if not crop_id.is_empty():
				crop_stage_sets[crop_id] = entry
	# ADR-042: textured terrain manifest. Loaded after the sprites files and
	# cast inside its own loader (keyed by material/pair/mask, not a
	# list_key array), before _cast_nested_ints so every data file is
	# boundary-cast in one boot pass.
	terrain_manifest = _load_terrain_manifest("terrain_manifest.json")
	_cast_nested_ints()


func get_crop(crop_id: String) -> Dictionary:
	return crops.get(crop_id, {})


## ADR-041: a data/sprites.json entry (static or animated), or {} when unset -
## SpriteManifest's static helper functions all treat {} as "no asset", so
## callers fail soft to their primitive fallback rather than crashing.
func get_sprite(sprite_id: String) -> Dictionary:
	return sprites.get(sprite_id, {})


## Presentation-only stage-set lookup. An absent set deliberately returns {}
## so FarmRenderer keeps drawing its established primitive crop dot.
func get_crop_stage_set(crop_id: String) -> Dictionary:
	return crop_stage_sets.get(crop_id, {})


## ADR-042: one terrain material family entry ({"variants": [...]}) by id -
## ids are "<soil>_<surface>" where surface is grass/tilled/tilled_wet
## (terrain_material_id() in FarmRenderer composes them). The optional season
## is presentation-only: terrain state and material ids stay season-neutral.
## {} when unset, so the renderer fails soft to flat-color polygons.
func get_terrain_material(material_id: String, season: String = "") -> Dictionary:
	return _terrain_season_block(season).get("materials", {}).get(material_id, {})


## ADR-042: the transition tile for one ordered material pair
## ("<center>|<other>", center first - a grass cell and a tilled cell ask
## for different directional art) and one 4-bit edge mask key. Mask chars
## are N,E,S,W in FarmRenderer's NEIGHBOR_OFFSETS order ("1000" = only the
## north/(0,-1) edge borders the other material). {} when unset - the
## renderer degrades that boundary to the material's base variant.
func get_terrain_transition(pair_key: String, mask_key: String, season: String = "") -> Dictionary:
	return _terrain_season_block(season).get("transitions", {}).get(pair_key, {}) \
		.get("entries", {}).get(mask_key, {})


## ADR-042: scatter/decal entries for one material id - each is a
## sprite-manifest-shaped entry plus a float `density` (hash-roll threshold
## in FarmRenderer). [] when unset.
func get_terrain_scatter(material_id: String, season: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Variant in _terrain_season_block(season).get("scatter", {}).get(material_id, []):
		out.append(entry as Dictionary)
	return out


func get_all_crop_ids() -> Array[String]:
	return _string_keys(crops)


func get_item(item_id: String) -> Dictionary:
	return items.get(item_id, {})


func get_all_item_ids() -> Array[String]:
	return _string_keys(items)


func get_villager(villager_id: String) -> Dictionary:
	return villagers.get(villager_id, {})


func get_villager_schedule(villager_id: String) -> Dictionary:
	return get_villager(villager_id).get("schedule", {})


func get_all_villager_ids() -> Array[String]:
	return _string_keys(villagers)


func get_villagers_by_faction(faction: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: Variant in villagers:
		var v: Dictionary = villagers[id]
		if str(v.get("faction", "")) == faction:
			out.append(v)
	return out


func get_weather_chances(season: String) -> Dictionary:
	return weather_seasons.get(season, {})


func get_soil_at(x: int, y: int, zone_id := DEFAULT_ZONE_ID) -> String:
	var grid: Array = _farm_zone(zone_id).get("grid", [])
	if y < 0 or y >= grid.size():
		return ""
	var row := grid[y] as Array
	if x < 0 or x >= row.size():
		return ""
	return str(row[x])


func get_zone_ids() -> Array[String]:
	return _string_keys(zones_cfg)


func get_zone(zone_id: String) -> Dictionary:
	## zones.json metadata merged with farm_map.json geometry: dims, soil
	## grid, and features are per-zone data living in farm_map; the zone
	## entry in zones.json carries name/tunables/exits. Consumers that need
	## the whole picture (bounds checks, geometry tests) call this.
	var zone: Dictionary = farm_map.get("zones", {}).get(zone_id, {})
	if zone.is_empty():
		return {}
	var out: Dictionary = (zones_cfg.get(zone_id, {}) as Dictionary).duplicate()
	out["width"] = int(zone.get("width", 0))
	out["height"] = int(zone.get("height", 0))
	out["grid"] = zone.get("grid", [])
	out["features"] = zone.get("features", [])
	return out


func get_zone_metadata(zone_id: String) -> Dictionary:
	return zones_cfg.get(zone_id, {})


## Presentation-only shell and fixture recipe for an interior. Fixtures remain
## independent records so later decorating can place, replace, or remove them
## without cutting openings into the room shell texture.
func get_zone_interior_visual(zone_id: String) -> Dictionary:
	var visual: Dictionary = get_zone_metadata(zone_id).get("interior_visual", {})
	return visual.duplicate(true)


func get_zone_exits(zone_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Variant in get_zone_metadata(zone_id).get("exits", []):
		out.append(entry as Dictionary)
	return out


## Door transitions are local to a zone and do not use map edges. This keeps
## an interior doorway such as the cottage's east wall data-driven while the
## existing edge-exit path remains responsible for ordinary region travel.
func get_zone_doors(zone_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Variant in get_zone_metadata(zone_id).get("doors", []):
		out.append(entry as Dictionary)
	return out


func get_spawn_point() -> Dictionary:
	return zones_spawn


func get_default_zone() -> String:
	return zones_default_zone


func get_soil_properties(soil_name: String) -> Dictionary:
	return soil_types.get(soil_name, {})


func get_feature_at(x: int, y: int, zone_id := DEFAULT_ZONE_ID) -> String:
	var features: Array = _farm_zone(zone_id).get("features", [])
	for entry: Variant in features:
		var f := entry as Dictionary
		var fx := int(f.get("x", -1))
		var fy := int(f.get("y", -1))
		var fw := int(f.get("width", 1))
		var fh := int(f.get("height", 1))
		if x >= fx and x < fx + fw and y >= fy and y < fy + fh:
			return str(f.get("feature", ""))
	return ""


## Every fixed manor feature anchor (player_house, well x2, chapel,
## market_zone, stewards_demesne), already int-cast. FeatureRenderer reads
## this to place structures without hardcoding farm_map.json's coordinates.
func get_all_features(zone_id := DEFAULT_ZONE_ID) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Variant in _farm_zone(zone_id).get("features", []):
		out.append(entry as Dictionary)
	return out


## Forward lookup (feature id -> tile), the inverse of get_feature_at(). Used
## by the spouse's home-schedule anchor so npc.gd doesn't hardcode a second
## magic coordinate the way main.gd's CHAPEL_TILE already does. (-1,-1) means
## not found - real map tiles are never negative.
func get_feature_tile(feature_id: String, zone_id := DEFAULT_ZONE_ID) -> Vector2i:
	for entry: Variant in _farm_zone(zone_id).get("features", []):
		var f := entry as Dictionary
		if str(f.get("feature", "")) == feature_id:
			return Vector2i(int(f.get("x", 0)), int(f.get("y", 0)))
	return Vector2i(-1, -1)


## The full footprint of a feature as a Rect2i (features carry optional
## width/height, defaulting to 1x1). An empty rect at (-1,-1) means not
## found. ADR-040's demesne chores ask FarmGrid/Player "is this tile on the
## lord's demesne" through this one helper instead of re-deriving the rect
## from farm_map.json in gameplay scripts. ADR-034 note: `stewards_demesne`
## lives in the `manor` zone's feature list, not `fallowfield`'s - a caller
## must pass the right zone_id (FarmGrid passes its own _resolved_zone_id())
## or this returns the empty rect for a zone that doesn't carry the feature.
func get_feature_rect(feature_id: String, zone_id := DEFAULT_ZONE_ID) -> Rect2i:
	for entry: Variant in _farm_zone(zone_id).get("features", []):
		var f := entry as Dictionary
		if str(f.get("feature", "")) == feature_id:
			return Rect2i(
				int(f.get("x", 0)), int(f.get("y", 0)),
				int(f.get("width", 1)), int(f.get("height", 1)))
	return Rect2i(-1, -1, 0, 0)


func is_in_feature(pos: Vector2i, feature_id: String, zone_id := DEFAULT_ZONE_ID) -> bool:
	var rect := get_feature_rect(feature_id, zone_id)
	return pos.x >= rect.position.x and pos.x < rect.end.x \
		and pos.y >= rect.position.y and pos.y < rect.end.y


func get_map_width(zone_id := DEFAULT_ZONE_ID) -> int:
	return int(_farm_zone(zone_id).get("width", 0))


func get_map_height(zone_id := DEFAULT_ZONE_ID) -> int:
	return int(_farm_zone(zone_id).get("height", 0))


func is_within_farm(x: int, y: int, zone_id := DEFAULT_ZONE_ID) -> bool:
	return x >= 0 and x < get_map_width(zone_id) and y >= 0 and y < get_map_height(zone_id)


func is_market_day(day: int, _season: String = "spring") -> bool:
	var days: Array = market_cfg.get("market_days", [])
	return days.has(day)


func get_market_buy_price(item_id: String) -> int:
	var prices: Dictionary = market_cfg.get("buy_prices", {})
	return int(prices.get(item_id, -1))


func get_market_buy_prices() -> Dictionary:
	return market_cfg.get("buy_prices", {})


func get_market_toll_percent() -> float:
	return float(market_cfg.get("toll_percent", 0.0))


func get_stall_inventory() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Variant in market_cfg.get("stall_inventory", []):
		out.append(entry as Dictionary)
	return out


func get_tithe_data() -> Dictionary:
	return tithe_cfg


func get_labor_credit_cap() -> int:
	var labor: Dictionary = tithe_cfg.get("labor", {})
	return int(labor.get("daily_credit_cap", 0))


func get_chore(chore_id: String) -> Dictionary:
	return chores.get(chore_id, {})


func get_all_chore_ids() -> Array[String]:
	return _string_keys(chores)


## ADR-040: the demesne config block from chores.json v2 - delivery feature,
## water threshold, sheaf stockpile/replenishment, and carry load size. The
## single source of truth for the spatial-chore tunables.
func get_demesne_config() -> Dictionary:
	return demesne_cfg


func get_church_data() -> Dictionary:
	return church_cfg


func get_reputation_effect(action: String) -> Dictionary:
	return reputation_actions.get(action, {})


func get_reputation_thresholds() -> Dictionary:
	return reputation_thresholds


func get_enemy(enemy_id: String) -> Dictionary:
	return enemies.get(enemy_id, {})


func get_scripted_raids(season: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Variant in raids_cfg.get("scripted_raids", []):
		var raid := entry as Dictionary
		if str(raid.get("season", "")) == season:
			out.append(raid)
	return out


func get_raid_settings() -> Dictionary:
	return {
		"deterrence_decay_per_day": int(raids_cfg.get("deterrence_decay_per_day", 0)),
		"deterrence_gain_per_victory": int(raids_cfg.get("deterrence_gain_per_victory", 0)),
		"min_deterrence_no_raid": int(raids_cfg.get("min_deterrence_no_raid", 0)),
		"dynamic_raid_earliest_day": int(raids_cfg.get("dynamic_raid_earliest_day", 0)),
		"dynamic_raid_size_min": int(raids_cfg.get("dynamic_raid_size_min", 0)),
		"dynamic_raid_size_max": int(raids_cfg.get("dynamic_raid_size_max", 0)),
		"night_raid_size_bonus": int(raids_cfg.get("night_raid_size_bonus", 0)),
	}


func get_quality_tier(tier: String) -> Dictionary:
	return quality_tiers.get(tier, {})


func get_dialogue_for(npc_id: String, reputation: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	for entry: Variant in dialogues:
		var line := entry as Dictionary
		if str(line.get("npc_id", "")) != npc_id:
			continue
		if not _dialogue_conditions_pass(line.get("conditions", {}), reputation):
			continue
		out.append(str(line.get("text", "")))
	return out


## E4/ADR-035: every raw line for an npc_id, unfiltered by conditions -
## DialogueManager runs ConditionEvaluator/priority/frequency selection
## itself. Distinct from get_dialogue_for(), which stays untouched (an
## existing test asserts its current filtered-list behavior).
func get_dialogue_lines_for(npc_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Variant in dialogues:
		var line := entry as Dictionary
		if str(line.get("npc_id", "")) == npc_id:
			out.append(line)
	return out


func get_time_config() -> Dictionary:
	return time_cfg


func get_skill(skill_id: String) -> Dictionary:
	return skills.get(skill_id, {})


func get_skill_xp_thresholds(skill_id: String) -> Array:
	return get_skill(skill_id).get("xp_thresholds", [0])


func get_skill_xp_source(skill_id: String, source_id: String) -> float:
	return float(get_skill(skill_id).get("xp_sources", {}).get(source_id, 0))


func get_skill_level_effects(skill_id: String, level: int) -> Dictionary:
	var effects: Array = get_skill(skill_id).get("level_effects", [])
	if level < 0 or level >= effects.size():
		return {}
	return effects[level]


func get_forage_config() -> Dictionary:
	return forage_cfg


func get_building(building_id: String) -> Dictionary:
	return buildings.get(building_id, {})


func get_all_building_ids() -> Array[String]:
	return _string_keys(buildings)


func get_recipe(recipe_id: String) -> Dictionary:
	return recipes.get(recipe_id, {})


func get_all_recipe_ids() -> Array[String]:
	return _string_keys(recipes)


func get_animal_species(species_id: String) -> Dictionary:
	return animals_cfg.get("species", {}).get(species_id, {})


func get_festival(festival_id: String) -> Dictionary:
	return festivals.get(festival_id, {})


func get_all_festivals() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: Variant in festivals:
		out.append(festivals[id])
	return out


func get_tenure_data() -> Dictionary:
	return tenure_cfg


func get_marriage_config() -> Dictionary:
	return marriage_cfg


func get_marriage_candidates() -> Array[String]:
	var out: Array[String] = []
	for id: Variant in marriage_cfg.get("candidates", []):
		out.append(str(id))
	return out


func get_requests_config() -> Dictionary:
	return requests_cfg


func get_manor_data() -> Dictionary:
	return manor_cfg


func get_economy_data() -> Dictionary:
	return economy_cfg


func get_board_orders_templates() -> Array:
	return board_orders_cfg.get("orders", [])


## E6/ADR-037 display: count-aware produce phrasing for the board panel
## ("a bushel of peas" / "4 bushels of peas"). Pure query - no state. Returns
## "" when the crop or its measure is unknown so callers can fall back to the
## raw-count format instead of inventing text.
func format_produce_count(crop_id: String, count: int) -> String:
	var crop := get_crop(crop_id)
	var measure := str(crop.get("measure", ""))
	if crop.is_empty() or measure.is_empty():
		return ""
	var name := _pluralize_crop_name(str(crop.get("name", crop_id)))
	if count == 1:
		return "%s %s of %s" % [_indefinite_article(measure), measure, name]
	return "%d %s of %s" % [count, _pluralize_measure(measure), name]


func get_clues_config() -> Dictionary:
	return clues_cfg


func _farm_zone(zone_id: String) -> Dictionary:
	return farm_map.get("zones", {}).get(zone_id, {})


func _string_keys(source: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key: Variant in source:
		out.append(str(key))
	return out


## E4/ADR-035: load-time validation, not runtime enforcement -
## ConditionEvaluator's own unknown-key fallback (returns true) is defense
## in depth, this is where a bad dialogue.json entry is actually caught.
## Soft failures (push_error + skip/default), matching this file's existing
## tolerance for malformed data rather than crashing boot.
func _validate_dialogue() -> void:
	var npc_ids_seen: Dictionary = {}
	var npc_has_fallback: Dictionary = {}
	for entry: Variant in dialogues:
		var line := entry as Dictionary
		var npc_id := str(line.get("npc_id", ""))
		npc_ids_seen[npc_id] = true
		var conditions: Dictionary = line.get("conditions", {})
		if conditions.is_empty():
			npc_has_fallback[npc_id] = true
		for key: Variant in conditions:
			var key_str := str(key)
			if DIALOGUE_CONDITION_KEYS.has(key_str) or key_str.begins_with("reputation."):
				continue
			push_error("[GameData] dialogue.json: unknown condition key '%s' on an %s line"
				% [key_str, npc_id])
		var frequency := str(line.get("frequency", "always"))
		if not DIALOGUE_FREQUENCIES.has(frequency):
			push_error("[GameData] dialogue.json: invalid frequency '%s' on an %s line"
				% [frequency, npc_id])
	for npc_id: Variant in npc_ids_seen:
		if not npc_has_fallback.has(npc_id):
			push_error("[GameData] dialogue.json: NPC '%s' has no unconditioned fallback line"
				% str(npc_id))


func _dialogue_conditions_pass(conditions: Variant, reputation: Dictionary) -> bool:
	if not (conditions is Dictionary):
		return true
	var conds := conditions as Dictionary
	for key: Variant in conds:
		# Keys like "reputation.manor" read a standing from the reputation dict.
		var path := str(key).split(".")
		if path.size() != 2 or path[0] != "reputation":
			continue
		var value := int(reputation.get(path[1], 0))
		var rule := conds[key] as Dictionary
		if rule.has("min") and value < int(rule.get("min", 0)):
			return false
	return true


func _load_id_file(file_name: String, list_key: String, int_keys: Array[String]) -> Dictionary:
	var raw := _read_json(file_name)
	var out := {}
	for entry: Variant in raw.get(list_key, []):
		var row := entry as Dictionary
		out[str(row.get("id", ""))] = _cast_ints(row, int_keys)
	return out


func _load_zones(file_name: String) -> Dictionary:
	## zones.json is a list of zone entries like _load_id_file, but each
	## entry carries nested exit/arrive_at ints (ZONE_INT_KEYS at the
	## boundary) and the root carries default_zone/spawn - so it gets its
	## own loader rather than forcing _load_id_file to learn nested casts.
	var raw := _read_json(file_name)
	zones_default_zone = str(raw.get("default_zone", DEFAULT_ZONE_ID))
	zones_spawn = _cast_ints(raw.get("spawn", {}) as Dictionary, ZONE_INT_KEYS)
	var out := {}
	for entry: Variant in raw.get("zones", []):
		var zone := entry as Dictionary
		var zone_id := str(zone.get("id", ""))
		var exits: Array = zone.get("exits", [])
		for i in range(exits.size()):
			var e := exits[i] as Dictionary
			e["edge"] = str(e.get("edge", ""))
			e["to"] = str(e.get("to", ""))
			e = _cast_ints(e, ZONE_INT_KEYS)
			var arrive: Dictionary = e.get("arrive_at", {})
			arrive = _cast_ints(arrive, ZONE_INT_KEYS)
			e["arrive_at"] = arrive
			exits[i] = e
		var doors: Array = zone.get("doors", [])
		for i in range(doors.size()):
			var d := doors[i] as Dictionary
			d["to"] = str(d.get("to", ""))
			d = _cast_ints(d, ZONE_INT_KEYS)
			var door_arrive: Dictionary = d.get("arrive_at", {})
			door_arrive = _cast_ints(door_arrive, ZONE_INT_KEYS)
			d["arrive_at"] = door_arrive
			doors[i] = d
		zone["doors"] = doors
		var interior_visual: Dictionary = zone.get("interior_visual", {})
		if not interior_visual.is_empty():
			interior_visual["shell_sprite_id"] = str(interior_visual.get("shell_sprite_id", ""))
			var fixtures: Array = interior_visual.get("fixtures", [])
			for i in range(fixtures.size()):
				var fixture := fixtures[i] as Dictionary
				fixture["sprite_id"] = str(fixture.get("sprite_id", ""))
				fixture["side"] = str(fixture.get("side", ""))
				fixtures[i] = _cast_ints(fixture, INTERIOR_FIXTURE_INT_KEYS)
			interior_visual["fixtures"] = fixtures
			zone["interior_visual"] = interior_visual
		out[zone_id] = zone
	return out


func _load_enemies(file_name: String) -> Dictionary:
	var raw := _read_json(file_name)
	var out := {}
	for key: Variant in raw.get("enemies", {}):
		out[str(key)] = _cast_ints(raw["enemies"][key] as Dictionary, ENEMY_INT_KEYS)
	return out


func _load_buildings(file_name: String) -> Dictionary:
	## buildings.json is keyed by id like enemies.json, not a list_key array -
	## same loader shape, BUILDING_INT_KEYS applied at the boundary.
	var raw := _read_json(file_name)
	var out := {}
	for key: Variant in raw.get("buildings", {}):
		out[str(key)] = _cast_ints(raw["buildings"][key] as Dictionary, BUILDING_INT_KEYS)
	return out


## ADR-042: terrain_manifest.json is keyed by material id / transition pair /
## mask rather than a list_key array, so it gets its own loader. The
## variant/transition/scatter sprite entries are int-cast here (section 6.2);
## scatter `density` stays a float.
func _load_terrain_manifest(file_name: String) -> Dictionary:
	var out := _read_json(file_name)
	_cast_terrain_manifest_ints(out)
	return out


## Terrain manifests from ADR-042 v1 were a single material/transition block.
## v2 nests those same blocks under seasons. Keeping this compatibility seam
## here lets a partial or older manifest retain the exact fail-soft routing
## instead of forcing FarmRenderer to understand data-schema history.
func _terrain_season_block(season: String) -> Dictionary:
	var season_blocks: Dictionary = terrain_manifest.get("seasons", {})
	if season_blocks.is_empty():
		return terrain_manifest
	var default_season := str(terrain_manifest.get("default_season", "spring")).to_lower()
	var requested := season.to_lower()
	if requested.is_empty():
		requested = default_season
	var selected: Variant = season_blocks.get(requested, season_blocks.get(default_season, {}))
	if selected is Dictionary:
		return selected as Dictionary
	return {}


## Test seam mirroring _cast_nested_ints: every nested sprite entry in the
## terrain manifest (material variants, transition tiles, scatter entries)
## gets the same int boundary cast as sprites.json entries. JSON numbers
## arrive as floats; JSON.parse_string never hands back an int.
func _cast_terrain_manifest_ints(manifest: Dictionary) -> void:
	var season_blocks: Dictionary = manifest.get("seasons", {})
	if season_blocks.is_empty():
		_cast_terrain_season_block_ints(manifest)
		return
	for season: Variant in season_blocks:
		var block: Variant = season_blocks[season]
		if block is Dictionary:
			_cast_terrain_season_block_ints(block as Dictionary)


func _cast_terrain_season_block_ints(block: Dictionary) -> void:
	var materials: Dictionary = block.get("materials", {})
	for mat_id: Variant in materials:
		var mat := materials[mat_id] as Dictionary
		var variants: Array = mat.get("variants", [])
		for i in range(variants.size()):
			variants[i] = _cast_ints(variants[i] as Dictionary, TERRAIN_SPRITE_INT_KEYS)
	var transitions: Dictionary = block.get("transitions", {})
	for pair_key: Variant in transitions:
		var pair := transitions[pair_key] as Dictionary
		var entries: Dictionary = pair.get("entries", {})
		for mask_key: Variant in entries:
			entries[mask_key] = _cast_ints(
				entries[mask_key] as Dictionary, TERRAIN_SPRITE_INT_KEYS)
	var scatter: Dictionary = block.get("scatter", {})
	for mat_id: Variant in scatter:
		var entries: Array = scatter[mat_id]
		for i in range(entries.size()):
			entries[i] = _cast_ints(entries[i] as Dictionary, TERRAIN_SPRITE_INT_KEYS)


func _load_flat_file(file_name: String, int_keys: Array[String]) -> Dictionary:
	return _cast_ints(_read_json(file_name), int_keys)


func _cast_ints(entry: Dictionary, int_keys: Array[String]) -> Dictionary:
	var out := entry.duplicate()
	for key: String in int_keys:
		if out.has(key):
			out[key] = int(out[key])
	return out


func _cast_nested_ints() -> void:
	for id: Variant in crops:
		var crop := crops[id] as Dictionary
		var weights: Dictionary = crop.get("quality_weights", {})
		for tier: Variant in weights:
			weights[tier] = int(weights[tier])
	for villager_id: Variant in villagers:
		var villager := villagers[villager_id] as Dictionary
		var schedule: Dictionary = villager.get("schedule", {})
		schedule["work_start_hour"] = int(schedule.get("work_start_hour", 8))
		schedule["work_end_hour"] = int(schedule.get("work_end_hour", 18))
		# villagers.json v6: spawn/home/work anchors are zone-qualified and
		# zone-local; x/y stay semantically integers and get the same
		# boundary cast as every other tile coordinate.
		var spawn: Dictionary = villager.get("spawn", {})
		spawn["zone"] = str(spawn.get("zone", DEFAULT_ZONE_ID))
		spawn["x"] = int(spawn.get("x", 0))
		spawn["y"] = int(spawn.get("y", 0))
		for anchor_key: String in ["home", "work"]:
			var anchor: Dictionary = schedule.get(anchor_key, {})
			anchor["zone"] = str(anchor.get("zone", DEFAULT_ZONE_ID))
			anchor["x"] = int(anchor.get("x", 0))
			anchor["y"] = int(anchor.get("y", 0))
	for soil: Variant in soil_types:
		soil_types[soil] = _cast_ints(soil_types[soil] as Dictionary, SOIL_INT_KEYS)
	var days: Array = market_cfg.get("market_days", [])
	for i in range(days.size()):
		days[i] = int(days[i])
	var prices: Dictionary = market_cfg.get("buy_prices", {})
	for crop: Variant in prices:
		prices[crop] = int(prices[crop])
	var stall: Array = market_cfg.get("stall_inventory", [])
	for entry: Variant in stall:
		var item := entry as Dictionary
		item["stock"] = int(item.get("stock", -1))
	var labor: Dictionary = tithe_cfg.get("labor", {})
	labor["daily_credit_cap"] = int(labor.get("daily_credit_cap", 0))
	var upkeep: Dictionary = tithe_cfg.get("upkeep", {})
	upkeep["interval_days"] = int(upkeep.get("interval_days", 7))
	upkeep["amount"] = int(upkeep.get("amount", 0))
	# farm_map.json v5: geometry lives per zone; dims and feature coords are
	# cast per zone instead of at the old top level.
	var farm_zones: Dictionary = farm_map.get("zones", {})
	for zone_id: Variant in farm_zones:
		var zone := farm_zones[zone_id] as Dictionary
		zone["width"] = int(zone.get("width", 0))
		zone["height"] = int(zone.get("height", 0))
		var features: Array = zone.get("features", [])
		for f: Variant in features:
			var feat := f as Dictionary
			feat["x"] = int(feat.get("x", 0))
			feat["y"] = int(feat.get("y", 0))
			feat["width"] = int(feat.get("width", 1))
			feat["height"] = int(feat.get("height", 1))
	var raids: Array = raids_cfg.get("scripted_raids", [])
	for raid: Variant in raids:
		var r := raid as Dictionary
		r["day"] = int(r.get("day", 0))
		var members: Array = r.get("enemies", [])
		for member: Variant in members:
			var enemy_entry := member as Dictionary
			enemy_entry["count"] = int(enemy_entry.get("count", 1))
	var dynamic_pool: Array = raids_cfg.get("dynamic_enemy_pool", [])
	for entry: Variant in dynamic_pool:
		var pool_entry := entry as Dictionary
		pool_entry["weight"] = int(pool_entry.get("weight", 0))
	for skill_id: Variant in skills:
		var skill := skills[skill_id] as Dictionary
		var thresholds: Array = skill.get("xp_thresholds", [])
		for i in range(thresholds.size()):
			thresholds[i] = int(thresholds[i])
		var effects: Array = skill.get("level_effects", [])
		for level: Variant in effects:
			var e := level as Dictionary
			for key: String in SKILL_LEVEL_EFFECT_INT_KEYS:
				if e.has(key):
					e[key] = int(e[key])
	for i in range(dialogues.size()):
		dialogues[i] = _cast_ints(dialogues[i] as Dictionary, DIALOGUE_INT_KEYS)
	for festival_id: Variant in festivals:
		var festival := festivals[festival_id] as Dictionary
		var location: Dictionary = festival.get("location", {})
		for key: String in ["x", "y"]:
			if location.has(key):
				location[key] = int(location[key])
		var standing_effects: Dictionary = festival.get("standing_effects", {})
		for axis: Variant in standing_effects:
			standing_effects[axis] = int(standing_effects[axis])
		# Festival contest block (world_bible.md Section V, festivals.json v2):
		# bet bounds, payout-by-score ladder, standing deltas, and opinion
		# delta are semantically integers and get the same boundary cast.
		var contest: Dictionary = festival.get("contest", {})
		if not contest.is_empty():
			var bet_cfg: Dictionary = contest.get("bet", {})
			for key: String in ["min", "max"]:
				if bet_cfg.has(key):
					bet_cfg[key] = int(bet_cfg[key])
			var payouts: Array = contest.get("payout_by_score", [])
			for i in range(payouts.size()):
				payouts[i] = int(payouts[i])
			var enter_standing: Dictionary = contest.get("enter_standing", {})
			for axis: Variant in enter_standing:
				enter_standing[axis] = int(enter_standing[axis])
			var cheer_standing: Dictionary = contest.get("cheer_standing", {})
			for axis: Variant in cheer_standing:
				cheer_standing[axis] = int(cheer_standing[axis])
			contest["cheer_opinion_delta"] = int(contest.get("cheer_opinion_delta", 0))
	forage_cfg = _cast_ints(forage_cfg, FORAGE_INT_KEYS)
	var spawns: Dictionary = forage_cfg.get("spawns", {})
	for soil: Variant in spawns:
		var entries: Array = spawns[soil]
		for i in range(entries.size()):
			entries[i] = _cast_ints(entries[i] as Dictionary, FORAGE_SPAWN_ENTRY_INT_KEYS)
	# E12 dig loot table (forage.json v3) - same entry shape as spawns
	# (weight/yield_min/yield_max), same int-cast helper.
	var dig_loot: Dictionary = forage_cfg.get("dig_loot", {})
	for soil: Variant in dig_loot:
		var dig_entries: Array = dig_loot[soil]
		for i in range(dig_entries.size()):
			dig_entries[i] = _cast_ints(dig_entries[i] as Dictionary, FORAGE_SPAWN_ENTRY_INT_KEYS)
	for building_id: Variant in buildings:
		var building := buildings[building_id] as Dictionary
		var materials: Dictionary = building.get("cost_materials", {})
		for mat_id: Variant in materials:
			materials[mat_id] = int(materials[mat_id])
	for recipe_id: Variant in recipes:
		var recipe := recipes[recipe_id] as Dictionary
		var inputs: Dictionary = recipe.get("inputs", {})
		for item_id: Variant in inputs:
			inputs[item_id] = int(inputs[item_id])
	# tenure.json v3: default ownership is a zone id (the whole Fallowfield
	# grid), and each strip carries a zone + zone-local rect. Rect ints are
	# cast through TENURE_INT_KEYS at the boundary like every other list.
	tenure_cfg["default_owned_zone"] = str(tenure_cfg.get("default_owned_zone", DEFAULT_ZONE_ID))
	var strips: Array = tenure_cfg.get("strips", [])
	for strip: Variant in strips:
		var s := strip as Dictionary
		s["zone"] = str(s.get("zone", DEFAULT_ZONE_ID))
		var rect: Dictionary = s.get("rect", {})
		s["rect"] = _cast_ints(rect, TENURE_INT_KEYS)
	requests_cfg["max_active_requests"] = int(requests_cfg.get("max_active_requests", 0))
	var request_templates: Array = requests_cfg.get("templates", [])
	for i in range(request_templates.size()):
		request_templates[i] = _cast_ints(
			request_templates[i] as Dictionary, REQUEST_INT_KEYS)
	var court_days: Array = manor_cfg.get("court_days", [])
	for i in range(court_days.size()):
		court_days[i] = int(court_days[i])
	var fines: Dictionary = manor_cfg.get("fines", {})
	for offense: Variant in fines:
		fines[offense] = int(fines[offense])
	var corvee: Dictionary = manor_cfg.get("corvee", {})
	corvee["notice_days"] = int(corvee.get("notice_days", 1))
	var black_market: Dictionary = manor_cfg.get("black_market", {})
	var visit_days: Array = black_market.get("visit_days", [])
	for i in range(visit_days.size()):
		visit_days[i] = int(visit_days[i])
	# E6/ADR-037: board order templates carry quantity/reward/deadline ints
	# (board_orders.json v1), cast at the boundary like every other list.
	var board_templates: Array = board_orders_cfg.get("orders", [])
	for i in range(board_templates.size()):
		board_templates[i] = _cast_ints(
			board_templates[i] as Dictionary, BOARD_ORDER_TEMPLATE_INT_KEYS)
	animals_cfg = _cast_ints(animals_cfg, ANIMAL_INT_KEYS)
	var species: Dictionary = animals_cfg.get("species", {})
	for species_id: Variant in species:
		var def := species[species_id] as Dictionary
		for key: String in ANIMAL_SPECIES_INT_KEYS:
			if def.has(key):
				def[key] = int(def[key])
		var weights: Dictionary = def.get("quality_weights", {})
		for tier: Variant in weights:
			weights[tier] = int(weights[tier])
	# ADR-041/Sprint 16 Phase 1: sprites.json's per-entry nested dictionaries -
	# `directions` (facing key -> {start, count}) and `frames` (explicit atlas
	# rects) - cast through their own key lists like every other nested block
	# above (dialogues, festivals, forage spawns).
	for sprite_id: Variant in sprites:
		var sprite := sprites[sprite_id] as Dictionary
		var directions: Dictionary = sprite.get("directions", {})
		for dir_key: Variant in directions:
			directions[dir_key] = _cast_ints(
				directions[dir_key] as Dictionary, SPRITE_DIRECTION_INT_KEYS)
		var frame_list: Array = sprite.get("frames", [])
		for i in range(frame_list.size()):
			frame_list[i] = _cast_ints(
				frame_list[i] as Dictionary, SPRITE_FRAME_INT_KEYS)


func _read_json(file_name: String) -> Dictionary:
	var path := DATA_DIR + "/" + file_name
	if not FileAccess.file_exists(path):
		push_error("[GameData] missing data file: %s" % path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[GameData] cannot open: %s" % path)
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_error("[GameData] invalid JSON in %s" % path)
	return {}


## The handful of irregular crop-name plurals is data-sized, not a real
## English pluralizer: Barley/Flax are mass nouns, Oats is already plural.
## Anything not listed falls back to lowercase + "s".
func _pluralize_crop_name(name: String) -> String:
	if CROP_NAME_PLURALS.has(name):
		return CROP_NAME_PLURALS[name]
	if name.ends_with("s"):
		return name.to_lower()
	return (name + "s").to_lower()


## Same small-table approach for measure words (crops.json v5).
func _pluralize_measure(measure: String) -> String:
	if MEASURE_PLURALS.has(measure):
		return MEASURE_PLURALS[measure]
	return measure + "s"


func _indefinite_article(word: String) -> String:
	if word.is_empty():
		return "a"
	var first := word.substr(0, 1).to_lower()
	if first in ["a", "e", "i", "o", "u"]:
		return "an"
	return "a"
