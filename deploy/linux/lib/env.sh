#!/usr/bin/env bash
# lib/env.sh — Carregamento de variáveis de ambiente

# Definido em common.sh antes do source: DEPLOY_LINUX_DIR
DAYZ_ENV_FILE="${DAYZ_ENV_FILE:-/home/ubuntu/dayz/.env}"

load_env() {
  if [[ -f "$DAYZ_ENV_FILE" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$DAYZ_ENV_FILE"
    set +a
    normalize_env_aliases
    return 0
  fi

  if [[ -f "${DEPLOY_LINUX_DIR}/.env.example" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "${DEPLOY_LINUX_DIR}/.env.example"
    set +a
    normalize_env_aliases
    log_warn "Usando .env.example — configure ${DAYZ_ENV_FILE}"
    return 0
  fi

  log_error "Arquivo de ambiente não encontrado: ${DAYZ_ENV_FILE}"
  return 1
}

apply_env_defaults() {
  DAYZ_USER="${DAYZ_USER:-ubuntu}"
  DAYZ_HOME="${DAYZ_HOME:-/home/ubuntu/dayz}"
  DAYZ_BASE="${DAYZ_BASE:-${DAYZ_HOME}}"
  DAYZ_SERVER_DIR="${DAYZ_SERVER_DIR:-${DAYZ_BASE}/server}"
  PROJECT_DIR="${PROJECT_DIR:-${DAYZ_BASE}/project}"
  DAYZ_PROJECT_DIR="${DAYZ_PROJECT_DIR:-${PROJECT_DIR}}"
  PROFILE_DIR="${PROFILE_DIR:-${DAYZ_BASE}/profiles}"
  DAYZ_PROFILES_DIR="${DAYZ_PROFILES_DIR:-${PROFILE_DIR}}"
  DAYZ_BACKUPS_DIR="${DAYZ_BACKUPS_DIR:-${DAYZ_BASE}/backups}"
  DAYZ_LOGS_DIR="${DAYZ_LOGS_DIR:-${DAYZ_BASE}/logs}"
  STEAMCMD_DIR="${STEAMCMD_DIR:-${DAYZ_BASE}/steamcmd}"
  WINEPREFIX="${WINEPREFIX:-/home/ubuntu/.wine-dayz}"
  DAYZ_PORT="${DAYZ_PORT:-2302}"
  DAYZ_CONFIG="${DAYZ_CONFIG:-serverDZ.cfg}"
  DAYZ_APP_ID="${DAYZ_APP_ID:-223350}"
  STEAM_PLATFORM="${STEAM_PLATFORM:-windows}"
  STEAMCMD_PLATFORM="${STEAMCMD_PLATFORM:-${STEAM_PLATFORM}}"
  DAYZ_PID_FILE="${DAYZ_PID_FILE:-${DAYZ_BASE}/dayz-server.pid}"
  DAYZ_TMUX_SESSION="${DAYZ_TMUX_SESSION:-dayz-server}"
  DAYZ_MAIN_LOG="${DAYZ_MAIN_LOG:-${DAYZ_LOGS_DIR}/dayz-server.log}"
  normalize_env_aliases
}

normalize_env_aliases() {
  DAYZ_HOME="${DAYZ_HOME:-${DAYZ_BASE:-/home/ubuntu/dayz}}"
  DAYZ_BASE="${DAYZ_BASE:-$DAYZ_HOME}"
  PROJECT_DIR="${PROJECT_DIR:-${DAYZ_PROJECT_DIR:-${DAYZ_HOME}/project}}"
  DAYZ_PROJECT_DIR="${DAYZ_PROJECT_DIR:-$PROJECT_DIR}"
  PROFILE_DIR="${PROFILE_DIR:-${DAYZ_PROFILES_DIR:-${DAYZ_HOME}/profiles}}"
  DAYZ_PROFILES_DIR="${DAYZ_PROFILES_DIR:-$PROFILE_DIR}"
  STEAM_PLATFORM="${STEAM_PLATFORM:-${STEAMCMD_PLATFORM:-windows}}"
  STEAMCMD_PLATFORM="${STEAMCMD_PLATFORM:-$STEAM_PLATFORM}"
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    log_error "Este script deve ser executado como root (use sudo)."
    exit 1
  fi
}

require_command() {
  if ! command -v "$1" &>/dev/null; then
    log_error "Comando obrigatório não encontrado: $1"
    exit 1
  fi
}

require_ubuntu() {
  if [[ ! -f /etc/os-release ]]; then
    log_error "Não foi possível detectar a distribuição Linux."
    exit 1
  fi
  # shellcheck disable=SC1091
  source /etc/os-release
  if [[ "${ID}" != "ubuntu" ]]; then
    log_warn "Distribuição detectada: ${ID}. Otimizado para Ubuntu 24.04."
  fi
}

command_exists() {
  command -v "$1" &>/dev/null
}

ensure_dayz_user() {
  if id "$DAYZ_USER" &>/dev/null; then
    return 0
  fi
  log_info "Criando usuário ${DAYZ_USER}..."
  useradd -m -s /bin/bash "$DAYZ_USER"
}

has_steam_username() {
  [[ -n "${STEAM_USERNAME:-}" ]]
}

is_dayz_installed() {
  [[ -f "${DAYZ_SERVER_DIR}/DayZServer_x64.exe" ]]
}

print_steam_auth_help() {
  cat <<EOF >&2

[ERROR] STEAM_USERNAME não configurado.

Configure em ${DAYZ_ENV_FILE}:
  STEAM_USERNAME=seu_usuario_steam

A senha NÃO é armazenada. Execute interativamente:
  sudo ./deploy/linux/install_dayz.sh

EOF
}
