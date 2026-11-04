# Content Plan - Tithe & Turnip

Companion to `design/roadmap.md`. That document sequenced **systems**
(Sprints 1-14, all shipped). This one sequences **content**: the setting, the
writing, the people, and the world's texture.

Content passes are numbered **C1..C4** to keep them unambiguous against the
systems sprints.

## The problem this plan solves

The systems layer can express far more than the content layer currently says.
Measured against the shipped code, not estimated:

| Thing | Current state |
|---|---|
| Total written dialogue | **36 lines** (6 NPCs x 5 reputation bands + 1 fallback each) |
| Villager `traits` wired to behavior | **1 of 12** (`"thief"`, read by `RaidManager._find_thief_id`) |
| Dialogue condition types supported | **1** (`reputation.<axis>.min`) |
| Lines shown per NPC per state | **1** - `main.gd` takes `lines[0]` unconditionally |
| Plantable crops in the Spring slice | **2** (cabbage is summer-locked) |
| Recipes / request templates / animal species | 5 / 6 / 2 |
| Authority document for fiction | **none** |

Two of these are hard blockers that must be cleared before writing volume is
worth doing:

1. **Dead-content bug.** `GameData.get_dialogue_for()` returns every matching
   line, but `main.gd`'s NPC handler reads `lines[0]`. A second line written
   for the same NPC and reputation band **can never display**. Writing more
   dialogue against today's code produces content the player will never see.
2. **No condition vocabulary.** `_dialogue_conditions_pass()` understands
   exactly one key shape. There is no way to write a line that fires at dawn,
   in the rain, on a market day, after a raid, or because a character is a
   gossip.

And one root cause behind the generic feel of what exists: there is no
document stating what the world *is*. `CLAUDE.md` is an engineering contract;
`decisions.md` is systems ADRs. Nobody writing a line had a source of truth
for the manor's name, the lord, the era, or the register - so the lines read
as generic-medieval because that is the only thing they could be.

## Locked creative direction (2026-08-06)

Decided with the project owner; recorded as **ADR-029** (to be written when C1
opens).

- **Register: grounded & hopeful.** A harsh world with warm people. Real
  pressure - the tithe is due, the winter was hard - but neighbours help,
  small wins land, and the game is not punishing the player for existing.
  Explicitly NOT grimdark; explicitly NOT cozy-without-stakes.
- **Anchoring: invented but plausible.** A fictional manor, village, and lord
  in an England-shaped world. Real institutions (manor court, tithe, corvee,
  assize prices) with no real people, places, or dates. No research debt and
  nothing factual to get wrong.
- **Cast: stays at six.** The small-cast principle is already established
  (ADR-028 applied it to animals). This plan deepens the six villagers rather
  than adding a seventh.
- **Marriage depth: courtship plus spouse life** (ADR-031). Spouse moves into
  the cottage, gains a home schedule, greets on waking, occasionally works a
  chore, giftable outside the daily cap.
- **Festival breadth: one per season, all four in data** (ADR-030), only
  Spring reachable in the slice.

## Scope discipline

**Amended 2026-08-06 by owner ruling: marriage and festivals are IN scope.**
CLAUDE.md v0.11 removed them from section 2's out-of-scope list; ADR-030
(festivals) and ADR-031 (marriage) supersede the exclusion clauses previously
recorded in ADR-024 and ADR-028. That amendment is landed, generated files
regenerated, and contract-sync suites green - the work below is unblocked.

C1-C4 remain **expression of already-accepted systems** - the same category as
the VSA-1..3 presentation pass. C5 and C6 are new feature work under the two
new ADRs. What stays out:

- **Children, in-laws, divorce, rival suitors** - the new boundary line, set
  by ADR-031. Marriage consumes existing systems (opinion, schedules,
  buildings, chores) and must not grow a simulation of its own.
- **Festival mini-games, festival-exclusive items** - ADR-030's boundary. A
  festival is a scheduled place, a window, dialogue, and a standing effect.
- **New simulation systems** (disease, aging, deeper politics) - out per
  section 2.
- **Art, audio, sprites** - out per section 2. Content here is *text and
  data*, rendered by the geometric-primitive UI that already exists.

Adding crops, recipes, forage entries, and request templates is data within
ADR-004/005/022/024/027 and needs no amendment.

---

## C1 - The Setting Bible (S, no code)

**Deliverable:** `design/world_bible.md`, plus **ADR-029** recording the
locked direction above.

The missing authority document. Everything downstream cites it. No code
changes, no data changes, no tests - which is exactly why it goes first and
why it is cheap.

