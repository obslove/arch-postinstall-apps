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

install_packages_in_order() {
  local array_name="$1"
  # shellcheck disable=SC2178
  declare -n target_packages="$array_name"
  local package
  local aur_helper_name=""
  local package_origin_status
  local shown_pacman_step=0
  local shown_aur_step=0
  local official_target_count=0
  local aur_target_count=0

  if ! refresh_official_repo_index; then
    announce_error "Não foi possível preparar o índice de pacotes oficiais antes da instalação."
    return 1
  fi

  state_reset_package_results

  if [[ "$STEP_OUTPUT_ONLY" == "1" ]]; then
    for package in "${target_packages[@]}"; do
      if package_exists_in_official_repos "$package"; then
        official_target_count=$((official_target_count + 1))
      else
        package_origin_status=$?
        if [[ "$package_origin_status" == "2" ]]; then
          announce_error "Não foi possível classificar o pacote '$package' entre repositório oficial e AUR."
          return 1
        fi
        aur_target_count=$((aur_target_count + 1))
      fi
    done
  fi

  for package in "${target_packages[@]}"; do
    if package_exists_in_official_repos "$package"; then
      package_origin_status=0
    else
      package_origin_status=$?
    fi

    if [[ "$package_origin_status" == "0" ]]; then
      state_add_main_official_package "$package"
      if [[ "$shown_pacman_step" == "0" ]]; then
        announce_step "Instalando apps oficiais..."
        if (( official_target_count > 0 )); then
          announce_detail "$official_target_count item(ns) previsto(s) na lista principal oficial."
        fi
        shown_pacman_step=1
      fi
      announce_detail "Instalando via pacman: $package"
      if ops_pacman_install_needed "$package"; then
        continue
      fi

      state_add_official_failure "$package"
      continue
    fi

    if [[ "$package_origin_status" == "2" ]]; then
      announce_error "Não foi possível classificar o pacote '$package' entre repositório oficial e AUR."
      return 1
    fi

    state_add_main_aur_package "$package"
    if ! ensure_aur_helper; then
      state_add_aur_failure "$package"
      continue
    fi

    if [[ "$shown_aur_step" == "0" ]]; then
      announce_step "Instalando apps AUR..."
      if (( aur_target_count > 0 )); then
        announce_detail "$aur_target_count item(ns) previsto(s) na lista principal AUR."
      fi
      shown_aur_step=1
    fi
    announce_detail "Instalando via AUR: $package"
    aur_helper_name="$(state_get_aur_helper_name)"
    if ops_aur_install_needed "$aur_helper_name" "$package"; then
      continue
    fi

    state_add_aur_failure "$package"
  done
}
