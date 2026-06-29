#!/usr/bin/env bash
# =============================================================================
# logs.sh — Exibe logs do servidor em tempo real
# =============================================================================
# Uso: ./logs.sh [arquivo]
# Sem argumentos: segue DAYZ_MAIN_LOG e logs RPT recentes nos profiles
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

find_latest_rpt() {
  find "$DAYZ_PROFILES_DIR" -maxdepth 1 -name "*.RPT" -type f -printf '%T@ %p\n' 2>/dev/null \
    | sort -rn | head -n1 | cut -d' ' -f2- || true
}

show_tmux_logs() {
  if tmux has-session -t "$DAYZ_TMUX_SESSION" 2>/dev/null; then
    log_info "Sessão tmux ativa — anexando à sessão ${DAYZ_TMUX_SESSION}"
    log_info "Pressione Ctrl+B, depois D para desanexar sem encerrar o servidor."
    echo ""
    tmux attach-session -t "$DAYZ_TMUX_SESSION"
    exit 0
  fi
}

tail_log_file() {
  local log_file="$1"

  if [[ ! -f "$log_file" ]]; then
    log_error "Arquivo de log não encontrado: ${log_file}"
    exit 1
  fi

  log_info "Seguindo: ${log_file}"
  log_info "Pressione Ctrl+C para sair."
  echo ""
  tail -f "$log_file"
}

tail_combined_logs() {
  local files=()

  if [[ -f "$DAYZ_MAIN_LOG" ]]; then
    files+=("$DAYZ_MAIN_LOG")
  fi

  local latest_rpt
  latest_rpt="$(find_latest_rpt)"
  if [[ -n "$latest_rpt" && -f "$latest_rpt" ]]; then
    files+=("$latest_rpt")
  fi

  local latest_script_log
  latest_script_log="$(find "$DAYZ_PROFILES_DIR" -maxdepth 1 -name "script_*.log" -type f -printf '%T@ %p\n' 2>/dev/null \
    | sort -rn | head -n1 | cut -d' ' -f2- || true)"
  if [[ -n "$latest_script_log" && -f "$latest_script_log" ]]; then
    files+=("$latest_script_log")
  fi

  if [[ ${#files[@]} -eq 0 ]]; then
    log_error "Nenhum arquivo de log encontrado."
    log_info "Inicie o servidor com start.sh ou especifique um arquivo: ./logs.sh /caminho/log"
    exit 1
  fi

  log_info "Seguindo ${#files[@]} arquivo(s) de log:"
  for f in "${files[@]}"; do
    log_info "  - ${f}"
  done
  log_info "Pressione Ctrl+C para sair."
  echo ""

  tail -f "${files[@]}"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
  # Se servidor está em tmux, oferece attach direto
  if [[ $# -eq 0 ]] && tmux has-session -t "$DAYZ_TMUX_SESSION" 2>/dev/null; then
    show_tmux_logs
  fi

  if [[ $# -gt 0 ]]; then
    tail_log_file "$1"
  else
    tail_combined_logs
  fi
}

main "$@"
