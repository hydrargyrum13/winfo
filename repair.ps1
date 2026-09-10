$ErrorActionPreference = 'Stop'

$repoRaw = 'https://raw.githubusercontent.com/hydrargyrum13/winfo/main'
$installDir = Join-Path $env:LOCALAPPDATA 'winfo'

Write-Host ''
Write-Host 'Repairing winfo...' -ForegroundColor Cyan

if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

$tmpPs1 = Join-Path $env:TEMP 'winfo-repair.ps1'
$tmpCmd = Join-Path $env:TEMP 'winfo-repair.cmd'

Invoke-WebRequest -UseBasicParsing -Uri "$repoRaw/winfo.ps1" -OutFile $tmpPs1
Invoke-WebRequest -UseBasicParsing -Uri "$repoRaw/winfo.cmd" -OutFile $tmpCmd

# Parse-check the downloaded script before replacing the installed copy.
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($tmpPs1, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) {
    $message = ($errors | ForEach-Object { $_.Message }) -join '; '
    throw "Downloaded winfo.ps1 failed PowerShell syntax validation: $message"
}

Copy-Item $tmpPs1 (Join-Path $installDir 'winfo.ps1') -Force
Copy-Item $tmpCmd (Join-Path $installDir 'winfo.cmd') -Force

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$parts = @($userPath -split ';' | Where-Object { $_ })
if ($parts -notcontains $installDir) {
    [Environment]::SetEnvironmentVariable('Path', (($parts + $installDir) -join ';'), 'User')
}
if (($env:Path -split ';') -notcontains $installDir) {
    $env:Path += ";$installDir"
}

Remove-Item $tmpPs1,$tmpCmd -Force -ErrorAction SilentlyContinue

Write-Host 'winfo repaired successfully.' -ForegroundColor Green
Write-Host 'Testing parser and version...' -ForegroundColor DarkGray
& (Join-Path $installDir 'winfo.cmd') version
Write-Host ''
Write-Host 'You can now run:' -ForegroundColor Gray
Write-Host '  winfo' -ForegroundColor Cyan
Write-Host '  winfo temps providers' -ForegroundColor Cyan
Write-Host '  winfo cpu temp' -ForegroundColor Cyan
Write-Host '  winfo gpu temp' -ForegroundColor Cyan
Write-Host '  winfo disk temp' -ForegroundColor Cyan
