# winfo

A fast, dependency-free Windows information shell built with native PowerShell.

`winfo` collects useful hardware, software, network, security, driver, storage, process, service, update and environment information in one place, with short commands and a terminal-first interface.

## Why

Windows exposes a huge amount of useful system information, but scatters it across Settings, Task Manager, Device Manager, PowerShell cmdlets, registry keys and third-party utilities.

winfo gives those things one small command surface.

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1+ or PowerShell 7+
- No Python
- No package manager
- No runtime installation

Some sensor values, especially CPU temperature, are not exposed reliably by Windows itself. For those, winfo can read sensor data from LibreHardwareMonitor or OpenHardwareMonitor when one is already running.

## Quick install

Open PowerShell and paste this single command:

```powershell
git clone https://github.com/hydrargyrum13/winfo.git "$env:TEMP\winfo"; powershell -ExecutionPolicy Bypass -File "$env:TEMP\winfo\install.ps1"
```

Then open a new terminal and run:

```text
winfo
```

### Without Git

If Git is not installed, use this PowerShell-only command:

```powershell
$p="$env:TEMP\winfo.zip"; $d="$env:TEMP\winfo-main"; Invoke-WebRequest https://github.com/hydrargyrum13/winfo/archive/refs/heads/main.zip -OutFile $p; Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue; Expand-Archive $p -DestinationPath $env:TEMP -Force; powershell -ExecutionPolicy Bypass -File "$d\install.ps1"
```

Both methods install winfo to `%LOCALAPPDATA%\winfo` and add it to your user PATH.

## Manual install

Clone the repository, then run:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Open a new terminal afterwards.

## Interactive shell

Run:

```text
winfo
```

You will enter the winfo shell:

```text
 __        _____ _   _ _____ ___
 \ \      / /_ _| \ | |  ___/ _ \
  \ \ /\ / / | ||  \| | |_ | | | |
   \ V  V /  | || |\  |  _|| |_| |
    \_/\_/  |___|_| \_|_|   \___/

  Windows information, without the scavenger hunt.

winfo › cpu
winfo › disk
winfo › software firefox
winfo › network
winfo › help
```

Use `exit`, `quit` or `q` to leave.

## Direct commands

Direct commands skip the banner and print only the requested information:

```text
winfo cpu
winfo cpu temp
winfo gpu
winfo ram
winfo disk
winfo os
```

## Commands

| Command | Description |
| --- | --- |
| `winfo summary` | Compact system overview |
| `winfo cpu` | CPU model, core/thread count, clocks and virtualization |
| `winfo cpu temp` | CPU sensor temperatures when a compatible provider exists |
| `winfo gpu` | GPU model, driver, VRAM and current display mode |
| `winfo ram` | Installed memory, usage and DIMM information |
| `winfo disk` | Physical drives, media type, bus, health and volume usage |
| `winfo os` | Windows edition, version, build, install date and uptime |
| `winfo board` | Motherboard information |
| `winfo bios` | BIOS/UEFI and Secure Boot information |
| `winfo battery` | Laptop battery state |
| `winfo network` | Active network adapters, addresses, MAC and link speed |
| `winfo network ip` | IPv4 addresses only |
| `winfo ports` | Listening TCP ports and owning processes |
| `winfo processes [n]` | Top processes by accumulated CPU time |
| `winfo services [query]` | List or search Windows services |
| `winfo startup` | Startup applications |
| `winfo software [query]` | List or search installed desktop software |
| `winfo drivers [query]` | List or search signed drivers |
| `winfo updates` | Recently installed Windows updates |
| `winfo env` | Environment variables |
| `winfo env path` | PATH entries |
| `winfo tpm` | TPM status |
| `winfo virtualization` | Hypervisor, virtualization and optional Windows features |
| `winfo doctor` | Check which winfo data providers are available |
| `winfo help` | Command reference |

Aliases include `memory`, `storage`, `system`, `motherboard`, `net`, `ps`, `apps` and `virt`.

## CPU temperature

Windows does not provide a dependable universal API for modern CPU package/core temperatures. winfo therefore does not fake or guess this value.

If LibreHardwareMonitor or OpenHardwareMonitor exposes its WMI/CIM sensor namespace, this works:

```text
winfo cpu temp
```

Without a provider, winfo explains that temperature data is unavailable instead of returning nonsense.

## Design principles

- Short commands
- Native Windows APIs first
- No Python dependency
- No mandatory third-party tools
- Human-readable terminal output
- Direct mode for scripting and quick lookups
- Interactive mode for exploration
- Never invent unavailable sensor data

## License

MIT
