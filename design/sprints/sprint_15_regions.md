# Sprint 15 - Regions & zone-keyed world state (ADR-034)

**Size:** L. **Markers:** AMENDMENT (CLAUDE.md section 2 gains a Region
bullet; sections 5 and 9.5's single-map wording is updated). No DESKTOP
marker - the new `ZoneManager` autoload registers headlessly through
`docs/register_autoloads.gd`, the same mechanism ADR-039 used for
`MarriageManager`.
**ADR:** ADR-034 - Accepted in principle (2026-08-06), implementation
deferred until "scheduled as a systems sprint in roadmap.md". This guide
is that scheduling. ADR-034's own text is unchanged; the CLAUDE.md
amendment is the remaining gate before work opens.
**Prerequisite:** Sprint 14 complete; the Sprint 15 CLAUDE.md amendment
landed (section 2 Region bullet, sections 5/9.5 wording); Stage 1 output
reviewed (`.deepseek/outputs/region_zone_map_out.md` -> full design at
`design/adr034_region_design.md`).

## Objective

Replace the single 30x20 `farm_map.json` grid with the nine-zone Vale of
the Nettle from Stage 1: Fallowfield (the player's holding), Nettleford,
the Manor of Harrowmere, the Upland Commons, Cottersward, the Nettle Brook
corridor, Edith's Plot, the North Strip, and the South Fields. The player
walks between zones by crossing map edges; only the current zone's terrain,
features, buildings, NPCs, and cull set are live at once. Simulation
state, physics, and saves remain axis-aligned and zone-local; the dimetric
projection is untouched (ADR-034's "compatible and helped by ADR-032"
relationship).

## Stage 1 input and the consult record

Stage 1's deliverable is `design/adr034_region_design.md` (the
`.deepseek/outputs/region_zone_map_out.md` receipt points to it). It
deliberately assigns **no tile coordinates** - every adjacency,
travel-time, and structure claim was meant to be fixed by Stage 2. This
guide is that geometry pass: the sizes, entry tiles, and exit ranges below
are Stage 2 proposals derived from the Stage 1 adjacency graph and
structure table, and the bidirectional-exit test in `test_zones.gd` exists
to prove they implement that graph. Travel minutes are fiction-scale and
are **not** encoded in any zone dimension (ADR-034 bans travel-time
simulation; zones are side-by-side flat planes).

DeepSeek consult (required by the task, performed 2026-08-07): POSTed to
`https://api.deepseek.com/chat/completions` with `model:
"deepseek-reasoner"` and the Codex-configured key. The endpoint returned
model id **`deepseek-v4-flash`** (finish `stop`; 4,655 reasoning + 2,310
content tokens), recommending **option A - one FarmGrid per zone behind a
ZoneManager autoload**, with the rationale used below. Pro-tier was not
consulted; the recommendation was reconciled against the live code (this
guide's API list is drawn from `farm_grid.gd`, `main.gd`, `npc.gd`,
`save_manager.gd`, `game_data.gd`, `building_manager.gd`, and the
renderers as they exist today).

## Scope and non-goals

**Delivers:**

- Zone-aware data: `farm_map.json` v4 (per-zone grids and features),
  `zones.json` v1 (zone list, exits, entry points, spawn), `tenure.json`
  v3 (strips re-expressed per zone), `villagers.json` v6 (zone-qualified
  anchors), `festivals.json` v3 (zone-qualified locations).
- One `FarmGrid` instance per zone (recommendation A below), a new
  `ZoneManager` autoload owning zone state and transitions.
- Edge-crossing zone transitions in the existing single scene, preserving
  all autoload state (inventory, money, energy, health, clock, weather,
  tithe, reputation, skills, buildings, animals, dialogue, marriage).
- Zone-aware NPC presence: a villager exists in the world only while the
  player is in the villager's current zone.
- `SAVE_VERSION` 17 -> 18 with a real migration (see Save version delta).

**Explicitly defers (do not build):**

- Fast travel, travel-time costs, random encounters, an overworld map,
  and a minimap - all out per ADR-034 and Stage 1.
- A master coordinate system or master map that the zones tile. Zones are
  separate maps; `zones.json` exits are the single source of adjacency
  truth. (Deliberate: ADR-034 says "separate maps", and a master grid
  would be a new simulation concept this sprint does not need.)
- Elevation in any form. "Upland", "north edge", "wooded shoulder" are
  narrative; no zone carries a height value, z-level, slope, or bridge
  (CLAUDE.md section 2 elevation ban, restated for this sprint).
- New mechanics: no fishing, no hunting, no NPC-to-NPC simulation, no
  travel UI, no zone-specific weather, no per-zone time.
- Deferred-raid or offscreen-raid resolution (see Integration points:
  RaidManager - a raid firing while the player is outside Fallowfield is
  message-only this sprint, flagged as an owner decision).
- The old church ruin, alehouse, smithy, mill, and other Stage 1 flavour
  structures get **no new feature ids or interactables**; they are
  narrative anchors (NPC home/work tiles) or are simply not rendered this
  sprint. `FeatureRenderer` continues to draw only the feature ids it
  already knows (`player_house`, `well`, `chapel`, `market_zone`,
  `town_board`, `stewards_demesne`).

## Data schema changes

### `data/farm_map.json` v4 - per-zone grids and features

The top-level `width`/`height`/`grid`/`features` keys are replaced by a
`zones` dictionary keyed by zone id. Every zone carries its own dims,
soil grid, and feature list. `GameData` keeps single-zone accessors with
an optional zone parameter defaulting to `DEFAULT_ZONE_ID` (see
GameData changes), so no pre-existing call site breaks at parse time.

```json
{
	"version": 4,
	"zones": {
		"fallowfield": {
			"width": 24, "height": 16,
			"grid": [
				["loamy","loamy","loamy", "..."],
				"..."
			],
			"features": [
				{ "x": 11, "y": 11, "feature": "player_house" },
				{ "x": 13, "y": 9, "feature": "well" }
			]
		},
		"nettleford": { "width": 24, "height": 16, "grid": ["..."], "features": [
			{ "x": 10, "y": 10, "feature": "chapel" },
			{ "x": 12, "y": 8, "feature": "market_zone" },
			{ "x": 11, "y": 8, "feature": "town_board" },
			{ "x": 20, "y": 9, "feature": "well" }
		] },
		"manor": { "width": 24, "height": 16, "grid": ["..."], "features": [
			{ "x": 4, "y": 6, "feature": "stewards_demesne", "width": 8, "height": 6 },
			{ "x": 18, "y": 12, "feature": "well" }
		] },
		"upland_commons": { "width": 32, "height": 14, "grid": ["..."], "features": [] },
		"cottersward": { "width": 24, "height": 14, "grid": ["..."], "features": [] },
		"nettle_brook": { "width": 16, "height": 32, "grid": ["..."], "features": [] },
		"ediths_plot": { "width": 16, "height": 14, "grid": ["..."], "features": [] },
		"north_strip": { "width": 24, "height": 8, "grid": ["..."], "features": [] },
		"south_fields": { "width": 24, "height": 14, "grid": ["..."], "features": [] }
	}
}
```

**Stage 2 zone geometry (concrete, derived from Stage 1 sections 3 and 4):**

| Zone id | Size (w x h) | Soil layout | Features (functional) | Exits (edge -> to) |
|---|---|---|---|---|
| `fallowfield` | 24x16 | Loamy dominant; one sandy pocket x16-19, y12-15 (Stage 1 3.1); road margin along west edge (visual, no exit) | `player_house` (11,11); starter `well` (13,9) - resolves Stage 1 open question 6 | north -> `north_strip`; east -> `ediths_plot`; south -> `south_fields` |
| `north_strip` | 24x8 | All loamy fallow | none | north -> `nettleford`; east -> `nettle_brook`; south x0-13 -> `fallowfield`; south x14-23 -> `ediths_plot` |
| `ediths_plot` | 16x14 | Loamy dominant; sandy 2-col east edge x14-15 (brook edge) | none (Edith's cottage/fields are home/work anchors) | north -> `north_strip`; east -> `nettle_brook`; west -> `fallowfield`; south -> `south_fields` |
| `nettleford` | 24x16 | Loamy; sandy lip x22-23 (ford flood edge, Stage 1 3.2) | `chapel` (10,10); `market_zone` (12,8); `town_board` (11,8); village `well` (20,9) - the ford refill point | north -> `manor`; east -> `nettle_brook` (the ford); south -> `north_strip` |
| `manor` | 24x16 | Loamy demesne; rocky north fringe rows 0-2 | `stewards_demesne` rect (4,6,8,6); manor `well` (18,12) | north -> `upland_commons`; south -> `nettleford` |
| `upland_commons` | 32x14 | Rocky dominant; scattered loamy hollows (minority patches) | none | south x0-23 -> `manor`; east -> `cottersward`; north/west are playable boundaries |
| `cottersward` | 24x14 | Loamy under trees; rocky north rows 0-2 | none | north -> `upland_commons`; south -> `nettle_brook` |
| `nettle_brook` | 16x32 | Sandy banks x4-11; loamy meadow x0-3 and x12-15 | none (mill and Marta's cottage are anchors, not interactables) | north -> `cottersward`; west y4-15 -> `nettleford`; west y16-23 -> `north_strip`; west y24-27 -> `ediths_plot`; west y28-31 -> `south_fields` |
| `south_fields` | 24x14 | Loamy both parcels; sandy pocket x17-20, y9-13 in the SE parcel; untillable gully column x11-12 | none | north x0-11 -> `fallowfield`; north x13-23 -> `ediths_plot`; east -> `nettle_brook`; south is the playable boundary |

Every Stage 1 adjacency pair appears exactly once as a directed exit in
each direction (14 pairs, 28 directed exits; the two deliberate
non-adjacencies - Manor/Cottersward and Village/Cottersward - must have **no**
exit). The old two `well` features map to the village well and manor well;
the starter well is the third `well`, on Fallowfield. No feature lives in
two zones; `test_zones.gd` asserts this.

### `data/zones.json` v1 - the zone list, exits, and spawn

```json
{
	"version": 1,
	"default_zone": "fallowfield",
	"spawn": { "zone": "fallowfield", "x": 12, "y": 10 },
	"zones": [
		{
			"id": "fallowfield", "name": "Fallowfield",
			"is_tillable": true, "allow_buildings": true, "forage_density": 0.8,
			"exits": [
				{ "edge": "north", "x_min": 6, "x_max": 17, "to": "north_strip", "arrive_at": { "x": 12, "y": 7 } },
				{ "edge": "east", "y_min": 2, "y_max": 13, "to": "ediths_plot", "arrive_at": { "x": 0, "y": 8 } },
				{ "edge": "south", "x_min": 4, "x_max": 19, "to": "south_fields", "arrive_at": { "x": 10, "y": 0 } }
			]
		},
		{ "id": "north_strip", "name": "The North Strip", "is_tillable": true, "allow_buildings": false, "forage_density": 1.0, "exits": [
			{ "edge": "north", "x_min": 2, "x_max": 21, "to": "nettleford", "arrive_at": { "x": 12, "y": 15 } },
			{ "edge": "east", "y_min": 0, "y_max": 7, "to": "nettle_brook", "arrive_at": { "x": 0, "y": 16 } },
			{ "edge": "south", "x_min": 0, "x_max": 13, "to": "fallowfield", "arrive_at": { "x": 12, "y": 0 } },
			{ "edge": "south", "x_min": 14, "x_max": 23, "to": "ediths_plot", "arrive_at": { "x": 2, "y": 0 } }
		] },
		{ "id": "ediths_plot", "name": "Edith's Plot", "is_tillable": false, "allow_buildings": false, "forage_density": 0.0, "exits": [
			{ "edge": "north", "x_min": 2, "x_max": 13, "to": "north_strip", "arrive_at": { "x": 16, "y": 7 } },
			{ "edge": "east", "y_min": 0, "y_max": 13, "to": "nettle_brook", "arrive_at": { "x": 0, "y": 22 } },
			{ "edge": "west", "y_min": 2, "y_max": 11, "to": "fallowfield", "arrive_at": { "x": 23, "y": 8 } },
			{ "edge": "south", "x_min": 2, "x_max": 13, "to": "south_fields", "arrive_at": { "x": 16, "y": 0 } }
		] },
		{ "id": "nettleford", "name": "Nettleford", "is_tillable": false, "allow_buildings": false, "forage_density": 0.4, "exits": [
			{ "edge": "north", "x_min": 4, "x_max": 19, "to": "manor", "arrive_at": { "x": 12, "y": 0 } },
			{ "edge": "east", "y_min": 6, "y_max": 11, "to": "nettle_brook", "arrive_at": { "x": 0, "y": 10 } },
			{ "edge": "south", "x_min": 2, "x_max": 21, "to": "north_strip", "arrive_at": { "x": 12, "y": 0 } }
		] },
		{ "id": "manor", "name": "The Manor of Harrowmere", "is_tillable": false, "allow_buildings": false, "forage_density": 0.5, "exits": [
			{ "edge": "north", "x_min": 4, "x_max": 19, "to": "upland_commons", "arrive_at": { "x": 12, "y": 13 } },
			{ "edge": "south", "x_min": 4, "x_max": 19, "to": "nettleford", "arrive_at": { "x": 12, "y": 15 } }
		] },
		{ "id": "upland_commons", "name": "The Upland Commons", "is_tillable": false, "allow_buildings": false, "forage_density": 1.2, "exits": [
			{ "edge": "south", "x_min": 0, "x_max": 23, "to": "manor", "arrive_at": { "x": 10, "y": 0 } },
			{ "edge": "east", "y_min": 0, "y_max": 13, "to": "cottersward", "arrive_at": { "x": 0, "y": 6 } }
		] },
		{ "id": "cottersward", "name": "Cottersward", "is_tillable": false, "allow_buildings": false, "forage_density": 1.2, "exits": [
			{ "edge": "north", "x_min": 2, "x_max": 21, "to": "upland_commons", "arrive_at": { "x": 31, "y": 6 } },
			{ "edge": "south", "x_min": 2, "x_max": 21, "to": "nettle_brook", "arrive_at": { "x": 0, "y": 0 } }
		] },
		{ "id": "nettle_brook", "name": "The Nettle Brook", "is_tillable": false, "allow_buildings": false, "forage_density": 1.0, "exits": [
			{ "edge": "north", "x_min": 2, "x_max": 13, "to": "cottersward", "arrive_at": { "x": 12, "y": 0 } },
			{ "edge": "west", "y_min": 4, "y_max": 15, "to": "nettleford", "arrive_at": { "x": 23, "y": 9 } },
			{ "edge": "west", "y_min": 16, "y_max": 23, "to": "north_strip", "arrive_at": { "x": 23, "y": 4 } },
			{ "edge": "west", "y_min": 24, "y_max": 27, "to": "ediths_plot", "arrive_at": { "x": 15, "y": 7 } },
			{ "edge": "west", "y_min": 28, "y_max": 31, "to": "south_fields", "arrive_at": { "x": 23, "y": 6 } }
		] },
		{ "id": "south_fields", "name": "The South Fields", "is_tillable": true, "allow_buildings": false, "forage_density": 1.0, "exits": [
			{ "edge": "north", "x_min": 0, "x_max": 11, "to": "fallowfield", "arrive_at": { "x": 10, "y": 15 } },
			{ "edge": "north", "x_min": 13, "x_max": 23, "to": "ediths_plot", "arrive_at": { "x": 14, "y": 13 } },
			{ "edge": "east", "y_min": 4, "y_max": 13, "to": "nettle_brook", "arrive_at": { "x": 15, "y": 10 } }
		] }
	]
}
```

Semantics: an `exit` means "crossing the source zone's named edge within
the optional range (columns for north/south, rows for east/west; omitted
range = whole edge) transitions to `to`, landing at `arrive_at` in the
destination's local coordinates." The `forage_density` is a per-zone
multiplier on `forage.json`'s `spawn_chance_per_tile_per_day` (0.0 on
Edith's Plot - occupied tenant land is not pickable, resolving Stage 1
open question 10; low on the village and manor margins per Stage 1 3.2/3.3;
high on the wild zones). `is_tillable` marks zones where ownership can
ever grant tilling; the actual gate stays `BuildingManager`
zone ownership.

`GameData`: new `zones_cfg` dictionary loaded by a dedicated
`_load_zones("zones.json")` (patterned on `_load_enemies`, casting
`x`/`y`/`x_min`/`x_max`/`y_min`/`y_max` ints via a new `ZONE_INT_KEYS`
list). New accessors: `get_zone_ids() -> Array[String]`,
`get_zone(zone_id) -> Dictionary`, `get_zone_metadata(zone_id) ->
Dictionary`, `get_zone_exits(zone_id) -> Array[Dictionary]`,
`get_spawn_point() -> Dictionary`, `get_default_zone() -> String`, plus
the zone-aware forms of every map accessor (below).

### `data/tenure.json` v3 - strips re-expressed per zone

```json
{
	"version": 3,
	"default_owned_zone": "fallowfield",
	"strips": [
		{ "id": "strip_north", "name": "Northern Strip", "zone": "north_strip", "rect": { "x": 0, "y": 0, "width": 24, "height": 8 } },
		{ "id": "strip_southwest", "name": "Southwestern Strip", "zone": "south_fields", "rect": { "x": 0, "y": 0, "width": 11, "height": 14 } },
		{ "id": "strip_southeast", "name": "Southeastern Strip", "zone": "south_fields", "rect": { "x": 13, "y": 0, "width": 11, "height": 14 } }
	]
}
```

`default_owned_rect` becomes `default_owned_zone` (the whole Fallowfield
grid is the player's holding). Strip ids are unchanged so `TitheManager`'s
per-held-strip surcharge (ADR-038) and `BuildingManager.is_strip_rented`
need no rename. `TENURE_INT_KEYS` returns to service for the nested rect
fields and gains the strip `zone` string field handling in the tenure
cast helper.

### `data/villagers.json` v6 - zone-qualified anchors

Every villager's `spawn` and `schedule.home`/`schedule.work` gain a
`zone` field; `x`/`y` become zone-local:

```json
{ "id": "marta", "name": "Marta", "role": "villager", "faction": "village",
	"traits": ["quiet", "thief"],
	"spawn": { "zone": "nettle_brook", "x": 6, "y": 20 },
	"schedule": { "home": { "zone": "nettle_brook", "x": 6, "y": 20 },
		"work": { "zone": "nettleford", "x": 20, "y": 9 }, "work_start_hour": 8, "work_end_hour": 18 },
	"likes": ["turnip", "wild_herb", "pea"], "dislikes": ["barley"] }
```

Stage 1 who-lives-where, concretely: Aldric (home/work `nettleford`,
steward's house / market stall), Tomas (home/work `nettleford`, priest
cottage / chapel), Hilda (home/work `nettleford`, alehouse), Cedric
(home/work `nettleford`, smithy), Marta (home `nettle_brook`, work
`nettleford` - her work tile is the village well tile, resolving Stage 1
open question 3), Bram (home/work `nettleford`, yard), Edith (home/work
`ediths_plot`), Osric (home/work `nettle_brook`, miller's cottage / mill),
Simkin (home/work `nettleford`, stall). `GameData._cast_nested_ints`
gains the schedule anchor x/y casts.

### `data/festivals.json` v3 - zone-qualified locations

Every `location` gains `"zone": "nettleford"` (all four festivals are
village events per Stage 1). `FestivalManager.get_active_festival_anchor()`
returns `{ "zone", "x", "y" }` instead of a bare `{x, y}`. **Do not
silently change `springturn_blessing`'s day (18) to the bible's 21** -
that is a content ruling, not an architecture fix; it stays an open owner
question (Stage 1 open question 8). Its placeholder coordinates are
replaced by the Nettleford chapel tile (10,10).

## `FarmGrid` architecture decision

**Recommendation: one `FarmGrid` instance per zone (option A), owned by a
new `ZoneManager` autoload.**

The two candidates weighed:

- **A - one instance per zone.** Each zone gets its own `FarmGrid`,
  configured with that zone's width/height/soil grid. Existing
  `Vector2i`-keyed methods keep their exact signatures; positions are
  zone-local by construction, so no coordinate-space ambiguity can enter.
  The save migration is a pure wrap (`farm.cells` ->
  `farm.zones.fallowfield.cells`), no per-cell rewriting. Test churn is
  minimal: every suite that builds a `FarmGrid` via `configure_for_test`
  keeps compiling and passing; new suites target `ZoneManager`.
  Renderer culling needs only the active grid's dims, which
  `IsoProjection.visible_cells` already accepts. Memory is trivial (nine
  zones ~ 3,200 cell dicts).
- **B - one grid, zone dimension in the key space.** Either every method
  signature gains a zone parameter (touches ~20 call sites and every
  existing suite) or the class routes through a mutable "current zone"
  field (hidden state, order-dependent tests, and a per-cell save rewrite
  for migration). It buys nothing the renderer needs.

The DeepSeek consult (recorded above) recommended A for the same reasons.
The one genuine cost of A is that ZoneManager must choreograph the swap
(active grid, renderers, camera, NPC set) atomically - that is this
sprint's main new complexity, and it is concentrated in one autoload.

### `FarmGrid` API changes (minimal by design)

Unchanged signatures (byte-for-byte): `configure_for_test`, `till_tile`,
`plant`, `water_tile`, `apply_compost`, `harvest`, `has_forage`,
`gather_forage`, `can_dig`, `dig_cell`, `advance_day`, `is_tilled`,
`is_harvestable`, `get_cell`, `get_cell_moisture`, `get_cell_fertility`,
`get_soil`, `is_owned`, `get_crop_name`, `tile_count`, `planted_count`,
`to_dict`, `from_dict`.

New members:

```gdscript
var _zone_id: String = ""   # set by ZoneManager at construction

func set_zone_id(zone_id: String) -> void
func get_zone_id() -> String
func get_grid_size() -> Vector2i    # active grid dims; renderer uses this instead of GameData
```

`configure_for_test` gains a trailing optional `zone_id := ""` parameter
(fully backward-compatible). Internal changes only:

- `_ready()`/`_build_live_grid()` read `game_data.get_map_width(_zone_id)`
  / `get_soil_at(x, y, _zone_id)`.
- `_is_owned(pos)` calls `BuildingManager.is_land_owned_in_zone(_zone_id,
  pos)` instead of the bare `is_land_owned(pos)`.
- `advance_day()` multiplies `spawn_chance_per_tile_per_day` by
  `game_data.get_zone_metadata(_zone_id).get("forage_density", 1.0)`.

`to_dict()`/`from_dict()` keep their per-grid `{cells, daily_dig_count}`
shape; ZoneManager composes the zone dimension, so `FarmGrid` itself
never knows about zones in its save format.

### `BuildingManager` changes

- New `is_land_owned_in_zone(zone_id: String, pos: Vector2i) -> bool`:
  true for every tile when `zone_id == "fallowfield"`; otherwise true
  only inside a rented strip whose `tenure.json` `zone` matches.
  `is_land_owned(pos)` is kept as a default-zone alias so pre-existing
  call sites and suites keep compiling.
- `can_place_building(building_id, pos, zone_id := DEFAULT_ZONE_ID)`
  additionally requires the zone's `allow_buildings` (only Fallowfield is
  true). `start_building` stores `"zone_id": zone_id` in each placed
  entry.
- `get_placed_buildings(zone_id := "")` filters when a zone is given
  (renderer uses this); `get_building_id_at(pos, zone_id :=
  DEFAULT_ZONE_ID)` becomes zone-aware.

## `ZoneManager` autoload (`scripts/autoloads/zone_manager.gd`)

`extends Node`, no `class_name` matching the singleton (CLAUDE.md rule
3.2). Registered headlessly by adding `["ZoneManager",
"res://scripts/autoloads/zone_manager.gd"]` to
`docs/register_autoloads.gd`'s `NEW_AUTOLOADS` and running the script -
no DESKTOP step (ADR-039 precedent). It is a data/state owner, not a
world-node owner: it holds the zone registry, the active-zone id, the
player's current zone/tile, and the per-zone `FarmGrid` references that
`main.gd` registers into it.

```gdscript
signal zone_changed(zone_id: String)

const DEFAULT_ZONE_ID := "fallowfield"

var _grids: Dictionary = {}            # zone_id -> FarmGrid node
var _active_zone_id := DEFAULT_ZONE_ID
var _player_tile := Vector2i(12, 10)   # fallowfield spawn; persisted
var _test_mode := false

func configure_for_test(game_data: Node, grids: Dictionary, active_zone := DEFAULT_ZONE_ID) -> void
func register_farm_grid(zone_id: String, grid: Node) -> void
func get_farm_grid(zone_id: String) -> Node
func get_all_farm_grids() -> Array[Node]
func get_active_zone_id() -> String
func get_active_farm_grid() -> Node
func get_player_tile() -> Vector2i
func set_player_tile(tile: Vector2i) -> void
func find_exit(zone_id: String, edge: String, index: int) -> Dictionary
func get_exits(zone_id: String) -> Array[Dictionary]
func resolve_exit(zone_id: String, edge: String, index: int) -> Dictionary   # {} when no match
func change_zone(zone_id: String, arrive_tile: Vector2i) -> bool
func get_npc_zone(npc_id: String) -> String
func advance_day(rain: bool, overcast: bool) -> void
func to_dict() -> Dictionary
func from_dict(data: Dictionary) -> void
func apply_saved_state(player: Node) -> void
```

`change_zone` is the model-layer transition: validates the zone id,
sets `_active_zone_id`, sets `_player_tile = arrive_tile`, emits
`zone_changed`. It deliberately does **not** touch scene nodes; `main.gd`
does the world swap in its `zone_changed` handler (single choreographer
responsibility - the consult's flagged risk). `advance_day` forwards to
every registered grid, so rain auto-waters all zones' tilled cells even
while the player is elsewhere (the current single-grid semantics,
preserved region-wide). `to_dict()`/`from_dict()` own the new farm save
shape (below).

## Scene / transition architecture

**One scene, no reload.** `main.tscn`'s `Main` root stays; `title_screen
-> main` flow is unchanged (CLAUDE.md section 5's scene flow is amended
only in that transitions are in-scene, not new scenes). All nine
`FarmGrid` nodes exist as children of `Main` at boot (built by `main.gd`
in `_ready`, registered with ZoneManager, each `visible = false` except
the active one). `FarmRenderer`/`FeatureRenderer`/`BuildingRenderer`
rebuild against the active zone's grid/features on `zone_changed`.

**Trigger: walking off a map edge.** No new input action, no Travel
interaction. Each physics tick, after the player moves, `main.gd` checks
`player.get_current_tile()` against `zone_manager.get_active_farm_grid().
get_grid_size()`; out of bounds, it calls
`zone_manager.resolve_exit(zone_id, edge, index)` for the crossed edge
(north when `y < 0`, south when `y >= height`, west when `x < 0`, east
when `x >= width`; `index` is the row/column at the crossing). If an exit
matches, `zone_manager.change_zone(to, arrive_at)`; if not (a playable
boundary such as the South Fields' south edge), the player is clamped
back inside and nothing else happens.

**`zone_changed` handler in `main.gd` (the world swap, in order):**

1. `player.set_active_farm_grid(zone_manager.get_active_farm_grid())` -
   swaps `Player._farm_grid` and `ToolManager._farm_grid` (new
   `ToolManager.set_farm_grid(grid)`; `Player` gains `get_farm_grid()`
   and `set_active_farm_grid()`). `Player.set_farm_grid` remains the boot
   wiring.
2. `player.position = Vector2(player_tile.x * 32.0 + 16.0,
   player_tile.y * 32.0 + 16.0)`; `player.velocity = Vector2.ZERO`.
3. `iso_camera.set_map_dims(width, height)` - new method on IsoCamera
   (dims override `_game_data.get_map_width()/get_map_height()` in
   `_process` and `_recompute_limits()`). The camera follows the player's
   projected position, so no other change is needed. Larger zones also
   retire most of the documented 30x20 degenerate-clamp case.
4. `farm_renderer.set_active_grid(grid)` - re-configures the grid
   reference and redraws (`configure` already tolerates re-wiring; keep
   its `tile_changed` connection management safe against double
   connects).
5. `feature_renderer.set_active_zone(zone_id)` - frees the previous
   zone's collision bodies and StructureVisuals and rebuilds from
   `GameData.get_all_features(zone_id)`. Free children synchronously
   (safe: this runs from ZoneManager's signal, never from a fixture's own
   callback; CLAUDE.md trap 4).
6. `building_renderer.set_active_zone(zone_id)` - rebuilds visuals from
   `get_placed_buildings(zone_id)` (all Fallowfield this sprint).
7. NPC set: free all NPC nodes and NpcVisuals, then
   `_spawn_npcs_for_zone(zone_id)` (below); rebuild `_npc_tiles` and
   re-`player.set_npc_lookup(...)`.
8. Animal visuals (whatever AnimalManager spawns today - verify its spawn
   path during implementation) are hidden when `zone_id != "fallowfield"`;
   animals are holding-only per Stage 1.
9. `ZoneManager.set_player_tile` is already updated by `change_zone`.

**Carries over:** everything owned by autoloads - inventory, money,
energy, health, equipped items, time-of-day/season/year, weather,
tithe/court/corvee state, reputation/opinions/requests, skills,
buildings/tenure, animals, dialogue history, marriage, investigation.
**Resets:** player position (to the arrival tile), the NPC node set (only
current-zone NPCs), renderer content (per-zone), camera bounds.

**Load path:** `SaveManager.load_game()` in `main.gd._ready()` now runs
`zone_manager.from_dict(payload["farm"])` inside `apply_payload`; after
loading, `main.gd` calls `zone_manager.apply_saved_state(player)`, which
repositions the player and triggers the same world swap via
`zone_changed` (guard the handler against running before panels exist -
the existing `_ready` order already builds panels before loading).

## NPC schedule changes

`npc.gd` keeps `_home_pos`/`_work_pos` as zone-local `Vector2` and gains
`_home_zone: String` / `_work_zone: String`. `_update_anchor(hour)`
computes an anchor as `{zone, pos}`:

- Marriage override first: spouse anchors at Fallowfield's
  `player_house` tile (`GameData.get_feature_tile("player_house",
  "fallowfield")`).
- Festival override second: anchors at the active festival's
  `location.zone` + tile (Nettleford this slice).
- Otherwise `work` zone/pos during work hours, `home` zone/pos outside.

New pure helper on the class: `get_current_zone() -> String` (same three
overrides), consumed by ZoneManager:

```gdscript
func get_npc_zone(npc_id: String) -> String:
	var mm := get_node_or_null("/root/MarriageManager")
	if mm != null and mm.has_method("is_spouse") and mm.is_spouse(npc_id):
		return "fallowfield"
	var fm := get_node_or_null("/root/FestivalManager")
	if fm != null and fm.has_method("get_active_festival_anchor"):
		var anchor: Dictionary = fm.get_active_festival_anchor()
		if not anchor.is_empty():
			return str(anchor.get("zone", "nettleford"))
	var schedule: Dictionary = GameData.get_villager(npc_id).get("schedule", {})
	var hour := int(TimeManager.get("hour"))
	var anchor := schedule.get("work", {}) \
		if hour >= int(schedule.get("work_start_hour", 8)) and hour < int(schedule.get("work_end_hour", 18)) \
		else schedule.get("home", {})
	return str(anchor.get("zone", DEFAULT_ZONE_ID))
```

`main.gd._spawn_npcs()` becomes `_spawn_npcs_for_zone(zone_id)`: iterate
`GameData.get_all_villager_ids()`, keep only those with
`zone_manager.get_npc_zone(npc_id) == zone_id`, spawn the NPC node with
its anchor tile's zone-local position, and create its NpcVisual under
`world_visuals` (exactly today's shape, filtered). ZoneManager also
re-filters on the hour boundary: subscribe to `TimeManager.minute_passed`
and, when the hour changes, recompute each villager's zone; if an NPC in
the active zone moved zones (or a villager elsewhere moved into it),
re-run the spawn/despawn for the active zone. `_npc_tiles` is rebuilt on
every spawn pass, so `player.set_npc_lookup` keeps pointing at a current
dictionary. NPC nodes hold no persistent state (dialogue/gifting/requests
live in autoloads), so despawn/respawn loses nothing.

**Player-facing consequence:** entering Nettleford during Marta's work
hours shows her by the village well; entering the brook during her work
hours does not show her - she is at work. The alibi data Sprint 12's
investigation reads comes from `GameData.get_villager_schedule()`, which
now includes zones, so alibi framing extends to "which zone they were
in".

## Save version delta

`SAVE_VERSION` **17 -> 18** (confirmed current 17 by reading
`save_manager.gd` before writing this). New farm payload shape:

```json
"farm": {
	"current_zone": "fallowfield",
	"player_tile": { "x": 12, "y": 10 },
	"zones": {
		"fallowfield": { "cells": [ ...existing cell dicts... ], "daily_dig_count": 0 },
		"nettleford": { "cells": [], "daily_dig_count": 0 },
		"...every zone id...": { "cells": [], "daily_dig_count": 0 }
	}
}
```

`build_payload()`: when `get_node_or_null("/root/ZoneManager")` resolves,
`payload["farm"] = zone_manager.to_dict()` (which composes each grid's
`to_dict()` under its zone id plus `current_zone`/`player_tile`);
otherwise the existing injected `_farm_grid_ref` fallback is kept so
single-grid test fixtures keep working. `apply_payload()` mirrors this:
zones shape routes each zone's `from_dict`; flat shape falls back to the
injected grid. `set_farm_grid_ref` stays (tests + fallback).

`migrate_to_v18(payload)`:

```gdscript
func migrate_to_v18(payload: Dictionary) -> Dictionary:
	payload["version"] = 18
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
```

Chain: `if version <= 17: parsed = migrate_to_v18(parsed)`.
Migration semantics, stated explicitly: **a v17 (or older) save with no
zone data at all has every existing farm cell wrapped under
`fallowfield` (the player's plot), the player's current zone defaults to
`fallowfield`, the player spawns at Fallowfield's spawn tile, every
existing building defaults to `fallowfield`, and all other zones start
empty.** This preserves every pre-existing cell field untouched
(`tilled`, `crop_id`, `growth_progress`, `moisture`, `days_mature`,
`forage_item_id`, `forage_yield`, `fertility`) - the wrap must not
rewrite cells, only relocate them.

## Integration points - every single-map assumption

- **CLAUDE.md section 9.5 (world representation):** the single-`FarmGrid`
  representation becomes one `FarmGrid` per zone + `ZoneManager`;
  farm state lives in per-zone grids; renderers cull to the active
  zone's visible rect; no script assumes any fixed dimension (the
  `IsoProjection.visible_cells` cull seam already takes `map_w`/`map_h`,
  now fed per-zone). Section 5's scene flow wording ("title -> main")
  stays, amended only to note in-scene zone transitions. Both are part of
  the AMENDMENT marker.
- **CLAUDE.md section 2 scope:** gains a Region bullet describing the
  nine-zone vale and zone transitions (AMENDMENT marker). ADR-034 is
  already Accepted-in-principle, so no new ADR is owed; the amendment is
  the contract-side step.
- **ADR-007 (property and soil regions):** soil regions become per-zone
  (`farm_map.json` v4). "The whole property is eligible for field or
  building" is amended to "the holding plus rented strips are eligible
  for field; only the holding is eligible for building" - ADR-034's
  structure placement and Stage 1's arable-only rented strips (open
  question 9, answered: buildings stay on the holding).
- **ADR-019 (soil scarcity and map redraw):** the redraw is re-expressed
  per zone: loam is the vale floor (Fallowfield, North Strip, South
  Fields, Nettleford, Manor demesne), sand the brook/ford edges and the
  SE pockets, rock the upland fringe. The old 30x20 checksum-style
  coverage tests (`test_season_sim.gd` loamy rects, `test_tenure.gd`
  area sums) are re-expressed against the new zones rather than deleted.
- **ADR-023 (buildings and land tenure):** tenure rects move to
  zone-local coordinates (`tenure.json` v3); ownership is
  zone-qualified (`BuildingManager.is_land_owned_in_zone`); tilling is
  gated per active zone grid; building placement is gated to Fallowfield
  (`allow_buildings`). Renting still raises the ADR-038 held-strip tithe
  surcharge unchanged (strip ids preserved).
- **ADR-032 (projection):** **`scripts/globals/iso_projection.gd` needs
  zero changes.** The projection is presentation-only and zone-agnostic;
  zone-aware rendering only means feeding the existing `visible_cells`
  the active zone's dims. No projected value enters gameplay state, and
  no gameplay decision is made from one - restated, not changed.
- **ADR-024 (NPC schedules):** home/work anchors gain zones (above);
  the alibi data is now zone-qualified.
- **ADR-026 / raids:** `RaidManager._spawn_raid` spawns enemies around
  the player's `global_position`, which would drop enemies into whatever
  zone is active. Gate world spawning to `active_zone_id ==
  "fallowfield"` (the farm is the raid target). **Flagged decision:** if
  the trigger fires while the player is elsewhere, the raid is
  message-only this sprint (no deferred-raid state, no save impact);
  owner may prefer a deferral in a later sprint.
- **ADR-030/036 (festivals):** festival location becomes zone-qualified;
  attendance and contest checks in `main.gd`/`FestivalManager` gate on
  active zone == Nettleford.
- **ADR-031 (marriage):** spouse anchor is Fallowfield's `player_house`;
  `MarriageManager.set_farm_grid_ref` receives the Fallowfield grid at
  boot (the spouse chore waters the holding, not the active zone).
- **ADR-037 (economy):** `market_zone`/`town_board` now live in
  Nettleford; the shop/board panels open only from that zone. Supply
  pressure and board orders are zone-agnostic (autoload state) and need
  no change.
- **ADR-038 (tithe):** `_held_strip_count` counts rented strip ids -
  unchanged. `TitheManager._farm_grid()` has no live consumer today
  (verified by reading the file); if a demesne chore needs tile state,
  re-point it to the manor grid. No other tithe change.
- **`main.gd`:** `_on_day_passed` calls `zone_manager.advance_day(...)`
  instead of `farm_grid.advance_day(...)`; `CHAPEL_TILE` becomes
  zone-qualified (`GameData.get_feature_tile("chapel", "nettleford")`)
  and the mass/festival checks gate on active zone; `_sleep` is
  unchanged (only reachable at Fallowfield's `player_house`).

## Tests

### New: `tests/suites/test_zones.gd` (data/geometry, 25+ checks)

Real GameData (`GAME_DATA_SCRIPT.new(); gd.load_all()`), plus the
Stage 1 adjacency list as a fixture:

1. `t.eq(gd.get_zone_ids().size(), 9, "all nine Stage 1 zones are present")`
   - and each expected id is in the list.
2. For every zone: `t.ok(gd.get_zone(id).get("width", 0) > 0 and
   gd.get_zone(id).get("height", 0) > 0, "zone %s has positive dims" % id)`.
3. Bidirectional exits: for every exit `e` from A to B, `t.ok(
   _has_exit_to(gd, B, A), "%s->%s has a return exit" % [A, B])`; every
   `arrive_at` is inside the destination's bounds; every `edge`/range is
   inside the source's bounds.
4. Non-adjacency: `t.not_ok(_has_exit_to(gd, "manor", "cottersward"),
   "manor and cottersward are separated by the road")` and the same for
   `nettleford`/`cottersward`.
5. Feature exclusivity: `t.eq(gd.get_all_features("fallowfield").size(),
   2, "fallowfield carries house + starter well only")`; every feature
   id appears in exactly one zone; `player_house` only in fallowfield;
   `chapel`/`market_zone`/`town_board` only in nettleford;
   `stewards_demesne` only in manor; three `well`s total across
   fallowfield/nettleford/manor.
6. Spawn: `t.eq(str(gd.get_spawn_point().get("zone", "")), "fallowfield",
   "new games boot in the player's plot")` and the spawn tile is in
   bounds.
7. Coverage checksum: sum of zone areas equals 3200 and each
   `is_tillable` zone's grid rows match its declared height.

### New: `tests/suites/test_zone_manager.gd` (model, 25+ checks)

Construct `ZONE_MANAGER_SCRIPT.new()`, `configure_for_test(gd, grids,
"fallowfield")` with nine real `FarmGrid`s (real GameData or MINI
fixtures - either is fine; one consistent choice per suite):

1. `t.eq(zone_manager.get_active_zone_id(), "fallowfield", "defaults to
   the player's plot")`.
2. `t.eq(zone_manager.change_zone("nettleford", Vector2i(12, 15)), true,
   "change_zone accepts a valid zone")`; `t.eq(zone_manager.get_player_tile(),
   Vector2i(12, 15), "player tile is the arrival tile")`; a `zone_changed`
   signal fired once (boxed-Array counter pattern from `test_market.gd`).
3. `t.eq(zone_manager.change_zone("not_a_zone", Vector2i.ZERO), false,
   "unknown zone is rejected with no state change")`.
4. `resolve_exit`: for each of fallowfield's three exits,
   `t.eq(str(zone_manager.resolve_exit("fallowfield", "north", 12).get("to",
   "")), "north_strip", "north-edge crossing resolves to the North Strip")`;
   `t.ok(zone_manager.resolve_exit("fallowfield", "south", 12).is_empty()
   == false ...)` and a boundary tile with no exit (e.g. fallowfield west
   edge) returns `{}`.
5. `advance_day(true)` waters every zone: `t.eq(
   zone_manager.get_farm_grid("nettle_brook").get_cell(Vector2i(4, 4)).get(
   "moisture", 0.0), 100.0, "rain waters a brook-zone cell while the
   player is elsewhere")`.
6. `to_dict()`/`from_dict()` round-trip: nine zone keys, non-empty
   fallowfield cells, `current_zone`/`player_tile` restored exactly.

### New: `tests/suites/test_zone_transitions.gd` (integration, 20+ checks)

Real `Player`/`PlayerState`/`TimeManager`-shaped fixtures where needed
(follow `test_iso_actors.gd`'s off-tree construction pattern):

1. Seed `player_state.add_item("turnip", 5)`; call
   `zone_manager.change_zone("nettleford", Vector2i(12, 15))` and the
   main-handler equivalent; `t.eq(player_state.get_item_count("turnip"),
   5, "inventory survives a zone transition")`. Same assertion for money,
   energy, and `time_manager.to_dict().hour` (14) unchanged.
2. `t.eq(player.position, Vector2(12 * 32.0 + 16.0, 15 * 32.0 + 16.0),
   "player lands on the arrival tile in world units")`.
3. `t.eq(player.get_farm_grid(), zone_manager.get_farm_grid("nettleford"),
   "player tools target the active zone grid")`; tilling a Nettleford
   tile then returns false (not farmland) while the fallowfield grid is
   untouched.
4. Active-zone NPC membership: at hour 10 in nettleford,
   `t.ok(npc_ids_in_active_zone.has("marta"), "Marta works in Nettleford
   by day")`; after switching to nettle_brook at hour 10,
   `t.not_ok(npc_ids_in_active_zone.has("marta"), "Marta is not in the
   brook during work hours")`; at hour 20 in nettle_brook,
   `t.ok(npc_ids_in_active_zone.has("marta"), "Marta is home by night")`;
   `t.not_ok(npc_ids_in_active_zone.has("edith"), "Edith never appears in
   Nettleford")`.
5. Camera bounds: `t.eq(iso_camera.get_map_dims(), Vector2i(24, 16),
   "camera clamps to the active zone's dimensions")` after entering
   nettleford.

### New: `tests/suites/test_save_v18.gd` (migration; fold into
`test_save_roundtrip.gd` where the existing v17 assertions live)

1. Write a realistic v17 payload (copy `SAMPLE_V5` and run the existing
   chain to 17, or build one by hand); `t.eq(int(migrated.get("version",
   -1)), 18, "v17 migrates to version 18")`.
2. `t.eq((migrated.get("farm", {}).get("zones", {}).get("fallowfield",
   {}).get("cells", []) as Array).size(), 1, "v17 cells wrap under
   fallowfield")`; `t.eq(float((migrated["farm"]["zones"]["fallowfield"]
   ["cells"][0] as Dictionary).get("fertility", -1.0)), 100.0, "cell
   fertility survives the wrap untouched")`.
3. `t.eq(str(migrated.get("farm", {}).get("current_zone", "")),
   "fallowfield", "no-zone saves default to the player's plot")`;
   `t.eq(int(migrated.get("farm", {}).get("player_tile", {}).get("x",
   -1)), 12, "player defaults to the fallowfield spawn tile")`.
4. `t.eq(str((migrated.get("buildings", {}).get("placed", [])[0] as
   Dictionary).get("zone_id", "")), "fallowfield", "existing buildings
   default to the holding")`.
5. Round-trip through `ZoneManager.from_dict`: nine zones, fallowfield
   state restored; `t.ok(not migrated.get("farm", {}).has("cells"),
   "flat farm.cells is consumed by the v18 migration")`.

### Existing suites to update (not just run)

- `test_season_sim.gd`: re-express the loamy-rect playthrough against
  fallowfield's layout; assert the season still ends affordable at the
  same tithe goal.
- `test_tenure.gd`: replace 30x20 area arithmetic with per-zone strip
  rects; add `t.not_ok(farm_grid_north.till_tile(Vector2i(12, 4)),
  "unrented strip tile cannot be tilled")` then
  `bm.rent_strip("strip_north")` then `t.ok(farm_grid_north.till_tile(
  Vector2i(12, 4)), "rented strip tile becomes tillable")`.
- `test_iso_terrain.gd` / `test_iso_camera.gd`: mocks implement
  `get_map_width`/`get_map_height` - they can keep compiling via the
  default-zone alias, but add zone-aware cases (per-zone cull rect).
- `test_iso_structures.gd`: real-data fixtures now assert per-zone
  anchors (well at (13,9) fallowfield, (20,9) nettleford, (18,12) manor;
  chapel/market/town_board in nettleford; demesne rect in manor).
- `test_schedules.gd`: add zone assertions to the position checks
  (`get_current_zone` at a given hour).
- `test_buildings.gd`: `can_place_building` bounds now use fallowfield
  dims (24x16); the `Vector2i(30, 0)` case stays false.
- `tests/run_tests.gd`: register `test_zones.gd`, `test_zone_manager.gd`,
  `test_zone_transitions.gd` (and the save additions live in the
  existing save suite).

## Sizing and sequencing

**Recommendation: one roadmap row (Sprint 15, L), implemented as two
independently-green internal passes.** Do not make it a single monolithic
landing.

- **Sprint 15a - data model, FarmGrid architecture, save migration (M).**
  `farm_map.json` v4 + `zones.json` v1 + `tenure.json` v3 +
  `villagers.json` v6 + `festivals.json` v3 authoring; GameData
  zone-aware accessors; per-zone FarmGrid construction + `zone_id`/
  `get_grid_size`; `ZoneManager` with registry, `advance_day`,
  `to_dict`/`from_dict`, `get_npc_zone`; BuildingManager
  zone-aware ownership; `SAVE_VERSION` 18 migration; `test_zones`,
  `test_zone_manager`, `test_save_v18`, and the tenure/iso/season-sim
  fixture updates. Live game still boots and plays entirely on
  Fallowfield (active zone defaults there); all new suites green before
  15b opens.
- **Sprint 15b - transitions, rendering, NPC zone-awareness (M-L).**
  Edge-triggered `zone_changed` world swap in `main.gd` (player/grid
  swap, camera dims, feature/building renderer rebuilds, NPC
  spawn/despawn, animal visual gating), festival/marriage zone anchors,
  RaidManager fallowfield gate, `test_zone_transitions` and the
  schedules/structures updates, plus the full manual pass.

Reasoning: the data schema and migration are the riskiest part and are
fully testable without any scene change; transitions are the second
independent risk and sit cleanly on top of 15a. This mirrors how
ADR-032's conversion was phased (data seam first, actors/structures
after).

## Risk list

1. **Stage 1 left geometry open.** The sizes/exits/entry tiles above are
   Stage 2 proposals, not Stage 1-verified facts. The bidirectional-exit
   suite is the guard; an exit that contradicts Stage 1's adjacency
   graph is a blocker caught by test, not a silent redesign.
2. **The save wrap is the one irreversible-looking operation.** A bug
   that rewrites cells (instead of relocating them) corrupts every legacy
   save. Mitigation: `migrate_to_v18` must be tested against a realistic
   v17 payload with non-default `fertility`, forage, and `days_mature`
   values, and the "flat farm.cells is consumed" assertion.
3. **Choreography drift in the zone swap.** If the player's grid,
   renderer bounds, camera dims, and NPC set are not swapped together,
   gameplay/culling desync (the consult's own flagged risk). Mitigation:
   `zone_changed` handler is the single place that mutates the world; the
   integration suite asserts the whole tuple after one call.
4. **Renderer rebuild churn.** `queue_free()`/signal races on per-zone
   rebuilds (CLAUDE.md traps 3-4): Area2D signals fire a tick late on
   fresh spawns, and freed nodes linger in arrays. Follow the
   `BuildingRenderer._rebuild_buildings` precedent (synchronous free from
   the signal handler, `is_instance_valid` guards).
5. **Silent test vacuity.** Suites that call `get_map_width()` against a
   v4 file with no top-level `width` could get 0 and pass vacuously.
   Mitigation: the default-zone alias returns fallowfield dims, and new
   suites assert non-zero dims + the 3200-tile checksum.
6. **NPC data migration ambiguity** (consult's flagged risk): existing
   `villagers.json` anchors were never zone-qualified; the authoring pass
   must place every anchor on a valid tile in its new zone (Marta's work
   tile becomes the village well tile; her current rocky placeholder
   tiles are discarded). `test_schedules.gd` validates every anchor is in
   bounds.
7. **Festival content mismatch.** Re-anchoring the festival location to
   Nettleford is architecture; changing day 18 -> 21 is content and stays
   an owner decision (flagged, not silently fixed).
8. **Raid behavior outside Fallowfield** is message-only this sprint - an
   accepted edge case that a player could in principle exploit to dodge a
   raid. Flagged for the owner; a deferred-raid state machine is a later
   sprint if the exploit matters.
9. **GDScript parse/hang trap.** Adding suites to `run_tests.gd`'s const
   array can manifest as a 12-minute silent hang on a parse error (the
   documented ADR-039 incident). Add suites one at a time and run an
   isolated runner if the full run stops printing.
10. **Camera clamp regressions.** The 30x20 degenerate-clamp path is
    documented and tested; per-zone dims change the exercised branch.
    `test_iso_camera.gd` must cover one small zone (north_strip, 24x8)
    and one large one (nettle_brook, 16x32).

## Manual test checklist

1. Open the project in Godot 4.7.1 and press F5 - the game runs with no
   errors in Output, booting on Fallowfield at the spawn tile.
2. Walk north across Fallowfield's top edge - the scene switches to the
   North Strip, the player lands on the arrival tile, the HUD (time,
   money, energy, inventory) is unchanged, and the camera is clamped to
   the new map.
3. Walk north again into Nettleford - the market stall, town board,
   chapel, and village well render; talking to the steward/Hilda works.
4. Walk east at the ford into the brook corridor - Marta is absent at
   hour 10 (she is at work in the village) and Osric is at the mill;
   return to Nettleford and confirm Marta is by the village well during
   work hours.
5. Till a tile in the North Strip before renting it - fails; rent
   `strip_north` via the build panel, cross back, till succeeds.
6. Try the build panel outside Fallowfield - placement is refused (only
   the holding allows buildings).
7. Watering-can refills work at all three wells (Fallowfield, Nettleford,
   Manor) - the farm loop is playable away from home.
8. Sleep in Fallowfield's cottage - day advances, rain auto-waters tilled
   cells in every zone (check a brook-zone cell's moisture via the debug
   panel or a save read), autosave writes a v18 file.
9. Save in Nettleford, quit, load - the player returns to Nettleford at
   the saved tile with the same inventory and time.
10. Load an old (pre-18) save - everything lands in Fallowfield, crops
    and fertility intact, buildings still placed.
11. Regression sweep: movement, day advance, crop growth/harvest, energy,
    save/load, pause, and window resize (wide and tall) all behave as
    before on Fallowfield and in at least one other zone.
12. Resize the window - no distortion in either zone, the cull rect
    follows the camera.

## Divergences to record

- Zones are separate maps with `zones.json` exits as the only adjacency
  truth; no master grid exists (deliberate, per ADR-034's "separate
  maps").
- Stage 1's travel minutes are fiction only; no zone size encodes them
  (ADR-034 bans travel-time simulation).
- Edith's Plot has `forage_density` 0 - occupied tenant land is not
  pickable (answers Stage 1 open question 10; owner can retune the
  density).
- Rented strips are arable-only; buildings stay on Fallowfield (answers
  open question 9).
- Raids firing while the player is outside Fallowfield are message-only
  (owner decision requested; see Risk 8).
- `springturn_blessing` keeps day 18 in data; only its location becomes
  zone-qualified (open owner question on the day).

## Status & remaining work

**Status: planned, not started.** This guide is the implementation spec
for Sprint 15 (roadmap row added 2026-08-07; ADR-034 follow-up recorded
in `design/decisions.md`). Before implementation opens: land the
CLAUDE.md amendment (section 2 Region bullet; sections 5/9.5 wording),
then run 15a, then 15b. The Stage 1 open questions not resolved here
(names confirmation, the old church ruin's placement, festival day 18 vs
21, Wat's staging point) remain owner decisions and are listed in Risk
list/Divergences rather than silently decided.
