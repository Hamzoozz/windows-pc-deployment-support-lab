# Windows PC Deployment & Support Lab

This project shows the work of an entry-level desktop support technician: prepare a Windows PC, confirm it is ready to hand to a user, and investigate the problems that show up after that handoff. The scripts are read-only PowerShell 5.1 tools for inventory, disk space, and running processes.

The checklists are procedures. They become a completed deployment only after someone performs them on a computer and records the result. This repository records one completed activity: the script validation in [docs/validation-results.md](docs/validation-results.md).

## What is already done, and what is still a procedure

| Material | Status |
| --- | --- |
| Deployment, validation, troubleshooting, software, and security guides | Written procedures. No PC was prepared or handed to a user. |
| `scripts/system_inventory.ps1`, `scripts/disk_space_report.ps1`, `scripts/running_processes.ps1` | Run on 8 October 2026 by [tests/Invoke-LabValidation.ps1](tests/Invoke-LabValidation.ps1). Result: 48 checks passed, 0 failed. |
| A finished deployment sign-off | Not started. The form in [docs/post-deployment-validation.md](docs/post-deployment-validation.md) is blank on purpose. |

In an interview, this is a fair sentence: "I wrote a repeatable Windows preparation checklist and read-only PowerShell reports, and I ran the script checks on a non-elevated Windows 11 session." It is not yet fair to say a computer was deployed.

## Practice scenario

A new employee needs a Windows PC on Monday. You receive a computer that already has Windows installed. Your job is to update it, install the requested apps, confirm the hardware the person will use, and hand it over without leaving your administrator password behind.

Use [docs/deployment-checklist.md](docs/deployment-checklist.md) while you work, then fill [docs/post-deployment-validation.md](docs/post-deployment-validation.md) from what you actually see. Attach a system inventory CSV and a disk report to the ticket. If something fails, use the troubleshooting guides and write down the symptom before you change anything.

That scenario is practice. It is not a ticket this repository closed.

## Layout

| Path | Purpose |
| --- | --- |
| [docs/deployment-checklist.md](docs/deployment-checklist.md) | Repeatable preparation checklist |
| [docs/post-deployment-validation.md](docs/post-deployment-validation.md) | Sign-off sheet after preparation |
| [docs/windows-troubleshooting.md](docs/windows-troubleshooting.md) | Application failures, high resource usage, printers |
| [docs/network-troubleshooting.md](docs/network-troubleshooting.md) | Connectivity, one layer at a time |
| [docs/software-installation.md](docs/software-installation.md) | Install and verify software from a trusted source |
| [docs/security-considerations.md](docs/security-considerations.md) | Least privilege and what these tools leave out |
| [docs/validation-results.md](docs/validation-results.md) | The script run that actually happened |
| `scripts/` | Read-only reports |
| `tests/Invoke-LabValidation.ps1` | Checks the scripts |

Run commands from this folder (the folder that contains `scripts` and `docs`).

## What you need

- Windows 10 or Windows 11
- Windows PowerShell 5.1, which is already installed as `powershell.exe`
- Permission to look at that computer
- A normal user session. These scripts do not ask for administrator rights.

The recorded run used Windows 11 Pro, version 10.0.26300, 64-bit, and Windows PowerShell 5.1.26100.9549. Details are in the validation record.

## How to run the scripts

