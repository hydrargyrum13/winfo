# winfo

A fast, dependency-free Windows information shell built with native PowerShell.

`winfo` collects useful hardware, software, network, security, driver, storage, process, service, update and environment information in one place, with short commands and a terminal-first interface.

## Quick install

Open PowerShell and paste:

```powershell
git clone https://github.com/hydrargyrum13/winfo.git "$env:TEMP\winfo"; powershell -ExecutionPolicy Bypass -File "$env:TEMP\winfo\install.ps1"
```

Then open a new terminal and run:

```text
winfo
```

### Without Git

```powershell
$p="$env:TEMP\winfo.zip"; $d="$env:TEMP\winfo-main"; Invoke-WebRequest https://github.com/hydrargyrum13/winfo/archive/refs/heads/main.zip -OutFile $p; Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue; Expand-Archive $p -DestinationPath $env:TEMP -Force; powershell -ExecutionPolicy Bypass -File "$d\install.ps1"
```

Both methods install winfo to `%LOCALAPPDATA%\winfo` and add it to your user PATH.

## Updating

Check manually:

```text
winfo update check
```

Update in one command:

```text
winfo update
```

`winfo upgrade` is an alias. The interactive shell also checks for a new version at most once every 24 hours and only shows a notice when an update exists.

## Interactive shell

```text
winfo
```

```text
 __        _____ _   _ _____ ___
 \ \      / /_ _| \ | |  ___/ _ \
  \ \ /\ / / | ||  \| | |_ | | | |
   \ V  V /  | || |\  |  _|| |_| |
    \_/\_/  |___|_| \_|_|   \___/

  Windows information, without the scavenger hunt.

winfo › cpu temp
winfo › gpu temp
winfo › disk temp
winfo › temps providers
winfo › help
```

Direct commands skip the banner.

## Composite command style

```text
winfo cpu temp
winfo cpu load
winfo cpu clock

winfo gpu temp
winfo gpu load
winfo gpu vram

winfo ram modules

winfo disk health
winfo disk temp
winfo disk usage

winfo wifi signal

winfo network ip
winfo network dns
winfo network public
winfo network ports
```

## Temperature fallback chain

Windows does not expose one reliable universal CPU/GPU temperature API, so winfo uses several independent providers instead of depending on a single tool.

`winfo temps` combines whatever is available from:

- LibreHardwareMonitor WMI/CIM sensors
- OpenHardwareMonitor WMI/CIM sensors
- NVIDIA `nvidia-smi` for NVIDIA GPU temperature/load/VRAM
- Windows Storage Reliability Counters for supported SSD/NVMe temperatures
- ACPI thermal zones as a last-resort thermal reading

Check which providers work on the current PC:

```text
winfo temps providers
```

Useful temperature commands:

```text
winfo cpu temp
winfo gpu temp
winfo disk temp
winfo temps
```

ACPI thermal zones are explicitly labeled as **not guaranteed to represent CPU package temperature**. winfo does not relabel ambiguous motherboard/firmware thermal zones as CPU readings.

## Commands

| Command | Description |
| --- | --- |
| `winfo summary` | Compact system overview |
| `winfo health` | Quick health overview |
| `winfo temps` | All available temperature readings |
| `winfo temps providers` | Show which temperature providers work |
| `winfo cpu` | CPU overview |
| `winfo cpu temp` | CPU temperature with fallbacks |
| `winfo cpu load` | Current CPU load |
| `winfo cpu clock` | Current and maximum CPU clock |
| `winfo gpu` | GPU overview |
| `winfo gpu temp` | GPU temperature with fallbacks |
| `winfo gpu load` | GPU load |
| `winfo gpu vram` | VRAM information |
| `winfo ram` | Memory overview |
| `winfo ram modules` | Physical memory modules |
| `winfo disk` | Storage overview |
| `winfo disk health` | Disk health status |
| `winfo disk temp` | SSD/NVMe/disk temperatures when available |
| `winfo disk usage` | Volume usage |
| `winfo battery` | Battery status |
| `winfo display` | Display adapters |
| `winfo wifi` | Wi-Fi information |
| `winfo wifi signal` | Wi-Fi signal/link data |
| `winfo network` | Active network adapters |
| `winfo network ip` | IPv4 addresses |
| `winfo network dns` | DNS servers |
| `winfo network public` | Public IP |
| `winfo network ports` | Listening TCP ports |
| `winfo os` | Windows information |
| `winfo board` | Motherboard information |
| `winfo bios` | BIOS/UEFI information |
| `winfo usb` | USB devices |
| `winfo audio` | Audio devices |
| `winfo devices [query]` | Search Plug and Play devices |
| `winfo dx` | DirectX/graphics runtime |
| `winfo processes [n]` | Top processes |
| `winfo services [query]` | Services |
| `winfo startup` | Startup applications |
| `winfo software [query]` | Installed software |
| `winfo drivers [query]` | Drivers |
| `winfo updates` | Recent Windows updates |
| `winfo update check` | Check for a winfo update |
| `winfo update` | Install latest winfo |
| `winfo power` | Power configuration |
| `winfo firewall` | Firewall profiles |
| `winfo tpm` | TPM status |
| `winfo virtualization` | Virtualization status |
| `winfo env` | Environment variables |
| `winfo uptime` | Uptime |
| `winfo doctor` | Provider/API diagnostics |
| `winfo help` | Command reference |

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1+ or PowerShell 7+
- No Python
- No package manager
- No required runtime installation

## License

MIT
