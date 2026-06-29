# Perfis do servidor

Perfis de runtime do DayZ Server, incluindo configurações do **VPPAdminTools**.

## O que é versionado

- `VPPAdminTools/BanList.json`
- `VPPAdminTools/LogOptions.json`
- `VPPAdminTools/ConfigurablePlugins/**/*.json`
- `VPPAdminTools/Permissions/UserGroups/`
- `VPPAdminTools/Permissions/SuperAdmins/`
- `Users/Server/DayZ.cfg`

## O que NÃO é versionado (runtime)

- Logs: `*.RPT`, `*.ADM`, `*.log`
- Cache: `DataCache/`
- BattlEye: `BattlEye/` (binários)
- Credenciais: `VPPAdminTools/Permissions/credentials.txt`
- Dados de jogador: `Users/Survivor/`
- Backups e exports automáticos do VPPAdminTools

## Parâmetro do servidor

O `Start_Server.bat` aponta para este diretório:

```
-profiles=C:\Users\User\Desktop\Projetos\DayZ-Project\profiles
```

Em produção (VPS), o caminho será ajustado pelo script de deploy.
