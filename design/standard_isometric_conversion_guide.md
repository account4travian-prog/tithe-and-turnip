Exit code: 0
Wall time: 0.2 seconds
Output:
# Standard 2:1 Isometric Conversion Guide

**Status:** proposed only (2026-08-10). This is an execution runbook for a future
owner-approved change from the current `64 x 48` dimetric presentation to
standard `64 x 32` isometric. It does **not** authorize implementation:
ADR-032 and `AGENTS.md` remain authoritative until Phase 0 is complete.

**Audience:** a coding agent such as DeepSeek or Claude. Before editing, read
`AGENTS.md`, `design/decisions.md`, `DEVELOPMENT_STATE.md`, and this
entire guide. This is a presentation migration, not a gameplay rewrite or a
runtime-3D conversion.

## 1. Target and hard boundaries

The target is the common 2:1 isometric ground grid used by many modular asset
packs. A logical simulation cell becomes a 64px-wide, 32px-high screen diamond.
The game retains two visible exterior wall faces and roofs, screen-relative
controls, 8-way facing, cutaway interiors, immediate-mode terrain, and the
existing `WorldVisuals` Y-sort architecture.

| Area | Required outcome |
|---|---|
| Projection | `64 x 32` screen diamond; logical cell remains `32` units |
| Simulation, saves, gameplay data | Unchanged; no save migration |
| Physics, collision, pathing | Unchanged axis-aligned logical space |
| Input | Remains screen-relative, re-derived through the new inverse projection |
| Render architecture | Keep `IsoProjection`, immediate-mode terrain, visual proxies, and Y-sort |
| Art | Replace/re-author old-angle art; do not squish it |
| Runtime 3D | Out of scope; no 2.5D conversion and no Blender dependency at runtime |

Never:

- change `FarmGrid`, feature coordinates, building footprints, room sizes,
  inventory, combat reach, NPC schedules, or save shape;
- put projection math/constants anywhere besides
  `scripts/globals/iso_projection.gd`;
- hand-edit `.tscn`, `.tres`, `.import`, or `project.godot`;
- affine/projectively compress a whole 64x48 building into 64x32. It produces
  warped walls and roofs, not native isometric art.

## 2. Exact geometry

Only `IsoProjection` owns these values.

```text
TILE_W       = 64.0
TILE_H       = 32.0
LOGICAL_CELL = 32.0      # unchanged

grid_to_screen(gx, gy):
  sx = (gx - gy) * 32.0
  sy = (gx + gy) * 16.0

screen_to_grid(sx, sy):
  gx = (sx / 32.0 + sy / 16.0) / 2.0
  gy = (sy / 16.0 - sx / 32.0) / 2.0
```

Cell `(0,0)` has corners: top `(0,0)`, right `(32,16)`, bottom
`(0,32)`, left `(-32,16)`. Increasing logical X still moves down-right;
increasing logical Y still moves down-left.

Keep the current input seam:

```gdscript
static func input_to_world_dir(screen_vec: Vector2) -> Vector2:
    return screen_to_grid(screen_vec) * LOGICAL_CELL
```

Do not replace it with a hand-written 45-degree rotation. The inverse
projection keeps perceived movement screen-relative and keeps one authoritative
coordinate seam.

## 3. Why this is contained

The hard conversion already happened when the project moved to dimetric:

```text
logical gameplay / physics positions
              |
              | IsoProjection only
              v
terrain renderer + WorldVisuals visual proxies
              |
              v
IsoCamera / screen presentation
```

Changing the aspect ratio changes seam output and art compatibility. It does
not change gameplay coordinates. The primary cost is visual re-authoring, not
rebuilding farming, saves, interaction, or collision.

## 4. Phase 0 â€” formal decision and clean baseline

Do not edit runtime code until the owner explicitly authorizes this conversion.
Once approved, one integrator makes a dedicated decision commit:

1. Append an **Accepted** ADR in `design/decisions.md` that supersedes
   ADR-032 only as to the tile aspect ratio, pins standard 64x32 isometric,
   and repeats the presentation-only / no-save-migration / no-elevation rules.
2. Amend the source contract `CLAUDE.md`; then run the project generators so
   `AGENTS.md` and `DEEPSEEK.md` are regenerated together. Never edit the
   generated files directly.
3. Update `DEVELOPMENT_STATE.md` with baseline commit, target, and rollback
   point.
4. Create a dedicated branch, e.g. `codex/standard-isometric-conversion`.
   Preserve old dimetric art and source metadata; do not delete it.
5. Run the full test suite and record the result before any code edit.

If approval is absent, stop. The present contract still pins 64x48 dimetric.

## 5. Phase 1 â€” projection foundation

**Owner:** one integrator. Do not start art replacement yet.

Files:

```text
scripts/globals/iso_projection.gd
tests/suites/test_iso_projection.gd
tests/suites/test_iso_invariants.gd
tests/suites/test_iso_camera.gd
tests/suites/test_iso_terrain.gd
tests/suites/test_iso_structures.gd
tests/suites/test_iso_actors.gd
```

