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

### Dependências técnicas instaladas explicitamente

- `git`
  Necessário para bootstrap, sincronização do repositório e operações Git do script.
- `shellcheck`
  Ferramenta instalada como parte da lista principal.
- `nodejs`
  Necessário para o ambiente do npm e para o Codex CLI.
- `npm`
  Necessário para configurar o prefixo local e instalar `@openai/codex`.
- `base-devel`
  Necessário para compilar e instalar o `yay`.
- `yay`
  Helper AUR preparado por padrão e usado preferencialmente pelo script.
- `github-cli`
  Necessário para autenticação no GitHub e gerenciamento da chave SSH.
- `openssh`
  Necessário para `ssh-keygen` e autenticação SSH com o GitHub.

### Apps e programas da lista principal

- `zen-browser-bin` (AUR)
- `google-chrome` (AUR)
- `code`
- `discord`
- `spotify-launcher`
- `steam`
- `codex`
  Item especial da lista: não instala um pacote do sistema, e sim o `@openai/codex` via npm em `~/Codex`.

### Dependências condicionais

- `pipewire`
  Garantido em sessões Hyprland para áudio e compartilhamento de tela.
- `wireplumber`
  Garantido em sessões Hyprland como gerenciador de sessão do PipeWire.
- `xdg-utils`
  Garantido em sessões Hyprland para integração desktop básica.
- `xdg-desktop-portal`
  Garantido em sessões Hyprland para a pilha de portais desktop.
- `xdg-desktop-portal-gtk`
  Garantido em sessões Hyprland como backend complementar de portal.
- `xdg-desktop-portal-hyprland`
  Garantido em sessões Hyprland como backend principal de portal.
- Pacotes de `config/packages-extra.txt`
  Instalados somente se esse arquivo existir.

### Dependência temporária

- `wl-clipboard`
  Instalado temporariamente em sessões Wayland quando o fluxo do `gh` precisa copiar o código de autenticação para a área de transferência.

Edite `config/packages.txt` para alterar a lista principal.
Se existir `config/packages-extra.txt`, esse arquivo também será carregado.
Se ele não existir, o script registrará essa ausência no log e continuará normalmente.

O instalador respeita a ordem definida em `config/packages.txt`.
Os repositórios usados pelo script ficam em `~/Repositories`.
O script instala `yay` por padrão e o usa como helper AUR principal.
Se a instalação do `yay` falhar, mas já houver outro helper AUR disponível, o script usará esse helper como fallback.
O item `codex` não é um pacote do sistema: ele executa uma configuração especial do Codex CLI.
Em sessões Hyprland, o script também garante `pipewire`, `wireplumber`, `xdg-utils`, `xdg-desktop-portal`, `xdg-desktop-portal-gtk` e `xdg-desktop-portal-hyprland`.

## O que acontece

### Ordem geral

1. O script valida o ambiente, exige `sudo`, cria o arquivo de bloqueio e inicia o log em `~/Backups/arch-postinstall.log`.
2. Se for executado fora do repositório, instala `git`, clona ou atualiza `~/Repositories/arch-postinstall-apps` e reinicia a execução a partir desse clone.
3. Se for executado dentro de um clone local, usa o repositório atual normalmente.
4. Cria `~/Backups`, `~/Codex`, `~/Dots`, `~/Pictures/Wallpapers`, `~/Pictures/Screenshots`, `~/Projects`, `~/Repositories` e `~/Videos`.
5. Carrega `config/packages.txt` e, se existir, `config/packages-extra.txt`.
6. Habilita `multilib`, se necessário.
7. Atualiza o sistema com `pacman -Syu`.
8. Prepara o `yay` por padrão.
9. Instala os itens da lista principal na ordem definida em `config/packages.txt`, usando `pacman`, `yay` ou configuração especial.
10. Ajusta a integração desktop do Hyprland quando a sessão atual for Hyprland.
11. Configura GitHub SSH.
12. Valida a instalação, grava o resumo final em `~/Backups/arch-postinstall-summary.txt` e remove arquivos temporários.

### Detalhes do bootstrap

- Evita duas execuções simultâneas por meio de um arquivo de bloqueio.
- Recupera automaticamente um lock órfão quando a execução anterior termina sem limpeza adequada.
- Exibe, por padrão, um modo resumido por etapas no terminal e mantém os detalhes completos no arquivo de log.
- Mantém clones auxiliares, como `yay`, dentro de `~/Repositories`.
- Preserva a branch escolhida entre o bootstrap e a segunda etapa.
- Interrompe o bootstrap se o clone gerenciado estiver com alterações locais em outra branch, em vez de executar código da branch incorreta.

### Detalhes da instalação

- Usa `yay` como helper AUR preferencial.
- Configura o Codex CLI com prefixo em `~/Codex`.
- Adiciona `~/Codex/bin` ao `PATH` do `bash`, `zsh` e `fish`.
- Instala `github-cli` e `openssh`.
- Cria a chave SSH, se ela não existir.
- Autentica no GitHub com `gh`, usando o fluxo web por código de dispositivo.
- Copia automaticamente o código do fluxo de autenticação para a área de transferência quando houver um utilitário compatível com a sessão atual.
- Instala `wl-clipboard` temporariamente em sessões Wayland quando faltar um utilitário de área de transferência compatível.
- Remove o utilitário temporário de área de transferência ao fim da etapa do GitHub, se ele tiver sido instalado pelo script.
- Renova o escopo `admin:public_key`, se necessário, para gerenciar chaves SSH.
- Envia a chave SSH ao GitHub com o título definido em `GITHUB_SSH_KEY_TITLE`.
- Usa o login atual do GitHub como título padrão quando essa variável não for definida.
- Se o login atual do GitHub não puder ser obtido, usa o nome do usuário local como fallback.
- Recria a chave atual no GitHub se ela já existir com outro título.
- Confirma, ao fim da etapa, se a chave atual realmente ficou registrada com o título esperado.
- Mantém a chave atual antes de remover as antigas, se `REPLACE_GITHUB_SSH_KEYS=1`.
- Ignora a etapa do GitHub se a autenticação falhar.
- Valida, em reruns, se a chave SSH atual ainda existe na conta do GitHub antes de confiar no checkpoint.
- Em sessões Hyprland, garante a pilha de integração desktop e compartilhamento de tela com `pipewire`, `wireplumber` e `xdg-desktop-portal`.
- Verifica, ao final, se os binários principais realmente ficaram disponíveis.
- Em Wayland, verifica a área de transferência, os pacotes de portal e serviços de usuário como `pipewire.service`, `wireplumber.service` e `xdg-desktop-portal.service`.
- Registra `Hostname` no resumo final.
- Registra, no resumo, a branch realmente em uso, o caminho do repositório e as versões principais.
- Registra também a branch solicitada, se ela for diferente da branch em uso.
- Inclui no resumo o clone gerenciado separado, quando a execução tiver acontecido fora dele.

## O que exige interação

- Senha do `sudo`.
- Login no GitHub via `gh auth login`, com o navegador padrão abrindo a página do fluxo por código de dispositivo.
- Autorização adicional do `gh auth refresh`, se faltar o escopo `admin:public_key`.
- Eventualmente, algum prompt raro de pacote AUR.

## Opcionais

- `REPLACE_GITHUB_SSH_KEYS=0`: preserva as chaves SSH atuais do GitHub.
- `GITHUB_SSH_KEY_TITLE="meu-dispositivo"`: define o título da chave SSH enviada ao GitHub.
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
