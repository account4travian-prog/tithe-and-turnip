#!/usr/bin/env bash
# One-paste setup for a rented RunPod GPU pod (RTX 4090, ComfyUI template),
# for the two jobs described in design/runpod_guide.md: IP-Adapter-enabled
# generation, and SDXL LoRA training via kohya_ss.
#
# Run this INSIDE the pod's web terminal (Console -> your pod -> Connect ->
# Start Web Terminal), not on your local machine.
#
# What this does NOT do, deliberately:
# - Does not download IP-Adapter's model weights. Those need a HuggingFace
#   URL that can require an accepted license/token and changes over time;
#   printing the exact file names and where to get them once, by hand, beats
#   silently fetching a stale or wrong URL. See the printed instructions at
#   the end.
# - Does not assume ComfyUI lives at one exact path - the official template
#   has changed layout before, so this searches common locations instead of
#   hardcoding one and failing confusingly if it's wrong.
# - Does not touch billing/runtime limits - set the pod's native max-runtime
#   at creation (design/runpod_guide.md section 2.6). This script only adds
#   a second, independent cost-visibility layer (pod_guard.py), not a
#   replacement for that.

set -euo pipefail

echo "=== locating ComfyUI ==="
COMFY_DIR=""
for candidate in /workspace/ComfyUI /workspace/comfyui /root/ComfyUI /ComfyUI; do
    if [ -d "$candidate" ] && [ -f "$candidate/main.py" ]; then
        COMFY_DIR="$candidate"
        break
    fi
done
if [ -z "$COMFY_DIR" ]; then
    echo "Could not find an existing ComfyUI install in the usual spots."
    echo "Searching the filesystem once (may take a moment)..."
    FOUND=$(find / -maxdepth 4 -iname "main.py" -path "*ComfyUI*" 2>/dev/null | head -1 || true)
    if [ -n "$FOUND" ]; then
        COMFY_DIR=$(dirname "$FOUND")
    fi
fi
if [ -z "$COMFY_DIR" ]; then
    echo "FAILED: no ComfyUI install found. Are you sure this pod used the"
    echo "official ComfyUI template? Aborting rather than guessing a path."
    exit 1
fi
echo "Found ComfyUI at: $COMFY_DIR"

echo
echo "=== installing IP-Adapter (cubiq/ComfyUI_IPAdapter_plus) ==="
CUSTOM_NODES="$COMFY_DIR/custom_nodes"
mkdir -p "$CUSTOM_NODES"
if [ -d "$CUSTOM_NODES/ComfyUI_IPAdapter_plus" ]; then
    echo "already installed, skipping"
else
    git clone --depth 1 https://github.com/cubiq/ComfyUI_IPAdapter_plus.git \
        "$CUSTOM_NODES/ComfyUI_IPAdapter_plus"
    if [ -f "$CUSTOM_NODES/ComfyUI_IPAdapter_plus/requirements.txt" ]; then
        pip install -q -r "$CUSTOM_NODES/ComfyUI_IPAdapter_plus/requirements.txt"
    fi
fi

echo
echo "=== kohya_ss (SDXL LoRA training) - optional ==="
read -r -p "Clone kohya_ss for a LoRA training session? [y/N] " do_kohya
if [[ "$do_kohya" =~ ^[Yy]$ ]]; then
    KOHYA_DIR="/workspace/kohya_ss"
    if [ -d "$KOHYA_DIR" ]; then
        echo "already present at $KOHYA_DIR, skipping clone"
    else
        git clone --recursive https://github.com/bmaltais/kohya_ss.git "$KOHYA_DIR"
        echo "Cloned to $KOHYA_DIR. It has its own setup script - cd there and"
        echo "follow its README (./setup.sh or similar) before training; that"
        echo "project isn't maintained here, so this script won't duplicate it."
    fi
fi

echo
echo "=== starting the cost-visibility guard in the background ==="
GUARD_SCRIPT="$(dirname "$0")/pod_guard.py"
if [ -f "$GUARD_SCRIPT" ]; then
    nohup python3 "$GUARD_SCRIPT" --max-hours 6 --rate-per-hour 0.30 \
        > /workspace/pod_guard.log 2>&1 &
    echo "pod_guard.py running in background (PID $!), logging to /workspace/pod_guard.log"
    echo "This is a SECOND layer, not a replacement for the pod's own native"
    echo "max-runtime setting - confirm you set that at pod creation too."
else
    echo "pod_guard.py not found next to this script - copy it up manually if you want it."
fi

cat <<'EOF'

=== SETUP DONE - one manual step remains ===

IP-Adapter's model weights are NOT downloaded by this script (see the
header comment for why). Grab these once:

  1. models/clip_vision/  <- a CLIP vision encoder
       (search "IP-Adapter SDXL clip vision" on huggingface.co if the
       exact current filename has moved; this changes over time)
  2. models/ipadapter/    <- ip-adapter-plus-sdxl_vit-h.safetensors
       (from the huggingface.co/h94/IP-Adapter-plus repo family, or
       whatever cubiq/ComfyUI_IPAdapter_plus's own README currently
       points to - check ITS README for the current canonical link
       rather than trusting a URL pasted into this script months ago)

Restart ComfyUI (or use ComfyUI Manager's restart button) after placing
both files so it picks up the new custom node and models.

Then from your LOCAL machine:
  python generate.py --host https://<this-pod-id>-<comfyui-port>.proxy.runpod.net \
      --category terrain_material --subject "..." --seed 7

NOTE: the port varies by template version - check the Connect tab's "HTTP
services" list for the actual port next to ComfyUI (it has been 3000 on at
least one observed pod, not the 8188 originally assumed here - see
design/runpod_guide.md's pod session log).
EOF
