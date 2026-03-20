#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034

readonly -a RUNTIME_ENTRYPOINT_MODULE_FILES=(
  "scripts/lib/core.sh"
  "scripts/lib/repo.sh"
  "scripts/lib/ops.sh"
  "scripts/lib/components.sh"
  "scripts/lib/components/codex.sh"
  "scripts/lib/components/aur-helper.sh"
  "scripts/lib/components/desktop.sh"
  "scripts/lib/components/github-ssh.sh"
  "scripts/lib/package-config.sh"
  "scripts/lib/package-repos.sh"
  "scripts/lib/package-install.sh"
  "scripts/lib/verification.sh"
  "scripts/lib/repair.sh"
  "scripts/lib/summary.sh"
  "scripts/lib/pipeline.sh"
  "scripts/lib/steps/system.sh"
  "scripts/lib/steps/packages.sh"
  "scripts/lib/steps/desktop.sh"
  "scripts/lib/steps/github-ssh.sh"
  "scripts/lib/steps/verification.sh"
  "scripts/lib/flow.sh"
)

readonly -a RUNTIME_CHECK_FILES=(
  "scripts/lib/runtime-modules.sh"
  "scripts/lib/cli.sh"
  "scripts/lib/components.sh"
  "scripts/lib/runtime-state.sh"
  "scripts/lib/status.sh"
  "scripts/lib/ops.sh"
  "scripts/lib/shellcheck-runtime.sh"
  "scripts/lib/step-result.sh"
  "scripts/lib/ui.sh"
  "scripts/lib/process.sh"
  "scripts/lib/locking.sh"
  "scripts/lib/env.sh"
  "scripts/lib/package-config.sh"
  "scripts/lib/package-repos.sh"
  "scripts/lib/package-install.sh"
  "scripts/lib/core.sh"
  "scripts/lib/repo.sh"
  "scripts/lib/components/aur-helper.sh"
  "scripts/lib/components/codex.sh"
  "scripts/lib/components/desktop.sh"
  "scripts/lib/components/github-ssh/clipboard.sh"
  "scripts/lib/components/github-ssh/auth.sh"
  "scripts/lib/components/github-ssh/key.sh"
  "scripts/lib/components/github-ssh/publish.sh"
  "scripts/lib/components/github-ssh.sh"
  "scripts/lib/verification.sh"
  "scripts/lib/repair.sh"
  "scripts/lib/summary.sh"
  "scripts/lib/pipeline.sh"
  "scripts/lib/steps/system.sh"
  "scripts/lib/steps/packages.sh"
  "scripts/lib/steps/desktop.sh"
  "scripts/lib/steps/github-ssh.sh"
  "scripts/lib/steps/verification.sh"
  "scripts/lib/flow.sh"
)

if false; then
  # shellcheck source=scripts/lib/core.sh
  source "$REPO_DIR/scripts/lib/core.sh"
  # shellcheck source=scripts/lib/repo.sh
  source "$REPO_DIR/scripts/lib/repo.sh"
  # shellcheck source=scripts/lib/ops.sh
  source "$REPO_DIR/scripts/lib/ops.sh"
  # shellcheck source=scripts/lib/components.sh
  source "$REPO_DIR/scripts/lib/components.sh"
  # shellcheck source=scripts/lib/components/codex.sh
  source "$REPO_DIR/scripts/lib/components/codex.sh"
  # shellcheck source=scripts/lib/components/aur-helper.sh
  source "$REPO_DIR/scripts/lib/components/aur-helper.sh"
  # shellcheck source=scripts/lib/components/desktop.sh
  source "$REPO_DIR/scripts/lib/components/desktop.sh"
  # shellcheck source=scripts/lib/components/github-ssh.sh
  source "$REPO_DIR/scripts/lib/components/github-ssh.sh"
  # shellcheck source=scripts/lib/package-config.sh
  source "$REPO_DIR/scripts/lib/package-config.sh"
  # shellcheck source=scripts/lib/package-repos.sh
  source "$REPO_DIR/scripts/lib/package-repos.sh"
  # shellcheck source=scripts/lib/package-install.sh
  source "$REPO_DIR/scripts/lib/package-install.sh"
  # shellcheck source=scripts/lib/verification.sh
  source "$REPO_DIR/scripts/lib/verification.sh"
  # shellcheck source=scripts/lib/repair.sh
  source "$REPO_DIR/scripts/lib/repair.sh"
  # shellcheck source=scripts/lib/summary.sh
  source "$REPO_DIR/scripts/lib/summary.sh"
  # shellcheck source=scripts/lib/pipeline.sh
  source "$REPO_DIR/scripts/lib/pipeline.sh"
  # shellcheck source=scripts/lib/steps/system.sh
  source "$REPO_DIR/scripts/lib/steps/system.sh"
  # shellcheck source=scripts/lib/steps/packages.sh
  source "$REPO_DIR/scripts/lib/steps/packages.sh"
  # shellcheck source=scripts/lib/steps/desktop.sh
  source "$REPO_DIR/scripts/lib/steps/desktop.sh"
  # shellcheck source=scripts/lib/steps/github-ssh.sh
  source "$REPO_DIR/scripts/lib/steps/github-ssh.sh"
  # shellcheck source=scripts/lib/steps/verification.sh
  source "$REPO_DIR/scripts/lib/steps/verification.sh"
  # shellcheck source=scripts/lib/flow.sh
  source "$REPO_DIR/scripts/lib/flow.sh"
fi

source_runtime_modules() {
  local repo_dir="$1"
  local module_path

  for module_path in "${RUNTIME_ENTRYPOINT_MODULE_FILES[@]}"; do
    # shellcheck disable=SC1090
    source "$repo_dir/$module_path"
  done
}
