# TRELLIS.2 RunPod handoff

Last updated: 2026-08-10

This is the operational handoff for the structure-art feasibility proof. It is
written so another model can resume without reconstructing the prior chat. Do
not add API keys, S3 secrets, Jupyter tokens, or private-key contents here.

## Objective

Test a hybrid structure pipeline without changing the game's 64x48 dimetric
projection:

1. Generate a textured 3D candidate from an approved structure reference with
   Microsoft TRELLIS.2.
2. Export a GLB.
3. Import it into headless Blender on the same pod.
4. Normalize ground contact, scale, orientation, lighting, and the fixed
   orthographic dimetric camera deterministically.
5. Render a neutrally lit opaque PNG review output for visual inspection.

TRELLIS is an appearance/3D accelerator, not geometry authority. Runtime
placement, footprint, anchor, collision, and sorting remain governed by the
existing Godot asset rig and `IsoProjection`.

## Current paid resource

- Pod ID: `8ej3pn32iu53u3`
- Data center: `US-MD-1` Secure Cloud
- GPU: NVIDIA A100-SXM4-80GB
- Compute rate observed at launch: $1.60/hour
- vCPU/RAM: 16 vCPU, 250GB RAM
- Container disk: 40GB
- Container image:
  `runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04`
- Template: `runpod-torch-v240`
- Network volume: `interested_brown_cricket`
- Network volume ID observed by `findmnt`: `zwuapttmgl`
- Network volume size: 80GB
- Mount: `/workspace`

Current direct SSH connection (ephemeral across redeploys):

```powershell
ssh root@154.54.102.25 -p 12907 `
  -i %USERPROFILE%\.ssh\id_ed25519_runpod
```

If that fails after a restart/redeploy, read the current command from the pod's
RunPod **Connect** tab. The local public-key fingerprint is recorded by Windows
as `SHA256:zRdsJAU0XZqxfliY3yHTThX+hXtwo5L2hxmVxMOVTp0`.

## Verified preflight

- SSH works with the existing `id_ed25519_runpod` key.
- GPU reports `NVIDIA A100-SXM4-80GB`, 81920 MiB.
- Driver reports 580.126.16.
- CUDA compiler exists at `/usr/local/cuda-12.4/bin/nvcc` and reports CUDA
  12.4. The template did not initially place `nvcc` on `PATH`.
- Ubuntu 22.04.5 LTS.
- `build-essential` is installed.
- `/workspace` was empty at setup start (`du -sh /workspace` reported 512
  bytes).

RunPod's network filesystem exposes its backing cluster size through `df`, not
the user's volume quota. Use `du -sh /workspace` and the RunPod console's stated
80GB allocation; do not infer free quota from `df -h /workspace`.

## Persistent layout

All expensive or takeover-critical files belong on the network volume:

```text
/workspace/
|-- TRELLIS.2/                    # pinned Microsoft repository checkout
|-- huggingface/                  # one canonical Hugging Face model cache
|-- setup_trellis2.sh             # copied from the project
|-- trellis2_setup.log            # detached setup output
|-- trellis2_install_manifest.txt # generated only after successful setup
|-- pod_guard.py
|-- pod_guard.log
`-- experiments/                  # planned inputs, GLBs, Blender files, renders
```

The reproducible venv is `/opt/trellis2_env`, and its stage markers are
`/opt/trellis2_setup_markers`. Both are disposable because RunPod explicitly
deletes non-network-volume data when this pod is stopped. Keeping markers on
the container is intentional: a recreated container must never see stale
markers and skip rebuilding its missing environment. Disposable compilation
products belong under `/tmp/trellis2-build` and `/tmp/extensions`.

## Reproducible setup

Source-controlled setup script:

```text
asset_studio/runpod/setup_trellis2.sh
```

Pinned Blender installer:

```text
asset_studio/runpod/install_blender.sh
```

Runtime import validator:

```text
asset_studio/runpod/verify_trellis_env.py
```

It resolves import names from installed distribution metadata, imports every
compiled dependency and `trellis2`, checks CUDA 12.4/A100 visibility, and
writes `/workspace/trellis2_import_report.json`.

Reproducible 512 experiment runner:

```text
asset_studio/runpod/run_trellis_image_to_3d.py
```

The runner subclasses the official image-to-3D pipeline only to omit its two
unused 1024-resolution flow checkpoints and BRIA's unnecessary RMBG-2.0
background-removal model. Generation, rendering, and GLB post-processing use
the pinned repository's official APIs and settings. It records seed,
input/output hashes, timings, mesh counts, peak CUDA allocation, checkpoint
commit, and disk growth in `generation_metadata.json`.

