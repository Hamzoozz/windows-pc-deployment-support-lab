# Windows computer preparation checklist

Use this list in the same order each time. Record the results on [post-deployment-validation.md](post-deployment-validation.md). These steps have not been carried out on a computer yet.

Installing applications before Windows Update finishes often wastes the work, because the required restart can interrupt the installer.

Work on a computer you are allowed to change. These steps change a PC. The PowerShell scripts in this project do not, and they are optional attachments, not a substitute for the checklist.

## 1. Take the request

Write down who the PC is for, the due date, the required applications, whether they need email and VPN, and whether a printer is in scope. Confirm you have a license for paid software. If the computer still has another person's files, stop and ask before you erase anything. This lab has no disk-wipe script.

**Verification**

- [ ] The user, due date, and required applications are written on the ticket.
- [ ] Another person's data is either out of scope or backed up by the process your organization uses.
- [ ] You know whether a printer, VPN, or email account is part of this request.

## 2. Identify the hardware and the Windows edition

Sign in with the account your organization uses for setup. Run the inventory script from the project folder:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\system_inventory.ps1 -OutputPath "$env:TEMP\inventory.csv"
```

`Get-CimInstance Win32_OperatingSystem` supplies the edition, version, and build. `Win32_ComputerSystem` supplies manufacturer and model. Compare the edition with what the ticket requires. Windows Home cannot join an Active Directory domain. A 32-bit Windows install cannot run 64-bit-only software.

**Verification**

- [ ] Computer name, manufacturer, model, edition, version, build, and architecture are on the ticket.
- [ ] The edition can do what the user needs (domain join, required apps).
- [ ] The inventory CSV is attached to the private ticket and is not committed to Git.

## 3. Confirm power, picture, and input

Connect the power adapter for a laptop. Confirm the display is readable, the keyboard types, and the pointing device clicks. If this is a desktop, check the monitor cable at both ends before you reinstall Windows drivers.

**Verification**

- [ ] The PC stays on when external power is connected.
- [ ] You can type and click on the local console.
- [ ] The display is on the correct input and the image is stable.

## 4. Install Windows updates

Open **Settings > Windows Update** on Windows 11. On Windows 10 the same page is **Settings > Update & Security > Windows Update**. Choose **Check for updates**. Install what Windows offers. Restart when it asks, then check again until required updates are finished or the remaining items are optional and documented.

Pending updates are shown in that Settings page. This command shows updates that are already installed, which is a different list:

```powershell
Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 10 HotFixID, Description, InstalledOn
```

`Get-HotFix` reads the installed-update list. An empty recent list does not mean Windows is current. It can mean the PC was imaged recently and the new updates are still waiting in Settings.

Installing updates changes the PC and can take a long time. This repository does not automate that install.

**Verification**

- [ ] Windows Update was checked after the last restart.
- [ ] Required updates are installed, or the leftover items are named on the ticket as optional.
- [ ] `Get-HotFix` shows the recent installed updates you expect after that restart.
- [ ] The user can still sign in after the restart.

## 5. Install the requested software

Follow [software-installation.md](software-installation.md). Install only what the ticket lists, from the company portal or the vendor. Confirm each app opens.

**Verification**

- [ ] Each required application is installed and opens to its main window.
- [ ] The version on the ticket matches the version in the app or in `winget list`.
- [ ] Extra toolbars or trial suites were declined.

## 6. Set the configuration the user will live with

Change only items the ticket or your standard build requires.

| Item | Where | Notes |
| --- | --- | --- |
| Time zone | Settings > Time & language > Date & time | Turn on automatic time. A wrong clock breaks sign-in and certificates. |
| Computer name | Settings > System > About > Rename this PC | Use the naming standard. A rename needs a restart. Skip it when the name is already correct. |
| Power | Settings > System > Power | A desktop can stay awake on AC power. A laptop still needs a balanced plan on battery. |
| Default browser and PDF app | Settings > Apps > Default apps | Set these only when the ticket names them. |
| Network | Settings > Network & internet | Confirm the right Wi-Fi or wired network. Details are in [network-troubleshooting.md](network-troubleshooting.md). |

There is no rename script in this project. Renaming is a one-time change with a restart, and a wrong name is annoying to undo in front of a user.

**Verification**

- [ ] The clock and time zone match the site.
- [ ] The computer name matches the standard, and Windows was restarted if you renamed it.
- [ ] Power settings match desktop or laptop use.
- [ ] Default apps match the ticket.
- [ ] The PC has an address on the network it is supposed to use.

## 7. Verify the devices the user will touch

Check each device that is in scope. "In scope" means the ticket or the standard build includes it.

| Device | What to do | Healthy result |
| --- | --- | --- |
| Display | Set resolution and scale the user can read | Image fills the panel and text is sharp |
| Audio | Play a sound and watch the speaker icon | You hear it, and the level is not muted |
| Camera and microphone | Open the privacy test in Settings, or the app the user will use | Picture and recording work, and a cover or mute switch is not left on by mistake |
| Keyboard and mouse | Type in Notepad and click both buttons | Characters match the keys |
| Printer | Only if the ticket includes one | A Windows test page prints. See the printer section of [windows-troubleshooting.md](windows-troubleshooting.md) |

Device Manager is the place to look when a device has a yellow mark. A yellow mark means Windows needs a driver or the device failed to start. Install the driver from the PC vendor or from Windows Update, not from a random download site.

**Verification**

- [ ] Each in-scope device was tried, not only listed in Device Manager.
- [ ] Yellow marks in Device Manager are resolved or written on the ticket with the device name.
- [ ] A test page was printed if a printer is in scope.

## 8. Check security before handoff

Read [security-considerations.md](security-considerations.md) while you do this.

- Windows Security is on, including real-time protection.
- The firewall is on for the network profile the PC is using.
- The setup account's password is not written on paper stuck to the laptop.
- The user will sign in with their own account. You do not leave them as a permanent local administrator unless the ticket says so.
- BitLocker, if your standard requires it, is on. Confirm status only. Do not copy a recovery key into this Git repository or into a screenshot.

`Get-BitLockerVolume` may require an elevated window. If Windows says access is denied, record that and check encryption in Settings > Privacy & security > Device encryption, or ask for the approved admin process. Do not run `manage-bde -protectors -get`. That command prints the recovery password.

**Verification**

- [ ] Real-time protection and the firewall are on.
- [ ] No shared password is written on the device or saved in the repo.
- [ ] The day-to-day user is not a local admin unless that was requested.
- [ ] Encryption status is recorded without storing a recovery key here.

## 9. Hand the PC to the user

Sit with the user long enough for them to sign in with their own account. Watch them open the one or two apps they care about. Show them how to connect to Wi-Fi if they will leave the building, and how to reach your team. Collect the setup account's session so you do not stay signed in.

Fill [post-deployment-validation.md](post-deployment-validation.md) before you close the ticket. A blank checkbox means you did not look.

**Verification**

- [ ] The user signed in with their own account.
- [ ] The user opened each required app once.
- [ ] The user knows how to reconnect to the network and how to ask for help.
- [ ] The sign-off sheet is filled from this visit, and your name and the date are on it.
- [ ] Inventory and disk reports attached to the ticket contain no passwords.

## Disk report to attach

After updates and app installs, free space should still be comfortable. Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\disk_space_report.ps1 -OutputPath "$env:TEMP\disk.csv"
```

Investigate before handoff when the script warns that free space is under 15 percent. Large update leftovers and installer caches are the usual cause. Deleting a user's documents is not the fix.

**Verification**

- [ ] The disk report is attached to the ticket.
- [ ] Any drive under the threshold is explained on the ticket, or free space was recovered by an approved method.

