# Sprint 16 - Art Asset Integration (ADR-041)

Master guide for turning fifteen purchased/found sprite packs under
`SourceArtAssets/` into textured visual proxies in the live game. Read
`design/decisions.md`'s ADR-041 first - this document is its execution
plan, not a separate ruling. Read `CLAUDE.md` v0.22 sections 2, 5, 8, and
9.5 next.

**The owner ruling this sprint executes:** integrate the packs *as-is* as
much as possible. Styles clash (pixel-art vs. painted vs. vector-clean) and
that is accepted, not fixed, in exchange for speed. Edit an asset only when
it fails to read at the game's `64x48` tile scale. Do not wait for, and do
not build, any cross-pack style unification (the `asset_studio/` LoRA
pipeline stays parked - see section 2 below).

This guide is deliberately an **index and routing plan**, not a schema
document. The one piece of real technical design it defers - the shared
sprite/animation foundation every workstream depends on - is being pulled
via a DeepSeek consult (`.deepseek/tasks/art_foundation_task.md` ->
`.deepseek/outputs/art_foundation_out.md`), the same pattern
`sprint_15_regions.md` used. **Do not start any workstream in section 6
until that output exists and has been reconciled against the live code**
(see section 5).

---

## 1. What we have (the manifest)

Fifteen packs, ~3,600 raster sprites, surveyed by directory/filename census
(not yet vision-catalogued - see section 1.1). Each PNG ships with a stale
`.import` sidecar from whatever project last touched it; ignore these, they
are not portable and Godot regenerates its own on `--headless --import`
(known trap #8). Several packs also ship `AI`/`EPS` vector masters, `SCML`
(Spriter) animation project files, and `Tiled/*.tmx` exports - none of
these are consumed directly; they exist as optional reference for a human
checking frame layout, never as a build input.

| Pack | Files (PNG) | Shape | Target system | Notes |
|---|---:|---|---|---|
| `Male1` | 174 | Directional sheets, `Unarmed`/`Sword` states, `Tiled_files` ref | Player + male NPC base (actors) | `Parts`, `With_shadow`/`Without_shadow` variants - pick one shadow treatment, discard the other |
| `Female1` | 157 | Same shape as Male1 | Player (female) + female NPC base (actors) | Same shadow-variant choice |
| `NPC1` | 1,273 | Three archetypes (Artist, Astrologer, Citizen), each with `PNG`/`popup` (speech-bubble UI graphic)/`TXT` (license/readme only, no frame docs) | Villager visual variety (actors) | By far the largest pack - largest curation task. `popup/` graphics are a UI asset, route to WS-D not WS-C |
| `Bandits1` | 1,209 | Three archetypes (Assassin, Robber, Thug), `SCML` project files present | Bandit raid enemies (actors) | SCML present for at least 6 files - see section 5's animation-extraction question |
| `Animals1` | 114 | `With_Shadow`/`Without_shadow`, one `Tiled/Animals.tmx` (16x16 base) | Generic wildlife / forageable-adjacent fauna (actors) | Confirm which species are actually needed before importing all 114 |
| `FarmAnimalsOption1` | 48 | `With_shadow`/`Without_shadow`, sample `Bull_animation_with_shadow.png` = 384x512 (packed multi-animation sheet) | Chickens/goat (ADR-028 livestock) (actors) | Directly relevant to the shipped `AnimalManager` - check species match (`chickens`, `goat`) before assuming coverage |
| `Building1` | 100 | `PNG` + `Tiled_files` (`Characters.tmx`, `Exterior.tmx`, two `Interior_*.tmx`, 16x16 base) | Cottage, market stall, other structures (structures) | Interior tiles are out of scope - no interior scenes exist; exterior only |
| `Home1PixelStyle` | 10 | Loose sheets: `exterior.png` (240x800), `Interior.png`, `walls_floor.png`, `house_details.png`, `ground_grass_details.png`, animal/animation sheets (`cat_animation`, `bird_fly/jump_animation`, `Smoke_animation`, `Trees_animation`) | Cottage exterior candidate; incidental animated critters/smoke are stretch, not required (structures + optional actors) | Already pixel-art styled - a candidate "anchor" pack if any future unification pass happens, per `asset_studio/plan_art_integration_pro2.md` |
| `Workshop1` | 45 | `PNG` (`Animation packed version` subfolder) + `Tiled_files` | Drying shed / hearth / crafting stations (structures) | `Customer.png` (384x32) suggests a directional strip, not a building - confirm per-file before assigning |
| `TreesOption1` | 164 | `Assets_separately/Trees` (+ 3 shadow variants: plain, texture_shadow, texture_shadow_dark), sample tree = 128x128 | Map-feature trees (world dressing) | Pick exactly one shadow variant project-wide for visual consistency within the pack itself |
| `BushesOption1` | 164 | Same four-variant shape as TreesOption1 | Map-feature bushes (world dressing) | Same shadow-variant choice |
| `RocksAndStones` | 164 | `Objects_separately`, sample rock = 64x64 | Map-feature rocks / forage flint source (world dressing) | Maps onto ADR-022's forage rocks |
| `FarmPlantsPixelStyle` | 2 | `Plants.png` (768x432 sheet), `Supplies.png` | Crop-stage sprites, tool/item icons | Tiny pack but potentially highest value per file - a packed sheet needing sub-rect slicing, not per-file assets |
| `AdventureUI` | 2 PNG + ~150 SVG | `Spritesheet/` (with `.xml` atlas index) + `Vector/` (buttons, panels, checkboxes, progress bars, minimap icons) | UI chrome (UI) | The `.xml` beside the spritesheet is an atlas coordinate index - read it, don't re-derive frame rects by eye |
| `UI2` | 19 | Loose PNGs | UI chrome (UI) | Smallest UI pack - likely icons/small elements |

**1.1 Cataloguing approach - filename-based, not vision-based, for this
pass.** `asset_studio/catalog.py` (a working tool, see section 2) can tag
every PNG with a local vision model, but Ollama is not running on this
machine as of this survey and the realistic cost is ~30s/image x ~3,600
images (order of a day of wall-clock, even though it is free and
resumable). That is enrichment, not a blocker: the table above plus each
pack's own folder/filename structure is already sufficient to start
curation. If a workstream agent hits a genuinely ambiguous file (a name
that doesn't say what it is), it should say so in its report rather than
block on a vision catalog run.

---

## 2. Relationship to `asset_studio/` - narrowed, not adopted

`asset_studio/` (root-level, git-ignored, private) is a working local
ComfyUI/SDXL pipeline with its own prior plans
(`plan_art_integration_pro.md`, `plan_art_integration_pro2.md`,
`style_bible.md`) built before this session's owner ruling. Its Phase
0/1/2/4/5 (contract amendment, catalog+selection, integration architecture,
integration+testing, polish) describe substantially the same shape this
sprint guide now formalizes as ADR-041 + this document. **Its Phase 3
(LoRA training + ControlNet/IP-Adapter restyling to unify style across
packs) is explicitly parked for this sprint** - ADR-041's owner ruling
chose speed and as-is integration over a multi-hour local-GPU unification
pipeline with uncertain output quality. Nothing in `asset_studio/` is
deleted or edited; it remains available if a future polish pass wants it.
Do not spend any workstream's budget re-deriving LoRA hyperparameters,
IP-Adapter settings, or restyling passes - that work already exists,
parked, in `asset_studio/plan_art_integration_pro2.md` sections 3a-3d if
it's ever revived.

---

## 3. Sequencing

```
Phase 0.5  Asset staging (sequential, one script)
     |
Phase 1    Shared foundation (sequential, blocking - DeepSeek consult,
     |     reconciled by Claude, then implemented)
     v
  -------------------------------------------------
  |          |            |                       |
 WS-A       WS-B         WS-D                    WS-C
 World      Structures   UI chrome               Actors
 dressing                                    (opens once Phase 1
 (parallel worktrees, independent file sets)  lands; merges last)
  -------------------------------------------------
     |
Phase 2    Integration test scene + full regression sweep
     |
Phase 3    ADR-041-realized follow-up entry (decisions.md), DEVELOPMENT_STATE.md
```

Phase 1 is sequential and blocking for the same reason ADR-032's Phase 0
was: it freezes the API every workstream calls (the sprite/animation
lookup and the manifest schema), so four agents don't invent four
incompatible answers to "how does a proxy find its texture." Once frozen,
WS-A, WS-B, and WS-D are fully independent (disjoint files - see the
ownership table in section 6) and can run concurrently in git worktrees,
exactly per `design/IsometricConversion_Worktrees.md`'s runbook (reuse
that document; only the workstream letters/branch names/file lists differ).
WS-C is technically parallel-eligible once Phase 1 lands but is scoped
separately because it is the largest, most animation-heavy, and touches
the most shared/sensitive files (`player.gd`, `npc.gd`, `enemy.gd`,
combat) - route it to the more capable agent available (see section 7) and
merge it last so any conflict it surfaces is diagnosed against an
otherwise-stable base.

---

## 4. Phase 0.5 - asset staging

**Goal:** get a small, curated, `res://`-ready set of PNGs out of the
~3,600-file source tree before any workstream touches Godot.

A staging script (Python or PowerShell - implementer's choice, no engine
dependency) that, per pack:

1. Picks exactly **one** shadow/background variant where a pack offers
   several (e.g. `TreesOption1`'s four variants -> pick `Assets_separately`
   plain or `Assets_texture_shadow`, not both; same for `BushesOption1`).
2. Excludes `.import`, `.DS_Store`, `AI/`, `EPS/`, `SCML` project files,
   and `Tiled/*.tmx` from the copy (reference-only, per ADR-041's
   source-tree hygiene clause).
3. Copies the surviving PNGs into `res://assets/sprites/<category>/<pack>/`
   using the category column from section 1's table (`actors`,
   `structures`, `world_dressing`, `ui`).
