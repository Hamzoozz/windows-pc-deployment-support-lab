# Security considerations

**Status: rules for this lab, plus one verified behavior.** The script checks on 8 October 2026 confirmed that the inventory and process CSV headers leave out passwords, tokens, serial numbers, command lines, and user names, and that a sample value starting with `=` is prefixed before it can become a spreadsheet formula. No deployment security checklist was performed on a user PC. See [validation-results.md](validation-results.md).

## Least privilege

Prepare a PC with an administrator account only where Windows asks for one: installing updates, installing a per-machine application, renaming the PC, or restarting the Print Spooler. Go back to a standard session for inventory, disk reports, process lists, and sitting with the user.

The three scripts were written to run without elevation. The recorded validation used a non-elevated Windows PowerShell 5.1 session. Administrator rights would not make the inventory more correct, and they would make a mistake more expensive.

The day-to-day user of the PC should be a standard user unless the ticket says they administer that computer. A help-desk account that is a domain admin is the wrong account for this work.

**Verification**

- [ ] Inventory, disk, and process reports were run without "Run as administrator."
- [ ] Elevation was used only for a step that Windows requires.
- [ ] The user's daily account is a standard account, unless the request says otherwise.

**Recorded result for this repository:** The scripts were validated without elevation. The account-type check on a user PC was not performed.

## What the scripts collect

| Script | Fields written |
| --- | --- |
| System inventory | Computer name, manufacturer, model, operating system, version, build, architecture, system drive, memory, logical processors, last boot time, collection time |
| Disk report | Drive letter, volume label, file system, size, free space, percent free |
| Process report | Process name, process id, total CPU seconds, working set in MB |

## What the scripts leave out

Leave these out of the scripts, the CSV files, screenshots, and this Git repository:

- Passwords and any answer to a Windows security prompt
- Authentication tokens, browser cookies, and saved Wi-Fi keys
- Command lines of running processes
- BitLocker or device-encryption recovery keys
- Serial numbers and the signed-in user's name (useful in a private asset system, unnecessary here)
- Email, documents, and the contents of user profiles

`manage-bde -protectors -get` prints a recovery password. Do not run it for this lab. Confirm encryption is on, then store the key only in the process your organization already uses.

**Verification**

- [ ] The CSV attached to a real ticket was glanced at for stray secrets before it was uploaded.
- [ ] No recovery key, password, or token is in the repo or the screenshot.

**Recorded result for this repository:** Header checks passed during script validation. No user-PC ticket was filed.

## CSV files are still sensitive

The inventory row contains the computer name. That is enough to identify a machine. `.gitignore` ignores `*.csv` in this project so a default `output\system-inventory.csv` is not committed by accident. Store reports in the ticket system. Delete the local copy when the ticket has it.

Excel treats a cell that begins with `=`, `+`, `-`, or `@` as a formula. The shared helper prefixes a single quote on those values. The validation run checked this with sample text. It did not open Excel.

**Verification**

- [ ] `git status` does not list a CSV from this lab.
- [ ] The report path you chose is a folder you intended.

**Recorded result for this repository:** The validation script deleted the CSVs it created, including the default `output\system-inventory.csv`. No CSV is part of the project files.

## The scripts do not change the PC

They do not call `Stop-Process`, `Restart-Service`, `Remove-Item` on user data, `Set-ItemProperty`, `Format-Volume`, `Disable-NetAdapter`, or user-account commands. Creating `output\` under this project, when you omit `-OutputPath` on the inventory script, is the only folder they create. Exporting a CSV you named is the only file write.

Service restarts, uninstalls, and Windows Update installs live in the procedure documents because a person should decide to run them. They are not hidden in a script.

**Verification**

- [ ] You can point at the script and say which cmdlet reads Windows and which cmdlet writes the CSV.
- [ ] A change such as a spooler restart was a separate, deliberate step.

**Recorded result for this repository:** Confirmed by reading the scripts and by the validation run completing without a request for administrator rights. A line-by-line code review by a second person has not been recorded.

## Execution policy

Execution policy is a guardrail against running unsigned scripts by accident. It is not an access-control boundary. Anyone who can run PowerShell can bypass it for one process.

This lab uses:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\system_inventory.ps1
```

`Bypass` lasts for that process only. It does not change the machine policy. Use it for these known scripts. For a script you downloaded from a stranger, stop and read it first. A reasonable setting for your own lab account, if you want one, is:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

`CurrentUser` does not require an administrator. `RemoteSigned` allows local scripts you wrote and requires a signature, or an unblock, for scripts downloaded from the internet. This repository does not run `Set-ExecutionPolicy` for you.

**Verification**

- [ ] You can explain why `Bypass` on one command is different from changing the policy for the PC.
- [ ] You read a script before you run it with `Bypass`.

**Recorded result for this repository:** The validation command used a one-process bypass. The machine execution policy was not changed by these scripts.

## Controls you should not turn off

A broken app is not a reason to turn off real-time protection, the firewall, or User Account Control. Those changes outlive the ticket and the next person may not notice. If a vendor's installer truly cannot run with the normal protections, escalate and name the installer, the error, and the setting they want changed.

Do not install "cleaner" or "driver update" tools from an ad. Use the PC vendor, Windows Update, or your company portal. That rule is also in [software-installation.md](software-installation.md).

**Verification**

- [ ] Real-time protection is still on at the end of the visit.
- [ ] The firewall is still on.
- [ ] User Account Control is still at the company default.

**Recorded result for this repository:** Not performed on a user PC.

## Tell the user what you are running

On a PC that already belongs to someone, say that you are collecting the computer model, Windows version, disk space, or a process list, and that you are not collecting their password or files. Lock the screen if you step away. Sign out of your setup account before you leave.

**Verification**

- [ ] The user heard what the script collects.
- [ ] The console is locked or signed out when you leave.

**Recorded result for this repository:** Not performed. No user was present for the script validation.
