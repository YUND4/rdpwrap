# Guía completa — RDP Wrapper con acceso remoto por Tailscale

> Flujo sencillo de punta a punta: dejar un equipo **host** accesible por RDP
> desde cualquier lugar, sin IP fija ni abrir puertos del router.

## El flujo en 4 pasos

```
┌─────────────┐   1. RDPWrap-Host-Setup.zip   ┌──────────────┐
│  EQUIPO     │ ─────────────────────────────▶│ Asistente    │
│  HOST       │    ejecutar "Iniciar           │  (7 pasos    │
│  (te conectas│    asistente.bat" como admin  │   automáticos)│
│   a este)   │                               └──────┬───────┘
└─────────────┘                                      │
        ▲              2. Login Tailscale con TU cuenta (botón en el asistente)
        │                                            ▼
        │                               3. Botón "Exportar paquete cliente"
        │                                  → RDPWrap-Cliente-HOST.zip
        │                                            │
┌──────┴──────┐   4. En el cliente: descomprimir,   ▼
│  EQUIPO     │      ejecutar Instalar-cliente.bat
│  CLIENTE    │      (instala Tailscale, login misma cuenta,
│  (desde te  │       .rdp al Escritorio)
│   conectas) │      → doble clic al .rdp y listo
└─────────────┘
```

## Paso 1 — Host: instalar

1. Descomprime `RDPWrap-Host-Setup.zip`.
2. Ejecuta `installer\Iniciar asistente.bat` y acepta el UAC.
3. El asistente instala y configura todo (verás cada paso en verde).

## Paso 2 — Host: login Tailscale

- En la página **Tailscale** del asistente pulsa **"Login Tailscale"**.
- Se abre tu navegador: inicia sesión con TU cuenta (Google/Microsoft/GitHub)
  y autoriza el equipo. El asistente detecta la conexión solo.
- Si Tailscale se queda "Iniciando..." y no responde: pulsa **"Reparar
  conexión"** (reinicia el servicio). Si ni así responde, ejecuta
  `installer\Reparar-Tailscale.bat`: lo reinstala limpio y repite el login
  automáticamente.

## Paso 3 — Host: exportar paquete cliente

En la página **Credenciales**:
- Guarda la contraseña (tarjeta oscura, seleccionable, botón Copiar).
- Pulsa **"Exportar paquete cliente (.zip)"** → queda en el Escritorio.
- El zip incluye: los 2 `.rdp` (LAN y Tailscale), `credenciales.txt`,
  instalador del cliente y README.

## Paso 4 — Cliente: instalar y conectar

1. Descomprime el zip en el equipo cliente.
2. Ejecuta `Instalar-cliente.bat` (acepta UAC). Instala Tailscale y abre el
   login: **usa la MISMA cuenta Tailscale del host**.
3. Abre el `.rdp` del Escritorio:
   - `rdp-HOST.rdp` → misma red local (más rápido)
   - `rdp-HOST-tailscale.rdp` → desde cualquier lugar
4. Credenciales: las de `credenciales.txt`.

## Desinstalar (host)

`installer\Desinstalar.bat` — revierte TODO: wrapper, firewall, exclusiones
de Defender, Windows Update, usuario `rdp` y archivos `.rdp`.
Para quitar también Tailscale:
`powershell -File installer\Uninstall-RDPWrap.ps1 -AlsoTailscale`
Sin confirmación (automatización): agregar `-Force`.

## Diagnóstico y logs (sin capturas de pantalla)

| Qué | Dónde |
|---|---|
| Log del asistente | `%TEMP%\RDPWrap-Wizard.log` |
| Log de reparación Tailscale | `%TEMP%\RDPWrap-Tailscale-Repair.log` |
| Log de desinstalación | `%TEMP%\RDPWrap-Uninstall.log` |
| Log del cliente | `%TEMP%\RDPWrap-Client.log` |

El log del asistente muestra: si corre como admin (`admin=True`), cada paso
con su resultado y, si algo falla, el tipo de excepción y la línea exacta.

## Para una IA asistente (automatización total)

En el host, PowerShell **elevado**:

```powershell
# Instalacion completa sin UI (7 pasos + exporta paquete cliente al Escritorio)
$env:RDPWRAP_WIZARD_AUTOPILOT = '1'
& '.\installer\RDPWrap-Setup-Wizard.ps1'
Get-Content "$env:TEMP\RDPWrap-Wizard.log"   # verificar: todo 'ok'

# Login Tailscale sin UI completa: requiere UNA accion del usuario (navegador)
& 'C:\Program Files\Tailscale\tailscale.exe' up
# → entregar al usuario la URL https://login.tailscale.com/a/... que imprime

# Tailscale pegado ("is starting" / NoState): reparacion automatica
& '.\installer\Reparar-Tailscale.ps1'

# Desinstalacion desatendida
& '.\installer\Uninstall-RDPWrap.ps1' -Force -AlsoTailscale
```

Notas para la IA:
- **Nunca** mates un proceso `tailscale up` en curso: cancela la autenticación
  y deja el demonio detenido (`WantRunning=false`). Deja que termine solo.
- Los comandos `tailscale status`/`ip` solo funcionan **elevados**; sin admin
  reportan `NoState` engañosamente.
- Tras regenerar credenciales (cada ejecución del asistente), el paquete
  cliente anterior queda obsoleto: exporta uno nuevo.

## Problemas frecuentes

| Síntoma | Causa | Solución |
|---|---|---|
| Pasos con "Acceso denegado" | El asistente no corre como admin | Acepta el UAC al abrirlo |
| Tailscale "is starting" eterno | Demonio corrupto o `up` cancelado a medias | `Reparar-Tailscale.bat` |
| Login Tailscale no conecta | Autorización no completada en el navegador | Repetir login; verificar en https://login.tailscale.com/admin/machines |
| `.rdp` Tailscale no conecta | Cliente sin Tailscale o con OTRA cuenta | Misma cuenta en ambos equipos |
| Contraseña no funciona | Se re-ejecutó el asistente (regenera) | Re-exportar paquete cliente |
