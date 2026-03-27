#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib/cli.sh
# shellcheck source=../lib/runtime-config.sh
# shellcheck source=../lib/invocation-context.sh
# shellcheck source=../lib/step-result.sh
# shellcheck source=../lib/ui.sh
# shellcheck source=../lib/pipeline.sh
# shellcheck source=../lib/step-manifest.sh
# shellcheck source=../lib/process.sh
# shellcheck source=../lib/locking.sh
# shellcheck source=../lib/env.sh
# shellcheck source=../lib/ops.sh
# shellcheck source=../lib/repo.sh
# shellcheck source=../bootstrap/repo-sync.sh
# shellcheck source=../bootstrap/config.sh
# shellcheck source=../bootstrap/steps/system.sh
# shellcheck source=../bootstrap/steps/packages.sh
# shellcheck source=../bootstrap/steps/repo.sh
# shellcheck source=../bootstrap/entrypoint.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$REPO_DIR/scripts/lib/cli.sh"
source "$REPO_DIR/scripts/lib/runtime-config.sh"
source "$REPO_DIR/scripts/lib/invocation-context.sh"
source "$REPO_DIR/scripts/lib/step-result.sh"
source "$REPO_DIR/scripts/lib/ui.sh"
source "$REPO_DIR/scripts/lib/pipeline.sh"
source "$REPO_DIR/scripts/lib/step-manifest.sh"
source "$REPO_DIR/scripts/lib/process.sh"
source "$REPO_DIR/scripts/lib/locking.sh"
source "$REPO_DIR/scripts/lib/env.sh"
source "$REPO_DIR/scripts/lib/ops.sh"
source "$REPO_DIR/scripts/lib/repo.sh"
source "$REPO_DIR/scripts/bootstrap/repo-sync.sh"
source "$REPO_DIR/scripts/bootstrap/config.sh"
source "$REPO_DIR/scripts/bootstrap/steps/system.sh"
source "$REPO_DIR/scripts/bootstrap/steps/packages.sh"
source "$REPO_DIR/scripts/bootstrap/steps/repo.sh"
