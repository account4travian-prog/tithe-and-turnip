# design/world_biblePROPOSAL.md
> **Assembly note (2026-08-07):** assembled from four DeepSeek V4 Pro rounds (outline, Part A, Part B, Part C) with orchestrator review. Corrections applied at assembly: Bram is the carter, not the smith (Cedric is the smith/hedger); Wat travels with a cart, not a pack; the non-candidates are the priest and the steward, not a clerk; the two sheet-less principals' candidacy is OPEN; X13's data version bump targets tithe.json (tenure rework belongs to ADR-034); per-character standing bands folded in from the questionnaire. Relay facts for all four calls are in .deepseek/outputs/worldbible_r*.md.receipt.json.


## I. Header & Status

**File:** `design/world_biblePROPOSAL.md`  
**Purpose:** This document defines the world of *Tithe & Turnip* — its geography, people, history, and tonal boundaries — as distilled from the full design questionnaire. It is the single source of narrative truth for all in-game text, dialogue, and event design. Opus 5 will finalise the presentation; this proposal locks every detail that was settled in interview and flags every gap that remains.

**Legend:**
- **LOCKED** — Settled in pre-production; do not alter without an Architecture Decision Record.
- **[OPEN]** — A conscious gap. The line describes the nature of the decision still required. Resolving it does not need a contract amendment unless it crosses a system boundary.

---

## II. The Place

The **Manor of Harrowmere** sits in the **vale of the Nettle**, a rolling lowland a day’s walk end to end. To the north, blue mountains smudge the horizon — a wall the eye leans on, the direction every story points. No one in Nettleford has ever reached them; they are weather, not destination. The vale is ringed by uplands and hills, thin-soiled country given over to sheep, the commons, and the wild margin where bandits hide. The vale floor is the good land: the demesne that feeds the lord, the tight cluster of **Nettleford** village, and the tenant plots strung along the **Harrow Road**. The road runs the spine of the vale, north into the uplands and south toward **Coldwich**, the nearest market town. Coldwich is a name on a cart-bench, a destination; it does not yet have a map.

In law, the lord owns every inch of soil, but custom is older than parchment. The village holds the right of common by usage — pasture, estovers (deadfall, furze, and hedge-cutting), and the liberty to take what grows. The manor resents it. The commons are a live wound, the subject of quiet enclosure and loud argument. In spring, during the hungry gap, no one questions a villager cutting deadfall or pulling wild carrot; the other eight months, every step off the tenancy is a statement.

The plague that swept through the vale a generation ago left its mark on the ground. Fallow strips and abandoned cottar plots still scar the demesne. The church collapsed with the dead; old beliefs and field rites crept back into the silence. Now the church is returning, and the village is of two minds about it. The manor sees it as useful; many in Nettleford see it as a second lord.

The game’s map set (ADR‑034) will comprise eight to ten zones: the player’s own plot, the village of Nettleford, the manor house and its immediate grounds, and two or three wilderness edges — upland, woodland, riverbank — plus two or three neighbouring tenant plots. Persistent trees and rock nodes are deferred past the vertical slice; for now, wood comes from deadfall, hedge‑cuttings, and the market stall.

---

## III. The People

The cast of Nettleford is small enough that every face is known. The plague thinned the elders; the village is a place of people in their thirties and forties, with only a handful older. The six principals below are the named drivers of daily life. Each carries a full sheet — age, trade, want, fear, trait, voice, and the standing bands that govern how they see the player. The itinerants and the unresolved figures follow.

### The Six Principals

#### Hilda (LOCKED)
- **Age:** Twenties.
- **Trade:** Alewife. Her alehouse doubles as the village inn; travellers sleep in an outbuilding that is also her home.
- **Wants:** Her brewing to be recognised as the village’s craft, not a widow’s pastime.
- **Fears:** Being dismissed for her sex — her knowledge taken and her name erased.
- **Traits:** Warm, compulsive gossip. She cannot hold a secret, which makes her the game’s most reliable vector of information; the player learns things from her that no one meant to say aloud. She half‑knows Marta’s theft and says nothing, because some pockets are deeper than her tongue.
- **Voice:** Every line asks a question. She teaches preserving and brewing.
- **Marriage candidate:** Yes.
- **Standing bands:** hostile: shuts the door and talks. cold: polite, and you hear about it later. neutral: news and weather. warm: advice you did not ask for. friendly: treats you as family and defends you unprompted.

#### Cedric (LOCKED)
- **Age:** Thirties.
- **Trade:** Smith or hedger — the village’s iron hand and its watcher on the road.
- **Wants:** The village able to defend itself. He saw the first raid and has not stopped seeing it.
- **Fears:** Being right and being ignored. He is the man with no alibi and the man most likely to have seen something; his knowledge is a weight he carries alone because no one asks.
- **Traits:** Gruff, vigilant, unpaid. He keeps watch from his door or the smithy by habit, a secondary set of eyes the manor never ordered. His speech is economy itself.
- **Voice:** Shortest lines in the game; rarely exceeds eight words. Teaches building.
- **Marriage candidate:** Yes.
- **Standing bands:** hostile: turns his back. cold: single syllables. neutral: work talk only. warm: shares tools. friendly: shares what he has seen on the road - mechanically the best reward in the game.

#### Marta (LOCKED)
- **Age:** Late twenties.
- **Trade:** Cottar — no land of her own. She hires out by the day to whoever can pay coin or food.
- **Wants:** Enough. She steals food and seed, never coin, never from the poorest, to feed a dependent whose nature no one in Nettleford has named aloud.
- **Fears:** Being caught. She knows when the player suspects her and goes quieter. Silence is her armour.
- **Traits:** The village’s quietest inhabitant. Her thefts are patterned: they escalate only when the dependent is hungry, and they stop if the player marries her (the player holds the knowledge then, and the need is met). She is not malicious; she is careful.
- **Voice:** Answers a question with an observation; never says “I.”
- **Marriage candidate:** Yes.
- **Standing bands:** hostile: says nothing at all. cold: courteous and absent. neutral: deflects ("I'm just a simple farmer" - a lie). warm: small true things. friendly: tells you something she should not.