4. Writes a plain-text manifest of what it copied vs. skipped, so a
   workstream agent can `grep` it instead of re-walking the source tree.

**Routing:** DeepSeek Flash (a pure scripting task, no design judgment -
see section 7). **Gate:** the script runs to completion and its manifest
lists a file count consistent with section 1's table (spot-check three
packs by hand).

**Status: LANDED (2026-08-08) - run by Claude directly, not DeepSeek,**
because the source tree (`SourceArtAssets/`) sits outside the repo and a
sandboxed Codex agent cannot be assumed to have read access to an
arbitrary path off the project directory - only the orchestrator's own
unrestricted shell does. `tools/stage_art_assets.py` (committed - not a
throwaway probe, since new packs may arrive later and this is meant to be
re-run) implements all four rules above, plus one the original plan
missed: `TreesOption1`/`BushesOption1` name their shadow variants as a
*suffix on a shared base* (`Trees`, `Trees_shadow`, `Trees_texture_shadow`,
`Trees_texture_shadow_dark`) rather than as a `With_shadow`/`Without_shadow`
sibling pair - the first version of the script missed this and staged all
four variants before the fix (dry-run caught it before any file was
actually copied). **2,157 files staged** across all fifteen packs'
`actors`/`structures`/`world_dressing`/`ui` category directories (191 MB);
zero `.import`/`.ai`/`.eps`/`.scml`/`.tmx`/`.txt` leaked into
`res://assets/sprites/`, confirmed by a post-run scan. Each workstream
agent should `find`/glob its own category directory directly rather than
trust a static file listing here - the directory structure itself is the
manifest, and staying accurate to disk beats a second copy of the same
information that can drift.

