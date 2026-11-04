# Dimetric Static-Asset Pipeline

This is the production path for newly generated static art. It is deliberately
separate from the game and from `data/*.json`: it produces source imagery,
assembly recipes, and review evidence only.

The fixed game convention comes from `res://scripts/globals/iso_projection.gd`:
`+X`/East reads lower-right on screen and `+Y`/South reads lower-left. A
playable building can expose those two faces only. A door, gate, or ramp is
therefore a required `south` or `east` catalog field, never a visual detail the
generator is asked to invent.

## Why structures use two lanes

The geometry rig and the finished exterior solve different problems. Flat
materials and fixture modules prove exact planes, footprint, fixture
orientation, alpha bounds, and anchors deterministically. Raw overlays from
separately painted sources can still look stretched or assembled, so they are
not the preferred finished-building treatment.

For a production exterior:

1. Supply the exact rig render as the composition control and approved art as
   the style control.
2. Generate or paint one cohesive isolated building already close to the rig.
3. Mark its South, near, and East foundation corners in a metadata sidecar.
4. Run `compose_cohesive_structure.py`. It applies one affine correction to
   the entire painting, preserving internal unity while making both ground
   vectors exact.
5. Validate and review the alpha-safe runtime bake in Godot.

This is intentionally not a general whole-building rescue tool. A source with
the wrong camera, hidden face, severe foreshortening, or incompatible roof is
rejected rather than heavily warped. Flat modules remain appropriate for
interior doors/windows, repeatable wall panels, geometry proofs, and fallback
art.

This does not mean every asset becomes an assembly. The catalog routes work:

| Asset class | Production lane |
|---|---|
| Buildings, chapel, coop, barn, gatehouse | One cohesive guide-conditioned exterior + three ground controls; modular rig as proof/fallback |
| Empty interiors | Deterministic floor/North/West shell + separate oriented doors/windows |
| Market stall | Shell guide only; it has no lockable player entry |
| Fences | One guided `fence_south` and `fence_east` segment; repeat deterministically in-game |
| Well, hearth, chest | One-piece freestanding-prop guide |
| Crops, tools, resources, animals, characters | One-piece isolated-sprite artboard; use a rendered base/center guide, not a building perspective prompt |

## Generate the guides

The guide script calls the production `IsoProjection` class directly; it does
not copy the projection math.

```powershell
<godot-4.7-console.exe> --headless --path . --script asset_studio/generate_dimetric_guides.gd
```

When launched from a sandboxed automation environment, run this command with
permission to use Godot's normal local `user://` folders. Restricting those
folders can make `--script` terminate before the script begins; that is an
execution-environment failure, not a guide or projection failure.

This writes ignored, regenerable images plus
`asset_studio/guides/guide_manifest.json`. The manifest records the slot
polygons and pixel bounding boxes used by composition. The tracked source of
truth is `asset_generation_catalog.json`.

The generator rasterizes the guide at quarter resolution and upscales it to
the fixed 1024-pixel canvas. This keeps the manifest geometry at full
resolution while avoiding slow per-pixel GDScript rendering during batch runs.

To add a target, add it to the catalog first. A `structure_shell` needs:

- `footprint_cells`
- exactly `visible_faces: ["south", "east"]`
- `entrance_side: "south" | "east" | "none"`
- `roof_family`
- anchors for all door/gate/window/ramp modules

The generator refuses illegal North/West anchors, a primary entry on the wrong
side, missing primary entries, duplicate IDs, and unknown modules.

## Terra trial protocol

For each target, attach its generated guide as the **composition reference**
and the relevant accepted library image(s) as **style references**. Use the
`terra_prompt` saved beside the target in `guide_manifest.json`; it already
states that the guide controls geometry while project references control the
painted/cel-shaded family. The guide is not decorative: reject a result whose
South/East planes or footprint drift from it.

Start with four outputs, not a large batch:

1. `structure_shell__coop.png` + `door_south` + `ramp_south`.
2. `structure_shell__farmhouse.png` + `door_south` + `window_south` +
   `window_east`.
3. For each source, preserve the opaque generation and the keyed RGBA copy.
4. Human-review each result on the guide before composition.

Use the RunPod/FLUX lane only for isolated props or module concept alternatives
until it proves it can retain these guides. FLUX.1-schnell remains eligible;
FLUX.1-dev and its ControlNet path are excluded by the non-commercial license.

## Compose an approved cohesive exterior

```powershell
python asset_studio/compose_cohesive_structure.py --asset farmhouse `
  --source asset_studio/sources_v2/cohesive/farmhouse_v1.png `
  --out-dir asset_studio/candidates/farmhouse_cohesive_v1

python asset_studio/validate_asset_rig.py `
  asset_studio/candidates/farmhouse_cohesive_v1
```

The source JSON must record backend, model, prompt, license, and
`ground_control_px` entries for `south`, `near`, and `east`. The compositor
derives all target points from the resolved Godot rig; no projection formula
is duplicated in Python.

## Compose an approved shell and modules

```powershell
python asset_studio/compose_structure.py --asset coop --shell output/coop_shell.png `
  --module door_primary=output/coop_door.png `
  --module ramp_primary=output/coop_ramp.png `
  --module window_east_1=output/coop_window.png `
  --out output/coop_assembled.png
```

The command normalizes a shell to the guide manifest's canvas size, then
perspective-maps every module to its exact four-corner dimetric slot polygon.
It fails if any expected slot is missing or an unknown slot is passed. It
creates both the assembled PNG and a
`*.recipe.json` identifying every source, face, and target box. Never
overwrite a raw shell or module with the assembled result.

## Acceptance gates

1. The asset follows its matching guide: two adjacent dimetric wall faces for
   structures; South is lower-left and East lower-right.
2. Every usable entry is visibly on the catalogued South or East face; none is
   on a hidden/back face or a flat frontal elevation.
3. Every required slot has its expected module and the module covers its
   guide box without a seam or floating edge.
4. The silhouette, lighting direction, outline weight, and material treatment
   read alongside `coop.png`, `chapel.png`, `well.png`, and `hearth.png`.
5. The asset is isolated, has a clean alpha edge after keying, has no ground
   platform/scene, and includes no accidental text.
6. Retain the guide manifest, raw sources, keyed sources, assembled output,
   recipe, generation backend/model, and license record together.

Geometry is deliberately a human review gate for now. The local small vision
critic is useful for gross artifacts but is not trusted to certify subtle
dimetric door placement.