Required implementation:

1. Change `IsoProjection.TILE_H` from `48.0` to `32.0`. Keep
   `TILE_W`, `LOGICAL_CELL`, function names, culling API, and input API
   intact.
2. Recalculate, never guess, all test values that encode projected pixels:
   diamond height 32; half-height 16; the cell-corner values above; and map
   limits/camera positions.
3. Keep `test_iso_invariants.gd` strict: no duplicate projection formulas and
   no direct `Input.` calls under `scripts/`.
4. Update dimetric-specific comments in `iso_projection.gd` and
   `iso_camera.gd` in the same change so the code explains the new math.
5. Do not alter expected logical footprints, collision centres, feature cells,
   or save tests merely to make them pass.

Acceptance:

- projection/inverse round-trip passes for integer and fractional values;
- a 30x20 map has projected bounds x `[-640, 960]`, y `[0, 800]`;
- no logical coordinate, collision shape, feature anchor, or save migration
  changes;
- full suite is green.

## 6. Phase 2 â€” renderer and camera adaptation

**Owner:** one coding agent after Phase 1 is merged.

Primary files:

```text
scripts/world/iso_camera.gd
scripts/world/farm_renderer.gd
scripts/world/feature_renderer.gd
scripts/world/building_renderer.gd
scripts/world/structure_visual.gd
scripts/world/static_prop_visual.gd
scripts/world/actor_visual.gd
scripts/player/player_visual.gd
scripts/npc/npc.gd
scripts/main.gd
```

Rules:

- Existing multipliers using `IsoProjection.TILE_W` and `TILE_H` should
  adapt automatically. Replace only literals/comments that truly encode the
  old 48px tile height; do not touch unrelated 24px UI margins or gameplay
  values.
- Keep every visual proxy as a **direct** child of `WorldVisuals`. Never
  parent visuals under logical actors or collision nodes.
- Keep culling through `IsoProjection.visible_cells()`; do not introduce a
  full-map redraw every frame.
- Keep all collision construction and building placement in logical space.
  Visual anchor and logical footprint must still describe the same `Rect2i`.
- Keep `IsoCamera` following the projected player. 64x32 makes the map
  vertically shorter, so validate zoom and clamp math through tests and live
  captures before selecting a new zoom constant.

Acceptance:

- player, NPC, enemy, forage props, fixed fixtures, buildings, and build ghost
  render at their new projected anchors;
- crossing in front of/behind a structure sorts correctly with no popping;
- screen-up visibly moves up and all eight faced cells remain reachable;
- camera has no NaN, no freeze, and controlled edge behavior on every zone;
- full suite is green.

## 7. Phase 3 â€” art and manifest migration

**Owner:** one art-integration agent after Phase 2. Freeze 64x32 before
purchasing or adapting an asset family.

Audit:

```text
data/terrain_manifest.json
data/sprites_structures.json
data/sprites_actors.json
data/sprites_world_dressing.json
data/sprites_interiors.json
assets/sprites/terrain/
assets/sprites/structures/
assets/sprites/interiors/
asset_studio/make_terrain_tiles.py
asset_studio/make_terrain_transitions.py
asset_studio/build_seasonal_terrain.py
asset_studio/make_terrain_manifest.py
asset_studio/generate_asset_rigs.gd
asset_studio/asset_rig_catalog_v2.json
asset_studio/compose_asset_rig.py
asset_studio/compose_cohesive_structure.py
asset_studio/compose_structure_kit.py
asset_studio/validate_asset_rig.py
```

Required work:

1. **Terrain first.** Existing terrain was authored at 2x 64x48:
   `128x96`. Regenerate/acquire 2x isometric terrain at `128x64`, retaining
   diamond alpha masks, deterministic variants, transitions, wet materials,
   seasons, and the owner-approved West-to-East tilled-row direction. Do not
   resize 128x96 art to 128x64.
2. **Structures.** Preserve `footprint_w`, `footprint_h`, and feature
   coordinates. Replace texture/frame/pixel-anchor data only after native 2:1
   assets pass a live placement review. Current player-house, well, chapel, and
   Terra outputs are legacy dimetric candidates, not automatic new runtime art.
3. **Scaling.** `SpriteManifest.get_scale()` is tile-height-relative. It will
   make art smaller when TILE_H becomes 32. Re-audit every manifest
   `height_tiles`, frame size, and pixel anchor visually; do not multiply all
   heights by 1.5 as a blanket fix.
4. **Actors and props.** Keep top-down sprites that sit cleanly on a 2:1
   diamond; replace only assets whose painted base assumes the old slope.
5. **Interiors.** Keep roomy/furniture-free rooms and North/West visible,
   South/East cutaway walls. Interiors are not exterior diamond assets. Only
   adjust entry anchors if a real live inspection proves it necessary.