---

## 5. Phase 1 - shared foundation (blocking)

This is the one piece of real technical design this sprint needs before
anything else can start, and it is already in flight as a DeepSeek
consult grounded in the live codebase (exact `iso_projection.gd` function
signatures, the `ActorVisual`/`StructureVisual` proxy pattern, and
`Player._facing`'s existing 8-way data - see
`.deepseek/tasks/art_foundation_task.md`). It must answer, concretely
enough to implement without another round-trip:

1. **The sprite/animation manifest schema** (a new `data/*.json` file,
   following this project's existing `INT_KEYS`/`version` conventions) -
   what fields describe a static sprite (source path, anchor offset, target
   scale) vs. a directional/animated one (frame rects or atlas coordinates,
   frame count, fps, which of the 8 `Player._facing` directions each row/
   sequence maps to).
2. **The lookup itself** - a static `class_name` helper (the
   `IsoProjection` pattern) or a `GameData` extension, per CLAUDE.md
   section 5's new autoload note. Not a new autoload.
3. **Anchor and scale math** - given a proxy's existing screen position
   (from `IsoProjection`, unchanged), where does a textured child
   `Sprite2D`/`AnimatedSprite2D`'s origin sit so its visual "feet" touch
   that point, and what scale factor brings each pack's native resolution
   (16px-128px+ bases, per section 1's table) to a sane footprint against
   the `64x48` tile / `32`-unit logical cell.
4. **Texture import defaults** - `project.godot` currently has no
   `[rendering]`/`[importer_defaults]` override, so Linear filtering
   applies by default. Pixel-styled packs (`FarmPlantsPixelStyle`,
   `Home1PixelStyle`, the 16x16-based Tiled packs) want Nearest; the
   higher-resolution painted/vector-clean packs (`Male1`/`Female1`/`NPC1`/
   `Bandits1`, `TreesOption1`/`BushesOption1`/`RocksAndStones`,
   `Building1`, `Workshop1`) may look better Linear. Recommend a decision
   and flag it as something to eyeball in the Phase 2 test scene, not
   something to lock blind.
5. **SCML animation handling** - `Bandits1` ships Spiriter (`.scml`)
   project files for at least 6 entries. No third-party addon can read
   these (CLAUDE.md section 1's addon ban covers test frameworks and
   everything else identically). Recommend: extract the needed frames as
   plain PNG sequences (the packs already ship per-frame PNGs alongside
   the `.scml` in every case surveyed - confirm this holds, since if it
   does, the `.scml` can simply be ignored and the manifest just points at
   the existing frame PNGs directly) rather than writing an SCML parser.
6. **A worked example**: apply the schema to one real case end-to-end -
   e.g. `RocksAndStones/Objects_separately/Rock1_1.png` as a static
   `StructureVisual`-style prop, and one `Male1` walk-cycle direction as an
   `AnimatedSprite2D` case - so workstream agents have a concrete template,
   not just a schema.

**Reconciliation (mandatory, per the deepseek-consult skill):** before any
workstream opens, verify every named file/function/line the consult output
claims still exists (grep it), and confirm it didn't silently invent an
answer to an open question this brief left open (the exact texture-filter
default, the exact manifest filename). **Do not skip this step** - this
project's own history (ADR-036 and others) repeatedly recorded DeepSeek
guessing wrong about a specific file's shape.

**Implementer:** the reconciled design should be built by Claude (this
session or a continuation) directly, not handed to a worktree agent -
like ADR-032's Phase 0, this is the frozen seam everything else depends
on, and a mistake here multiplies across four workstreams instead of one.

**Status: LANDED (2026-08-08).** The consult output
(`.deepseek/outputs/art_foundation_out.md`) was reconciled against the live
code (every named file/function/API claim grepped or verified against the
real Godot 4.7.1 binary via a throwaway probe script, per the
deepseek-consult skill's mandatory step) and implemented verbatim where
verified:
- `data/sprites_world_dressing.json`, `sprites_structures.json`,
  `sprites_actors.json`, `sprites_ui.json` (v1, each an empty `sprites`
  array) - **one file per workstream, not one shared `sprites.json`**, a
  post-consult correction: four worktrees appending to the same JSON file
  would conflict on every merge regardless of whether their entries
  actually overlap. `GameData.load_all()` merges all four into one
  in-memory `sprites` Dictionary; ids must stay unique across files (a
  clash keeps whichever file loaded first, per `Dictionary.merge`'s
  default - a bug to notice, not silently paper over).
- `GameData`: `SPRITE_INT_KEYS`/`SPRITE_DIRECTION_INT_KEYS`/
  `SPRITE_FRAME_INT_KEYS`, `sprites: Dictionary`, wired into `load_all()`
  and `_cast_nested_ints()`, `get_sprite(id) -> Dictionary` accessor.
- `scripts/globals/sprite_manifest.gd` - the static `SpriteManifest`
  helper (schema math, texture/SpriteFrames construction, anchor/scale,
  per-entry `filter`), no new autoload.
- `scripts/world/static_prop_visual.gd` - the WS-A static-prop proxy
  pattern (worked example a).
- `scripts/player/player_visual.gd` - updated with the textured-child
  path (worked example b), primitives as the automatic fallback since
  `data/sprites_actors.json` has no `male1_walk` entry yet - **zero
  behavior change today**, verified by the full suite staying green.
- New suite `tests/suites/test_art_foundation.gd` (15 test methods, 28
  checks) covering the schema/casting boundary and every `SpriteManifest`
  math function with hand-built entries - no staged texture files
  required.
- Full suite: 1846 -> **1874 checks, all green.**

Texture-import-default recommendation (deliverable 4): **per-entry**
`filter` field applied at the node via `CanvasItem.texture_filter`, not a
project-wide override - confirmed correct and implemented as designed.
Still to eyeball in the Phase 2 test scene once real assets are staged.

**Gate met for opening the parallel workstreams.** The Phase 2 integration
test scene (`test_dimetric_sprites.tscn` or equivalent, per
`asset_studio/plan_art_integration_pro2.md`'s Phase 2 precedent) showing a
real staged static prop and animated actor is still owed, but is no longer
blocking - it depends on Phase 0.5 staging (real files under
`res://assets/sprites/...`), which is itself now unblocked since the
manifest schema and lookup API it targets exist and are tested.

---

## 6. Workstreams (parallel once Phase 1 lands)

Follow `design/IsometricConversion_Worktrees.md` verbatim for mechanics
(worktree creation, agent prompt skeleton, merge discipline) - substitute
these workstreams and file lists for that document's WS-A..D.

| WS | Scope | Owns | Depends on |
|---|---|---|---|
| **A - World dressing** | `TreesOption1`, `BushesOption1`, `RocksAndStones`, `FarmPlantsPixelStyle` as static-sprite map features | `data/sprites_world_dressing.json`, `scripts/world/feature_renderer.gd`, `scripts/world/structure_visual.gd` (read-only reuse), a new `tests/suites/test_art_dressing.gd` | Phase 1 manifest schema + lookup |
| **B - Structures** | `Building1`, `Home1PixelStyle`, `Workshop1` exteriors as building textures | `data/sprites_structures.json`, `scripts/world/building_renderer.gd`, `scripts/world/structure_visual.gd` (footprint/scale extension if the static-sprite case needs one), `tests/suites/test_art_structures.gd` | Phase 1 |
| **C - Actors** | `Male1`, `Female1` (player + humanoid NPC base), `NPC1` (villager variety), `Bandits1` (raid enemies), `Animals1` + `FarmAnimalsOption1` (wildlife + ADR-028 livestock), the character/citizen sprites `Building1`/`Workshop1` also carry (staged to `actors/building1`, `actors/workshop1`), 8-way facing -> animation row mapping | `data/sprites_actors.json`, `scripts/world/actor_visual.gd`, `scripts/world/enemy_visual.gd`, `scripts/player/player_visual.gd`, `scripts/world/npc.gd`-adjacent visual wiring, `tests/suites/test_art_actors.gd` | Phase 1 - **opens after A/B/D are underway, merges last** |
| **D - UI chrome** | `AdventureUI`, `UI2` as panel/button/checkbox/progress-bar textures (`StyleBoxTexture`/`NinePatchRect`), `NPC1`'s `popup/` speech-bubble graphic | `data/sprites_ui.json`, `scripts/ui/ui_kit.gd`, `scenes/ui/*`, `tests/suites/test_art_ui.gd` | Phase 1 (for the lookup convention only - UI has no y-sort/anchor concern at all, so it is the *least* coupled workstream and could in principle start before Phase 1 finishes if someone needs to fill idle capacity) |

**Correction to this table's original pack assignments, found during Phase
0.5 staging (2026-08-08):** `Building1` and `Workshop1` are not pure
building packs - both mix building-exterior art with named-character
sprites (citizens, fighters, mages, a guildmaster, customers, a
smith/"Master", a "Seller") in the same source `PNG/` folder. The staging
script (`tools/stage_art_assets.py`) splits each by a filename keyword
check into `assets/sprites/structures/<pack>` (WS-B) and
`assets/sprites/actors/<pack>` (WS-C) - both workstreams draw from the
same two source packs, at different staged paths, and neither owns the
other's half.

**Ownership is binding**, per the worktree runbook's own rule: a workstream
that needs a file outside its list stops, records it, and escalates rather
than editing it. In particular, `player.gd`'s facing logic
(`_vector_to_facing`, `get_facing()`) is **frozen** for this sprint - WS-C
*consumes* `get_facing()`'s existing 8-way `Vector2i`, it does not change
how facing is computed.

---

## 7. Routing table - who does what

| Work | Route | Why |
|---|---|---|
| Phase 0.5 staging script | DeepSeek Flash (worktree or direct) | Pure scripting, no design judgment, easily verified by file count |
| Phase 1 foundation design | DeepSeek consult (Flash, delegating the anchor/scale math sub-question to Pro-tier reasoning per the deepseek-consult skill's delegation pattern) | Multi-system design question benefiting from a second model's pass, exactly the skill's stated use case |
| Phase 1 reconciliation + implementation | Claude (this session/a continuation) | Frozen shared seam; mistakes here multiply across every downstream workstream |
| WS-A (world dressing) | DeepSeek Flash, git worktree | Lowest risk, no animation, good first real delegation once the foundation lands |
| WS-B (structures) | DeepSeek Flash, git worktree | Same shape as WS-A, one step up in footprint/scale complexity |
| WS-D (UI chrome) | DeepSeek Flash, git worktree | Fully disjoint files from A/B/C, no dimetric/y-sort concern at all |
| WS-C (actors + facing/animation) | The second Claude instance | Highest judgment load: animation state machines interacting with existing combat/tool-use code, the largest pack (`NPC1`, 1,273 files) to curate, and the files most other systems already depend on (`player.gd`-adjacent, `npc.gd`, `enemy.gd`) |
| Phase 2 integration test scene + regression sweep | Claude (merge integrator) | Same role Claude played merging ADR-032's four worktreads |
| Optional: vision cataloguing (`asset_studio/catalog.py`) | The owner, locally, whenever Ollama is running | Free but slow (~30s/image); enrichment, not a blocker - see section 1.1 |

---

## 8. Merge order and verification gates

From `master`, once each workstream reports done:

1. WS-D (UI chrome) - most isolated, safest first merge.
2. WS-A (world dressing).
3. WS-B (structures).
4. WS-C (actors) - last, onto the most work already integrated, per section
   6's ownership table.

After **each** merge: `--headless --path . --import` then
`--headless --path . --script res://tests/run_tests.gd` must print
`ALL SUITES PASSED` before the next merge starts - identical discipline to
`design/IsometricConversion_Worktrees.md` section 5, same rationale
(a carried failure becomes unattributable one merge later).

**Status: WS-B, WS-A, WS-D landed and merged into
`feature/sprint16-art-foundation` (2026-08-08)**, in that order (WS-D
turned out no more isolated to merge first than the others once all three
were touching `tests/run_tests.gd`/`DEVELOPMENT_STATE.md` - the actual
order was B, A, D, each independently reverified before and after
merging; only those two shared files ever conflicted, both trivial
same-file-different-lines resolutions). Final count: **1874 -> 2073
checks, all green.** A `.gitattributes` fix (`*.import`/`*.uid text
eol=lf`) landed alongside the merges - Godot always writes these sidecars
with LF, and all three agents independently hit the same CRLF-checkout
churn and correctly left it out of their commits. `tools/
stage_art_assets.py`'s copied assets and each workstream's real diff are
the only content that changed; terrain/soil rendering remains untouched.
WS-C (actors) is the one workstream left - see section 7's routing table.

---

## 9. Definition of done

- Every pack in section 1's table has been triaged: integrated, held back
  with a stated reason (e.g. "Building1's interior tiles - no interior
  scenes exist"), or explicitly deferred to a future pass.
- Terrain/soil rendering is untouched (still `farm_renderer.gd`'s
  primitives) - confirmed by diff, not just by intent.
- Full test suite green (`ALL SUITES PASSED`), count recorded in
  `DEVELOPMENT_STATE.md` alongside the pre-sprint baseline (1846 checks).
- A live playtest (main.tscn, walking the farm, entering combat, opening
  the market/inventory/dialogue UI) shows textured actors, structures,
  world dressing, and UI chrome with no missing-texture placeholders and
  no `_draw()` primitive left behind *for any asset that was actually
  integrated* - primitives remaining where a pack was deliberately held
  back are correct, not a bug.
- `design/decisions.md` gains an "ADR-041 realized" follow-up entry (the
  ADR-030/036 pattern) recording what actually shipped vs. this guide's
  plan, and any owner calls made mid-sprint (e.g. which shadow variant was
  picked per pack, the final texture-filter default).
