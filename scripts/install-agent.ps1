#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Instala el agente Cloud Gaming como tarea programada de Windows:
  - Se inicia automáticamente al arrancar el sistema (sin necesidad de login).
  - Se ejecuta en segundo plano.
  - Se reinicia automáticamente si falla.

.PARAMETER AgentPath
  Ruta absoluta a la carpeta del agente compilado (donde está dist\index.js).
#>
param(
    [string]$AgentPath = (Resolve-Path "$PSScriptRoot\..\agent").Path
)

$ErrorActionPreference = 'Stop'
$TaskName = 'CloudGamingAgent'
$EntryPoint = Join-Path $AgentPath 'dist\index.js'
$EnvFile = Join-Path $AgentPath '.env'

Write-Host "== Instalando agente Cloud Gaming como tarea programada ==" -ForegroundColor Cyan

if (-not (Test-Path $EntryPoint)) {
    Write-Error "No se encontró $EntryPoint. Ejecuta primero: cd agent; npm install; npm run build"
    exit 1
}

if (-not (Test-Path $EnvFile)) {
    Write-Warning "No existe $EnvFile. Copia .env.example a .env y configura BACKEND_URL y AGENT_TOKEN."
}

$nodePath = (Get-Command node -ErrorAction Stop).Source
Write-Host "Node.js: $nodePath"
Write-Host "Agente:  $EntryPoint"

# Comando: carga variables de .env y arranca el agente
$command = @"
`$envFile = '$EnvFile'
if (Test-Path `$envFile) {
    Get-Content `$envFile | ForEach-Object {
        if (`$_ -match '^\s*([^#][^=]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable(`$matches[1].Trim(), `$matches[2].Trim(), 'Process')
        }
    }
}
Set-Location '$AgentPath'
& '$nodePath' '$EntryPoint'
"@

$wrapperPath = Join-Path $AgentPath 'start-agent.ps1'
Set-Content -Path $wrapperPath -Value $command -Encoding UTF8
Write-Host "Wrapper creado: $wrapperPath"

# Eliminar tarea previa si existe
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$wrapperPath`""

# Inicio automático con Windows (sin login) + repetición cada minuto como watchdog
$triggerBoot = New-ScheduledTaskTrigger -AtStartup
$triggerLogon = New-ScheduledTaskTrigger -AtLogOn

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartCount 999 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew

# Ejecutar como SYSTEM con máximos privilegios → funciona sin sesión iniciada y en segundo plano
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $triggerBoot, $triggerLogon `
    -Settings $settings `
    -Principal $principal `
    -Description 'Agente de escritorio remoto Cloud Gaming' | Out-Null

Start-ScheduledTask -TaskName $TaskName

Write-Host ""
Write-Host "Agente instalado y arrancado." -ForegroundColor Green
Write-Host "  Ver estado:    Get-ScheduledTask -TaskName '$TaskName' | Get-ScheduledTaskInfo"
Write-Host "  Detener:       Stop-ScheduledTask -TaskName '$TaskName'"
Write-Host "  Desinstalar:   Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false"
