# Arch Postinstall Apps

Script de bootstrap e pós-instalação para Arch Linux.

## Sobre

Um único script para preparar o ambiente inicial e a pós-instalação no Arch Linux.

## Instalação rápida

`fish`

```fish
curl -fsSL https://raw.githubusercontent.com/obslove/arch-postinstall-apps/main/install.sh | bash
```

`bash`

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/obslove/arch-postinstall-apps/main/install.sh)
```

`zsh`

```zsh
bash <(curl -fsSL https://raw.githubusercontent.com/obslove/arch-postinstall-apps/main/install.sh)
```

Quando executado fora do repositório, o script instala `git`, clona ou atualiza `~/Repositories/arch-postinstall-apps` e continua a execução a partir desse diretório.
Quando executado dentro de um clone local, ele usa o repositório atual e não força a migração para `~/Repositories/arch-postinstall-apps`.
Esse comando pressupõe que `curl` esteja disponível na instalação padrão do Arch.
Execute-o como usuário comum, e não com `sudo bash`.

## Pacotes

- `zen-browser-bin` (AUR)
- `google-chrome` (AUR)
- `git`
- `shellcheck`
- `nodejs`
- `npm`
- `codex` (configuração especial)
- `code`
- `discord`
- `spotify-launcher`
- `steam`

Edite `config/packages.txt` para alterar a lista principal.
Se existir `config/packages-extra.txt`, esse arquivo também será carregado.
Se ele não existir, o script registrará essa ausência no log e continuará normalmente.

O instalador respeita a ordem definida em `config/packages.txt`.
Os repositórios usados pelo script ficam em `~/Repositories`.
Se não houver helper AUR instalado, o script instalará `yay` antes do primeiro pacote AUR.
Se `paru` ou `yay` já existirem, o helper encontrado será reutilizado.
O item `codex` não é um pacote do sistema: ele executa uma configuração especial do Codex CLI.
O script instala `reflector` e atualiza a lista de mirrors antes de `pacman -Syu`, usando `10s` como tempo limite padrão para conexão e download.
O checkpoint de mirrors expira, por padrão, após `7` dias, para evitar que a lista fique desatualizada por tempo indeterminado.
Em sessões Hyprland, o script também garante `pipewire`, `wireplumber`, `xdg-utils`, `xdg-desktop-portal`, `xdg-desktop-portal-gtk` e `xdg-desktop-portal-hyprland`.

## O que acontece

- Evita duas execuções simultâneas por meio de um arquivo de bloqueio.
- Recupera automaticamente um lock órfão quando a execução anterior termina sem limpeza adequada.
- Grava o log em `~/Backups/arch-postinstall.log`.
- Exibe, por padrão, um modo resumido por etapas no terminal.
- Mantém os detalhes completos no arquivo de log.
- Instala `git`.
- Clona ou atualiza `~/Repositories/arch-postinstall-apps` quando executado fora do repositório.
- Mantém clones auxiliares, como `yay`, dentro de `~/Repositories`.
- Preserva a branch escolhida entre o bootstrap e a segunda etapa.
- Usa o clone atual normalmente quando você executa `bash install.sh` dentro de um repositório já existente.
- Interrompe o bootstrap se o clone gerenciado estiver com alterações locais em outra branch, em vez de executar código da branch incorreta.
- Cria `~/Backups`, `~/Codex`, `~/Dots`, `~/Pictures/Wallpapers`, `~/Pictures/Screenshots`, `~/Projects`, `~/Repositories` e `~/Videos`.
- Carrega `config/packages.txt` e, se existir, `config/packages-extra.txt`.
- Habilita `multilib`, se necessário.
- Instala `reflector`.
- Aceita avisos e limites de tempo parciais do `reflector` se ele ainda gerar uma lista de mirrors válida.
- Restaura a lista de mirrors anterior se o `reflector` falhar sem gerar saída válida.
- Marca um checkpoint para evitar a atualização da lista de mirrors em reruns recentes.
- Atualiza a lista de mirrors novamente quando o checkpoint estiver antigo demais.
- Atualiza o sistema com `pacman -Syu`.
- Segue a ordem definida em `config/packages.txt`.
- Instala cada item com `pacman`, `yay` ou configuração especial, conforme o tipo.
- Instala `yay` automaticamente antes do primeiro pacote AUR, se necessário.
- Informa quando não houver pacotes AUR na lista.
- Repete automaticamente etapas mais frágeis quando a primeira tentativa falha.
- Configura o Codex CLI com prefixo em `~/Codex`.
- Adiciona `~/Codex/bin` ao `PATH` do `bash`, `zsh` e `fish`.
- Instala `github-cli` e `openssh`.
- Cria a chave SSH, se ela não existir.
- Tenta abrir automaticamente `https://github.com/login/device` no navegador padrão.
- Autentica no GitHub com `gh`, usando o fluxo web por código de dispositivo.
- Copia automaticamente o código do fluxo de autenticação para a área de transferência quando houver um utilitário compatível com a sessão atual.
- Instala `wl-clipboard` temporariamente em sessões Wayland ou `xclip` em sessões X11 quando faltar um utilitário de área de transferência compatível.
- Remove o utilitário temporário de área de transferência ao fim da etapa do GitHub, se ele tiver sido instalado pelo script.
- Renova o escopo `admin:public_key`, se necessário, para gerenciar chaves SSH.
- Envia a chave SSH ao GitHub com título derivado de `usuário@hostname`.
- Mantém a chave atual antes de remover as antigas, se `REPLACE_GITHUB_SSH_KEYS=1`.
- Ignora a etapa do GitHub se a autenticação falhar.
- Valida, em reruns, se a chave SSH atual ainda existe na conta do GitHub antes de confiar no checkpoint.
- Em sessões Hyprland, garante a pilha de integração desktop e compartilhamento de tela com `pipewire`, `wireplumber` e `xdg-desktop-portal`.
- Verifica, ao final, se os binários principais realmente ficaram disponíveis.
- Em Wayland, verifica a área de transferência, os pacotes de portal e serviços de usuário como `pipewire.service`, `wireplumber.service` e `xdg-desktop-portal.service`.
- Grava o resumo em `~/Backups/arch-postinstall-summary.txt`.
- Registra `Hostname` no resumo final.
- Registra, no resumo, a branch realmente em uso, o caminho do repositório e as versões principais.
- Registra também a branch solicitada, se ela for diferente da branch em uso.
- Inclui no resumo o clone gerenciado separado, quando a execução tiver acontecido fora dele.
- Remove arquivos temporários mesmo se o script for interrompido.

## O que exige interação

- Senha do `sudo`.
- Login no GitHub via `gh auth login`, com o navegador padrão abrindo a página do fluxo por código de dispositivo.
- Autorização adicional do `gh auth refresh`, se faltar o escopo `admin:public_key`.
- Eventualmente, algum prompt raro de pacote AUR.

## Opcionais

- `REPLACE_GITHUB_SSH_KEYS=0`: preserva as chaves SSH atuais do GitHub.
- `REFLECTOR_CONNECTION_TIMEOUT=10`: ajusta o tempo limite de conexão do `reflector`.
- `REFLECTOR_DOWNLOAD_TIMEOUT=10`: ajusta o tempo limite de download do `reflector`.
- `MIRROR_CHECKPOINT_MAX_AGE_DAYS=7`: define, em dias, quando o checkpoint de mirrors expira.
- `STEP_OUTPUT_ONLY=0`: desativa o modo resumido e restaura a saída completa no terminal.

Se quiser usar essas opções no bootstrap, exporte-as antes da execução:

`fish`

```fish
set -x REPLACE_GITHUB_SSH_KEYS 1
```

`bash`

```bash
export REPLACE_GITHUB_SSH_KEYS=1
```

`zsh`

```zsh
export REPLACE_GITHUB_SSH_KEYS=1
```

## Uso local

`fish`

```fish
bash install.sh
```

`bash`

```bash
bash install.sh
```

`zsh`

```zsh
bash install.sh
```

## Validação local

`fish`

```fish
bash -n install.sh
shellcheck install.sh
```

`bash`

```bash
bash -n install.sh
shellcheck install.sh
```

`zsh`

```zsh
bash -n install.sh
shellcheck install.sh
```

## Estrutura

```text
config/packages-extra.txt.example
config/packages.txt
install.sh
```
