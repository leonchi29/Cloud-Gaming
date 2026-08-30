@echo off
REM ============================================================
REM  Cloud Gaming - PC DEV (despliegue en Railway)
REM  Compila y despliega backend + frontend en Railway.
REM  Se auto-eleva a Administrador.
REM ============================================================
title Cloud Gaming - Despliegue Railway (PC Dev)

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Solicitando permisos de administrador...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo ============================================================
echo   Cloud Gaming - Despliegue en Railway (PC DEV)
echo ============================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-dev.ps1"

echo.
echo ============================================================
echo   Proceso finalizado. ANOTA la URL y el token mostrados.
echo ============================================================
pause
