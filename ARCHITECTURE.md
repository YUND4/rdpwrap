# Arquitectura — RDP Wrapper (fork personal)

> Fork mantenido de [stascorp/rdpwrap](https://github.com/stascorp/rdpwrap) (archivado).
> Licencia: Apache 2.0. Remoto `upstream` apunta al original, `origin` al fork personal.

## ¿Qué hace?

Habilita el host de Escritorio Remoto y sesiones RDP concurrentes en ediciones de
Windows donde está limitado (Home, Starter, etc.). **No modifica `termsrv.dll`**:
actúa como capa intermedia entre el Service Control Manager (SCM) y Terminal Services,
por lo que resiste las actualizaciones de Windows.

## Cómo funciona (núcleo)

```
SCM (services.exe)
   │  carga el servicio TermService
   ▼
rdpwrap.dll  ←── se interpone como wrapper (ImagePath del servicio)
   │  1. Lee rdpwrap.ini
   │  2. Busca la sección del build de termsrv.dll instalado
   │  3. Aplica hooks/parches en memoria según los offsets del INI
   ▼
termsrv.dll (original, sin tocar en disco)
```

Hooks principales (en `RDPWrap.cpp`):
- `New_SLGetWindowsInformationDWORD` / `New_Win8SL*` — intercepta las consultas de
  licencia (SL Policy) para reportar la edición como habilitada para RDP host.
- `New_CSLQuery_Initialize` — hook de inicialización de la capa de licencias de termsrv.
- Parches en memoria a funciones como `CDefPolicy::Query`,
  `CSessionArbitrationHelper::IsSingleSessionPerUserEnabled` (sesión única por usuario).

## Componentes

| Carpeta | Lenguaje / Toolchain | Artefacto | Rol |
|---|---|---|---|
| `src-x86-x64-Fusix/` | C++ (VS2013, `RDPWrap.vcxproj`) | `rdpwrap.dll` (x86/x64) | **Núcleo**: DLL wrapper que se inyecta entre SCM y termsrv |
| `src-installer/` | Delphi (RAD Studio 2010) | `RDPWInst.exe` | Instalador/desinstalador con modo desatendido |
| `src-rdpcheck/` | Delphi | `RDPCheck.exe` | Verificador local de RDP (loopback 127.0.0.2) |
| `src-rdpconfig/` | Delphi | `RDPConf.exe` | Herramienta gráfica de configuración y diagnóstico |
| `src-x86-binarymaster/` | Delphi | `rdpwrap.dll` x86 legacy | Versión original en Delphi (solo histórico) |
| `res/rdpwrap.ini` | — | INI | **Datos por build**: offsets, firmas y parches por versión de termsrv.dll |
| `res/RDPWInst.wxs` | WiX | MSI | Paquete de instalación MSI |
| `bin/*.bat` | Batch | — | Scripts rápidos de install/uninstall/update |
| `res/rdpwrap-ini-kb.txt` | — | — | Base de conocimiento: cómo encontrar offsets en nuevos builds |

## El archivo INI (pieza crítica de mantenimiento)

`res/rdpwrap.ini` permite soportar nuevos builds de Windows **sin recompilar**:

- `[Main]` — fecha/versión del INI.
- `[SLPolicy]` — valores de política de licencia que el hook debe devolver.
- `[PatchCodes]` — opcodes comunes de parcheo.
- `[<versión termsrv.dll>]` — una sección por build (ej. `[10.0.17763.1]`),
  con offsets `LocalOnlyPatch`, `SingleUserPatch`, `DefPolicyPatch`, `SLInitHook`, etc.,
  para x86 y x64.
- `[<versión>-SLInit]` — direcciones de variables internas para el hook de SL Policy.

Cuando Windows Update cambia `termsrv.dll`, RDPConf muestra `[not supported]`
hasta que el INI incluya la sección del nuevo build.

### Cómo agregar soporte a un nuevo build

1. Obtener la versión: propiedades de `%windir%\System32\termsrv.dll`.
2. Seguir la guía en `res/rdpwrap-ini-kb.txt` (ingeniería inversa con IDA/Ghidra:
   buscar las firmas de las funciones y calcular offsets).
3. Agregar la sección al INI con los offsets encontrados.
4. Probar con `RDPConf.exe` (debe mostrar `[fully supported]`) y `RDPCheck.exe`.

La comunidad mantiene INIs actualizados (ver `res/rdpwrap.ini` — sección de fuentes).
El instalador soporta modo online (`-o`) que descarga el INI más reciente de GitHub.

## Build

- **DLL C++**: abrir `src-x86-x64-Fusix/RDPWrap.sln` en Visual Studio (2013+;
  el proyecto se puede actualizar a toolsets modernos), compilar Win32 y x64.
- **Ejecutables Delphi**: RAD Studio 2010+ (proyectos `.dproj`).
- **MSI**: `res/build_wxs.bat` (requiere WiX Toolset).

## Instalación en el sistema destino

1. `install.bat` como administrador → copia archivos a `%ProgramFiles%\RDP Wrapper`
   y registra `rdpwrap.dll` en el servicio TermService.
2. `update.bat` → actualiza solo el INI.
3. `uninstall.bat` → revierte el registro y elimina archivos.

## Flujo de trabajo de este fork

- `master` — rama principal del fork.
- `upstream` — original stascorp (archivado, solo referencia histórica).
- Convención de commits: prefijo por área (`INI:`, `Installer:`, `Core:`, `Docs:`).

## Riesgos conocidos

- Antivirus (AVG, Norton, Windows Defender en algunos casos) marcan la DLL como
  HackTool/PUA — documentar exclusión, no intentar evadir detección.
- Windows 10 Home Creators Update+: falta `rfxvmt.dll` → listener `[not listening]`
  (el instalador lo restaura).
- En tablets con Windows 8+, el sistema cierra sesiones inactivas.
