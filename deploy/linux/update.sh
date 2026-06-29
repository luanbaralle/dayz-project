#!/usr/bin/env bash
# =============================================================================
# update.sh — Único orquestrador de atualização completa
# =============================================================================
# Ordem fixa (nenhum script chama outro internamente):
#
#   git pull → install_dayz.sh → install_mods.sh → deploy.sh
#
# NÃO inicia nem reinicia o servidor.
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

require_script() {
  local script_name="$1"
  local script_path="${SCRIPT_DIR}/${script_name}"

  if [[ ! -f "$script_path" ]]; then
    log_error "Script obrigatório não encontrado: ${script_path}"
    exit 1
  fi

  if [[ ! -x "$script_path" ]]; then
    chmod +x "$script_path"
  fi
}

run_script() {
  local script_name="$1"
  local privilege="${2:-user}"  # root | user
  local script_path="${SCRIPT_DIR}/${script_name}"

  require_script "$script_name"
  log_step "Executando ${script_name}"

  case "$privilege" in
    root)
      if [[ "${EUID}" -ne 0 ]]; then
        sudo bash "$script_path"
      else
        bash "$script_path"
      fi
      ;;
    user)
      if [[ "${EUID}" -eq 0 ]]; then
        sudo -u "$DAYZ_USER" bash "$script_path"
      else
        bash "$script_path"
      fi
      ;;
    *)
      log_error "Privilégio inválido: ${privilege}"
      exit 1
      ;;
  esac
}

validate_project_repository() {
  if [[ ! -d "${DAYZ_PROJECT_DIR}/.git" ]]; then
    log_error "Repositório Git não encontrado em ${DAYZ_PROJECT_DIR}"
    log_error "Clone o projeto antes de atualizar:"
    log_error "  git clone <url> ${DAYZ_PROJECT_DIR}"
    exit 1
  fi
}

pull_latest_changes() {
  log_step "git pull"

  validate_project_repository

  sudo -u "$DAYZ_USER" git -C "$DAYZ_PROJECT_DIR" fetch --all --prune
  sudo -u "$DAYZ_USER" git -C "$DAYZ_PROJECT_DIR" checkout "${GIT_BRANCH:-main}"
  sudo -u "$DAYZ_USER" git -C "$DAYZ_PROJECT_DIR" pull --ff-only

  log_info "Commit atual: $(git -C "$DAYZ_PROJECT_DIR" rev-parse --short HEAD)"
}

print_update_summary() {
  log_step "Atualização concluída"
  cat <<EOF
Pipeline executado:
  1. git pull
  2. install_dayz.sh
  3. install_mods.sh
  4. deploy.sh

Para aplicar em runtime:
  ${SCRIPT_DIR}/restart.sh

EOF
}

# -----------------------------------------------------------------------------
# Main — ordem fixa, sem atalhos
# -----------------------------------------------------------------------------

main() {
  log_step "DayZ Project — Update"
  log_info "Projeto: ${DAYZ_PROJECT_DIR}"

  pull_latest_changes
  run_script "install_dayz.sh" "root"
  run_script "install_mods.sh" "root"
  run_script "deploy.sh" "user"

  print_update_summary
}

main "$@"
