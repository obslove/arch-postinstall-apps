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
# shellcheck source=../lib/components/aur-helper.sh
source "$REPO_DIR/scripts/lib/components/aur-helper.sh"
# shellcheck source=../lib/components/desktop.sh
source "$REPO_DIR/scripts/lib/components/desktop.sh"
# shellcheck source=../lib/components/github-ssh.sh
source "$REPO_DIR/scripts/lib/components/github-ssh.sh"
# shellcheck source=../lib/package-config.sh
source "$REPO_DIR/scripts/lib/package-config.sh"
# shellcheck source=../lib/package-repos.sh
source "$REPO_DIR/scripts/lib/package-repos.sh"
# shellcheck source=../lib/package-install.sh
source "$REPO_DIR/scripts/lib/package-install.sh"
# shellcheck source=../lib/verification.sh
source "$REPO_DIR/scripts/lib/verification.sh"
# shellcheck source=../lib/repair.sh
source "$REPO_DIR/scripts/lib/repair.sh"
# shellcheck source=../lib/summary.sh
source "$REPO_DIR/scripts/lib/summary.sh"
# shellcheck source=../lib/pipeline.sh
source "$REPO_DIR/scripts/lib/pipeline.sh"
# shellcheck source=../lib/steps/system.sh
source "$REPO_DIR/scripts/lib/steps/system.sh"
# shellcheck source=../lib/steps/packages.sh
source "$REPO_DIR/scripts/lib/steps/packages.sh"
# shellcheck source=../lib/steps/desktop.sh
source "$REPO_DIR/scripts/lib/steps/desktop.sh"
# shellcheck source=../lib/steps/github-ssh.sh
source "$REPO_DIR/scripts/lib/steps/github-ssh.sh"
# shellcheck source=../lib/steps/verification.sh
source "$REPO_DIR/scripts/lib/steps/verification.sh"
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
