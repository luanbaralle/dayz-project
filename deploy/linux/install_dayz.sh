#!/usr/bin/env bash
# =============================================================================
# install_dayz.sh — Instala ou atualiza o DayZ Dedicated Server via SteamCMD
# =============================================================================
# Requer: root (sudo) + SteamCMD instalado
# Idempotente: app_update só baixa arquivos novos/alterados
# Nota: mods NÃO são instalados neste script
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

load_env 2>/dev/null || true
apply_env_defaults

readonly STEAMCMD_BIN="${STEAMCMD_DIR}/steamcmd.sh"
readonly DAYZ_EXE="${DAYZ_SERVER_DIR}/DayZServer_x64.exe"

# -----------------------------------------------------------------------------
# Funções
# -----------------------------------------------------------------------------

validate_steamcmd() {
  if [[ ! -x "$STEAMCMD_BIN" ]]; then
    log_error "SteamCMD não encontrado. Execute install_steamcmd.sh primeiro."
    exit 1
  fi
}

prepare_server_directory() {
  log_info "Preparando diretório do servidor: ${DAYZ_SERVER_DIR}"
  ensure_owned_dir "$DAYZ_SERVER_DIR"
}

install_or_update_dayz() {
  log_step "Instalando/atualizando DayZ Dedicated Server (App ID: ${DAYZ_APP_ID})"

  local platform="${STEAMCMD_PLATFORM:-windows}"

  log_info "Diretório de instalação: ${DAYZ_SERVER_DIR}"
  log_info "Plataforma SteamCMD: ${platform}"

  # SteamCMD deve rodar como DAYZ_USER
  sudo -u "$DAYZ_USER" "$STEAMCMD_BIN" \
    +@sSteamCmdForcePlatformType "$platform" \
    +force_install_dir "$DAYZ_SERVER_DIR" \
    +login anonymous \
    +app_update "$DAYZ_APP_ID" validate \
    +quit

  log_info "SteamCMD concluiu app_update."
}

verify_installation() {
  log_step "Verificando instalação do DayZ Server"

  if [[ ! -f "$DAYZ_EXE" ]]; then
    log_error "Executável não encontrado: ${DAYZ_EXE}"
    log_error "A instalação pode ter falhado. Verifique logs do SteamCMD."
    exit 1
  fi

  log_info "Executável encontrado: ${DAYZ_EXE}"

  # Lista arquivos essenciais
  local essential_files=(
    "DayZServer_x64.exe"
    "serverDZ.cfg"
    "dayzsetting.xml"
    "addons"
  )

  for item in "${essential_files[@]}"; do
    if [[ -e "${DAYZ_SERVER_DIR}/${item}" ]]; then
      log_info "  [OK] ${item}"
    else
      log_warn "  [??] ${item} (não encontrado — pode ser normal em algumas versões)"
    fi
  done
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
  require_root
  validate_steamcmd
  prepare_server_directory
  install_or_update_dayz
  verify_installation
  log_info "DayZ Dedicated Server instalado/atualizado em ${DAYZ_SERVER_DIR}"
}

main "$@"
