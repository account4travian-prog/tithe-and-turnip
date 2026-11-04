# Proposed Dimetric Asset Rig v2

Status: Phases 0-5 are implemented for the six-source golden proof. The
real-source candidates passed validation, and the owner explicitly authorized
their runtime promotion on 2026-08-09. Further asset families still require
their own review and promotion.

Date: 2026-08-09

## Current implementation checkpoint

- Godot resolves the farmhouse, roomy player-home interior, and well from the
  v2 catalog through `IsoProjection`.
- Python projectively maps flat materials and fixture modules onto those
  resolved planes. It does not calculate dimetric coordinates.
- Freestanding props use an explicit source contact landmark rather than a
  trimmed-image or bottom-edge guess.
- Recipes retain source hashes, generation/license metadata, the independent
  resolved-manifest hash, and the exact resolved-asset hash.
- The validator reloads the independent manifest and fails on altered
  geometry, scale, alpha bounds, source data, or provenance.
- Eight offline pipeline tests include deliberately corrupted candidates and
  simulated real source files. The proof now also has six real generated
  sources with commercial-use metadata and promoted runtime assets; the tests
  remain offline and do not require a model or pod.

The remaining Phase 4 work is artistic: produce six constrained sources,
compose them, and ask the owner to judge the resulting review sheets. See
`design/dimetric_asset_rig_operator_guide.md`.

## Decision

Keep the game's existing `64x48` dimetric projection. Do not switch to
top-down or conventional `2:1` isometric, and do not attempt to repair a
misaligned finished building with a whole-image warp.

Finish the asset pipeline by separating two authorities:

- Godot and `IsoProjection` own geometry, footprint, scale, anchor, face
  orientation, fixture slots, and layer order.
- Generated or hand-painted raster sources own color, texture, material
  detail, and ornamentation only.

Every new production building must be assembled from deterministic surface
polygons. A model may generate flat wall materials, roof materials, doors,
windows, and small ornaments, but it may not provide the final building's
perspective. Whole pre-rendered buildings become concept/reference art unless
they were produced by this rig.

This is an extension of the existing guide/compositor work, not a replacement
for it. `generate_dimetric_guides.gd` already derives guide geometry from
`IsoProjection`, and `compose_structure.py` already perspective-maps fixture
modules. The missing piece is that the current compositor accepts an
unconstrained, AI-painted shell unchanged. That shell can have the wrong wall
angles before any correctly warped door or window is added.

## Why this is the recommended route

The recent failures are three independent problems:

1. The exterior cottage shell does not conform to the projected `3x2`
   footprint, especially on its South face.
2. The interior door and window are already-perspectived pictures positioned
   at wall points; they are not flat modules projected into exact wall slots.
3. The well's visible base, alpha bounds, scale, and sprite anchor were tuned
   manually rather than emitted from one tile rig.

More prompting cannot guarantee any of those geometric properties. A
deterministic compositor can.

Switching projection would discard working terrain, movement mapping, camera,
depth sorting, collision alignment, interaction targeting, and approved art.
A conventional isometric or top-down camera would make stock-art sourcing
easier, but it would not solve the underlying mistake of allowing generated
pixels to define gameplay geometry.

Warping a completed cottage is also not a durable solution. Its roof, walls,
door, windows, and depth cues occupy different planes. One transform would
distort all of them as if they occupied the same plane. Projective warping is
appropriate only for a flat source mapped to one known surface.

## Production architecture

### 1. One geometry source of truth

The golden proof uses the parallel tracked
`asset_studio/asset_rig_catalog_v2.json`, preserving the existing v1 catalog
and guide lane while the rig is proven. After owner approval, v2 may replace
or be folded into the older catalog in a separately reviewed migration. It
describes each structure as visual components and surface slots.

The catalog should express dimensions in cells or tile-height ratios, not
arbitrary source-image pixels. At minimum a structure needs:

- footprint width and height in cells;
- a presentation-only wall height in multiples of `IsoProjection.TILE_H`;
- roof family, ridge axis, and roof rise;
- entrance side (`south`, `east`, or `none`);
- visual components for compound structures such as a chapel tower;
- fixture slots with surface, normalized horizontal position, width in cells,
  bottom offset, and height ratio;
- material IDs for each wall and roof surface;
- optional trim and ornament sockets.

Suggested conceptual shape:

