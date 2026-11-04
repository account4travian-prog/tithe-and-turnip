# design/world_bible.md — Tithe & Turnip: The World Bible

**Status:** Final. Distilled from `design/world_biblePROPOSAL.md` (Parts A–C)
against `design/setting_questionnaire.md` (the source of truth for every
ruling below) and cross-checked against `data/*.json` and `design/decisions.md`
as of 2026-08-07. Where the proposal and the questionnaire disagreed, the
questionnaire's answer stands; every correction made in that reconciliation is
listed in the report that accompanies this document. **Updated 2026-08-07**
with the 17 items originally left `[OPEN]`, resolved via
`design/open_items_treatment.md` and accepted by the owner the same day —
see Appendix C for provenance and implementation status.

**Purpose.** This is the single source of narrative truth for *Tithe &
Turnip* — its geography, people, history, economy, and tonal law. Every piece
of in-game text — dialogue, UI strings, the season-end roll, item and place
names — should trace back to something written here.

**Legend.**
- **LOCKED** — settled fact. Do not alter without a new Architecture Decision
  Record.
- **[OPEN]** — a conscious, named gap. The decision needed and who decides it
  (the project owner) are stated plainly. Nothing below invents an answer to
  an `[OPEN]` line.

**Authority order.** `CLAUDE.md` (the engineering contract) and an Accepted
entry in `design/decisions.md` (the ADR log) both outrank this document. This
bible outranks nothing they say and contradicts neither.

---

## I. The Place

The **Manor of Harrowmere** sits in the **vale of the Nettle**, a rolling
lowland a day's walk end to end (Block 1b.4, LOCKED). To the north, blue
mountains stand distant and are never reached — weather, not destination, and
the direction every story about "somewhere else" points. Uplands and hills
ring the vale: thin soil, sheep, the commons, and the wild margin where
bandits shelter. The vale floor is the good land — the manor's demesne, the
tight cluster of **Nettleford**, and the tenant plots strung along the
**Harrow Road**, which runs the length of the vale, north into the uplands and
south toward **Coldwich**, the market town — present in speech as a
destination, not (yet) a map the player walks.

In law the lord owns every inch of soil; custom is older than parchment. The
village holds the **right of common** by usage — pasture, estovers (deadfall,
furze, hedge-cutting), and the liberty to take what grows on unclaimed ground.
The manor resents it. The commons are a live wound: quiet enclosure on the
manor's side, loud argument on the village's (Block 12.3). In spring, during
the hungry gap, no one questions a villager pulling wild carrot off the
uplands; the other eight months, every step off the tenancy is a statement.

A **plague, a generation ago**, thinned the vale and left its mark on the
ground — fallow strips and abandoned cottar plots still scar the demesne. The
village's own church collapsed with the dead, and the old field-rites and
charms crept back into the silence they left. The church's return is a live
disagreement (see Section V and Block 12.3): the manor finds it useful
prestige; a good half of Nettleford is not sure it needs a second lord.

**World architecture [ADR-034, Accepted in principle, implementation
deferred].** The 30×20 map currently in `farm_map.json` is a placeholder,
scheduled to become the player's own plot alone. The full region will be
eight to ten zones on separate maps: the player's plot, the village of
Nettleford, the manor and its grounds, two or three wilderness edges (upland,
woodland, riverbank), and two or three neighbouring tenant plots. This bible
describes the region ADR-034 targets; it does not describe the shipped
30×20 grid, and no text here should be read as a claim about today's map
coordinates. Persistent trees and rock nodes (harvestable, regrowing) are
deferred to that same systems sprint; for the Spring slice, wood comes from
deadfall, hedge-cuttings, and the market stall.

**How many people live here?** Roughly thirty households, of which the player
comes to know a working set by name — the Tier 1 principals, the Tier 2
residents, and an unbounded fund of Tier 3 names heard only in other people's
mouths (Block 1b.1/1b.5, ADR-033). "The village" as a reputation axis speaks
for the whole parish; the named cast are the doors the player actually knows.

---

## II. The People

