#!/usr/bin/env bash
# =============================================================================
# stop.sh — Encerra o DayZ Dedicated Server
# =============================================================================
# Uso: ./stop.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

load_env
apply_env_defaults

# -----------------------------------------------------------------------------
# Funções
# -----------------------------------------------------------------------------

stop_tmux_session() {
  if tmux has-session -t "$DAYZ_TMUX_SESSION" 2>/dev/null; then
    log_info "Encerrando sessão tmux: ${DAYZ_TMUX_SESSION}"
    tmux kill-session -t "$DAYZ_TMUX_SESSION"
  fi
}

stop_server_processes() {
  local pid
  pid="$(get_server_pid)"

  if [[ -z "$pid" ]]; then
    log_info "Nenhum processo DayZ Server em execução."
    cleanup_pid_file
    return 0
  fi

  log_info "Encerrando processo DayZ (PID: ${pid})..."

  # SIGTERM gracioso
  kill -TERM "$pid" 2>/dev/null || true

  # Aguarda até 30 segundos
  local waited=0
  while kill -0 "$pid" 2>/dev/null && [[ $waited -lt 30 ]]; do
    sleep 1
    waited=$((waited + 1))
  done

  # SIGKILL se ainda estiver rodando
  if kill -0 "$pid" 2>/dev/null; then
    log_warn "Processo não respondeu ao SIGTERM — enviando SIGKILL"
    kill -KILL "$pid" 2>/dev/null || true
  fi

  # Encerra processos Wine órfãos relacionados ao DayZ
  pkill -f "DayZServer_x64.exe" 2>/dev/null || true

  log_info "Servidor encerrado."
  cleanup_pid_file
}

cleanup_pid_file() {
  if [[ -f "$DAYZ_PID_FILE" ]]; then
    rm -f "$DAYZ_PID_FILE"
  fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
  log_step "DayZ Project — Stop"

  if ! is_server_running; then
    log_info "Servidor não está em execução."
    cleanup_pid_file
    stop_tmux_session
    exit 0
  fi

  stop_tmux_session
  stop_server_processes
  log_info "Stop concluído."
}

main "$@"
