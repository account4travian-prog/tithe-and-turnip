# Dimetric Asset Rig: Plain-Language Operator Guide

Status: The six-source real-art proof has passed and is promoted in the live
game. Use this guide for future asset-family batches; each still needs its own
explicit promotion step.

## What the system does

Godot makes a precise empty building blueprint from the same `64x48`
projection used by the game. There are now two consumers of that blueprint.
The flat-source compositor remains the exact geometry proof and fallback. The
cohesive-exterior compositor takes one finished, guide-conditioned painting
and applies one mild affine correction from three marked foundation corners.
The image model supplies the unified style; Godot's resolved rig still owns
the footprint, wall directions, scale, and anchor.

This is why the system is feasible. The model paints a building close to an
exact visual guide; deterministic code performs the final alignment and
rejects malformed or tampered inputs.

## Cohesive exterior source

Keep one transparent PNG and one same-named JSON under
`asset_studio/sources_v2/cohesive/`. The JSON must include:

```json
{
  "backend": "record the generation or painting backend",
  "model": "record the exact model name",
  "prompt": "retain the complete production brief",
  "license": "owner-confirmed commercial use",
  "ground_control_px": {
    "south": [46, 985],
    "near": [640, 1345],
    "east": [1096, 1068]
  }
}
```

Those example coordinates belong only to `farmhouse_v1.png`. Mark the actual
outer foundation corners for every new source. South-to-near and near-to-East
become the two exact dimetric footprint edges.

The well follows a simpler rule: it may be a complete isolated dimetric prop,
but its source metadata marks the rectangle where its base touches the ground.
The compositor places that rectangle at the center of its tile. It never
guesses from transparent padding.

## The six real source images needed now

Place each PNG beside a same-named JSON metadata file:

```text
asset_studio/sources_v2/
  materials/
    whitewash_timber.png
    whitewash_timber.json
    gold_thatch.png
    gold_thatch.json
    oak_floorboards.png
    oak_floorboards.json
  modules/
    door_oak_flat.png
    door_oak_flat.json
    window_shutter_flat.png
    window_shutter_flat.json
  props/
    well.png
    well.json
```

Source requirements:

- Materials are square, flat, crop-safe textures. They contain no building
  silhouette, perspective, door, window, or background scene.
- Door and window modules are upright, front-facing, isolated on transparent
  backgrounds. They contain no wall and no baked dimetric slant.
- The well is one isolated dimetric object on transparency. Its JSON contains
  `contact_bbox_px: [x, y, width, height]` around the painted base that touches
  the ground.
- Every JSON records `backend`, `model`, `prompt`, and `license`. The pipeline
  rejects missing records rather than losing provenance.

Example material/module metadata:

```json
{
  "backend": "terra",
  "model": "record the exact model name",
  "prompt": "record the exact generation or hand-paint instruction",
  "license": "owner-confirmed commercial use"
}
```

Example well metadata:

```json
{
  "backend": "terra",
  "model": "record the exact model name",
  "prompt": "record the exact generation or hand-paint instruction",
  "license": "owner-confirmed commercial use",
  "contact_bbox_px": [120, 410, 260, 90]
}
```

The example contact numbers are not reusable. They must describe the actual
well PNG and can be measured in any basic image editor.

## How to read a review sheet

Each row has three views:

1. **Source crop:** the composed transparent PNG at working resolution.
2. **Exact rig overlay:** colored outlines show the legal planes and slots.
   Painted pixels must stay inside those shapes, apart from the documented
   one-pixel resampling allowance.
3. **In-game scale:** the alpha-safe, runtime-baked sprite at its actual game
   size. The blue outline is
   its logical footprint. On the well, green is the allowed ground-contact
   region, the white point is the sorting anchor, and magenta is the maximum
   allowed prop silhouette.

The lines are inspection aids and are never shipped in the art. The ordinary
game grid may be hidden outside tool/placement modes; logical anchors remain
because collision, interaction, transitions, and depth sorting need them.

After deterministic validation passes, the only human questions are whether
the style, proportions, fixture size, and visual weight look good.

The candidate folder intentionally retains two resolutions. `final.png` (or
the equivalent named part) is the aligned 4x proof used for geometry
validation. `final_runtime.png` is the production PNG, reduced offline in
premultiplied-alpha space. Runtime manifests use the latter at `draw_scale =
1.0`; Godot does not perform the proof's 4x reduction every frame. This avoids
black chroma fringes, uneven one-pixel contours, and fractional anchors.

## Commands

Regenerate the exact Godot geometry:

```powershell
& '%USERPROFILE%\Desktop\GoDot\Godot_v4.7.1-stable_win64_console.exe' `
  --headless --path . --script res://asset_studio/generate_asset_rigs.gd
```

Run the geometry and fail-closed tests:

```powershell
& '%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' `
  asset_studio/test_asset_rig.py

& '%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' `
  asset_studio/test_asset_rig_pipeline.py

& '%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' `
  asset_studio/test_cohesive_structure_pipeline.py
```

Compose, validate, and review one real candidate:

```powershell
& '%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' `
  asset_studio/compose_asset_rig.py --asset farmhouse `
  --out-dir asset_studio/candidates/farmhouse

& '%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' `
  asset_studio/validate_asset_rig.py asset_studio/candidates/farmhouse

& '%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' `
  asset_studio/make_asset_rig_review.py asset_studio/candidates/farmhouse
```

Repeat those three commands for `player_home_interior` and `well`.

Compose and validate a cohesive farmhouse exterior:

```powershell
python asset_studio/compose_cohesive_structure.py --asset farmhouse `
  --source asset_studio/sources_v2/cohesive/farmhouse_v1.png `
  --out-dir asset_studio/candidates/farmhouse_cohesive_v1

python asset_studio/validate_asset_rig.py `
  asset_studio/candidates/farmhouse_cohesive_v1
```

## Terra versus the pod

Terra, Codex image generation, or the pod may produce a cohesive source because
none of them owns runtime geometry. Use the exact rig as composition control,
an approved in-game building as style control, and a small fixed batch. The
pod is economical for variants after the brief is proven; direct generation is
simpler for one-off art-direction corrections. Do not promote any result until
the three controls, validator, runtime-scale review, and live Godot check pass.

New batches may begin only after their whole approval set passes together and
the runtime-baked panels are approved.
