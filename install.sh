#!/usr/bin/env bash

set -euo pipefail

SELF_PATH="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SELF_PATH")" && pwd)"
LOCAL_MAIN="$SCRIPT_DIR/scripts/install/main.sh"

if [[ -f "$SELF_PATH" && -f "$LOCAL_MAIN" ]]; then
  exec bash "$LOCAL_MAIN" "$@"
fi

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
STEP_OUTPUT_ONLY=1
STATE_DIR="${POSTINSTALL_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/arch-postinstall-apps}"
LOCK_DIR="${POSTINSTALL_LOCK_DIR:-$STATE_DIR/lock}"
LOCK_HELD="${POSTINSTALL_LOCK_HELD:-0}"
BOOTSTRAP_PACKAGES=(
  ca-certificates
  git
  curl
  tar
)

cleanup_paths=()
step_counter=0
step_open=0
step_total=0
STEP_RESULT_STATUS=""
STEP_RESULT_MESSAGE=""
style_reset=""
style_step=""
style_detail=""
style_warning=""
style_error=""
style_muted=""

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  style_reset=$'\033[0m'
  style_step=$'\033[1;36m'
  style_detail=$'\033[0;37m'
  style_warning=$'\033[1;33m'
  style_error=$'\033[1;31m'
  style_muted=$'\033[0;90m'
fi

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
        shift
        ;;
      -e|--exclusive-key)
        shift
        ;;
      -n|--no-gh)
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

ensure_not_root() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    announce_error "Execute este script como usuário comum, e não como root."
    exit 1
  fi
}

checkpoint_file() {
  printf '%s/checkpoints/%s.done\n' "$STATE_DIR" "$1"
}

has_checkpoint() {
  [[ -f "$(checkpoint_file "$1")" ]]
}

acquire_lock() {
  local existing_pid=""

  if [[ "$LOCK_HELD" == "1" ]]; then
    return
  fi

  mkdir -p "$STATE_DIR"
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    printf '%s\n' "$$" >"$LOCK_DIR/pid"
    register_cleanup_path "$LOCK_DIR"
    export POSTINSTALL_LOCK_HELD=1
    LOCK_HELD=1
    return
  fi

  if [[ -f "$LOCK_DIR/pid" ]]; then
    existing_pid="$(<"$LOCK_DIR/pid")"
  fi

  if [[ -z "$existing_pid" ]] || ! kill -0 "$existing_pid" 2>/dev/null; then
    announce_warning "Foi detectado um lock órfão. Limpando a execução anterior."
    rm -rf "$LOCK_DIR"
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      printf '%s\n' "$$" >"$LOCK_DIR/pid"
      register_cleanup_path "$LOCK_DIR"
      export POSTINSTALL_LOCK_HELD=1
      LOCK_HELD=1
      return
    fi
  fi

  announce_error "Já existe outra execução do script em andamento."
  if [[ -f "$LOCK_DIR/pid" ]]; then
    announce_error "PID atual do lock: $(<"$LOCK_DIR/pid")"
  fi
  exit 1
}

register_cleanup_path() {
  cleanup_paths+=("$1")
}

package_is_installed() {
  pacman -Q "$1" >/dev/null 2>&1
}

collect_missing_packages() {
  local array_name="$1"
  shift
  local package_name
  # shellcheck disable=SC2178
  declare -n target_array="$array_name"

  target_array=()
  for package_name in "$@"; do
    if ! package_is_installed "$package_name"; then
      target_array+=("$package_name")
    fi
  done
}

cleanup() {
  local path

  for path in "${cleanup_paths[@]}"; do
    [[ -n "$path" ]] || continue
    rm -rf "$path"
  done
}

init_logging() {
  if [[ "${POSTINSTALL_LOG_INITIALIZED:-0}" == "1" ]]; then
    return
  fi

  mkdir -p "$(dirname "$LOG_FILE")"
  touch "$LOG_FILE"

  export POSTINSTALL_LOG_FILE="$LOG_FILE"
  export POSTINSTALL_LOG_INITIALIZED=1

  exec > >(tee -a "$LOG_FILE") 2>&1
}

