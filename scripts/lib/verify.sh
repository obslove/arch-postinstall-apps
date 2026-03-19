#!/usr/bin/env bash
# shellcheck shell=bash
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

verify_command() {
  local label="$1"
  local command_name="$2"

  if command -v "$command_name" >/dev/null 2>&1; then
    mark_verified_item "$label"
    return
  fi

  mark_missing_item "$label"
}

verify_package() {
  local label="$1"
  local package_name="$2"

  if pacman -Q "$package_name" >/dev/null 2>&1; then
    mark_verified_item "$label"
    return
  fi

  mark_missing_item "$label"
}

user_service_exists() {
  local service_name="$1"

  systemctl --user cat "$service_name" >/dev/null 2>&1
}

verify_user_service() {
  local label="$1"
  local service_name="$2"

  if ! command -v systemctl >/dev/null 2>&1; then
    mark_missing_item "$label"
    return
  fi

  if ! user_service_exists "$service_name"; then
    mark_missing_item "$label"
    return
  fi

  if systemctl --user --quiet is-active "$service_name"; then
    mark_verified_item "$label"
    return
  fi

  mark_missing_item "$label"
}

start_desktop_user_services() {
  if ! command -v systemctl >/dev/null 2>&1; then
    return 1
  fi

  ops_systemctl_user_daemon_reload || true
  ops_systemctl_user_start "${DESKTOP_USER_SERVICES[@]}"
}

collect_version() {
  local label="$1"
  shift
  local output

  if ! command -v "$1" >/dev/null 2>&1; then
    return
  fi

  output="$("$@" 2>/dev/null | sed -n '1p' || true)"
  if [[ -z "$output" ]]; then
    state_add_version_line "$label: versão indisponível"
    return 0
  fi
  state_add_version_line "$label: $output"
}

verify_installation() {
  local array_name="$1"
  # shellcheck disable=SC2178
  declare -n target_packages="$array_name"
  local package_name
  local service_name

  state_reset_verification_results

  for package_name in "${target_packages[@]}"; do
    case "$package_name" in
      nodejs)
        verify_command "nodejs" "node"
        ;;
      *)
        verify_package "$package_name" "$package_name"
        ;;
    esac
  done

  component_verify desktop_integration
  if component_enabled "codex_cli"; then
    component_verify codex_cli
  fi
  if github_ssh_expected; then
    component_verify github_ssh
  fi

  collect_version "node" node --version
  collect_version "npm" npm --version
  collect_version "gh" gh --version
  collect_version "codex" codex --version
  collect_version "zen-browser" zen-browser --version
  collect_version "google-chrome-stable" google-chrome-stable --version
}

component_verify_aur_helper() {
  component_detect aur_helper
}

repair_missing_item_as_pacman_package() {
  local item="$1"
  local package_name

  for package_name in "${GITHUB_SSH_SUPPORT_PACKAGES[@]}"; do
    [[ "$item" == "$package_name" ]] && return 0
  done

  for package_name in "${DESKTOP_INTEGRATION_PACKAGES[@]}"; do
    [[ "$item" == "$package_name" ]] && return 0
  done

  for package_name in "${TEMPORARY_CLIPBOARD_PACKAGES[@]}"; do
    [[ "$item" == "$package_name" ]] && return 0
  done

  return 1
}

repair_missing_item_requires_service_start() {
  local item="$1"
  local service_name

  for service_name in "${DESKTOP_USER_SERVICES[@]}"; do
    [[ "$item" == "$service_name" ]] && return 0
  done

  [[ "$item" == "screen-sharing-stack" ]]
}

attempt_final_repair_once() {
  local array_name="$1"
  local item
  local repair_pacman_packages=()
  local repair_aur_packages=()
  local pacman_missing_packages=()
  local aur_package
  local package_origin_status
  local should_repair_codex=0
  local should_repair_origin=0
  local should_start_services=0

  if ! state_has_missing_items; then
    return 0
  fi

  announce_step "Tentando corrigir itens ausentes..."
  for item in "${STATE_MISSING_ITEMS[@]}"; do
    case "$item" in
      codex)
        should_repair_codex=1
        ;;
      origin-ssh)
        should_repair_origin=1
        ;;
    esac

    if repair_missing_item_as_pacman_package "$item"; then
        append_array_item repair_pacman_packages "$item"
        continue
    fi

    if repair_missing_item_requires_service_start "$item"; then
        should_start_services=1
        continue
    fi

    if [[ "$item" == "codex" || "$item" == "origin-ssh" ]]; then
      continue
    fi

    if package_exists_in_official_repos "$item"; then
      package_origin_status=0
    else
      package_origin_status=$?
    fi

    if [[ "$package_origin_status" == "0" ]]; then
      append_array_item repair_pacman_packages "$item"
    else
      if [[ "$package_origin_status" == "2" ]]; then
        announce_error "Não foi possível classificar o item ausente '$item' para a correção automática."
        return 1
      fi
      append_array_item repair_aur_packages "$item"
    fi
  done

  collect_missing_packages pacman_missing_packages "${repair_pacman_packages[@]}"
  if ((${#pacman_missing_packages[@]} > 0)); then
    announce_detail "Reinstalando itens via pacman..."
    if ! ops_pacman_install_needed "${pacman_missing_packages[@]}"; then
      return 1
    fi
  fi

  if ((${#repair_aur_packages[@]} > 0)); then
    if ! ensure_aur_helper; then
      return 1
    fi

    for aur_package in "${repair_aur_packages[@]}"; do
      if package_is_installed "$aur_package"; then
        continue
      fi

      announce_detail "Reinstalando item via AUR: $aur_package"
      if ! ops_aur_install_needed "$aur_helper" "$aur_package"; then
        return 1
      fi
    done
  fi

  if (( should_repair_codex == 1 )); then
    announce_detail "Reconfigurando o Codex CLI..."
    if ! setup_codex_cli; then
      return 1
    fi
  fi

  if (( should_repair_origin == 1 )); then
    announce_detail "Ajustando o remoto principal do repositório..."
    if ! ensure_repo_origin_remote "$SCRIPT_DIR"; then
      return 1
    fi
  fi

  if (( should_start_services == 1 )) || ((${#pacman_missing_packages[@]} > 0)); then
    announce_detail "Tentando iniciar os serviços de usuário necessários..."
    start_desktop_user_services || true
  fi

  if desktop_integration_ready && ! has_checkpoint "desktop_integration" && ! mark_checkpoint "desktop_integration"; then
    announce_warning "Não foi possível registrar o checkpoint da integração desktop após a correção automática."
  fi

  verify_installation "$1"
  ! state_has_missing_items
}

ensure_final_verification_passed() {
  local array_name="$1"

  if ! state_has_missing_items; then
    return 0
  fi

  if attempt_final_repair_once "$array_name"; then
    return 0
  fi

  announce_error "A verificação final encontrou itens ausentes após a instalação."
  announce_error "Itens ausentes: ${STATE_MISSING_ITEMS[*]}"
  return 1
}
