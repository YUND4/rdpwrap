# ============================================================================
# Reparar-Tailscale.ps1 - Repara Tailscale pegado ("is starting" / NoState)
#
# Flujo automatico:
#   1) Mata procesos Tailscale colgados
#   2) Reinstala limpio con winget y borra el estado corrupto
#   3) Lanza 'tailscale up' y ABRE el navegador con la URL de login
#   4) Espera a que el usuario autorice (hasta 15 min)
#   5) Al conectar, regenera el paquete cliente en el Escritorio
#
# Uso: doble clic en Reparar-Tailscale.bat (se auto-eleva) o:
#   powershell -ExecutionPolicy Bypass -File Reparar-Tailscale.ps1
# Log: %TEMP%\RDPWrap-Tailscale-Repair.log
# ============================================================================
param([switch]$NoExport)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $self = $PSCommandPath; if (-not $self) { $self = $MyInvocation.MyCommand.Path }
    try { Start-Process powershell -Verb RunAs -ErrorAction Stop -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$self`"" }
    catch { Write-Host 'Se requieren privilegios de administrador.' -ForegroundColor Yellow; pause }
    exit 1
}

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

$log = Join-Path $env:TEMP 'RDPWrap-Tailscale-Repair.log'
function Log($m) { $l = '{0:HH:mm:ss} {1}' -f (Get-Date), $m; Add-Content $log $l -Encoding utf8; Write-Host $l }
Log '=== reparacion de Tailscale | admin=True ==='

$exe = 'C:\Program Files\Tailscale\tailscale.exe'

# --- 1. Matar procesos colgados ----------------------------------------------
Log 'matando procesos Tailscale...'
Get-Process tailscale,tailscaled,tailscale-ipn -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# --- 2. Reinstalar limpio -----------------------------------------------------
Log 'desinstalando...'
winget uninstall --id tailscale.tailscale --silent 2>&1 | Out-Null
Start-Sleep -Seconds 3
Get-Process tailscale,tailscaled,tailscale-ipn -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Remove-Item 'C:\ProgramData\Tailscale' -Recurse -Force -ErrorAction SilentlyContinue
Log 'estado corrupto eliminado, instalando la ULTIMA version...'
# Preferir el MSI mas reciente directo de Tailscale (winget a veces ofrece una
# version vieja cuyo driver Wintun no sirve en builds nuevas de Windows)
$msi = Join-Path $env:TEMP 'tailscale-setup-latest-amd64.msi'
$installed = $false
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri 'https://pkgs.tailscale.com/stable/tailscale-setup-latest-amd64.msi' -OutFile $msi -UseBasicParsing -ErrorAction Stop
    Log 'MSI descargado, instalando...'
    $rc = (Start-Process msiexec.exe -Wait -PassThru -ArgumentList '/i',"`"$msi`"",'/quiet','/norestart').ExitCode
    Log "msiexec exit code: $rc"
    $installed = (Test-Path $exe)
} catch { Log "descarga directa fallo ($($_.Exception.Message)); usando winget" }
if (-not $installed) {
    winget install --id tailscale.tailscale --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-Null
}
if (-not (Test-Path $exe)) { Log '[X] FALLO: Tailscale no quedo instalado.'; pause; exit 1 }
Log "[OK] Tailscale $((& $exe version 2>$null | Select-Object -First 1)) instalado"

Start-Service Tailscale -ErrorAction SilentlyContinue
Start-Sleep -Seconds 10

# --- 3. tailscale up con URL auto-abierta --------------------------------------
$outF = Join-Path $env:TEMP 'ts-up-output.txt'
Remove-Item $outF -Force -ErrorAction SilentlyContinue
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exe; $psi.Arguments = 'up'
$psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
$psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
$proc = [System.Diagnostics.Process]::Start($psi)
$writer = New-Object System.IO.StreamWriter($outF, $false)
$onData = { param($s, $e) if ($e.Data) { $writer.WriteLine($e.Data); $writer.Flush() } }
$proc.add_OutputDataReceived($onData); $proc.add_ErrorDataReceived($onData)
$proc.BeginOutputReadLine(); $proc.BeginErrorReadLine()
Log "proceso 'up' lanzado (pid $($proc.Id)); NO se mata: sale solo al conectar"

# --- 4. Esperar login (hasta 15 min) ------------------------------------------
$connected = $false; $urlOpened = $false
foreach ($i in 1..180) {
    Start-Sleep -Seconds 5
    $ip = & $exe ip -4 2>$null | Select-Object -First 1
    if ($ip -and "$ip".Trim() -match '^100\.') { Log "[OK] CONECTADO: $($ip.Trim())"; $connected = $true; break }
    if (-not $urlOpened -and (Test-Path $outF)) {
        $raw = Get-Content $outF -Raw -ErrorAction SilentlyContinue
        if ($raw -match 'https://login\.tailscale\.com/a/\w+') {
            $url = $Matches[0]
            Log "URL de login: $url  -> abriendo navegador..."
            Start-Process $url
            $urlOpened = $true
        }
    }
}
if ($proc -and -not $proc.HasExited -and -not $connected) { try { $proc.Kill() } catch {} }

if (-not $connected) { Log '[X] No conecto en 15 min. Vuelve a ejecutar este script.'; pause; exit 1 }

# --- 5. Regenerar paquete cliente ----------------------------------------------
Start-Sleep -Seconds 5
if (-not $NoExport -and (Test-Path "$scriptDir\RDPWrap-Setup-Wizard.ps1")) {
    Log 'regenerando paquete cliente...'
    $env:RDPWRAP_WIZARD_AUTOPILOT = '1'
    & "$scriptDir\RDPWrap-Setup-Wizard.ps1"
    $zip = Get-Item "$([Environment]::GetFolderPath('Desktop'))\RDPWrap-Cliente-*.zip" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($zip) { Log "[OK] paquete cliente: $($zip.FullName)"; Start-Process explorer.exe -ArgumentList "/select,`"$($zip.FullName)`"" }
}
Log '=== reparacion terminada con exito ==='
Write-Host ''
Write-Host 'Tailscale reparado y conectado. Puedes cerrar esta ventana.' -ForegroundColor Green
Start-Sleep -Seconds 10
