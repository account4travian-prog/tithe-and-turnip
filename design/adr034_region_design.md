# ADR-034 Region Design - Stage 1 of 2: The Vale of the Nettle

**Status:** Design draft for human review. No code, no data changes. Stage 2
(a later task) turns this into an implementable sprint plan, including grid
sizes, per-zone coordinates, save-version migration, and scene-loading.

## 1. Overview

The region is the **vale of the Nettle**: a rolling lowland a day's walk end
to end, ringed by uplands whose thin soil carries the sheep commons and the
bandit country, with the **Harrow Road** running the vale's length - north
into the uplands toward mountains that are scenery and never reached, south
toward **Coldwich**, the market town that exists in speech only and is never
a map the player walks. This design splits the region into **nine zones** on
separate maps: three civic zones (the player's holding, the village of
Nettleford, the manor of Harrowmere), three wilderness edges (the upland
commons, the lord's wood, the Nettle Brook corridor), and three neighbouring
tenant lands (Edith's plot, the North Strip, and the South Fields, the last
two holding the three rentable parcels inherited from `tenure.json`). The
playable region is the vale's inhabited middle - roughly two to two and a
half hours' walk from the upland commons' playable edge to the Coldwich road.
Beyond both edges the vale continues offstage (the mountain foot to the
north, the long southern reach to the south), which is what makes the whole
vale a day's walk. No zone is assigned tile coordinates; every adjacency,
travel-time, and structure claim below is meant to be checked by a human
before Stage 2 fixes geometry.

**Travel-time ledger (fiction-scale walking minutes; every pair is stated
identically in both zone write-ups):**

| Pair | Minutes |
|---|---|
| Village - Manor | 15-20 |
| Village - North Strip | 10-15 |
| Village - Upland Commons | 55-70 |
| Village - Cottersward | 15-20 (via the ford and the brook path) |
| Village - Nettle Brook (ford) / mill / Marta's cottage | 5 / 10-15 / 20-25 |
| Manor - Upland Commons | 40-50 |
| Cottersward - Upland Commons | 30-40 |
| Cottersward - Nettle Brook | 10-15 |
| North Strip - Fallowfield / Edith's Plot / Nettle Brook | 5-10 / 5-10 / 5-10 |
| Fallowfield - Edith's Plot / South Fields | 5-10 / 5-10 |
| Fallowfield - Village / Manor | 15-25 / 30-45 |
| Edith's Plot - Nettle Brook / South Fields | 5-10 / 5-10 |
| Nettle Brook - South Fields | 10-15 |
| South Fields - playable south edge (Coldwich road) | 30-45 |

Transitivity holds: Village-Upland (55-70) equals Village-Manor (15-20) plus
Manor-Upland (40-50); Fallowfield-Village (15-25) equals North Strip legs;
Fallowfield-Manor (30-45) equals the village path plus Village-Manor;
Village-Cottersward (15-20) equals the ford (5) plus the brook path (10-15);
and the full north-south band (upland edge to Coldwich road) sums to roughly
105-150 minutes, stated above as "two to two and a half hours."

## 2. Structure placement at a glance

Every structure that exists in the game's data (or is named in the world
bible as a fixed place) is placed in exactly one zone. Buildables from
`buildings.json` belong to the player's own plot zone, per the ADR-034 brief.

