#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034

if [[ "${MODULE_MANIFEST_LOADED:-0}" == "1" ]]; then
  return 0
fi
readonly MODULE_MANIFEST_LOADED=1

declare -ag MODULE_BOOTSTRAP_FRAGMENT_FILES=()
declare -ag MODULE_BOOTSTRAP_CHECK_FILES=()
declare -ag MODULE_RUNTIME_ENTRYPOINT_FILES=()
declare -ag MODULE_RUNTIME_CHECK_FILES=()

manifest_append_unique() {
  local array_name="$1"
  local module_path="$2"
  local existing
  declare -n target_array="$array_name"

  for existing in "${target_array[@]}"; do
    [[ "$existing" == "$module_path" ]] && return 0
  done

  target_array+=("$module_path")
}

register_module_file() {
  local module_path="$1"
  shift

  local role
  for role in "$@"; do
    case "$role" in
      bootstrap-fragment)
        manifest_append_unique MODULE_BOOTSTRAP_FRAGMENT_FILES "$module_path"
        ;;
      bootstrap-check)
        manifest_append_unique MODULE_BOOTSTRAP_CHECK_FILES "$module_path"
        ;;
      runtime-entrypoint)
        manifest_append_unique MODULE_RUNTIME_ENTRYPOINT_FILES "$module_path"
        ;;
      runtime-check)
        manifest_append_unique MODULE_RUNTIME_CHECK_FILES "$module_path"
        ;;
      *)
        printf 'Erro: papel de módulo desconhecido: %s\n' "$role" >&2
        return 1
        ;;
    esac
  done
}

register_module_file "scripts/lib/cli.sh" \
  bootstrap-fragment bootstrap-check runtime-check
register_module_file "scripts/lib/runtime-config.sh" \
  bootstrap-fragment bootstrap-check runtime-check
register_module_file "scripts/lib/execution-report.sh" \
  runtime-entrypoint runtime-check
register_module_file "scripts/lib/step-result.sh" \
  bootstrap-fragment bootstrap-check runtime-check
register_module_file "scripts/lib/ui.sh" \
  bootstrap-fragment bootstrap-check runtime-check
register_module_file "scripts/lib/pipeline.sh" \
  bootstrap-fragment bootstrap-check runtime-entrypoint runtime-check
register_module_file "scripts/lib/step-manifest.sh" \
  bootstrap-fragment bootstrap-check runtime-entrypoint runtime-check
register_module_file "scripts/lib/process.sh" \
  bootstrap-fragment bootstrap-check runtime-check
register_module_file "scripts/lib/locking.sh" \
  bootstrap-fragment bootstrap-check runtime-check
register_module_file "scripts/lib/env.sh" \
  bootstrap-fragment bootstrap-check runtime-check
register_module_file "scripts/lib/ops.sh" \
  bootstrap-fragment bootstrap-check runtime-entrypoint runtime-check
register_module_file "scripts/lib/repo.sh" \
  bootstrap-fragment bootstrap-check runtime-entrypoint runtime-check
register_module_file "scripts/bootstrap/repo-sync.sh" \
  bootstrap-fragment bootstrap-check
register_module_file "scripts/bootstrap/steps/system.sh" \
  bootstrap-fragment bootstrap-check
register_module_file "scripts/bootstrap/steps/packages.sh" \
  bootstrap-fragment bootstrap-check
register_module_file "scripts/bootstrap/steps/repo.sh" \
  bootstrap-fragment bootstrap-check
register_module_file "scripts/bootstrap/entrypoint.sh" \
  bootstrap-fragment bootstrap-check

register_module_file "scripts/lib/core.sh" \
  runtime-entrypoint runtime-check
register_module_file "scripts/lib/components.sh" \
  runtime-entrypoint runtime-check
register_module_file "scripts/lib/components/codex.sh" \
  runtime-entrypoint runtime-check
register_module_file "scripts/lib/components/aur-helper.sh" \
  runtime-entrypoint runtime-check
register_module_file "scripts/lib/components/desktop.sh" \
  runtime-entrypoint runtime-check
register_module_file "scripts/lib/components/github-ssh.sh" \
  runtime-entrypoint runtime-check
register_module_file "scripts/lib/package-config.sh" \
  runtime-entrypoint runtime-check
register_module_file "scripts/lib/package-repos.sh" \
  runtime-entrypoint runtime-check
register_module_file "scripts/lib/package-install.sh" \
  runtime-entrypoint runtime-check
register_module_file "scripts/lib/verification.sh" \
  runtime-entrypoint runtime-check
register_module_file "scripts/lib/repair.sh" \
  runtime-entrypoint runtime-check
register_module_file "scripts/lib/summary.sh" \
  runtime-entrypoint runtime-check
register_module_file "scripts/lib/steps/system.sh" \
  runtime-entrypoint runtime-check
register_module_file "scripts/lib/steps/packages.sh" \
  runtime-entrypoint runtime-check
register_module_file "scripts/lib/steps/codex.sh" \
  runtime-entrypoint runtime-check
register_module_file "scripts/lib/steps/desktop.sh" \
  runtime-entrypoint runtime-check
register_module_file "scripts/lib/steps/github-ssh.sh" \
  runtime-entrypoint runtime-check
register_module_file "scripts/lib/steps/verification.sh" \
  runtime-entrypoint runtime-check
register_module_file "scripts/lib/flow.sh" \
  runtime-entrypoint runtime-check

register_module_file "scripts/lib/runtime-state.sh" runtime-check
register_module_file "scripts/lib/status.sh" runtime-check
register_module_file "scripts/lib/shellcheck-runtime.sh" runtime-check
register_module_file "scripts/lib/components/github-ssh/clipboard.sh" runtime-check
register_module_file "scripts/lib/components/github-ssh/auth.sh" runtime-check
register_module_file "scripts/lib/components/github-ssh/key.sh" runtime-check
register_module_file "scripts/lib/components/github-ssh/publish.sh" runtime-check