write_log_only() {
  if [[ "${POSTINSTALL_LOG_INITIALIZED:-0}" != "1" ]]; then
    return 0
  fi

  printf '%s\n' "$1" >>"$LOG_FILE"
}

style_text() {
  local style="$1"
  local text="$2"

  if [[ -z "$style" ]]; then
    printf '%s' "$text"
    return 0
  fi

  printf '%s%s%s' "$style" "$text" "$style_reset"
}

emit_notice() {
  local symbol="$1"
  local style="$2"
  local message="$3"
  local line_prefix=""

  if [[ "$step_open" == "1" ]]; then
    line_prefix="│  "
  fi

  printf '%s%s %s\n' "$line_prefix" "$(style_text "$style" "$symbol")" "$message"
}

set_step_total() {
  step_total="$1"
}

step_result_reset() {
  STEP_RESULT_STATUS=""
  STEP_RESULT_MESSAGE=""
}

step_result_success() {
  STEP_RESULT_STATUS="success"
  STEP_RESULT_MESSAGE="${1:-}"
}

step_result_skipped() {
  STEP_RESULT_STATUS="skipped"
  STEP_RESULT_MESSAGE="${1:-}"
}

step_result_hard_fail() {
  STEP_RESULT_STATUS="hard_fail"
  STEP_RESULT_MESSAGE="${1:-}"
}

handle_bootstrap_step_result_or_exit() {
  case "${STEP_RESULT_STATUS:-}" in
    success|skipped|"")
      return 0
      ;;
    hard_fail)
      if [[ -n "${STEP_RESULT_MESSAGE:-}" ]]; then
        announce_error "$STEP_RESULT_MESSAGE"
      fi
      exit 1
      ;;
    *)
      announce_error "Resultado de etapa desconhecido no bootstrap: ${STEP_RESULT_STATUS:-indefinido}"
      exit 1
      ;;
  esac
}

announce_step() {
  local title="$1"
  local header=""

  close_step_block
  step_counter=$((step_counter + 1))
  if (( step_total > 0 )); then
    header=$(printf 'Etapa %02d/%02d • %s' "$step_counter" "$step_total" "$title")
  else
    header=$(printf 'Etapa %02d • %s' "$step_counter" "$title")
  fi
  echo
  printf '%s %s\n' "$(style_text "$style_step" "╭─")" "$(style_text "$style_step" "$header")"
  step_open=1
}

announce_detail() {
  if [[ "$STEP_OUTPUT_ONLY" == "1" ]]; then
    if [[ "$1" == *"Etapa ignorada."* ]]; then
      write_log_only "$1"
      return 0
    fi
    printf '│  %s %s\n' "$(style_text "$style_detail" "•")" "$1"
    return 0
  fi

  printf '│  %s %s\n' "$(style_text "$style_detail" "•")" "$1"
}

announce_warning() {
  emit_notice "!" "$style_warning" "$1"
}

announce_error() {
  emit_notice "x" "$style_error" "$1"
}

announce_prompt() {
  emit_notice "?" "$style_step" "$1"
}

close_step_block() {
  if [[ "$step_open" != "1" ]]; then
    return 0
  fi

  style_text "$style_muted" "╰─"
  printf '\n'
  step_open=0
}

run_with_terminal_stdin() {
  if [[ -r /dev/tty ]]; then
    "$@" </dev/tty
    return
  fi

  "$@"
}

run_log_only() {
  if [[ "$STEP_OUTPUT_ONLY" == "1" ]]; then
    "$@" </dev/null >>"$LOG_FILE" 2>&1
    return
  fi

  "$@" </dev/null 2>&1 | sed 's/^/│    /'
  return "${PIPESTATUS[0]}"
}

