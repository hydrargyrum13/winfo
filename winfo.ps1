param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$ErrorActionPreference = 'SilentlyContinue'
$script:Version = '0.1.0'
$script:Accent = 'Cyan'
$script:Muted = 'DarkGray'
$script:Good = 'Green'
$script:Warn = 'Yellow'
$script:Bad = 'Red'

function Write-Accent([string]$Text, [switch]$NoNewline) {
    Write-Host $Text -ForegroundColor $script:Accent -NoNewline:$NoNewline
}
function Write-Muted([string]$Text, [switch]$NoNewline) {
    Write-Host $Text -ForegroundColor $script:Muted -NoNewline:$NoNewline
}
function Write-Good([string]$Text) { Write-Host $Text -ForegroundColor $script:Good }
function Write-Warn([string]$Text) { Write-Host $Text -ForegroundColor $script:Warn }
function Write-Bad([string]$Text) { Write-Host $Text -ForegroundColor $script:Bad }

function Write-KV([string]$Key, $Value) {
    Write-Host ('  {0,-18}' -f $Key) -ForegroundColor DarkGray -NoNewline
    Write-Host ([string]$Value) -ForegroundColor White
}

function Write-Header([string]$Title) {
    Write-Host ''
    Write-Accent "  $Title"
    Write-Muted ('  ' + ('─' * ([Math]::Max(8, $Title.Length))))
}

function Format-Bytes([double]$Bytes) {
    $units = @('B','KiB','MiB','GiB','TiB')
    $i = 0
    while ($Bytes -ge 1024 -and $i -lt $units.Count - 1) { $Bytes /= 1024; $i++ }
    return ('{0:N2} {1}' -f $Bytes, $units[$i])
}

function Format-Uptime([datetime]$Boot) {
    $u = (Get-Date) - $Boot
    return ('{0}d {1}h {2}m' -f [int]$u.TotalDays, $u.Hours, $u.Minutes)
}

function Get-CPU {
    Get-CimInstance Win32_Processor | Select-Object -First 1
}

function Get-GPU {
    Get-CimInstance Win32_VideoController
}

function Get-OSInfo {
    Get-CimInstance Win32_OperatingSystem
}

function Get-Board {
    Get-CimInstance Win32_BaseBoard | Select-Object -First 1
}

function Get-BIOSInfo {
    Get-CimInstance Win32_BIOS | Select-Object -First 1
}

function Get-Computer {
    Get-CimInstance Win32_ComputerSystem | Select-Object -First 1
}

function Get-CpuTemperature {
    $results = @()
    foreach ($ns in @('root/LibreHardwareMonitor','root/OpenHardwareMonitor')) {
        try {
            $sensors = Get-CimInstance -Namespace $ns -ClassName Sensor -ErrorAction Stop |
                Where-Object { $_.SensorType -eq 'Temperature' -and ($_.Name -match 'CPU|Core|Package') }
            foreach ($sensor in $sensors) {
                $results += [pscustomobject]@{ Name=$sensor.Name; Value=[double]$sensor.Value; Source=$ns }
            }
        } catch {}
    }
    return $results
}

function Show-CPU([string[]]$Rest) {
    if ($Rest.Count -gt 0 -and $Rest[0].ToLower() -eq 'temp') {
        $temps = Get-CpuTemperature
        if (-not $temps -or $temps.Count -eq 0) {
            Write-Warn 'CPU temperature is unavailable through native Windows APIs.'
            Write-Muted 'Run LibreHardwareMonitor in the background to expose sensor data, then retry: winfo cpu temp'
            return
        }
        foreach ($t in $temps) { '{0}: {1:N1} °C' -f $t.Name, $t.Value }
        return
    }

    $cpu = Get-CPU
    if (-not $cpu) { Write-Bad 'CPU information unavailable.'; return }
    Write-Header 'CPU'
    Write-KV 'Model' $cpu.Name.Trim()
    Write-KV 'Cores' $cpu.NumberOfCores
    Write-KV 'Threads' $cpu.NumberOfLogicalProcessors
    Write-KV 'Max clock' ("$($cpu.MaxClockSpeed) MHz")
    Write-KV 'Current clock' ("$($cpu.CurrentClockSpeed) MHz")
    Write-KV 'Architecture' $env:PROCESSOR_ARCHITECTURE
    Write-KV 'Virtualization' $(if ($cpu.VirtualizationFirmwareEnabled) {'Enabled'} else {'Disabled / unavailable'})
}

