#!/usr/bin/env bash
# lib/launch.sh — Montagem e execução do processo DayZ Server

launch_resolve_mod_params() {
  MOD_CLIENT_ARG="$(mods_build_client_mod_argument)"
  MOD_SERVER_ARG="$(mods_build_server_mod_argument)"
}

launch_print_mod_summary() {
  mods_print_load_order
  if [[ -n "$MOD_CLIENT_ARG" ]]; then
    log_info "Parâmetro -mod=${MOD_CLIENT_ARG}"
  else
    log_info "Nenhum mod client habilitado no manifest."
  fi
  if [[ -n "$MOD_SERVER_ARG" ]]; then
    log_info "Parâmetro -serverMod=${MOD_SERVER_ARG}"
  fi
}

launch_write_inner_script() {
  local launch_script="${DAYZ_HOME}/start-dayz-inner.sh"
  local mod_client_flag=""
  local mod_server_flag=""

  if [[ -n "$MOD_CLIENT_ARG" ]]; then
    mod_client_flag="-mod=${MOD_CLIENT_ARG}"
  fi
  if [[ -n "$MOD_SERVER_ARG" ]]; then
    mod_server_flag="-serverMod=${MOD_SERVER_ARG}"
  fi

  cat > "$launch_script" <<LAUNCH_EOF
#!/usr/bin/env bash
set -euo pipefail
export WINEPREFIX="${WINEPREFIX}"
export WINEDEBUG="${WINEDEBUG:--all}"
cd "${DAYZ_SERVER_DIR}"
exec wine "${DAYZ_SERVER_DIR}/DayZServer_x64.exe" \
  -config="${DAYZ_CONFIG}" \
  -profiles="${DAYZ_PROFILES_DIR}" \
  -port=${DAYZ_PORT} \
  ${mod_client_flag} \
  ${mod_server_flag} \
  ${DAYZ_EXTRA_ARGS:-} \
  2>&1 | tee -a "${DAYZ_MAIN_LOG}"
LAUNCH_EOF

  chmod +x "$launch_script"
  chown "${DAYZ_USER}:${DAYZ_USER}" "$launch_script"
  echo "$launch_script"
}

launch_start_tmux() {
  local launch_script="$1"

  tmux kill-session -t "$DAYZ_TMUX_SESSION" 2>/dev/null || true

  if [[ "${EUID}" -eq 0 ]]; then
    sudo -u "$DAYZ_USER" tmux new-session -d -s "$DAYZ_TMUX_SESSION" "$launch_script"
  else
    tmux new-session -d -s "$DAYZ_TMUX_SESSION" "$launch_script"
  fi

  sleep 5
  local pid
  pid="$(get_server_pid)"

  if [[ -n "$pid" ]]; then
    echo "$pid" > "$DAYZ_PID_FILE"
    chown "${DAYZ_USER}:${DAYZ_USER}" "$DAYZ_PID_FILE" 2>/dev/null || true
    log_info "Servidor iniciado — PID: ${pid}"
    log_info "tmux: ${DAYZ_TMUX_SESSION} | Logs: ${DAYZ_MAIN_LOG}"
    return 0
  fi

  log_error "Servidor não iniciou. Logs: ${DAYZ_MAIN_LOG}"
  log_error "tmux attach-session -t ${DAYZ_TMUX_SESSION}"
  return 1
}
