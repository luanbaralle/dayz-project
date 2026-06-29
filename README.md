# DayZ Project

Repositório de infraestrutura e configuração para o servidor dedicado **DayZ Project DEV**.

Este monorepo centraliza tudo que é versionável do projeto: configurações, perfis administrativos, documentação, scripts de automação e estrutura de deploy. A instalação oficial do DayZ Server **não** faz parte deste repositório.

---

## Objetivos

- Manter configurações do servidor sob controle de versão (Git)
- Separar claramente o que é **projeto** do que é **instalação Steam**
- Preparar deploy automatizado para VPS (Oracle Cloud)
- Organizar documentação, decisões arquiteturais (ADRs) e ferramentas auxiliares
- Facilitar desenvolvimento contínuo com Cursor e fluxo Git → Deploy → Restart

---

## Estrutura de pastas

```
DayZ-Project/
├── adr/                  # Architecture Decision Records
├── config/               # Configurações do servidor (serverDZ.cfg, scripts .bat)
├── deploy/
│   ├── windows/          # Scripts de deploy para Windows
│   └── linux/            # Scripts de deploy para Linux (VPS)
├── docs/                 # Documentação do projeto
├── missions/             # Missões customizadas (futuro)
├── mods/                 # Referências e manifests de mods (não os binários)
├── profiles/             # Perfis do servidor (VPPAdminTools, permissões)
├── scripts/              # Scripts utilitários do projeto
├── tools/                # Ferramentas auxiliares (ex.: chaves SSH locais)
├── .github/              # Templates e workflows GitHub
├── README.md
├── .gitignore
└── LICENSE
```

---

## Fluxo de desenvolvimento

```
Cursor (edição local)
        ↓
   Git Commit
        ↓
    Git Push
        ↓
   Oracle VPS
        ↓
    Git Pull
        ↓
      Deploy
        ↓
 Restart Server
```

1. **Desenvolver** — Edite configs, perfis e scripts no Cursor
2. **Commitar** — Registre mudanças com mensagens descritivas
3. **Publicar** — `git push` para o repositório remoto
4. **Sincronizar** — Na VPS, execute `git pull`
5. **Deploy** — Scripts em `deploy/` copiam arquivos para a instalação do servidor
6. **Reiniciar** — Reinicie o processo do DayZ Server para aplicar alterações

---

## Arquitetura

### O que NÃO está no Git

A instalação oficial do DayZ Server é uma **dependência externa**, instalada via Steam:

```
C:\Program Files (x86)\Steam\steamapps\common\DayZServer
```

Ela contém:

- `DayZServer_x64.exe` e bibliotecas Steam
- Addons oficiais (`addons/`, `dta/`)
- Mods instalados (`@CF`, `@VPPAdminTools`)
- BattlEye, keys e binários do jogo

Esses arquivos são gerenciados pelo Steam e pelos scripts `Install_Mods.bat` — **não** devem ser commitados.

### O que ESTÁ no Git

| Categoria | Local no repositório |
|-----------|----------------------|
| Configurações do servidor | `config/` |
| Perfis e permissões (VPPAdminTools) | `profiles/` |
| Documentação | `docs/` |
| Decisões arquiteturais | `adr/` |
| Missões customizadas | `missions/` |
| Scripts utilitários | `scripts/` |
| Automação de deploy | `deploy/` |
| Ferramentas auxiliares | `tools/` |

### Ambiente local (desenvolvimento)

- **Config fonte:** `config/` (versionado)
- **Runtime:** cópias em uso na pasta Steam durante desenvolvimento
- **Perfis:** `profiles/` apontado pelo `Start_Server.bat`

---

## Pré-requisitos

- [DayZ Server](https://store.steampowered.com/app/221100/DayZ/) instalado via Steam
- Mods: **CF** e **VPPAdminTools** (via Steam Workshop)
- Windows (dev local) / Linux (VPS Oracle)

---

## Início rápido (desenvolvimento local)

1. Clone este repositório
2. Instale o DayZ Server via Steam (se ainda não tiver)
3. Copie os arquivos de `config/` para a pasta da instalação Steam (ou use deploy futuro)
4. Execute `Install_Mods.bat` na instalação Steam para instalar `@CF` e `@VPPAdminTools`
5. Execute `Start_Server.bat` na instalação Steam

> Os scripts em `config/` são a **fonte de verdade** versionada. Em produção, o deploy sincronizará automaticamente.

---

## Mods ativos

| Mod | Workshop ID |
|-----|-------------|
| CF (Community Framework) | 1559212036 |
| VPPAdminTools | 1828439124 |

---

## Licença

Consulte o arquivo [LICENSE](LICENSE).
