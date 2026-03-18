# Arch Postinstall Apps

Script de bootstrap e pós-instalação para Arch Linux.

## Sobre

Um único script para preparar o ambiente inicial e a pós-instalação no Arch Linux.

## Instalação rápida

`fish`

```fish
curl -fsSL https://obslove.dev | bash
```

`bash`

```bash
bash <(curl -fsSL https://obslove.dev)
```

`zsh`

```zsh
bash <(curl -fsSL https://obslove.dev)
```

Quando executado fora do repositório, o script instala `git`, clona ou atualiza `~/Repositories/arch-postinstall-apps` e continua a execução a partir desse diretório.
Quando executado dentro de um clone local, ele usa o repositório atual e não força a migração para `~/Repositories/arch-postinstall-apps`.
Esse comando pressupõe que `curl` esteja disponível na instalação padrão do Arch.
Execute-o como usuário comum, e não com `sudo bash`.
O fluxo atual do script foi ajustado para uso em Wayland com Hyprland.
Se a sessão atual não estiver nesse alvo, o script interromperá a execução com erro claro.

## Pacotes

<details>
<summary>Dependências garantidas pelo script</summary>

- `git`
  Necessário para bootstrap, sincronização do repositório e operações Git do script.
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
</details>

<details>
<summary>Apps e programas da lista principal</summary>

- `shellcheck`
  Ferramenta de validação incluída na lista principal padrão.
- `zen-browser-bin` (AUR)
- `google-chrome` (AUR)
- `code`
- `discord`
- `spotify-launcher`
- `steam`
- `codex`
  Item especial da lista: não instala um pacote do sistema, e sim o `@openai/codex` via npm em `~/Codex`.
</details>

<details>
<summary>Dependências do ambiente gráfico</summary>

- `pipewire`
  Necessário para áudio e compartilhamento de tela.
- `wireplumber`
  Necessário como gerenciador de sessão do PipeWire.
- `xdg-utils`
  Necessário para integração desktop básica.
- `xdg-desktop-portal`
  Necessário para a pilha de portais desktop.
- `xdg-desktop-portal-gtk`
  Necessário como backend complementar de portal.
- `xdg-desktop-portal-hyprland`
  Necessário como backend principal de portal.
</details>

<details>
<summary>Pacotes opcionais da lista extra</summary>

- Pacotes de `config/packages-extra.txt`
  Instalados somente se esse arquivo existir.
</details>

<details>
<summary>Dependência temporária</summary>

- `wl-clipboard`
  Instalado temporariamente quando o fluxo do `gh` precisa copiar o código de autenticação para a área de transferência.
</details>

Edite `config/packages.txt` para alterar a lista principal.
Se existir `config/packages-extra.txt`, esse arquivo também será carregado.
Se ele não existir, o script registrará essa ausência no log e continuará normalmente.

O instalador respeita a ordem definida em `config/packages.txt`.
Os repositórios usados pelo script ficam em `~/Repositories`.
O script instala `yay` por padrão e o usa como helper AUR principal.
Se a instalação do `yay` falhar, mas já houver outro helper AUR disponível, o script usará esse helper como fallback.
O item `codex` não é um pacote do sistema: ele executa uma configuração especial do Codex CLI.
O script também garante `pipewire`, `wireplumber`, `xdg-utils`, `xdg-desktop-portal`, `xdg-desktop-portal-gtk` e `xdg-desktop-portal-hyprland`.

## O que acontece

<details>
<summary>Ordem geral</summary>

