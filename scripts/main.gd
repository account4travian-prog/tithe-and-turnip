extends Node2D

## Main farm scene root: wires the farm world (grid, renderer, player, NPCs)
## and the Sprint 7 panel-based UI layer. Day rollover: weather first, then
## farm growth. Sleep is the safe day-end path (Sprint 6's _sleep()); a
## forced collapse at hour 24 is handled entirely inside PlayerState/
## TimeManager and surfaces here only as a knocked_out message.
##
## The old $HUD scene labels ($HUD/TimeLabel etc., from the bootstrap) are
## unused as of this rewrite - HudPanel builds its own CanvasLayer with its
## own labels at runtime, per the established no-.tscn-authoring pattern.
## They are harmless, empty, and not worth an editor trip to remove.
##
## ADR-032 (isometric projection, amended ADR-043; Phase 0 of IsometricConversion.md) added a
## second unused-but-harmless holdover for the same reason: main.tscn's
## $Camera2D is disabled rather than deleted, replaced at runtime by
## IsoCamera. This _ready() also now builds `world_visuals`, the single
## y_sort_enabled container every actor/structure visual proxy parents
## under (CLAUDE.md section 9.7), and wires the player and every NPC into it
## via PlayerVisual/NpcVisual (scripts/player/player_visual.gd,
## scripts/npc/npc_visual.gd - WS-C's concrete ActorVisual subclasses that
## carry the drawn geometry the base class deliberately doesn't).
## FarmRenderer/FeatureRenderer/BuildingRenderer's configure() calls already
## pass the camera/world_visuals references WS-A/WS-B need - this file is
## frozen per the conversion plan's Phase 0, so those signatures were decided
## now rather than left for the parallel phase to renegotiate against a
## moving caller. Camera-follow used to live in this file's own _process()
## (see prior revisions) precisely so it would freeze under pause the same
## way everything else does; IsoCamera's own _process() now carries that same
## reasoning, and this file's _process() was removed since nothing else was
## in it.
##
## Integration fix (2026-08-07, post-merge verification in the live editor):
## this file originally instantiated the generic `ActorVisual` base class
## directly for the player and every NPC - valid GDScript, since
## PlayerVisual/NpcVisual didn't exist yet when Phase 0 wrote this file, but
## `ActorVisual` on its own draws nothing (by design - see its own
## docstring), so the player and every NPC were silently invisible on screen
## even though their positions tracked correctly underneath. enemy.gd's own
## docstring had already flagged the expectation ("unlike PlayerVisual/
## NpcVisual, which main.gd wires...") but nothing enforced it once main.gd
## froze. Fixed by instantiating the concrete subclasses below - the only
## change this integration fix makes to this otherwise-frozen file.
## ADR-040 (spatial demesne chores): _on_day_passed now forwards the new
## calendar day into FarmGrid.advance_day so the steward's stored-sheaf
## backlog replenishes on its data-driven cadence at the day rollover.
## Sprint 15b (ADR-034 second half): walking off a map edge triggers
## zone_manager.change_zone -> zone_changed, and _on_zone_changed is the
## single world-swap site: player/ToolManager grid refs, player position,
## camera dims, HUD/TitheManager grid refs, farm/feature/building
## renderers, and the per-zone NPC set. NPC presence is zone-filtered and
## re-filtered on the hour boundary; raids gate on Fallowfield; a saved
## game restores the saved zone through the same handler.

@onready var farm_grid: FarmGrid = $FarmGrid
@onready var player: Player = $Player

var hud_panel: HudPanel
var inventory_panel: InventoryPanel
var shop_panel: ShopPanel
var tithe_panel: TithePanel
var church_panel: ChurchPanel
var dialogue_panel: DialoguePanel
var pause_menu: PauseMenu
var settings_menu: SettingsMenu
var season_summary_panel: SeasonSummaryPanel
var save_slot_panel: SaveSlotPanel
var building_renderer: BuildingRenderer
var building_panel: BuildingPanel
var feature_renderer: FeatureRenderer
var crafting_panel: CraftingPanel
var animal_panel: AnimalPanel
var board_panel: BoardPanel
var contest_panel: ContestPanel
var debug_panel: DebugPanel
var world_visuals: WorldVisuals
var iso_camera: IsoCamera

var _npcs: Array[NPC] = []
var _npc_visuals: Array[NpcVisual] = []
var _player_visual: ActorVisual
var _season_over := false
var _mass_checked_today := false
## Sprint 15b: true when a save was loaded this boot, so
## _position_player_at_spawn is skipped (apply_saved_state already placed
## the player at the saved tile through the zone_changed handler).
var _loaded_save := false
## Sprint 15b: last hour the active-zone NPC membership set was checked, so
## the minute_passed re-filter only respawns on an actual hour boundary.
var _last_npc_zone_hour := -1
var farm_renderer: FarmRenderer
var target_indicator: TargetIndicatorRenderer
var _zone_manager: Node

const MASS_DAY := 21
const MASS_HOUR := 9


