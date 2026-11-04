"""Local art catalog: tags and describes a folder of downloaded tile/sprite art.

Usage:
    python catalog.py <folder> [--out art_catalog.json] [--ext png,jpg,jpeg] [--model NAME]

Walks <folder> recursively, runs the same deterministic checks as critique.py
plus a cataloguing vision prompt against each image, and writes one combined
manifest keyed by relative path so future sessions can grep tags/descriptions
instead of re-viewing every file. Incremental: reruns skip entries already
catalogued successfully, so an interrupted batch resumes where it left off.

Requires Pillow and a running Ollama at config.json's ollama_url. Defaults to
gemma3:4b (confirmed working via critique.py, ~30s/image on a GTX 1070) -
qwen2.5vl:3b is known to hang on image input via /api/generate, see
DEVELOPMENT_STATE.md's "Local asset-generation studio" entry.
"""

import argparse
import base64
import io
import json
import os
import sys
import urllib.error
import urllib.request

from PIL import Image

from critique import deterministic_checks, load_config


def _ollama_error_text(exc: urllib.error.HTTPError) -> str:
    """Include Ollama's response body so a 400/500 isn't just a bare status."""
    try:
        body = exc.read().decode("utf-8", errors="replace")
    except Exception:
        body = ""
    detail = f": {body[:2000]}" if body else ""
    return f"HTTP {exc.code} {exc.reason}{detail}"

CATALOG_PROMPT = (
    "You are cataloguing a folder of downloaded 2D game tile/sprite art for a "
    "dimetric farming game. First look carefully at the whole image - its "
    "shapes, colors, and any repeating edges - then fill in the fields below. "
    "Respond with ONLY a JSON object, no other text, matching this shape: "
    '{"description": "<one sentence, what is depicted>", '
    '"tags": ["<lowercase keyword>", ...], '
    '"category": "<one of terrain, crop, building, prop, character, ui, item, other>", '
    '"perspective": "<one of top_down, isometric, dimetric, side_view, unclear>", '
    '"tileable": <true or false - does it look like a seamless/edge-matching tile>, '
    '"notes": "<anything relevant - part of a set, has transparency, style quirks>"}'
    " If unsure about a field, give your best guess rather than omitting it."
)


def prepare_image_b64(path: str, min_side: int = 256, max_side: int = 512) -> str:
    """Nearest-neighbour upscale small pixel art before sending to the vision
    model - per asset_studio/pro_v4pro.md's V4 Pro research, 3-4B vision
    models read tiny source tiles (Kenney packs are often 16-48px) much more
    reliably at 256-512px than at native resolution."""
    img = Image.open(path).convert("RGB")
    w, h = img.size
    short = min(w, h)
    if short < min_side:
        scale = max(2, round(min_side / short))
        new_w, new_h = w * scale, h * scale
        if max(new_w, new_h) > max_side * 2:
            factor = (max_side * 2) / max(new_w, new_h)
            new_w, new_h = max(1, int(new_w * factor)), max(1, int(new_h * factor))
        img = img.resize((new_w, new_h), Image.NEAREST)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode()


def catalog_one(path: str, cfg: dict, model: str, prompt: str) -> dict:
    body = {
        "model": model,
        "prompt": prompt,
        "images": [prepare_image_b64(path)],
        "stream": False,
        "format": "json",
        "options": {"temperature": 0},
    }
    req = urllib.request.Request(
        cfg["ollama_url"] + "/api/generate",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=cfg.get("timeout_seconds", 300)) as resp:
            data = json.loads(resp.read().decode())
    except urllib.error.HTTPError as exc:
        raise RuntimeError("Ollama /api/generate failed: " + _ollama_error_text(exc)) from exc
    except urllib.error.URLError as exc:
        raise RuntimeError("Ollama unreachable: " + str(exc.reason)) from exc
    raw = data.get("response", "")
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {"error": "model did not return valid JSON", "raw": raw}


def find_images(folder: str, exts: set) -> list:
    out = []
    for root, _dirs, files in os.walk(folder):
        for name in files:
            if os.path.splitext(name)[1].lower().lstrip(".") in exts:
                out.append(os.path.join(root, name))
    return sorted(out)


def main(argv: list) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("folder", help="Directory of downloaded art to catalog (searched recursively)")
    parser.add_argument("--out", default="art_catalog.json")
    parser.add_argument("--ext", default="png,jpg,jpeg")
    parser.add_argument("--model", default=None, help="Override the Ollama model (default: config catalog_model, else gemma3:4b)")
    args = parser.parse_args(argv)

    cfg = load_config()
    model = args.model or cfg.get("catalog_model", "gemma3:4b")
    prompt = cfg.get("catalog_prompt") or CATALOG_PROMPT
    exts = {e.strip().lower().lstrip(".") for e in args.ext.split(",")}

    here = os.path.dirname(os.path.abspath(__file__))
    out_path = args.out if os.path.isabs(args.out) else os.path.join(here, args.out)

    manifest = {}
    if os.path.isfile(out_path):
        with open(out_path, encoding="utf-8") as f:
            manifest = json.load(f)

    images = find_images(args.folder, exts)
    if not images:
        print(f"No images found under {args.folder} with extensions {sorted(exts)}")
        return 1

    print(f"Cataloging {len(images)} image(s) with model '{model}' -> {out_path}")
    for i, path in enumerate(images, 1):
        rel = os.path.relpath(path, args.folder)
        existing = manifest.get(rel)
        if existing and "error" not in existing.get("vision", {}):
            print(f"[{i}/{len(images)}] SKIP (already catalogued): {rel}")
            continue
        print(f"[{i}/{len(images)}] {rel} ...", end=" ", flush=True)
        try:
            det = deterministic_checks(path, cfg)
        except Exception as exc:  # noqa: BLE001 - report and continue
            print(f"FAIL deterministic: {exc}")
            continue
        try:
            vis = catalog_one(path, cfg, model, prompt)
        except Exception as exc:  # noqa: BLE001
            vis = {"error": str(exc)}
        manifest[rel] = {"deterministic": det, "vision": vis}
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(manifest, f, indent=2)
        if "error" in vis:
            print(f"ERROR {vis['error']}")
        else:
            print(f"{vis.get('category', '?')} [{', '.join(vis.get('tags', [])[:5])}]")

    print(f"\nWrote {out_path} ({len(manifest)} entries)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
