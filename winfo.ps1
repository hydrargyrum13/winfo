param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$ErrorActionPreference = 'SilentlyContinue'
$script:Version = '0.2.0'
$script:Accent = 'Cyan'
$script:Muted = 'DarkGray'
$script:Good = 'Green'
$script:Warn = 'Yellow'
$script:Bad = 'Red'

function Write-Accent([string]$Text, [switch]$NoNewline) { Write-Host $Text -ForegroundColor $script:Accent -NoNewline:$NoNewline }
function Write-Muted([string]$Text, [switch]$NoNewline) { Write-Host $Text -ForegroundColor $script:Muted -NoNewline:$NoNewline }
function Write-Good([string]$Text) { Write-Host $Text -ForegroundColor $script:Good }
function Write-Warn([string]$Text) { Write-Host $Text -ForegroundColor $script:Warn }
function Write-Bad([string]$Text) { Write-Host $Text -ForegroundColor $script:Bad }
function Write-KV([string]$Key, $Value) {
    Write-Host ('  {0,-20}' -f $Key) -ForegroundColor DarkGray -NoNewline
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
function Get-CPU { Get-CimInstance Win32_Processor | Select-Object -First 1 }
function Get-GPU { Get-CimInstance Win32_VideoController }
function Get-OSInfo { Get-CimInstance Win32_OperatingSystem }
function Get-Board { Get-CimInstance Win32_BaseBoard | Select-Object -First 1 }
function Get-BIOSInfo { Get-CimInstance Win32_BIOS | Select-Object -First 1 }
function Get-Computer { Get-CimInstance Win32_ComputerSystem | Select-Object -First 1 }

function Get-HardwareSensors {
    $results = @()
    foreach ($ns in @('root/LibreHardwareMonitor','root/OpenHardwareMonitor')) {
        try {
            $sensors = Get-CimInstance -Namespace $ns -ClassName Sensor -ErrorAction Stop
            foreach ($sensor in $sensors) {
                $results += [pscustomobject]@{ Name=$sensor.Name; Type=$sensor.SensorType; Value=[double]$sensor.Value; Source=$ns }
            }
        } catch {}
    }
    return $results
}
function Get-CpuTemperature {
    Get-HardwareSensors | Where-Object { $_.Type -eq 'Temperature' -and $_.Name -match 'CPU|Core|Package' }
}

function Show-CPU([string[]]$Rest) {
    if ($Rest.Count -gt 0 -and $Rest[0].ToLower() -eq 'temp') {
        $temps = Get-CpuTemperature
        if (-not $temps) {
            Write-Warn 'CPU temperature is unavailable through native Windows APIs.'
            Write-Muted 'Run LibreHardwareMonitor or OpenHardwareMonitor, then retry: winfo cpu temp'
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
    Write-Header 'GPU'
    foreach ($gpu in Get-GPU) {
        Write-KV 'Model' $gpu.Name
        if ($gpu.AdapterRAM) { Write-KV 'Reported VRAM' (Format-Bytes $gpu.AdapterRAM) }
        Write-KV 'Driver' $gpu.DriverVersion
        Write-KV 'Resolution' $(if ($gpu.CurrentHorizontalResolution) { "$($gpu.CurrentHorizontalResolution)x$($gpu.CurrentVerticalResolution) @ $($gpu.CurrentRefreshRate)Hz" } else { 'Unavailable' })
        Write-Host ''
    }
}
function Show-RAM {
    $os = Get-OSInfo
    $sticks = @(Get-CimInstance Win32_PhysicalMemory)
    $total = ($sticks | Measure-Object Capacity -Sum).Sum
    $free = [double]$os.FreePhysicalMemory * 1KB
    $used = $total - $free
    Write-Header 'Memory'
    Write-KV 'Installed' (Format-Bytes $total)
    Write-KV 'Used' (Format-Bytes $used)
    Write-KV 'Available' (Format-Bytes $free)
    Write-KV 'Usage' ('{0:N1}%' -f (($used / $total) * 100))
    Write-KV 'Modules' $sticks.Count
    foreach ($stick in $sticks) { Write-KV 'DIMM' ("$(Format-Bytes $stick.Capacity)  $($stick.Speed) MT/s  $($stick.Manufacturer)") }
}
function Show-Disk {
    Write-Header 'Storage'
    foreach ($disk in Get-PhysicalDisk) {
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
    Write-KV 'Installed' $os.InstallDate
    Write-KV 'Hostname' $env:COMPUTERNAME
    Write-KV 'User' $env:USERNAME
    Write-KV 'Uptime' (Format-Uptime $os.LastBootUpTime)
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
    Write-KV 'Release date' $b.ReleaseDate
    try { Write-KV 'Secure Boot' $(if (Confirm-SecureBootUEFI) {'Enabled'} else {'Disabled'}) }
    catch { Write-KV 'Secure Boot' 'Unavailable / legacy BIOS' }
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
        Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '169.254*' } | Select-Object InterfaceAlias,IPAddress,PrefixLength | Format-Table -AutoSize
        return
    }
    Write-Header 'Network'
    Get-NetAdapter | Where-Object Status -eq 'Up' | ForEach-Object {
        Write-KV 'Adapter' $_.Name
        Write-KV 'Interface' $_.InterfaceDescription
        Write-KV 'Link speed' $_.LinkSpeed
        Write-KV 'MAC' $_.MacAddress
        Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '169.254*' } | ForEach-Object { Write-KV 'IPv4' $_.IPAddress }
        Write-Host ''
    }
}
function Show-Ports {
    Get-NetTCPConnection -State Listen | Sort-Object LocalPort -Unique | Select-Object LocalAddress,LocalPort,OwningProcess,@{N='Process';E={(Get-Process -Id $_.OwningProcess).ProcessName}} | Format-Table -AutoSize
}
function Show-Processes([string[]]$Rest) {
    $count = 15
    if ($Rest.Count -gt 0 -and $Rest[0] -as [int]) { $count = [int]$Rest[0] }
    Get-Process | Sort-Object CPU -Descending | Select-Object -First $count Id,ProcessName,@{N='CPU(s)';E={if ($_.CPU) {[math]::Round($_.CPU,1)} else {0}}},@{N='RAM(MB)';E={[math]::Round($_.WorkingSet64/1MB,1)}} | Format-Table -AutoSize
}
function Show-Services([string[]]$Rest) {
    $filter = if ($Rest.Count) { $Rest -join ' ' } else { '' }
    $items = Get-Service
    if ($filter) { $items = $items | Where-Object { $_.Name -like "*$filter*" -or $_.DisplayName -like "*$filter*" } }
    $items | Sort-Object Status,Name | Format-Table Status,Name,DisplayName -AutoSize
}
function Show-Startup { Get-CimInstance Win32_StartupCommand | Select-Object Name,Location,Command | Format-Table -Wrap -AutoSize }
function Show-Software([string[]]$Rest) {
    $filter = if ($Rest.Count) { ($Rest -join ' ').ToLower() } else { '' }
    $paths = @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*')
    $apps = Get-ItemProperty $paths | Where-Object DisplayName | Select-Object DisplayName,DisplayVersion,Publisher,InstallDate | Sort-Object DisplayName -Unique
    if ($filter) { $apps = $apps | Where-Object { $_.DisplayName.ToLower().Contains($filter) } }
    $apps | Format-Table -AutoSize
}
function Show-Drivers([string[]]$Rest) {
    $filter = if ($Rest.Count) { ($Rest -join ' ').ToLower() } else { '' }
    $d = Get-CimInstance Win32_PnPSignedDriver | Where-Object DeviceName
    if ($filter) { $d = $d | Where-Object { $_.DeviceName.ToLower().Contains($filter) -or ([string]$_.Manufacturer).ToLower().Contains($filter) } }
    $d | Select-Object DeviceName,Manufacturer,DriverVersion,DriverDate | Sort-Object DeviceName | Format-Table -AutoSize
}
function Show-Updates { Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 20 HotFixID,Description,InstalledOn | Format-Table -AutoSize }
function Show-Environment([string[]]$Rest) {
    if ($Rest.Count -gt 0 -and $Rest[0].ToLower() -eq 'path') { $env:Path -split ';' | Where-Object { $_ }; return }
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
    $cpu = Get-CPU; $cs = Get-Computer
    Write-KV 'Firmware virtualization' $cpu.VirtualizationFirmwareEnabled
    Write-KV 'Hypervisor present' $cs.HypervisorPresent
    Get-WindowsOptionalFeature -Online | Where-Object { $_.FeatureName -match 'Hyper-V|VirtualMachinePlatform|Windows-Subsystem-Linux' } | ForEach-Object { Write-KV $_.FeatureName $_.State }
}

function Show-Temps {
    $s = Get-HardwareSensors | Where-Object Type -eq 'Temperature'
    if (-not $s) { Write-Warn 'No compatible hardware sensor provider detected.'; Write-Muted 'LibreHardwareMonitor or OpenHardwareMonitor can expose temperature sensors.'; return }
    Write-Header 'Temperatures'
    $s | Sort-Object Name | ForEach-Object { Write-KV $_.Name ('{0:N1} °C' -f $_.Value) }
}
function Show-Health {
    Write-Header 'System health'
    $os = Get-OSInfo
    $ramUsed = 100 - (($os.FreePhysicalMemory / $os.TotalVisibleMemorySize) * 100)
    Write-KV 'RAM usage' ('{0:N1}%' -f $ramUsed)
    foreach ($d in Get-PhysicalDisk) { Write-KV ("Disk: $($d.FriendlyName)") $d.HealthStatus }
    $pending = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    Write-KV 'Reboot pending' $(if ($pending) {'Yes'} else {'No'})
    $temps = Get-CpuTemperature
    if ($temps) { Write-KV 'CPU max temp' ('{0:N1} °C' -f (($temps | Measure-Object Value -Maximum).Maximum)) } else { Write-KV 'CPU temp' 'Sensor provider unavailable' }
}
function Show-Display {
    Write-Header 'Display'
    $gpus = Get-CimInstance Win32_VideoController
    foreach ($g in $gpus) {
        Write-KV 'Adapter' $g.Name
        if ($g.CurrentHorizontalResolution) { Write-KV 'Mode' ("$($g.CurrentHorizontalResolution)x$($g.CurrentVerticalResolution) @ $($g.CurrentRefreshRate)Hz") }
    }
    Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID | ForEach-Object {
        $name = -join ($_.UserFriendlyName | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ })
        $maker = -join ($_.ManufacturerName | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ })
        if ($name -or $maker) { Write-KV 'Monitor' ("$maker $name".Trim()) }
    }
}
function Show-Wifi {
    Write-Header 'Wi-Fi'
    $txt = netsh wlan show interfaces
    if (-not $txt) { Write-Warn 'Wi-Fi interface unavailable.'; return }
    $txt | Where-Object { $_ -match '^\s*(Name|Description|State|SSID|BSSID|Radio type|Authentication|Cipher|Channel|Receive rate|Transmit rate|Signal)\s*:' }
}
function Show-USB {
    Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like 'USB*' -or $_.Class -eq 'USB' } | Select-Object Status,Class,FriendlyName,InstanceId | Format-Table -AutoSize
}
function Show-Audio {
    Get-CimInstance Win32_SoundDevice | Select-Object Name,Manufacturer,Status,PNPDeviceID | Format-Table -AutoSize
}
function Show-Devices([string[]]$Rest) {
    $query = if ($Rest.Count) { ($Rest -join ' ').ToLower() } else { '' }
    $items = Get-PnpDevice -PresentOnly
    if ($query) { $items = $items | Where-Object { ([string]$_.FriendlyName).ToLower().Contains($query) -or ([string]$_.Class).ToLower().Contains($query) } }
    $items | Select-Object Status,Class,FriendlyName,InstanceId | Format-Table -AutoSize
}
function Show-DX {
    Write-Header 'DirectX / Graphics runtime'
    $dx = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\DirectX'
    Write-KV 'DirectX version' $dx.Version
    foreach ($g in Get-GPU) { Write-KV $g.Name $g.DriverVersion }
    Write-Muted '  For the full Microsoft diagnostic UI, run: dxdiag'
}
function Show-Power {
    Write-Header 'Power'
    $active = powercfg /getactivescheme
    Write-KV 'Active plan' ($active -join ' ')
    $sleep = powercfg /a
    Write-Host ($sleep -join [Environment]::NewLine) -ForegroundColor Gray
}
function Show-Firewall {
    Get-NetFirewallProfile | Select-Object Name,Enabled,DefaultInboundAction,DefaultOutboundAction | Format-Table -AutoSize
}
function Show-DNS {
    Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.ServerAddresses.Count -gt 0 } | Select-Object InterfaceAlias,ServerAddresses | Format-Table -AutoSize
}
function Show-Ping([string[]]$Rest) {
    $target = if ($Rest.Count) { $Rest[0] } else { '1.1.1.1' }
    $r = Test-Connection $target -Count 4
    if (-not $r) { Write-Bad "No response from $target"; return }
    $times = @($r | ForEach-Object { if ($_.ResponseTime -ne $null) { $_.ResponseTime } elseif ($_.Latency -ne $null) { $_.Latency } })
    Write-Header "Ping $target"
    if ($times.Count) {
        Write-KV 'Min' ("$([math]::Round(($times | Measure-Object -Minimum).Minimum,1)) ms")
        Write-KV 'Average' ("$([math]::Round(($times | Measure-Object -Average).Average,1)) ms")
        Write-KV 'Max' ("$([math]::Round(($times | Measure-Object -Maximum).Maximum,1)) ms")
    } else { Write-KV 'Status' 'Reachable' }
}
function Show-Uptime { $os = Get-OSInfo; Format-Uptime $os.LastBootUpTime }
function Show-PublicIP {
    try { (Invoke-RestMethod -Uri 'https://api.ipify.org?format=text' -TimeoutSec 5).Trim() }
    catch { Write-Warn 'Could not reach public IP service.' }
}
function Show-Summary {
    $cpu = Get-CPU; $os = Get-OSInfo; $cs = Get-Computer; $gpu = Get-GPU | Select-Object -First 1
    $drive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    Write-Header 'System summary'
    Write-KV 'OS' ("$($os.Caption)  $($os.OSArchitecture)  build $($os.BuildNumber)")
    Write-KV 'Device' ("$($cs.Manufacturer) $($cs.Model)")
    Write-KV 'CPU' $cpu.Name.Trim()
    Write-KV 'GPU' $gpu.Name
    Write-KV 'RAM' (Format-Bytes $cs.TotalPhysicalMemory)
    if ($drive) { Write-KV 'C:' ("$(Format-Bytes ($drive.Size-$drive.FreeSpace)) / $(Format-Bytes $drive.Size) used") }
    Write-KV 'Uptime' (Format-Uptime $os.LastBootUpTime)
}
function Show-Doctor {
    Write-Header 'winfo doctor'
    Write-KV 'PowerShell' $PSVersionTable.PSVersion
    Write-KV 'CIM' $(if (Get-Command Get-CimInstance) {'OK'} else {'Missing'})
    Write-KV 'Storage API' $(if (Get-Command Get-PhysicalDisk) {'OK'} else {'Missing'})
    Write-KV 'Network API' $(if (Get-Command Get-NetAdapter) {'OK'} else {'Missing'})
    Write-KV 'PnP API' $(if (Get-Command Get-PnpDevice) {'OK'} else {'Missing'})
    Write-KV 'CPU sensors' $(if (Get-CpuTemperature) {'Available'} else {'No provider detected'})
}
function Show-Help {
    Write-Header 'Commands'
    $rows = @(
        @('summary','Compact system overview'),@('health','Quick system health check'),@('temps','All available temperature sensors'),
        @('cpu','CPU details'),@('cpu temp','CPU temperatures'),@('gpu','GPU details'),@('ram','Memory usage and DIMMs'),@('disk','Storage and volume health'),
        @('os','Windows version and uptime'),@('board','Motherboard info'),@('bios','BIOS/UEFI and Secure Boot'),@('battery','Battery status'),
        @('display','Display adapters and monitors'),@('wifi','Current Wi-Fi connection'),@('usb','Connected USB devices'),@('audio','Audio devices'),@('devices [query]','PnP devices/search'),@('dx','DirectX and graphics runtime'),
        @('network','Active network adapters'),@('network ip','IPv4 addresses'),@('dns','DNS servers'),@('publicip','Public IP address'),@('ping [host]','Quick latency test'),@('ports','Listening TCP ports'),
        @('processes [n]','Top processes by CPU time'),@('services [query]','Windows services'),@('startup','Startup applications'),@('software [query]','Installed software'),@('drivers [query]','Installed drivers'),@('updates','Recent Windows updates'),
        @('power','Power plan and sleep states'),@('firewall','Firewall profile status'),@('tpm','TPM status'),@('virtualization','Hypervisor/virtualization status'),@('env','Environment variables'),@('env path','PATH entries'),@('uptime','Uptime only'),@('doctor','Check winfo providers'),@('clear','Clear interactive shell'),@('exit','Leave interactive shell')
    )
    foreach ($r in $rows) { Write-Host ('  {0,-22}' -f $r[0]) -ForegroundColor Cyan -NoNewline; Write-Host $r[1] -ForegroundColor Gray }
}
function Invoke-WinfoCommand([string[]]$Tokens) {
    if (-not $Tokens -or $Tokens.Count -eq 0) { Show-Summary; return }
    $cmd = $Tokens[0].ToLower()
    $rest = if ($Tokens.Count -gt 1) { @($Tokens[1..($Tokens.Count-1)]) } else { @() }
    switch ($cmd) {
        'summary' { Show-Summary }; 'health' { Show-Health }; 'temps' { Show-Temps }; 'temp' { Show-Temps }
        'cpu' { Show-CPU $rest }; 'gpu' { Show-GPU }; 'ram' { Show-RAM }; 'memory' { Show-RAM }; 'disk' { Show-Disk }; 'storage' { Show-Disk }
        'os' { Show-OS }; 'system' { Show-OS }; 'board' { Show-Board }; 'motherboard' { Show-Board }; 'bios' { Show-BIOS }; 'battery' { Show-Battery }
        'display' { Show-Display }; 'monitor' { Show-Display }; 'wifi' { Show-Wifi }; 'usb' { Show-USB }; 'audio' { Show-Audio }; 'devices' { Show-Devices $rest }; 'device' { Show-Devices $rest }; 'dx' { Show-DX }; 'directx' { Show-DX }
        'network' { Show-Network $rest }; 'net' { Show-Network $rest }; 'dns' { Show-DNS }; 'publicip' { Show-PublicIP }; 'ping' { Show-Ping $rest }; 'ports' { Show-Ports }
        'processes' { Show-Processes $rest }; 'ps' { Show-Processes $rest }; 'services' { Show-Services $rest }; 'startup' { Show-Startup }; 'software' { Show-Software $rest }; 'apps' { Show-Software $rest }; 'drivers' { Show-Drivers $rest }; 'updates' { Show-Updates }
        'power' { Show-Power }; 'firewall' { Show-Firewall }; 'env' { Show-Environment $rest }; 'tpm' { Show-TPM }; 'virtualization' { Show-Virtualization }; 'virt' { Show-Virtualization }; 'uptime' { Show-Uptime }; 'doctor' { Show-Doctor }
        'help' { Show-Help }; '--help' { Show-Help }; '-h' { Show-Help }; 'version' { "winfo $script:Version" }; '--version' { "winfo $script:Version" }
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
if ($Args.Count -eq 0) { Start-WinfoShell } else { Invoke-WinfoCommand $Args }
