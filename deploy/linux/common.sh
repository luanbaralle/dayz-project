#!/usr/bin/env bash
# =============================================================================
# common.sh — Fachada de bibliotecas (transição)
# =============================================================================
# Carrega módulos em deploy/linux/lib/. Scripts devem usar:
#   source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
# =============================================================================

set -euo pipefail

DEPLOY_LINUX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB="${DEPLOY_LINUX_DIR}/lib"

# shellcheck source=lib/log.sh
source "${_LIB}/log.sh"
# shellcheck source=lib/env.sh
source "${_LIB}/env.sh"
# shellcheck source=lib/filesystem.sh
source "${_LIB}/filesystem.sh"
# shellcheck source=lib/process.sh
source "${_LIB}/process.sh"
# shellcheck source=lib/steam.sh
source "${_LIB}/steam.sh"
# shellcheck source=lib/mods.sh
source "${_LIB}/mods.sh"
# shellcheck source=lib/validation.sh
source "${_LIB}/validation.sh"
# shellcheck source=lib/launch.sh
source "${_LIB}/launch.sh"
