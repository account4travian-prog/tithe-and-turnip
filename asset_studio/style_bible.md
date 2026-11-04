# Style Bible - Tithe & Turnip art direction

Source of truth for the vision critic and the orchestrator. Updated
2026-08-08 after two test rounds: turnip + farmhouse (5 generations),
then an 8-asset vertical-slice proof batch (crops, tools, animals, a
second structure, a character - `vertical_slice_test/`, 12 generations
including retries).

## Round 2 findings (vertical-slice proof batch)

- **The `item` category template was rewritten mid-batch** - see
  `prompt_templates.json`'s own changelog note on that category. Two
  failure modes found live, both fixed by the same change (switching to
  "children's book cartoon illustration" + explicit "thick bold black
  outlines" + explicit "one item, no pattern"):
  - **Tiling**: "carrot" with the original turnip-style prompt produced a
    repeating pattern of many carrots three different ways (plain retry,
    heavy negative-prompt additions, explicit "single/centered" wording)
    before the rewrite fixed it in one shot. This looks like a
    subject-specific bias in the pixel-art LoRA's training data (carrots
    photographed/illustrated in rows far more often than turnips), not a
    generic prompting mistake - **expect other row-crop subjects
    (onion, leek, cabbage, barley, oats, flax) to need the same
    anti-tile phrasing from the start**, not as a fallback.
  - **Photorealism drift**: "chicken" ignored "pixel art style" entirely
    on the first try and rendered as a full photoreal animal. The
    "children's book cartoon" rewrite fixed chicken in one shot.
- **Style-lock is subject-dependent, not template-dependent** - the exact
  same rewritten template that fixed chicken did **not** fix "goat" across
  two different seeds; both attempts stayed fully photorealistic
  (`vertical_slice_test/goat_photoreal_drift.png`, kept as a labeled
  example, not deleted). No amount of retrying with the same prompt shape
  is expected to fix this reliably - some subjects apparently sit on a
  much stronger photoreal prior than others. This is the concrete,
  repeatable case for eventually training a style LoRA (see the
  LoRA-timing conversation this session) rather than chasing every
  subject with prompt engineering indefinitely.
- **The `structure` category template is solid and repeatable** - a
  second structure (a small stone well, `vertical_slice_test/well.png`)
  landed in the same painterly zone as `farmhouse_v2_painterly.png` on
  the first try, no retries needed. This template does not need the
  `item` category's rework.
- **Human characters work well** - `vertical_slice_test/villager.png`
  (still using the `item` category, pre-rewrite prompt shape at
  generation time) landed close to the target chibi/Harvest-Moon look
  immediately. Characters do not appear to share the animal categories'
  photoreal bias.
