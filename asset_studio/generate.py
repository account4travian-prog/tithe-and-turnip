"""Generate an image via the local ComfyUI API (SDXL + pixel-art LoRA + Lightning).

Usage:
    python generate.py --category item --subject "turnip crop, young leafy stage"
                       [--seed 42] [--steps 4] [--cfg 1.0] [--critique]
                       [--remove-bg] [--init-image PATH --denoise 0.55]
                       [--reference-image PATH --ip-adapter-weight 0.6]
    python generate.py --prompt "a turnip crop sprite, pixel art" [same options]

Requires ComfyUI running on the configured URL. Defaults to local
(http://127.0.0.1:8188); override with --host or the COMFY_HOST env var
to point at a rented pod (e.g. --host https://<pod-id>-<port>.proxy.runpod.net
- check the pod's Connect tab for the actual port, it is not always 8188).
Precedence: --host flag > COMFY_HOST env var > local default.

Output images are always downloaded over HTTP via ComfyUI's /view
endpoint into asset_studio/output/ on THIS machine, never assumed to
live on local disk - this is what makes --host work at all: a remote
pod's ComfyUI writes its output to the pod's own filesystem, which this
script never touches directly. Input images (--init-image,
--reference-image) go the other direction over ComfyUI's /upload/image
endpoint for the same reason - a remote pod has no access to this
machine's filesystem, so a raw local path in a LoadImage node (which is
all that worked when this script only ever ran against a local ComfyUI)
silently fails against a pod. Both paths always upload now, local or
remote, so there is exactly one code path instead of one that happens to
work locally and a second that would need to work remotely.

Prints the saved (local) image path; with --critique, also runs critique.py on it.

--category NAME --subject TEXT looks up prompt_templates.json and builds the
full prompt/negative from the tested style-bible templates. --prompt remains
available for one-off overrides. --remove-bg writes <name>_transparent.png
via strip_background.py after generation.

--init-image PATH switches from text-to-image to img2img: LoadImage +
VAEEncode replace EmptyLatentImage and KSampler runs at --denoise (default
0.55 when an init image is given, 1.0 otherwise). This mode needs no extra
models - steers the whole image via the starting latent, coarse but simple.

--reference-image PATH conditions generation on a reference image's content
via IP-Adapter (IPAdapterModelLoader + CLIPVisionLoader + IPAdapterAdvanced,
from the cubiq/ComfyUI_IPAdapter_plus custom node) instead of - or alongside -
--init-image. This is finer-grained than img2img (attention-level
conditioning rather than a noised starting latent) but needs IP-Adapter's
custom node and model files installed on whatever host --host points at -
see design/runpod_guide.md section 7 for how those were installed on the
project's rented pod. Not installed on the local ComfyUI as of this writing,
so --reference-image only works against a host that has it.

--compose-with-flux (requires --category/--subject) fixes a real failure the
structure category hit generating "iconic scene" subjects (farmhouse, chapel,
barn): SDXL+LoRA kept drawing a full garden/landscape around them no matter
how the negative prompt was strengthened, because the base checkpoint's own
"isometric game asset" composition prior overpowers negative prompting.
FLUX.1 schnell isolates these reliably instead (stronger instruction
following) - this flag generates a stage-1 composition with FLUX using
prompt_templates.json's "flux_compose" template, then automatically uses it
as --init-image for the normal category-styled generation, restyling FLUX's
correct composition into the established look. Needs FLUX.1 schnell on
whatever host --host points at (already on the project's rented pod;
requires --denoise default of 0.45, tuned live against real drift, not a
guess - override with --denoise if a subject needs more/less restyling).
"""

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

from strip_background import DEFAULT_TOLERANCE, strip_background


