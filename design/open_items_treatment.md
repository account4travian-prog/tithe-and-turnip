# design/open_items_treatment.md — Treatment of the 17 Open Items

**Status:** Proposal / consult output. **Not authored by DeepSeek** — no
DeepSeek API access or CLI was available in this session; produced directly
by Claude (Sonnet 5) at the same rigor as this project's existing
`.deepseek/outputs/` consults, and clearly labelled as such rather than
faked. Everything below is a **recommendation, not a ruling** (per
`design/world_bible.md`'s own legend) until the project owner accepts it.
Nothing here has been written into `world_bible.md`, `setting_questionnaire.md`,
or any `data/*.json` file yet.

**Source:** the 17 open items listed in `design/world_bible.md` Appendix C,
carried over from `design/setting_questionnaire.md`'s open-collisions table.
Numbering matches that list.

---

## 1. Tithe/Assessment bridge gloss

**Recommendation:** a loading-screen tip, shown once, early:

> *Old-timers still call the manor's due "the tithe." On the roll, it is
> entered as the assessment — and it is the roll, not the talk at the well,
> that the steward reads from.*

**Rationale:** does the job in two sentences without breaking the register
(no fourth wall, no "the game" — it's framed as village usage vs. official
usage, which is true to how period terminology actually worked). Placing it
on a loading tip rather than the title screen keeps the title screen's own
locked line (Block 25.1) untouched.

**Alternative, if a loading-tip slot doesn't exist yet:** fold it into the
opening roll's presentation beat instead — after the parchment fades, a
single line of non-diegetic (menu-voice) text before the first morning:
*"The roll calls it the assessment. Everyone else still calls it the tithe."*
Slightly more intrusive; use only if there's no tip system to hang it on.

---

## 2. Per-acre assessment rate

**The modelling question first, because the number depends on it.**
`tenure.json` currently prices the three rentable strips at flat weekly
sums (5, 4, 5 coin per 7-day `rent_interval_days`) — not per-tile. If the
new held-acreage assessment (2b.4) taxes literal tile count, the base
10×10 owned plot alone is 100 tiles, which forces the per-tile rate down
to a fiddly fraction to stay sane. Taxing by **parcel** (the owned plot
counts as one unit; each rented strip is a second unit) matches the shape
`tenure.json` already uses and survives ADR-034's coming map rework better,
since exact tile counts on the current 30×20 grid are a placeholder anyway.

**Recommendation:** scale by held **parcels**, not tiles.
- Base 20 coin (already locked) covers the owned home plot.
- **+10 coin per rented strip currently held**, charged at the same
  season-end assessment moment as the base.
- A player holding all three strips (the current data's maximum) pays
  20 + 30 = **50 coin** for the season — a real stretch goal, not a trap,
  against a Spring where leeks sell at 15, onions at 12, and Wat pays a
  25% premium on top of either.

**A dependency worth flagging, not deciding:** `tenure.json` also charges
its own weekly `rent_per_interval` per strip, separate from the assessment.
Once acreage-scaling lands, a player renting a strip would be paying for it
*twice* — the weekly strip rent and the season-end acreage surcharge — under
two different names for the same fact (holding more land). **Recommend**
retiring the weekly per-strip rent charge when X13 lands, so "the
assessment is the rent" (already the bible's own phrase, Section III) stops
being a metaphor and becomes literally true — one due date, one number, per
season. This is a scope call beyond just picking a rate, so it's flagged
here rather than folded silently into the number above; the owner should
confirm before `tithe.json`/`tenure.json` are touched.

---

## 3. Merchet fee

**Recommendation: 25 coin.**

**Rationale:** it needs to sting without gatekeeping the whole marriage
system behind grinding. Against the game's own scale — a market day's good
haul is maybe 30–60 coin, a spear (a real splurge) is 150 — 25 coin reads as
"a real cost, paid once, at a moment the player has usually been saving
toward" rather than a wall. It also lands just above the assessment's own
20-coin base, which is a nice bit of unstated texture: the lord charges you
more to marry than he charges you to simply keep breathing on his land for
a season, which the player is free to feel some way about without a line of
dialogue ever saying it out loud.

**Placement:** paid to the steward at the point the banns are first read
(Block 11.4's three-market-day banns), not at the proposal itself — this
keeps the token (Section VIII, effort not coin) and the merchet (coin, not
effort) doing different narrative work rather than both landing on the same
beat.

---

## 4. The two unwritten Tier 1 principals — full sheets

### Edith — the neighbouring tenant

- **Age:** Early twenties, close to the player's own.
- **Trade & household:** Tenant farmer on the plot adjacent to the
  player's, holding it alone.
- **Wants:** To prove a woman's name on the roll needs no husband's beside
  it. She is not fighting the player; she is fighting the assumption that
  she needs to be married to keep her strip, an assumption the manor and
  half the village share without ever quite saying.
- **Fears:** Losing the plot to a "better," meaning male, claimant — a
  cousin, a suitor she never asked for, anyone the steward would find it
  easier to grant the land to.
- **Traits:** Proud, competitive, generous underneath it once the
  competition is won or abandoned. She counts things out loud — rows,
  days, coins — a farmer who trusts numbers over people: *"Three rows in.
  Two more to go, if the rain holds."*
- **Voice:** Every line contains a count or a tally, spoken or implied.
- **Marriage candidate:** **Recommended: yes.** A peer romance is standard
  to the genre and currently missing entirely from the four existing
  candidates, all of whom the player meets from a position of asking
  something of them (trade, faith, law, information). Edith is the one
  candidate the player meets as an equal.
- **Standing bands:** hostile — refuses to acknowledge the player's plot
  exists at all, which is worse than contempt. cold — talks about her own
  work, never asks about the player's. neutral — compares yields evenly,
  no warmth, no edge. warm — offers a tip that would genuinely help the
  player's own farm. friendly — asks the player for help first, which for
  her is the real vulnerability.
- **Family (feeds item 6, below):** Aldric's younger sister.

### Osric — the miller

- **Age:** Forties. Not native to Nettleford — took over the mill from a
  childless predecessor some years back, which is also why he carries no
  ready-made ties into the village's web (a clean reason he needs no forced
  kinship of his own).
- **Trade & household:** Runs the village mill on the Nettle Brook, held by
  a manor licence — no one grinds grain to flour without going through him,
  which makes him a power the village feels daily even though his charter
  ultimately comes from the same roll as everything else here. He takes his
  cut in **multure** — a toll paid in flour, not coin, at the mill door.
- **Wants:** The hand-quern trade stamped out. A household that grinds its
  own grain at home doesn't need him, and he resents every one that tries.
  He is quietly, plainly self-interested about this, in a way none of the
  six written principals are about their own trade.
- **Fears:** A second mill licensed on the brook, or the brook itself
  running low in a dry season — either one and his leverage is gone.
- **Traits:** Shrewd, transactional, not cruel — he has simply learned that
  flour is leverage and uses it plainly, without dressing it up.
- **Voice:** Speaks in weights and shares. *"A sack in, three stone back —
  that's the toll, same as always."*
- **Marriage candidate:** **Recommended: no.** Keeps the pattern clean —
  Aldric, Tomas, and now Osric are the three principals whose power sits
  outside the courtship pool; everyone the player can actually court is,
  in some sense, a peer rather than an authority. That's a real design rule
  a writer can hold onto, not just a headcount.
- **Standing bands:** hostile — takes the multure at its harshest legal
  measure and says so. cold — grinds the player's sack last, after
  everyone else's. neutral — takes his cut, says nothing further. warm —
  the sack comes back a little heavier than the toll strictly allows.
  friendly — warns the player when the multure rate is about to rise,
  before the manor announces it — his own version of Cedric's "best reward
  in the game," but economic gossip instead of road gossip.

**Decision needed (owner):** accept, reject, or amend these two sheets;
confirm marriage candidacy for both (Edith yes / Osric no is the
recommendation, not a foregone conclusion).

---

## 5. The young clerk

**Recommendation: name him Simkin.** Single given name (period-authentic —
a real Middle English diminutive, not tied to one famous historical
bearer), distinct in sound from the eight principals' names.

**Tier placement: Tier 2 (Resident).** He has a fixed work location (the
stall) and an active mechanic (his tone mirrors Aldric's opinion of the
player) — more than Tier 3's "referenced, never instantiated" bar, but he
carries no romance and no investigation role, so Tier 1 would overstate him.

**Brief sheet (Tier 2 depth, not a full Tier 1 sheet):**
- **Age:** Early teens — period-plausible for the start of an
  apprenticeship-style service.
- **Wants:** Aldric's approval, and someday his post.
- **Fears:** A scales-error made in front of a customer.
- **Trait:** Earnest, quick with sums, visibly aware he's being watched.

**A deliberate non-decision:** recommend he does **not** get his own
voice-tic to sit alongside the eight principals' six (Aldric, Tomas, Hilda,
Cedric, Marta, Bram already own that list). His texture should live in his
*handwriting*, not a spoken tic — see item 9 below, where his still-uneven
lettering on the town board does this work instead. A ninth tic to track
would dilute the six that already exist without buying much.

---

## 6. Familial ties among the eight

**Recommendation: Edith is Aldric's younger sister.**

This is the tie introduced in item 4, restated here because it's the
answer to this question specifically. It satisfies Block 12.2's "at least
two of the [cast] share blood or marriage" on its own, and it respects the
hard constraint (no two marriage *candidates* may be kin to each other) by
running the tie through Aldric, one of the two non-candidates.

**Why it's worth more than a fact:** it gives Aldric's rigidity a cost he
pays personally, not just professionally. His own sister is fighting to
hold a strip alone, and the sheet above (10.2/10.3, LOCKED) says he will
not bend a rule for anyone — which now has to include her. Play that two
ways depending on scene: the village can read his refusal to help Edith as
proof he really is impartial (respect), or as a colder thing — a man who
won't lift a finger even for his own blood (resentment). Both readings
should stay available; don't resolve which one is "true." That ambiguity
is more interesting than either reading alone, and it costs nothing new to
build — it's the existing Aldric sheet, pointed at a second target.

No second tie is recommended; one well-used relationship beats two thin
ones, and the ruling only requires "at least two" of the cast, which this
already delivers.

---

## 7. Missed-festival opinion-tick roster

**Recommendation (four notice, four do not), with the reasoning per
character rather than a bare list:**

| Notices a missed festival | Does not notice |
|---|---|
| **Hilda** — she keeps the village's social ledger in her head; an absence is exactly the kind of thing she'd register and mention later. | **Cedric** — often absent himself (night watch); wouldn't judge someone else's absence he can't verify was avoidable. |
| **Bram** — measures status by who was seen where; a missed public event is precisely his currency. | **Marta** — has her own reasons to keep her head down at gatherings; the last person to begrudge someone else's absence. |
| **Tomas** — it's his mass. His reaction should read as quiet concern, not social judgement — a distinct emotional flavour from Hilda's and Bram's. | **Aldric** — festivals sit on the church/village standing axes, not the manor axis; not his ledger to keep. |
| **Edith** — competitive by nature; tracks whether the player is "keeping up," festivals included. | **Osric** — transactional; cares whether the multure was paid, not whether anyone danced. |

Clean 4/4 split, and each "notices" or "doesn't" now has a one-line reason
a dialogue writer can lean on instead of memorising an arbitrary list.

---

## 8. Festival contest rules

All four designed to stay in-lore, none needing more than what already
exists (`skills.json` levels, the reputation axes, coin) — consistent with
ADR-030's no-new-simulation-layer boundary.

### Ada's Feast (Spring, reachable) — the Furrow Race

A ploughing race along the field boundary, blessed at the feast.
- **Direct entry:** not a twitch mini-game. Three timed prompts fire as the
  "team" passes; each successful press (a normal action-button press, no
  new input) adds to a furrow-straightness score. The Farming skill level
  (0–5, `skills.json`) shifts the timing window's forgiveness, so a
  higher-skill player is rewarded for what they've already built, not asked
  to learn a new twitch skill. Win: a Farming XP bonus, a village-standing
  tick, and (recommended, extending 24.4's once-only-text idea) a single
  once-per-playthrough line if it's the player's first win.
- **Cheer/bet mode:** back **Cedric** (steady, low variance) or **Bram**
  (showy, high variance — talks himself up, sometimes delivers) with a
  small coin bet (1–5 coin, player's choice) at even-money-ish odds
  weighted slightly toward Cedric. Correct bet pays out; either way, the
  player gets the reputation "cheering" bonus with whoever they backed.
  Using two already-written principals as the entrants costs nothing new
  to cast and is already characterful — Cedric's diligence against Bram's
  bluster is the race in miniature.

### Haysel (Summer, data-only) — the lifting contest

Tests the Labor skill instead of Farming, keeping the four festivals from
all testing the same stat. Same direct-entry/cheer-and-bet shape as above.

### Harvest Home (Autumn, data-only) — sheaf-tying

Tests Farming again, but through a different fiction (precision and speed
rather than timing) — "most sheaves tied before the bell finishes
ringing." Entrants should be drawn from the Tier 2 cast once it exists;
flag this one as genuinely lighter than the other three until residents
are written.

### The Long Night (Winter, data-only) — the storytelling contest

Deliberately **not** a skill-check. A hearth-bound, dead-of-winter
festival earns a different texture: the player picks a favourite
storyteller among whichever principals are present and cheers, no
direct-entry mode at all. Gives the calendar's four contests real variety
(three physical, one purely social) instead of four reskins of the same
mechanic.

**Decision needed (owner):** accept this shape, or send it back for a
different split; either way it needs prototyping before it's real, per the
original open item's framing.

---

## 9. Town board fiction

**Recommendation:** the board sits under Aldric's authority (matches
ADR-037's folding into `TitheManager`), but the *voice* on each posting is
an ordinary household's, transcribed by Simkin (item 5) in his own still-
uneven hand — which is exactly the texture that gives him presence without
needing a spoken voice-tic. Two sample postings, in that double voice
(colloquial request, a clerk's careful but imperfect lettering):

> *Ramsons wanted. Three bunches. Coin on delivery. — the Millers' girl
> has a fever and her mother swears by the poultice.*
> *(a word crossed out and re-written above it; the numeral "3" traced
> twice, as if unsure the first pass was clear enough)*

> *Barley sought for the Whitsun brewing. Two sacks, fair price paid at
> the board. Ask for Hilda if none is offered outright.*

**Rationale:** this also quietly answers a smaller worry — that the board,
being a manor-adjacent mechanic, could read as impersonal in a game that
otherwise insists on a village with an interior. Routing its handwriting
through a character who already exists (rather than an anonymous system
voice) keeps it inside the cast instead of beside it.

---

## 10. Pottage and game-meat content

**Pottage:** `herb_stew` already *is* pottage in every functional sense —
a hearth dish of wild greens and a root vegetable, no skill required, cheap.
**Recommendation: rename it**, in `items.json` and `recipes.json`, from
`herb_stew`/"Herb Stew" to `pottage`/"Pottage." A data-only rename, no new
recipe, no new mechanic — and it closes both this gap and G9 (no food
culture) from the original gap analysis in one move, since "Pottage" is
the single most period-evocative name available and it's sitting unused on
an identical recipe.

**Game meat:** add one new item — `rabbit`, "Rabbit," a purchased good
(never foraged, never hunted; the forest is the lord's, per Block 21.3).
Recommend price **10 coin**, `energy_base` around **10**, sold at Wat's
cart and, at the owner's discretion, occasionally at the market stall
too. Deliberately humble (rabbit, not venison) — venison would read as an
aristocratic or risky thing for a peasant to be caught with, which
undercuts rather than serves the fiction; rabbit is exactly the "bought
from a neighbour who had luck trading" item Section VI already describes.

**Decision needed (owner):** approve the rename and the new item; both are
small enough to land in the same data pass as X13, if that's convenient.

---

## 11. The proposal-token recipe

**Recommendation:** the braided straw-and-rush ring is made from
**`flax_fibre`** — an item that already exists, already narratively
"spun... or woven" (Section VI), and currently has exactly one use (sell
it). Giving it a second, sentimental use is a strong, cheap payoff: the
crop the game tells the player never to eat becomes, in this one recipe,
the thing they choose not to sell either.

**Recipe (drop-in shape for `recipes.json`):**
```
{ "id": "betrothal_ring", "station": "hearth", "inputs": { "flax_fibre": 1 },
  "output_item_id": "betrothal_ring", "output_count": 1, "energy_cost": 2,
  "craft_days": 0, "skill_id": "", "skill_level_required": 0 }
```
**Item (drop-in shape for `items.json`):**
```
{ "id": "betrothal_ring", "type": "material", "name": "Braided Ring",
  "price": 0, "stackable": false }
```
No station change needed (hearth already exists); no gating (this should
be available to any player who's grown a little flax, not skill-locked).

---

## 12. Spouse request lists

One recommended request per candidate, each built from that character's
own established want/fear rather than a generic fetch task:

- **Hilda** — she can't leave the alehouse mid-brew. Asks the player to
  mind a batch while she's called away, or to fetch sorrel/ramsons she
  hasn't had a free hour for.
- **Cedric** — poor sleep from the night watch. Asks the player to stand a
  watch shift in his place for a night, or to gather flint/wood he hasn't
  had time for.
- **Marta** — the lovely one: post-marriage, her old need never actually
  went away, it's just no longer secret. She occasionally asks for coin or
  food, plainly, for the same dependent she used to steal for — the exact
  same want, now spoken instead of hidden. No new fiction required; it's
  the payoff of 8.4's own ruling, made concrete.
- **Bram** — often on the road. Asks the player to look in on his place
  while he's travelling, or to carry word/goods back from a market day
  he'll miss.

Each: low frequency ("occasionally," per the locked ruling), modest reward
(coin, standing, or opinion — not all three), never framed as a fetch-
quest in the deny-list sense (no marker, no menu entry that reads like one
— just dialogue that asks and an inventory check that resolves it).

---

## 13. Marriage reputation-transfer — implementable spec

Reusing the band thresholds already shipped in `dialogue.json`'s steward
lines (friendly ≥50, warm ≥10, neutral ≥‑9, cold ≥‑49, hostile <‑49) rather
than inventing a new scale:

**On the wedding, once, for every other principal V who has a recorded
opinion of *both* the player and the new spouse:**
1. If `opinion(V, spouse) > opinion(V, player)`: `opinion(V, player) +=
   25`, clamped to [‑100, 100].
2. If `opinion(V, spouse) < opinion(V, player)`: `opinion(V, player) -=
   25`, clamped to [‑100, 100].
3. Symmetric pass for the spouse's opinion of V, using the player's
   standing with V as the reference.
4. If V has no recorded opinion of one party (never interacted), skip —
   no transfer without an actual relationship to soften.

**Why a flat ±25 rather than a computed "one band":** band widths in the
shipped scale aren't even (cold/warm each span 40 points, neutral spans
19), so "move exactly one band" isn't a single well-defined number. A flat
25-point nudge reliably crosses the narrowest band (neutral) and makes a
meaningful dent in the wider ones, without requiring the engine to look up
band boundaries at all — simpler to implement, and close enough to "one
notch" that it will read correctly in play.

---

## 14. Season-end success line

Block 25.3 locks the *shape* (Hilda, one sentence, warm/teasing/cutting by
her opinion of the player) but never drafted the text. Recommendation,
matching the failure line's already-approved register (Block 25.4) and
Hilda's question-tic:

> *"Paid in full, was it? Didn't I say you had it in you?"*

**One-line rationale:** warm without being saccharine, teasing in exactly
the register Section IX allows her, and it answers its own question rather
than waiting on the player — consistent with how her tic reads elsewhere in
the sheet.

**Optional addition, beyond the locked scope — a second variant for a
markedly successful season** (e.g., no arrears *and* high manor standing),
if the owner wants texture between "scraped by" and "thrived":

> *"Look at you. Coin to spare and no one had to tell you to sleep, either
> — did they?"*

Flagged explicitly as an addition, not required by the locked ruling.

---

## 15. X6 — village-standing reward for informing on Marta

The owner already agreed this is worth revisiting (18.5). **Recommendation:
reduce the flat reward and add a genuine third path**, rather than just
retuning the number.

1. **Reduce village standing on a correct accusation** from **+4 to +1**.
   Manor standing stays at +2 — the manor has an unambiguous reason to be
   pleased; the village's "relief" (per the bible's own text) shouldn't
   read as a clean social win, and +1 says "noticed, not celebrated" far
   better than +4 does.
2. **Add a mercy path.** If the player has assembled enough of the clue
   trail to *know* it's Marta but chooses not to accuse — quietly covering
   for her instead (leaving food anonymously, or simply sitting on the
   proof) — no manor or village standing change either way, but a private
   opinion gain with Marta and an event flag that lets her thefts taper off
   on their own once whatever crisis she's covering for passes. This gives
   the player a real middle option between "accuse" and "marry her,"
   which right now doesn't exist — marriage is a very large lever to pull
   just to be merciful to someone.

**Why this is worth the extra system surface:** it's a small addition
(one more event-flag branch, no new UI) that directly answers the
discomfort the owner already flagged, rather than only turning a dial.

**Decision needed (owner):** approve both changes, the standing reduction
alone, or neither — these touch shipped numbers and a small new branch, so
they need explicit sign-off before implementation.

---

## 16. The raid leader's identity — staying deferred, well

This item is *supposed* to stay open past the slice (Block 18.3, explicit).
A "quality treatment" here isn't naming him — that would violate the
ruling it's supposed to serve — it's leaving clean threads for whoever
picks this up later, so the deferral is a placeholder for an interesting
answer and not just an empty box.

**Threads already planted in the fiction, unclaimed, worth protecting for
later rather than spending now:**
- The bandits are already written as "what the player might become" (Block
  12.4, Section VII) — a leader with a name the player half-recognises
  would cash that theme in directly, rather than needing a new one built
  from scratch.
- Bram's testimony is established as "inflated but founded" (Block 9.3) —
  whatever he's said about the raid leader across the slice becomes
  retroactively partly true the moment the leader is finally named, which
  costs nothing to set up now and pays off later for free.
- Cedric's night watch (Block 7.3) makes him the one character positioned
  to have actually *seen* the leader up close before anyone else does —
  a natural reveal-conduit already sitting in the cast.

Nothing above is a proposal to resolve him now. It's a note for whoever
does, so the eventual answer doesn't have to be invented from zero.

---

## 17. `harvest_demesne` chore fiction (X5)

The problem: `tithe.json`'s corvee chore list includes `harvest_demesne`,
but Spring has no harvest — nothing on the lord's demesne is ready to reap
in a Spring-only slice.

**Recommendation: fiction fix, not a data fix.** Reinterpret the existing
chore diegetically as clearing and hauling out the **last of the previous
autumn's stored sheaves** from the demesne barn — finishing last year's
harvest logistics, not this year's crop. That's historically real (grain
stores genuinely were still being threshed and moved well into spring) and
needs zero changes to `tithe.json`'s `chore_ids` or any code — only the
chore's flavour text, wherever it's surfaced to the player, needs to say
"the old sheaves" rather than implying a Spring reaping.

**Alternative, if the owner would rather the data be exact:** rename the
chore id to `thresh_demesne` (or similar) and hold "harvest" language for
whichever season actually reaches a harvest. Flagged as the fallback
because it *is* a data/code touch, where the recommendation above is not.

---

## Summary table — what needs an owner decision, and how big each is

| # | Item | Size of ask |
|---|---|---|
| 1 | Bridge gloss | Text only — drop in as-is |
| 2 | Per-acre rate | Number + a scope call on retiring strip rent |
| 3 | Merchet fee | Number only |
| 4 | Two principal sheets | Full sheets to approve/amend + candidacy call |
| 5 | Young clerk | Name + tier to approve |
| 6 | Familial ties | One relationship to approve |
| 7 | Festival-tick roster | Roster to approve |
| 8 | Festival contests | Full mechanic to approve, then prototype |
| 9 | Town board voice | Text/voice convention to approve |
| 10 | Pottage/game-meat | One rename + one new item |
| 11 | Proposal-token recipe | Drop-in recipe + item |
| 12 | Spouse requests | Four short request texts to approve |
| 13 | Reputation-transfer math | Implementable spec, ready for C6 |
| 14 | Success line | Text to approve |
| 15 | X6 reward | Number change + new branch, needs sign-off |
| 16 | Raid leader | Explicitly stays open — notes only |
| 17 | `harvest_demesne` | Flavour-text fix, no data change |

Once any subset of these is approved, the next step is folding the
accepted ones into `world_bible.md` (moving them from `[OPEN]` to LOCKED,
citing this document) and into the relevant `data/*.json` files — neither
has been touched yet.
