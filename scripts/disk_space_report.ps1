#Requires -Version 5.1
<#
.SYNOPSIS
    Reports free space on local fixed disks.

.DESCRIPTION
    Reads Win32_LogicalDisk for DriveType 3 (local disks) and prints size,
    free space, and percent free. Removable, network, and CD drives are omitted
    so a USB stick or a disconnected mapped drive does not look like a full
    system disk.

    A warning is written for each drive below -MinimumFreePercent. The default
    threshold is 15 percent. The warning does not delete files or expand disks.

    The script does not need administrator rights.

.PARAMETER DriveLetter
    Optional drive to report, such as C or C:. Omit it to report every local disk.

.PARAMETER OutputPath
    Optional CSV file. The folder must already exist. When omitted, the report
    is only shown on screen.

.PARAMETER MinimumFreePercent
    Warn when percent free is lower than this number. Use 0 through 100.
    The default is 15. A drive sitting exactly at the threshold is not a warning.

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\disk_space_report.ps1

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\disk_space_report.ps1 -DriveLetter C -MinimumFreePercent 20 -OutputPath "$env:TEMP\disk.csv"

.NOTES
    Exit codes:
      0  The report was produced. Low-space warnings can still appear.
      1  DriveLetter, OutputPath, or MinimumFreePercent failed validation.
      2  Disk information could not be read, no matching disk was found, or the CSV file could not be written.

    Win32_LogicalDisk DriveType values you may be asked about:
      2 Removable, 3 Local disk, 4 Network, 5 Compact disc.
#>
[CmdletBinding()]
param(
    [string]$DriveLetter,

    [string]$OutputPath,

    [double]$MinimumFreePercent = 15
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

. (Join-Path -Path $PSScriptRoot -ChildPath 'Lab.Common.ps1')

$script:LabDiskColumns = @(
    'Drive'
    'VolumeLabel'
    'FileSystem'
    'SizeGB'
    'FreeGB'
    'PercentFree'
)

function Get-LabFixedDisk {
    <#
    .SYNOPSIS
        Gets local fixed disks, optionally limited to one device id such as C:.
    #>
    [CmdletBinding()]
    param(
        [string]$DeviceId
    )

    Write-Verbose 'Querying Win32_LogicalDisk where DriveType=3 (local disk).'
    # DriveType is a WMI enumeration. 3 means a local fixed disk.
    $disks = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop)

    if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
        $disks = @($disks | Where-Object { $_.DeviceID -eq $DeviceId })
    }

    return $disks
}

if ($MyInvocation.InvocationName -ne '.') {
    if ($env:OS -ne 'Windows_NT') {
        Write-Error 'This script supports Windows only.'
        exit 2
    }

    if ($MinimumFreePercent -lt 0 -or $MinimumFreePercent -gt 100) {
        Write-Error 'MinimumFreePercent must be from 0 through 100.' -ErrorAction Continue
        exit 1
    }

    $deviceId = $null
    if ($PSBoundParameters.ContainsKey('DriveLetter')) {
        $driveCheck = Resolve-LabDriveLetter -DriveLetter $DriveLetter
        if (-not $driveCheck.Ok) {
            Write-Error $driveCheck.Message -ErrorAction Continue
            exit 1
        }
        $deviceId = $driveCheck.DeviceId
    }

    $fullOutput = $null
    if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
        $pathCheck = Test-LabCsvPath -Path $OutputPath
        if (-not $pathCheck.Ok) {
            Write-Error $pathCheck.Message -ErrorAction Continue
            exit 1
        }
        $fullOutput = $pathCheck.FullPath
    }

    try {
        $disks = @(Get-LabFixedDisk -DeviceId $deviceId)
        if ($disks.Count -eq 0) {
            if ($deviceId) {
                Write-Error "No local fixed disk was found for $deviceId." -ErrorAction Continue
            }
            else {
                Write-Error 'No local fixed disks were found.' -ErrorAction Continue
            }
            exit 2
        }

        $rows = @($disks | ForEach-Object { ConvertTo-LabDiskSpaceRow -Disk $_ })
        foreach ($row in $rows) {
            $message = Get-LabLowSpaceMessage -Row $row -MinimumFreePercent $MinimumFreePercent
            if ($message) {
                Write-Warning $message
            }
        }

        if ($fullOutput) {
            $saved = Export-LabReport -Rows $rows -LiteralPath $fullOutput -Columns $script:LabDiskColumns
            if (-not $saved) {
                exit 2
            }
            Write-Host "Saved disk space report to $fullOutput"
        }

        $rows | Format-Table -AutoSize
        exit 0
    }
    catch {
        Write-Error "Could not report disk space. $($_.Exception.Message)" -ErrorAction Continue
        exit 2
    }
}