- Total time for the 8-asset batch: ~12 minutes wall-clock including all
  retries (carrot x3, chicken x1 retry, goat x1 retry that didn't help).

## Round 3: two generation lanes, measured head-to-head (2026-08-08)

A second lane exists now: **ChatGPT (Terra, `gpt-5.6-terra`) via the Codex
CLI**, which has `tools.image_gen__imagegen` *with a
`referenced_image_paths` parameter* - i.e. real style-reference
conditioning, the thing IP-Adapter would have given the local lane and
couldn't (not installed, and installing it risks OOM on the 8GB 1070).
It also has `tools.view_image`, which covers visual QA while the local
Ollama critic is down.

**Decisive measured result - Terra fixed the goat the local lane could
not.** "Goat" was our hardest style-lock failure: fully photorealistic
across two seeds with the corrected `item` template
(`vertical_slice_test/goat_photoreal_drift.png`). Given the three
accepted anchors (villager/chicken/carrot) as `referenced_image_paths`,
Terra produced `vertical_slice_test/goat_terra_FIXED.png` - bold dark
outlines, flat cel fills, cute proportions, on-anchor. Verified
independently by eye, not taken on the model's own say-so.

**Where Terra's images actually land** (it initially reported "no
file-path output"; empirically there is one): `%CODEX_HOME%\
generated_images\<session-id>\<call-id>.png`. Retrievable, so this lane
composes with the existing staging/manifest flow. Output was 1254x1254
(not 1024) - **do not assume a fixed output size from this lane**.
Corner-spread 4, so `strip_background.py` keys it cleanly.

**Cost/latency, measured, for routing decisions:**

| Lane | Per asset | Cost | Deterministic? | Fails on |
|---|---|---|---|---|
| Local SDXL | ~30 s | free (GPU) | yes - fixed seed/steps/ckpt, prompt recoverable from PNG metadata | some subjects resist style-lock entirely (goat) |
| Terra via Codex | ~85 s incl. QA | ChatGPT Plus usage | no - backend/seed not selectable | unproven at volume |

**Routing rule this implies (cheap-first escalation):** generate on the
local lane by default - it is free, fast, deterministic, and already
handles crops, tools, structures, and human characters well. Escalate a
subject to Terra only after the local lane demonstrably fails it, or when
style-reference conditioning to an existing anchor is the actual
requirement. Do not run whole batches through Terra by default; the Plus
plan has usage limits and the local lane costs nothing.

**Consequence for LoRA training:** the dataset must stay single-lane.
Terra-generated assets are excellent *game assets* and excellent *style
anchors to condition on*, but mixing two backends' output into one small
style-LoRA training set gives the LoRA a blurrier target. Train on
local-lane output; use Terra output as reference material and as the
QA/art-direction eye.

## Round 4: the vertical-slice batch, and where the two lanes actually sit (2026-08-08)

Generated the vertical-slice asset list (scoped from the real game data -
crops.json/items.json/buildings.json - not guessed). **25 assets now in
`vertical_slice_test/`, all passing the hard gates** (keyable background,
no tiling). Lane split: 18 local, 7 Terra.

**A three-tier QA ladder now exists, cheapest first:**
- Tier 0 `slice_batch.py` deterministic - free, instant. Corner-spread
  (keyability, a hard ship gate) + border-busyness (tiling smell).
- Tier 1 `screen.py` / Ollama `gemma3:4b` - free, ~30s. Two binary
  questions only: one-subject-or-many, cartoon-or-photoreal. It earned
  its place: correctly caught the flax/wood/fence tiling, the hearth/coop
  busy backgrounds, the photoreal goat, the photoreal-ish watering can,
  and that the spear rendered *two*. It over-flags (false "busy-bg" on
  oat/barley/well) - acceptable for a free gate; over-flagging is the
  safe direction. Do NOT ask it for nuanced style judgement.
  (`qwen3.5:9b` is installed and larger but TIMED OUT on image input -
  do not switch without re-testing.)
- Tier 2 Terra - paid, accurate. Art direction, style-match, escalation.

**Escalation rule, now proven twice:** if the local lane fails a subject
**twice** (different prompt AND different seed), escalate rather than
retry a third time. Local failed flax/wood/hearth/coop/fence twice each
and leek three times; Terra fixed all six in one pass with the anchors
passed via `referenced_image_paths`. Chasing them locally was pure waste.

**Small structures need the `item` template, not `structure`.** The
`structure` template's scene-y language ("cozy Harvest Moon", dimetric
perspective) overwhelms small subjects and produces landscapes. It works
for large subjects (farmhouse, well) and for the chest; hearth/coop/fence
came back as whole fields until they were escalated.

**Process bug found and fixed:** a retry at a different seed CLOBBERED a
passing asset (leek, seed 88). `slice_batch.py` now writes retries to
`<id>_candidate.png` and only promotes them if they actually beat the
previous result on the hard gate.

### HONEST STATE: the library is gate-clean but NOT yet style-uniform

This matters because the whole point of the set is LoRA training, and a
LoRA trained on inconsistent data learns a blurry target. Terra's seven
are visibly the most consistent with each other - bold dark outlines,
warm palette, isolated, uniform weight. Several local assets sit outside
that band and should be redone before the set is called a training
dataset:

| Asset | Problem |
|---|---|
| `watering_can` | soft//photoreal-ish, pale blue, off-palette |
| `well` | still a landscape scene (trees, grass), not an isolated object |
| `spear` | renders two spears |
| `pitchfork` | reads as three loose wooden forks |
| `flint` | flat grey, soft edges, weak outline |
| `oat` vs `barley` | near-identical golden sheaves - a *gameplay* problem, not just art |
| `spade` vs `hoe_spade` | duplicates; the game needs a hoe (perpendicular blade) distinct from a spade |

**Revised guidance on the earlier "keep the LoRA dataset single-lane"
note:** that advice assumed the two lanes were comparable in quality.
They are not - Terra's output is both more on-style and more internally
consistent. The better move is to unify *upward* to Terra's standard for
the assets in the table above, then train on the resulting set, rather
than protecting single-lane purity by keeping weaker images in.

