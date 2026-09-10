$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$mainScript = Join-Path $repoRoot 'winfo.ps1'
$versionFile = Join-Path $repoRoot 'VERSION'

foreach ($name in @('winfo.ps1', 'winfo.cmd', 'update.ps1', 'VERSION')) {
    if (-not (Test-Path (Join-Path $repoRoot $name))) {
        throw "Required distribution file is missing: $name"
    }
}

$installer = Get-Content (Join-Path $repoRoot 'install.ps1') -Raw
foreach ($name in @('winfo.ps1', 'winfo.cmd', 'update.ps1', 'VERSION')) {
    if ($installer -notmatch [regex]::Escape("'$name'")) {
        throw "Installer does not include distribution file: $name"
    }
}

foreach ($name in @('winfo.ps1', 'install.ps1', 'update.ps1', 'repair.ps1')) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $repoRoot $name), [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count) { throw "$name has parser errors: $(($errors.Message) -join '; ')" }
}

$expectedVersion = (Get-Content $versionFile -Raw).Trim()
$reportedVersion = (& powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $mainScript version | Out-String).Trim()
if ($reportedVersion -ne "winfo $expectedVersion") {
    throw "Version mismatch: VERSION=$expectedVersion, winfo.ps1='$reportedVersion'"
}

$help = & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $mainScript help | Out-String
foreach ($command in @('summary', 'battery health', 'temps providers', 'network', 'doctor')) {
    if ($help -notmatch [regex]::Escape($command)) { throw "Help is missing command: $command" }
}

$unknown = & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $mainScript __smoke_unknown__ | Out-String
if ($unknown -notmatch 'Unknown command') { throw 'Unknown commands do not produce a useful error.' }

$interactive = "winfo version`nq" | & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $mainScript | Out-String
if ($interactive -notmatch "winfo $([regex]::Escape($expectedVersion))") {
    throw 'Interactive mode does not accept a command prefixed with winfo.'
}

Write-Host 'winfo smoke tests passed.' -ForegroundColor Green