```json
{
  "id": "farmhouse",
  "guide_kind": "rigged_structure",
  "footprint_cells": [3, 2],
  "source_scale": 4,
  "components": [
    {
      "id": "body",
      "kind": "prism",
      "footprint_rect": [0, 0, 3, 2],
      "wall_height_tiles": 1.75,
      "south_material": "whitewash_timber",
      "east_material": "whitewash_timber"
    },
    {
      "id": "roof",
      "kind": "gable_roof",
      "parent": "body",
      "ridge_axis": "east_west",
      "rise_tiles": 1.0,
      "material": "gold_thatch"
    }
  ],
  "slots": [
    {
      "id": "door_primary",
      "surface": "body.south",
      "module": "door_oak_flat",
      "u": 0.5,
      "width_cells": 0.65,
      "bottom_ratio": 0.0,
      "height_ratio": 0.72
    }
  ]
}
```

The exact field names may change during implementation, but the units and
ownership must not.

### 2. Godot emits a resolved rig manifest

Extend `asset_studio/generate_dimetric_guides.gd` so it emits a resolved
manifest containing all source-pixel geometry needed by downstream tools:

- every wall, roof, floor, and compound-component polygon;
- deterministic paint/layer order;
- clip masks and permitted art-overhang envelopes;
- every fixture slot polygon;
- trim paths and ornament sockets;
- footprint guide corners;
- the source-pixel anchor corresponding to `footprint.end`, the same
  South-East-most sort origin used by `StructureVisual`;
- an exact runtime `draw_scale`, normally `1.0 / source_scale`;
- final crop bounds and padding.

The generator must call `IsoProjection`; it must not copy its projection
formula. Python receives already-resolved polygons and must not independently
calculate dimetric coordinates.

Use an integer source scale such as `4`. A runtime `64x48` tile then becomes a
`256x192` source tile, leaving enough resolution for painterly texture while
making runtime scale and anchor derivable instead of hand-tuned. Do not assume
that every generated source is `1024x1024`; normalize source materials and
modules separately from final rig geometry.

### 3. The compositor builds the shell

Change `asset_studio/compose_structure.py` from “load an AI shell and add
fixtures” to “construct the final shell from resolved surfaces.”

For each surface, it should:

1. Load a flat material source.
2. Crop or tile it to cover the surface.
3. Project it into the exact target polygon.
4. Clip alpha to that polygon plus only its declared overhang.
5. Composite surfaces in manifest-defined order.
6. Add edge trims, beams, eaves, and fixtures through their own declared
   paths, polygons, or sockets.

Flat, front-facing door and window sources should be transformed with the
existing projective mapping. Do not generate separate already-angled fixture
PNGs and then position them untransformed. The same clean source can be mapped
to South, East, North, or West slots; face-specific variants are permitted
only for intentional lighting or design differences, not to repair geometry.

The output recipe must record source paths and hashes, resolved polygons,
layer order, crop adjustment, final anchor, runtime scale, footprint, and
catalog version. The final PNG and recipe are inseparable production
artifacts.

### 4. Roofs and compound buildings

A roof is one or more exact polygons, not part of an AI-painted building.
The golden proof supports only a gabled roof. Hipped and shed/lean-to roofs
must be rejected until each receives its own resolver and failure tests.

Map flat roof material to each roof plane, then add deterministic ridge and
eave trims. More complex silhouettes are compound rigs. For example, a chapel
is a main prism and roof plus a smaller tower prism and tower roof. These are
presentation components only; they do not add simulation elevation or change
collision.

Do not attempt a universal architecture language in the first pass. Add a new
component type only when an approved asset cannot be expressed with the three
roof families and nested prisms.

### 5. Interiors use the same surface contract

The current interior shell is visually acceptable and should remain the
initial style/material reference. The v2 interior rig must represent:

- one projected floor polygon for the intentionally roomy `10x7` room;
- visible North and West wall polygons;
- invisible East and South wall surfaces that can still own standalone door,
  window, or wall-object slots;
- fixture slots in normalized wall coordinates;
- collision/transition references for validation only, never as raster
  geometry inputs.

Doors, windows, and future wall decorations are flat source modules projected
onto slot polygons. A window on the North wall is clipped and composited over
continuous North-wall material. A South-side door is drawn at the South edge
without causing the otherwise invisible South wall to appear. No fixture is
baked into the base shell.

The rig must preserve the owner rulings already recorded in
`asset_studio/visual_canon.md`: North/West visible, East/South cut away,
interiors larger than exteriors, and base rooms free of furniture and wall
objects.

### 6. Freestanding props use a one-tile rig

Props such as the well do not need wall surfaces, but they still need geometry
metadata. A one-tile prop rig must emit:

