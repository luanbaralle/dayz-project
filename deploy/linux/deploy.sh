#!/usr/bin/env bash
# =============================================================================
# deploy.sh — Sincroniza arquivos do projeto Git para o ambiente de runtime
# =============================================================================
# Responsabilidade única: rsync.
#
# Sincroniza: config/, profiles/, missions/, mods/local/, mods/keys/
#
# NÃO executa: git, SteamCMD, start, stop, install_mods
#
# Fluxo diário:
#   cd $PROJECT_DIR && git pull
#   ./deploy/linux/deploy.sh
#   ./deploy/linux/restart.sh
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
    log_error "Repositório Git não encontrado em ${DAYZ_PROJECT_DIR}"
    log_error "Clone o projeto antes do deploy:"
    log_error "  git clone <url> ${DAYZ_PROJECT_DIR}"
    exit 1
  fi
}

resolve_profiles_source() {
  # Compatibilidade: profiles/config/ (futuro) ou profiles/ (legado)
  local config_path="${DAYZ_PROJECT_DIR}/profiles/config"
  if [[ -d "$config_path" ]]; then
    echo "$config_path"
    return 0
  fi
  echo "${DAYZ_PROJECT_DIR}/profiles"
}

sync_config_files() {
  log_step "Sincronizando config/ → ${DAYZ_SERVER_DIR}"

  local config_src="${DAYZ_PROJECT_DIR}/config"

  if [[ ! -d "$config_src" ]]; then
    log_warn "Diretório config/ não encontrado — pulando."
    return 0
  fi

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
  local profiles_src
  profiles_src="$(resolve_profiles_source)"

  log_step "Sincronizando ${profiles_src} → ${DAYZ_PROFILES_DIR}"

  if [[ ! -d "$profiles_src" ]]; then
    log_warn "Diretório de profiles não encontrado — pulando."
    return 0
  fi

  rsync -av --checksum \
    --exclude='*.RPT' \
    --exclude='*.ADM' \
    --exclude='*.log' \
    --exclude='README.md' \
    --exclude='DataCache/' \
    --exclude='BattlEye/' \
    --exclude='runtime/' \
    --exclude='Users/Survivor/' \
    --exclude='VPPAdminTools/Logging/' \
    --exclude='VPPAdminTools/Backups/' \
    --exclude='VPPAdminTools/Exports/' \
    --exclude='VPPAdminTools/Permissions/credentials.txt' \
    "${profiles_src}/" "${DAYZ_PROFILES_DIR}/"

  log_info "Profiles sincronizados."
}

sync_missions() {
  log_step "Sincronizando missions/ → ${DAYZ_SERVER_DIR}/mpmissions"

  local missions_src="${DAYZ_PROJECT_DIR}/missions"
  local missions_dest="${DAYZ_SERVER_DIR}/mpmissions"

  if [[ ! -d "$missions_src" ]]; then
    log_info "Nenhuma missão customizada — pulando."
    return 0
  fi

  mkdir -p "$missions_dest"

  rsync -av --checksum \
    --exclude='README.md' \
    "${missions_src}/" "${missions_dest}/"

  log_info "Missões sincronizadas."
}

sync_mods_local() {
  log_step "Sincronizando mods/local/ → ${DAYZ_SERVER_DIR}"

  local local_src="${DAYZ_PROJECT_DIR}/mods/local"

  if [[ ! -d "$local_src" ]]; then
    log_info "mods/local/ não encontrado — pulando."
    return 0
  fi

  # Sincroniza apenas pastas @Mod (não manifest, keys, README)
  rsync -av --checksum \
    --include='@*/' \
    --include='@*/**' \
    --exclude='*' \
    "${local_src}/" "${DAYZ_SERVER_DIR}/"

  log_info "Mods locais sincronizados."
}

sync_mods_keys() {
  log_step "Sincronizando mods/keys/ → ${DAYZ_SERVER_DIR}/keys"

  local keys_src="${DAYZ_PROJECT_DIR}/mods/keys"

  if [[ ! -d "$keys_src" ]]; then
    log_info "mods/keys/ não encontrado — pulando."
    return 0
  fi

  mkdir -p "${DAYZ_SERVER_DIR}/keys"

  rsync -av --checksum \
    --include='*.bikey' \
    --exclude='*' \
    "${keys_src}/" "${DAYZ_SERVER_DIR}/keys/"

  log_info "Chaves de mods sincronizadas."
}

print_deploy_summary() {
  local commit
  commit="$(git -C "$DAYZ_PROJECT_DIR" rev-parse --short HEAD 2>/dev/null || echo '?')"

  log_step "Deploy concluído"
  cat <<EOF
Commit sincronizado: ${commit}

Destinos:
  config      → ${DAYZ_SERVER_DIR}
  profiles    → ${DAYZ_PROFILES_DIR}
  missions    → ${DAYZ_SERVER_DIR}/mpmissions
  mods/local  → ${DAYZ_SERVER_DIR}
  mods/keys   → ${DAYZ_SERVER_DIR}/keys

Para aplicar em runtime:
  ${SCRIPT_DIR}/restart.sh

EOF
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
  log_step "DayZ Project — Deploy (rsync)"
  validate_project
  sync_config_files
  sync_profiles
  sync_missions
  sync_mods_local
  sync_mods_keys
  print_deploy_summary
}

main "$@"
