# Runner elevado: exclusiones Defender + instalacion de RDP Wrapper
$ErrorActionPreference = 'Continue'
Set-Location $PSScriptRoot

Write-Host "=== 1. Exclusiones en Windows Defender ===" -ForegroundColor Cyan
& "$PSScriptRoot\defender-exclusions.ps1"

Write-Host ""
Write-Host "=== 2. Instalacion de RDP Wrapper ===" -ForegroundColor Cyan
& "$PSScriptRoot\RDPWInst.exe" -i

Write-Host ""
Write-Host "=== 3. Estado del servicio ===" -ForegroundColor Cyan
Get-Service TermService | Format-Table Name, Status, StartType -AutoSize
$listener = Get-NetTCPConnection -LocalPort 3389 -State Listen -ErrorAction SilentlyContinue
if ($listener) { Write-Host "[+] Listener RDP activo en puerto 3389" -ForegroundColor Green }
else { Write-Host "[!] No se detecta listener en 3389 (reinicia el equipo o TermService)" -ForegroundColor Yellow }

Write-Host ""
Write-Host "Instalacion finalizada. Presiona una tecla para cerrar..."
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