- the exact tile diamond;
- tile center and `footprint.end` anchor;
- a permitted base/contact region around the tile center;
- a maximum alpha envelope;
- final crop, anchor, and draw scale.

The prop image may be generated in one piece. It passes only if its contact
area is centered in the permitted region, its alpha is clean, and its output
anchor/scale comes from the rig recipe. This solves the well without forcing
it into the building surface system.

## Production lanes

| Asset input | Production use |
|---|---|
| Flat/tileable wall or roof material | Warp and clip to an exact rig surface |
| Front-facing door/window panel | Warp into an exact fixture slot |
| Beam, eave, ridge, or narrow trim | Map along an exact path or strip |
| Small chimney/ornament | Place at an exact socket with a declared anchor |
| One-piece prop | Validate against a one-tile contact and alpha rig |
| Whole generated building | Concept/reference only; never a new final runtime asset |

Existing approved whole buildings do not have to be removed immediately.
They are legacy assets. Replace them only when touched or when they visibly
fail the grid. New and corrected structures must use v2 recipes.

## Deterministic validator

Add an offline validator that fails closed and writes a machine-readable
report. It should validate the recipe and the output, not try to infer a
building's perspective from arbitrary painted pixels.

Hard failures:

- catalog or resolved-manifest schema mismatch;
- copied/contradictory projection metadata;
- missing expected surface, fixture, material, or layer;
- output not RGBA;
- nontransparent image corners or a connected white/gray background;
- opaque pixels outside the declared surface/overhang envelope;
- fixture alpha outside its target polygon and permitted frame overlap;
- anchor different from the resolved `footprint.end` pixel after cropping;
- draw scale different from `1/source_scale`;
- footprint mismatch between catalog, recipe, and candidate runtime entry;
- door face different from `entrance_side`;
- interior fixture side/index inconsistent with zone dimensions;
- final dimensions or texture path inconsistent with the proposed manifest
  entry;
- missing source hashes, generation metadata, or license record.

Geometry generated from the manifest should be exact. Permit at most one
source pixel of rasterization tolerance at a polygon edge; do not use a broad
“looks close” tolerance. Decorative eaves and outlines receive a separately
declared overhang envelope rather than weakening the wall/base rule.

Warnings requiring human review:

- poor material tiling or visible transform stretching;
- lighting mismatch between South and East faces;
- fixture too visually busy at runtime scale;
- roof or trim style inconsistent with canonical assets;
- prop visual mass appears off-center despite a valid contact anchor.

The validator must not claim artistic approval. It proves construction and
packaging only.

## Review sheet

Generate one deliberately compact review PNG per candidate with three columns:

1. final RGBA on a checkerboard at source-crop size;
2. the same image under exact rig/slot/contact overlays;
3. actual runtime scale with the complete footprint and sort anchor. Props
   also show their contact region and maximum alpha envelope.

Hashes, source IDs, validator errors, and provenance remain machine-readable
in `recipe.json` and `validation.json`; duplicating them as tiny text on the
visual sheet made the owner-facing evidence harder to read.

The human approval question should be narrow: “Do the style, proportions,
fixture scale, and visual weight look correct on this already-conforming
rig?” Perspective and anchoring should no longer be subjective review items.

## Golden proof before batch production

Do not migrate the entire library first. Prove the pipeline with exactly this
set:

1. Player-house exterior, `3x2`, with South entrance and both visible faces.
2. Player-home interior using the accepted roomy shell convention, with one
   North window and one South door as separately projected modules.
3. One-tile well with clean alpha and a centered contact region.

Keep current runtime manifest entries active while producing candidates under
`asset_studio/candidates/`. Only after owner approval should a later task copy
the approved PNGs into `assets/sprites/` and switch manifests.

Golden-proof acceptance criteria:

- all footprint and wall-base control points match the resolved guide within
  one source pixel;
- South and East wall edges are generated from the same projection polygons
  as the tile grid;
- the house sprite anchor is exactly the `3x2` footprint's `footprint.end`
  point and scale is recipe-derived;
- the South door slot agrees with the exterior collision/transition side;
- interior fixtures are contained in their wall/edge slots, sit on the
  correct side, and remain visually plausible at `1280x720`;
- the window leaves continuous wall material around its full frame;
- the well is centered over its tile, contains no connected matte/background,
  and uses recipe-derived scale/anchor;
- the candidate passes the validator and focused tests;
- the owner approves an in-game screenshot at normal zoom.

Do not batch chapel, alehouse, coop, or buildable structures until all three
golden-proof assets pass in the same run.

