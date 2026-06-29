#!/usr/bin/env bash
# =============================================================================
# lib/steam.sh — Execução SteamCMD com autenticação segura
# =============================================================================

# Requer: common.sh carregado (log_*, STEAM_*, DAYZ_USER, STEAMCMD_DIR)

steamcmd_bin_path() {
  echo "${STEAMCMD_DIR}/steamcmd.sh"
}

steamcmd_require() {
  local bin
  bin="$(steamcmd_bin_path)"
  if [[ ! -x "$bin" ]]; then
    log_error "SteamCMD não encontrado: ${bin}"
    exit 1
  fi
}

steamcmd_require_username() {
  unset STEAM_PASSWORD STEAM_GUARD
  if [[ -z "${STEAM_USERNAME:-}" ]]; then
    log_error "STEAM_USERNAME não configurado em ${DAYZ_ENV_FILE}"
    print_steam_auth_help
    exit 1
  fi
}

steamcmd_prompt_password_if_needed() {
  if [[ -n "${STEAM_PASSWORD:-}" ]]; then
    return 0
  fi
  if [[ -t 0 ]]; then
    log_info "Senha Steam necessária (não será armazenada)."
    echo -n "Senha Steam (${STEAM_USERNAME}): " >&2
    read -rs STEAM_PASSWORD
    echo >&2
    if [[ -z "${STEAM_PASSWORD:-}" ]]; then
      log_error "Senha não informada."
      exit 1
    fi
    return 0
  fi
  # Sem TTY: tenta autenticação em cache
  return 0
}

steamcmd_clear_password() {
  unset STEAM_PASSWORD
}

# Executa SteamCMD como DAYZ_USER.
# Uso: steamcmd_run +login ... +workshop_download_item ... +quit
steamcmd_run() {
  local bin
  bin="$(steamcmd_bin_path)"
  local -a args=("$@")

  log_info "SteamCMD: ${STEAM_USERNAME}@${STEAMCMD_DIR}"

  if [[ "${EUID}" -eq 0 ]]; then
    sudo -u "$DAYZ_USER" "$bin" "${args[@]}"
  else
    "$bin" "${args[@]}"
  fi
}

# Monta argumentos +login e executa comandos SteamCMD.
# Variável STEAM_PASSWORD em memória é opcional (primeira autenticação).
steamcmd_run_logged_in() {
  local -a steam_args=()
  local platform="${STEAM_PLATFORM:-${STEAMCMD_PLATFORM:-windows}}"

  steamcmd_require
  steamcmd_require_username

  steam_args+=(+@sSteamCmdForcePlatformType "$platform")

  if [[ -n "${STEAM_PASSWORD:-}" ]]; then
    steam_args+=(+login "$STEAM_USERNAME" "$STEAM_PASSWORD")
  else
    steam_args+=(+login "$STEAM_USERNAME")
  fi

  steam_args+=("$@")
  steam_args+=(+quit)

  steamcmd_run "${steam_args[@]}"
  steamcmd_clear_password
}
