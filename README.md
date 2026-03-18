# Arch Postinstall Apps

Script de bootstrap e pós-instalação para Arch Linux em Wayland com Hyprland.

## Instalação rápida

```bash
curl -fsSL https://obslove.dev | bash
```

Com flags:

```bash
curl -fsSL https://obslove.dev | bash -s -- -...
```

Execute como usuário comum. Não use `sudo bash`.

<details>
<summary>Requisitos e alvo</summary>

- Arch Linux
- Wayland com Hyprland
- `curl` disponível

Se o script for executado fora do repositório, ele verifica dependências iniciais, clona ou atualiza `~/Repositories/arch-postinstall-apps` e continua dali.
</details>

<details>
<summary>O que o script faz</summary>

1. Valida o ambiente, autentica `sudo`, inicia o log e evita execuções simultâneas.
2. Cria os diretórios principais em `~/Backups`, `~/Codex`, `~/Dots`, `~/Pictures`, `~/Projects`, `~/Repositories` e `~/Videos`.
3. Carrega `config/packages.txt` e, se existir, `config/packages-extra.txt`.
4. Habilita `multilib`, atualiza o sistema e prepara o `yay`.
5. Instala a lista principal de pacotes na ordem definida no arquivo de configuração.
6. Configura o Codex CLI em `~/Codex`.
7. Garante a integração desktop do ambiente.
8. Configura GitHub SSH.
9. Valida a instalação, tenta uma correção automática única e grava o resumo final.
</details>

<details>
<summary>Pacotes e dependências</summary>

- Dependências de suporte: `git`, `nodejs`, `npm`, `base-devel`, `yay`, `github-cli`, `openssh`
- Apps da lista principal padrão: `shellcheck`, `zen-browser-bin`, `google-chrome`, `code`, `discord`, `spotify-launcher`, `steam`, `codex`
- Dependências do ambiente: `pipewire`, `wireplumber`, `xdg-utils`, `xdg-desktop-portal`, `xdg-desktop-portal-gtk`, `xdg-desktop-portal-hyprland`
- Dependência temporária, quando necessária: `wl-clipboard`

Edite [config/packages.txt](/home/ven/arch-postinstall-apps-main/config/packages.txt) para alterar a lista principal. Se existir [config/packages-extra.txt](/home/ven/arch-postinstall-apps-main/config/packages-extra.txt), ele também será carregado.
</details>

<details>
<summary>O que exige interação</summary>

- Senha do `sudo`
- Login no GitHub via `gh auth login`
- Autorização adicional do `gh auth refresh`, se faltar o escopo `admin:public_key`
- Eventual prompt raro de pacote AUR
</details>

<details>
<summary>Opcionais</summary>

Comando base:

```bash
curl -fsSL https://obslove.dev | bash -s --
```

Flags disponíveis:

- `-c`, `--check`: valida o ambiente sem instalar nem alterar o sistema
- `-d`, `--no-desktop`: pula a etapa de integração desktop
- `-g`, `--no-gh`: pula a etapa de GitHub SSH
- `-k`, `--keep-gh-keys`: preserva as chaves SSH atuais do GitHub
- `-t`, `--ssh-title NOME`: define o título da chave SSH enviada ao GitHub
- `-v`, `--verbose`: desativa o modo resumido
- `-b`, `--branch NOME`: executa uma branch específica
- `-h`, `--help`: mostra a ajuda

Exemplos:

```bash
curl -fsSL https://obslove.dev | bash -s -- -c
curl -fsSL https://obslove.dev | bash -s -- -g
curl -fsSL https://obslove.dev | bash -s -- -d
curl -fsSL https://obslove.dev | bash -s -- -k
curl -fsSL https://obslove.dev | bash -s -- -t meu-dispositivo
curl -fsSL https://obslove.dev | bash -s -- -v
curl -fsSL https://obslove.dev | bash -s -- -c -g -t meu-dispositivo
```

As variáveis de ambiente antigas continuam funcionando por compatibilidade.
</details>

<details>
<summary>Uso local</summary>

Executar em um clone local:

```bash
bash install.sh
```

Validar localmente:

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