#### Bram (LOCKED)
- **Age:** Thirties.
- **Trade:** Carter or drover. He lives apart by the road, a span outside the village proper, and tells himself it is choice.
- **Wants:** Standing he has not earned. He knows the roads better than any man in Nettleford and believes that should count for more than it does.
- **Fears:** Being found ordinary. Every boast is a door he is holding shut.
- **Traits:** Boastful, a self‑made exile. His knowledge is real — he is the unreliable witness whose details are always inflated but never fabricated. He can tell you what he saw on the Harrow Road last market day, and the colour of the cart will be wrong but the number of wheels right.
- **Voice:** Every statement carries a comparative — “farther than Coldwich,” “rougher than the spring drive,” “more stone than a lord’s wall.” Teaches trade, routes, and the price of things.
- **Marriage candidate:** Yes.
- **Standing bands:** hostile: loud contempt. cold: performative indifference. neutral: stories about himself. warm: stories with the player in them. friendly: drops the performance, briefly.

#### Aldric the Steward (LOCKED)
- **Age:** Late thirties to early forties.
- **Trade:** Steward of Harrowmere. A villein’s son who learned letters and rose; resented by the village for the climb, never quite trusted by the manor for the origins.
- **Wants:** The manor’s accounts to balance and the law to hold. He is not corrupt; he will not take a bribe and will not bend a rule. Both of those things hurt the player equally.
- **Fears:** The bailiff. When the bailiff audits unannounced, Aldric’s word is the only shield the player has — and only if manor standing is high. At low standing, the bailiff overrules without a second thought.
- **Traits:** Rigid, precise, and unsmiling. He presides at the market stall, teaching letters and numbers to a young clerk whose own character remains unfinished — a mirror of Aldric’s opinion of the player.
- **Voice:** Never contracts. Speaks in obligations: “You will,” “You must,” “It is required.” At high individual opinion, he warns the player before the manor court sits — a breach of his own rule, and the only one he allows himself.
- **Marriage candidate:** No.

#### Father Tomas (LOCKED)
- **Age:** Thirties.
- **Trade:** Village priest. Born in Nettleford, never left; still trying to prove he belongs in the collar.
- **Wants:** To repair and grow the church because he believes in it — a faith that survived the plague when the institution did not.
- **Fears:** That the village sees him as a boy in a cassock, not a shepherd.
- **Traits:** Devout to the point of distraction. His forgetfulness is real — a byproduct of a mind too full of liturgy and worry — but he also wields it deliberately, letting people underestimate him and then surprising them with sharp recall when it matters. He is never the joke; he lets you think he is.
- **Voice:** Repeats a phrase from earlier in his own line; blesses reflexively. He thinks the lord’s assessment is lawful and says so, and it costs him to say it. Hilda is his oldest friend and manages his forgetting with quiet care.
- **Marriage candidate:** No (celibate).
- **Standing bands:** keep the existing five lines canonical (11.5); the hostile line "The bishop will hear of this" implies the off-map hierarchy.

### Itinerants (LOCKED)

#### Sir Edric Vane
The lord, a minor knight whose title outweighs his purse. He returns to Harrowmere frequently: the initial arrival around day 5, the reckoning after the scripted raid (~days 15–16), and the accounting of the manor roll around day 27. When he is in residence, the manor stiffens; Aldric’s authority shrinks to accounts, and every answer must satisfy a man who does not know the soil.

#### The Bailiff
Sir Edric’s eyes and fist. He arrives unannounced and overrules Aldric on matters of revenue and justice. The player’s protection is not a document but a relationship: if manor standing is high, Aldric’s word holds; if it is low, the bailiff takes what the roll says.

#### Wat the Chapman
An itinerant trader, a voice and a cart. He appears on market days 9 and 20, offering coin above the assize with no toll. Selling to him is illegal — it evades the lord’s share — but the village will not inform. Detection drops as village standing rises; the community closes its mouth. Wat is a test of loyalty as much as a source of coin.

### Further Principals (Sheet‑Less) [OPEN]

Two additional Tier 1 principals are required to round the cast. Their sheets have not yet been drafted.

- **The neighbouring tenant** — the player’s peer, another smallholder working a plot along the Harrow Road. Their wants, fears, and traits must mirror the player’s struggle without duplicating it; they represent what the player could become.
- **The miller or alewife‑equivalent** — a holder of economic power outside the manor and the church. This character was originally imagined as the black‑market gate, but that thread now belongs to Wat the Chapman (see above). The miller’s role is therefore re‑rooted in legitimate village economy: flour, price, and the tension of a monopoly that every loaf depends on.

Both are potential **marriage candidates**, but their candidacy is **[OPEN]** - to be settled when their sheets are written (the ADR-031 boundary excludes the priest and the steward, not future Tier 1 principals).

### The Young Clerk [OPEN]

An unfinished character who mirrors Aldric’s opinion of the player. Aldric teaches him letters and numbers at the market stall. No name, tier, or sheet has been assigned. The clerk’s function in dialogue and economy should be determined before his scenes are written.

### The Web

The village is not a backdrop; it is a knot of obligations, resentments, and silences that the player can pull.

**Observed relationships (LOCKED):**
- **Hilda and Tomas** are old friends. She covers his lapses in memory without remark and without condescension; he is the one person of whom she does not ask questions.
- **Cedric and Aldric** hold mutual contempt — the watchman who acts without permission and the steward who cannot act without rules. They speak about each other in clipped sentences.
- **Marta and Hilda:** Hilda half‑knows the theft. She says nothing. It is the one secret bigger than her own tongue.

**Familial ties [OPEN]:** At least two of the six principals share blood or marriage, because Nettleford is a place where most people are one family or another. The specific ties have not been decided. Two marriage candidates must not be close kin.

**Village disagreements (LOCKED):**
- **The commons.** Grazing versus foraging. The manor is quietly enclosing the uplands; Cedric sees it as theft of custom, Bram sees it as inevitable and argues that a wise man gets ahead of it. The argument spills into the alehouse weekly.
- **The church’s return.** Half the village remembers the plague years when the priest was dead and the fields were blessed by old women at dawn. Tomas walks a line between two congregations — those who want a church and those who remember they survived without one.

**The blame (LOCKED):** The raids are a wave of dispossessed peasants, men and women who lost their holdings in the noble infighting that followed the plague’s upheaval. They are not monsters; they are what the player might become. Nettleford knows this and talks around it.

---

## IV. Power & Economy

