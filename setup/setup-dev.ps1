#Requires -RunAsAdministrator
<#
.SYNOPSIS
  PC DEV — Despliegue completo en Railway en un solo paso.

  Ejecuta TODO lo necesario en el PC de desarrollo:

    1. Verifica Node.js, npm y Railway CLI (autenticado)
    2. Instala y compila el backend
    3. Instala y compila el frontend
    4. Genera un AGENT_TOKEN seguro
    5. Despliega en Railway (proyecto + backend + frontend + dominios)
    6. Muestra la URL pública final, la URL del backend y el token

  Al terminar, anota los 3 datos impresos: los necesitarás en el PC de stream
  para ejecutar setup-stream.ps1 / start-stream.bat.
#>
param(
    [string]$ProjectName = 'cloud-gaming'
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path "$PSScriptRoot\..").Path

function Write-Step([int]$n, [string]$msg) {
    Write-Host ""
    Write-Host "== [$n/6] $msg ==" -ForegroundColor Cyan
}

function Fail([string]$msg) {
    Write-Host ""
    Write-Host "ERROR FATAL: $msg" -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------
Write-Step 1 "Verificando requisitos"

foreach ($cmd in @('node', 'npm', 'railway')) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Fail "No se encontró '$cmd'. Instálalo y vuelve a ejecutar."
    }
    Write-Host "  $cmd : OK"
}

$whoami = (& railway whoami 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) {
    Fail "Railway CLI no está autenticado. Ejecuta 'railway login' primero."
}
Write-Host "  railway autenticado como: $whoami"

# ---------------------------------------------------------------
Write-Step 2 "Backend: instalando dependencias y compilando"
Push-Location "$Root\backend"
try {
    & npm install
    if ($LASTEXITCODE -ne 0) { Fail "npm install falló en backend" }
    & npm run build
    if ($LASTEXITCODE -ne 0) { Fail "Compilación falló en backend" }
} finally { Pop-Location }
Write-Host "  Backend listo."

# ---------------------------------------------------------------
Write-Step 3 "Frontend: instalando dependencias y compilando"
Push-Location "$Root\frontend"
try {
    & npm install
    if ($LASTEXITCODE -ne 0) { Fail "npm install falló en frontend" }
    & npm run build
    if ($LASTEXITCODE -ne 0) { Fail "Compilación falló en frontend" }
} finally { Pop-Location }
Write-Host "  Frontend listo."

# ---------------------------------------------------------------
Write-Step 4 "Generando AGENT_TOKEN seguro"
$AgentToken = ([guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N'))
Write-Host "  Token generado."

# ---------------------------------------------------------------
Write-Step 5 "Desplegando en Railway"
& powershell -NoProfile -ExecutionPolicy Bypass -File "$Root\scripts\deploy-railway.ps1" `
    -ProjectName $ProjectName -AgentToken $AgentToken
if ($LASTEXITCODE -ne 0) { Fail "El despliegue en Railway falló. Revisa los mensajes anteriores." }

# Recuperar dominios
Push-Location "$Root\backend"
try {
    $backendDomain = (& railway domain 2>$null | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($backendDomain)) {
        & railway domain | Out-Null
        $backendDomain = (& railway domain 2>$null | Out-String).Trim()
    }
} finally { Pop-Location }
if ([string]::IsNullOrWhiteSpace($backendDomain)) { Fail "No se pudo obtener el dominio del backend." }
$BackendUrl = "https://$backendDomain"

Push-Location "$Root\frontend"
try {
    $frontendDomain = (& railway domain 2>$null | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($frontendDomain)) {
        & railway domain | Out-Null
        $frontendDomain = (& railway domain 2>$null | Out-String).Trim()
    }
} finally { Pop-Location }
if ([string]::IsNullOrWhiteSpace($frontendDomain)) { Fail "No se pudo obtener el dominio del frontend." }
$FrontendUrl = "https://$frontendDomain"

# ---------------------------------------------------------------
Write-Step 6 "Resumen final"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  DESPLIEGUE EN RAILWAY COMPLETADO" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  URL PÚBLICA (web):  $FrontendUrl" -ForegroundColor Green
Write-Host "  Backend:            $BackendUrl" -ForegroundColor Green
Write-Host "  AGENT_TOKEN:        $AgentToken" -ForegroundColor Green
Write-Host ""
Write-Host "  ANOTA ESTOS DATOS. En el PC DE STREAM ejecuta:" -ForegroundColor Yellow
Write-Host ""
Write-Host "    setup\start-stream.bat" -ForegroundColor White
Write-Host ""
Write-Host "  y pega la URL del backend y el token cuando los pida." -ForegroundColor Yellow
Write-Host "  Después abre la URL pública en Chrome/Edge/Firefox" -ForegroundColor Yellow
Write-Host "  y pulsa Conectar." -ForegroundColor Yellow
Write-Host ""
