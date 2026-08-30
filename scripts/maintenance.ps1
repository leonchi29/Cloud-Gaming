<#
.SYNOPSIS
  Comandos de mantenimiento del host Cloud Gaming.
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('status', 'restart-agent', 'restart-sunshine', 'logs', 'health')]
    [string]$Action
)

$TaskName = 'CloudGamingAgent'

switch ($Action) {
    'status' {
        Write-Host "== Estado del sistema Cloud Gaming ==" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "-- Agente (tarea programada) --"
        try {
            $info = Get-ScheduledTask -TaskName $TaskName | Get-ScheduledTaskInfo
            $task = Get-ScheduledTask -TaskName $TaskName
            Write-Host "  Estado:             $($task.State)"
            Write-Host "  Última ejecución:   $($info.LastRunTime)"
            Write-Host "  Último resultado:   $($info.LastTaskResult)"
            Write-Host "  Próxima ejecución:  $($info.NextRunTime)"
        } catch {
            Write-Host "  La tarea '$TaskName' no está instalada." -ForegroundColor Yellow
        }
        Write-Host ""
        Write-Host "-- Sunshine --"
        $sunshine = Get-Process -Name 'sunshine' -ErrorAction SilentlyContinue
        if ($sunshine) {
            Write-Host "  En ejecución (PID: $($sunshine.Id -join ', '))" -ForegroundColor Green
        } else {
            Write-Host "  Detenido" -ForegroundColor Red
        }
        Write-Host ""
        Write-Host "-- Node (agente) --"
        $node = Get-Process -Name 'node' -ErrorAction SilentlyContinue
        if ($node) {
            $node | ForEach-Object { Write-Host "  PID $($_.Id) - iniciado $($_.StartTime)" }
        } else {
            Write-Host "  No hay procesos node en ejecución." -ForegroundColor Yellow
        }
    }
    'restart-agent' {
        Write-Host "Reiniciando agente..." -ForegroundColor Cyan
        Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        Get-Process -Name 'node' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Start-ScheduledTask -TaskName $TaskName
        Write-Host "Agente reiniciado." -ForegroundColor Green
    }
    'restart-sunshine' {
        Write-Host "Reiniciando Sunshine..." -ForegroundColor Cyan
        Get-Process -Name 'sunshine' -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 2
        $sunshinePath = "${env:ProgramFiles}\Sunshine\sunshine.exe"
        if (Test-Path $sunshinePath) {
            Start-Process $sunshinePath
            Write-Host "Sunshine reiniciado." -ForegroundColor Green
        } else {
            Write-Host "No se encontró $sunshinePath" -ForegroundColor Red
        }
    }
    'health' {
        Write-Host "Comprobaciones rápidas:" -ForegroundColor Cyan
        Write-Host "  Sunshine: $((Get-Process -Name 'sunshine' -ErrorAction SilentlyContinue) -ne $null)"
        Write-Host "  Node:     $((Get-Process -Name 'node' -ErrorAction SilentlyContinue) -ne $null)"
        $net = Get-NetAdapter | Where-Object Status -eq 'Up'
        Write-Host "  Red:      $($net.Count) adaptador(es) activo(s)"
    }
    'logs' {
        $logFile = Join-Path (Resolve-Path "$PSScriptRoot\..\agent").Path 'logs\agent.log'
        if (Test-Path $logFile) {
            Write-Host "== Últimas 40 líneas de $logFile ==" -ForegroundColor Cyan
            Get-Content $logFile -Tail 40
        } else {
            Write-Host "No existe $logFile todavía (el agente aún no ha escrito logs)." -ForegroundColor Yellow
        }
    }
}
