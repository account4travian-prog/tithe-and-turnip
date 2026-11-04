# IsometricConversion - the ADR-032 conversion plan

**Status:** ready to execute. Authority: ADR-032 (`design/decisions.md`),
CLAUDE.md v0.12. This document is subordinate to both - where it and the
contract disagree, the contract wins and this file is wrong.

**Companion:** `design/IsometricConversion_Worktrees.md` - the operational
runbook for running the parallel phase in git worktrees. Read it before
spawning any agent.

**Shape of the work:** one sequential foundation phase, then four workstreams
that run **concurrently in separate worktrees**, then a single integration
phase. The parallel phase is designed so that no two agents ever hold write
permission on the same file - see section 5.

---

## 1. What is actually changing

The game keeps a square, axis-aligned simulation and starts *drawing* it at a
dimetric angle. That sentence is the whole design; everything below is
consequence.

| Layer | Changes? |
|---|---|
| `FarmGrid`, crops, moisture, soil | No |
| Time, seasons, weather, tithes, reputation, raids, crafting, animals | No |
| Save payloads, `SAVE_VERSION` | No - and a migration would mean the plan was violated |
| `data/*.json` | No |
| Physics bodies, collision shapes, weapon reach, enemy pathing | No |
| Terrain / structure / actor **rendering** | Rewritten |
| Camera | Rewritten |
| Player input rotation + facing | Rewritten |
| `main.gd` wiring | Extended in Phase 0, frozen thereafter |

**The single most important rule in this document:** logical space and screen
space never mix. A gameplay node's `global_position` is always logical. A
projected value is never read back into gameplay, never compared against a
logical value, and never stored. This is CLAUDE.md section 8's projection
invariant, and the failure mode is nasty - everything looks approximately
right until something moves diagonally.

---

## 2. The projection, specified exactly

Frozen in Phase 0 as `scripts/globals/iso_projection.gd`. Every workstream
codes against this and none of them may redefine it.

```
TILE_W       = 64    # screen width of one cell's diamond
TILE_H       = 48    # screen height of one cell's diamond
LOGICAL_CELL = 32    # unchanged; the world-unit size of a cell in sim space
```

### Forward projection

```
grid (gx, gy)  ->  screen (sx, sy)

sx = (gx - gy) * (TILE_W / 2)   =  (gx - gy) * 32
sy = (gx + gy) * (TILE_H / 2)   =  (gx + gy) * 24
```

Cell `(0,0)` therefore draws as a diamond with its top corner on the origin:
top `(0,0)`, right `(32,24)`, bottom `(0,48)`, left `(-32,24)`. 64 wide, 48
tall, as pinned in CLAUDE.md section 1.

### Inverse projection

```
screen (sx, sy)  ->  grid (gx, gy)

gx = (sx / 32 + sy / 24) / 2
gy = (sy / 24 - sx / 32) / 2
```

Sanity identities that the Phase 0 test suite asserts directly:
`gx - gy == sx / 32` and `gx + gy == sy / 24`.

### Required API

Static functions on `IsoProjection`. Names are frozen; workstreams that need
another helper request it from the integrator rather than adding it locally.

| Function | Purpose |
|---|---|
| `grid_to_screen(g: Vector2) -> Vector2` | Fractional grid coords to screen |
| `screen_to_grid(s: Vector2) -> Vector2` | Inverse of the above |
| `world_to_screen(w: Vector2) -> Vector2` | Logical world units to screen (`grid_to_screen(w / LOGICAL_CELL)`) |
| `screen_to_world(s: Vector2) -> Vector2` | Inverse of the above |
| `cell_diamond(cell: Vector2i) -> PackedVector2Array` | The 4 screen corners of a cell, wound top/right/bottom/left |
| `cell_centre_screen(cell: Vector2i) -> Vector2` | Screen centre of a cell |
| `input_to_world_dir(screen_vec: Vector2) -> Vector2` | The Stardew rotation - see 2.1 |
| `visible_cells(screen_rect: Rect2, map_w: int, map_h: int) -> Rect2i` | Culling - see 2.2 |

