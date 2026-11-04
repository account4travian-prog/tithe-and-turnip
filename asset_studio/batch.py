"""Batch-generate images with GPU thermal cooldown between items.

Usage:
    python batch.py --prompts-file prompts.txt [options]
    python batch.py --prompt "prompt one" --prompt "prompt two" [options]
    python batch.py --host https://<pod-id>-<port>.proxy.runpod.net --prompts-file prompts.txt

Requires ComfyUI running. Between items the GPU must cool to <= --cool-below C
(hard gate: never starts while above --max-temp C), with a minimum --rest
second gap. Thermal cooldown is OPT-IN via --guard; without it, prompts run
back-to-back exactly as before the guard existed - and is meaningless
against a rented pod's GPU (no local thermal concern), so there's no
reason to pass --guard there. Add --critique to run the local vision
critique on each output - this always runs locally regardless of --host,
since generate.generate_image() downloads the image to this machine
before critique.py ever sees it.

--host (or the COMFY_HOST env var, checked by the generate module this
imports) points generation at a remote ComfyUI instead of the local
default - same precedence and URL shape as generate.py's own --host.
"""

import argparse
import time

import generate as gen
import gpu_guard


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--host",
        default=None,
        help="ComfyUI base URL, e.g. http://127.0.0.1:8188 (default) or "
             "https://<pod-id>-<port>.proxy.runpod.net for a rented pod. "
             "Overrides the COMFY_HOST env var, which overrides the local default.",
    )
    parser.add_argument("--prompts-file", help="text file with one prompt per line")
    parser.add_argument("--prompt", action="append", default=[], help="a prompt (repeatable)")
    parser.add_argument("--guard", action="store_true", help="enable GPU cooldown between items (off by default)")
    parser.add_argument("--max-temp", type=float, default=78.0, help="never generate above this GPU temp C (with --guard)")
    parser.add_argument("--cool-below", type=float, default=62.0, help="wait until GPU cools to this C (with --guard)")
    parser.add_argument("--rest", type=float, default=10.0, help="minimum seconds between generations (with --guard)")
    parser.add_argument("--seed", type=int, default=0, help="base seed; increments per prompt")
    parser.add_argument("--steps", type=int, default=None, help=f"default {gen.FAST_STEPS} (or {gen.FULL_QUALITY_STEPS} with --full-quality)")
    parser.add_argument("--cfg", type=float, default=None, help=f"default {gen.FAST_CFG} (or {gen.FULL_QUALITY_CFG} with --full-quality)")
    parser.add_argument(
        "--full-quality",
        action="store_true",
        help="skip the Lightning speed LoRA and sample at normal steps/cfg - "
             "see generate.py --full-quality; worth it against a rented pod's GPU",
    )
    parser.add_argument("--critique", action="store_true", help="run critique.py on each output")
    parser.add_argument("--dry-run", action="store_true", help="print the plan without generating")
    args = parser.parse_args()
    if args.host:
        gen.set_comfy_url(args.host)
    steps = args.steps if args.steps is not None else (gen.FULL_QUALITY_STEPS if args.full_quality else gen.FAST_STEPS)
    cfg = args.cfg if args.cfg is not None else (gen.FULL_QUALITY_CFG if args.full_quality else gen.FAST_CFG)

    prompts = list(args.prompt)
    if args.prompts_file:
        with open(args.prompts_file, encoding="utf-8") as f:
            prompts.extend(line.strip() for line in f if line.strip())
    if not prompts:
        parser.error("give at least one --prompt or a --prompts-file")

    guard_note = "on" if args.guard else "off (opt-in with --guard)"
    print(
        f"[batch] host {gen.COMFY_URL} | {len(prompts)} prompt(s) | GPU guard {guard_note} | "
        f"max-temp {args.max_temp}C | cool-below {args.cool_below}C | rest {args.rest}s"
    )
    for i, prompt in enumerate(prompts, 1):
        print(f"[batch] --- {i}/{len(prompts)} ---")
        if args.dry_run:
            print(f"[dry-run] would generate: {prompt}")
            continue
        if args.guard:
            print("[batch] waiting for GPU cooldown...")
            gpu_guard.wait_until_cool(cool_below=args.cool_below, max_temp=args.max_temp)
            if i > 1 and args.rest > 0:
                print(f"[batch] resting {args.rest}s...")
                time.sleep(args.rest)
        seed = args.seed + i - 1 if args.seed else 0
        path = gen.generate_image(
            prompt=prompt,
            negative=gen.DEFAULT_NEGATIVE,
            seed=seed,
            steps=steps,
            cfg=cfg,
            width=1024,
            height=1024,
            critique=args.critique,
            full_quality=args.full_quality,
        )
        gpu_label = "local GPU" if args.host is None else "local GPU, not the --host used for generation"
        print(f"[batch] done {i}/{len(prompts)} -> {path} | {gpu_label} {gpu_guard.temp_c():.0f}C")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
