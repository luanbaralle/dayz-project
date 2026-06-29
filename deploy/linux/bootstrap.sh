#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — Preparação inicial da VPS (executar UMA VEZ)
# =============================================================================
# Uso (como root):
#   sudo ./deploy/linux/bootstrap.sh
#
# Responsabilidade única: preparar a máquina.
#   - Dependências do sistema (APT)
#   - Wine
#   - SteamCMD
#   - Estrutura de diretórios
#   - Arquivo .env inicial
#
# NÃO executa: git pull, deploy, start, install_dayz, install_mods
#
# Idempotente para componentes de sistema (APT/Wine/SteamCMD).
# Após o bootstrap, siga os passos exibidos no resumo final.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

readonly ENV_FILE="${DAYZ_ENV_FILE:-/home/ubuntu/dayz/.env}"
readonly BOOTSTRAP_MARKER="${DAYZ_HOME:-/home/ubuntu/dayz}/.bootstrap_complete"

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

  if [[ -f "$BOOTSTRAP_MARKER" ]]; then
    log_warn "Bootstrap já executado anteriormente (${BOOTSTRAP_MARKER})."
    log_warn "Continuando em modo idempotente (apenas verificação de componentes)."
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
  chmod +x "${SCRIPT_DIR}"/*.sh 2>/dev/null || true
}

setup_environment() {
  log_step "Configurando ambiente (diretórios + .env)"
  run_script "configure_environment.sh"
}

mark_bootstrap_complete() {
  load_env 2>/dev/null || true
  apply_env_defaults

  ensure_dir "$DAYZ_HOME" "${DAYZ_USER}:${DAYZ_USER}"
  date -u +"%Y-%m-%dT%H:%M:%SZ" > "$BOOTSTRAP_MARKER"
  chown "${DAYZ_USER}:${DAYZ_USER}" "$BOOTSTRAP_MARKER"
  log_info "Marcador de bootstrap criado: ${BOOTSTRAP_MARKER}"
}

print_summary() {
  load_env 2>/dev/null || true
  apply_env_defaults

  log_step "Bootstrap concluído"

  cat <<EOF
A VPS está preparada. O bootstrap NÃO instala o DayZ nem clona o repositório.

Próximos passos (ordem recomendada):

  1. Configure o ambiente:
       nano ${ENV_FILE}
     Preencha pelo menos STEAM_USERNAME.

  2. Instale o DayZ Dedicated Server:
       sudo ${SCRIPT_DIR}/install_dayz.sh
     (senha Steam solicitada interativamente na primeira vez)

  3. Instale mods (Workshop — mods/manifest.yaml):
       sudo ${SCRIPT_DIR}/install_mods.sh

  4. Clone o repositório Git:
       sudo -u ${DAYZ_USER} git clone <url> ${DAYZ_PROJECT_DIR}

  5. Sincronize configs:
       ${SCRIPT_DIR}/deploy.sh

  6. Valide e inicie:
       ${SCRIPT_DIR}/validate.sh
       ${SCRIPT_DIR}/start.sh

Fluxo diário (após setup):
  cd ${DAYZ_PROJECT_DIR} && git pull
  ${SCRIPT_DIR}/deploy.sh
  ${SCRIPT_DIR}/restart.sh

Atualização completa (jogo + deploy):
  ${SCRIPT_DIR}/update.sh

Documentação: ${SCRIPT_DIR}/README.md

EOF
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
  log_step "DayZ Project — Bootstrap (instalação inicial da VPS)"
  log_info "Diretório de deploy: ${SCRIPT_DIR}"

  make_scripts_executable
  verify_prerequisites

  run_script "install_dependencies.sh"
  run_script "install_wine.sh"
  run_script "install_steamcmd.sh"
  setup_environment
  mark_bootstrap_complete
  print_summary
}

main "$@"