| Structure / feature | Zone |
|---|---|
| Cottage (`player_house`), its hearth and pottage crock | Fallowfield |
| Buildable stations: hearth, drying shed, coop, storage chest, well_extra, fence, cottage_upgrade | Fallowfield (player constructs them on the holding) |
| Starter well (or pond) for the watering can | Fallowfield (new feature for Stage 2; flagged in Open Questions) |
| Chapel (`chapel`) of Saint Ada + churchyard (manor court sits here) + the plague-era church ruin | Nettleford |
| Market stall (`market_zone`), town board (`town_board`), village well (`well`), alehouse + travellers' outbuilding, smithy/hedger's yard, priest's cottage, steward's house, Bram's yard | Nettleford |
| Steward's demesne (`stewards_demesne`), manor hall + yard/outbuildings, manor well (`well`) | Manor of Harrowmere |
| The mill (Osric's home and workplace), Marta's cottage | Nettle Brook |
| Edith's cottage and stead (home/work anchors from `villagers.json`) | Edith's Plot |
| None | Upland Commons, Cottersward, North Strip, South Fields |

The two `well` features in `farm_map.json` map to the village well and the
manor well; the player's plot gains its own starter well so the watering
loop does not depend on a quarter-hour walk to the village.

## 3. Zones

### 3.1 Fallowfield (the player's holding)

**Sense of place.** A small good holding on the vale floor, an hour's
shoulder-slump of old ploughland that the manor court granted on a heriot
after the last holder died over winter. In seedtime the cottage's smoke lies
low under a grey dawn, dew stands on the thatch and the hedges, and the
fields run in straight, honest rows out from the yard. The road fronts the
west hedge; a lane leaves the east hedge toward Edith's plot. It is a shell
of a farm that wants a chimney and a floor, and it is the whole world the
player starts with.

**Terrain.** Loamy throughout - the vale-floor old ploughland, quick to
drain, needing feeding, repaying steady work (`loamy` stats: 70 starting
fertility, 1.1x growth, modest quality bonuses). One small sandy pocket sits
against the south-east corner by the lane, a quirk the player can learn to
read (drains in hours, grows fast while wet, poorer quality odds). Design
note: all-loamy is the safe default; the sandy corner is a texture choice,
not a balance mandate.

**Buildings/structures.** The cottage (`player_house`) with its hearth and
pottage crock; the buildable stations - hearth, drying shed, coop, storage
chest, extra well, fence sections, and the cottage upgrade (200 coin, 20
flint, 20 wood); and the starter well by the yard for the watering can.

**Who lives/works there.** The player. After marriage (ADR-031), the spouse
moves in and gains a home-based schedule: morning greetings, occasional
completed farm chores, and a gift pool outside the daily cap.

**What is found there.** Untilled margins and hedgerows spawn the loamy
table: Early Berries, Sorrel, deadfall wood, and rare flint; spade digs turn
up wild turnips and, rarely in Spring, morels. The holding is for farming,
not foraging - nothing here is unique to it.

**Purpose in the game loop.** The whole daily loop: sleep (advance the day,
autosave), till/plant/water/harvest, fertility and compost (spoiled crop
dried at the shed), cooking and preserving at hearth and shed, storage,
livestock (goat and chickens in the coop), and raid defense - the scripted
day-15 raid and all dynamic raids target the farm, and fences, the guard
dog, and the hired guard feed deterrence here.

**Relative location.** Borders the North Strip to the north (5-10 min),
Edith's Plot to the east across the lane (5-10 min), and the South Fields to
the south (5-10 min); the Harrow Road runs along the west hedge. Nettleford
is 15-25 min north along the road; the manor 30-45 min; the upland commons
roughly 1.5-2 hours (fiction-scale, via the manor road).

### 3.2 Nettleford (the village)

**Sense of place.** The tight cluster where the road fords the Nettle: a
beaten green, smoke and malt and wet wool, the churchyard wall, and the
market stall's awning. In spring the ford runs high and brown, the first
market days bring carts in from the tenant land, and the village is a knot
of obligations the player is already tied into - the steward's roll, the
alehouse, the well where everyone's business is known. The old plague-era
church is a collapsed ruin at the yard's north end; the rebuilt chapel of
Saint Ada of the Furrow stands at the yard's south end, and the court sits
in the yard between them on days twelve and twenty-six.

**Terrain.** Loamy - the village stands on the vale's best ground. The green
is beaten earth and close-cropped grass; a sandy lip runs along the ford's
flood edge. There is no player farming here.

**Buildings/structures.** The chapel and churchyard (court days 12 and 26,
per the world bible), the old church ruin, the market stall (`market_zone`)
with the town board (`town_board`) beside it, the village well (`well`),
Hilda's alehouse with the separate travellers' outbuilding, Cedric's
smithy/hedger's yard, Father Tomas's priest-cottage, Aldric's steward's
house, Bram's yard at the village's south fringe ("a span outside the
village proper"), and the ford crossing itself.

**Who lives/works there.** Hilda (home and work: the alehouse, 8-18), Cedric
(home and work: the smithy, 8-18; his unpaid night watch on the road is
narrative), Father Tomas (home: the priest-cottage; work: the chapel, 6-21),
Aldric (home: the steward's house; work: the market stall, 7-20; he also
presides at the court and appears on the demesne when corvee is called),
Bram (home and work: his yard at the road's edge, 8-18; often away on the
road), Simkin the young clerk (Tier 2; works the stall), and Marta (works
the green/well where day-labor is hired, 8-18; she lives by the brook - see
3.6). Itinerants: Wat the Chapman stages his cart on the roadside verge at
the village fringe on days 9 and 20 (deliberately out of sight of the
stall); the bailiff appears at the manor but is also seen at the court in
the churchyard; Sir Edric rides through on the road on his returns.

**What is found there.** Loamy forage on the village margins only: hedge
berries, Sorrel, hedge-cuttings and deadfall, rare flint. Density is low -
the green is shared ground and the world does not wait; villagers pick
their own.

**Purpose in the game loop.** The civic core: the market (buy seeds, tools,
weapons, and wood; sell crops under the 5% toll, assize drift, and the
player's own supply pressure; market days 3, 7, 10, 14, 17, 21, 24, 28),
the town board's 1-3 postings, chapel donations (church standing, tithe
box), the manor court (fines for witnessed violence, illegal sales, and
false accusation; the thief trial), Ada's Feast on day 21 (village and
church standing; the Furrow Race with cheer-and-bet on Cedric or Bram),
gifting and requests, gossip and the investigation clue trail (Hilda,
Cedric, Bram, Simkin), the marriage ceremony at the chapel and the
celebration at Hilda's, the merchet fee paid to Aldric, and assessment
settlement in coin or in kind at the stall.

**Relative location.** Borders the manor to the north (15-20 min), the
Nettle Brook corridor to the east at the ford (5 min; the mill 10-15 min
further), and the North Strip to the south (10-15 min). Cottersward is
15-20 min north-east via the ford and the brook path - the riverbank
corridor lies between them, so they share no direct border. The upland
commons are 55-70 min north via the manor road.

### 3.3 The Manor of Harrowmere

**Sense of place.** The lord's home farm, west of the road and north of the
village: a long hall, a walled yard, ordered demesne strips running to the
upland fringe. In seedtime the demesne is ploughed first and corvee lands
here by design, colliding with the player's own planting window. It is
quiet - the lord is away more than he is home - and the village
straightens its back the moment Sir Edric's horse is seen on the road.

**Terrain.** Loamy demesne, the vale's best land kept in heart by boon
labor; a rocky north fringe where the demesne meets the upland (thin,
flinty ground that reads as the transition to the commons).

**Buildings/structures.** The steward's demesne (`stewards_demesne`) - the
boon-work fields where corvee labor is owed; the manor hall with its yard
and outbuildings (stable, granary - canon flavour, not data features); and
the manor well (`well`).

**Who lives/works there.** No Tier 1 principal keeps a daily home anchor
here - the manor's staff are unwritten Tier 2/3. Aldric's daily anchors are
the steward's house and the market stall in the village, but he supervises
the demesne on corvee days and sits with the roll at the hall. The
itinerants arrive here: Sir Edric Vane (the early-season ride of the
demesne, the mid-season reckoning in the wake of the day-15 raid, and the
day-27 accounting when manor standing cashes out), and the bailiff (the
unannounced audit; at good manor standing Aldric's word covers the player,
at bad standing it does not).

**What is found there.** Loamy forage on the demesne's margins (berries,
Sorrel, deadfall) and flint on the rocky north fringe; digs yield wild
turnips and rare morels. Design note: the lord's own worked strips are not
foragable - the tables apply to the margins and the commons-side fringe
only (a Stage 2 density/spawn-gating choice, not a new rule).

