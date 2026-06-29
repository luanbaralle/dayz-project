#!/usr/bin/env bash
# =============================================================================
# configure_environment.sh — Estrutura de diretórios e .env (uso interno)
# =============================================================================
# Chamado por bootstrap.sh na preparação inicial da VPS.
#
# Responsabilidade única:
#   - usuário dayz
#   - diretórios em DAYZ_HOME
#   - cópia de .env.example → .env (se não existir)
#   - symlinks de logs
#
# NÃO executa: git clone, git pull, deploy, start, install_dayz
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

load_env 2>/dev/null || true
apply_env_defaults

readonly ENV_DEST="${DAYZ_ENV_FILE:-/home/ubuntu/dayz/.env}"

# -----------------------------------------------------------------------------
# Funções
# -----------------------------------------------------------------------------

create_directory_structure() {
  log_step "Criando estrutura de diretórios em ${DAYZ_HOME}"

  local directories=(
    "$DAYZ_HOME"
    "$DAYZ_SERVER_DIR"
    "$DAYZ_PROJECT_DIR"
    "$DAYZ_PROFILES_DIR"
    "$DAYZ_BACKUPS_DIR"
    "$DAYZ_LOGS_DIR"
    "$STEAMCMD_DIR"
    "$STEAM_HOME"
  )

  for dir in "${directories[@]}"; do
    ensure_owned_dir "$dir"
    log_info "  ${dir}"
  done

  steam_ensure_home
}

deploy_env_file() {
  log_step "Configurando arquivo de ambiente: ${ENV_DEST}"

  if [[ -f "$ENV_DEST" ]]; then
    log_info "Arquivo .env já existe — mantendo configuração existente (não sobrescrito)."
    return 0
  fi

  if [[ ! -f "${SCRIPT_DIR}/.env.example" ]]; then
    log_error ".env.example não encontrado em ${SCRIPT_DIR}"
    exit 1
  fi

  ensure_dir "$(dirname "$ENV_DEST")" "${DAYZ_USER}:${DAYZ_USER}"

  cp "${SCRIPT_DIR}/.env.example" "$ENV_DEST"
  chown "${DAYZ_USER}:${DAYZ_USER}" "$ENV_DEST"
  chmod 600 "$ENV_DEST"

  log_info "Arquivo .env criado a partir de deploy/linux/.env.example"
  log_warn "Configure STEAM_USERNAME em ${ENV_DEST}"
}

setup_log_symlinks() {
  log_step "Configurando atalhos de logs"

  local profiles_link="${DAYZ_LOGS_DIR}/profiles"
  if [[ ! -L "$profiles_link" ]]; then
    ln -sfn "$DAYZ_PROFILES_DIR" "$profiles_link"
    chown -h "${DAYZ_USER}:${DAYZ_USER}" "$profiles_link" 2>/dev/null || true
    log_info "Symlink: ${profiles_link} -> ${DAYZ_PROFILES_DIR}"
  fi
}

print_environment_summary() {
  log_step "Ambiente configurado"
  cat <<EOF
Diretórios:
  Base:      ${DAYZ_HOME}
  Servidor:  ${DAYZ_SERVER_DIR}
  Projeto:   ${DAYZ_PROJECT_DIR}
  Profiles:  ${DAYZ_PROFILES_DIR}
  Backups:   ${DAYZ_BACKUPS_DIR}
  Logs:      ${DAYZ_LOGS_DIR}
  SteamCMD:  ${STEAMCMD_DIR}
  Steam lib: ${STEAM_HOME}

Configuração:
  ${ENV_DEST}

EOF
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
  require_root
  ensure_dayz_user
  create_directory_structure
  deploy_env_file
  setup_log_symlinks
  print_environment_summary
  log_info "Ambiente configurado com sucesso."
}

main "$@"
