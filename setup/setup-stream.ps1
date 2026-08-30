#Requires -RunAsAdministrator
<#
.SYNOPSIS
  PC DE STREAM — Instalación del agente Cloud Gaming en un solo paso.

  Ejecuta TODO lo necesario en el PC que se controlará remotamente:

    1. Verifica Node.js y npm
    2. Instala y compila el agente (robotjs nativo para teclado/ratón)
    3. Genera agent\.env con la URL del backend y el token proporcionados
    4. Configura energía de Windows 10 (nunca suspender/hibernar/apagar discos/red)
    5. Configura modo tapa cerrada
    6. Instala el agente como tarea programada (arranque con Windows, reinicio si falla)
    7. Verifica que el agente conectó con el backend

  Después de ejecutarlo UNA VEZ, el PC queda listo para siempre:
  el agente arranca solo con Windows y se reconecta automáticamente.

.PARAMETER BackendUrl
  URL pública del backend en Railway (la mostró el despliegue en el PC dev).
  Ejemplo: https://backend-production-xxxx.up.railway.app

.PARAMETER AgentToken
  Token generado durante el despliegue (el mismo que usa el backend).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File setup-stream.ps1 `
      -BackendUrl "https://backend-xxxx.up.railway.app" `
      -AgentToken "abc123..."
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$BackendUrl,

    [Parameter(Mandatory = $true)]
    [string]$AgentToken
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path "$PSScriptRoot\..").Path

function Write-Step([int]$n, [string]$msg) {
    Write-Host ""
    Write-Host "== [$n/7] $msg ==" -ForegroundColor Cyan
}

function Fail([string]$msg) {
    Write-Host ""
    Write-Host "ERROR FATAL: $msg" -ForegroundColor Red
    exit 1
}

# Normalizar URL (sin barra final)
$BackendUrl = $BackendUrl.TrimEnd('/')

# ---------------------------------------------------------------
Write-Step 1 "Verificando requisitos"

foreach ($cmd in @('node', 'npm')) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Fail "No se encontró '$cmd'. Instala Node.js 18+ desde https://nodejs.org y vuelve a ejecutar."
    }
    Write-Host "  $cmd : OK ($(node --version 2>$null))"
}

$sunshinePath = 'C:\Program Files\Sunshine\sunshine.exe'
if (Test-Path $sunshinePath) {
    Write-Host "  Sunshine: encontrado en $sunshinePath"
} else {
    Write-Warning "  Sunshine no encontrado en $sunshinePath."
    Write-Warning "  Si lo instalaste en otra ruta, edita SUNSHINE_PATH en agent\.env después."
}

# ---------------------------------------------------------------
Write-Step 2 "Agente: instalando dependencias y compilando"
Push-Location "$Root\agent"
try {
    & npm install
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "npm install completo falló (robotjs requiere Visual Studio Build Tools)."
        Write-Warning "Continuando sin scripts nativos: el vídeo funcionará pero NO el teclado/ratón"
        Write-Warning "hasta instalar Build Tools y ejecutar: cd agent; npm rebuild robotjs"
        & npm install --ignore-scripts
        if ($LASTEXITCODE -ne 0) { Fail "npm install falló en el agente" }
    }
    & npm run build
    if ($LASTEXITCODE -ne 0) { Fail "La compilación del agente falló" }
} finally { Pop-Location }
Write-Host "  Agente compilado."

# ---------------------------------------------------------------
Write-Step 3 "Generando agent\.env"
$envContent = @"
BACKEND_URL=$BackendUrl
AGENT_TOKEN=$AgentToken
SUNSHINE_PATH=$sunshinePath
SUNSHINE_CHECK_INTERVAL_MS=15000
STREAM_FPS=8
"@
Set-Content -Path "$Root\agent\.env" -Value $envContent -Encoding UTF8
Write-Host "  BACKEND_URL=$BackendUrl"

