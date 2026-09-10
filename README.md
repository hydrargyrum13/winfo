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

winfo › cpu
winfo › temps
winfo › wifi
winfo › health
winfo › help
```

Direct commands skip the banner:

```text
winfo cpu temp
winfo health
winfo display
winfo publicip
```

## Commands

| Command | Description |
| --- | --- |
| `winfo summary` | Compact system overview |
| `winfo health` | Quick health overview: memory, disks, reboot state, CPU temperature |
| `winfo temps` | All temperatures exposed by a compatible sensor provider |
| `winfo cpu` | CPU model, cores, threads, clocks and virtualization |
| `winfo cpu temp` | CPU temperature sensors |
| `winfo gpu` | Graphics adapters, driver and display mode |
| `winfo ram` | Memory usage and DIMM information |
| `winfo disk` | Physical disks, health and volume usage |
| `winfo os` | Windows edition, version, build and uptime |
| `winfo board` | Motherboard information |
| `winfo bios` | BIOS/UEFI and Secure Boot |
| `winfo battery` | Laptop battery status |
| `winfo display` | Display adapters and detected monitors |
| `winfo wifi` | Current Wi-Fi connection, signal, channel and link rates |
| `winfo usb` | Connected USB devices |
| `winfo audio` | Audio devices |
| `winfo devices [query]` | List or search Plug and Play devices |
| `winfo dx` | DirectX registry version and graphics driver information |
| `winfo network` | Active network adapters and addresses |
| `winfo network ip` | IPv4 addresses only |
| `winfo dns` | Configured IPv4 DNS servers |
| `winfo publicip` | Current public IP address |
| `winfo ping [host]` | Four-packet latency test; defaults to `1.1.1.1` |
| `winfo ports` | Listening TCP ports and owning processes |
| `winfo processes [n]` | Top processes by accumulated CPU time |
| `winfo services [query]` | List or search Windows services |
| `winfo startup` | Startup applications |
| `winfo software [query]` | List or search installed software |
| `winfo drivers [query]` | List or search signed drivers |
| `winfo updates` | Recently installed Windows updates |
| `winfo power` | Active power plan and available sleep states |
| `winfo firewall` | Windows Firewall profile state |
| `winfo tpm` | TPM status |
| `winfo virtualization` | Hypervisor and Windows virtualization feature status |
| `winfo env` | Environment variables |
| `winfo env path` | PATH entries |
| `winfo uptime` | Uptime only |
| `winfo doctor` | Check which winfo providers/APIs are available |
| `winfo help` | Command reference |

Useful aliases include `temp`, `memory`, `storage`, `system`, `motherboard`, `monitor`, `net`, `ps`, `apps`, `device`, `directx` and `virt`.

## Temperature support

Windows does not expose a dependable universal API for modern CPU/package temperatures. winfo does not guess them.

If LibreHardwareMonitor or OpenHardwareMonitor exposes its WMI/CIM namespace, these work:

```text
winfo cpu temp
winfo temps
winfo health
```

Without a compatible provider, winfo reports that the sensor is unavailable.

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1+ or PowerShell 7+
- No Python
- No package manager
- No required runtime installation

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
