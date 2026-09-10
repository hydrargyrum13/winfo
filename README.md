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

## Repair a broken or old installation

If `winfo` itself cannot start because of a parser error, update commands inside winfo cannot run either. Use the standalone repair script:

```powershell
irm https://raw.githubusercontent.com/hydrargyrum13/winfo/main/repair.ps1 | iex
```

The repair script downloads the current `winfo.ps1`, validates its PowerShell syntax before replacing the installed copy, refreshes the user PATH if necessary, and prints the installed version.

## Updates

Check manually:

```text
winfo update check
```

Update in place:

```text
winfo update
```

Interactive `winfo` checks at most once every 24 hours and only shows a notice when a newer version exists.

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
winfo › disk health
winfo › network dns
winfo › help
```

Direct commands skip the banner.

## Composite command style

Most areas expose predictable subcommands:

```text
winfo cpu temp
winfo cpu load
winfo cpu clock

winfo gpu temp
winfo gpu load
winfo gpu vram

winfo ram usage
winfo ram modules

winfo disk health
winfo disk temp
winfo disk usage

winfo battery health
winfo wifi signal

winfo network ip
winfo network dns
winfo network public
winfo network ports
```

## Temperature providers and fallbacks

Windows does not expose one dependable universal temperature API, so winfo tries several providers instead of assuming one will exist.

For CPU temperatures it prefers LibreHardwareMonitor/OpenHardwareMonitor sensors and falls back to ACPI thermal zones when available. ACPI values are explicitly marked because a thermal zone is not guaranteed to be the CPU package.

For NVIDIA GPUs, winfo can use `nvidia-smi` directly. It also reads GPU sensors exposed by LibreHardwareMonitor/OpenHardwareMonitor.

For SSD/NVMe drives, winfo tries Windows Storage Reliability Counters as well as compatible hardware-monitor providers.

Inspect what is available on the current machine:

```text
winfo temps providers
```

Then query specific categories:

```text
winfo cpu temp
winfo gpu temp
winfo disk temp
winfo temps
```

## Commands

| Command | Description |
| --- | --- |
| `winfo summary` | Compact system overview |
| `winfo health` | Quick health overview |
| `winfo temps` | All available temperature sensors |
| `winfo temps providers` | Show detected temperature providers |
| `winfo cpu` | CPU overview |
| `winfo cpu temp` | CPU temperatures with fallback providers |
| `winfo cpu load` | Current CPU load |
| `winfo cpu clock` | Current and maximum CPU clock |
| `winfo gpu` | GPU overview |
| `winfo gpu temp` | GPU temperatures |
| `winfo gpu load` | GPU load sensors |
| `winfo gpu vram` | Reported VRAM |
| `winfo ram` | Memory overview |
| `winfo ram usage` | Used, available and percentage memory |
| `winfo ram modules` | Physical memory module information |
| `winfo disk` | Storage overview |
| `winfo disk health` | Physical disk health status |
| `winfo disk temp` | Disk/NVMe temperatures when available |
| `winfo disk usage` | Volume usage |
| `winfo battery` | Battery status |
| `winfo battery health` | Design capacity versus full-charge capacity |
| `winfo display` | Display adapters and detected monitors |
| `winfo wifi` | Current Wi-Fi connection |
| `winfo wifi signal` | SSID, signal, channel and link rates |
| `winfo network` | Active network adapters |
| `winfo network ip` | IPv4 addresses |
| `winfo network dns` | DNS servers |
| `winfo network public` | Public IP address |
| `winfo network ports` | Listening TCP ports |
| `winfo os` | Windows edition, version, build and uptime |
| `winfo board` | Motherboard information |
| `winfo bios` | BIOS/UEFI and Secure Boot |
| `winfo usb` | Connected USB devices |
| `winfo audio` | Audio devices |
| `winfo devices [query]` | List or search Plug and Play devices |
| `winfo dx` | DirectX/runtime and graphics driver information |
| `winfo dns` | DNS servers shortcut |
| `winfo publicip` | Public IP shortcut |
| `winfo ping [host]` | Four-packet latency test |
| `winfo ports` | Listening ports shortcut |
| `winfo processes [n]` | Top processes by CPU time |
| `winfo services [query]` | List or search services |
| `winfo startup` | Startup applications |
| `winfo software [query]` | Installed software |
| `winfo drivers [query]` | Installed drivers |
| `winfo updates` | Recent Windows updates |
| `winfo update check` | Check for a newer winfo release |
| `winfo update` | Download and install the current winfo release |
| `winfo power` | Power plan and sleep states |
| `winfo firewall` | Windows Firewall profiles |
| `winfo tpm` | TPM status |
| `winfo virtualization` | Virtualization status |
| `winfo env` | Environment variables |
| `winfo env path` | PATH entries |
| `winfo uptime` | Uptime only |
| `winfo doctor` | Check available APIs/providers |
| `winfo help` | Command reference |

Useful aliases include `temp`, `memory`, `storage`, `system`, `motherboard`, `monitor`, `net`, `ps`, `apps`, `device`, `directx` and `virt`.

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1+ or PowerShell 7+
- No Python
- No package manager
- No required runtime installation

## Design principles

- Short commands
- Predictable composite subcommands
- Native Windows APIs first
- Multiple sensor fallbacks
- No Python dependency
- No mandatory third-party tools
- Human-readable terminal output
- Direct mode for scripting and quick lookups
- Interactive mode for exploration
- Never invent unavailable sensor data

## License

MIT
