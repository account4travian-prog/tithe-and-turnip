"""Cost-discipline guardrail for a rented GPU pod - the actual risk with
hourly billing isn't the rate, it's forgetting to stop the meter.

Run this ON THE POD (not your local machine), in the background, the
moment you finish setup. It does two independent things:

1. Prints an elapsed-cost estimate every 5 minutes to the pod's own
   console, so it's impossible to lose track of how long you've been
   running.
2. Enforces a hard wall-clock ceiling: past --max-hours it tries RunPod's
   GraphQL API to stop the pod, then falls back to `sudo poweroff`.

USE RUNPOD'S OWN NATIVE MAX-RUNTIME FEATURE AS THE PRIMARY GUARDRAIL,
NOT THIS SCRIPT. Verified 2026-08-08 via RunPod's docs: pods stop
themselves automatically when you set a runtime limit on the Edit Pod
screen (or in the Docker Command field at creation) - RunPod's own
words: "pods will be automatically stopped when you have about 10
minutes of runtime left at your chosen GPU spec." That's first-party,
platform-enforced, and doesn't depend on a script staying alive inside
your container. Set it when you create the pod. This script is a
SECOND, independent layer on top of that - cost visibility in the
console, and a same-effect backstop if you forget the native setting.

Also confirmed: your account has a default spending limit (RunPod's own
backstop, ~$80/hr across all resources as of 2026-08-08 - already far
above anything this workflow needs) visible under Billing, so a true
runaway is capped by the platform regardless of anything below.

CORRECTION from an earlier draft of this file: RUNPOD_API_KEY is NOT
auto-injected into a pod - you must set it yourself as a pod environment
variable (Runpod console -> your pod -> Edit -> Environment Variables,
or better, a Runpod "Secret" so it's not in plaintext) for the
self-stop-via-API path below to do anything. RUNPOD_POD_ID's auto-
injection is unconfirmed either way - the code below checks for both
and falls straight to the poweroff fallback if either is missing, so
nothing breaks if you skip setting the API key; you just lose that one
layer and rely on the native setting + poweroff instead.

**Test before trusting for an unattended multi-hour run.** Run with
`--max-hours 0.05` (3 minutes) once, watching the RunPod dashboard
yourself, and confirm the pod actually stops.

This is a backstop, not a substitute for stopping the pod yourself when
a job finishes - it exists for the case where a session gets abandoned
(a training run left going, a Claude Code session ending unexpectedly)
and nobody is watching the clock.

Usage (on the pod):
    python3 pod_guard.py --max-hours 4 --rate-per-hour 0.34 &
"""

import argparse
import os
import sys
import time
import urllib.error
import urllib.request
import subprocess


def runpod_stop_self() -> bool:
    api_key = os.environ.get("RUNPOD_API_KEY")
    pod_id = os.environ.get("RUNPOD_POD_ID")
    if not api_key or not pod_id:
        return False
    query = (
        "mutation { podStop(input: {podId: \"%s\"}) { id desiredStatus } }" % pod_id
    )
    req = urllib.request.Request(
        "https://api.runpod.io/graphql?api_key=" + api_key,
        data=("{\"query\": %r}" % query).encode(),
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            resp.read()
        return True
    except (urllib.error.URLError, urllib.error.HTTPError) as exc:
        print(f"[pod_guard] RunPod stop API failed: {exc}", file=sys.stderr)
        return False


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--max-hours", type=float, required=True,
                     help="hard ceiling - the pod stops itself past this, no confirmation")
    ap.add_argument("--rate-per-hour", type=float, default=0.0,
                     help="for the printed running-cost estimate only")
    ap.add_argument("--warn-at-hours", type=float, default=None,
                     help="print an extra loud warning starting at this many hours "
                          "(default: max_hours - 0.5, or half of max_hours if that's negative)")
    args = ap.parse_args()

    warn_at = args.warn_at_hours
    if warn_at is None:
        warn_at = max(args.max_hours - 0.5, args.max_hours * 0.5)

    start = time.time()
    print(f"[pod_guard] started. ceiling={args.max_hours}h rate=${args.rate_per_hour}/h "
          f"warn_at={warn_at}h", flush=True)

    while True:
        elapsed_h = (time.time() - start) / 3600.0
        cost = elapsed_h * args.rate_per_hour
        tag = "!!! " if elapsed_h >= warn_at else ""
        print(f"[pod_guard] {tag}elapsed={elapsed_h:.2f}h  est_cost=${cost:.2f}"
              f"  ({elapsed_h / args.max_hours * 100:.0f}% of ceiling)", flush=True)
        if elapsed_h >= args.max_hours:
            print(f"[pod_guard] CEILING REACHED at {elapsed_h:.2f}h - stopping pod now.",
                  flush=True)
            if not runpod_stop_self():
                print("[pod_guard] falling back to poweroff", flush=True)
                subprocess.run(["sudo", "poweroff"], check=False)
            return 0
        time.sleep(300)


if __name__ == "__main__":
    sys.exit(main())