## The Manor of Harrowmere

Harrowmere is held of a greater lord whom nobody names aloud. That lord is distant enough to be an article of faith—the tax roll will someday reach him, but nobody in the village has ever seen his face. The knight who holds this land in his name, Sir Edric Vane, is not an abstraction. He returns frequently, and his presence falls across the village like the shadow of a hawk.

**Sir Edric** arrives around the fifth day of seedtime. He does nothing mechanical in that first visit; he simply *is*, a man walking the boundary paths and watching the plough teams, and the village straightens its back when he passes. His return after the scripted raid on day fifteen carries a different weight: the raid is no longer just a combat event but a political wound that must be dressed, and Sir Edric’s displeasure or patience shapes how the steward acts through the rest of the season. The accounting of the roll on day twenty‑seven is the last time the player sees him before the season‑end summary—the moment when the lord’s ledger becomes a person standing in the churchyard, and the player’s standing with the manor cashes out into something tangible.

**The bailiff** arrives without announcement and can overrule Aldric the steward. His audits are not scheduled; they appear like a storm. When the player’s manor standing is good, Aldric’s word covers them—the steward vouches for the holding, and the bailiff’s interest fades. At bad standing, that protection evaporates, and an audit can draw blood from a farm already thin from the hungry gap.

## The Steward

Aldric is rigid—not cruel, not corrupt. He cannot be bribed; he will not bend a rule for friendship. What he will do is champion a tenant whose actions benefit the manor and the village together. Competence is the language he understands, and at high individual opinion he warns the player before the manor court sits. That warning is precious: it tells you what the charge is and whether you will need a fine or a defence. Aldric answers to the bailiff, and he knows that his own position depends on the lord’s confidence. He serves the village because he serves the manor; the player who sees those two loyalties as one thing finds an ally.

## The Manor Court

The court meets on days twelve and twenty‑six, in the churchyard. It is half legal proceeding and half village theatre: every household attends, the steward reads the roll, the clerk scratches entries into the book, and the whole community watches. Fines are fixed by custom and loud in their effect—fifteen coin for witnessed violence, illegal sale, or a false accusation. The coin is the least of it. Being fined is humiliating; it is the village seeing that you are not in good standing with the manor, and that verdict follows you into every conversation for the rest of the season.

## Tenure and the Assessment

The holding—the farm map the player works—is held on condition of rent. Rent is the assessment: a base of twenty coin, plus a charge for each acre in the holding [LOCKED—base from questionnaire; per‑acre rate is [OPEN: the exact per‑acre rent rate must be decided and added to `data/time.json` or a new rent‑schedule file] ]. The assessment can be met three ways: in coin, in kind (crops valued at the assize price, multiplied by quality), or at the boon‑work—the corvée labour days summoned by the steward. However it is paid, the full amount must be settled by season’s end or the manor court distrains.

Distraint is not eviction and not a prison cell. The court seizes stock and tools to the value owed, and the holding is entered in arrears on the roll. The player continues—poorer, marked, and knowing the village watched it happen. A distraint is a slow, public wound, and the only way out of it is the next season’s rent paid in full.

**The Corvée (Boon‑Day).** The steward may summon the player to labour on the lord’s demesne on one day’s notice. This is the boon‑day—ploughing or carting, or whatever the demesne needs. It cannot be refused; the only choice is to succeed or fail. A failure is a court matter. The labour credit it earns applies to the assessment at one‑and‑a‑half times the ordinary rate, which makes it the most efficient way to settle the lord’s demand, but the timing is never the player’s.

## The Market

The market is held by charter on eight days each season: the third, seventh, tenth, fourteenth, seventeenth, twenty‑first, twenty‑fourth, and twenty‑eighth days. It is a manor court right, not a convenience, and the toll of five parts in a hundred is the lord’s cut for the privilege of trading.

Prices are the assize—fixed by the court from custom and revised at Michaelmas. In practice, the assize is ignored at the margins: on any given market day prices drift by a small amount (up to five percent, locked at market open) as the stall‑keeper’s ledger adjusts to recent gluts and dearths. A tenant in good standing with the manor pays a slightly better price (up to ten percent advantage); a tenant in bad standing finds the clerk less inclined to weigh the scales generously.

Aldric presides. He is teaching a young clerk—a boy learning his letters and numbers—to transact the stall. The clerk’s view of the player mirrors Aldric’s opinion: if the steward is displeased, the clerk will be cold and exacting; if the steward is pleased, the clerk becomes an ally who might weigh a sack of barley just a little shy of the toll.

Wood is sold at the stall, and its presence there matters: deadfall and hedge‑cutting are rights of common, but the market offers a supply for anyone who cannot gather enough themselves, setting a ceiling on the price of building and fuel.

**Coin itself** is the penny, called “coin” in every interface. A single coin buys a loaf of bread. A soldier’s weapon—a spear or a bow—costs a hundred and fifty coin, a sum so absurd for a peasant to own that it marks the weapon as an heirloom or a dangerous ambition. The game’s economy builds its meaning around that word: coin is always concrete, a thing weighed and counted, not an abstract score.

## The Black Market

On the ninth and twentieth days of seedtime, a chapman named Wat appears at the edge of the village. He pays above the assize price—twenty‑five percent more—and charges no toll. Selling to him means evading the lord’s toll, which the manor court considers theft, plain and simple. The law says it is stealing from the lord. The village says it is fair dealing and will not inform; Wat’s presence is an open secret, and a player who sells to him is not a villain in the eyes of the neighbours.

The danger is detection. A dice roll, scaled by the player’s standing with the village: the more the village trusts and respects the player, the quieter the gossip becomes, and the harder it is for word to reach the steward. A low village standing turns every transaction with Wat into a risk. Taking his coin is a test of what the player values more: the safety of the manor’s good graces or the warmth of the village’s approval.

## Merchet

A villein tenant must have the lord’s licence to marry. The licence is obtained through the steward, and it costs coin—a fee paid before any wedding can be arranged. This is merchet, and it is a legal fact in Harrowmere, not a fiction. [OPEN: the exact fee for merchet and its integration into the marriage system (ADR‑031) must be decided.]

---

## V. The Church

## Saint Ada of the Furrow

