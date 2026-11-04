# Setting Questionnaire - Tithe & Turnip

**Purpose.** This is the working instrument for content pass **C1** in
`design/content_plan.md` (ADR-029). It does two jobs:

1. **Part A** records the *gap analysis* - what this project's fiction lacks
   measured against shipped genre peers and against its own systems layer.
2. **Part B** is the *question set* that closes those gaps. It is answered in
   **blocks of five**, in order. Each answer is written back into this file
   under its question, so this document becomes the raw material for
   `design/world_bible.md`.

**How to use it.**

- Questions are asked five at a time, in block order. Answer in prose - no
  format required.
- Every question carries a **Default:** line. Saying "default" accepts it and
  moves on; that is a legitimate answer, not a skipped one.
- Answers are transcribed into the **A:** field verbatim-in-substance.
  Block status is tracked in the table below.
- When all blocks are closed, `world_bible.md` is written *from this file* and
  this file stays as the record of what was decided and what was defaulted.

**Authority.** This document sits below `CLAUDE.md` and `design/decisions.md`.
Nothing here may contradict the contract or an Accepted ADR. Where a question
below *does* collide with shipped data, it is flagged **[COLLISION]** and the
resolution may require an ADR.

---

## Block status

> **SCOPE NOTICE (2026-08-06).** Block 1 surfaced two owner rulings that break
> locked decisions and must be resolved by amendment before content is written
> against them:
> - **X8 - cast size.** ADR-029 locks the cast at six; the owner wants 10-12+.
> - **X9 - multiple maps.** The world is to be split across a manor map, a
>   village map, wilderness maps, the player's plot, and other farmers' plots.
>   The shipped design is a single 30x20 grid (`CLAUDE.md` section 5,
>   `farm_map.json`, `tenure.json`, NPC schedule coordinates, save v13).
>
> X9 is a **systems change, not a content change** - it is larger than
> anything in C1-C6 and belongs in `roadmap.md` as its own sprint. C1 can
> proceed in parallel *only* on questions that do not depend on where things
> physically are (tone, diction, character interiority, economy fiction).
>
> **RESOLVED (2026-08-06).** X8 -> **ADR-033** (cast expansion and tiering,
> Accepted). X9 -> **ADR-034** (the region, Accepted in principle,
> implementation deferred). X10 -> the `CLAUDE.md` amendment and generated-file
> regeneration ADR-033 required, **landed 2026-08-07 (`CLAUDE.md` v0.13)**.
>
> **Concurrency note.** ADR-032 (dimetric projection) landed in this repository
> from a parallel session while this questionnaire was being written, taking
> the number 032 and amending `CLAUDE.md` to v0.12. Check the tail of
> `design/decisions.md` before assuming an ADR number is free.

