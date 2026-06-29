#!/usr/bin/env bash
# =============================================================================
# start.sh — Inicia o DayZ Dedicated Server via Wine
# =============================================================================
# Responsabilidade única: iniciar o processo do servidor.
# NÃO executa: deploy, git, SteamCMD, install_mods
#
# Fase 3: totalmente dirigido por mods/manifest.yaml (sem DAYZ_MODS no .env)
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

  mods_require_manifest
}

run_pre_start_validation() {
  log_step "Validação pré-start"
  if ! validation_run true; then
    log_error "Corrija os erros com: ${SCRIPT_DIR}/validate.sh"
    exit 1
  fi
  log_info "Validação aprovada."
}

start_in_tmux() {
  log_step "Iniciando DayZ Server via Wine (tmux: ${DAYZ_TMUX_SESSION})"

  launch_resolve_mod_params
  launch_print_mod_summary

  launch_prepare_runtime_dirs

  local launch_script
  launch_script="$(launch_write_inner_script)"

  if launch_start_tmux "$launch_script"; then
    log_info "Acompanhe com: ${SCRIPT_DIR}/logs.sh"
  else
    exit 1
  fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
  log_step "DayZ Project — Start"
  validate_prerequisites
  run_pre_start_validation
  start_in_tmux
}

main "$@"