6. **Future packs.** Accept an asset only if its ground plane is native 2:1
   isometric, or it is modular/source art that can be rendered to that camera.
   Require transparency, verified license/provenance, known ground-contact
   anchor, and a placement against a 64x32 guide. Reject whole building sprites
   that miss the base guide; do not warp them into conformance.

Only after a real 2:1 representative asset passes should
`asset_studio/visual_canon.md`, `design/asset_generation_status.md`, and
dimetric-named tool comments be changed to make the new pipeline authoritative.
Retain old rig output as provenance until its replacement is tested.

Representative acceptance capture must include: one well, one 4x3 farmhouse,
a tilled plot, and one actor on 64x32 terrain. It must prove clean alpha,
correct ground contact, correct South/East fixtures, coherent roof/walls,
terrain seams, seasonal material change, and readable West-to-East rows. The
owner approves this screenshot before more art families migrate.

## 8. Phase 4 â€” integration and regression

**Owner:** integrator only.

1. Run `git diff --check`.
2. Run import/parse:

   ```powershell
   & '%USERPROFILE%\\Desktop\\GoDot\\Godot_v4.7.1-stable_win64_console.exe' `
     --headless --path . --editor --quit
   ```

3. Run the full suite:

   ```powershell
   & '%USERPROFILE%\\Desktop\\GoDot\\Godot_v4.7.1-stable_win64_console.exe' `
     --headless --path . --script res://tests/run_tests.gd
   ```

4. Manually exercise, at 1280x720 and an expanded aspect ratio: movement,
   tool aim, tilling/watering/planting/harvest, building ghost, house entry and
   exit, well refill, NPC talk/collision, combat, pause, zone transition,
   save/load, and all seasonal terrain.
5. Archive farm and village screenshots as visual acceptance evidence.
6. Update `DEVELOPMENT_STATE.md` with commands, exact test count, known
   fixture shutdown warnings, asset versions, capture paths, and remaining
   risks. Commit code, tests, docs, and promoted art together.

## 9. Test requirements

Do not delete old exact assertions. Recalculate them for 64x32.

| Suite | Must prove |
|---|---|
| `test_iso_projection.gd` | 64x32 dimensions, forward/inverse identities, culling, input round trip |
| `test_iso_camera.gd` | new bounds, anti-freeze behavior, large-map no-void behavior, wide/tall aspects |
| `test_iso_terrain.gd` | 64x32 destination rectangles, 2:1 source frames, row orientation |
| `test_iso_structures.gd` | new visual anchors; unchanged logical footprints/collision |
| `test_iso_actors.gd` | screen-relative movement and all eight facings |
| `test_art_*.gd` | scale/anchor correctness at new TILE_H and fail-soft loading |
| `test_terrain_manifest.gd` | 2:1 frame dimensions, variant/transition completeness, seasonal paths |
| `test_interior_visuals.gd` | cutaway and fixture-overlay rules stay intact |

Add one pure assertion that fails if target constants cease to be 64x32. Pixel
tests are not a replacement for the live capture.

## 10. Failure table

| Symptom | Cause | Correct response |
|---|---|---|
| House looks squashed | Old 64x48 art was resized | Use native 2:1 art; never compensate with arbitrary scale |
| Visual/collision disagree | Sprite anchor changed with logical footprint/collision | Restore logical geometry; correct visual anchor only |
| Tool aims diagonally wrong | Input bypasses `input_to_world_dir` | Restore projection seam; do not patch tool code |
| Camera freezes/shows void | Old zoom/clamp assumptions | Recalculate through inverse projection, update tests, then tune zoom |
| Well floats/off-center | Anchor guessed from transparent padding | Use explicit ground-contact landmark and one-diamond review |
| Roof/wall artifacts | Whole asset is warped or wrongly layered | Reject/re-author source, rather than adding visual hacks |
| Bought asset still fails | Pack is not truly 2:1 or has baked plate/shadow | Reject it from runtime; retain only as reference if useful |

## 11. Copyable agent prompt

```text
Execute design/standard_isometric_conversion_guide.md exactly. Read AGENTS.md,
design/decisions.md, DEVELOPMENT_STATE.md, this guide, and current git status
first. The owner has approved standard 64x32 isometric presentation.

Preserve the 32-unit logical simulation grid, saves, collision, feature
coordinates, input abstraction, WorldVisuals/Y-sort architecture,
immediate-mode terrain, and the no-runtime-3D boundary. First make the
decision/contract checkpoint as its own commit. Then complete Phase 1 before
touching art. Never hand-edit Godot-managed files. Never duplicate projection
math outside scripts/globals/iso_projection.gd. Never warp old 64x48 sprites
into 64x32. Stop for owner review after the Phase 3 representative live
capture. Run every listed test and document exact commands, screenshots, and
remaining risks in DEVELOPMENT_STATE.md.
```

## 12. Rollback

Until the owner approves the Phase 3 representative screenshot, revert the
conversion branch/commits as a unit if necessary. Do not delete existing
dimetric art or provenance during migration. If Phase 1 or 2 affects logical
behavior, stop and revert rather than patching simulation code to compensate
for a presentation mistake.
