"""Tier-1 QA screen: free, local, coarse. Runs BEFORE the paid art-director pass.

Usage:
    python screen.py [--dir vertical_slice_test] [--model gemma3:4b]

Asks a local Ollama vision model two narrow yes/no questions per image,
chosen because they are exactly the two failure modes this project has
actually hit (style_bible.md, Rounds 2-3):

  1. Is there ONE subject, or many/a repeating pattern?   -> tiling
  2. Is it flat cartoon art, or photorealistic?           -> style drift

Deliberately NOT asking for open-ended art critique. A 4B vision model is
unreliable at nuanced style judgement (its own earlier turnip review
hedged and mis-scored detail), but it is adequate at these two gross
binary calls - gemma3:4b correctly called our villager "flat cartoon
illustration" on a live test. Nuanced style-match against the anchors is
the art director's job (Terra), not this tier's.

Model note: qwen3.5:9b is installed but timed out on image input during
testing (2026-08-08) - do not switch to it without re-testing.
"""

import argparse
import base64
import io
import json
import os
import sys
import urllib.request

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROMPT = (
    "Look at this game asset image and answer ONLY with a JSON object, no other text:\n"
    '{"subject": "<the single main object, 1-3 words>", '
    '"count": "<one|many>", '
    '"style": "<flat_cartoon|painterly|photorealistic>", '
    '"background_plain": <true|false>}\n'
    'Use "many" if the image shows a repeating pattern or a grid of the same object. '
    'Use "photorealistic" only if it looks like a photograph or a lifelike 3D render.'
)


def ask(path: str, model: str, url: str, timeout: int) -> dict:
    img = Image.open(path).convert("RGB")
    img.thumbnail((512, 512))  # small models read downscaled art more reliably
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    body = {
        "model": model,
        "prompt": PROMPT,
        "images": [base64.b64encode(buf.getvalue()).decode()],
        "stream": False,
        "format": "json",
        "options": {"temperature": 0},
    }
    req = urllib.request.Request(
        url + "/api/generate", data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        raw = json.loads(resp.read().decode()).get("response", "")
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {"error": "non-json", "raw": raw[:200]}


def main(argv) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default="vertical_slice_test")
    ap.add_argument("--model", default="gemma3:4b")
    ap.add_argument("--url", default="http://localhost:11434")
    ap.add_argument("--timeout", type=int, default=180)
    args = ap.parse_args(argv)

    d = args.dir if os.path.isabs(args.dir) else os.path.join(HERE, args.dir)
    report_path = os.path.join(d, "batch_report.json")
    report = {}
    if os.path.isfile(report_path):
        with open(report_path, encoding="utf-8") as f:
            report = json.load(f)

    pngs = sorted(f for f in os.listdir(d) if f.lower().endswith(".png"))
    if not pngs:
        print(f"no PNGs in {d}")
        return 1

    flagged = []
    for i, name in enumerate(pngs, 1):
        aid = os.path.splitext(name)[0]
        try:
            res = ask(os.path.join(d, name), args.model, args.url, args.timeout)
        except Exception as exc:  # surfaced, never swallowed
            res = {"error": str(exc)}
        entry = report.setdefault(aid, {})
        entry["screen"] = res
        bad = []
        if res.get("count") == "many":
            bad.append("MANY/tiled")
        if res.get("style") == "photorealistic":
            bad.append("PHOTOREAL")
        if res.get("background_plain") is False:
            bad.append("busy-bg")
        if bad:
            flagged.append((aid, bad))
        print(f"[{i}/{len(pngs)}] {aid}: {res.get('subject','?')} | "
              f"{res.get('count','?')} | {res.get('style','?')} "
              f"{'<< ' + ', '.join(bad) if bad else ''}")
        with open(report_path, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=2)

    print(f"\nflagged {len(flagged)}/{len(pngs)}:")
    for aid, bad in flagged:
        print(f"  {aid}: {', '.join(bad)}")
    print(f"wrote {report_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
