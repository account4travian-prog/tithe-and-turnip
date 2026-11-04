# Vertical Slice Manual Test Plan - Tithe & Turnip

**Target build:** Godot 4.7.1 stable (debug build), Spring-only vertical slice,
save version 19. Last updated: 2026-08-07. Run in a debug build so the cheat
panel exists; it is compiled out of release exports.

## Ordering rationale

The plan starts with the cheapest, highest-signal checks (boot, movement,
time) because they gate everything else, then moves to the farm loop - the
system every other feature hangs off. Economy, obligations, NPCs, combat, and
the event systems follow in dependency order, each leaning on the cheat panel
so no item takes more than a few minutes. The zone tour and season end come
late because they need the most setup, and the regression sweep is last so it
can double as the post-change safety net.

## How to use this plan

1. **Start fresh**: F5 boots straight into the farm (main.tscn is the project
   main scene; you start at the Fallowfield cottage with a wood hoe, wood
   watering can, 5 turnip seeds, 5 arrows, and 8 coin). For save-dependent
   items, use the cheat panel's Quick Save/Load to reset between attempts.
2. **Cheat habit**: press **Escape** to pause, then **Ctrl+K** to open the
   Cheat Options panel. Use it to set time/weather/money/inventory instead of
   grinding. Close with the Close button (or Escape).
3. **Marking**: put `PASS` / `FAIL` / `SKIP` next to each item id, plus a
   one-line note on FAILs. Bug report convention:
   `[Area] #id - step X: expected Y, got Z (save state, build date)`.
4. **Time budget**: full pass ~90-120 minutes; the regression sweep alone is
   ~15 minutes and should run after every future change.

## 0. Pre-flight (2 min)

**P0.1 Headless suite is green**
1. In a terminal (unsandboxed - this machine's sandbox blocks Godot's
   `user://` setup), run:
   `%USERPROFILE%\Desktop\GoDot\Godot_v4.7.1-stable_win64_console.exe --headless --path . --import`
2. Then:
   `%USERPROFILE%\Desktop\GoDot\Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/run_tests.gd`
- Expect: import clean (no SCRIPT ERROR), then `ALL SUITES PASSED` (~1780
  checks) with exit 0.
- Fail: any FAIL line, or a check-count drop without a FAIL (a suite that
  failed to compile silently contributes 0 checks - watch the total count).

**P0.2 Editor boot**
1. Open the project in Godot 4.7.1, press F5.
- Expect: the farm scene runs with zero errors/warnings in Output.
- Fail: red SCRIPT ERROR lines in Output.

## 1. Shell: boot, title, pause, cheat panel, resize (5 min)

**T1.1 Fresh game spawns at the cottage**
- Expect: player spawns beside the Fallowfield cottage (player_house feature
  at (11,11)); HUD shows Day 1 of Spring, Year 1, 8 coin, full energy/health.

**T1.2 Title screen**
1. Open `scenes/title_screen.tscn` and run the current scene (F6).
- Expect: "Begin a New Life", "Return to the Farm", "Leave the Manor".
- Expect: "Begin a New Life" -> farm scene, fresh state; "Leave the Manor"
  quits; "Return to the Farm" only works when an autosave exists.
- Fail: buttons missing, or "Return to the Farm" errors with no autosave.

