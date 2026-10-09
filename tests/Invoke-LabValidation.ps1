#Requires -Version 5.1
<#
.SYNOPSIS
    Validates the lab scripts without changing Windows configuration.

.DESCRIPTION
    Runs two kinds of checks:

    1. Function checks. Sample disk and process objects are passed in memory.
       These do not read the live PC.
    2. Script checks. Each script is started with powershell.exe -File against
       this PC, using a temporary CSV path. Cell values are not printed.

    The temporary CSV files are deleted before the script exits.

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Invoke-LabValidation.ps1

.NOTES
    Exit code 0 means every check passed. Exit code 1 means at least one check failed.
    This file does not record a PC deployment.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$commonPath = Join-Path -Path $repoRoot -ChildPath 'scripts\Lab.Common.ps1'
$inventoryScript = Join-Path -Path $repoRoot -ChildPath 'scripts\system_inventory.ps1'
$diskScript = Join-Path -Path $repoRoot -ChildPath 'scripts\disk_space_report.ps1'
$processScript = Join-Path -Path $repoRoot -ChildPath 'scripts\running_processes.ps1'

. $commonPath

$script:PassCount = 0
$script:FailCount = 0
$script:Failures = New-Object System.Collections.Generic.List[string]

function Write-Check {
    param(
        [bool]$Passed,
        [string]$Message
    )

    if ($Passed) {
        $script:PassCount++
        Write-Host "PASS  $Message"
    }
    else {
        $script:FailCount++
        $script:Failures.Add($Message)
        Write-Host "FAIL  $Message"
    }
}

function Read-LabCsvHeader {
    param([string]$Path)

    $first = Get-Content -LiteralPath $Path -TotalCount 1
    if ($null -eq $first) {
        return @()
    }

    # Export-Csv quotes headers. Strip quotes so the comparison is stable.
    return @($first.Split(',') | ForEach-Object { $_.Trim().Trim('"') })
}

function Get-LabCsvRowCount {
    param([string]$Path)

    $lines = @(Get-Content -LiteralPath $Path | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($lines.Count -eq 0) {
        return 0
    }

    return $lines.Count - 1
}

function Invoke-LabScript {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,

        [string[]]$Arguments = @()
    )

    # Native stderr is an ErrorRecord when merged with 2>&1. Continue keeps a
    # deliberate script error from aborting the rest of the checks.
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $ScriptPath @Arguments 2>&1
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    return [pscustomobject]@{
        ExitCode = $code
        Output   = @($output | ForEach-Object { "$_" })
    }
}

Write-Host 'Function checks (sample data, not a live inventory)'
Write-Host ''

$formula = Protect-LabCsvValue '=HYPERLINK("http://example.invalid")'
Write-Check ($formula.StartsWith("'")) 'Formula-like text is prefixed so a spreadsheet treats it as text.'
Write-Check ((Protect-LabCsvValue 'Windows 11') -eq 'Windows 11') 'Ordinary text is unchanged.'

$sampleDisk = [pscustomobject]@{
    DeviceID   = 'C:'
    VolumeName = 'OS'
    FileSystem = 'NTFS'
    Size       = 100GB
    FreeSpace  = 20GB
}
$sampleRow = ConvertTo-LabDiskSpaceRow -Disk $sampleDisk
Write-Check ($sampleRow.SizeGB -eq 100) '100GB sample disk reports SizeGB 100.'
Write-Check ($sampleRow.FreeGB -eq 20) '20GB free on the sample disk reports FreeGB 20.'
Write-Check ($sampleRow.PercentFree -eq 20) 'Sample disk reports 20 percent free.'

$emptyDisk = [pscustomobject]@{
    DeviceID   = 'Z:'
    VolumeName = $null
    FileSystem = $null
    Size       = 0
    FreeSpace  = 0
}
$emptyRow = ConvertTo-LabDiskSpaceRow -Disk $emptyDisk
Write-Check ($null -eq $emptyRow.PercentFree) 'A zero-size disk does not divide by zero.'