run_interactive_log_only() {
  if [[ "$STEP_OUTPUT_ONLY" == "1" ]]; then
    run_with_terminal_stdin "$@" >>"$LOG_FILE" 2>&1
    return
  fi

  run_with_terminal_stdin "$@" 2>&1 | sed 's/^/│    /'
  return "${PIPESTATUS[0]}"
}

retry() {
  "$@"
}

retry_log_only() {
  run_log_only "$@"
}

retry_interactive_log_only() {
  run_interactive_log_only "$@"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    announce_error "Comando obrigatório não encontrado: $1"
    exit 1
  fi
}

get_host_name() {
  if command -v hostname >/dev/null 2>&1; then
    hostname
    return
  fi

  if command -v hostnamectl >/dev/null 2>&1; then
    hostnamectl hostname 2>/dev/null
    return
  fi

  if [[ -f /etc/hostname ]]; then
    cat /etc/hostname
    return
  fi

  uname -n
}

sanitize_label() {
  printf '%s' "$1" | tr -cs '[:alnum:].@_-' '-'
}

build_ssh_key_name() {
  local github_login=""

  if [[ -n "$GITHUB_SSH_KEY_NAME" ]]; then
    printf '%s\n' "$GITHUB_SSH_KEY_NAME"
    return
  fi

  if command -v gh >/dev/null 2>&1; then
    github_login="$(gh api user --jq '.login' 2>/dev/null || true)"
    if [[ -n "$github_login" ]]; then
      printf '%s\n' "$github_login"
      return
    fi
  fi

  printf '%s\n' "$USER"
}

current_public_ssh_key() {
  [[ -f "${SSH_KEY_PATH}.pub" ]] || return 1
  awk 'NR == 1 { print $1, $2 }' "${SSH_KEY_PATH}.pub"
}

find_current_github_ssh_key() {
  local current_key

  current_key="$(current_public_ssh_key)" || return 1
  gh api user/keys --jq ".[] | select(.key == \"$current_key\") | [.id, .title] | @tsv"
}

github_has_expected_ssh_key_name() {
  local key_data
  local current_key_name=""

  key_data="$(find_current_github_ssh_key 2>/dev/null || true)"
  [[ -n "$key_data" ]] || return 1
  IFS=$'\t' read -r _ current_key_name <<<"$key_data"
  [[ "$current_key_name" == "$(build_ssh_key_name)" ]]
}

github_ssh_ready() {
  [[ -f "${SSH_KEY_PATH}.pub" ]] || return 1
  command -v gh >/dev/null 2>&1 || return 1
  gh auth status >/dev/null 2>&1 || return 1
  has_checkpoint "github_ssh" || return 1
  github_has_expected_ssh_key_name
}

desired_repo_origin_url() {
  if github_ssh_ready; then
    printf '%s\n' "$REPO_SSH_URL"
    return
  fi

  printf '%s\n' "$REPO_HTTPS_URL"
}

ensure_repo_origin_remote() {
  local repo_dir="$1"
  local current_origin_url=""
  local desired_origin_url

  desired_origin_url="$(desired_repo_origin_url)"
  current_origin_url="$(git -C "$repo_dir" remote get-url origin 2>/dev/null || true)"

  if [[ -z "$current_origin_url" ]]; then
    git -C "$repo_dir" remote add origin "$desired_origin_url"
    return
  fi

  if [[ "$current_origin_url" != "$REPO_HTTPS_URL" && "$current_origin_url" != "$REPO_SSH_URL" ]]; then
    announce_detail "Foi detectado um remoto origin personalizado em $repo_dir. A configuração atual será mantida."
    return
  fi

  if [[ "$current_origin_url" != "$desired_origin_url" ]]; then
    git -C "$repo_dir" remote set-url origin "$desired_origin_url"
  fi
}

