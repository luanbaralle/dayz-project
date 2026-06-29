#!/usr/bin/env bash
# lib/mods.sh — Interface bash para mods/manifest.yaml

MODS_MANIFEST_REL="mods/manifest.yaml"
MODS_PARSER="${DEPLOY_LINUX_DIR}/lib/mods_parser.py"

mods_manifest_path() {
  echo "${DAYZ_PROJECT_DIR}/${MODS_MANIFEST_REL}"
}

mods_local_dir() {
  echo "${DAYZ_PROJECT_DIR}/mods/local"
}

mods_keys_dir() {
  echo "${DAYZ_PROJECT_DIR}/mods/keys"
}

mods_manifest_exists() {
  [[ -f "$(mods_manifest_path)" ]]
}

mods_has_parser() {
  command -v python3 &>/dev/null && python3 -c "import yaml" 2>/dev/null \
    && [[ -f "$MODS_PARSER" ]]
}

mods_require_parser() {
  require_command python3
  if ! python3 -c "import yaml" 2>/dev/null; then
    log_error "Instale: sudo apt-get install -y python3-yaml"
    exit 1
  fi
  if [[ ! -f "$MODS_PARSER" ]]; then
    log_error "Parser não encontrado: ${MODS_PARSER}"
    exit 1
  fi
}

mods_require_manifest() {
  if ! mods_manifest_exists; then
    log_error "Manifest não encontrado: $(mods_manifest_path)"
    exit 1
  fi
  mods_require_parser
}

mods_parser_cmd() {
  mods_require_manifest
  python3 "$MODS_PARSER" "$@" --manifest "$(mods_manifest_path)"
}

mods_workshop_app_id() {
  mods_parser_cmd workshop-app-id
}

mods_workshop_content_path() {
  local workshop_id="$1"
  local app_id
  app_id="$(mods_workshop_app_id)"
  steam_workshop_item_path "$workshop_id" "$app_id"
}

mods_build_client_mod_argument() {
  if ! mods_manifest_exists || ! mods_has_parser; then
    echo ""
    return 0
  fi
  python3 "$MODS_PARSER" client-mod-arg --manifest "$(mods_manifest_path)"
}

mods_build_server_mod_argument() {
  if ! mods_manifest_exists || ! mods_has_parser; then
    echo ""
    return 0
  fi
  python3 "$MODS_PARSER" server-mod-arg --manifest "$(mods_manifest_path)"
}

mods_print_load_order() {
  if ! mods_has_parser || ! mods_manifest_exists; then
    return 0
  fi
  log_step "Ordem de carregamento (client_mods)"
  local line folder order name section
  while IFS=$'\t' read -r folder order name section; do
    printf "  %3s  %-20s  %s  [%s]\n" "$order" "$folder" "$name" "$section"
  done < <(python3 "$MODS_PARSER" list-client-mods --manifest "$(mods_manifest_path)")
}

mods_python_workshop_client() {
  python3 "$MODS_PARSER" workshop-client-mods --manifest "$(mods_manifest_path)"
}

mods_python_workshop_server() {
  python3 "$MODS_PARSER" workshop-server-mods --manifest "$(mods_manifest_path)"
}

mods_python_local_folders() {
  python3 "$MODS_PARSER" list-client-mods --manifest "$(mods_manifest_path)" \
    | awk -F'\t' '$4 == "local_mods" {print $1}'
}

mods_get_mission_template() {
  python3 "$MODS_PARSER" mission \
    --manifest "$(mods_manifest_path)" \
    --server-dir "$DAYZ_SERVER_DIR" \
    --project-dir "$DAYZ_PROJECT_DIR" \
    --config "$DAYZ_CONFIG"
}

mods_get_server_build() {
  python3 "$MODS_PARSER" server-build --server-dir "$DAYZ_SERVER_DIR"
}
