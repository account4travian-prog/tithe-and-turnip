# Dimetric Asset Rig v2: Phase 0 Schema Contract

**Status:** Implemented as an offline golden-proof lane. It changes no game
data or runtime rendering; real-source art remains pending owner review.

**Decision owner:** the project owner

**Purpose:** Pin the exact data contract for the deterministic asset rig before
any implementation work begins.

## Plain-language model

The game does not create art while the player is running around. An offline
Godot helper creates a *blueprint* for art by reading the same dimetric
projection used by the game. For a farmhouse it writes facts such as:

- this is a 3-by-2 tile footprint;
- these four points bound the South wall;
- these four points bound the East wall;
- this is the roof plane;
- this is the exact door quadrilateral;
- this pixel is the sprite's in-game anchor;
- this is the scale at which the final image must draw.

The compositor then fills those precomputed shapes with art generated or
painted elsewhere. A Pod model supplies texture and visual character; it is
not trusted to choose angles, sizes, or anchors.

“Local rig” means project-owned, deterministic offline tooling, not local AI
generation or local GPU use. It is ordinary Godot/Python CPU work that may run
on the development PC because it needs the checked-out project files. Terra or
the Pod may supply source art; neither one owns geometry.

## Scope and boundaries

- The canonical projection remains `IsoProjection`'s `64x48` dimetric tile.
- Within the v2 lane, only `asset_studio/generate_asset_rigs.gd` may call
  `IsoProjection` to
  resolve rig coordinates. Python consumes the resulting coordinates; it must
  not reproduce projection math.
- The asset rig is presentation-only. It cannot alter collision, gameplay,
  saves, zone transitions, or simulation coordinates.
- The live v1 `asset_generation_catalog.json` remains unchanged through the
  golden proof. The v2 sidecar catalog and generator are migrated or merged
  only after owner approval.
- Existing runtime images remain active until a later owner-approved
  promotion.
- AI images are inputs to recipes, never a replacement for recipe geometry.

## Terms

| Term | Meaning |
|---|---|
| **Rig** | Structured rules describing surfaces, slots, anchor, scale, layer order, and output parts for one asset. |
| **Source scale** | Integer conversion from a runtime screen pixel to a high-resolution source pixel. v2 uses `4`. |
| **Surface** | One flat plane: a South/East wall, interior North/West wall, floor, or roof plane. |
| **Slot** | A named quadrilateral on a surface or cutaway edge where a door, window, trim, or ornament belongs. |
| **Module** | Flat source art mapped into one slot, such as an upright rectangular door panel. |
| **Material** | Tileable or crop-safe art that supplies visual texture for a surface, such as thatch or whitewashed timber. |
| **Anchor** | The source pixel that becomes the `Sprite2D` root origin. It is derived by the rig, never tuned by hand. |
| **Recipe** | The auditable record tying final PNG, source files, resolved geometry, anchor, scale, and validation result together. |

## Catalog v2

The golden proof uses the parallel tracked
`asset_studio/asset_rig_catalog_v2.json`. This preserves the existing v1
catalog and guide pipeline until the new route has owner approval. The catalog
is source data; it contains only semantic layout and source selection. It
contains no final source-pixel polygons.

```json
{
  "version": 2,
  "purpose": "Offline source of truth for deterministic dimetric art rigs.",
  "projection_source": "res://scripts/globals/iso_projection.gd",
  "source_scale": 4,
  "materials": [],
  "modules": [],
  "assets": []
}
```

### Global rules

- `source_scale` is a positive integer and is initially fixed to `4` for all
  v2 assets. A runtime `64x48` tile is therefore a `256x192` source tile.
- A generated final sprite has `draw_scale = 1.0 / source_scale`, initially
  `0.25`. The resolved recipe owns this value.
- A world structure or freestanding prop's final anchor is calculated from the
  resolved `footprint.end` point after crop adjustment. An interior shell's
  anchor is the room origin, and an interior fixture's anchor is its resolved
  perimeter point. No catalog or runtime entry may provide an independent
  `anchor_x`, `anchor_y`, or `draw_scale` for a v2 output part.
- All dimensions are expressed in cells, normalized ratios, or tile-height
  ratios. Source pixels belong only in the resolved manifest.
- A source path, SHA-256 hash, generation backend, model identifier, and
  license record are mandatory at candidate validation time, not in the
  semantic catalog.

### Material definition

```json
{
  "id": "whitewash_timber",
  "kind": "surface_material",
  "repeat_mode": "tile",
  "allowed_surfaces": ["wall", "interior_wall"],
  "default_edge_overlap_source_px": 4
}
```

Rules:

- `kind` is initially only `surface_material`.
- `repeat_mode` is `tile` or `stretch`; use `tile` for wall/floor/roof
  materials unless a visible repeating seam makes that unsuitable.
- `allowed_surfaces` is a semantic safety check. A roof material cannot be
  selected for a wall by accident.