`grid_to_screen` and `screen_to_grid` are linear (no translation), so the same
functions serve for both points and direction vectors. That is deliberate and
the reason `input_to_world_dir` is a thin wrapper rather than separate maths.

### 2.1 Input rotation and the speed decision

```
input_to_world_dir(s) = screen_to_grid(s) * LOGICAL_CELL
```

Because the projection is linear, inverse-projecting the input means the
player's *on-screen* velocity is exactly `s * speed`. **Apparent screen speed
is therefore constant in every direction**, which is what a player perceives
and the reason this was chosen over rotating the input 45 degrees.

The trade-off, which is expected and is not a bug: **grid-space** speed now
varies by heading. Moving up-screen covers `220 / 48 ≈ 4.6` cell-diagonals per
second at the current `move_speed`; moving right-screen covers `220 / 64 ≈
3.4`. Consequences for whoever tunes it:

- `player_cfg.move_speed` in `data/` now reads as **screen pixels per second**,
  not world units per second. Its numeric value is unchanged and needs no data
  edit, but it will *feel* different and is a tuning item for Phase 2, not a
  defect to be "fixed" mid-workstream.
- Switching to constant grid-space speed is a one-line change inside
  `input_to_world_dir` (normalise the result). Do not make that change without
  an ADR amendment; it is a design decision, not an implementation detail.

### 2.2 Culling

`visible_cells` takes the camera's screen-space rect, inverse-projects its four
corners, takes the bounding box in grid space, pads by **2 cells on every
side**, and clamps to `[0, map_w) x [0, map_h)`. The padding covers structures
whose footprint origin is off-screen but whose drawn body is not.

The bounding box of the inverse-projected corners is deliberately conservative
- it over-selects cells near the diamond's corners. That is correct and cheap;
do not "optimise" it into a per-row scan without a measured reason.

### 2.3 Facing

Facing widens from 4-way to 8-way (ADR-032). `_vector_to_facing` takes the
**already-rotated grid-space** vector and returns the nearest of the eight
`Vector2i` neighbours. `get_faced_tile()` keeps its current signature and
meaning, so every downstream consumer - tool use, feature interaction, NPC
talk, combat - is unaffected.

Tie-breaking must be deterministic and documented in the function. Exact 22.5
degree boundaries are reachable on a gamepad stick.

---

## 3. The visual-proxy architecture

Actors cannot simply be moved to their projected position: their position *is*
their physics position, and shearing collision shapes is how this conversion
goes wrong. So gameplay nodes stay where they are and gain a **visual proxy**.

```
Main (Node2D)
├── TerrainLayer        (Node2D, no y-sort)      <- FarmRenderer draws here
├── WorldVisuals        (Node2D, y_sort_enabled) <- everything that must sort
│   ├── StructureVisual (one per structure, WS-B)
│   ├── ActorVisual     (one per player/NPC/enemy, WS-C)
│   └── ...
├── FarmGrid            (logical, invisible)
├── Player              (CharacterBody2D, logical position, draws nothing)
├── NPCs / Enemies      (logical position, draw nothing)
└── IsoCamera           (WS-D)
```

Rules that follow from this and that reviewers should check:

1. **`_draw()` moves out of gameplay nodes.** `Player`, `Npc`, and `Enemy`
   stop drawing themselves; their geometry moves into their proxy. A `_draw()`
   left on a `CharacterBody2D` renders at the logical position - i.e. visibly
   in the wrong place.
2. **Proxies are children of `WorldVisuals`, never of their owner.**
   `y_sort_enabled` orders only *direct* children (CLAUDE.md trap 10). A proxy
   parented to its actor silently stops sorting.
3. **Proxies follow in `_process`, not `_physics_process`.** Projection is
   presentation (CLAUDE.md section 4 and 9.7).
4. **Proxies hold no gameplay state** and are freed with their owner. Use
   `is_instance_valid()` on the owner every frame - trap 4.
5. **Sorting is free.** Projected screen Y increases with grid depth
   (`sy = (gx+gy) * 24`), so Godot's Y-sort produces correct dimetric painter
   order with no manual depth maths. Resist adding a `z_index` scheme on top;
   the two fight.

