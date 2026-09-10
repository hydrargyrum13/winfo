$ErrorActionPreference = 'Stop'

$repoRaw = 'https://raw.githubusercontent.com/hydrargyrum13/winfo/main'
$installDir = Join-Path $env:LOCALAPPDATA 'winfo'

Write-Host ''
Write-Host 'Repairing winfo...' -ForegroundColor Cyan

if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

$tmp = Join-Path $env:TEMP ('winfo-repair-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null

try {
    foreach ($name in @('winfo.ps1','winfo.cmd','update.ps1','VERSION')) {
        Invoke-WebRequest -UseBasicParsing -Uri "$repoRaw/$name" -OutFile (Join-Path $tmp $name) -TimeoutSec 15
    }

    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $tmp 'winfo.ps1'), [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
        throw ('Downloaded winfo.ps1 failed PowerShell syntax validation: ' + (($errors | ForEach-Object Message) -join '; '))
    }

    foreach ($name in @('winfo.ps1','winfo.cmd','update.ps1','VERSION')) {
        Copy-Item (Join-Path $tmp $name) (Join-Path $installDir $name) -Force
    }

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @($userPath -split ';' | Where-Object { $_ })
    if ($parts -notcontains $installDir) {
        [Environment]::SetEnvironmentVariable('Path', (($parts + $installDir) -join ';'), 'User')
    }
    if (($env:Path -split ';') -notcontains $installDir) {
        $env:Path += ";$installDir"
    }

    Remove-Item (Join-Path $installDir 'update-check.json') -Force -ErrorAction SilentlyContinue

    Write-Host 'winfo repaired successfully.' -ForegroundColor Green
    & (Join-Path $installDir 'winfo.cmd') version
    Write-Host ''
    Write-Host 'Try:' -ForegroundColor Gray
    Write-Host '  winfo' -ForegroundColor Cyan
    Write-Host '  winfo update check' -ForegroundColor Cyan
    Write-Host '  winfo temps providers' -ForegroundColor Cyan
} finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
