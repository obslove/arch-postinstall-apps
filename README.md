# Arch Postinstall Apps

Setup simples de aplicativos para Arch Linux.

## Sobre

Um único script para bootstrap e pós-instalação no Arch Linux.

## Instalação rápida

`fish`

```fish
curl -fsSL https://raw.githubusercontent.com/obslove/arch-postinstall-apps/main/install.sh | bash
```

`bash`

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/obslove/arch-postinstall-apps/main/install.sh)
```

`zsh`

```zsh
bash <(curl -fsSL https://raw.githubusercontent.com/obslove/arch-postinstall-apps/main/install.sh)
```

Quando executado fora do repositório, o script instala `git`, clona ou atualiza `~/Repositories/arch-postinstall-apps` e continua a execução a partir dali.
Esse comando assume que `curl` esteja disponível na instalação padrão do Arch.
Execute como usuário normal, não com `sudo bash`.

## O que acontece

- grava log em `~/Backups/arch-postinstall.log`
- grava resumo em `~/Backups/arch-postinstall-summary.txt`
- grava `Hostname` no resumo final
- instala `git`
- clona ou atualiza `~/Repositories/arch-postinstall-apps`
- preserva a branch escolhida entre o bootstrap e a segunda etapa
- cria `~/Backups`, `~/Dots`, `~/Pictures/Wallpapers`, `~/Pictures/Screenshots`, `~/Videos`, `~/Projects` e `~/Codex`
- instala `reflector`
- habilita `multilib`, se necessário
- restaura a mirrorlist anterior se o `reflector` falhar
- marca checkpoint para não atualizar a mirrorlist novamente em reruns
- instala os pacotes via `pacman` primeiro
- instala `yay` se precisar
- informa quando não houver pacotes AUR na lista
- instala o restante via AUR
- repete automaticamente etapas mais frágeis se alguma falhar na primeira tentativa
- limpa arquivos temporários mesmo se o script abortar
- evita duas execuções simultâneas com lockfile
- instala `nodejs` e `npm` via `pacman`
- roda `npm config set prefix "$HOME/Codex"`
- instala `@openai/codex` no prefix `~/Codex`
- adiciona `~/Codex/bin` ao `PATH` no `.bashrc`
- marca checkpoint para não repetir a configuração do Codex CLI em reruns
- instala `github-cli` e `openssh`
- cria a chave SSH se não existir
- autentica no GitHub com `gh`, abrindo o navegador padrão
- copia automaticamente o código do device flow para a área de transferência
- renova o scope `admin:public_key` se precisar para gerenciar chaves SSH
- envia a chave SSH para o GitHub com título fixo `abslove`
- mantém a chave atual antes de remover as antigas, se `REPLACE_GITHUB_SSH_KEYS=1`
- pula a parte do GitHub se a autenticação falhar
- marca checkpoint para não repetir a configuração SSH do GitHub em reruns
- pode abrir ChatGPT, três abas do GitHub e YouTube no Zen Browser, se você habilitar
- marca checkpoint para não reabrir as abas do Zen em reruns
- verifica no fim se os binários principais realmente ficaram disponíveis
- grava no resumo a branch usada, o caminho do repositório e as versões principais

## O que exige interação

- senha do `sudo`
- login no GitHub via `gh auth login`, no final, abrindo no navegador padrão
- autorização extra do `gh auth refresh` se faltar o scope `admin:public_key`
- eventualmente algum prompt raro de pacote AUR

## Opcionais

- `REPLACE_GITHUB_SSH_KEYS=0`: preserva as chaves SSH atuais do GitHub
- `OPEN_ZEN_TABS=1`: abre ChatGPT, GitHub e YouTube no Zen Browser no fim

Se quiser usar essas opções no bootstrap, exporte-as antes:

`fish`

```fish
set -x REPLACE_GITHUB_SSH_KEYS 1
set -x OPEN_ZEN_TABS 1
```

`bash`

```bash
export REPLACE_GITHUB_SSH_KEYS=1
export OPEN_ZEN_TABS=1
```

`zsh`

```zsh
export REPLACE_GITHUB_SSH_KEYS=1
export OPEN_ZEN_TABS=1
```

## Uso local

`fish`

```fish
bash install.sh
```

`bash`

```bash
bash install.sh
```

`zsh`

```zsh
bash install.sh
```

## Validação local

`fish`

```fish
bash -n install.sh
shellcheck install.sh
```

`bash`

```bash
bash -n install.sh
shellcheck install.sh
```

`zsh`

```zsh
bash -n install.sh
shellcheck install.sh
```

## Pacotes

- `code`
- `discord`
- `git`
- `nodejs`
- `npm`
- `shellcheck`
- `google-chrome` (AUR)
- `spotify-launcher`
- `steam`
- `zen-browser-bin` (AUR)

Edite `config/packages.txt` para alterar a lista principal.
Se existir `config/packages-extra.txt`, ele também será carregado.
Se esse arquivo não existir, o script registra isso no log e segue normalmente.

Se não houver helper AUR instalado, o script instala `yay`.
Se `paru` ou `yay` já existirem, o script reutiliza o helper encontrado.
O script instala `reflector` e atualiza a mirrorlist antes do `pacman -Syu`.

## Estrutura

```text
config/packages-extra.txt.example
config/packages.txt
install.sh
```
