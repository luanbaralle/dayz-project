#!/usr/bin/env bash
# lib/filesystem.sh — Operações de sistema de arquivos

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
