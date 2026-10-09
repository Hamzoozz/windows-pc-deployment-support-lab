# Windows troubleshooting

**Status: proposed procedure.** These are the steps to follow when a user reports a problem. They are not a log of a real incident. When you use them, write the symptom, the command, and the result in the ticket before you change the PC.

Network symptoms have their own guide: [network-troubleshooting.md](network-troubleshooting.md).

## Before you change anything

Ask four questions and write the answers down.

1. What were you doing when it failed?
2. What did you expect, and what happened instead? Include the exact error text.
3. Did it ever work on this PC, and when did it change?
4. Is it one application, one PC, or everyone in the office?

One application on one PC points at that app, its files, or its settings. Every PC at once points at a server, a recent company change, or the network. Those are different jobs.

**Verification**

- [ ] The symptom is written in the user's words plus the exact error text.
- [ ] You know whether the failure is one app, one PC, or many PCs.
- [ ] You have not restarted, reinstalled, or "cleaned" anything yet.

**Recorded result for this repository:** Not performed.

## Application failures

Work from the cheapest evidence to the most disruptive fix.

### 1. Reproduce it

Ask the user to do the same click again, or do it yourself while they watch. A failure you cannot reproduce is not ready for a reinstall. Note whether it fails only with one file, one account, or every account on the PC.

**Verification**

- [ ] You saw the failure, or you recorded that you could not reproduce it.
- [ ] You know if another Windows account on the same PC can open the app.

**Recorded result for this repository:** Not performed.

### 2. Read Application errors from the last day

Open **Event Viewer > Windows Logs > Application** and filter for Error. The matching PowerShell query is:

```powershell
Get-WinEvent -FilterHashtable @{
    LogName   = 'Application'
    Level     = 2
    StartTime = (Get-Date).AddDays(-1)
} -MaxEvents 15 | Select-Object TimeCreated, ProviderName, Id, Message
```

`LogName` chooses the log. `Level = 2` means Error (`3` is Warning, `4` is Information). `StartTime` limits the search to the last day. `-MaxEvents 15` stops after 15 matches so you are not reading a week of noise.

If PowerShell says no events were found, that window has no Application errors. That is useful. It means the app may be failing without writing to this log, so look at the app's own log next.

**Reliability Monitor** (`perfmon /rel`, or search for "Reliability") shows a timeline of app crashes and driver failures. Use it when the user says "it started after Tuesday" and they are not sure which app.

**Verification**

- [ ] You checked the Application log or recorded that it had no errors in the window.
- [ ] Any matching error's time, source, and event ID are on the ticket.
- [ ] You looked at Reliability Monitor when the start time was vague.

**Recorded result for this repository:** Not performed.

### 3. Check disk space and the app's own repair

A full disk makes installers and browsers fail in odd ways. Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\disk_space_report.ps1
```

If the app has a Repair option in **Settings > Apps > Installed apps**, use that before a full uninstall. Repair keeps settings more often than a remove-and-install does. Uninstall only after you know the user's data is in a normal place (the vendor's cloud, or a folder you have confirmed).

**Verification**

- [ ] Free space was checked before you blamed the application.
- [ ] Repair was tried when the vendor offers it, and the result is recorded.
- [ ] A reinstall happened only after the error text and the log entry were saved.

**Recorded result for this repository:** Not performed.

## High resource usage

"My computer is slow" is the start of the ticket, not the diagnosis. Find which process is busy, then decide if that usage is expected.

### 1. Look at the top consumers

Open Task Manager (**Ctrl+Shift+Esc**) to the Processes tab. Sort by CPU and by Memory. Then capture a short list you can paste into the ticket:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\running_processes.ps1 -Top 15
```

The script sorts by working set, which is physical memory in use now. `CPUSeconds` is total processor time since the process started, not the live percentage Task Manager shows. A process can sit at the top of `CPUSeconds` because it has been open all week. Confirm a live CPU problem in Task Manager before you treat that column as "it is busy right now."

Many rows with the same name are normal. Browsers and `svchost` do that. `svchost` is a host for Windows services. Identify the service in Task Manager's details before you restart anything.

**Verification**

- [ ] The top memory processes were recorded.
- [ ] A CPU complaint was confirmed with Task Manager's live percentage, not only with `CPUSeconds`.
- [ ] You can name the process you think is responsible.

