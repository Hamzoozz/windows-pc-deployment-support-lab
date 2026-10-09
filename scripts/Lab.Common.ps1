# Shared helpers for the Windows PC Deployment & Support Lab.
# These functions only check input and shape report rows.
# They do not change Windows settings or collect secrets.

Set-StrictMode -Version 2.0

function Protect-LabCsvValue {
    <#
    .SYNOPSIS
        Neutralizes spreadsheet formula characters at the start of a text value.
    .DESCRIPTION
        Excel and similar tools treat a cell that starts with =, +, -, or @ as a
        formula. Prefixing a single quote makes the value display as text.
        This matters if a computer name or volume label ever contains those characters.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Value
    )

    if ([string]::IsNullOrEmpty($Value)) {
        return ''
    }

    if ($Value.StartsWith('=') -or $Value.StartsWith('+') -or $Value.StartsWith('-') -or $Value.StartsWith('@')) {
        return "'" + $Value
    }

    return $Value
}

function Test-LabCsvPath {
    <#
    .SYNOPSIS
        Checks that a report path is a .csv file in a folder that already exists.
    .OUTPUTS
        An object with Ok ($true or $false), Message, and FullPath.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return [pscustomobject]@{
            Ok       = $false
            Message  = 'OutputPath is empty. Example: .\output\system-inventory.csv'
            FullPath = $null
        }
    }

    if ($Path -notmatch '(?i)\.csv$') {
        return [pscustomobject]@{
            Ok       = $false
            Message  = 'OutputPath must end in .csv. Example: .\output\system-inventory.csv'
            FullPath = $null
        }
    }

    $leaf = Split-Path -Path $Path -Leaf
    if ($leaf -match '[<>:"|?*]') {
        return [pscustomobject]@{
            Ok       = $false
            Message  = 'The file name contains a character Windows does not allow: < > : " | ? *'
            FullPath = $null
        }
    }

    try {
        $full = [System.IO.Path]::GetFullPath($Path)
    }
    catch {
        return [pscustomobject]@{
            Ok       = $false
            Message  = "OutputPath is not a valid path. $($_.Exception.Message)"
            FullPath = $null
        }
    }

    $parent = Split-Path -Path $full -Parent
    if ([string]::IsNullOrWhiteSpace($parent) -or -not (Test-Path -LiteralPath $parent -PathType Container)) {
        return [pscustomobject]@{
            Ok       = $false
            Message  = "The folder for OutputPath does not exist: $parent"
            FullPath = $null
        }
    }

    if (Test-Path -LiteralPath $full -PathType Container) {
        return [pscustomobject]@{
            Ok       = $false
            Message  = "OutputPath is a folder. Pass a .csv file path instead: $full"
            FullPath = $null
        }
    }

    return [pscustomobject]@{
        Ok       = $true
        Message  = $full
        FullPath = $full
    }
}

function Export-LabReport {
    <#
    .SYNOPSIS
        Writes report rows to a CSV file, including a header when there are no rows.
    .DESCRIPTION
        Windows PowerShell 5.1 writes an empty file when Export-Csv receives no
        objects, so this function writes the header row itself in that case.
        Returns $true when the file is written.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object[]]$Rows,

        [Parameter(Mandatory = $true)]
        [string]$LiteralPath,

        [Parameter(Mandatory = $true)]
        [string[]]$Columns
    )

    if ($null -eq $Rows) {
        $Rows = @()
    }

    $rowsToWrite = @($Rows)

    try {
        if ($rowsToWrite.Count -eq 0) {
            $header = $Columns -join ','
            Set-Content -LiteralPath $LiteralPath -Value $header -Encoding UTF8 -ErrorAction Stop
            return $true
        }

        $rowsToWrite |
            Select-Object -Property $Columns |
            Export-Csv -LiteralPath $LiteralPath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
        return $true
    }
    catch {
        Write-Error "Could not write the CSV file '$LiteralPath'. $($_.Exception.Message)"
        return $false
    }
}

function Test-LabProcessName {
    <#
    .SYNOPSIS
        Accepts a normal Windows process name and rejects wildcards and path characters.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $false
    }

    # Image names such as explorer or RuntimeBroker. No path, no .exe, no wildcards.
    # Spaces are rejected so a value cannot smuggle extra arguments.
    if ($Name -like '*.exe') {
        return $false
    }

    return $Name -match '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$'
}