## Round 5: library unified (2026-08-08)

**25 assets, all gate-clean, and now visually consistent.** The 7 assets
flagged in Round 4 were escalated to Terra with the accepted assets as
`referenced_image_paths`; 9 replacements came back (oat/barley split into
two distinct crops, spade/hoe split into two distinct tools) and all 9
verified by eye. Lane split is now terra=16, local=5 - the library
converged on Terra's look, which is the consistency standard.

Two gameplay-legibility problems are fixed, not just art problems:
- **barley vs oat** were near-identical golden sheaves. Now barley is
  dense upright AWNS (bristles), oat is pale drooping PANICLES. A player
  can tell them apart at a glance in an inventory slot.
- **spade vs hoe** were duplicates. Now the spade has an in-line pointed
  blade for digging and the hoe a perpendicular blade for tilling.
  `hoe_spade.png` is deleted; the ids match items.json (`spade`, `hoe_*`).

**Process note - verify the art director's self-grade.** Terra's viewer
tool broke partway through this run (a Windows sandbox error reopening
generated files) and it said so plainly rather than quietly asserting a
visual pass, then self-assessed from its own render output instead. Its
verdicts turned out correct on independent inspection, but the disclosure
is the reason the check was possible. **Always re-verify accept verdicts
independently** - the model reporting its own tooling failure is the
good case, not the bad one.

### Still not in the library (known gaps, not oversights)
- Terrain/grass/soil tiles - authorized by ADR-042 but a different
  workflow (tileable material family, seam checks, no isolated-object
  prompts). Not attempted yet.