func _ready() -> void:
	# ADR-032: camera and the visual-proxy container are wired first -
	# _spawn_npcs() and the player proxy both need world_visuals to exist.
	$Camera2D.enabled = false
	iso_camera = IsoCamera.new()
	add_child(iso_camera)
	iso_camera.configure(player, GameData)

	world_visuals = WorldVisuals.new()
	add_child(world_visuals)

	player.set_farm_grid(farm_grid)
	_zone_manager = get_node_or_null("/root/ZoneManager")
	# Sprint 15a: register the scene's FarmGrid (Fallowfield) plus every other
	# zone grid with ZoneManager before any save load can restore
	# per-zone farm state. Sprint 15b: the zone_changed connection is made
	# here too, before the pending-load block, so apply_saved_state's emit
	# runs the world swap once every renderer/panel exists.
	_boot_zone_grids()
	if _zone_manager != null and not _zone_manager.zone_changed.is_connected(_on_zone_changed):
		_zone_manager.zone_changed.connect(_on_zone_changed)
	SaveManager.set_farm_grid_ref(farm_grid)
	TitheManager.set_farm_grid_ref(farm_grid)
	var marriage_manager_boot := get_node_or_null("/root/MarriageManager")
	if marriage_manager_boot != null:
		marriage_manager_boot.set_farm_grid_ref(farm_grid)
	# Sprint 15b: NPC presence is zone-filtered - a villager exists in the
	# world only while the player is in the villager's current zone. At boot
	# that is Fallowfield, which no villager anchors in, so the holding
	# starts empty of villagers (they appear once Nettleford/Brook/Mill are
	# reached).
	_spawn_npcs_for_zone("fallowfield")
	# Problem 3: the interaction lookup reads each villager's CURRENT tile via
	# NPC.npc_id_at() (an O(n) scan over ~6-8 live villagers - CLAUDE.md
	# section 9.1's note explicitly permits this). The old spawn-tile
	# dictionary went stale the first time an NPC wandered.
	player.set_npc_lookup(func(tile: Vector2i) -> String:
		return NPC.npc_id_at(_npcs, tile))
	var tool_manager := player.get_tool_manager()
	tool_manager.water_level_changed.connect(_on_water_changed)
	farm_renderer = FarmRenderer.new()
	farm_renderer.configure(farm_grid, GameData, iso_camera)
	farm_renderer.set_terrain_season(TimeManager.season)
	add_child(farm_renderer)
	move_child(farm_renderer, 0)
	move_child(world_visuals, 1)
	# Fixed manor structures (VSA-1) draw above the soil but below player
	# buildings and the player/NPCs (tree order). This move_child layering is
	# a Phase 0 holdover from before ADR-032 - once WS-B populates
	# world_visuals with per-structure StructureVisual nodes, y_sort_enabled
	# inside world_visuals is what actually determines paint order for
	# structures and actors, not this index.
	feature_renderer = FeatureRenderer.new()
	feature_renderer.configure(GameData, world_visuals)
	add_child(feature_renderer)
	move_child(feature_renderer, 2)
	# Buildings draw above the soil but below the player (tree order).
	var building_manager = get_node_or_null("/root/BuildingManager")
	if building_manager != null:
		building_renderer = BuildingRenderer.new()
		building_renderer.configure(building_manager, GameData, world_visuals)
		add_child(building_renderer)
		move_child(building_renderer, 3)
	# Playtest fix (item 4): drawn above terrain/fixtures/buildings/the
	# y-sorted world_visuals container - deliberately the topmost world
	# sibling, so nothing can occlude the tile the player is aiming at. Needs
	# no set_active_zone() re-wire (unlike the renderers above): it reads
	# Player/the active grid live every frame, and _on_zone_changed cancels
	# any in-progress hold below.
	target_indicator = TargetIndicatorRenderer.new()
	target_indicator.configure(player)
	add_child(target_indicator)
	move_child(target_indicator, 4)
	_build_panels()

	# ADR-032 actor proxy (plan section 3): PlayerVisual (WS-C) draws the
	# body and facing indicator at the player's projected screen position.
	_player_visual = PlayerVisual.new()
	world_visuals.add_child(_player_visual)
	_player_visual.track(player)

	TimeManager.day_passed.connect(_on_day_passed)
	TimeManager.season_changed.connect(_on_season_changed)
	TimeManager.minute_passed.connect(_on_minute_passed)
	player.interacted_with.connect(_on_player_interacted)
	player.npc_interacted.connect(_on_npc_interacted)
	player.station_interacted.connect(_on_station_interacted)
	TitheManager.chore_completed.connect(_on_chore_completed)
	TitheManager.daily_labor_limit_reached.connect(_on_labor_limit)
	TitheManager.donation_made.connect(_on_donation_made)
	TitheManager.order_fulfilled.connect(_on_order_fulfilled)
	PlayerState.knocked_out.connect(_on_player_knocked_out)
	RaidManager.raid_started.connect(_on_raid_started)
	RaidManager.raid_resolved.connect(_on_raid_resolved)
	RaidManager.theft_occurred.connect(_on_theft)
	RaidManager.raid_message.connect(_on_raid_message)
	if not SaveManager.pending_load.is_empty():
		var slot := SaveManager.pending_load
		SaveManager.pending_load = ""
		SaveManager.load_game(slot)
		# Sprint 15b: a saved game restores the saved zone/tile and fires
		# the same zone_changed world swap the transitions use. Runs here,
		# after every renderer/panel exists and the boot NPC set is live, so
		# the handler's respawn pass replaces the boot set.
		_loaded_save = true
		if _zone_manager != null:
			_zone_manager.apply_saved_state(player)
	# Sprint 15b: only a fresh game positions the player at the spawn tile;
	# a loaded save's position came from apply_saved_state above.
	if not _loaded_save:
		_position_player_at_spawn()
	_last_npc_zone_hour = TimeManager.hour
	_show_tithe_gloss_once()


