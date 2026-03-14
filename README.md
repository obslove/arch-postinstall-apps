# Arch Postinstall Apps

Setup simples de apps para Arch Linux.

## About

Um script so para bootstrap e pos-instalacao no Arch.

## Instalacao rapida

```bash
command -v curl >/dev/null 2>&1 || sudo pacman -Syu --needed --noconfirm curl
curl -fsSL https://raw.githubusercontent.com/obslove/arch-postinstall-apps/main/install.sh | bash
```

Quando rodado fora do repo, ele instala `git`, clona/atualiza `~/Repositories/arch-postinstall-apps` e continua dali.
Rode como usuario normal, nao com `sudo bash`.

## O que acontece

- instala `curl` se faltar
- grava log em `~/Backups/arch-postinstall.log`
- verifica conectividade antes das etapas que dependem de rede
- instala `git`
- clona ou atualiza `~/Repositories/arch-postinstall-apps`
- preserva a branch escolhida entre bootstrap e segunda etapa
- cria `~/Backups`, `~/Dots`, `~/Pictures/Wallpapers`, `~/Pictures/Screenshots`, `~/Videos` e `~/Codex`
- instala `reflector`
- habilita `multilib` se precisar
- restaura a mirrorlist anterior se o `reflector` falhar
- instala os pacotes via `pacman` primeiro
- instala `yay` se precisar
- instala o restante via AUR
- repete automaticamente etapas de rede mais frageis se alguma falhar de primeira
- limpa arquivos temporarios mesmo se o script abortar
- instala `nodejs` e `npm` via `pacman`
- roda `npm config set prefix "$HOME/Codex"`
- instala `@openai/codex` no prefix `~/Codex`
- adiciona `~/Codex/bin` ao `PATH` no `.bashrc`
- instala `github-cli` e `openssh`
- cria a chave SSH se nao existir
- autentica no GitHub com `gh` no Zen Browser, se ele estiver instalado
- apaga as chaves SSH atuais do GitHub
- envia a chave SSH nova para o GitHub
- mantem a chave nova antes de remover as antigas
- pula a parte do GitHub se a autenticacao falhar
- pode abrir ChatGPT, tres abas do GitHub e YouTube no Zen Browser, se voce habilitar
- verifica no fim se os binarios principais realmente ficaram disponiveis

## O que vai pedir interacao

- senha do `sudo`
- login no GitHub via `gh auth login`, no final, abrindo no Zen Browser se ele estiver instalado
- eventualmente algum prompt raro de pacote do AUR

## Opcionais

- `REPLACE_GITHUB_SSH_KEYS=0`: preserva as chaves SSH atuais do GitHub
- `OPEN_ZEN_TABS=1`: abre ChatGPT, GitHub e YouTube no Zen Browser no fim

Se quiser usar essas opcoes no bootstrap, exporte antes:

```bash
export REPLACE_GITHUB_SSH_KEYS=1
export OPEN_ZEN_TABS=1
```

## Uso local

```bash
bash install.sh
```

## Pacotes

- `code`
- `discord`
- `git`
- `nodejs`
- `npm`
- `google-chrome` (AUR)
- `spotify-launcher`
- `steam`
- `zen-browser-bin` (AUR)

Edite `config/packages.txt` para mudar a lista.

Se nao houver helper AUR instalado, o script instala `yay`. Se ja existir `paru` ou `yay`, ele reutiliza o helper encontrado.
O script instala `reflector` e atualiza a mirrorlist antes do `pacman -Syu`.

## Estrutura

```text
config/packages.txt
install.sh
```