- Crop growth stages - the library has ONE mature sprite per crop; the
  game needs 3-4 stages each (see the architecture doc's crop_stage_set).
- Animated actors come from the purchased packs, not generation - see
  `make_actor_manifest.py`. Generation is for static subjects only.

## Target aesthetic

"Somewhere between stylistic and realistic" - real medieval material
detail (thatch, timber framing, fieldstone, whitewash) rendered as a
warm painted illustration, not a photo and not a flat vector cartoon.
Tone: Harvest Moon / Story of Seasons - cozy, inviting, lived-in but
not ruined, humble scale (this is a peasant's holding, not a manor).

Reference set (owner-supplied, 2026-08-08): a mix of hand-painted
chibi/cozy scenes (kittycouch farming illustration, an isometric room
diorama), detailed painterly pixel art (Stardew/Fields-of-Mistria-style
garden and cottage scenes), and photoreal 3D-rendered medieval stock
kits ("Isometric Medieval Village" asset-pack previews). None of these
is the literal target - the target sits between the painterly-pixel
scenes and the stock-kit's material richness, using the chibi/cozy
references for warmth and proportion only.

## What the pipeline actually does per subject (tested, not theorized)

The same checkpoint + LoRA stack (RealVisXL_V4.0 + pixel-art-lora-sdxl
@0.8 + sdxl_lightning_4step_lora @1.0, 4 steps, cfg 1.0) behaves
**very differently by subject complexity**:

- **Simple single-character subjects** (the turnip test,
  `asset_studio_00001_.png`/`00002_.png`) land close to the target on
  the first try: clean thick dark outlines, flat-ish cel-shaded color,
  warm cream/green/brown palette, isolated on flat gray. This is the
  style anchor for **characters, crops, and small props**.
- **Architecture/structures pull hard toward photoreal 3D-render /
  miniature-diorama look** by default (`farmhouse_v1_diorama.png`,
  seed 101, straightforward prompt) - the base checkpoint's
  photorealism prior dominates the LoRA for detailed multi-material
  subjects. Explicitly fighting this in the prompt ("2D digital
  painting", "not 3D render", "not a miniature diorama", "video game
  sprite illustration") pulls it back toward painterly
  (`farmhouse_v2_painterly.png`, seed 202) - **this is the closest
  structure result to the target and the current best anchor for
  buildings**.
- **Pushing explicitly for the turnip's flat/bold-outline look on a
  building did not work** (`farmhouse_v3_landscape.png`, seed 303) -
  instead of a flat cartoon cottage it produced a wider painterly
  landscape scene, drifting away from "isolated single object" too.
  Hard bold outlines appear to be a character-subject trope in this
  checkpoint's training bias, not something that transfers to
  buildings by prompting alone.

**Working conclusion:** characters/crops and structures may end up
using **different points on the same stylize<->realistic spectrum**
(characters closer to bold-outline/flat, structures closer to painterly
detail) while sharing the same palette, lighting, and perspective
conventions. This is a real open question, not settled - the next
useful step is IP-Adapter or img2img conditioning directly against the
turnip image to see if that pulls structures further toward the flat
style than prompting alone could (see the DeepSeek task this finding
was handed off to, `.deepseek/tasks/asset_pipeline_followup_task.md`).

## Palette (hex) - provisional, not yet locked

<!-- Sample from the accepted turnip/farmhouse_v2 once one is chosen as final. -->

| Role | Hex | Use |
|------|-----|-----|
| Outline | `#1a1a1a` (turnip); painterly structures use soft dark edges, not a flat outline | sprite outlines |
| Soil dark | | tilled/fertile soil |
| Soil light | | untilled |
| Crop green A | | leaf base |
| Crop green B | | leaf highlight |
| Wood | warm mid-brown, timber framing | buildings, fences |
| Stone | pale grey-cream | paths, well, chimneys |
| Roof (thatch) | warm gold-tan | buildings |
| Wall (whitewash) | warm off-white | building walls |
| Skin | | NPCs |
| Cloth | | NPC clothing |

## Art direction

- Perspective: dimetric, matching the game's `64x48` screen tile - not
  flat top-down, not full 3D isometric with visible floor-to-ceiling depth.
- Lighting: single soft top-left light source, warm, gentle shadow -
  no hard directional rim light, no dramatic contrast.
- Composition for structure/prop generations: single subject, isolated
  on a plain flat background (gray works well and matches the turnip's
  own background, easy to key out later), standing on a small grounded
  base/patch rather than floating with a drop shadow only.
- No faces on crops/food items (the turnip test's face was liked for
  the *rendering technique*, not as a rule to keep - crops should read
  as plants, not characters).

## Rules (the critic checks these)

- No text artifacts, no watermark.
- Not a photograph, not a 3D render/CGI render/miniature-diorama look
  for the *final* accepted asset - the diorama result is a rejected
  data point, kept on disk as a "what not to do" reference, not deleted.
- Warm earthy palette only - no cool/neutral grays as a dominant color
  (the turnip's flat gray *background* is fine and intentional; gray as
  a *subject* color is not).
- Single isolated subject per generation for asset-ready images (the
  landscape-drift result, seed 303, is exactly the failure mode to
  watch for and reject).

## Prompt template (SDXL) - as tested 2026-08-08

Structures (closest working version, seed 202's prompt):
```
2D digital painting, hand-painted game art illustration, [SUBJECT],
timber-framed / stone / thatched (as applicable), dimetric isometric
perspective, painterly cel-shaded style, bold clean dark outlines
around every shape, flat warm color fills with soft brush shading,
not 3D render, not photorealistic, not a miniature diorama, video
game sprite illustration, cozy Harvest Moon Story of Seasons art
style, warm earthy palette, soft top-left lighting, isolated on plain
flat gray background, no people, no text
-- blurry, low quality, jpeg artifacts, text, watermark, photorealistic,
3d render, cgi, unreal engine, octane render, miniature diorama, tilt
shift, realistic photo
```

Characters/crops/props (the turnip's own successful shape, unchanged):
```
clean pixel art, 2D farming game sprite, [SUBJECT], [ACTION/STAGE],
dimetric view, [PALETTE WORDS], simple shading, crisp 1px outlines,
no text, no background, centered
-- [NEGATIVES]
```

## Review gates

1. Deterministic: palette roughly matches the table above, dimensions
   correct (1024x1024 for a source generation, cropped/resized at
   staging time), no obvious artifacts.
2. Vision critic (when Ollama is running): no artifacts, subject
   matches prompt, not drifted into a landscape/scene, not a 3D-render
   read.
3. Human/orchestrator: final accept/reject. Accepted -> cleanup, crop
   to a usable game asset, integrate through the ADR-041 sprite
   manifest; rejected -> reason recorded here, kept as a labeled
   "rejected" file rather than deleted (the diorama and landscape
   results are exactly this - useful negative examples for future
   prompt-tuning, not failures to hide).
