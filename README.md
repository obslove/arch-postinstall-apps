# Arch Postinstall Apps

Bootstrap e pós-instalação declarativa para Arch Linux, focada em Wayland com Hyprland.

O projeto mantém o fluxo remoto `curl -fsSL https://obslove.dev | bash`, sincroniza o clone gerenciado em `~/Projects/arch-postinstall-apps`, instala os apps por categoria, prepara o ambiente, garante clones auxiliares em `~/Projects`, `~/Dots` e `~/EasyEffects-Preset`, e fecha a máquina com integração desktop, Codex CLI e GitHub SSH.

> [!NOTE]
> O bootstrap publicado em `https://obslove.dev` é tratado como parte do repositório e é verificado automaticamente contra `main/dist/install.sh`.

## Instalação rápida

Execute como usuário comum. Não use `sudo bash`.

Fluxo padrão:

```bash
curl -fsSL https://obslove.dev | bash
```

Fluxo com opções:

```bash
curl -fsSL https://obslove.dev | bash -s -- -s "meu-dispositivo"
```

O modo padrão usa saída resumida. Use `-v` para ver a saída detalhada no terminal.

> [!IMPORTANT]
> O fluxo suportado e preservado pelo projeto é `curl -fsSL https://obslove.dev | bash`.

> [!TIP]
> Depois do primeiro bootstrap remoto, as execuções seguintes continuam a partir do clone gerenciado em `~/Projects/arch-postinstall-apps`.

## O que o script faz

Durante uma execução normal, o projeto:

1. valida a sessão atual, autentica `sudo`, inicia o log e impede execuções simultâneas;
2. carrega [config/packages.txt](config/packages.txt) por categorias e, se existir, `config/packages-extra.txt`;
3. cria os diretórios principais usados pelo ambiente, move repositórios Git soltos em `~` para `~/Repositories` e migra o clone gerenciado para `~/Projects/arch-postinstall-apps` quando necessário;
4. habilita `multilib`, atualiza o sistema, prepara o GitHub SSH e mantém os remotos gerenciados em SSH sempre que a chave estiver pronta;
5. clona ou atualiza `~/EasyEffects-Preset`, `~/Projects/terminal-lyrics`, `~/Projects/synthetic-profile-generator` e `~/Dots/obslove`, depois instala os apps da lista principal;
6. se o componente estiver habilitado, configura o Codex CLI em `~/Codex` e garante a integração desktop necessária para o ambiente gráfico;
7. valida o resultado, tenta uma correção automática única e grava o resumo final.

Arquivos gerados pela execução:

- log completo: `~/Backups/arch-postinstall.log`
- resumo final: `~/Backups/arch-postinstall-summary.txt`

> [!NOTE]
> O fluxo remoto e o fluxo local executam o mesmo runtime depois que o clone gerenciado é sincronizado.

## Alvo do projeto

Este setup foi ajustado para o seguinte cenário:

- Arch Linux
- sessão Wayland com Hyprland
- `curl` disponível

Se ele for executado fora de um clone local do projeto, o bootstrap remoto instala as dependências iniciais necessárias, clona ou atualiza `~/Projects/arch-postinstall-apps` e continua a partir desse clone.

> [!NOTE]
> O projeto não foi desenhado para ser um instalador Arch genérico. Ele assume Wayland com Hyprland e trata desvios desse alvo como erro de ambiente.

> [!WARNING]
> Rodar isso fora do alvo esperado significa entrar num caminho que o projeto não tenta suportar nem suavizar.

## Pacotes e dependências

O projeto separa claramente:

- infraestrutura do próprio fluxo;
- dependências dos componentes;
- apps principais da máquina, agrupados por categoria.

> [!TIP]
> Componentes de setup ficam fora da lista principal de apps e são mantidos em [config/components.sh](config/components.sh).

<!-- packages:start -->
- Dependências do bootstrap remoto:
  `ca-certificates`, `git`, `curl`, `tar`
- Ferramentas de suporte instaladas no fluxo local:
  `shellcheck`
- Helper AUR padrão preparado pelo script:
  `base-devel`, `yay`
- Dependências da etapa de GitHub SSH:
  `github-cli`, `openssh`
- Apps principais - Browsers:
  `zen-browser-bin`, `firefox`
- Apps principais - Audio:
  `easyeffects`
- Apps principais - Development:
  `code`
- Apps principais - Social:
  `discord`, `spotify-launcher`
- Apps principais - Network:
  `mullvad-vpn`
- Apps principais - Gaming:
  `steam`
- Apps principais - Utilities:
  `less`
- Componentes usados para instalar e executar o Codex CLI:
  `nodejs`, `npm`, `codex`
- Dependências do ambiente gráfico:
  `pipewire`, `wireplumber`, `xdg-utils`, `xdg-desktop-portal`, `xdg-desktop-portal-gtk`, `xdg-desktop-portal-hyprland`