function ConvertTo-LabProcessRow {
    <#
    .SYNOPSIS
        Copies safe process fields into one report object.
    .DESCRIPTION
        CPU can be null for processes that do not expose a processor time counter
        to a standard user. Working set is converted from bytes to megabytes with
        the 1MB constant. Command line and executable path are not copied.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Process
    )

    $cpu = $null
    if ($null -ne $Process.CPU) {
        $cpu = [math]::Round([double]$Process.CPU, 2)
    }

    $workingSet = 0L
    if ($null -ne $Process.WorkingSet64) {
        $workingSet = [int64]$Process.WorkingSet64
    }

    [pscustomobject]@{
        Name            = Protect-LabCsvValue ([string]$Process.Name)
        Id              = [int]$Process.Id
        CPUSeconds      = $cpu
        WorkingSetMB    = [math]::Round($workingSet / 1MB, 2)
        # Used only if a caller sorts before selecting the public columns.
        WorkingSetBytes = $workingSet
    }
}

function Resolve-LabDriveLetter {
    <#
    .SYNOPSIS
        Turns C or C: into C: and rejects anything that is not one letter.
    .OUTPUTS
        An object with Ok, Message, and DeviceId (for example C:).
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$DriveLetter
    )

    if ([string]::IsNullOrWhiteSpace($DriveLetter)) {
        return [pscustomobject]@{
            Ok       = $false
            Message  = 'DriveLetter is empty. Example: C'
            DeviceId = $null
        }
    }

    $trimmed = $DriveLetter.Trim().TrimEnd('\').TrimEnd(':')
    if ($trimmed -notmatch '^[A-Za-z]$') {
        return [pscustomobject]@{
            Ok       = $false
            Message  = 'DriveLetter must be a single letter such as C or C:.'
            DeviceId = $null
        }
    }

    return [pscustomobject]@{
        Ok       = $true
        Message  = 'Drive letter accepted.'
        DeviceId = $trimmed.ToUpperInvariant() + ':'
    }
}

function ConvertTo-LabDiskSpaceRow {
    <#
    .SYNOPSIS
        Converts one Win32_LogicalDisk object (or a similar object) into report fields.
    .DESCRIPTION
        Size and FreeSpace from WMI/CIM are bytes. Dividing by 1GB uses PowerShell's
        built-in gigabyte constant. PercentFree is blank when Size is missing or zero
        so the script does not divide by zero.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Disk
    )

    $size = 0.0
    $free = 0.0
    if ($null -ne $Disk.Size) {
        $size = [double]$Disk.Size
    }
    if ($null -ne $Disk.FreeSpace) {
        $free = [double]$Disk.FreeSpace
    }

    $percent = $null
    if ($size -gt 0) {
        $percent = [math]::Round(($free / $size) * 100, 1)
    }

    $label = ''
    if ($null -ne $Disk.VolumeName) {
        $label = [string]$Disk.VolumeName
    }

    $fileSystem = ''
    if ($null -ne $Disk.FileSystem) {
        $fileSystem = [string]$Disk.FileSystem
    }

    [pscustomobject]@{
        Drive       = Protect-LabCsvValue ([string]$Disk.DeviceID)
        VolumeLabel = Protect-LabCsvValue $label
        FileSystem  = Protect-LabCsvValue $fileSystem
        SizeGB      = [math]::Round($size / 1GB, 2)
        FreeGB      = [math]::Round($free / 1GB, 2)
        PercentFree = $percent
    }
}

function Get-LabLowSpaceMessage {
    <#
    .SYNOPSIS
        Returns a warning message when free space is below the threshold.
    .DESCRIPTION
        A drive at exactly the threshold is not a warning. PercentFree of $null
        (unknown size) does not produce a low-space warning.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Row,

        [Parameter(Mandatory = $true)]
        [double]$MinimumFreePercent
    )

    if ($null -eq $Row.PercentFree) {
        return $null
    }

    if ([double]$Row.PercentFree -lt $MinimumFreePercent) {
        return "Drive $($Row.Drive) has $($Row.PercentFree)% free space, which is below the $MinimumFreePercent% threshold."
    }

    return $null
}
