# Guia de início rápido

## 1. Clonar o repositório

```bash
git clone https://github.com/SEU_USUARIO/dayz-project.git
cd dayz-project
```

## 2. Instalar o DayZ Server (Steam)

Instale o **DayZ Server** via Steam Client ou SteamCMD.

Caminho padrão Windows:

```
C:\Program Files (x86)\Steam\steamapps\common\DayZServer
```

## 3. Sincronizar configurações

Copie os arquivos de `config/` para a pasta da instalação Steam:

```powershell
$steam = "C:\Program Files (x86)\Steam\steamapps\common\DayZServer"
$project = "C:\Users\User\Desktop\Projetos\DayZ-Project"
Copy-Item "$project\config\*" $steam -Force
```

> No futuro, scripts em `deploy/windows/` automatizarão este passo.

## 4. Instalar mods

Execute na pasta Steam:

```
Install_Mods.bat
```

Requisitos: mods **CF** e **VPPAdminTools** assinados na Steam Workshop.

## 5. Iniciar o servidor

```
Start_Server.bat
```

O servidor usará:

- Config: `serverDZ.cfg`
- Perfis: `profiles/` do repositório
- Porta: `2302`
- Mods: `@CF;@VPPAdminTools`

## 6. Verificar logs

Logs de runtime ficam em `profiles/` e **não** são versionados. Consulte arquivos `.RPT` e `script_*.log` em caso de erro.
