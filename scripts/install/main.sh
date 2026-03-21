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
  load_runtime_invocation_context "$REPO_DIR" "$@"
  runtime_state_init
  validate_managed_paths
  trap cleanup EXIT

  ensure_not_root
  acquire_lock

  run_install
}

main "$@"
