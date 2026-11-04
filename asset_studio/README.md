# Asset Studio (local AI game-art pipeline)

Git-ignored user tooling for generating and critiquing 2D game art locally on
this machine (GTX 1070 / 8 GB VRAM / 16 GB RAM). Nothing here is part of the
game; it is a private workspace.

## The loop

1. SDXL/ComfyUI (or another local generator) produces an image.
2. `critique.py` inspects it two ways:
   - deterministic checks: exact palette (hex + coverage), dimensions, unique
     color count, off-palette colors vs `allowed_palette`;
   - a local vision model (default `gemma3:4b` via Ollama) writes a terse
     art-director critique.
   Both go into `reviews/<image>.json`.
3. Codex (the orchestrator) reads the JSON + critique, compares against
   `style_bible.md`, and returns concrete steering: prompt deltas, LoRA
   strength, seed policy, accept/reject.
4. The human looks at the image (Codex renders it in chat) and makes the final
   call.

## Usage

```powershell
# Criticise one or more images
python critique.py ..\data\crops\potato_1.png ..\data\crops\potato_2.png

# Extract a combined palette from inspiration images (style input)
python inspire.py ref_stardew.png ref_horizon.png
# -> writes style_reference.json; copy its palette into config.json
#    allowed_palette to enforce colour compliance.

# Tag and describe a folder of downloaded (not generated) art - e.g. a Kenney
# pack - so future sessions can grep tags instead of re-viewing every file
python catalog.py C:\path\to\downloaded_pack
# -> writes art_catalog.json (one entry per image: description, tags,
#    category, perspective, tileable guess). Incremental - safe to re-run,
#    already-catalogued entries are skipped.
```

Requires Pillow (`import PIL`) and a running Ollama on `localhost:11434`
(`gemma3:4b` works; `qwen2.5vl:3b` image input currently hangs - see
DEVELOPMENT_STATE.md).

## Generation

```powershell
# Generate from a style-bible template (recommended - ComfyUI must be running;
# first run loads the model slowly)
python generate.py --category item --subject "turnip crop, young leafy stage, cream and green palette" --critique
python generate.py --category structure --subject "timber-framed farmhouse with thatched roof" --critique

# One-off prompt override still works exactly as before
python generate.py --prompt "a turnip crop sprite, pixel art" --critique

# img2img (no new models): steer toward a reference image's style/layout
python generate.py --prompt "..." --init-image farmhouse_v2_painterly.png --denoise 0.55

# Also key out the flat background after generation
python generate.py --category item --subject "carrot sprout" --remove-bg

# Batch-generate with GPU thermal cooldown between items
python batch.py --prompts-file prompts.txt --guard --max-temp 78 --cool-below 62 --rest 10
```

### Prompt templates

`prompt_templates.json` holds the two tested style-bible categories:

- `item` - crops, tools, animals, and small props; the pixel-art-sprite
  template anchored by the turnip test.
- `structure` - buildings; the 2D-painting template anchored by
  `farmhouse_v2_painterly.png`, including the extra negatives that stop the
  photoreal/miniature-diorama drift (`cgi, unreal engine, octane render,
  miniature diorama, tilt shift, realistic photo`).

`--category NAME --subject TEXT` builds the full prompt/negative from the
template and defaults `--width`/`--height` to the category's values. Both
categories default to **1024x1024** because SDXL's native training
resolution is square and the style bible's source-generation gate already
assumes 1024x1024; game tiles are cropped/resized at staging time, not at
generation time. Explicit `--width`/`--height` still win over the template.
`--prompt` remains available for one-off work and is mutually exclusive with
`--category`.

### Background removal

`--remove-bg` (or the standalone `strip_background.py`) keys out the flat
background the style bible requires. It samples the four corner pixels,
checks they are uniform within a per-channel tolerance (default 24; if they
are not, it warns and skips instead of mangling a real background), then
flood-fills the connected background from each corner into a transparent
alpha channel. The result is written next to the original as
`<name>_transparent.png`; the opaque original is never overwritten.

```powershell
# Standalone, on an existing image
python strip_background.py farmhouse_v2_painterly.png
python strip_background.py asset_studio_00001_.png --tolerance 16 --out keyed.png

# Same keying built into generation
python generate.py --category structure --subject "stone well" --remove-bg
```

## Thermal management (GTX 1070)

- 70 C is normal under load: the card throttles itself near 83 C and its
  absolute max is 94 C, and it cools to idle almost instantly when load ends.
- Cooldown is **opt-in**: add `--guard` to `batch.py` to wait between
  generations until the GPU cools to `--cool-below` (default 62 C), never
  start above `--max-temp` (default 78 C), and rest `--rest` seconds between
  items. Without `--guard`, prompts run back-to-back as before the guard
  existed. `gpu_guard.py` exposes the same checks for other scripts.
- Optional hardware limiter (admin, reversible): `nvidia-smi -pl 120` caps
  power/heat output (default is ~151 W); reset with `nvidia-smi -pl 151`.

## Pinned stack (do not upgrade)

- ComfyUI **v0.7.0** (checked out at `%USERPROFILE%\ComfyUI_windows_portable`)
  - newer releases require `comfy_kitchen`, which needs torch >= 2.8.
- torch **2.6.0+cu124** - the last line with GTX 10-series (Pascal) kernels.
  Upgrading either one brings back "no kernel image is available" errors.

## Known machine facts (2026-08-07)

- Codex cannot view images in this session (no image input support), so the
  vision model + deterministic scripts are the eyes.
- Gemini-class 3-4B vision models are mid-tier critics: good at gross issues,
  unreliable on exact colours. That is why deterministic palette checks exist.
- Generation stack installed 2026-08-08: ComfyUI v0.7.0 + torch 2.6.0+cu124 at
  `%USERPROFILE%\ComfyUI_windows_portable` (see "Pinned stack"); the harness
  now covers generate -> critique -> steer.
