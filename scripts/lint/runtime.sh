#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib/core.sh
# shellcheck source=../lib/components.sh
# shellcheck source=../lib/components/aur-helper.sh
# shellcheck source=../lib/components/codex.sh
# shellcheck source=../lib/components/desktop.sh
# shellcheck source=../lib/components/github-ssh.sh
# shellcheck source=../lib/package-config.sh
# shellcheck source=../lib/package-repos.sh
# shellcheck source=../lib/package-install.sh
# shellcheck source=../lib/verification.sh
# shellcheck source=../lib/repair.sh
# shellcheck source=../lib/summary.sh
# shellcheck source=../lib/steps/system.sh
# shellcheck source=../lib/steps/packages.sh
# shellcheck source=../lib/steps/codex.sh
# shellcheck source=../lib/steps/desktop.sh
# shellcheck source=../lib/steps/github-ssh.sh
# shellcheck source=../lib/steps/verification.sh
# shellcheck source=../lib/flow.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$REPO_DIR/scripts/lib/core.sh"
source "$REPO_DIR/scripts/lib/components.sh"
source "$REPO_DIR/scripts/lib/components/aur-helper.sh"
source "$REPO_DIR/scripts/lib/components/codex.sh"
source "$REPO_DIR/scripts/lib/components/desktop.sh"
source "$REPO_DIR/scripts/lib/components/github-ssh.sh"
source "$REPO_DIR/scripts/lib/package-config.sh"
source "$REPO_DIR/scripts/lib/package-repos.sh"
source "$REPO_DIR/scripts/lib/package-install.sh"
source "$REPO_DIR/scripts/lib/verification.sh"
source "$REPO_DIR/scripts/lib/repair.sh"
source "$REPO_DIR/scripts/lib/summary.sh"
source "$REPO_DIR/scripts/lib/steps/system.sh"
source "$REPO_DIR/scripts/lib/steps/packages.sh"
source "$REPO_DIR/scripts/lib/steps/codex.sh"
source "$REPO_DIR/scripts/lib/steps/desktop.sh"
source "$REPO_DIR/scripts/lib/steps/github-ssh.sh"
source "$REPO_DIR/scripts/lib/steps/verification.sh"
source "$REPO_DIR/scripts/lib/flow.sh"
