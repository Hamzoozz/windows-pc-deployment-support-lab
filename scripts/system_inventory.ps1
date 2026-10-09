#Requires -Version 5.1
<#
.SYNOPSIS
    Collects basic computer and operating system facts and writes them to a CSV file.

.DESCRIPTION
    This is a read-only inventory for desktop support. It queries two CIM classes:

    - Win32_OperatingSystem: Windows edition, version, build, architecture, system drive, last boot
    - Win32_ComputerSystem: manufacturer, model, installed RAM, logical processor count

    It does not collect passwords, tokens, BitLocker recovery keys, serial numbers,
    the signed-in user name, or domain membership.

    The script does not change Windows settings and does not need administrator rights.

.PARAMETER OutputPath
    CSV file to create. The folder must already exist, except for the default
    path under this repository's output folder, which the script creates.
    If you omit OutputPath, the file is output\system-inventory.csv next to the
    repository root (the parent of the scripts folder).

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\system_inventory.ps1

    Shows one inventory row and writes output\system-inventory.csv.

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\system_inventory.ps1 -OutputPath "$env:TEMP\inventory.csv" -Verbose

    Writes the CSV to a temp folder and prints the CIM queries as they run.

.NOTES
    Exit codes:
      0  The report was written.
      1  OutputPath failed validation.
      2  Windows information could not be read, or the CSV file could not be written.

    Run this file. Do not dot-source it in a session you still need, unless you
    only want the Get-LabSystemInventory function. The entry point is skipped
    when the file is dot-sourced.
#>
[CmdletBinding()]
param(
    [string]$OutputPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# Captured at load time. Inside a function, $PSScriptRoot is not reliable.
$script:LabScriptRoot = $PSScriptRoot
. (Join-Path -Path $script:LabScriptRoot -ChildPath 'Lab.Common.ps1')

$script:LabInventoryColumns = @(
    'ComputerName'
    'Manufacturer'
    'Model'
    'OperatingSystem'
    'OSVersion'
    'OSBuild'
    'Architecture'
    'SystemDrive'
    'TotalMemoryGB'
    'LogicalProcessors'
    'LastBootTime'
    'CollectedAtUtc'
)

function Get-LabSystemInventory {
    <#
    .SYNOPSIS
        Returns one object of basic computer and operating system facts.
    #>
    [CmdletBinding()]
    param()

    Write-Verbose 'Querying Win32_OperatingSystem.'
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop

    Write-Verbose 'Querying Win32_ComputerSystem.'
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop

    $memoryGb = $null
    if ($null -ne $cs.TotalPhysicalMemory -and [int64]$cs.TotalPhysicalMemory -gt 0) {
        $memoryGb = [math]::Round(([double]$cs.TotalPhysicalMemory) / 1GB, 2)
    }

    $lastBoot = ''
    if ($null -ne $os.LastBootUpTime) {
        $lastBoot = $os.LastBootUpTime.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    }

    $collected = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

    [pscustomobject]@{
        ComputerName       = Protect-LabCsvValue ([string]$env:COMPUTERNAME)
        Manufacturer       = Protect-LabCsvValue ([string]$cs.Manufacturer)
        Model              = Protect-LabCsvValue ([string]$cs.Model)
        OperatingSystem    = Protect-LabCsvValue ([string]$os.Caption)
        OSVersion          = Protect-LabCsvValue ([string]$os.Version)
        OSBuild            = Protect-LabCsvValue ([string]$os.BuildNumber)
        Architecture       = Protect-LabCsvValue ([string]$os.OSArchitecture)
        SystemDrive        = Protect-LabCsvValue ([string]$os.SystemDrive)
        TotalMemoryGB      = $memoryGb
        LogicalProcessors  = $cs.NumberOfLogicalProcessors
        LastBootTime       = $lastBoot
        CollectedAtUtc     = $collected
    }
}

function Get-LabDefaultInventoryPath {
    [CmdletBinding()]
    param()

    $repoRoot = Split-Path -Path $script:LabScriptRoot -Parent
    $outputDir = Join-Path -Path $repoRoot -ChildPath 'output'
    if (-not (Test-Path -LiteralPath $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir | Out-Null
    }

    Join-Path -Path $outputDir -ChildPath 'system-inventory.csv'
}

# The entry point stays quiet when a test dot-sources this file to call the function.
if ($MyInvocation.InvocationName -ne '.') {
    if ($env:OS -ne 'Windows_NT') {
        Write-Error 'This script supports Windows only.'
        exit 2
    }

    try {
        if ([string]::IsNullOrWhiteSpace($OutputPath)) {
            $OutputPath = Get-LabDefaultInventoryPath
        }

        $pathCheck = Test-LabCsvPath -Path $OutputPath
        if (-not $pathCheck.Ok) {
            Write-Error $pathCheck.Message -ErrorAction Continue
            exit 1
        }

        $row = Get-LabSystemInventory
        $saved = Export-LabReport -Rows @($row) -LiteralPath $pathCheck.FullPath -Columns $script:LabInventoryColumns
        if (-not $saved) {
            exit 2
        }

        Write-Host "Saved system inventory to $($pathCheck.FullPath)"
        $row | Format-Table -AutoSize
        exit 0
    }
    catch {
        Write-Error "Could not collect system inventory. $($_.Exception.Message)" -ErrorAction Continue
        exit 2
    }
}
