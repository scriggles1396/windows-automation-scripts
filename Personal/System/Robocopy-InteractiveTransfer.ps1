<#
.SYNOPSIS
    Interactively copies, moves, or mirrors a folder to one or more destinations using Robocopy.

.DESCRIPTION
    Collects a source folder, destination folders, and one transfer mode: Copy, Move, or Mirror.
    Subfolders (including empty ones) are always included. Robocopy retries failed files three
    times, waiting five seconds between attempts. The script validates paths before a transfer,
    prevents overlapping source and destination folders, and explains Robocopy results clearly.

    A multi-destination Move first copies successfully to every destination, then removes the
    source contents. It never deletes source files after only a partial multi-destination copy.

.AUTHOR
    scriggles1396

.VERSION
    1.0.0

.LAST UPDATED
    2026-09-03

.AI ASSISTANCE
    AI-assisted:
    Portions of this script and/or its documentation were created with assistance from
    ChatGPT by OpenAI. The output should be reviewed and tested by a human before publication
    or production use.

.REQUIREMENTS
    - Windows PowerShell 5.1 or later
    - Windows built-in robocopy.exe
    - Read access to the source and write access to every destination

.EXAMPLE
    PS> .\Robocopy-InteractiveTransfer.ps1
    Starts the guided transfer process.

.OUTPUTS
    - Console transfer status and final result summary
    - An optional Robocopy log file

.SAFETY
    Mirror makes each destination match the source and can delete destination files that do not
    exist in the source. It requires a separate typed confirmation.

    Move deletes source contents only after successful copies to every destination. Review the
    confirmation summary carefully and test with non-critical data first.

.LICENSE
    MIT License. See the repository LICENSE file.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Pause-BeforeExit {
    Write-Host ''
    [void](Read-Host 'Press Enter to close')
}

function Get-YesNo {
    param([Parameter(Mandatory)][string]$Prompt)

    do {
        $answer = (Read-Host "$Prompt [Y/N]").Trim()
        if ($answer -match '^(?i)y(es)?$') { return $true }
        if ($answer -match '^(?i)n(o)?$') { return $false }
        Write-Warning 'Please enter Y or N.'
    } while ($true)
}