**T1.3 Pause menu**
1. Press Escape in-game.
- Expect: game freezes (time stops, player can't move); pause menu opens with
  Resume; Escape again closes it; "Ctrl+K: Cheat Options (debug build)" hint
  is visible.
- Fail: gameplay keeps moving while paused, or Escape doesn't close.

**T1.4 Cheat panel opens**
1. While paused, press Ctrl+K.
- Expect: Cheat Options panel opens with Time / Weather / Economy / Player /
  Inventory / Skills / Reputation / Raids & Combat / Thief Investigation /
  Marriage / Buildings & Crafting / Save sections and a live status line
  (day, season, coin, energy).
- Fail: nothing opens (see DEVELOPMENT_STATE: the pause + Ctrl+K order
  matters - pause first), or the panel shows "not registered" for a section
  whose autoload is actually registered.

**T1.5 Window resize**
1. Resize the window to a wide aspect, then a tall aspect, then back.
- Expect: play area adapts without distortion (canvas_items stretch, expand
  aspect); HUD stays on-screen and legible.
- Fail: stretched sprites, off-screen HUD, or layout breakage.

**T1.6 Gamepad (if a pad is attached)**
1. Move with the left stick.
- Expect: same movement as WASD; no dead-zone jitter; gamepad detected
  (`InputManager.is_using_gamepad()`).

## 2. Movement, facing, projection (5 min)

**T2.1 Eight-way movement**
1. Hold WASD in all four cardinals and four diagonals.
- Expect: smooth 8-way movement; "up" on screen is always visually up (never
  a grid diagonal); facing indicator follows the last direction.
- Fail: diagonal-only movement, screen-up mapped to a diagonal, or drift.

**T2.2 Collision with structures**
1. Walk into the cottage and the well.
- Expect: the player stops at buildings/features instead of clipping through.
- Fail: walking through the cottage or well.

**T2.3 NPCs collide with the world (not the player)**
1. Walk through a villager in Nettleford.
- Expect: the player passes through villagers, but villagers stop at
  buildings/walls instead of clipping through them.
- Fail: villagers clipped into buildings or stuck pushing forever (wander
  abandon should kick in after 0.5 s).

**T2.4 Zone-edge clamp**
1. Walk to a Fallowfield edge that has no neighbor on that side (e.g. the
  west edge if it is a boundary).
- Expect: the player is clamped inside the map - no falling off, no errors.

## 3. Time & HUD (5 min)

**T3.1 Clock advances at the right rate**
1. Watch the HUD clock for one real minute.
- Expect: about 77 game-minutes pass (0.78 s per game-minute); no stutter
  under load.

**T3.2 Set Hour / Jump to Day / Advance Day(s)**
1. Pause, Ctrl+K. Time section: Set Hour to 23, resume, confirm the HUD hour.
2. Pause, Jump to Day = 3 (no cascade), resume, confirm day reads 3 and no
   crops/market processed.
3. Pause, Advance Day(s) = 1 (full cascade), resume.
- Expect: Set Hour lands exactly (minute 0); Jump to Day changes the day
  number only; Advance Day(s) runs the full cascade (weather roll, moisture
  decay, crop growth, sleep restore) - energy is restored ~60% and health +15
  from `sleep_restore`.
- Fail: cascade items (e.g. growth) run on Jump to Day, or Advance doesn't
  restore energy/health.

**T3.3 HUD readout**
- Expect: HUD shows day/season/year, clock, money, energy, health, and tithe
  progress; all update live when cheat buttons change them.

## 4. Farm loop (15 min) - the core

**T4.1 Till, plant, and grow turnips**
1. Fresh game. Equip hoe (1), face grass, E/Space to till.
2. Equip turnip seed (3), face the tilled tile, E to plant.
3. Equip watering can (2), face the planted tile, E to water.
4. Pause, Ctrl+K, Advance Day(s) = 3.
- Expect: tile darkens when tilled; seed count drops by 1; sprout appears;
  water raises moisture; after 3 in-range days the crop is harvestable.
- Fail: nothing happens on E, energy doesn't drop, seed not consumed, or
  crop never matures.

**T4.2 Moisture gates growth**
1. Plant a turnip, do NOT water, advance 3 days.
- Expect: no growth progress while moisture is below the crop's range
  (turnip 15-85); watering then advancing grows it.
- Fail: crop grows without moisture.

**T4.3 Harvest: quality + seed recovery**
1. Plant and water 5+ turnips, advance 3 days, harvest with E (no tool).
- Expect: harvested turnips stack with a quality (common/fine/choice); 1-3
  turnip seeds recovered per harvest; farming skill XP gained.
- Fail: no quality shown, zero seed recovery, or seed recovery > 3.

**T4.4 Soil types behave differently**
1. Find loamy (most of Fallowfield), sandy, and rocky cells (sandy patches
   near the southeast of Fallowfield; rocky in Upland Commons).
2. Plant the same crop on each, same watering, advance to harvest.
- Expect: moisture decay, growth speed, and quality odds differ per soil per
  `soil_types.json` - loamy is best, rocky worst.
- Fail: identical behavior on all three soils.

**T4.5 Fertility: depletion, cover crops, and compost**
1. Harvest 3 rounds of turnips on the same cell (fertility depletion 10).
2. Plant peas on another exhausted cell (depletion -8 = restores).
3. Craft compost from `spoiled_crop` at the Drying Shed (see section 14) and
   apply it.
- Expect: fertility drops after turnip harvests; peas restore it; compost
   restores it; oat/flax need `fertility_min` (20/30) and refuse planting
   below it.
- Fail: fertility never changes, or oat/flax plant on depleted soil.

**T4.6 Cabbage season gate**
1. Give yourself 10 cabbage seeds (Ctrl+K Inventory give row), try to plant.
- Expect: rejected with an "in season later" tooltip (cabbage is summer-only).
- Fail: cabbage plants in Spring.

**T4.7 Well refill and tool tiers**
1. Empty the wood can (capacity 50, 25/use), face the Fallowfield well
   (13,9), E.
2. Buy the iron can + iron hoe at market (day 3+, see section 9) and compare.
- Expect: well refills the can; iron hoe tills a 3x1 area at energy 3 vs wood
  single tile at 4; iron can capacity 90 vs 50.
- Fail: no refill at the well, or iron tools no better than wood.

**T4.8 Spring Crop Pack smoke**
1. Give 3 seeds each of carrot, pea, onion, leek, plant, water, advance to
   their growth days (carrot 2, pea 3, onion 4, leek 4).
- Expect: all four grow and harvest with quality tiers and market prices
  (carrot 8, pea 10, onion 12, leek 15).

## 5. Weather (5 min)

**T5.1 Force weather states**
1. Pause, Ctrl+K, Weather section: force Sunny, then Rain, Overcast, Snow.
- Expect: HUD/terrain reacts to each state (`weather_changed` fires); no
  errors; forced state persists until changed or the day rolls.

**T5.2 Rain auto-waters tilled cells**
1. Till + plant several cells, force Rain, advance 1 day.
- Expect: all tilled/planted cells get watered to the crop's moisture max
  (not above it - a plain 100 would exceed crop maxes).
- Fail: rain doesn't water, or moisture overshoots the crop's max.

**T5.3 Snow blocks tilling (Spring data behavior)**
1. Force Snow, try to till a new tile.
- Expect: tilling is blocked/disabled (snow is winter data active in the
  checker - verify it doesn't hard-crash in Spring; expected result per
  `weather.json` is blocked tilling).

## 6. Foraging & digging (5 min)

**T6.1 Gather wild plants, rocks, lumber**
1. Walk untilled Fallowfield/Upland Commons tiles.
- Expect: wild plants, rocks (flint), and lumber (wood) spawn by soil/season;
  interact collects them into the inventory with energy cost; they don't
  respawn instantly.

**T6.2 Spade dig**
1. Give yourself a spade (Ctrl+K Inventory), equip nothing, face an untilled
   tile, E.
- Expect: dig consumes energy (spade 4), has a daily dig cap, has a genuine
   miss chance, and can find wild carrot/wild turnip (morel is a rare Spring
   find). Season gating + cap + miss chance all apply.
- Fail: digging is free, uncapped, always succeeds, or yields nothing ever.

## 7. Inventory, vitals, food (5 min)

**T7.1 Inventory & stacking**
1. Open inventory (Tab/I). Give items via cheat panel with each quality.
- Expect: same item at different qualities stacks separately; counts are
  accurate; menu opens/closes cleanly (Esc).

**T7.2 Eat restores energy by quality**
1. Give 1 common + 1 choice turnip; record energy; eat both.
- Expect: choice restores 2x common (energy multiplier 1.0 / 1.5 / 2.0 for
  common/fine/choice); cooked meals (section 14) restore more than raw.

**T7.3 Knockout ladder & wound**
1. Set energy to ~1 via tool use (or force low), keep working to 0.
2. Force a combat pass-out (section 13), then check the wound.
- Expect: first exhaustion the same day skips 2 hours and restores 20 energy
  (per ADR-016); the second forces sleep; a combat pass-out costs 20% money,
  floors health at 10, and leaves a wound that taxes tool energy until it
  heals (~1 day); Clear Wound cheat removes it.
- Fail: instant game-over on first exhaustion, or no money/health cost.

## 8. Sleep & saves (5 min)

**T8.1 Sleep -> next day + autosave**
1. Interact with the bed at the cottage (E). Confirm day advances and
   `user://save_autosave.json` is written.

**T8.2 Quick save/load roundtrip**
1. Set a distinctive state (money 1234 via Set Money To, plant a crop, walk
   to a specific tile, ideally in another zone).
2. Ctrl+K -> Save: Quick Save (autosave). Then make changes. Then Quick Load.
- Expect: day, season, money, energy, inventory, zone, and player tile all
   restore exactly; no errors in Output.
- Fail: any field drifts, or loading crashes.

**T8.3 Title-screen "Return to the Farm"**
1. After a quick save, go to the title scene (F6 on title_screen.tscn) and
   pick "Return to the Farm".
- Expect: the autosave loads into the farm scene with the saved zone/state.

## 9. Market & economy (10 min)

**T9.1 Market open day: buy**
1. Jump to Day 3 (market day), walk to Nettleford market_zone (12,8), E.
- Expect: stall menu opens with all seeds, tools, weapons, spade, guard dog,
  hired guard, rabbit; number keys select; buying deducts coin and adds items.

**T9.2 Market open day: sell with toll**
1. Sell a common turnip (base 5) and a choice turnip.
- Expect: payout = floor(base x quality mult x 0.95): common turnip = 4 coin,
  choice = 9 coin (5 x 2.0 x 0.95 = 9). Quality visibly multiplies price.
- Fail: no 5% toll, or quality ignored.

**T9.3 Market closed day**
1. Jump to Day 2 or 4, interact with the market.
- Expect: stall unavailable or says closed; no purchase possible.
- Fail: market open off-schedule.

**T9.4 Supply pressure / price drift**
1. On a market day, sell 30+ of one crop (cheat-give them).
2. Note the price on the same day after the glut, then advance a night and
   reopen.
- Expect: price drops inside the 0.5x-1.5x band as supply pressure rises;
   pressure decays nightly so the price recovers.

**T9.5 Town board orders**
1. On a market day, interact with the town_board (11,8) in Nettleford.
2. Accept an order, fulfill it (give the item via cheat panel if short),
   return to deliver.
- Expect: 1-3 in-season orders post each market day (max 3 active); delivery
   pays the reward and optional standing; unfulfilled orders expire silently
   after their deadline.
- Fail: more than 3 active orders, or expired orders still deliverable.

## 10. Tithe & church (10 min)

**T10.1 Tithe assessment reflects held acreage**
1. Open the tithe panel (interact with the steward/market).
- Expect: assessment = 20 coin + 10 per held (rented) strip; pay by coin and
   watch progress fall to zero.

**T10.2 In-kind payment**
1. With crops on hand, choose the in-kind avenue.
- Expect: crops are valued at market buy price x quality (no toll), and the
  tithe balance drops by that value.

**T10.3 Spatial demesne chores (Manor)**
1. Walk the chain Fallowfield -> North Strip -> Nettleford -> Manor (north
   edges). At the Manor, interact with the stewards_demesne (4,6).
2. Till, water, harvest, and carry a real demesne tile.
- Expect: each chore requires real farm state (a tile to till, water, a crop
  to harvest, produce to carry) and pays its credit (till 3, water 2, harvest
  4, carry 3) with a daily credit cap of 10; energy cost comes from real
  actions.
- Fail: chores grant credit without touching real tiles (the old flat
  button bug), or the daily cap is ignored.

**T10.4 Upkeep and unpaid tithe**
1. Advance 7+ days.
- Expect: 8-coin upkeep is assessed every 7 days; if the tithe is unpaid at
  season end, the summary shows a soft failure (not a hard game-over).

**T10.5 Church donations + mass**
1. Interact with the chapel tithe box (Nettleford chapel (10,10)); donate
   coin/crops.
2. Set Hour 9 on Day 21, attend mass.
- Expect: donations raise church + village standing; mass attendance on day
  21 hour 9 at the chapel raises both; missing mass has no penalty.

## 11. NPCs & dialogue (10 min)

**T11.1 Schedules and zone awareness**
1. Watch a villager across hours (Set Hour 6, 9, 12, 18).
2. Walk between zones and return.
- Expect: villagers move between home/work anchors on the hour per
  `villagers.json`; only the active zone's NPCs exist; the correct NPC set
  re-appears when you return.

**T11.2 Dialogue priority & frequency**
1. Interact with the steward at different standing values (cheat +/- 20 on
   manor).
- Expect: dialogue lines change with conditions (time, season, standing,
   inventory, skills); `once_per_day` lines don't repeat on the same day;
   higher-priority matches win ties randomly.
- Fail: always the same first line, or `once_per_day` lines repeating.

**T11.3 Gifting**
1. Give a villager a liked item, then a disliked item (cheat-give e.g.
   turnip vs flint).
- Expect: opinion moves up for liked, down for disliked; daily gift cap
   blocks further gifts until Reset Daily Gift Cap or the next day.

**T11.4 Requests**
1. Accept a villager request, deliver the item.
- Expect: coin + opinion reward; fulfillment recorded; can't double-claim.

**T11.5 Attack reputation**
1. Attack a villager (J) with a witness nearby.
- Expect: witnessed violence damages manor/village standing (court
  consequence may follow - see section 13).

## 12. Festival (5 min)

**T12.1 Attend Springturn Blessing**
1. Jump to Day 18, Set Hour 10, walk to Nettleford chapel (10,10).
- Expect: festival is active hours 10-14; attending grants village +10 and
  church +8 standing; leaving before 10 or after 14 = no effect, no penalty.

**T12.2 Furrow Race contest**
1. Enter the contest directly.
2. Hit the 3 timed beats (2.0 / 5.0 / 8.0 s targets, 0.55 s half-windows,
   +0.07 s forgiveness per farming level).
- Expect: payout by score (0/2/5/10 coin per the payout table); farming XP
  gained; village standing +2 for entering.

**T12.3 Cheer and bet**
1. Cheer villager_2 or villager_4; place a 1-5 coin bet.
- Expect: cheer raises village standing +1 and entrant opinion +2; a winning
  bet pays the odds multiplier (1.8x / 2.2x).

## 13. Combat & raids (10 min)

**T13.1 Weapon equips, reach, ammo**
1. Equip fists (0), knife, staff, spear, pitchfork, bow (5).
2. Attack a raid enemy or villager with each (J or left mouse).
- Expect: reach/damage per the table - knife 30/5, staff 60/8, spear 90/12,
  pitchfork 100/15, bow 300/10 consuming arrows (20 in the starter kit);
  energy cost per swing (3/4/6/8/5); attacks miss at the edge of reach.

**T13.2 Scripted day-15 raid**
1. Jump to Day 15, Advance 1 day (real cascade), stay on Fallowfield.
- Expect: 2 bandit_melee + 1 bandit_archer spawn at the farm; fighting them
  works; victory adds +15 deterrence.

**T13.3 Dynamic raids & deterrence lever**
1. Set Deterrence -> 0, advance days from 16.
- Expect: dynamic raids occur (12%/day base, 2-4 enemies); archer/leader/
  night variants appear over time.
2. Set Deterrence -> 100, advance 5+ days.
- Expect: no raids (threshold 30).

**T13.4 Raid dismissal on zone change**
1. Trigger a raid on Fallowfield, then immediately walk off the north edge.
- Expect: raid despawns (message-only), no enemies leak into the next zone,
  no errors.

**T13.5 Theft event -> investigation -> trial**
1. Trigger Theft Event (cheat).
2. Reveal All Clues (cheat), accuse a villager through dialogue.
3. Attend the manor court on a court day.
- Expect: clues accumulate; accusation moves to trial; a false accusation has
  a real consequence (standing/opinion hit); schedules provide alibi framing.

## 14. Buildings, crafting, livestock (10 min)

**T14.1 Build a station**
1. Open build menu (B) on Fallowfield, place a Drying Shed and a Hearth.
2. Use Ctrl+K "Force-Complete All Constructions" to skip build time.
- Expect: construction progresses and completes; completed station is
  interactable; only Fallowfield permits building placement.

**T14.2 Cooking and preservation**
1. At the Hearth, cook with farmed ingredients (recipes gated by farming
   skill - use +1000 XP Farming to unlock).
2. At the Drying Shed, dry turnip/barley; craft compost from `spoiled_crop`.
- Expect: cooked meals restore more energy/health than raw crops; dried goods
  and ale are sellable at market (dried_turnip 9, dried_barley 12,
  barley_ale 18); compost restores fertility.
- Fail: recipes blocked despite sufficient skill, or spoiled_crop has no
  compost path.

**T14.3 Livestock**
1. Buy a chicken and a goat (market, or cheat-give), build/own a coop.
2. Feed and water daily; advance days.
- Expect: eggs daily, milk every other day; product quality skews with
  happiness (fed/watered/sheltered = higher); a lost raid can drive off the
  goat.

## 15. Marriage (5 min)

**T15.1 One-shot marry**
1. Ctrl+K -> Marriage, pick a candidate, press "Marry Selected Candidate Now".
- Expect: opinion maxed, ring given, propose -> merchet (25 coin) ->
  ceremony completes; spouse recorded in the marriage state.

**T15.2 Step-by-step gating**
1. Use the granular buttons out of order (Ceremonize before Propose, etc.).
- Expect: each step refuses until its precondition (max opinion + ring for
  propose, merchet paid for ceremony) - the state machine can't be skipped
  into an unreachable state.

**T15.3 Spouse life**
1. Sleep (advance a day).
- Expect: spouse greets on waking, occasionally completes a farm chore, is
  giftable outside the shared daily cap.

## 16. Zone tour (10 min)

**T16.1 Known chain**
1. Walk off Fallowfield's north edge.
- Expect: arrive in North Strip; camera/resolution swap (24x8); renderers
  rebuild without duplicates.
2. Continue north into Nettleford, then north into Manor.
- Expect: Nettleford shows chapel/market/town board and ~6 NPCs; the Manor
  shows the demesne (4,6) and the tithe grid re-points so spatial chores
  work there.

**T16.2 All nine zones reachable**
1. Explore remaining edges to reach Upland Commons, Cottersward, Nettle
   Brook, Edith's Plot, and South Fields.
- Expect: every zone loads its own terrain/features/NPC set with no errors;
  camera dims match each zone; no stray Fallowfield NPCs leak into another
  zone.

**T16.3 Save/load inside a non-fallback zone**
1. In the Manor, Quick Save, change zone, Quick Load.
- Expect: restores to the Manor at the saved tile with zone state intact
  (save v19).

## 17. Season end (5 min)

**T17.1 Unpaid tithe soft failure**
1. Jump to Day 27, keep the tithe unpaid, Advance 1 day.
- Expect: season-end summary shows the unpaid-tithe soft failure (no hard
  game-over), plus stats.

**T17.2 Summary actions**
1. From the summary, try Restart and Quit.
- Expect: Restart begins a fresh game (or returns to a fresh start flow);
  Quit closes the app cleanly.

## 18. Regression sweep (15 min - rerun after every change)

**R1 Movement** - WASD/arrows/diagonals feel identical; no drift.
**R2 Day advance** - Advance Day(s) cascade order: weather first, then farm
  growth; energy/health restored on sleep.
**R3 Crop growth/harvest** - plant -> water -> 3 days -> harvest yields
  quality + seeds (same as T4.1/T4.3).
**R4 Energy** - tool use drains; eat/full-energy restores; exhaustion ladder
  matches section 7.
**R5 Save/load** - quick save/load roundtrip exact (section 8).
**R6 Pause** - Escape freezes everything; menus/PROCESS_MODE_ALWAYS panels
  (inventory/dialogue/pause) still work; Ctrl+K opens the cheat panel.
**R7 Window resize** - wide and tall aspects adapt without distortion.

---

## Appendix A - Cheat panel quick reference (Ctrl+K while paused)

| Section | Buttons |
|---|---|
| Time | Advance Day(s) (1-60, full cascade) / Jump to Day (no cascade) / Set Hour (0-23) |
| Weather | Force Sunny / Rain / Overcast / Snow |
| Economy | +100 Coin / +1000 Coin / Set Money To |
| Player | Full Energy / Full Health / Clear Wound |
| Inventory | Give Starter Kit / item + quality + qty give row |
| Skills | +1000 XP per skill / Max All Skills |
| Reputation | +/-20 per axis / Reset to Neutral / Force Attend Mass / Reset Daily Gift Cap |
| Raids & Combat | Trigger Scripted / Dynamic Raid, Trigger Theft Event, Deterrence 0 or 100 |
| Thief Investigation | Reveal All Clues |
| Marriage | Candidate dropdown / Marry Now / Max Opinion / Ring / Propose / Merchet / Ceremonize / Force Spouse Chore |
| Buildings & Crafting | Force-Complete Constructions / Finish Pending Crafts |
| Save | Quick Save / Quick Load (autosave slot) |

## Appendix B - Key bindings

| Action | Key |
|---|---|
| Move | WASD / arrows / gamepad stick |
| Interact / use tool | E or Space |
| Inventory | Tab or I |
| Pause | Escape |
| Equip | 1 hoe, 2 can, 3 turnip seed, 4 spear, 5 bow, 0 none |
| Attack | J or left mouse |
| Build menu | B |
| Runtime menu select | 0-9; Escape closes |
| Cheat panel | Ctrl+K while paused (debug build) |

## Appendix C - Key data (verified 2026-08-07)

- Market days: 3, 7, 10, 14, 17, 21, 24, 28; toll 5%.
- Crop buy prices: turnip 5, carrot 8, pea 10, onion 12, leek 15, oat 4,
  barley 6, cabbage 7; morel 25, truffle 80; dried_turnip 9, dried_barley 12,
  barley_ale 18, pottage 7, egg 4, milk 7.
- Growth (days / moisture range): carrot 2 (30-70), turnip 3 (15-85), pea 3
  (40-80), onion 4 (20-50), leek 4 (50-90), oat 4 (30-70), barley 5 (35-65),
  flax 5 (40-60). Cabbage 6 (40-60), summer only.
- Fertility: depletion turnip 10, carrot 8, onion 16, leek 12, barley 18,
  flax 18, oat 12; pea -8 (restores). oat/flax need fertility_min 20/30.
- Quality: common x1.0, fine x1.5, choice x2.0 (price and energy restore).
- Tithe: base 20 + 10/strip; labor cap 10/day; chores till 3 / water 2 /
  harvest 4 / carry 3 credit; upkeep 8 coin per 7 days; merchet 25.
- Festival: Springturn Blessing day 18, 10:00-14:00, Nettleford chapel;
  Furrow Race beats 2.0/5.0/8.0 s, half-window 0.55 s, +0.07 s per farming
  level; payout 0/2/5/10.
- Raids: scripted day 15 (2 melee + 1 archer); dynamic from day 16, 12%/day,
  2-4 enemies; deterrence threshold 30, +15/victory, -2/day.
- Player: 8 start coin, 100 max energy, 50 max health, sleep restores 60%
  energy + 15 health, first exhaustion = skip 2 h + 20 energy, second =
  sleep; pass-out loses 20% money, health floor 10; wound ~1 day.
- Zones: fallowfield 24x16 (house 11,11, well 13,9), north_strip 24x8,
  ediths_plot 16x14, nettleford 24x16 (chapel 10,10, market 12,8, board
  11,8, well 20,9), manor 24x16 (demesne 4,6, well 18,12), upland_commons
  32x14, cottersward 24x14, nettle_brook 16x32, south_fields 24x14.

## Appendix D - Current known behaviors (not bugs, per the repo log)

- **F5 boots straight into the farm** (main.tscn is the project main scene);
  the title screen is a standalone scene you run with F6.
- **NPCs block the world, not the player**: villagers collide with
  buildings/walls but the player walks through them by design.
- **Villagers can be hit but don't die**; the reputation consequence fires.
- **First exhaustion is deliberately soft** (ADR-016): 2 hours skipped + 20
  energy; only the second same-day exhaustion forces sleep.
- **Cheat panel is debug-build only**; it must not exist in a release export
  (pause-menu hint also disappears).
- **Headless Godot needs an unsandboxed run on this machine** (the sandbox
  blocks `user://`/AppData creation and this 4.7.1 build segfaults on it).
- **Raids outside Fallowfield are message-only**; leaving mid-raid dismisses
  them.