## world_bible.md Section IX's "bridge gloss": bridges the title's "Tithe"
## to the diegetic "Assessment" the rest of the game uses. The locked text
## is meant to follow a loading-screen tip, or (its own documented
## fallback) "a single non-diegetic line after the opening roll fades" -
## neither a loading-tip slot nor the Section X "Opening Still" parchment
## intro exist in this codebase yet, so this uses the fallback line through
## the same one-shot HUD toast every other flavor message already uses,
## shown once ever via the existing PlayerState.event_flags mechanism
## (checked after SaveManager.load_game above, so a save that already saw
## this doesn't show it again).
func _show_tithe_gloss_once() -> void:
	const FLAG := "framing.saw_tithe_gloss"
	if PlayerState.has_event_flag(FLAG):
		return
	PlayerState.set_event_flag(FLAG)
	hud_panel.show_message("The roll calls it the assessment. Everyone else still calls it the tithe.")


## Sprint 15b: walking off a map edge is the transition trigger. Checked
## every physics tick. Parent _physics_process order means this observes the
## player's movement from the PREVIOUS tick, so a crossing is caught one
## tick late at most - invisible in practice because the camera and
## renderers consume the repositioned player, not the one-tick out-of-bounds
## probe.
func _physics_process(_delta: float) -> void:
	_check_zone_edge_crossing()


func _check_zone_edge_crossing() -> void:
	var zm := _zone_manager
	if zm == null or player == null:
		return
	var grid: Node = zm.get_active_farm_grid()
	if grid == null:
		return
	var size: Vector2i = grid.get_grid_size()
	if size.x <= 0 or size.y <= 0:
		return
	var tile := player.get_current_tile()
	# Doorways are local transitions inside a map, so they must be checked
	# before the ordinary edge-exit logic. The cottage's east-wall door is the
	# first such doorway; the destination zone's east-edge exit preserves that
	# orientation on the return trip from inside the house.
	if zm.has_method("resolve_door"):
		var door: Dictionary = zm.resolve_door(str(zm.get_active_zone_id()), tile)
		if not door.is_empty():
			var door_arrive: Dictionary = door.get("arrive_at", {})
			var door_tile := Vector2i(
				int(door_arrive.get("x", 0)), int(door_arrive.get("y", 0)))
			if zm.change_zone(str(door.get("to", "")), door_tile):
				return
	var edge := ""
	var index := 0
	if tile.y < 0:
		edge = "north"
		index = tile.x
	elif tile.y >= size.y:
		edge = "south"
		index = tile.x
	elif tile.x < 0:
		edge = "west"
		index = tile.y
	elif tile.x >= size.x:
		edge = "east"
		index = tile.y
	if edge.is_empty():
		return
	var exit_data: Dictionary = zm.resolve_exit(str(zm.get_active_zone_id()), edge, index)
	if exit_data.is_empty():
		_clamp_player_inside(size)
		return
	var arrive: Dictionary = exit_data.get("arrive_at", {})
	var arrived := Vector2i(int(arrive.get("x", 0)), int(arrive.get("y", 0)))
	if not zm.change_zone(str(exit_data.get("to", "")), arrived):
		_clamp_player_inside(size)


## A playable boundary (e.g. the South Fields' south edge) clamps the player
## back inside and does nothing else. Velocity is zeroed too so the player
## does not jitter against the boundary every tick.
func _clamp_player_inside(size: Vector2i) -> void:
	var half := IsoProjection.LOGICAL_CELL / 2.0
	player.position.x = clampf(player.position.x, half,
		float(size.x) * IsoProjection.LOGICAL_CELL - half)
	player.position.y = clampf(player.position.y, half,
		float(size.y) * IsoProjection.LOGICAL_CELL - half)
	player.velocity = Vector2.ZERO