**Purpose in the game loop.** Boon-work and corvee (one day's notice; labor
credit at 1.5x toward the assessment), the season-end accounting and roll
review with Sir Edric, the bailiff's audit (the manor-standing axis given a
face), and the demesne as the visible cost of the assessment. Manor
standing's price benefits are spent at the village stall but earned here.

**Relative location.** Borders the upland commons to the north (40-50 min
through the demesne track) and Nettleford to the south (15-20 min). The
Harrow Road runs along its east edge, with Cottersward across the road -
the two are not directly adjacent. To the west the vale's slope runs
offstage.

### 3.4 The Upland Commons

**Sense of place.** The vale's north edge: thin grass, wind, stone, and the
argument over common right made visible in the land. Mid-spring turns the
village stock out here; the hungry gap sends villagers up to pull whatever
the ground offers; the broken ground beyond the sheep walks shelters the
bandits. Note on wording: mechanically this is a flat zone like every
other - "upland" and "north edge" are narrative geography, not elevation,
consistent with ADR-032's no-elevation boundary.

**Terrain.** Rocky dominant - thin soil that holds moisture forever and
yields almost nothing for it, exactly the bible's reading of rocky ground
and the `rocky` table's 30 starting fertility and 0.75x growth. Scattered
loamy hollows hold runoff and better grass, a minority of tiles where the
best forage and the sheep shelters sit.

