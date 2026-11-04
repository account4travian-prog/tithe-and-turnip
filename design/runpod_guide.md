# RunPod rental guide: what to rent, how to rent it, how to set it up

Written 2026-08-08 for two specific jobs this project needs done during
Claude's ~4-day gap: IP-Adapter-enabled reference-conditioned generation
(reduces GPT/Terra usage), and an SDXL style LoRA training run on the
vetted 25-asset library. Everything below was checked against RunPod's
current docs/blog at write time, not assumed - claims that couldn't be
verified are marked as such.

---

## 0. Quick reference / handoff (read this first, especially if you're not Claude)

This section is maintained as a live cold-start summary for whichever
assistant is driving pod work at a given moment - Claude, DeepSeek, ChatGPT,
or the owner directly. **Section 7 below is the detailed, chronological log
of everything that's happened on the current pod; this section is the
current-state snapshot.** If you're picking this up mid-session, read this
block, skim section 7's bullet headers for anything that looks relevant to
what you're about to do, then act - you don't need the full chronological
read to be useful.

**Whoever is driving: append new findings to section 7 in the same
terse/dated style already used there. Don't rewrite or delete existing
entries - this doc's value is the accumulated gotcha list, and future
sessions (any assistant) rely on nothing having silently vanished.**

### Current pod (as of 2026-08-09)

