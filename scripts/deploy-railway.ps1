<#
.SYNOPSIS
  Despliegue automatizado en Railway (CLI v5+, ya autenticado).
  Sintaxis verificada contra Railway CLI v5.45.x.

  Pasos:
    1. Verifica autenticación y vinculación del proyecto
    2. Crea los servicios que falten (railway add --service=<nombre>)
    3. Vincula cada carpeta a su servicio (railway service link <nombre>)
    4. Configura variables (railway variable set)
    5. Despliega con railway up --detach
    6. Genera dominios públicos (railway domain) y muestra la URL final

  Idempotente: reutiliza proyecto, servicios y dominios existentes.

.PARAMETER ProjectName
  Nombre del proyecto en Railway.

.PARAMETER AgentToken
  Token compartido entre el backend y el agente Windows.
#>
param(
    [string]$ProjectName = 'cloud-gaming',
    [Parameter(Mandatory = $true)]
    [string]$AgentToken
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path "$PSScriptRoot\..").Path

# Ejecuta railway suprimiendo stderr (el CLI emite ecos interactivos y avisos
# por stderr que PowerShell 5.1 confunde con errores). El código de salida
# sigue reflejando el resultado real.
function Invoke-Railway {
    param([string[]]$CmdArgs, [string]$WorkDir)
    Push-Location $WorkDir
    try {
        & railway @CmdArgs 2>$null | Out-String | Write-Host
        return $LASTEXITCODE
    } finally {
        Pop-Location
    }
}

function Get-ServiceNames {
    $out = (& railway service list --json 2>$null | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($out)) { return @() }
    try {
        $services = @($out | ConvertFrom-Json)
        return @($services | ForEach-Object { $_.name })
    } catch {
        return @()
    }
}

function Get-ServiceDomain([string]$ServiceName) {
    try {
        $out = (& railway domain list --service $ServiceName --json 2>$null | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($out)) { return $null }
        $json = $out | ConvertFrom-Json
        $domains = @()
        if ($json.domains) { $domains = @($json.domains) }
        elseif ($json -is [array]) { $domains = @($json) }
        foreach ($d in $domains) {
            $name = if ($d.domain) { $d.domain } elseif ($d.name) { $d.name } else { $null }
            if ($name) { return $name }
        }
        return $null
    } catch {
        return $null
    }
}

function Ensure-Domain([string]$ServiceName) {
    $domain = Get-ServiceDomain $ServiceName
    if ($domain) {
        Write-Host "  Dominio de '$ServiceName' existente: $domain"
        return $domain
    }
    # 'railway domain' sin argumentos genera un dominio Railway automático
    $code = Invoke-Railway -CmdArgs @('domain', '--service', $ServiceName) -WorkDir $Root
    if ($code -ne 0) { throw "No se pudo generar el dominio de $ServiceName" }
    $domain = Get-ServiceDomain $ServiceName
    if (-not $domain) { throw "El dominio de $ServiceName se generó pero no se pudo leer." }
    return $domain
}

function Ensure-Service([string]$Name) {
    $names = Get-ServiceNames
    if ($names -contains $Name) {
        Write-Host "  Servicio '$Name' ya existe; reutilizándolo."
        return
    }
    $code = Invoke-Railway -CmdArgs @('add', "--service=$Name") -WorkDir $Root
    if ($code -ne 0) { throw "railway add --service=$Name falló" }
    Write-Host "  Servicio '$Name' creado."
}

# ---------------------------------------------------------------
Write-Host "== 1/8 Proyecto Railway '$ProjectName' ==" -ForegroundColor Cyan
$status = (& railway status --json 2>$null | Out-String).Trim()
$linked = $false
if (-not [string]::IsNullOrWhiteSpace($status)) {
    try {
        $st = $status | ConvertFrom-Json
        $linked = ($st.project -eq $ProjectName) -or ($st.name -eq $ProjectName)
    } catch { $linked = $false }
}
if ($linked) {
    Write-Host "  Directorio ya vinculado al proyecto '$ProjectName'."
} else {
    $code = Invoke-Railway -CmdArgs @('init', '--name', $ProjectName) -WorkDir $Root
    if ($code -ne 0) { throw "railway init falló" }
}

# ---------------------------------------------------------------
Write-Host "== 2/8 Servicio backend ==" -ForegroundColor Cyan
Ensure-Service 'backend'

Write-Host "== 3/8 Servicio frontend ==" -ForegroundColor Cyan
Ensure-Service 'frontend'

# ---------------------------------------------------------------
# NOTA: en CLI v5 la vinculación de servicio se comparte entre subcarpetas
# del mismo proyecto, por lo que TODOS los comandos pasan --service de
# forma explícita en lugar de depender de 'railway service link'.
# ---------------------------------------------------------------
Write-Host "== 4/8 Variables del backend ==" -ForegroundColor Cyan
$code = Invoke-Railway -CmdArgs @('variable', 'set', "AGENT_TOKEN=$AgentToken", '--service', 'backend', '--skip-deploys') -WorkDir "$Root\backend"
if ($code -ne 0) { throw "railway variable set AGENT_TOKEN falló" }
$code = Invoke-Railway -CmdArgs @('variable', 'set', 'CORS_ORIGIN=*', '--service', 'backend', '--skip-deploys') -WorkDir "$Root\backend"
if ($code -ne 0) { throw "railway variable set CORS_ORIGIN falló" }

Write-Host "== 5/8 Desplegando backend ==" -ForegroundColor Cyan
# PATH + --path-as-root: sube SOLO la carpeta backend/ (sin esto, railway up
# sube el proyecto completo y el builder no encuentra el Dockerfile)
$code = Invoke-Railway -CmdArgs @('up', 'backend', '--path-as-root', '--service', 'backend', '--detach') -WorkDir $Root
if ($code -ne 0) { throw "railway up (backend) falló" }

$backendDomain = Ensure-Domain 'backend'
$backendUrl = "https://$backendDomain"
Write-Host "Backend URL: $backendUrl" -ForegroundColor Green

# ---------------------------------------------------------------
Write-Host "== 6/8 Variables del frontend ==" -ForegroundColor Cyan
$code = Invoke-Railway -CmdArgs @('variable', 'set', "VITE_BACKEND_URL=$backendUrl", '--service', 'frontend', '--skip-deploys') -WorkDir "$Root\frontend"
if ($code -ne 0) { throw "railway variable set VITE_BACKEND_URL falló" }

Write-Host "== 7/8 Desplegando frontend ==" -ForegroundColor Cyan
$code = Invoke-Railway -CmdArgs @('up', 'frontend', '--path-as-root', '--service', 'frontend', '--detach') -WorkDir $Root
if ($code -ne 0) { throw "railway up (frontend) falló" }

$frontendDomain = Ensure-Domain 'frontend'
$frontendUrl = "https://$frontendDomain"

# ---------------------------------------------------------------
Write-Host ""
Write-Host "== 8/8 Despliegue completado ==" -ForegroundColor Green
Write-Host ""
Write-Host "======================================================" -ForegroundColor Green
Write-Host "  URL PÚBLICA:  $frontendUrl" -ForegroundColor Green
Write-Host "  Backend:      $backendUrl" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Para el PC de stream (setup\start-stream.bat) usa:" -ForegroundColor Yellow
Write-Host "  URL del backend: $backendUrl"
Write-Host "  AGENT_TOKEN:     $AgentToken"
Write-Host ""