The chapel in Harrowmere is dedicated to Saint Ada of the Furrow, a local saint unknown to the wider Church. The story the village tells is that she was a ploughman’s daughter who, when the oxen died in a bad year, took the plough herself and cut a furrow so straight that the seed in it grew twice as thick as any in the parish. She is the patron of this exact problem: thin soil, uncertain weather, and the need to get one more season out of a tired field.

Her feast, on the twenty‑first day of seedtime, is the spring festival—Ada’s Feast—and it is the one church attendance the parish actually counts. The festival includes a procession to the field boundary, a blessing of the seed‑corn, and ale after, all of it blending the old agrarian habit with the thin new authority of the chapel.

## The Weakness of the Church

The church in Harrowmere has no ability to punish. It cannot fine, cannot distrain, cannot force anyone to kneel. Its only power is social, and that power is real but slow: the offering box at the chapel takes voluntary donations, and those who give are noticed by the members of the congregation. Those who do not give are also noticed, but nothing happens to them except a subtle cooling of the air.

The manor pays Father Tomas a stipend because a church on the demesne adds prestige to Sir Edric’s estate, but the church receives no other help. It must sustain itself on its own small lands and on the donations of the faithful. The arrangement breeds unease—financial dependence on a prestige payment is not comfortable for a priest who believes in the church’s independence—but it has not yet soured into open rivalry. It is a quiet, constant tension, like a crack in a beam that hasn’t yet moved.

## The Old Beliefs

The great plague that swept through the region a generation ago stripped the church of its influence. When the bodies stopped and the survivors crawled out of their houses, the old beliefs were already returning: charms against the murrain, words spoken at the turn of the season, the habit of asking the land rather than the priest for a good harvest. The church’s return is a live disagreement in Harrowmere. Some villagers attend mass out of genuine piety; many attend because everyone else does, and it would be odd not to; a few stay away entirely, and the village lets them.

This is the world Father Tomas works in. He knows the church is weaker than it appears, and he knows that the offering box and the lord’s stipend are not enough to repair the crumbling plaster and the leaking roof. He wants to rebuild the church—physically and spiritually—because he believes in it, and because he believes that Harrowmere needs it. That conviction, quiet and unshakeable, makes him a more interesting figure than a simple holy fool.

## Father Tomas

Tomas is devout and deeply practical. His forgetfulness—a habit of losing his place in a sentence, mislaying a name, staring into the middle distance—is a genuine product of a mind always half‑in‑prayer, but he has learned to use it. He lets people underestimate him, and then he surprises them with a memory that is precise when it matters. He says that the lord’s assessment is lawful, and he says it publicly. That statement costs him. Some villagers hear it as betrayal; he hears it as the price of telling the truth. Tomas is a priest who will not lie to make you like him, and that is a rare and difficult quality in a man whose church depends on being liked.

The player who donates to the church, who attends Ada’s Feast, and who treats the chapel as a living place will find Tomas becoming a quiet ally. His aid is never material—he has nothing to give—but his word carries weight with the village, and a priest who vouches for a farmer is a priest who changes the social weather.

---

## VI. The Year

## The Shape of a Day

A day in seedtime lasts fourteen real minutes, and each game‑minute is a heart’s‑beat of light and weather. Dawn comes grey and cool, dew heavy on the grass, the chickens beginning their low clucking in the yard. The work hours run from six in the morning to six in the evening, and in those hours the player is a body in the world: walking to the well, bending over a row of onions, swinging a hoe to the rhythm of a tired back. Dusk brings a long, soft half‑light, and night shuts the door on everything but the hearth fire and the small sound of the goat shifting in its shelter.

The weather is a daily roll: in spring, rain comes on three days out of ten. Rain is good news. It wets every tilled cell without the player lifting a watering can, and when it falls the characters say so—a passing remark about a wet spring being a blessing on the thin loam, a conversation that teaches the mechanic without a tutorial screen. A dry spring is hard. A wet spring feels like the village exhaling.

## The Calendar of Seedtime

Time is spoken of not by day numbers but by reference to the great fixed points of the season. “After the court sat,” someone says, or “before market day,” or “the day of Ada’s Feast.” Coin amounts are used freely; day numbers are not. The calendar is a set of anchors:

- **Market days** (the 3rd, 7th, 10th, 14th, 17th, 21st, 24th, and 28th) are the pulse of the economy. On market morning the village is louder, the stall‑clerk sharpens his quill, and Aldric stands with his ledger. The player has the best prices here, the legal channel, and the social weight of being seen at market.
- **Court days** (12th and 26th) feel different. The churchyard fills before the steward arrives; people talk in lower voices; the players of yesterday’s fight or black‑market deal keep to the edges. Fines are given here, and the whole village will remember them.
- **Ada’s Feast** (21st) is the day the parish counts. A procession, a blessing, ale, and the spring festival. Missing it costs standing with the church and with any villager who leans toward social participation.
- **Wat’s visits** (9th and 20th) are unannounced except by rumour. He appears at the edge of the commons, a cart at his side, selling and buying in a voice that never quite rises above a murmur.
- **The scripted raid** (15th) is a day the village remembers in its bones. After it passes, Sir Edric returns, and the manor’s questions begin.

## The Spring Agricultural Round

Seedtime begins with ploughing and sowing the lord’s demesne, which is why the corvée lands in early spring. The steward’s summons drives the player to the lord’s fields when the player’s own fields also want attention—that collision is the design. Mid‑spring sees the stock turned out to the commons, the village’s animals mingling in the rough grazing, and the player settling into the daily rhythm of watering, weeding, and watching the sky. Late spring is the hungry gap: the old stores are running out, the new crops are still thin in the ground, and every coin and every foraged leaf matters. The assessment falls at the worst possible moment, because the gamesystem knows what spring means.

## Festivals and Contests

Each season has one festival: Ada’s Feast in seedtime, Haysel in haymonth, Harvest Home in harvest, and the Long Night in the dead months (the last three exist in data but are unreachable in this slice). Each festival includes contests—some the player enters directly, some where the player chooses a character to cheer on, staking coin or simply earning a reputation bump with the chosen friend. The contests are small narrative games, never button‑mashing, always rooted in the festival’s in‑world logic: a ploughing race at Ada’s Feast, a lifting competition at Haysel, a sheaf‑tying challenge at Harvest Home. [OPEN: the exact contest types and their rule sets must be decided and prototyped—likely small scenes with timed inputs or skill checks from `skills.json`.]

