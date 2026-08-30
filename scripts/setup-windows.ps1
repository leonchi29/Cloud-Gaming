#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Configura Windows 10 para que el PC permanezca siempre encendido y disponible
  para el escritorio remoto (nunca suspender, nunca hibernar, discos y red siempre activos).
#>

Write-Host "== Configurando energía de Windows 10 para Cloud Gaming ==" -ForegroundColor Cyan

# Nunca suspender (AC y batería)
powercfg /change standby-timeout-ac 0
powercfg /change standby-timeout-dc 0

# Nunca hibernar
powercfg /change hibernate-timeout-ac 0
powercfg /change hibernate-timeout-dc 0
powercfg /hibernate off

# Nunca apagar discos
powercfg /change disk-timeout-ac 0
powercfg /change disk-timeout-dc 0

# Nunca apagar la pantalla por inactividad (opcional: mantiene la sesión gráfica activa)
powercfg /change monitor-timeout-ac 0
powercfg /change monitor-timeout-dc 0

# Plan de energía en Alto rendimiento
$highPerformance = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
powercfg /setactive $highPerformance 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Warning "No se pudo activar el plan Alto rendimiento; se mantiene el plan actual."
}

# Desactivar ahorro de energía USB (suspensión selectiva)
powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0

# Desactivar ahorro de energía PCIe
powercfg /setacvalueindex SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0

# Aplicar cambios
powercfg /setactive SCHEME_CURRENT

# Nunca apagar adaptadores de red (ahorro de energía)
Write-Host "== Desactivando ahorro de energía en adaptadores de red ==" -ForegroundColor Cyan
try {
    Get-NetAdapter -Physical | ForEach-Object {
        Disable-NetAdapterPowerManagement -Name $_.Name -ErrorAction SilentlyContinue
        Write-Host "  Ahorro de energía desactivado en: $($_.Name)"
    }
} catch {
    Write-Warning "Disable-NetAdapterPowerManagement no disponible; usando WMI."
}

# Método alternativo vía WMI (cubre adaptadores no gestionados por NetAdapter)
try {
    $powerDevices = Get-WmiObject MSPower_DeviceEnable -Namespace root\wmi -ErrorAction Stop
    foreach ($device in $powerDevices) {
        if ($device.InstanceName -match 'PCI|USB|Net') {
            $device.Enable = $false
            $device.Put() | Out-Null
        }
    }
    Write-Host "  Ahorro de energía desactivado vía WMI." 
} catch {
    Write-Warning "No se pudo aplicar la configuración WMI de energía: $($_.Exception.Message)"
}

# Mantener la red activa: desactivar desconexión automática por inactividad
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" -Name "KeepConn" -Value 86400 -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Configuración de energía completada." -ForegroundColor Green
Write-Host "El sistema nunca se suspenderá, hibernará ni apagará discos/adaptadores de red."
