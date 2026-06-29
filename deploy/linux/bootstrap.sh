#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — Prepara uma VPS Ubuntu 24.04 do zero para o DayZ Server
# =============================================================================
# Uso (como root ou via sudo):
#   chmod +x deploy/linux/bootstrap.sh
#   sudo ./deploy/linux/bootstrap.sh
#
# Idempotente: pode ser executado múltiplas vezes com segurança.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

# -----------------------------------------------------------------------------
# Funções
# -----------------------------------------------------------------------------

verify_prerequisites() {
  log_step "Verificando pré-requisitos"

  require_root
  require_ubuntu

  if ! command_exists apt-get; then
    log_error "apt-get não encontrado. Este bootstrap requer Debian/Ubuntu."
    exit 1
  fi

  # Verifica conectividade básica
  if ! curl -fsSL --max-time 10 https://steamcdn-a.akamaihd.net/ &>/dev/null; then
    log_warn "Não foi possível alcançar os servidores Steam. Verifique a rede/firewall."
  fi

  log_info "Pré-requisitos OK"
}

run_script() {
  local script_name="$1"
  local script_path="${SCRIPT_DIR}/${script_name}"

  if [[ ! -f "$script_path" ]]; then
    log_error "Script não encontrado: ${script_path}"
    exit 1
  fi

  if [[ ! -x "$script_path" ]]; then
    chmod +x "$script_path"
  fi

  log_step "Executando ${script_name}"
  bash "$script_path"
}

make_scripts_executable() {
  log_step "Garantindo permissões de execução nos scripts"
  chmod +x "${SCRIPT_DIR}"/*.sh 2>/dev/null || true
}

print_summary() {
  log_step "Bootstrap concluído"
  cat <<EOF

Próximos passos:
  1. Revise o arquivo de ambiente:  /home/ubuntu/dayz/.env
  2. Clone ou atualize o projeto:  \${DAYZ_PROJECT_DIR}
  3. Sincronize configs:           sudo -u ubuntu ${SCRIPT_DIR}/deploy.sh
  4. Inicie o servidor:            sudo -u ubuntu ${SCRIPT_DIR}/start.sh
  5. Verifique status:             ${SCRIPT_DIR}/status.sh

Documentação completa: ${SCRIPT_DIR}/README.md

EOF
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
  log_step "DayZ Project — Bootstrap Linux (Oracle VPS)"
  log_info "Diretório de deploy: ${SCRIPT_DIR}"

  make_scripts_executable
  verify_prerequisites

  # Ordem obrigatória de instalação
  run_script "install_dependencies.sh"
  run_script "install_wine.sh"
  run_script "install_steamcmd.sh"
  run_script "install_dayz.sh"
  run_script "configure_environment.sh"

  print_summary
}

main "$@"
