# Arch Postinstall Apps

Setup simples de apps para Arch Linux.

## About

Um script so para bootstrap e pos-instalacao no Arch.

## Instalacao rapida

```bash
command -v curl >/dev/null 2>&1 || sudo pacman -Syu --needed --noconfirm curl
curl -fsSL https://raw.githubusercontent.com/obslove/arch-postinstall-apps/main/install.sh | bash
```

Quando rodado fora do repo, ele instala `git`, `github-cli` e `openssh`, autentica com `gh`, cria a chave SSH, apaga as chaves SSH existentes no GitHub, envia a chave nova, clona/atualiza `~/Repositories/arch-postinstall-apps` e continua dali.

## O que acontece

- instala `curl` se faltar
- instala `git`, `github-cli` e `openssh`
- cria a chave SSH se nao existir
- autentica no GitHub com `gh`
- apaga as chaves SSH atuais do GitHub
- envia a chave SSH nova para o GitHub
- clona ou atualiza `~/Repositories/arch-postinstall-apps`
- cria `~/Backups`, `~/Dots`, `~/Pictures/Wallpapers`, `~/Pictures/Screenshots`, `~/Videos` e `~/Codex`
- habilita `multilib` se precisar
- instala os pacotes via `pacman` primeiro
- instala `yay` se precisar
- instala o restante via AUR

## O que vai pedir interacao

- senha do `sudo`
- login no GitHub via `gh auth login`
- eventualmente algum prompt raro de pacote do AUR

## Uso local

```bash
bash install.sh
```

## Pacotes

- `code`
- `discord`
- `git`
- `google-chrome` (AUR)
- `spotify-launcher`
- `steam`
- `zen-browser-bin` (AUR)

Edite `config/packages.txt` para mudar a lista.

Se nao houver helper AUR instalado, o script instala `yay`. Se ja existir `paru` ou `yay`, ele reutiliza o helper encontrado.
Se `reflector` estiver instalado, o script atualiza a mirrorlist antes do `pacman -Syu`.

## Estrutura

```text
config/packages.txt
install.sh
```
