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
# shellcheck source=../lib/ops.sh
source "$REPO_DIR/scripts/lib/ops.sh"
# shellcheck source=../lib/components.sh
source "$REPO_DIR/scripts/lib/components.sh"
# shellcheck source=../lib/components/codex.sh
source "$REPO_DIR/scripts/lib/components/codex.sh"
# shellcheck source=../lib/components/desktop.sh
source "$REPO_DIR/scripts/lib/components/desktop.sh"
# shellcheck source=../lib/components/github-ssh.sh
source "$REPO_DIR/scripts/lib/components/github-ssh.sh"
# shellcheck source=../lib/packages.sh
source "$REPO_DIR/scripts/lib/packages.sh"
# shellcheck source=../lib/verify.sh
source "$REPO_DIR/scripts/lib/verify.sh"
# shellcheck source=../lib/summary.sh
source "$REPO_DIR/scripts/lib/summary.sh"
# shellcheck source=../lib/pipeline.sh
source "$REPO_DIR/scripts/lib/pipeline.sh"
# shellcheck source=../lib/flow.sh
source "$REPO_DIR/scripts/lib/flow.sh"

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