## Sprint 15b: the world swap - the ONLY place scene-side zone state
## changes (ZoneManager deliberately only owns model state). Order settled
## with the DeepSeek Pro consult: player grid/zone first, then position,
## camera dims, HUD/TitheManager grid refs, renderers, then the NPC set.
## The raid dismissal is Pro's flagged addition so spawned enemies never
## leak across zones.
func _on_zone_changed(zone_id: String) -> void:
	var zm := _zone_manager
	if zm == null:
		return
	var grid: Node = zm.get_active_farm_grid()
	if grid == null:
		return
	# Pro-consult addition: a raid in progress cannot follow the player into
	# another zone - dismiss it message-only (no deferred state).
	var raid_manager := get_node_or_null("/root/RaidManager")
	if raid_manager != null and raid_manager.has_method("dismiss_raid_if_active"):
		raid_manager.dismiss_raid_if_active()
	# Playtest fix (item 4): a hold-to-preview must not survive a zone swap -
	# the previewed tile is about to belong to a different map entirely.
	player.cancel_interact_hold()
	# 1. Player + ToolManager grid refs (and the player's active zone id).
	player.set_active_farm_grid(grid)
	# 2. Arrival tile in world units, velocity zeroed.
	# Explicit Vector2i, not := - zm is typed Node and the method returns
	# Variant through the base-class reference (project trap 12.1).
	var tile: Vector2i = zm.get_player_tile()
	var half_cell := IsoProjection.LOGICAL_CELL / 2.0
	player.position = Vector2(
		tile.x * IsoProjection.LOGICAL_CELL + half_cell,
		tile.y * IsoProjection.LOGICAL_CELL + half_cell)
	player.velocity = Vector2.ZERO
	# 3. Camera dims override to the new zone.
	var size: Vector2i = grid.get_grid_size()
	iso_camera.set_map_dims(size.x, size.y)
	# 4. HUD + TitheManager grid refs. TitheManager's ref is demesne-only
	# (its spatial chore queries); MarriageManager's stays on the holding by
	# design - the spouse waters Fallowfield, never the active zone.
	if hud_panel != null:
		hud_panel.set_farm_grid(grid)
	var tithe_manager := get_node_or_null("/root/TitheManager")
	if tithe_manager != null and tithe_manager.has_method("set_farm_grid_ref"):
		tithe_manager.set_farm_grid_ref(grid)
	# 5. Terrain renderer re-wire (signal connection management is
	# idempotent inside set_active_grid).
	if farm_renderer != null:
		farm_renderer.set_active_grid(grid)
		# A zone switch can be emitted while the renderer is mid-frame. Defer one
		# presentation-only redraw so the new interior cannot retain a cleared
		# viewport until unrelated camera motion happens to trigger a redraw.
		farm_renderer.call_deferred("queue_redraw")
	# 6. Fixed fixtures: free the old zone's collision/visuals, rebuild the
	# new zone's (synchronous free is safe from this signal handler -
	# CLAUDE.md trap 4's deferred-free window does not apply to owner-side
	# cleanup).
	if feature_renderer != null:
		feature_renderer.set_active_zone(zone_id)
	# 7. Placed buildings.
	if building_renderer != null:
		building_renderer.set_active_zone(zone_id)
	# 8. NPC set + interaction lookup.
	_respawn_npcs_for_active_zone(zone_id)
	# 9. Animals: AnimalManager is state-only (verified during
	# implementation - it spawns no world nodes), so the guide's
	# animal-visual step is a documented no-op.


## Frees every current NPC node and NpcVisual proxy, then respawns the new
## zone's set. queue_free is deferred, so the arrays are cleared immediately
## and is_instance_valid guards matter anywhere else that held a reference
## for the rest of this tick.
func _respawn_npcs_for_active_zone(zone_id: String) -> void:
	for npc: NPC in _npcs:
		if is_instance_valid(npc):
			npc.queue_free()
	_npcs.clear()
	for visual: NpcVisual in _npc_visuals:
		if is_instance_valid(visual):
			visual.queue_free()
	_npc_visuals.clear()
	_spawn_npcs_for_zone(zone_id)


## Sprint 15b hour-boundary re-filter: when a villager's work/home zone
## changes relative to the active zone, its world presence must change even
## without a zone crossing. Compares the expected membership set against the
## currently spawned set and respawns only when they differ.
func _refresh_npcs_for_active_zone() -> void:
	if _zone_manager == null:
		return
	# Explicit Array[String], not := - same Variant-through-Node trap.
	var expected: Array[String] = _zone_manager.get_active_zone_npc_ids()
	var current: Array[String] = []
	for npc: NPC in _npcs:
		current.append(npc.npc_id)
	if current.size() != expected.size():
		_respawn_npcs_for_active_zone(str(_zone_manager.get_active_zone_id()))
		return
	for npc_id: String in expected:
		if not current.has(npc_id):
			_respawn_npcs_for_active_zone(str(_zone_manager.get_active_zone_id()))
			return


func _on_raid_message(text: String) -> void:
	hud_panel.show_message(text)