The cast is tiered by writing cost, not by importance (ADR-033, Accepted,
superseding ADR-029's six-person lock).

- **Tier 1 — Principals (8).** Full sheet: age, trade, want, fear, traits,
  voice, standing bands. Marriage candidates and investigation roles are
  drawn only from this tier. All eight are written below.
- **Tier 2 — Residents (6–8).** A trade, a schedule, a handful of lines, gift
  preferences. No romance, no investigation role. Not yet cast — a later
  content pass.
- **Tier 3 — Named background.** Referenced only in other characters'
  dialogue, never instantiated as a node ("Old Wilf's ewes got out again").
  Unbounded and free; not yet authored.
- **Itinerants.** A fourth tier, added by amendment to ADR-033 (Block 2b.1):
  defined by *arriving* rather than living here. Day-scheduled like
  `manor.json`'s `court_days`/`black_market.visit_days`, no home zone, no
  daily schedule, no gifting, no romance, no requests — a focused dialogue
  set tied to why they came, and the standing authority to change the
  player's situation when they do. Members: **Sir Edric Vane**, **the
  bailiff**, and **Wat the Chapman**.

### The Eight Written Principals

#### Hilda
- **Age:** Twenties (Block 6.1 — age changed from the questionnaire's default
  of fifties; a village of the plague-thinned demographic makes a young
  widow the norm, not an exception).
- **Trade & household:** Widow; the village's alewife. Her alehouse doubles
  as the only inn Nettleford has — travellers sleeping over stay in an
  **outbuilding separate from the alehouse**, which is also her own home
  (Block 7.4, resolving **X4** — no inn building is added to the map).
- **Wants:** Her brewing recognised as the village's craft, not a widow's
  pastime (Block 6.2).
- **Fears:** Being dismissed for her sex — passed over, her knowledge taken
  and her name erased (Block 6.2).
- **Traits:** Warm, compulsive gossip (Block 6.3). She is not cruel; she
  simply cannot hold a thing, which makes her the game's most reliable
  vector of information — the player learns what nobody meant to say aloud.
  She half-knows Marta's theft and says nothing (Block 12.1) — the one
  secret bigger than her own tongue.
- **Voice:** Every line asks a question, wanted or not (Block 15). Teaches
  preserving and brewing (Block 19.2).
- **Marriage candidate:** Yes (Block 6.4 — ruling, resolving **X2**: the
  older-widow characterisation that collided with candidacy no longer
  exists once her age moved to twenties).
- **Standing bands (Block 6.5):** hostile — shuts the door and *talks*.
  cold — polite, and you hear about it later. neutral — news and weather.
  warm — advice you did not ask for. friendly — treats you as family and
  defends you unprompted.

#### Cedric
- **Age:** Thirties (Block 7.1 — changed from the default of forties).
- **Trade & household:** The village's smith or hedger — the flint and
  arrow preferences of a man who makes and mends.
- **Wants:** The village able to defend itself (Block 7.2).
- **Fears:** Being right about the danger and ignored (Block 7.2).
- **Traits:** Gruff. Keeps watch on the road at night, unpaid and unasked,
  since the raids began (Block 7.3) — which makes him both the man with no
  alibi and the man most likely to have seen something. His speech is
  economy itself.
- **Voice:** Rarely exceeds eight words (Block 15). Teaches building
  (Block 19.2).
- **Marriage candidate:** Yes.
- **Standing bands (Block 7.5):** hostile — turns his back. cold — single
  syllables. neutral — work talk only. warm — shares tools. friendly —
  shares what he has seen on the road, mechanically the best reward in the
  game.

#### Marta
- **Age:** Late twenties (Block 8.1).
- **Trade & household:** A cottar — no land of her own. Hires out by the day
  to whoever can pay coin or food.
- **Wants:** Enough. She steals **food and seed, never coin, never from the
  poorest**, to feed a dependent whose exact nature — a sick mother, an
  unacknowledged child, a debt to the wrong person — is hinted but never
  confirmed within the slice (Block 8.2, the single most load-bearing answer
  in the questionnaire).
- **Fears:** Being caught. She knows when the player suspects her and grows
  quieter and more careful as the investigation advances (Block 8.3) — the
  `quiet` trait as characterisation, not a label.
- **Traits:** The village's quietest inhabitant. Not malicious; careful. Her
  thefts are patterned and escalate only when her dependent is hungry.
- **Voice:** Answers a question with an observation; never says "I"
  (Block 15). Her neutral-band deflection — "I'm just a simple farmer" — is
  a *lie*, flagged as one on this sheet (Block 8.5).
- **Marriage candidate:** Yes. If courted and married, the thefts end
  silently — she no longer needs to — and the player alone holds the
  knowledge (Block 8.4, resolving **X3**; a C6 code touch to make the
  marriage and theft systems talk is owed).
- **Standing bands (Block 8.5):** hostile — says nothing at all. cold —
  courteous and absent. neutral — deflects (the lie, above). warm — small
  true things. friendly — tells you something she should not.

#### Bram
- **Age:** Thirties (Block 9.1).
- **Trade & household:** Carter or drover. Lives apart by the road, a span
  outside the village proper, out of trade rather than choice — though he
  tells himself it is choice (Block 9.4).
- **Wants:** Standing he has not earned. He knows the roads better than
  anyone in Nettleford and believes that should count for more (Block 9.2).
- **Fears:** Being found ordinary. Every boast is a door held shut
  (Block 9.2).
- **Traits:** Boastful. A self-made exile. His information is **inflated but
  founded** (Block 9.3) — a real thing under every exaggeration, which gives
  the investigation's witness testimony a second flavour distinct from
  Hilda's gossip. He can tell you what he saw on the Harrow Road last market
  day; the colour of the cart will be wrong, the number of wheels right.
- **Voice:** Every statement carries a comparative — "farther than
  Coldwich," "rougher than the spring drive" (Block 15). Teaches trade,
  routes, and the price of things.
- **Marriage candidate:** Yes.
- **Standing bands (Block 9.5):** hostile — loud contempt. cold —
  performative indifference. neutral — stories about himself. warm —
  stories with the player in them. friendly — drops the performance,
  briefly.

#### Edith
- **Age:** Early twenties, close to the player's own (Block 1b.5's "roughly
  the player's age and circumstance").
- **Trade & household:** Tenant farmer on the plot adjacent to the player's,
  holding it alone.
- **Wants:** To prove a woman's name on the roll needs no husband's beside
  it — not a fight with the player, a fight with the assumption (shared by
  half the village and the manor alike) that she needs one to keep her
  strip.
- **Fears:** Losing the plot to a "better," meaning male, claimant — a
  cousin, an unwanted suitor, anyone the steward would find it easier to
  grant the land to.
- **Traits:** Proud, competitive, generous underneath it once the
  competition is won or dropped. She counts things out loud — rows, days,
  coins — a farmer who trusts numbers over people.
- **Voice:** Every line contains a count or a tally, spoken or implied:
  *"Three rows in. Two more to go, if the rain holds."*
- **Marriage candidate:** Yes — the one candidate the player meets as an
  equal rather than from a position of asking something of them.
- **Standing bands:** hostile — refuses to acknowledge the player's plot
  exists at all, which is worse than contempt. cold — talks about her own
  work, never asks about the player's. neutral — compares yields evenly, no
  warmth, no edge. warm — offers a tip that would genuinely help the
  player's farm. friendly — asks the player for help first, which for her
  is the real vulnerability.
- **Family:** Aldric's younger sister (see The Web, below).

#### Osric
- **Age:** Forties. Not native to Nettleford — took over the mill from a
  childless predecessor some years back, which is also why he has no
  ready-made ties into the village web.
- **Trade & household:** Runs the village mill on the Nettle Brook, held by
  a manor licence — no one grinds grain to flour without going through him,
  which makes him a power the village feels daily even though his charter
  ultimately comes from the same roll as everything else here. He takes his
  cut in **multure**, a toll paid in flour at the mill door.
- **Wants:** The hand-quern trade stamped out. A household that grinds its
  own grain needs him less, and he resents every one that tries.
- **Fears:** A second mill licensed on the brook, or the brook running low
  in a dry season — either one and his leverage is gone.
- **Traits:** Shrewd, transactional, not cruel — he has learned that flour
  is leverage and uses it plainly, without dressing it up.
- **Voice:** Speaks in weights and shares: *"A sack in, three stone back —
  that's the toll, same as always."*
- **Marriage candidate:** No — keeps the pattern clean. Aldric, Tomas, and
  Osric are the three principals whose power sits outside the courtship
  pool; everyone the player can court is, in some sense, a peer.
- **Standing bands:** hostile — takes the multure at its harshest legal
  measure and says so. cold — grinds the player's sack last, after
  everyone else's. neutral — takes his cut, says nothing further. warm —
  the sack comes back a little heavier than the toll strictly allows.
  friendly — warns the player when the multure rate is about to rise,
  before the manor announces it — his own version of Cedric's "best reward
  in the game," economic gossip instead of road gossip.

#### Aldric the Steward
- **Age:** Late thirties to early forties (Block 10.1 — changed from the
  default of fifties).
- **Trade & household:** Steward of Harrowmere. A villein's son who learned
  letters and rose — resented by the village for the climb, never quite
  trusted by the manor for the origin.
- **Wants:** The manor's accounts to balance and the law to hold. Not
  corrupt: he will not take a bribe, will not bend a rule, and both of those
  hurt the player equally (Block 10.2). Competence moves him — a holding
  kept in order earns his grudging respect, and any action that benefits
  **both the manor and the village** moves him further (Block 10.3).
- **Fears:** The bailiff's unannounced audit landing on his own name (Block
  2.4). He suspects Marta but lacks proof, and would rather have it from the
  player than dig for it himself (Block 10.4).
- **Traits:** Rigid, precise, unsmiling. Presides at the market stall,
  teaching letters and numbers to a young clerk (see below) whose read on
  the player mirrors his own. He mentions the heriot exactly once, at high
  opinion — the line that reveals he was the one who granted the player's
  holding (Block 17.5).
- **Voice:** Never contracts. Speaks in obligations: "You will." "You must."
  "It is required." At high individual opinion he warns the player before
  the manor court sits — a breach of his own rule, and the only one he
  allows himself.
- **Marriage candidate:** No — fiction grounds (manor staff).
- **Family:** Edith's older brother (see The Web, below) — a personal cost
  to his rigidity that the village can read two ways: proof he really is
  impartial, or proof he will not lift a finger even for his own blood.
  Both readings should stay available.
- **Standing bands (Block 10.5):** the five existing lines are canonical and
  are kept, not rewritten (`data/dialogue.json`, `npc_id: steward`):
  friendly (manor ≥50) — *"The lord himself has heard your name spoken
  well."* warm (≥10) — *"You keep the manor in good order. I notice."*
  neutral (≥‑9) — *"Work hard and you may eat."* cold (≥‑49) — *"Keep your
  head down and pay what's owed."* hostile (<‑49) — *"You're a stain on
  this manor. Watch yourself."*

#### Father Tomas
- **Age:** Thirties (Block 11.1 — changed from the default of sixties; still
  trying to prove he belongs in the collar, which the plague's demographics
  make a fact of the parish rather than a mark against him).
- **Trade & household:** Village priest, born in Nettleford, never left.
- **Wants:** To repair and grow the church, because he genuinely believes in
  his religion and its power to help people (Block 3.3).
- **Fears:** That the village sees a boy in a cassock, not a shepherd.
- **Traits:** Devout to the point of distraction. His forgetfulness is a
  genuine byproduct of a mind turned toward the faith rather than the world
  (Block 3.3/11.2) — **not** extreme, **not** early decline, **not**
  politics. He also leans into it deliberately, letting people underestimate
  him and then surprising them with sharp recall (Block 11.2) — played for
  **comedy**, never at his own dignity's expense (Block 13.4). He thinks the
  lord's assessment is lawful and says so publicly; it costs him to say it
  (Block 11.3). Hilda is his oldest friend and manages his forgetting with
  quiet care, without remark or condescension (Block 12.1).
- **Voice:** Repeats a phrase from earlier in his own line; blesses
  reflexively (Block 15).
