The sandbox is read-only, so I can't write the doc into the repo — the full design doc is below, implementation-ready and inline.

# Sprint 16 continuation — art→game implementation architecture

Design status: read-only review of the contract, ADR-032/041, the sprint guide, `SpriteManifest`, all four `sprites_*.json` files, the visual proxies, `player.gd`, `tool_manager.gd`, `farm_grid.gd`, `farm_renderer.gd`, `combat_manager.gd`, and the staged asset tree. No files were modified. Anything I could not verify against the real checkout is explicitly marked **UNVERIFIED** in §7.

Invariants respected throughout: presentation-only; no gameplay/save/collision/coordinate changes; no new autoload; terrain/soil stays immediate-mode and untouched. The only terrain dependency is one sentence: crop sprites and forage props draw *above* the existing primitive terrain, so this work needs nothing from a terrain retexture pass.

---

## 1. One-shot / transient animations

### 1.1 Data shape

Animated entries gain two optional fields:

- `"loop": false` — default is `true`, so every existing walk entry keeps today's behavior.
- `"return_to": "idle"` — the state the actor returns to after the animation finishes; absent means the actor grouping's `default_state`.

Example (shape matches the existing `male1_walk` entry; frame rects below are illustrative until the real sheet is measured):

```json
{
  "id": "male1_attack",
  "kind": "animated",
  "texture": "res://assets/sprites/actors/male1/Sword/Without_shadow/Sword_attack_without_shadow.png",
  "frame_w": 15,
  "frame_h": 25,
  "anchor_x": 7,
  "anchor_y": 25,
  "height_tiles": 1.2,
  "fps": 10.0,
  "loop": false,
  "return_to": "idle",
  "filter": "linear",
  "frames": [
    { "x": 0, "y": 0, "w": 15, "h": 25 }
  ],
  "directions": {
    "0,1":  { "start": 0,  "count": 6, "flip_h": false }
  }
}
```

`directions` stays exactly as it is today — one `"x,y"` key per facing, indexing the flat `frames` list.

### 1.2 The gameplay→presentation trigger

The gameplay side emits a plain, rendering-agnostic event; the visual side never learns about the world from it, and the visual never writes gameplay state.

- `scripts/world/tool_manager.gd` gains:

```gdscript
signal action_started(action_id: String, target: Vector2i)
```

Emit it at the top of `use_tool()` after the `_farm_grid` null guard. The action id is the equipped item id, or `"harvest"` / `"forage"` when bare-handed. This is a commit-time event, so an attempted swing that hits nothing still gets a gesture — a presentation choice, not a gameplay one.

- Attacks and player hurt already have events: `CombatManager.player_attack_started(weapon_id)` and `CombatManager.player_damaged(amount, attacker)`.
- Enemy attacks need one additive signal on `scripts/world/enemy.gd`:

```gdscript
signal attack_started
```

emitted in `_perform_attack()`.

### 1.3 `SpriteManifest` changes

`scripts/globals/sprite_manifest.gd` owns all resource construction. Add:

```gdscript
static func get_static_region(entry: Dictionary) -> Rect2
```

and make `get_animated_frames()` apply the entry's loop flag per animation:

```gdscript
var loop := bool(entry.get("loop", true))
# inside the directions loop, after add_animation():
frames.set_animation_loop(anim_name, loop)
```

`set_animation_loop` is long-stable SpriteFrames API but was not verified against the local 4.7.1 binary in this read-only session — flagged in §7.

### 1.4 Tick-rule crossing, explicitly

1. `_physics_process` (gameplay) runs `ToolManager.use_tool()` / `CombatManager._try_attack()`; those emit a signal. No rendering API is called there.
2. The visual proxy's signal handler runs synchronously but **only records presentation intent** — e.g. sets `_pending_state = "attack"` or `_pending_hurt = true`. It never calls `play()`, never changes `sprite_frames`, never touches `_player`, `PlayerState`, `FarmGrid`, or any autoload state.
3. The visual proxy's `_process` (already the only place visuals mutate) drains the pending request, switches `AnimatedSprite2D.sprite_frames` / `animation`, and calls `play()`.
4. `AnimatedSprite2D.animation_finished` (non-looping) fires while the animation node advances; its handler only sets `_return_pending = true`. The next `_process` returns the actor to `default_state`.

