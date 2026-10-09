# Validation results

**Status: this run happened.** The notes below are the script checks from 8 October 2026, Eastern time. They are not a PC deployment, a Windows Update install, a software install, or a user handoff.

The procedure documents stay unmarked until those tasks are done on a computer and the results are written down there.

## Environment

Collected in the same Windows session with `Get-CimInstance Win32_OperatingSystem`, `$PSVersionTable`, and a Windows principal check. The computer name was not copied into this file.

| Item | Observed value |
| --- | --- |
| Operating system | Microsoft Windows 11 Pro |
| Version | 10.0.26300 |
| Build | 26300 |
| Architecture | 64-bit |
| PowerShell | 5.1.26100.9549, edition Desktop (`powershell.exe`) |
| Elevated administrator | False |

The scripts do not request elevation. This session was already a standard user session.

## Command

Run from the project folder (the folder that contains `scripts` and `tests`):

```powershell
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\tests\Invoke-LabValidation.ps1
```

Exit code: **0**

Summary printed by the test:

```text
Passed: 48
Failed: 0
```

## What the 48 checks were

Function checks used sample objects in memory. They do not describe this PC.

- Formula-like sample text is prefixed so a spreadsheet treats it as text.
- Ordinary sample text is unchanged.
- A sample 100 GB disk with 20 GB free reports those sizes and 20 percent free.
- A sample disk with size 0 leaves percent free blank.
- Low-space warnings follow the threshold: 20 percent does not warn at 15, 10 percent does, and exactly 15 percent does not.
- Drive letter `c:` becomes `C:`. Drive letter `99` is rejected.
- Process names `explorer` and `powershell` are accepted.
- `notepad.exe`, a name with a space, and `*` are rejected.
- A sample process row keeps id 42, rounds CPU seconds, converts 10 MB of working set, neutralizes a name that starts with `=`, and allows a blank CPU value.

Script checks started each script with `powershell.exe -File`. CSV files went to a temporary folder and were deleted before the test exited. The test printed pass or fail only. It did not print live computer names, process names, or free-space figures.

Observed on this PC during those checks:

- `system_inventory.ps1` exited 0, created a CSV, wrote one data row, and used the documented column list.
- The inventory header did not contain Password, Token, Secret, Credential, SerialNumber, CommandLine, RecoveryKey, or UserName.
- A `.txt` output path and a missing folder each exited 1.
- `disk_space_report.ps1` exited 0, created a CSV with the documented columns, and wrote at least one local disk.
- Drive letter `99` and a minimum free percent of 150 each exited 1.
- `Z:` was not a local fixed disk on this PC, so the script exited 2. A PC that actually has a fixed `Z:` would exit 0 instead. The test looks up `Z:` before it decides which code to expect.
- `running_processes.ps1 -Top 5` exited 0 and wrote five data rows with the documented columns.
- The process header did not contain command lines or credential fields.
- The name `notepad.exe` and `-Top 0` each exited 1.
- A valid process name that was not running exited 0 and wrote a header with zero data rows.
- Dot-sourcing `system_inventory.ps1` loaded `Get-LabSystemInventory` and did not write a CSV.
- Omitting `-OutputPath` wrote `output\system-inventory.csv`. The test deleted that file and exited with the folder removed.

## What this run does not show

- It does not show that any checklist task was done.
- It does not compare the disk report with File Explorer or Disk Management. Column names and "at least one disk" were checked. The gigabyte figures were not checked against the GUI.
- It does not open the CSV in Excel. The formula prefix was checked on a sample string in memory.
- It was not repeated on Windows 10 or on PowerShell 7.
- It does not prove behavior when CIM queries are broken.

## Output left behind

No CSV file was kept. The default inventory file created by the last check was deleted by the test.