### What does *not* sort (deliberate simplification)

Crops and soil overlays stay inside the terrain layer and do not sort against
actors. At a 48px cell height a crop dot is short enough that an actor
overlapping it reads fine, and per-crop proxies would mean up to 2,400 extra
nodes on the target map size for no visible gain. Revisit only if it looks
wrong in Phase 2 - flag it, do not unilaterally build it.

---

## 4. Phases

### Phase 0 - Foundation (sequential, ONE agent, blocks everything)

Nobody starts Phase 1 until Phase 0 is merged. Its entire purpose is to freeze
the shared surfaces so the parallel phase touches no shared file.

| # | Task | Files |
|---|---|---|
| 0.1 | **Make the initial commit.** The repo has zero commits (see section 7 risk R1). Worktrees are impossible without one. | - |
| 0.2 | Implement `IsoProjection` exactly per section 2 | `scripts/globals/iso_projection.gd` |
| 0.3 | Write its suite: round-trip identities, the two sanity identities, diamond dimensions, cull-rect correctness and clamping, input rotation direction | `tests/suites/test_iso_projection.gd` |
| 0.4 | Add `WorldVisuals` + the `ActorVisual`/`StructureVisual` base contracts, with no owners wired yet | `scripts/world/world_visuals.gd`, `scripts/world/actor_visual.gd` |
| 0.5 | Extract camera control out of `main.gd` into its own node so WS-D owns a file rather than a hunk | `scripts/world/iso_camera.gd`, `scripts/main.gd` |
| 0.6 | **Wire `main.gd` completely, against interfaces that do not exist yet.** Build the node tree from section 3, construct every renderer, and call every method the four workstreams will implement. `main.gd` is then frozen. | `scripts/main.gd` |
| 0.7 | **Pre-register all five suites in the runner**, pointing at stub suite files that pass trivially. Workstreams then fill in their own stub and never edit the runner. | `tests/run_tests.gd`, five stub files under `tests/suites/` |
| 0.8 | Add the invariant-guard suite: fails if a projection constant or formula appears outside `iso_projection.gd`, or if `Input.` appears under `scripts/` | `tests/suites/test_iso_invariants.gd` |
| 0.9 | Pre-create one dated, empty `DEVELOPMENT_STATE.md` subsection **per workstream**, so four agents append to four different regions | `DEVELOPMENT_STATE.md` |

**Exit criteria:** full suite green; `F5` still runs the game (it will look
broken or half-projected - that is expected and acceptable at this gate, and
is the only gate where it is).

Steps 0.6, 0.7 and 0.9 are the contingency, not bureaucracy. They are what
turn three guaranteed three-way merge conflicts into zero.

### Phase 1 - The four workstreams (CONCURRENT)

All four branch from the Phase 0 merge commit. None depends on another's
output; each depends only on `IsoProjection`, which is frozen.

---

#### WS-A - Terrain

**Owns:** `scripts/world/farm_renderer.gd`, `tests/suites/test_iso_terrain.gd`

Redraw the soil grid as projected diamonds. `draw_rect` becomes
`draw_colored_polygon` over `IsoProjection.cell_diamond()`. Tilled darkening,
the moisture overlay, and crop dots follow the same cell, with crop dots moving
to `cell_centre_screen`. The grid lines become diamond edges - draw shared
edges once, not twice per cell.

Add culling: `_draw` iterates only `IsoProjection.visible_cells(...)`, not the
whole map. Read `map_w`/`map_h` from `GameData` only; **no literal 30 or 20
anywhere.** This is the workstream that makes the 4x map viable.

Keep the existing dirty-flag discipline - redraw on `tile_changed`, never per
frame - and add a redraw on camera movement, since the visible set now changes
as the player walks.

**Done when:** the farm reads as a dimetric field; a 60x40 `farm_map.json`
loads and scrolls without a frame-time cliff; suite covers cull-set
correctness at map corners and the redraw-on-scroll trigger.

---

#### WS-B - Structures