- **Marriage candidate:** No — celibate, by fiction.
- **Standing bands (Block 11.5):** the five existing lines are canonical
  (`data/dialogue.json`, `npc_id: priest`): friendly (church ≥50) — *"The
  church lights a candle for you, friend."* warm (≥10) — *"Your generosity
  is remembered in our prayers."* neutral (≥‑9) — *"A donation to the
  church is never forgotten."* cold (≥‑49) — *"You have turned your back on
  the church's call."* hostile (<‑49) — *"The bishop will hear of this."*
  The hostile line implies an off-map church hierarchy — texture, not yet a
  place on any map.

### Itinerants

#### Sir Edric Vane, the lord
Holds Harrowmere of a greater lord nobody local names — an article of faith
more than a person. Sir Edric himself is not an abstraction: he is **present
and returning**, away on lordly business (war, patrols, other lords'
weddings) rather than gone for the season (Block 2.1/2.2). Three scheduled
appearances, none colliding with an existing calendar beat (Block 2b.2):
- **Early (~day 5) — the return.** He is simply *there*, riding the demesne,
  watching the plough teams. No mechanic; the village straightens its back
  when he passes.
- **Mid (~day 15–16) — the reckoning.** Arrives in the wake of the scripted
  raid, giving the raid a political consequence beyond the fight itself.
- **Late (~day 27) — the accounting.** Reviews the roll before the season
  closes — the moment manor standing cashes out, and the point person behind
  the season-end summary (see Section XI).

#### The Bailiff
Sir Edric's eyes and fist, and the one figure who can overrule Aldric. He
arrives **unannounced** to audit (Block 2b.3). At good manor standing,
Aldric's word covers the player and the audit's interest fades; at bad
standing, that protection ends and the audit can draw blood from a holding
already thin from the hungry gap. He gives the manor-standing axis a face.

#### Wat the Chapman
An itinerant trader — a voice and a cart, never on a schedule, never fully
in the cast (Block 16.4). Appears at the map edge on market days **9 and
20**, paying **25% above the assize with no toll** (`manor.json`:
`price_premium_pct: 0.25`). Selling to him evades the lord's toll — the
manor court's definition of theft — but the village will not inform: it
thinks the dealing is fair, and detection chance falls as village standing
rises (`base_detection_chance: 0.2`, `standing_detection_reduction: 0.15`).
Wat is a test of what the player values more: the manor's good graces, or
the village's quiet loyalty.

### Simkin, the Young Clerk