1. O script valida o ambiente, exige `sudo`, cria o arquivo de bloqueio e inicia o log em `~/Backups/arch-postinstall.log`.
2. Se for executado fora do repositório, instala `git`, clona ou atualiza `~/Repositories/arch-postinstall-apps` e reinicia a execução a partir desse clone.
3. Se for executado dentro de um clone local, usa o repositório atual normalmente.
4. Carrega `config/packages.txt` e, se existir, `config/packages-extra.txt`.
5. Cria `~/Backups`, `~/Codex`, `~/Dots`, `~/Pictures/Wallpapers`, `~/Pictures/Screenshots`, `~/Projects`, `~/Repositories` e `~/Videos`.
6. Habilita `multilib`, se necessário.
7. Atualiza o sistema com `pacman -Syu`.
8. Prepara o `yay` por padrão.
9. Instala os itens da lista principal na ordem definida em `config/packages.txt`, usando `pacman`, `yay` ou configuração especial.
10. Garante a integração desktop do ambiente.
11. Configura GitHub SSH.
12. Valida a instalação com base na lista real de pacotes carregada, tenta uma correção automática única para itens ausentes, grava o resumo final em `~/Backups/arch-postinstall-summary.txt` e interrompe a execução com erro se ainda houver pendências.
</details>

<details>
<summary>Detalhes do bootstrap</summary>

- Evita duas execuções simultâneas por meio de um arquivo de bloqueio.
- Recupera automaticamente um lock órfão quando a execução anterior termina sem limpeza adequada.
- Exibe, por padrão, um modo resumido por etapas no terminal e mantém os detalhes completos no arquivo de log.
- Verifica `ca-certificates`, `git`, `curl` e `tar` antes de tentar instalá-los no bootstrap.
- Mantém clones auxiliares, como `yay`, dentro de `~/Repositories`.
- Preserva a branch escolhida entre o bootstrap e a segunda etapa.
- Interrompe o bootstrap se o clone gerenciado estiver com alterações locais em outra branch, em vez de executar código da branch incorreta.
</details>

<details>
<summary>Detalhes da instalação</summary>

- Usa `yay` como helper AUR preferencial.
- Configura o Codex CLI com prefixo em `~/Codex`.
- Adiciona `~/Codex/bin` ao `PATH` do `bash`, `zsh` e `fish`.
- Instala `github-cli` e `openssh`.
- Cria a chave SSH, se ela não existir.
- Autentica no GitHub com `gh`, usando o fluxo web por código de dispositivo.
- Copia automaticamente o código do fluxo de autenticação para a área de transferência quando houver um utilitário compatível.
- Instala `wl-clipboard` temporariamente quando faltar um utilitário de área de transferência compatível.
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
- Garante a pilha de integração desktop e compartilhamento de tela com `pipewire`, `wireplumber` e `xdg-desktop-portal`.
- Marca um checkpoint para a integração desktop e reaproveita a etapa quando a base já estiver pronta.
- Interrompe a execução se a integração desktop não puder ser preparada.
- Verifica, ao final, se os itens esperados pela lista carregada e pelas dependências do fluxo realmente ficaram disponíveis.
- Verifica a área de transferência, os pacotes de portal e serviços de usuário como `pipewire.service`, `wireplumber.service` e `xdg-desktop-portal.service`.
- Tenta uma correção automática única para os itens ausentes antes de encerrar com erro.
- Registra `Hostname` no resumo final.
- Separa no resumo o que o script tratou explicitamente do que foi apenas verificado.
- Registra, no resumo, a branch realmente em uso, o caminho do repositório e as versões principais.
- Registra também a branch solicitada, se ela for diferente da branch em uso.
- Inclui no resumo o clone gerenciado separado, quando a execução tiver acontecido fora dele.
- Registra, no resumo, o estado da etapa de GitHub SSH e do remoto `origin`.
- Indica, no resumo, se a etapa de GitHub SSH era esperada naquela execução.
</details>

## O que exige interação

- Senha do `sudo`.
- Login no GitHub via `gh auth login`, com o navegador padrão abrindo a página do fluxo por código de dispositivo.
- Autorização adicional do `gh auth refresh`, se faltar o escopo `admin:public_key`.
- Eventualmente, algum prompt raro de pacote AUR.

## Opcionais

<details>
<summary><code>REPLACE_GITHUB_SSH_KEYS=0</code>: preserva as chaves SSH atuais do GitHub</summary>

