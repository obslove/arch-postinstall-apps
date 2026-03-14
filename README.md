# Arch Postinstall Apps

Script simples para reinstalacao no Arch Linux.

## About

Instala seus apps no Arch, priorizando `pacman` e usando AUR so quando precisar.

## Instalacao rapida

```bash
URL="https://raw.githubusercontent.com/obslove/arch-postinstall-apps/main/bootstrap.sh"

if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$URL" | bash
elif command -v wget >/dev/null 2>&1; then
  wget -qO- "$URL" | bash
else
  echo "Erro: instale curl ou wget." >&2
fi
```

Outra branch:

```bash
URL="https://raw.githubusercontent.com/obslove/arch-postinstall-apps/main/bootstrap.sh"
BRANCH="sua-branch"

if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$URL" | bash -s -- "$BRANCH"
elif command -v wget >/dev/null 2>&1; then
  wget -qO- "$URL" | bash -s -- "$BRANCH"
else
  echo "Erro: instale curl ou wget." >&2
fi
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