Transacts the market stall under Aldric's teaching; his read on the player
mirrors Aldric's own opinion of them — a reputation mirror (Block 16.3).
- **Name:** Simkin (a period-authentic diminutive, distinct in sound from
  the eight principals' names).
- **Tier placement:** Tier 2 (Resident) — a fixed work location and an
  active mechanic (the reputation mirror) put him above Tier 3's
  referenced-only bar, but he carries no romance and no investigation role,
  so Tier 1 would overstate him.
- **Age:** Early teens.
- **Wants:** Aldric's approval, and someday his post.
- **Fears:** A scales-error made in front of a customer.
- **Traits:** Earnest, quick with sums, visibly aware he is being watched.
- **Voice:** Deliberately **no spoken tic of his own** — the eight
  principals already own six voice tics (Section IX), and a ninth to track
  would dilute them without buying much. His texture lives in his
  handwriting instead: see the town board postings, Section III.

### The Web

The village is a knot of obligations, resentments, and silences the player
can pull.

**Observed relationships (LOCKED, Block 12.1):**
- **Hilda & Tomas** — old friends. She covers his lapses without remark or
  condescension; he is the one person of whom she asks nothing.
- **Cedric & Aldric** — mutual contempt: the watchman who acts without
  permission, the steward who cannot act without rules. They speak of each
  other in clipped sentences.
- **Marta & Hilda** — Hilda half-knows the theft and says nothing. The one
  secret bigger than her own tongue.

**Familial ties (Block 12.2), resolved:** **Edith is Aldric's younger
sister.** Satisfies the ruling's "at least two share blood or marriage" and
respects the hard constraint that no two marriage *candidates* may be kin
to each other, since the tie runs through Aldric, one of the three
non-candidates. It also gives his rigidity a personal cost: his own sister
is fighting to hold a strip alone, and his sheet (10.2/10.3) says he will
not bend a rule for anyone — now including her. The village can read his
refusal to help her either way (impartiality, or coldness toward his own
blood), and both readings should stay live rather than resolved. No second
tie is needed; one well-used relationship beats two thin ones.

**Village disagreements (LOCKED, Block 12.3):**
- **The commons.** Grazing versus foraging; the manor's quiet enclosure of
  the uplands. Cedric calls it theft of custom; Bram calls it inevitable and
  argues a wise man gets ahead of it. The argument runs weekly at the
  alehouse.
- **The church's return.** The plague stripped the church's influence and
  let old field-rites and charms seep back in. Now the church is returning,
  and Nettleford is of two minds: those glad of it, and those who remember
  surviving without it.

**Who the village blames for the raids (LOCKED, Block 12.4):** a
combination of causes, not a single villain — much of the surrounding land
is still recovering from the plague, and fighting among the nobility is
common now, producing a wave of the dispossessed who see more opportunity on
the wrong side of the law than the right one. Nettleford does not talk this
around into a single scapegoat; the causes are structural, and the raiders
are "what the player might become," not monsters (Section VIII).

### Reactive & Ambient Text (Block 24)

Rules for when the village speaks about what has happened, distinct from
each character's standing-band lines.

- **Events that draw a next-day comment (LOCKED, 24.1):** a raid, a court
  day, a corvee call, the thief's exposure, a festival, a marriage, the
  player's first harvest, and a failed assessment.
- **Who comments (LOCKED, 24.2):** **all six** written principals, not a
  rotating subset — overturning the proposal's draft default of two. Six
  lines per qualifying event. Whether the two unwritten principals also
  comment is a later decision, once they are cast.
- **Choices, not just events (LOCKED, 24.3):** a black-market sale and
  paying the assessment at the boon-work are both visible and both judged —
  the village comments on how the player chose to pay, not only on what
  happened to them.
- **Once-only text (LOCKED, 24.4):** the first market day, the first rain,
  the first raid survived, and the last line of the season each carry a
  line that fires exactly once per playthrough. This is where the strongest
  writing should go.
- **The hungry gap (LOCKED, 24.5):** communicated through dialogue only, no
  new mechanic — the village simply grows quieter and shorter with the
  player as days 20–28 wear the stores down.
- **Missed festivals (LOCKED, 22.5):** villagers who lean toward social
  participation give a small negative individual-opinion tick for a missed
  festival, persisting until the next one (accumulating if that one is
  missed too); others do not notice. Roster, resolved: **notices** — Hilda
  (keeps the village's social ledger in her head), Bram (measures status by
  who was seen where), Tomas (it is his mass — reads as quiet concern, not
  judgement, a distinct flavour from Hilda's and Bram's), Edith (competitive
  by nature, tracks whether the player is "keeping up"). **Does not notice**
  — Cedric (often absent himself, on watch), Marta (has her own reasons to
  keep her head down at gatherings), Aldric (festivals sit on the
  church/village axes, not his ledger), Osric (transactional — cares
  whether the multure was paid, not whether anyone danced).

---

## III. Power & Economy

### The Manor of Harrowmere

Harrowmere is held of a greater lord nobody in the village names aloud — an
article of faith rather than a person they have seen. Sir Edric Vane, who
holds it in that lord's name, is not an abstraction (see Itinerants, above):
he returns on a predictable rhythm, and the village straightens its back
when he passes.

### The Steward

Aldric is rigid, not cruel, not corrupt. He will not take a bribe and will
not bend a rule for friendship; competence and outcomes that serve both
manor and village are the only currencies he trades in. He answers to the
bailiff and knows his own position rests on the lord's confidence — which is
why he serves the village *through* serving the manor, and why a player who
treats those two loyalties as one thing finds an ally in him.

### The Manor Court

Meets on days **twelve and twenty-six**, in the churchyard — half legal
proceeding, half village theatre. Every household attends; the steward
reads the roll, fines are fixed by custom and public (Block 2.5,
`manor.json`):

| Offence | Fine |
|---|---|
| Witnessed violence | 15 coin |
| Illegal sale (black-market or untolled) | **20 coin** |
| False accusation | 15 coin |

The coin is the least of it. Being fined is humiliating before it is
expensive — the village seeing that a holder is not in the manor's good
graces follows them into every conversation for the rest of the season.

### Tenure and the Assessment

The holding is a farm map that permits building, farming, and ranching so
long as rent is paid — rent is the condition of tenure, not the shape of the
land (Block 17.1; the earlier open-field-strip fiction is not adopted). The
assessment is that rent: a base of **20 coin**, plus a charge scaled to the
**held acreage** — the owned plot plus any rented strips — rather than to
how hard the player works it (Block 2b.4, superseding ADR-017's original
per-tilled-tile scaling). Working a tile harder no longer raises what is
owed; taking on more land is the bet, and working it well is how that bet is
won.

**The rate is resolved (X13, ADR-038): 10 coin per held strip.** "Acre" is
measured by **parcel**, not tile — the owned home plot counts as the base,
each rented strip (`tenure.json`) adds one unit — since `tenure.json`
already prices strips as discrete units rather than by tile count, and the
current 30×20 grid is a placeholder ADR-034 will replace regardless. A
player holding all three strips pays 20 + 30 = **50 coin**, a real stretch
goal against a Spring where leeks sell at 15 and Wat pays a 25% premium on
top. Shipped in `tithe.json` v3 as `coin_per_held_strip`, computed in
`tithe_manager.gd` from `BuildingManager`'s rented-strip state.

`[OPEN]` **One interaction was deliberately left unresolved.**
`tenure.json` also charges its own weekly `rent_per_interval` per rented
strip, separate from this seasonal surcharge — so a player renting a strip
currently pays for it twice, once weekly and once at season's end, under
two different names for the same fact. Folding the weekly rent into the
seasonal assessment (so "the assessment is the rent" stops being a
metaphor) is the clean fix, but it touches `BuildingManager`'s tested
rent/eviction mechanic and needs its own design pass before it's touched —
not done as a side effect of this rate change. **Decision needed (owner):**
retire the weekly strip rent, or accept the double charge as intentional
friction on renting.

Three avenues settle the assessment, named in-world as "in coin," "in kind"
(crops at the assize price, times quality), and **"at the boon-work"** — the
labour owed (Block 17.2). However it is paid, the full amount must be
settled by season's end.

**Distraint**, not eviction, is the consequence of an unpaid assessment: the
court seizes stock and tools to the value owed and enters the holding as in
arrears on the roll (Block 17.4). The player continues — poorer, marked, and
watched — and the only way clear is next season's rent paid in full.

**The Boon-Day (corvee).** The steward may summon the player to the lord's
demesne on **one day's notice** (`manor.json`: `notice_days: 1`). It cannot
be refused, only failed, and failing it is a court matter — which is why the
short notice is cruel. Labour credit earned there applies to the assessment
at **one-and-a-half times** the ordinary rate (`credit_multiplier: 1.5`),
making it the most efficient avenue and the least controllable one.

### The Market

Held by charter on eight days each season — the **3rd, 7th, 10th, 14th,
17th, 21st, 24th, and 28th** — twice weekly, the uneven spacing simply the
calendar falling where it falls (Block 5.3). The **toll is five parts in a
hundred** (`toll_percent: 0.05`), the lord's cut for the right to trade.

Prices are the **assize**, fixed by the manor court from custom and revised
at Michaelmas (Block 16.2). Two separate forces move a price away from that
fixed figure inside a market day, and a writer should keep them distinct:
- A small, universal **assize drift** — up to 5% (`price_drift.
  market_day_price_swing_pct: 0.05`) — the assize being ignored at the
  margins, the same for every seller.
- The player's own **supply pressure** (ADR-037, accepted and shipped):
  every unit the player sells nudges that item's price down, locked into a
  wider 0.5×–1.5× band at each market's open and decaying back nightly.
  This one is personal — it is the ledger remembering what *this* farm has
  been selling — and it is what makes flooding the stall with one crop a
  real, felt cost.

A tenant in good standing with the manor pays up to **10% better** on both
buying and selling (`standing_price_adjustment.max_pct: 0.10`); poor
standing finds the clerk less inclined to weigh the scales generously.

Aldric presides; a **young clerk** he is teaching letters and numbers to
transacts the stall, working for Aldric in turn (Block 16.3, and see "The
Young Clerk" above). The clerk's read on the player mirrors Aldric's own.

**The town board.** On each market day, the board beside the stall carries
one to three postings — plain requests for goods, in season, each naming a
quantity, a coin reward, and sometimes standing on offer, expiring quietly
if unmet (ADR-037; capped at three live postings at once). These are folded
into the manor's economy, not a separate system, and are quality-blind:
what the board wants is the count, not the tier. The board sits under
Aldric's authority, but the *voice* on each posting is an ordinary
household's, transcribed by Simkin (Section II) in his own still-uneven
hand — a word crossed out and rewritten, a numeral traced twice as if
unsure the first pass was clear. Two sample postings, in that double voice:

> *Ramsons wanted. Three bunches. Coin on delivery. — the Millers' girl has
> a fever and her mother swears by the poultice.*

> *Barley sought for the Whitsun brewing. Two sacks, fair price paid at the
> board. Ask for Hilda if none is offered outright.*

This is also how Simkin gets presence without a spoken voice-tic of his
own (Section II) — his texture lives in the handwriting, not the words.

Wood is also sold at the stall (`items.json`: price 3) — deadfall and
hedge-cuttings are rights of common, but the market gives a legal source to
anyone who cannot gather enough, and sets a ceiling on what building costs.

**Coin** is the penny, called "coin" in every interface. One coin buys a
loaf. A soldier's weapon — a spear, 150 coin — is a sum so absurd for a
peasant to own that it marks the weapon as heirloom or dangerous ambition.
Coin stays concrete throughout: weighed and counted, never an abstract
score.

### The Black Market

See **Wat the Chapman**, above (Itinerants). Selling to him is, in the
manor court's own terms, theft from the lord; in the village's terms, fair
dealing that nobody will report.

### Merchet

A villein needs the lord's licence to marry, obtained through the steward
and paid in coin before any wedding proceeds (Block 23.3, resolving **X7**).
This is a legal fact of Harrowmere, not an invented obstacle.

**The fee is 25 coin**, paid at the point the banns are first read (not at
the proposal itself, which stays effort-not-coin — see Section VIII), landing
just above the assessment's own 20-coin base: a real cost, paid once, at a
moment the player has usually been saving toward. Present in `tithe.json` as
`merchet_fee`; the ADR-031 amendment recording the gate is in
`design/decisions.md`.

---

## IV. The Church

### Saint Ada of the Furrow

The chapel is dedicated to **Saint Ada of the Furrow**, an invented local
saint (Block 3.1) — the story told is that she was a ploughman's daughter
who, when the oxen died in a bad year, took the plough herself and cut a
furrow so straight the seed in it grew twice as thick as any in the parish.
She is patron of exactly this village's exact problem: thin soil, uncertain
weather, one more season out of a tired field.

### The Weakness of the Church

The church in Harrowmere is **very weak** and has no power to compel
anything (Block 3.2). It cannot fine, cannot distrain, cannot force a knee
to bend. Its only instrument is **social pressure from other church
members** — real, but slow, and it does not reach the majority who simply do
not attend. This is why the church tithe is voluntary where the lord's is
not: institutional weakness, not theology, not mechanical convenience.

The manor pays Father Tomas a **stipend**, because a church on the demesne
adds prestige to Sir Edric's holding (Block 3.4) — but that is the whole of
the manor's help. The church sustains itself on its own small lands and its
congregation's offerings. Donating does not anger the manor; it simply does
not move it either. The unease here is financial dependence on a prestige
payment, not open rivalry — a crack in a beam that has not yet moved.

### The Old Beliefs

The plague stripped the church's influence a generation ago; when the dying
stopped, the old field-rites and charms against the murrain were already
filling the silence. The church's return is a live disagreement (Block
12.3): some attend out of real piety, many because everyone else does and it
would be strange not to, a few stay away entirely and the village lets them.

### Father Tomas

See his sheet in Section III. Genuinely devout, genuinely practical, and
aware the church cannot pay its own way — his ambition to repair and grow
it is quiet and unshakeable rather than dramatic, which is what keeps him
from being a simple holy fool. A player who donates, who attends Ada's
Feast, and who treats the chapel as a living place earns his word — never
material help, since he has none to give, but weight with the village that
changes its social weather.

### Mass

Mass is weekly and assumed, unremarked in play. Attendance is only ever
**counted** once — the **21st day**, the feast of Saint Ada — which the
festival calendar also uses as Ada's Feast (Block 3.5, 22.2). See Section V
for the calendar and Section XI's data note on the current mismatch between
this ruling and the shipped `festivals.json`.

---

## V. The Year

### The Shape of a Day

A day in seedtime lasts fourteen real minutes. Dawn is grey and cool, dew
heavy, the hens beginning their low clucking. Work hours run six in the
morning to six in the evening; dusk brings a long soft half-light, and night
shuts the door on everything but the hearth fire and the goat shifting in
its shelter.

Weather is a daily roll — in spring, rain on three days in ten. Rain is good
news, spoken of as such: it waters every tilled cell without a hand lifted,
and a wet spring is a blessing on thin loam (Block 5.5). A dry spring is
hard; a wet one feels like the village exhaling.

### The Calendar of Seedtime

Villagers never say "day 17" (Block 5.2, a diction rule with teeth). Time is
spoken by reference to its fixed points:

- **Market days** — the **3rd, 7th, 10th, 14th, 17th, 21st, 24th, 28th** —
  the pulse of the economy, twice weekly by charter (Block 5.3). No reason
  beyond that is needed or given.
- **Court days** — the **12th and 26th** — the churchyard fills, voices drop,
  and yesterday's fight or black-market deal keeps to the edges.
- **Ada's Feast** — the **21st** — the one attendance the parish counts (see
  Section IV and the data note in Section XI).
