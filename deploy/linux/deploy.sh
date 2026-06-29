#!/usr/bin/env bash
# =============================================================================
# deploy.sh — Sincroniza arquivos do projeto para a instalação do servidor
# =============================================================================
# Uso: ./deploy.sh
# Requer: repositório clonado em DAYZ_PROJECT_DIR
#
# PLACEHOLDER: implementação básica com rsync.
# Expanda este script conforme o pipeline de deploy amadurecer.
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

validate_project() {
  if [[ ! -d "${DAYZ_PROJECT_DIR}/.git" ]]; then
    log_error "Repositório não encontrado em ${DAYZ_PROJECT_DIR}"
    log_error "Configure GIT_REPO_URL em ${DAYZ_ENV_FILE} e execute configure_environment.sh"
    exit 1
  fi
}

pull_latest_changes() {
  log_step "Atualizando repositório (git pull)"

  git -C "$DAYZ_PROJECT_DIR" fetch --all --prune
  git -C "$DAYZ_PROJECT_DIR" checkout "${GIT_BRANCH:-main}"
  git -C "$DAYZ_PROJECT_DIR" pull --ff-only

  log_info "Repositório atualizado: $(git -C "$DAYZ_PROJECT_DIR" rev-parse --short HEAD)"
}

sync_config_files() {
  log_step "Sincronizando config/ → ${DAYZ_SERVER_DIR}"

  local config_src="${DAYZ_PROJECT_DIR}/config"

  if [[ ! -d "$config_src" ]]; then
    log_warn "Diretório config/ não encontrado no projeto — pulando."
    return 0
  fi

  # Copia configs versionadas (serverDZ.cfg, etc.)
  # Nota: Start_Server.bat é Windows-only; serverDZ.cfg é usado pelo start.sh Linux
  rsync -av --checksum \
    --include='serverDZ.cfg' \
    --include='*.xml' \
    --include='whitelist.txt' \
    --include='ban.txt' \
    --exclude='*' \
    "${config_src}/" "${DAYZ_SERVER_DIR}/"

  log_info "Configurações sincronizadas."
}

sync_profiles() {
  log_step "Sincronizando profiles/ do projeto → ${DAYZ_PROFILES_DIR}"

  local profiles_src="${DAYZ_PROJECT_DIR}/profiles"

  if [[ ! -d "$profiles_src" ]]; then
    log_warn "Diretório profiles/ não encontrado no projeto — pulando."
    return 0
  fi

  # Sincroniza configs versionadas, exclui logs e runtime
  rsync -av --checksum \
    --exclude='*.RPT' \
    --exclude='*.ADM' \
    --exclude='*.log' \
    --exclude='DataCache/' \
    --exclude='BattlEye/' \
    --exclude='Users/Survivor/' \
    --exclude='VPPAdminTools/Logging/' \
    --exclude='VPPAdminTools/Backups/' \
    --exclude='VPPAdminTools/Exports/' \
    --exclude='VPPAdminTools/Permissions/credentials.txt' \
    "${profiles_src}/" "${DAYZ_PROFILES_DIR}/"

  log_info "Profiles sincronizados."
}

sync_missions() {
  log_step "Sincronizando missions/ (se existirem)"

  local missions_src="${DAYZ_PROJECT_DIR}/missions"
  local missions_dest="${DAYZ_SERVER_DIR}/mpmissions"

  if [[ ! -d "$missions_src" ]]; then
    log_info "Nenhuma missão customizada — pulando."
    return 0
  fi

  # Copia apenas subdiretórios de missão (ignora README.md na raiz)
  rsync -av --checksum \
    --exclude='README.md' \
    "${missions_src}/" "${missions_dest}/" 2>/dev/null || {
      log_warn "Diretório mpmissions/ não existe ainda — será criado na primeira missão."
      mkdir -p "$missions_dest"
      rsync -av --checksum --exclude='README.md' "${missions_src}/" "${missions_dest}/"
    }

  log_info "Missões sincronizadas."
}

print_deploy_summary() {
  log_step "Deploy concluído (placeholder)"
  cat <<EOF
Arquivos sincronizados do projeto para o servidor.

Para aplicar alterações em runtime:
  ${SCRIPT_DIR}/restart.sh

TODO (expansões futuras):
  - Instalar/atualizar mods via Steam Workshop
  - Backup automático antes do deploy
  - Validação de serverDZ.cfg
  - Rollback em caso de falha

EOF
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
  log_step "DayZ Project — Deploy"
  validate_project
  pull_latest_changes
  sync_config_files
  sync_profiles
  sync_missions
  print_deploy_summary
}

main "$@"
