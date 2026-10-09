#Requires -Version 5.1
<#
.SYNOPSIS
    Lists running processes, busiest memory users first.

.DESCRIPTION
    Uses Get-Process, which reads the process table available to the current
    user. Each row contains the process name, process id, CPU seconds, and
    working set in megabytes.

    The script does not stop processes, change priority, or read command lines.
    Command lines are omitted because they sometimes contain connection strings
    or tokens. The executable path is omitted because it can fail with access
    denied and can expose a user profile path.

    Administrator rights are not required. Some processes still show a blank
    CPU value when Windows does not provide that counter to a standard user.

.PARAMETER Name
    Optional process name without .exe, such as explorer or powershell.
    Wildcards and path characters are rejected.

.PARAMETER Top
    Optional maximum number of rows after sorting by memory. Use 1 through 5000.
    Omit it to list every matching process.

.PARAMETER OutputPath
    Optional CSV file. The folder must already exist.

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\running_processes.ps1 -Top 15

    Shows the 15 processes using the most working-set memory.

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\running_processes.ps1 -Name explorer -OutputPath "$env:TEMP\processes.csv"

.NOTES
    Exit codes:
      0  The list was produced. Zero matches is still success when the name is valid.
      1  Name, Top, or OutputPath failed validation.
      2  The process list could not be read, or the CSV file could not be written.

    Get-Process -Name expects the image name, not the file name. Use notepad,
    not notepad.exe.
#>
[CmdletBinding()]
param(
    [string]$Name,

    [int]$Top,

    [string]$OutputPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

. (Join-Path -Path $PSScriptRoot -ChildPath 'Lab.Common.ps1')

$script:LabProcessColumns = @(
    'Name'
    'Id'
    'CPUSeconds'
    'WorkingSetMB'
)

function Get-LabProcessReport {
    <#
    .SYNOPSIS
        Returns process rows sorted by working set, largest first.
    #>
    [CmdletBinding()]
    param(
        [string]$ProcessName,

        [int]$TopCount = 0
    )

    Write-Verbose 'Reading the process table with Get-Process.'
    if ([string]::IsNullOrWhiteSpace($ProcessName)) {
        $processes = @(Get-Process -ErrorAction Stop | Where-Object { $null -ne $_ })
    }
    else {
        # SilentlyContinue: a valid name that is not running is an empty result, not a crash.
        $processes = @(Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Where-Object { $null -ne $_ })
    }

    $sorted = @($processes | Sort-Object -Property WorkingSet64 -Descending)
    if ($TopCount -gt 0 -and $sorted.Count -gt $TopCount) {
        $sorted = @($sorted | Select-Object -First $TopCount)
    }

    return @($sorted | ForEach-Object { ConvertTo-LabProcessRow -Process $_ })
}

if ($MyInvocation.InvocationName -ne '.') {
    if ($env:OS -ne 'Windows_NT') {
        Write-Error 'This script supports Windows only.'
        exit 2
    }

    if ($PSBoundParameters.ContainsKey('Name')) {
        if (-not (Test-LabProcessName -Name $Name)) {
            Write-Error 'Name must be a process name such as explorer or powershell. Do not include .exe, a path, or wildcard characters.' -ErrorAction Continue
            exit 1
        }
    }

    $topCount = 0
    if ($PSBoundParameters.ContainsKey('Top')) {
        if ($Top -lt 1 -or $Top -gt 5000) {
            Write-Error 'Top must be a whole number from 1 through 5000.' -ErrorAction Continue
            exit 1
        }
        $topCount = $Top
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
        $processName = ''
        if ($PSBoundParameters.ContainsKey('Name')) {
            $processName = $Name
        }

        $rows = @(Get-LabProcessReport -ProcessName $processName -TopCount $topCount)
        if ($rows.Count -eq 0) {
            Write-Warning "No running process matched '$processName'."
        }

        if ($fullOutput) {
            $saved = Export-LabReport -Rows $rows -LiteralPath $fullOutput -Columns $script:LabProcessColumns
            if (-not $saved) {
                exit 2
            }
            Write-Host "Saved process report to $fullOutput"
        }

        if ($rows.Count -gt 0) {
            $rows | Select-Object -Property $script:LabProcessColumns | Format-Table -AutoSize
        }
        exit 0
    }
    catch {
        Write-Error "Could not list running processes. $($_.Exception.Message)" -ErrorAction Continue
        exit 2
    }
}
