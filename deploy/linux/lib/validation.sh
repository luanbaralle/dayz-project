#!/usr/bin/env bash
# lib/validation.sh — Validação declarativa do ambiente

# Executa validação completa. Retorna 0 se OK, 1 se erros críticos.
# Uso: validation_run [--quiet]
validation_run() {
  local quiet="${1:-false}"

  mods_require_manifest

  if [[ "$quiet" != "true" ]]; then
    log_step "Validação do ambiente"
  fi

  if python3 "${DEPLOY_LINUX_DIR}/lib/mods_parser.py" validate \
    --manifest "$(mods_manifest_path)" \
    --server-dir "$DAYZ_SERVER_DIR" \
    --project-dir "$DAYZ_PROJECT_DIR" \
    --profiles-dir "$DAYZ_PROFILES_DIR" \
    --config "$DAYZ_CONFIG"; then
    [[ "$quiet" != "true" ]] && log_info "Validação concluída sem erros críticos."
    return 0
  fi

  [[ "$quiet" != "true" ]] && \
    log_error "Validação falhou — corrija os erros acima antes de iniciar o servidor."
  return 1
}
