#!/usr/bin/env bash
# Recreate the previously validated FLUX.1-schnell + game-assets LoRA service.
# The ComfyUI application and model cache intentionally live in separate trees:
# re-cloning the app must never delete the costly persistent checkpoint cache.
set -euo pipefail

WORKSPACE_ROOT="/workspace"
COMFY_APP_ROOT="${WORKSPACE_ROOT}/ComfyUI_app"
MODEL_ROOT="${WORKSPACE_ROOT}/ComfyUI/models"
PYTHON_BIN="/opt/trellis2_env/bin/python"
CHECKPOINT_PATH="${MODEL_ROOT}/checkpoints/flux1-schnell-fp8.safetensors"
LORA_PATH="${MODEL_ROOT}/loras/flux_2d_game_assets_game_assets_v3.safetensors"

if [[ ! -x "${PYTHON_BIN}" ]]; then
    echo "Missing ${PYTHON_BIN}. Run setup_trellis2.sh first to restore the container-local Python runtime." >&2
    exit 1
fi

if [[ -e "${COMFY_APP_ROOT}" && ! -d "${COMFY_APP_ROOT}/.git" ]]; then
    echo "Refusing to overwrite non-git ComfyUI application path: ${COMFY_APP_ROOT}" >&2
    exit 1
fi
if [[ ! -d "${COMFY_APP_ROOT}/.git" ]]; then
    git clone --depth 1 --branch v0.7.0 https://github.com/comfyanonymous/ComfyUI.git "${COMFY_APP_ROOT}"
fi

if [[ ! -s "${CHECKPOINT_PATH}" ]]; then
    echo "Missing FLUX checkpoint: ${CHECKPOINT_PATH}" >&2
    exit 1
fi
if [[ ! -s "${LORA_PATH}" ]]; then
    echo "Missing game-assets LoRA: ${LORA_PATH}" >&2
    exit 1
fi

cat > "${COMFY_APP_ROOT}/extra_model_paths.yaml" <<EOF
tithe_turnip:
  base_path: ${MODEL_ROOT}
  checkpoints: checkpoints
  loras: loras
EOF

cd "${COMFY_APP_ROOT}"
git rev-parse --verify HEAD
"${PYTHON_BIN}" -m pip install --upgrade-strategy only-if-needed -r requirements.txt

"${PYTHON_BIN}" - <<'PY'
import torch

assert torch.cuda.is_available(), "CUDA is required for the FLUX proof"
print(f"torch={torch.__version__}")
print(f"gpu={torch.cuda.get_device_name(0)}")
PY

echo "FLUX_2D_SETUP_COMPLETE"
echo "Launch with: cd ${COMFY_APP_ROOT} && ${PYTHON_BIN} main.py --listen 127.0.0.1 --port 8188"
