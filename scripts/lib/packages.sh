#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034
# shellcheck source-path=SCRIPTDIR
# shellcheck disable=SC1091
# shellcheck source=scripts/lib/package-config.sh
# shellcheck source=scripts/lib/package-repos.sh
# shellcheck source=scripts/lib/package-install.sh
# shellcheck source=scripts/lib/components/aur-helper.sh

if false; then
  source "$SCRIPT_DIR/scripts/lib/package-config.sh"
  source "$SCRIPT_DIR/scripts/lib/package-repos.sh"
  source "$SCRIPT_DIR/scripts/lib/package-install.sh"
  source "$SCRIPT_DIR/scripts/lib/components/aur-helper.sh"
fi

PACKAGE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=package-config.sh
source "$PACKAGE_LIB_DIR/package-config.sh"
# shellcheck source=package-repos.sh
source "$PACKAGE_LIB_DIR/package-repos.sh"
# shellcheck source=package-install.sh
source "$PACKAGE_LIB_DIR/package-install.sh"
# shellcheck source=components/aur-helper.sh
source "$PACKAGE_LIB_DIR/components/aur-helper.sh"
