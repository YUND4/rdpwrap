# ============================================================================
# Empaquetar-host.ps1 - Genera el zip de instalacion para el equipo HOST
# Salida: dist\packages\RDPWrap-Host-Setup.zip (y copia en el Escritorio)
# ============================================================================
$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }
$root = Split-Path -Parent $scriptDir   # installer/ -> raiz del repo

# Verificar piezas obligatorias
$need = @(
    "$scriptDir\RDPWrap-Setup-Wizard.ps1",
    "$scriptDir\Iniciar asistente.bat",
    "$scriptDir\cliente",
    "$root\res\rdpwrap.ini",
    "$root\dist\RDPWInst.exe"
)
foreach ($n in $need) {
    if (-not (Test-Path $n)) { throw "Falta: $n (descarga los binarios 1.6.2 a dist\)" }
}

$stage = Join-Path $env:TEMP 'rdpwrap-host-pkg\RDPWrap-Host-Setup'
Remove-Item (Split-Path $stage) -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path "$stage\installer","$stage\res","$stage\dist" -Force | Out-Null

Copy-Item "$scriptDir\RDPWrap-Setup-Wizard.ps1" "$stage\installer\"
Copy-Item "$scriptDir\Iniciar asistente.bat"    "$stage\installer\"
Copy-Item "$scriptDir\Uninstall-RDPWrap.ps1"    "$stage\installer\"
Copy-Item "$scriptDir\Desinstalar.bat"          "$stage\installer\"
Copy-Item "$scriptDir\Reparar-Tailscale.ps1"    "$stage\installer\"
Copy-Item "$scriptDir\Reparar-Tailscale.bat"    "$stage\installer\"
Copy-Item "$scriptDir\cliente"                  "$stage\installer\" -Recurse
Copy-Item "$scriptDir\README-PAQUETE.md"        "$stage\README.md"
Copy-Item "$root\docs\guia-instalacion.md"      "$stage\GUIA.md"
Copy-Item "$root\res\rdpwrap.ini"               "$stage\res\"
foreach ($b in 'RDPWInst.exe','RDPConf.exe','RDPCheck.exe') {
    $src = "$root\dist\$b"
    if (Test-Path $src) { Copy-Item $src "$stage\dist\" }
}

$outDir = "$root\dist\packages"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$zip = "$outDir\RDPWrap-Host-Setup.zip"
Remove-Item $zip -Force -ErrorAction SilentlyContinue
Compress-Archive -Path $stage -DestinationPath $zip -CompressionLevel Optimal
Remove-Item (Split-Path $stage) -Recurse -Force -ErrorAction SilentlyContinue

$desktopZip = Join-Path ([Environment]::GetFolderPath('Desktop')) 'RDPWrap-Host-Setup.zip'
Copy-Item $zip $desktopZip -Force

Write-Host ''
Write-Host "Paquete HOST generado:" -ForegroundColor Green
Write-Host "  $zip"
Write-Host "  $desktopZip (copia en el Escritorio)"
Write-Host ''
Write-Host 'Contenido:'
[System.IO.Compression.ZipFile]::OpenRead($zip).Entries | ForEach-Object { "  $($_.FullName)" }
