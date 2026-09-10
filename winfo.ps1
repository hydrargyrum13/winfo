param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$ErrorActionPreference = 'SilentlyContinue'
$script:Version = '0.5.0'
$script:RepoRaw = 'https://raw.githubusercontent.com/hydrargyrum13/winfo/main'
$script:InstallDir = Join-Path $env:LOCALAPPDATA 'winfo'
$script:UpdateCache = Join-Path $script:InstallDir 'update-check.json'

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
    Write-Host ('  {0,-22}' -f $Key) -ForegroundColor DarkGray -NoNewline
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
function Compare-Version([string]$A, [string]$B) {
    try { return ([version]$A).CompareTo([version]$B) } catch { return 0 }
}

function Get-CPU { Get-CimInstance Win32_Processor | Select-Object -First 1 }
function Get-GPU { Get-CimInstance Win32_VideoController }
function Get-OSInfo { Get-CimInstance Win32_OperatingSystem }
function Get-Board { Get-CimInstance Win32_BaseBoard | Select-Object -First 1 }
function Get-BIOSInfo { Get-CimInstance Win32_BIOS | Select-Object -First 1 }
function Get-Computer { Get-CimInstance Win32_ComputerSystem | Select-Object -First 1 }

# ---------------- Temperature / sensor providers ----------------

function Get-MonitorSensors {
    $out = @()
    foreach ($ns in @('root/LibreHardwareMonitor','root/OpenHardwareMonitor')) {
        try {
            Get-CimInstance -Namespace $ns -ClassName Sensor -ErrorAction Stop | ForEach-Object {
                $out += [pscustomobject]@{
                    Name = [string]$_.Name
                    Category = if ($_.Identifier -match '/gpu') { 'GPU' } elseif ($_.Identifier -match '/cpu') { 'CPU' } elseif ($_.Identifier -match '/hdd|/nvme') { 'Disk' } else { 'Other' }
                    Type = [string]$_.SensorType
                    Value = [double]$_.Value
                    Source = if ($ns -match 'Libre') { 'LibreHardwareMonitor' } else { 'OpenHardwareMonitor' }
                }
            }
        } catch {}
    }
    return $out
}

function Get-NvidiaSensors {
    $out = @()
    $nvsmi = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
    if (-not $nvsmi) {
        $candidate = Join-Path $env:ProgramFiles 'NVIDIA Corporation\NVSMI\nvidia-smi.exe'
        if (Test-Path $candidate) { $nvsmi = $candidate }
    }
    if (-not $nvsmi) { return $out }
    try {
        $rows = & $nvsmi --query-gpu=name,temperature.gpu,utilization.gpu,memory.total,memory.used --format=csv,noheader,nounits 2>$null
        foreach ($row in $rows) {
            $p = $row -split ',' | ForEach-Object { $_.Trim() }
            if ($p.Count -ge 5) {
                $out += [pscustomobject]@{ Name = "$($p[0]) temperature"; Category='GPU'; Type='Temperature'; Value=[double]$p[1]; Source='nvidia-smi' }
                $out += [pscustomobject]@{ Name = "$($p[0]) load"; Category='GPU'; Type='Load'; Value=[double]$p[2]; Source='nvidia-smi' }
                $out += [pscustomobject]@{ Name = "$($p[0]) VRAM total"; Category='GPU'; Type='VRAMTotalMiB'; Value=[double]$p[3]; Source='nvidia-smi' }
                $out += [pscustomobject]@{ Name = "$($p[0]) VRAM used"; Category='GPU'; Type='VRAMUsedMiB'; Value=[double]$p[4]; Source='nvidia-smi' }
            }
        }
    } catch {}
    return $out
}

function Get-StorageSensors {
    $out = @()
    try {
        foreach ($disk in Get-PhysicalDisk) {
            try {
                $r = $disk | Get-StorageReliabilityCounter
                if ($null -ne $r.Temperature -and [double]$r.Temperature -gt 0 -and [double]$r.Temperature -lt 150) {
                    $out += [pscustomobject]@{ Name = "$($disk.FriendlyName) temperature"; Category='Disk'; Type='Temperature'; Value=[double]$r.Temperature; Source='Windows Storage' }
                }
            } catch {}
        }
    } catch {}
    return $out
}

