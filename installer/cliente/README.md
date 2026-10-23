# RDP Wrapper — Paquete CLIENTE (conectarse a {{HOST}})

Este paquete prepara **este equipo** para conectarse por Escritorio Remoto
al equipo host **{{HOST}}** (usuario `{{USER}}`).

## Contenido

| Archivo | Para qué |
|---|---|
| `rdp-{{HOST}}.rdp` | Conexión cuando ambos equipos están en la **misma red (LAN)** |
| `rdp-{{HOST}}-tailscale.rdp` | Conexión **desde cualquier lugar** vía Tailscale (IP {{TSIP}}) |
| `credenciales.txt` | Usuario y contraseña del host |
| `Instalar-cliente.bat` | Instalador automático (Tailscale + copia los .rdp al Escritorio) |
| `Setup-RDPClient.ps1` | El script que hace el trabajo (lo llama el .bat) |

## Pasos (humano)

1. Ejecuta `Instalar-cliente.bat` y acepta el aviso de administrador (UAC).
2. Si no tenías Tailscale, se instala y se abre el login:
   **inicia sesión con la MISMA cuenta Tailscale que usaste en el host**.
3. Los `.rdp` quedan en tu Escritorio. Ábrelos con doble clic (mstsc).
4. Cuando pida credenciales, usa las de `credenciales.txt`.

¿Cuál .rdp usar? Si estás en la misma red que el host, el de LAN (más rápido).
Si estás fuera (otra casa, oficina, datos móviles), el de Tailscale.

## Pasos (para una IA asistente)

Si estás ayudando al usuario a instalar este paquete, ejecuta en PowerShell
**elevado**, desde la carpeta extraída:

```powershell
# 1) Instalar Tailscale si falta
$ts = 'C:\Program Files\Tailscale\tailscale.exe'
if (-not (Test-Path $ts)) {
    winget install --id tailscale.tailscale --accept-source-agreements --accept-package-agreements
}
# 2) Conectar (imprime URL de login; el usuario debe iniciar sesión
#    con la MISMA cuenta Tailscale del host)
& $ts status --json | ConvertFrom-Json | Select-Object -Expand BackendState
# si no es 'Running': & $ts up
# 3) Copiar accesos directos al Escritorio
Copy-Item "$PSScriptRoot\*.rdp" ([Environment]::GetFolderPath('Desktop')) -Force
# 4) Credenciales para mstsc: ver credenciales.txt (NO las muestres en logs)
```

Notas:
- No instales nada más: el host ya expone RDP en el puerto 3389, restringido
  por firewall a la LAN y a la red Tailscale (100.64.0.0/10).
- Si la conexión Tailscale falla, verifica que AMBOS equipos usan la misma
  cuenta y aparecen en https://login.tailscale.com/admin/machines
- Si la contraseña no funciona, en el host se re-ejecutó el asistente y se
  regeneró: pide que exporten de nuevo este paquete desde la página de
  credenciales del asistente (botón "Exportar paquete cliente").