- **Wat's visits** — the **9th and 20th** — announced only by rumour.
- **The scripted raid** — the **15th** — a day the village remembers in its
  bones; Sir Edric's mid-season return follows in its wake.

### Reckoning the Year

Two registers coexist, chosen by who is speaking (Block 5.1): formal
reckoning (regnal year, year of grace) for characters who deal in records
and authority — Aldric, the bailiff, the manor roll itself — and folk
reckoning ("the third spring since the murrain") for those who do not. In
the data, seasons keep their plain names; in the fiction, spring is
**seedtime**, summer **haymonth**, autumn **harvest**, winter **the dead
months** — a soft convention, easy to change later, not deeply embedded.

### The Spring Agricultural Round

Early spring is ploughing and sowing the lord's demesne — the reason corvee
lands here, colliding by design with the player's own planting window. Mid-
spring turns the village's stock out to the commons. Late spring is the
**hungry gap**: old stores running out, new crops still thin in the ground,
every coin and every foraged leaf mattering — and the assessment falls at
exactly this moment, because the game knows what spring means (Block 5.4).

### Festivals and Contests

One festival per season, all four in data, only Spring reachable in the
slice (ADR-030). Spring's is **Ada's Feast** on the 21st, merged with the
day's mass attendance rather than a second calendar beat (Block 22.1/22.2).
The other three, unreachable this slice: summer's **Haysel**, autumn's
**Harvest Home**, winter's **the Long Night** (Block 22.3).

Festivals include **contests**, in two modes (Block 22.4, overturning the
proposal's original "no mini-games" premise): some the player enters
directly, and some the player joins by **cheering a chosen character** (a
reputation bonus with them) and/or placing a small coin bet. Any mini-game
must stay in-lore and must never become an excuse for button-mashing.

**The contests, resolved (design locked; engine implementation still
owed):**
- **Ada's Feast (Spring) — the Furrow Race.** Not a twitch mini-game: three
  timed prompts fire as the ploughing team passes, each successful press
  adding to a furrow-straightness score; the Farming skill level (0–5)
  widens the timing window's forgiveness. Cheer/bet mode backs **Cedric**
  (steady, low variance) or **Bram** (showy, high variance) with a 1–5
  coin bet, odds weighted slightly toward Cedric — reusing two already-
  written principals rather than casting new entrants.
- **Haysel (Summer) — the lifting contest.** Tests Labor instead of
  Farming, so the four festivals don't all test the same stat. Same
  direct-entry/cheer-and-bet shape.
- **Harvest Home (Autumn) — sheaf-tying.** Tests Farming again, through
  speed rather than timing ("most sheaves tied before the bell finishes").
  Entrants should be drawn from the Tier 2 cast once it exists — lighter
  than the other three until residents are written.
- **The Long Night (Winter) — the storytelling contest.** Deliberately not
  a skill-check: the player picks a favourite storyteller among whichever
  principals are present and cheers, no direct-entry mode. Gives the
  calendar's four contests real variety (three physical, one social)
  instead of four reskins.

All four reuse existing systems (`skills.json` levels, the reputation axes,
coin) per ADR-030's no-new-simulation-layer rule; none has been built or
prototyped in `FestivalManager` yet.

Missing a festival costs standing, not law: see Reactive & Ambient Text,
Section II.

---

## VI. The Land & Food

### The Soil

Loam is golden, quick to drain, wants feeding, and repays it with steady,
unspectacular growth. Sandy patches drain in hours and burn hot but push
plants up fast while the water lasts. Rocky soil holds moisture forever and
yields almost nothing for it. A farmer learns to read the dirt by hand.

Fertility is a living score: worn down by harvest, restored by fallow days,
by the nitrogen-fixing roots of peas (the only crop with a *negative*
depletion value in `crops.json` — it feeds the ground it grows in), and by
compost spread from spoiled crops dried at the shed. Oats and flax both
need soil already in decent heart to take root at all (`fertility_min` 20
and 30 respectively) — the game's first crops that gate on it.

### The Crops of Seedtime

**Barley** is the staff of life — bread, ale, feed. **Turnips** bulk out the
poor's pottage. **Carrots, onions, and leeks** give sweetness, savour, and a
sharp green bite. **Peas** climb sticks and leave the soil richer than they
found it. **Oats** are the low-value bulk cereal, cheap to grow, cheap to
sell, the safety net when everything else fails (Block 21.1, added
following a genre and historical review — barley, oats, peas, onions, leeks,
and flax are all attested spring-sown crops of the period). **Flax** is the
one non-food crop — pale blue flowers spun into fibre, never food — and the
law of the farm is absolute: sell or weave it, never eat the seed corn and
never eat the flax (Block 21.2/21.4). The rule holds by construction (flax
has no food value) and by temptation (a market-day-gated sale against a
starving week before market is a real pressure), not by an artificial block
on the action.

**Cabbage** stays summer-locked and unplantable this slice, its "in season
later" tooltip a deliberate, costless promise of the season to come (Block
21.5).

### The Commons and the Forage

The lord owns the soil of the commons; the village holds the right of
common by custom (Block 20.1). In spring, foraging is respectable, not
marginal — the hungry gap makes it everyone's business (Block 20.2). Three
true-named pickables replace the old placeholder items (Block 20.3,
`items.json`): **Sorrel** (`wild_herb`), sharp and lemony; **Ramsons**
(`wild_onion`), the wild garlic of damp places; **Early Berries**
(`wild_berry`), small and tart from the hedgerows.

**Wood** comes from deadfall and hedge-cutting only — by custom, what has
fallen, never what stands (Block 20.4). It is also purchasable at the market
(`items.json`: price 3) as a legal source when the commons run dry.
Sometimes a tile the player was saving is already picked — the world does
not wait, and the commons are shared ground, not a private pantry (Block
20.5).

### The Table and the Hearth

The daily diet centres on the pottage pot — a fireproof crock on the hearth
that takes whatever is to hand: barley, turnips, wild greens, dried peas.
Bread is baked a loaf or two at a time. Cheese comes when the goat is in
milk; eggs come daily from the hens. Game meat is bought or traded, never
hunted — the forest is the lord's (Block 21.3).

`herb_stew` (wild greens and a turnip, at the hearth) already filled the
pottage's functional role in `recipes.json` — the everyday meal, distinct
from the aspirational berry pie — so it has been **renamed to `pottage`**
in `items.json`/`recipes.json` rather than duplicated: a data-only fix that
closes this gap and G9 (no food culture) at once. **Rabbit** joins the
table as the purchasable game-meat item (10 coin, at the market stall),
deliberately humble rather than venison, which would read as an
aristocratic or risky thing for a peasant to be caught with. A true "any
two vegetables" input system for a future second pottage-family recipe
remains open, but is not required to satisfy the fiction (Block 21.3).

