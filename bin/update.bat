@echo off
:: Actualizador del INI de RDP Wrapper (fork YUND4/rdpwrap)
:: 1) Descarga el INI mas reciente desde el fork (builds actuales de Win10/11)
:: 2) Fallback: actualizador clasico del instalador

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [*] Elevando permisos de administrador...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

powershell -ExecutionPolicy Bypass -File "%~dp0update-ini.ps1"
if %errorlevel% equ 0 goto :restart

echo [*] Fallo la descarga directa, usando el actualizador clasico...
if not exist "%~dp0RDPWInst.exe" goto :error
"%~dp0RDPWInst" -w

:restart
echo.
echo [*] Reiniciando Terminal Services para aplicar cambios...
net stop TermService /y >nul 2>&1
net start TermService >nul 2>&1
echo [+] Listo. Verifica el estado con RDPConf.exe (debe decir "fully supported").
echo.
goto :anykey

:error
echo [-] No se encontro RDPWInst.exe.
echo     Extrae todos los archivos del paquete o revisa tu antivirus.

:anykey
pause
