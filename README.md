# Arch Postinstall Apps

Setup simples de apps para Arch Linux.

## About

Um script so para bootstrap e pos-instalacao no Arch.

## Instalacao rapida

```bash
command -v curl >/dev/null 2>&1 || sudo pacman -Syu --needed --noconfirm curl
curl -fsSL https://raw.githubusercontent.com/obslove/arch-postinstall-apps/main/install.sh | bash
```

Quando rodado fora do repo, ele instala `git` e `openssh`, cria a chave SSH, clona/atualiza `~/Repositories/arch-postinstall-apps` e continua dali.

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
