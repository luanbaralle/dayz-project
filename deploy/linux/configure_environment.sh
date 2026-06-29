#!/usr/bin/env bash
# =============================================================================
# configure_environment.sh — Cria estrutura de diretórios e arquivo .env
# =============================================================================
# Requer: root (sudo)
# Idempotente: cria apenas o que não existe
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
  log_step "Criando estrutura de diretórios em ${DAYZ_BASE}"

  local directories=(
    "$DAYZ_BASE"
    "$DAYZ_SERVER_DIR"
    "$DAYZ_PROJECT_DIR"
    "$DAYZ_PROFILES_DIR"
    "$DAYZ_BACKUPS_DIR"
    "$DAYZ_LOGS_DIR"
    "$STEAMCMD_DIR"
  )

  for dir in "${directories[@]}"; do
    ensure_owned_dir "$dir"
    log_info "  ${dir}"
  done
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

  # Garante diretório pai antes de copiar
  ensure_dir "$(dirname "$ENV_DEST")" "${DAYZ_USER}:${DAYZ_USER}"

  cp "${SCRIPT_DIR}/.env.example" "$ENV_DEST"
  chown "${DAYZ_USER}:${DAYZ_USER}" "$ENV_DEST"
  chmod 600 "$ENV_DEST"

  log_info "Arquivo .env criado a partir de deploy/linux/.env.example"
  log_warn "Configure STEAM_USERNAME em ${ENV_DEST}"
  log_warn "A senha Steam não é armazenada — será solicitada na primeira instalação."
}

clone_or_update_project() {
  log_step "Configurando repositório do projeto"

  # Recarrega .env após deploy
  if [[ -f "$ENV_DEST" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$ENV_DEST"
    set +a
    normalize_env_aliases
  fi

  if [[ -z "${GIT_REPO_URL:-}" || "${GIT_REPO_URL}" == *"SEU_USUARIO"* ]]; then
    log_warn "GIT_REPO_URL não configurado — clone manual necessário:"
    log_warn "  git clone <url> ${DAYZ_PROJECT_DIR}"
    return 0
  fi

  if [[ -d "${DAYZ_PROJECT_DIR}/.git" ]]; then
    log_info "Repositório já clonado em ${DAYZ_PROJECT_DIR}"
    sudo -u "$DAYZ_USER" git -C "$DAYZ_PROJECT_DIR" fetch --all --prune || true
    sudo -u "$DAYZ_USER" git -C "$DAYZ_PROJECT_DIR" checkout "${GIT_BRANCH:-main}" || true
    sudo -u "$DAYZ_USER" git -C "$DAYZ_PROJECT_DIR" pull --ff-only || true
    return 0
  fi

  log_info "Clonando repositório: ${GIT_REPO_URL}"
  sudo -u "$DAYZ_USER" git clone --branch "${GIT_BRANCH:-main}" "$GIT_REPO_URL" "$DAYZ_PROJECT_DIR"
}

setup_log_symlinks() {
  log_step "Configurando atalhos de logs"

  # Symlink para logs RPT gerados nos profiles (quando existirem)
  local profiles_link="${DAYZ_LOGS_DIR}/profiles"
  if [[ ! -L "$profiles_link" ]]; then
    ln -sfn "$DAYZ_PROFILES_DIR" "$profiles_link"
    chown -h "${DAYZ_USER}:${DAYZ_USER}" "$profiles_link" 2>/dev/null || true
    log_info "Symlink criado: ${profiles_link} -> ${DAYZ_PROFILES_DIR}"
  fi
}

print_environment_summary() {
  log_step "Ambiente configurado"
  cat <<EOF
Diretórios:
  Base:      ${DAYZ_BASE}
  Servidor:  ${DAYZ_SERVER_DIR}
  Projeto:   ${DAYZ_PROJECT_DIR}
  Profiles:  ${DAYZ_PROFILES_DIR}
  Backups:   ${DAYZ_BACKUPS_DIR}
  Logs:      ${DAYZ_LOGS_DIR}
  SteamCMD:  ${STEAMCMD_DIR}
  Wine:      ${WINEPREFIX}

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
  clone_or_update_project
  setup_log_symlinks
  print_environment_summary
  log_info "Ambiente configurado com sucesso."
}

main "$@"
