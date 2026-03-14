# Arch Postinstall Apps

Setup simples de apps para Arch Linux.

## About

Um script para pós-instalação no Arch Linux.

## Instalação rápida

Se voce usa `bash`, rode:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/obslove/arch-postinstall-apps/main/install.sh)
```

Se voce usa `fish`, rode:

```fish
curl -fsSL https://raw.githubusercontent.com/obslove/arch-postinstall-apps/main/install.sh | bash
```



Quando rodado fora do repo, ele instala `git`, clona/atualiza `~/Repositories/arch-postinstall-apps` e continua dali.
Esse comando assume `curl` presente na instalacao padrao do Arch.
Rode como usuario normal, nao com `sudo bash`.



## O que acontece

- grava log em `~/Backups/arch-postinstall.log`
- grava resumo curto em `~/Backups/arch-postinstall-summary.txt`
- grava `Hostname` no resumo final
- instala `git`
- clona ou atualiza `~/Repositories/arch-postinstall-apps`
- preserva a branch escolhida entre bootstrap e segunda etapa
- cria `~/Backups`, `~/Dots`, `~/Pictures/Wallpapers`, `~/Pictures/Screenshots`, `~/Videos`, `~/Projects` e `~/Codex`
- instala `reflector`
- habilita `multilib` se precisar
- restaura a mirrorlist anterior se o `reflector` falhar
- marca checkpoint para não atualizar mirrors de novo em reruns
- instala os pacotes via `pacman` primeiro
- instala `yay` se precisar
- informa quando não houver pacotes AUR na lista
- instala o restante via AUR
- repete automaticamente etapas frágeis se alguma falhar de primeira
- limpa arquivos temporários mesmo se o script abortar
- evita duas execuções ao mesmo tempo com lockfile
- instala `nodejs` e `npm` via `pacman`
- roda `npm config set prefix "$HOME/Codex"`
- instala `@openai/codex` no prefix `~/Codex`
- adiciona `~/Codex/bin` ao `PATH` no `.bashrc`
- marca checkpoint para não repetir a configuração do Codex CLI em reruns
- instala `github-cli` e `openssh`
- cria a chave SSH se não existir
- autentica no GitHub com `gh`, abrindo o navegador padrão
- copia automaticamente o código do device flow para a área de transferencia
- renova o scope `admin:public_key` se precisar para gerenciar chaves SSH
- envia a chave SSH para o GitHub com título fixo `abslove`
- mantem a chave atual antes de remover as antigas, se `REPLACE_GITHUB_SSH_KEYS=1`
- pula a parte do GitHub se a autenticação falhar
- marca checkpoint para não repetir a configuração SSH do GitHub em reruns
- pode abrir ChatGPT, três abas do GitHub e YouTube no Zen Browser, se voce habilitar
- marca checkpoint para não reabrir as abas do Zen em reruns
- verifica no fim se os binarios principais realmente ficaram disponíveis
- grava no resumo a branch usada, o caminho do repo e versões principais

## O que vai pedir interação

- senha do `sudo`
- login no GitHub via `gh auth login`, no final, abrindo no navegador padrão
- autorização extra do `gh auth refresh` se faltar o scope `admin:public_key`
- eventualmente algum prompt raro de pacote do AUR

## Opcionais

- `REPLACE_GITHUB_SSH_KEYS=0`: preserva as chaves SSH atuais do GitHub
- `OPEN_ZEN_TABS=1`: abre ChatGPT, GitHub e YouTube no Zen Browser no fim

Se quiser usar essas opções no bootstrap, exporte antes:

```bash
export REPLACE_GITHUB_SSH_KEYS=1
export OPEN_ZEN_TABS=1
```

## Uso local

```bash
bash install.sh
```

## Validação local

```bash
bash -n install.sh
shellcheck install.sh
```

## Pacotes

- `code`
- `discord`
- `git`
- `nodejs`
- `npm`
- `shellcheck`
- `google-chrome` (AUR)
- `spotify-launcher`
- `steam`
- `zen-browser-bin` (AUR)

Edite `config/packages.txt` para mudar a lista.
Se existir `config/packages-extra.txt`, ele tambem será carregado.
Se ele nao existir, o script registra isso no log e segue normalmente.

Se não houver helper AUR instalado, o script instala `yay`. Se já existir `paru` ou `yay`, ele reutiliza o helper encontrado.
O script instala `reflector` e atualiza a mirrorlist antes do `pacman -Syu`.

## Estrutura

```text
config/packages-extra.txt.example
config/packages.txt
install.sh
```
