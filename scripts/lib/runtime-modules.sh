#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034

_RUNTIME_MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
_RUNTIME_MODULES_REPO_DIR="$(cd "$_RUNTIME_MODULES_DIR/../.." && pwd)"

# shellcheck source=scripts/lib/module-manifest.sh
source "$_RUNTIME_MODULES_REPO_DIR/scripts/lib/module-manifest.sh"

readonly -a RUNTIME_ENTRYPOINT_MODULE_FILES=("${MODULE_RUNTIME_ENTRYPOINT_FILES[@]}")
readonly -a RUNTIME_CHECK_FILES=(
  "scripts/lib/module-manifest.sh"
  "scripts/lib/runtime-modules.sh"
  "${MODULE_RUNTIME_CHECK_FILES[@]}"
)

unset _RUNTIME_MODULES_DIR
unset _RUNTIME_MODULES_REPO_DIR

source_runtime_modules() {
  local repo_dir="$1"
  local module_path

  for module_path in "${RUNTIME_ENTRYPOINT_MODULE_FILES[@]}"; do
    # shellcheck disable=SC1090
    source "$repo_dir/$module_path"
  done
}