function Show-GPU {
    $gpus = Get-GPU
    Write-Header 'GPU'
    foreach ($gpu in $gpus) {
        Write-KV 'Model' $gpu.Name
        if ($gpu.AdapterRAM) { Write-KV 'Reported VRAM' (Format-Bytes $gpu.AdapterRAM) }
        Write-KV 'Driver' $gpu.DriverVersion
        Write-KV 'Resolution' $(if ($gpu.CurrentHorizontalResolution) { "$($gpu.CurrentHorizontalResolution)x$($gpu.CurrentVerticalResolution) @ $($gpu.CurrentRefreshRate)Hz" } else { 'Unavailable' })
        Write-Host ''
    }
}

function Show-RAM {
    $os = Get-OSInfo
    $sticks = Get-CimInstance Win32_PhysicalMemory
    $total = ($sticks | Measure-Object Capacity -Sum).Sum
    $free = [double]$os.FreePhysicalMemory * 1KB
    $used = $total - $free
    Write-Header 'Memory'
    Write-KV 'Installed' (Format-Bytes $total)
    Write-KV 'Used' (Format-Bytes $used)
    Write-KV 'Available' (Format-Bytes $free)
    Write-KV 'Usage' ('{0:N1}%' -f (($used / $total) * 100))
    Write-KV 'Modules' $sticks.Count
    foreach ($stick in $sticks) {
        Write-KV 'DIMM' ("$(Format-Bytes $stick.Capacity)  $($stick.Speed) MT/s  $($stick.Manufacturer)")
    }
}

function Show-Disk {
    Write-Header 'Storage'
    $disks = Get-PhysicalDisk
    foreach ($disk in $disks) {
        Write-KV 'Drive' $disk.FriendlyName
        Write-KV 'Type' $disk.MediaType
        Write-KV 'Bus' $disk.BusType
        Write-KV 'Size' (Format-Bytes $disk.Size)
        Write-KV 'Health' $disk.HealthStatus
        Write-Host ''
    }
    Write-Muted '  Volumes'
    Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
        $used = $_.Size - $_.FreeSpace
        Write-KV $_.DeviceID ("$(Format-Bytes $used) / $(Format-Bytes $_.Size) used")
    }
}

function Show-OS {
    $os = Get-OSInfo
    Write-Header 'Windows'
    Write-KV 'Edition' $os.Caption
    Write-KV 'Version' $os.Version
    Write-KV 'Build' $os.BuildNumber
    Write-KV 'Architecture' $os.OSArchitecture
    Write-KV 'Installed' ([Management.ManagementDateTimeConverter]::ToDateTime($os.InstallDate))
    Write-KV 'Hostname' $env:COMPUTERNAME
    Write-KV 'User' $env:USERNAME
    Write-KV 'Uptime' (Format-Uptime ([Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime)))
}

function Show-Board {
    $b = Get-Board
    Write-Header 'Motherboard'
    Write-KV 'Manufacturer' $b.Manufacturer
    Write-KV 'Product' $b.Product
    Write-KV 'Version' $b.Version
    Write-KV 'Serial' $b.SerialNumber
}

function Show-BIOS {
    $b = Get-BIOSInfo
    Write-Header 'BIOS / UEFI'
    Write-KV 'Vendor' $b.Manufacturer
    Write-KV 'Version' $b.SMBIOSBIOSVersion
    Write-KV 'Release date' ([Management.ManagementDateTimeConverter]::ToDateTime($b.ReleaseDate))
    try {
        $secure = Confirm-SecureBootUEFI
        Write-KV 'Secure Boot' $(if ($secure) {'Enabled'} else {'Disabled'})
    } catch { Write-KV 'Secure Boot' 'Unavailable / legacy BIOS' }
}