**Buildings/structures.** None. A drystone sheep fold and the bandits'
shelters are flavour, not structures.

**Who lives/works there.** No residents. Villagers are on the commons at
certain hours - a tile the player was saving is sometimes already picked
(world bible Block 20.5). The bandits shelter in the wild margin here and
approach the vale through Cottersward's cover.

**What is found there.** Rocky forage: Sorrel, flint (the region's best
flint ground), and deadfall wood (estovers - what has fallen, never what
stands); spade digs: flint, wild turnip, and the rare Spring morel; truffle
is defined in data for Autumn and is unreachable this slice. Sheep on the
walks, mid-spring stock turn-out, and the commons-enclosure dispute (Cedric
versus Bram) are the zone's narrative load. Design note: the bible's speech
line about pulling wild carrot "off the uplands" conflicts with the data,
which puts wild carrot digs on sandy soil; this design follows the data -
the upland is flint/turnip/morel country and wild carrots come from the
brook. Flagged in Open Questions.

**Purpose in the game loop.** Foraging and spade-digging for the Foraging
skill and the Labor economy: flint for tools and buildings (hoe tiers,
drying shed, hearth, cottage upgrade), deadfall wood when the market price
stings, Sorrel and wild turnips for the hungry gap, morels as a throttled
spring bonus. Also the bandits' origin - raids are launched from here and
approach through the wood; combat is available if the player hunts them,
while the raids themselves target the farm.

**Relative location.** Borders the manor to the south (40-50 min) and
Cottersward to the east (30-40 min). The road enters through its west edge;
its north edge is the playable boundary, with the mountain foot offstage
beyond. Nettleford is 55-70 min south.

### 3.5 Cottersward (the lord's wood)

**Sense of place.** The lord's wood on the vale's east shoulder: standing
timber, hazel underwood, brambles, and the first green underfoot in
seedtime. The game moves in it - deer, hare, birds - and is never hunted:
the forest is the lord's, and rabbit comes from the market stall, not a
poacher's snare. The wood is where the vale's deadfall is gathered and
where the road's quiet stretches feel watched.

**Terrain.** Loamy under the trees (leaf mould; the richest dig ground in
the region), with rocky outcrops on its north edge where it meets the
upland. Thin on the upland side, deep toward the brook.

**Buildings/structures.** None - deadfall and hedge-cutting only, by custom.

