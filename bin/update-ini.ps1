# Actualiza rdpwrap.ini desde el fork mantenido (YUND4/rdpwrap).
# Uso: powershell -ExecutionPolicy Bypass -File update-ini.ps1 [-InstallDir <ruta>]
[CmdletBinding()]
param(
    [string]$InstallDir = "$env:ProgramFiles\RDP Wrapper",
    [string]$RepoRaw = "https://raw.githubusercontent.com/YUND4/rdpwrap/master/res/rdpwrap.ini"
)

$ErrorActionPreference = 'Stop'
$iniPath = Join-Path $InstallDir 'rdpwrap.ini'
$tmpFile = Join-Path $env:TEMP "rdpwrap-$([Guid]::NewGuid().ToString('N')).ini"

try {
    Write-Host "[*] Descargando INI actualizado desde $RepoRaw ..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $RepoRaw -OutFile $tmpFile -UseBasicParsing

    # Validación mínima: debe tener secciones [Main] y [SLPolicy]
    $content = Get-Content $tmpFile -Raw
    if ($content -notmatch '\[Main\]' -or $content -notmatch '\[SLPolicy\]') {
        throw "El archivo descargado no parece un rdpwrap.ini válido."
    }

    # Backup del INI anterior antes de reemplazar
    if (Test-Path $iniPath) {
        $backup = "$iniPath.bak"
        Copy-Item $iniPath $backup -Force
        Write-Host "[*] Backup del INI anterior: $backup"
    }

    Copy-Item $tmpFile $iniPath -Force
    $builds = ([regex]::Matches($content, '^\[\d+\.\d+\.\d+\.\d+\]', 'Multiline')).Count
    Write-Host "[+] INI actualizado en $iniPath ($builds builds soportados)"
    exit 0
}
catch {
    Write-Host "[-] Error al actualizar el INI: $($_.Exception.Message)"
    exit 1
}
finally {
    Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
}