Missing a festival has social consequences, but not for everyone. Villagers who value community participation—the more religious, the more traditional—give the player a small negative opinion tick that lasts until the next festival, accumulating if the player misses that one too. Others do not notice at all. The system is soft pressure, never a punishment, keeping the festivals feel like a choice that matters rather than an obligation.

---

## VII. The Land & Food

## The Soil

The ground under Harrowmere is thin, hungry stuff. The loam is golden and quick to drain—it wants feeding, and when fed it repays the farmer with steady, unspectacular growth. The sandy patches near the stream drain in hours and burn hot in the sun, but they push plants up fast while they have the water. The rocky soil, outcropping in the high corner of the holding, holds moisture forever and yields almost nothing for it. A farmer learns to read the dirt with their hands.

Fertility is a living score, worn down by harvests and restored by fallow days, by the nitrogen‑fixing roots of peas, by the careful spreading of compost made from spoiled crops in the drying shed. Every cell carries a number that the player learns to feel rather than see: the dark, crumb‑rich tilth of a well‑fed square versus the pale, tired dust of a patch that has had too many turnips pulled from it without a rest.

## The Crops of Seedtime

Spring’s crops are the peasant’s palette. **Barley** is the staff of life—for bread, for ale, for animal feed. **Turnips** are the staple of the poor, bulking out the pottage. **Carrots** and **onions** give sweetness and savour, **leeks** a sharp green bite. **Peas** crawl up sticks and leave the soil richer than they found it; a farmer who rotates peas through the plot learns the deep magic of the game. **Oats** are a low‑value bulk cereal, cheap to grow and cheap to sell, the safety net when everything else fails. **Flax** is the cash crop—pale blue flowers that become linen—but flax is not food, and the law of the farm is absolute: you never eat the seed corn, and you never eat the flax. Sell it or weave it, but do not let it touch your lips. The market‑day window gives that rule teeth: the money from a flax harvest is a season’s rent, but it arrives only when the stall is open, and if the hungry gap has you starving the day before market, the temptation is a real threat.

**Cabbage** is a summer crop and cannot be planted in seedtime. The tooltip that says “in season later” is a deliberate teaser, a promise of the seasons to come. The seed‑corn rule—never sell what you must plant—makes the farmer think like a farmer, counting sacks against next year’s furrows.

## The Commons and the Forage

The lord owns the soil of the commons, but the village holds the right of common by custom. In spring, foraged food is a legitimate, respectable source of sustenance—exactly the time when the hungry gap bites. The player gathers **sorrel**, sharp and lemony, for the pot; **ramsons**, the wild garlic that grows in damp places, pungent and unmistakable; **early berries** from the hedgerows, small and tart. **Wood** comes from deadfall and hedge‑cutting—never from standing timber, by custom—and its availability makes building possible. Wood is also sold at the market, setting a ceiling on the cost of any structure.

Sometimes a villager has been through a patch before the player, and the tile is bare. This is a soft reminder that the commons are shared ground, not a private pantry; the world does not wait for the player to pass.

## The Table and the Hearth

The diet of a Harrowmere peasant is built around the pottage pot—a fireproof crock always on the hearth, into which everything goes: barley, turnips, wild greens, the last of the dried peas. Bread is baked a loaf or two at a time. Cheese comes when the goat is in milk; eggs come daily from the hens. Game meat is a purchased good, not something hunted—the forest is the lord’s, and the peasant buys rabbit or venison from the chapman or from a neighbour who had luck trading.

The **hearth** is the heart of the cottage, and the **drying shed** is the visible sign of prosperity—a separate roof, a rack for herbs and meat, a barrel for the first real ale. **Hilda** teaches the arts of preserving and brewing: dry the apples, salt the meat, ferment the barley into something that makes the winter easier. **Cedric** teaches building: how to raise a wall, how to fit a door, how to make the drying shed that changes the farm from a subsistence patch into a working homestead.

## Livestock

Every farm in Harrowmere wants a goat. The player’s goat is bought at the market and named by the player—the game’s small ritual of attachment. It gives milk on a cycle, and the quality of that milk rises with the goat’s happiness, which in turn depends on daily feed (barley) and water and shelter. The **chickens** do the same for eggs, clucking in the yard, needing to be shut in at night. **Bram**—the carter who lives by the road’s sturdy centre—has something to say about the player’s first goat, a remark that makes the step up feel like a step into the community. If bandits drive the goat off, the village, at decent standing, responds with a small material gift: a bundle of fodder, a sack of barley, a few coin pressed into the player’s hand. It is not charity; it is the village closing ranks against the thing that hurt one of its own.

## The Cottage

A cottage is a shell until it has a proper chimney and a floor. The upgrade costs two hundred coin, twenty pieces of flint, and twenty bundles of wood—an aspirational sum that takes a season of careful work to amass. Once built, every villager has a line about it, because a floor means the family is no longer sleeping on dirt, and a chimney means the fire smokes only upward. It is the quietest ambition in the game, and the one that most feels like a life being built.


---

## VIII. Conflict & Investigation

### The Bandit’s Lot
The bandits are not a foreign evil. They are dispossessed—men and women pushed off their own holdings in the chaos of the late plague, the drawn‑out recovery, and the petty noble infighting that still tears at the south‑west hills. Nettleford is not the first place they have come to. It is the place where the road ran out. They do to Nettleford what was done to them: take what food and coin they can, burn what they cannot carry, and move on when the ground is bare. The game does not let the player fight a clean enemy. The player’s boot is the one kicking someone else’s head, and the world text never pretends otherwise.

### The Spring Wave
The raids this spring are heavier than in living memory. Two forces converge. First, the land around Nettleford is still half‑empty; the plague thinned every village, and smallholdings lay fallow, unclaimed. Second, Sir Edric is away on his frequent journeys over the Downs, and his armed men are with him. The manor is undefended, and everyone in the parish knows it. The bandits are not a standing army; they are a loose collection of desperate households, brothers, and broken men who see a farm with no lord’s sword behind it and decide that taking a risk is better than starving. The spring’s lean larder makes the farms the only target that promises immediate food.

