<#
.SYNOPSIS
    Cleans common Windows temporary files and runs safe Windows image/component-store maintenance.

.DESCRIPTION
    Removes files from common Windows temp, update cache, delivery optimization cache, thumbnail
    cache, Windows Error Reporting, CBS/DISM log archive, and per-user temp/cache folders.

    It also analyzes the Windows component store and can run DISM StartComponentCleanup when
    recommended or explicitly requested.

    Use -WhatIf first to review delete targets before allowing cleanup.

.AUTHOR
    scriggles1396

.VERSION
    1.0.0

.LAST UPDATED
    2026-09-26

.AI ASSISTANCE
    AI-assisted:
    Portions of this script and/or its documentation were created with assistance from
    ChatGPT by OpenAI. The output should be reviewed and tested by a human before publication
    or production use.

.REQUIREMENTS
    - Windows 10, Windows 11, or Windows Server
    - Windows PowerShell 5.1 or later
    - Administrator privileges
    - Built-in DISM.exe

.PARAMETER IncludeAllUsers
    Cleans temp/cache folders under every local user profile. Without this switch, only the
    current user's temp/cache folders are cleaned.

.PARAMETER ComponentCleanup
    Runs DISM /Online /Cleanup-Image /StartComponentCleanup after analysis.

.PARAMETER ComponentCleanupIfRecommended
    Runs DISM /StartComponentCleanup only when DISM analysis says component store cleanup is
    recommended. This is the default when no component cleanup mode is specified.

.PARAMETER ResetBase
    Runs DISM /StartComponentCleanup /ResetBase. This can save more space, but permanently
    removes the ability to uninstall currently installed Windows updates.

.PARAMETER ClearRecycleBin
    Clears the recycle bin for all drives.

.PARAMETER Aggressive
    Adds extra cleanup locations that are usually safe but more disruptive, such as old Windows
    upgrade leftovers and memory dump files.

.PARAMETER LogPath
    File path for the transcript log. Defaults to the user's Desktop.

.EXAMPLE
    PS> .\Invoke-WindowsMaintenanceCleanup.ps1 -WhatIf
    Shows cleanup targets without deleting files or running DISM cleanup.

.EXAMPLE
    PS> .\Invoke-WindowsMaintenanceCleanup.ps1 -IncludeAllUsers -ComponentCleanup
    Cleans common temp locations for all users and runs DISM component cleanup.

.EXAMPLE
    PS> .\Invoke-WindowsMaintenanceCleanup.ps1 -Aggressive -ClearRecycleBin
    Includes extra cleanup targets and empties the recycle bin.

.OUTPUTS
    Console output and a transcript log containing cleanup actions, DISM output, and warnings.

.SAFETY
    This script deletes temporary files, caches, logs, crash dumps, and optional recycle-bin
    contents. It does not delete user documents, photos, downloads, desktop files, or browser
    profiles.

    The -ResetBase option is irreversible for currently installed Windows updates.

.LICENSE
    MIT License. See the repository LICENSE file.

.NOTES
    Some files will be locked by running services and skipped. This is normal.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [switch]$IncludeAllUsers,
    [switch]$ComponentCleanup,
    [switch]$ComponentCleanupIfRecommended,
    [switch]$ResetBase,
    [switch]$ClearRecycleBin,
    [switch]$Aggressive,
    [string]$LogPath = "$env:USERPROFILE\Desktop\WindowsMaintenanceCleanup_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

function Test-IsAdministrator {
    $CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentIdentity)
    return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-FriendlySize {
    param([long]$Bytes)

    if ($Bytes -ge 1GB) { return '{0:N2} GB' -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return '{0:N2} MB' -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return '{0:N2} KB' -f ($Bytes / 1KB) }
    return "$Bytes bytes"
}

function Get-DirectorySize {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return 0 }

    try {
        $Total = 0
        Get-ChildItem -LiteralPath $Path -Force -Recurse -ErrorAction SilentlyContinue |
            Where-Object { -not $_.PSIsContainer } |
            ForEach-Object { $Total += $_.Length }
        return $Total
    }
    catch {
        Write-Warning "Could not calculate size for ${Path}: $($_.Exception.Message)"
        return 0
    }
}

function Clear-FolderContents {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path)) { return }

    $BeforeBytes = Get-DirectorySize -Path $Path

    if ($PSCmdlet.ShouldProcess($Path, "Clean $Label")) {
        Write-Host "Cleaning: $Label"
        Write-Host "Path:     $Path"
        Write-Host "Before:   $(Get-FriendlySize -Bytes $BeforeBytes)"

        try {
            Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
        catch {
            Write-Warning "Cleanup had errors for ${Path}: $($_.Exception.Message)"
        }

        $AfterBytes = Get-DirectorySize -Path $Path
        $SavedBytes = [math]::Max(0, $BeforeBytes - $AfterBytes)
        Write-Host "After:    $(Get-FriendlySize -Bytes $AfterBytes)"
        Write-Host "Saved:    $(Get-FriendlySize -Bytes $SavedBytes)"
        Write-Host ''
    }
}

function Get-TargetUserProfiles {
    if ($IncludeAllUsers) {
        Get-ChildItem -LiteralPath 'C:\Users' -Directory -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -notin @('All Users', 'Default', 'Default User', 'Public') -and
                $_.Attributes -notmatch 'ReparsePoint'
            } |
            Select-Object -ExpandProperty FullName
    }
    else {
        @($env:USERPROFILE)
    }
}

