#!/usr/bin/env bash
# =============================================================================
# install_dependencies.sh — Instala pacotes base do sistema
# =============================================================================
# Requer: root (sudo)
# Idempotente: verifica pacotes antes de instalar
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

# -----------------------------------------------------------------------------
# Funções
# -----------------------------------------------------------------------------

update_apt_cache() {
  log_info "Atualizando cache APT..."
  apt-get update -qq
}

install_base_packages() {
  log_step "Instalando dependências base"

  local packages=(
    git
    curl
    wget
    zip
    unzip
    tmux
    tree
    htop
    rsync
    nano
    software-properties-common
    ca-certificates
    gnupg
    locales
  )

  apt_install "${packages[@]}"
}

configure_locale() {
  log_info "Configurando locale en_US.UTF-8 (recomendado para Wine/SteamCMD)"

  if ! locale -a 2>/dev/null | grep -qi "en_US.utf8"; then
    locale-gen en_US.UTF-8 || true
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 || true
  fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
  require_root
  load_env 2>/dev/null || true
  apply_env_defaults
  ensure_dayz_user
  update_apt_cache
  install_base_packages
  configure_locale
  log_info "Dependências base instaladas com sucesso."
}

main "$@"
