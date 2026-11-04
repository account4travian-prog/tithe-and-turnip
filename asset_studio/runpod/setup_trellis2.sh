#!/usr/bin/env bash
# Reproducible TRELLIS.2 proof environment for the project's RunPod A100 pod.
# Irreplaceable/heavy artifacts live under /workspace. The disposable Python
# environment and build products stay on the pod's faster container disk: the
# MooseFS network volume stalled indefinitely while unpacking PyTorch wheels.

set -euo pipefail

readonly WORKSPACE_ROOT="/workspace"
readonly TRELLIS_ROOT="${WORKSPACE_ROOT}/TRELLIS.2"
readonly VENV_ROOT="/opt/trellis2_env"
# Markers describe container-local packages, so they must disappear with the
# disposable container. Persisting them would incorrectly skip a rebuild after
# RunPod stops and recreates the pod filesystem.
readonly MARKER_ROOT="/opt/trellis2_setup_markers"
readonly TRELLIS_COMMIT="75fbf0183001ed9876c8dbb35de6b68552ee08bd"

export CUDA_HOME="/usr/local/cuda-12.4"
export PATH="${CUDA_HOME}/bin:${VENV_ROOT}/bin:${PATH}"
export LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${LD_LIBRARY_PATH:-}"
export HF_HOME="${WORKSPACE_ROOT}/huggingface"
export TMPDIR="/tmp/trellis2-build"
export PIP_NO_CACHE_DIR="1"
export MAX_JOBS="8"
export CMAKE_BUILD_PARALLEL_LEVEL="8"
export TORCH_CUDA_ARCH_LIST="8.0"

mkdir -p "${MARKER_ROOT}" "${HF_HOME}" "${TMPDIR}"

if [ ! -f "${MARKER_ROOT}/system_packages.ok" ]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        git \
        git-lfs \
        libegl1 \
        libgl1 \
        libglib2.0-0 \
        libjpeg-dev \
        libxi6 \
        libxrender1 \
        libxxf86vm1 \
        python3.10-dev \
        python3.10-venv \
        sudo \
        wget
    touch "${MARKER_ROOT}/system_packages.ok"
fi

if [ ! -x "${VENV_ROOT}/bin/python" ]; then
    python3.10 -m venv "${VENV_ROOT}"
fi

# shellcheck disable=SC1091
source "${VENV_ROOT}/bin/activate"

if [ ! -f "${MARKER_ROOT}/python_base.ok" ]; then
    python -m pip install --no-cache-dir \
        pip==25.1.1 \
        setuptools==80.9.0 \
        wheel==0.45.1
    python -m pip install --no-cache-dir \
        torch==2.6.0 \
        torchvision==0.21.0 \
        --index-url https://download.pytorch.org/whl/cu124
    touch "${MARKER_ROOT}/python_base.ok"
fi

if [ ! -d "${TRELLIS_ROOT}/.git" ]; then
    git clone --recursive https://github.com/microsoft/TRELLIS.2.git \
        "${TRELLIS_ROOT}"
fi

git -C "${TRELLIS_ROOT}" fetch origin "${TRELLIS_COMMIT}"
git -C "${TRELLIS_ROOT}" checkout --detach "${TRELLIS_COMMIT}"
git -C "${TRELLIS_ROOT}" submodule update --init --recursive

cd "${TRELLIS_ROOT}"

run_setup_stage() {
    local marker_name="$1"
    local setup_flag="$2"
    if [ -f "${MARKER_ROOT}/${marker_name}.ok" ]; then
        return
    fi
    # Microsoft's setup script is intended to be sourced into the selected
    # environment. We create that environment ourselves so it persists at an
    # explicit path and omit the script's name-based --new-env step.
    # shellcheck disable=SC1091
    source ./setup.sh "${setup_flag}"
    touch "${MARKER_ROOT}/${marker_name}.ok"
}

run_setup_stage "basic" "--basic"
run_setup_stage "flash_attn" "--flash-attn"
run_setup_stage "nvdiffrast" "--nvdiffrast"
run_setup_stage "nvdiffrec" "--nvdiffrec"
run_setup_stage "cumesh" "--cumesh"
run_setup_stage "o_voxel" "--o-voxel"
run_setup_stage "flexgemm" "--flexgemm"

python - <<'PY'
import torch

assert torch.cuda.is_available(), "PyTorch cannot see the A100"
assert torch.version.cuda == "12.4", torch.version.cuda
print(torch.__version__)
print(torch.cuda.get_device_name(0))
PY

{
    printf 'trellis_commit=%s\n' "$(git -C "${TRELLIS_ROOT}" rev-parse HEAD)"
    printf 'python=%s\n' "$(python --version 2>&1)"
    printf 'pip=%s\n' "$(python -m pip --version)"
    printf 'torch=%s\n' "$(python -c 'import torch; print(torch.__version__)')"
    printf 'cuda=%s\n' "$(python -c 'import torch; print(torch.version.cuda)')"
    printf 'gpu=%s\n' "$(python -c 'import torch; print(torch.cuda.get_device_name(0))')"
} > "${WORKSPACE_ROOT}/trellis2_install_manifest.txt"

du -sh "${TRELLIS_ROOT}" "${VENV_ROOT}" "${HF_HOME}"
printf 'TRELLIS2_SETUP_COMPLETE\n'
