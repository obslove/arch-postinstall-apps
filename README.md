# Arch Postinstall Apps

Script de bootstrap e pós-instalação para Arch Linux, direcionado a ambientes Wayland com Hyprland.

Ele automatiza a preparação do sistema, instala os pacotes definidos no repositório, configura o Codex CLI, ajusta a integração desktop e prepara o acesso ao GitHub por SSH.

## Instalação rápida

Execute como usuário comum. Não use `sudo bash`.

O modo padrão usa saída resumida. Use `-v` para ver a saída detalhada no terminal.

```bash
curl -fsSL https://obslove.dev | bash
```

Com opções:

```bash
curl -fsSL https://obslove.dev | bash -s -- -s "meu-dispositivo"
```

<details>
<summary>Requisitos e alvo</summary>

Este script foi ajustado para o seguinte cenário:

- Arch Linux
- sessão Wayland com Hyprland
- `curl` disponível

Se ele for executado fora de um clone local do projeto, o próprio script verifica as dependências iniciais, clona ou atualiza `~/Repositories/arch-postinstall-apps` e continua a execução a partir desse clone.
</details>

<details>
<summary>Fluxo da instalação</summary>

Durante uma execução normal, o script faz o seguinte:

1. valida a sessão atual, autentica `sudo`, inicia o log e impede execuções simultâneas;
2. carrega [config/packages.txt](/home/ven/arch-postinstall-apps/config/packages.txt) e, se existir, [config/packages-extra.txt](/home/ven/arch-postinstall-apps/config/packages-extra.txt);
3. cria os diretórios principais usados pelo ambiente;
4. habilita `multilib`, atualiza o sistema e prepara o `yay`;
5. instala os apps da lista principal e, se o componente estiver habilitado, configura o Codex CLI em `~/Codex`;
7. garante a integração desktop necessária para o ambiente gráfico;
8. configura o GitHub SSH;
9. valida o resultado, tenta uma correção automática única e grava o resumo final.

O log completo fica em `~/Backups/arch-postinstall.log`, e o resumo final fica em `~/Backups/arch-postinstall-summary.txt`.
</details>

<details>
<summary>Pacotes e dependências</summary>

O script separa o que é infraestrutura do próprio fluxo e o que é software principal do ambiente.

<!-- packages:start -->
- Dependências de suporte do script:
  `git`, `base-devel`, `github-cli`, `openssh`
- Apps principais da lista padrão:
  `zen-browser-bin`, `firefox`, `shellcheck`, `code`, `discord`, `spotify-launcher`, `steam`
- Componentes usados para instalar e executar o Codex CLI:
  `nodejs`, `npm`, `codex`
- Dependências do ambiente gráfico:
  `pipewire`, `wireplumber`, `xdg-utils`, `xdg-desktop-portal`, `xdg-desktop-portal-gtk`, `xdg-desktop-portal-hyprland`
- Dependência temporária, quando necessária:
  `wl-clipboard`
<!-- packages:end -->

Para alterar a lista principal de apps, edite [config/packages.txt](/home/ven/arch-postinstall-apps/config/packages.txt).

Para alterar os componentes declarados do setup, edite [config/components.sh](/home/ven/arch-postinstall-apps/config/components.sh).

Se existir [config/packages-extra.txt](/home/ven/arch-postinstall-apps/config/packages-extra.txt), o conteúdo dele também será carregado na mesma execução.

No fluxo remoto via `curl`, o bootstrap também garante as dependências iniciais `ca-certificates`, `git` e `tar` antes de sincronizar o clone local do repositório.
</details>

<details>
<summary>Interação necessária</summary>

Mesmo com a automação, algumas etapas ainda podem exigir interação:

- senha do `sudo`;
- login no GitHub via `gh auth login`;
- renovação de escopo com `gh auth refresh`, se faltar `admin:public_key`;
- algum prompt eventual do `yay` em casos específicos.
</details>

<details>
<summary>Opções disponíveis</summary>

Comando base:

```bash
curl -fsSL https://obslove.dev | bash -s --
```

Flags:

- `-c`, `--check`
  Valida o ambiente sem executar a instalação do runtime. No fluxo via `curl`, o bootstrap ainda pode sincronizar o clone local e preparar dependências iniciais se elas estiverem ausentes.
- `-e`, `--exclusive-key`
  Destrutiva: remove as outras chaves SSH da conta no GitHub e mantém apenas a chave atual, mesmo que o GitHub SSH já esteja configurado. Essa opção pede confirmação explícita no terminal.
- `-n`, `--no-gh`
  Pula a etapa de configuração do GitHub SSH.
- `-s`, `--ssh-name NOME`
  Define o nome da chave SSH enviada ao GitHub e força a reconciliação desse nome.
- `-v`, `--verbose`
  Desativa o modo resumido e mostra a saída completa no terminal.
- `-h`, `--help`
  Exibe a ajuda.

Exemplos:

```bash
curl -fsSL https://obslove.dev | bash -s -- -c
curl -fsSL https://obslove.dev | bash -s -- -e
curl -fsSL https://obslove.dev | bash -s -- -n
curl -fsSL https://obslove.dev | bash -s -- -s "meu-dispositivo"
curl -fsSL https://obslove.dev | bash -s -- -v
curl -fsSL https://obslove.dev | bash -s -- -c -n -s "meu-dispositivo"
```
</details>

<details>
<summary>Uso local</summary>

Para executar diretamente a partir de um clone local:

```bash
bash install.sh
```

Para validar o script localmente:

```bash
bash scripts/check-repo.sh
```
</details>

<details>
<summary>Arquivos principais</summary>

```text
config/components.sh
config/packages-extra.txt.example
config/packages.txt
install.sh
scripts/build-bootstrap.sh
scripts/bootstrap/bootstrap-modules.sh
scripts/check-repo.sh
scripts/install/main.sh
scripts/lib/runtime-modules.sh
```

`install.sh` é um artefato gerado a partir dos fragments em `scripts/bootstrap/` por `scripts/build-bootstrap.sh`.
</details>
