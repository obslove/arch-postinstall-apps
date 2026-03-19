#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR

SHARED_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=shared.sh
source "$SHARED_LIB_DIR/shared.sh"
COMPONENT_CONFIG_FILE="$(cd "$SHARED_LIB_DIR/../../config" && pwd)/components.sh"
# shellcheck source=../../config/components.sh
source "$COMPONENT_CONFIG_FILE"

config_init() {
  local repo_dir="$1"

  REPO_DIR="$repo_dir"
  SCRIPT_DIR="$REPO_DIR"
  PACKAGE_FILE="$REPO_DIR/config/packages.txt"
  EXTRA_PACKAGE_FILE="$REPO_DIR/config/packages-extra.txt"
  BASHRC_FILE="$HOME/.bashrc"
  ZSHRC_FILE="$HOME/.zshrc"
  FISH_CONFIG_FILE="$HOME/.config/fish/config.fish"
  REPO_HTTPS_URL="https://github.com/obslove/arch-postinstall-apps.git"
  REPO_SSH_URL="git@github.com:obslove/arch-postinstall-apps.git"
  REPOSITORIES_DIR="${REPOSITORIES_DIR:-$HOME/Repositories}"
  INSTALL_DIR="${BOOTSTRAP_DIR:-$REPOSITORIES_DIR/arch-postinstall-apps}"
  YAY_REPO_DIR="${YAY_REPO_DIR:-$REPOSITORIES_DIR/yay}"
  YAY_SNAPSHOT_URL="${YAY_SNAPSHOT_URL:-https://aur.archlinux.org/cgit/aur.git/snapshot/yay.tar.gz}"
  SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_ed25519}"
  GITHUB_SSH_KEY_NAME=""
  LOG_FILE="${POSTINSTALL_LOG_FILE:-$HOME/Backups/arch-postinstall.log}"
  SUMMARY_FILE="${POSTINSTALL_SUMMARY_FILE:-$HOME/Backups/arch-postinstall-summary.txt}"
  CHECK_ONLY=0
  EXCLUSIVE_GITHUB_SSH_KEY=0
  SKIP_GITHUB_SSH=0
  STEP_OUTPUT_ONLY=1
  STATE_DIR="${POSTINSTALL_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/arch-postinstall-apps}"
  LOCK_DIR="${POSTINSTALL_LOCK_DIR:-$STATE_DIR/lock}"
  LOCK_HELD="${POSTINSTALL_LOCK_HELD:-0}"
  SYSTEM_UPDATED="${POSTINSTALL_BOOTSTRAP_UPDATED:-${POSTINSTALL_SYSTEM_UPDATED:-0}}"
}

finalize_config() {
  readonly REPO_DIR
  readonly SCRIPT_DIR
  readonly PACKAGE_FILE
  readonly EXTRA_PACKAGE_FILE
  readonly BASHRC_FILE
  readonly ZSHRC_FILE
  readonly FISH_CONFIG_FILE
  readonly REPO_HTTPS_URL
  readonly REPO_SSH_URL
  readonly REPOSITORIES_DIR
  readonly INSTALL_DIR
  readonly YAY_REPO_DIR
  readonly YAY_SNAPSHOT_URL
  readonly SSH_KEY_PATH
  readonly GITHUB_SSH_KEY_NAME
  readonly LOG_FILE
  readonly SUMMARY_FILE
  readonly CHECK_ONLY
  readonly EXCLUSIVE_GITHUB_SSH_KEY
  readonly SKIP_GITHUB_SSH
  readonly STEP_OUTPUT_ONLY
  readonly STATE_DIR
  readonly LOCK_DIR
  readonly SYSTEM_UPDATED
}

execution_state_reset() {
  official_packages=()
  aur_packages=()
  official_failed=()
  aur_failed=()
  support_packages=()
  environment_packages=()
  aur_helper=""
  aur_helper_status="não preparado"
  verified_commands=()
  missing_commands=()
  version_info=()
  temp_clipboard_package=""
  official_repo_metadata_checked=0
  official_repo_metadata_ready=0
  github_ssh_status="pendente"
  desktop_integration_status="pendente"
  soft_failures=()
  step_result_reset
}

runtime_state_init() {
  cleanup_paths=()
  step_counter=0
  step_open=0
  step_total=0
  init_output_styles
  execution_state_reset
}

record_soft_failure() {
  local message="$1"

  [[ -n "$message" ]] || return 0
  append_array_item soft_failures "$message"
}

print_usage() {
  cat <<'EOF'
Uso:
  bash install.sh [opções]
  curl -fsSL https://obslove.dev | bash -s -- [opções]

Opções:
  -c, --check             Valida o ambiente sem instalar nem alterar o sistema.
  -e, --exclusive-key     Destrutiva: remove as outras chaves SSH do GitHub e mantém só a atual.
  -n, --no-gh             Pula a etapa de GitHub SSH.
  -s, --ssh-name NOME     Define o nome da chave SSH enviada ao GitHub.
  -v, --verbose           Desativa o modo resumido e mostra a saída completa.
  -h, --help              Exibe esta ajuda.
EOF
}

parse_cli_args() {
  while (($# > 0)); do
    case "$1" in
      -c|--check)
        CHECK_ONLY=1
        shift
        ;;
      -e|--exclusive-key)
        EXCLUSIVE_GITHUB_SSH_KEY=1
        shift
        ;;
      -n|--no-gh)
        SKIP_GITHUB_SSH=1
        shift
        ;;
      -s|--ssh-name)
        [[ $# -ge 2 ]] || {
          printf 'Erro: faltou informar o valor de %s.\n' "$1" >&2
          exit 1
        }
        GITHUB_SSH_KEY_NAME="$2"
        shift 2
        ;;
      --ssh-name=*)
        GITHUB_SSH_KEY_NAME="${1#*=}"
        shift
        ;;
      -v|--verbose)
        STEP_OUTPUT_ONLY=0
        shift
        ;;
      -h|--help)
        print_usage
        exit 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        printf 'Erro: opção desconhecida: %s\n' "$1" >&2
        printf 'Use --help para ver as opções disponíveis.\n' >&2
        exit 1
        ;;
      *)
        printf 'Erro: argumento não reconhecido: %s\n' "$1" >&2
        exit 1
        ;;
    esac
  done

  if (($# > 0)); then
    printf 'Erro: argumentos extras não reconhecidos: %s\n' "$*" >&2
    exit 1
  fi
}

create_directories() {
  announce_step "Criando diretórios..."
  mkdir -p \
    "$HOME/Backups" \
    "$HOME/Codex" \
    "$HOME/Dots" \
    "$HOME/Pictures/Screenshots" \
    "$HOME/Pictures/Wallpapers" \
    "$HOME/Projects" \
    "$REPOSITORIES_DIR" \
    "$HOME/Videos"
}