| # | Block | Feeds | Status |
|---|---|---|---|
| 1 | The place | world_bible, farm_map fiction | **CLOSED** - 1.1 accepted; 1.2/1.4 superseded by ADR-034; 1.3/1.5 answered in 1b |
| 1b | The region and the cast | ADR-033, ADR-034 | **CLOSED** - all five defaults accepted |
| 2 | The manor and the lord | tithe, court, corvee, steward | **CLOSED** - 2.1-2.5 answered 2026-08-06; opened 2b |
| 2b | Itinerants, and what the tithe taxes | ADR-033 amendment, tithe.json | **CLOSED** - defaults accepted on all four (2b.1-2b.4) |
| 3 | The church | church tithe, mass, chapel, priest | **CLOSED** - 3.1/3.5 defaults; 3.2-3.4 answered |
| 4 | The player character | intro, title screen, start_money=8 | **CLOSED** - 4.1-4.4 defaults; 4.5 answered |
| 5 | Time, calendar, era | time.json, festivals, market days | **CLOSED** - 5.1 answered (both halves); 5.2-5.5 defaults |
| 6 | Hilda | villagers, dialogue, marriage | **CLOSED** - 6.1/6.2/6.4 answered; 6.3/6.5 defaults; X2 resolved |
| 7 | Cedric | villagers, dialogue, marriage | **CLOSED** - 7.1/7.4 answered; 7.2/7.3/7.5 defaults; X4 resolved |
| 8 | Marta (thief + candidate) | villagers, investigation, marriage | **CLOSED** - defaults on all five; X3 resolved, C6 code touch owed |
| 9 | Bram | villagers, dialogue, marriage | **CLOSED** - defaults on all five |
| 10 | Steward Aldric | manor, chores, court | **CLOSED** - 10.1/10.3 answered; 10.2/10.4/10.5 defaults |
| 11 | Father Tomas | church, mass, ceremony | **CLOSED** - 11.1/11.2 answered; 11.3-11.5 defaults; cast demography ruling recorded |
| 12 | The web between them | dialogue, gossip, investigation | **CLOSED** - 12.1 default; 12.2-12.5 answered; marriage reputation-transfer ruling feeds C6 |
| 13 | Register and tone rules | all writing | **CLOSED** - 13.1-13.3/13.5 defaults; 13.4 answered (Tomas's comedy reconciled with 11.2) |
| 14 | Diction and naming law | UI strings, all writing | **CLOSED** - defaults on all five |
| 15 | Voice per character | dialogue | **CLOSED** - defaults accepted for all six |
| 16 | Money, market, black market | market.json, manor.json | **CLOSED** - 16.1/16.2/16.4/16.5 defaults; 16.3 answered (young clerk introduced) |
| 17 | Tenure, tithe, corvee, court | tenure.json, tithe.json, manor.json | **CLOSED** - 17.1 answered; 17.2-17.5 defaults |
| 18 | Bandits and the thief | enemies.json, raids.json, clues.json | **CLOSED** - 18.1/18.2/18.4/18.5 defaults; 18.3 deferred post-slice; X6 confirmed as design question |
| 19 | Buildings, stations, livestock | buildings, recipes, animals | **CLOSED** - defaults on all five; 19.5 sub-question resolved (2026-08-07): wood sinks applied to cottage_upgrade + fence |
| 20 | The commons and forage | forage.json | **CLOSED** - 20.1-20.3/20.5 defaults; 20.4 default + purchasable; item renames and market wood applied |
| 21 | Crops, food, and the table | crops.json, items.json, recipes.json | **CLOSED** - 21.1/21.3/21.4 answered (V4 Pro consulted); 21.2/21.5 defaults; oats + flax added |
| 22 | Festivals | festivals.json (C5) | **CLOSED** - 22.1-22.3 defaults; 22.4/22.5 answered (contests, social-participation ticks); C5 flags recorded |
| 23 | Marriage and courtship custom | C6 | **CLOSED** - 23.1/23.4/23.5 answered; 23.2 adopted (token fits lore); 23.3 default (X7 resolved, ADR-031 amendment owed) |
| 24 | Reactive and ambient text | C4 dialogue events | **CLOSED** - 24.1/24.3-24.5 defaults; 24.2 answered (all six principals comment) |
| 25 | Framing: intro, endings, failure | title, season summary | **CLOSED** - 25.1/25.3 defaults; 25.2/25.4/25.5 drafted via V4 Pro (max effort) with review corrections. **QUESTIONNAIRE COMPLETE - all 27 blocks closed.** |

**Standing ruling - cast demography (2026-08-07).** The majority of the cast
is in their **30s and 40s**; older people are **exceedingly rare**, having
been thinned out by a **widespread plague a couple of decades prior**. Current
sheets already conform: Hilda twenties, Marta late twenties, Cedric and Bram
thirties, Aldric late thirties-early forties, Tomas thirties. This also gives
the parish its demographic backstory - why the priest is young, why the
steward rose young, and why the village is small enough to know everyone.

**Standing ruling - materials & the commons (2026-08-07).** (1) **Wood gains
sinks**: the cottage upgrade now costs flint 20 **+ wood 20** (a chimney and
floor are timber), and the fence costs **wood 2** instead of flint 2 (fences
are wood, making wood load-bearing for the ADR-026 deterrence system).
Applied to `buildings.json`, tests updated - full suite 1117 checks, all
pass. (2) **The commons gains persistent trees and rock nodes** that replenish
over time - visible, tool-required entities - scheduled as a post-slice
systems item riding with ADR-034's map rework, not in the Spring slice.
Deadfall remains the legal wood source for now; the standing-timber custom
(20.4) becomes load-bearing and will be ruled in Block 20.

---

# Part A - Gap analysis

## A.1 How the comparison was made

Two axes, both measured rather than estimated:

- **Against the codebase.** Every `data/*.json` file was read in full, plus the
  ADR log and the content plan. Counts below are actual.
- **Against the genre.** Structural comparison to *Stardew Valley*, *Story of
  Seasons / Harvest Moon*, *Rune Factory*, *My Time at Portia*, *Graveyard
  Keeper*, *Kynseed*, and - for the medieval-village-with-a-court-and-an-
  investigation shape specifically - *Pentiment*. Simulation-forward peers
  (*Manor Lords*, *Ostriv*, *Farthest Frontier*, *Lords and Villeins*) are
  cited only where relevant, because they deliberately have almost no
  character fiction and are therefore the wrong model for the social half of
  this design.

A caveat worth stating: exact base-game dialogue line counts for the genre
leaders are not publicly documented, so no per-line benchmark is claimed
below. The comparisons made are *structural* - what kinds of content exist,
not how many words - which is both verifiable and the more useful axis here.

## A.2 The measured state of the fiction

| Thing | Count / state |
|---|---|
| Named places in the entire project | **0** |
| Named characters | 6 (`Aldric`, `Tomas`, `Hilda`, `Cedric`, `Marta`, `Bram`) |
| Characters with a stated age, sex, family, or trade | **0** |
| Stated relationships between villagers | **0** |
| Lines of dialogue | 36 |
| Dialogue axes available to a writer | 1 (community standing band) |
| Villager `traits` wired to behavior | 1 of 12 (`thief`) |
| Stated reason the player is here | **none** |
| Stated reason the assessment is 30 coin | **none** |
| Named lord | **none** - the lord is referenced in dialogue and never defined |
| Map landmarks | 6, all generic: `player_house`, `well` x2, `chapel`, `market_zone`, `stewards_demesne` |
| Spring-plantable crops | 2 (turnip, barley) |
| Food items with any cultural specificity | 1 (`barley_ale`) |
| Enemy factions with an identity | 0 (`bandit_melee`, `bandit_archer`, `raid_leader`) |

## A.3 The gaps, ranked

**G1 - There is no place.** Nothing in the project is named. The manor, the
village, the river, the road, the wood, the chapel, the inn Cedric's dialogue
mentions ("the village sings your praise at the inn") - none exist as named
things. Every peer in the genre leads with a named place because the place is
the product's identity: Pelican Town, Mineral Town, Portia, Mistria. This is
the root gap; most others are downstream of it.

**G2 - There is no premise.** The player wakes with 8 coin, a wooden hoe, five
turnip seeds, and a 30-coin debt, and the game never says why. The genre's
single strongest piece of framing - Stardew's inherited farm and the letter
that opens it - is a *thirty-second* piece of content that recontextualizes
sixty hours. There is no equivalent here, and `start_money: 8` currently reads
as a balance number rather than a story.

**G3 - The six are roles, not people.** Each villager is a name, two adjective
strings, a like, a dislike, and a work tile. No age, no sex, no trade, no
family, no history, no wants. This matters more here than in most projects
because **ADR-031 makes four of them marriage candidates** and **ADR-026 makes
one of them a thief the player must investigate**. Both systems require the
player to have a *model* of these people - courtship needs desire and
investigation needs motive - and there is currently nothing to build a model
from. `villager_1` through `villager_4` is, honestly, the tell.

**G4 - The village has no internal web.** Hilda, Cedric, Marta, and Bram do
not know each other. In every strong peer, the town's texture comes from
relationships *between* NPCs that the player observes and eventually gets
drawn into. It is also the mechanically cheapest depth available here: the
gossip trait, the alibi system, and the clue system all already exist and all
want a web to run on.

**G5 - Dialogue can only be keyed to one thing.** All 36 lines fire off a
community-standing band. There is no birthday, no season, no weather, no hour,
no per-person opinion line, no reaction to yesterday's raid. C2 in the content
plan fixes the engine; this questionnaire has to supply the *occasions* worth
writing for. (Note the compounding bug already flagged in the content plan:
`main.gd` reads `lines[0]`, so extra lines per band are dead content until C2
lands.)

**G6 - The mechanics have no fiction attached.** Systems shipped with numbers
and no story:
- Why 30 coin? Why market days 3/7/10/14/17/21/24/28? Why court on 12 and 26?
- Who is the black-market trader who appears on days 9 and 20? They have a
  25% premium and a detection roll and no name, face, or reason.
- Where do bandits come from, and why *this* spring?
- What is the drying shed, the hearth, the coop *in this village* - and who
  taught the player to use them?

**G7 - [COLLISION] The map's fiction contradicts itself.** This is the one
real structural problem the survey turned up, and it needs a ruling rather
than a paragraph of flavour. `farm_map.json` puts the chapel (10,15), the
market zone (25,15), the steward's demesne (15,5 - 6x6), two wells, and all
six villager homes inside a single 30x20 grid. `tenure.json` then says the
player owns (0,0)-(10,10) and may **rent the rest in three strips**. Worked
through:
- `strip_north` (x10-29, y0-9) contains **the steward's demesne** and Bram's
  house.
- `strip_southwest` (x0-14, y10-19) contains **the chapel**, a well, and
  Hilda's house.
- `strip_southeast` (x15-29, y10-19) contains **the market**, a well, and
  Marta's house.

So the player can currently rent, till, and plant turnips on the chapel, the
market, the lord's own demesne, and their neighbours' front doors. Mechanically
harmless today; fictionally incoherent the moment anyone writes a line about
where the village *is*. Block 1 asks the question that resolves it.

**G8 - The calendar is numbers.** Days are integers and seasons are the four
English words. The medieval frame offers the richest free texture in the whole
design here - a year keyed to feast days, quarter days, and the agricultural
round - and none of it is used. Peers name every festival and every birthday;
this project's calendar has eight market days, two court days, one mass, and
one raid, none of which are *called* anything.

**G9 - There is no food culture.** Items are `Turnip`, `Barley`, `Cabbage`,
`Wild Herb`, `Berry Pie`. The one item with a period-specific identity,
`barley_ale`, is also the most evocative thing in `items.json` - which is the
argument. Pottage, bread, cheese, and the distinction between what a peasant
eats and what a peasant *sells* are all absent.

**G10 - The register is undocumented.** The UI has already committed to a
diction ("Vigour", "Coin", "Satchel", "Resume Toil", "Keep Record") and
nothing writes that rule down. The next panel anyone adds will drift.

**G11 - Failure has no fiction.** Unpaid tithe produces a "soft failure at
season end". What does the game *say*? Who says it? In a game whose title is a
tax, this is the emotional climax of the slice and it is currently a summary
screen with a Restart button.

## A.4 What the genre does that this design has deliberately *not* copied

Worth stating so these do not get re-litigated as gaps:

- **Large casts.** Stardew has 34+ NPCs. ADR-029 fixes the cast at six. That
  is a defensible choice - *Pentiment* and *Graveyard Keeper* both do more with
  fewer - but it raises the per-character writing bar considerably. Six people
  must carry gossip, alibis, courtship, requests, and festival life.
- **Art-led charm.** The genre leans on portraits and sprites for character.
  This project is geometric primitives by contract. **All characterisation must
  therefore live in text**, which is an argument for writing *more* per
  character, not less.
- **Combat as a dungeon layer.** Peers put combat in a separate mine or
  dungeon. Here it is on the home map and tied to reputation, which is more
  interesting and means bandits need a *social* explanation, not just a spawn
  table.

---

# Part B - The question set

Answer format for every question:

> **Q:** the question
> **Why it matters:** what it unblocks
> **Default:** what happens if you say "default"
> **A:** _(unanswered)_

---

## Block 1 - The place

*Closes G1 and G7. Nothing else can be written until these are settled.*

**1.1 - What is the manor called, and what is the village called?**
**Why it matters:** every dialogue line, the title screen, the season summary,
and the name of the court all need it. Also settles whether manor and village
share a name (common) or differ (also common, and useful - it lets villagers
say one and the steward say the other).
**Default:** the manor is **Harrowmere**, the village that sits within it is
**Nettleford**. "The Manor of Harrowmere" is what the steward says; "Nettleford"
is what everybody else says.
**A:** **ACCEPTED as working names** (2026-08-06). Harrowmere = the manor,
Nettleford = the village. Held as provisional, not final - may be revisited
before the bible is written.

**1.2 - [COLLISION] What is the 30x20 map, in fiction?** Three candidate
readings, and they are not compatible:
   (a) **The whole village and its fields.** The player's holding is the
       northwest corner; the chapel, market, demesne, and neighbours' houses
       are the village proper. Then renting a "strip" must mean renting
       *arable land within a strip*, not the buildings on it - and
       `tenure.json`'s rectangles need reworking or reinterpreting.
   (b) **The player's holding only**, and the chapel/market/demesne tiles are
       *edges* - the point where you step off your land toward the village.
       Then the tenure rectangles are fine and the villager homes are wrong.
   (c) **An open-field parish** where land genuinely is intermixed and the
       player really can hold a strip beside the chapel - historically the most
       accurate reading, and it makes the tenure system a feature rather than
       a bug, but it needs the fiction to say so out loud.
**Why it matters:** this is the one contradiction in the shipped data. It
decides what `tenure.json` means, whether renting needs a rule against
buildings, and what the player is looking at every second of play.
**Default:** **(c)**, the open-field parish - it costs no code change, it makes
the existing strip rectangles correct instead of embarrassing, and "your land
is scattered among your neighbours' land" is a genuinely good pressure source
for a game about a village watching you.
**A:** **NONE OF THE ABOVE - the question is void** (2026-08-06). Owner ruling:
**the current 30x20 map is a placeholder.** It will be enlarged and become the
player's plot alone - home, buildings, fields - with the manor, the village,
the wilderness, and other farmers' plots living on **separate maps**. See
**X9**: this is a world-architecture change, not a fiction ruling, and it
supersedes the premise of this question. It also **dissolves X1**, since the
chapel, market, and demesne leave the player's map entirely.

**1.3 - What natural features bound and cross this place?** A river, a road, a
wood, a hill, a mill? Name them. The 30x20 grid is mostly rocky with loamy
patches at the west edge and scattered sandy pockets - what *is* that, in
landscape terms?
**Why it matters:** `soil_types.json` and the `farm_map` soil distribution
currently have no explanation. Wells, the commons, forage spawns (flint on
rocky, berries on loamy), and where bandits come from all hang off geography.
It also gives villagers something to talk about that is not the player.
**Default:** the **Nettle Brook** runs south through the sandy channel that
cuts the map; the **Harrow Road** crosses north to the market; the rocky
uplands are the **commons** where the village grazes and forages; the good
loam is the **West Furlong**, the old ploughland, which is why the player's
strip is there and why it is small. A wood, the **Cottersward**, lies off-map
north - source of the `wood` item and the direction raiders come from.
**A:** **OPEN - deferred to Block 1b** (2026-08-06). Owner: "no idea yet -
imagining a typical medieval setting, perhaps some hills, distant mountains."
Under X9 this question changes scale: it is no longer "what is on the 30x20
grid" but "what is the **region**, and which parts of it are maps." Re-asked
in Block 1b with a concrete proposal to react to.

**1.4 - What lies beyond the map, and how far away is it?** Is there a market
town, an abbey, a castle, a city? Can the player conceive of leaving?
**Why it matters:** the black-market trader arrives from somewhere on days 9
and 20. The bishop is threatened in the priest's dialogue. The lord is absent
*to* somewhere. Bandits come *from* somewhere. Right now all four are gestures
at an off-map world that does not exist. It also sets the size of the player's
ambition: a peasant who could walk to a city in a day is in a different story
than one who could not.
**Default:** a market town, **Coldwich**, two days' walk; a bishop's seat far
beyond it that nobody local has seen. The player cannot leave - not by law
(villeinage binds them to the manor) and not by means. That constraint is the
premise of the whole game.
**A:** **PARTIALLY ANSWERED - and the answer is structural** (2026-08-06).
Owner ruling: the world is **split across multiple maps** - a manor map, a
village-proper map, multiple wilderness maps, the player's plot, and other
farmers' plots in the region. What lies "beyond" is therefore mostly
*reachable*, which inverts the default above: the player is not sealed in.
Whether anything lies beyond the *region* (a market town, a bishop's seat) is
still open - see Block 1b. **This is X9** and requires an ADR before any
content is written against it.

**1.5 - How many people live here, beyond the six we meet?** Is the village
six households, or sixty with six who matter?
**Why it matters:** decides whether "the village" reputation axis means six
opinions or a community that the six *speak for*. Affects every line that says
"folks", "the village", "we". Also affects whether the mass and the festival
are intimate or crowded, and whether an unnamed crowd can be referenced for
free.
**Default:** roughly **thirty households**, of which we meet six. The village
axis is the whole parish's opinion; the six are the ones whose doors you know.
This is the cheap option - it buys crowd scenes and gossip chains without
adding a seventh NPC, respecting ADR-029's cast lock.
**A:** **DIRECTION SET, NUMBER OPEN** (2026-08-06). Owner: "ten to twelve
unique characters, maybe more." This **breaks ADR-029's cast lock of six** and
requires a superseding ADR - see **X8**. Genre benchmarks gathered and a
tiered-cast proposal put to the owner in Block 1b; final number pending.

---

## Block 1b - The region and the cast

*Opened 2026-08-06 after Block 1's answers changed the scale of the world.
Closes the deferred 1.3 and 1.5, and takes the two amendment rulings.*

### Genre reference: cast sizes (researched, not estimated)

| Game | Total named NPCs | Romanceable |
|---|---|---|
| Stardew Valley | 34 | 12 (6+6) |
| Story of Seasons: Friends of Mineral Town | ~32 | 12 |
| My Time at Portia | 50+ | ~26 |
| Coral Island | very large | 27-30 |
| Fields of Mistria (early access) | ~25 | 10 |
| **Tithe & Turnip (current)** | **6** | **4** |

The genre standard is roughly **30 named NPCs with 10-12 romanceable**. So an
owner target of 10-12 *unique characters* is still well below the genre's
headcount while being double the current cast.

**The critical caveat.** Every game in that table uses **portraits and sprites**
to carry character cheaply - a face does characterisation work no line of text
has to. This project is geometric primitives by contract, so **every character
costs strictly more words here than the same character costs Stardew**. That
argues for tiering the cast rather than picking a flat number.

**1b.1 - Adopt a tiered cast instead of a flat count?**
**Why it matters:** it lets the village *look* like 30 households while only
paying full writing cost on the people who carry systems (marriage, the
investigation, gossip, requests).
**Default (recommended):**
- **Tier 1 - Principals, 8.** Full character sheet, five standing bands,
  seasonal and event lines, gift prefs, request templates. Marriage candidates
  and investigation roles come from here. The current six plus two.
- **Tier 2 - Residents, 6-8.** A trade, a schedule, a handful of lines, gift
  prefs. No romance, no investigation role. They make the village map populated
  and give gossip somewhere to travel.
- **Tier 3 - Named background, unlimited and free.** Referenced in other
  people's dialogue, never instantiated as a node. "Old Wilf's ewes got out
  again." Costs nothing, buys a great deal.

Total instantiated: **14-16**, of which 8 are deep. Reads as a real village;
costs about twice the current writing rather than five times.
**A:** **DEFAULT ACCEPTED** (2026-08-06). Tiered cast adopted: 8 principals,
6-8 residents, unbounded named background. Recorded as **ADR-033**.

**1b.2 - Ruling on X8: supersede ADR-029's cast lock?**
**Why it matters:** ADR-029 is Accepted and says "cast stays at six." The ADR
log is append-only, so raising the cast needs a **new** ADR that explicitly
supersedes that clause, plus a `CLAUDE.md` edit (section 2's small-cast
language) and a regeneration of `AGENTS.md` / `DEEPSEEK.md`.
**Default:** yes - write **ADR-032, Cast expansion and tiering**, superseding
ADR-029's cast clause only. ADR-029's tone and anchoring rulings stand
untouched.
**A:** **YES** (2026-08-06). Written and Accepted as **ADR-033** - the number
032 was claimed mid-session by the dimetric-projection ruling landing in
parallel. ADR-029's tone and anchoring rulings stand untouched.
**X10 landed** (2026-08-07): `CLAUDE.md` v0.13 amends the marriage entry to
draw candidates from the ADR-033 Tier 1 principal cast (minus priest and
steward) rather than naming a fixed four; `AGENTS.md` / `DEEPSEEK.md`
regenerated and the contract-sync suites re-verified green.

**1b.3 - Ruling on X9: how is the multi-map world sequenced?**
**Why it matters:** this is the largest single change proposed to the project
so far. It is not a content pass - it touches the scene flow in the contract,
the map data format, tenure, NPC schedule coordinates, the farm grid's key
space, the renderers, and the save format. Options:
   (a) **Do it first**, as a new systems sprint before C1-C6 resume. Content is
       then written once, against the real world.
   (b) **Do it after C1-C4.** Write the tone, diction, and character
       interiority now - none of which depends on geography - and land the
       world change before C5/C6.
   (c) **Design it now, build it later.** Write the ADR and the target data
       shape immediately so C1's bible describes the real region, but do not
       write the code until the content passes are done.
**Default (recommended):** **(c)**. The bible must describe the world that will
exist, or it gets rewritten; but stopping content work for a multi-sprint
systems change wastes the fact that tone, diction, and the six existing
characters are all geography-independent. Write **ADR-033, The region: multiple
maps and zone-keyed world state**, then keep writing.
**A:** **(c) - design now, build later** (2026-08-06). Written and Accepted in
principle as **ADR-034**, implementation deferred until scheduled as a systems
sprint in `roadmap.md`. C1-C4 proceed against it. Note it **will** require a
SAVE_VERSION bump and migration when built - unlike ADR-032, which forbids one.

**1b.4 - What is the region, concretely?** (Re-asked from 1.3/1.4 at the new
scale. You said "typical medieval - hills, distant mountains." Here is a
concrete version to react to, edit, or reject.)
**Default:**
A **river valley** - the vale of the **Nettle**, a day's walk end to end.
- **Mountains** stand blue and distant to the north and are never reached.
  They are scenery and weather, and they are where every story about
  "somewhere else" points.
- **Uplands and hills** ring the vale: thin soil, sheep, the **commons**, and
  the wilderness maps. This is where forage, flint, wood, and bandits live.
- **The vale floor** is the good land: the manor's demesne, the village of
  **Nettleford**, and the tenant plots including the player's.
- **The Harrow Road** runs the length of the vale, north to the uplands and
  south toward **Coldwich**, the market town - present as a destination, not
  necessarily a map.
- Maps, then: *player's plot* / *village* / *manor* / *2-3 wilderness (upland,
  wood, riverbank)* / *2-3 neighbouring plots*. Eight to ten zones.

**Why this shape:** it gives every shipped system a home. Soil types become
geography (loam on the vale floor, sandy by the brook, rocky upland). Forage
and raids come from the uplands. The market and court are in the village. The
demesne where corvee is worked is the manor's. Nothing has to be invented
twice.
**A:** **DEFAULT ACCEPTED** (2026-08-06). The vale of the Nettle, mountains
distant and unreachable to the north, uplands as commons and wilderness, vale
floor as the good land, the Harrow Road running toward Coldwich. 8-10 zones.
Recorded in **ADR-034**.

**1b.5 - Who are the two new Tier 1 principals?** (Assuming 1b.1's default.)
**Why it matters:** the current six are steward, priest, and four villagers -
there is no one the player's own age doing the player's own job, and no
authority figure who is *not* the manor or the church. Both are standard genre
roles and both are missing.
**Default:**
- **A neighbouring tenant** - a farmer on an adjacent plot, roughly the
  player's age and circumstance. Gives the player a peer, a benchmark, and
  someone who is failing or succeeding visibly alongside them. Uses the
  "other plots run by other farmers" maps you described.
- **A miller or an alewife-equivalent outsider** - someone who holds economic
  power in the village without holding manor or church authority, and who can
  be leaned on when the market stall is closed. The natural home for the
  black-market thread (see 16.4), which currently has no face.
**A:** **DEFAULT ACCEPTED** (2026-08-06). Two new principals: **a neighbouring
tenant** (the player's peer) and **a holder of economic power outside manor and
church authority** (miller or alewife), who takes the black-market thread.
Both need full sheets - added as **Blocks 6b and 6c**, to be asked after the
existing six are done.

---

## Block 2 - The manor and the lord

*Closes part of G6. Feeds `tithe.json`, `manor.json`, `chores.json`, ADR-003,
ADR-017, ADR-025.*

**2.1** Who holds this manor - name, title, and are they a person, a family, or
an institution (an abbey holding a manor is very period and changes the
church's role entirely)?
**Default:** Sir Edric Vane, a minor knight, holds Harrowmere of a greater lord
nobody local names.
**A:** **DEFAULT ACCEPTED, WITH A MAJOR REVISION** (2026-08-06). Sir Edric Vane
it is - **but the lord is not an absent abstraction.** Owner ruling: he makes
**multiple appearances each season**, being otherwise away on lordly business -
war, patrols, attendance on his own lord, other lords' weddings. See **X11**:
this makes the lord a character rather than a rumour, and the cast structure
ADR-033 just locked has no room for him.

**2.2** Why is the lord absent, and could they return within the game's span?
An absent lord who might *arrive* is a different pressure than one who never
will.
**Default:** on campaign abroad, third year. Will not return in the slice, but
the possibility is spoken of.
**A:** **ANSWERED BY 2.1 - the default is overturned** (2026-08-06). He returns
repeatedly and predictably. The pressure is therefore not "the lord is gone"
but "the lord is coming back, and will see what you have done." That is a
stronger premise and it changes the emotional shape of the season.

**2.3** Why is the assessment **30 coin** specifically, and is it the same for
every holding or scaled to the player's? (ADR-017 already made it
acreage-scaled - the fiction has to agree.)
**Default:** it is the customary rent-in-money for a half-virgate holding,
fixed by the manor roll "since the old lord's time", and the steward has no
authority to change it - which is why arguing is pointless and why paying it is
the whole problem.
**A:** **ACREAGE-SCALED, WITH A REASONABLE BASE - and this is already built**
(2026-08-06). Owner ruling matches the shipped implementation: `tithe.json` has
carried `base_amount: 20` plus `coin_per_tilled_tile: 1.5` since ADR-017, which
explicitly amended ADR-003's fixed 30. The question's premise (a fixed 30) was
taken from `CLAUDE.md`, which is **stale** - see **X12**. Open sub-question on
whether the scaling axis is right: it currently taxes *tilled* tiles, i.e. it
taxes effort. Carried into Block 2b.

**2.4** Who does Steward Aldric answer to, and what is he afraid of? The
content plan already rules that "he answers to someone, and that someone is not
the player's friend."
**Default:** he answers to the lord's bailiff at Coldwich, who audits the manor
roll. Aldric's fear is a shortfall on the roll with his name against it.
**A:** **YES, AND THE BAILIFF APPEARS TOO** (2026-08-06). Both the bailiff and
Sir Edric are on-screen characters who arrive at intervals. Folded into **X11**
with the lord. Aldric's fear stands and is now dramatised rather than
described - the player can watch him be audited.

**2.5** What is the manor *court*, socially? Days 12 and 26 with fines for
witnessed violence, illegal sale, and false accusation. Is it feared, resented,
routine, or a village entertainment where everyone turns up to watch?
**Default:** routine and public - held in the churchyard, half legal
proceeding and half village theatre. Everyone attends. Being fined is
humiliating before it is expensive, which is why the reputation hit matters
more than the coin.
**A:** **DEFAULT ACCEPTED** (2026-08-06). Public, churchyard, everyone attends,
humiliation before expense.

---

## Block 2b - Itinerants, and what the tithe taxes

*Opened 2026-08-06. Block 2's answers put two new people on screen and
questioned the tithe's scaling axis.*

**2b.1 - Ruling on X11: add a fourth cast tier for itinerants?**
**Why it matters:** ADR-033 (written one exchange ago) tiers the cast as 8
principals / 6-8 residents / unbounded background, and closes Tier 1 with "a
ninth principal is a new ADR." Sir Edric and the bailiff fit none of those
tiers: they are not residents (no home zone, no daily schedule), they are not
background (they appear on screen and carry systems), and making them
principals would take Tier 1 to ten and reopen a ruling that is one day old.
**Default (recommended):** a fourth tier, **Itinerants**, defined by *arriving*
rather than living here:
- Scheduled by **day**, not by hour - the pattern `manor.json` already uses for
  `court_days`, `black_market.visit_days`, and `market_days`.
- No home zone, no daily schedule, no gifting, no romance, no requests.
- A focused dialogue set tied to why they came, and the authority to change the
  player's situation when they do.
- Members: **Sir Edric Vane** (the lord), **the bailiff**, and **Wat the
  chapman** (the black-market trader from 16.4, who has always been this shape
  and had no tier to sit in).
This is cheaper than three more principals, it gives the grey-economy trader a
home in the taxonomy, and it recognises a category the data already had.
Recorded as an amendment to ADR-033.
**A:** **DEFAULT ACCEPTED** (2026-08-06). A fourth tier, **Itinerants**, is
added to ADR-033: Sir Edric Vane, the bailiff, and Wat the chapman. Defined by
arrival rather than residence - day-scheduled, no home zone, no daily
schedule, no gifting/romance/requests, a focused dialogue set tied to why they
came, and the authority to change the player's situation. Resolves **X11**;
the amendment is still to be recorded in the ADR log.

**2b.2 - How often does Sir Edric appear, and what does an appearance *do*?**
**Why it matters:** "multiple appearances each season" needs a cadence and a
consequence, or he is a cutscene. The season is 28 days and already carries 8
market days, 2 court days, a mass/festival on 21, black-market visits on 9 and
20, and a scripted raid on 15. The calendar is crowded; his days must be chosen
against it.
**Default:** **three appearances**, each with a distinct function and none
colliding with an existing beat:
- **Early (day ~5) - the return.** He is simply *there*, riding the demesne.
  Establishes he exists and that he looks at things. No mechanic.
- **Mid (day ~15-16) - the reckoning.** He hears something that matters -
  arriving in the wake of the scripted raid, which gives the raid a political
  consequence it currently lacks.
- **Late (day ~27) - the accounting.** He reviews the roll before the season
  closes. This is where standing with the manor cashes out, and it gives the
  season-end summary (Block 25) a *person* to deliver it rather than a screen.
**A:** **DEFAULT ACCEPTED** (2026-08-06). Three appearances, none colliding
with an existing beat: **early (~day 5) the return** - present, riding the
demesne, no mechanic; **mid (~day 15-16) the reckoning** - arrives in the wake
of the scripted raid, giving the raid the political consequence it lacked;
**late (~day 27) the accounting** - reviews the roll before the season closes,
where manor standing cashes out and the season-end summary gains a person to
deliver it.

**2b.3 - What is the bailiff for, mechanically and dramatically?**
**Why it matters:** he is currently a name in Aldric's backstory. If he appears,
he needs a reason the player cares.
**Default:** he arrives to **audit**, on a day the player is not told in
advance. He is the one character who can overrule Aldric - which cuts both
ways: at good manor standing Aldric's word protects the player, and at bad
standing the audit is where Aldric stops protecting them. That makes the manor
standing axis, which currently only adjusts prices and fines, into something
with a face.
**A:** **DEFAULT ACCEPTED** (2026-08-06). The bailiff arrives to **audit** on a
day the player is not told in advance. He is the one character who can overrule
Aldric - at good manor standing Aldric's word protects the player, and at bad
standing the audit is where the protection ends. The manor standing axis gains
a face.

**2b.4 - Should the tithe scale on *tilled* tiles or on *held* acreage?**
**Why it matters:** a real design question, not just fiction. `tithe.json`
currently charges `base_amount: 20` plus `coin_per_tilled_tile: 1.5`, so the
assessment **taxes effort** - every tile the player works raises what they owe.
That is backwards both historically (rent fell on the size of the holding, not
on how hard it was farmed) and motivationally (it penalises the core verb).
Scaling on *rented/held* acreage instead makes the tenure system from ADR-023
the risk it was designed to be: taking a strip is a bet, and working it harder
is how you win the bet rather than how you lose it.
**Default:** move the scaling to **held acreage** (owned plot + rented strips),
keep a base that stands alone. Base 20 on the starting plot with nothing rented
is the "reasonable initial assessment" the owner asked for. **Flag:** this
amends ADR-017 and changes `tithe.json`'s shape, so it needs its own ADR and a
data version bump. Non-trivial - your call whether it is worth opening.
**A:** **DEFAULT ACCEPTED** (2026-08-06). The tithe scales on **held acreage**
(owned plot + rented strips), base 20 standing alone. Working a tile no longer
raises the assessment - taking a strip is the bet, and working it harder is how
the bet is won. **Flag stands:** this amends ADR-017 and changes `tithe.json`'s
shape; it opens its own ADR and a data version bump - see **X13**.

---

## Block 3 - The church

*Feeds ADR-012, `church.json`, mass, the chapel, the ceremony (ADR-031).*

**3.1** What is the chapel called and to which saint is it dedicated? (An
invented saint, per ADR-029's no-real-people rule.)
**Default:** the chapel of **Saint Ada of the Furrow**, a local invented saint
said to have been a ploughman's daughter - which makes her the patron of
exactly this village's exactly this problem.
**A:** **DEFAULT ACCEPTED** (2026-08-06). The chapel of **Saint Ada of the
Furrow**; invented local saint, a ploughman's daughter, patron of exactly this
village's problem.

**3.2** Why is the church tithe **voluntary** when the lord's is not? ADR-012
locked the mechanic; the fiction is unwritten and currently reads as a
mechanical convenience.
**Default:** the real tithe is taken in sheaves off the field before the
player ever touches the crop - already gone, invisible, not a decision. What
the box at the chapel takes is the *offering*, which is voluntary by
definition. This makes the game's mechanic accurate rather than a shortcut.
**A:** **ANSWERED - custom** (2026-08-06). The church is **very weak** in this
village and has no ability to punish those who do not tithe - its only
instrument is **social pressure from other church members**: essentially
everyone, but not everyone. The voluntary mechanic is therefore institutional
weakness, not theology or convenience. (The default's sheaves-off-the-field
framing was not adopted.)

**3.3** What does Father Tomas want? He is `devout` and `forgetful` and has
nothing else.
**Default:** to repair the chapel roof before winter, and to be remembered as
having kept the parish whole. His forgetfulness is early decline and he knows
it.
**A:** **ANSWERED - custom** (2026-08-06). Forgetfulness is a byproduct of his
devoutness - attention turned toward the faith rather than toward the world,
and not extreme forgetfulness. It is not politics and it is not early decline.
His goals are to **repair and grow the church** because he genuinely believes
in his religion and its ability to help people.

**3.4** What is the church's relationship to the manor - allied, rival, or
uneasy? This determines whether donating to the church can ever cost the
player manor standing (it currently costs nothing, which is a missed tension).
**Default:** uneasy. The chapel is poor, the manor rich, and Tomas will not say
so out loud. Donating does not currently anger Aldric - and the question of
whether it *should* is a live design question, not just flavour.
**A:** **ANSWERED - custom** (2026-08-06). The manor pays the father a
**stipend** because a church in the demesne is **prestigious**. Donating does
not anger the manor; the church simply gets no help beyond the basic stipend,
and the church and its associated donated lands must sustain themselves. The
unease is financial dependence on a prestige payment, not open rivalry.

**3.5** What is mass, in practice, and why is attendance on day 21 at hour 9
rather than weekly? (Currently a single fixed-day check in `main.gd`.)
**Default:** mass is weekly and assumed; **day 21 is a feast of Saint Ada**,
the one attendance the parish actually counts. That reframes the existing
mechanic as a special occasion rather than an oddly rare Sunday.
**A:** **DEFAULT ACCEPTED** (2026-08-06). Mass is weekly and assumed; **day 21
is a feast of Saint Ada**, the one attendance the parish actually counts.

---

## Block 4 - The player character

*Closes G2. Feeds the title screen, the intro, `player.json` starting state.*

**4.1** Who is the player character - name (or is it player-chosen?), age, sex
(or player-chosen), and legal status: villein (bound, owing labour) or free
tenant (owing rent only)? The distinction is the entire political frame of the
game.
**Default:** player-chosen name and sex; roughly twenty; a **villein** -
bound to the manor, owing both rent and labour, which is exactly why corvee
can be imposed on short notice.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Player-chosen name and sex, roughly
twenty, a **villein** - bound to the manor, owing both rent and labour, which
is exactly why corvee can be imposed on short notice.

**4.2** Why does the player hold this strip *now*? What happened immediately
before day 1?
**Default:** the previous holder - the player's parent or aunt - died over
winter, and the manor court granted the holding to the player on payment of a
**heriot** (a death duty). Paying it is what left them with 8 coin. That single
sentence explains `start_money: 8`, the debt, the hoe, and why the village is
watching to see if they can hold it.
**A:** **DEFAULT ACCEPTED** (2026-08-07). The previous holder - the player's
parent or aunt - died over winter; the manor court granted the holding on
payment of a **heriot** (a death duty), which is what left them with 8 coin.
One sentence explains `start_money: 8`, the debt, the hoe, and why the village
is watching.

**4.3** What does the player know how to do on day 1, and what do they not?
The skill system starts everyone at level 1 in farming, foraging, combat, and
labor.
**Default:** raised to the work but never responsible for it. Competent with a
hoe, clueless about the roll, the market, and the court - which is why the
tutorial framing can be an NPC explaining things without it feeling artificial.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Raised to the work but never
responsible for it - competent with a hoe, clueless about the roll, the
market, and the court; the tutorial framing can be an NPC explaining things
without feeling artificial.

**4.4** Does the village *want* the player to succeed? Their standing starts at
neutral (0) on all three axes. Is that indifference, suspended judgement, or
guarded goodwill?
**Default:** suspended judgement. They knew the previous holder. They are
waiting to see which way this one goes - and they will say so, which gives
every early dialogue line a reason to exist.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Suspended judgement - they knew the
previous holder and are waiting to see which way this one goes; they will say
so, which gives early dialogue a reason to exist.

**4.5** What does the player *want*? The game needs a stated ambition beyond
"do not fail", because a season-end summary that only measures the tithe is
measuring survival, not aspiration.
**Default:** to hold the land free and clear - to get the holding entered on
the manor roll in their own name, secure against the next steward's whim. That
is a goal the tithe, the reputation axes, and marriage all feed, and it is the
sentence the title screen should be built around.
**A:** **ANSWERED - default plus addition** (2026-08-07). Yes - to hold the
land free and clear, entered on the manor roll in the player's own name,
secure against the next steward's whim. Added: despite its issues, Nettleford
is a **relatively safe and peaceful village**, far from the typically
over-bearing rule of nobles, and the lord is gone frequently - the player
wants to keep what is worth keeping, not merely survive what is owed.

---

## Block 5 - Time, calendar, era

*Closes G8. Feeds `time.json`, market/court/festival scheduling, ADR-030.*

**5.1** How is the year reckoned in-world - regnal year, year of grace, or
simply "the third spring since the murrain"? And do the seasons have in-world
names distinct from `spring/summer/autumn/winter`?
**Default:** seasons keep their plain names in the data (no code change) but
the *fiction* calls spring **seedtime**, summer **haymonth**, autumn
**harvest**, winter **the dead months** - available to writers as flavour
without touching `time.json`.
**A:** **ANSWERED - custom** (2026-08-07). Both reckonings are used,
**depending on the personality of the character speaking** - formal
(regnal/year-of-grace) for characters who deal with records and authority,
folk ("the third spring since the murrain") for those who do not. **Season
names: DEFAULT ACCEPTED, soft** (2026-08-07). The fiction adopts spring
**seedtime**, summer **haymonth**, autumn **harvest**, winter **the dead
months** - data keeps the plain names, and the names are **not deeply
embedded**: easy to change later in development.

**5.2** What is a "day" numbered 1-28 called by the people in it? Do they use
day numbers at all, or feast days and the phases of the work?
**Default:** villagers never say "day 17". They say "market day", "before Ada's
feast", "after the court sat". The HUD keeps numbers; the writing never uses
them. This is a diction rule with teeth.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Villagers never say day numbers -
"market day", "before Ada's feast", "after the court sat". HUD keeps numbers;
the writing never uses them.

**5.3** Why are market days **3, 7, 10, 14, 17, 21, 24, 28** - twice a week,
uneven? Is there a reason, or should the fiction just say "market days"?
**Default:** the manor holds market by charter on two fixed days each week; the
uneven numbers are the calendar falling where it falls. No explanation needed
beyond "twice weekly by charter".
**A:** **DEFAULT ACCEPTED** (2026-08-07). Market by charter, twice weekly; the
uneven day numbers are the calendar falling where it falls - "twice weekly by
charter" is all the fiction needs.

**5.4** What is the agricultural truth of a Spring here? What is *actually*
happening in the fields around the player in days 1-28, beyond their own
turnips?
**Why it matters:** gives ambient dialogue 28 days of subject matter for free,
and grounds the corvee chore list (`till_demesne`, `water_demesne`,
`harvest_demesne`, `carry_produce` - note that harvesting in spring is
currently a small fiction problem).
**Default:** early spring is ploughing and sowing the lord's demesne (hence
corvee); mid-spring the stock goes out to the commons; late spring is weeding
and the hungry gap - stores run out before the harvest comes in, which is the
real reason the tithe hurts in *this* season.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Early spring is ploughing and sowing
the demesne (hence corvee); mid-spring the stock goes to the commons; late
spring is weeding and the hungry gap - stores run out before the harvest, the
real reason the tithe hurts in this season.

**5.5** Is there weather lore? Rain is 30% in spring and auto-waters the
tilled cells - the single most consequential random event in the game and
nobody comments on it.
**Default:** yes, and villagers speak it - a wet spring is a good spring here
because the loam is thin. Rain is *good news* in dialogue, which quietly
teaches the mechanic.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Yes - villagers speak the lore: a wet
spring is a good spring because the loam is thin. Rain is good news in
dialogue, quietly teaching the mechanic.

---

## Block 6 - Hilda (`villager_1`)

*Currently: `gossip`, `early_riser`; likes wild_berry and barley; dislikes
flint; works (5,12) 08:00-18:00; requests wild berries.*

**6.1** Age, sex, trade, and household - who does she live with?
**Default:** fifties, widow, the village's alewife - she brews and sells,
which is why she likes barley and why everyone passes through her door.
**A:** **ANSWERED - custom** (2026-08-07). **Twenties**, widow, the village's
alewife - brews and sells, which is why she likes barley and why everyone
passes through her door. (Age changed from the default's fifties; all else
stands.)

**6.2** What does she want, and what does she fear?
**Default:** wants her brewing recognised as the village's; fears becoming
the old woman nobody visits.
**A:** **ANSWERED - default plus addition** (2026-08-07). Wants her brewing
recognised as the village's; fears becoming the old woman nobody visits - and
specifically fears being **ignored for her gender**, passed over because she
is a woman.

**6.3** Her `gossip` trait is due to become mechanical (C3: reveals
investigation clues more readily). What *kind* of gossip is she - malicious,
warm, compulsive, transactional?
**Default:** warm and compulsive. She is not cruel; she simply cannot hold a
thing. That makes her clue-giving feel like character, not a quest dispenser.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Warm and compulsive gossip - not
cruel, simply unable to hold a thing; clue-giving reads as character rather
than a quest dispenser.

**6.4** She is a marriage candidate under ADR-031. Given the default above
(fifties, widow) - is she, or should the four candidates be re-cast?
**[COLLISION risk]** ADR-031 names all four village villagers as candidates.
**Default:** re-cast is **not** needed - drop Hilda from the candidate list in
fiction and let the *game* gate her out the same way it gates the priest and
steward, or make her younger. **This one genuinely needs your ruling**, because
ADR-031's text says all four and the ADR log is append-only.
**A:** **RULING** (2026-08-07). **Age reverted to twenties** (per 6.1); Hilda
**remains a marriage candidate** under ADR-031, consistent with all four
village villagers being candidates. Resolves **X2** - the older-widow
characterisation that collided with candidacy no longer exists.

**6.5** How does she regard the player at hostile / cold / neutral / warm /
friendly? One sentence each - this is the shape every character sheet takes.
**Default:** hostile: shuts the door and *talks*. cold: polite, and you hear
about it later. neutral: news and weather. warm: advice you did not ask for.
friendly: treats you as family and defends you unprompted.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Hostile: shuts the door and *talks*.
Cold: polite, and you hear about it later. Neutral: news and weather. Warm:
advice you did not ask for. Friendly: treats you as family and defends you
unprompted.

---

## Block 7 - Cedric (`villager_2`)

*Currently: `gruff`, `night_owl`; likes arrow and flint; dislikes wild_onion;
requests flint; his dialogue references an inn.*

**7.1** Age, sex, trade, household?
**Default:** forties, the village's smith or hedger - the flint and arrow
preferences point at someone who makes and mends.
**A:** **ANSWERED - custom** (2026-08-07). **Thirties**, the village's smith
or hedger - the flint and arrow preferences point at someone who makes and
mends. (Age changed from the default's forties; all else stands.)

**7.2** What does he want, what does he fear?
**Default:** wants the village able to defend itself; fears being right about
the danger and ignored.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Wants the village able to defend
itself; fears being right about the danger and ignored.

**7.3** He is `night_owl` and that trait is about to become a real schedule
offset. *Why* is he up at night? An answer here makes him an alibi problem in
the ADR-026 investigation, which is free depth.
**Default:** he keeps watch on the road, unpaid and unasked, since the raids
started. It makes him the man with no alibi and the man most likely to have
seen something - both at once.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Keeps watch on the road, unpaid and
unasked, since the raids started - the man with no alibi and the man most
likely to have seen something, both at once.

**7.4** He mentions an inn. Does one exist? Nothing in the map or data has one.
**Default:** no inn - Hilda's alehouse is the gathering place, and the line
gets rewritten. Cheaper than adding a building, and it ties two characters
together.
**A:** **ANSWERED - custom** (2026-08-07). **Hilda's alehouse doubles as an
inn** for travellers who come this way - not unheard of, but not frequent
either. She houses guests in an **outbuilding separate from the alehouse**,
which doubles as her own home as well. Resolves **X4**: Cedric's line stands,
no building added to the map.

**7.5** Five standing bands, one sentence each.
**Default:** hostile: turns his back. cold: single syllables. neutral: work
talk only. warm: shares tools. friendly: shares what he has seen on the road -
which is mechanically the best reward in the game.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Hostile: turns his back. Cold: single
syllables. Neutral: work talk only. Warm: shares tools. Friendly: shares what
he has seen on the road - mechanically the best reward in the game.

---

## Block 8 - Marta (`villager_3`) - the thief and the candidate

*Currently: `quiet`, `thief`; likes turnip and wild_herb; dislikes barley;
works (22,13) - beside the southeast well; is `RaidManager`'s thief; is an
ADR-031 marriage candidate. This collision is called "deliberate and worth
keeping."*

**8.1** Age, sex, trade, household?
**Default:** late twenties, cottar (no land of her own), hires out by the day.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Late twenties, cottar (no land of her
own), hires out by the day.

**8.2** **Why does she steal?** This is the most important single answer in the
whole questionnaire - it determines whether the investigation is a whodunit or
a tragedy, and whether catching her feels like justice or like a betrayal.
**Default:** a dependent she cannot feed - a sick mother, an unacknowledged
child, a debt to the wrong person. She steals *food and seed*, never coin, and
never from the poorest. Accusing her correctly should cost the player
something.
**A:** **DEFAULT ACCEPTED** (2026-08-07). A dependent she cannot feed - a sick
mother, an unacknowledged child, a debt to the wrong person. She steals food
and seed, never coin, never from the poorest. Accusing her correctly costs the
player something.

**8.3** Does she know the player suspects her, and does her dialogue change as
the investigation advances?
**Default:** yes, and her lines get quieter and more careful. The `quiet` trait
becomes characterisation instead of a label.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Yes - and her lines get quieter and
more careful as the investigation advances; the `quiet` trait becomes
characterisation rather than a label.

**8.4** If she is courted and married, what happens to the theft? The systems
do not currently talk to each other.
**Default:** marrying her ends the thefts silently - she no longer needs to -
and the player is left holding the knowledge. That is the best possible use of
the collision ADR-031 asked to keep. **Needs your ruling**, as it implies a
code touch in C6.
**A:** **DEFAULT ACCEPTED - ruling** (2026-08-07). Marrying her ends the thefts
silently - she no longer needs to - and the player is left holding the
knowledge. Resolves **X3**. **Implied work:** a code touch in C6 so the
marriage and theft systems talk.

**8.5** Five standing bands, one sentence each.
**Default:** hostile: says nothing at all. cold: courteous and absent. neutral:
deflects ("I'm just a simple farmer" - the existing line, which is a *lie* and
should be flagged as one in the sheet). warm: small true things. friendly:
tells you something she should not.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Hostile: says nothing at all. Cold:
courteous and absent. Neutral: deflects - "I'm just a simple farmer", the
existing line, a *lie* flagged as one in the sheet. Warm: small true things.
Friendly: tells you something she should not.

---

## Block 9 - Bram (`villager_4`)

*Currently: `boastful`, `night_owl`; likes wild_onion and cabbage; dislikes
wild_berry; lives at (27,8) - the far northeast, apart from the others;
mentions "trouble on the roads" and "the crossroads".*

**9.1** Age, sex, trade, household?
**Default:** thirties, carter or drover - which explains living out by the
road and knowing what is on it.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Thirties, carter or drover - living
out by the road explains knowing what is on it.

**9.2** What does he want, what does he fear?
**Default:** wants standing he has not earned; fears being found ordinary.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Wants standing he has not earned;
fears being found ordinary.

**9.3** His `boastful` trait plus his road knowledge makes him the natural
unreliable witness in the investigation. Is his information good, bad, or
inflated-but-founded?
**Default:** inflated but founded - always a real thing underneath an
exaggeration, which is the most interesting kind of witness and gives the
gossip/clue system a second flavour distinct from Hilda's.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Inflated but founded - a real thing
underneath every exaggeration; the gossip/clue system gains a second flavour
distinct from Hilda's.

**9.4** He lives apart from the village. Why - choice, exclusion, or trade?
**Default:** trade, and he tells himself it is choice.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Trade - and he tells himself it is
choice.

**9.5** Five standing bands, one sentence each.
**Default:** hostile: loud contempt. cold: performative indifference. neutral:
stories about himself. warm: stories with the player in them. friendly: drops
the performance, briefly.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Hostile: loud contempt. Cold:
performative indifference. Neutral: stories about himself. Warm: stories with
the player in them. Friendly: drops the performance, briefly.

---

## Block 10 - Steward Aldric

**10.1** Age, background, and *class* - is he gentry, a risen peasant, or an
outsider brought in? A risen peasant steward is the most interesting version
in a game about a peasant.
**Default:** fifties, a villein's son who learned letters and rose - resented
by the village for exactly that, and never quite trusted by the manor either.
**A:** **ANSWERED - custom** (2026-08-07). Age is **late thirties to early
forties** (not fifties); otherwise the default stands - a villein's son who
learned letters and rose, resented by the village for exactly that, and never
quite trusted by the manor either.

**10.2** Is he corrupt, rigid, or fair? The court fines, the corvee, and the
detection roll all read differently depending.
**Default:** rigid, not corrupt. He will not take a bribe and will not bend a
rule, and both of those hurt the player equally.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Rigid, not corrupt - will not take a
bribe and will not bend a rule, and both hurt the player equally.

**10.3** What could make him an ally? He has a `likes` list and an opinion axis
that nothing gates.
**Default:** competence. He respects a holding kept in order and says so
grudgingly - and at high opinion he warns the player before the court sits.
**A:** **ANSWERED - default plus addition** (2026-08-07). Competence, as
defaulted - a holding kept in order earns grudging respect, and at high
opinion he warns the player before the court sits. **Added:** any action that
benefits the manor **and** the village also moves him.

**10.4** Does he know about Marta?
**Default:** he suspects and lacks proof, and would rather have the proof from
the player than find it himself.
**A:** **DEFAULT ACCEPTED** (2026-08-07). He suspects and lacks proof, and
would rather have the proof from the player than find it himself.

**10.5** Five standing bands - the existing five lines are the strongest
writing in the project. Keep, revise, or replace?
**Default:** keep all five as canonical and write outward from them.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Keep all five as canonical and write
outward from them.

---

## Block 11 - Father Tomas

**11.1** Age, background - local boy or sent here?
**Default:** sixties, local, never left, quietly aware that is why he is still
in a parish this small.
**A:** **ANSWERED - custom** (2026-08-07). **Thirties - still trying to prove
himself.** The default background (local, never left) stands; under the plague
ruling, a parish this small having a priest this young is the demographic
truth rather than a mark of failure.

**11.2** How does his `forgetful` trait present, and is it played for warmth,
sadness, or comedy? (The register is grounded-and-hopeful; this is a place the
tone rules will be tested.)
**Default:** warmth shading to sadness. He repeats himself; nobody corrects
him. Never comedy.
**A:** **ANSWERED - custom** (2026-08-07). Played for **comedy** - a quirk he
plays into deliberately because he **prefers people to underestimate him and
then surprising them**; a tactic he uses frequently. **Flag:** sits alongside
3.3 as trait-plus-performance - the forgetfulness is genuine devoutness, and
he leans into the perception of it on purpose.

**11.3** What does he think of the lord's tithe? He is the one character with
standing to have an opinion about the game's central injustice.
**Default:** he thinks it is lawful and says so, and the player can see it
costs him to say it.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Thinks it lawful and says so - and
the player can see it costs him to say it.

**11.4** He performs the marriage ceremony (ADR-031). What is a wedding here -
banns, a churchyard door, a feast? And does he require anything of the couple?
**Default:** banns read three market days running, vows at the church door,
ale after at Hilda's. He asks only that they mean it.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Banns read three market days running,
vows at the church door, ale after at Hilda's; he asks only that they mean it.

**11.5** Five standing bands - keep, revise, or replace the existing lines?
**Default:** keep; his "The bishop will hear of this" hostile line implies an
off-map church hierarchy that Block 1.4 should make real.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Keep the five lines canonical; the
"The bishop will hear of this" line implies an off-map church hierarchy that
Block 1.4 should make real.

---

## Block 12 - The web between them

*Closes G4. Six people, fifteen possible pairs - not all need content.*

**12.1** Which **three pairs** carry a real relationship the player can
observe? (Three is the number that fits a six-person cast without becoming a
soap opera.)
**Default:** Hilda & Tomas (old friends, she manages his forgetting); Cedric &
Aldric (mutual contempt - the watchman and the rule-keeper); Marta & Hilda
(Hilda half-knows and says nothing, which is the one secret in the village
bigger than the player's).
**A:** **DEFAULT ACCEPTED** (2026-08-07). Hilda & Tomas (old friends; she
manages his forgetting); Cedric & Aldric (mutual contempt - the watchman and
the rule-keeper); Marta & Hilda (Hilda half-knows and says nothing - the one
secret in the village bigger than the player's).

**12.2** Is anyone related by blood or marriage?
**Default:** no - a village of thirty households where our six are unrelated
is more useful, since it keeps marriage clean and keeps every relationship
chosen rather than given.
**A:** **ANSWERED - custom** (2026-08-07). **Yes - there should be familial
relationships in at least a few of the primary six, where it makes sense.**
The default's unrelated-six framing is overturned. **Flag for C6/bible
authoring:** four of the six are marriage candidates; family ties that make
two candidates kin would break ADR-031, so ties involving the non-candidates
(Tomas, Aldric) or candidate-to-non-candidate pairs are the natural homes.

**12.3** What does the village *disagree* about? A community with no internal
politics has nothing to draw the player into.
**Default:** the commons - whether the uplands should be grazed or foraged,
and whether the manor is quietly enclosing them. Cedric and Bram are on
opposite sides. This also gives `forage.json` a political dimension for free.
**A:** **ANSWERED - default plus addition** (2026-08-07). The commons
disagreement stands (grazing vs. foraging; whether the manor is quietly
enclosing the uplands; Cedric and Bram on opposite sides). **Added - the
church's presence:** the plague mostly wiped the church's influence from the
region, allowing old beliefs and habits to seep back into the village and the
surrounding areas; now the church is back, and not everyone is glad.

**12.4** Who does the village blame for the raids?
**Default:** each other, then the manor for not defending them, and eventually
whoever is newest - which can turn on the player if their standing drops.
**A:** **ANSWERED - custom** (2026-08-07). A **combination of factors**: much
of the surrounding land is still recovering from the plague, and **fighting
between the nobility is common now**, producing a wave of people who figure
there is more opportunity to be found on that side of the law. Gives the raid
wave a concrete cause (consistent with Block 18's dispossessed-bandits
default); the default's inward blame dynamics are left open as texture.

**12.5** When the player marries, how do the other five react? ADR-031 rules
out rival suitors, so this must be reaction, not competition.
**Default:** each gets one line, and Hilda's is the one that lands.
**A:** **ANSWERED - custom, mechanical ruling** (2026-08-07). Each gets a
line, and **the player inherits others' feelings toward their spouse into
their own reputation with those people**, augmented by the player's own
efforts: if Hilda is friendly with the player but hates the spouse, the player
is **downgraded one reputation level** with Hilda - not to the level of her
hatred. **The inverse holds for the spouse**: if someone hates the spouse but
likes the player, their reputation toward the spouse is **upgraded one
level**. **Implied work:** a C6 code touch for marriage reputation transfer.

---

## Block 13 - Register and tone rules

*Closes part of G10. Produces the section a writer tests a line against.*

**13.1** State the game's theme in one sentence - the thing every line should
be compatible with.
**Default:** *"A person can be owned by the land and still make a life on it."*
**A:** **DEFAULT ACCEPTED** (2026-08-07). *"A person can be owned by the land
and still make a life on it."*

**13.2** Give the **too grim** boundary: write or approve one line that is over
it.
**Default:** over the line - *"The child died in the night. There was nothing
to bury her in."* Grounded-and-hopeful can have hardship in the past tense and
in the aggregate; it does not put suffering on screen for texture.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Over the line - *"The child died in
the night. There was nothing to bury her in."* Hardship lives in the past
tense and in the aggregate, never on screen for texture.

**13.3** Give the **too cozy** boundary: one line that is over it.
**Default:** over the line - *"Tee-hee! Don't forget to water your veggies!"*
No whimsy voice, no exclamation points from adults, nobody who exists to be
adorable.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Over the line - *"Tee-hee! Don't
forget to water your veggies!"* No whimsy voice, no exclamation points from
adults, nobody who exists to be adorable.

**13.4** How funny is this game allowed to be, and who is allowed to be funny?
**Default:** dry, dialect-flavoured, never quippy. Hilda and Bram are funny;
Aldric is unintentionally funny; Tomas is never a joke.
**A:** **DEFAULT ACCEPTED, with addition** (2026-08-07). Dry, dialect-flavoured,
never quippy; Hilda and Bram are funny, Aldric unintentionally so. **Tomas is
never a joke - but he will let people think he is** if they are not observant
enough to realise otherwise. Reconciles 11.2: the comedy is his performance
and his shield; the game never laughs at him.

**13.5** Does anyone ever address the player as "you, the player"? Any
fourth-wall, tutorial-voice, or system-voice text - and if so, whose voice is
the HUD and the season summary written in?
**Default:** never. The HUD is terse and impersonal; the season summary is
written as **the manor roll** - an accounting, in the steward's register. That
turns the game's most functional screen into its most thematic one.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Never. The HUD is terse and
impersonal; the season summary is written as **the manor roll** - an
accounting in the steward's register.

---

## Block 14 - Diction and naming law

*Closes the rest of G10. This becomes a checkable list.*

**14.1** Confirm the existing UI diction as law: Vigour (not Stamina/Energy),
Coin (not Gold/Money), Satchel (not Inventory), Resume Toil (not Resume), Keep
Record (not Save). Any changes or additions?
**Default:** confirmed as-is, plus: **Holding** (not Farm), **Roll** (not
Ledger), **Standing** (not Reputation) in player-facing text, **Assessment**
(not Tax) for the lord's tithe, **Offering** (not Donation) for the church.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Existing diction confirmed as law
(Vigour, Coin, Satchel, Resume Toil, Keep Record), plus Holding, Roll,
Standing, Assessment, and Offering.

**14.2** The deny list - words that must never appear in player-facing text.
**Default:** quest, XP, level up, craft (as a noun), stamina, gold, shop, NPC,
buff, loot, grind, upgrade, unlock. Where a mechanic needs the concept, find
the period word.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Deny list locked: quest, XP, level
up, craft (as a noun), stamina, gold, shop, NPC, buff, loot, grind, upgrade,
unlock. Find the period word for each concept.

**14.3** How much dialect? "Aye", contractions, dropped articles, thee/thou?
**Default:** light and consistent - plain modern English with period *nouns*,
never period *grammar*. No thee/thou, no "prithee". "Aye" sparingly. The rule:
a line should read as though translated *from* the period, not performed in it.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Light and consistent - plain modern
English with period nouns, never period grammar; no thee/thou, no "prithee",
"aye" sparingly. Lines read as translated *from* the period, not performed in
it.

**14.4** Naming conventions for any future person, place, item, or building.
**Default:** people get single Anglo-Saxon or Norman given names, no surnames
except by trade or place ("Aldric the Steward", "Marta of the Brook"); places
get compound English forms (-ford, -mere, -wich, -ley, -ward); items get the
plainest true name available.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Single Anglo-Saxon or Norman given
names; surnames only by trade or place; places in compound English forms
(-ford, -mere, -wich, -ley, -ward); items get the plainest true name.

**14.5** Do numbers ever appear in dialogue?
**Default:** coin amounts yes (they are the subject of the game); day numbers
never; percentages, stats, and levels never.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Coin amounts yes; day numbers never;
percentages, stats, and levels never.

---

## Block 15 - Voice per character

**15.1-15.5** For each of the six: one **verbal tic or constraint** that makes
their lines identifiable with the name hidden.
**Default:**
- **Aldric** - never uses a contraction. Speaks in obligations.
- **Tomas** - repeats a phrase from earlier in his own line. Blesses reflexively.
- **Hilda** - asks a question in every line, whether or not she wants an answer.
- **Cedric** - shortest lines in the game. Rarely exceeds eight words.
- **Marta** - answers a question with an observation. Never says "I".
- **Bram** - every statement has a comparative in it; something is always
  bigger, worse, or further than you would think.
**A:** **DEFAULT ACCEPTED** (2026-08-07) for all six:
- **Aldric** - never uses a contraction. Speaks in obligations.
- **Tomas** - repeats a phrase from earlier in his own line. Blesses
  reflexively.
- **Hilda** - asks a question in every line, whether or not she wants an
  answer.
- **Cedric** - shortest lines in the game. Rarely exceeds eight words.
- **Marta** - answers a question with an observation. Never says "I".
- **Bram** - every statement has a comparative in it; something is always
  bigger, worse, or further than you would think.

---

## Block 16 - Money, market, black market

**16.1** What is the coin called, and what does 1 coin buy? (Turnip seeds cost
2; a spear costs 150; the assessment is 30.)
**Default:** pennies, called **coin** in the UI per the diction law. One coin
is a loaf; 30 is a season's rent; 150 is a soldier's weapon and absurd for a
peasant to own - which is the point.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Pennies, called **coin** in the UI.
One coin is a loaf; 150 is a soldier's weapon and absurd for a peasant to own.
(The 30-as-assessment figure is superseded by the 2b.4/X13 ruling - base 20 +
held acreage; "30 is a season's rent" remains as rough scale, not the
assessment.)

**16.2** What is the **assize** the market prices are set by, and who sets it?
**Default:** prices fixed by the manor court by custom, revised at Michaelmas;
the 5% toll is the lord's cut for the right to trade. The ±5% market-day drift
is the assize being ignored at the margins.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Prices fixed by the manor court by
custom, revised at Michaelmas; the 5% toll is the lord's cut for the right to
trade; market-day drift is the assize being ignored at the margins.

**16.3** Who runs the market stall - is it Aldric, or an unnamed seventh face?
**Default:** Aldric presides, an unnamed clerk transacts. Keeps the cast at six
and puts the steward at the centre of the economy, which is thematically
correct.
**A:** **ANSWERED - custom** (2026-08-07). Aldric presides; a **young clerk**
(younger than most, not a child) transacts. **Aldric is teaching this
character letters and numbers**, and in return the clerk works for Aldric at
times. The character is **not fully developed** - and his take on the player
is **directly tied to how Aldric feels about the player** (a reputation
mirror). Needs naming (per 14.4) and a tier placement (resident or background)
when developed.

**16.4** Who is the **black-market trader** (days 9 and 20, +25% and a
detection roll)? They are the most underwritten entity in the project.
**Default:** an itinerant chapman, **Wat**, who is a *voice and a cart* rather
than a character - never named in the cast, never on a schedule, arrives at
the map edge. Gives the grey economy a face without breaking the cast lock.
**A:** **DEFAULT ACCEPTED** (2026-08-07). An itinerant chapman, **Wat** - a
voice and a cart rather than a character; never in the cast, never on a
schedule, arrives at the map edge. Sits in the Itinerants tier (2b.1).

**16.5** Why is selling to him illegal, and what do villagers think of it?
**Default:** it evades the lord's toll, so it is theft from the lord. The
village thinks it is fine and would not inform - which is why detection
chance drops as village standing rises, making the existing mechanic a piece of
characterisation.
**A:** **DEFAULT ACCEPTED** (2026-08-07). It evades the lord's toll - theft
from the lord. The village thinks it is fine and would not inform, which is
why detection chance drops as village standing rises.

---

## Block 17 - Tenure, tithe, corvee, court

**17.1** Confirm the answer to 1.2 in tenure terms: what is a "strip", who
grants it, and what does the 7-day rent interval represent?
**Default:** strips are furlongs in the open field, granted at the steward's
discretion, rent due weekly at his tally.
**A:** **ANSWERED - custom** (2026-08-07). The holding is **a farm map that
allows building, farming, ranching, and so on - so long as rent is paid.**
Rent is the condition of tenure, not the shape of the land. Consistent with
ADR-034 (the player's plot as its own map) and with 2b.4 (held acreage drives
the assessment); the strip/furlong default fiction is not adopted.

**17.2** What are the three avenues of paying the assessment *called* in-world
(coin / in-kind crops / labour)?
**Default:** "in coin", "in kind", "at the boon-work" - the last being the
period term for the labour owed.
**A:** **DEFAULT ACCEPTED** (2026-08-07). "In coin", "in kind", "at the
boon-work" - the last the period term for the labour owed.

**17.3** **Corvee** is called on one day's notice with a 1.5x credit
multiplier. What is it in-world, and can it be refused?
**Default:** the boon-day - the lord's ploughing or carting, summoned by the
steward. It cannot be refused, only failed, and failing it is a court matter.
That is why the notice period is cruel.
**A:** **DEFAULT ACCEPTED** (2026-08-07). The boon-day - the lord's ploughing
or carting, summoned by the steward. Cannot be refused, only failed; failing
it is a court matter, which is why the notice period is cruel.

**17.4** What actually happens at the end of the season if the assessment is
unpaid? (Currently: "soft failure".) Who acts, and what do they say?
**Default:** the court **distrains** - seizes stock and tools to the value
owed - and the holding is entered as in arrears on the roll. Not eviction, not
prison: the player continues, poorer and marked, and the village saw it happen.
That is the grounded-hopeful register applied to a failure state.
**A:** **DEFAULT ACCEPTED** (2026-08-07). The court **distrains** - seizes
stock and tools to the value owed - and the holding is entered as in arrears
on the roll. Not eviction, not prison: the player continues, poorer and
marked, and the village saw it happen.

**17.5** What is the **heriot** (per default 4.2) called on the roll, and is
it ever referenced again?
**Default:** yes - Aldric mentions it once at high opinion, and it is the line
that reveals he was the one who granted the holding.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Yes - Aldric mentions it once at high
opinion, the line that reveals he was the one who granted the holding.

---

## Block 18 - Bandits and the thief

**18.1** Who are the bandits - deserters, dispossessed peasants, a local
outlaw band, foreigners?
**Default:** dispossessed - men put off holdings elsewhere, doing to
Nettleford what was done to them. Fighting them is not clean, which suits the
register.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Dispossessed - men put off holdings
elsewhere, doing to Nettleford what was done to them. Fighting them is not
clean, which suits the register. Consistent with 12.4 (plague-recovering
lands and noble infighting produce the wave).

**18.2** Why *this* spring? Raids escalate with the deterrence system; the
scripted first one is day 15.
**Default:** the lord's men went with him on campaign; the manor is undefended
and everyone knows it. That single fact ties the absent lord, the raids, and
Cedric's night watch into one thread.
**A:** **DEFAULT ACCEPTED** (2026-08-07). The lord's men went with him on
campaign; the manor is undefended and everyone knows it. (Read against 2.1/2.2:
the lord is away on lordly business, not absent - the thread ties his
frequent departures, the raids, and Cedric's night watch together.)

**18.3** Does the `raid_leader` have a name or identity?
**Default:** no name, one repeated recognisable detail. Naming him would demand
an arc the slice cannot pay for.
**A:** **ANSWERED - custom, deferred** (2026-08-07). **Not yet** - no name or
identity for the slice; **future updates past the slice/Spring may require
the topic returned to**. The default's "one repeated recognisable detail" is
not adopted for now, leaving room for the revisit.

**18.4** What are the three **clues** in the investigation, concretely?
(`clues.json` currently contains only `clue_count: 3`.)
**Default:** a witness placing someone away from where they should have been;
a physical trace at the theft site; a thing sold that should not have been
sellable. Each is a different information channel - schedule, place, market -
which uses three systems already built.
**A:** **DEFAULT ACCEPTED** (2026-08-07). A witness placing someone away from
where they should have been; a physical trace at the theft site; a thing sold
that should not have been sellable - schedule, place, and market, using three
systems already built.

**18.5** What happens to Marta if accused correctly - and is the player's
reward (manor +2, village +4) the right shape given she may be sympathetic?
**Default:** the court fines her and the village is relieved and slightly
ashamed. Keep the numbers; let the *text* carry the cost. **Flag for
consideration:** a village standing gain for turning in a neighbour may be
worth revisiting as a design question, not just a writing one.
**A:** **DEFAULT ACCEPTED** (2026-08-07). The court fines her; the village is
relieved and slightly ashamed. Keep the numbers; let the text carry the cost.
**Owner agrees with the consideration** - the village-standing gain for
turning in a neighbour should be revisited as a design question (see X6).

---

## Block 19 - Buildings, stations, livestock

**19.1** What are the drying shed and the hearth, in this village - the
player's own, or shared?
**Default:** the hearth is inside the cottage and always was; the drying shed
is built and is a visible sign of prosperity that villagers comment on.
**A:** **DEFAULT ACCEPTED** (2026-08-07). The hearth is inside the cottage and
always was; the drying shed is built and is a visible sign of prosperity that
villagers comment on.

**19.2** Who teaches the player to build and to preserve? Recipes are gated on
farming skill level with no in-fiction source.
**Default:** Hilda teaches preserving and brewing; Cedric teaches building.
Turns two skill gates into two relationships.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Hilda teaches preserving and
brewing; Cedric teaches building - two skill gates turned into two
relationships.

**19.3** The chicken and the goat - are they named, bought from whom, and does
the village react to a peasant owning stock?
**Default:** bought at market; the player may name them; a goat is a real step
up and Bram will have something to say about it.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Bought at market; the player may name
them; a goat is a real step up and Bram has something to say about it.

**19.4** What does it mean, socially, when bandits drive off the goat?
**Default:** the village helps - a small material gift the next day at decent
standing. This is the clearest place in the whole game to make "harsh world,
warm people" mechanical rather than stated.
**A:** **DEFAULT ACCEPTED** (2026-08-07). The village helps - a small material
gift the next day at decent standing; "harsh world, warm people" made
mechanical rather than stated.

**19.5** The cottage upgrade (200 coin, +15% sleep restore) - what is it, in
fiction?
**Default:** a proper chimney and a floor. It is the most quietly aspirational
purchase in the game and deserves a line from every villager.
**A:** **DEFAULT ACCEPTED** (2026-08-07). A proper chimney and a floor - the
quietly aspirational purchase, deserving a line from every villager. **Data
note:** the shipped `cottage_upgrade` already costs 200 coin **+ 20 flint**
(`buildings.json` v3) - the in-kind partial cost already exists. **Open
sub-question (owner, feeds Block 20):** should foraged materials join the
cottage cost, and does `wood` need a sink anywhere at all?
**RESOLVED (2026-08-07):** yes to both. `cottage_upgrade` now costs flint 20
+ wood 20; `fence` now costs wood 2 (was flint 2). Applied with test updates
- full suite 1117 checks, all pass. See the materials standing ruling.

---

## Block 20 - The commons and forage

**20.1** Who owns the commons, and what are the player's rights there?
**Default:** the lord owns the soil, the village holds the right of common by
custom. The player may take wood, stone, and what grows. That right is old and
resented by the manor - see 12.3.
**A:** **DEFAULT ACCEPTED** (2026-08-07). The lord owns the soil; the village
holds the right of common by custom. The player may take wood, stone, and what
grows - a right that is old and resented by the manor (see 12.3).

**20.2** Is gathering respectable, marginal, or shameful?
**Default:** respectable in spring, when everyone is short. This is the hungry
gap; nobody looks twice.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Respectable in spring, when everyone
is short - the hungry gap; nobody looks twice.

**20.3** What are the wild plants, really - and should `wild_herb`,
`wild_onion`, `wild_berry` get true names?
**Default:** yes: **sorrel**, **ramsons** (wild garlic), **elderflower** or
early berries. Free specificity, no code change beyond `name` fields.
**A:** **DEFAULT ACCEPTED** (2026-08-07). True names adopted: `wild_herb` ->
**Sorrel**, `wild_onion` -> **Ramsons**, `wild_berry` -> **Early Berries**
(the default's alternative was elderflower; "Early Berries" keeps the
berry-pie coherence and is easy to change later, per the soft-embedding
principle). Applied to `items.json` name fields.

**20.4** Where does `wood` come from, given the Cottersward is off-map?
**Default:** deadfall and hedge-cutting on the commons - by custom the villager
may take what is fallen, never what stands. A single sentence that makes the
3%-per-tile spawn rate feel like a rule instead of a number.
**A:** **DEFAULT ACCEPTED, plus addition** (2026-08-07). Deadfall and
hedge-cutting on the commons - by custom, take what is fallen, never what
stands (standing timber stays off-limits; the trees/nodes standing ruling
keeps this custom load-bearing for the post-slice work). **Added: wood is
also purchasable** at the market stall (`items.json` price 3, stall stock
added) - a legal source when the commons run dry.

**20.5** Does anyone else forage the commons, and can the player see it?
**Default:** yes - villagers are on the commons at certain hours, and a tile
you were saving is sometimes already picked. Needs a small code touch; flag as
optional C4 work.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Yes - villagers are on the commons
at certain hours, and a tile the player was saving is sometimes already
picked. Needs a small code touch; flagged as optional C4 work.

---

## Block 21 - Crops, food, and the table

**21.1** Spring currently offers two plantable crops. What else should grow?
**Default:** add **peas**, **oats**, and **flax** - peas as the fast
nitrogen-fixing food crop, oats as the reliable low-value bulk, flax as the
non-food cash crop that cannot be eaten in a crisis. That last one is a real
decision to give a player.
**A:** **ANSWERED - genre research + V4 Pro consult** (2026-08-07). Note: the
"two plantable crops" premise was stale - `crops.json` already ships six
spring crops (turnip, barley, carrot, pea, onion, leek), so peas already
exist. Genre research (Stardew spring: parsnip/potato/garlic/kale/cauliflower/
strawberry; Harvest Moon/SoS: turnip/potato/strawberry/cabbage/cucumber; Rune
Factory: turnip/potato/cabbage/cucumber/onion/leek; historical English
spring-sown: barley/oats/wheat/rye/peas/beans/onions/leeks/flax) plus V4 Pro
(deepseek-v4-pro, effort max, prompt 15922 / completion 5095 tokens, no
truncation; see `.deepseek/outputs/block21_crops_out.md`) recommends adding
**oats** and **flax**, declining kale as a palette swap with cabbage already
summer-locked as the green. **Applied to data:** oat (4d, bulk low-value
cereal, fertility_min 20) and flax (5d, non-food cash crop yielding
flax_fibre, fertility_min 30) with seed/produce/market entries - the first
crops with fertility_min > 0. **Flagged follow-up:** oats-as-livestock-feed
needs an AnimalManager code touch (species feed a single `feed_item_id`,
barley today).

**21.2** Should any crop be non-food (fibre, dye) to make the "sell it or eat
it" choice sharp?
**Default:** yes - flax, per above.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Flax is the non-food crop, per 21.1 -
`flax_fibre` is a material, structurally inedible.

**21.3** What does a peasant here actually eat daily, and does the game model
it?
**Default:** pottage and bread. Add **pottage** as a cheap hearth recipe from
any two vegetables - the everyday meal, distinct from the aspirational
berry pie.
**A:** **ANSWERED - custom** (2026-08-07). Pottage, bread, **foraged food, and
some game when they can trade for or buy it** - wild meat is a purchased or
traded good, not a hunting system. **Flagged as C5 content work:** a pottage
recipe (any two vegetables) needs a recipe-input shape the current
`recipes.json` list doesn't express, and a game-meat item + market entry are
needed.

**21.4** Is there a food the player would never sell, and one they would never
eat?
**Default:** never sell seed corn (there is a real temptation to make this
mechanical); never eat flax.
**A:** **ANSWERED - V4 Pro consult, default confirmed** (2026-08-07). Pro:
the rule is mechanically sound and thematically resonant as-is. Unlimited
market seed stock softens but does not remove the teeth - seeds cost coin
and replanting is gated to market days, so selling the last seed can burn a
growing window. Flax is enforced by construction (zero food value). Optional
future hardening: limited per-market-day seed stock (3-5) - explicitly not
for this slice.

**21.5** Cabbage is summer-locked and unplantable, with an "in season later"
tooltip. Keep as a teaser, or move to spring?
**Default:** keep - it is a working promise of a future season and costs
nothing.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Keep cabbage summer-locked as the
working promise of a future season - it costs nothing.

---

## Block 22 - Festivals (ADR-030)

**22.1** What is the Spring festival, what day, and what does the village
actually do?
**Default:** **Ada's Feast**, day 21 - merging with the existing mass check
rather than competing with it. Procession to the field boundary, blessing of
the seed, ale after.
**A:** **DEFAULT ACCEPTED** (2026-08-07). **Ada's Feast**, day 21 - merged
with the existing mass check; procession to the field boundary, blessing of
the seed, ale after.

**22.2** Should the festival and the mass be the same event or two?
**Default:** the same. The slice has one day-21 attendance check already built;
making the festival *be* that is cheaper, cleaner, and stronger than adding a
second calendar beat.
**A:** **DEFAULT ACCEPTED** (2026-08-07). The same event - the festival *is*
the day-21 attendance check; one calendar beat.

**22.3** Name the other three (data-only, unreachable in the slice).
**Default:** summer **Haysel**, autumn **Harvest Home**, winter **the Long
Night**.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Summer **Haysel**, autumn **Harvest
Home**, winter **the Long Night** - data-only, unreachable in the slice.

**22.4** What does the player *do* at a festival, given no mini-games are
allowed?
**Default:** show up, and every villager has a festival-specific line. That is
the whole mechanic and it is enough if the lines are good.
**A:** **ANSWERED - custom, expansion** (2026-08-07). **There should be
contests**, in two participation modes: (a) some the player enters directly;
(b) some the player joins by **cheering a specific character** - bonus
reputation with that character - and/or **placing small bets with coin**.
Mini-games are acceptable **so long as they are in-lore and never an excuse
for button mashing**. Overturns the block's "no mini-games" premise.
**Flagged: C5 systems work** - contest definitions (festivals.json or
adjacent data), cheering -> individual-opinion bonus, betting -> coin
transaction; fold into the existing festival/UI managers (ADR-030's
no-new-simulation-layer rule).

**22.5** What does missing it cost - socially, not mechanically?
**Default:** nothing legal, but three villagers mention it the next day. The
absence of a penalty *is* the design; the noticing is the consequence.
**A:** **ANSWERED - custom, mechanical** (2026-08-07). Villagers whose
personalities **lean toward social participation** frown on a missed
festival: a **small negative tick to their individual opinion** of the
player, persisting **until the next festival** - and continuing if it is
missed again. Other characters do not notice. Replaces the "three villagers
mention it" default. **Flagged:** feeds reputation/dialogue work (C5/C6);
which characters qualify is a content decision - likely Hilda, Bram, and
Tomas (the festival is his mass); Cedric, Marta, and Aldric plausibly do not
notice.

---

## Block 23 - Marriage and courtship (ADR-031)

**23.1** What does courtship look like here - what does a peasant do to signal
intent?
**Default:** repeated gifts, completed favours, and being seen together at
market. All three already exist as systems.
**A:** **DEFAULT ACCEPTED, plus addition** (2026-08-07). Repeated gifts,
completed favours, and being seen together at market - **plus spending time
together**: not necessarily a date, but an event that conveys some story and
character progression. **Flagged: C6** - "time together" events need
scene/dialogue content per candidate.

**23.2** Is there a token - a gift item that constitutes a proposal?
**Default:** yes, and it should be craftable rather than bought, so a proposal
costs effort rather than coin.
**A:** **ANSWERED - yes, adopted** (2026-08-07). Owner asked whether this fits
the lore; it does - betrothal tokens are real peasant custom (broken-groat
halves, carved love-tokens, braided rings). Craftable form adopted: a
**braided straw/rush ring made at the hearth** - effort, not coin, and no new
station. **Flagged: C6** - one hearth recipe + item entry.

**23.3** Does the manor or the church have to approve? (A villein needed the
lord's licence to marry - **merchet** - which is a genuinely period pressure
point.)
**Default:** yes: a fee to the steward. It makes Aldric relevant to the
romance plot and gives the money economy a stake in the social one. **Flag:**
this adds a gate ADR-031 does not currently describe - your ruling needed.
**A:** **DEFAULT ACCEPTED - ruling** (2026-08-07). Yes: **merchet** - a fee to
the steward before the wedding. Resolves **X7**. **Owed:** an ADR-031
amendment in the ADR log (append-only) recording the gate; C6 implementation
of the fee.

**23.4** What changes in the cottage and the day after marriage?
**Default:** a waking greeting, a chore sometimes done, and one villager who
treats the player differently forever after.
**A:** **DEFAULT ACCEPTED, plus addition** (2026-08-07). A waking greeting, a
chore sometimes done, and one villager who treats the player differently
forever after - **plus a small 'requests' queue to give your spouse**, which
is **restricted during pregnancy** (pregnancy comes later in development; out
of slice scope today). **Flagged: C6** - spouse request queue.

**23.5** Does the spouse ever *ask* for anything?
**Default:** yes, rarely, and it is never a fetch-quest - it is a request to
stop working for one day.
**A:** **ANSWERED - custom** (2026-08-07). Yes, but only a small amount - and
the requests are related to **tasks the asking spouse is not proficient at**.
Replaces the "stop working for one day" default: the spouse asks the player
to do what they cannot. **Flagged: C6** - per-spouse skill-gap request list.

---

## Block 24 - Reactive and ambient text

**24.1** Which events must draw a next-day comment from villagers?
**Default:** raid, court, corvee, theft, festival, marriage, first harvest,
and a failed assessment.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Raid, court, corvee, theft,
festival, marriage, first harvest, failed assessment. (The 22.5
missed-festival opinion tick is separate and already ruled.)

**24.2** How many villagers comment on a given event - all six, or a
rotating subset?
**Default:** two, chosen by who plausibly would - which is what makes the
village feel like it has an interior.
**A:** **ANSWERED - custom** (2026-08-07). **All six principals** comment on a
given event - overturns the rotating-two default. Writing volume is six lines
per event; under ADR-033's cast expansion, whether the two additional
principals also comment is a later content decision - this ruling covers the
core six.

**24.3** Should the player's *choices* be commented on, not just events? (Sold
to the black market, paid in labour rather than coin, refused to gift.)
**Default:** yes for black-market sales and for paying at the boon-work - both
are visible, both are judged.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Yes for black-market sales and for
paying at the boon-work - both visible, both judged.

**24.4** Is there any text that appears exactly once per playthrough?
**Default:** yes - the first market day, the first rain, the first raid
survived, and the last line of the season. Once-only lines are where the
strongest writing goes.
**A:** **DEFAULT ACCEPTED** (2026-08-07). First market day, first rain, first
raid survived, and the last line of the season - once-only lines carry the
strongest writing.

**24.5** How does the game communicate the passage of the hungry gap - days
20-28 pressure?
**Default:** through dialogue only. No new mechanic; the village simply gets
quieter and shorter with the player as stores run down.
**A:** **DEFAULT ACCEPTED** (2026-08-07). Through dialogue only - no new
mechanic; the village gets quieter and shorter as stores run down.

---

## Block 25 - Framing: intro, endings, failure

**25.1** What does the title screen say beneath the title?
**Default:** one line naming the place and the debt.
**A:** **DEFAULT ACCEPTED, provisional** (2026-08-07). One line beneath the
title naming the place and the debt ("for now" - held as revisable before the
bible is written).

**25.2** What is the game's opening - a letter, a scene, a paragraph, or
nothing?
**Default:** the manor roll entry granting the holding, three lines, in
Aldric's register voice. It is the cheapest possible intro and it establishes
the roll as the game's framing device on the first screen.
**A:** **ANSWERED - V4 Pro consult, max effort** (2026-08-07). Draft opening
roll entry (Pro-authored; relay facts in `.deepseek/outputs/block25_framing_out.md`):

> Harrowmere Manor Roll, Nettleford. The holding late of Alys Fletcher is
> granted to her kin, heriot paid. Rent and assessment are owed by
> quarter-day; four days' work on the demesne is due each year.
> The holder shall keep the hedges and the ditch, attend the manor court when
> summoned, and see that the assessment is met.
> Entered this first day of Spring.

Presentation: after the title screen, a still of the manor roll - ink on
parchment - advances on a single click, then fades to the farm at dawn.
**Review corrections applied:** "tithe" -> "assessment" in line 1 (14.1
diction law; Pro's own line 2 already used it); "her issue" -> "her kin"
(4.2 leaves the previous holder as parent or aunt). **Pro-authored, easily
changed:** the previous holder's name (Alys Fletcher, a trade surname per
14.4).

**25.3** What does the season-end summary say when the player has **succeeded**?
**Default:** the roll, updated, with the arrears line blank - and one sentence
from a villager underneath it. The document is the score; the person is the
point.
**A:** **DEFAULT ACCEPTED** (2026-08-07). The roll, updated, arrears line
blank, one villager's sentence underneath - the document is the score, the
person is the point.

**25.4** What does it say on **failure**? (Per 17.4.)
**Default:** the same roll, with the arrears line filled, distraint recorded,
and the same villager's sentence - different, and kind.
**A:** **ANSWERED - V4 Pro consult** (2026-08-07). Failure roll text
(Pro-authored):

> Arrears - The holder has not met the Spring assessment. Distraint taken:
> the stock and tools of this holding have been seized to the value of the
> debt. The hold is entered in arrears upon this roll.

Villager's line (Pro chose Hilda; **voice-tic correction applied** - her 15
tic requires a question in every line):

> "Some seasons are like that, aren't they? You'll still have a bed and a
> bowl here. The land's not going anywhere."

**Review note:** the seized items should reflect the player's actual stock
and tools at runtime (list in the roll), not a fixed set.

**25.5** What is the last thing the player reads before Restart/Quit?
**Default:** a line that points at next season, because grounded-and-hopeful
means the story does not end at a debt.
**A:** **ANSWERED - V4 Pro consult** (2026-08-07). Last line (Pro-authored):

> The roll is never closed. The next season's work is already on the page.

**Review note (optional polish):** "already on the page" implies the roll
contains future entries; an alternative that keeps the framing device
stricter: "The roll is never closed - the page waits for the next season's
entry." Both are grounded-and-hopeful; owner's pick.

---

## Open collisions requiring a ruling

Tracked here so they are not lost in the blocks:

| ID | Collision | Block | Needs |
|---|---|---|---|
| ~~X11~~ | ~~**The lord and the bailiff appear on screen.**~~ **RESOLVED -> 2b.1 default (2026-08-06).** Fourth tier **Itinerants** accepted as an amendment to ADR-033: Sir Edric Vane, the bailiff, and Wat the chapman - day-scheduled, no home zone / daily schedule / gifting / romance / requests, focused dialogue, authority to change the player's situation. Amendment still to be recorded in the ADR log. | 2.1, 2.4 | ADR-033 amendment - recording owed; batch with X10/X12 |
| ~~X12~~ | ~~**Contract drift: the tithe.**~~ **RESOLVED (2026-08-07).** `CLAUDE.md` section 2 amended off "fixed 30-coin assessment" to describe the held-acreage shape landed under X13/ADR-038 (base 20 + 10/held strip); `AGENTS.md`/`DEEPSEEK.md` regenerated. | 2.3, 2b.4 | Closed - see `design/world_bible.md` Appendix C and `design/decisions.md` ADR-038 |
| ~~X13~~ | ~~**Tithe scaling axis amendment (ADR-017).**~~ **RESOLVED (2026-08-07) -> ADR-038.** Tithe moved off `coin_per_tilled_tile` onto **held strips** (owned plot + one unit per rented strip), base 20 standing alone, rate 10 coin/strip. `tithe.json` v3; `tithe_manager.gd` updated. One sub-question stays open: whether `tenure.json`'s separate weekly per-strip rent should be retired now that the assessment also scales on acreage (double-charge risk) - not resolved this pass, see `design/world_bible.md` Section III. | 2b.4 | Closed (core scaling) - **one interaction left open**, see note |
| ~~X10~~ | ~~**`CLAUDE.md` amendment owed under ADR-033.**~~ **RESOLVED (2026-08-07, `CLAUDE.md` v0.13).** Section 2's marriage entry no longer hardcodes "the four village villagers"; candidates are drawn from the Tier 1 principal cast minus priest/steward. This table's own "OPEN" marker was stale - the amendment landed the same day it was opened. | 1b.2 | Closed - confirmed via `CLAUDE.md` v0.13 changelog |
| ~~X9~~ | ~~**Multi-map world vs. the single-grid design.**~~ **RESOLVED -> ADR-034** (Accepted in principle, implementation deferred). Breaks `CLAUDE.md` s5 scene flow (title -> main), `farm_map.json` (one 30x20 grid), `tenure.json` (strips on that grid), NPC schedule coords (bare x/y with no zone), `FarmGrid` (one `Vector2i` dict), and save v13 (`farm.cells` flat array). Also touches ADR-007, ADR-019, ADR-023. | 1.2, 1.4 | **New ADR + contract amendment + a roadmap sprint.** Blocks any content that names where a thing is. |
| ~~X8~~ | ~~**Cast of 10-12+ vs. ADR-029's lock of six.**~~ **RESOLVED -> ADR-033** (Accepted). Leaves X10 owed. Also contradicts `content_plan.md` ("deepens the six rather than adding a seventh") and the small-cast principle ADR-028 established. | 1.5 | **Superseding ADR.** Cheap - data + writing only, no systems risk. |
| ~~X1~~ | ~~Tenure strips overlay the chapel, market, demesne, and villager homes~~ **RESOLVED by X9** - the village leaves the player's map, so the overlap cannot occur. `tenure.json` still needs rework under X9. | 1.2 | Folded into X9 |
| ~~X2~~ | ~~Hilda as marriage candidate vs. an older-widow characterisation~~ **RESOLVED (2026-08-07).** 6.1/6.4 ruling sets Hilda in her twenties; the older-widow collision with ADR-031 candidacy no longer exists. She remains a candidate. | 6.4 | Closed by owner ruling - no amendment needed |
| ~~X3~~ | ~~Marta married vs. Marta as thief - systems do not talk~~ **RESOLVED (2026-08-07).** 8.4 default accepted: marriage ends the thefts silently; the player holds the knowledge. Systems still need to talk - a C6 code touch is owed. | 8.4 | Closed by owner ruling - **C6 code touch owed** |
| ~~X4~~ | ~~Cedric's dialogue references an inn that does not exist~~ **RESOLVED (2026-08-07).** Hilda's alehouse doubles as an inn for travellers - uncommon but not unheard of - with guests housed in an outbuilding separate from the alehouse that doubles as her own home. The line stands; no building added to the map. | 7.4 | Closed by owner ruling - no data change |
| ~~X5~~ | ~~`harvest_demesne` chore exists in a spring-only slice~~ **RESOLVED (2026-08-07).** Fiction fix, not a data fix: the chore is reframed as clearing and hauling the last of the *previous autumn's* stored sheaves from the demesne barn, not this spring's (nonexistent) crop. No change to `tithe.json`'s `chore_ids`. | 5.4 | Closed - fiction fix, no data change |
| ~~X6~~ | ~~Village standing *rises* for informing on a neighbour~~ **RESOLVED (2026-08-07).** Village-standing reward on a correct accusation reduced from +4 to **+1** (manor stays +2); a **mercy path** added alongside accusation - covering for Marta quietly (no standing change, private opinion gain, thefts taper via an event flag) as a real middle option between accuse and marry. Design locked in `design/world_bible.md` Section VII; the standing-number change and the mercy-path branch are both still owed in `investigation_manager.gd`/`raid_manager.gd`. | 18.5 | Closed (design) - **code implementation still owed** |
| ~~X7~~ | ~~Merchet (marriage licence fee) not described in ADR-031~~ **RESOLVED (2026-08-07).** 23.3 default adopts merchet - a fee to the steward before the wedding, now **25 coin**, shipped as `tithe.json`'s `merchet_fee`. ADR-031 amendment recorded in `design/decisions.md`, also adding Edith as a fifth marriage candidate. | 23.3 | Closed - fee set, ADR-031 amendment recorded; C6 gate implementation still owed |

---

## Provenance

Created 2026-08-06 as the working instrument for content pass C1
(`design/content_plan.md`), under ADR-029. Gap analysis in Part A is measured
against the repository as of that date: 27 data files, 36 dialogue lines, 6
named characters, 0 named places.

**Follow-up (2026-08-07).** `design/world_bible.md` was written from this
document, then a residual list of 17 `[OPEN]` items it carried forward was
treated in `design/open_items_treatment.md` and accepted by the owner. The
open-collisions table above reflects those resolutions; `world_bible.md`
Appendix C is the authoritative status list (design locked vs. still
implementation-owed) going forward.
