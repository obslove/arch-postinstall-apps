#!/usr/bin/env bash

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

  run_log_only systemctl --user daemon-reload || true
  run_log_only systemctl --user start pipewire.service wireplumber.service xdg-desktop-portal.service
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
    version_info+=("$label: versão indisponível")
    return 0
  fi
  version_info+=("$label: $output")
}

verify_installation() {
  local package_name

  verified_commands=()
  missing_commands=()
  version_info=()

  for package_name in "${packages[@]}"; do
    case "$package_name" in
      codex)
        verify_command "codex" "codex"
        ;;
      nodejs)
        verify_command "nodejs" "node"
        ;;
      *)
        verify_package "$package_name" "$package_name"
        ;;
    esac
  done

  if github_ssh_expected; then
    verify_command "github-cli" "gh"
    verify_command "openssh" "ssh-keygen"
    if [[ "$(current_repo_origin_status "$SCRIPT_DIR")" == "ssh" ]]; then
      mark_verified_item "origin-ssh"
    else
      mark_missing_item "origin-ssh"
    fi
  fi

  if command -v xdg-open >/dev/null 2>&1; then
    mark_verified_item "xdg-utils"
  elif command -v gio >/dev/null 2>&1; then
    mark_verified_item "xdg-utils"
  else
    mark_missing_item "xdg-utils"
  fi

  if command -v wl-copy >/dev/null 2>&1 && command -v wl-paste >/dev/null 2>&1; then
    mark_verified_item "clipboard"
  elif package_is_installed wl-clipboard; then
    mark_missing_item "wl-clipboard"
  fi

  verify_command "pipewire" "pipewire"
  verify_command "wireplumber" "wireplumber"
  verify_package "xdg-desktop-portal" "xdg-desktop-portal"
  verify_package "xdg-desktop-portal-gtk" "xdg-desktop-portal-gtk"
  verify_package "xdg-desktop-portal-hyprland" "xdg-desktop-portal-hyprland"

  verify_user_service "pipewire.service" "pipewire.service"
  verify_user_service "wireplumber.service" "wireplumber.service"
  verify_user_service "xdg-desktop-portal.service" "xdg-desktop-portal.service"

  if [[ \
    " ${verified_commands[*]} " == *" pipewire.service "* && \
    " ${verified_commands[*]} " == *" wireplumber.service "* && \
    " ${verified_commands[*]} " == *" xdg-desktop-portal.service "* \
  ]]; then
    mark_verified_item "screen-sharing-stack"
  else
    mark_missing_item "screen-sharing-stack"
  fi

  collect_version "node" node --version
  collect_version "npm" npm --version
  collect_version "gh" gh --version
  collect_version "codex" codex --version
  collect_version "zen-browser" zen-browser --version
  collect_version "google-chrome-stable" google-chrome-stable --version
}

attempt_final_repair_once() {
  local item
  local repair_pacman_packages=()
  local repair_aur_packages=()
  local pacman_missing_packages=()
  local aur_package
  local package_origin_status
  local should_repair_codex=0
  local should_repair_origin=0
  local should_start_services=0

  if ((${#missing_commands[@]} == 0)); then
    return 0
  fi

  announce_step "Tentando corrigir itens ausentes..."
  for item in "${missing_commands[@]}"; do
    case "$item" in
      codex)
        should_repair_codex=1
        ;;
      github-cli|openssh|xdg-utils|wl-clipboard|pipewire|wireplumber|xdg-desktop-portal|xdg-desktop-portal-gtk|xdg-desktop-portal-hyprland)
        append_array_item repair_pacman_packages "$item"
        ;;
      origin-ssh)
        should_repair_origin=1
        ;;
      pipewire.service|wireplumber.service|xdg-desktop-portal.service|screen-sharing-stack)
        should_start_services=1
        ;;
      *)
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
        ;;
    esac
  done

  collect_missing_packages pacman_missing_packages "${repair_pacman_packages[@]}"
  if ((${#pacman_missing_packages[@]} > 0)); then
    announce_detail "Reinstalando itens via pacman..."
    if ! retry_interactive_log_only sudo pacman -S --needed --noconfirm "${pacman_missing_packages[@]}"; then
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
      if ! retry_log_only "$aur_helper" -S --needed --noconfirm "$aur_package"; then
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

  verify_installation
  ((${#missing_commands[@]} == 0))
}

ensure_final_verification_passed() {
  if ((${#missing_commands[@]} == 0)); then
    return 0
  fi

  if attempt_final_repair_once; then
    return 0
  fi

  announce_error "A verificação final encontrou itens ausentes após a instalação."
  announce_error "Itens ausentes: ${missing_commands[*]}"
  return 1
}
