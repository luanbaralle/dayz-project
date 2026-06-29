#!/usr/bin/env bash
# =============================================================================
# start.sh — Inicia o DayZ Dedicated Server via Wine
# =============================================================================
# Uso: ./start.sh
# O servidor roda em sessão tmux para persistência (DAYZ_TMUX_SESSION)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

load_env
apply_env_defaults

readonly DAYZ_EXE="${DAYZ_SERVER_DIR}/DayZServer_x64.exe"

# -----------------------------------------------------------------------------
# Funções
# -----------------------------------------------------------------------------

validate_prerequisites() {
  if [[ ! -f "$DAYZ_EXE" ]]; then
    log_error "Executável não encontrado: ${DAYZ_EXE}"
    log_error "Execute install_dayz.sh primeiro."
    exit 1
  fi

  require_command wine
  require_command tmux

  if is_server_running; then
    log_warn "Servidor já está em execução (PID: $(get_server_pid))"
    log_warn "Use restart.sh para reiniciar ou stop.sh para encerrar."
    exit 1
  fi
}

start_in_tmux() {
  log_step "Iniciando DayZ Server via Wine (tmux: ${DAYZ_TMUX_SESSION})"

  ensure_dir "$DAYZ_LOGS_DIR" "${DAYZ_USER}:${DAYZ_USER}"

  # Script de lançamento temporário (evita problemas de quoting no tmux)
  local launch_script="${DAYZ_BASE}/start-dayz-inner.sh"

  cat > "$launch_script" <<LAUNCH_EOF
#!/usr/bin/env bash
set -euo pipefail
export WINEPREFIX="${WINEPREFIX}"
export WINEDEBUG="${WINEDEBUG:--all}"
cd "${DAYZ_SERVER_DIR}"
exec wine "${DAYZ_EXE}" \
  -config="${DAYZ_CONFIG}" \
  -profiles="${DAYZ_PROFILES_DIR}" \
  -port=${DAYZ_PORT} \
  $([ -n "${DAYZ_MODS:-}" ] && echo "-mod=${DAYZ_MODS}") \
  -serverMod=${DAYZ_SERVER_MODS:-} \
  ${DAYZ_EXTRA_ARGS:-} \
  2>&1 | tee -a "${DAYZ_MAIN_LOG}"
LAUNCH_EOF

  chmod +x "$launch_script"
  chown "${DAYZ_USER}:${DAYZ_USER}" "$launch_script"

  # Encerra sessão tmux anterior se existir (órfã)
  tmux kill-session -t "$DAYZ_TMUX_SESSION" 2>/dev/null || true

  # Inicia em nova sessão tmux detached
  sudo -u "$DAYZ_USER" tmux new-session -d -s "$DAYZ_TMUX_SESSION" "$launch_script"

  # Aguarda processo subir e grava PID
  sleep 5
  local pid
  pid="$(pgrep -f 'DayZServer_x64.exe' | head -n1 || true)"

  if [[ -n "$pid" ]]; then
    echo "$pid" > "$DAYZ_PID_FILE"
    chown "${DAYZ_USER}:${DAYZ_USER}" "$DAYZ_PID_FILE" 2>/dev/null || true
    log_info "Servidor iniciado — PID: ${pid}"
    log_info "Sessão tmux: ${DAYZ_TMUX_SESSION}"
    log_info "Logs: ${DAYZ_MAIN_LOG}"
    log_info "Acompanhe com: ${SCRIPT_DIR}/logs.sh"
  else
    log_error "Servidor não iniciou. Verifique logs: ${DAYZ_MAIN_LOG}"
    log_error "Verifique também: tmux attach-session -t ${DAYZ_TMUX_SESSION}"
    exit 1
  fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
  log_step "DayZ Project — Start"
  validate_prerequisites
  start_in_tmux
}

main "$@"
