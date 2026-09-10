@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$p = '%~dp0winfo.ps1'; $s = [System.IO.File]::ReadAllText($p, [System.Text.UTF8Encoding]::new($false)); & ([ScriptBlock]::Create($s)) %*"
exit /b %errorlevel%
