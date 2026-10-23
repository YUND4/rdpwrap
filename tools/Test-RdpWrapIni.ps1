# Valida la integridad de res\rdpwrap.ini (usado en CI y localmente).
# Exit 0 = valido, Exit 1 = errores encontrados.
[CmdletBinding()]
param([string]$IniPath)

# Resolucion robusta de la ruta del INI (algunos hosts no definen $PSScriptRoot)
if (-not $IniPath) {
    $scriptDir = $PSScriptRoot
    if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
    $candidates = @()
    if ($scriptDir) { $candidates += Join-Path $scriptDir '..\res\rdpwrap.ini' }
    $candidates += Join-Path (Get-Location).Path 'res\rdpwrap.ini'
    $candidates += Join-Path (Get-Location).Path '..\res\rdpwrap.ini'
    $IniPath = ($candidates | Where-Object { Test-Path $_ } | Select-Object -First 1)
}

$errors = 0
if (-not (Test-Path $IniPath)) {
    Write-Host "[-] No existe: $IniPath"
    exit 1
}

$lines = Get-Content $IniPath
$sections = [regex]::Matches(($lines -join "`n"), '^\[(.+?)\]', 'Multiline') | ForEach-Object { $_.Groups[1].Value }

# 1. Secciones obligatorias
foreach ($req in @('Main', 'SLPolicy', 'PatchCodes')) {
    if ($sections -notcontains $req) {
        Write-Host "[-] Falta seccion obligatoria [$req]"
        $errors++
    }
}

# 2. Secciones duplicadas
$dups = $sections | Group-Object | Where-Object Count -gt 1
foreach ($d in $dups) {
    Write-Host "[-] Seccion duplicada: [$($d.Name)] ($($d.Count) veces)"
    $errors++
}

# 3. Cada build debe tener su seccion -SLInit (y viceversa)
$builds  = $sections | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' }
$slinits = $sections | Where-Object { $_ -match '^(\d+\.\d+\.\d+\.\d+)-SLInit$' } | ForEach-Object { $Matches[1] }
foreach ($b in $builds) {
    if ($slinits -notcontains $b) {
        Write-Host "[!] Build [$b] sin seccion SLInit (puede ser intencional en builds viejos)"
    }
}
foreach ($s in $slinits) {
    if ($builds -notcontains $s) {
        Write-Host "[-] Seccion [$s-SLInit] huerfana: no existe el build [$s]"
        $errors++
    }
}

# 4. Fecha de actualizacion presente
if ($lines -notcontains ($lines | Select-String '^Updated=\d{4}-\d{2}-\d{2}' | Select-Object -First 1).Line) {
    Write-Host "[!] No se encontro linea 'Updated=YYYY-MM-DD' en [Main]"
}

Write-Host ""
Write-Host "[*] $($builds.Count) builds soportados, $($sections.Count) secciones totales"
if ($errors -gt 0) {
    Write-Host "[-] Validacion FALLIDA con $errors error(es)"
    exit 1
}
Write-Host "[+] Validacion OK"
exit 0
