#!/usr/bin/env bash
# =============================================================================
# status.sh — Painel de diagnóstico do ambiente DayZ
# =============================================================================
# Uso: ./status.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

load_env
apply_env_defaults

# -----------------------------------------------------------------------------
# Painel de diagnóstico
# -----------------------------------------------------------------------------

print_header() {
  echo ""
  echo "=============================================="
  echo "  DayZ Project — Diagnóstico"
  echo "=============================================="
  echo "  $(date +'%Y-%m-%d %H:%M:%S')"
  echo "=============================================="
  echo ""
}

print_server_panel() {
  echo "Servidor"
  local pid
  pid="$(get_server_pid)"
  if [[ -n "$pid" ]]; then
    status_ok "Online"
    status_label "PID" "$pid"
  else
    status_fail "Offline"
    status_label "PID" "—"
  fi
  echo ""
}

mod_exists_on_server() {
  local folder="$1"
  [[ -d "${DAYZ_SERVER_DIR}/${folder}" ]]
}

print_mods_panel() {
  echo "Mods"

  if ! mods_manifest_exists; then
    status_fail "manifest.yaml ausente"
    echo ""
    return
  fi

  if ! mods_has_parser; then
    status_fail "python3-yaml ou mods_parser.py indisponível"
    echo ""
    return
  fi

  local any=0 folder order name section
  while IFS=$'\t' read -r folder order name section; do
    [[ -z "$folder" ]] && continue
    any=1
    if mod_exists_on_server "$folder"; then
      status_ok "${folder}"
    else
      status_fail "${folder} (ausente em ${DAYZ_SERVER_DIR})"
    fi
  done < <(python3 "${DEPLOY_LINUX_DIR}/lib/mods_parser.py" list-client-mods \
    --manifest "$(mods_manifest_path)" 2>/dev/null || true)

  while IFS=$'\t' read -r folder order name section; do
    [[ -z "$folder" ]] && continue
    any=1
    if mod_exists_on_server "$folder"; then
      status_ok "${folder} [server]"
    else
      status_fail "${folder} [server] (ausente)"
    fi
  done < <(python3 "${DEPLOY_LINUX_DIR}/lib/mods_parser.py" list-server-mods \
    --manifest "$(mods_manifest_path)" 2>/dev/null || true)

  if [[ "$any" -eq 0 ]]; then
    status_label "" "(nenhum mod habilitado)"
  fi
  echo ""
}

print_steamcmd_panel() {
  echo "SteamCMD"
  local steamcmd_bin="${STEAMCMD_DIR}/steamcmd.sh"
  if [[ -x "$steamcmd_bin" ]] && [[ -f "${DAYZ_SERVER_DIR}/DayZServer_x64.exe" ]]; then
    status_ok "OK"
  elif [[ -x "$steamcmd_bin" ]]; then
    status_warn "SteamCMD OK — DayZ Server não instalado"
  else
    status_fail "Não instalado"
  fi
  echo ""
}

print_wine_panel() {
  echo "Wine"
  if command_exists wine && [[ -d "$WINEPREFIX" ]]; then
    status_ok "OK ($(wine --version 2>/dev/null || echo 'wine'))"
  elif command_exists wine; then
    status_warn "Wine instalado — prefixo ausente (${WINEPREFIX})"
  else
    status_fail "Não instalado"
  fi
  echo ""
}

print_profiles_panel() {
  echo "Profiles"
  if [[ -d "$DAYZ_PROFILES_DIR" ]]; then
    status_ok "OK"
  else
    status_fail "Diretório ausente: ${DAYZ_PROFILES_DIR}"
  fi
  echo ""
}

print_mission_panel() {
  echo "Mission"
  local template short_name
  template="$(mods_get_mission_template 2>/dev/null || true)"
  if [[ -n "$template" ]]; then
    short_name="${template##*.}"
    status_label "" "${short_name}"
    if [[ ! -d "${DAYZ_SERVER_DIR}/mpmissions/${template}" ]]; then
      status_fail "mpmissions/${template} não encontrada"
    fi
  else
    status_label "" "(não detectada)"
  fi
  echo ""
}

print_port_panel() {
  echo "Porta"
  status_label "" "${DAYZ_PORT}"
  if command_exists ss; then
    if ss -tulnp 2>/dev/null | grep -q ":${DAYZ_PORT} "; then
      status_ok "em escuta"
    fi
  fi
  echo ""
}

print_version_panel() {
  echo "Versão"
  local build
  build="$(mods_get_server_build 2>/dev/null || echo "unknown")"
  if [[ "$build" != "unknown" ]]; then
    status_label "" "build ${build}"
  else
    status_label "" "desconhecida"
  fi
  echo ""
}

print_validation_hint() {
  if mods_manifest_exists && mods_has_parser; then
    if ! validation_run true 2>/dev/null; then
      echo "Validação"
      status_fail "erros críticos — execute ./validate.sh"
      echo ""
    fi
  fi
}

print_extended_details() {
  log_step "Detalhes do sistema"
  echo "--- Memória ---"
  free -h 2>/dev/null || true
  echo ""
  echo "--- Disco (${DAYZ_BASE}) ---"
  df -h "$DAYZ_BASE" 2>/dev/null || log_warn "Base ausente: ${DAYZ_BASE}"
  echo ""
  if [[ -n "$(get_server_pid)" ]]; then
    echo "--- Processo ---"
    ps -p "$(get_server_pid)" -o pid,ppid,%cpu,%mem,etime,cmd --no-headers 2>/dev/null || true
    echo ""
  fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
  print_header
  print_server_panel
  print_mods_panel
  print_steamcmd_panel
  print_wine_panel
  print_profiles_panel
  print_mission_panel
  print_port_panel
  print_version_panel
  print_validation_hint
  print_extended_details
}

main "$@"
