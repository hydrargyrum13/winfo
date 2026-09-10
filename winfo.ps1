param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$ErrorActionPreference = 'SilentlyContinue'
$script:Version = '0.3.0'
$script:Accent = 'Cyan'
$script:Muted = 'DarkGray'
$script:Good = 'Green'
$script:Warn = 'Yellow'
$script:Bad = 'Red'

function Write-Accent([string]$Text,[switch]$NoNewline){Write-Host $Text -ForegroundColor $script:Accent -NoNewline:$NoNewline}
function Write-Muted([string]$Text,[switch]$NoNewline){Write-Host $Text -ForegroundColor $script:Muted -NoNewline:$NoNewline}
function Write-Good([string]$Text){Write-Host $Text -ForegroundColor $script:Good}
function Write-Warn([string]$Text){Write-Host $Text -ForegroundColor $script:Warn}
function Write-Bad([string]$Text){Write-Host $Text -ForegroundColor $script:Bad}
function Write-KV([string]$Key,$Value){Write-Host ('  {0,-20}' -f $Key) -ForegroundColor DarkGray -NoNewline; Write-Host ([string]$Value) -ForegroundColor White}
function Write-Header([string]$Title){Write-Host '';Write-Accent "  $Title";Write-Muted ('  '+('─'*([Math]::Max(8,$Title.Length))))}
function Format-Bytes([double]$Bytes){$u=@('B','KiB','MiB','GiB','TiB');$i=0;while($Bytes-ge 1024-and$i-lt$u.Count-1){$Bytes/=1024;$i++};'{0:N2} {1}'-f $Bytes,$u[$i]}
function Format-Uptime([datetime]$Boot){$u=(Get-Date)-$Boot;'{0}d {1}h {2}m'-f[int]$u.TotalDays,$u.Hours,$u.Minutes}
function Get-CPU{Get-CimInstance Win32_Processor|Select-Object -First 1}
function Get-GPU{Get-CimInstance Win32_VideoController}
function Get-OSInfo{Get-CimInstance Win32_OperatingSystem}
function Get-Board{Get-CimInstance Win32_BaseBoard|Select-Object -First 1}
function Get-BIOSInfo{Get-CimInstance Win32_BIOS|Select-Object -First 1}
function Get-Computer{Get-CimInstance Win32_ComputerSystem|Select-Object -First 1}

function Get-HardwareSensors {
    $out=@()
    foreach($ns in @('root/LibreHardwareMonitor','root/OpenHardwareMonitor')){
        try{
            Get-CimInstance -Namespace $ns -ClassName Sensor -ErrorAction Stop|ForEach-Object{
                $out+=[pscustomobject]@{Name=$_.Name;Type=$_.SensorType;Value=[double]$_.Value;Min=$_.Min;Max=$_.Max;Identifier=$_.Identifier;Source=$ns}
            }
        }catch{}
    }
    $out
}
function Get-Sensors([string]$Kind,[string]$Type){Get-HardwareSensors|Where-Object{$_.Type-eq$Type-and($_.Name-match$Kind-or$_.Identifier-match$Kind)}}
function Show-SensorValues($Sensors,[string]$Unit){if(-not $Sensors){return $false};$Sensors|Sort-Object Name|ForEach-Object{Write-KV $_.Name ('{0:N1}{1}'-f$_.Value,$Unit)};return $true}

function Show-CPU([string[]]$Rest){
    $sub=if($Rest.Count){$Rest[0].ToLower()}else{''}
    if($sub-eq'temp'){$s=Get-Sensors 'CPU|Core|Package' 'Temperature';if(-not(Show-SensorValues $s ' °C')){Write-Warn 'CPU temperature unavailable.';Write-Muted 'Run LibreHardwareMonitor or OpenHardwareMonitor and retry.'};return}
    if($sub-eq'load'){$c=Get-CimInstance Win32_Processor|Select-Object -First 1;'{0:N1}%'-f[double]$c.LoadPercentage;return}
    if($sub-eq'clock'){$c=Get-CPU;Write-KV 'Current' "$($c.CurrentClockSpeed) MHz";Write-KV 'Maximum' "$($c.MaxClockSpeed) MHz";return}
    $cpu=Get-CPU;if(-not$cpu){Write-Bad 'CPU information unavailable.';return}
    Write-Header 'CPU';Write-KV 'Model' $cpu.Name.Trim();Write-KV 'Cores' $cpu.NumberOfCores;Write-KV 'Threads' $cpu.NumberOfLogicalProcessors;Write-KV 'Max clock' "$($cpu.MaxClockSpeed) MHz";Write-KV 'Current clock' "$($cpu.CurrentClockSpeed) MHz";Write-KV 'Load' "$($cpu.LoadPercentage)%";Write-KV 'Architecture' $env:PROCESSOR_ARCHITECTURE;Write-KV 'Virtualization' $(if($cpu.VirtualizationFirmwareEnabled){'Enabled'}else{'Disabled / unavailable'})
}

