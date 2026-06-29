#!/usr/bin/env bash
# =============================================================================
# lib/steam.sh — Execução SteamCMD com autenticação segura
# =============================================================================
# STEAM_HOME  — biblioteca Steam (steamapps/, workshop/)
# STEAMCMD_DIR — binário steamcmd.sh apenas
# =============================================================================

steamcmd_bin_path() {
  echo "${STEAMCMD_DIR}/steamcmd.sh"
}

steam_steamapps_dir() {
  echo "${STEAM_HOME}/steamapps"
}

steam_workshop_content_root() {
  echo "${STEAM_HOME}/steamapps/workshop/content"
}

# Caminho de um item Workshop baixado pelo SteamCMD.
steam_workshop_item_path() {
  local workshop_id="$1"
  local app_id="$2"
  echo "$(steam_workshop_content_root)/${app_id}/${workshop_id}"
}

# Prepara STEAM_HOME e alinha ~/Steam para instalações novas.
steam_ensure_home() {
  resolve_steam_home

  local user_home user_steam
  user_home="$(dayz_user_home)"
  user_steam="${user_home}/Steam"

  ensure_owned_dir "${STEAM_HOME}/steamapps/workshop/content"

  # SteamCMD resolve a biblioteca via ~/Steam quando não há force_install_dir.
  if [[ "$STEAM_HOME" != "$user_steam" ]] && [[ ! -e "$user_steam" ]]; then
    ln -sfn "$STEAM_HOME" "$user_steam"
    chown -h "${DAYZ_USER}:${DAYZ_USER}" "$user_steam" 2>/dev/null || true
    log_info "Biblioteca Steam: ${user_steam} -> ${STEAM_HOME}"
  fi
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
  return 0
}

steamcmd_clear_password() {
  unset STEAM_PASSWORD
}

steamcmd_run() {
  local bin
  bin="$(steamcmd_bin_path)"
  local -a args=("$@")

  log_info "SteamCMD: ${STEAM_USERNAME} | lib=${STEAM_HOME} | bin=${STEAMCMD_DIR}"

  if [[ "${EUID}" -eq 0 ]]; then
    sudo -u "$DAYZ_USER" "$bin" "${args[@]}"
  else
    "$bin" "${args[@]}"
  fi
}

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

# Downloads Workshop: force_install_dir aponta para STEAM_HOME (biblioteca).
steamcmd_run_workshop_logged_in() {
  steam_ensure_home
  log_info "Workshop content root: $(steam_workshop_content_root)"
  steamcmd_run_logged_in +force_install_dir "$STEAM_HOME" "$@"
}
