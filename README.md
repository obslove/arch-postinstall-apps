# Arch Postinstall Apps

Script simples para reinstalacao no Arch Linux.

## About

Instala seus apps no Arch, priorizando `pacman` e usando AUR so quando precisar.

## Instalacao rapida

```bash
sudo pacman -Syu --needed git && git clone https://github.com/obslove/arch-postinstall-apps.git && cd arch-postinstall-apps && bash install.sh
```

## Uso

```bash
bash install.sh
``` 

## Pacotes

- `code`
- `discord`
- `git`
- `google-chrome`
- `spotify-launcher`
- `steam`
- `zen-browser-bin`

Edite `packages.txt` para mudar a lista.

## Estrutura

```text
install.sh
bin/postinstall-apps
packages.txt
```