**Hilda** teaches preserving and brewing; **Cedric** teaches building
(Block 19.2) — two skill gates, two relationships.

### Livestock

Every farm wants a goat, bought at market and named by the player — the
game's small ritual of attachment (Block 19.3). Its milk quality rises with
its happiness, which rests on daily feed, water, and shelter; chickens do
the same for eggs. Bram has something to say about the player's first goat.
If bandits drive it off, the village — at decent standing — responds with a
small material gift the next day: fodder, a sack of barley, a few coin
pressed into the player's hand (Block 19.4). Not charity — the village
closing ranks around one of its own.

### The Cottage

A cottage is a shell until it has a proper chimney and floor — the
`cottage_upgrade`, costing **200 coin, 20 flint, and 20 wood**
(`buildings.json` v3; the wood sink applied 2026-08-07). Once built, every
villager has a line about it: a floor means sleeping off the dirt, a
chimney means the fire smokes only upward — the quietest ambition in the
game (Block 19.5).

---

## VII. Conflict & Investigation

### The Bandit's Lot

The bandits are not a foreign evil. They are dispossessed — men and women
put off holdings elsewhere by the same plague-recovery and noble infighting
that touches everything else this spring (Block 18.1/18.4). They do to
Nettleford what was done to them: take what food and coin they can, burn
what they cannot carry, move on. The player's boot is the one kicking
someone else's head, and the world text never pretends otherwise.

### The Spring Wave

Two forces converge on this particular spring (Block 18.2). The land around
Nettleford is still half-empty from the plague, smallholdings lying fallow
and unclaimed. And Sir Edric's armed men travel with him on his frequent
absences — the manor is undefended, and everyone in the parish knows it.
That single fact ties the lord's departures, the raids, and Cedric's
unpaid night watch into one thread.

### The Raids

Three shapes, any of which may follow the scripted day-15 event (matches
CLAUDE.md's ADR-026 raid variants): a **night raid** striking in darkness,
damaging crops and buildings with less direct engagement; an **archer raid**
harassing from range while a small party tries the fence; a **leader raid**,
larger and organised enough to hold a ragged crew together for one careful
push. Deterrence — past victories, fences, a guard dog, a hired guard —
reduces both frequency and size; an undefended, fatalistic holding draws
trouble.

### The Raid Leader `[OPEN]`

No name, no biography, no identity within the Spring slice (Block 18.3) —
deliberately faceless so the player projects their own fear onto him.
**Decision needed (owner, explicitly post-slice):** whether and how to give
him a face in a later season. This item stays open *by design* — naming him
now would spend the ruling it's meant to serve — but three threads are
already planted in the fiction and worth protecting for whoever picks this
up, rather than spending now: the bandits are already written as "what the
player might become" (Block 12.4), so a leader with a half-recognisable
name would cash that theme in directly; Bram's testimony is established as
"inflated but founded" (Block 9.3), so whatever he's said about the leader
across the slice becomes retroactively partly true the moment he's finally
named, for free; and Cedric's night watch (Block 7.3) makes him the one
character positioned to have actually seen the leader up close before
anyone else does — a reveal-conduit already sitting in the cast.

### The Thief: Marta

See her sheet in Section II. She steals inside the village's own fences —
food and seed, never coin, never from the poorest — for a dependent she
will not name.

### The Three Clues (Block 18.4)

1. **Schedule witness — Bram.** Inflated but founded; he places someone
   away from where they should have been, self-serving in the telling but
   true underneath.
2. **Physical trace — Cedric.** A broken tool, a scrap of fabric, disturbed
   earth at the theft site — furnished by the man with no alibi and the
   most reason to have been watching, if the player presses him.
3. **Market trace.** An item for sale that should not be sellable — a rare
   seed, a cut of meat, a piece of craft a villager would never part with —
   traced back to Marta through the manor's own market rolls.

Hilda's warm gossip surfaces clues more readily than direct interrogation;
she is the village's memory, and a player who talks to her often finds the
threads easier to pull.

### Resolution Paths

A correct accusation goes to the manor court. Marta is fined; the village
is relieved and quietly ashamed — they knew her and did not see. **X6,
resolved:** manor standing gains **+2** (unchanged — the manor has an
unambiguous reason to be pleased); village standing gains **+1**, reduced
from the originally-shipped +4, since "relief" should not read as a clean
social win — +1 says "noticed, not celebrated." The text still carries the
weight the numbers alone don't.

**A mercy path is added alongside accusation.** If the player has gathered
enough of the clue trail to know it is Marta but chooses not to accuse —
covering for her quietly instead, leaving food anonymously or simply
sitting on the proof — no manor or village standing changes either way, but
a private opinion gain with Marta and an event flag let her thefts taper
off on their own once whatever crisis she's covering for passes. This gives
the player a real middle option between "accuse" and "marry her," which
otherwise doesn't exist — marriage is a large lever to pull just to be
merciful. **Not yet implemented** — needs one new event-flag branch in
`investigation_manager.gd`/`raid_manager.gd`, no new UI.

A false accusation is itself a court offence: the accuser is fined **15
coin**, village standing drops **‑8**. The community does not forgive a
false charge lightly.

If the player marries Marta, the thefts end silently — the player knows,
the village does not, and there is no reputation tick and no court record
(Block 8.4). Only the private weight of what was done, and the quiet
promise it will not happen again.

---

## VIII. Life Milestones

### Courtship

A slow, public thing, built from four kinds of action (Block 23.1): repeated
sincere **gifts**; **favours** completed (once is a friendly act, five times
is a courtship); **public visibility** at market, at mass, at the manor
court, tallied by the village's own gossip; and **spending time together** —
not necessarily a formal outing, but a scene that advances the story and the
two people's understanding of each other (walking the field-bounds at dusk,
sharing a meal at Hilda's on a festival day, sitting in silence after a hard
morning). `[OPEN]` — content work: each candidate needs their own
time-together scenes; none are written yet.

### The Proposal Token

A **braided straw-and-rush ring**, made at the hearth (Block 23.2) — real
peasant custom (broken-groat halves, carved love-tokens), adapted so the
proposal costs effort, not coin. Built from `flax_fibre` — already an
existing item, already narratively "spun... or woven" (Section VI) — rather
than a new material: the cash crop the game tells the player never to eat
becomes, in this one recipe, the thing they choose not to sell either.
Shipped as `betrothal_ring` in `recipes.json`/`items.json` (station hearth,
one flax fibre, no skill gate). The recipe exists; the courtship/proposal
*system* that would let a player actually give it does not — no
`MarriageManager` or equivalent has been built (courtship, the proposal
flow, the ceremony, and spouse life are all still C6 work, owed).

### Merchet

See Section III. A fee to the steward, owed before the wedding proceeds.
`[OPEN]` the fee itself, and the ADR-031 amendment describing the gate.

### The Ceremony

Officiated by Tomas. Banns read on three successive market days — nothing
in Nettleford stays secret — and the ceremony proceeds on the next clear
morning if unopposed. The couple meets at the church door, not inside; Tomas
asks only that they mean it. No incense, no choir, no lord's blessing, no
manor-provided feast — the celebration after is ale at Hilda's, paid for by
the couple or their friends (Block 11.4).

### Married Life

The spouse moves into the player's cottage and gains a **home-based
schedule** — mornings and evenings at the cottage, a midday routine that
varies by season. Each morning they may greet the player with a short line
fitted to weather, season, and recent events. Every few days they may
complete a small **farm chore** — watering, gathering eggs, turning compost,
weeding a fallow strip — chosen from a small pool and performed silently.
They are **giftable outside the normal daily cap** — one extra gift a day,
uncounted against the limit for everyone else (Block 23.4).

The other five principals each get one reaction line; Hilda's is the one
meant to land.

### Marriage Reputation Transfer

Marrying someone means marrying their place in the village's web of feeling
(Block 12.5): for every villager with an opinion of both parties, the
player's standing with them softens one notch toward the spouse's own
standing (never past a full drop to hostile), and the spouse's standing
softens one notch toward the player's in turn.