- `default_edge_overlap_source_px` is a small deterministic seam allowance.
  It is not an anchor or scale adjustment.

### Module definition

```json
{
  "id": "door_oak_flat",
  "kind": "door",
  "source_orientation": "flat_front",
  "allowed_surface_faces": ["south", "east", "north", "west"],
  "requires_opaque_frame": true
}
```

Rules:

- `kind` is one of `door`, `window`, `gate`, `ramp`, `trim`, or `ornament`.
- `source_orientation` is initially always `flat_front`. The source is an
  upright rectangular painted panel with no dimetric slant baked in.
- The compositor maps the source into the target slot. It may use the same
  source on several faces.
- `requires_opaque_frame` is true for doors and windows so the module covers
  the wall material behind its frame and prevents a hairline seam.
- Existing `door_south`, `door_east`, `window_south`, and `window_east`
  source prompts are v1 legacy. They are replaced by neutral flat-source
  prompts in Phase 4; no new angled module art is generated.

### Structure asset definition

```json
{
  "id": "farmhouse",
  "kind": "structure",
  "footprint_cells": [3, 2],
  "entrance_side": "south",
  "components": [
    {
      "id": "main_body",
      "kind": "prism",
      "footprint_rect_cells": [0, 0, 3, 2],
      "wall_height_tiles": 1.75,
      "south_material": "whitewash_timber",
      "east_material": "whitewash_timber"
    },
    {
      "id": "main_roof",
      "kind": "gable_roof",
      "body_id": "main_body",
      "ridge_axis": "east_west",
      "rise_tiles": 0.65,
      "material": "gold_thatch"
    }
  ],
  "slots": [
    {
      "id": "door_primary",
      "kind": "door",
      "surface": "main_body.south",
      "module": "door_oak_flat",
      "u_center": 0.46,
      "width_cells": 0.52,
      "bottom_ratio": 0.0,
      "height_ratio": 0.72
    },
    {
      "id": "window_east_1",
      "kind": "window",
      "surface": "main_body.east",
      "module": "window_shutter_flat",
      "u_center": 0.55,
      "width_cells": 0.34,
      "bottom_ratio": 0.36,
      "height_ratio": 0.34
    }
  ]
}
```

Rules:

- `footprint_cells` contains two positive integers.
- Every visual exterior entry exposes only `south` and `east` walls.
- `entrance_side` is `south`, `east`, or `none`.
- A primary door/gate slot must exist exactly once when `entrance_side` is not
  `none`, and it must target that side.
- `prism` is the base structure component. It describes two visible walls,
  not physical elevation in simulation.
- The golden-proof implementation supports `gable_roof`. `hipped_roof` and
  `lean_to_roof` are rejected until each has its own tested polygon resolver.
  A future chapel tower is another small `prism` plus a supported roof
  component, not a special free-painted building class.
- `footprint_rect_cells` must lie fully inside `footprint_cells`.
- `wall_height_tiles` is a positive presentation ratio. `rise_tiles` is
  greater than `0` and below `0.95`; at the locked dimetric ratio a one-tile
  gable rise can project a roof plane to a line. The Phase 1 generator converts
  both values to source pixels using the locked tile height.
- Slot `u_center`, `bottom_ratio`, and `height_ratio` are in `0.0..1.0`.
- Slot width is in cells along the target wall's ground edge.
- A slot may not cross its target surface boundary.
- `ramp` slots target the base edge and are composited after the wall/door;
  their exact lower plane is emitted by Godot.

### Interior asset definition

```json
{
  "id": "player_home_interior",
  "kind": "interior",
  "zone_id": "player_home_interior",
  "room_cells": [10, 7],
  "floor_material": "oak_floorboards",
  "visible_wall_sides": ["north", "west"],
  "cutaway_sides": ["south", "east"],
  "wall_height_tiles": 1.5,
  "fixtures": [
    {
      "id": "door_south",
      "kind": "door",
      "side": "south",
      "index": 5,
      "module": "door_oak_flat",
      "span_cells": 0.85,
      "height_ratio": 0.72
    },
    {
      "id": "window_north",
      "kind": "window",
      "side": "north",
      "index": 6,
      "module": "window_shutter_flat",
      "span_cells": 0.58,
      "height_ratio": 0.34,
      "bottom_ratio": 0.36
    }
  ]
}
```

Rules:

- `zone_id` must name an existing interior zone.
- `room_cells` must exactly match that zone's width and height.
- v2 initially requires `visible_wall_sides: ["north", "west"]` and
  `cutaway_sides: ["south", "east"]` in that order.
- Interior fixtures use the same perimeter convention as
  `FarmRenderer.interior_fixture_grid_position`: north/south indexes run
  across room width; east/west indexes run across room height.
- Fixture `side` and `index` must match the corresponding `zones.json`
  `interior_visual.fixtures` record before runtime promotion.
- The shell output contains only floor and continuous visible walls. It never
  contains a door, window, furniture, storage, or wall object.
