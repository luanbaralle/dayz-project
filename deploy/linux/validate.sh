#!/usr/bin/env bash
# =============================================================================
# validate.sh — Validação declarativa antes de iniciar o servidor
# =============================================================================
# Valida manifest.yaml, mods, dependências, serverDZ.cfg, missão e diretórios.
# Uso: ./validate.sh [--quiet]
# Retorno: 0 = OK, 1 = erros críticos
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

QUIET=false
if [[ "${1:-}" == "--quiet" ]]; then
  QUIET=true
fi

load_env
apply_env_defaults

if [[ "$QUIET" == "true" ]]; then
  validation_run true
else
  log_step "DayZ Project — Validação"
  validation_run false
fi