### The Raids Themselves
Raids come in three broad shapes, any of which may appear after the scripted day‑15 event:
- **Night raid:** the bandits strike in darkness, damaging crops and buildings but less likely to engage the player directly.
- **Archer raid:** one or two bowmen harass from a distance while a small group tries to breach the fence and steal stored goods.
- **Leader raid:** a larger, more organized assault led by a figure with enough authority to hold a ragged crew together for a single, careful push.

Player actions determine the frequency and intensity: a high deterrence score (built from past victories, fences, a guard dog, or a hired guard) reduces the number of raids and the size of the attacking party. A fatalistic, undefended holding draws trouble.

### The Raid Leader
Within the spring slice, the raid leader has no name, no biography, and no distinct identity. He is an event, not a character. The design deliberately leaves him faceless so that the player can project their own feelings onto the threat. Post‑slice work may give him a grudge, a history, and a face, but for the vertical slice the leader is only the shape of a man at the head of a mob.
`[OPEN: Raid leader identity is deferred to post‑slice content.]`

### The Thief: Marta
The thief who moves inside Nettleford’s own fences is **Marta**. She steals food and seed—never coin, never from the poorest. Her thefts are careful, targeted, and small enough that a distracted villager might miss them. She steals because someone depends on her; the exact identity of that dependent is hinted at but never confirmed within the slice. The player can suspect, but the door is not opened wide enough to walk through.

### The Three Clues
The investigation is built from three information channels, each a different kind of evidence and a different way to learn the truth:

1. **Schedule witness.** Bram, the inflated but not wholly unreliable witness, places someone away from where they should have been at the time of a theft. His report is self‑serving—he wants to be the man who saw—but it is founded in a genuine observation.
2. **Physical trace.** A broken tool, a scrap of fabric, or a disturbed patch of earth left at the theft site ties the crime to a person. Cedric, who has no alibi and thus the most reason to have been watching the fields, furnishes this clue if the player presses him.
3. **Market trace.** An item appears for sale that should not have been sellable: a rare seed, a particular cut of meat, a piece of craftwork that a villager would never part with. The trail leads back to Marta through the manor market rolls.

Hilda’s warm gossip reveals clues more readily than direct interrogation. She is the village’s memory; she knows who is concealing, who is lying, and who is simply frightened. The player who talks to Hilda often will find the investigation threads easier to pull.

### Resolution Paths
A correct accusation brings the matter to the manor court. Marta is fined. The village is relieved the thief is caught, but there is an undercurrent of shame: they knew her, and they did not see. Mechanically, manor standing gains **+2** and village standing gains **+4**, but the text must carry the weight of the cost. The village’s eagerness to applaud a neighbour’s exposure is flagged for revisit.
`[OPEN: X6 – village‑standing reward for informing on a neighbour is under review; the number may be reduced or the framing adjusted in a later pass.]`

A false accusation is itself a court offence: the accuser is fined **15 coin**, and village standing drops **‑8**. The community does not forgive a false charge lightly; the penalty is public and sharp.

If the player marries Marta, the thefts end silently. The player knows; the village does not. The truth remains a private, unspoken burden between the two of them. No reputation tick, no court record—only the weight of what was done and the quiet promise that it will not happen again.

### Aftermath and Design Notes
The investigation system is designed to scale. Future seasons may add more suspects, more layers of clues, and a longer, colder trail. The three‑channel structure (schedule, place, market) stays constant; the specific actors and objects change.

---

## IX. Life Milestones

### Courtship
Courtship in Nettleford is a slow, public thing. The player’s interest in another person becomes known long before any formal proposal is made. The path to marriage is built from four kinds of action:
- **Gifts:** repeated, sincere gifts the candidate likes. Tokens carry weight—a herb, a cooked dish, a craft piece—and the candidate remembers what was given.
- **Favours:** completing the requests the candidate posts is the clearest signal of commitment. A favour done once is a friendly act; a favour done five times is a courtship.
- **Public visibility:** being seen together at market, sitting near one another at mass, standing together at the manor court. The village keeps its own tally of who is stepping out with whom.
- **Spending time:** the player must spend time with the candidate in a way that advances the story and the character’s understanding of each other. This is not a formal “date”; it is an event—walking the field‑bounds together at dusk, sharing a meal at Hilda’s on a festival day, sitting in silence after a hard morning. The world bible does not prescribe each scene; it requires that the relationship feel witnessed, earned, and specific to the candidate.

### Proposal Token
The player proposes not with a purchased ring but with a token of labour: a **braided straw and rush ring**, crafted at the hearth. Its value is the time the player spent making it. The ring is simple and fragile, but in Nettleford that is a virtue: it says, “I will work for you, and with you.”
`[OPEN: Proposal token recipe is a C6 code touch, owed. The recipe must be added to recipes.json when the hearth crafting system is extended.]`

### Merchet
Marriage is a legal act as well as a personal one. The steward demands a **merchet**—a fee paid to the lord for the licence to marry—before the wedding can proceed. The fee is a tax on a new household, and the steward collects it without sentiment.
`[OPEN: Exact merchet fee (in coin) is not yet set. The fee must be entered into tithe.json and the TitheManager logic, requiring an ADR‑031 amendment.]`

### The Ceremony
The wedding is officiated by **Tomas**, the village priest. The banns are read on three successive market days—nothing in Nettleford stays secret—and if no objection is raised, the ceremony proceeds on the next clear morning. The parties meet at the church door, not inside. Tomas asks only that they mean it; there is no incense, no choir, no lord’s blessing, no feast provided by the manor. The celebration afterward is ale at Hilda’s, paid for by the couple or their friends.

### Married Life
After the ceremony, the spouse moves into the player’s cottage. Their rhythm changes in permanent ways:
- They gain a **home-based NPC schedule** that replaces their previous work pattern. They are at the cottage in the morning and evening, with a midday routine that varies by season.
- Each morning, the spouse may greet the player with a short line appropriate to the weather, the season, and recent events.
- Once every few days, they may complete a **farm chore**: water a tilled cell, collect eggs, turn the compost, or weed a fallow strip. The chore is chosen from a small pool and is performed silently.
- The spouse is **giftable outside the normal daily cap**; the player may give one extra gift per day to their spouse without counting it against the gift limit for other villagers.

The other five principal villagers each produce a single reaction line to the marriage. Hilda’s reaction is the one that lands—warm, teasing, or cutting, depending on her individual opinion of the match.

