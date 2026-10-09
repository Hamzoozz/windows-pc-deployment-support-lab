# Software installation

**Status: proposed procedure.** No application was installed, upgraded, or removed while this repository was built. `winget` examples below are commands to run on a PC you support, when a ticket names that application.

Install the applications the request lists, from a source you can explain, and prove each one opens.

## 1. Confirm the request and the license

Write the product name, the edition, and who approves a paid license. A free vendor download and a company-licensed copy are different installs. If the user emailed you an installer, treat that file as untrusted until you can show it came from the vendor or from your software portal.

**Verification**

- [ ] Product name and version or edition are on the ticket.
- [ ] A paid product has an approved license path.
- [ ] The installer source is the vendor or the company portal.

**Recorded result for this repository:** Not performed.

## 2. See whether it is already there

Check **Settings > Apps > Installed apps** first. Then ask Windows Package Manager, if the PC has it:

```powershell
winget --version
winget list --name "App Name"
```

`winget --version` shows the client is installed. `winget list` searches software it knows about. Some older installers never register with `winget`, so an empty list does not always mean the app is absent. The Settings page is the backup.

For a closer look at one package id:

```powershell
winget show --id Vendor.Product
```

`--id` is the stable package name, such as `Microsoft.VisualStudioCode`. `--name` is the friendly title and can match more than one package. Prefer `--id` with `--exact` when you install, so you do not accept a similarly named package.

**Verification**

- [ ] You checked Installed apps before downloading anything.
- [ ] You recorded the installed version, or recorded that it was absent.

**Recorded result for this repository:** Not performed. `winget list` was not run as part of building this project.

## 3. Choose per-user or per-machine

A per-machine install needs administrator rights and is available to every account on the PC. A per-user install stays in that person's profile and is the right choice for a single employee when the vendor supports it. Your company standard wins when it names one of these.

Do not disable User Account Control to make an installer quieter. Give the setup window the admin credentials through the normal prompt, or use the deployment tool your company already runs.

**Verification**

- [ ] You know whether the app was installed for one user or for the computer.
- [ ] The elevation prompt was the normal Windows prompt.

**Recorded result for this repository:** Not performed.

## 4. Install from the chosen source

Company portal: use the portal's Install button and wait until it reports success.

`winget`, when your site allows it:

```powershell
winget search "Visual Studio Code"
winget install --id Microsoft.VisualStudioCode --exact --accept-package-agreements --accept-source-agreements
```

`winget search` finds candidates. `winget install --id ... --exact` installs that id only. The two `--accept-*` switches record agreement with the package and source terms so the command can finish in a script. Read those terms the first time you see a new publisher. `winget source list` shows where the client is allowed to look. Prefer the company source when you have one.

This project does not ship installers and does not run `winget install`.

Decline extra offers inside a vendor setup program: extra browsers, toolbars, and trial antivirus. Those are a common way a "simple install" leaves unwanted software behind.

**Verification**

- [ ] The installer came from the source you named in step 1.
- [ ] Extra bundled software was declined.
- [ ] The installer finished with its own success message, or the error text was saved.

**Recorded result for this repository:** Not performed.

## 5. Prove the install

Open the application and perform one small action the user cares about: sign-in page loads, a blank document opens, or the about box shows the expected version.

```powershell
winget list --id Microsoft.VisualStudioCode --exact
```

You can also read the uninstall registry, which is what Settings uses for many classic apps. This is a read:

```powershell
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
    Where-Object { $_.DisplayName } |
    Select-Object DisplayName, DisplayVersion, Publisher |
    Sort-Object DisplayName
```

`HKLM` is the machine-wide list and may require administrator rights to read. The current user's list is `HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*`. `DisplayName` and `DisplayVersion` are what you put on the sign-off sheet. Do not change these keys to "hide" an application.

**Verification**

- [ ] The app opened.
- [ ] The version on the sign-off sheet matches `winget list` or the uninstall entry.
- [ ] A shortcut exists where the user will look, when the installer normally creates one.

**Recorded result for this repository:** Not performed.

## 6. If it fails, remove the half-installed copy

Save the installer error first. Use **Settings > Apps** or the vendor's uninstall entry. When `winget` installed it, this removes that package:

```powershell
winget uninstall --id Microsoft.VisualStudioCode --exact
```

Restart if the installer says a restart is required, then try once more from the same trusted source. If the second attempt fails with the same error, stop and escalate with the error text. Installing a second copy on top of a broken one usually makes the uninstall harder.

**Verification**

- [ ] The failure text is on the ticket before you uninstall.
- [ ] The broken copy was removed through Apps or `winget uninstall`.
- [ ] A second attempt used the same trusted source, or the ticket was escalated.

**Recorded result for this repository:** Not performed.

## 7. Record it on the sign-off

Add one row per application on [post-deployment-validation.md](post-deployment-validation.md). Include the version you observed, not the version you meant to install.

**Verification**

- [ ] Every requested app has a row.
- [ ] Apps that were not requested were not installed "while you were there."

**Recorded result for this repository:** Not performed.
