#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034
# shellcheck source-path=SCRIPTDIR
# shellcheck source=scripts/lib/step-result.sh
# shellcheck source=scripts/lib/ui.sh
# shellcheck source=scripts/lib/process.sh
# shellcheck source=scripts/lib/locking.sh
# shellcheck source=scripts/lib/env.sh
# shellcheck source=scripts/lib/runtime-state.sh

if false; then
  source "$SCRIPT_DIR/scripts/lib/step-result.sh"
  source "$SCRIPT_DIR/scripts/lib/ui.sh"
  source "$SCRIPT_DIR/scripts/lib/process.sh"
  source "$SCRIPT_DIR/scripts/lib/locking.sh"
  source "$SCRIPT_DIR/scripts/lib/env.sh"
  source "$SCRIPT_DIR/scripts/lib/runtime-state.sh"
fi

mark_support_package() {
  state_add_support_package "$1"
}

mark_environment_package() {
  state_add_environment_package "$1"
}

mark_verified_item() {
  state_add_verified_item "$1"
}

mark_missing_item() {
  state_add_missing_item "$1"
}

SHARED_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=step-result.sh
source "$SHARED_LIB_DIR/step-result.sh"
# shellcheck source=ui.sh
source "$SHARED_LIB_DIR/ui.sh"
# shellcheck source=process.sh
source "$SHARED_LIB_DIR/process.sh"
# shellcheck source=locking.sh
source "$SHARED_LIB_DIR/locking.sh"
# shellcheck source=env.sh
source "$SHARED_LIB_DIR/env.sh"