function Show-GPU([string[]]$Rest){
    $sub=if($Rest.Count){$Rest[0].ToLower()}else{''}
    if($sub-eq'temp'){$s=Get-Sensors 'GPU' 'Temperature';if(-not(Show-SensorValues $s ' °C')){Write-Warn 'GPU temperature unavailable.';Write-Muted 'Run LibreHardwareMonitor or OpenHardwareMonitor and retry.'};return}
    if($sub-eq'load'){$s=Get-Sensors 'GPU' 'Load';if(-not(Show-SensorValues $s '%')){Write-Warn 'GPU load sensor unavailable.'};return}
    if($sub-eq'vram'){$g=Get-GPU;foreach($x in $g){if($x.AdapterRAM){Write-KV $x.Name (Format-Bytes $x.AdapterRAM)}else{Write-KV $x.Name 'Unavailable'}};return}
    Write-Header 'GPU';foreach($g in Get-GPU){Write-KV 'Model' $g.Name;if($g.AdapterRAM){Write-KV 'Reported VRAM' (Format-Bytes $g.AdapterRAM)};Write-KV 'Driver' $g.DriverVersion;if($g.CurrentHorizontalResolution){Write-KV 'Resolution' "$($g.CurrentHorizontalResolution)x$($g.CurrentVerticalResolution) @ $($g.CurrentRefreshRate)Hz"};Write-Host ''}
}

function Show-RAM([string[]]$Rest){
    $os=Get-OSInfo;$sticks=@(Get-CimInstance Win32_PhysicalMemory);$total=($sticks|Measure-Object Capacity -Sum).Sum;$free=[double]$os.FreePhysicalMemory*1KB;$used=$total-$free;$pct=($used/$total)*100
    if($Rest.Count-and$Rest[0].ToLower()-eq'usage'){Write-KV 'Used' (Format-Bytes $used);Write-KV 'Available' (Format-Bytes $free);Write-KV 'Usage' ('{0:N1}%'-f$pct);return}
    if($Rest.Count-and$Rest[0].ToLower()-eq'modules'){$sticks|Select-Object BankLabel,DeviceLocator,@{N='Capacity';E={Format-Bytes $_.Capacity}},Speed,ConfiguredClockSpeed,Manufacturer,PartNumber|Format-Table -AutoSize;return}
    Write-Header 'Memory';Write-KV 'Installed' (Format-Bytes $total);Write-KV 'Used' (Format-Bytes $used);Write-KV 'Available' (Format-Bytes $free);Write-KV 'Usage' ('{0:N1}%'-f$pct);Write-KV 'Modules' $sticks.Count;foreach($s in $sticks){Write-KV 'DIMM' "$(Format-Bytes $s.Capacity)  $($s.Speed) MT/s  $($s.Manufacturer)"}
}

