"""Local image critique: deterministic palette checks + Ollama vision critique.

Usage:
    python critique.py image1.png [image2.png ...]
    python critique.py --host http://localhost:11435 image1.png [image2.png ...]

Writes one JSON report per image into reviews/ and prints a readable summary.
Requires Pillow. Talks to Ollama at config.json's ollama_url by default;
--host overrides it (e.g. an SSH tunnel to a rented pod's Ollama - see
design/runpod_guide.md for how that's set up). The deterministic palette
checks never need Ollama and always run locally regardless of --host.
"""

import argparse
import base64
import json
import os
import sys
import urllib.error
import urllib.request
from collections import Counter
from datetime import datetime

from PIL import Image


def load_config() -> dict:
    here = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(here, "config.json"), encoding="utf-8") as f:
        return json.load(f)


def _ollama_error_text(exc: urllib.error.HTTPError) -> str:
    """Include Ollama's response body so a 400/500 isn't just a bare status."""
    try:
        body = exc.read().decode("utf-8", errors="replace")
    except Exception:
        body = ""
    detail = f": {body[:2000]}" if body else ""
    return f"HTTP {exc.code} {exc.reason}{detail}"


def hex_color(rgb: tuple) -> str:
    return "#{:02x}{:02x}{:02x}".format(*rgb)


def deterministic_checks(path: str, cfg: dict) -> dict:
    img = Image.open(path)
    rgb = img.convert("RGB")
    colors = rgb.getcolors(maxcolors=2_000_000)
    if colors is None:
        raise ValueError("image has too many unique colors to be clean pixel art")
    total = sum(c for c, _ in colors)
    top = sorted(colors, reverse=True)[: cfg["top_colors"]]
    top_colors = [
        {"hex": hex_color(color), "count": count, "coverage_pct": round(100.0 * count / total, 2)}
        for count, color in top
    ]
    allowed = {c.strip().lower().lstrip("#") for c in cfg.get("allowed_palette", [])}
    off_palette = []
    if allowed:
        for count, color in top:
            h = hex_color(color).lstrip("#").lower()
            if h not in allowed:
                off_palette.append({"hex": hex_color(color), "count": count})
    return {
        "file": os.path.basename(path),
        "size_px": list(rgb.size),
        "aspect": round(rgb.size[0] / rgb.size[1], 3),
        "unique_colors": len(colors),
        "top_colors": top_colors,
        "off_palette": off_palette,
    }


def vision_critique(path: str, cfg: dict) -> dict:
    with open(path, "rb") as f:
        b64 = base64.b64encode(f.read()).decode()
    body = {
        "model": cfg["critic_model"],
        "prompt": cfg["critic_prompt"],
        "images": [b64],
        "stream": False,
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
    return {"model": cfg["critic_model"], "response": data.get("response", "")}


def main(argv: list) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default=None, help="Ollama base URL override, e.g. http://localhost:11435 (an SSH tunnel to a rented pod)")
    parser.add_argument("images", nargs="*")
    args = parser.parse_args(argv)

    cfg = load_config()
    if args.host:
        cfg["ollama_url"] = args.host.rstrip("/")
    if not args.images:
        print(__doc__)
        return 1
    review_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), cfg["review_dir"])
    os.makedirs(review_dir, exist_ok=True)
    for path in args.images:
        if not os.path.isfile(path):
            print(f"SKIP (not a file): {path}")
            continue
        try:
            det = deterministic_checks(path, cfg)
        except Exception as exc:  # noqa: BLE001 - report and continue
            print(f"FAIL deterministic {path}: {exc}")
            continue
        try:
            vis = vision_critique(path, cfg)
        except Exception as exc:  # noqa: BLE001
            vis = {"model": cfg["critic_model"], "error": str(exc)}
        report = {
            "timestamp": datetime.now().isoformat(timespec="seconds"),
            "deterministic": det,
            "vision": vis,
        }
        base = os.path.splitext(os.path.basename(path))[0]
        out = os.path.join(review_dir, base + ".json")
        with open(out, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=2)
        print(f"== {path}")
        print(f"   size {det['size_px']}  aspect {det['aspect']}  unique colors {det['unique_colors']}")
        print("   palette: " + ", ".join(f"{c['hex']} {c['coverage_pct']}%" for c in det["top_colors"]))
        if det["off_palette"]:
            print("   OFF-PALETTE: " + ", ".join(c["hex"] for c in det["off_palette"]))
        if "error" in vis:
            print(f"   vision: ERROR {vis['error']}")
        else:
            print(f"   vision ({vis['model']}): {vis['response'][:400]}")
        print(f"   -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