`fish`

  ```fish
  set -x REPLACE_GITHUB_SSH_KEYS 0
  curl -fsSL https://obslove.dev | bash
  ```

  `bash`

  ```bash
  REPLACE_GITHUB_SSH_KEYS=0 bash <(curl -fsSL https://obslove.dev)
  ```

  `zsh`

  ```zsh
  REPLACE_GITHUB_SSH_KEYS=0 bash <(curl -fsSL https://obslove.dev)
  ```
</details>

<details>
<summary><code>GITHUB_SSH_KEY_TITLE="meu-dispositivo"</code>: define o título da chave SSH enviada ao GitHub</summary>

`fish`

  ```fish
  set -x GITHUB_SSH_KEY_TITLE "meu-dispositivo"
  curl -fsSL https://obslove.dev | bash
  ```

  `bash`

  ```bash
  GITHUB_SSH_KEY_TITLE="meu-dispositivo" bash <(curl -fsSL https://obslove.dev)
  ```

  `zsh`

  ```zsh
  GITHUB_SSH_KEY_TITLE="meu-dispositivo" bash <(curl -fsSL https://obslove.dev)
  ```
</details>

<details>
<summary><code>CHECK_ONLY=1</code>: valida o ambiente e gera o resumo sem instalar pacotes nem alterar a configuração do sistema</summary>

O resumo final registra explicitamente `Modo: verificação` e `Alterações aplicadas: não`.

`fish`

  ```fish
  set -x CHECK_ONLY 1
  curl -fsSL https://obslove.dev | bash
  ```

  `bash`

  ```bash
  CHECK_ONLY=1 bash <(curl -fsSL https://obslove.dev)
  ```

  `zsh`

  ```zsh
  CHECK_ONLY=1 bash <(curl -fsSL https://obslove.dev)
  ```
</details>

<details>
<summary><code>STEP_OUTPUT_ONLY=0</code>: desativa o modo resumido e restaura a saída completa no terminal</summary>

`fish`

  ```fish
  set -x STEP_OUTPUT_ONLY 0
  curl -fsSL https://obslove.dev | bash
  ```

  `bash`

  ```bash
  STEP_OUTPUT_ONLY=0 bash <(curl -fsSL https://obslove.dev)
  ```

  `zsh`

  ```zsh
  STEP_OUTPUT_ONLY=0 bash <(curl -fsSL https://obslove.dev)
  ```
</details>

<details>
<summary><code>SKIP_GITHUB_SSH=1</code>: pula a etapa de GitHub SSH e registra isso no resumo final</summary>

`fish`

  ```fish
  set -x SKIP_GITHUB_SSH 1
  curl -fsSL https://obslove.dev | bash
  ```

  `bash`

  ```bash
  SKIP_GITHUB_SSH=1 bash <(curl -fsSL https://obslove.dev)
  ```

  `zsh`

  ```zsh
  SKIP_GITHUB_SSH=1 bash <(curl -fsSL https://obslove.dev)
  ```
</details>

<details>
<summary><code>SKIP_DESKTOP_INTEGRATION=1</code>: pula a etapa de integração desktop e registra isso no resumo final</summary>

`fish`

  ```fish
  set -x SKIP_DESKTOP_INTEGRATION 1
  curl -fsSL https://obslove.dev | bash
  ```

  `bash`

  ```bash
  SKIP_DESKTOP_INTEGRATION=1 bash <(curl -fsSL https://obslove.dev)
  ```

  `zsh`

  ```zsh
  SKIP_DESKTOP_INTEGRATION=1 bash <(curl -fsSL https://obslove.dev)
  ```
</details>

## Uso local

<details>
<summary>Comandos para executar o script em um clone local</summary>

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

</details>

## Validação local

<details>
<summary>Comandos para validação estática local</summary>

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

</details>

## Estrutura

<details>
<summary>Arquivos principais do repositório</summary>

```text
config/packages-extra.txt.example
config/packages.txt
install.sh
```

</details>
