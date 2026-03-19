#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../lib/core.sh
source "$REPO_DIR/scripts/lib/core.sh"
# shellcheck source=../lib/repo.sh
source "$REPO_DIR/scripts/lib/repo.sh"
# shellcheck source=../lib/packages.sh
source "$REPO_DIR/scripts/lib/packages.sh"
# shellcheck source=../lib/integrations.sh
source "$REPO_DIR/scripts/lib/integrations.sh"
# shellcheck source=../lib/verify.sh
source "$REPO_DIR/scripts/lib/verify.sh"
# shellcheck source=../lib/flow.sh
source "$REPO_DIR/scripts/lib/flow.sh"

main() {
  init_context "$REPO_DIR"
  parse_cli_args "$@"
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
  run_with_terminal_stdin sudo -v
  init_logging

  run_install
}

main "$@"
