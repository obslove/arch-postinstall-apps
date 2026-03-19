#!/usr/bin/env bash

print_summary() {
  local host_name
  local actual_branch
  local actual_commit
  local repo_path
  local origin_status="indisponível"
  local completed_actions=()
  local execution_mode="instalação"
  local changes_applied="sim"
  local version_line

  if [[ "$CHECK_ONLY" == "1" ]]; then
    execution_mode="verificação"
    changes_applied="não"
  fi

  host_name="$(get_host_name)"
  actual_branch="$(get_repo_branch "$SCRIPT_DIR" 2>/dev/null || printf '%s\n' "main")"
  actual_commit="$(current_repo_commit_short "$SCRIPT_DIR")"
  repo_path="$SCRIPT_DIR"
  origin_status="$(current_repo_origin_status "$SCRIPT_DIR")"

  if has_checkpoint "codex_cli"; then
    completed_actions+=("codex_cli")
  fi
  if has_checkpoint "desktop_integration"; then
    completed_actions+=("desktop_integration")
  fi
  if has_checkpoint "github_ssh"; then
    completed_actions+=("github_ssh")
  fi

  close_step_block

  if [[ "$STEP_OUTPUT_ONLY" == "1" ]]; then
    echo
    printf '%s %s\n' "$(style_text "$style_success" "╭─")" "$(style_text "$style_success" "Concluído")"
    print_summary_section "Resultado"
    print_summary_item "Modo:" "$execution_mode"
    print_summary_item "Alterações aplicadas:" "$changes_applied"
    print_summary_item "GitHub SSH:" "$github_ssh_status"
    print_summary_item "Integração desktop:" "$desktop_integration_status"
    print_summary_section "Repositório"
    print_summary_item "Commit:" "$actual_commit"
    print_summary_section "Arquivos"
    print_summary_item "Log:" "$LOG_FILE"
    print_summary_item "Resumo:" "$SUMMARY_FILE"
    echo "│"
    style_text "$style_muted" "╰─ Fim"
    printf '\n'
  else
    echo
    printf '%s %s\n' "$(style_text "$style_success" "╭─")" "$(style_text "$style_success" "Concluído")"
    print_summary_section "Arquivos"
    print_summary_item "Log:" "$LOG_FILE"
    print_summary_item "Resumo:" "$SUMMARY_FILE"
    print_summary_section "Estado"
    print_summary_item "Modo:" "$execution_mode"
    print_summary_item "Alterações aplicadas:" "$changes_applied"
    print_summary_item "Hostname:" "$host_name"
    print_summary_item "Repositório:" "$repo_path"
    print_summary_item "Branch:" "$actual_branch"
    print_summary_item "Commit:" "$actual_commit"
    print_summary_item "Origin:" "$origin_status"
    print_summary_section "Pacotes e configuração"
    print_summary_item "Lista principal via pacman:" "${official_packages[*]:-nenhum}"
    print_summary_item "Lista principal via AUR:" "${aur_packages[*]:-nenhum}"
    print_summary_item "Dependências de suporte:" "${support_packages[*]:-nenhuma}"
    print_summary_item "Ambiente gráfico:" "${environment_packages[*]:-nenhuma}"
    print_summary_item "Configurações explícitas:" "${completed_actions[*]:-nenhuma}"
    print_summary_item "GitHub SSH esperado:" "$(if github_ssh_expected; then echo sim; else echo não; fi)"
    print_summary_item "GitHub SSH:" "$github_ssh_status"
    print_summary_item "Integração desktop:" "$desktop_integration_status"
    print_summary_item "Helper AUR:" "${aur_helper_status:-indisponível}"
    print_summary_section "Verificação"
    print_summary_item "Falhas pacman:" "${official_failed[*]:-nenhuma}"
    print_summary_item "Falhas AUR:" "${aur_failed[*]:-nenhuma}"
    print_summary_item "Verificados:" "${verified_commands[*]:-nenhum}"
    print_summary_item "Ausentes:" "${missing_commands[*]:-nenhum}"
    if ((${#version_info[@]} == 0)); then
      print_summary_item "Versões:" "nenhuma"
    else
      print_summary_section "Versões"
      for version_line in "${version_info[@]}"; do
        echo "│    $(style_text "$style_detail" "•") $version_line"
      done
    fi
    echo "│"
    style_text "$style_muted" "╰─ Fim"
    printf '\n'
  fi

  mkdir -p "$(dirname "$SUMMARY_FILE")"
  cat >"$SUMMARY_FILE" <<EOF
Data: $(date '+%Y-%m-%d %H:%M:%S %z')
Modo: $execution_mode
Alterações aplicadas: $changes_applied
Log: $LOG_FILE
Hostname: $host_name
Repositório: $repo_path
Branch: $actual_branch
Commit: $actual_commit
Origin: $origin_status
Itens da lista principal tratados via pacman: ${official_packages[*]:-nenhum}
Itens da lista principal tratados via AUR: ${aur_packages[*]:-nenhum}
Dependências de suporte tratadas: ${support_packages[*]:-nenhuma}
Dependências do ambiente gráfico tratadas: ${environment_packages[*]:-nenhuma}
Configurações explícitas: ${completed_actions[*]:-nenhuma}
GitHub SSH esperado: $(if github_ssh_expected; then echo sim; else echo não; fi)
GitHub SSH: $github_ssh_status
Integração desktop: $desktop_integration_status
Helper AUR: ${aur_helper_status:-indisponível}
Falhas pacman: ${official_failed[*]:-nenhuma}
Falhas AUR: ${aur_failed[*]:-nenhuma}
Verificados: ${verified_commands[*]:-nenhum}
Ausentes: ${missing_commands[*]:-nenhum}
Versões:
$(if ((${#version_info[@]} == 0)); then echo "- nenhuma"; else printf '%s\n' "${version_info[@]/#/- }"; fi)
Checkpoints:
- codex_cli: $(if has_checkpoint "codex_cli"; then echo concluido; else echo pendente; fi)
- desktop_integration: $(if has_checkpoint "desktop_integration"; then echo concluido; else echo pendente; fi)
- github_ssh: $(if has_checkpoint "github_ssh"; then echo concluido; else echo pendente; fi)
EOF

  if [[ "$SCRIPT_DIR" != "$INSTALL_DIR" ]]; then
    printf 'Clone gerenciado: %s\n' "$INSTALL_DIR" >>"$SUMMARY_FILE"
  fi
}

run_install() {
  local package_name

  official_packages=()
  aur_packages=()
  official_failed=()
  aur_failed=()
  support_packages=()
  environment_packages=()
  aur_helper_status="não preparado"
  github_ssh_status="pendente"
  desktop_integration_status="pendente"
  announce_step "Carregando configuração..."
  load_packages
  if [[ "$CHECK_ONLY" != "1" ]]; then
    set_step_total "$(calculate_install_step_total)"
  fi
  if [[ "$CHECK_ONLY" == "1" ]]; then
    announce_step "Executando verificação sem alterações..."
    detect_aur_helper || true
    if desktop_integration_ready; then
      desktop_integration_status="ignorada por já estar pronta"
    else
      desktop_integration_status="pendente"
    fi
    for package_name in \
      pipewire \
      wireplumber \
      xdg-utils \
      xdg-desktop-portal \
      xdg-desktop-portal-gtk \
      xdg-desktop-portal-hyprland; do
      mark_environment_package "$package_name"
    done
    if github_ssh_expected; then
      if github_ssh_ready; then
        github_ssh_status="ignorada por já estar pronta"
      else
        github_ssh_status="pendente"
      fi
    else
      github_ssh_status="ignorada por configuração"
    fi
    verify_installation
    print_summary
    if ((${#missing_commands[@]} > 0)); then
      announce_error "A verificação sem alterações encontrou itens ausentes."
      exit 1
    fi
    return 0
  fi

  create_directories
  ensure_multilib

  if [[ "$SYSTEM_UPDATED" == "1" ]]; then
    announce_detail "O sistema já foi atualizado no bootstrap. A nova atualização completa será ignorada."
  else
    announce_step "Atualizando o sistema..."
    if ! retry_interactive_log_only sudo pacman -Syu --noconfirm; then
      announce_error "Não foi possível concluir a atualização completa do sistema."
      print_summary
      exit 1
    fi
  fi

  announce_step "Preparando helper AUR..."
  if ! ensure_aur_helper; then
    announce_error "Não foi possível preparar o helper AUR padrão para a instalação."
    print_summary
    exit 1
  fi

  if ! install_packages_in_order; then
    print_summary
    exit 1
  fi

  if ((${#official_failed[@]} > 0 || ${#aur_failed[@]} > 0)); then
    print_summary
    exit 1
  fi
  announce_step "Ajustando integração desktop..."
  if ! ensure_desktop_integration; then
    announce_error "A integração desktop falhou. A etapa do GitHub SSH não foi executada."
    print_summary
    exit 1
  fi
  announce_step "Configurando GitHub SSH..."
  setup_github_ssh
  announce_step "Validando instalação..."
  verify_installation
  if ! ensure_final_verification_passed; then
    print_summary
    exit 1
  fi
  print_summary
}
