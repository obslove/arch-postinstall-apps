#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034

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
