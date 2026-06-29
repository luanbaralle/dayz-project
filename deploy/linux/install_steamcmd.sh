#!/usr/bin/env bash
# =============================================================================
# install_steamcmd.sh — Instala SteamCMD
# =============================================================================
# Requer: root (sudo)
# Idempotente: não rebaixa se steamcmd já estiver instalado
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

load_env 2>/dev/null || true
apply_env_defaults

readonly STEAMCMD_URL="https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"
readonly STEAMCMD_BIN="${STEAMCMD_DIR}/steamcmd.sh"

# -----------------------------------------------------------------------------
# Funções
# -----------------------------------------------------------------------------

install_steamcmd_dependencies() {
  log_info "Instalando dependências do SteamCMD (lib32)..."

  local packages=(
    lib32gcc-s1
    lib32stdc++6
    libc6-i386
  )

  apt_install "${packages[@]}"
}

download_steamcmd() {
  log_step "Instalando SteamCMD em ${STEAMCMD_DIR}"

  ensure_owned_dir "$STEAMCMD_DIR"

  if [[ -x "$STEAMCMD_BIN" ]]; then
    log_info "SteamCMD já instalado: ${STEAMCMD_BIN}"
    return 0
  fi

  local tmp_archive="/tmp/steamcmd_linux.tar.gz"

  log_info "Baixando SteamCMD..."
  curl -fsSL "$STEAMCMD_URL" -o "$tmp_archive"

  log_info "Extraindo SteamCMD..."
  tar -xzf "$tmp_archive" -C "$STEAMCMD_DIR"
  rm -f "$tmp_archive"

  chown -R "${DAYZ_USER}:${DAYZ_USER}" "$STEAMCMD_DIR"
  chmod +x "$STEAMCMD_BIN"

  log_info "SteamCMD instalado com sucesso."
}

verify_steamcmd() {
  log_info "Verificando SteamCMD..."

  if [[ ! -x "$STEAMCMD_BIN" ]]; then
    log_error "steamcmd.sh não encontrado em ${STEAMCMD_DIR}"
    exit 1
  fi

  # Primeira execução baixa atualizações do cliente Steam
  log_info "Executando primeira inicialização do SteamCMD (pode demorar)..."
  sudo -u "$DAYZ_USER" "$STEAMCMD_BIN" +quit || true

  log_info "SteamCMD verificado."
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
  require_root
  ensure_dayz_user
  install_steamcmd_dependencies
  download_steamcmd
  verify_steamcmd
  log_info "SteamCMD pronto em ${STEAMCMD_DIR}"
}

main "$@"
