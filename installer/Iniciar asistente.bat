@echo off
:: RDP Wrapper - Asistente de instalacion
:: Doble clic: se eleva como administrador automaticamente (UAC).
powershell -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0RDPWrap-Setup-Wizard.ps1"