- Each fixture is emitted as a separate output PNG with its anchor at the
  fixture perimeter point. A visible-wall fixture is clipped to its wall slot;
  a cutaway-side fixture is drawn by itself at its edge slot.

### Freestanding prop asset definition

```json
{
  "id": "well",
  "kind": "freestanding_prop",
  "footprint_cells": [1, 1],
  "contact_region": {
    "kind": "ellipse",
    "center": [0.5, 0.5],
    "size_cells": [0.58, 0.38]
  },
  "max_height_tiles": 1.5,
  "max_overhang_cells": [0.18, 0.18, 0.24, 0.12]
}
```

Rules:

- v2's well proof uses exactly a `1x1` footprint.
- `contact_region` defines where the opaque base must rest inside the tile. It
  is expressed in logical tile fractions, never source pixels.
- `max_overhang_cells` is `[north, east, south, west]`. It permits a roof
  crank or outline to extend beyond the base while keeping visual mass under
  control.
- `max_height_tiles` caps the presentation height above that expanded ground
  area. Godot resolves both limits into an alpha-envelope rectangle; Python
  rejects any prop pixels outside it.
- The final anchor is still the rig's `footprint.end` corner. The prop may be
  visually centered elsewhere on the diamond; the compositor accounts for
  that while preserving the anchor.

## Resolved rig manifest

`generate_dimetric_guides.gd` produces this file. It is ignored/regenerable
output and is the only geometry input to Python.

```json
{
  "version": 2,
  "asset_id": "farmhouse",
  "catalog_version": 2,
  "projection_source": "res://scripts/globals/iso_projection.gd",
  "source_scale": 4,
  "canvas_size_px": [960, 896],
  "crop_rect_px": [64, 32, 832, 800],
  "anchor_before_crop_px": [512, 704],
  "anchor_after_crop_px": [448, 672],
  "runtime": {
    "draw_scale": 0.25,
    "footprint_cells": [3, 2],
    "anchor_origin": "footprint_end"
  },
  "surfaces": [],
  "slots": [],
  "layers": []
}
```

Rules:

- `surfaces` contain named, clockwise polygons, a material ID, a clip polygon,
  and a permitted overhang envelope.
- `slots` contain named, clockwise target polygons, source module IDs,
  semantic kind, target surface/edge, and deterministic layer position.
- `layers` is the only source of render order. It is generated from component
  and slot semantics; a human never types a z-order for a candidate.
- `crop_rect_px` is derived from resolved bounds plus deterministic padding.
- `anchor_after_crop_px = anchor_before_crop_px - crop_rect_px.position`.
- `runtime.anchor_origin` is `footprint_end` for a world structure/prop,
  `room_origin` for an interior shell, and `fixture_perimeter` for an interior
  fixture.
- `runtime.draw_scale` equals exactly `1.0 / source_scale`.
- The recipe and generated runtime-manifest candidate copy the resolved
  anchor, dimensions, draw scale, and footprint verbatim.

## Recipe and validator contract

For every candidate, the compositor writes:

```text
asset_studio/candidates/<asset-id>/
  <part>.png
  recipe.json
  validation.json
  review.png
```

`recipe.json` embeds the output-part records and source records. Each source
record includes its path and SHA-256 plus a sidecar-metadata hash, generation
backend/model, prompt or hand-paint note, and license record. Candidate
folders are staging only and must not be referenced by
`data/sprites_*.json`.

The validator proves these facts:

- recipe geometry exactly matches the resolved manifest;
- final alpha is isolated and remains inside each declared envelope;
- crop-adjusted anchor and `draw_scale` are recipe-derived;
- all expected surfaces and fixtures exist in correct order;
- exterior entry side agrees with its door/gate slot;
- interior side/index agrees with `zones.json`;
- prop contact region and allowed overhang are respected;
- every source is traceable and licensed.

It does not prove artistic quality. After a validator pass, human review still
decides material quality, visual weight, lighting, and style consistency.

## Golden-proof values pinned in Phase 0

| Candidate | Values that must remain true |
|---|---|
| Player house exterior | `3x2`, South entry, doorway aligned to Fallowfield door `(11, 12)`, sort origin at its footprint end. |
| Player-home interior | `10x7`; visible North/West; cutaway South/East; South door index `5`; North window index `6`; furniture-free shell. |
| Well | `1x1`; contact centered at logical `[0.5, 0.5]`; transparent outside allowed envelope. |

## Phase 0 acceptance checklist

- [x] Existing v1 catalog, `IsoProjection`, `StructureVisual`, `zones.json`,
  and interior fixture mapping were reviewed.
- [x] No new projection formula is defined outside `IsoProjection`.
- [x] No v2 field permits manual final anchor or draw-scale tuning.
- [x] Existing house/interior/well facts are represented as concrete examples.
- [x] Pod generation is isolated to materials/modules; it is not required for
  Phase 0.
- [x] Owner authorized implementation before Phase 1 modified code or catalog
  data.
