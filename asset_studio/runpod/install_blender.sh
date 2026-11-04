#!/usr/bin/env bash
# Install the pinned official Blender LTS build used to validate TRELLIS GLBs.

set -euo pipefail

readonly BLENDER_VERSION="4.5.12"
readonly BLENDER_ARCHIVE="blender-${BLENDER_VERSION}-linux-x64.tar.xz"
readonly BLENDER_SHA256="95e3a2dfedba3bd32ca54fc355eac6b15a11986954ccb02815a07535d0120a25"
readonly BLENDER_URL="https://download.blender.org/release/Blender4.5/${BLENDER_ARCHIVE}"
readonly WORKSPACE_ROOT="/workspace"
readonly INSTALL_ROOT="${WORKSPACE_ROOT}/blender-${BLENDER_VERSION}-linux-x64"
readonly DOWNLOAD_PATH="/tmp/${BLENDER_ARCHIVE}"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
    libice6 \
    libsm6 \
    libxkbcommon0

if [ ! -x "${INSTALL_ROOT}/blender" ]; then
    curl --fail --location --retry 3 --output "${DOWNLOAD_PATH}" "${BLENDER_URL}"
    printf '%s  %s\n' "${BLENDER_SHA256}" "${DOWNLOAD_PATH}" | sha256sum --check --strict
    tar --extract --xz --file "${DOWNLOAD_PATH}" --directory "${WORKSPACE_ROOT}" --no-same-owner
fi

ln -sfn "${INSTALL_ROOT}" "${WORKSPACE_ROOT}/blender"
"${WORKSPACE_ROOT}/blender/blender" --background --version

{
    printf 'blender_version=%s\n' "${BLENDER_VERSION}"
    printf 'archive_sha256=%s\n' "${BLENDER_SHA256}"
    printf 'source_url=%s\n' "${BLENDER_URL}"
} > "${WORKSPACE_ROOT}/blender_install_manifest.txt"
