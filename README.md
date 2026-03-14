# Arch Postinstall Apps

Setup simples de apps para Arch Linux.

## About

Um script so para bootstrap e pos-instalacao no Arch.

## Instalacao rapida

```bash
sudo pacman -Syu --needed --noconfirm git github-cli openssh
gh auth login --web --git-protocol ssh
gh repo clone obslove/arch-postinstall-apps ~/Repositories/arch-postinstall-apps
bash ~/Repositories/arch-postinstall-apps/install.sh
```

Como o repo e privado, o fluxo oficial comeca com `gh auth login` e `gh repo clone`.
Depois disso, o `install.sh` cria e envia a chave SSH para o GitHub se precisar e segue com a instalacao.

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
