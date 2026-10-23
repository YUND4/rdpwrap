@echo off
:: RDP Wrapper - Instalador del equipo CLIENTE
:: Doble clic: se eleva como administrador automaticamente (UAC).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-RDPClient.ps1"
