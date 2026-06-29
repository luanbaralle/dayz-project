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

## Bootstrap (VPS nova)

Uma VPS Ubuntu 24.04 limpa pode ser preparada com um único comando:

```bash
# 1. Clone o repositório (ou copie os scripts)
git clone https://github.com/SEU_USUARIO/dayz-project.git
cd dayz-project

# 2. Execute o bootstrap como root
chmod +x deploy/linux/*.sh
sudo ./deploy/linux/bootstrap.sh
```

### O que o bootstrap faz

```
bootstrap.sh
    ├── install_dependencies.sh   # git, curl, tmux, rsync, etc.
    ├── install_wine.sh           # Wine 64 + Wine32 + WINEPREFIX
    ├── install_steamcmd.sh       # SteamCMD
    ├── install_dayz.sh           # DayZ Dedicated Server (App 223350)
    └── configure_environment.sh  # Diretórios + .env + git clone
```

Todos os scripts são **idempotentes** — podem ser reexecutados com segurança.

---

## Estrutura de arquivos

```
deploy/linux/
├── bootstrap.sh              # Orquestrador principal
├── install_dependencies.sh   # Pacotes APT base
├── install_wine.sh           # Wine 64 + 32 bits
├── install_steamcmd.sh       # SteamCMD
├── install_dayz.sh           # DayZ Server via SteamCMD
├── configure_environment.sh  # Diretórios e .env
├── deploy.sh                 # Sync projeto → servidor
├── start.sh                  # Inicia servidor (Wine + tmux)
├── stop.sh                   # Encerra servidor
├── restart.sh                # stop + start
├── logs.sh                   # Logs em tempo real
├── status.sh                 # CPU, memória, processos
├── common.sh                 # Funções compartilhadas
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
| `DAYZ_BASE` | Diretório raiz | `/home/ubuntu/dayz` |
| `DAYZ_SERVER_DIR` | Instalação Steam | `/home/ubuntu/dayz/server` |
| `DAYZ_PROJECT_DIR` | Repositório Git | `/home/ubuntu/dayz/project` |
| `DAYZ_PROFILES_DIR` | Perfis runtime | `/home/ubuntu/dayz/profiles` |
| `STEAMCMD_DIR` | SteamCMD | `/home/ubuntu/dayz/steamcmd` |
| `WINEPREFIX` | Prefixo Wine | `/home/ubuntu/.wine-dayz` |
| `DAYZ_PORT` | Porta do servidor | `2302` |
| `GIT_REPO_URL` | URL do repositório | *(configurar)* |
| `DAYZ_APP_ID` | Steam App ID | `223350` |

Copie o template se necessário:

```bash
cp deploy/linux/.env.example /home/ubuntu/dayz/.env
```

---

## Operação diária

Todos os comandos abaixo são executados a partir de `deploy/linux/`:

```bash
cd /home/ubuntu/dayz/project/deploy/linux
```

### Deploy (sync configs do Git)

```bash
./deploy.sh
```

Sincroniza `config/`, `profiles/` e `missions/` do repositório para os diretórios de runtime.

### Iniciar / parar / reiniciar

```bash
./start.sh      # Inicia via Wine em sessão tmux
./stop.sh       # Encerra graciosamente (SIGTERM → SIGKILL)
./restart.sh    # stop + start
```

### Monitoramento

```bash
./status.sh     # CPU, memória, Wine, SteamCMD, processo DayZ
./logs.sh       # Tail em tempo real dos logs
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
      ↓ git pull (VPS)
deploy.sh
      ↓ rsync configs
restart.sh
      ↓
DayZ Server rodando via Wine
```

---

## Arquitetura Wine + SteamCMD

O DayZ Dedicated Server é distribuído apenas como binário **Windows** (.exe). No Linux:

1. **SteamCMD** baixa os arquivos Windows (`+@sSteamCmdForcePlatformType windows`)
2. **Wine** executa `DayZServer_x64.exe` com o prefixo dedicado `~/.wine-dayz`
3. **tmux** mantém o processo ativo após desconexão SSH

Parâmetros de lançamento (equivalente ao `Start_Server.bat` Windows):

```
wine DayZServer_x64.exe
  -config=serverDZ.cfg
  -profiles=/home/ubuntu/dayz/profiles
  -port=2302
  -serverMod=
  -freezecheck -adminlog -dologs
```

> **Mods:** não instalados nesta fase. Variáveis `DAYZ_MODS` e `DAYZ_SERVER_MODS` estão preparadas no `.env` para uso futuro.

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

### Servidor não inicia

```bash
./status.sh                          # Verifica componentes
cat /home/ubuntu/dayz/logs/dayz-server.log
ls -lt /home/ubuntu/dayz/profiles/*.RPT | head -3
```

### Reinstalar DayZ Server

```bash
sudo ./install_dayz.sh               # Idempotente — revalida arquivos
```

### Recriar prefixo Wine

```bash
rm -rf /home/ubuntu/.wine-dayz
sudo ./install_wine.sh
```

### Bootstrap completo (reinstalar tudo)

```bash
sudo ./bootstrap.sh                  # Seguro — idempotente
```

---

## Expansões futuras

- [ ] Instalação de mods via Steam Workshop (`install_mods.sh`)
- [ ] Serviço systemd para auto-start
- [ ] Backup automático antes do deploy
- [ ] GitHub Actions para deploy remoto
- [ ] Validação de `serverDZ.cfg` no CI
- [ ] Rollback de deploy

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
