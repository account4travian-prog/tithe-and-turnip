# Vertical Slice Visual Canon

This is the production target for all newly accepted environment art. It is a
rendering contract, not a promise that every current source image is approved.

## Projection and entry rule

- The game uses the `64 x 48` dimetric projection from
  `scripts/globals/iso_projection.gd`.
- East (`+X`) faces read lower-right on screen; South (`+Y`) faces read
  lower-left.
- A playable exterior door, ramp, or gate must appear on one of those two
  near faces. North/far and West/far entryways are rejected.
- South and East entrances are equally valid. Deliberately vary the entry face
  across new structures when their function does not dictate one, so the
  village does not develop a South-only visual pattern.
- Each building must expose two wall faces and a roof plane. Flat frontal,
  side-scrolling, top-down, or sticker framing is rejected.

## Style target

- Clean isolated object on transparent output; no plinth, base tile, cast
  shadow plate, border, text, UI, or full-scene background.
- Warm painted/cel-shaded medieval materials, readable dark contour, simple
  broad values, and strong silhouette at `64 x 48` tile scale.
- The reference coop establishes the desired structural read: front/near wall
  is immediately legible, the ramp follows the door, and roof plus both wall
  planes stay readable.
- The farmhouse failure establishes the rejection case: plausible cottage
  styling alone is insufficient when the camera/entry relation is wrong.

## Canonical subjects

The first approval set is: coop, well, hearth, chapel, cottage/alehouse.
Those subjects establish all later structure, prop, interior, and terrain
decisions. Existing vertical-slice files remain reference candidates only
until their alpha, scale, license, and in-game placement checks pass.

## Production policy

1. Generate final exterior art in a guide-conditioned, in-context pass.
   Modules provide placement constraints; they are not raw overlays on a
   separately painted shell. Mark the painted South, near, and East ground
   corners in source metadata, then use one bounded affine correction to land
   them on the exact rig. Reject a source if that correction does not preserve
   a natural silhouette; never projectively warp an unrelated whole building.
2. Generate the matching empty interior shell after the exterior is approved.
   Door and window positions must agree with the exterior's declared entry
   face and the zone edge-exit data, but those elements are not baked into the
   shell (see the modular-interior rule below).
3. Interior camera-wall rule: render the North and West walls; leave the East
   and South walls invisible so the player can read into the room. Doors and
   windows remain visible where their data-defined placements require them,
   including on an otherwise hidden near wall.
4. Interior-space rule: rooms may be intentionally much larger inside than
   their exterior footprint suggests. Treat the interior zone dimensions as
   the playable fiction; do not shrink an interior merely to literalize its
   exterior silhouette.
5. Modular-interior rule: base interior art contains only floor and continuous
   visible North/West architecture—no furniture, storage, rugs, tools,
   clutter, doors, windows, or wall-mounted objects. Doors, windows, and wall
   objects are individually placed overlays using zone data, so they never
   leave an accidental gap in the shell wall. A future player decorating
   system likewise owns every placeable furnishing as a separate visual.
6. Add an approved PNG under `assets/sprites/`, then add only its metadata to
   the relevant sprite manifest. `FeatureRenderer` and `BuildingRenderer`
   both fail soft to primitives until that manifest entry exists.
7. Run a scale/anchor pass in Godot and obtain a human visual sign-off before
   calling the asset accepted. Automated palette checks do not replace that
   review.

## Status of current generated output

The owner confirmed that all downloaded and Terra-produced source art is
approved for commercial use. Individual assets still require geometry,
provenance, alpha, runtime-scale, and human visual review before promotion.

The v5 player farmhouse establishes the cohesive-exterior production example:
one guide-conditioned repaint, one three-landmark affine correction, an
alpha-safe offline runtime bake, and exact rig-relative ground controls. The
flat material/module compositor remains the deterministic geometry proof and
fallback, not the preferred finished exterior look.

## Review note - chapel replacement accepted (2026-08-09)

The replacement chapel is accepted: it has the needed taller silhouette, no
attached platform/plinth, two visible wall faces plus roof, and a South-face
entrance. Future chapel variants may use either the South or East near face.
