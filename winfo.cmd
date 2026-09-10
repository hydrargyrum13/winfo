@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0winfo.ps1" %*
exit /b %errorlevel%
