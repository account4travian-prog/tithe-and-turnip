# Design Decisions (ADR log)

Append-only log of design rulings for Tithe & Turnip. Each record states its
status. When a ruling changes, add a new record that supersedes the old one;
never edit a closed record.

## ADR-001 - Project bootstrap and harness

**Status:** Accepted (2026-08-05).

The project harness is modeled on TheAscentGoDot: `CLAUDE.md` is the single
source of truth; `AGENTS.md` and `DEEPSEEK.md` are generated from it by
headless Godot scripts; hand-rolled test suites (no third-party framework)
enforce sync; all gameplay tunables live in `data/*.json`.

**Rulings overturned:** none (greenfield).

## ADR-002 - Calendar and slice boundary

**Status:** Accepted (2026-08-05).

Day length 14 real minutes (time.json `real_seconds_per_game_minute` = 0.78),
28-day seasons, wake 6 / sleep 24, empty `calendar_events` hook. The vertical
slice covers Spring only (days 1-28) with a season-end summary screen
(Restart/Quit); Summer/Autumn/Winter stay defined in data but unreachable.

**Rulings overturned:** none (greenfield); supersedes the compressed-time
proposal (7-day seasons) rejected in interview round 2.

## ADR-003 - Three-avenue lord tithe

**Status:** Accepted (2026-08-05).

Fixed 30-coin-value assessment (data-driven), payable via coin, in-kind crops
(market buy price x quality multiplier), or energy-based labor on the
steward's demesne (daily chore list, daily credit cap). Unpaid -> soft failure
at season end.

**Rulings overturned:** none (greenfield); grounded in Louis the Pious's 817
tithe decree allowing payment "in kind or in money, or in labor."

## ADR-004 - Moisture-based growth

**Status:** Accepted (2026-08-05).

Each crop has a moisture range (`moisture_min`/`moisture_max` in crops.json);
growth advances on `day_passed` only when the cell's moisture is in range.
Moisture decays daily per soil type; rain sets 1.0; watering adds a fixed
amount. Growth increment = (1.0 / days_to_mature) x soil growth multiplier.

**Rulings overturned:** the binary watered/not-watered stub.

## ADR-005 - Crop quality and seed recovery

**Status:** Accepted (2026-08-05).

Three farming-centric quality tiers (common / fine / choice) with value and
energy multipliers; weighted roll adjusted by soil type. Every harvest also
yields 1-3 seeds, independent of quality. Quality items occupy separate
inventory stacks.

**Rulings overturned:** the single-yield, no-quality stub.

## ADR-006 - Tool upgrades

**Status:** Accepted (2026-08-05).

Hoe and watering can have tiers (area, energy multiplier, water capacity)
purchased at the market; tools never break; harvest is by hand. The watering
can has limited capacity and refills at a well/pond on the property.

**Rulings overturned:** the fixed starting-tools stub.

## ADR-007 - Property and soil regions

**Status:** Accepted (2026-08-05).

The farm is a 30x20 tile property (farm_map.json) where every tile has a soil
type (loamy/sandy/rocky from soil_types.json) affecting moisture decay, growth
speed, and quality odds. The whole property is eligible for field or building.

**Rulings overturned:** the uniform single-plot grid assumption.

## ADR-008 - Exhaustion ladder (attempt-triggered)

**Status:** Accepted (2026-08-05).

Energy 0 blocks tool use; attempting a tool use at 0 energy triggers a brief
pass-out (2 game hours, energy set to 20); a second pass-out the same day
forces sleep to the next morning. The counter resets on `day_passed`.

**Rulings overturned:** the simple "tools blocked" stub; amended to
attempt-triggered per interview round 3.

## ADR-009 - Periodic manor market

**Status:** Accepted (2026-08-05).

The steward's stall is the sole legal market: buys crops (assize prices x
quality) and sells seeds, tools, and weapons; open two market days per week
(days 3, 7, 10, 14, 17, 21, 24, 28); 5% toll on all transactions.

**Rulings overturned:** the always-open "single buyer" stub; contract wording
amended (buyer and seller).

## ADR-010 - Two-layer reputation

**Status:** Accepted (2026-08-05).

Reputation is two-layer: individual opinions per villager plus community
standing (manor, village, church). Action effects are data-driven
(reputation.json) and flow through EventBus. Standing affects prices, dialogue,
and the season-end text.

**Rulings overturned:** the single-score reputation stub; amended to two-layer
per interview round 3.

## ADR-011 - Seasonal weather

**Status:** Accepted (2026-08-05).

Daily weather is rolled per season from weather.json (Spring 30% rain, Summer
10%, Autumn 40%, Winter snow). Rain auto-waters all tilled cells; snow blocks
tilling/planting. Winter is data-only in the slice.

**Rulings overturned:** the random rain/sun stub.

## ADR-012 - Voluntary church tithe

**Status:** Accepted (2026-08-05).

A voluntary church tithe: coin/crop donations at a chapel tithe box boost
church and village standing. Suggested due is 10% of the lord tithe; there is
no legal consequence for not donating.

**Rulings overturned:** none (new); adds moral depth without a hard failure.

## ADR-013 - Energy-based labor chore list

**Status:** Accepted (2026-08-05).

The lord tithe can be paid by working the steward's demesne: a daily chore
list (till/water/harvest/carry) whose tasks cost energy and yield credit
toward the tithe, with a daily credit cap. Labor credit is tracked per season.

**Rulings overturned:** the whole-day labor / pure coin-crop stub.

## ADR-014 - Combat system (approved)

**Status:** Accepted (2026-08-05).

Real-time melee + ranged combat on the main farm map. Weapons are items -
fists (default), staff, spear, pitchfork, knife (melee, varying reach), bow
(ranged, consumes arrows). Any NPC can be attacked, with witnessed-violence
reputation outcomes. Bandit raids threaten the farm and are deterred by the
player's victories (deterrence value). Thieves can come from within the
village (hidden traits, clues, accusation). Spring slice proof: spear as the
equipped weapon, one scripted bandit raid (day 15), one thief villager; full
dynamic systems deferred.

**Rulings overturned:** the "Combat of any kind" out-of-scope clause (contract
amended in v0.2).

---

# Post-slice roadmap (Sprints 6-14)

Records drafted alongside `design/roadmap.md` on 2026-08-05 after the
slice-completion design review. ADR-015..019 were **Accepted** on 2026-08-05
when Sprint 6 opened (none require a CLAUDE.md section 2 amendment). The
records below remain **Proposed** until their sprint opens; each must be
accepted - and, where it says so, the CLAUDE.md section 2 scope list amended -
before work opens. Per the authority order, check the status line before
acting.

## ADR-015 - Overwatering is a penalty, not a hard stop

**Status:** Accepted (2026-08-05). Sprint 6.

Growth is gated on `moisture >= moisture_min` only; exceeding `moisture_max`
halves the growth increment instead of blocking it. `plant()` clamps cell
moisture to the crop's `moisture_max` on planting.

**Why:** ADR-004's symmetric gate is unrecoverable in practice. Rain sets a
bare tilled cell to 100; planting a turnip (max 80) into it yields a crop that
can never grow - loamy decay of 0.5/day needs 40 days to clear, the season is
28, there is no drain action and re-tilling is refused. Tilling ahead of
planting is the natural strategy, so players reach this reliably at Spring's
30% rain rate.

**Rulings overturned:** amends ADR-004's upper moisture bound.

## ADR-016 - Sleep, energy restore, and the exhaustion ladder

**Status:** Accepted (2026-08-05). Sprint 6.

Sleep is a player action at `player_house`: advances the day, restores a
data-driven **fraction** of energy (not a full refill), regenerates health, and
autosaves. Not sleeping by hour 24 forces a collapse with a penalty. Resolves
the ADR-008 conflict by choosing one exhaustion rule and superseding the other.

**Why:** `sleep_to_next_day()` has no gameplay caller, energy is set once at
boot and never restored, `heal()` is never called, and autosave never fires -
so the contract's promised loop terminator does not exist. Separately, ADR-008
specifies a pass-out ladder while `apply_pass_out_penalty` implements a
different rule (20% coin, health 10); both exist and neither fires from energy
exhaustion. A partial energy restore keeps food meaningful once Sprint 13 adds
cooking.

**Rulings overturned:** supersedes ADR-008.

## ADR-017 - Acreage-scaled tithe and recurring upkeep

**Status:** Accepted (2026-08-05). Sprint 6.

The lord tithe scales with tilled/rented acreage rather than sitting at a flat
30 coin, and a recurring seasonal upkeep is introduced as a coin sink.

**Why:** 30 coin is roughly three turnip plants or six barley tiles once - the
title mechanic is not a decision. Separately there is no coin sink: about 530
coins buys every purchasable item, tools never break (ADR-006), and seeds
compound for free, so money accumulates with nothing to spend it on from
roughly day 14. Scaling also gives Sprint 9's land tenure its risk side.

**Rulings overturned:** amends ADR-003's fixed assessment.

## ADR-018 - Crop spoilage after maturity

**Status:** Accepted (2026-08-05). Sprint 6.

A crop left standing at full growth degrades in quality and then yield after a
data-driven number of days.

**Why:** growth clamps at 1.0 and the crop stands forever, so nothing creates a
harvest window. Spoilage is free tension, thematically apt, and gives Sprint
13's preservation chain something to solve.

**Rulings overturned:** none.

## ADR-019 - Soil scarcity and map redraw

**Status:** Accepted (2026-08-05). Sprint 6.

`farm_map.json` is redrawn so the best soil is scarce and fragmented, water
sources sit away from it, and sandy and rocky each carry a compensating upside
rather than being strictly worse.

**Why:** the map is 20 identical rows of three vertical stripes. That is 200
contiguous loamy tiles - best on decay, growth, and quality - with the well
inside them and the house adjacent. A player cannot work 200 tiles in a season,
so 400 tiles (67% of the property) are unreachable content and soil type never
becomes a choice. ADR-007's system is sound; the content defeats it.

**Rulings overturned:** none (ADR-007's map content, not its ruling).

## ADR-020 - Save slots and settings UI

**Status:** Accepted (2026-08-05). Sprint 7. CLAUDE.md v0.3 dropped
"Multiple save slots UI" from section 2's out-of-scope list; see the v0.3
changelog entry.

Named save slots exposed through a UI, plus a settings screen (window mode,
key rebinding via `InputManager`, text size).

**Why:** `SaveManager` already supports named slots; only the UI is missing.
Small amendment, and rebinding is the accessibility floor for a keyboard game.

## ADR-021 - Life skills

**Status:** Accepted (2026-08-06). Sprint 8. CLAUDE.md v0.9 added life skills
to section 2's in-scope list; no out-of-scope amendment was needed (life
skills were never on the out-of-scope list).

A `SkillManager` autoload tracking farming, foraging, combat, and labor. XP
from actions, levels and effects from `skills.json`.

**Why:** the Rune Factory "life skills" pillar from the vision is unrepresented,
and the slice has no long-arc progression beyond buying two tools.

## ADR-022 - Foraging and the commons

**Status:** Accepted (2026-08-06). Sprint 8. CLAUDE.md v0.9 added foraging to
section 2's in-scope list. Acceptance condition: rocks (flint) and lumber
(wood) also have a chance of spawning as forage, implemented as per-soil
weights in forage.json v2.

Wild plants spawn on untilled tiles by soil type and season from
`forage.json`, gathered with a dedicated action.

