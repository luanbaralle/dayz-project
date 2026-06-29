#!/usr/bin/env bash
# lib/process.sh — Estado do processo do servidor

is_server_running() {
  if [[ -f "$DAYZ_PID_FILE" ]]; then
    local pid
    pid="$(cat "$DAYZ_PID_FILE")"
    if kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  fi
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