# Overridable at runtime by set_comfy_url() (called from main() after arg
# parsing) - module-level default covers direct imports (batch.py) that
# never call main().
COMFY_URL = os.environ.get("COMFY_HOST", "http://127.0.0.1:8188").rstrip("/")
CHECKPOINT = "RealVisXL_V4.0.safetensors"
PIXEL_LORA = "pixel-art-lora-sdxl.safetensors"
LIGHTNING_LORA = "sdxl_lightning_4step_lora.safetensors"
# IP-Adapter model files - names match what design/runpod_guide.md section 7
# documents downloading onto the rented pod (h94/IP-Adapter's vit-h family).
CLIP_VISION_MODEL = "CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors"
IPADAPTER_MODEL = "ip-adapter-plus_sdxl_vit-h.safetensors"
DEFAULT_IP_ADAPTER_WEIGHT = 0.6
OUTPUT_PREFIX = "asset_studio"
# LIGHTNING_LORA trades fidelity for a 4-step/cfg=1.0 sample - chosen for the
# local GTX 1070's speed constraints, not for best quality. --full-quality
# skips it and samples the checkpoint + PIXEL_LORA normally instead.
FAST_STEPS = 4
FAST_CFG = 1.0
FULL_QUALITY_STEPS = 30
FULL_QUALITY_CFG = 7.0
DEFAULT_PIXEL_LORA_STRENGTH = 0.8
# Tuned live 2026-08-09 against real isolation-drift failures on structure
# subjects, not guessed - see build_flux_compose_workflow / --compose-with-flux.
DEFAULT_FLUX_RESTYLE_DENOISE = 0.45
DEFAULT_NEGATIVE = "blurry, low quality, jpeg artifacts, text, watermark, photorealistic, 3d render"
LOCAL_OUTPUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "output")
# urllib's default "Python-urllib/x.y" User-Agent gets blocked (Cloudflare
# error 1010) by the WAF sitting in front of *.proxy.runpod.net - harmless
# against a local ComfyUI, required against a remote pod.
REQUEST_HEADERS = {"User-Agent": "Mozilla/5.0 (asset-studio generate.py)"}


def set_comfy_url(url: str) -> None:
    """Overrides the module-level COMFY_URL - used by --host and by callers
    that import generate.py directly (batch.py) and want a remote pod."""
    global COMFY_URL
    COMFY_URL = url.rstrip("/")


def load_prompt_templates() -> dict:
    here = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(here, "prompt_templates.json"), encoding="utf-8") as f:
        return json.load(f)


