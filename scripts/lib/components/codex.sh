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

setup_codex_cli() {
  local codex_path_line="export PATH=\"\$HOME/Codex/bin:\$PATH\""
  local fish_codex_path_marker="if not contains \"\$HOME/Codex/bin\" \$PATH"
  local fish_codex_path_block="if not contains \"\$HOME/Codex/bin\" \$PATH
    set -gx PATH \"\$HOME/Codex/bin\" \$PATH
end"

  if codex_cli_ready; then
    announce_detail "O Codex CLI já está configurado. Etapa ignorada."
    return 0
  fi

  require_command npm

  announce_detail "Configurando o prefixo do npm em $HOME/Codex..."
  if ! ops_npm_config_set_prefix "$HOME/Codex"; then
    announce_error "Não foi possível configurar o prefixo do npm para o Codex CLI."
    return 1
  fi

  if [[ ! -f "$BASHRC_FILE" ]]; then
    touch "$BASHRC_FILE"
  fi

  if ! grep -qxF "$codex_path_line" "$BASHRC_FILE"; then
    printf '\n%s\n' "$codex_path_line" >>"$BASHRC_FILE"
  fi

  if [[ ! -f "$ZSHRC_FILE" ]]; then
    touch "$ZSHRC_FILE"
  fi

  if ! grep -qxF "$codex_path_line" "$ZSHRC_FILE"; then
    printf '\n%s\n' "$codex_path_line" >>"$ZSHRC_FILE"
  fi

  mkdir -p "$(dirname "$FISH_CONFIG_FILE")"
  if [[ ! -f "$FISH_CONFIG_FILE" ]]; then
    touch "$FISH_CONFIG_FILE"
  fi

  if ! grep -qxF "$fish_codex_path_marker" "$FISH_CONFIG_FILE"; then
    printf '\n%s\n' "$fish_codex_path_block" >>"$FISH_CONFIG_FILE"
  fi

  export PATH="$HOME/Codex/bin:$PATH"

  announce_detail "Instalando Codex CLI em $HOME/Codex..."
  if ! ops_npm_install_codex_cli; then
    announce_error "Não foi possível instalar o Codex CLI."
    return 1
  fi

  if ! mark_checkpoint "codex_cli"; then
    announce_error "Não foi possível registrar o checkpoint do Codex CLI."
    return 1
  fi
}

codex_cli_shell_configured() {
  local codex_path_line="export PATH=\"\$HOME/Codex/bin:\$PATH\""
  local fish_codex_path_marker="if not contains \"\$HOME/Codex/bin\" \$PATH"

  [[ -f "$BASHRC_FILE" ]] || return 1
  [[ -f "$ZSHRC_FILE" ]] || return 1
  [[ -f "$FISH_CONFIG_FILE" ]] || return 1

  grep -qxF "$codex_path_line" "$BASHRC_FILE" || return 1
  grep -qxF "$codex_path_line" "$ZSHRC_FILE" || return 1
  grep -qxF "$fish_codex_path_marker" "$FISH_CONFIG_FILE" || return 1
}

codex_cli_ready() {
  command -v codex >/dev/null 2>&1 && codex_cli_shell_configured
}

component_detect_codex_cli() {
  codex_cli_ready
}

component_checkpoint_key_codex_cli() {
  printf '%s\n' "codex_cli"
}

component_apply_codex_cli() {
  local missing_packages=()

  component_enabled "codex_cli" || return 0

  collect_missing_packages missing_packages "${CODEX_CLI_PACKAGES[@]}"
  if ((${#missing_packages[@]} > 0)); then
    announce_detail "Instalando dependências do Codex CLI..."
    if ! ops_pacman_install_needed "${missing_packages[@]}"; then
      announce_error "Não foi possível instalar as dependências do Codex CLI."
      return 1
    fi
  fi

  if ! setup_codex_cli; then
    return 1
  fi
}

component_verify_codex_cli() {
  local package_name

  for package_name in "${CODEX_CLI_PACKAGES[@]}"; do
    case "$package_name" in
      nodejs)
        verify_command "nodejs" "nodejs" "node" "pacman_package" "nodejs"
        ;;
      *)
        verify_package "$package_name" "$package_name" "$package_name" "pacman_package" "$package_name"
        ;;
    esac
  done
  verify_command "codex" "codex" "codex" "codex_cli_setup" "codex_cli"
}