function Get-AcpiThermalSensors {
    $out = @()
    try {
        Get-CimInstance -Namespace 'root/wmi' -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop | ForEach-Object {
            $c = ([double]$_.CurrentTemperature / 10.0) - 273.15
            if ($c -gt 0 -and $c -lt 150) {
                $name = if ($_.InstanceName) { "ACPI $($_.InstanceName)" } else { 'ACPI thermal zone' }
                $out += [pscustomobject]@{ Name=$name; Category='ThermalZone'; Type='Temperature'; Value=$c; Source='ACPI' }
            }
        }
    } catch {}
    return $out
}

function Get-AllSensors {
    $all = @()
    $all += @(Get-MonitorSensors)
    $all += @(Get-NvidiaSensors)
    $all += @(Get-StorageSensors)
    $all += @(Get-AcpiThermalSensors)

    # Deduplicate exact provider/name/value repeats while keeping different providers visible.
    return @($all | Sort-Object Source,Name,Value -Unique)
}

function Get-BestTemperatureSensors([string]$Category) {
    $all = @(Get-AllSensors | Where-Object { $_.Type -eq 'Temperature' })
    if ($Category -eq 'CPU') {
        $primary = @($all | Where-Object { $_.Category -eq 'CPU' })
        if ($primary.Count) { return $primary }
        return @($all | Where-Object { $_.Category -eq 'ThermalZone' })
    }
    if ($Category -eq 'GPU') { return @($all | Where-Object { $_.Category -eq 'GPU' }) }
    if ($Category -eq 'Disk') { return @($all | Where-Object { $_.Category -eq 'Disk' }) }
    return $all
}

function Show-TemperatureSensors([string]$Category) {
    $sensors = @(Get-BestTemperatureSensors $Category)
    if (-not $sensors.Count) {
        Write-Warn "$Category temperature unavailable."
        if ($Category -eq 'CPU') { Write-Muted 'No CPU sensor provider responded. ACPI thermal zones were also unavailable.' }
        return $false
    }
    foreach ($s in $sensors) {
        $label = if ($s.Category -eq 'ThermalZone') { "$($s.Name) [not guaranteed CPU]" } else { $s.Name }
        Write-KV $label ('{0:N1} °C  [{1}]' -f $s.Value, $s.Source)
    }
    return $true
}

# ---------------- Self-update ----------------

function Get-RemoteVersion {
    try {
        $text = (Invoke-WebRequest -UseBasicParsing -Uri "$script:RepoRaw/winfo.ps1" -TimeoutSec 5).Content
        $m = [regex]::Match($text, "\$script:Version\s*=\s*'([^']+)'")
        if ($m.Success) { return $m.Groups[1].Value }
    } catch {}
    return $null
}
function Save-UpdateCache([string]$RemoteVersion) {
    try {
        if (-not (Test-Path $script:InstallDir)) { New-Item -ItemType Directory -Path $script:InstallDir -Force | Out-Null }
        [pscustomobject]@{ checked=(Get-Date).ToUniversalTime().ToString('o'); version=$RemoteVersion } | ConvertTo-Json | Set-Content $script:UpdateCache -Encoding UTF8
    } catch {}
}
function Test-WinfoUpdate([switch]$Force) {
    $remote = $null
    if (-not $Force -and (Test-Path $script:UpdateCache)) {
        try {
            $cache = Get-Content $script:UpdateCache -Raw | ConvertFrom-Json
            if (((Get-Date).ToUniversalTime() - ([datetime]$cache.checked).ToUniversalTime()).TotalHours -lt 24) { $remote = [string]$cache.version }
        } catch {}
    }
    if (-not $remote) { $remote = Get-RemoteVersion; if ($remote) { Save-UpdateCache $remote } }
    if (-not $remote) { return $null }
    return [pscustomobject]@{ Current=$script:Version; Latest=$remote; Available=((Compare-Version $remote $script:Version) -gt 0) }
}
function Show-UpdateNotice {
    $status = Test-WinfoUpdate
    if ($status -and $status.Available) { Write-Host ''; Write-Warn "  Update available: v$($status.Current) -> v$($status.Latest)"; Write-Muted '  Run: winfo update' }
}
function Invoke-WinfoUpdate([string[]]$Rest) {
    $status = Test-WinfoUpdate -Force
    if (-not $status) { Write-Bad 'Could not check for updates.'; return }
    if ($Rest.Count -and $Rest[0].ToLower() -eq 'check') {
        if ($status.Available) { Write-Warn "Update available: v$($status.Current) -> v$($status.Latest)"; Write-Muted 'Run: winfo update' } else { Write-Good "winfo is up to date (v$script:Version)." }
        return
    }
    if (-not $status.Available) { Write-Good "winfo is already up to date (v$script:Version)."; return }
    try {
        Write-Accent "Updating winfo v$script:Version -> v$($status.Latest)..."
        $tmpPs1 = Join-Path $env:TEMP 'winfo-update.ps1'; $tmpCmd = Join-Path $env:TEMP 'winfo-update.cmd'
        Invoke-WebRequest -UseBasicParsing "$script:RepoRaw/winfo.ps1" -OutFile $tmpPs1 -TimeoutSec 15
        Invoke-WebRequest -UseBasicParsing "$script:RepoRaw/winfo.cmd" -OutFile $tmpCmd -TimeoutSec 15
        Copy-Item $tmpPs1 (Join-Path $script:InstallDir 'winfo.ps1') -Force
        Copy-Item $tmpCmd (Join-Path $script:InstallDir 'winfo.cmd') -Force
        Save-UpdateCache $status.Latest
        Write-Good "Updated to winfo v$($status.Latest)."
    } catch { Write-Bad "Update failed: $($_.Exception.Message)" }
}

