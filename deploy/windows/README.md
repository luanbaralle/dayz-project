# Deploy — Windows

Scripts de deploy para ambiente de desenvolvimento Windows.

## Uso previsto

- Sincronizar `config/` → instalação Steam local
- Sincronizar `profiles/` → destino de runtime
- Reiniciar servidor após deploy

## Exemplo futuro

```powershell
# deploy/windows/sync-config.ps1
$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$steamRoot   = "C:\Program Files (x86)\Steam\steamapps\common\DayZServer"
Copy-Item "$projectRoot\config\*" $steamRoot -Force
```