func _on_day_passed(day: int, _season: String, _year: int) -> void:
	_mass_checked_today = false
	WeatherManager.advance_day()
	# ADR-034: the day rollover forwards to every zone's grid, so rain
	# auto-waters tilled cells region-wide while the player is elsewhere.
	# ADR-040: `day` also drives the demesne's stored-sheaf replenish
	# cadence, so it has to reach every grid's advance_day the same way
	# rain/overcast already do.
	var zone_manager := get_node_or_null("/root/ZoneManager")
	if zone_manager != null:
		zone_manager.advance_day(WeatherManager.is_raining(), WeatherManager.is_overcast(), day)
	else:
		farm_grid.advance_day(WeatherManager.is_raining(), WeatherManager.is_overcast(), day)


## Sprint 15a minimal wiring: one FarmGrid per zone exists at boot (the
## scene's own grid is Fallowfield; the other eight are built in code),
## each registered with ZoneManager. Only the active grid's renderer is
## connected; the extras are state-only siblings until 15b swaps them in.
func _boot_zone_grids() -> void:
	var zone_manager := get_node_or_null("/root/ZoneManager")
	if zone_manager == null:
		return
	zone_manager.register_farm_grid("fallowfield", farm_grid)
	for zone_id: String in GameData.get_zone_ids():
		if zone_id == "fallowfield":
			continue
		var grid := FarmGrid.new()
		grid.name = "FarmGrid_%s" % zone_id
		grid.visible = false
		# Zone id is set BEFORE add_child so this grid's _ready() builds its
		# own zone's dims/soil - the per-instance _ready ordering the
		# multi-instance audit flagged (an id set after add_child would leave
		# _ready() reading the wrong zone's dims).
		grid.set_zone_id(zone_id)
		add_child(grid)
		zone_manager.register_farm_grid(zone_id, grid)


## Boots the player on the Fallowfield spawn tile (zones.json) - the
## 24x16 holding's house/well moved away from the scene origin with
## farm_map.json v5, so the old default (0,0) would strand the player far
## from the cottage.
func _position_player_at_spawn() -> void:
	var spawn: Dictionary = GameData.get_spawn_point()
	var tile := Vector2i(int(spawn.get("x", 0)), int(spawn.get("y", 0)))
	var half_cell := IsoProjection.LOGICAL_CELL / 2.0
	player.position = Vector2(
		tile.x * IsoProjection.LOGICAL_CELL + half_cell,
		tile.y * IsoProjection.LOGICAL_CELL + half_cell)
	player.velocity = Vector2.ZERO
	var zone_manager := get_node_or_null("/root/ZoneManager")
	if zone_manager != null:
		zone_manager.set_player_tile(tile)


## Sleep is the safe day-end: restore energy/health first, advance the day
## second (day_passed cascades into weather/farm/tithe/player handlers), and
## autosave last so the file captures the new day's state.
func _sleep() -> void:
	PlayerState.sleep_restore()
	TimeManager.sleep_to_next_day()
	SaveManager.save_game("autosave")
	var marriage_manager := get_node_or_null("/root/MarriageManager")
	if marriage_manager != null and marriage_manager.has_method("get_waking_greeting"):
		var greeting := str(marriage_manager.get_waking_greeting())
		if not greeting.is_empty():
			hud_panel.show_message(greeting)
	hud_panel.show_message("You sleep... a new day begins.")


func _on_player_interacted(feature: String, _pos: Vector2i) -> void:
	# Festival contests (world_bible.md Section V): during a festival's
	# active window, interacting with its anchor tile opens the contest
	# panel instead of the tile's ordinary feature panel. The minute_passed
	# attendance grant in _check_festival_attendance() is untouched -
	# contests are an additional interaction, not a replacement for it.
	var festival_manager := get_node_or_null("/root/FestivalManager")
	if festival_manager != null and festival_manager.has_method("get_active_festival"):
		var active_festival: Dictionary = festival_manager.get_active_festival()
		if not active_festival.is_empty() and festival_manager.has_method("get_contest"):
			var contest: Dictionary = festival_manager.get_contest(
				str(active_festival.get("id", "")))
			if not contest.is_empty():
				var anchor: Dictionary = active_festival.get("location", {})
				var anchor_tile := Vector2i(
					int(anchor.get("x", -1)), int(anchor.get("y", -1)))
				if anchor_tile == _pos:
					UIManager.open_menu("contest")
					return
	match feature:
		"market_zone":
			# Black-market visit days open the same shop panel; only its
			# black-market section shows then, so the trader needs no world
			# presence of its own.
			if TitheManager.is_market_open() or TitheManager.is_black_market_open():
				UIManager.open_menu("shop")
			else:
				hud_panel.show_message("Market is closed today")
		"chapel":
			# ADR-031 (realized): ceremony takes precedence over the ordinary
			# church panel when a proposal is pending and the merchet is paid -
			# the player already made the choice by walking to the chapel and
			# interacting, so this is one branch rather than a second dialogue
			# response with its own tile-position gate.
			var marriage_manager := get_node_or_null("/root/MarriageManager")
			if marriage_manager != null and (marriage_manager.has_method("can_ceremonize") and marriage_manager.can_ceremonize()) and marriage_manager.ceremonize():
				hud_panel.show_message("You are wed at the chapel. The village takes notice.")
			else:
				UIManager.open_menu("church")
		"stewards_demesne":
			# ADR-040: the panel is now the fallback for a demesne
			# interaction (bare hands with no chore available); tool chores
			# and harvest/delivery are handled in player.gd's _use_tool and
			# never reach this signal.
			UIManager.open_menu("tithe")
		"town_board":
			UIManager.open_menu("board")
		"player_house":
			_sleep()
		_:
			pass


