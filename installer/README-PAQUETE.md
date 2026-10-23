# RDP Wrapper — Paquete de instalación HOST

Instala RDP Wrapper en este equipo (el que va a **alojar** las sesiones de
Escritorio Remoto) y déjalo accesible desde internet vía Tailscale, sin IP
fija ni abrir puertos en el router.

## Qué hace el asistente

1. Instala RDP Wrapper 1.6.2 (parche en memoria de `termsrv.dll`, nunca en disco)
2. Instala la base de datos INI actualizada (768 builds de Windows soportados)
3. Agrega exclusiones en Windows Defender
4. Desactiva Windows Update (evita que una actualización rompa el soporte)
5. Crea el usuario local `rdp` con contraseña aleatoria y archivos `.rdp` listos
6. Instala Tailscale y te pide iniciar sesión **con tu propia cuenta**
7. Restringe el firewall: puerto 3389 solo accesible desde la LAN y Tailscale

## Pasos (humano)

1. Descomprime esta carpeta donde quieras (ej. `Documentos\RDPWrap-Host-Setup`).
2. Ejecuta `installer\Iniciar asistente.bat` y acepta el UAC.
3. Sigue el asistente; cuando aparezca Tailscale, inicia sesión con TU cuenta
   (la misma cuenta se usará en los equipos cliente).
4. En la página **Credenciales**: guarda la contraseña y pulsa
   **"Exportar paquete cliente (.zip)"** → se crea en el Escritorio
   `RDPWrap-Cliente-<equipo>.zip`.
5. Lleva ese zip a cada equipo cliente y sigue su `README.md`.

## Pasos (para una IA asistente)

El asistente es automatizable de punta a punta. En PowerShell **elevado**:

```powershell
$env:RDPWRAP_WIZARD_AUTOPILOT = '1'
& '.\installer\RDPWrap-Setup-Wizard.ps1'
# Ejecuta los 7 pasos, exporta el paquete cliente al Escritorio y se cierra.
# Verifica el resultado en el log:
Get-Content "$env:TEMP\RDPWrap-Wizard.log"
# Todo paso debe quedar en 'ok'. El log incluye elevacion (admin=True) y,
# por cada paso fallido, el tipo de excepcion y la linea exacta.
```

Limitación: el **login interactivo de Tailscale** (paso 6) requiere al usuario
(autopilot lo omite si ya está instalado). Tras el autopilot, ejecuta
`& 'C:\Program Files\Tailscale\tailscale.exe' up` y entrégame la URL de login
para que el usuario inicie sesión.

## Requisitos

- Windows 10/11 (cualquier build listado en `res\rdpwrap.ini`, hasta 25H2)
- Conexión a internet (instalación de Tailscale vía winget)
- Cuenta Tailscale gratuita (https://tailscale.com) — hasta 100 equipos

## Estructura del paquete

```
GUIA.md     Guia completa del flujo (leer primero)
installer\  Asistente GUI, desinstalador, reparador Tailscale,
            plantillas del paquete cliente
res\        rdpwrap.ini (offsets por build de termsrv.dll)
dist\       Binarios oficiales 1.6.2 (RDPWInst/RDPConf/RDPCheck)
```

## Utilidades incluidas

- `installer\Desinstalar.bat` — revierte toda la configuracion (wrapper,
  firewall, Defender, Windows Update, usuario rdp)
- `installer\Reparar-Tailscale.bat` — repara Tailscale pegado ("is starting"):
  reinstalacion limpia + login automatico con el navegador