def build_workflow(
    prompt: str,
    negative: str,
    seed: int,
    steps: int,
    cfg: float,
    width: int,
    height: int,
    init_image: str | None = None,
    denoise: float = 1.0,
    reference_image: str | None = None,
    ip_adapter_weight: float = DEFAULT_IP_ADAPTER_WEIGHT,
    full_quality: bool = False,
    pixel_lora_strength: float = DEFAULT_PIXEL_LORA_STRENGTH,
) -> dict:
    """init_image and reference_image are names already uploaded to ComfyUI
    via upload_image() - see generate_image(), which does the uploading
    before calling this. Never local filesystem paths here: this function
    only builds the graph, it does no I/O and makes no assumption about
    which machine ComfyUI is running on."""
    workflow = {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": CHECKPOINT}},
        "2": {
            "class_type": "LoraLoader",
            "inputs": {
                "model": ["1", 0],
                "clip": ["1", 1],
                "lora_name": PIXEL_LORA,
                "strength_model": pixel_lora_strength,
                "strength_clip": pixel_lora_strength,
            },
        },
    }
    # full_quality skips LIGHTNING_LORA entirely rather than just changing
    # steps/cfg - sampling a Lightning-distilled model at non-Lightning step
    # counts doesn't recover quality, it just samples the wrong model longer.
    if full_quality:
        model_source = ["2", 0]
        clip_source = ["2", 1]
    else:
        workflow["3"] = {
            "class_type": "LoraLoader",
            "inputs": {
                "model": ["2", 0],
                "clip": ["2", 1],
                "lora_name": LIGHTNING_LORA,
                "strength_model": 1.0,
                "strength_clip": 1.0,
            },
        }
        model_source = ["3", 0]
        clip_source = ["3", 1]
    workflow["4"] = {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": clip_source}}
    workflow["5"] = {"class_type": "CLIPTextEncode", "inputs": {"text": negative, "clip": clip_source}}
    workflow["7"] = {
        "class_type": "KSampler",
        "inputs": {
            "seed": seed,
            "steps": steps,
            "cfg": cfg,
            "sampler_name": "euler",
            "scheduler": "normal",
            "denoise": 1.0,
            "model": model_source,
            "positive": ["4", 0],
            "negative": ["5", 0],
            "latent_image": [],
        },
    }
    workflow["8"] = {"class_type": "VAEDecode", "inputs": {"samples": ["7", 0], "vae": ["1", 2]}}
    workflow["9"] = {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": OUTPUT_PREFIX}}
    if init_image is not None:
        # img2img: LoadImage + VAEEncode in place of EmptyLatentImage.
        workflow["10"] = {
            "class_type": "LoadImage",
            "inputs": {"image": init_image},
        }
        workflow["6"] = {
            "class_type": "VAEEncode",
            "inputs": {"pixels": ["10", 0], "vae": ["1", 2]},
        }
    else:
        workflow["6"] = {
            "class_type": "EmptyLatentImage",
            "inputs": {"width": width, "height": height, "batch_size": 1},
        }
    workflow["7"]["inputs"]["latent_image"] = ["6", 0]
    workflow["7"]["inputs"]["denoise"] = denoise

    if reference_image is not None:
        # IP-Adapter conditioning: CLIPVisionLoader + IPAdapterModelLoader +
        # LoadImage feed IPAdapterAdvanced, which wraps the model and takes
        # over KSampler's "model" input from whichever LoRA chain fed it
        # (node 3 normally, node 2 under --full-quality).
        workflow["11"] = {
            "class_type": "CLIPVisionLoader",
            "inputs": {"clip_name": CLIP_VISION_MODEL},
        }
        workflow["12"] = {
            "class_type": "IPAdapterModelLoader",
            "inputs": {"ipadapter_file": IPADAPTER_MODEL},
        }
        workflow["13"] = {
            "class_type": "LoadImage",
            "inputs": {"image": reference_image},
        }
        workflow["14"] = {
            "class_type": "IPAdapterAdvanced",
            "inputs": {
                "model": model_source,
                "ipadapter": ["12", 0],
                "image": ["13", 0],
                "clip_vision": ["11", 0],
                "weight": ip_adapter_weight,
                "weight_type": "linear",
                "combine_embeds": "concat",
                "start_at": 0.0,
                "end_at": 1.0,
                "embeds_scaling": "V only",
            },
        }
        workflow["7"]["inputs"]["model"] = ["14", 0]

    return workflow


def build_flux_compose_workflow(
    prompt: str, checkpoint: str, seed: int, steps: int, cfg: float, width: int, height: int,
) -> dict:
    """Stage-1 composition workflow for --compose-with-flux. Deliberately
    minimal - no LoRAs (FLUX-incompatible with the project's SDXL LoRAs), no
    negative prompt (FLUX schnell is CFG-distilled; cfg=1.0 makes a real
    negative conditioning a no-op, so this uses an empty string rather than
    pretending one does something). Positive-only prompt text; see the
    module docstring and prompt_templates.json's flux_compose entry for why
    negative object lists backfired here."""
    return {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": checkpoint}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["1", 1]}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"text": "", "clip": ["1", 1]}},
        "6": {"class_type": "EmptyLatentImage", "inputs": {"width": width, "height": height, "batch_size": 1}},
        "7": {
            "class_type": "KSampler",
            "inputs": {
                "seed": seed, "steps": steps, "cfg": cfg,
                "sampler_name": "euler", "scheduler": "simple", "denoise": 1.0,
                "model": ["1", 0], "positive": ["4", 0], "negative": ["5", 0],
                "latent_image": ["6", 0],
            },
        },
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["7", 0], "vae": ["1", 2]}},
        "9": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": "flux_compose"}},
    }