**Why:** thematically this is gathering on the lord's waste. Mechanically it is
the first reason to walk onto the non-loamy two thirds of the property, and it
supplies Sprint 9's building materials without a purchase-only path.

## ADR-023 - Buildings and land tenure

**Status:** Accepted (2026-08-05). Sprint 9.

A `BuildingManager` autoload with footprint validation, material and coin cost,
and multi-day construction. Additional strips of land are rented from the manor,
expanding tillable area and raising the tithe.

**Why:** buildings are already in scope under ADR-007 ("the whole property is
eligible for field or building"); only tenure is a new ruling. Together they
are the "thrive" pillar and the primary coin sink, and tenure creates the first
real risk/reward decision in the economy.

**Rulings overturned:** none; extends ADR-007.

## ADR-024 - NPC schedules, gifting, and requests

**Status:** Accepted (2026-08-05). Sprint 10. CLAUDE.md v0.4 amended section
2's scope to add NPC schedules, gifting, requests, and chapel mass; marriage
and festivals remain out of scope.

Villagers follow daily schedules driven by `TimeManager` hours. Players may
gift items (per-NPC likes, daily cap) and accept data-driven requests for coin
and opinion. Marriage and festivals remain out of scope.

**Why:** the two-layer reputation of ADR-010 has almost nothing to express
itself through - seven dialogue lines and one condition. Schedules also produce
the alibi data ADR-026's investigation depends on, and requests create the first
demand for a specific quality tier.

## ADR-025 - Manor politics and the grey economy

**Status:** Accepted (2026-08-05). Sprint 11. CLAUDE.md v0.5 amended section
2's scope to add manor court, corvee, black market, and price drift; deeper
manor politics beyond those approved systems remains out of scope.

A manor court with scheduled sessions and fines; corvee labor days called on
short notice; an itinerant black-market trader paying above assize with no toll
against a detection roll; drifting assize prices.

**Why:** this is the ruling that makes "under the shadow of the manor" a system
rather than flavour. The black market in particular weaponizes ADR-009's "sole
legal venue" rule, and corvee turns the existing chore system into a genuine
scheduling conflict.

## ADR-026 - Dynamic raids and the thief investigation

**Status:** Accepted (2026-08-05). Sprint 12. CLAUDE.md v0.6 amended section
2's scope to add deterrence-driven dynamic raids (archer/leader/night-raid
variants), defenses (fences, guard dog, hired guard), the full thief
investigation (clues, alibis, accusation, manor-court consequences), and
combat injuries persisting past sleep; the deferred-dynamic-combat
out-of-scope clause was removed.

Deterrence-driven raid frequency and scaling; archer, leader, and night-raid
variants; defenses; and a full thief investigation - clues, alibis, accusation
through a dialogue response, and trial at the manor court, with consequences
for a false accusation. Every villager carries a populated `traits` list.

**Why:** ADR-014 deferred exactly these. `raids.json` already carries the
deterrence fields and nothing consumes them; `bandit_archer` is defined and
barely spawns; Sprint 5 shipped the thief as a notification plus a coin loss and
explicitly deferred the accusation flow. Marta is currently the only villager
with a non-empty `traits` array and it reads `["thief"]`, so the culprit is
identifiable by reading the data file rather than by investigating.

**Rulings overturned:** supersedes ADR-014's deferral clause.

## ADR-027 - Crafting, cooking, and preservation

**Status:** Accepted (2026-08-05). Sprint 13. CLAUDE.md v0.7 amended section
2's scope to add skill-gated crafting at built stations (drying shed, hearth),
cooking, and preservation (drying, salting, ale); the "full crafting, cooking
recipes" out-of-scope clause was removed.

Skill-gated recipes executed at built stations. Cooked meals return more energy
and health than raw crops. Preservation (drying, salting, ale) converts
perishable harvest into storable, sellable value.

**Why:** cooking is the only thing in the roadmap that delivers the vision's
"survive" pillar - food is otherwise an optional top-up. Preservation answers
ADR-018's spoilage clock and turns the economy into a production chain instead
of raw-crop arbitrage.

## ADR-028 - Livestock

**Status:** Accepted (2026-08-06). Sprint 14. CLAUDE.md v0.8 amended section
2's scope to add livestock (chickens and one goat); marriage and festivals
remain out of scope.

Chickens and one goat. Daily feed and water, shelter, products on a cycle,
happiness driving product quality via the existing tiers, and animals as raid
targets.

**Why:** livestock is core to the genre and to the medieval premise. The small-
cast restriction applies to animals as it does to villagers. Bandits driving off
the goat is both a real period threat and a clean way to make ADR-026's
deterrence consequential.

## ADR-029 - Setting, tone, and the content authority

**Status:** Accepted (2026-08-06). Content pass C1.

The game's fiction gets an authority document, `design/world_bible.md`, sitting
below `CLAUDE.md` and this log but above every content decision. Locked rulings:

- **Register: grounded and hopeful.** A harsh world with warm people. Real
  pressure, but neighbours help and small wins land. Not grimdark; not cozy-
  without-stakes.
- **Anchoring: invented but plausible.** A fictional manor, village, and lord
  in an England-shaped world. Real institutions (manor court, tithe, corvee,
  assize prices), no real people, places, or dates.
- **Cast stays at six.** Depth over breadth, extending the small-cast
  principle ADR-028 applied to animals.

**Why:** the systems layer can express far more than the content layer says -
36 total lines of dialogue against 14 sprints of mechanics. The generic feel of
what exists traces to a missing source of truth: nobody writing a line had a
document stating what the world is, so the only thing the lines could be was
generic-medieval. The bible also codifies the diction the UI already commits to
("Vigour" not "Stamina", "Coin" not "Gold", "Satchel" not "Inventory"), which
is currently undocumented and will drift the moment anyone adds a panel.

## ADR-030 - Festivals

**Status:** Accepted (2026-08-06). Owner ruling. CLAUDE.md v0.11 amended
section 2 to add festivals to the in-scope list. **Supersedes** the "marriage
and festivals remain out of scope" clauses recorded in ADR-024 and ADR-028;
those records stand unchanged as history.

Data-driven village gatherings on fixed calendar days from a new
`festivals.json`. One festival per season, all four defined in data, only the
Spring festival reachable in the Spring slice - the same season-aware data
convention every other system follows, so unlocking the rest stays a data
change. A festival declares its day, hour, place, and standing effects.
Attending at the right day/hour/place moves village and church standing;
missing one carries no legal penalty, consistent with ADR-012's voluntary
church axis, but forfeits the standing on offer. Festival days also gate
their own dialogue via the C2 condition vocabulary.

**Why:** the calendar already has texture the player cannot see - market days,
court days, corvee, mass. Festivals are the positive beat in that rhythm, and
they cost almost nothing structurally: TimeManager supplies the calendar,
ReputationManager the axes, NPC schedules the gathering. Explicitly NOT a new
simulation layer - a festival that needed its own rules engine would be a
different, larger ADR.

**Boundary:** no mini-games, no festival-exclusive items, no art. A festival is
a scheduled place, a window, dialogue, and a standing effect.

## ADR-031 - Marriage: courtship and spouse life

**Status:** Accepted (2026-08-06). Owner ruling. CLAUDE.md v0.11 amended
section 2 to add marriage to the in-scope list. **Supersedes** the marriage
exclusions recorded in ADR-024 and ADR-028; those records stand unchanged as
history.

Candidates are the four village villagers (Hilda, Cedric, Marta, Bram). The
priest is celibate and the steward is manor staff; neither is a candidate, and
that is fiction, not a technical limit.

- **Courtship** gates on the individual-opinion axis ReputationManager has
  tracked since Sprint 4 but has never gated anything on, advanced by the
  existing gifting and request systems.
- **Proposal** unlocks at an opinion threshold and is offered through the
  existing DialoguePanel response mechanism.
- **Ceremony** at the chapel, reusing the existing chapel feature tile.
- **Spouse life:** the spouse moves into the player's cottage, gains a
  home-based schedule (NPC schedules already support home/work anchors),
  greets the player on waking, occasionally completes a farm chore, and is
  giftable outside the normal daily cap.

**Why:** the relationship substrate is already built and underused - opinions
are tracked and never gated, gifting moves a number with no destination.
Marriage gives the whole social layer a terminal goal, which the slice
currently lacks. Marta being both a marriage candidate and the thief
(ADR-026) is a deliberate collision worth keeping.

**Boundary (the new out-of-scope line):** children, in-laws, divorce, and
rival suitors are out. Marriage consumes existing systems - opinion,
schedules, buildings, chores - and must not grow a simulation of its own.

**Save impact:** implementation will require a SAVE_VERSION bump and a
migration (spouse id, courtship state, ceremony flag). None in this
amendment itself.

## ADR-032 - Dimetric projection

**Status:** Accepted (2026-08-06). Owner ruling. CLAUDE.md v0.12 amended
sections 1, 2, 5, 8, 9, and 12. **Supersedes** section 9.5's `TileMapLayer`
requirement, specified in v0.1 and never built.

The world renders in a **dimetric projection at a `64 x 48` screen tile**
(2:1.33), replacing the orthogonal top-down presentation the project has had
since bootstrap. The shallower-than-classic angle was chosen over true 2:1
isometric for headroom: structures get vertical room to read as buildings
rather than as floor decals, and the plane looks less like a tilted table.

**The projection is presentation-only.** This is the load-bearing half of the
ruling and is mirrored into section 8 as an invariant:

- The simulation grid, `FarmGrid`, physics bodies, collision shapes, weapon
  reach, enemy pathing, and every save payload stay axis-aligned at the
  existing 32-unit logical cell. None of them learn about the projection.
- Conversion happens in exactly one file, `scripts/globals/iso_projection.gd`.
  A projection formula written anywhere else is a defect.
- Gameplay nodes keep logical `global_position`. What the player sees is a
  **visual proxy** under one `y_sort_enabled` container, positioned by the
  projection each `_process`.

**Depth ordering** is per object and continuous via `y_sort_enabled`, not the
per-layer `move_child` ordering `main.gd` uses today. Structures larger than
one cell (the cottage, the market stall, player-built buildings) split into
individually-sortable nodes so an actor can pass behind them. Terrain draws
beneath the sort container and does not participate.

**Input is screen-relative** - the convention the owner picked, and the one
Stardew Valley uses. `InputManager` continues to return a screen-space vector;
the rotation into grid space happens once, at the point of entry, so "up"
always means visually up and never a grid diagonal. Facing, and therefore the
faced tile that all interaction targets, is grid-relative downstream of that
rotation.

**Facing widens from 4-way to 8-way**, as a forced consequence of the above
rather than a separate preference. Under the rotation the four screen
cardinals (W/A/S/D) map onto the four grid *diagonals*, and the four screen
diagonals (W+D and friends) map onto the grid cardinals. A 4-way facing would
therefore leave four of every tile's eight neighbours permanently
untargetable, and `_vector_to_facing`'s `absf(x) >= absf(y)` tie-break would
resolve a pressed W into a silent west-facing. Widening to 8 makes every
neighbour reachable and removes the tie. Nothing downstream cares: tool use,
interaction, and combat all consume `get_faced_tile()`, not the facing value
itself.

**Scale.** The 30x20 property map is roughly a quarter of the intended final
size. The render layer therefore culls to the visible rect and reads map
dimensions from `farm_map.json` only; no script may assume 30x20. This is
built now rather than retrofitted, on the owner's ruling, because the render
layer is being rewritten anyway and doing it twice is the expensive path.

