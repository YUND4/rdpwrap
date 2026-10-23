# ============================================================================
# RDP Wrapper - Instalador del equipo CLIENTE
# Prepara ESTE equipo para conectarse por RDP al host {{HOST}}:
#   1) Instala Tailscale (si falta)   2) Abre el login de Tailscale
#   3) Copia los .rdp al Escritorio   4) Muestra las credenciales
# Requiere administrador (se auto-eleva por UAC).
# ============================================================================

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $self = $PSCommandPath
    if (-not $self) { $self = $MyInvocation.MyCommand.Path }
    try {
        Start-Process powershell -Verb RunAs -ErrorAction Stop -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$self`""
    } catch {
        Write-Host 'Se requieren privilegios de administrador. Vuelve a ejecutarlo y acepta el UAC.' -ForegroundColor Yellow
        pause
    }
    exit 1
}

$ErrorActionPreference = 'Continue'
$dir = $PSScriptRoot
if (-not $dir) { $dir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $dir) { $dir = (Get-Location).Path }
$log = Join-Path $env:TEMP 'RDPWrap-Client.log'
function Log($m) { $l = '{0:HH:mm:ss} {1}' -f (Get-Date), $m; Add-Content $log $l -Encoding utf8; Write-Host $l }
Log '=== instalador cliente | admin=True ==='

# --- 1. Tailscale -----------------------------------------------------------
$tsExe = 'C:\Program Files\Tailscale\tailscale.exe'
if (Test-Path $tsExe) {
    Log '[OK] Tailscale ya esta instalado'
} else {
    Log '[..] Instalando Tailscale (winget)...'
    winget install --id tailscale.tailscale --accept-source-agreements --accept-package-agreements | Out-Null
    if (Test-Path $tsExe) { Log '[OK] Tailscale instalado' }
    else { Log '[X] No se pudo instalar Tailscale. Instalalo manual desde https://tailscale.com/download' }
}

# --- 2. Login ----------------------------------------------------------------
if (Test-Path $tsExe) {
    $state = (& $tsExe status --json 2>$null | ConvertFrom-Json).BackendState
    if ($state -eq 'Running') {
        Log '[OK] Tailscale ya esta conectado'
    } else {
        Log '[..] Abriendo login de Tailscale...'
        Write-Host ''
        Write-Host 'IMPORTANTE: inicia sesion con LA MISMA cuenta Tailscale que usaste en el host.' -ForegroundColor Yellow
        Start-Process $tsExe -ArgumentList 'up'
    }
}

# --- 3. Copiar .rdp al Escritorio --------------------------------------------
$desktop = [Environment]::GetFolderPath('Desktop')
Get-ChildItem $dir -Filter '*.rdp' | ForEach-Object {
    Copy-Item $_.FullName $desktop -Force
    Log "[OK] $($_.Name) copiado al Escritorio"
}

# --- 4. Credenciales ----------------------------------------------------------
$cred = Join-Path $dir 'credenciales.txt'
Write-Host ''
Write-Host '==================================================' -ForegroundColor Cyan
if (Test-Path $cred) { Get-Content $cred | Write-Host } else { Write-Host 'credenciales.txt no encontrado en este paquete.' }
Write-Host '==================================================' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Listo. Para conectarte:' -ForegroundColor Green
Write-Host '  - Misma red (LAN):  abre rdp-{{HOST}}.rdp del Escritorio'
Write-Host '  - Desde internet:   abre rdp-{{HOST}}-tailscale.rdp (requiere Tailscale conectado aqui)'
Log 'fin del instalador cliente'
pause
