#!/usr/bin/env bash
# lib/log.sh — Logging e saída de diagnóstico

log_info()  { echo "[INFO]  $(date +'%Y-%m-%d %H:%M:%S') $*"; }
log_warn()  { echo "[WARN]  $(date +'%Y-%m-%d %H:%M:%S') $*" >&2; }
log_error() { echo "[ERROR] $(date +'%Y-%m-%d %H:%M:%S') $*" >&2; }
log_step()  { echo ""; echo "==> $*"; echo ""; }

# Painel de status (status.sh)
status_ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; }
status_fail() { printf "  \033[31m✗\033[0m %s\n" "$*"; }
status_warn() { printf "  \033[33m!\033[0m %s\n" "$*"; }
status_label() { printf "  %-12s %s\n" "$1" "$2"; }
