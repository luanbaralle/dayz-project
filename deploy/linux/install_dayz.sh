#!/usr/bin/env bash
# =============================================================================
# install_dayz.sh — Instala ou atualiza o DayZ Dedicated Server via SteamCMD
# =============================================================================
# Requer: root (sudo) + SteamCMD instalado + STEAM_USERNAME no .env
# Segurança: senha Steam NUNCA é armazenada — solicitada interativamente na
#            primeira instalação; atualizações usam autenticação em cache.
# Idempotente: app_update só baixa arquivos novos/alterados
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

load_env
apply_env_defaults

# Nunca usar senha persistida em arquivo (mesmo em .env legado)
unset STEAM_PASSWORD STEAM_GUARD

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

validate_steam_username() {
  if has_steam_username; then
    log_info "Conta Steam configurada: ${STEAM_USERNAME}"
    return 0
  fi

  log_error "STEAM_USERNAME não configurado em ${DAYZ_ENV_FILE}"
  print_steam_auth_help
  exit 1
}

require_interactive_terminal() {
  if [[ ! -t 0 ]]; then
    log_error "Terminal interativo necessário para informar a senha Steam."
    log_error "Execute diretamente: sudo ${SCRIPT_DIR}/install_dayz.sh"
    exit 1
  fi
}

prompt_steam_password() {
  require_interactive_terminal

  log_info "A senha não será exibida nem armazenada em disco."
  echo -n "Senha Steam (${STEAM_USERNAME}): " >&2
  read -rs STEAM_PASSWORD
  echo >&2

  if [[ -z "${STEAM_PASSWORD:-}" ]]; then
    log_error "Senha não informada."
    exit 1
  fi
}

clear_steam_password() {
  unset STEAM_PASSWORD
}

prepare_server_directory() {
  log_info "Preparando diretório do servidor: ${DAYZ_SERVER_DIR}"
  ensure_owned_dir "$DAYZ_SERVER_DIR"
}

run_steamcmd() {
  local platform="${STEAM_PLATFORM:-${STEAMCMD_PLATFORM:-windows}}"
  local -a steamcmd_args=(
    +@sSteamCmdForcePlatformType "$platform"
    +force_install_dir "$DAYZ_SERVER_DIR"
  )

  # Login: com senha (primeira instalação) ou apenas usuário (auth em cache)
  if [[ -n "${STEAM_PASSWORD:-}" ]]; then
    steamcmd_args+=(+login "$STEAM_USERNAME" "$STEAM_PASSWORD")
  else
    steamcmd_args+=(+login "$STEAM_USERNAME")
  fi

  steamcmd_args+=(
    +app_update "$DAYZ_APP_ID" validate
    +quit
  )

  log_info "Diretório de instalação: ${DAYZ_SERVER_DIR}"
  log_info "Plataforma SteamCMD: ${platform}"
  log_info "Conta Steam: ${STEAM_USERNAME}"

  # SteamCMD interativo: permite Steam Guard na primeira autenticação
  sudo -u "$DAYZ_USER" "$STEAMCMD_BIN" "${steamcmd_args[@]}"

  log_info "SteamCMD concluiu app_update."
}

install_or_update_dayz() {
  log_step "Instalando/atualizando DayZ Dedicated Server (App ID: ${DAYZ_APP_ID})"

  if is_dayz_installed; then
    log_info "Servidor já instalado — usando autenticação em cache do SteamCMD."
    run_steamcmd
    return 0
  fi

  log_info "Primeira instalação — senha será solicitada interativamente."
  log_info "Se a conta usar Steam Guard, o SteamCMD solicitará o código."
  prompt_steam_password
  run_steamcmd
  clear_steam_password
}

verify_installation() {
  log_step "Verificando instalação do DayZ Server"

  if [[ ! -f "$DAYZ_EXE" ]]; then
    log_error "Executável não encontrado: ${DAYZ_EXE}"
    log_error "A instalação pode ter falhado. Verifique:"
    log_error "  - STEAM_USERNAME em ${DAYZ_ENV_FILE}"
    log_error "  - A conta possui licença do DayZ Dedicated Server"
    log_error "  - Steam Guard (informado interativamente na primeira autenticação)"
    exit 1
  fi

  log_info "Executável encontrado: ${DAYZ_EXE}"

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
  validate_steam_username
  prepare_server_directory
  install_or_update_dayz
  verify_installation
  clear_steam_password
  log_info "DayZ Dedicated Server instalado/atualizado em ${DAYZ_SERVER_DIR}"
}

main "$@"
