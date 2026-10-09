# Windows PC Deployment & Support Lab

Checklists and read-only PowerShell scripts for preparing a Windows PC and looking into common desktop problems.

The checklists have not been used to deploy a computer. The scripts were tested on 8 October 2026. Results are in [docs/validation-results.md](docs/validation-results.md).

## Overview

The lab covers the usual desktop-support sequence: identify the PC, install updates and requested software, check devices, and hand the computer to the user. Three scripts collect an inventory, a disk-space report, and a process list. They only read Windows and write a CSV.

Troubleshooting notes cover application failures, high CPU or memory use, printers, and network connectivity. Those notes are procedures, not records of closed tickets.

## Objectives

- Write a repeatable preparation checklist for a Windows PC that already has Windows installed.
- Collect computer, disk, and process information without administrator rights and without changing the system.
- Document checks for application failures, resource usage, printers, software installs, and basic network problems.

## Technologies Used

- Windows PowerShell 5.1 (`powershell.exe`)
- `Get-CimInstance` (`Win32_OperatingSystem`, `Win32_ComputerSystem`, `Win32_LogicalDisk`)
- `Get-Process`
- CSV export

## What is included

| Item | State |
| --- | --- |
| Deployment, software, security, and troubleshooting guides | Written. Not carried out on a user PC. |
| `scripts/system_inventory.ps1` | Collects one row of computer and OS facts and writes a CSV. |
| `scripts/disk_space_report.ps1` | Reports free space on local fixed disks and warns under 15% free. |
| `scripts/running_processes.ps1` | Lists processes, largest working set first. |
| `tests/Invoke-LabValidation.ps1` | Checks the scripts. Run on 8 October 2026; see the validation record. |
| [docs/post-deployment-validation.md](docs/post-deployment-validation.md) | Blank sign-off sheet. |

The inventory leaves out passwords, tokens, recovery keys, serial numbers, the signed-in user, and the domain name. Process reports leave out command lines and executable paths.

## Project structure

| Path | Purpose |
| --- | --- |
| [docs/deployment-checklist.md](docs/deployment-checklist.md) | Preparation steps |
| [docs/post-deployment-validation.md](docs/post-deployment-validation.md) | Sign-off sheet |
| [docs/windows-troubleshooting.md](docs/windows-troubleshooting.md) | Applications, resource usage, printers |
| [docs/network-troubleshooting.md](docs/network-troubleshooting.md) | Connectivity checks, one layer at a time |
| [docs/software-installation.md](docs/software-installation.md) | Install and verify software |
| [docs/security-considerations.md](docs/security-considerations.md) | Least privilege and what the scripts omit |
| [docs/validation-results.md](docs/validation-results.md) | Script test record |
| `scripts/` | Reports |
| `tests/Invoke-LabValidation.ps1` | Script checks |

## Setup and usage

Run the commands from this folder on Windows 10 or Windows 11. PowerShell 5.1 is included with Windows. The scripts do not request administrator rights.

`-NoProfile` skips the personal PowerShell profile. `-ExecutionPolicy Bypass` applies only to that process. `-File` runs the script and returns its exit code.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\system_inventory.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\disk_space_report.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\running_processes.ps1 -Top 15
```

Other examples:

```powershell
Get-Help .\scripts\system_inventory.ps1 -Full

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\system_inventory.ps1 -OutputPath "$env:TEMP\inventory.csv" -Verbose

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\disk_space_report.ps1 -DriveLetter C -MinimumFreePercent 20 -OutputPath "$env:TEMP\disk.csv"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\running_processes.ps1 -Name explorer -OutputPath "$env:TEMP\processes.csv"
```

If `-OutputPath` is omitted, the inventory script writes `output\system-inventory.csv`. That file contains the computer name. CSV files are gitignored. `Get-Process -Name` expects the image name without `.exe`.

| Exit code | Meaning |
| --- | --- |
| 0 | The report ran. A low-disk warning can still appear with code 0. |
| 1 | The path, drive letter, percent, process name, or `-Top` value was rejected. |
| 2 | Windows could not be queried, the disk was missing, or the CSV could not be written. |

`$LASTEXITCODE` shows the code after `powershell.exe` exits.

Re-run the checks with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Invoke-LabValidation.ps1
```

## Script notes

`system_inventory.ps1` reads `Win32_OperatingSystem` and `Win32_ComputerSystem`. Memory is `TotalPhysicalMemory / 1GB` (1024 cubed). `Get-CimInstance` returns the last boot time as a date.

`disk_space_report.ps1` queries `Win32_LogicalDisk` with `DriveType=3` (local disks). Size and free space are bytes. Percent free is `FreeSpace / Size * 100`. A size of zero leaves the percent blank. The default warning threshold is 15% free. The warning does not delete files.

`running_processes.ps1` sorts by working set. `WorkingSetMB` is current physical memory. `CPUSeconds` is total processor time since the process started, not the live CPU percentage in Task Manager. A blank CPU value is left blank.

`Export-Csv -NoTypeInformation` omits the `#TYPE` line that Windows PowerShell 5.1 otherwise writes. The CSV is written before `Format-Table`. Values that start with `=`, `+`, `-`, or `@` are prefixed with a quote so a spreadsheet does not treat them as formulas.

## Future improvements

- Use the deployment checklist on a test PC and fill in the sign-off sheet.
- Compare the disk report with File Explorer.
- Run the same script checks on Windows 10 and on PowerShell 7.