The runner fails closed unless the source has a non-opaque alpha channel. This
is intentional: every approved structure proof is already isolated, while the
self-hosted `briaai/RMBG-2.0` weights are CC BY-NC 4.0 unless the owner obtains
a separate commercial agreement. Do not authenticate to, download, or use
RMBG-2.0 for this commercial game proof. DINOv3 is still required for image
conditioning and uses Meta's separate DINOv3 license. Primary terms pages:

- `https://huggingface.co/briaai/RMBG-2.0`
- `https://ai.meta.com/resources/models-and-libraries/dinov3-license/`

The base environment's OpenCV build returned `None` for the repository-tracked
`assets/hdri/forest.exr` despite `OPENCV_IO_ENABLE_OPENEXR=1`. The runner
therefore records whether that HDRI loaded and falls back to TRELLIS renderer
defaults for its diagnostic turntable. This does not affect generation, GLB
materials, or the authoritative Blender render/validation gate.

It installs the official Blender 4.5.12 LTS Linux x64 archive under
`/workspace`, verifies the Blender Foundation SHA-256
`95e3a2dfedba3bd32ca54fc355eac6b15a11986954ccb02815a07535d0120a25`,
installs the three runtime packages absent from the base image (`libice6`,
`libsm6`, and `libxkbcommon0`), and writes
`/workspace/blender_install_manifest.txt`.

The script deliberately creates its own reproducible Python 3.10 virtual
environment instead of relying on the template's Python 3.11/PyTorch 2.4.
The environment lives at `/opt/trellis2_env` on the pod's 40 GB container
disk. It is disposable and is rebuilt by the source-controlled script when a
new pod is created. Checkpoints, source, setup markers, logs, and experiment
outputs remain persistent under `/workspace`.

This layout was adopted after the first PyTorch install wrote about 3.0 GB to
`/workspace/trellis2_env` and then remained blocked in the MooseFS
`request_wait_answer` kernel wait with unchanged process I/O counters across
multiple checks. The incomplete directory can be removed later after the new
environment and experiments are verified; it is not used by the setup script.
Microsoft's required runtime is installed exactly as PyTorch 2.6.0,
torchvision 0.21.0, CUDA 12.4. The TRELLIS repository is pinned to commit:

```text
75fbf0183001ed9876c8dbb35de6b68552ee08bd
```

Launch/relaunch setup:

```bash
chmod 755 /workspace/setup_trellis2.sh
bash -n /workspace/setup_trellis2.sh
setsid bash /workspace/setup_trellis2.sh \
  > /workspace/trellis2_setup.log 2>&1 < /dev/null &
```

Monitor:

```bash
pgrep -af setup_trellis2
find /opt/trellis2_setup_markers -maxdepth 1 -type f -printf '%f\n' | sort
tail -n 50 /workspace/trellis2_setup.log
du -sh /workspace
```

The marker files allow safe continuation after a stopped pod. Do not delete a
marker unless the corresponding installed stage is known to be corrupt.

## Cost guard

When the pod is running, launch `/workspace/pod_guard.py` with a six-hour
ceiling and the observed rate of $1.60/hour. It logs to
`/workspace/pod_guard.log`. No RunPod API key is put on the pod, so its final
fallback is pod `poweroff`, not API deletion. RunPod native runtime limits and
manual stop/termination remain the primary cost controls. The initial guard
process ended when the pod was intentionally stopped at the DINOv3 access
gate; relaunch it immediately after the next start.

## Resume after the DINOv3 access gate

1. Confirm the Hugging Face account has accepted access to
   `facebook/dinov3-vitl16-pretrain-lvd1689m` and has a read token.
2. Start a compatible A100 pod with the existing network volume; the original
   allocation may not be available after a stop. Use RunPod's migration option
   when offered so the persistent volume follows the replacement pod.
3. Read the new direct SSH host/port from RunPod's Connect tab.
4. Upload the current source-controlled scripts in `asset_studio/runpod/`,
   especially `setup_trellis2.sh` and the revised
   `run_trellis_image_to_3d.py`, then rerun setup. The container-local venv and
   packages were intentionally discarded on stop.
5. Rerun `install_blender.sh` to restore the three Ubuntu runtime libraries;
   the verified Blender archive itself is already persistent.
6. Relaunch the cost guard.
7. In the pod's interactive web terminal, run
   `/opt/trellis2_env/bin/hf auth login` and paste the read token there. Never
   place it in a command log, source file, this document, or chat.
