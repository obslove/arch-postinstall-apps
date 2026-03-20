#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../lib/runtime-modules.sh
source "$REPO_DIR/scripts/lib/runtime-modules.sh"

source_runtime_modules "$REPO_DIR"

main() {
  config_init "$REPO_DIR"
  parse_cli_args "$@"
  finalize_config
  runtime_state_init
  trap cleanup EXIT

  ensure_not_root
  acquire_lock

  if [[ "$CHECK_ONLY" == "1" ]]; then
    set_step_total 3
  fi

  announce_step "Validando ambiente..."
  ensure_arch
  ensure_supported_session
  require_command pacman
  require_command sudo
  announce_prompt "Autenticando sudo..."
  ops_sudo_auth
  init_logging

  run_install
}

main "$@"