### Marriage Reputation Transfer
In a small community, you marry not just a person but their place in the village’s web of feeling. When the wedding takes place, a **reputation transfer** occurs:
- For every villager who has an opinion of both the player and the spouse, the player’s standing with that villager softens one notch toward the spouse’s standing. If a villager likes the player but hates the spouse, the player drops one reputation level with that villager (never all the way to hatred). If the villager is neutral toward the player but likes the spouse, the player rises one level.
- The inverse holds for the spouse: their standing with every villager softens toward the player’s existing position.

This system ensures that the marriage has lasting social consequences without catastrophically tanking either party’s position overnight. The math is a C6 code touch, owed.

### Spouse Requests
The spouse occasionally has a small queue of rare requests. These always concern tasks the spouse is not proficient at—mending the roof, fetching a rare herb from the commons, sorting out a thorny conversation with the steward. They ask the player to do what they cannot. During pregnancy (future scope, out of the slice), requests are suspended.

### Marriage Candidates
In the spring slice, the marriageable villagers are **Hilda**, **Cedric**, **Marta**, and **Bram**. The priest (Tomas) and the steward (Aldric) are not candidates on fiction grounds. The two remaining Tier 1 principals—the neighbouring tenant and the miller/alewife—have not yet been written.
`[OPEN: Their candidacy is open; it will be settled when their character sheets are written.]`

---

## X. Tone, Register, Diction

**Theme (LOCKED):** A person can be owned by the land and still make a life on it.

**Boundaries (LOCKED):**
- *Too grim.* Hardship belongs in the past tense and in aggregate: the plague is a memory, a missing generation, not a thing you watch. Starvation is a threat the player works against, never a cutscene. Death on screen is combat, not spectacle; the village carries loss in its silences, not in lamentation.
- *Too cozy.* No whimsy. No talking animals, no comedic guard, no exclamation points from an adult character. Warmth is earned: a gifted meal, a spouse’s quiet chore, the relief of rain.

**Humour (LOCKED):** Dry, dialect‑flavoured, and never at the expense of a character’s dignity. Tomas forgets his own text, and the player may smile; Tomas is never a joke, but he lets people think he is. That distinction is the line.

**Voice of the roll (LOCKED):** The manor’s accounting roll is the framing narrative voice — the prose of the game’s menus, the HUD, and every line that is not character speech. It is terse, declarative, and never breaks the fourth wall. No tutorial that says “Use the hoe on the ground.” The roll says: *You may till a plot.*

**Diction law (LOCKED):**
- Use these period‑rooted but legible words: Vigour, Coin, Satchel, Resume Toil, Keep Record, Holding, Roll, Standing, Assessment, Offering.
- **Deny list** (never appear diegetically): quest, XP, level up, craft (noun), stamina, gold, shop, NPC, buff, loot, grind, upgrade, unlock.
- The game’s title retains “Tithe”; the diegetic term is **Assessment**. A framing gloss — “the assessment that folk call the tithe” — is permitted in introductory text, pending owner confirmation of the bridge [OPEN].

**Dialect (LOCKED):** Speech is plain modern English inflected with period nouns. Never period grammar: “Thou goest” is out. The characters sound like people who would say “reckon” and “yon” but not “forsooth.”

**Naming (LOCKED):**
- Given names: single, Anglo‑Saxon or Norman. Surnames by trade or place (e.g., Smith, of Coldwich). No compound fantasy names.
- Place names: compound English forms (Nettleford, Harrowmere, Coldwich). The pattern is noun + geological/civic suffix.
- Items use the plainest true name — “carrot,” “flint,” “watering can” — never an invented classification.

**Numbers rule (LOCKED):** Coin amounts appear; day numbers never. Diegetic text may say “on market day” or “the third day” but never “Day 3.”

**Voices (LOCKED):**
- Aldric never contracts and speaks in obligations: “You will,” “You must,” “It is required.”
- Tomas repeats a phrase from earlier in his own line and blesses reflexively.
- Hilda asks a question in every line.
- Cedric rarely exceeds eight words.
- Marta answers a question with an observation and never says “I.”
- Bram embeds a comparative in every statement.

---

---

## XI. Framing

### The Title and Diegetic Language
The game is titled **Tithe & Turnip**, with a provisional one‑line subtitle beneath: *“A holding in Nettleford.”* The word “tithe” is used only in the title and the external marketing text. Inside the game, every diegetic reference—the steward’s spoken dialogue, the manor roll, the ledger entries, villager conversation—uses the term **assessment**. The term “tithe” never appears in‑game.
`[OPEN: A bridge gloss—a tip on the loading screen, a one‑time tutorial pop‑up, or a parenthetical in the opening roll—is permitted to connect the player’s out‑of‑game understanding to the in‑game word. The exact mechanism is open.]`

### The Manor Roll as Framing Device
The game’s core framing is the manor roll itself—the legal document that records the holding, its obligations, and its history. Every significant event the player encounters is ultimately entered in that ledger. The roll is written in the steward Aldric’s voice: precise, dry, and entirely without warmth. It is not a narrator; it is a record. But the player comes to read it as a mirror.

### The Opening Still
After the title screen, the player sees a single, parchment‑textured still: a page from the roll. The entry reads:

> *Harrowmere Manor Roll, Nettleford.*
> *The holding late of Alys Fletcher is granted to her kin, heriot paid. Rent and assessment are owed by quarter‑day; four days’ work on the demesne is due each year.*
> *The holder shall keep the hedges and the ditch, attend the manor court when summoned, and see that the assessment is met.*
> *Entered this first day of Spring.*

The player advances with a single click or keystroke. The parchment fades, and the first morning of Spring begins, the player standing outside a small cottage on a rectangular patch of land.

Alys Fletcher’s name is a placeholder; it may be changed at any time if another name better serves the story.

### Season‑End Summary: Success
At the close of the spring slice (day 28), the player sees the roll brought up to date. The assessment line is blank—no arrears. The steward’s day‑27 accounting provides the factual summary; Sir Edric’s voice (channeled through Aldric) delivers the numbers without praise. Beneath the formal entry, a different hand writes a single sentence from a villager: Hilda speaks, with her characteristic question‑tic. The document is the score; the person is the point.