**Who lives/works there.** No residents. Bandits use it as approach cover
between the upland shelters and the farm. No itinerant stages here; Wat
keeps to the road.

**What is found there.** Loamy forage: Early Berries in the hedgerows,
Sorrel, wood - the region's best deadfall ground - and rare flint; rocky
outcrops add flint and Sorrel. Digs: wild turnip (45), wild carrot (15),
morel (7 - the highest Spring morel weight in `forage.json`, making the
wood the region's morel ground), and Autumn truffle (data only this slice).

**Purpose in the game loop.** The wood sink: deadfall for fences, the
drying shed, and the cottage upgrade; berries for energy and berry pie;
morel digging as a throttled high-value spring find (morel stew); and the
bandits' approach route, which makes the wood the place a cautious player
watches after the raids begin. No new mechanics - hunting is explicitly not
added.

**Relative location.** Borders the upland commons to the north (30-40 min)
and the Nettle Brook corridor to the south (10-15 min to the brook path).
The Harrow Road runs along its west edge, with the manor across the road -
not a direct border. Its east edge is the vale's slope, offstage. The
village is 15-20 min south-west via the ford, with the riverbank corridor
between them.

### 3.6 The Nettle Brook (the riverbank corridor)

**Sense of place.** The brook that names the vale: cold and quick after
rain, slow in a dry week, lined with alder and willow. The ford at
Nettleford marks its meeting with the road; below the ford the weir and
millpond hum, and Marta's cottage squats on the common edge of the bank. In
seedtime the water is high, Ramsons thick in the damp, and the whole
corridor smells of wet earth and wild garlic.

**Terrain.** Sandy dominant right along the water (drains fast, warms fast,
pushes plants up while the water lasts - the `sandy` table, and the canon
that sand sits by the brook), with loamy flood-meadow strips between the
water and the fields where the better grass and hedgerows grow.

**Buildings/structures.** The mill - Osric's home and workplace, the
village mill on the Nettle Brook, held by manor licence (his multure toll
is narrative; no grinding mechanic exists or is added) - and Marta's
cottage, a cottar's hovel on common-edge ground. The ford crossing is
shared with the village at the corridor's north end.

**Who lives/works there.** Osric (home: the miller's cottage beside the
mill; work: the mill, 6-19). Marta (home: her cottage "of the Brook", the
place-surname the bible's naming register gives her; work: the village
green/well where day-labor hires out - her current `villagers.json` work
anchor sits on a well tile, which becomes the village well under this
design; flagged). No Tier 2/3 cast yet.

**What is found there.** Sandy forage: Ramsons (wild onion - the
damp-place item's canonical home), Sorrel, willow-and-alder deadfall, and
rare flint; loamy meadow strips add Early Berries. Digs: wild carrot (50 -
the region's best wild-carrot ground), wild turnip, and the rare Spring
morel. Unique flavour: the mill and its pond, the ford, fish in the water -
there is no fishing mechanic, and none is proposed.

**Purpose in the game loop.** Ramsons and wild carrots for the hungry gap,
pottage, and board orders; digging for the Foraging skill; Osric and Marta
as dialogue/gifting/request anchors (and Marta's home as an address in the
investigation); the ford as a watering-can refill point (the existing
"well/pond" fiction; flagged for Stage 2 feature typing); and the corridor
as the short route between the village and the tenant land.

**Relative location.** Borders Cottersward to the north (10-15 min), the
village at the ford to the west (5 min; the mill 10-15 min from the village
center), the North Strip to the west (5-10 min), Edith's Plot to the west
(5-10 min), and the South Fields to the west (10-15 min). Its south end
continues offstage toward the vale's southern reach. Fallowfield is 10-20
min away via Edith's lane.

### 3.7 Edith's Plot

**Sense of place.** The neighbouring tenant's holding, immediately east of
the player's across the lane: a cottage like the player's but older and
better kept, fields measured and counted out loud. Edith holds it alone,
and the village reads that fact a dozen ways. In seedtime her peas are in
sticks early and her rows are the benchmark the player's own rows are
measured against - by her, and by everyone else watching the two plots.

**Terrain.** Loamy dominant - deliberately the same good vale-floor soil as
Fallowfield, so the two holdings compare fairly - with a sandy strip along
her brook edge.

**Buildings/structures.** Her cottage and stead: the home and work anchors
from `villagers.json` made concrete. None of the player's buildables live
here.

**Who lives/works there.** Edith (home: the cottage; work: her fields,
7-19). Her brother Aldric is the steward - the village reads his refusal to
help her as either impartiality or coldness, and both readings stay live.

**What is found there.** None for the player: this is occupied tenant land,
not common ground. Design note: the current engine spawns forage on
untilled tiles, so Stage 2 should either gate player forage off occupied
plots or accept her fallow strips as pickable; a human should confirm which
reads better.

**Purpose in the game loop.** Edith as peer and benchmark: gifting, favors,
dialogue, the courtship arc (she is a marriage candidate), and the
relationship web that ties her holding to her brother's office. No new
mechanics - placement only.

**Relative location.** Borders Fallowfield to the west across the lane
(5-10 min), the North Strip to the north (5-10 min), the Nettle Brook to
the east (5-10 min), and the South Fields to the south (5-10 min). The
village is 20-30 min away via the lane and road; the manor roughly 40-50
min.

### 3.8 The North Strip

**Sense of place.** A band of fallow between the village and the tenant
block: old ridge-and-furrow softening under grass, a half-collapsed field
barn (flavour, not a structure), and the plague's long shadow over land no
one has worked since. It is the first rentable step toward a bigger
holding - and the place where the village's eyes and the manor's roll both
fall on the player's ambition.

**Terrain.** Loamy - good land resting, fertility recovering with every
fallow day, which is exactly what the fertility system models.

**Buildings/structures.** None. Rented land is arable land; the player's
buildings stay on the holding (see Open Questions for the confirm on
whether rented strips may ever hold buildings).

**Who lives/works there.** No one. It is empty, watched, and rentable.

**What is found there.** Loamy forage while it lies fallow: Early Berries,
Sorrel, deadfall, rare flint; digs: wild turnip and the rare Spring morel.
Once rented and tilled, it is farmed, not foraged.

**Purpose in the game loop.** The northern rentable parcel - `tenure.json`'s
`strip_north` re-expressed here. Renting it expands acreage, adds the
10-coin-per-held-strip assessment surcharge, and gives the player a second
field within sight of the village; it is also the walking corridor between
the village and Fallowfield.

**Relative location.** Borders the village to the north (10-15 min), the
Nettle Brook to the east (5-10 min), Fallowfield to the south-west (5-10
min), and Edith's Plot to the south-east (5-10 min). The Harrow Road runs
along its west edge.

### 3.9 The South Fields

**Sense of place.** The good land running out southward: two fallow parcels
split by the lane and a shallow gully, south of which the hedges thin, the
scrub begins, and the road leaves the vale toward Coldwich - a destination
everyone speaks of and no one in the parish has walked to this season. The
plague emptied these strips and the manor has been trying to put them back
to work ever since.

**Terrain.** Loamy dominant on both parcels; a sandy pocket in the
south-eastern parcel near the brook - a quirk the player will feel if they
rent it (fast drains, fast growth, weaker quality odds).

**Buildings/structures.** None.

**Who lives/works there.** No one. The two parcels map to `tenure.json`'s
`strip_southwest` and `strip_southeast`, re-expressed as one zone in Stage
2.

**What is found there.** Loamy forage while fallow: Early Berries, Sorrel,
deadfall, rare flint; the sandy pocket adds Ramsons and wild-carrot digs.
Same rule as the North Strip: rented means farmed.

**Purpose in the game loop.** The second and third rentable parcels
(acreage expansion, assessment scaling, fallow-time forage) and the
region's southern boundary - the road continues south offstage, and
Coldwich remains speech, not a map.

**Relative location.** Borders Fallowfield to the north-west (5-10 min),
Edith's Plot to the north-east (5-10 min), and the Nettle Brook to the east
(10-15 min); the Harrow Road runs along its west edge. Its south edge is
the playable boundary, 30-45 min of walking from the fields to the road's
edge; Coldwich is hours beyond, offstage.

## 4. ASCII world map

Top-down schematic, not to scale, no tile coordinates. The Harrow Road runs
the vale's length; the Nettle Brook rises in the wood, crosses the road at
Nettleford (the ford), and turns south along the east side.

```
                            N
          (mountains - blue, distant, never reached)

  +--------------------------+----------------------------+
  |       UPLAND COMMONS     |  (road enters via the      |
  |   the vale's north edge: |   pass on the west)        |
  |   sheep walks, flint,    |                            |
  |   bandit shelters        |                            |
  +------------+-------------+--------------+-------------+
               | Harrow Road               | wild edge
  +------------+-------------+  +----------+-------------+
  |   MANOR OF HARROWMERE    |  |      COTTERSWARD        |
  |   hall, demesne,         |  |  (the lord's wood)      |
  |   boon-work fields       |  |  deadfall, berries,     |
  |                          |  |  morels, bandit cover   |
  +------------+-------------+  +----------+-------------+
               | road                        | ~ brook emerges
  +------------+----------------------------+--------------+
  |          NETTLEFORD                    X ~ RIVERBANK  |
  |  village at the ford: green, chapel +  | ~ (brook     |
  |  churchyard, market stall + town       | ~ corridor)  |
  |  board, well, alehouse, smithy         | ~ the mill,  |
  |                                        | ~ Marta's    |
  +------------+----------------------------+--------------+
               | road                        | ~ brook south
  +------------+-------------+  +----------+--------------+
  | NORTH STRIP               |  | ~                       |
  | (fallow, rentable)        |  | ~                       |
  +---------------------------+  | ~                       |
  | FALLOWFIELD               |  | ~                       |
  | (the player's plot)       |  | ~                       |
  +------------+--------------+  | ~                       |
  |            | EDITH'S PLOT |  | ~                       |
  |            |              |  | ~                       |
  +------------+--------------+--+------------------------+
  |       SOUTH FIELDS (SW parcel | SE parcel)             |
  +------------+-------------------------------------------+
               | road continues south; the brook continues
               | south offstage through the vale's southern
               | reach
               v
        (COLDWICH ROAD - offstage; Coldwich itself never a map)

  Legend:  | Harrow Road     ~ Nettle Brook
           X the ford, inside the village's east edge
           - the lane between Fallowfield and Edith's Plot
```

Adjacency check (every pair is stated in both zones' write-ups): Upland -
Manor, Upland - Cottersward, Manor - Village, Cottersward - Nettle Brook,
Village - Nettle Brook (ford), Village - North Strip, Nettle Brook - North
Strip, Nettle Brook - Edith's Plot, Nettle Brook - South Fields, North
Strip - Fallowfield, North Strip - Edith's Plot, Fallowfield - Edith's
Plot, Fallowfield - South Fields, Edith's Plot - South Fields. Manor and
Cottersward are separated by the road; the village and Cottersward are
separated by the brook corridor. Both non-adjacencies are deliberate and
stated in the zone write-ups.

## 5. Open questions (things a human should confirm)

1. **Names.** Fallowfield (player's holding), Cottersward (the wood),
   Edith's Plot, the North Strip, and the South Fields are working names.
   The bible locks Nettleford, Harrowmere, Coldwich, the Nettle, and the
   Harrow Road; everything else is provisional. Cottersward in particular
   comes from the superseded 1.3 default in `design/setting_questionnaire.md`
   and should be confirmed or renamed.
2. **The old church ruin.** The bible says the village church collapsed
   with the dead but never says where the ruin stands. This design places
   it at the north end of the village churchyard beside the rebuilt chapel.
   Alternative: leave the ruin unnamed off-map entirely.
3. **Marta's home.** Chosen at the brook ("Marta of the Brook," world bible
   Section IX), but her current `villagers.json` anchors sit on rocky
   placeholder tiles. Confirm the brook reading; it drives which zone her
   home anchor lands in.
4. **Aldric's home.** Chosen in the village (steward's house by the market
   square), matching his current home/work anchors next to the `market_zone`
   feature. The bible is silent; the manor-house reading is defensible if
   preferred.
5. **Wild carrot and the uplands.** The bible's hungry-gap speech says wild
   carrot is pulled "off the uplands"; `forage.json` gives wild carrot to
   sandy digs only, and the upland is rocky. This design follows the data
   (wild carrots come from the brook and the sandy pocket). Either soften
   the speech line or rebalance the dig table - owner's call.
6. **Starter well on the player's plot.** The watering loop needs a source
   on the holding; `farm_map.json` currently has none near the cottage and
   `buildings.json` only defines `well_extra`. This design adds a starter
   well (or pond, matching the "well/pond" wording in `CLAUDE.md`) as a
   Stage 2 data change.
7. **Wat's staging point.** The bible says he appears "at the map edge";
   with no single map edge, this design stages his cart on the roadside
   verge at the village fringe (near enough to reach on market days, out of
   sight of the stall). The South Fields road edge is the alternative.
8. **Festival data mismatch.** `festivals.json` still ships
   `springturn_blessing` on day 18 with placeholder coordinates; the bible
   says Ada's Feast is day 21 at the chapel. This design places all four
   festivals at the village (green and chapel); the data mismatch is
   already flagged in the bible's Appendix C and belongs to Stage 2.
9. **Rented strips and buildings.** The design treats rented strips as
   arable-only (buildings stay on the holding). Confirm that reading of
   tenure before Stage 2 re-expresses parcel boundaries.
10. **Forage on occupied plots.** Stage 2 should decide whether occupied
    tenant land (Edith's Plot) can spawn player-pickable forage, or whether
    forage gates to common/wild/marginal tiles.
11. **The brook's course.** The geometry (rises in the wood, fords at
    Nettleford, runs south along the east side) is invented to satisfy
    "Nettleford" and "sand by the brook"; it is consistent with both but
    not independently canon.

## 6. Consistency-check note (DeepSeek API delegation)

The draft zone list, adjacency graph, and travel-time claims were sent to
the DeepSeek API before finalizing, per the task instructions. The call
itself happened and returned findings. Honest detail on the model: I
requested `deepseek-reasoner` (the task's named model); the endpoint
accepted the request but returned the model id `deepseek-v4-flash` with
25,829 reasoning tokens - `deepseek-v4-pro` was explicitly rejected by the
API as unavailable ("available starting early August 2026"). So: the
consistency check was performed by the DeepSeek API, but it was not the
Pro-tier model, and the response's model id did not match the requested
one. Its findings, all folded in:

1. **Playable-band scale** (BLOCKER): the stated "3-4 hours" did not match
   the sum of the travel times (~1.5-2 hours). Fixed: the overview now
   states the playable band as roughly two to two and a half hours, with
   the offstage northern and southern reaches explaining the day's-walk
   vale.
2. **Village to Cottersward** (SHOULD-FIX): the via-brook route (15-20)
   was faster than the claimed direct route (20-25). Fixed: the village-to-
   wood time is now 15-20 via the ford, and the two zones are explicitly
   non-adjacent with the riverbank corridor between.
3. **"North rim" wording** (NIT): "rim" could read as elevation, which
   ADR-032 forbids. Fixed: zone 3.4 now states that upland/north-edge is
   narrative, not mechanical elevation.
4. **Road course south of the village** (NIT): underspecified. Fixed: the
   road runs the west edge of the tenant block, and Fallowfield-Edith's
   Plot share a direct boundary across a lane; the ASCII map shows this.

A manual pass then re-checked every adjacency claim in both directions and
every travel-time pair against the ledger above; all pairs agree.