`-NoProfile` skips the commands in your personal PowerShell profile, so the script behaves the same on another PC. `-ExecutionPolicy Bypass` applies only to that one process. It does not change the policy stored on the computer. `-File` runs the script and keeps its exit code.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\system_inventory.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\disk_space_report.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\running_processes.ps1 -Top 15
```

Useful variations:

```powershell
Get-Help .\scripts\system_inventory.ps1 -Full

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\system_inventory.ps1 -OutputPath "$env:TEMP\inventory.csv" -Verbose

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\disk_space_report.ps1 -DriveLetter C -MinimumFreePercent 20 -OutputPath "$env:TEMP\disk.csv"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\running_processes.ps1 -Name explorer -OutputPath "$env:TEMP\processes.csv"
```

`Get-Help` reads the comment block at the top of each script. `-Verbose` prints the CIM or process query as it runs. `$env:TEMP` is the current user's temporary folder.

The inventory script writes `output\system-inventory.csv` when `-OutputPath` is omitted. That file includes the computer name, so `.gitignore` keeps CSV files out of Git. Delete it after you attach it to a private ticket.

### Exit codes

| Code | Meaning |
| --- | --- |
| 0 | The report ran. A low-disk warning can still appear with code 0. |
| 1 | An input was rejected: path, drive letter, percent, process name, or `-Top`. |
| 2 | Windows could not be queried, the requested disk was missing, or the CSV could not be written. |

Check the code in PowerShell with `$LASTEXITCODE` immediately after `powershell.exe` finishes.

## System inventory

`scripts/system_inventory.ps1` answers "what PC is this?" It writes one row.

| Column | Where it comes from | Why a technician wants it |
| --- | --- | --- |
| ComputerName | `$env:COMPUTERNAME` | Identifies the machine on the ticket |
| Manufacturer, Model | `Win32_ComputerSystem` | Tells you the hardware vendor and model |
| OperatingSystem, OSVersion, OSBuild, Architecture | `Win32_OperatingSystem` | Shows edition, version, build, and 32-bit or 64-bit |
| SystemDrive | `Win32_OperatingSystem` | Usually `C:`, the drive Windows starts from |
| TotalMemoryGB | `TotalPhysicalMemory` divided by `1GB` | Installed RAM, in gibibytes |
| LogicalProcessors | `Win32_ComputerSystem` | How many logical CPUs Windows sees |
| LastBootTime | `LastBootUpTime`, converted to UTC | A recent boot means a restart already happened |
| CollectedAtUtc | Current time in UTC | Shows when the row was taken |

The script leaves out the signed-in user, serial number, domain name, passwords, and recovery keys. A private asset database might store a user and an asset tag. A sample project that can be published should not.

`Get-CimInstance` is the current way to read those classes. `Get-WmiObject` is the old command. It is removed from PowerShell 7, and it returns boot time as a text string you have to parse. `Get-CimInstance` already returns a date.

`1GB` is PowerShell's gibibyte constant, 1024 cubed, which matches how Windows reports memory. Dividing by `1000000000` would not match Task Manager.

## Disk space

`scripts/disk_space_report.ps1` reads `Win32_LogicalDisk` where `DriveType` is `3`. That value means a local fixed disk.

| DriveType | Meaning |
| --- | --- |
| 2 | Removable, such as a USB drive |
| 3 | Local disk |
| 4 | Network drive |
| 5 | CD or DVD |

USB sticks and mapped drives are omitted so a tiny removable disk does not look like a full system drive. Size and free space arrive in bytes. The script divides by `1GB` and rounds to two decimals. Percent free is `FreeSpace / Size * 100`. If size is zero, percent stays blank so the script does not divide by zero.

`-MinimumFreePercent` defaults to 15. A drive **below** 15 percent free produces a warning. A drive sitting at exactly 15 percent does not. The warning only prints a message. It does not delete files.

`-DriveLetter` accepts `C` or `C:` and rejects values such as `99`.

## Running processes

`scripts/running_processes.ps1` uses `Get-Process` and sorts by working set, largest first. `-Top 15` keeps the 15 largest. That is the list you want when a user says the PC is slow.

| Column | Meaning |
| --- | --- |
| Name | Process image name. `explorer`, not `explorer.exe`. |
| Id | Process ID. Two Chrome rows can share a name and still have different IDs. |
| CPUSeconds | Total processor time since the process started, in seconds. This is not the CPU percentage in Task Manager. |
| WorkingSetMB | Physical memory the process is using right now, in mebibytes. This is the closest match to Task Manager's Memory column. |

A blank `CPUSeconds` means Windows did not give that counter to this user. The script keeps the row.

The executable path and the command line are left out. A command line sometimes contains a connection string or a token, and the path can fail with access denied. Ending a process is also out of scope. `Stop-Process` is a change, and ending `lsass`, `csrss`, `winlogon`, or `services` will take down Windows.

A valid name that is not running is an empty report and exit code 0. `notepad.exe` is rejected because `Get-Process -Name` does not want the `.exe`.

## Commands worth practicing out loud

| Command | What you are saying when you use it |
| --- | --- |
| `Get-CimInstance -ClassName Win32_OperatingSystem` | "I am asking Windows for the operating system object." |
| `Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3"` | "I want local disks only. The filter is WQL, the query language CIM uses." |
| `Get-Process` | "Show the process table this user is allowed to see." |
| `Export-Csv -NoTypeInformation` | "Write real columns. `-NoTypeInformation` leaves off the `#TYPE` line Windows PowerShell 5.1 would otherwise put in the file." |
| `Set-StrictMode -Version 2.0` | "Unset variables and missing properties should fail loudly while I am writing the script." |
| `[CmdletBinding()]` | "This script accepts the common parameters, including `-Verbose`." |
| `exit 1` | "The caller can tell a bad path from a successful report." |

`Format-Table` is for the screen. Once you format for the screen, the original objects are gone, so the script writes the CSV first and formats a table second. Piping `Format-Table` into `Export-Csv` is a common mistake: the CSV then contains formatting junk instead of the columns you wanted.

Text that starts with `=`, `+`, `-`, or `@` gets a leading single quote before it is written. Spreadsheets treat those characters as formulas. The validation checks that behavior with a sample value. It does not open Excel.

## Validate the scripts

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Invoke-LabValidation.ps1
```

The test does two things:

1. It calls the helper functions with sample disks and sample processes. Those checks do not describe this PC.
2. It starts each script with `powershell.exe -File`, checks the exit code and the CSV header, and deletes the CSV afterward. It prints pass or fail. It does not print computer names, process names, or free-space numbers from the live PC.

The recorded result is [docs/validation-results.md](docs/validation-results.md).

## Safety

- The scripts query Windows and write a CSV you asked for.
- They do not install software, change settings, restart services, or remove files belonging to a user.
- Run them only on a computer you are allowed to support.
- Keep the CSV in the ticket system, not in a public repository.
- Read [docs/security-considerations.md](docs/security-considerations.md) before you use the checklists on a real PC.

## Interview close

Walk through one script from top to bottom: the help comment, the parameters, the CIM or process query, the CSV, and the exit code. Then say which checks you have actually run, and point to the validation record. Keep the deployment checklist in the "this is how I would do it" column until you have done it and written down what the screen showed.
