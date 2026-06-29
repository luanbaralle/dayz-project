# Deploy Linux — DayZ Project (Oracle Cloud VPS)

Infraestrutura reproduzível para executar o **DayZ Dedicated Server** em **Ubuntu 24.04** via **Wine**, com instalação automatizada via **SteamCMD**.

---

## Visão geral

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Oracle Cloud VPS (Ubuntu 24.04)                 │
│                                                                     │
│  /home/ubuntu/dayz/                                                 │
│  ├── server/          ← DayZ Dedicated Server (SteamCMD, Windows)   │
│  ├── project/         ← Repositório Git (DayZ-Project)              │
│  ├── profiles/        ← Perfis de runtime (VPPAdminTools, etc.)      │
│  ├── steamcmd/        ← Cliente SteamCMD                            │
│  ├── backups/         ← Backups locais                              │
│  ├── logs/            ← Logs centralizados                          │
│  └── .env             ← Variáveis de ambiente                       │
│                                                                     │
│  Wine (WINEPREFIX=~/.wine-dayz)                                     │
│       └── DayZServer_x64.exe                                        │
│                                                                     │
│  deploy/linux/          ← Scripts de bootstrap e operação           │
└─────────────────────────────────────────────────────────────────────┘
```

### Separação de responsabilidades

| Componente | Local | Versionado no Git? |
|------------|-------|------------------|
| Configs (`serverDZ.cfg`) | `project/config/` → sync → `server/` | Sim |
| Perfis VPPAdminTools | `project/profiles/` → sync → `profiles/` | Sim |
| Binários DayZ Server | `server/` (SteamCMD) | Não |
| Wine prefix | `~/.wine-dayz` | Não |
| Logs runtime | `logs/`, `profiles/*.RPT` | Não |

---

## Camadas de operação

| Camada | Script | Quando usar |
|--------|--------|-------------|
| **Bootstrap** | `bootstrap.sh` | Uma vez na vida da VPS — prepara SO e estrutura |
| **Provisioning** | `install_dayz.sh`, `install_mods.sh`* | Instalar/atualizar binários Steam |
| **Atualização** | `update.sh` | `git pull` + SteamCMD + mods + deploy |
| **Deploy** | `deploy.sh` | Sincronizar Git → runtime (rsync only) |
| **Operação** | `start.sh`, `stop.sh`, `restart.sh` | Controlar o processo do servidor |
| **Validação** | `validate.sh` | Verificar manifest, mods e ambiente antes do start |

\* `install_mods.sh` — lê `mods/manifest.yaml`, Workshop + locais

---

## Bootstrap (VPS nova — executar UMA VEZ)

Prepara a máquina. **Não** instala DayZ, **não** clona Git, **não** faz deploy.

```bash
# Copie os scripts ou clone o repositório
git clone https://github.com/SEU_USUARIO/dayz-project.git /tmp/dayz-project
chmod +x /tmp/dayz-project/deploy/linux/*.sh
sudo /tmp/dayz-project/deploy/linux/bootstrap.sh
```

### O que o bootstrap faz

```
bootstrap.sh
    ├── install_dependencies.sh   # git, curl, tmux, rsync, etc.
    ├── install_wine.sh           # Wine 64 + Wine32 + WINEPREFIX
    ├── install_steamcmd.sh       # SteamCMD
    └── configure_environment.sh  # diretórios + .env (nunca sobrescreve)
```

O bootstrap **não** chama: `install_dayz.sh`, `deploy.sh`, `start.sh`, `git pull`.

Componentes de sistema (APT, Wine, SteamCMD) são idempotentes.
O `.env` existente **nunca é sobrescrito**.

---

## Primeira configuração

O DayZ Dedicated Server (App ID `223350`) **não pode** ser instalado com `login anonymous`.
É necessária uma conta Steam com licença do servidor dedicado.

### Passo a passo

**1. Execute o bootstrap** (primeira vez na VPS):

```bash
chmod +x deploy/linux/*.sh
sudo ./deploy/linux/bootstrap.sh
```

Na primeira execução, o bootstrap cria automaticamente `/home/ubuntu/dayz/.env` a partir de `deploy/linux/.env.example`.

**2. Edite o arquivo de ambiente:**

```bash
nano /home/ubuntu/dayz/.env
```

**3. Configure o usuário Steam:**

```env
STEAM_USERNAME=seu_usuario_steam
```

> A conta Steam deve possuir a licença do **DayZ Dedicated Server**.
> A **senha não é armazenada** em arquivo — veja [Autenticação Steam](#autenticação-steam).

**4. Instale o DayZ Server** (senha solicitada interativamente na primeira vez):

```bash
sudo ./deploy/linux/install_dayz.sh
```

O script pedirá a senha com `read -s` (não exibida, não gravada em disco).
Se a conta usar **Steam Guard**, o SteamCMD solicitará o código no terminal.

**5. Clone o repositório Git:**

```bash
sudo -u ubuntu git clone https://github.com/SEU_USUARIO/dayz-project.git /home/ubuntu/dayz/project
```

**6. Sincronize e inicie:**

```bash
cd /home/ubuntu/dayz/project/deploy/linux
./deploy.sh
./start.sh
```

**7. Verifique a instalação:**

```bash
./deploy/linux/status.sh
ls -la /home/ubuntu/dayz/server/DayZServer_x64.exe
```

### Comportamento idempotente

| Situação | Comportamento |
|----------|---------------|
| `.env` já existe | **Nunca sobrescrito** |
| Servidor já instalado | Atualiza via autenticação em cache do SteamCMD |
| Primeira instalação | Solicita senha interativamente (`read -s`) |
| `STEAM_USERNAME` ausente | Erro amigável com instruções |

---

## Autenticação Steam

A infraestrutura segue boas práticas de segurança para credenciais:

| Dado | Armazenado em `.env`? | Como funciona |
|------|----------------------|---------------|
| `STEAM_USERNAME` | **Sim** | Identifica a conta com licença do DayZ |
| Senha Steam | **Nunca** | Solicitada com `read -s` apenas na primeira instalação |
| Steam Guard | **Nunca** | SteamCMD solicita interativamente se necessário |

### Primeira instalação

1. Configure `STEAM_USERNAME` no `.env`
2. Execute `sudo ./deploy/linux/install_dayz.sh`
3. Informe a senha quando solicitado (não será exibida)
4. Se a conta usar Steam Guard, digite o código quando o SteamCMD pedir
5. O SteamCMD salva arquivos de autenticação localmente (em `~/Steam/` do usuário `ubuntu`)

### Atualizações subsequentes

Após a primeira autenticação bem-sucedida, o `install_dayz.sh` usa apenas:

```
+login "$STEAM_USERNAME"
```

Os tokens de sessão gerados pelo SteamCMD são reutilizados automaticamente.
Normalmente **não será necessário informar a senha novamente**.

> **Importante:** execute `install_dayz.sh` em um terminal interativo na primeira instalação.
> Execuções via cron ou pipe não conseguem solicitar a senha.

---

## Estrutura de arquivos

```
deploy/linux/
├── bootstrap.sh              # Preparação inicial da VPS (uma vez)
├── update.sh                 # git pull + SteamCMD + deploy
├── configure_environment.sh  # Diretórios + .env (interno ao bootstrap)
├── install_dependencies.sh   # Pacotes APT base
├── install_wine.sh           # Wine 64 + 32 bits
├── install_steamcmd.sh       # SteamCMD
├── install_dayz.sh           # DayZ Server via SteamCMD
├── install_mods.sh           # Mods Workshop + locais (manifest.yaml)
├── deploy.sh                 # Rsync Git → runtime (sem git pull)
├── start.sh                  # Inicia servidor (Wine + tmux, manifest-driven)
├── validate.sh               # Validação declarativa pré-start
├── stop.sh                   # Encerra servidor
├── restart.sh                # stop + start
├── logs.sh                   # Logs em tempo real
├── status.sh                 # Painel de diagnóstico
├── common.sh                 # Fachada — carrega lib/
├── lib/
│   ├── env.sh                # Variáveis de ambiente
│   ├── log.sh                # Logging e painel de status
│   ├── filesystem.sh         # Diretórios e APT
│   ├── process.sh            # PID / processo do servidor
│   ├── steam.sh              # SteamCMD + autenticação
│   ├── mods.sh               # Interface bash → manifest.yaml
│   ├── mods_parser.py        # Parser/validador Python (CI-ready)
│   ├── validation.sh         # Validação do ambiente
│   └── launch.sh             # Montagem de parâmetros e start
├── .env.example              # Template de variáveis
└── README.md                 # Este arquivo
```

---

## Configuração (.env)

Após o bootstrap, revise `/home/ubuntu/dayz/.env`:

```bash
nano /home/ubuntu/dayz/.env
```

Variáveis principais:

| Variável | Descrição | Padrão |
|----------|-----------|--------|
| `DAYZ_HOME` | Diretório raiz | `/home/ubuntu/dayz` |
| `DAYZ_SERVER_DIR` | Instalação Steam | `/home/ubuntu/dayz/server` |
| `PROJECT_DIR` | Repositório Git | `/home/ubuntu/dayz/project` |
| `PROFILE_DIR` | Perfis runtime | `/home/ubuntu/dayz/profiles` |
| `STEAMCMD_DIR` | Binário SteamCMD | `/home/ubuntu/dayz/steamcmd` |
| `STEAM_HOME` | Biblioteca Steam (workshop, steamapps) | auto: `~/Steam` ou `$DAYZ_HOME/steam` |
| `STEAM_USERNAME` | Login Steam com licença DayZ (**obrigatório**) | *(configurar)* |
| `STEAM_PLATFORM` | Plataforma SteamCMD | `windows` |
| `DAYZ_APP_ID` | Steam App ID | `223350` |
| `WINEPREFIX` | Prefixo Wine | `/home/ubuntu/.wine-dayz` |
| `DAYZ_PORT` | Porta do servidor | `2302` |
| `GIT_REPO_URL` | URL do repositório | *(configurar)* |

> **Autenticação Steam:** o App ID `223350` requer conta com licença do DayZ Server.
> Login anonymous retorna `ERROR! Failed to install app '223350' (No subscription)`.
> A senha **não** fica no `.env` — veja [Autenticação Steam](#autenticação-steam).

Copie o template manualmente apenas se necessário:

```bash
cp deploy/linux/.env.example /home/ubuntu/dayz/.env
chmod 600 /home/ubuntu/dayz/.env
```

---

## Operação diária

### Fluxo de desenvolvimento (após setup inicial)

```
Cursor → git commit → git push
         ↓
Oracle VPS → git pull → deploy.sh → restart.sh
```

```bash
cd /home/ubuntu/dayz/project
git pull
./deploy/linux/deploy.sh
./deploy/linux/restart.sh
```

> `deploy.sh` **não** executa `git pull`. Atualize o repositório antes do deploy.

### Atualização completa (jogo + mods + configs)

```bash
cd /home/ubuntu/dayz/project/deploy/linux
./update.sh        # git pull → install_dayz → install_mods* → deploy
./restart.sh       # se necessário
```

### Deploy (somente sincronização)

```bash
./deploy.sh
```

Sincroniza `config/`, `profiles/` e `missions/` do repositório para runtime via rsync.

### Iniciar / parar / reiniciar

```bash
./validate.sh   # Opcional — start.sh valida automaticamente
./start.sh      # Inicia via Wine em sessão tmux (bloqueia se validação falhar)
./stop.sh       # Encerra graciosamente (SIGTERM → SIGKILL)
./restart.sh    # stop + start
```

### Monitoramento

```bash
./status.sh     # Painel de diagnóstico (servidor, mods, Wine, missão, versão)
./logs.sh       # Tail em tempo real dos logs
./validate.sh   # Validação completa do manifest e ambiente
```

Para anexar à sessão tmux do servidor:

```bash
tmux attach-session -t dayz-server
# Ctrl+B, depois D para desanexar
```

---

## Fluxo de desenvolvimento completo

```
Cursor (Windows)
      ↓ git commit + push
GitHub
      ↓ git pull (VPS — manual ou via update.sh)
deploy.sh
      ↓ rsync (sem git pull interno)
restart.sh
      ↓
DayZ Server rodando via Wine
```

---

## Arquitetura Wine + SteamCMD

O DayZ Dedicated Server é distribuído apenas como binário **Windows** (.exe). No Linux:

1. **SteamCMD** baixa os arquivos Windows (`+@sSteamCmdForcePlatformType windows`)
2. **Login Steam** com conta licenciada (`STEAM_USERNAME`; senha só na 1ª vez)
3. **Wine** executa `DayZServer_x64.exe` com o prefixo dedicado `~/.wine-dayz`
4. **tmux** mantém o processo ativo após desconexão SSH

Parâmetros de lançamento (equivalente ao `Start_Server.bat` Windows):

```
wine DayZServer_x64.exe
  -config=serverDZ.cfg
  -profiles=/home/ubuntu/dayz/profiles
  -port=2302
  -serverMod=
  -freezecheck -adminlog -dologs
```

> **Mods:** `mods/manifest.yaml` é a fonte de verdade. `start.sh` gera `-mod=` e `-serverMod=` automaticamente a partir do manifest (sem variáveis no `.env`).

### Biblioteca Steam (`STEAM_HOME`)

O SteamCMD separa dois caminhos:

| Variável | Conteúdo |
|----------|----------|
| `STEAMCMD_DIR` | Binário `steamcmd.sh` |
| `STEAM_HOME` | Biblioteca Steam (`steamapps/`, workshop) |

Downloads Workshop vão para:

```
$STEAM_HOME/steamapps/workshop/content/<app_id>/<item_id>
```

Por padrão o SteamCMD usa `~/Steam` do usuário `DAYZ_USER`. A infraestrutura resolve `STEAM_HOME` automaticamente (VPS existente) ou consolida em `$DAYZ_HOME/steam` (instalação nova).

### Manifest de mods (`mods/manifest.yaml`)

Cada mod suporta metadados declarativos:

| Campo | Descrição |
|-------|-----------|
| `name` | Nome legível |
| `id` | Workshop ID (client/server mods) |
| `folder` | Pasta no servidor (ex: `@CF`) |
| `required` | Se `true`, `validate.sh` bloqueia o start se ausente |
| `enabled` | Se `false`, ignorado em install/start |
| `load_order` | Ordem de carregamento (menor = primeiro) |
| `depends_on` | Pastas que devem carregar antes |

`validate.sh` verifica: YAML válido, IDs/pastas duplicados, mods ausentes, `.bikey`, dependências, `serverDZ.cfg`, missão e diretórios obrigatórios.

---

## Firewall Oracle Cloud

Libere as portas necessárias no **Security List** e no `iptables`/`ufw` da VPS:

| Porta | Protocolo | Uso |
|-------|-----------|-----|
| 2302 | UDP | Game port |
| 2303 | UDP | Steam query (+1) |
| 22 | TCP | SSH |

```bash
sudo ufw allow 22/tcp
sudo ufw allow 2302:2305/udp
sudo ufw enable
```

---

## Troubleshooting

### Servidor não inicia / falha na instalação

```bash
./status.sh                          # Verifica componentes
cat /home/ubuntu/dayz/logs/dayz-server.log
ls -lt /home/ubuntu/dayz/profiles/*.RPT | head -3
```

### Erro "No subscription" no SteamCMD

A conta Steam configurada não possui licença do DayZ Dedicated Server,
ou `STEAM_USERNAME` está incorreto/vazio.

```bash
nano /home/ubuntu/dayz/.env          # Configurar STEAM_USERNAME
sudo ./install_dayz.sh               # Senha solicitada interativamente
```

Se a conta usa Steam Guard, o SteamCMD solicitará o código no terminal
durante a primeira autenticação — não é necessário configurar nada no `.env`.

### Reinstalar DayZ Server

```bash
sudo ./install_dayz.sh               # Idempotente — revalida arquivos
```

### Recriar prefixo Wine

```bash
rm -rf /home/ubuntu/.wine-dayz
sudo ./install_wine.sh
```

### Reexecutar bootstrap (apenas componentes de sistema)

```bash
sudo ./bootstrap.sh    # Idempotente — não reinstala DayZ nem faz deploy
```

---

## Expansões futuras

- [x] Separação bootstrap / update / deploy (Fase 1)
- [x] `mods/manifest.yaml` + `install_mods.sh` (Fase 2)
- [x] Validação declarativa + `lib/` modular + painel `status.sh` (Fase 3)
- [ ] Serviço systemd para auto-start
- [ ] Backup automático antes do deploy
- [ ] GitHub Actions para deploy remoto
- [ ] Validação de `serverDZ.cfg` no CI
- [ ] Rollback de deploy
- [ ] Remover fachada `common.sh` (imports diretos de `lib/`)

---

## Requisitos mínimos da VPS

| Recurso | Mínimo | Recomendado |
|---------|--------|-------------|
| RAM | 4 GB | 8 GB |
| CPU | 2 vCPU | 4 vCPU |
| Disco | 30 GB | 50 GB |
| SO | Ubuntu 24.04 LTS | Ubuntu 24.04 LTS |

---

## Referências

- [DayZ Server Steam App](https://store.steampowered.com/app/223350/) — App ID `223350`
- [SteamCMD](https://developer.valvesoftware.com/wiki/SteamCMD)
- [Wine HQ](https://www.winehq.org/)
- Repositório do projeto: `docs/architecture.md`