### Season‑End Summary: Failure
If the assessment is not met, the roll shows the arrears entered in red ink, and the distraint (the seizure of a possession or a future levy of goods) recorded. Hilda’s sentence appears again, but the words are different and kind. She does not reproach; she acknowledges how hard the spring has been, and her question‑tic wraps the line in something close to sympathy.

### The Last Line Before Restart/Quit
After the season‑end text, a final line stands alone:

> *The page waits for the next season’s entry.*

It is set in the roll’s hand, not a villager’s. It does not promise victory, nor does it threaten further hardship. It promises continuation. The roll is never closed.

### The Player’s Ambition
The title screen is the only place where the player’s ultimate goal is stated plainly: to hold the land free and clear, entered in the roll in the player’s own name, in a village that is safe, quiet, and far from the petty politics of nobles. Sir Edric’s frequent absence is a feature, not a threat—the player wants a lord who is rarely home.

---

## XII. Appendices

### A. Standing Rulings

| Ruling | Detail |
|--------|--------|
| **Cast demography** | Majority of villagers in their 30s and 40s. Elders are few; the plague thinned that generation. |
| **Materials & commons** | Wood sinks: cottage upgrade (20 wood), fence (2 wood per segment). Wood is purchasable at the market. Persistent tree/rock nodes (harvestable with a regrowth cycle) are deferred to ADR‑034. |
| **Crop additions** | **Oats** and **flax** added to the crop roster. Oats double as animal feed; the feed‑path code touch is owed. |
| **Item renames** | Forage items renamed: **Sorrel**, **Ramsons**, **Early Berries** (the three spring forage‑pickables). |
| **Assessment on held acreage** | The assessment scales with the total acreage the player holds. Base rate is 20 coin for the starting holding. `[OPEN: Per‑acre rate not set.]` |
| **Merchet adopted** | The merchet system is accepted into the design; ADR‑031 amendment is owed for the code. |
| **Questionnaire blocks closed** | All outstanding questionnaire items from the original questionnaire schedule were closed as of 2026‑08‑07. |

### B. Open Items / Owed Work

| Tag | Item | Status |
|-----|------|--------|
| X10 | CLAUDE.md amendment for this proposal’s rulings + regeneration of AGENTS.md / DEEPSEEK.md | Owed |
| X12 | Contract‑drift analysis against CLAUDE.md | Owed |
| X13 | Held‑acreage ADR + data version bump for tithe.json | Owed |
| X3, 12.5 | C6 marriage code touches (reputation transfer, spouse requests, merchet flow) | Owed |
| X5 | `harvest_demesne` chore for the labor avenue of the tithe system | Owed |
| X6 | Village‑standing reward on thief accusation revisit | Open |
| – | ADR‑031 amendment to include merchet | Owed |
| – | Exact merchet fee | `[OPEN]` |
| – | Per‑acre assessment rate | `[OPEN]` |
| – | Two sheet‑less principals: character sheets and candidacy | `[OPEN]` |
| – | Young clerk: name, tier, and sheet | `[OPEN]` |
| – | Raid leader identity | Deferred to post‑slice |
| – | Oats‑as‑feed code touch (animal consumption path) | Owed |
| – | Pottage and game‑meat items for C5 (crafting) | Owed |
| – | Festival contest rules (mechanics write‑up) | Owed |
| – | 22.5 reputation ticks (C5/C6 subtleties) | Owed |
| – | Proposal‑token recipe | Owed (C6) |
| – | Spouse requests queue implementation | Owed (C6) |
| – | Tithe/Assessment bridge gloss | `[OPEN]` |

### C. Data Files Touched

| File | Status |
|------|--------|
| `crops.json` | Oats and flax added; already applied. |
| `items.json` | Item renames (Sorrel, Ramsons, Early Berries) applied. |
| `market.json` | Market price entries for new crops and materials; applied. |
| `buildings.json` | Wood sink values for cottage upgrade and fence; applied. |
| `tenure.json` | Rework under ADR-034 (multi-map); per-acre rate belongs in `tithe.json` under X13. Owed. |
| `tithe.json` | Merchet fee and per‑acre assessment rates; owed. |
| `festivals.json` | Festival contest rules entries; owed. |
| `recipes.json` | Proposal‑token and pottage recipes; owed. |
| `dialogue.json` | Post‑marriage villager lines; owed. |

### D. Handoff Notes for Opus 5

- This document (`design/world_biblePROPOSAL.md`, Parts A–C) is a **raw material proposal**, not an approved contract. It has not yet been ratified by the project owner.
- All rulings marked as “standing” are the current working position but may be overturned during owner review.
- Every item tagged `[OPEN]` must be resolved or explicitly deferred before final creation work begins. The standing recommendation is that no code‑side work that depends on an `[OPEN]` value should start until the value is settled.
- The document should be treated as the game’s source of truth for character, plot, and tone during Opus 5’s planning phase, but it cannot override CLAUDE.md or the ADR log until accepted.

---

## Consistency Check (Parts A–C)

The following minor conflicts or ambiguous points were identified during a scan of the full locked context against itself and this Part C draft.

1. **Village‑standing reward for correct thief accusation.**
   The locked context states a gain of +4 village standing, but also flags it as a design question (X6) because “informing on a neighbour” feels at odds with the tone. This is correctly marked `[OPEN]` and noted, so no contradiction within the proposal.

2. **Merchet adoption.**
   The locked context says the merchet is adopted, and an ADR‑031 amendment is owed. Part IX reiterates that and marks the exact fee `[OPEN]`. No conflict.

3. **Marriage candidates and two sheet‑less principals.**
   Part IX correctly notes that the two unnamed principals’ candidacy is `[OPEN]`. The locked context states the same. No conflict.

4. **The raid leader identity.**
   Part VIII defers the leader’s identity to post‑slice; locked context says it is deferred. Consistent.

5. **Framing title and “assessment.”**
   The locked context specifies that the title uses “Tithe” but diegetic text uses “Assessment.” Part XI follows that exactly and opens a bridge gloss as `[OPEN]`. No conflict.

6. **Last line before Restart/Quit.**
   The locked context offers two drafts. Part XI uses the stricter alternative (“The page waits for the next season’s entry.”) as final, which is within the allowed choices. No inconsistency.

**Verdict:** The proposal is internally consistent with the locked context. All genuine unknowns are flagged as open. No amendments to the locked context are required.

