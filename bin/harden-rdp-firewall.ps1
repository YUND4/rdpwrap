# Restringe RDP (3389) a: red Tailscale (100.64.0.0/10) + subred local.
# Deshabilita las reglas por defecto de Windows (que aceptan de cualquier origen)
# y crea una regla limitada. Revertir con -Restore.
[CmdletBinding()]
param([switch]$Restore)

$ErrorActionPreference = 'Stop'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[-] Ejecuta este script como administrador."; exit 1
}

$ruleName = 'RDP-Wrapper-Tailscale-LAN'
$defaultRules = @(
    'RemoteDesktop-UserMode-In-TCP',
    'RemoteDesktop-UserMode-In-UDP'
)

if ($Restore) {
    Remove-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue
    foreach ($r in $defaultRules) { Enable-NetFirewallRule -Name $r -ErrorAction SilentlyContinue }
    Write-Host "[+] Firewall restaurado: reglas RDP por defecto habilitadas."
    exit 0
}

# Deshabilitar reglas por defecto (aceptan 3389 desde cualquier IP)
foreach ($r in $defaultRules) {
    Disable-NetFirewallRule -Name $r -ErrorAction SilentlyContinue
    Write-Host "[*] Regla por defecto deshabilitada: $r"
}

# Regla limitada: solo Tailscale + subred local
Remove-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue
New-NetFirewallRule -Name $ruleName -DisplayName "RDP (solo Tailscale y LAN local)" `
    -Direction Inbound -Protocol TCP -LocalPort 3389 -Action Allow `
    -RemoteAddress @('100.64.0.0/10', 'LocalSubnet') -Profile Any | Out-Null
Write-Host "[+] Regla '$ruleName' creada: 3389 TCP solo desde Tailscale (100.64.0.0/10) y LAN local"

Write-Host ""
Write-Host "[*] Reglas RDP activas ahora:"
Get-NetFirewallRule -DisplayName '*RDP*', '*Remote Desktop*' -ErrorAction SilentlyContinue |
    Where-Object Enabled -eq 'True' | Select-Object -ExpandProperty DisplayName