function Get-NormalizedPath {
    param([Parameter(Mandatory)][string]$Path)

    $expanded = [Environment]::ExpandEnvironmentVariables($Path.Trim().Trim('"'))
    $fullPath = [System.IO.Path]::GetFullPath($expanded)
    if ($fullPath.Length -gt 3) { $fullPath = $fullPath.TrimEnd('\') }
    return $fullPath
}

function Test-OverlappingPaths {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )

    if ($Source.Equals($Destination, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    $sourcePrefix = $Source.TrimEnd('\') + '\'
    $destinationPrefix = $Destination.TrimEnd('\') + '\'
    return $Destination.StartsWith($sourcePrefix, [StringComparison]::OrdinalIgnoreCase) -or
           $Source.StartsWith($destinationPrefix, [StringComparison]::OrdinalIgnoreCase)
}

function Get-SourceFolder {
    do {
        $value = Read-Host 'Source folder'
        if ([string]::IsNullOrWhiteSpace($value)) {
            Write-Warning 'A source folder is required.'
            continue
        }
        try {
            $path = Get-NormalizedPath -Path $value
            if ((Test-Path -LiteralPath $path -PathType Container)) { return $path }
            Write-Warning "The source folder does not exist: $path"
        } catch {
            Write-Warning "That source path is not valid: $($_.Exception.Message)"
        }
    } while ($true)
}

function Get-DestinationFolder {
    param([Parameter(Mandatory)][string]$Source, [Parameter(Mandatory)][int]$Number)

    do {
        $value = Read-Host "Destination $Number"
        if ([string]::IsNullOrWhiteSpace($value)) {
            Write-Warning 'A destination folder is required.'
            continue
        }
        try {
            $path = Get-NormalizedPath -Path $value
            if (Test-OverlappingPaths -Source $Source -Destination $path) {
                Write-Warning 'The source and destination cannot be the same folder or contain one another.'
                continue
            }
            if (Test-Path -LiteralPath $path) {
                if (Test-Path -LiteralPath $path -PathType Container) { return $path }
                Write-Warning "The destination exists but is not a folder: $path"
                continue
            }
            if (Get-YesNo -Prompt "Destination does not exist. Create it: $path") {
                New-Item -ItemType Directory -LiteralPath $path -Force | Out-Null
                return $path
            }
        } catch {
            Write-Warning "Unable to use that destination: $($_.Exception.Message)"
        }
    } while ($true)
}

function Get-RobocopyResultText {
    param([int]$ExitCode)

    if ($ExitCode -ge 8) { return "FAILED (Robocopy exit code $ExitCode)" }
    switch ($ExitCode) {
        0 { return 'SUCCESS - no files needed copying' }
        1 { return 'SUCCESS - files copied' }
        2 { return 'SUCCESS - extra destination files found (not removed unless mirroring)' }
        3 { return 'SUCCESS - files copied and extra destination files found' }
        default { return "SUCCESS WITH WARNINGS - Robocopy exit code $ExitCode" }
    }
}

function Invoke-RobocopyTransfer {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][ValidateSet('Copy', 'Mirror')][string]$Mode,
        [string]$LogPath
    )

    $arguments = @($Source, $Destination, '/E', '/COPY:DAT', '/DCOPY:DAT', '/R:3', '/W:5', '/Z', '/TEE', '/ETA')
    if ($Mode -eq 'Mirror') { $arguments[2] = '/MIR' }
    if ($LogPath) { $arguments += "/LOG+:$LogPath" }

    Write-Host "`nStarting $Mode transfer to: $Destination" -ForegroundColor Cyan
    & robocopy.exe @arguments
    return $LASTEXITCODE
}

try {
    if (-not (Get-Command robocopy.exe -ErrorAction SilentlyContinue)) {
        throw 'robocopy.exe was not found. This script must run on Windows with Robocopy available.'
    }

    Write-Host 'ROBOCOPY FILE TRANSFER' -ForegroundColor Cyan
    Write-Host '======================' -ForegroundColor Cyan
    Write-Host 'UNC paths such as \\server\share\folder are supported.'
    Write-Host ''

    $source = Get-SourceFolder
    do {
        $destinationCountText = Read-Host 'Number of destinations'
        $destinationCount = 0
        if ([int]::TryParse($destinationCountText, [ref]$destinationCount) -and $destinationCount -ge 1) { break }
        Write-Warning 'Enter a whole number of at least 1.'
    } while ($true)

    $destinations = @()
    for ($i = 1; $i -le $destinationCount; $i++) {
        do {
            $destination = Get-DestinationFolder -Source $source -Number $i
            if ($destinations | Where-Object { $_.Equals($destination, [StringComparison]::OrdinalIgnoreCase) }) {
                Write-Warning 'Each destination must be different.'
            } else {
                $destinations += $destination
                break
            }
        } while ($true)
    }

    do {
        Write-Host "`nTransfer type:"
        Write-Host '[1] Copy'
        Write-Host '[2] Move'
        Write-Host '[3] Mirror'
        switch ((Read-Host 'Select').Trim()) {
            '1' { $mode = 'Copy'; break }
            '2' { $mode = 'Move'; break }
            '3' { $mode = 'Mirror'; break }
            default { Write-Warning 'Select 1, 2, or 3.' }
        }
    } while ($true)

    $logPath = $null
    if (Get-YesNo -Prompt 'Save a log file') {
        do {
            $logFolderInput = Read-Host 'Folder in which to save the log'
            try {
                $logFolder = Get-NormalizedPath -Path $logFolderInput
                if (-not (Test-Path -LiteralPath $logFolder)) {
                    if (-not (Get-YesNo -Prompt "Log folder does not exist. Create it: $logFolder")) { continue }
                    New-Item -ItemType Directory -LiteralPath $logFolder -Force | Out-Null
                }
                if (-not (Test-Path -LiteralPath $logFolder -PathType Container)) { throw 'The log location is not a folder.' }
                $logPath = Join-Path $logFolder ("Robocopy-Transfer-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
                break
            } catch {
                Write-Warning "Unable to use that log folder: $($_.Exception.Message)"
            }
        } while ($true)
    }

    Write-Host "`nREADY TO START" -ForegroundColor Yellow
    Write-Host '==============' -ForegroundColor Yellow
    Write-Host "Source:       $source"
    $index = 1; foreach ($destination in $destinations) { Write-Host "Destination ${index}: $destination"; $index++ }
    Write-Host "Operation:    $mode"
    Write-Host 'Subfolders:   Included, including empty folders'
    Write-Host 'Retries:      3, with a 5-second wait'
    Write-Host (if ($logPath) { "Log file:     $logPath" } else { 'Log file:     No' })

    if ($mode -eq 'Mirror') {
        Write-Warning 'MIRROR WARNING: files and folders in each destination that are absent from the source WILL BE DELETED.'
        $mirrorConfirmation = Read-Host 'Type MIRROR to confirm this deletion risk'
        if ($mirrorConfirmation -cne 'MIRROR') { Write-Host 'Cancelled. No transfer was started.'; return }
    }
    if (-not (Get-YesNo -Prompt 'Start transfer')) { Write-Host 'Cancelled. No transfer was started.'; return }

    $robocopyMode = if ($mode -eq 'Mirror') { 'Mirror' } else { 'Copy' }
    $results = @()
    foreach ($destination in $destinations) {
        $code = Invoke-RobocopyTransfer -Source $source -Destination $destination -Mode $robocopyMode -LogPath $logPath
        $results += [pscustomobject]@{ Destination = $destination; ExitCode = $code; Success = ($code -lt 8) }
    }

    $allSucceeded = @($results | Where-Object { -not $_.Success }).Count -eq 0
    if ($mode -eq 'Move' -and $allSucceeded) {
        Write-Host "`nAll destinations received the source. Removing source contents..." -ForegroundColor Yellow
        try {
            Get-ChildItem -LiteralPath $source -Force | Remove-Item -Recurse -Force -ErrorAction Stop
            Write-Host 'Source contents removed. The source folder itself was kept.' -ForegroundColor Green
        } catch {
            Write-Error "Copies succeeded, but source contents could not be fully removed: $($_.Exception.Message)"
        }
    } elseif ($mode -eq 'Move') {
        Write-Warning 'At least one destination failed. Source contents were NOT removed.'
    }

    Write-Host "`nTRANSFER RESULTS" -ForegroundColor Cyan
    Write-Host '================'
    foreach ($result in $results) {
        $color = if ($result.Success) { 'Green' } else { 'Red' }
        Write-Host ("{0}`n  {1}" -f $result.Destination, (Get-RobocopyResultText -ExitCode $result.ExitCode)) -ForegroundColor $color
    }
} catch {
    Write-Error $_.Exception.Message
} finally {
    Pause-BeforeExit
}
