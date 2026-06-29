#!/usr/bin/env bash
# =============================================================================
# status.sh — Exibe status do ambiente DayZ (CPU, memória, processos)
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
# Funções
# -----------------------------------------------------------------------------

print_header() {
  echo ""
  echo "=============================================="
  echo "  DayZ Project — Status do Ambiente Linux"
  echo "=============================================="
  echo "  Data: $(date +'%Y-%m-%d %H:%M:%S')"
  echo "=============================================="
  echo ""
}

print_system_resources() {
  log_step "Recursos do sistema"

  echo "--- Memória ---"
  free -h
  echo ""

  echo "--- CPU (load average) ---"
  uptime
  echo ""

  echo "--- Disco (${DAYZ_BASE}) ---"
  if [[ -d "$DAYZ_BASE" ]]; then
    df -h "$DAYZ_BASE"
  else
    log_warn "Diretório base não existe: ${DAYZ_BASE}"
  fi
  echo ""
}

print_dayz_server_status() {
  log_step "DayZ Dedicated Server"

  local pid
  pid="$(get_server_pid)"

  if [[ -n "$pid" ]]; then
    echo "  Status:    RODANDO"
    echo "  PID:       ${pid}"
    echo "  Porta:     ${DAYZ_PORT}"
    echo "  tmux:      ${DAYZ_TMUX_SESSION}"

    if tmux has-session -t "$DAYZ_TMUX_SESSION" 2>/dev/null; then
      echo "  Sessão:    ATIVA"
    else
      echo "  Sessão:    INATIVA (processo órfão?)"
    fi

    echo ""
    echo "  Uso de recursos do processo:"
    ps -p "$pid" -o pid,ppid,%cpu,%mem,vsz,rss,etime,cmd --no-headers 2>/dev/null || true

    # Processos filhos Wine
    echo ""
    echo "  Processos Wine relacionados:"
    pgrep -a -f "wineserver|wine.*DayZ" 2>/dev/null || echo "    (nenhum)"
  else
    echo "  Status:    PARADO"
    echo "  PID:       —"
  fi
  echo ""
}

print_wine_status() {
  log_step "Wine"

  if command_exists wine; then
    echo "  Versão:    $(wine --version 2>/dev/null || echo 'desconhecida')"
  else
    echo "  Versão:    NÃO INSTALADO"
  fi

  echo "  WINEPREFIX: ${WINEPREFIX}"

  if [[ -d "$WINEPREFIX" ]]; then
    echo "  Prefixo:   EXISTE ($(du -sh "$WINEPREFIX" 2>/dev/null | cut -f1))"
  else
    echo "  Prefixo:   NÃO CRIADO"
  fi
  echo ""
}

print_steamcmd_status() {
  log_step "SteamCMD"

  local steamcmd_bin="${STEAMCMD_DIR}/steamcmd.sh"

  if [[ -x "$steamcmd_bin" ]]; then
    echo "  Status:    INSTALADO"
    echo "  Caminho:   ${steamcmd_bin}"
  else
    echo "  Status:    NÃO INSTALADO"
  fi

  if [[ -d "$DAYZ_SERVER_DIR" ]]; then
    echo "  Servidor:  ${DAYZ_SERVER_DIR} ($(du -sh "$DAYZ_SERVER_DIR" 2>/dev/null | cut -f1))"
    if [[ -f "${DAYZ_SERVER_DIR}/DayZServer_x64.exe" ]]; then
      echo "  Executável: OK"
    else
      echo "  Executável: AUSENTE"
    fi
  else
    echo "  Servidor:  NÃO INSTALADO"
  fi
  echo ""
}

print_project_status() {
  log_step "Projeto Git"

  if [[ -d "${DAYZ_PROJECT_DIR}/.git" ]]; then
    echo "  Repositório: ${DAYZ_PROJECT_DIR}"
    echo "  Branch:      $(git -C "$DAYZ_PROJECT_DIR" branch --show-current 2>/dev/null || echo '?')"
    echo "  Commit:      $(git -C "$DAYZ_PROJECT_DIR" rev-parse --short HEAD 2>/dev/null || echo '?')"
    echo "  Remote:      $(git -C "$DAYZ_PROJECT_DIR" remote get-url origin 2>/dev/null || echo '?')"
  else
    echo "  Repositório: NÃO CLONADO"
    echo "  Esperado em: ${DAYZ_PROJECT_DIR}"
  fi
  echo ""
}

print_directory_status() {
  log_step "Diretórios"

  local dirs=(
    "Base:${DAYZ_BASE}"
    "Server:${DAYZ_SERVER_DIR}"
    "Project:${DAYZ_PROJECT_DIR}"
    "Profiles:${DAYZ_PROFILES_DIR}"
    "Backups:${DAYZ_BACKUPS_DIR}"
    "Logs:${DAYZ_LOGS_DIR}"
    "SteamCMD:${STEAMCMD_DIR}"
  )

  for entry in "${dirs[@]}"; do
    local label="${entry%%:*}"
    local path="${entry#*:}"
    if [[ -d "$path" ]]; then
      printf "  %-12s %s (%s)\n" "${label}:" "$path" "$(du -sh "$path" 2>/dev/null | cut -f1)"
    else
      printf "  %-12s %s (AUSENTE)\n" "${label}:" "$path"
    fi
  done
  echo ""
}

print_network_ports() {
  log_step "Portas de rede"

  if command_exists ss; then
    echo "  Porta ${DAYZ_PORT} (DayZ):"
    ss -tulnp 2>/dev/null | grep ":${DAYZ_PORT} " || echo "    (não em escuta)"
  else
    log_warn "Comando 'ss' não disponível — pulando verificação de portas."
  fi
  echo ""
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
  print_header
  print_system_resources
  print_dayz_server_status
  print_wine_status
  print_steamcmd_status
  print_project_status
  print_directory_status
  print_network_ports
}

main "$@"