So gameplay mutation stays in `_physics_process`, presentation mutation stays in `_process`, and the only thing crossing the boundary is an event that neither side interprets as gameplay state.

---

## 2. Multi-state actors

### 2.1 Decision: separate entries per state + one `kind: "actor"` grouping entry

**Do not add a state dimension inside one animated entry.** Reasons:

- The purchased packs ship one sheet per action (`Unarmed_Walk`, `Unarmed_Idle`, `Unarmed_Hurt`, `Sword_attack`, Bandits1's `Front - Walking`, `Front - Attacking`, etc.). Separate entries map 1:1 onto real source files.
- `SpriteManifest.get_animated_frames()` stays exactly as-is per state entry, so the already-tested foundation seam is not rewritten.
- States can be loaded lazily: an actor builds only the SpriteFrames for states it actually enters, instead of one monolithic SpriteFrames containing every state × 8 facings.
- Each state can have its own `fps`, `loop`, `filter`, `height_tiles`, and even its own sheet, without schema gymnastics.
- A missing state is a data gap that fails soft to the current animation, not a malformed entry.

The actor grouping entry is a small indirection layer:

```json
{
  "id": "male1",
  "kind": "actor",
  "default_state": "idle",
  "states": {
    "idle":    "male1_idle",
    "walk":    "male1_walk",
    "use_tool": "male1_use_tool",
    "attack":  "male1_attack",
    "hurt":    "male1_hurt"
  }
}
```

`male1_walk` is the only one of those state entries that exists in the current data today; the others resolve to `{}` until their sheets are measured, and the visual falls back exactly as it does now. `kind: "actor"` entries live in the same `sprites` array, so `GameData` needs no new file-loading mechanism — but `SpriteManifest.apply_animated()` must never be called on one.

### 2.2 API

`scripts/globals/sprite_manifest.gd` adds one pure lookup:

```gdscript
static func get_state_sprite_id(actor_entry: Dictionary, state: String) -> String:
    return str(actor_entry.get("states", {}).get(state, ""))
```

`scripts/world/actor_visual.gd` owns the shared actor presentation state machine (all three actor proxies extend it). Additive:

```gdscript
const STATE_IDLE := "idle"
const STATE_WALK := "walk"
const STATE_USE_TOOL := "use_tool"
const STATE_ATTACK := "attack"
const STATE_HURT := "hurt"

var _default_state := STATE_IDLE
var _state_entries: Dictionary = {}   # state name -> parsed entry
var _state_frames: Dictionary = {}    # state name -> SpriteFrames, built lazily
var _current_state := STATE_IDLE
var _pending_state := ""
var _return_pending := false

func configure_states(actor_entry: Dictionary) -> void
func queue_state(state: String) -> void
func _apply_pending_state(facing: Vector2i) -> void
func _switch_to_state(state: String, facing: Vector2i) -> void
func _on_animation_finished() -> void
```

`_switch_to_state()` lazily builds the state's SpriteFrames via the existing `SpriteManifest.get_animated_frames()`, assigns `anim.sprite_frames`, calls `SpriteManifest.set_facing()` with the entry and the facing **captured when the one-shot started**, sets the loop flag, and plays. While a one-shot is playing, `_process` does not reface it, so an attack/tool swing keeps the direction it started with; after `animation_finished`, the next `_process` returns to `_default_state` and re-evaluates movement.

Subclass responsibilities:

- `PlayerVisual` (already owns `_player`): `configure_states(SpriteManifest.get_entry("male1"))`; in `_process`, choose walk/idle from `_player.velocity`, and map signal events (`ToolManager.action_started`, `CombatManager.player_attack_started`, `CombatManager.player_damaged`) to `queue_state(...)`.
- `NpcVisual` / `EnemyVisual`: same, using `ActorVisual.facing_from_velocity()` and filtering `CombatManager.player_hit_enemy` by `enemy == _npc` / `enemy == _enemy` for hurt; `EnemyVisual` also connects `_enemy.attack_started`.
- A legacy fallback: if `configure_states()` receives a non-`actor` entry (today's walk-only `male1_walk`), treat it as both `idle` and `walk`. That keeps the current shipped behavior untouched until the grouping entry lands.

---

## 3. Crop growth stages

### 3.1 Data shape

The stage→sprite mapping lives in `data/sprites_world_dressing.json` (WS-A already owns `FarmPlantsPixelStyle` there). It must **not** go in `crops.json`: growth days are gameplay data; sprite ids are presentation data.

Two entry kinds:

A `kind: "crop_stage_set"` entry that maps a crop id to ordered thresholds:

```json
{
  "id": "crop_stage_turnip",
  "kind": "crop_stage_set",
  "crop_id": "turnip",
  "stages": [
    { "sprite_id": "crop_turnip_stage_1", "min_progress": 0.0 },
    { "sprite_id": "crop_turnip_stage_2", "min_progress": 0.5 },
    { "sprite_id": "crop_turnip_stage_3", "min_progress": 1.0 }
  ]
}
```

And ordinary static sprite entries for the stages themselves:

```json
{
  "id": "crop_turnip_stage_2",
  "kind": "static",
  "texture": "res://assets/sprites/world_dressing/farm_plants/generated_atlas_nearest_0.png",
  "frames": [ { "x": 210, "y": 6, "w": 96, "h": 128 } ],
  "frame_w": 96,
  "frame_h": 128,
  "anchor_x": 48,
  "anchor_y": 128,
  "height_tiles": 0.5,
  "filter": "nearest"
}
```

`min_progress` is a float, so no `INT_KEYS` addition is needed. `frames` is already int-cast by `SPRITE_FRAME_INT_KEYS`.

### 3.2 GameData and SpriteManifest

`scripts/autoloads/game_data.gd` builds a crop-stage index after the four sprite files merge:

```gdscript
var crop_stage_sets: Dictionary = {}

# in load_all(), after sprites.merge(...) and before _cast_nested_ints():
crop_stage_sets = {}
for sprite_id: Variant in sprites:
    var entry := sprites[sprite_id] as Dictionary
    if str(entry.get("kind", "")) == "crop_stage_set":
        crop_stage_sets[str(entry.get("crop_id", ""))] = entry

func get_crop_stage_set(crop_id: String) -> Dictionary:
    return crop_stage_sets.get(crop_id, {})
```

`scripts/globals/sprite_manifest.gd` owns the stage selection math:

```gdscript
static func get_stage_sprite_id(stage_set: Dictionary, progress: float) -> String:
    var selected := ""
    for stage: Variant in stage_set.get("stages", []):
        var s := stage as Dictionary
        if progress >= float(s.get("min_progress", 0.0)):
            selected = str(s.get("sprite_id", ""))
    return selected
```

### 3.3 `FarmRenderer` drawing

`scripts/world/farm_renderer.gd` owns the pick-and-draw path, replacing only the crop-dot branch of `_draw()`:

```gdscript
func _crop_sprite_entry(crop_id: String, progress: float) -> Dictionary:
    var stage_set := _game_data.get_crop_stage_set(crop_id)
    if stage_set.is_empty():
        return {}
    var sprite_id := SpriteManifest.get_stage_sprite_id(stage_set, progress)
    if sprite_id.is_empty():
        return {}
    return _game_data.get_sprite(sprite_id)
```

When the entry is non-empty and its texture loads, draw it with the same anchor/scale formula the rest of the foundation uses:

```gdscript
var origin := IsoProjection.cell_centre_screen(pos)   # matches the old dot anchor
var region := SpriteManifest.get_static_region(entry)
var scale := SpriteManifest.get_scale(entry)
var draw_rect := Rect2(origin - SpriteManifest.get_anchor(entry) * scale,
                       region.size * scale)
draw_texture_rect_region(texture, draw_rect, region)
```

Missing entry, missing texture, or empty stage set falls back to the existing primitive dot — the same fail-soft contract every other visual already follows. No `StaticPropVisual` nodes are needed: crops are terrain-adjacent, `_draw()` already culls to the visible rect, and `advance_day()` already emits `tile_changed` for every grown cell, which triggers the renderer's redraw. Crops drawn this way do not participate in y-sorting; that matches the current primitive dots and is a deliberate scope boundary.

This requires one `SpriteManifest` addition used by the formula:

```gdscript
static func get_static_region(entry: Dictionary) -> Rect2:
    var rects := get_frame_rects(entry)
    if not rects.is_empty():
        return rects[0]
    return Rect2(0.0, 0.0,
        float(entry.get("frame_w", 0.0)),
        float(entry.get("frame_h", 0.0)))
```

and `apply_static()` must set `sprite.region_rect = get_static_region(entry)` instead of always using the texture origin — otherwise atlas-backed static entries would draw the wrong region.

---

## 4. Sprite-sheet packing

**Recommendation: yes, pack the normalized AI-generated single-asset PNGs into 2048×2048 atlases, offline, per filter class. Do not repack the purchased pack sheets.**

Rationale:

- The generated assets are 1024×1024 or 1254×1254 squares with a small subject and mostly padding — loading them individually wastes VRAM and draw calls. I verified the `vertical_slice_test` PNGs are 1024/1254 RGB images with no alpha channel.
- The purchased packs already arrive as sheets (Male1, Bandits1, etc.) or small tiles; only manifest-referenced entries load, so repacking them buys little and risks disturbing verified frame layouts.
- A 2048×2048 RGBA atlas is 16 MiB on the GPU; even ten atlases are ~160 MiB on the GTX 1070's 8 GB. No VRAM concern.
- Godot imports one PNG per atlas, so this stays fully headless: no editor session, no hand-edited `.import` files, no project-wide import overrides. The existing per-entry `filter` field continues to apply at the node.
- `SpriteManifest` already supports atlas-backed animation via `frames` + `AtlasTexture`; with §3's `get_static_region`, static entries get the same support.

Tooling: a new Pillow script `asset_studio/normalize_and_pack.py`. No runtime GDScript, no third-party packer.

Packing algorithm (stdlib + Pillow):

1. Group normalized frames by `filter` (`nearest` vs `linear`) so no atlas mixes sampling styles.
2. Sort by height descending, then width descending.
3. Shelf-pack into 2048×2048 canvases: place each frame on the current shelf if it fits; otherwise start a new shelf; if the shelf doesn't fit the atlas, start a new atlas.
4. Reserve 2 px of bleed around each frame. The bleed border is drawn outside the recorded frame rect: paste the content at `(x + 2, y + 2)` and extend edge pixels into the 2-px border, so linear filtering at region edges samples duplicated edge color rather than another asset.
5. Record the **content** rect (excluding bleed) in the entry's `frames`.
6. Write `assets/sprites/<category>/generated_atlas_<filter>_<n>.png`.
7. Emit manifest entries pointing at the atlas path with the recorded frame rect, original content `frame_w`/`frame_h`, content-relative anchor, and `height_tiles`.

Because the recorded rect excludes bleed, `height_tiles` and anchor math stay identical to the un-packed case.

---

## 5. Offline normalisation step

New Pillow script in `asset_studio/`: `normalize_and_pack.py` (or `normalize.py` + `pack_atlas.py` if you prefer two stages — one script is fine for this batch).

CLI shape:

```text
python asset_studio/normalize_and_pack.py
    --input asset_studio/vertical_slice_test
    --category world_dressing          # routes to data/sprites_world_dressing.json
    --filter nearest                   # nearest | linear
    --height 128                       # normalized frame height, default 128
    --height-tiles 0.5                 # desired on-screen height as tile fraction
    --atlas-size 2048
    --write-data                       # default: dry-run JSON to asset_studio/out/
```

Algorithm per source PNG:

1. Open with Pillow. If the image has no alpha channel (verified true for the current generated batch), run the existing `strip_background` keying logic first. **Refuse the asset if the corners are not uniform** — never invent alpha from a non-flat background.
2. Build an alpha mask with `alpha > threshold` (default 0, configurable `--alpha-threshold 8` to drop noise).
3. `bbox = alpha.getbbox()`; abort with a named error if fully transparent.
4. Crop to the bbox. This is the critical fix for the `male1_walk` history: the subject, not the full 1024/1254 canvas, defines the frame.
5. Uniformly scale the crop to `target_height` (`--height`, default 128; use 256 for structures). Width scales by the same factor. Use `LANCZOS` for `linear` assets and `NEAREST` for `nearest` assets.
6. Compute the anchor in the normalized frame: default `bottom_center` → `anchor_x = round(frame_w / 2)`, `anchor_y = frame_h`. Optional `--anchor-mode center|top_left` for item/UI variants.
7. Emit the manifest entry:
   - `kind: "static"`
   - `texture` (atlas path after packing)
   - `frames`: one content rect
   - `frame_w` / `frame_h`: normalized content size
   - `anchor_x` / `anchor_y`: normalized content-relative
   - `height_tiles`: `desired_on_screen_height / IsoProjection.TILE_H` (48)
   - `filter`

Worked example: a 1024×1024 source with an opaque bbox of 800×600, normalized to height 128 → frame 171×128, `anchor (86, 128)`, and with `height_tiles: 0.5` the sprite renders 24 px tall on screen.

`--write-data` merges the generated entries into the category's `data/sprites_*.json` (bumping its version to 2) and writes the atlas PNGs under `assets/sprites/`. Dry-run mode writes everything to `asset_studio/out/` for review instead. The script never overwrites the 1024/1254 originals.

---

## 6. Sequenced work plan

1. **Manifest/GameData seam (blocking).** Add `get_static_region`, `loop` handling, `get_state_sprite_id`, `get_stage_sprite_id` to `SpriteManifest`; add the `crop_stage_sets` index + accessor to `GameData`; extend `test_art_foundation.gd`. Everything after this depends on these signatures.
2. **Offline pipeline (parallel-safe after step 1).** Implement `asset_studio/normalize_and_pack.py`; run it on the generated batch; dry-run review, then commit atlases + manifest entries. This is independent of actor/crop GDScript work.
3. **Event seams.** Add `ToolManager.action_started` and `Enemy.attack_started`; add tests for signal payloads without a scene tree. No visual changes yet.
4. **Actor state machine.** Extend `ActorVisual`, wire `PlayerVisual` / `NpcVisual` / `EnemyVisual`, add the `male1` actor grouping entry, and extend `test_art_actors.gd`. Missing state entries fall back to today's walk-only behavior.
5. **Crop stages.** Add `crop_stage_set` entries + stage sprites for the Spring crops, implement the `FarmRenderer` draw path, extend `test_art_dressing.gd`.
6. **Integration and regression.** `--headless --path . --import`, full suite green, then the Phase 2 test scene: one atlas-packed crop, one nearest asset, one linear asset, a player tool swing returning to idle, and an 8-direction walk regression.

Dependencies: 1 → 3/4/5; 1 → 2; 4 and 5 are independent once 1 lands; 6 is last.

---

## 7. Risks and UNVERIFIED items

- **UNVERIFIED — `SpriteFrames.set_animation_loop()` and `AnimatedSprite2D.animation_finished` against the local 4.7.1 binary.** Both are long-stable 4.x API, but this read-only session could not run the engine. Fallback if either misbehaves: `ActorVisual` implements one-shot completion with a presentation-only frame counter in `_process`.
- **UNVERIFIED — state-sheet frame geometry for `male1_idle`, `male1_hurt`, `male1_attack`, NPC1, and Bandits1.** The staged tree confirms `Unarmed_Idle_without_shadow.png`, `Unarmed_Hurt_without_shadow.png`, `Sword_attack_without_shadow.png`, and Bandits1's per-direction `Idle`/`Attacking`/`Hurt`/`Walking` sheets exist, but their exact frame rects were not measured here. The JSON examples are templates; do not commit unmeasured rects as if they were facts.
- **Generated batch is RGB, not RGBA.** The normalization script must key the background before trimming, and must refuse non-uniform-corner sources. This was verified by parsing the PNG headers of 26 `vertical_slice_test` images, not guessed.
- **Atlas filter/mipmap bleed.** Godot's default import settings may generate mipmaps, and atlas regions can bleed under Linear filtering. Mitigation: per-filter atlases + 2 px edge-extended bleed, then eyeball in the Phase 2 test scene. If bleed persists, the follow-up is a per-texture import preset — outside this pass's headless-only rule.
- **`GameData` id collisions.** The four sprite files merge first-seen. The crop-stage index must be built after that merge and keyed by `crop_id`; a duplicate `crop_id` should be treated as a data bug, not silently overwritten.
- **Crop sprites drawn in `_draw()` do not y-sort against actors.** That matches the current primitive dots and keeps culling free, but a tall crop behind the player will not occlude. If playtesting says it must, that is a follow-up visual-proxy pass, not this one.
- **`player.gd` stays frozen.** No signal is added there; tool events come from `ToolManager` and combat events from existing `CombatManager` signals.
- **Off-tree tests can't reach `/root` autoloads.** The actor state machine therefore needs public seams (`queue_state`, `_build_sprite_child`-style entry injection) so the headless suites exercise it with hand-built dictionaries, matching the project's established test pattern.