func _on_station_interacted(station_id: String, _pos: Vector2i) -> void:
	if station_id == "coop":
		animal_panel.open_for_coop()
		return
	crafting_panel.open_for_station(station_id)


## ADR-035 (E4): line selection moved from the old get_dialogue_for()/
## lines[0]-of-first-match to DialogueManager.get_next_line(), which runs
## the full condition/priority/frequency pipeline. Everything downstream
## (request override, investigation-clue append, the final show_dialogue()
## call) is unchanged.
## DialogueManager reached via get_node_or_null, not a bare reference
## (matching this same function's existing InvestigationManager check) -
## it needs a Project Settings -> Autoload registration (ADR-035's DESKTOP
## step) that hasn't landed yet. A bare `DialogueManager.` reference would
## fail to even parse until that's done, breaking main.gd entirely; the
## old get_dialogue_for()/lines[0] path is kept as the fallback so the game
## works exactly as it does today until the registration lands, then
## switches over automatically with no further code change.
func _on_npc_interacted(npc_id: String) -> void:
	var npc_name := str(GameData.get_villager(npc_id).get("name", npc_id))
	var dialogue_manager := get_node_or_null("/root/DialogueManager")
	var selected := ""
	if dialogue_manager != null:
		selected = str(dialogue_manager.get_next_line(npc_id))
	else:
		var standings := {
			"manor": ReputationManager.get_standing("manor"),
			"village": ReputationManager.get_standing("village"),
			"church": ReputationManager.get_standing("church"),
		}
		var lines := GameData.get_dialogue_for(npc_id, standings)
		selected = str(lines[0]) if not lines.is_empty() else ""
	var line := selected if not selected.is_empty() else "%s looks at you silently." % npc_name
	var responses: Array[Dictionary] = []
	for req: Dictionary in ReputationManager.get_active_requests():
		if str(req.get("npc_id", "")) != npc_id:
			continue
		line = "%s needs %d %s (%s)." % [
			npc_name, int(req.get("quantity", 0)), str(req.get("item_id", "")), str(req.get("quality", "common"))]
		if ReputationManager.can_complete_request(str(req.get("id", ""))):
			var fulfill_callback := func() -> void:
				ReputationManager.complete_request(str(req.get("id", "")))
			responses.append({"text": "Fulfill request", "callback": fulfill_callback})
	var marriage_manager := get_node_or_null("/root/MarriageManager")
	if marriage_manager != null:
		if marriage_manager.has_method("can_propose") and marriage_manager.can_propose(npc_id):
			var propose_callback := func() -> void:
				if marriage_manager.propose(npc_id):
					dialogue_panel.show_dialogue(npc_name,
						"You offer the braided ring. %s accepts." % npc_name, [])
				else:
					dialogue_panel.show_dialogue(npc_name, "It is not the moment.", [])
			responses.append({"text": "Propose marriage", "callback": propose_callback})
		# The merchet is paid to the steward specifically, once a proposal is
		# pending - matches the locked ruling (a fee to the steward before the
		# wedding proceeds), not to whichever candidate was proposed to.
		if npc_id == "steward" and marriage_manager.has_method("can_pay_merchet") and marriage_manager.can_pay_merchet():
			var merchet_callback := func() -> void:
				if marriage_manager.pay_merchet():
					dialogue_panel.show_dialogue(npc_name,
						"The steward records the licence. The wedding may proceed.", [])
				else:
					dialogue_panel.show_dialogue(npc_name, "You cannot pay the fee yet.", [])
			responses.append({"text": "Pay the merchet", "callback": merchet_callback})
	var gift_callback := func() -> void:
		inventory_panel.open_for_gift(npc_id)
	responses.append({"text": "Give a gift", "callback": gift_callback})
	# ADR-026: while an investigation is open, every villager may have heard
	# something - revealing a clue hands out the next unrevealed one. The
	# accusation targets whoever the player is currently talking to.
	# X6 (world_bible.md Section VII): once the true clue is revealed, the
	# player talking to the real thief gets a mercy option alongside the
	# accusation - same dialogue panel, third terminal resolution, no new UI.
	var inv := get_node_or_null("/root/InvestigationManager")
	if inv != null and inv.can_accuse():
		var revealed: Dictionary = inv.reveal_clue_for(npc_id)
		if not revealed.is_empty():
			line += " " + str(revealed.get("text", ""))
		var accuse_callback := func() -> void:
			var correct: bool = inv.accuse(npc_id)
			dialogue_panel.show_dialogue(npc_name,
				"Accused! The village stirs." if correct else "You have no proof - the village grumbles.", [])
		responses.append({"text": "Accuse of theft", "callback": accuse_callback})
		if inv.can_show_mercy(npc_id):
			var mercy_callback := func() -> void:
				var shown: bool = inv.show_mercy(npc_id)
				dialogue_panel.show_dialogue(npc_name,
					"You keep the proof to yourself. %s nods, quietly." % npc_name if shown else "It is not the moment.", [])
			responses.append({"text": "Show mercy", "callback": mercy_callback})
	dialogue_panel.show_dialogue(npc_name, line, responses)


