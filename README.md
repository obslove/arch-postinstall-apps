# Arch Postinstall Apps

Script simples para reinstalacao no Arch Linux.

## About

Instala seus apps no Arch, priorizando `pacman` e usando AUR so quando precisar.

## Instalacao rapida

Com `curl`:

```bash
curl -fsSL https://raw.githubusercontent.com/obslove/arch-postinstall-apps/main/bootstrap.sh | bash
```

Com `wget`:

```bash
wget -qO- https://raw.githubusercontent.com/obslove/arch-postinstall-apps/main/bootstrap.sh | bash
```

## Uso

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

Edite `packages.txt` para mudar a lista.

## Estrutura

```text
bootstrap.sh
install.sh
bin/postinstall-apps
packages.txt
```
