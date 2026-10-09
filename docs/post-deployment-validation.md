# Post-deployment validation

**Status: blank template.** Nobody has filled this in. Copy it into the ticket when you finish a real preparation, and mark a line only after you have seen the result.

The deployment steps live in [deployment-checklist.md](deployment-checklist.md). This page is the sign-off. A procedure that exists on paper is not a pass.

## Visit

| Field | Value |
| --- | --- |
| Date | |
| Technician | |
| User | |
| Computer name | |
| Asset tag, if your site uses one | |
| Location | |
| Ticket number | |

## Windows

| Check | How you know | Result (pass, fail, or not in scope) | Notes |
| --- | --- | --- | --- |
| Windows edition matches the request | Inventory script, OperatingSystem column | | |
| Version and build recorded | Inventory script, OSVersion and OSBuild | | |
| Windows Update checked after the last restart | Settings > Windows Update | | |
| Required updates installed | Settings page, plus `Get-HotFix` for what is already installed | | |
| Time zone and clock | Settings > Date & time | | |
| Computer name matches the standard | Inventory script, ComputerName column | | |
| User signed in with their own account | You watched the sign-in | | |

## Applications

Add one row per required application. Leave the table empty until a real request names the apps.

| Application | Requested version | Observed version | Opens | Result | Notes |
| --- | --- | --- | --- | --- | --- |
| | | | | | |

## Devices and network

| Check | Result | Notes |
| --- | --- | --- |
| Display | | |
| Keyboard and pointing device | | |
| Audio | | |
| Camera and microphone, if in scope | | |
| Wired or Wi-Fi network | | |
| Can open an internal site the user needs | | |
| Can open an external site, if internet is allowed | | |
| Printer test page, if in scope | | |
| Disk free space acceptable | | Attach `disk_space_report.ps1` output privately |

## Security handoff

| Check | Result | Notes |
| --- | --- | --- |
| Real-time protection on | | |
| Firewall on | | |
| Day-to-day account is not a local admin, unless requested | | |
| Encryption on, if your standard requires it | | Do not paste a recovery key |
| No password written on the device or in Git | | |

## Attachments

- [ ] System inventory CSV stored with the ticket, not in Git
- [ ] Disk space CSV stored with the ticket, not in Git

## Sign-off

| Field | Value |
| --- | --- |
| User confirmed they can work | |
| Follow-ups | |
| Technician signature or name | |
| Time finished | |

**Recorded result for this repository:** The table is empty because no handoff was performed.