## Mass is a scheduled check, not a system: on day 21 at hour 9, standing at
## the chapel tile grants the attend_mass reputation action exactly once.
func _on_minute_passed(hour: int, _minute: int) -> void:
	var active_zone := str(_zone_manager.get_active_zone_id()) if _zone_manager != null else "fallowfield"
	# Sprint 15b: mass is a Nettleford event - the chapel tile lookup is
	# zone-qualified and the attendance check is gated on the active zone.
	if active_zone == "nettleford" and TimeManager.day == MASS_DAY \
			and hour == MASS_HOUR and not _mass_checked_today:
		_mass_checked_today = true
		var chapel_tile: Vector2i = GameData.get_feature_tile("chapel", "nettleford")
		if player.get_faced_tile() == chapel_tile or player.get_current_tile() == chapel_tile:
			ReputationManager.apply_action("attend_mass")
			hud_panel.show_message("You attended mass. The village takes notice.")
	# Sprint 15b: a villager whose work/home zone just changed needs a
	# spawn/despawn pass at the hour boundary, not just at zone crossings.
	if hour != _last_npc_zone_hour:
		_last_npc_zone_hour = hour
		_refresh_npcs_for_active_zone()
	_check_festival_attendance()


## E5 (ADR-036): mirrors the mass-attendance check above - same tile-position
## predicate, but gated by PlayerState.event_flags (not a _today bool) since
## attendance should never re-grant, not even on a later day. FestivalManager
## is a pending-DESKTOP autoload (ADR-036) - reached via get_node_or_null,
## not a bare reference, same as DialogueManager's own pending registration.
func _check_festival_attendance() -> void:
	var festival_manager := get_node_or_null("/root/FestivalManager")
	if festival_manager == null:
		return
	var festival: Dictionary = festival_manager.get_active_festival()
	if festival.is_empty():
		return
	var festival_id := str(festival.get("id", ""))
	var flag := "festival.attended_%s" % festival_id
	if PlayerState.has_event_flag(flag):
		return
	var location: Dictionary = festival.get("location", {})
	# Sprint 15b: festivals anchor in a specific zone (Nettleford this
	# slice); attendance only counts while the player is in that zone.
	var festival_zone := str(location.get("zone", ""))
	var active_zone := str(_zone_manager.get_active_zone_id()) if _zone_manager != null else "fallowfield"
	if active_zone != festival_zone:
		return
	var tile := Vector2i(int(location.get("x", -1)), int(location.get("y", -1)))
	if player.get_faced_tile() != tile and player.get_current_tile() != tile:
		return
	PlayerState.set_event_flag(flag)
	var standing_effects: Dictionary = festival.get("standing_effects", {})
	for axis: Variant in standing_effects:
		ReputationManager.modify_standing(str(axis), float(standing_effects[axis]))
	hud_panel.show_message(
		"You attended the %s. The village takes notice." % str(festival.get("name", festival_id)))


func _on_player_knocked_out(cause: String) -> void:
	match cause:
		"combat":
			hud_panel.show_message("You were knocked out and lost some coin")
		"exhaustion":
			hud_panel.show_message("You collapsed from exhaustion")
		"exhausted_day":
			hud_panel.show_message("You never went to bed and collapsed")
		_:
			hud_panel.show_message("You were knocked out")


func _on_raid_started(enemy_count: int) -> void:
	hud_panel.show_message("Bandits attack! (%d enemies)" % enemy_count)


func _on_raid_resolved(win: bool) -> void:
	if win:
		hud_panel.show_message("You repelled the bandits! Deterrence up.")
	else:
		hud_panel.show_message("You were overwhelmed...")


func _on_theft(_coin_lost: int, message: String) -> void:
	hud_panel.show_message(message)


func _on_season_changed(season: String) -> void:
	if farm_renderer != null:
		farm_renderer.set_terrain_season(season)
	if season != "spring" and not _season_over:
		_season_over = true
		season_summary_panel.show_summary()


func _on_chore_completed(chore_id: String, credit: float, energy_cost: float) -> void:
	hud_panel.show_message("%s: +%d tithe credit, -%d energy" % [chore_id, int(credit), int(energy_cost)])


func _on_labor_limit() -> void:
	hud_panel.show_message("You've done enough labor for today")


func _on_donation_made(type: String, value: float) -> void:
	hud_panel.show_message("Donated %s worth %d" % [type, int(value)])


