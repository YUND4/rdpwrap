# Configura exclusiones de Windows Defender para RDP Wrapper.
# RECOMENDADO sobre desactivar Defender por completo.
# Uso: powershell -ExecutionPolicy Bypass -File defender-exclusions.ps1 [-Full] [-Remove]
[CmdletBinding()]
param(
    [switch]$Full,    # ADVERTENCIA: desactiva la proteccion en tiempo real (no recomendado)
    [switch]$Remove   # Quita las exclusiones creadas por este script
)

$ErrorActionPreference = 'Stop'
$paths = @(
    "$env:ProgramFiles\RDP Wrapper",
    "$env:WINDIR\System32\rdpwrap.dll"
)
$processes = @('RDPWInst.exe', 'RDPConf.exe', 'RDPCheck.exe')

# Requiere admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[-] Ejecuta este script como administrador."; exit 1
}

if ($Remove) {
    foreach ($p in $paths)    { Remove-MpPreference -ExclusionPath $p -ErrorAction SilentlyContinue }
    foreach ($pr in $processes) { Remove-MpPreference -ExclusionProcess $pr -ErrorAction SilentlyContinue }
    Write-Host "[+] Exclusiones eliminadas."
    exit 0
}

foreach ($p in $paths)    { Add-MpPreference -ExclusionPath $p;    Write-Host "[+] Exclusion (ruta):    $p" }
foreach ($pr in $processes) { Add-MpPreference -ExclusionProcess $pr; Write-Host "[+] Exclusion (proceso): $pr" }

if ($Full) {
    Write-Host ""
    Write-Host "[!] ADVERTENCIA: desactivar la proteccion en tiempo real deja el equipo expuesto." -ForegroundColor Yellow
    Write-Host "[!] Preferible: mantener solo las exclusiones anteriores."
    Write-Host "[!] Si Tamper Protection esta activo, esta operacion fallara (desactivalo manualmente en Seguridad de Windows)."
    Set-MpPreference -DisableRealtimeMonitoring $true
    Write-Host "[!] Proteccion en tiempo real DESACTIVADA."
}

Write-Host ""
Write-Host "[*] Estado actual de exclusiones:"
(Get-MpPreference).ExclusionPath | Where-Object { $_ -like '*RDP*' } | ForEach-Object { "    $_" }