get_repo_branch() {
  local repo_dir="$1"
  local branch_name=""

  if ! git -C "$repo_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 1
  fi

  branch_name="$(git -C "$repo_dir" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  if [[ -n "$branch_name" ]]; then
    printf '%s\n' "$branch_name"
    return 0
  fi

  branch_name="$(git -C "$repo_dir" rev-parse --short HEAD 2>/dev/null || true)"
  [[ -n "$branch_name" ]] || return 1
  printf 'detached@%s\n' "$branch_name"
}

repo_is_dirty() {
  ! git -C "$INSTALL_DIR" diff --quiet --no-ext-diff || \
    ! git -C "$INSTALL_DIR" diff --cached --quiet --no-ext-diff || \
    [[ -n "$(git -C "$INSTALL_DIR" status --porcelain --untracked-files=normal)" ]]
}

is_wayland_session() {
  [[ "${XDG_SESSION_TYPE:-}" == "wayland" || -n "${WAYLAND_DISPLAY:-}" ]]
}

is_hyprland_session() {
  [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || \
    [[ "${XDG_CURRENT_DESKTOP:-}" == *Hyprland* ]] || \
    [[ "${DESKTOP_SESSION:-}" == "hyprland" ]]
}

is_supported_session() {
  is_wayland_session && is_hyprland_session
}

ensure_supported_session() {
  if is_supported_session; then
    return 0
  fi

  announce_error "Este script foi ajustado para Wayland com Hyprland."
  announce_error "Sessão atual: XDG_SESSION_TYPE='${XDG_SESSION_TYPE:-}', XDG_CURRENT_DESKTOP='${XDG_CURRENT_DESKTOP:-}', DESKTOP_SESSION='${DESKTOP_SESSION:-}'"
  exit 1
}

ensure_arch() {
  if [[ ! -f /etc/arch-release ]]; then
    announce_error "Este script foi feito para Arch Linux."
    exit 1
  fi
}

sync_repo() {
  local current_branch=""
  local fetched_origin=0

  mkdir -p "$(dirname "$INSTALL_DIR")"

  if [[ -d "$INSTALL_DIR/.git" ]]; then
    announce_step "Atualizando repositório..."
    if repo_is_dirty; then
      current_branch="$(get_repo_branch "$INSTALL_DIR" 2>/dev/null || true)"
      if [[ -n "$current_branch" && "$current_branch" != "main" ]]; then
        announce_error "O clone gerenciado está com mudanças locais na branch '$current_branch'."
        announce_error "Não dá para executar com segurança a branch 'main' sem limpar ou mover essas mudanças."
        return 1
      fi

      announce_warning "O repositório local tem alterações. A atualização automática será ignorada."
      return
    fi

    if ! ensure_repo_origin_remote "$INSTALL_DIR"; then
      announce_error "Não foi possível ajustar o remoto origin do clone gerenciado."
      return 1
    fi

    if retry_log_only git -C "$INSTALL_DIR" fetch origin; then
      fetched_origin=1
    else
      announce_warning "Falha ao buscar atualizações de origin. O script tentará usar a cópia local."
    fi

    if git -C "$INSTALL_DIR" show-ref --verify --quiet "refs/heads/main"; then
      if ! run_log_only git -C "$INSTALL_DIR" checkout main; then
        announce_error "Não foi possível trocar para a branch local 'main'."
        return 1
      fi
    elif git -C "$INSTALL_DIR" show-ref --verify --quiet "refs/remotes/origin/main"; then
      if ! run_log_only git -C "$INSTALL_DIR" checkout -b main origin/main; then
        announce_error "Não foi possível criar a branch local 'main' a partir de origin."
        return 1
      fi
    elif [[ "$fetched_origin" == "0" ]]; then
      announce_error "Não foi possível atualizar origin e a branch 'main' não existe localmente."
      announce_error "Verifique acesso ao GitHub ou recupere um clone local válido."
      return 1
    else
      announce_error "Branch 'main' não encontrada no repositório local nem em origin."
      return 1
    fi

    if [[ "$fetched_origin" == "0" ]]; then
      announce_warning "O 'git pull' será ignorado porque o fetch de origin falhou. O script continuará com a branch local."
      return
    fi

    if ! retry_log_only git -C "$INSTALL_DIR" pull --ff-only origin main; then
      announce_warning "Falha ao atualizar 'main' com 'git pull --ff-only'. O script continuará com a cópia atual."
    fi
  else
    if [[ -e "$INSTALL_DIR" ]]; then
      announce_error "$INSTALL_DIR já existe e não é um repositório git."
      return 1
    fi

    announce_step "Clonando repositório..."
    if ! retry_log_only git clone --branch main --single-branch "$REPO_HTTPS_URL" "$INSTALL_DIR"; then
      announce_error "Falha ao clonar 'main' de $REPO_HTTPS_URL."
      announce_error "Verifique acesso ao GitHub e se a branch existe no remoto."
      return 1
    fi
  fi
}

bootstrap_install_dependencies_step() {
  local array_name="$1"
  # shellcheck disable=SC2178
  declare -n missing_packages="$array_name"

  step_result_reset

  if ((${#missing_packages[@]} == 0)); then
    announce_detail "As dependências iniciais já estão disponíveis. Etapa ignorada."
    step_result_skipped "As dependências iniciais já estavam disponíveis."
    return 0
  fi

  if retry_interactive_log_only sudo pacman -Syu --needed --noconfirm "${missing_packages[@]}"; then
    step_result_success "As dependências iniciais foram instaladas."
    return 0
  fi

  step_result_hard_fail "Não foi possível instalar as dependências iniciais."
}

bootstrap_sync_repo_step() {
  step_result_reset

  if sync_repo; then
    step_result_success "O repositório gerenciado foi sincronizado."
    return 0
  fi

  step_result_hard_fail "Não foi possível sincronizar o repositório gerenciado."
}

main() {
  local bootstrap_system_updated=0
  local bootstrap_missing_packages=()

  parse_cli_args "$@"
  trap cleanup EXIT

  ensure_not_root
  acquire_lock
  collect_missing_packages bootstrap_missing_packages "${BOOTSTRAP_PACKAGES[@]}"
  if ((${#bootstrap_missing_packages[@]} > 0)); then
    set_step_total 4
  else
    set_step_total 3
  fi

  announce_step "Validando ambiente..."
  ensure_arch
  ensure_supported_session
  require_command pacman
  require_command sudo
  announce_prompt "Autenticando sudo..."
  run_with_terminal_stdin sudo -v
  init_logging

  announce_step "Verificando dependências iniciais já instaladas..."
  if ((${#bootstrap_missing_packages[@]} > 0)); then
    announce_step "Instalando dependências iniciais..."
    bootstrap_install_dependencies_step bootstrap_missing_packages
    handle_bootstrap_step_result_or_exit
    bootstrap_system_updated=1
  fi

  require_command git
  require_command curl
  require_command tar
  bootstrap_sync_repo_step
  handle_bootstrap_step_result_or_exit

  exec env \
    POSTINSTALL_BOOTSTRAP_UPDATED="$bootstrap_system_updated" \
    POSTINSTALL_LOG_FILE="$LOG_FILE" \
    POSTINSTALL_LOG_INITIALIZED=1 \
    POSTINSTALL_LOCK_HELD=1 \
    POSTINSTALL_SUMMARY_FILE="$SUMMARY_FILE" \
    POSTINSTALL_STATE_DIR="$STATE_DIR" \
    POSTINSTALL_LOCK_DIR="$LOCK_DIR" \
    SSH_KEY_PATH="$SSH_KEY_PATH" \
    REPOSITORIES_DIR="$REPOSITORIES_DIR" \
    YAY_REPO_DIR="$YAY_REPO_DIR" \
    YAY_SNAPSHOT_URL="$YAY_SNAPSHOT_URL" \
    bash "$INSTALL_DIR/scripts/install/main.sh" "$@"
}

main "$@"
