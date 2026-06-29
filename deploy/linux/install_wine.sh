#!/usr/bin/env bash
# =============================================================================
# install_wine.sh — Instala e configura Wine 64-bit + Wine32
# =============================================================================
# Requer: root (sudo)
# Idempotente: verifica instalação existente antes de reinstalar
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

load_env 2>/dev/null || true
apply_env_defaults

# -----------------------------------------------------------------------------
# Funções
# -----------------------------------------------------------------------------

enable_i386_architecture() {
  log_info "Habilitando arquitetura i386 (necessária para Wine32)..."

  if dpkg --print-foreign-architectures | grep -q i386; then
    log_info "Arquitetura i386 já habilitada."
    return 0
  fi

  dpkg --add-architecture i386
  apt-get update -qq
}

install_wine_packages() {
  log_step "Instalando Wine 64-bit e Wine32"

  # Pacotes do repositório Ubuntu 24.04 (Noble)
  local packages=(
    wine
    wine64
    wine32:i386
    winbind
    cabextract
  )

  apt_install "${packages[@]}"

  log_info "Versão do Wine: $(wine --version 2>/dev/null || echo 'não detectada')"
}

init_wine_prefix() {
  log_step "Inicializando prefixo Wine dedicado: ${WINEPREFIX}"

  # Executa como usuário dayz (não root) para evitar problemas de permissão
  if [[ ! -d "$WINEPREFIX" ]]; then
    log_info "Criando WINEPREFIX como ${DAYZ_USER}..."
    sudo -u "$DAYZ_USER" env WINEPREFIX="$WINEPREFIX" WINEARCH="${WINEARCH:-win64}" \
      wineboot --init 2>/dev/null || true
    log_info "Prefixo Wine criado."
  else
    log_info "Prefixo Wine já existe: ${WINEPREFIX}"
  fi
}

configure_wine_environment() {
  log_step "Configurando variáveis de ambiente Wine"

  local profile_snippet="/etc/profile.d/dayz-wine.sh"

  cat > "$profile_snippet" <<EOF
# DayZ Project — variáveis Wine (gerado por install_wine.sh)
export WINEPREFIX="${WINEPREFIX}"
export WINEARCH="${WINEARCH:-win64}"
export WINEDEBUG="${WINEDEBUG:--all}"
EOF

  chmod 644 "$profile_snippet"
  log_info "Snippet de ambiente criado: ${profile_snippet}"
}

fix_wine_permissions() {
  if [[ -d "$WINEPREFIX" ]]; then
    chown -R "${DAYZ_USER}:${DAYZ_USER}" "$WINEPREFIX"
    log_info "Permissões do WINEPREFIX ajustadas para ${DAYZ_USER}."
  fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
  require_root
  ensure_dayz_user
  enable_i386_architecture
  install_wine_packages
  init_wine_prefix
  configure_wine_environment
  fix_wine_permissions
  log_info "Wine instalado e configurado com sucesso."
}

main "$@"
