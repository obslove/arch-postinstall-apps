#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034

_BOOTSTRAP_MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
_BOOTSTRAP_MODULES_REPO_DIR="$(cd "$_BOOTSTRAP_MODULES_DIR/../.." && pwd)"

# shellcheck source=scripts/lib/module-manifest.sh
source "$_BOOTSTRAP_MODULES_REPO_DIR/scripts/lib/module-manifest.sh"

readonly -a BOOTSTRAP_FRAGMENT_FILES=("${MODULE_BOOTSTRAP_FRAGMENT_FILES[@]}")
readonly -a BOOTSTRAP_CHECK_FILES=(
  "scripts/lib/module-manifest.sh"
  "scripts/bootstrap/bootstrap-modules.sh"
  "${MODULE_BOOTSTRAP_CHECK_FILES[@]}"
)

unset _BOOTSTRAP_MODULES_DIR
unset _BOOTSTRAP_MODULES_REPO_DIR
