# Structure kit v1

The structure kit is the production extension of the existing dimetric asset
rig. It builds a final transparent sprite offline from Godot-resolved geometry;
it does not add a second coordinate system or runtime composition dependency.

## First family: whitewash and thatch

The first reusable family comprises:

- continuous warm-white plaster wall material;
- golden thatch roof material;
- deterministic South/East framing, cross rails, gable post, eaves, and roof
  ridge;
- orientation-projected oak door and leaded window modules.

The wall frame is always composed before roof planes. Roof material and eave
trim are composed later, so no wall timber can appear through a roof or eave.
Fixture modules are composed last, after their target wall is already opaque.

`asset_studio/structure_kit_v1.json` owns the architectural rhythm for each
approved footprint. `asset_studio/compose_structure_kit.py` consumes the
resolved Godot rig verbatim and creates a review candidate. The candidate must
pass the existing alpha/anchor validator and a human in-game review before any
runtime sprite manifest is changed.

## Module roadmap

The kit deliberately starts with the modules already proven in the player
house. A chimney is not a generic painted rectangle: it must be a dedicated
transparent roof module, placed on a declared roof surface, with its base
occluded by the roof and its silhouette checked at runtime scale. The same
rule applies to shutters, flower boxes, and signs. Add those as individually
reviewed modules rather than asking a whole-building model to invent them.

This lets one approved material family produce a cottage, farmhouse, alehouse,
workshop, and larger manor outbuilding while preserving exact gameplay
footprints and visibly coherent construction.