8. Rerun `verify_trellis_env.py`, then rerun the official sample command. The
   9.2 GB of selected TRELLIS weights should be reused from the persistent
   Hugging Face cache.

## Backup and old volume

The old US-IL-1 volume (`fj1sdh5rid`) has not been modified or deleted. Its
project-specific payload is verified locally at:

```text
%USERPROFILE%\Documents\TitheAndTurnip_RunPod_Archive_2026-08-09
```

Verification result: 107 files, 1,427,576,989 bytes, zero missing files, zero
size mismatches, with SHA-256 values in `backup_manifest_sha256.csv`.
Large replaceable checkpoints, Ollama models, environments, caches, and
upstream repositories were intentionally excluded. Keep the old volume until
the new proof environment and restored unique data are verified; revoke the
temporary S3 key after migration work is finished.

## Experiment sequence and acceptance gates

1. **Environment gate**
   - Setup exits zero and writes `trellis2_install_manifest.txt`.
   - PyTorch reports CUDA 12.4 and sees the A100.
   - Required compiled modules import in the persistent environment.
2. **Official sample gate**
   - Run Microsoft's bundled example at 512 resolution.
   - Produce a non-empty PBR-ready GLB and preview.
   - Reopen/inspect the GLB rather than treating process exit as proof.
3. **Blender gate**
   - Install a pinned official Linux Blender build on `/workspace`.
   - Run it with `--background` and a Python script.
   - Import the official-sample GLB and render a neutrally lit opaque PNG.
4. **Farmhouse gate**
   - Use the approved farmhouse/house proof as the image input.
   - Begin at 512 resolution and fixed seed.
   - Export GLB, inspect topology/materials, and render with the project's fixed
     dimetric camera.
   - Record prompt/input hash, seed, resolution, TRELLIS commit, output hashes,
     camera values, render settings, timings, and peak disk usage.
5. **Feasibility decision**
   - Accept only if repeated exports can be normalized and rendered without
     perspective drift, unusable geometry, or excessive manual repair.
   - A visually attractive but unrepeatable one-off is not success.

## Current status

As of the 2026-08-10 experiment run:

- Backup/migration: complete and verified. The current pod is `8ej3pn32iu53u3`;
  its container-local venv was rebuilt, while `/workspace` retained TRELLIS,
  Blender, the Hugging Face cache, and experiment directories.
- Fast container-disk environment recovery: complete at
  `/opt/trellis2_env`; the import report confirms Python 3.10.12, PyTorch
  2.6.0+cu124, CUDA 12.4, compiled extensions, and the A100-SXM4-80GB.
- DINOv3 access: cleared after owner approval. The token was supplied only in
  the pod terminal and is not recorded in source, logs, this document, or chat.
- Export compatibility: a current Transformers DINOv3 encoder-path shim is in
  the runner; the pod Pillow WebP binary is incompatible, so GLBs are exported
  with standard PNG textures. The optional TRELLIS internal turntable remains
  skipped because OpenCV cannot decode its tracked EXR environment map; this
  does not affect the independent Blender validation.
- Official sample: `/workspace/experiments/official_sample_glb_png/model.glb`
  is 71,161,572 B, SHA-256
  `41e7d7453ed7e7bcfcd55e67f6b534091bd3c7fe5473a2d04534fef9e7fd8642`.
  Blender reopened it and rendered
  `dimetric_validation_final.png`; the report measured 675,723 vertices and
  946,774 triangles. This passes the environment/GLB/Blender technical gate.
- Farmhouse sample: the accepted 2D source
  `farmhouse_wide_4x3_southeast_post/final_runtime.png`, seed 42, produced
  `/workspace/experiments/farmhouse_southeast_trellis/model.glb`, 48,896,352 B,
  SHA-256 `b2401ce6dba55ae5aaa65e051af28710836fb3aa127d07a2c9d081d811767602`.
  Blender rendered `dimetric_validation.png`; the report measured 576,405
  vertices and 950,462 triangles. Its final rendered house is coherent enough
  to prove conversion, but it hallucinates an additional door/window and
  changes the roof. It **fails the production-art acceptance gate**.
- Decision: keep the deterministic 2D rig as the only production path.
  TRELLIS may be revisited as a blockout/reference accelerator after a resident
  batch runner removes repeated 4B-model loads and an architecture-preserving
  normalization stage is demonstrated. Do not integrate its current output.

Update this section after every material success or failure. Include exact log
paths and output hashes; never summarize an unverified process as successful.
