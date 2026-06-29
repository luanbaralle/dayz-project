#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — Prepara uma VPS Ubuntu 24.04 do zero para o DayZ Server
# =============================================================================
# Uso (como root ou via sudo):
#   chmod +x deploy/linux/bootstrap.sh
#   sudo ./deploy/linux/bootstrap.sh
#
# Idempotente: pode ser executado múltiplas vezes com segurança.
# Nunca apaga .env nem configurações existentes.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

readonly ENV_FILE="${DAYZ_ENV_FILE:-/home/ubuntu/dayz/.env}"

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

ensure_env_before_dayz() {
  log_step "Verificando arquivo de ambiente"

  if [[ -f "$ENV_FILE" ]]; then
    log_info "Arquivo .env encontrado: ${ENV_FILE}"
    return 0
  fi

  log_warn "Arquivo .env não encontrado — executando configure_environment.sh"
  log_warn "O .env será criado a partir de deploy/linux/.env.example"
  run_script "configure_environment.sh"
}

print_summary() {
  load_env 2>/dev/null || true
  apply_env_defaults

  log_step "Bootstrap concluído"

  if ! has_steam_username; then
    cat <<EOF

================================================================================
  ATENÇÃO: STEAM_USERNAME não configurado
================================================================================

O DayZ Dedicated Server não pôde ser instalado sem conta Steam.

Próximos passos:
  1. Edite o arquivo de ambiente:
       nano ${ENV_FILE}

  2. Preencha:
       STEAM_USERNAME=seu_usuario_steam

  3. Instale o servidor (senha solicitada interativamente, não é salva):
       sudo ${SCRIPT_DIR}/install_dayz.sh

     ou reexecute o bootstrap completo:
       sudo ${SCRIPT_DIR}/bootstrap.sh

================================================================================

EOF
  else
    cat <<EOF

Próximos passos:
  1. Revise o arquivo de ambiente:  ${ENV_FILE}
  2. Sincronize configs:            sudo -u ubuntu ${SCRIPT_DIR}/deploy.sh
  3. Inicie o servidor:             sudo -u ubuntu ${SCRIPT_DIR}/start.sh
  4. Verifique status:              ${SCRIPT_DIR}/status.sh

EOF
  fi

  echo "Documentação completa: ${SCRIPT_DIR}/README.md"
  echo ""
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

  # Garante que /home/ubuntu/dayz/.env existe antes de install_dayz.sh
  ensure_env_before_dayz

  run_script "install_dayz.sh"
  run_script "configure_environment.sh"

  print_summary
}

main "$@"