**Why now:** the cost of a projection change is normally dominated by
re-authoring art at a new angle, and this project has no art - the
geometric-primitives-only rule means every drawable is `draw_rect` and
`draw_circle` in four files, and grid-to-world conversion exists at only four
sites. The conversion will never again be as cheap as it is before art
exists. The simulation layer, which is the bulk of fourteen sprints of work,
is untouched by it.

**Why not `TileMapLayer`:** section 9.5 had promised one since v0.1. An
isometric `TileMapLayer` needs a `TileSet` with texture atlases, and the
geometric-primitives-only rule has nothing to put in one. It would also make
every terrain change an editor session, which cannot run headless and would
serialise work that is otherwise parallel. Immediate-mode renderers keep the
whole conversion scriptable and testable. The off-ramp survives: because all
projection math sits behind one seam, adopting `TileMapLayer` after real art
exists is a contained change rather than an excavation.

**Boundary:** no elevation in any form - no height values, no z-levels, no
terrain slopes, no multi-storey structures, no jumping or flying, no cliffs or
bridges. The projection is a flat plane drawn at an angle. Anything needing a
third axis in the *simulation* is a new ADR, not an extension of this one.
No art assets, and no change to the game's loop, pacing, or tone.

**Save impact:** none, and none is permitted. Save version stays at 13. Work
under this ADR that finds itself wanting a migration has violated the
presentation-only invariant and should stop.

**Execution:** `design/IsometricConversion.md` (workstreams, file ownership,
merge order) and `design/IsometricConversion_Worktrees.md` (parallel-agent
runbook).

## ADR-033 - Cast expansion and tiering

**Status:** Accepted (2026-08-06). Owner ruling, content pass C1.
**Supersedes** ADR-029's "cast stays at six" clause **only**; ADR-029's tone
(grounded and hopeful) and anchoring (invented but plausible) rulings stand
unchanged, as does the record itself.

The cast grows from six to a **tiered roster**, sized by what each character
is required to carry rather than by a flat headcount:

- **Tier 1 - Principals (8).** Full character sheet, five standing bands,
  seasonal and event dialogue, gift preferences, request templates. Marriage
  candidates and investigation roles are drawn exclusively from this tier. The
  existing six plus two: **a neighbouring tenant** (the player's peer - same
  age, same circumstance, visibly succeeding or failing alongside them) and
  **a holder of economic power outside manor and church authority** (miller or
  alewife), which gives the black-market thread of ADR-025 a face it has never
  had.
- **Tier 2 - Residents (6-8).** A trade, a schedule, a handful of lines, gift
  preferences. No romance, no investigation role. They populate the village and
  give gossip somewhere to travel.
- **Tier 3 - Named background (unbounded, free).** Referenced inside other
  characters' dialogue and never instantiated as a node. Costs nothing.

Total instantiated: **14-16**, of which 8 are deep.

**Why:** the genre standard is roughly 30 named NPCs with 10-12 romanceable
(Stardew Valley 34/12; Story of Seasons: Friends of Mineral Town ~32/12;
Fields of Mistria ~25/10; My Time at Portia 50+/~26). Six is far below that,
and ADR-031 asks four of the six to carry marriage while ADR-026 asks one to
carry the investigation - a load the cast cannot bear. The current roster also
has a structural hole the genre never has: **no peer**. Every existing
character is an authority (steward, priest) or a neighbour of another
generation; nobody does the player's job under the player's constraints.

**Why tiering rather than a flat 12:** every game in the benchmark carries
character on portraits and sprites. The geometric-primitives-only rule means
this project has **no** visual characterisation, so each character costs
strictly more words here than the same character costs Stardew. Tiering buys
the appearance of a populated village at roughly double the current writing
cost rather than five times it.

**Boundary:** Tier 1 stays at 8. Marriage candidates remain a subset of Tier 1
and the priest and steward remain excluded on fiction grounds (ADR-031). A
ninth principal is a new ADR. Tier 2 characters may not acquire heart-event
equivalents, romance, or investigation roles without promotion, and promotion
is an amendment.

**Contract impact:** `CLAUDE.md` section 2's marriage entry named "the four
village villagers" as candidates and needed amending before candidates could
be authored beyond that set. **Landed 2026-08-07 as `CLAUDE.md` v0.13 (X10);
`AGENTS.md`/`DEEPSEEK.md` regenerated.**

**Save impact:** none from this record. Villager identity is data
(`villagers.json`); individual opinions are keyed by villager id and already
serialize as a dictionary, so added characters need no migration.

## ADR-034 - The region: multiple maps and zone-keyed world state

**Status:** Accepted in principle (2026-08-06), **implementation deferred** by
owner ruling (option (c): design now, build later). Content passes C1-C4
proceed against this record; no code is written under it until it is
scheduled as a systems sprint in `roadmap.md`.

The world stops being one grid. It becomes a **region of discrete zones**:

- **The vale of the Nettle**, a day's walk end to end. Mountains stand blue
  and distant to the north and are never reached - scenery, weather, and the
  direction every "somewhere else" story points. Uplands and hills ring the
  vale: thin soil, sheep, the commons, the wilderness. The vale floor is the
  good land. The **Harrow Road** runs its length toward **Coldwich**, a market
  town that is a destination rather than a zone.
- **Zones (8-10):** the player's plot; the village of Nettleford; the manor;
  two or three wilderness zones (upland, wood, riverbank); two or three
  neighbouring tenant plots.
- The player's plot is enlarged and holds **only** the player's holding -
  home, buildings, fields. The chapel, market stall, and steward's demesne
  move to the village and manor zones respectively.

**Why:** the shipped 30x20 grid carries the player's farm, the village, the
chapel, the market, the lord's demesne, and six villagers' houses
simultaneously, at a scale where they are all within a few seconds' walk. It
reads as a diagram of a manor rather than a place. Separating zones also gives
every shipped system a geography it currently lacks: soil types become
landscape (loam on the vale floor, sand by the brook, rock on the upland),
forage and raids acquire an origin, and the market and court acquire a civic
setting.

**What this breaks** (the reason it is a systems sprint and not a content
pass):

- `CLAUDE.md` section 5's scene flow (`title_screen -> main`) and section 9.5's
  single-`FarmGrid` world representation.
- `farm_map.json` - one grid, one feature list, no zone key.
- `tenure.json` - strip rectangles defined against the single grid. Rent and
  tenure must be re-expressed against the new plot.
- NPC schedules - `home`/`work` anchors are bare `x`/`y` with no zone, so a
  villager cannot currently be *somewhere else*.
- `FarmGrid` - one `Vector2i`-keyed dictionary; needs a zone in the key space
  or one grid per zone.
- Save v13 - `farm.cells` is a flat array with no zone dimension. **This will
  require a SAVE_VERSION bump and a migration**, unlike ADR-032.
- ADR-007 (property and soil regions), ADR-019 (soil scarcity and map redraw),
  and ADR-023 (buildings and land tenure), all of which assume one map.

**Relationship to ADR-032:** compatible and helped by it. ADR-032 already
rules that the 30x20 map is "roughly a quarter of the intended final size",
requires the render layer to cull to the visible rect, and forbids any script
from assuming 30x20. That work makes the render layer size-agnostic ahead of
this ADR. It does **not** make it zone-aware, which remains this record's
problem. ADR-032's presentation-only invariant is unaffected: zones are
simulation state, not projection.

**Why deferred:** tone, diction, and character interiority - the bulk of
C1-C4 - do not depend on geography, so halting content work for a multi-sprint
systems change would waste writing that can be done today. But the world bible
must describe the world that will exist or it gets written twice, which is why
this record is Accepted now rather than left as a note.

**Boundary:** no elevation, consistent with ADR-032 - zones are flat planes
side by side, not a heightmap. No overworld travel simulation, no travel time
cost, no random encounters between zones. Coldwich and the mountains are
fiction, not zones. Zone count stays at 8-10; a twentieth zone is a new ADR.

## Decision note - Spring Feature Expansion: package accepted with amended scope

**Status:** Recorded (2026-08-07). Owner ruling, walking `design/proposals/
Proposal_Spring_Feature_Expansion.md` section 12's checklist. Not a numbered
ADR - **ADR-035** stays reserved for the dialogue condition evaluator per the
proposal's own section 9 numbering; this note records the package-level
decisions the checklist called for.

The five-item package (E1 Spring Crop Pack, E2-trim Soil Fertility, E4+E5
Dialogue Engine 2.0 + Festivals, E6-trim Market Board Orders, E12 Foraging
2.0) is **accepted**, but not as printed - the owner restored two of the four
items the proposal recommended deferring, so the package is now larger than
Pro's own recommendation:

