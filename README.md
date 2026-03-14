# Arch Postinstall Apps

Script simples para reinstalacao no Arch Linux.

## About

Instala seus apps no Arch, priorizando `pacman` e usando AUR so quando precisar.

## Instalacao rapida

```bash
curl -fsSL https://raw.githubusercontent.com/obslove/arch-postinstall-apps/main/bootstrap.sh | bash
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
