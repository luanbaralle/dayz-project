# Arquitetura

## Visão geral

O projeto segue uma separação clara entre **repositório Git** (configuração e infraestrutura) e **instalação Steam** (binários e mods).

```
┌─────────────────────────────────────────────────────────────┐
│                    DayZ-Project (Git)                       │
│  config/  profiles/  docs/  deploy/  scripts/  missions/   │
└──────────────────────────┬──────────────────────────────────┘
                           │ deploy (git pull + sync)
                           ▼
┌─────────────────────────────────────────────────────────────┐
│          DayZ Server (Steam - dependência externa)          │
│  DayZServer_x64.exe  addons/  @CF  @VPPAdminTools  keys/    │
└─────────────────────────────────────────────────────────────┘
```

## Componentes

### Repositório (`DayZ-Project/`)

| Pasta | Responsabilidade |
|-------|------------------|
| `config/` | `serverDZ.cfg`, `Start_Server.bat`, `Install_Mods.bat` |
| `profiles/` | Perfis VPPAdminTools, permissões, banlist |
| `deploy/` | Scripts de sincronização para Windows e Linux |
| `missions/` | Missões customizadas (quando existirem) |
| `mods/` | Manifests e referências (não binários Workshop) |
| `scripts/` | Utilitários de manutenção do projeto |
| `tools/` | Ferramentas locais (ex.: chaves SSH para VPS) |

### Instalação Steam (externa)

```
C:\Program Files (x86)\Steam\steamapps\common\DayZServer
```

Contém executáveis, addons oficiais, mods copiados pelo `Install_Mods.bat` e arquivos gerados em runtime (logs, cache).

**Nunca commitar** conteúdo desta pasta.

## Fluxo de dados

1. Desenvolvedor edita arquivos em `config/` e `profiles/`
2. Commit e push para GitHub
3. Na VPS Oracle: `git pull`
4. Script em `deploy/linux/` copia configs para a instalação do servidor
5. Servidor reiniciado com novas configurações

## Perfis

O servidor aponta para `profiles/` deste repositório via parâmetro `-profiles=` no `Start_Server.bat`.

**Versionado:** JSONs de configuração VPPAdminTools, permissões, banlist  
**Ignorado (runtime):** logs `.RPT`, `.ADM`, `.log`, cache, credenciais
