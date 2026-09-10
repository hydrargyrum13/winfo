$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$installDir = Join-Path $env:LOCALAPPDATA 'winfo'

Write-Host ''
Write-Host 'Installing winfo...' -ForegroundColor Cyan

if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir | Out-Null
}

foreach ($name in @('winfo.ps1', 'winfo.cmd', 'update.ps1', 'VERSION')) {
    Copy-Item (Join-Path $repoRoot $name) (Join-Path $installDir $name) -Force
}

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$parts = @($userPath -split ';' | Where-Object { $_ })

if ($parts -notcontains $installDir) {
    $newPath = (($parts + $installDir) -join ';')
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    $env:Path = "$env:Path;$installDir"
    Write-Host 'Added winfo to your user PATH.' -ForegroundColor Green
} else {
    Write-Host 'winfo is already in your user PATH.' -ForegroundColor DarkGray
}

Write-Host ''
Write-Host 'Installed.' -ForegroundColor Green
Write-Host 'Open a new terminal and run:' -ForegroundColor Gray
Write-Host '  winfo' -ForegroundColor Cyan
Write-Host ''
Write-Host "Install location: $installDir" -ForegroundColor DarkGray
