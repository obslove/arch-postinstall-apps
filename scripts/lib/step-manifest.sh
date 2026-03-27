#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034

STEP_DEFINITION_IDS=()
declare -Ag STEP_DEFINITION_MODES=()
declare -Ag STEP_DEFINITION_TITLES=()
declare -Ag STEP_DEFINITION_FUNCTIONS=()
declare -Ag STEP_DEFINITION_COUNT_FLAGS=()

register_step_definition() {
  local step_id="$1"
  local step_mode="$2"
  local step_title="$3"
  local step_function="$4"
  local count_for_progress="${5:-1}"

  STEP_DEFINITION_IDS+=("$step_id")
  STEP_DEFINITION_MODES["$step_id"]="$step_mode"
  STEP_DEFINITION_TITLES["$step_id"]="$step_title"
  STEP_DEFINITION_FUNCTIONS["$step_id"]="$step_function"
  STEP_DEFINITION_COUNT_FLAGS["$step_id"]="$count_for_progress"
}

step_definition_mode() {
  printf '%s\n' "${STEP_DEFINITION_MODES[$1]:-}"
}

step_definition_title() {
  printf '%s\n' "${STEP_DEFINITION_TITLES[$1]:-}"
}

step_definition_function() {
  printf '%s\n' "${STEP_DEFINITION_FUNCTIONS[$1]:-}"
}

step_definition_count_flag() {
  printf '%s\n' "${STEP_DEFINITION_COUNT_FLAGS[$1]:-0}"
}

append_registered_step() {
  local step_id="$1"
  local step_args="${2:-}"
  local step_mode=""
  local step_title=""
  local step_function=""
  local step_count_flag="0"

  step_mode="$(step_definition_mode "$step_id")"
  step_title="$(step_definition_title "$step_id")"
  step_function="$(step_definition_function "$step_id")"
  step_count_flag="$(step_definition_count_flag "$step_id")"

  [[ -n "$step_mode" && -n "$step_function" ]] || {
    printf 'Erro: etapa não registrada: %s\n' "$step_id" >&2
    return 1
  }

  pipeline_add_step "$step_id" "$step_mode" "$step_title" "$step_function" "$step_count_flag" "$step_args"
}

append_runtime_component_steps() {
  local phase="$1"
  local component_ids=()
  local component_id
  local pipeline_title=""
  local pipeline_function=""

  case "$phase" in
    pre_package)
      mapfile -t component_ids < <(component_pre_package_pipeline_ids)
      ;;
    post_package)
      mapfile -t component_ids < <(component_post_package_pipeline_ids)
      ;;
    *)
      printf 'Erro: fase de pipeline desconhecida: %s\n' "$phase" >&2
      return 1
      ;;
  esac

  for component_id in "${component_ids[@]}"; do
    pipeline_title="$(component_pipeline_title "$component_id")"
    pipeline_function="$(component_pipeline_step_function "$component_id")"
    pipeline_add_step "$component_id" "install" "$pipeline_title" "$pipeline_function" "1"
  done
}

append_runtime_install_pipeline() {
  local package_array_name="$1"
  local origin_status=0

  append_registered_step "create_directories"
  append_registered_step "relocate_home_repositories"
  append_registered_step "ensure_multilib"
  append_registered_step "update_system"
  append_registered_step "install_local_support_packages"
  append_runtime_component_steps "pre_package"
  append_registered_step "sync_managed_repositories"

  if target_packages_have_official_entries "$package_array_name"; then
    append_registered_step "prepare_package_installation"
    append_registered_step "install_official_packages" "$package_array_name"
  else
    origin_status=$?
    if [[ "$origin_status" != "1" ]]; then
      return 1
    fi
  fi

  if target_packages_have_aur_entries "$package_array_name"; then
    if ! pipeline_contains_step_id "prepare_package_installation"; then
      append_registered_step "prepare_package_installation"
    fi
    append_registered_step "install_aur_packages" "$package_array_name"
  else
    origin_status=$?
    if [[ "$origin_status" != "1" ]]; then
      return 1
    fi
  fi

  if pipeline_contains_step_id "prepare_package_installation"; then
    append_registered_step "finalize_package_installation"
  fi

  append_runtime_component_steps "post_package"
  append_registered_step "final_verification" "$package_array_name"
}

define_runtime_pipeline() {
  local package_array_name="$1"

  pipeline_reset
  append_registered_step "runtime_validate_environment"
  append_registered_step "load_configuration" "$package_array_name"

  if [[ "$CHECK_ONLY" == "1" ]]; then
    append_registered_step "check_only_verification" "$package_array_name"
  fi
}

define_bootstrap_pipeline() {
  local missing_packages_array_name="$1"

  pipeline_reset
  append_registered_step "bootstrap_validate_environment"
  append_registered_step "bootstrap_check_dependencies" "$missing_packages_array_name"

  if bootstrap_missing_packages_present "$missing_packages_array_name"; then
    append_registered_step "bootstrap_install_dependencies" "$missing_packages_array_name"
  fi

  append_registered_step "bootstrap_sync_repo"
}

bootstrap_missing_packages_present() {
  local array_name="$1"
  declare -n missing_packages="$array_name"

  (( ${#missing_packages[@]} > 0 ))
}

register_step_definition "runtime_validate_environment" "all" "Validando ambiente..." "runtime_validate_environment_step"
register_step_definition "load_configuration" "all" "Carregando configuração..." "load_configuration_step"
register_step_definition "check_only_verification" "check" "Executando verificação sem alterações..." "check_only_step"
register_step_definition "create_directories" "install" "Criando diretórios..." "create_directories_step"
register_step_definition "relocate_home_repositories" "install" "Reorganizando repositórios da home..." "relocate_home_repositories_step"
register_step_definition "sync_managed_repositories" "install" "Sincronizando repositórios gerenciados..." "sync_managed_repositories_step"
register_step_definition "ensure_multilib" "install" "Preparando repositório multilib..." "ensure_multilib_step"
register_step_definition "update_system" "install" "Atualizando o sistema..." "update_system_step"
register_step_definition "install_local_support_packages" "install" "Instalando ferramentas de suporte..." "install_local_support_packages_step"
register_step_definition "prepare_package_installation" "install" "" "prepare_package_installation_step" "0"
register_step_definition "install_official_packages" "install" "Instalando apps oficiais..." "install_official_packages_step"
register_step_definition "install_aur_packages" "install" "Instalando apps AUR..." "install_aur_packages_step"
register_step_definition "finalize_package_installation" "install" "" "finalize_package_installation_step" "0"
register_step_definition "final_verification" "install" "Validando instalação..." "final_verification_step"

register_step_definition "bootstrap_validate_environment" "bootstrap" "Validando ambiente..." "bootstrap_validate_environment_step"
register_step_definition "bootstrap_check_dependencies" "bootstrap" "Verificando dependências iniciais já instaladas..." "bootstrap_check_dependencies_step"
register_step_definition "bootstrap_install_dependencies" "bootstrap" "Instalando dependências iniciais..." "bootstrap_install_dependencies_step"
register_step_definition "bootstrap_sync_repo" "bootstrap" "Sincronizando repositório..." "bootstrap_sync_repo_step"
