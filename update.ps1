param(
    [string]$Mode = 'install'
)

$ErrorActionPreference = 'Stop'
$repoRaw = 'https://raw.githubusercontent.com/hydrargyrum13/winfo/main'
$installDir = Join-Path $env:LOCALAPPDATA 'winfo'
$versionFile = Join-Path $installDir 'VERSION'

function Get-InstalledVersion {
    if (Test-Path $versionFile) {
        try { return (Get-Content $versionFile -Raw).Trim() } catch {}
    }
    $ps1 = Join-Path $installDir 'winfo.ps1'
    if (Test-Path $ps1) {
        try {
            $text = [IO.File]::ReadAllText($ps1, [Text.Encoding]::UTF8)
            $m = [regex]::Match($text, "(?m)^\$script:Version\s*=\s*'([^']+)'\s*$")
            if ($m.Success) { return $m.Groups[1].Value }
        } catch {}
    }
    return 'unknown'
}

function Get-LatestVersion {
    return ((Invoke-WebRequest -UseBasicParsing -Uri "$repoRaw/VERSION" -TimeoutSec 10).Content).Trim()
}

$current = Get-InstalledVersion
$latest = Get-LatestVersion

if ($Mode -eq 'check') {
    if ($current -eq 'unknown') {
        Write-Host "Latest version: v$latest" -ForegroundColor Cyan
        Write-Host 'Installed version could not be detected.' -ForegroundColor Yellow
        exit 0
    }
    try {
        if ([version]$latest -gt [version]$current) {
            Write-Host "Update available: v$current -> v$latest" -ForegroundColor Yellow
            Write-Host 'Run: winfo update' -ForegroundColor DarkGray
        } else {
            Write-Host "winfo is up to date (v$current)." -ForegroundColor Green
        }
    } catch {
        Write-Host "Installed: $current  Latest: $latest" -ForegroundColor Cyan
    }
    exit 0
}

Write-Host "Updating winfo: $current -> $latest" -ForegroundColor Cyan
if (-not (Test-Path $installDir)) { New-Item -ItemType Directory -Path $installDir -Force | Out-Null }

$tmp = Join-Path $env:TEMP ('winfo-update-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    foreach ($name in @('winfo.ps1','winfo.cmd','update.ps1','VERSION')) {
        Invoke-WebRequest -UseBasicParsing -Uri "$repoRaw/$name" -OutFile (Join-Path $tmp $name) -TimeoutSec 15
    }

    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $tmp 'winfo.ps1'), [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
        throw ('Downloaded winfo.ps1 failed parser validation: ' + (($errors | ForEach-Object Message) -join '; '))
    }

    foreach ($name in @('winfo.ps1','winfo.cmd','update.ps1','VERSION')) {
        Copy-Item (Join-Path $tmp $name) (Join-Path $installDir $name) -Force
    }
    Write-Host "Updated to v$latest." -ForegroundColor Green
} finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
