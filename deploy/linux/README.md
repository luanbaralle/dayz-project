# Deploy — Linux (Oracle VPS)

Scripts de deploy para o servidor de produção em Linux (Oracle Cloud VPS).

## Uso previsto

- `git pull` do repositório
- Sincronizar `config/` e `profiles/` para a instalação DayZ Server
- Reiniciar serviço do servidor (systemd ou script manual)

## Exemplo futuro

```bash
#!/bin/bash
# deploy/linux/deploy.sh
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DAYZ_ROOT="/opt/dayz-server"
git -C "$PROJECT_ROOT" pull
cp -r "$PROJECT_ROOT/config/"* "$DAYZ_ROOT/"
cp -r "$PROJECT_ROOT/profiles/"* "$DAYZ_ROOT/profiles/"
# systemctl restart dayz-server
```
