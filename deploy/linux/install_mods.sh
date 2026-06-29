#!/usr/bin/env bash
# =============================================================================
# install_mods.sh — Instala/atualiza mods (Workshop + locais) no servidor
# =============================================================================
# Responsabilidade única:
#   - Ler mods/manifest.yaml
#   - Baixar mods Workshop via SteamCMD
#   - Copiar mods para DAYZ_SERVER_DIR (@Pastas)
#   - Copiar .bikey para server/keys/
#   - Sincronizar mods locais (mods/local/)
#
# NÃO executa: deploy, start, stop, git, alteração de configs
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

load_env
apply_env_defaults
unset STEAM_PASSWORD STEAM_GUARD

# -----------------------------------------------------------------------------
# Funções
# -----------------------------------------------------------------------------

validate_environment() {
  if [[ ! -d "${DAYZ_PROJECT_DIR}" ]]; then
    log_error "Projeto não encontrado: ${DAYZ_PROJECT_DIR}"
    exit 1
  fi

  mods_require_manifest
  steamcmd_require
  steamcmd_require_username
  ensure_owned_dir "$DAYZ_SERVER_DIR"
  mkdir -p "${DAYZ_SERVER_DIR}/keys"
  chown "${DAYZ_USER}:${DAYZ_USER}" "${DAYZ_SERVER_DIR}/keys"
}

install_keys_from_directory() {
  local source_dir="$1"
  local keys_source="${source_dir}/keys"

  if [[ ! -d "$keys_source" ]]; then
    return 0
  fi

  local key_file
  shopt -s nullglob
  for key_file in "${keys_source}"/*.bikey; do
    cp -f "$key_file" "${DAYZ_SERVER_DIR}/keys/"
    log_info "  Key instalada: $(basename "$key_file")"
  done
  shopt -u nullglob
  chown -R "${DAYZ_USER}:${DAYZ_USER}" "${DAYZ_SERVER_DIR}/keys"
}

copy_workshop_mod_to_server() {
  local workshop_id="$1"
  local folder="$2"
  local name="$3"
  local content_path dest_path

  content_path="$(mods_workshop_content_path "$workshop_id")"
  dest_path="${DAYZ_SERVER_DIR}/${folder}"

  if [[ ! -d "$content_path" ]]; then
    log_error "Conteúdo Workshop não encontrado: ${content_path}"
    log_error "Mod: ${name:-${folder}} (ID ${workshop_id})"
    exit 1
  fi

  log_info "Copiando ${folder} → ${dest_path}"
  ensure_owned_dir "$dest_path"
  rsync -av --checksum "${content_path}/" "${dest_path}/"
  install_keys_from_directory "$content_path"
  install_keys_from_directory "$dest_path"
}

download_all_workshop_mods() {
  local -a workshop_args=()
  local app_id line workshop_id folder name has_mods=0

  app_id="$(mods_workshop_app_id)"

  while IFS=$'\t' read -r workshop_id folder name; do
    [[ -z "$workshop_id" || -z "$folder" ]] && continue
    has_mods=1
    log_info "Workshop na fila: ${name:-${folder}} (${workshop_id})"
    workshop_args+=(+workshop_download_item "$app_id" "$workshop_id" validate)
  done < <(mods_python_workshop_client)

  while IFS=$'\t' read -r workshop_id folder name; do
    [[ -z "$workshop_id" || -z "$folder" ]] && continue
    has_mods=1
    log_info "Workshop (server) na fila: ${name:-${folder}} (${workshop_id})"
    workshop_args+=(+workshop_download_item "$app_id" "$workshop_id" validate)
  done < <(mods_python_workshop_server)

  if [[ "$has_mods" -eq 0 ]]; then
    log_info "Nenhum mod Workshop definido no manifest."
    return 0
  fi

  log_step "Baixando mods Workshop via SteamCMD (sessão única)"
  steamcmd_prompt_password_if_needed
  steamcmd_run_logged_in "${workshop_args[@]}"
}

install_workshop_mods_to_server() {
  local line workshop_id folder name

  if ! mods_python_workshop_client | grep -q . && \
     ! mods_python_workshop_server | grep -q .; then
    return 0
  fi

  download_all_workshop_mods

  log_step "Instalando mods Workshop em ${DAYZ_SERVER_DIR}"

  while IFS=$'\t' read -r workshop_id folder name; do
    [[ -z "$workshop_id" || -z "$folder" ]] && continue
    copy_workshop_mod_to_server "$workshop_id" "$folder" "$name"
  done < <(mods_python_workshop_client)

  while IFS=$'\t' read -r workshop_id folder name; do
    [[ -z "$workshop_id" || -z "$folder" ]] && continue
    copy_workshop_mod_to_server "$workshop_id" "$folder" "$name"
  done < <(mods_python_workshop_server)
}

install_local_mods_from_manifest() {
  local local_root folder src dest

  local_root="$(mods_local_dir)"

  if ! mods_python_local_folders | grep -q .; then
    log_info "Nenhum mod local definido no manifest."
    return 0
  fi

  log_step "Mods locais (mods/local/) → ${DAYZ_SERVER_DIR}"

  while IFS= read -r folder; do
    [[ -z "$folder" ]] && continue
    src="${local_root}/${folder}"
    dest="${DAYZ_SERVER_DIR}/${folder}"

    if [[ ! -d "$src" ]]; then
      log_warn "Mod local ausente no repositório: ${src}"
      log_warn "Adicione em mods/local/ ou remova do manifest."
      continue
    fi

    ensure_owned_dir "$dest"
    rsync -av --checksum "${src}/" "${dest}/"
    install_keys_from_directory "$src"
    log_info "Mod local sincronizado: ${folder}"
  done < <(mods_python_local_folders)
}

install_project_keys() {
  local keys_dir
  keys_dir="$(mods_keys_dir)"

  if [[ ! -d "$keys_dir" ]]; then
    return 0
  fi

  log_step "Chaves customizadas (mods/keys/) → ${DAYZ_SERVER_DIR}/keys"

  mkdir -p "${DAYZ_SERVER_DIR}/keys"
  rsync -av --checksum \
    --include='*.bikey' \
    --exclude='*' \
    "${keys_dir}/" "${DAYZ_SERVER_DIR}/keys/"

  chown -R "${DAYZ_USER}:${DAYZ_USER}" "${DAYZ_SERVER_DIR}/keys"
  log_info "Chaves customizadas sincronizadas."
}

print_summary() {
  log_step "Instalação de mods concluída"
  cat <<EOF
Manifest: $(mods_manifest_path)

Ordem de carregamento (client_mods):
$(python3 "${DEPLOY_LINUX_DIR}/lib/mods_parser.py" list-client-mods \
  --manifest "$(mods_manifest_path)" 2>/dev/null | awk -F'\t' '{printf "  %3s  %s\n", $2, $1}' || echo "  (vazio)")

Parâmetro -mod= (gerado para start.sh):
  $(mods_build_client_mod_argument || echo "(vazio)")

EOF
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
  require_root
  log_step "DayZ Project — Install Mods"
  validate_environment
  install_workshop_mods_to_server
  install_local_mods_from_manifest
  install_project_keys
  steamcmd_clear_password
  print_summary
}

main "$@"
