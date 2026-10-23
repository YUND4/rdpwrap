@echo off
:: Instalador rapido de RDP Wrapper (fork YUND4/rdpwrap)
:: Se auto-eleva como administrador si es necesario.

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [*] Elevando permisos de administrador...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

if not exist "%~dp0RDPWInst.exe" goto :error
"%~dp0RDPWInst" -i -o

echo ______________________________________________________________
echo.
echo Actualizando INI desde el fork mantenido...
powershell -ExecutionPolicy Bypass -File "%~dp0update-ini.ps1"

echo ______________________________________________________________
echo.
echo Puedes verificar el funcionamiento con RDPCheck.exe
echo y configurar opciones avanzadas con RDPConf.exe.
echo.
goto :anykey

:error
echo [-] No se encontro RDPWInst.exe.
echo     Extrae todos los archivos del paquete o revisa tu antivirus.

:anykey
pause