**Recorded result for this repository:** Not performed. The script's `-Top 5` path was validated for columns and row count only. See [validation-results.md](validation-results.md).

### 2. Decide whether the usage is expected

Windows Update, a defender scan, a large file copy, and a just-opened browser are normal short spikes. A single app at the top of memory after the user closed it, or a fan that never settles, is worth a closer look.

Search the vendor's support site for that process name plus the version you have. Do this before you download a "PC cleaner."

**Verification**

- [ ] You can say whether the busy process matches something the user just did.
- [ ] You did not install a third-party cleaner.

**Recorded result for this repository:** Not performed.

### 3. Close only a process you can explain

Ask the user to save their work. Close the application from its own menu when you can. Ending the task is the fallback for an app that will not close.

Do not end these Windows processes. Stopping them crashes or logs off the PC:

- `System`
- `Registry`
- `smss`
- `csrss`
- `wininit`
- `winlogon`
- `services`
- `lsass`

Startup apps live in Task Manager > Startup apps. Disable a vendor's helper only when you know what it does and the user agrees. Leave security software enabled.

**Verification**

- [ ] The user saved their work before anything was closed.
- [ ] The process you closed was a user application you identified.
- [ ] Critical Windows processes were left running.
- [ ] You checked the PC again after the change and wrote down whether it improved.

**Recorded result for this repository:** Not performed.

## Printers

Most "it will not print" tickets are a selected printer, a stuck queue, or an offline device. Walk them in that order.

### 1. Confirm the job and the printer

Watch the user print. Note the printer they selected and the exact error. In **Settings > Bluetooth & devices > Printers & scanners**, the printer should not say Offline or Error.

```powershell
Get-Printer | Select-Object Name, PrinterStatus, JobCount, PortName
Get-PrintJob -PrinterName "Printer Name Here"
```

`Get-Printer` lists queues on this PC. `PrinterStatus` and `JobCount` tell you whether Windows thinks the device is idle and whether jobs are waiting. `Get-PrintJob` needs the queue name from the first command. Replace `Printer Name Here` with that name. These commands read the queue. They do not cancel jobs.

**Verification**

- [ ] The selected printer name matches the one the user thinks they used.
- [ ] Printer status and the waiting jobs are written on the ticket.

**Recorded result for this repository:** Not performed.

### 2. Clear a stuck queue, then test the spooler

If one job is stuck, cancel that job from the queue window after the user agrees. If jobs remain and will not delete, the Print Spooler service is the next place to look.

```powershell
Get-Service -Name Spooler | Select-Object Name, Status, StartType
```

`Status` should be `Running` for a PC that prints. `StartType` should normally be `Automatic`.

Restarting the spooler deletes in-memory queue state and cancels printing on this PC until the service is back. Warn the user. Then, in an elevated PowerShell window, because service restarts require administrator rights:

```powershell
Restart-Service -Name Spooler
```

This repository does not include a script that restarts the spooler. Run it only as a deliberate support step, then print a Windows test page from the printer's properties.

**Verification**

- [ ] Spooler status was checked before a restart.
- [ ] The user was told printing would pause.
- [ ] A test page was printed after the service was running again, or the remaining error was recorded.

**Recorded result for this repository:** Not performed.

### 3. Separate a cable, a driver, and a network printer

- Local USB: reseat the cable and watch Device Manager for the printer.
- Network printer: the PC needs a route to the printer's address. Use [network-troubleshooting.md](network-troubleshooting.md), and ping the printer only if your site allows ICMP. A failed ping can mean ICMP is blocked, so also try the printer's web page in a browser when it has one.
- Driver: install the model-specific driver from the printer vendor or from your company portal after the queue and the spooler are healthy. A second copy of the same printer with a slightly different name is a common source of "I printed and nothing happened."

**Verification**

- [ ] You know whether the printer is USB or network.
- [ ] For a network printer, you recorded the address and whether the PC can reach it.
- [ ] Only one queue is the default, and a test page used that queue.

**Recorded result for this repository:** Not performed.

## When to stop and escalate

Escalate when the error mentions a server you do not administer, when many users are affected, when the fix needs a domain admin or a firewall change, or when you would have to disable security software to continue. Write what you already checked so the next person does not start over.

**Verification**

- [ ] The ticket says what you tested and what you saw.
- [ ] You did not disable antivirus, the firewall, or User Account Control to force the app open.

**Recorded result for this repository:** Not performed.