function Invoke-Dism {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $DismPath = Join-Path $env:SystemRoot 'System32\dism.exe'
    if (-not (Test-Path -LiteralPath $DismPath)) {
        Write-Warning 'DISM.exe was not found.'
        return $null
    }

    Write-Host "Running: DISM $($Arguments -join ' ')"
    $Output = & $DismPath @Arguments 2>&1
    $ExitCode = $LASTEXITCODE
    $Output | ForEach-Object { Write-Host $_ }

    if ($ExitCode -ne 0) {
        Write-Warning "DISM returned exit code $ExitCode."
    }

    return [PSCustomObject]@{
        ExitCode = $ExitCode
        Output   = ($Output | Out-String)
    }
}

if (-not (Test-IsAdministrator)) {
    Write-Error 'Administrator privileges are required. Open PowerShell as Administrator and run this script again.'
    exit 1
}

if ($ResetBase -and -not $ComponentCleanup) {
    $ComponentCleanup = $true
}

if (-not $ComponentCleanup -and -not $ComponentCleanupIfRecommended) {
    $ComponentCleanupIfRecommended = $true
}

try {
    $LogDirectory = Split-Path -Path $LogPath -Parent
    if ($LogDirectory -and -not (Test-Path -LiteralPath $LogDirectory)) {
        New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
    }

    Start-Transcript -Path $LogPath -Force | Out-Null
}
catch {
    Write-Warning "Could not start transcript: $($_.Exception.Message)"
}

Write-Host '============================================================'
Write-Host ' Windows Maintenance Cleanup'
Write-Host '============================================================'
Write-Host "Log: $LogPath"
Write-Host ''

$CleanupTargets = @(
    @{ Label = 'Windows temp'; Path = "$env:SystemRoot\Temp" },
    @{ Label = 'Windows update download cache'; Path = "$env:SystemRoot\SoftwareDistribution\Download" },
    @{ Label = 'Delivery Optimization cache'; Path = "$env:SystemRoot\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache" },
    @{ Label = 'Windows Error Reporting archive'; Path = "$env:ProgramData\Microsoft\Windows\WER\ReportArchive" },
    @{ Label = 'Windows Error Reporting queue'; Path = "$env:ProgramData\Microsoft\Windows\WER\ReportQueue" },
    @{ Label = 'CBS compressed log archives'; Path = "$env:SystemRoot\Logs\CBS" },
    @{ Label = 'DISM log archives'; Path = "$env:SystemRoot\Logs\DISM" }
)

if ($Aggressive) {
    $CleanupTargets += @(
        @{ Label = 'Windows old upgrade folder'; Path = "$env:SystemDrive\Windows.old" },
        @{ Label = 'Windows upgrade temporary files'; Path = "$env:SystemDrive\`$WINDOWS.~BT" },
        @{ Label = 'Windows setup temporary files'; Path = "$env:SystemDrive\`$WINDOWS.~WS" },
        @{ Label = 'System memory dump'; Path = "$env:SystemRoot\MEMORY.DMP" },
        @{ Label = 'Minidump files'; Path = "$env:SystemRoot\Minidump" }
    )
}

foreach ($Target in $CleanupTargets) {
    Clear-FolderContents -Path $Target.Path -Label $Target.Label
}

foreach ($UserProfile in Get-TargetUserProfiles) {
    $UserTargets = @(
        @{ Label = "User temp for $UserProfile"; Path = "$UserProfile\AppData\Local\Temp" },
        @{ Label = "Thumbnail cache for $UserProfile"; Path = "$UserProfile\AppData\Local\Microsoft\Windows\Explorer" },
        @{ Label = "Crash dump cache for $UserProfile"; Path = "$UserProfile\AppData\Local\CrashDumps" },
        @{ Label = "WER cache for $UserProfile"; Path = "$UserProfile\AppData\Local\Microsoft\Windows\WER" }
    )

    foreach ($Target in $UserTargets) {
        Clear-FolderContents -Path $Target.Path -Label $Target.Label
    }
}

if ($ClearRecycleBin) {
    if ($PSCmdlet.ShouldProcess('Recycle Bin', 'Clear all recycle-bin contents')) {
        try {
            Clear-RecycleBin -Force -ErrorAction Stop
            Write-Host 'Recycle Bin cleared.'
        }
        catch {
            Write-Warning "Could not clear Recycle Bin: $($_.Exception.Message)"
        }
    }
}

Write-Host ''
Write-Host 'Analyzing Windows component store...'
$AnalyzeResult = Invoke-Dism -Arguments @('/Online', '/Cleanup-Image', '/AnalyzeComponentStore')
$CleanupRecommended = $false

if ($AnalyzeResult -and $AnalyzeResult.Output -match '(?im)Component Store Cleanup Recommended\s*:\s*Yes') {
    $CleanupRecommended = $true
}

if ($ComponentCleanup -or ($ComponentCleanupIfRecommended -and $CleanupRecommended)) {
    $DismArguments = @('/Online', '/Cleanup-Image', '/StartComponentCleanup')
    if ($ResetBase) {
        $DismArguments += '/ResetBase'
    }

    if ($PSCmdlet.ShouldProcess('Windows component store', "DISM $($DismArguments -join ' ')")) {
        Invoke-Dism -Arguments $DismArguments | Out-Null
    }
}
else {
    Write-Host 'Component cleanup skipped because DISM did not recommend it.'
}

Write-Host ''
Write-Host '============================================================'
Write-Host ' Cleanup Complete'
Write-Host '============================================================'
Write-Host 'Restart Windows before measuring final free space.'

try {
    Stop-Transcript | Out-Null
}
catch {}
