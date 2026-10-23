# AGENTS.md — Guía para agentes de IA

> Lee este archivo PRIMERO antes de modificar el proyecto. Es la fuente de verdad
> para construir, probar y mantener este fork. Contexto humano: `ARCHITECTURE.md`.

## Resumen en 5 líneas

Fork mantenido de `stascorp/rdpwrap` (Apache 2.0, archivado). Habilita RDP host
concurrente en Windows parcheando `termsrv.dll` **solo en memoria**, vía
`rdpwrap.dll` (C++) + `res/rdpwrap.ini` (offsets por build). Nunca se modifica
ningún archivo de Windows en disco.

## Mapa del repo

```
src-x86-x64-Fusix/   Núcleo: RDPWrap.vcxproj (C++) → rdpwrap.dll (Win32/x64)
src-installer/       RDPWInst.exe (Delphi) — instalador
src-rdpcheck/        RDPCheck.exe (Delphi) — prueba loopback
src-rdpconfig/       RDPConf.exe (Delphi) — config UI
res/rdpwrap.ini      Offsets por build de termsrv.dll (PIEZA CRÍTICA)
installer/           Asistente GUI WPF (RDPWrap-Setup-Wizard.ps1) + desinstalador
                     (Uninstall-RDPWrap.ps1) + reparador (Reparar-Tailscale.ps1)
                     + Empaquetar-host.ps1 (zip) + cliente/ (plantillas cliente)
bin/                 install/update/uninstall .bat + update-ini.ps1
tools/               Test-RdpWrapIni.ps1 (lint del INI), RDPWrap-Monitor.ps1
docs/                guia-instalacion.md (flujo host/cliente + sección para IA)
.github/workflows/   build.yml (lint+compilar) y sync-ini.yml (sync semanal INI)
```

## Asistente GUI (installer/)

- Auto-elevación UAC obligatoria (dev: `RDPWRAP_WIZARD_NOELEVATE=1` la omite).
- Multiidioma EN (defecto) / ES: combo en la barra lateral o `RDPWRAP_WIZARD_LANG`.
 Todas las cadenas viven en `$script:Strings` (añadir clave en AMBOS idiomas).
- Verificación INI: la página de opciones muestra si el INI soporta el build local
 de termsrv.dll; el paso `ini` valida `[X.Y.Z.W]` + `[X.Y.Z.W-SLInit]` y, si falta,
 descarga el INI comunitario (fallback: fork). OJO: FileVersion trae sufijo
 "(WinBuild...)" — usar FileMajorPart/MinorPart/BuildPart/PrivatePart.
- Log SIEMPRE en `%TEMP%\RDPWrap-Wizard.log` (admin, pasos, excepciones con línea).
- Autopilot para pruebas sin UI: `RDPWRAP_WIZARD_AUTOPILOT=1` → ejecuta los 7
  pasos, exporta el paquete cliente al Escritorio y se cierra solo (~5s).
- "Exportar paquete cliente" genera zip con .rdp + credenciales.txt +
  plantillas de `installer/cliente/` (placeholders `{{HOST}}`/`{{TSIP}}`/`{{USER}}`).
- Regla de oro Tailscale: JAMÁS matar un `tailscale up` en curso (cancela la
  autenticación y deja el demonio en WantRunning=false). El CLI solo funciona
  elevado; sin admin reporta NoState engañosamente.

## Comandos

```powershell
# Compilar la DLL (requiere VS 2022+ con C++; retarguetea toolset)
msbuild src-x86-x64-Fusix\RDPWrap.sln /p:Configuration=Release /p:Platform=x64  /p:PlatformToolset=v143 /p:WindowsTargetPlatformVersion=10.0
msbuild src-x86-x64-Fusix\RDPWrap.sln /p:Configuration=Release /p:Platform=Win32 /p:PlatformToolset=v143 /p:WindowsTargetPlatformVersion=10.0

# Validar el INI (OBLIGATORIO tras cualquier cambio en res/rdpwrap.ini)
./tools/Test-RdpWrapIni.ps1

# Verificar build de Windows del equipo actual
(Get-Item "$env:windir\System32\termsrv.dll").VersionInfo.FileVersion
# → debe existir sección [X.Y.Z.W] y [X.Y.Z.W-SLInit] en res/rdpwrap.ini
```

Los ejecutables Delphi NO se compilan en CI (requieren RAD Studio 2010+).
Se distribuyen los binarios del release oficial 1.6.2.

## Convenciones

- Commits con prefijo de área: `INI:`, `Core:`, `Installer:`, `Docs:`, `Build:`, `Repo:`
- Remotos: `origin` = YUND4/rdpwrap (este fork), `upstream` = stascorp (solo lectura histórica)
- Comentarios y mensajes de usuario en español; identificadores en inglés
- `.gitignore` cubre artefactos de build — nunca commitear `Release/`, `*.obj`, etc.

## Reglas duras (NO romper)

1. **Jamás** parchear `termsrv.dll` en disco — solo en memoria (filosofía del proyecto).
2. Tras editar `res/rdpwrap.ini`, ejecutar el lint antes de commitear.
3. No agregar funcionalidad de red al núcleo (`RDPWrap.cpp`/`dllmain.cpp`).
4. No introducir binarios precompilados de terceros al repo.
5. El INI se sincroniza semanalmente desde `sebaxakerhtc/rdpwrap.ini` vía CI —
   ediciones manuales al INI pueden ser sobrescritas; preferir PR al repo comunitario
   o coordinar el sync.

## Tareas comunes

### Agregar soporte a un build nuevo de termsrv.dll
1. Obtener versión: propiedades de `C:\Windows\System32\termsrv.dll`.
2. Verificar si `sebaxakerhtc/rdpwrap.ini` ya la tiene → correr sync (Actions → "Sync INI comunidad" → Run workflow).
3. Si no: seguir `res/rdpwrap-ini-kb.txt` (ingeniería inversa con IDA/Ghidra).
4. Lint + probar con `RDPConf.exe` → `[fully supported]`.

### Diagnosticar "[not supported]" en un equipo
1. Versión de termsrv.dll (comando arriba).
2. `Select-String -Path res/rdpwrap.ini -Pattern '^\[<version>\]'` — si no está, sync INI.
3. Si está y sigue fallando: Windows Update cambió la DLL y el INI local está viejo → `bin/update.bat`.

### Instalación local de prueba
1. Descargar binarios del release 1.6.2 (stascorp) para RDPWInst/RDPConf/RDPCheck.
2. Reemplazar `rdpwrap.ini` por `res/rdpwrap.ini` del repo.
3. Exclusión en Defender ANTES de instalar (ver `bin/defender-exclusions.ps1`).
4. `bin/install.bat` como admin.

## Estado del proyecto

- CI verde: lint INI + build DLL Win32/x64 en cada push.
- INI: 768 builds (hasta Windows 11 25H2, termsrv 10.0.29639).
- Auditoría de seguridad: `SECURITY.md`.