## Phased implementation handoff

Each phase is intentionally small enough for a cheaper coding model. Give the
model only one phase at a time, require it to inspect the listed files first,
and do not let it proceed after a failing check.

### Phase 0 - Freeze the contract (complete)

Files to inspect:

- `AGENTS.md`
- `asset_studio/visual_canon.md`
- `asset_studio/generation_pipeline.md`
- `asset_studio/asset_generation_catalog.json`
- `asset_studio/generate_dimetric_guides.gd`
- `asset_studio/compose_structure.py`
- `scripts/globals/iso_projection.gd`
- `scripts/world/structure_visual.gd`

Deliverable: propose the exact v2 catalog and resolved-manifest schemas in a
short design note, including one farmhouse, one interior, and one prop
example. No code. Confirm that Python consumes resolved polygons and never
reimplements projection math.

Review gate: reject the schema if scale or anchors can still be manually
adjusted independently of the rig.

### Phase 1 - Resolve all geometry in Godot (complete for golden proof)

Primary files:

- `asset_studio/asset_generation_catalog.json`
- `asset_studio/generate_dimetric_guides.gd`

Deliverables:

- versioned v2 catalog validation;
- resolved surface polygons, fixture slots, layer order, envelopes, crop,
  anchor, and scale;
- structure, interior, and one-tile prop rig output;
- deterministic debug guide images;
- focused headless tests for legal/illegal catalog cases and exact anchor
  derivation.

No compositor or runtime files in this phase.

### Phase 2 - Build surfaces deterministically (complete for golden proof)

Primary files:

- `asset_studio/compose_structure.py`
- a small source-material/module fixture folder for tests;
- offline compositor tests.

Deliverables:

- polygon-clipped surface material mapping;
- deterministic roof/wall/trim order;
- flat fixture-module projection;
- crop-adjusted anchor and recipe output;
- compound-prism support sufficient for a simple chapel, but no generalized
  architecture framework;
- identical output hash when run twice with identical sources.

No AI generation and no runtime manifest changes in this phase. Use synthetic
colored/checker sources so geometry defects are obvious.

### Phase 3 - Validate and make review evidence (complete for golden proof)

New offline tools may be introduced under `asset_studio/` for validation and
review-sheet generation.

Deliverables:

- fail-closed JSON validation report;
- checkerboard/grid/guide review sheet;
- deliberate bad fixtures proving every hard gate fails;
- a command that validates a full candidate folder in one run.

Do not use a vision model for hard geometry gates. The local vision critic may
add warnings after deterministic validation passes.

### Phase 4 - Author the golden proof (complete)

Use synthetic materials first. Once the three rigs pass, replace synthetic
inputs with approved/generated material and module sources.

Deliverables:

- player-house exterior candidate and recipe;
- player-home interior candidate and fixture recipes;
- well candidate and recipe;
- validation reports and review sheets;
- real-source sidecar provenance and review sheets retained beside the
  candidates.

This is the first phase where RunPod may be useful, and only for a small fixed
list of material/module sources.

### Phase 5 - Human review and runtime promotion (complete for golden proof)

This phase begins only after the owner accepts the review sheets. The owner
explicitly approved this proof's promotion on 2026-08-09.

Deliverables:

- copy approved final PNGs to runtime asset paths;
- bake aligned 4x proofs to alpha-safe runtime resolution, with integer
  anchors and `draw_scale = 1.0`;
- generate candidate sprite-manifest entries from recipes rather than typing
  anchor, scale, dimensions, or footprint by hand;
- review the manifest diff before applying it;
- run existing focused structure/interior suites plus new recipe consistency
  tests;
- capture an in-game screenshot at `1280x720` for final owner approval.

Refinement note (2026-08-09): the first live proof showed that geometrically
valid high-resolution surfaces could still produce rough shared edges when
Godot reduced them at draw time. The compositor now samples opaque materials
inside transform boundaries, finishes exposed gable seams from the source
material palette, aligns crops/anchors to `source_scale`, and emits a separate
premultiplied-alpha runtime PNG. Validator hashes and checks both resolutions.

Promotion should be explicit. The compositor must not silently write to
`assets/` or `data/`.

### Phase 6 - Migrate only as needed

After the golden proof is approved, migrate visible failures first, then new
assets. Suggested order:

1. alehouse exterior;
2. buildable structures with player-facing entrances;
3. chapel only if its currently approved art later fails alignment;
4. remaining props and fixtures.

