#!/usr/bin/env bash
# =============================================================================
# common.sh — Funções compartilhadas pelos scripts de deploy Linux
# =============================================================================
# Uso: source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

set -euo pipefail

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------

log_info()  { echo "[INFO]  $(date +'%Y-%m-%d %H:%M:%S') $*"; }
log_warn()  { echo "[WARN]  $(date +'%Y-%m-%d %H:%M:%S') $*" >&2; }
log_error() { echo "[ERROR] $(date +'%Y-%m-%d %H:%M:%S') $*" >&2; }
log_step()  { echo ""; echo "==> $*"; echo ""; }

# -----------------------------------------------------------------------------
# Ambiente
# -----------------------------------------------------------------------------

# Diretório deste script (deploy/linux)
DEPLOY_LINUX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Arquivo .env principal (gerado por configure_environment.sh)
DAYZ_ENV_FILE="${DAYZ_ENV_FILE:-/home/ubuntu/dayz/.env}"

load_env() {
  if [[ -f "$DAYZ_ENV_FILE" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$DAYZ_ENV_FILE"
    set +a
    return 0
  fi

  # Fallback: .env.example durante bootstrap inicial
  if [[ -f "${DEPLOY_LINUX_DIR}/.env.example" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "${DEPLOY_LINUX_DIR}/.env.example"
    set +a
    log_warn "Usando .env.example — execute configure_environment.sh para gerar ${DAYZ_ENV_FILE}"
    return 0
  fi

  log_error "Arquivo de ambiente não encontrado: ${DAYZ_ENV_FILE}"
  return 1
}

# Valores padrão (sobrescritos pelo .env)
DAYZ_USER="${DAYZ_USER:-ubuntu}"
DAYZ_BASE="${DAYZ_BASE:-/home/ubuntu/dayz}"
DAYZ_SERVER_DIR="${DAYZ_SERVER_DIR:-${DAYZ_BASE}/server}"
DAYZ_PROJECT_DIR="${DAYZ_PROJECT_DIR:-${DAYZ_BASE}/project}"
DAYZ_PROFILES_DIR="${DAYZ_PROFILES_DIR:-${DAYZ_BASE}/profiles}"
DAYZ_BACKUPS_DIR="${DAYZ_BACKUPS_DIR:-${DAYZ_BASE}/backups}"
DAYZ_LOGS_DIR="${DAYZ_LOGS_DIR:-${DAYZ_BASE}/logs}"
STEAMCMD_DIR="${STEAMCMD_DIR:-${DAYZ_BASE}/steamcmd}"
WINEPREFIX="${WINEPREFIX:-/home/ubuntu/.wine-dayz}"
DAYZ_PORT="${DAYZ_PORT:-2302}"
DAYZ_CONFIG="${DAYZ_CONFIG:-serverDZ.cfg}"
DAYZ_APP_ID="${DAYZ_APP_ID:-223350}"
DAYZ_PID_FILE="${DAYZ_PID_FILE:-${DAYZ_BASE}/dayz-server.pid}"
DAYZ_TMUX_SESSION="${DAYZ_TMUX_SESSION:-dayz-server}"

apply_env_defaults() {
  DAYZ_USER="${DAYZ_USER:-ubuntu}"
  DAYZ_BASE="${DAYZ_BASE:-/home/ubuntu/dayz}"
  DAYZ_SERVER_DIR="${DAYZ_SERVER_DIR:-${DAYZ_BASE}/server}"
  DAYZ_PROJECT_DIR="${DAYZ_PROJECT_DIR:-${DAYZ_BASE}/project}"
  DAYZ_PROFILES_DIR="${DAYZ_PROFILES_DIR:-${DAYZ_BASE}/profiles}"
  DAYZ_BACKUPS_DIR="${DAYZ_BACKUPS_DIR:-${DAYZ_BASE}/backups}"
  DAYZ_LOGS_DIR="${DAYZ_LOGS_DIR:-${DAYZ_BASE}/logs}"
  STEAMCMD_DIR="${STEAMCMD_DIR:-${DAYZ_BASE}/steamcmd}"
  WINEPREFIX="${WINEPREFIX:-/home/ubuntu/.wine-dayz}"
  DAYZ_PORT="${DAYZ_PORT:-2302}"
  DAYZ_CONFIG="${DAYZ_CONFIG:-serverDZ.cfg}"
  DAYZ_APP_ID="${DAYZ_APP_ID:-223350}"
  DAYZ_PID_FILE="${DAYZ_PID_FILE:-${DAYZ_BASE}/dayz-server.pid}"
  DAYZ_TMUX_SESSION="${DAYZ_TMUX_SESSION:-dayz-server}"
}

# -----------------------------------------------------------------------------
# Validações
# -----------------------------------------------------------------------------

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    log_error "Este script deve ser executado como root (use sudo)."
    exit 1
  fi
}

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" &>/dev/null; then
    log_error "Comando obrigatório não encontrado: ${cmd}"
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
    log_warn "Distribuição detectada: ${ID}. Scripts otimizados para Ubuntu 24.04."
  fi
}

command_exists() {
  command -v "$1" &>/dev/null
}

# -----------------------------------------------------------------------------
# Sistema de arquivos
# -----------------------------------------------------------------------------

ensure_dir() {
  local dir="$1"
  local owner="${2:-}"

  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
    log_info "Diretório criado: ${dir}"
  fi

  if [[ -n "$owner" ]]; then
    chown -R "$owner" "$dir"
  fi
}

ensure_owned_dir() {
  ensure_dir "$1" "${DAYZ_USER}:${DAYZ_USER}"
}

# -----------------------------------------------------------------------------
# APT (idempotente)
# -----------------------------------------------------------------------------

apt_install() {
  local packages=("$@")
  local missing=()

  for pkg in "${packages[@]}"; do
    if ! dpkg -s "$pkg" &>/dev/null; then
      missing+=("$pkg")
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    log_info "Pacotes já instalados: ${packages[*]}"
    return 0
  fi

  log_info "Instalando pacotes: ${missing[*]}"
  apt-get install -y "${missing[@]}"
}

# -----------------------------------------------------------------------------
# Processos do servidor
# -----------------------------------------------------------------------------

is_server_running() {
  if [[ -f "$DAYZ_PID_FILE" ]]; then
    local pid
    pid="$(cat "$DAYZ_PID_FILE")"
    if kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  fi

  # Fallback: busca por processo Wine + DayZ
  pgrep -f "DayZServer_x64.exe" &>/dev/null
}

get_server_pid() {
  if [[ -f "$DAYZ_PID_FILE" ]]; then
    local pid
    pid="$(cat "$DAYZ_PID_FILE")"
    if kill -0 "$pid" 2>/dev/null; then
      echo "$pid"
      return 0
    fi
  fi
  pgrep -f "DayZServer_x64.exe" | head -n1 || true
}

ensure_dayz_user() {
  if id "$DAYZ_USER" &>/dev/null; then
    return 0
  fi

  log_info "Criando usuário ${DAYZ_USER}..."
  useradd -m -s /bin/bash "$DAYZ_USER"
}