function Show-Battery {
    $b = Get-CimInstance Win32_Battery
    if (-not $b) { Write-Warn 'No battery detected.'; return }
    Write-Header 'Battery'
    Write-KV 'Charge' ("$($b.EstimatedChargeRemaining)%")
    Write-KV 'Status' $b.Status
    if ($b.EstimatedRunTime -and $b.EstimatedRunTime -lt 71582788) { Write-KV 'Runtime' ("$($b.EstimatedRunTime) min") }
}

function Show-Network([string[]]$Rest) {
    if ($Rest.Count -gt 0 -and $Rest[0].ToLower() -eq 'ip') {
        Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '169.254*' } |
            Select-Object InterfaceAlias,IPAddress,PrefixLength | Format-Table -AutoSize
        return
    }
    Write-Header 'Network'
    Get-NetAdapter | Where-Object Status -eq 'Up' | ForEach-Object {
        Write-KV 'Adapter' $_.Name
        Write-KV 'Interface' $_.InterfaceDescription
        Write-KV 'Link speed' $_.LinkSpeed
        Write-KV 'MAC' $_.MacAddress
        $ips = Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '169.254*' }
        foreach ($ip in $ips) { Write-KV 'IPv4' $ip.IPAddress }
        Write-Host ''
    }
}

function Show-Ports {
    Get-NetTCPConnection -State Listen | Sort-Object LocalPort -Unique |
        Select-Object LocalAddress,LocalPort,OwningProcess,@{N='Process';E={(Get-Process -Id $_.OwningProcess).ProcessName}} |
        Format-Table -AutoSize
}

function Show-Processes([string[]]$Rest) {
    $count = 15
    if ($Rest.Count -gt 0 -and $Rest[0] -as [int]) { $count = [int]$Rest[0] }
    Get-Process | Sort-Object CPU -Descending | Select-Object -First $count Id,ProcessName,
        @{N='CPU(s)';E={if ($_.CPU) {[math]::Round($_.CPU,1)} else {0}}},
        @{N='RAM(MB)';E={[math]::Round($_.WorkingSet64/1MB,1)}} | Format-Table -AutoSize
}

function Show-Services([string[]]$Rest) {
    $filter = if ($Rest.Count) { $Rest -join ' ' } else { '' }
    $items = Get-Service
    if ($filter) { $items = $items | Where-Object { $_.Name -like "*$filter*" -or $_.DisplayName -like "*$filter*" } }
    $items | Sort-Object Status,Name | Format-Table Status,Name,DisplayName -AutoSize
}

function Show-Startup {
    Get-CimInstance Win32_StartupCommand | Select-Object Name,Location,Command | Format-Table -Wrap -AutoSize
}

function Show-Software([string[]]$Rest) {
    $filter = if ($Rest.Count) { ($Rest -join ' ').ToLower() } else { '' }
    $paths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $apps = Get-ItemProperty $paths | Where-Object DisplayName |
        Select-Object DisplayName,DisplayVersion,Publisher,InstallDate |
        Sort-Object DisplayName -Unique
    if ($filter) { $apps = $apps | Where-Object { $_.DisplayName.ToLower().Contains($filter) } }
    $apps | Format-Table -AutoSize
}

function Show-Drivers([string[]]$Rest) {
    $filter = if ($Rest.Count) { ($Rest -join ' ').ToLower() } else { '' }
    $d = Get-CimInstance Win32_PnPSignedDriver | Where-Object DeviceName
    if ($filter) { $d = $d | Where-Object { $_.DeviceName.ToLower().Contains($filter) -or $_.Manufacturer.ToLower().Contains($filter) } }
    $d | Select-Object DeviceName,Manufacturer,DriverVersion,DriverDate | Sort-Object DeviceName | Format-Table -AutoSize
}

function Show-Updates {
    Write-Header 'Recent Windows Updates'
    Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 20 HotFixID,Description,InstalledOn | Format-Table -AutoSize
}