function Show-Disk([string[]]$Rest){
    $sub=if($Rest.Count){$Rest[0].ToLower()}else{''}
    if($sub-eq'health'){Get-PhysicalDisk|Select-Object FriendlyName,MediaType,HealthStatus,OperationalStatus|Format-Table -AutoSize;return}
    if($sub-eq'temp'){$s=Get-Sensors 'SSD|HDD|NVMe|Drive|Disk' 'Temperature';if(-not(Show-SensorValues $s ' °C')){Write-Warn 'Disk temperature unavailable.'};return}
    if($sub-eq'usage'){Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3'|ForEach-Object{$used=$_.Size-$_.FreeSpace;Write-KV $_.DeviceID "$(Format-Bytes $used) / $(Format-Bytes $_.Size) used"};return}
    Write-Header 'Storage';foreach($d in Get-PhysicalDisk){Write-KV 'Drive' $d.FriendlyName;Write-KV 'Type' $d.MediaType;Write-KV 'Bus' $d.BusType;Write-KV 'Size' (Format-Bytes $d.Size);Write-KV 'Health' $d.HealthStatus;Write-Host ''};Write-Muted '  Volumes';Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3'|ForEach-Object{$used=$_.Size-$_.FreeSpace;Write-KV $_.DeviceID "$(Format-Bytes $used) / $(Format-Bytes $_.Size) used"}
}

function Show-OS{ $os=Get-OSInfo;Write-Header 'Windows';Write-KV 'Edition' $os.Caption;Write-KV 'Version' $os.Version;Write-KV 'Build' $os.BuildNumber;Write-KV 'Architecture' $os.OSArchitecture;Write-KV 'Installed' $os.InstallDate;Write-KV 'Hostname' $env:COMPUTERNAME;Write-KV 'User' $env:USERNAME;Write-KV 'Uptime' (Format-Uptime $os.LastBootUpTime)}
function Show-Board{$b=Get-Board;Write-Header 'Motherboard';Write-KV 'Manufacturer' $b.Manufacturer;Write-KV 'Product' $b.Product;Write-KV 'Version' $b.Version;Write-KV 'Serial' $b.SerialNumber}
function Show-BIOS{$b=Get-BIOSInfo;Write-Header 'BIOS / UEFI';Write-KV 'Vendor' $b.Manufacturer;Write-KV 'Version' $b.SMBIOSBIOSVersion;Write-KV 'Release date' $b.ReleaseDate;try{Write-KV 'Secure Boot' $(if(Confirm-SecureBootUEFI){'Enabled'}else{'Disabled'})}catch{Write-KV 'Secure Boot' 'Unavailable / legacy BIOS'}}

function Show-Battery([string[]]$Rest){
    $b=Get-CimInstance Win32_Battery;if(-not$b){Write-Warn 'No battery detected.';return}
    $sub=if($Rest.Count){$Rest[0].ToLower()}else{''}
    if($sub-eq'health'){
        $static=Get-CimInstance -Namespace root\wmi -Class BatteryStaticData|Select-Object -First 1;$full=Get-CimInstance -Namespace root\wmi -Class BatteryFullChargedCapacity|Select-Object -First 1
        if($static.DesignedCapacity-and$full.FullChargedCapacity){$h=100*$full.FullChargedCapacity/$static.DesignedCapacity;Write-KV 'Design capacity' "$($static.DesignedCapacity) mWh";Write-KV 'Full charge capacity' "$($full.FullChargedCapacity) mWh";Write-KV 'Health' ('{0:N1}%'-f$h)}else{Write-Warn 'Battery health data unavailable.'};return
    }
    Write-Header 'Battery';Write-KV 'Charge' "$($b.EstimatedChargeRemaining)%";Write-KV 'Status' $b.Status;if($b.EstimatedRunTime-and$b.EstimatedRunTime-lt71582788){Write-KV 'Runtime' "$($b.EstimatedRunTime) min"}
}

function Show-Network([string[]]$Rest){
    $sub=if($Rest.Count){$Rest[0].ToLower()}else{''}
    if($sub-eq'ip'){Get-NetIPAddress -AddressFamily IPv4|Where-Object{$_.IPAddress-notlike'169.254*'}|Select-Object InterfaceAlias,IPAddress,PrefixLength|Format-Table -AutoSize;return}
    if($sub-eq'dns'){Show-DNS;return}
    if($sub-eq'public'){Show-PublicIP;return}
    if($sub-eq'ports'){Show-Ports;return}
    Write-Header 'Network';Get-NetAdapter|Where-Object Status-eq'Up'|ForEach-Object{Write-KV 'Adapter' $_.Name;Write-KV 'Interface' $_.InterfaceDescription;Write-KV 'Link speed' $_.LinkSpeed;Write-KV 'MAC' $_.MacAddress;Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4|Where-Object{$_.IPAddress-notlike'169.254*'}|ForEach-Object{Write-KV 'IPv4' $_.IPAddress};Write-Host ''}
}
function Show-Ports{Get-NetTCPConnection -State Listen|Sort-Object LocalPort -Unique|Select-Object LocalAddress,LocalPort,OwningProcess,@{N='Process';E={(Get-Process -Id $_.OwningProcess).ProcessName}}|Format-Table -AutoSize}
function Show-Processes([string[]]$Rest){$n=15;if($Rest.Count-and$Rest[0]-as[int]){$n=[int]$Rest[0]};Get-Process|Sort-Object CPU -Descending|Select-Object -First $n Id,ProcessName,@{N='CPU(s)';E={if($_.CPU){[math]::Round($_.CPU,1)}else{0}}},@{N='RAM(MB)';E={[math]::Round($_.WorkingSet64/1MB,1)}}|Format-Table -AutoSize}
function Show-Services([string[]]$Rest){$f=if($Rest.Count){$Rest-join' '}else{''};$x=Get-Service;if($f){$x=$x|Where-Object{$_.Name-like"*$f*"-or$_.DisplayName-like"*$f*"}};$x|Sort-Object Status,Name|Format-Table Status,Name,DisplayName -AutoSize}
function Show-Startup{Get-CimInstance Win32_StartupCommand|Select-Object Name,Location,Command|Format-Table -Wrap -AutoSize}
function Show-Software([string[]]$Rest){$f=if($Rest.Count){($Rest-join' ').ToLower()}else{''};$p=@('HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*');$a=Get-ItemProperty $p|Where-Object DisplayName|Select-Object DisplayName,DisplayVersion,Publisher,InstallDate|Sort-Object DisplayName -Unique;if($f){$a=$a|Where-Object{$_.DisplayName.ToLower().Contains($f)}};$a|Format-Table -AutoSize}
function Show-Drivers([string[]]$Rest){$f=if($Rest.Count){($Rest-join' ').ToLower()}else{''};$d=Get-CimInstance Win32_PnPSignedDriver|Where-Object DeviceName;if($f){$d=$d|Where-Object{$_.DeviceName.ToLower().Contains($f)-or([string]$_.Manufacturer).ToLower().Contains($f)}};$d|Select-Object DeviceName,Manufacturer,DriverVersion,DriverDate|Sort-Object DeviceName|Format-Table -AutoSize}
function Show-Updates{Get-HotFix|Sort-Object InstalledOn -Descending|Select-Object -First 20 HotFixID,Description,InstalledOn|Format-Table -AutoSize}
function Show-Environment([string[]]$Rest){if($Rest.Count-and$Rest[0].ToLower()-eq'path'){$env:Path-split';'|Where-Object{$_};return};Get-ChildItem Env:|Sort-Object Name|Format-Table -AutoSize}
function Show-TPM{try{$t=Get-Tpm;Write-Header 'TPM';Write-KV 'Present' $t.TpmPresent;Write-KV 'Ready' $t.TpmReady;Write-KV 'Enabled' $t.TpmEnabled;Write-KV 'Activated' $t.TpmActivated;Write-KV 'Owned' $t.TpmOwned}catch{Write-Warn 'TPM information unavailable.'}}
function Show-Virtualization{Write-Header 'Virtualization';$c=Get-CPU;$s=Get-Computer;Write-KV 'Firmware virtualization' $c.VirtualizationFirmwareEnabled;Write-KV 'Hypervisor present' $s.HypervisorPresent;Get-WindowsOptionalFeature -Online|Where-Object{$_.FeatureName-match'Hyper-V|VirtualMachinePlatform|Windows-Subsystem-Linux'}|ForEach-Object{Write-KV $_.FeatureName $_.State}}

function Show-Temps{$s=Get-HardwareSensors|Where-Object Type-eq'Temperature';if(-not$s){Write-Warn 'No compatible hardware sensor provider detected.';Write-Muted 'LibreHardwareMonitor or OpenHardwareMonitor can expose temperature sensors.';return};Write-Header 'Temperatures';$s|Sort-Object Name|ForEach-Object{Write-KV $_.Name ('{0:N1} °C'-f$_.Value)}}
function Show-Health{Write-Header 'System health';$os=Get-OSInfo;$ram=100-(($os.FreePhysicalMemory/$os.TotalVisibleMemorySize)*100);Write-KV 'RAM usage' ('{0:N1}%'-f$ram);foreach($d in Get-PhysicalDisk){Write-KV "Disk: $($d.FriendlyName)" $d.HealthStatus};$p=Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired';Write-KV 'Reboot pending' $(if($p){'Yes'}else{'No'});$t=Get-Sensors 'CPU|Core|Package' 'Temperature';if($t){Write-KV 'CPU max temp' ('{0:N1} °C'-f(($t|Measure-Object Value -Maximum).Maximum))}else{Write-KV 'CPU temp' 'Sensor provider unavailable'}}
function Show-Display{Write-Header 'Display';foreach($g in Get-GPU){Write-KV 'Adapter' $g.Name;if($g.CurrentHorizontalResolution){Write-KV 'Mode' "$($g.CurrentHorizontalResolution)x$($g.CurrentVerticalResolution) @ $($g.CurrentRefreshRate)Hz"}};Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID|ForEach-Object{$n=-join($_.UserFriendlyName|Where-Object{$_-ne0}|ForEach-Object{[char]$_});$m=-join($_.ManufacturerName|Where-Object{$_-ne0}|ForEach-Object{[char]$_});if($n-or$m){Write-KV 'Monitor' "$m $n".Trim()}}}
function Show-Wifi([string[]]$Rest){$txt=netsh wlan show interfaces;if(-not$txt){Write-Warn 'Wi-Fi interface unavailable.';return};if($Rest.Count-and$Rest[0].ToLower()-eq'signal'){$txt|Where-Object{$_-match'^\s*(SSID|Signal|Receive rate|Transmit rate|Channel)\s*:'};return};Write-Header 'Wi-Fi';$txt|Where-Object{$_-match'^\s*(Name|Description|State|SSID|BSSID|Radio type|Authentication|Cipher|Channel|Receive rate|Transmit rate|Signal)\s*:'}}
function Show-USB{Get-PnpDevice -PresentOnly|Where-Object{$_.InstanceId-like'USB*'-or$_.Class-eq'USB'}|Select-Object Status,Class,FriendlyName,InstanceId|Format-Table -AutoSize}
function Show-Audio{Get-CimInstance Win32_SoundDevice|Select-Object Name,Manufacturer,Status,PNPDeviceID|Format-Table -AutoSize}
function Show-Devices([string[]]$Rest){$q=if($Rest.Count){($Rest-join' ').ToLower()}else{''};$x=Get-PnpDevice -PresentOnly;if($q){$x=$x|Where-Object{([string]$_.FriendlyName).ToLower().Contains($q)-or([string]$_.Class).ToLower().Contains($q)}};$x|Select-Object Status,Class,FriendlyName,InstanceId|Format-Table -AutoSize}
function Show-DX{Write-Header 'DirectX / Graphics runtime';$d=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\DirectX';Write-KV 'DirectX version' $d.Version;foreach($g in Get-GPU){Write-KV $g.Name $g.DriverVersion};Write-Muted '  Full Microsoft diagnostic UI: dxdiag'}
function Show-Power{Write-Header 'Power';Write-KV 'Active plan' ((powercfg /getactivescheme)-join' ');Write-Host ((powercfg /a)-join[Environment]::NewLine) -ForegroundColor Gray}
function Show-Firewall{Get-NetFirewallProfile|Select-Object Name,Enabled,DefaultInboundAction,DefaultOutboundAction|Format-Table -AutoSize}
function Show-DNS{Get-DnsClientServerAddress -AddressFamily IPv4|Where-Object{$_.ServerAddresses.Count-gt0}|Select-Object InterfaceAlias,ServerAddresses|Format-Table -AutoSize}
function Show-Ping([string[]]$Rest){$target=if($Rest.Count){$Rest[0]}else{'1.1.1.1'};$r=Test-Connection $target -Count 4;if(-not$r){Write-Bad "No response from $target";return};$t=@($r|ForEach-Object{if($_.ResponseTime-ne$null){$_.ResponseTime}elseif($_.Latency-ne$null){$_.Latency}});Write-Header "Ping $target";if($t.Count){Write-KV 'Min' "$([math]::Round(($t|Measure-Object -Minimum).Minimum,1)) ms";Write-KV 'Average' "$([math]::Round(($t|Measure-Object -Average).Average,1)) ms";Write-KV 'Max' "$([math]::Round(($t|Measure-Object -Maximum).Maximum,1)) ms"}else{Write-KV 'Status' 'Reachable'}}
function Show-Uptime{$os=Get-OSInfo;Format-Uptime $os.LastBootUpTime}
function Show-PublicIP{try{(Invoke-RestMethod -Uri 'https://api.ipify.org?format=text' -TimeoutSec 5).Trim()}catch{Write-Warn 'Could not reach public IP service.'}}
function Show-Summary{$cpu=Get-CPU;$os=Get-OSInfo;$cs=Get-Computer;$gpu=Get-GPU|Select-Object -First 1;$d=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'";Write-Header 'System summary';Write-KV 'OS' "$($os.Caption)  $($os.OSArchitecture)  build $($os.BuildNumber)";Write-KV 'Device' "$($cs.Manufacturer) $($cs.Model)";Write-KV 'CPU' $cpu.Name.Trim();Write-KV 'GPU' $gpu.Name;Write-KV 'RAM' (Format-Bytes $cs.TotalPhysicalMemory);if($d){Write-KV 'C:' "$(Format-Bytes ($d.Size-$d.FreeSpace)) / $(Format-Bytes $d.Size) used"};Write-KV 'Uptime' (Format-Uptime $os.LastBootUpTime)}
function Show-Doctor{Write-Header 'winfo doctor';Write-KV 'PowerShell' $PSVersionTable.PSVersion;Write-KV 'CIM' $(if(Get-Command Get-CimInstance){'OK'}else{'Missing'});Write-KV 'Storage API' $(if(Get-Command Get-PhysicalDisk){'OK'}else{'Missing'});Write-KV 'Network API' $(if(Get-Command Get-NetAdapter){'OK'}else{'Missing'});Write-KV 'PnP API' $(if(Get-Command Get-PnpDevice){'OK'}else{'Missing'});Write-KV 'Hardware sensors' $(if(Get-HardwareSensors){'Available'}else{'No provider detected'})}

function Show-Help{
    Write-Header 'Commands'
    $rows=@(
        @('summary','Compact system overview'),@('health','Quick system health check'),@('temps','All available temperature sensors'),
        @('cpu','CPU details'),@('cpu temp','CPU temperatures'),@('cpu load','Current CPU load'),@('cpu clock','Current/max CPU clock'),
        @('gpu','GPU details'),@('gpu temp','GPU temperatures'),@('gpu load','GPU load sensors'),@('gpu vram','Reported VRAM'),
        @('ram','Memory details'),@('ram usage','Memory usage only'),@('ram modules','Physical DIMM details'),
        @('disk','Storage overview'),@('disk health','Physical disk health'),@('disk temp','Drive temperatures'),@('disk usage','Volume usage'),
        @('battery','Battery status'),@('battery health','Design vs full-charge capacity'),@('display','Display adapters/monitors'),@('wifi','Wi-Fi connection'),@('wifi signal','Signal and link data'),
        @('network','Active adapters'),@('network ip','IPv4 addresses'),@('network dns','DNS servers'),@('network public','Public IP'),@('network ports','Listening ports'),
        @('os','Windows version and uptime'),@('board','Motherboard'),@('bios','BIOS/UEFI'),@('usb','USB devices'),@('audio','Audio devices'),@('devices [query]','PnP devices/search'),@('dx','DirectX/runtime'),
        @('processes [n]','Top processes'),@('services [query]','Windows services'),@('startup','Startup apps'),@('software [query]','Installed software'),@('drivers [query]','Drivers'),@('updates','Windows updates'),
        @('dns','DNS servers'),@('publicip','Public IP'),@('ping [host]','Latency test'),@('ports','Listening ports'),@('power','Power configuration'),@('firewall','Firewall profiles'),@('tpm','TPM'),@('virtualization','Virtualization'),@('env','Environment'),@('uptime','Uptime only'),@('doctor','Provider diagnostics'),@('clear','Clear shell'),@('exit','Exit shell')
    );foreach($r in$rows){Write-Host ('  {0,-22}'-f$r[0]) -ForegroundColor Cyan -NoNewline;Write-Host $r[1] -ForegroundColor Gray}
}

function Invoke-WinfoCommand([string[]]$Tokens){
    if(-not$Tokens-or$Tokens.Count-eq0){Show-Summary;return};$cmd=$Tokens[0].ToLower();$rest=if($Tokens.Count-gt1){@($Tokens[1..($Tokens.Count-1)])}else{@()}
    switch($cmd){
        'summary'{Show-Summary};'health'{Show-Health};'temps'{Show-Temps};'temp'{Show-Temps}
        'cpu'{Show-CPU $rest};'gpu'{Show-GPU $rest};'ram'{Show-RAM $rest};'memory'{Show-RAM $rest};'disk'{Show-Disk $rest};'storage'{Show-Disk $rest}
        'os'{Show-OS};'system'{Show-OS};'board'{Show-Board};'motherboard'{Show-Board};'bios'{Show-BIOS};'battery'{Show-Battery $rest}
        'display'{Show-Display};'monitor'{Show-Display};'wifi'{Show-Wifi $rest};'usb'{Show-USB};'audio'{Show-Audio};'devices'{Show-Devices $rest};'device'{Show-Devices $rest};'dx'{Show-DX};'directx'{Show-DX}
        'network'{Show-Network $rest};'net'{Show-Network $rest};'dns'{Show-DNS};'publicip'{Show-PublicIP};'ping'{Show-Ping $rest};'ports'{Show-Ports}
        'processes'{Show-Processes $rest};'ps'{Show-Processes $rest};'services'{Show-Services $rest};'startup'{Show-Startup};'software'{Show-Software $rest};'apps'{Show-Software $rest};'drivers'{Show-Drivers $rest};'updates'{Show-Updates}
        'power'{Show-Power};'firewall'{Show-Firewall};'env'{Show-Environment $rest};'tpm'{Show-TPM};'virtualization'{Show-Virtualization};'virt'{Show-Virtualization};'uptime'{Show-Uptime};'doctor'{Show-Doctor}
        'help'{Show-Help};'--help'{Show-Help};'-h'{Show-Help};'version'{"winfo $script:Version"};'--version'{"winfo $script:Version"}
        default{Write-Bad "Unknown command: $cmd";Write-Muted 'Run: winfo help'}
    }
}
function Show-Banner{Write-Host '';Write-Host ' __        _____ _   _ _____ ___  ' -ForegroundColor Cyan;Write-Host ' \ \      / /_ _| \ | |  ___/ _ \ ' -ForegroundColor Cyan;Write-Host '  \ \ /\ / / | ||  \| | |_ | | | |' -ForegroundColor Cyan;Write-Host '   \ V  V /  | || |\  |  _|| |_| |' -ForegroundColor Cyan;Write-Host '    \_/\_/  |___|_| \_|_|   \___/ ' -ForegroundColor Cyan;Write-Host '';Write-Muted "  Windows information, without the scavenger hunt.  v$script:Version";Write-Muted '  Type help to see commands.';Write-Host ''}
function Start-WinfoShell{Show-Banner;while($true){Write-Host 'winfo' -ForegroundColor Cyan -NoNewline;Write-Host ' › ' -ForegroundColor DarkGray -NoNewline;$line=Read-Host;if($null-eq$line){break};$line=$line.Trim();if(-not$line){continue};if($line.ToLower()-in@('exit','quit','q')){break};if($line.ToLower()-in@('clear','cls')){Clear-Host;Show-Banner;continue};$tokens=[regex]::Matches($line,'(?:[^\s"]+|"[^"]*")+')|ForEach-Object{$_.Value.Trim('"')};Invoke-WinfoCommand @($tokens)}}
if($Args.Count-eq0){Start-WinfoShell}else{Invoke-WinfoCommand $Args}