**Owns:** `scripts/world/feature_renderer.gd`,
`scripts/world/building_renderer.gd`, `scripts/world/structure_visual.gd`,
`tests/suites/test_iso_structures.gd`

The heaviest workstream, and the one that makes the projection actually read as
3D. Today `FeatureRenderer` draws the cottage, both wells, two chests and the
market stall from a single node's `_draw()`. Under Y-sort a single node has a
single depth, so the player would pass in front of or behind the *entire set*
at once.

Split every structure into its own `StructureVisual` under `WorldVisuals`,
positioned at its footprint's projected anchor. Same for each placed building
in `BuildingRenderer`, including the placement ghost.

Each structure then needs a dimetric body rather than a flat rect - a
projected floor diamond plus extruded vertical faces for walls, with the
existing colour constants reused for the top face and darkened variants for
the side faces. This is where the 48px tile height earns itself.

**Collision does not move.** `_build_collision`, `_add_wall_body` and
`_add_solid_tile` stay exactly as they are, in logical space, on
`PhysicsLayers.INTERACTABLE`. Touching them is out of scope for this
workstream and would breach the projection invariant.

**Done when:** the player can walk behind the cottage's north wall and be
occluded, then walk in front of it and occlude it, with no popping at the
boundary; the market stall's open/shut redraw still works; the build ghost
tracks correctly.

---

#### WS-C - Actors and input

**Owns:** `scripts/player/player.gd`, `scripts/npc/npc.gd`,
`scripts/world/enemy.gd`, `tests/suites/test_iso_actors.gd`

Two jobs.

