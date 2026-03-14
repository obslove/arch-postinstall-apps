# Arch Postinstall Apps

Script simples para reinstalacao no Arch Linux.

## About

Instala seus apps no Arch, priorizando `pacman` e usando AUR so quando precisar, clonando o repo localmente e criando uma chave SSH.

## Instalacao rapida

Se tiver `curl`:

```bash
curl -fsSL https://raw.githubusercontent.com/obslove/arch-postinstall-apps/main/bootstrap.sh | bash
```

Se tiver `wget`:

```bash
wget -qO- https://raw.githubusercontent.com/obslove/arch-postinstall-apps/main/bootstrap.sh | bash
```

Outra branch:

```bash
curl -fsSL https://raw.githubusercontent.com/obslove/arch-postinstall-apps/main/bootstrap.sh | bash -s -- sua-branch
```

## Uso

```bash
bash install.sh
``` 

O bootstrap clona o repo em `~/arch-postinstall-apps` e cria `~/.ssh/id_ed25519` se ela nao existir.
Se nao houver helper AUR instalado, o script instala `yay` automaticamente. Se ja existir `paru` ou `yay`, ele reutiliza o helper encontrado.

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
