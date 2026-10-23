@echo off
:: RDP Wrapper - Desinstalacion completa (reversa todo lo del asistente)
:: Doble clic: se eleva como administrador automaticamente (UAC).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-RDPWrap.ps1"