**Proxies:** move the `_draw()` bodies out of all three actor scripts into
`ActorVisual` instances under `WorldVisuals`. Delete `player.gd`'s `rotation =
...` line - rotating the node was a top-down affordance and reads as a sheared
smear under projection; facing is conveyed by the proxy's face bar instead.
Replace the tile-position literals at `npc.gd:38-39` and `npc.gd:80` with
`LOGICAL_CELL` (they are the last hardcoded `32.0`s outside the projection).

**Input:** route `InputManager.get_movement_vector()` through
`IsoProjection.input_to_world_dir()` before it becomes velocity, and widen
`_vector_to_facing` to 8-way per section 2.3. `InputManager` itself is **not**
modified - it correctly returns raw screen-space input, and the rotation
belongs at the consumer. No `Input.` call may appear in this workstream's
diff (CLAUDE.md section 9.4, and the Phase 0 guard suite enforces it).

**Do not touch** `combat_manager.gd`. Its hitboxes are spawned in logical space
from `_last_facing` and stay correct for free. If they visibly land wrong, the
bug is in a proxy, not in combat - report it, do not patch combat.

**Done when:** W moves the player visibly up-screen; all eight neighbouring
tiles are reachable and tillable; NPCs and enemies appear at their projected
positions and sort correctly against the player; `test_schedules` and
`test_combat*` still pass untouched.

---

#### WS-D - Camera and viewport

**Owns:** `scripts/world/iso_camera.gd`, `tests/suites/test_iso_camera.gd`

Follow the player's **projected** position. Compute map bounds by projecting
the four corners of the grid - the projected map is a diamond, so its screen
bounding box is much wider than tall, and naive bounds derived from `map_w *
TILE_W` will be wrong.

Set limits from those bounds, read map dimensions from `GameData` only, and
pick a zoom that frames the dimetric field sensibly at the 1280x720 base
viewport. Verify at wide and tall aspect ratios - CLAUDE.md section 9.3 still
applies, and nothing may hardcode the base size.

Expose the camera's screen-space rect for WS-A's culling; this is the only
cross-workstream interface, and Phase 0 freezes its signature.

**Done when:** the camera tracks smoothly with no jitter at diagonal headings,
clamps at all four map edges without showing void, and behaves at both
aspect extremes.

---

### Phase 2 - Integration (sequential, ONE agent - the integrator)

1. Merge in the order given in section 6.
2. Full suite green after **each** merge, not only at the end.
3. Manual regression sweep, per CLAUDE.md section 10: movement, day advance,
   crop growth and harvest, energy, save/load, pause, window resize. Save/load
   deserves particular attention - not because the projection touches saves,
   but because proving it did not is the cheapest confirmation the invariant
   held.
4. Consolidate the four `DEVELOPMENT_STATE.md` subsections into one coherent
   record; delete the stub headings.
5. Tuning pass: `move_speed` feel (section 2.1), camera zoom, structure face
   colours. This is the first point at which anyone should be adjusting feel.
6. Delete the Phase 0 stub scaffolding that real suites replaced.

---

## 5. Concurrency contingency

Four agents, one repository. This section is the answer to "what happens when
two of them want the same file".

### 5.1 Ownership is exclusive

Every file in the conversion has exactly one owner. No file appears in two
workstreams. The full map:

| File | Owner |
|---|---|
| `scripts/globals/iso_projection.gd` | Phase 0, then **frozen** |
| `scripts/world/world_visuals.gd`, `actor_visual.gd` | Phase 0, then **frozen** |
| `scripts/main.gd` | Phase 0, then **frozen** |
| `tests/run_tests.gd` | Phase 0, then **frozen** |
| `scripts/world/farm_renderer.gd` | WS-A |
| `scripts/world/feature_renderer.gd`, `building_renderer.gd`, `structure_visual.gd` | WS-B |
| `scripts/player/player.gd`, `scripts/npc/npc.gd`, `scripts/world/enemy.gd` | WS-C |
| `scripts/world/iso_camera.gd` | WS-D |
| `tests/suites/test_iso_*.gd` | The matching workstream, one file each |
| `DEVELOPMENT_STATE.md` | All four, but **append-only into a pre-assigned subsection** |
| `CLAUDE.md`, `AGENTS.md`, `DEEPSEEK.md`, `design/decisions.md` | **Nobody.** Already amended. A workstream that believes it needs a contract change stops and escalates |
| `data/*.json`, everything under `scripts/autoloads/` | **Nobody.** Out of scope by construction |

### 5.2 The three hotspots, and why they are pre-empted

Three files would otherwise be edited by all four agents and conflict every
time. Phase 0 removes each as a category:

- **`main.gd`** - wired completely in step 0.6 against interfaces that do not
  exist yet, so the parallel phase only implements those interfaces. Agents
  write the callee, never the caller.
- **`tests/run_tests.gd`** - all five suite entries pre-registered in step 0.7
  against passing stubs. Each agent replaces the body of one stub file.
- **`DEVELOPMENT_STATE.md`** - four separate pre-created subsections from step
  0.9. Four agents appending to four different regions of a file merge
  cleanly; four agents appending to the same tail do not.

### 5.3 If an agent needs a file it does not own

The protocol, in order. It is short on purpose:

1. **Stop.** Do not edit it, and do not work around it by duplicating the
   logic into an owned file - a second copy of the projection formula is worse
   than a merge conflict and is a contract defect besides.
2. Record what is needed and why in the workstream's `DEVELOPMENT_STATE.md`
   subsection.
3. Escalate to the integrator (or the owner) with the specific change.
4. Continue with the rest of the workstream. A blocked seam blocks one task,
   not a whole branch.

The overwhelmingly likely trigger is a missing `IsoProjection` helper. That is
why section 2's API table is explicit, and why adding to it is a Phase 0
amendment made once by the integrator rather than four divergent local
helpers.

### 5.4 If a conflict happens anyway

- **Both sides touched genuinely different concerns** - resolve by taking
  both hunks, then run the full suite. Do not hand-merge a file neither agent
  owns; hand it to the owner.
- **Both sides changed the same behaviour** - the ownership table decides.
  The non-owner's change is reverted and re-raised as a request, even when it
  is the better change. Re-litigating ownership mid-merge is how a
  four-branch merge becomes a rewrite.
- **The conflict is in `main.gd`, `run_tests.gd`, or `IsoProjection`** -
  something has gone wrong upstream of the merge, because nobody should have
  touched those. Stop the merge and find out who did and why, before
  resolving. Treat it as a process failure, not a text conflict.

### 5.5 Standing rules for every agent

- Never open the Godot editor. Everything here is scriptable and headless;
  editor-managed files stay editor-managed (CLAUDE.md section 8).
- Run `--headless --path . --import` after adding a script, before running
  tests (trap 8).
- The full suite must pass before a branch is offered for merge - not the
  workstream's own suite, the full one.
- Every code-modifying response still ends with a "How to Test This Change"
  checklist (CLAUDE.md section 10). Four workstreams do not dilute that.
- Report honestly. A workstream that half-lands is far more useful merged
  honestly than claimed complete - the integrator's merge order depends on
  knowing what is actually in each branch.

---

## 6. Merge order

Ordered by blast radius, least first, so that each merge is verified against a
progressively more complete world.

1. **WS-D (camera)** - smallest surface, and merging it first means every
   later visual check is done through the correct camera.
2. **WS-A (terrain)** - gives the world a floor to judge everything else
   against. Consumes WS-D's camera rect, so this order also validates the one
   cross-workstream interface early.
3. **WS-C (actors)** - the player becomes controllable and correctly placed
   against a correct floor. Depth sorting is trivially verifiable here because
   there is not yet anything tall to sort against.
4. **WS-B (structures)** - largest and most visual, merged last against an
   otherwise-verified world, so any sorting fault is unambiguously WS-B's.

If a branch is not ready, merge the rest in the same relative order and
integrate it after. Nothing in 1-3 depends on WS-B existing.

---

## 7. Risk register

**R1 - The repository has no commits at all.** *(Confirmed 2026-08-06: `git
log` reports no commits on `master`; 14 untracked top-level entries; no
remote.)* Fourteen sprints of work exist only as working-tree files. Worktrees
require a commit, so this blocks Phase 0 outright - but the real exposure is
that a four-agent parallel conversion would run with no baseline to revert
to. **Mitigation: step 0.1, before anything else.** Consider a remote too;
worktrees protect against merge damage, not against disk loss.

**R2 - An agent "fixes" physics into screen space.** The most damaging
plausible failure: shapes look wrong, an agent shears the collision to match,
and gameplay silently breaks in a way no headless test catches. **Mitigation:**
the section 8 invariant, the Phase 0 guard suite, and the explicit
"do not touch collision / do not touch combat" clauses in WS-B and WS-C.

**R3 - Depth sorting looks right in isolation, wrong when combined.** WS-B and
WS-C each sort correctly against terrain but potentially not against each
other, and no headless test can see it. **Mitigation:** merge order puts
structures last, against a verified world; Phase 2's manual sweep is the real
gate. Accept that this one is caught by eye.

**R4 - The projection API turns out to be incomplete mid-phase.** Four agents
each inventing a local helper is the bad outcome. **Mitigation:** section 5.3's
escalation path, and one integrator-owned amendment point.

**R5 - Feel regression.** Constant screen speed changes traversal pace, and
the dimetric field changes how big the farm feels. **Mitigation:** explicitly
deferred to Phase 2 step 5. Nobody tunes feel mid-workstream, where it would
be indistinguishable from a projection bug.

**R6 - Godot 4.7 API confidence.** `CanvasItem.y_sort_enabled`,
`draw_colored_polygon`, and `Camera2D` limits are long-stable core API and are
expected to hold, but per CLAUDE.md's API confidence rule they are flagged
here as not verifiable from memory against 4.7 specifically. Whoever first
touches each records the outcome in `DEVELOPMENT_STATE.md`.

---

## 8. Definition of done

- Full suite green, including the five new `test_iso_*` suites.
- `F5` presents a dimetric farm; the player walks screen-relative and can
  reach all eight neighbouring tiles.
- An actor occludes and is occluded by structures, correctly, at the boundary.
- A `60x40` map loads and scrolls without a frame-time cliff, with no script
  containing a literal `30` or `20` map dimension.
- `SAVE_VERSION` is still 13, and a save written before the conversion loads
  after it.
- `DEVELOPMENT_STATE.md` records every 4.7 API that could not be verified from
  memory, and every deliberate divergence.
- `CLAUDE.md`, `AGENTS.md`, and `DEEPSEEK.md` are in sync (the contract-sync
  suites already enforce this).
