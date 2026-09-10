@echo off
setlocal

if /I "%~1"=="update" (
  if /I "%~2"=="check" (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0update.ps1" check
  ) else (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0update.ps1"
  )
  exit /b %errorlevel%
)

if /I "%~1"=="version" (
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0update.ps1" version
  exit /b %errorlevel%
)

if "%~1"=="" (
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0update.ps1" notice
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$p='%~dp0winfo-core.ps1'; if(-not [IO.File]::Exists($p)){$p='%~dp0winfo.ps1'}; $c=[IO.File]::ReadAllText($p,[Text.Encoding]::UTF8); & ([ScriptBlock]::Create($c)) @args" %*
exit /b %errorlevel%
