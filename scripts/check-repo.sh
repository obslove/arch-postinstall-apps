#!/usr/bin/env bash
# shellcheck shell=bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCAL_INSTALL_FILE="$REPO_DIR/install.sh"
PUBLIC_BOOTSTRAP_FILE="$REPO_DIR/dist/install.sh"

# shellcheck disable=SC1091
source "$REPO_DIR/scripts/bootstrap/bootstrap-modules.sh"
# shellcheck disable=SC1091
source "$REPO_DIR/scripts/lib/runtime-modules.sh"

SYNTAX_FILES=()
SHELLCHECK_FILES=()

append_check_file() {
  local array_name="$1"
  local file_path="$2"
  local existing
  # shellcheck disable=SC2178
  declare -n target_array="$array_name"

  for existing in "${target_array[@]}"; do
    [[ "$existing" == "$file_path" ]] && return 0
  done

  target_array+=("$file_path")
}

append_manifest_files() {
  local target_array_name="$1"
  shift
  local relative_path

  for relative_path in "$@"; do
    append_check_file "$target_array_name" "$REPO_DIR/$relative_path"
  done
}

check_help_output() {
  bash "$LOCAL_INSTALL_FILE" --help | grep -Fq -- '--exclusive-key'
  bash "$LOCAL_INSTALL_FILE" --help | grep -Fq -- '--ssh-name'
  bash "$PUBLIC_BOOTSTRAP_FILE" --help | grep -Fq -- '--exclusive-key'
  bash "$PUBLIC_BOOTSTRAP_FILE" --help | grep -Fq -- '--ssh-name'
}

check_cli_parser() {
  local parser_log

  parser_log="$(mktemp)"

  if bash "$LOCAL_INSTALL_FILE" --opcao-inexistente >"$parser_log" 2>&1; then
    rm -f "$parser_log"
    return 1
  fi
  grep -Fq 'opção desconhecida' "$parser_log"

  if bash "$LOCAL_INSTALL_FILE" -s >"$parser_log" 2>&1; then
    rm -f "$parser_log"
    return 1
  fi
  grep -Fq 'faltou informar o valor' "$parser_log"

  if bash "$LOCAL_INSTALL_FILE" -- lixo >"$parser_log" 2>&1; then
    rm -f "$parser_log"
    return 1
  fi
  grep -Fq 'argumentos extras não reconhecidos' "$parser_log"

  if bash "$PUBLIC_BOOTSTRAP_FILE" --opcao-inexistente >"$parser_log" 2>&1; then
    rm -f "$parser_log"
    return 1
  fi
  grep -Fq 'opção desconhecida' "$parser_log"

  if bash "$PUBLIC_BOOTSTRAP_FILE" -s >"$parser_log" 2>&1; then
    rm -f "$parser_log"
    return 1
  fi
  grep -Fq 'faltou informar o valor' "$parser_log"

  if bash "$PUBLIC_BOOTSTRAP_FILE" -- lixo >"$parser_log" 2>&1; then
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

check_readme_links() {
  if rg -n '/home/' "$REPO_DIR/README.md" >/dev/null 2>&1; then
    printf 'Erro: README.md contém caminhos absolutos locais.\n' >&2
    return 1
  fi
}

check_cloudflare_deploy_files() {
  test -f "$REPO_DIR/.github/workflows/deploy-bootstrap.yml"
  test -f "$REPO_DIR/cloudflare/bootstrap-worker/src/index.js"
  test -f "$REPO_DIR/cloudflare/bootstrap-worker/wrangler.toml"
  node --check "$REPO_DIR/cloudflare/bootstrap-worker/src/index.js"
  grep -Fqx 'name = "obslove"' "$REPO_DIR/cloudflare/bootstrap-worker/wrangler.toml"
  grep -Fqx 'main = "src/index.js"' "$REPO_DIR/cloudflare/bootstrap-worker/wrangler.toml"
  grep -Fqx 'compatibility_date = "2026-03-21"' "$REPO_DIR/cloudflare/bootstrap-worker/wrangler.toml"
  grep -Fqx 'workers_dev = false' "$REPO_DIR/cloudflare/bootstrap-worker/wrangler.toml"
  grep -Fq 'pattern = "obslove.dev/*"' "$REPO_DIR/cloudflare/bootstrap-worker/wrangler.toml"
}

build_check_file_lists() {
  append_check_file SYNTAX_FILES "$LOCAL_INSTALL_FILE"
  append_check_file SYNTAX_FILES "$PUBLIC_BOOTSTRAP_FILE"
  append_check_file SYNTAX_FILES "$REPO_DIR/scripts/build-bootstrap.sh"
  append_check_file SYNTAX_FILES "$REPO_DIR/scripts/build-shellcheck-runtime.sh"
  append_check_file SYNTAX_FILES "$REPO_DIR/scripts/check-published-bootstrap.sh"
  append_manifest_files SYNTAX_FILES "${BOOTSTRAP_CHECK_FILES[@]}"
  append_check_file SYNTAX_FILES "$REPO_DIR/scripts/install/main.sh"
  append_manifest_files SYNTAX_FILES "${RUNTIME_CHECK_FILES[@]}"
  append_check_file SYNTAX_FILES "$REPO_DIR/scripts/update-readme-packages.sh"
  append_check_file SYNTAX_FILES "$REPO_DIR/config/components.sh"

  append_check_file SHELLCHECK_FILES "$LOCAL_INSTALL_FILE"
  append_check_file SHELLCHECK_FILES "$PUBLIC_BOOTSTRAP_FILE"
  append_check_file SHELLCHECK_FILES "$REPO_DIR/scripts/check-repo.sh"
  append_check_file SHELLCHECK_FILES "$REPO_DIR/scripts/build-bootstrap.sh"
  append_check_file SHELLCHECK_FILES "$REPO_DIR/scripts/build-shellcheck-runtime.sh"
  append_check_file SHELLCHECK_FILES "$REPO_DIR/scripts/check-published-bootstrap.sh"
  append_manifest_files SHELLCHECK_FILES "${BOOTSTRAP_CHECK_FILES[@]}"
  append_check_file SHELLCHECK_FILES "$REPO_DIR/scripts/install/main.sh"
  append_manifest_files SHELLCHECK_FILES "${RUNTIME_CHECK_FILES[@]}"
  append_check_file SHELLCHECK_FILES "$REPO_DIR/scripts/update-readme-packages.sh"
  append_check_file SHELLCHECK_FILES "$REPO_DIR/config/components.sh"
}

main() {
  build_check_file_lists
  bash "$REPO_DIR/scripts/build-bootstrap.sh" --check
  bash "$REPO_DIR/scripts/build-shellcheck-runtime.sh" --check
  bash "$REPO_DIR/scripts/update-readme-packages.sh" --check
  bash -n "${SYNTAX_FILES[@]}"
  shellcheck -x "${SHELLCHECK_FILES[@]}"
  check_help_output
  check_cli_parser
  check_readme_commands
  check_readme_links
  check_cloudflare_deploy_files
}

main "$@"