Contents:

- **The place.** Manor name, village name, the river/road/wood that bound it,
  and why the property is 30x20 with the soil distribution `farm_map.json`
  already encodes. The map exists; this gives it a geography.
- **The lord and the manor.** Who holds it, why they are absent, why the
  assessment is 30 coin, and what the steward's actual position is (he
  answers to someone, and that someone is not the player's friend).
- **The church.** The chapel, its saint, what Father Tomas wants, and why the
  church tithe is voluntary when the lord's is not (ADR-012's fiction).
- **The player character.** Who arrives, why they hold this strip, what they
  owe on arrival. Currently unstated anywhere.
- **Thematic pillars.** What the game is *about* - stated in three or four
  sentences so a writer can test a line against them.
- **Tone rules.** Concrete do/don't for the grounded-hopeful register, with
  worked examples of a line that is too grim and a line that is too cozy.
- **Diction rules.** A vocabulary allow/deny list. The UI already commits to
  a register - "Vigour" not "Stamina", "Coin" not "Gold", "Satchel" not
  "Inventory", "Resume Toil" not "Resume", "Keep Record" not "Save". That
  choice is currently undocumented and will drift the moment anyone writes a
  new panel. Codify it.
- **Naming conventions** for any future NPC, item, building, or place.

**Gate:** owner reads and approves the bible before C2 opens. Nothing else in
this plan is worth doing against a setting that is not agreed.

## C2 - Dialogue engine unblock (S-M, code + tests)

**Deliverable:** dialogue can express what the systems already know.

Pure engineering, no new writing - this clears the two blockers so C3's
writing is not wasted.

- **Fix the `lines[0]` dead-content bug.** `get_dialogue_for` should return
  candidates and the caller should pick - random among the highest-priority
  matching set, so multiple lines per band become live content. Must not
  regress the 36 existing lines.
- **Extend the condition vocabulary** in `_dialogue_conditions_pass`, keeping
  `reputation.<axis>.min` working byte-identically:
  - `time.hour` (min/max) - dawn, working hours, after dark
  - `weather` - rain, overcast, snow
  - `season`, `day` (min/max) - late-season pressure, market days
  - `opinion.min` / `opinion.max` - the per-NPC axis, currently unused by
    dialogue despite `ReputationManager` tracking it since Sprint 4
  - `event` - a small set of transient flags the game already knows:
    `post_raid`, `post_court`, `market_day`, `corvee_active`,
    `investigation_open`, `tithe_unpaid_late`
  - `trait` - lets one line be authored for "any gossip" rather than per-NPC
- **Bump `dialogue.json` version** (schema shape change, contract rule 6.4).
- **Tests:** extend the existing dialogue coverage in `test_reputation.gd`;
  new `test_dialogue_conditions.gd` for each condition type, priority
  ordering, the multi-line selection fix, and backward compatibility of the
  existing 36 lines.

**Risk to watch:** the existing band lines use `min`-only conditions ordered
highest-first with a no-condition fallback last (a documented Sprint 6
divergence - see `DEVELOPMENT_STATE.md`). The new selector must preserve that
ordering semantics or every NPC silently drops to their fallback line.

## C3 - Character depth (M, data + code + writing)

**Deliverable:** the six villagers become people, and their declared traits
actually do something.

This is the heart of the plan.

- **Character sheets** in the bible: for each of the six - history, what they
  want, what they fear, how they regard the player at each standing band, and
  how they regard *each other*. Six sheets, written against C1's tone rules.
- **Traits become mechanical.** A trait registry (new `traits.json`, or an
  effects block on the existing villager entries) where each trait declares
  what it does, replacing eleven inert strings:
  - `early_riser` / `night_owl` -> real schedule offsets. Today every
    villager but the steward and priest works exactly 08:00-18:00, which
    makes `night_owl` a lie the schedule system is already capable of telling
    the truth about.
  - `gossip` -> reveals investigation clues more readily; a natural fit with
    ADR-026's "any villager might have heard something" design.
  - `stern` / `gruff` / `quiet` / `boastful` / `devout` / `loyal` /
    `forgetful` -> dialogue flavor tags (consumed via C2's `trait`
    condition) plus small gift-reaction and opinion-drift modifiers.
  - `thief` -> unchanged. It already works and ADR-026 owns it.
- **Dialogue volume:** from 6 lines per NPC to roughly 25-30, spread across
  the new condition types. This is the bulk of the writing effort and is only
  possible once C2 lands.
