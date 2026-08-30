@echo off
REM ============================================================
REM  Cloud Gaming - PC DE STREAM (el PC que se controla)
REM  Instala el agente, configura Windows y lo deja listo.
REM  Se auto-eleva a Administrador.
REM
REM  Uso: doble clic y rellenar los datos cuando los pida.
REM ============================================================
title Cloud Gaming - Setup PC de Stream

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Solicitando permisos de administrador...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo ============================================================
echo   Cloud Gaming - Instalacion del PC DE STREAM
echo ============================================================
echo.
echo Necesitas los datos que mostro el despliegue en el PC dev:
echo.

set /p BACKEND_URL="URL del backend (https://backend-xxxx.up.railway.app): "
set /p AGENT_TOKEN="AGENT_TOKEN: "

if "%BACKEND_URL%"=="" (
    echo ERROR: La URL del backend es obligatoria.
    pause
    exit /b 1
)
if "%AGENT_TOKEN%"=="" (
    echo ERROR: El token es obligatorio.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-stream.ps1" -BackendUrl "%BACKEND_URL%" -AgentToken "%AGENT_TOKEN%"

echo.
echo ============================================================
echo   Proceso finalizado. Revisa los mensajes anteriores.
echo ============================================================
pause
