# Arch Postinstall Apps

Script simples de pos-instalacao para Arch Linux.

## Estrutura

```text
.
├── bin/
│   └── postinstall-apps
├── packages.txt
└── README.md
```

## O que ele faz

- habilita `multilib` se precisar
- instala o que existir via `pacman` primeiro
- manda para o AUR so o que nao existir no repo oficial
- usa `paru` se ja existir, senao instala `yay`

## Uso

```bash
bash bin/postinstall-apps
```

## Pacotes

A lista fica em `packages.txt`.

Pacotes atuais:

- `code`
- `discord`
- `git`
- `google-chrome`
- `spotify-launcher`
- `steam`
- `zen-browser-bin`

## Editar

Adicione ou remova linhas em `packages.txt`.
