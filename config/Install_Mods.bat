@echo off
setlocal EnableExtensions
title DayZ Server - Instalar Mods (CF + VPPAdminTools)
cd /d "%~dp0"

set "CF_SRC=D:\SteamLibrary\steamapps\workshop\content\221100\1559212036"
set "VPP_SRC=D:\SteamLibrary\steamapps\workshop\content\221100\1828439124"
set "SERVER_ROOT=%~dp0"
set "KEYS_DIR=%SERVER_ROOT%keys"

echo ============================================
echo   Instalacao de Mods - Sprint 002
echo   CF + VPPAdminTools
echo ============================================
echo Servidor: "%SERVER_ROOT%"
echo.

if not exist "%CF_SRC%\addons" (
    echo [ERRO] CF nao encontrado em: "%CF_SRC%"
    goto :fail
)

if not exist "%VPP_SRC%\addons" (
    echo [ERRO] VPPAdminTools nao encontrado em: "%VPP_SRC%"
    goto :fail
)

if not exist "%KEYS_DIR%\" (
    echo [ERRO] Pasta keys nao encontrada: "%KEYS_DIR%"
    goto :fail
)

echo [1/4] Copiando @CF...
robocopy "%CF_SRC%" "%SERVER_ROOT%@CF" /E /NFL /NDL /NJH /NJS /NC /NS /NP
if errorlevel 8 (
    echo [ERRO] Falha ao copiar @CF.
    goto :fail
)

echo [2/4] Copiando @VPPAdminTools...
robocopy "%VPP_SRC%" "%SERVER_ROOT%@VPPAdminTools" /E /NFL /NDL /NJH /NJS /NC /NS /NP
if errorlevel 8 (
    echo [ERRO] Falha ao copiar @VPPAdminTools.
    goto :fail
)

echo [3/4] Copiando chaves (.bikey)...
copy /Y "%CF_SRC%\keys\Jacob_Mango_V3.bikey" "%KEYS_DIR%\" >nul
if errorlevel 1 (
    echo [ERRO] Falha ao copiar Jacob_Mango_V3.bikey
    goto :fail
)

copy /Y "%VPP_SRC%\keys\VPP.bikey" "%KEYS_DIR%\" >nul
if errorlevel 1 (
    echo [ERRO] Falha ao copiar VPP.bikey
    goto :fail
)

echo [4/4] Validando instalacao...
set "OK=1"

if not exist "%SERVER_ROOT%@CF\addons\scripts.pbo" set "OK=0"
if not exist "%SERVER_ROOT%@VPPAdminTools\addons\VPPAdminTools.pbo" set "OK=0"
if not exist "%KEYS_DIR%\Jacob_Mango_V3.bikey" set "OK=0"
if not exist "%KEYS_DIR%\VPP.bikey" set "OK=0"

if "%OK%"=="0" (
    echo [ERRO] Validacao falhou. Verifique os arquivos copiados.
    goto :fail
)

echo.
echo ============================================
echo   Instalacao concluida com sucesso.
echo ============================================
echo Mods: @CF, @VPPAdminTools
echo Keys: Jacob_Mango_V3.bikey, VPP.bikey
echo Proximo passo: Start_Server.bat
pause
exit /b 0

:fail
echo.
echo Instalacao interrompida.
pause
exit /b 1