def _http_error_text(exc: urllib.error.HTTPError) -> str:
    """Include the server's response body (ComfyUI node_errors etc.) in errors."""
    try:
        body = exc.read().decode("utf-8", errors="replace")
    except Exception:
        body = ""
    detail = f": {body[:2000]}" if body else ""
    return f"HTTP {exc.code} {exc.reason}{detail}"


def _execution_error_text(entry: dict) -> str:
    """Pull the exception message out of a failed ComfyUI history entry."""
    status = entry.get("status", {})
    for msg_type, payload in status.get("messages", []):
        if msg_type == "execution_error" and isinstance(payload, dict):
            return str(payload.get("exception_message") or payload)
    return str(status)


def post_json(path: str, payload: dict, timeout: int = 60) -> dict:
    req = urllib.request.Request(
        COMFY_URL + path,
        data=json.dumps(payload).encode(),
        headers={**REQUEST_HEADERS, "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"ComfyUI {path} failed: {_http_error_text(exc)}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"ComfyUI {path} unreachable: {exc.reason}") from exc


def get_json(path: str, timeout: int = 60) -> dict:
    req = urllib.request.Request(COMFY_URL + path, headers=REQUEST_HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"ComfyUI {path} failed: {_http_error_text(exc)}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"ComfyUI {path} unreachable: {exc.reason}") from exc


def upload_image(local_path: str) -> str:
    """Uploads a local file to ComfyUI's /upload/image endpoint and returns
    the name a LoadImage node should reference. Required for a remote host -
    LoadImage otherwise only sees ComfyUI's own input directory on whatever
    machine it's running on, not this one - and harmless against a local
    ComfyUI, which is why both --init-image and --reference-image always go
    through this rather than only doing so when --host is remote."""
    boundary = uuid.uuid4().hex
    filename = os.path.basename(local_path)
    with open(local_path, "rb") as f:
        file_bytes = f.read()
    body = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="image"; filename="{filename}"\r\n'
        "Content-Type: application/octet-stream\r\n\r\n"
    ).encode("utf-8") + file_bytes + f"\r\n--{boundary}--\r\n".encode("utf-8")
    req = urllib.request.Request(
        COMFY_URL + "/upload/image",
        data=body,
        headers={**REQUEST_HEADERS, "Content-Type": f"multipart/form-data; boundary={boundary}"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            result = json.loads(resp.read().decode())
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"ComfyUI /upload/image failed for {filename}: {_http_error_text(exc)}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"ComfyUI /upload/image unreachable for {filename}: {exc.reason}") from exc
    name = result.get("name", filename)
    subfolder = result.get("subfolder", "")
    return f"{subfolder}/{name}" if subfolder else name


def wait_for_image(prompt_id: str, timeout: int = 900) -> tuple[str, str]:
    """Poll the GET-only /history/<id> endpoint until the output exists.
    Returns (subfolder, filename) - NOT a filesystem path. ComfyUI's own
    output directory is on whatever machine is running it (local disk for
    a local instance, the pod's disk for a rented one); this script never
    assumes it can see that filesystem directly. download_image() below
    fetches the actual bytes over HTTP, which works identically either way.

    The earlier POST-vs-GET bug made every poll fail silently (bare
    except: pass) and hung until timeout. Poll failures are now logged with
    a consecutive-failure count so persistent problems are visible, and a
    completed-but-failed prompt raises immediately with ComfyUI's exception
    message instead of burning the whole timeout.
    """
    deadline = time.time() + timeout
    last_progress = 0.0
    last_error_log = 0.0
    consecutive_failures = 0
    while time.time() < deadline:
        try:
            history = get_json("/history/" + prompt_id, timeout=10)
            consecutive_failures = 0
            if prompt_id in history:
                entry = history[prompt_id]
                if entry.get("status", {}).get("status_str") == "error":
                    raise RuntimeError(
                        "ComfyUI generation failed: " + _execution_error_text(entry)
                    )
                outputs = entry.get("outputs", {})
                for node in outputs.values():
                    for img in node.get("images", []):
                        if img.get("type") == "output":
                            return str(img.get("subfolder", "")), str(img["filename"])
        except RuntimeError:
            raise
        except Exception as exc:
            consecutive_failures += 1
            now = time.time()
            if now - last_error_log >= 30:
                print(
                    f"...poll failed ({consecutive_failures} consecutive): {exc}",
                    flush=True,
                )
                last_error_log = now
        if time.time() - last_progress > 30:
            print(f"...waiting ({int(deadline - time.time())}s left)", flush=True)
            last_progress = time.time()
        time.sleep(5)
    raise TimeoutError("generation timed out")


def download_image(subfolder: str, filename: str, dest_dir: str = LOCAL_OUTPUT_DIR) -> str:
    """Fetches one output image over HTTP via ComfyUI's /view endpoint and
    saves it under dest_dir on THIS machine. Works identically for a local
    ComfyUI (loopback HTTP, negligible cost) and a remote pod (this is the
    only correct way to get the bytes off a machine you don't have
    filesystem access to). Returns the local path it wrote."""
    os.makedirs(dest_dir, exist_ok=True)
    query = urllib.parse.urlencode(
        {"filename": filename, "subfolder": subfolder, "type": "output"})
    url = f"{COMFY_URL}/view?{query}"
    dest = os.path.join(dest_dir, filename)
    req = urllib.request.Request(url, headers=REQUEST_HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            data = resp.read()
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"ComfyUI /view failed for {filename}: {_http_error_text(exc)}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"ComfyUI /view unreachable for {filename}: {exc.reason}") from exc
    with open(dest, "wb") as f:
        f.write(data)
    return dest


def generate_flux_composition(
    subject: str, seed: int, width: int = 1024, height: int = 1024,
    camera_hint: str = "",
) -> str:
    """Runs the stage-1 FLUX composition pass (see build_flux_compose_workflow)
    and returns the local downloaded path - meant to be handed straight to
    generate_image() as init_image. Reuses post_json/wait_for_image/
    download_image as-is since they're already host-agnostic; the only new
    piece here is the FLUX-specific workflow shape.

    camera_hint (from a category's 'flux_camera_hint' in prompt_templates.json,
    e.g. structure's) is appended after the generic isolation framing - fixes
    a real failure where FLUX defaulted to a flat front elevation on
    symmetric-doorway subjects (chapel, barn, gatehouse) instead of the
    three-quarter angle the vetted library actually uses (coop.png etc.)."""
    templates = load_prompt_templates()
    flux_entry = templates.get("flux_compose")
    if not flux_entry:
        raise RuntimeError("prompt_templates.json has no 'flux_compose' entry")
    prompt = f"{flux_entry['prompt_prefix']}{subject}{flux_entry['prompt_suffix']}"
    if camera_hint:
        prompt = f"{prompt}, {camera_hint}"
    workflow = build_flux_compose_workflow(
        prompt=prompt,
        checkpoint=flux_entry["checkpoint"],
        seed=seed,
        steps=int(flux_entry.get("steps", 4)),
        cfg=float(flux_entry.get("cfg", 1.0)),
        width=width,
        height=height,
    )
    print("queueing FLUX composition pass...")
    resp = post_json("/prompt", {"prompt": workflow, "client_id": "asset-studio-flux"})
    prompt_id = resp["prompt_id"]
    subfolder, filename = wait_for_image(prompt_id)
    path = download_image(subfolder, filename)
    print("FLUX composition saved:", path)
    return path


def generate_image(
    prompt: str,
    negative: str = DEFAULT_NEGATIVE,
    seed: int = 0,
    steps: int = FAST_STEPS,
    cfg: float = FAST_CFG,
    width: int = 1024,
    height: int = 1024,
    critique: bool = False,
    init_image: str | None = None,
    denoise: float = 1.0,
    remove_bg: bool = False,
    bg_tolerance: int = DEFAULT_TOLERANCE,
    reference_image: str | None = None,
    ip_adapter_weight: float = DEFAULT_IP_ADAPTER_WEIGHT,
    full_quality: bool = False,
    pixel_lora_strength: float = DEFAULT_PIXEL_LORA_STRENGTH,
) -> str:
    """Queue one prompt in ComfyUI, wait for the output, return the image path.
    init_image and reference_image are LOCAL paths here (unlike
    build_workflow's params of the same name) - they get uploaded to
    whatever host --host points at before the workflow is built."""
    if init_image is not None and not os.path.isfile(init_image):
        raise FileNotFoundError(f"init image not found: {init_image}")
    if reference_image is not None and not os.path.isfile(reference_image):
        raise FileNotFoundError(f"reference image not found: {reference_image}")
    if not 0.0 < denoise <= 1.0:
        raise ValueError(f"denoise must be in (0, 1], got {denoise}")
    uploaded_init = upload_image(init_image) if init_image is not None else None
    uploaded_ref = upload_image(reference_image) if reference_image is not None else None
    workflow = build_workflow(
        prompt, negative, seed, steps, cfg, width, height,
        uploaded_init, denoise, uploaded_ref, ip_adapter_weight, full_quality,
        pixel_lora_strength,
    )
    print("queueing prompt...")
    resp = post_json("/prompt", {"prompt": workflow, "client_id": "asset-studio"})
    prompt_id = resp["prompt_id"]
    print("prompt id:", prompt_id)
    subfolder, filename = wait_for_image(prompt_id)
    path = download_image(subfolder, filename)
    print("saved:", path)
    if remove_bg:
        transparent = strip_background(path, tolerance=bg_tolerance)
        if transparent is None:
            print("transparent: SKIPPED (background corners not uniform)")
        else:
            print("transparent:", transparent)
    if critique:
        here = os.path.dirname(os.path.abspath(__file__))
        subprocess.run([sys.executable, os.path.join(here, "critique.py"), path], check=False)
    return path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--host",
        default=None,
        help="ComfyUI base URL, e.g. http://127.0.0.1:8188 (default) or "
             "https://<pod-id>-8188.proxy.runpod.net for a rented pod. "
             "Overrides the COMFY_HOST env var, which overrides the local default.",
    )
    parser.add_argument("--prompt", default=None, help="one-off full prompt (alternative to --category/--subject)")
    parser.add_argument("--category", default=None, help="prompt template category: item or structure")
    parser.add_argument("--subject", default=None, help="subject description for --category templates")
    parser.add_argument("--negative", default=DEFAULT_NEGATIVE, help="base negative; template additions are appended in --category mode")
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument("--steps", type=int, default=None, help=f"default {FAST_STEPS} (or {FULL_QUALITY_STEPS} with --full-quality)")
    parser.add_argument("--cfg", type=float, default=None, help=f"default {FAST_CFG} (or {FULL_QUALITY_CFG} with --full-quality)")
    parser.add_argument("--width", type=int, default=None, help="defaults to the category template's width")
    parser.add_argument("--height", type=int, default=None, help="defaults to the category template's height")
    parser.add_argument(
        "--full-quality",
        action="store_true",
        help="skip the Lightning speed LoRA and sample at normal steps/cfg - "
             "worth it on a rented pod's GPU, not worth the time cost on a "
             "weak local card (that's what LIGHTNING_LORA exists for)",
    )
    parser.add_argument("--critique", action="store_true")
    parser.add_argument("--remove-bg", action="store_true", help="also write <name>_transparent.png via strip_background.py")
    parser.add_argument(
        "--bg-tolerance",
        type=int,
        default=DEFAULT_TOLERANCE,
        help=f"background corner/fill tolerance for --remove-bg (default {DEFAULT_TOLERANCE})",
    )
    parser.add_argument(
        "--init-image",
        default=None,
        help="img2img source image; LoadImage+VAEEncode replace EmptyLatentImage",
    )
    parser.add_argument(
        "--denoise",
        type=float,
        default=None,
        help="img2img denoise strength (default 0.55 with --init-image, 1.0 otherwise)",
    )
    parser.add_argument(
        "--reference-image",
        default=None,
        help="IP-Adapter reference image; requires IP-Adapter installed on --host "
             "(see design/runpod_guide.md section 7 for the rented pod's setup)",
    )
    parser.add_argument(
        "--ip-adapter-weight",
        type=float,
        default=DEFAULT_IP_ADAPTER_WEIGHT,
        help=f"IP-Adapter conditioning strength (default {DEFAULT_IP_ADAPTER_WEIGHT})",
    )
    parser.add_argument(
        "--pixel-lora-strength",
        type=float,
        default=DEFAULT_PIXEL_LORA_STRENGTH,
        help=f"pixel-art style LoRA strength, can exceed 1.0 to push harder "
             f"against the checkpoint's own composition tendencies (default {DEFAULT_PIXEL_LORA_STRENGTH})",
    )
    parser.add_argument(
        "--compose-with-flux",
        action="store_true",
        help="generate a stage-1 isolated composition with FLUX.1 schnell first, "
             f"then restyle it via --init-image (default denoise {DEFAULT_FLUX_RESTYLE_DENOISE}) - "
             "fixes structure-category subjects that SDXL+LoRA can't isolate on gray "
             "(requires --category/--subject; see module docstring)",
    )
    args = parser.parse_args()
    if args.host:
        set_comfy_url(args.host)

    if args.category:
        if args.prompt is not None:
            parser.error("--prompt and --category/--subject are mutually exclusive")
        if not args.subject:
            parser.error("--category requires --subject")
        templates = load_prompt_templates()
        categories = templates.get("categories", {})
        if args.category not in categories:
            parser.error(
                f"unknown category '{args.category}'; "
                f"valid categories: {', '.join(sorted(categories))}"
            )
        entry = categories[args.category]
        try:
            prompt = f"{entry['prompt_prefix']}{args.subject}{entry['prompt_suffix']}"
            width = int(entry.get("width", 1024))
            height = int(entry.get("height", 1024))
        except (KeyError, TypeError) as exc:
            parser.error(f"prompt template '{args.category}' is malformed: {exc}")
        base_negative = args.negative if args.negative is not None else DEFAULT_NEGATIVE
        additions = str(entry.get("negative_additions", "") or "").strip()
        parts = [part.strip() for part in (base_negative, additions) if part and part.strip()]
        negative = ", ".join(parts)
    elif args.subject is not None:
        parser.error("--subject requires --category")
    elif args.prompt is None:
        parser.error("give --prompt or --category/--subject")
    else:
        prompt = args.prompt
        negative = args.negative
        width = 1024 if args.width is None else args.width
        height = 1024 if args.height is None else args.height

    if args.category:
        if args.width is not None:
            width = args.width
        if args.height is not None:
            height = args.height

    if args.compose_with_flux:
        if not args.category or not args.subject:
            parser.error("--compose-with-flux requires --category/--subject")
        if args.init_image:
            parser.error("--compose-with-flux and --init-image are mutually exclusive "
                          "(--compose-with-flux generates the init image itself)")
        camera_hint = str(categories.get(args.category, {}).get("flux_camera_hint", ""))
        args.init_image = generate_flux_composition(args.subject, args.seed, width, height, camera_hint)

    if args.denoise is not None:
        denoise = args.denoise
    elif args.compose_with_flux:
        denoise = DEFAULT_FLUX_RESTYLE_DENOISE
    elif args.init_image:
        denoise = 0.55
    else:
        denoise = 1.0
    if args.steps is not None:
        steps = args.steps
    else:
        steps = FULL_QUALITY_STEPS if args.full_quality else FAST_STEPS
    if args.cfg is not None:
        cfg = args.cfg
    else:
        cfg = FULL_QUALITY_CFG if args.full_quality else FAST_CFG
    generate_image(
        prompt=prompt,
        negative=negative,
        seed=args.seed,
        steps=steps,
        cfg=cfg,
        width=width,
        height=height,
        critique=args.critique,
        init_image=args.init_image,
        denoise=denoise,
        remove_bg=args.remove_bg,
        bg_tolerance=args.bg_tolerance,
        reference_image=args.reference_image,
        ip_adapter_weight=args.ip_adapter_weight,
        full_quality=args.full_quality,
        pixel_lora_strength=args.pixel_lora_strength,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
