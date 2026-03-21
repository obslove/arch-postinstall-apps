#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034

readonly -a BOOTSTRAP_FRAGMENT_FILES=(
  "scripts/lib/cli.sh"
  "scripts/lib/step-result.sh"
  "scripts/lib/ui.sh"
  "scripts/lib/process.sh"
  "scripts/lib/locking.sh"
  "scripts/lib/env.sh"
  "scripts/lib/ops.sh"
  "scripts/lib/repo.sh"
  "scripts/bootstrap/repo-sync.sh"
  "scripts/bootstrap/entrypoint.sh"
)

readonly -a BOOTSTRAP_CHECK_FILES=(
  "scripts/bootstrap/bootstrap-modules.sh"
  "scripts/lib/cli.sh"
  "scripts/lib/step-result.sh"
  "scripts/lib/ui.sh"
  "scripts/lib/process.sh"
  "scripts/lib/locking.sh"
  "scripts/lib/env.sh"
  "scripts/lib/ops.sh"
  "scripts/lib/repo.sh"
  "scripts/bootstrap/repo-sync.sh"
  "scripts/bootstrap/entrypoint.sh"
)
