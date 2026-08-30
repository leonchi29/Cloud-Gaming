#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Modo tapa cerrada: al cerrar la tapa del portátil el sistema NO hace nada
  y el escritorio remoto sigue disponible (red, Sunshine y agente activos).
#>

Write-Host "== Configurando modo tapa cerrada ==" -ForegroundColor Cyan

# SUB_BUTTONS / LIDACTION = 0  →  "No hacer nada" al cerrar la tapa
# GUID SUB_BUTTONS: 4f971e89-eebd-4455-a8de-9e59040e7347
# GUID LIDACTION:   5ca83367-6e45-459f-a27b-476b1d01c936
powercfg /setacvalueindex SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936 0
powercfg /setdcvalueindex SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936 0

# Botón de encendido: no hacer nada (evita apagados accidentales) - opcional pero recomendado
# GUID PBUTTONACTION: 7648efa3-dd9c-4e3e-b566-50f929386280
powercfg /setacvalueindex SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 7648efa3-dd9c-4e3e-b566-50f929386280 0
powercfg /setdcvalueindex SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 7648efa3-dd9c-4e3e-b566-50f929386280 0

# Nunca suspender ni hibernar aunque la tapa esté cerrada
powercfg /change standby-timeout-ac 0
powercfg /change standby-timeout-dc 0
powercfg /change hibernate-timeout-ac 0
powercfg /change hibernate-timeout-dc 0
powercfg /hibernate off

powercfg /setactive SCHEME_CURRENT

# Mantener la red activa con la tapa cerrada: desactivar ahorro de energía de adaptadores
try {
    Get-NetAdapter -Physical | ForEach-Object {
        Disable-NetAdapterPowerManagement -Name $_.Name -ErrorAction SilentlyContinue
    }
    Write-Host "Adaptadores de red: ahorro de energía desactivado."
} catch {
    Write-Warning "No se pudo desactivar el ahorro de energía de red automáticamente."
}

# Deshabilitar "Modern Standby" si el equipo lo soporta (mantiene el sistema plenamente activo)
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
try {
    Set-ItemProperty -Path $regPath -Name "PlatformAoAcOverride" -Value 0 -ErrorAction Stop
    Write-Host "Modern Standby deshabilitado (PlatformAoAcOverride=0)."
} catch {
    Write-Warning "No se pudo deshabilitar Modern Standby (puede no aplicar en este equipo)."
}

Write-Host ""
Write-Host "Modo tapa cerrada configurado." -ForegroundColor Green
Write-Host "Al cerrar la tapa el sistema seguirá encendido, con red, Sunshine y agente activos."
Write-Host "Verifica que Sunshine y el agente estén en ejecución:" -ForegroundColor Yellow
Write-Host "  Get-Process sunshine"
Write-Host "  Get-ScheduledTask -TaskName 'CloudGamingAgent' | Get-ScheduledTaskInfo"