function Show-Environment([string[]]$Rest) {
    if ($Rest.Count -gt 0 -and $Rest[0].ToLower() -eq 'path') {
        $env:Path -split ';' | Where-Object { $_ } | ForEach-Object { $_ }
        return
    }
    Get-ChildItem Env: | Sort-Object Name | Format-Table -AutoSize
}

function Show-TPM {
    try {
        $t = Get-Tpm
        Write-Header 'TPM'
        Write-KV 'Present' $t.TpmPresent
        Write-KV 'Ready' $t.TpmReady
        Write-KV 'Enabled' $t.TpmEnabled
        Write-KV 'Activated' $t.TpmActivated
        Write-KV 'Owned' $t.TpmOwned
    } catch { Write-Warn 'TPM information unavailable.' }
}

function Show-Virtualization {
    Write-Header 'Virtualization'
    $cpu = Get-CPU
    $cs = Get-Computer
    Write-KV 'Firmware virtualization' $cpu.VirtualizationFirmwareEnabled
    Write-KV 'Hypervisor present' $cs.HypervisorPresent
    $features = Get-WindowsOptionalFeature -Online | Where-Object { $_.FeatureName -match 'Hyper-V|VirtualMachinePlatform|Windows-Subsystem-Linux' }
    foreach ($f in $features) { Write-KV $f.FeatureName $f.State }
}

function Show-Summary {
    $cpu = Get-CPU
    $os = Get-OSInfo
    $cs = Get-Computer
    $gpu = (Get-GPU | Select-Object -First 1)
    $drive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    Write-Header 'System summary'
    Write-KV 'OS' ("$($os.Caption)  $($os.OSArchitecture)  build $($os.BuildNumber)")
    Write-KV 'Device' ("$($cs.Manufacturer) $($cs.Model)")
    Write-KV 'CPU' $cpu.Name.Trim()
    Write-KV 'GPU' $gpu.Name
    Write-KV 'RAM' (Format-Bytes $cs.TotalPhysicalMemory)
    if ($drive) { Write-KV 'C:' ("$(Format-Bytes ($drive.Size-$drive.FreeSpace)) / $(Format-Bytes $drive.Size) used") }
    Write-KV 'Uptime' (Format-Uptime ([Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime)))
}

function Show-Doctor {
    Write-Header 'winfo doctor'
    Write-KV 'PowerShell' $PSVersionTable.PSVersion
    Write-KV 'CIM' $(if (Get-Command Get-CimInstance) {'OK'} else {'Missing'})
    Write-KV 'Storage API' $(if (Get-Command Get-PhysicalDisk) {'OK'} else {'Missing'})
    Write-KV 'Network API' $(if (Get-Command Get-NetAdapter) {'OK'} else {'Missing'})
    $temps = Get-CpuTemperature
    Write-KV 'CPU sensors' $(if ($temps) {'Available'} else {'No provider detected'})
    Write-Muted '  Temperature note: Windows does not expose reliable CPU package temperature through a universal native API.'
}

function Show-Help {
    Write-Header 'Commands'
    $rows = @(
        @('summary', 'Compact system overview'),
        @('cpu', 'CPU model, cores, clocks, virtualization'),
        @('cpu temp', 'CPU temperature via Libre/OpenHardwareMonitor sensor provider'),
        @('gpu', 'Graphics adapters, driver and display info'),
        @('ram', 'Memory usage and DIMM information'),
        @('disk', 'Physical disks, health and volume usage'),
        @('os', 'Windows version, build, install date and uptime'),
        @('board', 'Motherboard information'),
        @('bios', 'BIOS/UEFI and Secure Boot'),
        @('battery', 'Laptop battery status'),
        @('network', 'Active adapters and addresses'),
        @('network ip', 'IPv4 addresses only'),
        @('ports', 'Listening TCP ports and owning processes'),
        @('processes [n]', 'Top processes by CPU time'),
        @('services [query]', 'List or search Windows services'),
        @('startup', 'Startup applications'),
        @('software [query]', 'Installed software list/search'),
        @('drivers [query]', 'Installed signed drivers'),
        @('updates', 'Recently installed Windows updates'),
        @('env', 'Environment variables'),
        @('env path', 'PATH entries'),
        @('tpm', 'TPM status'),
        @('virtualization', 'Hypervisor and optional feature status'),
        @('doctor', 'Check winfo data providers'),
        @('clear', 'Clear the interactive shell'),
        @('exit', 'Leave the interactive shell')
    )
    foreach ($r in $rows) {
        Write-Host ('  {0,-22}' -f $r[0]) -ForegroundColor Cyan -NoNewline
        Write-Host $r[1] -ForegroundColor Gray
    }
}