| Thing | Value |
|---|---|
| Pod ID | `m203ev61vy65oy` (region US-IL-1, Secure Cloud, $0.74/hr) |
| ComfyUI web UI / API | `https://m203ev61vy65oy-3000.proxy.runpod.net` (**port 3000, not ComfyUI's usual 8188** - this template remaps it) |
| Jupyter Lab | `https://m203ev61vy65oy-8888.proxy.runpod.net` |
| SSH | `ssh -i ~/.ssh/id_ed25519_runpod -p 10054 root@203.57.40.123` (local key at `%USERPROFILE%\.ssh\id_ed25519_runpod`; see section 7 for why the Connect-tab key UI didn't work and had to be worked around manually) |
| ComfyUI code | `/ComfyUI` on the pod - **ephemeral**, lost if the pod is ever terminated (not just stopped) |
| Models (persistent) | `/workspace/comfyui/models/<checkpoints\|loras\|clip_vision\|ipadapter\|...>/` - on the 50GB network volume, survives termination |
| Local ComfyUI (for `scp` sources) | `%USERPROFILE%\ComfyUI_windows_portable\ComfyUI\models\` |
| This repo's generate script | `%USERPROFILE%\Documents\2DFarmingSim\asset_studio\generate.py` (run from inside `asset_studio\`) |
| Ollama (critique vision model) | `llava:13b` on the pod, models at `/workspace/ollama_models` - reach it via SSH tunnel `ssh -N -L 11435:localhost:11434 -i ~/.ssh/id_ed25519_runpod -p 10054 root@203.57.40.123` kept running in the background; `config.json`'s `ollama_url` already points at `http://localhost:11435` |

### State as of last update

- IP-Adapter custom node: installed (`/ComfyUI/custom_nodes/ComfyUI_IPAdapter_plus`).
- IP-Adapter models: both in place (CLIP vision encoder + the SDXL vit-h weights) under `/workspace/comfyui/models/`.
- `generate.py`'s pipeline models (`RealVisXL_V4.0.safetensors` checkpoint + 2 LoRAs): all three confirmed present at full size (6.5G checkpoint, 178M + 376M LoRAs) as of 2026-08-09.
- **RESOLVED**: end-to-end smoke test succeeded 2026-08-09 - `generate.py` returned a real 2MB PNG. See section 7's new bullets for the two real root causes that had to be fixed to get there (ComfyUI Manager's restart button doesn't restart the backend process; this template's ComfyUI needs `--extra-model-paths-config` passed explicitly, it does NOT auto-load `extra_model_paths.yaml`).
- **6 new structure images generated and fixed** (farmhouse, drying_shed, market_stall, chapel, manor_gatehouse, barn) via the new `--compose-with-flux` pipeline (section 7 has the full story: SDXL+LoRA alone couldn't isolate these on gray, FLUX composition + SDXL restyle fixed it, then a separate camera-angle fix for symmetric-doorway subjects). Promoted into `vertical_slice_test/` (31 images total now) - entrance-facing side (left vs right) is not locked to one convention, accepted as-is rather than spending another iteration cycle on it.
- **LoRA training IN PROGRESS as of 2026-08-09 08:28** - see the new bullet below for the full setup. Check `/workspace/lora_training.log` on the pod for live status; output lands in `/workspace/lora_output/tithe_turnip_style_v1.safetensors` (final) plus epoch checkpoints every 2 epochs.
- **LoRA training setup** (`sd-scripts`, not the kohya_ss GUI - driven via SSH/CLI, no GUI needed):
  - Cloned `bmaltais/kohya_ss` (with its `sd-scripts` submodule) to `/workspace/kohya_ss` - on the persistent volume, unlike ComfyUI's code.
  - Dedicated venv at `/workspace/kohya_venv` (avoids dependency conflicts with ComfyUI's Python environment). **Same ephemeral-disk trap as ComfyUI/Ollama, twice over here**: (1) `pip`'s download *cache* defaults to `/root/.cache/pip` on the 5GB container disk - use `--no-cache-dir`; (2) even with that, pip's *temporary* download/extraction directory (normally `/tmp`, also on the container disk) is too small for torch+CUDA's multi-GB wheels - fix is `TMPDIR=/workspace/tmp` set on every `pip install` call. Both were hit for real before finding this; don't skip either fix on a fresh pod.
  - Torch installed separately first (`pip install torch==2.6.0 torchvision --index-url https://download.pytorch.org/whl/cu124`, matching the pod's CUDA 12.4), then `pip install -r sd-scripts/requirements.txt` for the rest. Verified `torch.cuda.is_available()` is True and sees the RTX 4090 before proceeding.
  - Dataset: all 31 vetted images `scp`'d to `/workspace/training_data/10_tithestyle/` (the `10_` prefix is `sd-scripts`' repeat-count-in-folder-name convention - each image seen 10x per epoch), one `.txt` caption per image (`tithestyle, <short content description>` - content only, no style words, so the style associates with the `tithestyle` trigger token rather than getting diluted across per-image text).
  - Training command (`sdxl_train_network.py` via `accelerate launch`): `--network_dim=32 --network_alpha=16 --train_batch_size=1 --max_train_epochs=6 --learning_rate=1e-4 --optimizer_type=AdamW8bit --lr_scheduler=cosine_with_restarts --mixed_precision=bf16 --gradient_checkpointing --sdpa --cache_latents` - 1860 total steps (31 images x 10 repeats x 6 epochs). `--sdpa` (PyTorch's native efficient attention) used instead of `--xformers` specifically to avoid installing xformers as a second dependency to version-match against torch - not verified against a different torch/sd-scripts version, flag if a future session's `sd-scripts` checkout doesn't recognize it.
  - Same detached-launch pattern as ComfyUI/Ollama (`nohup setsid ... & disown`, redirect all stdio) - and the same SSH-hang-on-launch quirk showed up again too; check the log via a fresh connection rather than trusting the launch command's own exit.
- The smoke test that now works:
  ```bash
  python generate.py --host https://m203ev61vy65oy-3000.proxy.runpod.net --category terrain_material --subject "test" --seed 7
  ```
  run from `asset_studio\` on the local machine. `generate.py` was patched this session to send a real `User-Agent` header (see section 7) - without that fix, every request 403s against Cloudflare, which fronts every `*.proxy.runpod.net` URL.

### Disaster recovery: two different scenarios, two different runbooks

**Verified 2026-08-09: everything expensive (checkpoints, LoRAs, IP-Adapter
weights, the Ollama vision model - ~18GB total) lives on the persistent
50GB network volume, not the pod's 5GB ephemeral container disk.** Only
small, fast-to-reinstall software lives on the container disk: ComfyUI's
own code + the IP-Adapter custom node (34MB), the Ollama binary (37MB),
and the SSH key registration workaround. So which runbook you need depends
on what actually broke:

**Scenario A - the POD died/was terminated, but the Network Volume still
exists** (the common case - a pod can be stopped/deleted independently of
its attached volume). Fast path, ~10 minutes, no re-downloading:

1. Console -> Pods -> Deploy. Same GPU/template as section 1, but at the
   **Storage** step attach the **existing** network volume instead of
   creating a new one - all the model files are already on it.
2. Note the new pod's ID and the Connect tab's actual port for ComfyUI's
   HTTP service (**do not assume it's still `m203ev61vy65oy`/port `3000`**
   - both are per-deployment, not tied to the volume).
3. Enable the web terminal (off by default) or use Jupyter Lab's terminal.
4. Re-run `asset_studio/runpod/setup_pod.sh` (upload via Jupyter, `bash
   setup_pod.sh`) - reinstalls the IP-Adapter custom node fresh (cheap,
   seconds). Say N to the kohya_ss clone prompt unless training right away.
5. Launch ComfyUI manually with the extra-model-paths flag - **this is the
   one step that's easy to skip and silently break generation**:
   ```bash
   cd /ComfyUI && nohup setsid python main.py --listen --port <actual port> \
       --extra-model-paths-config /workspace/extra_model_paths.yaml \
       > /workspace/comfyui.log 2>&1 < /dev/null &
   disown
   ```
   (`/workspace/extra_model_paths.yaml` already exists on the volume from
   this session - nothing to recreate. If it's somehow missing, section 7
   has the exact YAML content to write fresh.)
6. Set up SSH: generate a local key if needed
   (`ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_runpod -N ""`), paste the
   `.pub` into the Connect tab's SSH key box (may not actually work - see
   section 7), then confirm by checking
   `/root/.ssh/authorized_keys` over the web terminal - if the key isn't
   there, append it directly: `mkdir -p /root/.ssh && chmod 700 /root/.ssh
   && echo "<pubkey>" >> /root/.ssh/authorized_keys && chmod 600
   /root/.ssh/authorized_keys`. Test with `ssh -i ~/.ssh/id_ed25519_runpod
   -p <actual port> root@<actual IP>` (get IP/port from the Connect tab's
   Direct TCP Ports panel - also per-deployment, will differ from
   `203.57.40.123:10054`).
7. Reinstall and relaunch Ollama pointed at the **existing** persistent
   model directory - `ollama pull` is NOT needed, the model blobs are
   already on the volume:
   ```bash
   curl -fsSL https://ollama.com/install.sh | sh
   OLLAMA_MODELS=/workspace/ollama_models nohup setsid ollama serve \
       > /workspace/ollama.log 2>&1 < /dev/null & disown
   ```
   Then confirm `llava:13b` shows up without pulling:
   `curl http://localhost:11434/api/tags` (should list it immediately -
   Ollama just reads whatever's already in `OLLAMA_MODELS`).
8. Re-open the SSH tunnel for Ollama (new pod IP/port from step 6):
   `ssh -N -L 11435:localhost:11434 -i ~/.ssh/id_ed25519_runpod -p <port>
   root@<ip>` kept running in the background.
9. Update local references to the new pod: `--host` in any `generate.py`/
   `batch.py` command needs the new proxy URL; `config.json`'s
   `ollama_url` stays `http://localhost:11435` (tunnel-side, doesn't
   change) as long as step 8's tunnel points at the new pod.

**Scenario B - the Network Volume itself is gone/corrupted** (rare - would
mean losing the actual model files, not just the pod). Full rebuild from
zero: follow sections 1-7 of this guide in order, start to finish, exactly
as this session did the first time. Budget real time for this one - it
means re-downloading the ~6.5GB checkpoint and ~7.5GB Ollama model, not
just relaunching software.

---

## 1. What to rent

**RTX 4090, 24GB VRAM.** Not the 3090 Ti (older, slightly slower, similar
price band), not an 80GB card (that tier is for hosting 70B+ LLMs, which
is not this week's job - see the "is 80GB worth it" note at the end).

- **Cloud type: Community Cloud**, not Secure Cloud, to start. Cheaper,
  and neither of this week's jobs needs Secure Cloud's stronger
  isolation/compliance guarantees. Switch to Secure Cloud only if a
  Community host proves flaky.
- **Template: the official "ComfyUI" template** (not a bare PyTorch
  template). It ships ComfyUI pre-installed with ComfyUI Manager, which
  turns "install IP-Adapter" from a manual git-clone-and-restart into a
  few clicks inside ComfyUI's own UI. If your GPU is Blackwell-class
  (5090/B200 - not the 4090), RunPod has a separate "ComfyUI Blackwell
  Edition" template; the 4090 does not need it.
- **Storage: attach a Network Volume** (RunPod's persistent storage,
  billed separately by the GB/month, survives the pod being stopped or
  deleted). Without one, everything you install and every model you
  download is lost the moment the pod is terminated - you'd pay to
  re-download tens of GB of model weights every single session. 50-100GB
  is enough for SDXL + a handful of LoRA/IP-Adapter models.

## 2. How to rent it

1. Sign up / log in at runpod.io, add billing (a card; RunPod bills
   hourly against your balance).
2. **Set a spending limit** under Billing before doing anything else -
   RunPod's own default account-wide limit is high (reportedly ~$80/hr
   as of this writing, meant as a runaway-protection ceiling, not a
   budget), so set your own real number there.
3. Console -> Pods -> Deploy. Filter by GPU = RTX 4090, Cloud = Community.
   Pick a listing - price and availability vary by host/region; $0.20-0.35/hr
   is the range you found.
4. Attach (or create) a Network Volume in the same region as the pod you
   picked - volumes are region-locked, so the pod and volume must match.
5. Select the ComfyUI template. Before deploying, open its exposed-port
   settings and confirm **8188** (ComfyUI's default port) is listed as an
   exposed HTTP port - the template should already do this, just confirm.
6. **Before you hit Deploy: set a max runtime / stop-after limit.**
   RunPod's own docs describe this as something you set via the Docker
   Command field on pod creation (or the Edit Pod screen after) - the
   platform then auto-stops the pod near the end of that window on its
   own, independent of anything running inside the container. This is
   your primary cost guardrail; treat it as mandatory, not optional.
7. Deploy. Wait for it to reach "Running."

## 3. Connecting to it

- **Web terminal**: Console -> your pod -> Connect -> "Start Web
  Terminal" - a browser terminal, no SSH setup needed. Good enough for
  everything in this guide.
- **ComfyUI's own UI**: Connect -> HTTP Service on port 8188 gives you a
  clickable link in the shape `https://<pod-id>-8188.proxy.runpod.net`
  (verified URL format). Open it - that's the same ComfyUI web UI you
  use locally, just remote.
- **From your local machine's scripts**: that same URL is what you pass
  to this project's tooling - see section 5.

## 4. One-paste setup

Open the web terminal and run:

```bash
curl -sL https://raw.githubusercontent.com/<not-yet-hosted>/setup_pod.sh | bash
```

That URL doesn't exist yet - this repo isn't public, so RunPod's
terminal can't `curl` a script out of it. Practically: open
`asset_studio/runpod/setup_pod.sh` from this repo, copy its contents,
paste into the pod's web terminal, hit enter. It:

- Locates the existing ComfyUI install (the template ships one - the
  script searches common paths rather than assuming one exact layout,
  since that's the one thing not confirmed with certainty here).
- Installs IP-Adapter (`cubiq/ComfyUI_IPAdapter_plus`, the standard
  ComfyUI IP-Adapter implementation) into `custom_nodes/`.
- Prints the exact IP-Adapter model files needed
  (`ip-adapter-plus-sdxl_vit-h.safetensors` + a CLIP vision encoder into
  `models/clip_vision/`) and where to get them - it does NOT auto-download
  these, because the correct HuggingFace URLs can require an accepted
  license/token and change over time; downloading the wrong or a stale
  URL silently is worse than telling you to grab them once, by hand,
  the first time.
- Clones `bmaltais/kohya_ss` (the SDXL LoRA training GUI) if you're doing
  the training job this session, gated behind a prompt so a
  generation-only session doesn't pay the setup time for it.
- Starts `pod_guard.py` (`asset_studio/runpod/pod_guard.py`) in the
  background for cost visibility, in addition to (not instead of) the
  native max-runtime setting from step 2.6.

## 5. Using it from this project's existing tooling

`asset_studio/generate.py` already supports a remote host as of tonight
(`--host` flag or `COMFY_HOST` env var). From your LOCAL machine:

```bash
python generate.py --host https://<pod-id>-8188.proxy.runpod.net \
    --category terrain_material --subject "..." --seed 7
```

Everything else about the call is identical to a local run - the image
downloads to `asset_studio/output/` on your local machine either way (see
tonight's generate.py fix for why that download step exists at all).

## 6. Doing the LoRA training run

Once `kohya_ss` is cloned and its own setup script has run (it has its
own dependency installer - follow its own README inside the pod, this
guide doesn't duplicate a project we don't maintain):

1. Upload the vetted 25-asset library
   (`asset_studio/vertical_slice_test/`) to the pod - easiest path is the
   web terminal's file upload, or `scp` if you set up SSH keys.
2. Point kohya_ss's dataset config at that folder.
3. Train (SDXL LoRA, 24GB is comfortable - no special low-VRAM flags
   needed, unlike the local 8GB card).
4. Download the resulting `.safetensors` LoRA file back to your local
   machine and drop it into your local ComfyUI's `models/loras/`
   directory - generation from then on is free and local again, just
   better-conditioned.
5. **Stop the pod.** Don't let it sit "just in case" - re-renting for the
   next session costs less than a few idle hours here.

## 7. Pod session log (observed, not planned)

Recorded from an actual deployed pod, 2026-08-09 - corrections to the plan
above where reality differed.

- **Pod ID**: `m203ev61vy65oy`, region **US-IL-1**. (Earlier drafts of this
  log had this as `m283ev61vy65oy` - a transcription error from an
  ambiguous 0/8 in a screenshot, not a second pod. Confirmed against the
  Connect tab's own displayed URL after it caused a real debugging
  detour - every request to the wrong ID returned a clean HTTP 404 from
  RunPod's edge proxy rather than a connection error, which looked
  exactly like a ComfyUI/routing problem until this was caught.)
- **Cloud type actually used: Secure Cloud, not Community Cloud.** Section 1
  above recommends Community Cloud to start; this pod was deployed on
  Secure Cloud instead (whether by explicit choice or the listing picked).
  Not wrong, just pricier - see below. Switch to a Community listing on the
  next rental if cost matters more than the isolation guarantee.
- **Price: $0.74/hr total** (compute $0.74/hr + container storage $0.001/hr
  for 5GB). Well above the guide's $0.20-0.35/hr Community Cloud estimate -
  consistent with the Secure Cloud premium above, not a pricing error.
- **Template**: `runpod/stable-diffusion:comfy-ui-6.0.0`, ComfyUI v0.3.10 +
  ComfyUI Manager + Jupyter Lab - matches section 1's "official ComfyUI
  template" pick.
- **Pre-installed checkpoints** (this template ships more than the guide
  assumed): FLUX.1 schnell, SDXL Base 1.0, SDXL Refiner 1.0, SD 1.5, SD 2.1,
  already under `/workspace/comfyui/models/checkpoints/`. SDXL Base does NOT
  need downloading for the LoRA training job - only the IP-Adapter files
  (section 4) still need to be fetched by hand.
- **Ports - correction to section 4's setup script**: ComfyUI's HTTP service
  is on **port 3000** on this template, not 8188 as originally assumed
  (8188 is ComfyUI's own default when run standalone; this template's own
  proxy remaps it). Jupyter Lab is on 8888, SSH on 22. Use the Connect tab's
  "HTTP services" list to confirm the actual port on any given pod rather
  than trusting a hardcoded number - `setup_pod.sh`'s final printed command
  was updated to say so instead of guessing 8188.
- **Web terminal is off by default** - the Connect tab shows an "Enable web
  terminal" toggle in the Stopped state; flip it on before trying to open a
  terminal, matching section 3's claim that a web terminal needs no SSH but
  contradicting the implicit assumption that it's already running.
- **SSH key**: not set up by default; the Connect tab prompts for one
  (`ssh-keygen -t ed25519 ...` then paste the public key) only if SSH access
  is wanted. Not required for the web-terminal path this guide uses.
- **Network volume actually attached**: 50GB, named `senior_gold_dinosaur`,
  mounted at `/workspace` - within section 1's 50-100GB recommendation, on
  the low end. `/workspace/comfyui` (lowercase) is where this template's
  ComfyUI install lives, which `setup_pod.sh`'s search list already covers.
- **Spending limit / auto-recharge**: no explicit "set a spending limit"
  control was found in this flow (contradicting section 2 step 2's
  assumption that one exists prominently under Billing). What was found
  instead: an auto-recharge/auto-pay setting, off by default. With it off,
  a prepaid balance is a hard ceiling - the account cannot spend past what
  was deposited, and (per RunPod's general billing model) a pod is expected
  to stop once balance hits zero. This has NOT been verified against
  current RunPod docs at write time, unlike the rest of this guide - treat
  it as the working assumption, not a confirmed fact, and still set the
  pod's own native max-runtime limit (section 2 step 6) regardless, since
  that guards against burning the whole balance on one long-running pod
  even before hitting the account ceiling.

- **Pasting the setup script into the web terminal**: plain Ctrl+V can show
  a literal `^V` instead of pasting - that's bash's readline reading it as
  "quoted-insert," not a real failure. Ctrl+Shift+V worked. Alternatively,
  Jupyter Lab (port 8888, already running on this template) has a file
  upload button - upload `setup_pod.sh` there directly and run it from a
  Jupyter-launched terminal, sidestepping the browser-paste keybinding
  question entirely. Confirmed working in practice.

- **`extra_model_paths.yaml` on this template** (`/ComfyUI/extra_model_paths.yaml`)
  maps `checkpoints`, `clip`, `clip_vision`, `configs`, `controlnet`,
  `embeddings`, `loras`, `upscale_models`, `vae`, `unet` to
  `/workspace/comfyui/models/<name>/` - all persistent via the network
  volume despite the ComfyUI code itself living at ephemeral `/ComfyUI`.
  **`ipadapter` is NOT in that list** - `cubiq/ComfyUI_IPAdapter_plus`
  expects its models at `<ComfyUI root>/models/ipadapter/`, which resolves
  to the ephemeral `/ComfyUI/models/ipadapter/` by default. Fix applied:
  create `/workspace/comfyui/models/ipadapter/` on the volume and symlink
  `/ComfyUI/models/ipadapter` to it, so the large IP-Adapter weights land
  on persistent storage like everything else.
- **IP-Adapter SDXL file locations** (recalled from the `h94/IP-Adapter`
  HuggingFace repo and cubiq's README, NOT freshly verified against the
  live repo - confirm before trusting if a download 404s):
  - CLIP vision (ViT-H): `https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors`
    -> `/workspace/comfyui/models/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors`
  - IP-Adapter plus SDXL vit-h weights: `https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus_sdxl_vit-h.safetensors`
    -> `/workspace/comfyui/models/ipadapter/ip-adapter-plus_sdxl_vit-h.safetensors`
  (Note the filename is `ip-adapter-plus_sdxl_vit-h.safetensors` - underscore
  before `sdxl`, not the hyphen `setup_pod.sh`'s printed instructions used.)

- **Getting `generate.py`'s pipeline models onto the pod**: `generate.py`
  hardcodes `RealVisXL_V4.0.safetensors` (checkpoint), `pixel-art-lora-sdxl.safetensors`,
  and `sdxl_lightning_4step_lora.safetensors` (both LoRAs) - none of which
  ship with the pod's ComfyUI template, so `/prompt` 400s with
  `value_not_in_list` until they're present under
  `/workspace/comfyui/models/checkpoints/` and `.../loras/`. Getting them
  there needs SSH (see the next bullet), then either `scp` from your local
  ComfyUI install or a direct download on the pod - **prefer downloading
  directly on the pod when the file has a known public source**
  (`RealVisXL_V4.0.safetensors` and `sdxl_lightning_4step_lora.safetensors`
  both do, from CivitAI/HuggingFace) rather than uploading from a home
  connection - datacenter download bandwidth is typically much faster than
  home upload bandwidth. Only `scp` a file you have no public source URL
  for (e.g. a custom-trained or renamed LoRA like `pixel-art-lora-sdxl.safetensors`
  in this session, whose original source wasn't known at transfer time).
- **SSH key setup on this template did not work as documented.** Pasting a
  public key into the Connect tab's "SSH public key" box and clicking Save
  appeared to succeed in the UI, but `cat /root/.ssh/authorized_keys`
  on the pod showed the literal string `null`, not the pasted key -
  auth then failed with `Permission denied (publickey,password)`. Root
  cause not confirmed (possibly an account-level SSH key setting this
  per-pod box doesn't actually feed, possibly a UI bug) - not investigated
  further because there's a reliable workaround: since the web
  terminal/Jupyter path already gives root shell access, just append the
  key directly - `mkdir -p /root/.ssh && chmod 700 /root/.ssh && echo
  "<pubkey>" >> /root/.ssh/authorized_keys && chmod 600
  /root/.ssh/authorized_keys` - then SSH connects normally. Confirmed
  working.

- **ComfyUI Manager's in-UI "Restart" button does not restart the backend
  process** on this template - confirmed by checking the PID before/after
  clicking it (unchanged) and the fact that newly-added models still
  didn't show up. If new models/nodes need picking up, restart via SSH
  instead: `pkill -f 'main.py --listen --port 3000'`, then relaunch (see
  next bullet for the launch command that actually works). A plain `kill`
  is safe here - nothing supervises this process (no `supervisorctl` on
  this template), so it will NOT auto-restart; you must relaunch it
  yourself in the same command.
- **The real root cause of every `value_not_in_list` error this session**
  (not a restart problem at all, in the end): this ComfyUI build does
  **NOT auto-load `extra_model_paths.yaml`** from its own root directory
  on startup, despite that being the file's usual convention and despite
  the file existing with correct content (checked and confirmed twice).
  It needs `--extra-model-paths-config PATH` passed explicitly on the
  command line - confirmed via `python main.py --help`. Once passed, the
  log shows one `Adding extra search path <name> <path>` line per
  category and the models actually show up. The working launch command:
  ```bash
  cd /ComfyUI && nohup setsid python main.py --listen --port 3000 \
      --extra-model-paths-config /workspace/extra_model_paths.yaml \
      > /workspace/comfyui.log 2>&1 < /dev/null &
  disown
  ```
  Note the config path points at **`/workspace/extra_model_paths.yaml`**
  (the persistent volume), not `/ComfyUI/extra_model_paths.yaml` (the
  original ephemeral copy) - the original file at the ephemeral path
  inexplicably disappeared between an earlier successful `cat` of it and
  a later restart attempt (ComfyUI-Manager's startup "security scan" is
  the leading suspect, not confirmed). Recreated on the volume instead so
  this can't recur; that copy also adds the `ipadapter:` mapping (see the
  bullet above on that gap). If renting a fresh pod, create this file
  under `/workspace/` from the start rather than relying on whatever the
  template ships at `/ComfyUI/extra_model_paths.yaml`:
  ```yaml
  runpod_comfyui:
    base_path: /workspace/comfyui
    checkpoints: models/checkpoints/
    clip: models/clip/
    clip_vision: models/clip_vision/
    configs: models/configs/
    controlnet: models/controlnet/
    embeddings: models/embeddings/
    loras: models/loras/
    upscale_models: models/upscale_models/
    vae: models/vae/
    unet: models/unet/
    ipadapter: models/ipadapter/
  ```
- **Backgrounding a process over SSH on this pod is flaky**: `nohup
  setsid ... & disown` with all stdio redirected away from the terminal
  is the textbook-correct way to fully detach a process, and it did work
  every time the underlying command actually ran - but the SSH *client
  command itself* would intermittently hang past expected completion (and
  separately, some connection attempts failed outright with `Connection
  timed out` or a bare exit 255 with no message) for reasons not fully
  root-caused - possibly RunPod's proxy layer on the direct-TCP SSH port,
  possibly host-level flakiness. Workaround: don't trust a hung/failed SSH
  command as evidence the remote action didn't happen - reconnect fresh
  and check actual state (`ps aux`, `ss -tlnp`) before retrying the same
  action, since a retry-without-checking risks issuing it twice.

- **Moved local Ollama critique to the pod too (2026-08-09)**, freeing the
  local GTX 1070 entirely - `generate.py`/`batch.py --host` already ran
  generation there; `critique.py` now gets a `--host` flag (same pattern)
  and `config.json`'s `ollama_url`/`critic_model` defaults were repointed
  at the pod, upgraded from the local `gemma3:4b` to `llava:13b` (no VRAM
  constraint here to justify staying small - verified live, `llava:13b`
  caught a real detail `gemma3:4b` missed on the same image).
  - Ollama installed via its official install script over SSH. **Same
    ephemeral-disk trap as ComfyUI's `extra_model_paths.yaml`**: its
    default model path (`/root/.ollama/models`) is on the 5GB *container*
    disk, not the 50GB *network volume* - a `pull` filled the container
    disk and crashed the server before this was caught. Fixed by starting
    Ollama with `OLLAMA_MODELS=/workspace/ollama_models` so models land on
    the persistent volume like everything else.
  - This container also has no systemd (same as ComfyUI) - Ollama's
    self-installed systemd service never starts on its own; launch
    manually: `OLLAMA_MODELS=/workspace/ollama_models nohup setsid ollama
    serve > /workspace/ollama.log 2>&1 < /dev/null & disown`.
  - Ollama's port (11434) is not exposed as an HTTP service on this pod
    (only 3000/8888/22 are), so it's not reachable via a `*.proxy.runpod.net`
    URL the way ComfyUI is. Reached instead via an SSH local port-forward:
    `ssh -N -L 11435:localhost:11434 -i ~/.ssh/id_ed25519_runpod -p 10054
    root@203.57.40.123` (kept running in the background; local port 11435
    chosen to not collide with a local Ollama instance on 11434 if one is
    ever run again). **This tunnel has to stay alive for `critique.py` to
    reach the pod** - if it drops (this pod's SSH has shown real
    intermittent flakiness all session, cause not confirmed), reconnect it
    before critique calls start failing, don't assume a failure is
    Ollama's fault first.
  - `df -h` on `/workspace` reports the size of the *entire shared network
    storage cluster* behind it (hundreds of TB), not this pod's actual 50GB
    volume quota - don't read that number as available space. Check real
    usage with `du -sh /workspace` instead.

- **Camera angle/framing needed its own explicit fix, separate from
  isolation** (2026-08-09): even after `--compose-with-flux` solved
  background isolation, symmetric-doorway subjects (chapel, barn, manor
  gatehouse) still defaulted to a flat, near-frontal "architectural
  elevation" view - one wall face only, not the vetted library's
  three-quarter angle (`coop.png`: two full wall faces + both roof slopes).
  Fixed with a new per-category `flux_camera_hint` field in
  `prompt_templates.json` (structure's describes the exact target framing
  in concrete terms - "two full wall faces... camera rotated diagonally...
  not a flat symmetric front elevation"), appended to the FLUX stage-1
  prompt only. `generate_flux_composition()` takes an optional
  `camera_hint` param; `--compose-with-flux` in `main()` passes the active
  category's hint automatically. Confirmed fixed on all three affected
  subjects on the first retry.
  **Not yet pinned down**: which wall (left- or right-facing) carries the
  entrance is not fixed to one side - `coop.png`/`chapel`/`manor_gatehouse`
  all show it on the lower-left wall, `farmhouse.png` mirrored to
  lower-right on a regenerate. If the game needs a single consistent
  convention (not just "either is fine"), the camera hint needs an
  explicit left/right lock added - not done yet, flagged for whoever
  picks this up next.
- **Vision critique (llava:13b, pod-hosted) hallucinates scene elements
  that direct visual inspection doesn't confirm** - e.g. describing
  "grass area," "garden," "blue sky" on images directly confirmed (by
  looking at the actual pixels) to have plain gray backgrounds. Read as a
  residual training bias toward "cottage in a garden" imagery in the
  critic model itself, not a real defect in the critiqued image. Trust
  direct visual inspection over critique text for composition-level
  claims; the critique remains useful for gross deterministic/style
  issues (it did correctly catch the original scene-drift failure before
  `--compose-with-flux` existed).

- **LoRA training v1 FAILED validation** (2026-08-09) - training itself
  completed cleanly (1860 steps, no errors, loss settled around 0.09) but
  **the loss number was a false positive** - it only reflects normal
  diffusion-loss convergence, not whether the intended style actually
  transferred. Tested three ways after training (standalone at full
  strength, stacked with the original pixel-art LoRA + Lightning, and
  standalone at full-quality settings with the exact training caption) -
  all three reverted to fully photorealistic architectural photography
  with a full grass/tree scene, nothing like the target flat cel-shaded
  style. Renamed to
  `DO_NOT_USE_tithe_turnip_style_v1_FAILED_VALIDATION.safetensors` in
  `/workspace/comfyui/models/loras/` so it can't be mistaken for usable.
  **Lesson for next time: verify a trained LoRA with a real generated
  image immediately, don't trust the training log's loss curve as
  success evidence** - same "test with real output before declaring
  success" lesson this whole session already learned the hard way for
  generation itself, just not applied to training verification the first
  time round. Suspected cause: `RealVisXL_V4.0` is *explicitly* a
  photoreal-tuned checkpoint, and 31 images / `network_dim=32` /
  1860 steps likely wasn't a strong enough signal to override that this
  aggressively - a v2 attempt would want higher dim/alpha, more
  steps, and/or UNet-only training, not a small tweak.
- **Network Volumes can be attached to multiple pods simultaneously**
  (confirmed by accident, not by design) - a second pod was rented for
  the ChatGPT model-research handoff (`design/chatgpt_asset_model_research_handoff.md`)
  using the *same* existing volume rather than a new one, and files it
  downloaded (two FLUX LoRAs) showed up on `/workspace` from this pod's
  own SSH session immediately, with no reattachment step. Consistent with
  the volume being backed by a real shared filesystem (MooseFS - see the
  `df -h` mount type noted earlier), not exclusive block storage. Useful
  for future multi-pod work, but be careful two pods don't write the same
  file concurrently (e.g. both restarting ComfyUI, or both writing to
  `/workspace/tmp`).

- **Strong candidate found: `flux_2d_game_assets_game_assets_v3.safetensors`**
  (a Civitai LoRA for FLUX.1-schnell, downloaded via the ChatGPT
  model-research handoff, tested 2026-08-09). Applied directly to
  `flux1-schnell-fp8.safetensors` (already on the pod, Apache 2.0, no
  licensing concern - see the FLUX.1-dev note below) with a plain prompt
  and **no SDXL restyle pass** - tested on chapel, farmhouse, barn, and
  carrot, 4/4 came back cleanly isolated, correctly 3/4-angled, bold flat
  cel-shaded style, in a **single generation stage**. This may be able to
  replace the whole `--compose-with-flux` two-stage workaround, not just
  patch around it - not yet integrated into `generate.py`, pending style
  consistency comparison against the existing 31-image vetted library and
  more subject coverage. A second candidate from the same research pass,
  `flux_flat_art_game_assets_FOSZ.safetensors`, was tested and rejected -
  clean isolation but a flat "sticker/emoji" frontal framing, wrong camera
  convention for this project - removed.
- **FLUX.1-dev is licensing-blocked for this project, don't download it.**
  Black Forest Labs licenses FLUX.1-dev under a non-commercial research
  license; FLUX.1-schnell (Apache 2.0, already in use) has no such
  restriction. A `flux1-dev-fp8.safetensors` (7.6GB) landed in
  `/workspace/comfyui/models/checkpoints/` during the ChatGPT research
  pass before this was caught - deleted once flagged.
- **Network volume quota got genuinely close** (48GB of 50GB) from the
  combination of this session's own downloads plus the parallel ChatGPT
  pod writing into the same shared `/workspace` (see the "Network Volumes
  can be attached to multiple pods simultaneously" bullet above) -
  cleaned up back to 41GB by removing the above FLUX.1-dev file, the
  failed LoRA training output, and the rejected LoRA. Worth periodically
  checking `du -sh /workspace` when two pods share a volume, since usage
  can climb faster than expected from either side alone.

## Is the 80GB tier worth it?

Not for this week. That's an A100/H100-class card, meant for hosting a
70B+-class open LLM as a stand-in code-review/bulk-implementation lane.
It's a real idea worth a cheap one-off experiment eventually, but it is
not a substitute for the contract-enforcement judgment described in
`design/multi_agent_protocol.md`, and setting up a reliable self-hosted
LLM serving stack (vLLM or similar) is real DevOps work that competes
with actual dev time during a short gap. Skip it for now; revisit once
the 24GB workflow above is routine.