- **Tests:** trait-effect lookups, schedule offsets (extend the existing
  `test_schedules.gd`, which already sweeps all six villagers), gossip clue
  behavior, and a content-integrity check that every villager has at least
  one line per reputation band (the kind of gap that is invisible until a
  player hits it).

## C4 - World texture (M, data + writing)

**Deliverable:** the loop has more to say across 28 days.

- **Crops.** More Spring-plantable options - the slice currently offers two.
  Every system is already season-aware, so this is a data change.
- **Recipes, forage, requests.** Widen from 5 / and 6 templates; request text
  should read as a person asking a favour, not a fetch-quest string.
- **Reactive event text.** Raids, court days, corvee notices, black-market
  visits, and the theft all currently surface as single fixed HUD strings.
  With C2's `event` conditions these can vary and can be commented on by
  villagers the next day - which is what makes a village feel like it
  noticed.
- **Seasonal beats** as *dialogue* - the late-season tithe squeeze, the first
  warm day, the state of the commons. Distinct from C5's festivals, which are
  scheduled events with standing effects rather than ambient commentary.

## C5 - Festivals (M, data + code + writing; ADR-030)

**Deliverable:** the calendar's positive beat.

- **`festivals.json`** (new): one festival per season, all four defined, each
  declaring day, hour, place, standing effects, and its dialogue hooks. Only
  the Spring festival is reachable in the slice.
- **Attendance check** modeled on the existing chapel-mass implementation -
  which is already a one-`if` day/hour/tile check in `main.gd`, deliberately
  not a system. Festivals generalize that into data rather than reinventing
  it.
- **Villager gathering:** NPC schedules already support anchor switching by
  hour; a festival day overrides the work anchor to the festival place.
- **Dialogue:** festival-day lines via C2's `event` condition, plus
  next-day commentary so the village visibly remembers.
- **Tests:** `test_festivals.gd` - calendar lookup, attendance window
  boundaries (inclusive start / exclusive end, matching the schedule
  convention), standing effects, missing-it-is-penalty-free, save round-trip
  of the attended flag.

**Depends on:** C2 (event conditions), C1 (what a festival in this world
actually is).

## C6 - Marriage (M-L, data + code + writing; ADR-031)

**Deliverable:** the social layer gets a terminal goal.

The largest pass here, and the only one that changes the save format.

- **Candidates:** Hilda, Cedric, Marta, Bram. Marta being simultaneously a
  marriage candidate and ADR-026's thief is a deliberate collision - keep it.
- **Courtship** gates on the individual-opinion axis, which
  `ReputationManager` has tracked since Sprint 4 and has never gated anything
  on. Advanced by existing gifting and requests.
- **Proposal** through the existing `DialoguePanel` response mechanism at an
  opinion threshold; **ceremony** at the existing chapel tile.
- **Spouse life:** moves into the cottage, home-based schedule, a waking
  greeting, an occasional completed farm chore, giftable outside the daily
  cap.
- **Save:** `SAVE_VERSION` bump + migration (spouse id, courtship state,
  ceremony flag). First save-shape change since Sprint 14's v13.
- **Tests:** `test_marriage.gd` - opinion gating, non-candidates rejected
  (priest and steward), proposal threshold, ceremony state, spouse chore
  contribution, gift-cap exemption, save round-trip and migration defaults.

**Depends on:** C3 (a spouse needs a personality before they need a house).

---

## Sequencing and rationale

```
C1 (bible) -> C2 (engine) -> C3 (characters) -> C4 (texture)
  no code      code only      the main event     breadth
                                   |
                                   +-> C5 (festivals)  [needs C2 + C1]
                                   +-> C6 (marriage)   [needs C3]
```

C1 first because everything cites it and it is nearly free. C2 before any
writing, because writing against the current code produces content the player
cannot see. C3 is the payoff and the prerequisite for C6 - a spouse needs a
personality before they need a house. C5 can run in parallel with C4 once C2
lands; C6 is last and largest.

**Amendment status: landed.** CLAUDE.md v0.11 (2026-08-06) moved marriage and
festivals into scope by owner ruling; ADR-029 (setting and tone), ADR-030
(festivals), and ADR-031 (marriage) are appended and Accepted. `AGENTS.md` and
`DEEPSEEK.md` were regenerated with the real generators and the contract-sync
suites pass (711/711 checks). No further amendment is required for C1-C6 as
scoped.

**Verification convention** (unchanged from the systems sprints): headless
import clean, full runner green with the check count stated, boot smoke exit
0 for both scenes, and every deliberate divergence recorded in
`DEVELOPMENT_STATE.md` in the same response that makes it.