# ---------------------------------------------------------------
Write-Step 4 "Configurando energía de Windows 10"
& powershell -NoProfile -ExecutionPolicy Bypass -File "$Root\scripts\setup-windows.ps1"
if ($LASTEXITCODE -ne 0) { Write-Warning "setup-windows.ps1 devolvió código $LASTEXITCODE (continuando)" }

# ---------------------------------------------------------------
Write-Step 5 "Configurando modo tapa cerrada"
& powershell -NoProfile -ExecutionPolicy Bypass -File "$Root\scripts\lid-closed.ps1"
if ($LASTEXITCODE -ne 0) { Write-Warning "lid-closed.ps1 devolvió código $LASTEXITCODE (continuando)" }

# ---------------------------------------------------------------
Write-Step 6 "Instalando agente como tarea programada de Windows"
& powershell -NoProfile -ExecutionPolicy Bypass -File "$Root\scripts\install-agent.ps1" -AgentPath "$Root\agent"
if ($LASTEXITCODE -ne 0) { Fail "La instalación del agente falló." }

# ---------------------------------------------------------------
Write-Step 7 "Verificación de conexión con el backend"

# Espera activa: el agente tarda unos segundos en registrarse. Se comprueba
# contra el backend real (online=true) en lugar de solo el estado de la tarea.
$agentOnline = $false
foreach ($i in 1..15) {
    Start-Sleep -Seconds 3
    try {
        $status = Invoke-RestMethod -Uri "$BackendUrl/status" -TimeoutSec 10
        if ($status.online -eq $true) {
            $agentOnline = $true
            break
        }
    } catch {
        # backend aún no responde; reintentar
    }
    Write-Host "  Esperando al agente... ($i/15)"
}

$task = Get-ScheduledTask -TaskName 'CloudGamingAgent' -ErrorAction SilentlyContinue
$taskState = if ($task) { $task.State } else { 'NO INSTALADA' }

if ($agentOnline) {
    Write-Host "  Agente: CONECTADO al backend (online=true)" -ForegroundColor Green
    Write-Host "  Estado de la tarea: $taskState" -ForegroundColor Green
} else {
    Write-Warning "  El agente NO conectó con el backend tras 45s."
    Write-Warning "  Estado de la tarea: $taskState"
    Write-Host ""
    Write-Host "  Diagnóstico:" -ForegroundColor Yellow
    Write-Host "    1. Revisa el log: Get-Content $Root\agent\logs\agent.log -Tail 30"
    Write-Host "    2. Comprueba que BACKEND_URL y AGENT_TOKEN son correctos en agent\.env"
    Write-Host "    3. Verifica que el backend responde: Invoke-RestMethod $BackendUrl/status"
    Write-Host "    4. Estado completo: scripts\maintenance.ps1 -Action status"
}

$sunshine = Get-Process -Name 'sunshine' -ErrorAction SilentlyContinue
if ($sunshine) {
    Write-Host "  Sunshine: en ejecución (PID $($sunshine.Id -join ', '))" -ForegroundColor Green
} else {
    Write-Host "  Sunshine: el agente lo iniciará automáticamente en unos segundos."
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  PC DE STREAM LISTO" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Backend configurado: $BackendUrl" -ForegroundColor Green
Write-Host "  Agente conectado:    $(if ($agentOnline) { 'SÍ' } else { 'NO (ver diagnóstico arriba)' })" -ForegroundColor $(if ($agentOnline) { 'Green' } else { 'Red' })
Write-Host ""
Write-Host "  El agente arranca solo con Windows y se reconecta solo." -ForegroundColor Yellow
Write-Host "  Ya puedes cerrar esta ventana. En el PC dev abre la URL" -ForegroundColor Yellow
Write-Host "  pública del frontend y pulsa Conectar." -ForegroundColor Yellow
Write-Host ""
Write-Host "  Mantenimiento: scripts\maintenance.ps1 -Action status" -ForegroundColor Yellow
Write-Host ""
