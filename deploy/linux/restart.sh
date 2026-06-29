#!/usr/bin/env bash
# =============================================================================
# restart.sh — Reinicia o DayZ Dedicated Server (stop + start)
# =============================================================================
# Uso: ./restart.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

# -----------------------------------------------------------------------------
# Funções
# -----------------------------------------------------------------------------

run_stop() {
  log_info "Executando stop..."
  bash "${SCRIPT_DIR}/stop.sh"
}

run_start() {
  log_info "Aguardando 3 segundos antes de reiniciar..."
  sleep 3
  log_info "Executando start..."
  bash "${SCRIPT_DIR}/start.sh"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
  log_step "DayZ Project — Restart"
  run_stop
  run_start
  log_info "Restart concluído."
}

main "$@"