function Invoke-WinfoCommand([string[]]$Tokens) {
    if (-not $Tokens -or $Tokens.Count -eq 0) { Show-Summary; return }
    $cmd = $Tokens[0].ToLower()
    $rest = if ($Tokens.Count -gt 1) { @($Tokens[1..($Tokens.Count-1)]) } else { @() }

    switch ($cmd) {
        'summary' { Show-Summary }
        'cpu' { Show-CPU $rest }
        'gpu' { Show-GPU }
        'ram' { Show-RAM }
        'memory' { Show-RAM }
        'disk' { Show-Disk }
        'storage' { Show-Disk }
        'os' { Show-OS }
        'system' { Show-OS }
        'board' { Show-Board }
        'motherboard' { Show-Board }
        'bios' { Show-BIOS }
        'battery' { Show-Battery }
        'network' { Show-Network $rest }
        'net' { Show-Network $rest }
        'ports' { Show-Ports }
        'processes' { Show-Processes $rest }
        'ps' { Show-Processes $rest }
        'services' { Show-Services $rest }
        'startup' { Show-Startup }
        'software' { Show-Software $rest }
        'apps' { Show-Software $rest }
        'drivers' { Show-Drivers $rest }
        'updates' { Show-Updates }
        'env' { Show-Environment $rest }
        'tpm' { Show-TPM }
        'virtualization' { Show-Virtualization }
        'virt' { Show-Virtualization }
        'doctor' { Show-Doctor }
        'help' { Show-Help }
        '--help' { Show-Help }
        '-h' { Show-Help }
        'version' { "winfo $script:Version" }
        '--version' { "winfo $script:Version" }
        default { Write-Bad "Unknown command: $cmd"; Write-Muted 'Run: winfo help' }
    }
}

function Show-Banner {
    Write-Host ''
    Write-Host ' __        _____ _   _ _____ ___  ' -ForegroundColor Cyan
    Write-Host ' \ \      / /_ _| \ | |  ___/ _ \ ' -ForegroundColor Cyan
    Write-Host '  \ \ /\ / / | ||  \| | |_ | | | |' -ForegroundColor Cyan
    Write-Host '   \ V  V /  | || |\  |  _|| |_| |' -ForegroundColor Cyan
    Write-Host '    \_/\_/  |___|_| \_|_|   \___/ ' -ForegroundColor Cyan
    Write-Host ''
    Write-Muted "  Windows information, without the scavenger hunt.  v$script:Version"
    Write-Muted '  Type help to see commands.'
    Write-Host ''
}

function Start-WinfoShell {
    Show-Banner
    while ($true) {
        Write-Host 'winfo' -ForegroundColor Cyan -NoNewline
        Write-Host ' › ' -ForegroundColor DarkGray -NoNewline
        $line = Read-Host
        if ($null -eq $line) { break }
        $line = $line.Trim()
        if (-not $line) { continue }
        if ($line.ToLower() -in @('exit','quit','q')) { break }
        if ($line.ToLower() -in @('clear','cls')) { Clear-Host; Show-Banner; continue }
        $tokens = [regex]::Matches($line, '(?:[^\s"]+|"[^"]*")+') | ForEach-Object { $_.Value.Trim('"') }
        Invoke-WinfoCommand @($tokens)
    }
}

if ($Args.Count -eq 0) {
    Start-WinfoShell
} else {
    Invoke-WinfoCommand $Args
}
