@echo off
title DayZ Dedicated Server - DayZ Project DEV
cd /d "%~dp0"

echo ============================================
echo   DayZ Project DEV
echo ============================================
echo Config:   serverDZ.cfg
echo Profiles: C:\Users\User\Desktop\Projetos\DayZ-Project\profiles
echo Porta:    2302
echo Mods:     @CF;@VPPAdminTools
echo ============================================
echo.

if not exist "%~dp0@CF\addons\scripts.pbo" (
    echo [ERRO] @CF nao encontrado. Execute Install_Mods.bat primeiro.
    pause
    exit /b 1
)

if not exist "%~dp0@VPPAdminTools\addons\VPPAdminTools.pbo" (
    echo [ERRO] @VPPAdminTools nao encontrado. Execute Install_Mods.bat primeiro.
    pause
    exit /b 1
)

DayZServer_x64.exe -config=serverDZ.cfg "-mod=@CF;@VPPAdminTools" "-serverMod=" "-profiles=C:\Users\User\Desktop\Projetos\DayZ-Project\profiles" -port=2302 -freezecheck -adminlog -dologs

echo.
echo Servidor encerrado. Verifique os logs em profiles se houve erro.
pause
