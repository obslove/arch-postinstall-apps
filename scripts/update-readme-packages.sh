#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
README_FILE="$REPO_DIR/README.md"
PACKAGE_FILE="$REPO_DIR/config/packages.txt"

usage() {
  cat <<'EOF'
Uso:
  bash scripts/update-readme-packages.sh
  bash scripts/update-readme-packages.sh --check
EOF
}

render_package_block() {
  local line
  local items=()
  local app_items=()
  local codex_items=()
  local item

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -n "$line" ]] || continue
    [[ "$line" == \#* ]] && continue
    items+=("$line")
  done <"$PACKAGE_FILE"

  for item in "${items[@]}"; do
    case "$item" in
      git)
        ;;
      nodejs|npm|codex)
        codex_items+=("$item")
        ;;
      *)
        app_items+=("$item")
        ;;
    esac
  done

  printf '%s\n' '<!-- packages:start -->'
  printf '%s\n' '- Dependências de suporte do script:'
  printf '%s\n' '  `git`, `base-devel`, `yay`, `github-cli`, `openssh`'
  printf '%s\n' '- Apps principais da lista padrão:'
  printf '  '
  printf '`%s`' "${app_items[0]}"
  for item in "${app_items[@]:1}"; do
    printf ', `%s`' "$item"
  done
  printf '\n'
  printf '%s\n' '- Componentes usados para instalar e executar o Codex CLI:'
  printf '  '
  printf '`%s`' "${codex_items[0]}"
  for item in "${codex_items[@]:1}"; do
    printf ', `%s`' "$item"
  done
  printf '\n'
  printf '%s\n' '- Dependências do ambiente gráfico:'
  printf '%s\n' '  `pipewire`, `wireplumber`, `xdg-utils`, `xdg-desktop-portal`, `xdg-desktop-portal-gtk`, `xdg-desktop-portal-hyprland`'
  printf '%s\n' '- Dependência temporária, quando necessária:'
  printf '%s\n' '  `wl-clipboard`'
  printf '%s\n' '<!-- packages:end -->'
}

replace_package_block() {
  local temp_file
  local start_line
  local end_line

  start_line="$(grep -n '^<!-- packages:start -->$' "$README_FILE" | cut -d: -f1)"
  end_line="$(grep -n '^<!-- packages:end -->$' "$README_FILE" | cut -d: -f1)"

  [[ -n "$start_line" && -n "$end_line" ]] || {
    printf 'Erro: marcadores de pacotes não encontrados no README.\n' >&2
    exit 1
  }

  temp_file="$(mktemp)"
  if (( start_line > 1 )); then
    head -n $((start_line - 1)) "$README_FILE" >"$temp_file"
  else
    : >"$temp_file"
  fi

  render_package_block >>"$temp_file"
  tail -n +$((end_line + 1)) "$README_FILE" >>"$temp_file"

  if [[ "${1:-}" == "--check" ]]; then
    if ! cmp -s "$README_FILE" "$temp_file"; then
      printf 'Erro: a seção de pacotes do README está desatualizada. Rode bash scripts/update-readme-packages.sh.\n' >&2
      rm -f "$temp_file"
      exit 1
    fi
    rm -f "$temp_file"
    return 0
  fi

  mv "$temp_file" "$README_FILE"
}

main() {
  case "${1:-}" in
    ""|--check)
      replace_package_block "${1:-}"
      ;;
    -h|--help)
      usage
      ;;
    *)
      printf 'Erro: opção desconhecida: %s\n' "${1:-}" >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
