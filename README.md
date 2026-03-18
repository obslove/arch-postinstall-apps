# Arch Postinstall Apps

Script de bootstrap e pós-instalação para Arch Linux, direcionado a ambientes Wayland com Hyprland.

Ele automatiza a preparação do sistema, instala os pacotes definidos no repositório, configura o Codex CLI, ajusta a integração desktop e prepara o acesso ao GitHub por SSH.

## Instalação rápida

Execute como usuário comum. Não use `sudo bash`.

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
2. cria os diretórios principais usados pelo ambiente;
3. carrega [config/packages.txt](/home/ven/arch-postinstall-apps/config/packages.txt) e, se existir, [config/packages-extra.txt](/home/ven/arch-postinstall-apps/config/packages-extra.txt);
4. habilita `multilib`, atualiza o sistema e prepara o `yay`;
5. instala os apps e dependências definidos na lista de pacotes;
6. configura o Codex CLI em `~/Codex`;
7. garante a integração desktop necessária para o ambiente gráfico;
8. configura o GitHub SSH;
9. valida o resultado, tenta uma correção automática única e grava o resumo final.

O log completo fica em `~/Backups/arch-postinstall.log`, e o resumo final fica em `~/Backups/arch-postinstall-summary.txt`.
</details>

<details>
<summary>Pacotes e dependências</summary>

O script separa o que é infraestrutura do próprio fluxo e o que é software principal do ambiente.

- Dependências de suporte do script:
  `git`, `base-devel`, `yay`, `github-cli`, `openssh`
- Apps principais da lista padrão:
  `shellcheck`, `zen-browser-bin`, `google-chrome`, `code`, `discord`, `spotify-launcher`, `steam`
- Componentes usados para instalar e executar o Codex CLI:
  `nodejs`, `npm`, `codex`
- Dependências do ambiente gráfico:
  `pipewire`, `wireplumber`, `xdg-utils`, `xdg-desktop-portal`, `xdg-desktop-portal-gtk`, `xdg-desktop-portal-hyprland`
- Dependência temporária, quando necessária:
  `wl-clipboard`

Para alterar a lista principal, edite [config/packages.txt](/home/ven/arch-postinstall-apps/config/packages.txt).

Se existir [config/packages-extra.txt](/home/ven/arch-postinstall-apps/config/packages-extra.txt), o conteúdo dele também será carregado na mesma execução.
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
  Valida o ambiente sem instalar nem alterar o sistema.
- `-e`, `--exclusive-key`
  Remove as outras chaves SSH da conta no GitHub e mantém apenas a chave atual.
- `-n`, `--no-gh`
  Pula a etapa de configuração do GitHub SSH.
- `-s`, `--ssh-name NOME`
  Define o nome da chave SSH enviada ao GitHub.
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
bash -n install.sh
shellcheck install.sh
```
</details>

<details>
<summary>Arquivos principais</summary>

```text
config/packages-extra.txt.example
config/packages.txt
install.sh
```
</details>
