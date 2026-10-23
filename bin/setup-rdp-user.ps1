# Crea un usuario local dedicado para RDP y un archivo .rdp exportable.
# Uso: powershell -ExecutionPolicy Bypass -File setup-rdp-user.ps1 [-Username rdp] [-OutDir <ruta>]
[CmdletBinding()]
param(
    [string]$Username = 'rdp',
    [string]$OutDir = "$env:USERPROFILE\Desktop"
)

$ErrorActionPreference = 'Stop'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[-] Ejecuta este script como administrador."; exit 1
}

# Generar contrasena robusta (20 chars: letras, digitos, simbolos seguros)
$chars = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%&*+-=?'
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$bytes = New-Object byte[] 20
$rng.GetBytes($bytes)
$password = -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
$secure = ConvertTo-SecureString $password -AsPlainText -Force

# Crear o resetear usuario
$existing = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue
if ($existing) {
    Set-LocalUser -Name $Username -Password $secure -PasswordNeverExpires $true
    Write-Host "[*] Usuario '$Username' ya existia: contrasena regenerada"
} else {
    New-LocalUser -Name $Username -Password $secure -PasswordNeverExpires $true -UserMayNotChangePassword -Description "Cuenta dedicada para acceso RDP remoto" | Out-Null
    Write-Host "[+] Usuario local '$Username' creado"
}

# Agregar al grupo Remote Desktop Users (nombre varia segun idioma del SO)
$rdpGroup = Get-LocalGroup | Where-Object { $_.SID.Value -like '*-553' }  # SID bien conocido
if ($rdpGroup) {
    $isMember = Get-LocalGroupMember -Group $rdpGroup.Name -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*\$Username" }
    if (-not $isMember) { Add-LocalGroupMember -Group $rdpGroup.Name -Member $Username }
    Write-Host "[+] Agregado al grupo '$($rdpGroup.Name)'"
}

# Archivo .rdp exportable (apunta al nombre del equipo en LAN; editable)
$rdpFile = Join-Path $OutDir "rdp-$env:COMPUTERNAME.rdp"
@"
full address:s:$env:COMPUTERNAME
username:s:$Username
prompt for credentials:i:1
screen mode id:i:2
use multimon:i:1
audiomode:i:0
redirectprinters:i:0
redirectclipboard:i:1
authentication level:i:2
enablecredsspsupport:i:1
"@ | Out-File $rdpFile -Encoding ascii
Write-Host "[+] Archivo .rdp exportable: $rdpFile"
Write-Host "    (copialo a cualquier equipo; pedira la contrasena al conectar)"

Write-Host ""
Write-Host "================ CREDENCIALES (guardar, se muestran una vez) ================" -ForegroundColor Yellow
Write-Host "  Usuario:     $env:COMPUTERNAME\$Username"
Write-Host "  Contrasena:  $password"
Write-Host "============================================================================="
