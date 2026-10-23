# ============================================================================
# Uninstall-RDPWrap.ps1 - Desinstala TODO lo que configura el asistente:
#   1) RDP Wrapper (RDPWInst -u)          2) Regla de firewall propia
#   3) Exclusiones de Defender            4) Reactiva Windows Update
#   5) Usuario local 'rdp' y archivos .rdp del Escritorio
#   6) Opcional (-AlsoTailscale): desinstala Tailscale
#
# Uso: doble clic en Desinstalar.bat  o  powershell -File Uninstall-RDPWrap.ps1
#   -Force          sin confirmacion (automatizacion / IA)
#   -AlsoTailscale  tambien desinstala Tailscale
# Log: %TEMP%\RDPWrap-Uninstall.log
# ============================================================================
param([switch]$Force, [switch]$AlsoTailscale)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $self = $PSCommandPath; if (-not $self) { $self = $MyInvocation.MyCommand.Path }
    $args2 = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$self`"")
    if ($Force) { $args2 += '-Force' }
    if ($AlsoTailscale) { $args2 += '-AlsoTailscale' }
    try { Start-Process powershell -Verb RunAs -ErrorAction Stop -ArgumentList $args2 }
    catch { Write-Host 'Se requieren privilegios de administrador.' -ForegroundColor Yellow; pause }
    exit 1
}

$log = Join-Path $env:TEMP 'RDPWrap-Uninstall.log'
function Log($m) { $l = '{0:HH:mm:ss} {1}' -f (Get-Date), $m; Add-Content $log $l -Encoding utf8; Write-Host $l }
Log '=== desinstalacion RDP Wrapper | admin=True ==='

if (-not $Force) {
    Write-Host ''
    Write-Host 'Esto REVERTIRA toda la configuracion de RDP Wrapper en este equipo:' -ForegroundColor Yellow
    Write-Host '  wrapper, firewall, exclusiones Defender, Windows Update, usuario rdp'
    if ($AlsoTailscale) { Write-Host '  y TAMBIEN desinstalara Tailscale' -ForegroundColor Yellow }
    $r = Read-Host 'Escribe SI para continuar'
    if ($r -ne 'SI') { Log 'cancelado por el usuario'; exit 0 }
}

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }
$root = Split-Path -Parent $scriptDir
$installDir = "$env:ProgramFiles\RDP Wrapper"

# --- 1. RDP Wrapper -----------------------------------------------------------
$inst = @("$root\dist\RDPWInst.exe", "$root\bin\RDPWInst.exe", "$installDir\RDPWInst.exe") |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if ($inst) {
    Log "[..] Desinstalando RDP Wrapper ($inst -u)..."
    $out = & $inst -u 2>&1 | Out-String
    Log $out.Trim()
} else {
    Log '[..] RDPWInst.exe no encontrado; limpiando a mano...'
    Stop-Service termsrv -Force -ErrorAction SilentlyContinue
    Remove-Item $installDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:WINDIR\System32\rdpwrap.dll" -Force -ErrorAction SilentlyContinue
    $k = 'HKLM:\SYSTEM\CurrentControlSet\Services\TermService\Parameters'
    Set-ItemProperty -Path $k -Name 'ServiceDll' -Value "$env:WINDIR\System32\termsrv.dll" -ErrorAction SilentlyContinue
    Start-Service termsrv -ErrorAction SilentlyContinue
    Log '[OK] limpieza manual hecha (ServiceDll restaurado a termsrv.dll)'
}

# --- 2. Firewall ----------------------------------------------------------------
Log '[..] Restaurando firewall...'
Remove-NetFirewallRule -Name 'RDP-Wrapper-Tailscale-LAN' -ErrorAction SilentlyContinue
Get-NetFirewallRule -DisplayName 'Remote Desktop' -ErrorAction SilentlyContinue |
    Where-Object { ($_ | Get-NetFirewallPortFilter).LocalPort -eq '3389' } |
    Set-NetFirewallRule -RemoteAddress Any -ErrorAction SilentlyContinue
foreach ($r in 'RemoteDesktop-UserMode-In-TCP','RemoteDesktop-UserMode-In-UDP') {
    Enable-NetFirewallRule -Name $r -ErrorAction SilentlyContinue
}
Log '[OK] reglas RDP restauradas (puerto 3389 configuracion por defecto)'

# --- 3. Exclusiones Defender ------------------------------------------------------
Log '[..] Quitando exclusiones de Defender...'
Remove-MpPreference -ExclusionPath $installDir -ErrorAction SilentlyContinue
Remove-MpPreference -ExclusionPath "$env:WINDIR\System32\rdpwrap.dll" -ErrorAction SilentlyContinue
foreach ($p in 'RDPWInst.exe','RDPConf.exe','RDPCheck.exe') {
    Remove-MpPreference -ExclusionProcess $p -ErrorAction SilentlyContinue
}
Log '[OK] exclusiones eliminadas'

# --- 4. Windows Update --------------------------------------------------------------
Log '[..] Reactivando Windows Update...'
foreach ($s in 'wuauserv','UsoSvc') {
    Set-Service $s -StartupType Manual -ErrorAction SilentlyContinue
}
Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'NoAutoUpdate' -ErrorAction SilentlyContinue
Start-Service wuauserv -ErrorAction SilentlyContinue
Log '[OK] Windows Update reactivado (inicio manual)'

# --- 5. Usuario rdp y archivos ---------------------------------------------------------
if (Get-LocalUser -Name 'rdp' -ErrorAction SilentlyContinue) {
    Remove-LocalUser -Name 'rdp' -ErrorAction SilentlyContinue
    Log "[OK] usuario local 'rdp' eliminado"
} else { Log "[..] usuario 'rdp' no existia" }
$desktop = [Environment]::GetFolderPath('Desktop')
Get-ChildItem $desktop -Filter 'rdp-*.rdp' -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-Item $_.FullName -Force; Log "[OK] borrado $($_.Name)"
}
Get-ChildItem $desktop -Filter 'RDPWrap-Cliente-*.zip' -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-Item $_.FullName -Force; Log "[OK] borrado $($_.Name)"
}

# --- 6. Tailscale (opcional) -------------------------------------------------------------
if ($AlsoTailscale) {
    Log '[..] Desinstalando Tailscale...'
    Get-Process tailscale,tailscaled,tailscale-ipn -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    winget uninstall --id tailscale.tailscale --silent 2>&1 | Out-Null
    Remove-Item 'C:\ProgramData\Tailscale' -Recurse -Force -ErrorAction SilentlyContinue
    Log '[OK] Tailscale desinstalado'
} else {
    Log '[..] Tailscale se conserva (usa -AlsoTailscale para quitarlo)'
}

Log '=== desinstalacion terminada ==='
Write-Host ''
Write-Host 'Listo. Recomendado reiniciar el equipo.' -ForegroundColor Green
if (-not $Force) { pause }
