#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034
# shellcheck source-path=SCRIPTDIR
# shellcheck source=scripts/lib/shellcheck-runtime.sh
# shellcheck source=scripts/lib/ops.sh

if false; then
  source "$SCRIPT_DIR/scripts/lib/shellcheck-runtime.sh"
  source "$SCRIPT_DIR/scripts/lib/ops.sh"
fi

multilib_enabled() {
  awk '
    /^[[:space:]]*\[multilib\][[:space:]]*$/ { in_multilib=1; next }
    /^[[:space:]]*\[/ { in_multilib=0 }
    in_multilib && /^[[:space:]]*Include = \/etc\/pacman.d\/mirrorlist[[:space:]]*$/ { found=1 }
    END { exit(found ? 0 : 1) }
  ' /etc/pacman.conf
}

ensure_multilib() {
  if multilib_enabled; then
    announce_detail "O repositório multilib já está habilitado."
    return
  fi

  announce_detail "Habilitando o repositório multilib..."
  ops_backup_pacman_conf "/etc/pacman.conf.bak.$(date +%Y%m%d%H%M%S)"
  ops_enable_multilib_config

  if ! multilib_enabled; then
    announce_error "Não foi possível habilitar multilib automaticamente."
    return 1
  fi

  if ! ops_pacman_refresh_databases; then
    announce_error "Não foi possível sincronizar os bancos de dados do pacman após habilitar multilib."
    return 1
  fi
}

refresh_official_repo_index() {
  if [[ "$official_repo_metadata_checked" == "1" ]]; then
    [[ "$official_repo_metadata_ready" == "1" ]]
    return
  fi

  official_repo_metadata_checked=1
  if ! pacman -Slq >/dev/null 2>&1; then
    official_repo_metadata_ready=0
    announce_error "Não foi possível carregar os metadados dos repositórios oficiais do pacman."
    return 1
  fi

  official_repo_metadata_ready=1
}

package_exists_in_official_repos() {
  local package="$1"

  if ! refresh_official_repo_index; then
    return 2
  fi

  if pacman -Si -- "$package" >/dev/null 2>&1; then
    return 0
  fi

  return 1
}
