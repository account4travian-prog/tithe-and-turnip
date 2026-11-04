# Handoff: research + hands-on test specialized 2D/game-asset generation models

**Paste this whole document into a new ChatGPT conversation to start.** Also
attach (or describe if you can't attach files) two reference images from this
repo if you can — `asset_studio/vertical_slice_test/coop.png` (what a
*successful* generated asset looks like) and
`asset_studio/vertical_slice_test/farmhouse.png` (what our *current best*
output looks like, still slightly imperfect). Seeing both is worth more than
any text description of "the style."

You (ChatGPT) do not have access to this project's prior conversation
history. Everything you need to act usefully is in this document. Where
something depends on files in the actual repo you don't have access to, that
is called out explicitly - ask the owner to paste the file content rather
than guessing at it.

---

## 1. What this project is

**Tithe & Turnip**: a 2D dimetric (isometric-ish, 2:1.33 screen tile) farming
sim built in Godot 4.7.1. The part relevant to you is `asset_studio/` - a
private, git-ignored AI art-generation pipeline (not part of the shipped
game) that produces sprite art for items, buildings, and terrain, run
locally and against a rented RunPod GPU pod.

The pipeline: `asset_studio/generate.py` builds a ComfyUI workflow (JSON
API calls, not the ComfyUI GUI) using a checkpoint + two SDXL LoRAs, driven
by `asset_studio/prompt_templates.json`'s per-category prompt templates.
Generated images get reviewed (deterministic palette checks + a local/pod
vision model critique), then a human approves/rejects, then accepted images
go into `asset_studio/vertical_slice_test/` - the "vetted library" - which
is about to become the training set for a style LoRA (training is running
right now, in parallel with your work, on a separate pod - see section 6,
this is exactly why a *second* pod for your testing is wanted, not a
conflict).

## 2. The actual bottleneck - read this carefully, it's the whole point

The current stack is **SDXL** (checkpoint: a photoreal-leaning fine-tune
called `RealVisXL_V4.0.safetensors`) **+ a generic third-party pixel-art
style LoRA + an SDXL-Lightning speed LoRA**, steered entirely through very
heavily hand-engineered prompt text. This combination has a specific,
confirmed, reproducible failure:

**For "iconic scene" building subjects (a farmhouse, a chapel, a barn, a
gatehouse) the checkpoint refuses to isolate the object on a plain
background.** It insists on drawing a full garden/landscape scene around
the building (grass, trees, fences, dirt paths) - almost certainly because
RealVisXL's training data associates "isometric painterly cottage" imagery
strongly with a specific, extremely common AI-art genre ("isometric
diorama" renders), and that learned association overpowers negative
prompting entirely. This was proven, not assumed - here's the evidence
trail, so you don't have to re-derive it:

- Strengthening the negative prompt (explicitly listing "no grass, no
  garden, no trees, no fence, no scenery...") had **no visible effect** on
  the composition at all - same result before and after.
- Raising the style LoRA's strength from 0.8 to 1.2 had **no visible
  effect** either (same seed produced a near-identical image).
- Naming the *specific* unwanted thing even in the negative
  ("no platform, no pedestal, no base") sometimes made it **worse** - one
  test produced a literal floating gray platform with a drop shadow that
  wasn't there before, as if naming the concept invoked it rather than
  suppressing it.

**What did work**: switching the *composition* stage to **FLUX.1 schnell**
(a different, more modern, better-instruction-following base model) with a
prompt using **positive-only framing** - describing what should be visible
("the house hovers alone in empty space, entirely surrounded by plain flat
gray") rather than listing what shouldn't be there. This isolates reliably.
The FLUX output is then run back through the original SDXL+LoRA pipeline as
an img2img pass (`--init-image`, moderate denoise ~0.45) to apply the
established house style on top of FLUX's correct composition, since FLUX
itself doesn't carry the project's specific art style (the SDXL LoRAs are
architecturally incompatible with FLUX).

This two-stage FLUX-compose-then-SDXL-restyle pipeline **works** and is
already built (`generate.py --compose-with-flux`), but it is a workaround,
not a real fix, and it has real costs:

- Two full generation passes per asset instead of one (time + pod cost).
- The exact wording that makes FLUX behave took real trial and error to
  find (positive-only framing was not obvious in advance - several
  negative-framing attempts made things worse before positive framing was
  tried).
- Camera angle needed a *second*, separate fix on top of the isolation
  fix - symmetric-doorway buildings (chapel, barn, gatehouse) still
  defaulted to a flat, near-frontal "architectural elevation" view even
  after isolation was solved, requiring an explicit, very specific camera
  hint describing exactly which wall faces should be visible and at what
  angle.
- Some residual imperfections remain unsolved: a faint background platform
  outline still shows up on some generations, and the entrance/doorway's
  left-vs-right facing isn't locked to one consistent convention.

**This is being called the single biggest bottleneck in the asset pipeline
right now.** Every new subject risks needing its own round of prompt
archaeology to find wording that doesn't trigger this failure mode. That is
not sustainable for a project that needs many more assets.

## 3. Your actual task

**Find out whether a better-suited model exists that avoids this problem
at the source, instead of prompting around it - and prove it with real
generated test images, not just research notes.**

### 3a. Start with these specific leads (already found, not yet tested)

A prior research pass found these on Civitai but **did not test any of
them** - verifying they're real, checking their licenses, and actually
running them is entirely your job:

- [Flux 2D Game Assets LoRA](https://civitai.com/models/920557/flux-2d-game-assets-lora)
- [Flux Lora - Flat art style game assets](https://civitai.com/models/1039062/flux-lora-flat-art-style-game-assets) (explicitly trained for isolated/plain-background output)
- [Stylized Icon Designer (Game Asset)](https://civitai.com/models/1835691/stylized-icon-designer-game-asset) (Illustrious-based)
- [Vector Icons - Game Assets LoRA](https://civitai.com/models/2251918/vector-icons-game-assets-lora) (ZImageTurbo-based)
- [isometric game assets](https://civitai.com/models/328173/isometric-game-assets) (SD1.x)
- [Stylized Setting (Isometric) SDXL & SD1.5](https://civitai.com/models/118775/stylized-setting-isometric-sdxl-and-sd15)

The two FLUX-native ones are the highest-priority leads, since the working
pipeline already depends on FLUX for composition - a FLUX LoRA that's
*already* trained for isolated game-asset output could plausibly replace
the hand-engineered positive-only prompt entirely, and might carry
useful style information the current pipeline has to bolt on separately
via the SDXL restyle pass.

### 3b. Broaden the search past that starting list

Your knowledge extends past this project's. Look for:

- Other open checkpoints or LoRAs (SDXL, FLUX, Illustrious, Pony-derived,
  or anything newer) specifically fine-tuned for isometric/2D game asset,
  icon, or sprite generation - particularly anything trained explicitly on
  isolated-background data, since that is the exact property being sought.
- Whether any *base* model (not just a LoRA) has a meaningfully different
  and more favorable "default" composition prior for this kind of subject
  than RealVisXL/SDXL does - this session already found FLUX.1 schnell is
  one such model; are there others worth comparing?
- Newer techniques (ControlNet variants, IP-Adapter variants, or anything
  else) specifically aimed at composition/isolation control rather than
  style control - the failure mode here is compositional, not stylistic,
  and it's worth checking whether a control-net-style solution is a better
  fit than a LoRA/prompt-only fix.

### 3c. Actually test candidates - this is the part that matters most

Research and recommendations without generated proof are not useful here -
this project has already been burned once by trusting an unverified
model/tool without hands-on testing (see section 6's guide for other
hard-won lessons from exactly that pattern). For your **2-3 most promising
candidates**:

1. Get them running (see section 6 for pod/ComfyUI setup - you'll likely
   need a rented GPU pod for this, budget is explicitly OK, see below).
2. Generate against these exact test prompts (the ones that exposed the
   original failure) so results are directly comparable to what's already
   been tried:
   - `"small stone chapel with a wooden door and a modest bell tower"`
   - `"large timber barn with double doors and a hay loft"`
   - `"stone manor gatehouse with a heavy wooden door and small windows"`
3. Judge each result against these concrete pass/fail criteria:
   - **Isolated on a plain/flat background** with no invented scenery
     (grass, trees, gardens, paths) - the core failure being solved.
   - **Three-quarter dimetric-ish camera angle** - two wall faces and the
     roof slope(s) visible, not a flat frontal "elevation" view.
   - **Style compatibility** - flat/cel-shaded, bold clean outlines,
     children's-book-illustration-adjacent (compare directly against the
     attached `coop.png` reference) - or if the style doesn't match,
     whether it's close enough that steering it there looks tractable.
   - **No unwanted base/platform/pedestal** under the building.
4. Send back actual images alongside your written assessment - "this LoRA
   isolates reliably but the style needs work" is a useful, honest finding;
   "this LoRA should work well" without a generated example is not.

## 4. What integrating a winner would actually mean (context, not your job yet)

If something tests well, the follow-up (not part of this task, just so you
understand what "useful" cashes out to) would be integrating it as a new
code path in `asset_studio/generate.py` alongside the existing
`--compose-with-flux` flag - likely either replacing the FLUX composition
stage's prompt with the new LoRA, or replacing the whole two-stage pipeline
with a single-stage one if a model handles both isolation AND the target
style natively. Report findings in enough detail that this integration
decision could be made from your writeup alone.

## 5. Boundaries

- **Don't touch the pod currently running LoRA training** (pod ID
  `m203ev61vy65oy` if you somehow have access to project files that name
  it - you shouldn't need to touch it either way). Use a **separate,
  second pod** for all testing in this task - the owner is fine spending a
  couple of hours of pod rental to get this sorted out properly, in
  parallel with the training run. A second RTX 4090 isn't guaranteed to be
  available; any modern 16GB+ VRAM card (3090, 3090 Ti, A5000, 4080, etc.)
  is fine for testing/comparison purposes - this doesn't need to match the
  training pod's exact hardware.
- **You will be guiding the human through actual pod setup, not doing it
  yourself** - the owner has the RunPod account and will click the buttons
  and run the terminal commands you give them, the same way this project's
  existing sessions have worked. Give exact, copy-pasteable commands, one
  at a time, and ask them to report back output rather than assuming
  success.
- This is a research/evaluation task, not a production integration task -
  don't modify any files in the actual game repo or commit anything.
  Deliver findings + test images + a recommendation.

## 6. Setting up a pod for this (condensed - the owner has a much more
detailed reference at `design/runpod_guide.md` in the repo if they can
paste it to you; ask for it if you want the full detail, especially its
"Pod session log" section which documents several non-obvious gotchas)

1. **Rent**: RunPod console -> Pods -> Deploy. GPU: any 16GB+ card (RTX
   4090 preferred if available, not required). Cloud type: Community
   Cloud (cheaper; Secure Cloud works too, just pricier - not worth
   waiting on availability for). Template: the official **ComfyUI**
   template (ships ComfyUI + ComfyUI Manager pre-installed). **Attach a
   Network Volume** (50GB is enough) - critical, see the next point.
2. **The single most important gotcha**: this pod's container disk is
   tiny (~5GB) and separate from the attached Network Volume (which is
   large, e.g. 50GB+). *Anything* downloaded to the default paths - model
   checkpoints, LoRA files, pip's download cache, pip's temp extraction
   directory, Ollama's model directory if used - will silently fail with
   "No space left on device" if it lands on the small container disk
   instead of the volume. **Always explicitly target the persistent
   volume's mount path** (commonly `/workspace` - confirm the exact mount
   point once connected) for any file you download, and for pip
   specifically set `TMPDIR=/workspace/tmp` on top of `--no-cache-dir`,
   since pip's temp directory defaults to the container disk even when
   caching is disabled.
3. **Before deploying**: set a max-runtime/stop-after limit (RunPod's own
   cost guardrail) and check the account's spending limit/auto-recharge
   setting under Billing.
4. **Connecting**: enable the web terminal (off by default) or use Jupyter
   Lab's terminal (more reliable for pasting long commands - the plain web
   terminal has a Ctrl+V quirk where it inserts a literal `^V` instead of
   pasting; Ctrl+Shift+V or Jupyter's file upload both work around it).
5. **ComfyUI's actual HTTP port varies by template version** - check the
   pod's Connect tab for the real port, don't assume the standard 8188.
6. **SSH, if you want direct terminal access from your own tooling rather
   than the web terminal**: the Connect tab's own "paste your key here" UI
   may not actually work reliably (this project hit a case where the
   pasted key silently didn't take, shown by `authorized_keys` containing
   the literal string `null` instead of the key) - the reliable fallback
   is generating a keypair locally, then appending the public key directly
   via the web terminal: `mkdir -p /root/.ssh && chmod 700 /root/.ssh &&
   echo "<pubkey>" >> /root/.ssh/authorized_keys && chmod 600
   /root/.ssh/authorized_keys`.
7. **If downloading models directly on the pod** (usually faster than
   uploading from a home connection - datacenter bandwidth beats home
   upload bandwidth): use `wget`/`curl` straight to the target directory
   under the network volume's mount path.

---

**When you're done**: report back per section 3c's format - which models
you tested, the actual generated images, a pass/fail against the four
criteria for each, and a clear recommendation (adopt one, adopt none and
here's why, or "needs a different approach entirely" with reasoning).
