# Asset-generation status

Last updated: 2026-08-10

This is the concise, authoritative handoff for how Tithe & Turnip should make
and accept art. It separates the production-ready 2D path from experiments so
a future model does not confuse a useful proof with a new runtime commitment.

## Decision

Keep the game's `64x48` dimetric presentation and its axis-aligned logical
grid. Do not convert gameplay to top-down, isometric, or runtime 2.5D.

The current production path is the **deterministic 2D dimetric asset rig**.
It fixes the exact footprint, visible wall faces, roof plane, sorting anchor,
and fixture slots before art is accepted. Grid lines may be hidden during
ordinary play, but anchors remain mandatory for collision, interaction,
transitions, placement, and depth sorting.

The TRELLIS.2/Blender route is an **offline 3D-to-2D feasibility experiment**.
It may eventually provide a faster way to obtain a coherent building mesh and
flatten it with the same fixed camera. It does not alter the production
projection, simulation, collision, save data, or asset-rig contract, and it
is not yet proven usable.

## What is ready now

| Area | Method | Status | Authority |
|---|---|---|---|
| Structure footprint and anchor | Godot guide resolver plus validator | Production-ready | `IsoProjection`, resolved rig, manifest |
| Finished farmhouse exterior | One cohesive guide-conditioned source, bounded three-corner affine correction, alpha-safe runtime bake | Promoted 2D proof | v7 `4x3` farmhouse rig and runtime PNG |
| Well/one-tile props | Isolated transparent source with explicit painted-contact bbox | Promoted 2D proof | one-tile anchor/contact validator |
| Interiors | Furniture-free shell; North/West walls visible; South/East cut away; independent fixtures | Promoted for player house | zone fixture side/index data |
| Doors/windows | Orientation-specific transparent modules, placed by known surface slot | Production-ready | exterior/interior recipe data |
| Terrain seasons | Seasonal terrain artwork is integrated separately from structures | Working current-art lane | terrain renderer and season data |

The current accepted exterior farmhouse is a `4x3` logical footprint widened
on the North-South axis. Its South door, enlarged northward East window, roof,
and corner post were deliberately refined in the v7 proof. Do not reuse old
Terra whole-building sprites as a geometry source merely because their style
is attractive; use them as references only unless they pass the current rig.

## How to make the next structure

1. Generate the empty exact rig through `asset_studio/generate_asset_rigs.gd`.
2. Choose one of two source lanes:
   - Preferred polished exterior: make one cohesive, transparent,
     guide-conditioned building source and record its South/near/East ground
     corners. `compose_cohesive_structure.py` may apply one mild affine
     correction only.
   - Exact fallback/proof: use flat material swatches and flat front-facing
     fixture modules with `compose_asset_rig.py`.
3. Keep doors, windows, furniture, and wall-mounted objects out of base
   interior shells. Place them as data-defined overlays.
4. Add source provenance (backend, model, prompt, commercial-use record,
   hashes, and prop contact data when applicable), run the validator and the
   review sheet, then check the baked runtime PNG in Godot.
5. Promote only after human visual approval. Automated checks prove geometry,
   alpha, anchors, scale, and provenance; they do not prove that a building is
   attractive.

## Rejected or constrained approaches

- Asking an image model for a final unconditioned whole building and nudging
  it onto the grid is rejected: painted perspective drift is not reliably
  repairable.
- Projectively warping a finished complete building is rejected: it distorts
  roof, wall, and depth relationships inconsistently.
- Baking doors, windows, or furniture into interior shells is rejected: it
  causes missing wall around fixtures and blocks player decoration later.
- A model-generated plinth, base tile, background, cast-shadow plate, or
  built-in grid is rejected from runtime art.
- Switching the project projection to escape an art problem is rejected. The
  rig, not the dimetric projection, is the controlling solution.

## Generation backends and licensing

The local/RunPod image-generation tooling is source production only; generated
images and model caches stay out of git. A FLUX.1-schnell game-asset LoRA was
previously tested as a promising single-pass isolated-source backend, but is
not yet wired into the ordinary generator and does not bypass rig validation.
FLUX.1-dev is not a permitted backend for this commercial project.

All Terra/downloaded sources are owner-confirmed commercial-use candidates,
but each candidate still needs provenance, alpha, scale, rig, and human review
before it becomes runtime art. See `asset_studio/visual_canon.md` for the
visual contract and `design/dimetric_asset_rig_operator_guide.md` for exact
operator commands.

## TRELLIS.2 experiment: current live state

The DINOv3 access gate cleared on 2026-08-10. The A100 environment, compiled
dependencies, and headless Blender have all been verified. Both fixed-seed
proofs completed end to end:

1. Microsoft’s bundled transparent `T.png` exported a non-empty 71,161,572 B
   GLB and Blender reopened it as 675,723 vertices / 946,774 triangles.
2. The accepted `farmhouse_wide_4x3_southeast_post/final_runtime.png` exported
   a non-empty 48,896,352 B GLB and Blender reopened it as 576,405 vertices /
   950,462 triangles through the game’s fixed `64x48` dimetric camera.

The second image is a **technical pass but a production-art acceptance fail**:
TRELLIS preserved a coherent, widened house volume, but invented extra
door/window details and changed the roof treatment. It is therefore useful as
an optional offline blockout/mesh accelerator, but is not an automatic final
structure-art generator and must not replace the deterministic 2D rig.

The runner now uses PNG texture payloads inside GLB because the pod’s Pillow
WebP binary is incompatible. Blender validation is intentionally opaque with
neutral lighting so material/geometry faults are observable; runtime sources
remain alpha-safe under the existing 2D rig.

The remaining experiment gate is repeatability and practical normalization:
show that a constrained input can be converted without hand-repairing its
architecture. Until then, produce shippable structures through the 2D rig and
consider TRELLIS output reference/blockout material only.

`design/trellis2_runpod_handoff.md` is the operational source of truth for
the pod, pinned versions, commands, storage layout, license boundary, cost
guard, and the latest failure/result logs.