Ground textures, seasonal terrain, crops, actors, and already-correct UI art
are outside this migration.

## Commands the implementation should eventually support

Names are illustrative; the Phase 0 schema task may refine them.

```powershell
& '%USERPROFILE%\Desktop\GoDot\Godot_v4.7.1-stable_win64_console.exe' `
  --headless --path . --script res://asset_studio/generate_dimetric_guides.gd

python asset_studio/compose_structure.py `
  --asset farmhouse `
  --materials asset_studio/sources/materials `
  --modules asset_studio/sources/modules `
  --out asset_studio/candidates/farmhouse

python asset_studio/validate_asset_rig.py `
  asset_studio/candidates/farmhouse

python asset_studio/make_asset_review.py `
  asset_studio/candidates/farmhouse
```

A final one-command wrapper is desirable only after the individual commands
and failure modes are proven. Do not hide early pipeline failures behind a
large orchestration script.

## RunPod and model-usage guidance

RunPod is an appearance accelerator, not part of the geometry solution.

- Complete Phases 0-3 locally without generation calls.
- Do not spend Terra/ChatGPT image usage iterating on perspective.
- Before any pod start, inspect the existing pod and network volume read-only.
- Start or resume compute only with explicit owner approval and a fixed time
  and cost limit.
- Generate a small batch of flat materials and front-facing modules with fixed
  prompts, retained metadata, and commercial-use records.
- Use the already-tested FLUX.1-schnell game-assets lane or the project style
  references for appearance. Do not ask it for final building geometry.
- Stop after the golden-proof source list; do not generate the full catalog.

The local pipeline remains suitable for deterministic retries. RunPod is
worth using when it materially shortens material/module generation or style
conditioning. Neither one should be trusted to certify geometry.

## Instructions for cheaper implementation models

Use this preamble for every phase:

> Read `AGENTS.md` first. This is a dirty worktree; preserve all unrelated
> changes. Implement only the named phase from
> `design/dimetric_asset_rig_implementation_plan.md`. Do not alter gameplay,
> projection, collision, saves, terrain, or existing runtime manifests unless
> the phase explicitly authorizes promotion. The only geometry authority is
> `scripts/globals/iso_projection.gd`; Godot may call it and emit resolved
> polygons, while Python may only consume those polygons. Run the phase's
> focused checks and stop on failure. Report exact files changed, commands,
> results, and remaining risks.

Additional safeguards:

- Ask the model to show the proposed schema/diff before a large rewrite.
- Keep synthetic geometry tests separate from generated art.
- Require a failing test before each bug fix where practical.
- Never accept “looks correct” as a geometry result.
- Never let a model self-approve its own generated image; owner review is the
  final art gate.
- Commit or checkpoint each passing phase separately before starting the
  next one.

## Rejected alternatives

### Change the game projection

Rejected because it solves sourcing convenience by invalidating substantial
working game and art infrastructure. Reconsider only as a separate owner-led
design decision, not as an asset-pipeline fix.

### Keep generating complete buildings and add a validator

Rejected as the production route. A validator can reject obvious drift but
cannot reliably recover hidden intended wall/roof planes from painterly
pixels. It would improve rejection, not production reliability.

### Warp finished buildings into alignment

Rejected because a single homography treats several depth planes as one and
creates visible distortion. Salvage may be attempted manually for a genuinely
flat single-face source, never for a whole cottage.

### Install GIMP and manually nudge every asset

Useful for alpha cleanup, masks, texture painting, and minor ornament edits,
but not the coordinate authority. Manual edits after composition must retain
the recipe, stay inside declared envelopes, and re-run validation.

### Build everything in 3D

An orthographic Blender render rig would also guarantee perspective and is a
valid future fallback for unusually complex architecture. It adds modeling,
materials, render setup, and a second production skillset, so it is excessive
for the current cottage/interior/well proof. Revisit only if compound polygon
rigs become more expensive than maintaining simple 3D models.

## Definition of done

The asset-creation issue is considered closed when:

- final structure geometry can be reproduced without a generative model;
- the same catalog data produces guides, output polygons, anchor, scale, and
  runtime metadata;
- arbitrary full-building generations cannot enter the v2 production lane;
- exterior fixtures and interior fixtures use exact surface slots;
- one-tile props have deterministic contact, alpha, scale, and anchor gates;
- malformed candidates fail automatically;
- player house, player-home interior fixtures, and well pass together and are
  approved in game;
- a cheaper model can add a new catalogued structure by supplying materials
  and modules without inventing screen coordinates or manually tuning scale.
