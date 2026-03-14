# Arch Postinstall Apps

Script simples de pos-instalacao para Arch Linux.

Ele:

- habilita `multilib` se precisar
- tenta instalar os apps via `pacman` primeiro
- instala via AUR so o que nao existir no repositorio oficial
- usa `paru` se ja existir, senao `yay`

## Pacotes

- `code`
- `discord`
- `git`
- `google-chrome`
- `spotify-launcher`
- `steam`
- `zen-browser-bin`

## Uso

```bash
bash arch-postinstall-apps.sh
```

Se quiser deixar mais facil no seu usuario:

```bash
alias postinstall-apps='bash "$HOME/arch-postinstall-apps.sh"'
```

## Editar a lista

Edite o array `packages` no topo do arquivo `arch-postinstall-apps.sh`.

## Subir para o GitHub

```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/SEU_USUARIO/arch-postinstall-apps.git
git push -u origin main
```