func _on_order_fulfilled(_order_id: String, reward_money: int) -> void:
	hud_panel.show_message("Board order fulfilled: +%d coin" % reward_money)


func _on_water_changed(current: float, capacity: float) -> void:
	hud_panel.refresh_water(current, capacity)


func _build_panels() -> void:
	hud_panel = HudPanel.new()
	hud_panel.configure(player, farm_grid)
	add_child(hud_panel)
	inventory_panel = InventoryPanel.new()
	add_child(inventory_panel)
	shop_panel = ShopPanel.new()
	add_child(shop_panel)
	tithe_panel = TithePanel.new()
	add_child(tithe_panel)
	church_panel = ChurchPanel.new()
	add_child(church_panel)
	dialogue_panel = DialoguePanel.new()
	add_child(dialogue_panel)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	settings_menu = SettingsMenu.new()
	add_child(settings_menu)
	season_summary_panel = SeasonSummaryPanel.new()
	add_child(season_summary_panel)
	save_slot_panel = SaveSlotPanel.new()
	add_child(save_slot_panel)
	building_panel = BuildingPanel.new()
	building_panel.configure(player, get_node_or_null("/root/BuildingManager"), building_renderer)
	add_child(building_panel)
	crafting_panel = CraftingPanel.new()
	add_child(crafting_panel)
	animal_panel = AnimalPanel.new()
	add_child(animal_panel)
	board_panel = BoardPanel.new()
	add_child(board_panel)
	contest_panel = ContestPanel.new()
	add_child(contest_panel)
	# Debug cheat panel (Ctrl+K while paused): workshop tool only, never built
	# in a release export.
	if OS.is_debug_build():
		debug_panel = DebugPanel.new()
		add_child(debug_panel)


## Sprint 15b: spawns exactly the villagers whose current zone matches
## `zone_id` (ZoneManager.get_npc_zone: marriage -> fallowfield, festival ->
## nettleford, else the work/home schedule zone for the current hour), each
## at its current anchor tile, plus its NpcVisual proxy, and rebuilds the
## player's live-position interaction lookup. The boot call passes
## "fallowfield"; the zone_changed handler and the hour-boundary re-filter
## call the respawn variant.
func _spawn_npcs_for_zone(zone_id: String) -> void:
	_npcs.clear()
	_npc_visuals.clear()
	for npc_id: String in GameData.get_all_villager_ids():
		if _zone_manager == null or _zone_manager.get_npc_zone(npc_id) != zone_id:
			continue
		var tile := _npc_anchor_tile(npc_id)
		var half_cell := IsoProjection.LOGICAL_CELL / 2.0
		var npc := NPC.new()
		npc.npc_id = npc_id
		npc.position = Vector2(
			tile.x * IsoProjection.LOGICAL_CELL + half_cell,
			tile.y * IsoProjection.LOGICAL_CELL + half_cell)
		add_child(npc)
		_npcs.append(npc)
		# ADR-032 actor proxy (plan section 3): NpcVisual (WS-C) draws this
		# villager's body at its projected screen position.
		var npc_visual := NpcVisual.new()
		world_visuals.add_child(npc_visual)
		npc_visual.track(npc)
		_npc_visuals.append(npc_visual)
	player.set_npc_lookup(func(tile_l: Vector2i) -> String:
		return NPC.npc_id_at(_npcs, tile_l))


## The tile a villager anchors on RIGHT NOW, zone-local to the villager's
## current zone (the same three overrides ZoneManager.get_npc_zone applies,
## in tile form): marriage -> Fallowfield's player_house, festival -> the
## active festival's tile, otherwise the work/home schedule tile for the
## current hour. Spawning at the anchor (rather than the static spawn tile)
## means a villager who just switched zones appears where their schedule
## says they are.
func _npc_anchor_tile(npc_id: String) -> Vector2i:
	var marriage_manager := get_node_or_null("/root/MarriageManager")
	if marriage_manager != null and marriage_manager.has_method("is_spouse") \
			and bool(marriage_manager.is_spouse(npc_id)):
		var house: Vector2i = GameData.get_feature_tile("player_house", "fallowfield")
		if house.x >= 0:
			return house
	var festival_manager := get_node_or_null("/root/FestivalManager")
	if festival_manager != null and festival_manager.has_method("get_active_festival_anchor"):
		var anchor: Dictionary = festival_manager.get_active_festival_anchor()
		if not anchor.is_empty():
			return Vector2i(int(anchor.get("x", 0)), int(anchor.get("y", 0)))
	var schedule: Dictionary = GameData.get_villager_schedule(npc_id)
	var hour := TimeManager.hour
	var at_work := hour >= int(schedule.get("work_start_hour", 8)) \
		and hour < int(schedule.get("work_end_hour", 18))
	var anchor_tile: Dictionary = schedule.get("work", {}) if at_work else schedule.get("home", {})
	return Vector2i(int(anchor_tile.get("x", 0)), int(anchor_tile.get("y", 0)))