**Implementable spec, ready for C6 (not yet built):** reuse the band
thresholds already shipped in `dialogue.json`'s steward lines (friendly
≥50, warm ≥10, neutral ≥‑9, cold ≥‑49, hostile <‑49) rather than inventing a
new scale. On the wedding, once, for every other principal V who has a
recorded opinion of *both* the player and the new spouse: if
`opinion(V,spouse) > opinion(V,player)`, `opinion(V,player) += 25` (clamped
to [‑100,100]); if less, `-= 25`; a symmetric pass runs for the spouse's
opinion of V, referenced off the player's own standing with V; V is skipped
entirely if either opinion was never recorded. A flat ±25 is recommended
over computing an exact "one band," since the shipped band widths aren't
even (cold/warm each span 40 points, neutral spans 19) — 25 reliably
crosses the narrowest band and dents the wider ones without the engine
needing to look up band boundaries at all.

### Spouse Requests

A small, rare queue of requests — always tasks the spouse is not proficient
at themselves. They ask the player to do what they cannot. Pregnancy
(future scope, out of this slice) suspends the queue (Block 23.4/23.5).
One request drafted per candidate, each built from that character's own
established want rather than a generic fetch task:
- **Hilda** — can't leave the alehouse mid-brew; asks the player to mind a
  batch while she's called away, or to fetch sorrel/ramsons she hasn't had
  a free hour for.
- **Cedric** — poor sleep from the night watch; asks the player to stand a
  watch shift in his place, or to gather flint/wood he hasn't had time for.
- **Marta** — the payoff of 8.4's own ruling, made concrete: her old need
  never went away, it's just no longer secret. She occasionally asks for
  coin or food, plainly, for the same dependent she used to steal for.
- **Bram** — often on the road; asks the player to look in on his place
  while he's travelling, or to carry word/goods back from a market day
  he'll miss.
- **Edith** — content not yet drafted; add when her candidacy is exercised
  in play.

Content is drafted; the request-queue system itself is not implemented
(C6, owed, alongside the rest of the marriage system).

### Marriage Candidates

**Hilda, Cedric, Marta, Bram, and Edith** in the Spring slice — five, not
four; Edith's candidacy is resolved (Section II). Tomas, Aldric, and Osric
are excluded on fiction grounds (celibate; manor staff; the pattern that
economic/institutional authority sits outside the courtship pool).
`design/decisions.md`'s ADR-031 amendment records the expanded list, since
the ADR log is append-only and the original entry still names only four.

---

## IX. Tone, Register, Diction

**Theme (LOCKED):** *A person can be owned by the land and still make a life
on it.*

**Boundaries (LOCKED):**
- *Too grim, an example over the line:* "The child died in the night. There
  was nothing to bury her in." Hardship belongs in the past tense and the
  aggregate — the plague is a memory, not a scene; starvation is a threat
  worked against, never staged; death on screen is combat, not spectacle.
- *Too cozy, an example over the line:* "Tee-hee! Don't forget to water your
  veggies!" No whimsy, no talking animals, no exclamation points from an
  adult, nobody who exists to be adorable. Warmth is earned — a gifted meal,
  a spouse's quiet chore, the relief of rain.

**Humour (LOCKED):** Dry, dialect-flavoured, never quippy, never at a
character's dignity. Hilda and Bram are funny; Aldric is unintentionally so;
Tomas is never a joke, but he lets people think he is.

**Voice of the roll (LOCKED):** the manor roll is the framing voice for
every line that is not character speech — the HUD, the menus, the season
summary. Terse, declarative, never fourth-wall. Not "Use the hoe on the
ground." Instead: *"You may till a plot."*

**Diction law (LOCKED):**
- **Use:** Vigour, Coin, Satchel, Resume Toil, Keep Record, Holding, Roll,
  Standing, Assessment, Offering.
- **Deny list — never appear diegetically:** quest, XP, level up, craft
  (noun), stamina, gold, shop, NPC, buff, loot, grind, upgrade, unlock.
  Where a mechanic needs the concept, find the period word instead.
- **The title keeps "Tithe"; the diegetic word is Assessment.** Bridged by a
  one-time loading-screen tip: *"Old-timers still call the manor's due 'the
  tithe.' On the roll, it is entered as the assessment — and it is the
  roll, not the talk at the well, that the steward reads from."* If no
  loading-tip slot exists, the fallback is a single non-diegetic line after
  the opening roll fades: *"The roll calls it the assessment. Everyone else
  still calls it the tithe."*

**Dialect (LOCKED):** Plain modern English, period *nouns*, never period
*grammar*. No "thee/thou," no "prithee." A line should read as translated
*from* the period, not performed in it. "Aye" is used sparingly.

**Naming (LOCKED):** Given names single, Anglo-Saxon or Norman; surnames
only by trade or place ("Aldric the Steward," "Marta of the Brook"). Places
in compound English forms (Nettleford, Harrowmere, Coldwich — -ford, -mere,
-wich, -ley, -ward). Items get the plainest true name — "carrot," "flint,"
"watering can" — never an invented classification.

**Numbers (LOCKED):** Coin amounts appear freely; day numbers never;
percentages, stats, and levels never.

**Voices, per character (LOCKED, see full sheets in Section II):** Aldric —
never contracts, speaks in obligations. Tomas — repeats an earlier phrase,
blesses reflexively. Hilda — a question in every line. Cedric — rarely over
eight words. Marta — an observation, never "I." Bram — a comparative in
every statement.

---

## X. Framing

### Title and Subtitle

*Tithe & Turnip*, subtitled *"A holding in Nettleford"* (Block 25.1,
provisional — held revisable). "Tithe" appears only in the title and
external marketing text; every diegetic reference uses **assessment**.

### The Opening Still

After the title screen, a single parchment-textured still — a page from the
manor roll — advances on a click or keystroke (Block 25.2):

> *Harrowmere Manor Roll, Nettleford.*
> *The holding late of Alys Fletcher is granted to her kin, heriot paid.
> Rent and assessment are owed by quarter-day; four days' work on the
> demesne is due each year.*
> *The holder shall keep the hedges and the ditch, attend the manor court
> when summoned, and see that the assessment is met.*
> *Entered this first day of Spring.*

"Alys Fletcher" is a placeholder name (a trade surname, per the naming law)
and may be changed freely. The parchment fades to the first morning of
Spring, the player standing outside a small cottage on their plot.

### Season-End Summary: Success

The roll, brought up to date, the assessment line blank — no arrears —
delivered in Sir Edric's numbers, channelled through Aldric's register
voice, without praise. Beneath it, Hilda's sentence, in her question-tic:

> *"Paid in full, was it? Didn't I say you had it in you?"*

Warm without being saccharine, teasing in exactly the register Section IX
allows her, and it answers its own question rather than waiting on the
player. Optional variant for a markedly successful season (no arrears *and*
high manor standing), beyond the locked scope:

> *"Look at you. Coin to spare and no one had to tell you to sleep,
> either — did they?"*

### Season-End Summary: Failure

The same roll, arrears filled, distraint recorded — the seized items should
reflect the player's actual stock and tools at runtime, not a fixed list
(Block 25.4):

> *Arrears — The holder has not met the Spring assessment. Distraint
> taken: the stock and tools of this holding have been seized to the value
> of the debt. The hold is entered in arrears upon this roll.*

Hilda's line follows, her question-tic intact:

> *"Some seasons are like that, aren't they? You'll still have a bed and a
> bowl here. The land's not going anywhere."*

### The Last Line Before Restart/Quit

> *The roll is never closed. The next season's work is already on the
> page.*

(Block 25.5; an alternative phrasing was offered and not chosen — *"The
roll is never closed — the page waits for the next season's entry"* — kept
here as a documented, available variant rather than discarded, should the
owner prefer its stricter framing.)

### The Player's Ambition

Stated once, on the title screen: to hold the land free and clear, entered
on the roll in the player's own name, secure against the next steward's
whim. Nettleford, for all its trouble, is a relatively safe and peaceful
place, and the lord is gone more often than not — the player wants to keep
what is worth keeping, not merely survive what is owed (Block 4.5).

