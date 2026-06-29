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

launch_prepare_runtime_dirs() {
  ensure_dir "$DAYZ_LOGS_DIR" "${DAYZ_USER}:${DAYZ_USER}"
  ensure_dir "$DAYZ_PROFILES_DIR" "${DAYZ_USER}:${DAYZ_USER}"
}

# Gera script de boot sem exec/pipe — wine permanece em foreground no tmux.
launch_write_inner_script() {
  local launch_script="${DAYZ_HOME}/start-dayz-inner.sh"

  cat > "$launch_script" <<LAUNCH_EOF
#!/usr/bin/env bash
# Gerado por deploy/linux/lib/launch.sh — não editar manualmente

set +e
set +o pipefail

export WINEPREFIX="${WINEPREFIX}"
export WINEARCH="${WINEARCH:-win64}"
export WINEDEBUG="${WINEDEBUG:--all}"

readonly DAYZ_EXE="${DAYZ_SERVER_DIR}/DayZServer_x64.exe"
readonly LOG_FILE="${DAYZ_MAIN_LOG}"
readonly PROFILES_DIR="${DAYZ_PROFILES_DIR}"
readonly SERVER_DIR="${DAYZ_SERVER_DIR}"
readonly MOD_CLIENT="${MOD_CLIENT_ARG}"
readonly MOD_SERVER="${MOD_SERVER_ARG}"
readonly EXTRA_ARGS="${DAYZ_EXTRA_ARGS:-}"

log_boot() {
  printf '[%s] %s\n' "\$(date +'%Y-%m-%d %H:%M:%S')" "\$*" >> "\$LOG_FILE"
}

mkdir -p "\$(dirname "\$LOG_FILE")" "\$PROFILES_DIR"
: >> "\$LOG_FILE"

log_boot "=== DayZ Server — boot ==="
log_boot "EXE=\$DAYZ_EXE"
log_boot "WINEPREFIX=\$WINEPREFIX | WINEARCH=\$WINEARCH"
log_boot "profiles=\$PROFILES_DIR"
log_boot "log=\$LOG_FILE"

if [[ ! -f "\$DAYZ_EXE" ]]; then
  log_boot "ERRO: executável não encontrado"
  exit 1
fi

cd "\$SERVER_DIR" || {
  log_boot "ERRO: cd falhou em \$SERVER_DIR"
  exit 1
}

wine_args=()
wine_args+=(-config="${DAYZ_CONFIG}")
wine_args+=(-profiles="\$PROFILES_DIR")
wine_args+=(-port=${DAYZ_PORT})
[[ -n "\$MOD_CLIENT" ]] && wine_args+=("-mod=\$MOD_CLIENT")
[[ -n "\$MOD_SERVER" ]] && wine_args+=("-serverMod=\$MOD_SERVER")
if [[ -n "\$EXTRA_ARGS" ]]; then
  # shellcheck disable=SC2206
  extra=(\$EXTRA_ARGS)
  wine_args+=("\${extra[@]}")
fi

log_boot "cmd: wine DayZServer_x64.exe \${wine_args[*]}"

run_wine_foreground() {
  # Redirecionamento direto — sem pipe/tee/exec (DayZ não escreve em stdout).
  wine "\$DAYZ_EXE" "\${wine_args[@]}" >> "\$LOG_FILE" 2>&1
}

exit_code=0
if [[ -z "\${DISPLAY:-}" ]] && command -v xvfb-run >/dev/null 2>&1; then
  log_boot "DISPLAY ausente — iniciando com xvfb-run"
  xvfb-run -a wine "\$DAYZ_EXE" "\${wine_args[@]}" >> "\$LOG_FILE" 2>&1
  exit_code=\$?
else
  log_boot "Iniciando wine em foreground"
  run_wine_foreground
  exit_code=\$?
fi

log_boot "=== processo encerrado (exit=\$exit_code) ==="
exit \$exit_code
LAUNCH_EOF

  chmod +x "$launch_script"
  chown "${DAYZ_USER}:${DAYZ_USER}" "$launch_script"
  echo "$launch_script"
}

launch_verify_log_file() {
  local waited=0
  while [[ $waited -lt 10 ]]; do
    if [[ -f "$DAYZ_MAIN_LOG" ]]; then
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done
  log_warn "Arquivo de log não criado após 10s: ${DAYZ_MAIN_LOG}"
  return 1
}

launch_start_tmux() {
  local launch_script="$1"

  tmux kill-session -t "$DAYZ_TMUX_SESSION" 2>/dev/null || true

  # bash explícito: evita ambiguidade e garante redirecionamentos do script gerado.
  if [[ "${EUID}" -eq 0 ]]; then
    sudo -u "$DAYZ_USER" tmux new-session -d -s "$DAYZ_TMUX_SESSION" \
      "bash '${launch_script}'"
  else
    tmux new-session -d -s "$DAYZ_TMUX_SESSION" "bash '${launch_script}'"
  fi

  launch_verify_log_file || true

  sleep 5
  local pid
  pid="$(get_server_pid)"

  if [[ -n "$pid" ]]; then
    echo "$pid" > "$DAYZ_PID_FILE"
    chown "${DAYZ_USER}:${DAYZ_USER}" "$DAYZ_PID_FILE" 2>/dev/null || true
    log_info "Processo Wine/DayZ detectado — PID: ${pid}"
    log_info "tmux: ${DAYZ_TMUX_SESSION}"
    log_info "Log stdout/stderr Wine: ${DAYZ_MAIN_LOG}"
    log_info "Logs do jogo (.RPT/.ADM): ${DAYZ_PROFILES_DIR}/"
    return 0
  fi

  log_error "Processo DayZ não detectado após inicialização."
  if [[ -f "$DAYZ_MAIN_LOG" ]]; then
    log_error "Últimas linhas de ${DAYZ_MAIN_LOG}:"
    tail -n 20 "$DAYZ_MAIN_LOG" >&2 || true
  else
    log_error "Log ausente: ${DAYZ_MAIN_LOG}"
  fi
  log_error "Diagnóstico: tmux attach-session -t ${DAYZ_TMUX_SESSION}"
  return 1
}