| Checklist item | Decision | Diverges from proposal's recommendation? |
|---|---|---|
| Accept package | Yes | matches |
| Restore compost bin (E2) | **Yes - restored** | **diverges** (Pro recommended deferring; "spoilage volume doesn't justify the UI") |
| Restore supply-pressure curve (E6) | **Yes - restored** | **diverges** (Pro called this "the single most over-engineered element of the original R2a design") |
| Restore E3 skill perks / E7 livestock expansion | No - stay deferred | matches |
| SAVE_VERSION bump timing | Single v14 at Phase 3 end | matches |
| Livestock (E7) ADR timing | Later, dedicated ADR-028 amendment | matches |
| Spring festival contest | **Stat-only comparison** (e.g. a "best harvest" readout, no interactive mini-game) | **diverges** (Pro's default was no contest mechanics) |
| Content authoring (C1-C6) start | C2 at Phase 2 exit; C1/C3-C6 in parallel now | matches |

**Consequences for the delivery plan (section 7 of the proposal):**

- **E2** reverts to its full, untrimmed R2a design: the compost bin, the
  `compost` item, and spoiled-crop-to-compost crafting land alongside
  fertility in Phase 1, not as a post-slice item. Needs its own data/save
  fields beyond what section 10's trimmed migration spec lists.
- **E6** reverts to the full dynamic-pricing design (0.5x-1.5x band with
  decay) instead of the board-orders-only trim, landing in Phase 3. This was
  the proposal's single flagged highest-risk-of-overrun element; Phase 3's
  gate criteria should include explicit balance/tuning verification, not just
  a green suite.
- **Festival contest** has no existing spec in any proposal round output. It
  needs a short design pass before Phase 3 and an **amendment note to
  ADR-030** (already anticipated in the proposal's section 9 ADR list, timing
  now fixed to "before this decision's Phase 3 gate") - ADR-030 as it
  currently reads rules out contest mechanics ("no mini-games"), and a
  stat-only comparison needs that boundary explicitly loosened, not silently
  crossed.
- **Section 10's consolidated SAVE_VERSION 14 migration spec is now
  incomplete** - it explicitly excludes compost state and supply-pressure
  data as "deferred." Both must be added to the v14 field table before Phase
  1 (compost) and Phase 3 (supply-pressure) implementation, respectively.
- **Section 11's risk register item 1** ("scope creep... owner freeze on the
  deferred list") no longer holds for compost and supply-pressure - the
  freeze now applies only to E3 (skill perks) and E7 (livestock expansion),
  which remain deferred behind their own future ADRs per this same checklist.

**X10** (the `CLAUDE.md` marriage-candidate amendment ADR-033 left owed) was
landed separately as `CLAUDE.md` v0.13, ahead of and independent of this
package - see ADR-033's "Contract impact" line above.

**Save impact:** none from this note directly - it amends what the future
v14 migration must contain, not any shipped save data. No code has been
written under this decision yet.

## Decision note - ADR-018 amendment: rot produces a spoiled_crop pickup

**Status:** Recorded (2026-08-07), implemented same day as part of Phase 1
of the Spring Feature Expansion. Amends ADR-018 (Crop spoilage after
maturity, Accepted 2026-08-05, Sprint 6) - a new record per the append-only
convention (`design/decisions.md`'s own header: "never edit a closed
record"), not an edit to ADR-018 itself.

**What changes:** ADR-018's two-stage rot still degrades quality past
`spoil_after_days` and still clears the crop past `2 * spoil_after_days` -
that ruling is untouched. What's new: the moment the crop past
`2 * spoil_after_days` clears, the cell now also gets a `spoiled_crop`
forage pickup (`forage_item_id`/`forage_yield`, the same fields every other
forage spawn already uses), gathered through the ordinary forage action
rather than granted directly - `FarmGrid` still never touches inventory.
Previously the crop was destroyed with nothing produced.

**Why:** decided in `Compost_Spec_Addendum.md` section 8 while pulling
E2's compost design out of R2a - compost's declared input (`spoiled_crop`)
had no production source anywhere in the shipped code, since ADR-018's rot
only ever cleared the cell. Two ways to close the gap were weighed there;
the owner chose changing ADR-018's behavior over routing compost through a
different input, because it's truer to the fiction the whole fertility
system is going for - "even your mistakes feed the land."

**Implementation:** `scripts/world/farm_grid.gd`'s `advance_day()` rot
branch; no new save field (spoiled_crop is an ordinary inventory item once
gathered, ADR-018's own save shape is unaffected); `tests/suites/
test_soil_fertility.gd` / `test_foraging_expansion.gd` cover the fertility
and dig-mechanic sides of Phase 1, though the rot-produces-an-item change
itself is exercised indirectly (compost's own inputs) rather than by a
dedicated rot-drop test - a gap worth a direct assertion if this behavior
is touched again.

**Rulings overturned:** none of ADR-018's letter - the two-stage timing and
quality-then-yield-loss sequence are unchanged. Only the "nothing is
produced" consequence of the second stage is superseded.

## ADR-035 - Dialogue condition evaluator and vocabulary

**Status:** Accepted (2026-08-07), implemented same day as Phase 2 of the
Spring Feature Expansion. Number reserved for this record by
`Proposal_Spring_Feature_Expansion.md` section 9 (ADR-034 was already taken
by the region record). Pulled from R2a/R2a-continuation's E4 deep design
(`.deepseek/outputs/proposal_r2a_cont_out.md` lines 226-347), reconciled
against the live code the same way the Phase 1 addenda were.

**The dead-content bug this fixes:** `main.gd:197` selects a dialogue line
with `lines[0] if not lines.is_empty() else ...` where `lines` is every
line whose conditions currently pass, in file order - not the best match,
just whichever was authored first. `GameData.get_dialogue_for()` and
`_dialogue_conditions_pass()` are untouched by this record (an existing
test, `test_reputation.gd`, asserts their exact current return shape) - the
fix is a second, parallel path.

**The mechanism:**
- **`ConditionEvaluator`** (`scripts/world/condition_evaluator.gd`) - a
  stateless static function, `evaluate(conditions: Dictionary, context:
  Dictionary) -> bool`. AND-only; OR is two line entries, same as every
  other data-driven filter in this project. Vocabulary: `time` {min,max},
  `season`, `weather`, `is_market_day`, `is_mass_day`, `is_festival`,
  `has_item` {id,min}, `skill_level` {id,min}, `player_money`/`player_energy`/
  `player_health` {min}, `standing` {axis,min}, `opinion` {npc,min},
  `event_flag`, `not`. The old `"reputation.AXIS": {min}` dot-key shape
  (dialogue.json v3's only condition form) is preserved as a recognized
  key, not migrated away - existing content keeps working unedited.
- **`DialogueManager`** (new autoload, `scripts/autoloads/dialogue_manager.gd`)
  - builds a context dict per NPC from `TimeManager`/`WeatherManager`/
  `ReputationManager`/`SkillManager`/`PlayerState`/`GameData`, filters that
  NPC's lines through `ConditionEvaluator`, picks the highest `priority`
  (random among exact ties), applies `frequency` gating via its own
  `dialogue_history`, and fires `set_flag` through
  `PlayerState.set_event_flag()` directly - no new `EventBus` round-trip;
  Phase 1 already established direct calls as this project's pattern for
  flag-setting, and R2a's proposed `EventBus.event_flag_set` signal would
  be a second way to do the same thing.
- **`main.gd`'s one necessary edit:** `_on_npc_interacted` swaps
  `GameData.get_dialogue_for(...)`/`lines[0]` for
  `DialogueManager.get_next_line(npc_id)`. R2a's own design claimed this
  needed zero `main.gd` changes via a `DialogueUI.start()` abstraction -
  checked against the live file and no such abstraction exists; the swap is
  one line, everything downstream (request-override, investigation-clue
  append, the final `show_dialogue()` call) is untouched.

**Backward-compatibility correction made during implementation, not left
as R2a drafted it:** R2a's compatibility claim ("existing lines have no
priority - default 0 - and continue to work exactly as before") does not
hold as stated. Each NPC's five reputation-threshold lines use `min`
conditions that are **not mutually exclusive** - a standing of 60 satisfies
all five simultaneously (60 >= 50, >= 10, >= -9, >= -49, >= -100). Today's
`lines[0]`-of-first-match happens to always return the friendliest matching
line only because the file lists thresholds in descending order - an
accident of authoring order, not a rule the new priority-based selector
would reproduce if every old line defaulted to priority 0 (ties would
resolve **randomly**, a real behavioral regression, not a preserved
default). Fixed by backfilling explicit priority on the existing 36 lines
during the v3->v4 upgrade: each NPC's five threshold lines get descending
priority 40/30/20/10/0 (matching file order exactly, so selection is
provably identical to today for every standing value), and each NPC's
unconditioned line gets priority -999, promoted from an implicit sixth
option to R2a's own explicit fallback marker.

**Data schema:** `dialogue.json` v3 -> v4, additive per line: `priority`
(int, default 0), `frequency` (enum: `always`/`once_per_conversation`/
`once_per_day`, default `always`), `set_flag` (optional string).
`GameData` validates at load: unknown condition keys are rejected
(push_error, line skipped), `frequency` must be one of the three values,
and every `npc_id` appearing in the file must have at least one
conditionless line.

**Simplification flagged, not hidden:** `once_per_conversation` has no
distinct behavior from `always` in this engine today. `DialoguePanel`
shows exactly one line and closes on a response - there is no multi-turn
conversation loop that calls `get_next_line` more than once per
interaction, so nothing currently exercises the difference. The vocabulary
supports it for when conversations become multi-turn; the implementation
treats it identically to `always` until then, noted here rather than
silently no-op'd.

**Pre-existing wart carried forward, not fixed:** `is_mass_day` duplicates
`main.gd`'s hardcoded `MASS_DAY := 21` / `MASS_HOUR := 9` constants (there
is no `church.json` field for either - checked). Out of scope for this
record to unify; flagged so it isn't mistaken for a new magic number this
ADR introduced.

**Save impact:** a new top-level `dialogue` block (`{npc_id: Array[int]}` of
spoken line indices, cleared on `day_passed` - only `once_per_day` tracking
needs persistence), owned and serialized by `DialogueManager` itself -
corrected from R2a's "PlayerState gains dialogue_history" during
implementation: `DialogueManager` is the state's actual owner, and every
other autoload-owned save state in this project (`crafting`, `skills`,
`animals`, `buildings`) already gets its own top-level block rather than
being folded into `player`, so this follows that existing convention
instead of introducing a one-off exception. `player.event_flags` already
exists (Phase 1, E12) and is unaffected. Requires **SAVE_VERSION 14 -> 15**
(Phase 1 already closed v14; this is the next additive rung, not a
reopening of it).

**DESKTOP step landed (2026-08-07).** `DialogueManager` is registered in
`project.godot`'s `[autoload]` section via `docs/register_autoloads.gd`
(the same engine-serialization approach `docs/bootstrap_project.gd` uses,
applied to this narrower recurring case rather than hand-editing the file)
- full suite re-verified green with the autoload live. Its
logic is headless-testable via a `configure_for_test` injection seam
(mirrors `CraftingManager`'s multi-dependency pattern) regardless of
whether the autoload is registered yet, but `main.gd`'s bare `DialogueManager`
reference will not resolve in the live game until a human completes that
step in the editor.

**Anti-bloat, carried from R2a unchanged:** the evaluator is a flat AND
filter over a closed, load-validated key vocabulary - never a scripting
layer. A line that needs branching logic is authored as multiple entries
with `event_flag` gating, not a new condition primitive.

**Conflicts:** none. Compatible with ADR-024 (gifting/requests, which
`_on_npc_interacted` still overrides dialogue text for), ADR-030
(festivals - `is_festival` is wired in the vocabulary now, always false
until `FestivalManager` exists in Phase 3), ADR-032 (dialogue is pure UI,
no projection concern).

## ADR-036 - Festivals implementation (ADR-030 realized)

**Status:** Accepted (2026-08-07), implemented same day as Phase 3 of the
Spring Feature Expansion (E5). Number reserved by
`Proposal_Spring_Feature_Expansion.md` section 9's numbering sequence -
ADR-035 is the dialogue engine (Phase 2), ADR-037 is reserved for the
parallel E6 (dynamic market/board orders) workstream. Pulled from R2b's
deep design (`.deepseek/outputs/proposal_r2b_out.md` lines 94-237),
reconciled against the live code the same way every prior phase's design
pull has been.

**The mechanism, closely mirroring the shipped chapel-mass check rather
than R2b's proposed autoload-only design (see corrections below):**
- **`data/festivals.json` v1** - all four seasons defined (id, season, day,
  start_hour, end_hour, location {x,y}, standing_effects {village, church}).
  Only Spring's `springturn_blessing` (day 18, hours 10-14, chapel tile
  10,15, +10 village/+8 church) is reachable in the slice - the same
  season-gating convention every other system in this project already
  follows (cabbage, truffle, ...).
- **`FestivalManager`** (new autoload) is a pure query surface: given the
  current day/hour, `get_active_festival() -> Dictionary` returns the
  matching festival entry or `{}`. No signals, no schedule-override
  methods, no internal "attended" tracking - it holds no state of its own
  at all.
- **Attendance** is checked in `main.gd`'s existing `_on_minute_passed`,
  immediately alongside the mass-day check it already contains - not a
  separate signal-driven system. Standing on the festival's tile
  (`player.get_current_tile()`/`get_faced_tile()`, the exact predicate
  mass attendance already uses) during the active window calls
  `ReputationManager.modify_standing(axis, amount)` for both axes, gated
  by a `player.event_flags` entry (`"festival.attended_<id>"`) so it only
  ever fires once - reusing Phase 1's `PlayerState.set_event_flag`/
  `has_event_flag`, not a new `attended_festivals` array.
- **NPC schedule override:** `npc.gd`'s existing `_update_anchor(hour)`
  (each NPC already owns its own home/work anchor logic - there is no
  central `NPCManager` to hook into) queries `FestivalManager` for an
  active festival and uses its location as the anchor when present,
  falling through to the normal work/home logic otherwise.
- **Dialogue (E4):** `DialogueManager.build_context()`'s `is_festival`/
  `festival_id` fields - hardcoded `false`/`""` as a Phase 2 placeholder
  precisely for this moment - now query `FestivalManager.get_active_festival()`
  for real. `ConditionEvaluator`'s `is_festival` condition (bool or string
  form) already existed since Phase 2; nothing new needed there.
  "Has attended" gating doesn't need a new condition type either - it's
  just `event_flag: "festival.attended_springturn_blessing"`, already
  supported.

**Three corrections to R2b's design made during implementation, all
because the live code didn't match what R2b assumed - the same category
of gap every prior phase's ADR has documented, not a new problem:**
1. **`TimeManager.hour_passed` does not exist.** The real signals are
   `minute_passed(hour, minute)`, `day_passed(day, season, year)`,
   `season_changed(season)`, `year_passed(year)` - checked directly against
   `scripts/autoloads/time_manager.gd`. `main.gd` already has a
   `_on_minute_passed` handler wired to `minute_passed`; festival
   attendance rides in that same handler rather than a new connection.
2. **`ReputationManager.apply_standing(axis, value)` does not exist.** The
   real method is `modify_standing(axis: String, amount: float)` -
   `apply_action(action_id, target_npc_id)` also exists but routes through
   a named `reputation.json` action with its own fixed deltas, which
   doesn't fit festival-specific per-festival amounts already defined in
   `festivals.json`.
3. **R2b's claim of "zero edits to main.gd" does not hold**, for the same
   reason it didn't hold for E4 (ADR-035): there is no centralized
   "check if the player is standing on tile X" query surface outside
   `main.gd` - the existing mass-attendance check already lives there
   directly, using the live `player` node reference `main.gd` holds.
   Rather than building a new autoload-side position-query mechanism
   R2b never specified how to wire, festival attendance follows the
   already-shipped, already-tested mass-attendance pattern exactly. This
   is the third phase in a row (E1/E4/E5) where a design pull's "no
   main.gd changes" claim needed correcting once checked against the
   real file - worth naming as a pattern: **R2b/R2a's claims about what
   `main.gd` needs are consistently unreliable** and should be verified,
   not assumed, on every future phase that touches player interaction.

**`FestivalManager`'s DESKTOP step landed (2026-08-07)**, alongside
`DialogueManager`'s, via `docs/register_autoloads.gd`. `main.gd` and
`npc.gd` still reach it via `get_node_or_null`, not a bare reference - the
same parse-safety fix Phase 2 already established, applied proactively here
rather than
discovered via a failed parse-check.

**Save impact: none.** Attendance rides entirely on
`player.event_flags`, which already exists and already round-trips.
`FestivalManager` holds no state of its own to serialize - "is a festival
active right now" is a pure function of `TimeManager.day`/`hour` against
static data, recomputed on demand, never persisted. **No SAVE_VERSION
bump for this record** - the parallel E6 workstream's own v16 bump (if it
lands one) is unaffected by this.

**Balance guardrails, carried from R2b unchanged:** standing gains
(+10 village/+8 church) are modest, once-per-festival via the event-flag
gate prevents any stacking exploit, and the 4-hour window is long enough
to notice without trapping the player in a forced scene - the player can
still farm, forage, or fight during it; festivals are not instanced.

**Anti-bloat:** no mini-games, no exclusive items, no new UI beyond what
the HUD already shows (day/hour). The entire mechanic is a data lookup, a
tile-position check reusing an existing predicate, and a reputation delta
reusing an existing method - matching ADR-030's boundary exactly, and
`CLAUDE.md` section 2 already listed festivals as in-scope, so no contract
amendment is needed beyond noting the implementation is now real rather
than planned.

**Conflicts:** none. Fully satisfies ADR-030 with no deviation. Compatible
with ADR-024 (schedules), ADR-035 (dialogue, both hooks already
anticipated), ADR-012 (church stays voluntary - no manor standing change
from festivals, matching mass).

## ADR-037 - Dynamic local economy: supply pressure and the town board

**Status:** Accepted (2026-08-07), implemented same day as Phase 3 of the
Spring Feature Expansion (E6, the untrimmed version). Number reserved for
this record by the E6 task brief (ADR-035 was taken by the dialogue engine,
ADR-036 by the parallel E5 festival workstream). Pulled from R2a's E6 deep
design (`.deepseek/outputs/proposal_r2a_cont_out.md` lines 349-457),
reconciled against the live code the same way Phase 1/2 records were.

**The two systems this record locks:**

- **Player-only supply pressure.** `TitheManager` tracks `crop_pressure`
  (item_id -> float, positive = oversupply). Selling a crop at the market
  stall adds the quantity sold to that item's pressure; every night pressure
  decays toward zero by a fixed fraction (`economy.json`
  `pressure_decay_per_day`). On each market day the pressure is converted
  into a per-item price multiplier - `1.0 - clamp(pressure / scale,
  -(cap-1), 1-floor)` - locked at market open (proposal open-question #2:
  repeated mid-day sales never move today's prices) and bounded to the
  `economy.json` price band (0.5x-1.5x by default). There are **no AI
  farmers and no global supply chain**; the only external force remains the
  small random drift ADR-025 already shipped. The black market is untouched
  by pressure (its fixed premium and no-toll status make it attractive
  exactly when the legal market is glutted).
- **Board orders as fetch quests.** A new `town_board` feature tile in
  `farm_map.json` (x:24, y:14, next to the market) opens a UIManager
  "board" panel listing active orders. On each market day the board tops up
  with 1-3 orders drawn from `board_orders.json` v1 templates, in-season
  crops only, capped at 3 active; orders persist until their `deadline_day`
  and expire silently with no penalty. Fulfillment deducts inventory across
  any quality mix, grants the coin reward plus optional standing on the
  order's axis, and removes the order. Orders deliberately do NOT feed the
  supply-pressure system - they are a separate contract channel, per R2a.

**Why folded into TitheManager, not a new BoardManager autoload:** the
proposal offers both options ("or integrated into TitheManager for
simplicity"); the task brief takes the simplicity option, and the project's
own history backs it: a new autoload needs a Project Settings -> Autoload
registration only a human can land in the editor (the DESKTOP step ADR-035
recorded, and E5 needs one for FestivalManager already), and a bare
autoload identifier referenced before that registration fails to parse, not
just to run. TitheManager already owns every market transaction, so the
pressure bookkeeping and order lifecycle ride the existing
serialize/deserialize and `_on_day_passed` seams with no new singleton.

**Data schema:** new `economy.json` v1 (supply_scale, pressure_decay_per_day,
price_floor_mult/price_cap_mult, max_active_orders, orders-per-market-day
min/max) and new `board_orders.json` v1 templates (crop_id, min/max_quantity,
base_reward_money, reward_standing, standing_amount, deadline_days, weight).
`farm_map.json` v2 -> v3 (one new `town_board` feature entry). No changes to
`crops.json` or `items.json` - confirmed against the live code exactly as
R2a's Save Impact section promised.

**Corrections made during implementation, not left as R2a drafted them:**

- R2a's integration points guessed at `sell_item()` and a `BoardManager`
  autoload; the live file has `sell_crop()` and the brief's verified hooks
  (`_compute_sell_net`, `_on_day_passed`, `serialize`/`deserialize`) were
  used instead.
- R2a's test "wait 10 days without selling, price drifts back to near base"
  and "after 5 days of zero sales, price returns to within 5% of base"
  calibration: `supply_scale` is anchored to the 5-day guardrail (a typical
  ~26-unit market-day dump decays to the 5% boundary after five quiet days),
  which keeps the existing `test_season_sim` balance assertions green
  unmodified.
- **Board-order quality is any-quality, not common-only.** R2a's schema
  never states a quality requirement; fulfilling against
  `PlayerState.has_item`'s default quality would reject a player holding
  only fine/choice goods. Fulfillment counts and deducts across all quality
  stacks.
- **Orders persist until their deadline and the board tops up** rather than
  being wholesale-replaced each market day - the balance guardrail's
  "overlaps with market days ensure constant options" only makes sense if
  orders survive across market days, and `deadline_days` (3-5 in the shipped
  data) then does real work between market days.

**Save impact:** `tithe.crop_pressure` (Dictionary) and `tithe.active_orders`
(Array[Dictionary]) on the existing tithe block, owned and serialized by
TitheManager itself - not a new top-level block, since every other market
field already lives there. Requires **SAVE_VERSION 15 -> 16**; the migration
defaults both to empty state (no glut, no posted orders). The parallel E5
workstream also bumps to 16 on its branch - the merge renumbers one
migration, which is the documented expectation, not a conflict to solve
here.

**Anti-bloat, carried from R2a unchanged:** no order-book, no matching, no
NPC inventories, no global supply. Pressure is one float per item; decay is
linear; the board is a deadline list. The one deliberate UI addition beyond
R2a's minimum is a geometric town-board fixture in FeatureRenderer (the
board is an interactable; an invisible interactable is a broken playtest).

**Conflicts:** none. Extends ADR-025's market-price work (drift remains a
separate factor applied after the supply multiplier, per R2a). Compatible
with ADR-009 (sole legal venue - the board is a second legal channel, not a
third buyer), ADR-010 (order standing rewards flow through
ReputationManager.modify_standing on the order's declared axis), ADR-030
(festival days are data-only in the slice and never overlap market days),
and ADR-032 (the board is a data-driven feature tile and UI panel; no
projection involvement).

## ADR-038 - Held-acreage tithe scaling and the merchet fee (X13, X7)

**Status:** Accepted (2026-08-07), implemented same day. Resolves **X13**
(the 2b.4 ruling in `design/setting_questionnaire.md`, moving the tithe off
`coin_per_tilled_tile` onto held acreage) and **X7** (the merchet gate),
both accepted by the owner via `design/open_items_treatment.md`. Amends
**ADR-017**, which this record supersedes on the scaling axis only -
ADR-017's recurring-upkeep ruling stands untouched.

**The scaling axis moves from tilled tiles to held parcels.** `tithe.json`
v2's `coin_per_tilled_tile: 1.5` charged the assessment against every tile
the player worked - taxing effort, backwards both historically (rent fell
on the size of a holding, not how hard it was farmed) and motivationally
(it penalised the core verb). `tithe.json` v3 replaces it with
`coin_per_held_strip: 10`: the base 20 covers the owned home plot
(implicit, always held), and each strip currently rented from
`BuildingManager` (`tenure.json`'s `strip_north`/`strip_southwest`/
`strip_southeast`) adds a flat 10-coin surcharge. "Acreage" is measured by
**parcel, not tile** - `tenure.json` already prices strips as discrete
units rather than by tile count, and the current 30x20 grid is a
placeholder ADR-034 will replace regardless, so a tile-count-based formula
would be thrown away with it. A player holding all three strips pays
20 + 30 = 50 coin, a real stretch goal against a Spring where leeks sell at
15 and Wat pays a 25% premium on top.

**Implementation:** `TitheManager._tithe_goal()` reads
`coin_per_held_strip` and a new `_held_strip_count()` helper, which counts
`BuildingManager.is_strip_rented(id)` truthy entries across
`GameData.get_tenure_data().strips` (0 outside live play - a
`configure_for_test(..., held_strips)` seam drives it in tests, mirroring
the existing `farm_grid`/`reputation` injection pattern).
`TitheManager._farm_grid()`/`set_farm_grid_ref` are left in place
(unused by the tithe goal now, but still a valid seam other tithe features
may want) rather than removed, to avoid an unrelated signature break.
`GameData.TITHE_INT_KEYS` gains `merchet_fee`. `test_tithe_labor.gd`'s
hardcoded 30-coin-goal arithmetic (a legacy of the flat pre-ADR-017 tithe)
is corrected to the new 20-coin base-only goal (0 held strips in that
suite's harness), and a new `_test_acreage_scaling` case exercises 0/1/3
held strips directly against the shipped rate.

**Merchet fee set at 25 coin**, shipped as `tithe.json`'s `merchet_fee` -
paid at the point banns are first read, not at the proposal (which stays
effort-not-coin, the braided-rush-ring token). Lands just above the
assessment's own 20-coin base: a real cost, paid once, at a point the
player has usually been saving toward. **No code consumes this field yet**
- no `MarriageManager` or courtship system exists to charge it (see the
ADR-031 amendment below); the data is forward-looking, consistent with
every other tunable in this project living in JSON ahead of the system
that reads it.

**Left deliberately unresolved:** `tenure.json`'s separate weekly
`rent_per_interval` per rented strip is untouched by this record. A player
renting a strip now pays for it twice - once weekly (the existing
eviction-on-nonpayment mechanic `test_tenure.gd` covers) and once at
season's end (this record's surcharge) - under two different names for the
same fact. Folding the weekly rent into the seasonal assessment so "the
assessment is the rent" (`design/world_bible.md` Section III's own phrase)
stops being a metaphor is the clean fix, but it touches
`BuildingManager`'s tested rent/eviction mechanic and needs its own design
pass, not a side effect of this rate change. Flagged in
`design/world_bible.md` Appendix C as the one item from the 17-item
open-items pass that stays genuinely open.

**Amendment to ADR-031 (marriage candidates and the merchet gate).**
ADR-031's original text names the four marriage candidates as "Hilda,
Cedric, Marta, Bram." Per ADR-033's cast expansion and the owner's
acceptance of `design/open_items_treatment.md`'s item 4, **Edith** (the
neighbouring-tenant Tier 1 principal) is added as a fifth candidate; her
counterpart **Osric** (the miller) is explicitly not a candidate, keeping
economic/institutional authority (Aldric, Tomas, Osric) outside the
courtship pool as a clean rule. ADR-031's text is left standing per the
append-only convention; this amendment is the current word on candidacy.
The merchet gate ADR-031 never described is now recorded: a villein needs
the lord's licence to marry, obtained through the steward for 25 coin (see
above), before any wedding proceeds. None of ADR-031's other rulings
(courtship gating, the proposal mechanism, spouse life, the out-of-scope
boundary) change.

**Save impact:** none. `tithe.json`'s own `version` (2 -> 3) is a data-file
version, not `SAVE_VERSION` - no persisted save field changes shape.

**Not attempted in this record:** the marriage system itself (courtship,
proposal flow, ceremony, spouse life, the reputation-transfer math
specified in `design/world_bible.md` Section VIII) remains unbuilt. No
`MarriageManager` autoload exists. This is **not** blocked on manual editor
work the way ADR-035/ADR-036 once were - `docs/register_autoloads.gd`
(landed 2026-08-07, same day as the E5/E6 merge) headlessly registers new
autoloads via `ProjectSettings.save()` and is designed to be re-run with an
updated `NEW_AUTOLOADS` list, so a future `MarriageManager` needs only a
one-line addition there, not a GUI session. The system was left unbuilt in
this record purely as a scope call: courtship, proposal, ceremony, and
spouse life are a multi-system undertaking (UI, save data, dialogue
integration) that deserves its own design and test pass, not a side effect
of a data-and-tithe-scaling pass.

## ADR-039 - Marriage system implementation (ADR-031 realized)

**Status:** Accepted (2026-08-07), implemented same day. Closes the
"not attempted" gap ADR-038 left open. A deep design pull was run through
`design/open_items_treatment.md`'s successor workflow - `.claude/skills/
deepseek-consult` (new this session, see below) - producing
`.deepseek/outputs/marriage_system_out.md`, reconciled line-by-line against
the live codebase before anything was implemented (the same discipline
every prior DeepSeek-assisted phase in this project has required, since
this project's own history shows design-pull claims about specific files
turning out wrong more often than not).

**New autoload: `MarriageManager`** (`scripts/autoloads/marriage_manager.gd`),
registered via `docs/register_autoloads.gd` (no manual editor step needed -
the same headless mechanism that landed `DialogueManager`/`FestivalManager`).
Owns the proposal -> merchet -> ceremony state machine and spouse-life
effects. Courtship itself is not a new system: it rides the existing
`ReputationManager` opinion axis, gifting, and requests, exactly as ADR-031
specified.

**The flow, each step gated and reachable through the existing
`DialoguePanel` response mechanism (`main.gd`'s `_on_npc_interacted`, the
same pattern gift-giving and thief-accusation already use):**
- **Propose** - available once opinion reaches `marriage.json`'s
  `proposal_opinion_threshold` (50, the bottom of the `friendly` band) and
  the player holds a `betrothal_ring` (already existed from ADR-038's data
  pass). No rejection roll - the locked design doesn't describe one, so
  none was invented.
- **Pay the merchet** - a new response when talking to the steward with a
  proposal pending; charges `tithe.json`'s `merchet_fee` (25 coin) exactly.
- **Ceremony** - triggered by interacting with the chapel tile once
  proposed and merchet-paid; takes precedence over the ordinary church
  panel for that one interaction. Runs the reputation transfer once, then
  sets the spouse.

**Spouse life, each effect a small addition to an existing system rather
than a new one:**
- **Home-based schedule** - `npc.gd` gains `_marriage_anchor_position()`,
  mirroring the existing `_festival_anchor_position()` pattern exactly:
  when this NPC is the current spouse, anchor at the `player_house` feature
  tile (looked up via a new `GameData.get_feature_tile()`, not a second
  hardcoded constant next to `main.gd`'s existing `CHAPEL_TILE`).
- **Waking greeting** - one line per calendar day from `marriage.json`'s
  per-candidate `greetings`, shown in `_sleep()`.
- **Farm chore** - a `chore_chance_per_day` roll waters up to
  `chore_water_cells` tilled-but-thirsty tiles via `FarmGrid.water_tile()`.
  Egg-gathering, compost-turning, and weeding were left data-shaped but
  unimplemented - no generic existing API to hang them off safely, and
  guessing one blind was judged worse than a smaller honest scope.
- **Giftable outside the normal cap** - `ReputationManager.gift_item()`
  now checks a second `_spouse_gift_count` / `spouse_daily_gift_cap` (1)
  pool for the current spouse, entirely independent of the shared
  `DAILY_GIFT_CAP` (1) every other villager still draws from. "Outside the
  normal cap" means the two pools don't interact, not that the spouse gets
  unlimited gifts - confirmed by test, since the first implementation of
  the test itself got this backwards before the code did.
- **Spouse requests** - `data/requests.json` v2 adds a `spouse_only` flag
  to five new per-candidate templates rather than building a second request
  queue; `ReputationManager._maybe_offer_request()` filters them to only
  surface for the current spouse. The existing request system already had
  the exact shape a "spouse asks the player to do what they cannot" request
  needs.

**Reputation transfer** (`ReputationManager.apply_marriage_transfer()`),
the one place the locked spec from `design/world_bible.md` Section VIII
could not be implemented against the live data shape as written. `opinions`
is flat (villager's opinion of the player only); the spec needs "V's
opinion of the spouse" too. Re-deriving the spec's wording precisely: "the
player's standing with V softens toward the spouse's standing with V, and
the spouse's standing with V softens toward the player's" - in this
project's convention "X's standing with V" always means "V's opinion of X",
so both halves read off the same two facts about V (V's opinion of the
player, and V's opinion of the spouse) rather than needing a third
"spouse's opinion of V" fact. A new `pairwise_opinions` dictionary (keyed
`"from_id->to_id"`) holds the one new fact needed, seeded from a new
`marriage.json` field `relationship_opinions`. Shipped seeded with the
three relationships `design/world_bible.md`'s "The Web" already locked
(Hilda/Tomas old friends, Cedric/Aldric mutual contempt, Marta/Hilda's
half-known secret) rather than left empty - real content already ruled,
not invented for this record. `ReputationManager.get_opinion()` became
non-mutating (previously seeded every villager to 0.0 on first read,
which made "has this villager ever formed an opinion" unanswerable - a
real prerequisite bug the design-pull surfaced, not a cosmetic cleanup).

**`RaidManager` guard** (`world_bible.md` Block 8.4: "if the player marries
Marta, the thefts end silently"): the scripted day-19 theft
(`execute_theft`) is a one-time event, not a recurring roll, so this is a
single `if not _thief_is_spouse(): execute_theft()` guard, not a per-day
suppression system.

**Save impact: `SAVE_VERSION` 16 -> 17.** New top-level `marriage` block
(`MarriageManager.serialize()`/`deserialize()`); `reputation` block gains
`pairwise_opinions` and `spouse_gift_count`. `migrate_to_v17()` also drops
zero-valued entries from old saves' `opinions` (indistinguishable from
never-recorded under the new non-mutating `get_opinion()` - a player who
earned exactly a net 0 loses only that "touched" bit, not the value,
accepted as an edge case rather than solved).

**New skill: `.claude/skills/deepseek-consult`.** Packages the
`.deepseek/tasks` -> `.deepseek/outputs` (+ `.receipt.json`) pattern this
project has used ad hoc for a dozen prior consults (world bible R1-R4,
block21, block25, the E1-E6 deep designs) into a reusable, documented
workflow, plus records two environment facts worth not re-discovering:
`deepseek-v4-pro` is listed in Codex's model catalog but gated server-side
as of this date (confirmed by a live call, not assumed), and the
owner-directed workaround - use `deepseek-v4-flash` via Codex, instructed
in its own task brief to delegate hard reasoning to the DeepSeek API
directly for sub-problems that need it.

**Two bugs the test suite itself caught, not the implementation:** a
shell/Python double-escaping accident while hand-patching `main.gd`'s
line-continuation syntax (a corrupted backslash that would have been a
silent parse-time syntax error, caught by re-reading the bytes before
trusting the edit, not by the test run); and `test_marriage.gd`'s own
first draft mis-specified the gift-cap and reputation-transfer wiring
(a missing `ReputationManager<->MarriageManager` cross-injection, and an
assertion that had the spouse gift cap's "outside the normal cap" meaning
backwards) - both caught by an isolated bisection run when the full suite
appeared to hang (a `:=` type-inference parse error in the test file
itself, not an infinite loop, made the const-array suite list fail to
compile in a way that manifested as a hang rather than a clean error).

**Verification:** `--headless --path . --import` clean; full suite ->
**ALL SUITES PASSED, 1241 checks**, exit 0, including the new
`test_marriage` suite (10 sections, 40 checks) and updated assertions in
`test_save_roundtrip.gd` for the v17 migration.

**Not attempted:** the festival contest engine and the X6 mercy-path
branch remain exactly as ADR-038 left them - unrelated to this record.

## ADR-038 follow-up - weekly tenure rent retired (2026-08-07)

**Status:** Accepted, implemented same day. Resolves the one open
sub-question ADR-038 itself flagged and left standing: "whether to retire
`tenure.json`'s weekly strip rent" against the new seasonal
`coin_per_held_strip` tithe surcharge that charges the same fact (holding a
rented strip) under a different name. Owner ruling: keep the new system,
omit the old, rather than reconciling the two into a single formula.

`BuildingManager._charge_rent_if_due()`/`_evict_cheapest_strip()` are
deleted outright, along with the `rent_charged`/`strip_evicted` signals and
the `fail_rent` reputation action (`data/reputation.json`) they drove.
Renting a strip (`rent_strip()`) is now a one-time, uncosted claim with no
recurring bill and no eviction path - its cost is paid entirely through
`TitheManager`'s existing per-held-strip seasonal surcharge (ADR-038),
which already counts the exact same `BuildingManager.is_strip_rented()`
state. `tenure.json` bumped to v2 with `rent_interval_days` and every
strip's `rent_per_interval` field removed (dead schema, not dead code left
behind); `GameData`'s `TENURE_INT_KEYS` and the matching int-cast go with
them. `BuildingPanel`'s tenure rows now read "adds N coin to the Lord's
Tithe each season" instead of quoting a per-interval coin/day rate that no
longer exists.

**Verification:** `--headless --path . --import` clean; full suite ->
**ALL SUITES PASSED, 1234 checks** (down from 1241 - the two retired
`test_tenure.gd` cases and two retired `test_game_data_smoke.gd`
assertions account for exactly the 7-check delta), exit 0. No other suite
touched.

## ADR-034 follow-up - region sprint plan exists (2026-08-07)

**Status:** Recorded. Per ADR-034's own deferral ruling ("no code is
written under it until it is scheduled as a systems sprint in
roadmap.md"), the region design is now scheduled as **Sprint 15**
(roadmap row added) with a full code-level implementation guide at
`design/sprints/sprint_15_regions.md`. The guide fixes Stage 1's
deliberately-open geometry (concrete per-zone sizes, entry points, and
directed exits derived from the Stage 1 adjacency graph and structure
placement), chooses **one `FarmGrid` instance per zone** behind a new
`ZoneManager` autoload over a zone-dimensioned single grid (option A -
recommended by a direct DeepSeek API consult on this date; `deepseek-
reasoner` was requested, the endpoint returned `deepseek-v4-flash`, and
the recommendation was reconciled against the live code before use),
re-expresses `tenure.json` strips into their zones, and requires
**`SAVE_VERSION` 17 -> 18** with a wrap migration that places every
pre-existing farm cell into `fallowfield` and defaults the player to
that zone. ADR-034's own text is unchanged per the append-only
convention; Stage 1's remaining open questions are carried in the sprint
guide with the plan's answers flagged where it had to choose.

The zone design itself (nine zones - Fallowfield, Nettleford, the Manor of
Harrowmere, the Upland Commons, Cottersward, the Nettle Brook corridor,
Edith's Plot, the North Strip, and the South Fields) lives at
`design/adr034_region_design.md` (Stage 1 of this two-stage consult
pipeline), cross-checked against real `villagers.json`/`forage.json`/
`tenure.json`/`festivals.json` data and consistency-checked via the
DeepSeek API before Stage 2 began (one real blocker caught and fixed:
Stage 1's first draft claimed a "3-4 hour" playable band that didn't match
the sum of its own travel-time ledger).

**Not opened for implementation.** Per the sprint guide's own stated
prerequisite, Sprint 15 needs a `CLAUDE.md` section 2 amendment (a Region
bullet, plus corrected single-map wording in sections 5 and 9.5) before
work begins - deliberately not landed in this pass, since scheduling a
sprint and authorizing it to start are different decisions and the latter
is the owner's to make. No code or data file changed as part of this
record; only the two design documents and the roadmap/decisions index
entries described above.

## ADR-040 - Spatial demesne chores (ADR-013's abstract labor shape superseded)

**Status:** Accepted (2026-08-07), implemented same day.

The lord-tithe labor chores must be real, stateful, spatial actions on the
existing demesne, not menu buttons. ADR-013's "energy-based labor chore list"
delivered `do_chore(chore_id)`/`can_do_chore(chore_id)` as free-standing
credit buttons with no connection to `FarmGrid`, any tile state, or the
player's position - every chore was infinitely spammable up to the daily cap,
and `water_demesne` on a rainy day granted credit for watering the lord's
field after the weather had already done it. The demesne was always a real
place (`data/farm_map.json`'s `stewards_demesne` 6x6 rect at x:15..20,
y:5..10 on the same grid `FarmGrid` manages); the chores were simply never
wired to it. This record supersedes ADR-013's abstract-chore shape. ADR-003's
three-avenue tithe and the labor avenue itself stand untouched; only the
precondition-checking and action-triggering layer changes, and every
bookkeeping side effect of a successful chore (daily credit cap, corvee 1.5x
multiplier, `_apply_reputation("complete_labor_day")`,
`SkillManager.add_xp_for("labor", "chore_complete")`, tithe credit, signals)
is preserved verbatim.

**Till and water are real `FarmGrid` actions on real demesne tiles.**
`till_demesne` requires an untilled, unoccupied demesne tile and calls
`FarmGrid.till_tile(pos, true)` - the `force` bypass ADR-023 left in place for
exactly this kind of ownership-excepted call site. `water_demesne` requires a
tilled demesne tile whose moisture is below a data-driven
`needs_water_moisture_below` threshold (chores.json v2) and calls
`FarmGrid.water_tile(pos, amount)` with the watering can's own
`water_amount`. Both grant the existing chore credit only when the tile
action succeeds, and both consume the tool's energy through the normal
`ToolManager` path rather than a second, abstract charge. The rain-watering
exploit is fixed **structurally, with no rain check anywhere in the diff**:
`FarmGrid.advance_day(rain)` saturates every tilled cell, so a rain day simply
leaves no demesne tile below the threshold; if a player tries anyway, the
tool wastes its swing and no credit is granted. A "block during rain" rule was
deliberately not added - the gate is tile moisture, and the weather is just
one way tile moisture gets to 100.

**Harvest is clearing stored sheaves, not growing a crop.** Per
`design/world_bible.md` Appendix C item 17's locked fiction there is no live
Spring crop on the demesne; `harvest_demesne` is clearing last autumn's
stored sheaves. Adopting the direct DeepSeek API consult's recommendation
(requested `deepseek-reasoner`; endpoint served `deepseek-v4-flash`), the
backlog is **spatial, not an abstract counter**: `FarmGrid` tile state carries
a `demesne_sheaf` marker per tile, spawned only on untilled demesne tiles
inside the rect, never on the tithe-chest anchor tile, replenished on a
data-driven cadence (chores.json's `sheaves_replenish_interval_days` /
`sheaves_max` / `sheaves_replenish_amount`). Bare-hand interaction on a
marked tile is harvest **and** pickup in one interaction: it removes the
marker, consumes the chore's energy, sets `TitheManager.carrying_sheaves`,
and grants the existing `harvest_demesne` credit. It never creates a player
inventory item - this is labor for the lord. Tilling under a stored sheaf is
refused (`FarmGrid.till_tile`), and planting on any demesne tile is refused
(`FarmGrid.plant` returns a new code 6), so the demesne cannot become the
player's field.

**Carry is a point-A-to-point-B delivery.** The delivery point is the manor
tithe-chest fixture, which already exists at the `stewards_demesne` feature
anchor tile (`data/farm_map.json`'s feature origin - `GameData.get_feature_tile`
lookup, no new feature id). Interacting at that tile while
`carrying_sheaves > 0` consumes the chore's energy, clears the carry state,
and grants the existing `carry_produce` credit. One carry at a time: while
carrying, further harvests are refused until delivery. `carrying_sheaves`
persists through save/load (it is a physical load that should not vanish on
quit) but **clears on day rollover** - sleeping is the work-shift boundary;
the steward collects an undelivered load back into the backlog and the player
gets no `carry_produce` credit. That also closes the cheap exploit of carrying
a load across the daily credit-cap reset.

**The tithe panel no longer executes chores.** `tithe_panel.gd`'s chores view
becomes a status board: what to do and where, with live readiness
(`can_do_chore`), sheaves remaining, and carrying state. The old `Do` button
and `TitheManager.do_chore()` are gone; the chore completions enter through
`ToolManager` (till/water) or `Player`'s bare-hand interaction precedence
(harvest/delivery), both calling new `TitheManager` spatial entry points
(`can_demesne_chore_at`, `complete_demesne_tool_chore`,
`complete_demesne_interaction`). Wired through `GameData` helpers
(`get_feature_rect`, `is_in_feature`, `get_demesne_config`) and FarmGrid's
`tile_changed` redraw path; no new autoload.

**Save impact: `SAVE_VERSION` 17 -> 18** with `migrate_to_v18()` seeding the
tithe block's `carrying_sheaves` (0) and each farm cell's `demesne_sheaf`
(false), mirroring the v14/v16 pattern of defaulting new persisted fields
inside existing blocks. **Note for the future:** the ADR-034 follow-up's
sprint guide reserves "17 -> 18" for the region wrap migration; this record
consumes 18, so the region sprint guide's planned bump must shift to 19 when
that work opens. No contract (CLAUDE.md) amendment is needed - the Lord tithe
bullet already describes working the steward's demesne; this ADR makes that
description true.

**Rulings overturned:** ADR-013's abstract, menu-button chore shape (the
credit/energy bookkeeping, cap, and corvee rules it introduced all stand).

## ADR-041 - Art asset integration (purchased/found sprite packs, as-is)

**Status:** Accepted (2026-08-08). Owner ruling. CLAUDE.md v0.22 amends
section 2 (in-scope gains an Art asset integration bullet, out-of-scope's
"Sprites, art assets... geometric primitives only" clause is narrowed to
audio/particles/shaders), section 5 (directory tree, autoload seams),
section 8 (a new textured-proxy invariant), and section 9.5 (world
representation restated for textured visual proxies). **Narrows** ADR-032's
"why now" rationale ("this project has no art") without contradicting
ADR-032 itself - the projection, the visual-proxy pattern, and the
presentation-only invariant are exactly what makes this ADR a contained
change rather than an excavation, per ADR-032's own stated off-ramp.

Fifteen purchased/found art packs land under `SourceArtAssets/` -
characters (Male1, Female1), NPC archetypes (NPC1's Artist, Astrologer,
Citizen), antagonists (Bandits1's Assassin, Robber, Thug), animals
(Animals1, FarmAnimalsOption1), buildings (Building1, Home1PixelStyle,
Workshop1), terrain dressing (TreesOption1, BushesOption1, RocksAndStones,
FarmPlantsPixelStyle), and UI chrome (AdventureUI, UI2) - roughly 3,600
raster sprites plus vector/EPS masters and stale `.import`/Tiled-export
artifacts left over from whatever project last touched them. They are
integrated **as textured visual proxies** for structures, map features,
actors, and UI screens - the primitive `_draw()` proxies ADR-032 built
stay as the fallback/default where no asset exists, not as a rule that is
now false.

**Terrain/soil is explicitly out of this ADR's scope and stays
immediate-mode.** None of the fifteen packs is a farm-soil tile atlas;
retexturing `FarmGrid`'s ground rendering is a separate, larger,
not-yet-authorized undertaking with its own ADR if it's ever proposed.

**Style unification is explicitly not required this pass - owner
ruling.** The packs clash (pixel-art vs. painted/vector-clean vs.
photoreal-shaded), spanning bases from 16px to 128px+ per sprite. They are
integrated **as-is**, edited only where an asset fails to read at all at
the game's `64x48` tile scale (e.g. a source sprite so large or so
thin-lined it disappears or smears at that scale) - not for palette or
line-weight consistency. This directly narrows `asset_studio/`'s existing
`plan_art_integration_pro2.md` Phase 3 (LoRA training + ControlNet
restyling for a unified style): that pipeline is **parked, not adopted**,
for this integration pass. `asset_studio/` itself, its `style_bible.md`,
and its scripts (`catalog.py`, `critique.py`, `generate.py`) are untouched
and remain available for a future polish pass; nothing about this ADR
deletes or supersedes that private, git-ignored workspace's own README.

**Visual proxies may now carry a texture.** A structure/feature/actor's
`y_sort_enabled` visual proxy (ADR-032, section 9.7) may add a child
`Sprite2D` or `AnimatedSprite2D` sourced from a data-driven manifest,
instead of or alongside its primitive `_draw()` override. Anchoring,
`y_sort_enabled` participation, and the presentation-only projection
contract are unchanged - a textured proxy still reports its screen
position from `IsoProjection` and sorts exactly like a primitive one.
8-way player/NPC facing (ADR-032) is already discrete data
(`Player._facing: Vector2i`, `get_facing()`) and is expected to drive
directional frame/row selection once character sprites land, with no
change to the facing computation itself.

**No new autoload.** Registering one needs a human-only Project Settings
step (the DESKTOP-step constraint ADR-035 and ADR-037 already recorded).
A sprite/animation lookup lands as a static `class_name` helper (the
`IsoProjection` pattern) or folds into `GameData`'s existing boundary,
whichever the implementation sprint guide picks.

**No `TileMapLayer`.** Unchanged from ADR-032: it would still need an
editor session for every terrain change, which blocks headless/parallel
work regardless of art availability, and none of the sourced packs target
farm-soil tiles anyway.

**Source-tree hygiene.** Stale `.import` files, `Tiled/*.tmx` exports, and
`AI`/`EPS`/`SVG` design masters that ship alongside the PNGs are reference
only - Godot regenerates its own `.import` files on `--headless --path .
--import` (known trap #8), and only the raster frames actually consumed by
a sprite/animation manifest are copied into `res://assets/`. macOS
`.DS_Store` junk is never copied.

**Boundary:** no elevation, no gameplay-affecting new systems, no audio,
no particles, no shaders beyond what a `Sprite2D`/`AnimatedSprite2D` needs
for straightforward playback - consistent with ADR-032's own elevation
boundary and this contract's existing out-of-scope list. License
confirmation for any pack that ships publicly remains the owner's own
manual gate, outside any agent's scope to assess.

**Save impact:** none, and none is permitted. A texture swap is exactly as
presentation-only as the projection it renders through - work under this
ADR that finds itself wanting a save migration has violated that invariant
and should stop.

**Execution:** opened as a multi-sprint effort; the implementation-ready
per-workstream sprint guide is
`design/sprints/sprint_16_art_integration.md`.

## ADR-042 - Textured terrain (ADR-041's terrain exclusion lifted)

**Status:** Accepted (2026-08-08). Owner ruling: "All art related aspects
of the project are now authorized." **Supersedes** ADR-041's terrain
exclusion and the clause in CLAUDE.md section 9.5 that terrain "stays
immediate-mode primitives" *as a scope boundary* - the immediate-mode
**rendering method** is retained, for the reasons below, but it now draws
textures instead of flat colour.

**Terrain becomes textured.** `farm_renderer.gd` continues to own
per-cell drawing, culling, and state layering; what changes is that a
cell's surface is a texture region rather than a flat `Color`.

**Rendering method: immediate-mode, NOT `TileMapLayer`.** This was
questioned directly by the owner ("I want the game to look good: I am
afraid sticking to your recommendation will hinder that") and put to the
art director (ChatGPT Terra) as a visual-ceiling question rather than an
engineering-preference one. Its verdict, recorded here because it is the
load-bearing reason this ADR does not adopt `TileMapLayer`:

> "Choose A - immediate-mode textured terrain. It does not lower the
> visual ceiling here. A TileMapLayer would improve authoring ergonomics
> and possibly batching, but neither is what makes this terrain
> beautiful. ... The visual problem is not its API; it is that every
> surface is a single flat color and every state is a transparent wash
> or dot."

`TileMapLayer` would additionally require authoring a `TileSet` in the
Godot editor, which this project's headless, multi-agent workflow cannot
absorb (a constraint that has blocked work repeatedly - ADR-032, ADR-035,
ADR-037), and a `TileSet` is an editor-managed resource section 8 forbids
hand-editing. Since it buys ergonomics rather than visual ceiling, it is
declined. **The off-ramp survives:** all cell geometry still comes from
`IsoProjection.cell_diamond()`, so adopting `TileMapLayer` later remains
a contained change.

**What "textured terrain" actually requires** - the art director's
explicit warning was that swapping `draw_colored_polygon()` for a texture
is NOT sufficient and would still look tiled:

> "do not frame A as merely replacing `draw_colored_polygon()` with
> texture UVs. The visual upgrade needs a small terrain rendering system:
> masks, variation selection, layered decals, and plot-aware tilled rows."

So this ADR authorizes a terrain rendering *system*, sized as:
- **Variant selection.** 6-8 quiet grass variants, 4-6 dirt/path, 3-4
  tilled, chosen deterministically per cell (hash of `Vector2i`, so it is
  stable across redraws and saves without persisting anything).
- **Transitions.** Adjacency-aware boundaries between grass/dirt/tilled,
  irregular and material-driven rather than a recoloured diamond outline.
  The **dual-grid** technique is authorized for two-material boundaries
  (the owner already has a dual-grid template) but explicitly is not the
  whole solution - 16 repeated transition pieces create their own visible
  pattern.
- **Scatter/decals.** Sparse deterministic dressing (tufts, pebbles,
  ruts) layered over the base to break repetition.
- **Moisture stops being a blue wash.** The art director called the
  current transparent moisture overlay out directly: it "will always read
  as a debug/status effect before it reads as moisture." Wet soil becomes
  a darker, richer soil *material*, not an alpha tint.
- **The always-on grid lattice becomes contextual.** It "will fight
  painterly terrain"; it stays as an interaction/placement affordance,
  not a permanent outline around every cell.

**Invariants unchanged.** Terrain textures are presentation only. The
simulation grid, `FarmGrid` cell state, soil types, moisture/fertility
values, collision, pathing, and every save payload are untouched -
ADR-032's presentation-only rule applies to terrain exactly as it applies
to actors and structures. Variant and scatter selection must be a pure
function of the cell coordinate and existing cell state; **nothing about
the visual grid may become new gameplay state.**

**Boundary:** still no elevation, no z-levels, no slopes (ADR-032's
boundary is untouched). Terrain art must be generated as a tileable
material family with seam checks - the art director flagged that seams,
per-tile baked lighting, and scale drift are failure modes specific to
terrain that the isolated-object generation so far has not had to face.

**Save impact:** none, and none is permitted, for the same reason
ADR-041 permitted none.

**Contract impact:** CLAUDE.md section 2's out-of-scope list and section
9.5 both need amending, since both currently assert terrain stays
primitive. Owed as a `CLAUDE.md` amendment alongside the first
terrain implementation work.

## ADR-043 - Standard 2:1 isometric tile aspect (ADR-032's aspect superseded)

**Status:** Accepted (2026-08-10). Owner ruling: "Let's go ahead and get the
isometric conversion going" - authorizing
`design/standard_isometric_conversion_guide.md`, which had sat as a
proposal-only runbook since the same day. **Supersedes ADR-032 only as to
the tile aspect ratio.** Every other ADR-032 ruling - presentation-only
projection, the single `iso_projection.gd` seam, screen-relative input,
8-way facing, `y_sort_enabled` depth ordering, immediate-mode terrain, the
no-elevation boundary, and the no-save-impact rule - stands unchanged and is
restated here, not re-litigated.

**What changes:** the screen diamond one grid cell projects to moves from
`64 x 48` (dimetric, 2:1.33) to `64 x 32` (standard 2:1 isometric).
`IsoProjection.TILE_H` becomes `32.0`. `TILE_W` (`64.0`) and
`LOGICAL_CELL` (`32.0`, the physics/collision/save unit) are unchanged.

**Why now:** ADR-032 picked the shallower 2:1.33 angle deliberately, for
structure headroom, over the "common 2:1 isometric ground grid used by many
modular asset packs" (`standard_isometric_conversion_guide.md` section 1).
That tradeoff reverses once commercial/found modular isometric art packs
are the intended source: a non-standard aspect has no realistic integration
path against art authored at 2:1, and re-deriving every asset family at a
bespoke angle is the more expensive path going forward. ADR-041/ADR-042
already committed this project to sourced and textured art; this record
follows that commitment to its geometric consequence rather than opening a
new one.

**Presentation-only, restated:** `FarmGrid`, physics bodies, collision
shapes, weapon reach, NPC pathing, feature coordinates, building footprints,
room sizes, inventory, combat reach, NPC schedules, and every save payload
are unaffected - none of them read `TILE_H`. Conversion still lives in
exactly one file, `scripts/globals/iso_projection.gd`; a projection or
inverse-projection formula anywhere else remains a defect. Input stays
screen-relative through the existing `input_to_world_dir` seam (itself
`screen_to_grid` composed with the logical-cell scale) - the guide
explicitly forbids replacing it with a hand-written 45-degree rotation,
since that seam is what keeps "up" meaning visually up under either aspect.

**No elevation, no save impact, as ADR-032 already ruled:** still a flat
plane drawn at an angle - no height values, no z-levels, no slopes, no
multi-storey structures. Save version stays unchanged; work under this ADR
that finds itself wanting a migration has violated the presentation-only
invariant and should stop, exactly as ADR-032 warned.

**Art consequence (the real cost of this ADR):** existing dimetric art
authored at `64x48`/`128x96` does not carry over - squashing it into
`64x32`/`128x64` produces warped walls and roofs, not native isometric art,
and is explicitly forbidden. Old dimetric art and its source metadata are
preserved as provenance, not deleted. Terrain, structures, actors, and
interiors are re-authored or re-sourced at native `2:1` per
`standard_isometric_conversion_guide.md` section 7 (Phase 3), which requires
an owner-approved live representative capture (one well, one 4x3 farmhouse,
a tilled plot, one actor) before further art families migrate. That capture
gate is this record's own condition for Phase 3 to proceed past its first
representative asset, not a separate approval.

**Execution:** `design/standard_isometric_conversion_guide.md` is the
authoritative phased runbook (Phase 0 decision checkpoint - this record and
its CLAUDE.md amendment; Phase 1 projection foundation; Phase 2 renderer/
camera adaptation; Phase 3 art migration, gated on owner review of the
representative capture; Phase 4 integration/regression). Exact geometry,
test requirements, and the failure/rollback tables live there and are not
duplicated here.

**Contract impact:** `CLAUDE.md` section 1's projection pin, section 2's
projection bullet, and section 8's projection invariant all name the
`64 x 48` dimetric aspect and need amending. Landed alongside this record as
`CLAUDE.md` v0.23; `AGENTS.md`/`DEEPSEEK.md` regenerated in the same commit.

**Save impact:** none, and none is permitted - identical to ADR-032's own
save-impact ruling. Save version unchanged.

**Rulings overturned:** ADR-032's `64 x 48` / 2:1.33 tile-aspect ruling
only. ADR-032's presentation-only architecture, projection seam, input
convention, facing widening, and depth-ordering rulings are unaffected and
remain the governing record for all of them.