- Dependência temporária, quando necessária:
  `wl-clipboard`
<!-- packages:end -->

Arquivos de configuração principais:

- lista principal por categoria: [config/packages.txt](config/packages.txt)
- lista extra opcional com o mesmo formato: `config/packages-extra.txt`
- componentes declarados do setup: [config/components.sh](config/components.sh)

> [!NOTE]
> A ordem das categorias e dos pacotes é respeitada pelo instalador.

## Interação esperada

Mesmo com a automação, algumas etapas ainda podem exigir interação:

- senha do `sudo`;
- login no GitHub via `gh auth login`;
- renovação de escopo com `gh auth refresh`, se faltar `admin:public_key`;
- algum prompt eventual do `yay` em casos específicos.

> [!NOTE]
> A etapa de GitHub SSH só reconcilia o título da chave quando `--ssh-name` é informado explicitamente.

> [!TIP]
> Sem `--ssh-name`, o script tenta reutilizar a chave já existente no GitHub em vez de recreá-la só por diferença de título.

## Opções disponíveis

Comando base:

```bash
curl -fsSL https://obslove.dev | bash -s --
```

Flags:

- `-c`, `--check`
  Valida o ambiente sem executar a instalação do runtime. No fluxo via `curl`, o bootstrap ainda pode sincronizar o clone local e preparar dependências iniciais se elas estiverem ausentes.
- `-e`, `--exclusive-key`
  Destrutiva: remove as outras chaves SSH da conta no GitHub e mantém apenas a chave atual, mesmo que o GitHub SSH já esteja configurado. Essa opção pede confirmação explícita no terminal.
- `-n`, `--no-gh`
  Pula a etapa de configuração do GitHub SSH.
- `-s`, `--ssh-name NOME`
  Define explicitamente o nome da chave SSH enviada ao GitHub. Sem essa flag, o script reutiliza a chave existente sem reconciliar o título automaticamente.
- `-v`, `--verbose`
  Desativa o modo resumido e mostra a saída completa no terminal.
- `-h`, `--help`
  Exibe a ajuda.

Exemplos:

```bash
curl -fsSL https://obslove.dev | bash -s -- -c
curl -fsSL https://obslove.dev | bash -s -- -e
curl -fsSL https://obslove.dev | bash -s -- -n
curl -fsSL https://obslove.dev | bash -s -- -s "meu-dispositivo"
curl -fsSL https://obslove.dev | bash -s -- -v
curl -fsSL https://obslove.dev | bash -s -- -c -n -s "meu-dispositivo"
```

> [!NOTE]
> `--check` não transforma o bootstrap remoto em no-op. Ele ainda pode sincronizar o clone local e preparar dependências mínimas antes de validar o runtime.

## Uso local

Executar a partir de um clone local:

```bash
bash install.sh
```

Validar o repositório localmente:

```bash
bash scripts/check-repo.sh
```

> [!TIP]
> Esse check cobre geração do `dist/install.sh`, lint dos entrypoints reais, parser de CLI, README e consistência do bootstrap publicado.

## Publicação do bootstrap

O conteúdo servido em `https://obslove.dev` é tratado como parte do sistema.

O repositório mantém:

- verificação de consistência publicada em [scripts/check-published-bootstrap.sh](scripts/check-published-bootstrap.sh);
- workflow de verificação em [.github/workflows/published-bootstrap.yml](.github/workflows/published-bootstrap.yml);
- workflow de deploy em [.github/workflows/deploy-bootstrap.yml](.github/workflows/deploy-bootstrap.yml);
- Worker Cloudflare em `cloudflare/bootstrap-worker/`.

O endpoint publicado deve sempre refletir `main/dist/install.sh`.

Secrets necessários no GitHub:

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`

> [!IMPORTANT]
> Evite editar manualmente a rota ou o Worker do `obslove.dev` no dashboard do Cloudflare. O objetivo do projeto é manter essa publicação sob controle do repositório.

> [!NOTE]
> O workflow de publicação atualiza o Worker já existente associado a `obslove.dev`, então o contrato do domínio fica preso ao `main`.

## Arquivos principais

```text
dist/install.sh
config/components.sh
config/packages-extra.txt.example
config/packages.txt
install.sh
scripts/build-bootstrap.sh
scripts/bootstrap/bootstrap-modules.sh
scripts/check-repo.sh
scripts/install/main.sh
scripts/lib/runtime-modules.sh
```

`install.sh` é um wrapper local fino para `scripts/install/main.sh`.

`dist/install.sh` é o artefato gerado a partir dos fragments em `scripts/bootstrap/` por `scripts/build-bootstrap.sh` e é o bootstrap publicado por `https://obslove.dev`.
