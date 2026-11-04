"""Submit a reproducible FLUX.1-schnell game-asset proof to local ComfyUI."""

from __future__ import annotations

import argparse
import json
import time
import urllib.error
import urllib.request
from pathlib import Path


CHECKPOINT_NAME: str = "flux1-schnell-fp8.safetensors"
LORA_NAME: str = "flux_2d_game_assets_game_assets_v3.safetensors"
DEFAULT_ENDPOINT: str = "http://127.0.0.1:8188"


def _request_json(url: str, payload: dict[str, object] | None = None) -> dict[str, object]:
    data: bytes | None = None
    headers: dict[str, str] = {}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=data, headers=headers, method="POST" if data else "GET")
    with urllib.request.urlopen(request, timeout=30) as response:
        decoded: object = json.loads(response.read().decode("utf-8"))
    if not isinstance(decoded, dict):
        raise RuntimeError(f"Expected a JSON object from {url}")
    return decoded


def _workflow(subject: str, prefix: str, seed: int, lora_strength: float) -> dict[str, object]:
    prompt: str = (
        "single isolated game asset illustration of "
        + subject
        + ", flat cel-shaded medieval farming-game style, bold dark outlines, "
        "three-quarter dimetric view with two wall faces and roof slopes visible, "
        "centered and filling most of the frame, plain flat gray background, no text"
    )
    return {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": CHECKPOINT_NAME}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["1", 1]}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"text": "", "clip": ["1", 1]}},
        "6": {"class_type": "EmptyLatentImage", "inputs": {"width": 1024, "height": 1024, "batch_size": 1}},
        "7": {
            "class_type": "KSampler",
            "inputs": {
                "seed": seed,
                "steps": 4,
                "cfg": 1.0,
                "sampler_name": "euler",
                "scheduler": "simple",
                "denoise": 1.0,
                "model": ["10", 0],
                "positive": ["4", 0],
                "negative": ["5", 0],
                "latent_image": ["6", 0],
            },
        },
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["7", 0], "vae": ["1", 2]}},
        "9": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": prefix}},
        "10": {
            "class_type": "LoraLoaderModelOnly",
            "inputs": {"model": ["1", 0], "lora_name": LORA_NAME, "strength_model": lora_strength},
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--subject", required=True)
    parser.add_argument("--prefix", required=True)
    parser.add_argument("--seed", type=int, required=True)
    parser.add_argument("--lora-strength", type=float, default=1.0)
    parser.add_argument("--endpoint", default=DEFAULT_ENDPOINT)
    parser.add_argument("--timeout-seconds", type=int, default=900)
    parser.add_argument("--metadata", type=Path, required=True)
    arguments = parser.parse_args()

    workflow: dict[str, object] = _workflow(
        arguments.subject, arguments.prefix, arguments.seed, arguments.lora_strength
    )
    queued: dict[str, object] = _request_json(f"{arguments.endpoint}/prompt", {"prompt": workflow})
    prompt_id: object = queued.get("prompt_id")
    if not isinstance(prompt_id, str) or not prompt_id:
        raise RuntimeError(f"ComfyUI did not return a prompt ID: {queued}")

    deadline: float = time.monotonic() + arguments.timeout_seconds
    history: dict[str, object] = {}
    while time.monotonic() < deadline:
        history_payload: dict[str, object] = _request_json(f"{arguments.endpoint}/history/{prompt_id}")
        candidate: object = history_payload.get(prompt_id)
        if isinstance(candidate, dict) and candidate.get("status", {}).get("status_str") == "success":
            history = candidate
            break
        time.sleep(2.0)
    if not history:
        raise TimeoutError(f"ComfyUI did not finish prompt {prompt_id} within {arguments.timeout_seconds} seconds")

    record: dict[str, object] = {
        "backend": "ComfyUI",
        "base_model": CHECKPOINT_NAME,
        "lora": LORA_NAME,
        "lora_strength": arguments.lora_strength,
        "seed": arguments.seed,
        "steps": 4,
        "cfg": 1.0,
        "sampler": "euler",
        "scheduler": "simple",
        "width": 1024,
        "height": 1024,
        "subject": arguments.subject,
        "prefix": arguments.prefix,
        "prompt_id": prompt_id,
        "history": history,
    }
    arguments.metadata.parent.mkdir(parents=True, exist_ok=True)
    arguments.metadata.write_text(json.dumps(record, indent=2), encoding="utf-8")
    print(json.dumps({"prompt_id": prompt_id, "metadata": str(arguments.metadata)}, indent=2))


if __name__ == "__main__":
    try:
        main()
    except urllib.error.URLError as error:
        raise SystemExit(f"ComfyUI endpoint unavailable: {error}") from error
