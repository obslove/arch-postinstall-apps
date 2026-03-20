#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034

readonly -a BOOTSTRAP_FRAGMENT_FILES=(
  "scripts/lib/cli.sh"
  "scripts/bootstrap/step-result.sh"
  "scripts/bootstrap/ui.sh"
  "scripts/bootstrap/process.sh"
  "scripts/bootstrap/locking.sh"
  "scripts/bootstrap/env.sh"
  "scripts/bootstrap/repo.sh"
  "scripts/bootstrap/entrypoint.sh"
)

readonly -a BOOTSTRAP_CHECK_FILES=(
  "scripts/bootstrap/bootstrap-modules.sh"
  "scripts/bootstrap/step-result.sh"
  "scripts/bootstrap/ui.sh"
  "scripts/bootstrap/process.sh"
  "scripts/bootstrap/locking.sh"
  "scripts/bootstrap/env.sh"
  "scripts/bootstrap/repo.sh"
  "scripts/bootstrap/entrypoint.sh"
)
