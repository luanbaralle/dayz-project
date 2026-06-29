# Mods — DayZ Project

Arquitetura de mods do servidor. **`manifest.yaml` é a única fonte de verdade.**

## Estrutura

```
mods/
├── manifest.yaml    # Definição de todos os mods (Workshop + locais)
├── local/           # Mods próprios versionados (@Pastas)
├── keys/            # Chaves .bikey customizadas (opcional)
└── README.md
```

## Tipos de mod

| Tipo | Origem | Instalação | Deploy |
|------|--------|------------|--------|
| **Workshop** | Steam (`client_mods` / `server_mods` no manifest) | `install_mods.sh` | — |
| **Local** | Git (`mods/local/@Mod`) | `install_mods.sh` + `deploy.sh` | `deploy.sh` |
| **Keys custom** | Git (`mods/keys/*.bikey`) | — | `deploy.sh` |

## Mods ativos (padrão)

| Mod | Pasta | Workshop ID |
|-----|-------|-------------|
| Community Framework | `@CF` | 1559212036 |
| VPPAdminTools | `@VPPAdminTools` | 1828439124 |

## Comandos

```bash
# Instalar/atualizar mods Workshop + sincronizar locais
sudo ./deploy/linux/install_mods.sh

# Atualização completa (inclui mods)
./deploy/linux/update.sh
```

## Adicionar um mod Workshop

Edite `manifest.yaml`:

```yaml
client_mods:
  - name: Nome do Mod
    id: WORKSHOP_ID
    folder: "@NomePasta"
    required: true
    enabled: true
    load_order: 30
    depends_on:
      - "@CF"
```

Execute `install_mods.sh` ou `update.sh`.

## Metadados por mod

| Campo | Descrição |
|-------|-----------|
| `required` | Bloqueia start se o mod estiver ausente |
| `enabled` | `false` ignora o mod em install/start |
| `load_order` | Ordem de carregamento (menor = primeiro) |
| `depends_on` | Pastas `@Mod` que devem carregar antes |

Valide antes de iniciar: `./deploy/linux/validate.sh`

## Adicionar um mod local

1. Coloque o mod em `mods/local/@MeuMod/`
2. Adicione em `manifest.yaml`:

```yaml
local_mods:
  - "@MeuMod"
```

3. Execute `deploy.sh` (ou `update.sh`)

## Parâmetros de launch

`-mod=` e `-serverMod=` são gerados a partir do manifest (Fase 3 — `start.sh`).
**Não** configure mods em `.env`.
