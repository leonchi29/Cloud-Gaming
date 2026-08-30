#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Desinstala la tarea programada del agente Cloud Gaming.
#>

$TaskName = 'CloudGamingAgent'

Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

Write-Host "Agente desinstalado." -ForegroundColor Green
