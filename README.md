# Arch Postinstall Apps

Setup simples de apps para Arch Linux.

## About

Instala seus apps no Arch com `pacman` primeiro e AUR depois.

## Instalacao rapida

Se tiver `curl`:

```bash
curl -fsSL https://raw.githubusercontent.com/obslove/arch-postinstall-apps/main/scripts/bootstrap.sh | bash
```

Se tiver `wget`:

```bash
wget -qO- https://raw.githubusercontent.com/obslove/arch-postinstall-apps/main/scripts/bootstrap.sh | bash
```

Outra branch:

```bash
curl -fsSL https://raw.githubusercontent.com/obslove/arch-postinstall-apps/main/scripts/bootstrap.sh | bash -s -- sua-branch
```

O bootstrap clona o repo em `~/Repositories/arch-postinstall-apps`, cria `~/.ssh/id_ed25519` se ela nao existir e roda o instalador.

## Uso local

```bash
bash scripts/install.sh
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
scripts/bootstrap.sh
scripts/install.sh
scripts/postinstall-apps
```
