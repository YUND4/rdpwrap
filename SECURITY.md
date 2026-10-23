# Auditoría de seguridad — RDP Wrapper (fork)

Fecha: 2026-10-23 · Auditoría del estado del fork `YUND4/rdpwrap`.

## Procedencia del código

| Fuente | Verificación |
|---|---|
| `stascorp/rdpwrap` (base) | Clonado vía git desde GitHub; historia íntegra verificada (`git fsck`). Commit base `a5c64a4` = tip del upstream |
| Commits propios (5) | Todos los cambios sobre upstream fueron hechos en esta sesión y son auditables con `git diff upstream/master..HEAD` |
| `res/rdpwrap.ini` (comunidad: sebaxakerhtc) | Archivo de **datos** (offsets hex). Validado con `tools/Test-RdpWrapIni.ps1` |

## Resultados del escaneo (2026-10-23)

- ✅ **Windows Defender custom scan** de todo el repo: sin detecciones
- ✅ **INI**: sin cadenas hex anómalamente largas (descarta shellcode embebido);
  solo entradas `clave=valor`, secciones y comentarios
- ✅ **Sin binarios de terceros** en el repo: `*.dll`/`*.exe` están en `.gitignore`;
  la `rdpwrap.dll` usada se compila localmente desde el fuente auditado
- ✅ Sin código de red, persistencia ni ejecución remota agregado en los commits propios

## Qué hace el software (para evaluación informada)

RDP Wrapper es dual-use por naturaleza: intercepta llamadas de licencias de
Terminal Services **en memoria** para habilitar RDP host en ediciones de Windows
que no lo incluyen. No modifica archivos del sistema en disco.

- **Persistencia**: una sola entrada — `HKLM\SYSTEM\CurrentControlSet\Services\TermService`
  apunta a `rdpwrap.dll` en vez de `termsrv.dll` directamente. Reversible con `uninstall.bat`.
- **Red**: el núcleo no hace conexiones salientes. Solo los scripts de update
  descargan el INI desde `raw.githubusercontent.com/YUND4/rdpwrap`.
- **Antivirus**: esperable que algunos AV lo clasifiquen como `HackTool:Win32/RDPWrap`
  (PUA). No es un falso positivo en sentido estricto: la herramienta hace lo que
  dice; la clasificación refleja su potencial de abuso, no comportamiento oculto.

## Riesgo residual conocido

- El INI contiene opcodes de parche (`[PatchCodes]`, `xxxPatch=`). La DLL **verifica
  firmas binarias antes de parchear**: si los bytes esperados no coinciden con el
  termsrv.dll real, el parche no se aplica. Esto limita el impacto de un INI malicioso,
  pero la fuente del INI debe seguir siendo de confianza — por eso el sync semanal
  de CI apunta al repo comunitario más usado y auditado públicamente.
- Desactivar Windows Update o Windows Defender (scripts en `bin/`, opcionales y
  bajo decisión del usuario) reduce la postura de seguridad del equipo. Ver
  advertencias en cada script.

## Verificación rápida (reproducible)

```powershell
# Integridad vs upstream
git fetch upstream; git log --oneline upstream/master..HEAD

# Lint del INI
./tools/Test-RdpWrapIni.ps1

# Escaneo Defender del repo
Start-MpScan -ScanPath . -ScanType CustomScan

# Hash de la DLL compilada localmente (comparar tras cada build)
Get-FileHash ./src-x86-x64-Fusix/x64/Release/RDPWrap.dll -Algorithm SHA256
```
