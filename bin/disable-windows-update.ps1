# Desactiva (o reactiva) Windows Update.
# MOTIVO: evitar que una actualizacion cambie termsrv.dll y rompa RDP Wrapper.
# ADVERTENCIA: sin Windows Update el equipo NO recibe parches de seguridad.
#   Alternativa menos agresiva: pausar actualizaciones desde Configuracion,
#   o ejecutar bin\update.bat cuando RDPConf muestre [not supported].
# Uso: powershell -ExecutionPolicy Bypass -File disable-windows-update.ps1 [-Restore]
[CmdletBinding()]
param([switch]$Restore)

$ErrorActionPreference = 'Stop'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[-] Ejecuta este script como administrador."; exit 1
}

$auKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
$services = @('wuauserv', 'UsoSvc')

if ($Restore) {
    foreach ($s in $services) {
        Set-Service $s -StartupType Manual -ErrorAction SilentlyContinue
    }
    Remove-ItemProperty -Path $auKey -Name 'NoAutoUpdate' -ErrorAction SilentlyContinue
    Write-Host "[+] Windows Update RESTAURADO (inicio manual, sin politica de bloqueo)."
    Write-Host "    Nota: WaaSMedicSvc se reactiva solo; verifica en Configuracion > Windows Update."
    exit 0
}

Write-Host "[!] ADVERTENCIA: esto desactiva las actualizaciones automaticas de Windows." -ForegroundColor Yellow
Write-Host "[!] El equipo dejara de recibir parches de seguridad hasta que uses -Restore."

foreach ($s in $services) {
    Stop-Service $s -Force -ErrorAction SilentlyContinue
    Set-Service $s -StartupType Disabled
    Write-Host "[+] Servicio $s detenido y deshabilitado"
}

# Politica: no buscar/descargar/instalar actualizaciones automaticamente
New-Item -Path $auKey -Force | Out-Null
Set-ItemProperty -Path $auKey -Name 'NoAutoUpdate' -Value 1 -Type DWord
Write-Host "[+] Politica NoAutoUpdate=1 aplicada en HKLM"

Write-Host ""
Write-Host "[+] Windows Update desactivado. Para revertir: .\disable-windows-update.ps1 -Restore"
