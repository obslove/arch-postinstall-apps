#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034
# shellcheck disable=SC1091

BOOTSTRAP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=step-result.sh
source "$BOOTSTRAP_LIB_DIR/step-result.sh"
# shellcheck source=ui.sh
source "$BOOTSTRAP_LIB_DIR/ui.sh"
# shellcheck source=process.sh
source "$BOOTSTRAP_LIB_DIR/process.sh"
# shellcheck source=locking.sh
source "$BOOTSTRAP_LIB_DIR/locking.sh"
# shellcheck source=env.sh
source "$BOOTSTRAP_LIB_DIR/env.sh"
# shellcheck source=repo.sh
source "$BOOTSTRAP_LIB_DIR/repo.sh"