$lowMessage = Get-LabLowSpaceMessage -Row $sampleRow -MinimumFreePercent 15
$highMessage = Get-LabLowSpaceMessage -Row ([pscustomobject]@{ Drive = 'C:'; PercentFree = 10 }) -MinimumFreePercent 15
$exactMessage = Get-LabLowSpaceMessage -Row ([pscustomobject]@{ Drive = 'C:'; PercentFree = 15 }) -MinimumFreePercent 15
Write-Check ([string]::IsNullOrEmpty($lowMessage)) '20 percent free is not a warning at a 15 percent threshold.'
Write-Check ($highMessage -like 'Drive C: has 10% free space*') '10 percent free warns at a 15 percent threshold.'
Write-Check ([string]::IsNullOrEmpty($exactMessage)) 'Free space equal to the threshold is not a warning.'

$goodDrive = Resolve-LabDriveLetter -DriveLetter 'c:'
$badDrive = Resolve-LabDriveLetter -DriveLetter '99'
Write-Check ($goodDrive.Ok -and $goodDrive.DeviceId -eq 'C:') 'Drive letter c: is normalized to C:.'
Write-Check (-not $badDrive.Ok) 'Drive letter 99 is rejected.'

Write-Check (Test-LabProcessName -Name 'explorer') 'Process name explorer is accepted.'
Write-Check (Test-LabProcessName -Name 'powershell') 'Process name powershell is accepted.'
Write-Check (-not (Test-LabProcessName -Name 'notepad.exe')) 'A name ending in .exe is rejected. Get-Process does not want the extension.'
Write-Check (-not (Test-LabProcessName -Name 'bad name')) 'A process name with a space is rejected by this lab filter.'
Write-Check (-not (Test-LabProcessName -Name '*')) 'A wildcard process name is rejected.'

$fakeProcess = [pscustomobject]@{
    Name         = '=calc'
    Id           = 42
    CPU          = 1.256
    WorkingSet64 = 10MB
}
$processRow = ConvertTo-LabProcessRow -Process $fakeProcess
Write-Check ($processRow.Name.StartsWith("'")) 'A process name that starts with = is neutralized.'
Write-Check ($processRow.Id -eq 42) 'Process id is preserved.'
Write-Check ($processRow.CPUSeconds -eq 1.26) 'CPU seconds are rounded to two places.'
Write-Check ($processRow.WorkingSetMB -eq 10) '10MB working set reports WorkingSetMB 10.'

$nullCpu = ConvertTo-LabProcessRow -Process ([pscustomobject]@{
    Name         = 'Idle'
    Id           = 0
    CPU          = $null
    WorkingSet64 = 0
})
Write-Check ($null -eq $nullCpu.CPUSeconds) 'A missing CPU value stays blank instead of throwing.'

$tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ("lab-validation-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null

$forbiddenHeaders = @(
    'Password'
    'Token'
    'Secret'
    'Credential'
    'SerialNumber'
    'CommandLine'
    'RecoveryKey'
    'UserName'
)

try {
    Write-Host ''
    Write-Host 'Script checks (live read-only queries; values are not printed)'
    Write-Host ''

    $inventoryCsv = Join-Path -Path $tempRoot -ChildPath 'inventory.csv'
    $inventoryRun = Invoke-LabScript -ScriptPath $inventoryScript -Arguments @('-OutputPath', $inventoryCsv)
    Write-Check ($inventoryRun.ExitCode -eq 0) 'system_inventory.ps1 exits 0 for a valid CSV path.'
    Write-Check (Test-Path -LiteralPath $inventoryCsv) 'system_inventory.ps1 creates the CSV file.'

    $inventoryHeader = @(Read-LabCsvHeader -Path $inventoryCsv)
    $expectedInventory = @(
        'ComputerName', 'Manufacturer', 'Model', 'OperatingSystem', 'OSVersion', 'OSBuild',
        'Architecture', 'SystemDrive', 'TotalMemoryGB', 'LogicalProcessors', 'LastBootTime', 'CollectedAtUtc'
    )
    $inventoryHeaderOk = ($inventoryHeader -join '|') -eq ($expectedInventory -join '|')
    Write-Check $inventoryHeaderOk 'system_inventory.ps1 CSV columns match the documented field list.'
    Write-Check ((Get-LabCsvRowCount -Path $inventoryCsv) -eq 1) 'system_inventory.ps1 writes one data row.'

    $leaked = @($forbiddenHeaders | Where-Object { $inventoryHeader -contains $_ })
    Write-Check ($leaked.Count -eq 0) 'system_inventory.ps1 CSV header does not include passwords, tokens, serial numbers, or user names.'

    $badInventory = Invoke-LabScript -ScriptPath $inventoryScript -Arguments @('-OutputPath', (Join-Path $tempRoot 'notes.txt'))
    Write-Check ($badInventory.ExitCode -eq 1) 'system_inventory.ps1 exits 1 when OutputPath is not a .csv file.'

    $missingFolder = Join-Path -Path $tempRoot -ChildPath 'missing\inventory.csv'
    $missingRun = Invoke-LabScript -ScriptPath $inventoryScript -Arguments @('-OutputPath', $missingFolder)
    Write-Check ($missingRun.ExitCode -eq 1) 'system_inventory.ps1 exits 1 when the output folder does not exist.'

    $diskCsv = Join-Path -Path $tempRoot -ChildPath 'disk.csv'
    $diskRun = Invoke-LabScript -ScriptPath $diskScript -Arguments @('-OutputPath', $diskCsv, '-MinimumFreePercent', '15')
    Write-Check ($diskRun.ExitCode -eq 0) 'disk_space_report.ps1 exits 0 for local disks.'
    Write-Check (Test-Path -LiteralPath $diskCsv) 'disk_space_report.ps1 creates the CSV file.'

    $diskHeader = @(Read-LabCsvHeader -Path $diskCsv)
    $expectedDisk = @('Drive', 'VolumeLabel', 'FileSystem', 'SizeGB', 'FreeGB', 'PercentFree')
    Write-Check (($diskHeader -join '|') -eq ($expectedDisk -join '|')) 'disk_space_report.ps1 CSV columns match the documented field list.'
    Write-Check ((Get-LabCsvRowCount -Path $diskCsv) -ge 1) 'disk_space_report.ps1 writes at least one local disk.'

    $badDriveRun = Invoke-LabScript -ScriptPath $diskScript -Arguments @('-DriveLetter', '99')
    Write-Check ($badDriveRun.ExitCode -eq 1) 'disk_space_report.ps1 exits 1 for drive letter 99.'

    $badPercent = Invoke-LabScript -ScriptPath $diskScript -Arguments @('-MinimumFreePercent', '150')
    Write-Check ($badPercent.ExitCode -eq 1) 'disk_space_report.ps1 exits 1 when MinimumFreePercent is above 100.'

    $absentDrive = Invoke-LabScript -ScriptPath $diskScript -Arguments @('-DriveLetter', 'Z')
    # Z: may exist on a machine that has a fixed Z: volume. Accept 0 only when a row is a real disk.
    # This lab treats "no local disk" as exit 2. If Z: is a real fixed disk, exit 0 is also honest.
    $zDisks = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3 AND DeviceID='Z:'" -ErrorAction SilentlyContinue)
    if ($zDisks.Count -eq 0) {
        Write-Check ($absentDrive.ExitCode -eq 2) 'disk_space_report.ps1 exits 2 when Z: is not a local fixed disk.'
    }
    else {
        Write-Check ($absentDrive.ExitCode -eq 0) 'disk_space_report.ps1 exits 0 because this PC has a fixed disk Z:.'
    }

    $processCsv = Join-Path -Path $tempRoot -ChildPath 'processes.csv'
    $processRun = Invoke-LabScript -ScriptPath $processScript -Arguments @('-Top', '5', '-OutputPath', $processCsv)
    Write-Check ($processRun.ExitCode -eq 0) 'running_processes.ps1 exits 0 for -Top 5.'
    $processHeader = @(Read-LabCsvHeader -Path $processCsv)
    $expectedProcess = @('Name', 'Id', 'CPUSeconds', 'WorkingSetMB')
    Write-Check (($processHeader -join '|') -eq ($expectedProcess -join '|')) 'running_processes.ps1 CSV columns match the documented field list.'
    Write-Check ((Get-LabCsvRowCount -Path $processCsv) -eq 5) 'running_processes.ps1 -Top 5 writes five data rows.'
    $processLeaked = @($forbiddenHeaders | Where-Object { $processHeader -contains $_ })
    Write-Check ($processLeaked.Count -eq 0) 'running_processes.ps1 does not export command lines or credentials.'

    $badName = Invoke-LabScript -ScriptPath $processScript -Arguments @('-Name', 'notepad.exe')
    Write-Check ($badName.ExitCode -eq 1) 'running_processes.ps1 exits 1 when the name includes .exe.'

    $badTop = Invoke-LabScript -ScriptPath $processScript -Arguments @('-Top', '0')
    Write-Check ($badTop.ExitCode -eq 1) 'running_processes.ps1 exits 1 when Top is 0.'

    $missingProcessCsv = Join-Path -Path $tempRoot -ChildPath 'none.csv'
    $missingProcess = Invoke-LabScript -ScriptPath $processScript -Arguments @('-Name', 'not-a-real-process-lab', '-OutputPath', $missingProcessCsv)
    Write-Check ($missingProcess.ExitCode -eq 0) 'running_processes.ps1 exits 0 when a valid name is not running.'
    Write-Check ((Get-LabCsvRowCount -Path $missingProcessCsv) -eq 0) 'A process name that is not running still writes a CSV header and no data rows.'
    $noneHeader = @(Read-LabCsvHeader -Path $missingProcessCsv)
    Write-Check (($noneHeader -join '|') -eq ($expectedProcess -join '|')) 'The empty process CSV keeps the documented header.'

    $dotSourceCommand = ". '$inventoryScript'; if (-not (Get-Command Get-LabSystemInventory -ErrorAction SilentlyContinue)) { exit 3 }; exit 0"
    $repoOutput = Join-Path -Path $repoRoot -ChildPath 'output\system-inventory.csv'
    if (Test-Path -LiteralPath $repoOutput) {
        Remove-Item -LiteralPath $repoOutput -Force
    }
    & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command $dotSourceCommand | Out-Null
    Write-Check ($LASTEXITCODE -eq 0) 'Dot-sourcing system_inventory.ps1 loads Get-LabSystemInventory and does not exit early.'
    Write-Check (-not (Test-Path -LiteralPath $repoOutput)) 'Dot-sourcing system_inventory.ps1 does not write a CSV file.'

    $repoOutput = Join-Path -Path $repoRoot -ChildPath 'output\system-inventory.csv'
    if (Test-Path -LiteralPath $repoOutput) {
        Remove-Item -LiteralPath $repoOutput -Force
    }
    $defaultRun = Invoke-LabScript -ScriptPath $inventoryScript
    Write-Check ($defaultRun.ExitCode -eq 0) 'system_inventory.ps1 exits 0 when OutputPath is omitted.'
    Write-Check (Test-Path -LiteralPath $repoOutput) 'Omitting OutputPath writes output\system-inventory.csv.'
    if (Test-Path -LiteralPath $repoOutput) {
        Remove-Item -LiteralPath $repoOutput -Force
    }
    $outputDir = Join-Path -Path $repoRoot -ChildPath 'output'
    if ((Test-Path -LiteralPath $outputDir) -and -not (Get-ChildItem -LiteralPath $outputDir -Force | Select-Object -First 1)) {
        Remove-Item -LiteralPath $outputDir -Force
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }

    $leftoverInventory = Join-Path -Path $repoRoot -ChildPath 'output\system-inventory.csv'
    if (Test-Path -LiteralPath $leftoverInventory) {
        Remove-Item -LiteralPath $leftoverInventory -Force
    }
}

Write-Host ''
Write-Host "Passed: $script:PassCount"
Write-Host "Failed: $script:FailCount"
if ($script:FailCount -gt 0) {
    Write-Host 'Failed checks:'
    foreach ($item in $script:Failures) {
        Write-Host " - $item"
    }
    exit 1
}

exit 0
