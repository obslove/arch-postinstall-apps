# Arch Postinstall Apps

Script simples para reinstalacao no Arch Linux.

## About

Instala seus apps no Arch, priorizando `pacman` e usando AUR so quando precisar.

## Instalacao rapida

```bash
bash -c 'if command -v curl >/dev/null 2>&1; then curl -fsSL https://raw.githubusercontent.com/obslove/arch-postinstall-apps/main/bootstrap.sh; elif command -v wget >/dev/null 2>&1; then wget -qO- https://raw.githubusercontent.com/obslove/arch-postinstall-apps/main/bootstrap.sh; else echo "Erro: instale curl ou wget." >&2; exit 1; fi' | bash
```

Outra branch:

```bash
bash -c 'if command -v curl >/dev/null 2>&1; then curl -fsSL https://raw.githubusercontent.com/obslove/arch-postinstall-apps/main/bootstrap.sh; elif command -v wget >/dev/null 2>&1; then wget -qO- https://raw.githubusercontent.com/obslove/arch-postinstall-apps/main/bootstrap.sh; else echo "Erro: instale curl ou wget." >&2; exit 1; fi' | bash -s -- sua-branch
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

Se `reflector` estiver instalado, o script atualiza a mirrorlist antes do `pacman -Syu`.

## Estrutura

```text
bootstrap.sh
install.sh
bin/postinstall-apps
packages.txt
```
