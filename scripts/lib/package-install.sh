#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034
# shellcheck source-path=SCRIPTDIR
# shellcheck source=scripts/lib/shellcheck-runtime.sh
# shellcheck source=scripts/lib/ops.sh
# shellcheck source=scripts/lib/components.sh
# shellcheck source=scripts/lib/runtime-state.sh
# shellcheck source=scripts/lib/package-repos.sh
# shellcheck source=scripts/lib/components/aur-helper.sh

if false; then
  source "$SCRIPT_DIR/scripts/lib/shellcheck-runtime.sh"
  source "$SCRIPT_DIR/scripts/lib/ops.sh"
  source "$SCRIPT_DIR/scripts/lib/components.sh"
  source "$SCRIPT_DIR/scripts/lib/runtime-state.sh"
  source "$SCRIPT_DIR/scripts/lib/package-repos.sh"
  source "$SCRIPT_DIR/scripts/lib/components/aur-helper.sh"
fi

install_official_packages_in_order() {
  local array_name="$1"
  local official_packages=()
  local package_previously_installed=0
  local package_name

  if ! refresh_official_repo_index; then
    announce_error "Não foi possível preparar o índice de pacotes oficiais antes da instalação."
    return 1
  fi

  collect_packages_by_origin "$array_name" "official" official_packages || return 1

  if [[ "$STEP_OUTPUT_ONLY" == "1" ]]; then
    announce_detail "${#official_packages[@]} item(ns) previsto(s) na lista principal oficial."
  fi

  for package_name in "${official_packages[@]}"; do
    report_add_requested_main_official_package "$package_name"
    package_previously_installed=0
    if package_is_installed "$package_name"; then
      package_previously_installed=1
      report_add_reused_main_official_package "$package_name"
    fi

    state_add_main_official_package "$package_name"
    announce_detail "Instalando via pacman: $package_name"
    if ops_pacman_install_needed "$package_name"; then
      if [[ "$package_previously_installed" == "0" ]]; then
        report_add_changed_main_official_package "$package_name"
      fi
      continue
    fi

    state_add_official_failure "$package_name"
  done
}

install_aur_packages_in_order() {
  local array_name="$1"
  local aur_packages=()
  local package_name
  local aur_helper_name=""
  local package_previously_installed=0

  collect_packages_by_origin "$array_name" "aur" aur_packages || return 1

  if [[ "$STEP_OUTPUT_ONLY" == "1" ]]; then
    announce_detail "${#aur_packages[@]} item(ns) previsto(s) na lista principal AUR."
  fi

  for package_name in "${aur_packages[@]}"; do
    report_add_requested_main_aur_package "$package_name"
    package_previously_installed=0
    if package_is_installed "$package_name"; then
      package_previously_installed=1
      report_add_reused_main_aur_package "$package_name"
    fi

    state_add_main_aur_package "$package_name"
    if ! ensure_aur_helper; then
      state_add_aur_failure "$package_name"
      continue
    fi

    announce_detail "Instalando via AUR: $package_name"
    aur_helper_name="$(state_get_aur_helper_name)"
    if ops_aur_install_needed "$aur_helper_name" "$package_name"; then
      if [[ "$package_previously_installed" == "0" ]]; then
        report_add_changed_main_aur_package "$package_name"
      fi
      continue
    fi

    state_add_aur_failure "$package_name"
  done
}