---

## XI. Appendices

### A. The Player Character (Block 4)

- **Identity:** player-chosen name and sex, roughly twenty, a **villein** —
  bound to the manor, owing both rent and labour, which is why corvee can
  fall on one day's notice (4.1).
- **Why the holding, now:** the previous holder — a parent or aunt — died
  over winter; the manor court granted the holding on payment of a
  **heriot** (a death duty), which is what left the player with their
  starting 8 coin (4.2).
- **Competence on day 1:** raised to the work, never responsible for it —
  handy with a hoe, ignorant of the roll, the market, the court. NPC
  explanation stands in for a tutorial screen without feeling artificial
  (4.3).
- **How the village receives them:** suspended judgement, not indifference
  — they knew the last holder and are watching to see which way this one
  goes, and they will say so (4.4).

### B. Standing Rulings

| Ruling | Detail |
|---|---|
| Cast demography | Majority in their 30s–40s; elders exceedingly rare — the plague thinned that generation a couple of decades back. |
| Materials & the commons | Wood is load-bearing: `cottage_upgrade` costs flint 20 + wood 20; `fence` costs wood 2. Wood purchasable at market. Persistent tree/rock nodes deferred to the ADR-034 systems sprint. |
| Crop additions | Oats and flax added to the Spring roster; oats double as animal feed (code touch owed). |
| Item renames | `wild_herb` → Sorrel, `wild_onion` → Ramsons, `wild_berry` → Early Berries, `herb_stew` → Pottage. |
| Assessment scaling | Base 20 coin + 10 coin per held strip (parcel model). Shipped `tithe.json` v3 / ADR-038. |
| Merchet | Adopted; fee 25 coin, `tithe.json`'s `merchet_fee`, ADR-031 amendment recorded. |
| Cast expansion | Edith and Osric written as the two remaining Tier 1 principals (ADR-033's eight); Edith is a fifth marriage candidate, ADR-031 amendment recorded. |

### C. Resolved Items — provenance and status

All 17 items originally listed here as `[OPEN]` were treated in
`design/open_items_treatment.md` (2026-08-07, not a DeepSeek consult — no
API access in that session; produced directly by Claude at the same rigor)
and accepted by the owner the same day. Status below distinguishes **design
locked** (the content in this document is final) from **implementation
owed** (the design is settled but no code exists yet for it to drive).

| # | Item | Design | Implementation |
|---|---|---|---|
| 1 | Bridge gloss | Locked, text in Section IX | **Done** (2026-08-07) — no loading-tip slot or Opening Still intro exists yet, so the documented fallback line is shown once via the existing HUD-toast mechanism (`main.gd._show_tithe_gloss_once`, gated by a new `framing.saw_tithe_gloss` event flag) |
| 2 | Per-acre rate | Locked: 10 coin/held strip | **Done** — `tithe.json` v3, `tithe_manager.gd`. The weekly strip-rent question is also resolved (2026-08-07 follow-up to ADR-038): the old recurring rent/eviction mechanic is retired, `tenure.json` v2 drops `rent_per_interval`/`rent_interval_days` entirely |
| 3 | Merchet fee | Locked: 25 coin | **Done** (ADR-039, 2026-08-07) — charged exactly via `MarriageManager.pay_merchet()` |
| 4 | Two principal sheets | Locked — Edith, Osric (Section II) | **Done** — `villagers.json`, `dialogue.json` |
| 5 | Young clerk | Locked — Simkin, Tier 2 (Section II) | **Done** (2026-08-07) — `villagers.json`'s `simkin` entry (spawn/schedule beside the steward's own market-stall tile), `dialogue.json`'s 5-band lines keyed on `{"opinion": {"npc": "steward", ...}}` rather than his own opinion — the reputation-mirror mechanic implemented purely in data, no code change needed since `ConditionEvaluator` already supports checking any villager's individual opinion |
| 6 | Familial ties | Locked — Edith/Aldric (Section II) | N/A — narrative fact, nothing to implement |
| 7 | Festival-tick roster | Locked (Section II) | Festival system itself not built |
| 8 | Festival contests | Locked design, four contests (Section V) | Implementation pass queued (dedicated DeepSeek worktree task, 2026-08-07) — not yet merged as of this row's last edit |
| 9 | Town board voice | Locked (Section III) | Board postings still generated from templates, not yet carrying this voice in-game — deliberately bundled with the pending townboard payout/naming playtest-feedback fix rather than touched separately, to avoid two concurrent passes editing the same board-order code |
| 10 | Pottage/game-meat | Locked | **Done** — `items.json`, `recipes.json`, `market.json`, `pottage` rename |
| 11 | Proposal-token recipe | Locked | **Done** (ADR-039) — spent by `MarriageManager.propose()` |
| 12 | Spouse requests | Locked, four drafted (Section VIII) | **Done** (ADR-039) — `requests.json` v2 `spouse_only` templates |
| 13 | Reputation-transfer math | Locked spec (Section VIII) | **Done** (ADR-039) — `ReputationManager.apply_marriage_transfer()`, with a new `pairwise_opinions` map to express "V's opinion of the spouse," which the flat `opinions` dict couldn't |
| 14 | Season-end success line | Locked — Hilda's line (Section X) | **Done** (2026-08-07) — both her success and failure lines wired into `season_summary_panel.gd`, chosen by whether the tithe was paid in full. The "markedly successful season" variant stays unwired, per the bible's own note that it's "beyond the locked scope" |
| 15 | X6 reward | Locked: +1 village standing + a mercy path (Section VII) | The standing-number change already shipped. The mercy-path branch has an implementation pass queued (dedicated DeepSeek worktree task, 2026-08-07) — not yet merged as of this row's last edit |
| 16 | Raid leader | **Stays open by design** — explicitly deferred past this slice (Section VII) | N/A |
| 17 | `harvest_demesne` fiction | Locked — reframed as clearing last autumn's stored sheaves, no data change needed | **Done** — fiction-only, nothing to implement |

**What remains genuinely open (owner decision, not just implementation):**
- Item 16, by design (the raid leader stays unnamed).

**Large systems still owed as of the last edit to this row** (each needs
its own design/testing time, not a side effect of a data pass): the
festival contest engine (item 8) and the X6 mercy-path branch (item 15) -
both have a dedicated implementation pass queued as of 2026-08-07 but not
yet merged. The marriage system (items 3, 11, 12, 13) shipped in full via
ADR-039 the same day this row was last edited.

### D. Data Files Touched

| File | Status |
|---|---|
| `crops.json` | Oats and flax present (v4). Verified. |
| `items.json` | Renames (Sorrel, Ramsons, Early Berries, Pottage) present; `rabbit` and `betrothal_ring` added. |
| `market.json` | Market days, toll, standing adjustment present (v5); `pottage`/`rabbit` prices added. |
| `buildings.json` | Cottage-upgrade and fence wood sinks present (v3). Verified. |
| `manor.json` | Court fines, corvee, black market, price drift present (v2). Verified — the illegal-sale fine is 20 coin, not the 15 an earlier proposal draft stated; corrected in this document's Section III. |
| `tithe.json` | v3 — `coin_per_held_strip` replaces `coin_per_tilled_tile`; `merchet_fee` added. ADR-038. |
| `recipes.json` | `pottage` (renamed from `herb_stew`), `betrothal_ring` added. |
| `villagers.json` | `villager_5` (Edith), `villager_6` (Osric) added — fully functional in-game (spawn, schedule, gifting, investigation, raid-thief eligibility) since the NPC systems read `villagers.json` generically. |
| `dialogue.json` | Standing-band lines added for both new villagers; Aldric/Tomas's five-band lines transcribed in Section II are unchanged. |
| `festivals.json` | Still ships names/days (`springturn_blessing`, day 18) that do not match this document's Section V calendar (Ada's Feast, day 21). Not touched this pass — flagged, not fixed. |

### E. Handoff Note

This document is now the narrative source of truth for *Tithe & Turnip*'s
Spring slice, standing below `CLAUDE.md` and the ADR log and above every
other design note. Two items remain genuinely open for an owner decision
(Appendix C); everything else is either fully implemented or is a locked
design waiting on a systems pass it does not, by itself, authorize.