# ---------------- Information commands ----------------

function Show-CPU([string[]]$Rest) {
    $sub = if ($Rest.Count) { $Rest[0].ToLower() } else { '' }
    if ($sub -eq 'temp') { Show-TemperatureSensors 'CPU' | Out-Null; return }
    if ($sub -eq 'load') { '{0:N1}%' -f [double](Get-CPU).LoadPercentage; return }
    if ($sub -eq 'clock') { $c=Get-CPU; Write-KV 'Current' "$($c.CurrentClockSpeed) MHz"; Write-KV 'Maximum' "$($c.MaxClockSpeed) MHz"; return }
    $c=Get-CPU; Write-Header 'CPU'; Write-KV 'Model' $c.Name.Trim(); Write-KV 'Cores' $c.NumberOfCores; Write-KV 'Threads' $c.NumberOfLogicalProcessors; Write-KV 'Current clock' "$($c.CurrentClockSpeed) MHz"; Write-KV 'Max clock' "$($c.MaxClockSpeed) MHz"; Write-KV 'Load' "$($c.LoadPercentage)%"
}
function Show-GPU([string[]]$Rest) {
    $sub = if ($Rest.Count) { $Rest[0].ToLower() } else { '' }
    if ($sub -eq 'temp') { Show-TemperatureSensors 'GPU' | Out-Null; return }
    if ($sub -eq 'load') {
        $s=@(Get-AllSensors|Where-Object{$_.Category-eq'GPU'-and$_.Type-eq'Load'}); if($s.Count){$s|ForEach-Object{Write-KV $_.Name ('{0:N1}%  [{1}]'-f$_.Value,$_.Source)}}else{Write-Warn 'GPU load unavailable.'}; return
    }
    if ($sub -eq 'vram') {
        $s=@(Get-AllSensors|Where-Object{$_.Category-eq'GPU'-and$_.Type-like'VRAM*'}); if($s.Count){$s|ForEach-Object{Write-KV $_.Name ('{0:N0} MiB  [{1}]'-f$_.Value,$_.Source)}}else{foreach($g in Get-GPU){if($g.AdapterRAM){Write-KV $g.Name (Format-Bytes $g.AdapterRAM)}}}; return
    }
    Write-Header 'GPU'; foreach($g in Get-GPU){Write-KV 'Model' $g.Name; if($g.AdapterRAM){Write-KV 'Reported VRAM' (Format-Bytes $g.AdapterRAM)}; Write-KV 'Driver' $g.DriverVersion}
}
function Show-RAM([string[]]$Rest) {
    $os=Get-OSInfo; $sticks=@(Get-CimInstance Win32_PhysicalMemory); $total=($sticks|Measure-Object Capacity -Sum).Sum; $free=[double]$os.FreePhysicalMemory*1KB; $used=$total-$free
    if($Rest.Count -and $Rest[0].ToLower() -eq 'modules'){$sticks|Select-Object BankLabel,DeviceLocator,@{N='Capacity';E={Format-Bytes $_.Capacity}},Speed,Manufacturer,PartNumber|Format-Table -AutoSize;return}
    Write-Header 'Memory'; Write-KV 'Installed' (Format-Bytes $total); Write-KV 'Used' (Format-Bytes $used); Write-KV 'Available' (Format-Bytes $free); Write-KV 'Usage' ('{0:N1}%'-f(100*$used/$total))
}
function Show-Disk([string[]]$Rest) {
    $sub=if($Rest.Count){$Rest[0].ToLower()}else{''}
    if($sub-eq'temp'){Show-TemperatureSensors 'Disk'|Out-Null;return}
    if($sub-eq'health'){Get-PhysicalDisk|Select-Object FriendlyName,MediaType,HealthStatus,OperationalStatus|Format-Table -AutoSize;return}
    if($sub-eq'usage'){Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3'|ForEach-Object{$used=$_.Size-$_.FreeSpace;Write-KV $_.DeviceID "$(Format-Bytes $used) / $(Format-Bytes $_.Size) used"};return}
    Write-Header 'Storage'; Get-PhysicalDisk|Select-Object FriendlyName,MediaType,BusType,@{N='Size';E={Format-Bytes $_.Size}},HealthStatus|Format-Table -AutoSize
}
function Show-Temps {
    $s=@(Get-AllSensors|Where-Object{$_.Type-eq'Temperature'})
    if(-not$s.Count){Write-Warn 'No temperature provider returned data.';return}
    Write-Header 'Temperatures'
    foreach($x in $s|Sort-Object Category,Name,Source){Write-KV "$($x.Category): $($x.Name)" ('{0:N1} °C  [{1}]'-f$x.Value,$x.Source)}
}
function Show-SensorProviders {
    Write-Header 'Temperature providers'
    Write-KV 'LibreHardwareMonitor' $(if((Get-MonitorSensors|Where-Object Source-eq'LibreHardwareMonitor')){'Available'}else{'Unavailable'})
    Write-KV 'OpenHardwareMonitor' $(if((Get-MonitorSensors|Where-Object Source-eq'OpenHardwareMonitor')){'Available'}else{'Unavailable'})
    Write-KV 'NVIDIA SMI' $(if((Get-NvidiaSensors).Count){'Available'}else{'Unavailable'})
    Write-KV 'Windows Storage' $(if((Get-StorageSensors).Count){'Available'}else{'Unavailable'})
    Write-KV 'ACPI thermal zones' $(if((Get-AcpiThermalSensors).Count){'Available'}else{'Unavailable'})
}
function Show-OS { $o=Get-OSInfo;Write-Header 'Windows';Write-KV 'Edition' $o.Caption;Write-KV 'Version' $o.Version;Write-KV 'Build' $o.BuildNumber;Write-KV 'Architecture' $o.OSArchitecture;Write-KV 'Hostname' $env:COMPUTERNAME;Write-KV 'Uptime' (Format-Uptime $o.LastBootUpTime) }
function Show-Board { $b=Get-Board;Write-Header 'Motherboard';Write-KV 'Manufacturer' $b.Manufacturer;Write-KV 'Product' $b.Product;Write-KV 'Version' $b.Version;Write-KV 'Serial' $b.SerialNumber }
function Show-BIOS { $b=Get-BIOSInfo;Write-Header 'BIOS / UEFI';Write-KV 'Vendor' $b.Manufacturer;Write-KV 'Version' $b.SMBIOSBIOSVersion;Write-KV 'Release date' $b.ReleaseDate;try{Write-KV 'Secure Boot' $(if(Confirm-SecureBootUEFI){'Enabled'}else{'Disabled'})}catch{Write-KV 'Secure Boot' 'Unavailable'} }
function Show-Battery([string[]]$Rest) { $b=Get-CimInstance Win32_Battery;if(-not$b){Write-Warn 'No battery detected.';return};Write-Header 'Battery';Write-KV 'Charge' "$($b.EstimatedChargeRemaining)%";Write-KV 'Status' $b.Status }
function Show-Display { Get-CimInstance Win32_VideoController|Select-Object Name,DriverVersion,CurrentHorizontalResolution,CurrentVerticalResolution,CurrentRefreshRate|Format-Table -AutoSize }
function Show-Wifi([string[]]$Rest) { $txt=netsh wlan show interfaces;if($Rest.Count -and $Rest[0].ToLower()-eq'signal'){$txt|Where-Object{$_-match'^\s*(SSID|Signal|Receive rate|Transmit rate|Channel)\s*:'}}else{$txt} }
function Show-USB { Get-PnpDevice -PresentOnly|Where-Object{$_.InstanceId-like'USB*'-or$_.Class-eq'USB'}|Select-Object Status,Class,FriendlyName|Format-Table -AutoSize }
function Show-Audio { Get-CimInstance Win32_SoundDevice|Select-Object Name,Manufacturer,Status|Format-Table -AutoSize }
function Show-Devices([string[]]$Rest) { $q=if($Rest.Count){($Rest-join' ').ToLower()}else{''};$x=Get-PnpDevice -PresentOnly;if($q){$x=$x|Where-Object{([string]$_.FriendlyName).ToLower().Contains($q)-or([string]$_.Class).ToLower().Contains($q)}};$x|Select-Object Status,Class,FriendlyName|Format-Table -AutoSize }
function Show-DX { $d=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\DirectX';Write-KV 'DirectX version' $d.Version;Get-GPU|ForEach-Object{Write-KV $_.Name $_.DriverVersion} }
function Show-DNS { Get-DnsClientServerAddress -AddressFamily IPv4|Where-Object{$_.ServerAddresses.Count-gt0}|Select-Object InterfaceAlias,ServerAddresses|Format-Table -AutoSize }
function Show-PublicIP { try{(Invoke-RestMethod 'https://api.ipify.org?format=text' -TimeoutSec 5).Trim()}catch{Write-Warn 'Could not reach public IP service.'} }
function Show-Ports { Get-NetTCPConnection -State Listen|Sort-Object LocalPort -Unique|Select-Object LocalAddress,LocalPort,OwningProcess,@{N='Process';E={(Get-Process -Id $_.OwningProcess).ProcessName}}|Format-Table -AutoSize }
function Show-Network([string[]]$Rest) { $s=if($Rest.Count){$Rest[0].ToLower()}else{''};if($s-eq'ip'){Get-NetIPAddress -AddressFamily IPv4|Where-Object{$_.IPAddress-notlike'169.254*'}|Select-Object InterfaceAlias,IPAddress,PrefixLength|Format-Table -AutoSize;return};if($s-eq'dns'){Show-DNS;return};if($s-eq'public'){Show-PublicIP;return};if($s-eq'ports'){Show-Ports;return};Get-NetAdapter|Where-Object Status-eq'Up'|Format-Table Name,InterfaceDescription,LinkSpeed,MacAddress -AutoSize }
function Show-Ping([string[]]$Rest) { $target=if($Rest.Count){$Rest[0]}else{'1.1.1.1'};Test-Connection $target -Count 4 }
function Show-Processes([string[]]$Rest) { $n=15;if($Rest.Count -and $Rest[0]-as[int]){$n=[int]$Rest[0]};Get-Process|Sort-Object CPU -Descending|Select-Object -First $n Id,ProcessName,@{N='CPU(s)';E={[math]::Round($_.CPU,1)}},@{N='RAM(MB)';E={[math]::Round($_.WorkingSet64/1MB,1)}}|Format-Table -AutoSize }
function Show-Services([string[]]$Rest) { $f=if($Rest.Count){$Rest-join' '}else{''};$x=Get-Service;if($f){$x=$x|Where-Object{$_.Name-like"*$f*"-or$_.DisplayName-like"*$f*"}};$x|Format-Table Status,Name,DisplayName -AutoSize }
function Show-Startup { Get-CimInstance Win32_StartupCommand|Select-Object Name,Location,Command|Format-Table -Wrap -AutoSize }
function Show-Software([string[]]$Rest) { $q=if($Rest.Count){($Rest-join' ').ToLower()}else{''};$p=@('HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*');$a=Get-ItemProperty $p|Where-Object DisplayName|Select-Object DisplayName,DisplayVersion,Publisher|Sort-Object DisplayName -Unique;if($q){$a=$a|Where-Object{$_.DisplayName.ToLower().Contains($q)}};$a|Format-Table -AutoSize }
function Show-Drivers([string[]]$Rest) { $q=if($Rest.Count){($Rest-join' ').ToLower()}else{''};$d=Get-CimInstance Win32_PnPSignedDriver|Where-Object DeviceName;if($q){$d=$d|Where-Object{$_.DeviceName.ToLower().Contains($q)}};$d|Select-Object DeviceName,Manufacturer,DriverVersion|Format-Table -AutoSize }
function Show-Updates { Get-HotFix|Sort-Object InstalledOn -Descending|Select-Object -First 20 HotFixID,Description,InstalledOn|Format-Table -AutoSize }
function Show-Power { Write-Header 'Power';Write-KV 'Active plan' ((powercfg /getactivescheme)-join' ');powercfg /a }
function Show-Firewall { Get-NetFirewallProfile|Select-Object Name,Enabled,DefaultInboundAction,DefaultOutboundAction|Format-Table -AutoSize }
function Show-TPM { $t=Get-Tpm;Write-KV 'Present' $t.TpmPresent;Write-KV 'Ready' $t.TpmReady;Write-KV 'Enabled' $t.TpmEnabled }
function Show-Virtualization { $c=Get-CPU;$s=Get-Computer;Write-KV 'Firmware virtualization' $c.VirtualizationFirmwareEnabled;Write-KV 'Hypervisor present' $s.HypervisorPresent }
function Show-Uptime { Format-Uptime (Get-OSInfo).LastBootUpTime }
function Show-Summary { $c=Get-CPU;$o=Get-OSInfo;$s=Get-Computer;$g=Get-GPU|Select-Object -First 1;Write-Header 'System summary';Write-KV 'OS' "$($o.Caption) build $($o.BuildNumber)";Write-KV 'Device' "$($s.Manufacturer) $($s.Model)";Write-KV 'CPU' $c.Name.Trim();Write-KV 'GPU' $g.Name;Write-KV 'RAM' (Format-Bytes $s.TotalPhysicalMemory);Write-KV 'Uptime' (Format-Uptime $o.LastBootUpTime) }
function Show-Health { Write-Header 'System health';$o=Get-OSInfo;Write-KV 'RAM usage' ('{0:N1}%'-f(100-(100*$o.FreePhysicalMemory/$o.TotalVisibleMemorySize)));Get-PhysicalDisk|ForEach-Object{Write-KV "Disk: $($_.FriendlyName)" $_.HealthStatus};$cpu=@(Get-BestTemperatureSensors 'CPU');if($cpu.Count){Write-KV 'CPU/thermal max' ('{0:N1} °C'-f(($cpu|Measure-Object Value -Maximum).Maximum))}else{Write-KV 'CPU temperature' 'Unavailable'} }
function Show-Environment([string[]]$Rest) { if($Rest.Count -and $Rest[0].ToLower()-eq'path'){$env:Path-split';'|Where-Object{$_};return};Get-ChildItem Env:|Sort-Object Name|Format-Table -AutoSize }
function Show-Doctor { Write-Header 'winfo doctor';Write-KV 'PowerShell' $PSVersionTable.PSVersion;Write-KV 'CIM' $(if(Get-Command Get-CimInstance){'OK'}else{'Missing'});Write-KV 'Storage API' $(if(Get-Command Get-PhysicalDisk){'OK'}else{'Missing'});Write-KV 'NVIDIA SMI' $(if((Get-NvidiaSensors).Count){'Available'}else{'Unavailable'});Write-KV 'Monitor WMI' $(if((Get-MonitorSensors).Count){'Available'}else{'Unavailable'});Write-KV 'ACPI thermal' $(if((Get-AcpiThermalSensors).Count){'Available'}else{'Unavailable'}) }

function Show-Help {
    Write-Header 'Commands'
    $rows = @(
        @('summary','Compact system overview'), @('health','Quick health overview'), @('temps','All available temperatures'), @('temps providers','Show temperature providers'),
        @('cpu','CPU details'), @('cpu temp','CPU temperature with fallbacks'), @('cpu load','CPU load'), @('cpu clock','CPU clocks'),
        @('gpu','GPU details'), @('gpu temp','GPU temperature with fallbacks'), @('gpu load','GPU load'), @('gpu vram','VRAM information'),
        @('ram','Memory usage'), @('ram modules','DIMM details'), @('disk','Storage overview'), @('disk health','Disk health'), @('disk temp','Disk temperatures'), @('disk usage','Volume usage'),
        @('battery','Battery'), @('display','Displays'), @('wifi','Wi-Fi'), @('wifi signal','Wi-Fi signal'), @('network','Network'), @('network ip','IPv4'), @('network dns','DNS'), @('network public','Public IP'), @('network ports','Ports'),
        @('os','Windows'), @('board','Motherboard'), @('bios','BIOS/UEFI'), @('usb','USB'), @('audio','Audio'), @('devices [query]','PnP devices'), @('dx','DirectX'),
        @('processes [n]','Processes'), @('services [query]','Services'), @('startup','Startup apps'), @('software [query]','Software'), @('drivers [query]','Drivers'), @('updates','Windows updates'),
        @('update','Update winfo'), @('update check','Check for winfo update'), @('ping [host]','Ping'), @('power','Power'), @('firewall','Firewall'), @('tpm','TPM'), @('virtualization','Virtualization'), @('env','Environment'), @('uptime','Uptime'), @('doctor','Provider diagnostics'), @('help','Help')
    )
    foreach ($r in $rows) {
        Write-Host ('  {0,-24}' -f $r[0]) -ForegroundColor Cyan -NoNewline
        Write-Host $r[1] -ForegroundColor Gray
    }
}

function Invoke-WinfoCommand([string[]]$Tokens) {
    if (-not $Tokens -or $Tokens.Count -eq 0) { Show-Summary; return }
    $cmd=$Tokens[0].ToLower(); $rest=if($Tokens.Count -gt 1){@($Tokens[1..($Tokens.Count-1)])}else{@()}
    switch($cmd) {
        'summary'{Show-Summary}; 'health'{Show-Health}; 'temps'{if($rest.Count -and $rest[0].ToLower()-eq'providers'){Show-SensorProviders}else{Show-Temps}}; 'temp'{Show-Temps}
        'cpu'{Show-CPU $rest}; 'gpu'{Show-GPU $rest}; 'ram'{Show-RAM $rest}; 'memory'{Show-RAM $rest}; 'disk'{Show-Disk $rest}; 'storage'{Show-Disk $rest}
        'os'{Show-OS}; 'system'{Show-OS}; 'board'{Show-Board}; 'motherboard'{Show-Board}; 'bios'{Show-BIOS}; 'battery'{Show-Battery $rest}; 'display'{Show-Display}; 'monitor'{Show-Display}; 'wifi'{Show-Wifi $rest}; 'usb'{Show-USB}; 'audio'{Show-Audio}; 'devices'{Show-Devices $rest}; 'device'{Show-Devices $rest}; 'dx'{Show-DX}; 'directx'{Show-DX}
        'network'{Show-Network $rest}; 'net'{Show-Network $rest}; 'dns'{Show-DNS}; 'publicip'{Show-PublicIP}; 'ports'{Show-Ports}; 'ping'{Show-Ping $rest}
        'processes'{Show-Processes $rest}; 'ps'{Show-Processes $rest}; 'services'{Show-Services $rest}; 'startup'{Show-Startup}; 'software'{Show-Software $rest}; 'apps'{Show-Software $rest}; 'drivers'{Show-Drivers $rest}; 'updates'{Show-Updates}
        'power'{Show-Power}; 'firewall'{Show-Firewall}; 'tpm'{Show-TPM}; 'virtualization'{Show-Virtualization}; 'virt'{Show-Virtualization}; 'env'{Show-Environment $rest}; 'uptime'{Show-Uptime}; 'doctor'{Show-Doctor}
        'update'{Invoke-WinfoUpdate $rest}; 'upgrade'{Invoke-WinfoUpdate $rest}; 'help'{Show-Help}; '--help'{Show-Help}; '-h'{Show-Help}; 'version'{"winfo $script:Version"}; '--version'{"winfo $script:Version"}
        default{Write-Bad "Unknown command: $cmd";Write-Muted 'Run: winfo help'}
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
    Show-UpdateNotice
    Write-Host ''
}
function Start-WinfoShell {
    Show-Banner
    while($true) {
        Write-Host 'winfo' -ForegroundColor Cyan -NoNewline; Write-Host ' › ' -ForegroundColor DarkGray -NoNewline
        $line=Read-Host; if($null-eq$line){break}; $line=$line.Trim(); if(-not$line){continue}
        if($line.ToLower()-in@('exit','quit','q')){break}; if($line.ToLower()-in@('clear','cls')){Clear-Host;Show-Banner;continue}
        $tokens=[regex]::Matches($line,'(?:[^\s"]+|"[^"]*")+')|ForEach-Object{$_.Value.Trim('"')}; Invoke-WinfoCommand @($tokens)
    }
}

if($Args.Count -eq 0){Start-WinfoShell}else{Invoke-WinfoCommand $Args}
