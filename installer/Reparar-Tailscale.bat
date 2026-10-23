@echo off
:: RDP Wrapper - Reparar Tailscale (cuando queda pegado en "is starting")
:: Doble clic: se eleva como administrador automaticamente (UAC).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Reparar-Tailscale.ps1"
