#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034
# shellcheck source-path=SCRIPTDIR
# shellcheck source=scripts/lib/shellcheck-runtime.sh
# shellcheck source=scripts/lib/ops.sh
# shellcheck source=scripts/lib/components.sh
# shellcheck source=scripts/lib/runtime-state.sh

if false; then
  source "$SCRIPT_DIR/scripts/lib/shellcheck-runtime.sh"
  source "$SCRIPT_DIR/scripts/lib/ops.sh"
  source "$SCRIPT_DIR/scripts/lib/components.sh"
  source "$SCRIPT_DIR/scripts/lib/runtime-state.sh"
fi

append_package() {
  local array_name="$1"
  local package="$2"
  local existing
  # shellcheck disable=SC2178
  declare -n target_array="$array_name"

  for existing in "${target_array[@]}"; do
    if [[ "$existing" == "$package" ]]; then
      return
    fi
  done

  target_array+=("$package")
}

load_package_file() {
  local package_path="$1"
  local array_name="$2"
  local line

  if [[ ! -f "$package_path" ]]; then
    if [[ "$package_path" == "$EXTRA_PACKAGE_FILE" ]]; then
      announce_detail "Pacotes extras não encontrados em $package_path. Etapa ignorada."
    fi
    return 0
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -n "$line" ]] || continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    append_package "$array_name" "$line"
  done <"$package_path"
}

load_packages() {
  local array_name="$1"
  # shellcheck disable=SC2178
  declare -n target_array="$array_name"

  [[ -f "$PACKAGE_FILE" ]] || {
    announce_error "Lista de pacotes não encontrada em $PACKAGE_FILE"
    return 1
  }

  target_array=()
  load_package_file "$PACKAGE_FILE" "$array_name"
  load_package_file "$EXTRA_PACKAGE_FILE" "$array_name"
}

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

detect_aur_helper() {
  if command -v yay >/dev/null 2>&1; then
    aur_helper="yay"
    aur_helper_status="yay (reutilizado)"
    return 0
  fi

  if command -v paru >/dev/null 2>&1; then
    aur_helper="paru"
    aur_helper_status="paru (fallback)"
    return 0
  fi

  aur_helper=""
  aur_helper_status="indisponível"
  return 1
}

component_detect_aur_helper() {
  detect_aur_helper
}

component_checkpoint_key_aur_helper() {
  return 1
}

build_yay() {
  local yay_dir="$1"

  (
    cd "$yay_dir" || exit
    makepkg -si --noconfirm
  )
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

calculate_install_step_total() {
  local array_name="$1"
  # shellcheck disable=SC2178
  declare -n target_packages="$array_name"
  local package
  local total=8
  local has_official=0
  local has_aur=0

  for package in "${target_packages[@]}"; do
    if pacman -Si -- "$package" >/dev/null 2>&1; then
      has_official=1
    else
      has_aur=1
    fi
  done

  if component_enabled "codex_cli"; then
    total=$((total + 1))
  fi
  (( has_official == 1 )) && total=$((total + 1))
  (( has_aur == 1 )) && total=$((total + 1))

  printf '%s\n' "$total"
}

install_yay() {
  local archive_file
  local missing_packages=()
  local package_name
  local status=0

  for package_name in "${AUR_HELPER_SUPPORT_PACKAGES[@]}"; do
    mark_support_package "$package_name"
  done
  mkdir -p "$REPOSITORIES_DIR"
  collect_missing_packages missing_packages "${AUR_HELPER_SUPPORT_PACKAGES[@]}"
  if ((${#missing_packages[@]} > 0)); then
    if ! ops_pacman_install_needed "${missing_packages[@]}"; then
      return 1
    fi
  fi
  require_command curl
  require_command tar

  archive_file="$(mktemp)"
  register_cleanup_path "$archive_file"

  announce_detail "Baixando snapshot do yay..."
  if ! ops_download_file "$YAY_SNAPSHOT_URL" "$archive_file"; then
    return 1
  fi

  rm -rf "$YAY_REPO_DIR"
  announce_detail "Extraindo snapshot do yay em $YAY_REPO_DIR..."
  if ! ops_extract_tar_gz "$archive_file" "$REPOSITORIES_DIR"; then
    return 1
  fi

  if [[ -d "$REPOSITORIES_DIR/yay" && "$REPOSITORIES_DIR/yay" != "$YAY_REPO_DIR" ]]; then
    mv "$REPOSITORIES_DIR/yay" "$YAY_REPO_DIR"
  fi

  if (( status == 0 )); then
    if ops_build_yay_package "$YAY_REPO_DIR"; then
      aur_helper="yay"
      aur_helper_status="yay (instalado nesta execução)"
    else
      status=$?
    fi
  fi

  return "$status"
}

component_apply_aur_helper() {
  if command -v yay >/dev/null 2>&1; then
    aur_helper="yay"
    aur_helper_status="yay (reutilizado)"
    announce_detail "Usando helper AUR: $aur_helper"
    return 0
  fi

  announce_detail "O yay será instalado e usado como helper AUR padrão."
  if ! install_yay; then
    if detect_aur_helper; then
      announce_warning "Não foi possível instalar o yay. O script usará o helper AUR disponível: $aur_helper."
      return 0
    fi

    announce_error "Não foi possível preparar um helper AUR (yay)."
    return 1
  fi

  aur_helper="yay"
  aur_helper_status="yay (instalado nesta execução)"
  announce_detail "Usando helper AUR: $aur_helper"
}

ensure_aur_helper() {
  component_apply aur_helper
}

install_codex_cli_component() {
  component_apply codex_cli
}

install_packages_in_order() {
  local array_name="$1"
  # shellcheck disable=SC2178
  declare -n target_packages="$array_name"
  local package
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
    if ops_aur_install_needed "$aur_helper" "$package"; then
      continue
    fi

    state_add_aur_failure "$package"
  done

  install_codex_cli_component
}
