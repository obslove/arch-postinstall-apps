#!/usr/bin/env bash
# shellcheck shell=bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SYNTAX_FILES=(
  "$REPO_DIR/install.sh"
  "$REPO_DIR/scripts/build-bootstrap.sh"
  "$REPO_DIR/scripts/bootstrap/entrypoint.sh"
  "$REPO_DIR/scripts/install/main.sh"
  "$REPO_DIR/scripts/lib/cli.sh"
  "$REPO_DIR/scripts/lib/ops.sh"
  "$REPO_DIR/scripts/lib/shared.sh"
  "$REPO_DIR/scripts/lib/core.sh"
  "$REPO_DIR/scripts/lib/repo.sh"
  "$REPO_DIR/scripts/lib/packages.sh"
  "$REPO_DIR/scripts/lib/integrations.sh"
  "$REPO_DIR/scripts/lib/verify.sh"
  "$REPO_DIR/scripts/lib/summary.sh"
  "$REPO_DIR/scripts/lib/pipeline.sh"
  "$REPO_DIR/scripts/lib/flow.sh"
  "$REPO_DIR/scripts/update-readme-packages.sh"
  "$REPO_DIR/config/components.sh"
)

SHELLCHECK_FILES=(
  "$REPO_DIR/install.sh"
  "$REPO_DIR/scripts/check-repo.sh"
  "$REPO_DIR/scripts/build-bootstrap.sh"
  "$REPO_DIR/scripts/bootstrap/entrypoint.sh"
  "$REPO_DIR/scripts/install/main.sh"
  "$REPO_DIR/scripts/lib/cli.sh"
  "$REPO_DIR/scripts/lib/ops.sh"
  "$REPO_DIR/scripts/lib/shellcheck-runtime.sh"
  "$REPO_DIR/scripts/lib/core.sh"
  "$REPO_DIR/scripts/lib/shared.sh"
  "$REPO_DIR/scripts/lib/repo.sh"
  "$REPO_DIR/scripts/lib/packages.sh"
  "$REPO_DIR/scripts/lib/integrations.sh"
  "$REPO_DIR/scripts/lib/verify.sh"
  "$REPO_DIR/scripts/lib/summary.sh"
  "$REPO_DIR/scripts/lib/pipeline.sh"
  "$REPO_DIR/scripts/lib/flow.sh"
  "$REPO_DIR/scripts/update-readme-packages.sh"
  "$REPO_DIR/config/components.sh"
)

check_help_output() {
  bash "$REPO_DIR/install.sh" --help | grep -Fq -- '--exclusive-key'
  bash "$REPO_DIR/install.sh" --help | grep -Fq -- '--ssh-name'
}

check_cli_parser() {
  local parser_log

  parser_log="$(mktemp)"

  if bash "$REPO_DIR/install.sh" --opcao-inexistente >"$parser_log" 2>&1; then
    rm -f "$parser_log"
    return 1
  fi
  grep -Fq 'opção desconhecida' "$parser_log"

  if bash "$REPO_DIR/install.sh" -s >"$parser_log" 2>&1; then
    rm -f "$parser_log"
    return 1
  fi
  grep -Fq 'faltou informar o valor' "$parser_log"

  if bash "$REPO_DIR/install.sh" -- lixo >"$parser_log" 2>&1; then
    rm -f "$parser_log"
    return 1
  fi
  grep -Fq 'argumentos extras não reconhecidos' "$parser_log"
  rm -f "$parser_log"
}

check_readme_commands() {
  grep -Fqx 'curl -fsSL https://obslove.dev | bash' "$REPO_DIR/README.md"
  grep -Fqx 'curl -fsSL https://obslove.dev | bash -s --' "$REPO_DIR/README.md"
}

main() {
  bash "$REPO_DIR/scripts/build-bootstrap.sh" --check
  bash "$REPO_DIR/scripts/update-readme-packages.sh" --check
  bash -n "${SYNTAX_FILES[@]}"
  shellcheck -x "${SHELLCHECK_FILES[@]}"
  check_help_output
  check_cli_parser
  check_readme_commands
}

main "$@"
