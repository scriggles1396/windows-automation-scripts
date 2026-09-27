<#
.SYNOPSIS
    Removes Mozilla Firefox and common Firefox traces from the local Windows computer.

.DESCRIPTION
    Stops Firefox-related processes, runs registered Firefox uninstallers when available,
    removes the Mozilla Maintenance Service, deletes common Firefox program, profile, cache,
    crash-report, update, shortcut, scheduled-task, and registry locations.

    Use -WhatIf first to review the actions before allowing removal.

.AUTHOR
    scriggles1396

.VERSION
    1.0.0

.LAST UPDATED
    2026-09-22

.AI ASSISTANCE
    AI-assisted:
    Portions of this script and/or its documentation were created with assistance from
    ChatGPT by OpenAI. The output should be reviewed and tested by a human before publication
    or production use.

.REQUIREMENTS
    - Windows 10 or Windows 11
    - Windows PowerShell 5.1 or later
    - Administrator privileges

.PARAMETER IncludeAllUsers
    Attempts to remove Firefox profile and cache data from every local user profile.
    Without this switch, only the current user's profile data is removed.

.PARAMETER SkipUninstaller
    Skips registered Firefox uninstallers and removes files/registry entries directly.

.PARAMETER NoRestart
    Does not prompt to restart after removal.

.EXAMPLE
    PS> .\Remove-Firefox-Traces.ps1 -IncludeAllUsers -WhatIf
    Shows what would be removed without deleting anything.

.EXAMPLE
    PS> .\Remove-Firefox-Traces.ps1 -IncludeAllUsers
    Removes Firefox and common traces for all local users.

.OUTPUTS
    Console output describing completed and failed removal actions.

.SAFETY
    This script deletes browser applications, profiles, bookmarks, passwords, extensions,
    cache, crash reports, update data, shortcuts, scheduled tasks, and related registry keys.
    Back up Firefox profile data before use if anything may be needed later.

.LICENSE
    MIT License. See the repository LICENSE file.

.NOTES
    "All traces" cannot be guaranteed because third-party tools, backups, sync providers,
    restore points, forensic artefacts, prefetch files, jump lists, DNS caches, and security
    products may retain separate records. This script targets common Firefox-owned locations.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [switch]$IncludeAllUsers,
    [switch]$SkipUninstaller,
    [switch]$NoRestart
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

function Test-IsAdministrator {
    $CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentIdentity)
    return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-Removal {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Target,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Action
    )

    if ($PSCmdlet.ShouldProcess($Target, 'Remove Firefox trace')) {
        try {
            & $Action
            Write-Host "Removed: $Target"
        }
        catch {
            Write-Warning "Failed: $Target - $($_.Exception.Message)"
        }
    }
}

function Remove-PathIfPresent {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (Test-Path -LiteralPath $Path) {
        Invoke-Removal -Target $Path -Action {
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        }
    }
}

function Remove-RegistryKeyIfPresent {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (Test-Path -LiteralPath $Path) {
        Invoke-Removal -Target $Path -Action {
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        }
    }
}

function Stop-FirefoxProcesses {
    $ProcessNames = @(
        'firefox',
        'maintenanceservice',
        'plugin-container',
        'pingsender'
    )

    foreach ($ProcessName in $ProcessNames) {
        Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | ForEach-Object {
            $Process = $_
            Invoke-Removal -Target "Process $($Process.ProcessName) ($($Process.Id))" -Action {
                Stop-Process -Id $Process.Id -Force -ErrorAction Stop
            }
        }
    }
}

function Get-FirefoxUninstallEntries {
    $UninstallRoots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    )

    foreach ($Root in $UninstallRoots) {
        if (-not (Test-Path -LiteralPath $Root)) { continue }

        Get-ChildItem -LiteralPath $Root -ErrorAction SilentlyContinue | ForEach-Object {
            $Item = $_
            try {
                $Properties = Get-ItemProperty -LiteralPath $Item.PSPath -ErrorAction Stop
                if ($Properties.DisplayName -match 'Mozilla Firefox') {
                    [PSCustomObject]@{
                        DisplayName     = $Properties.DisplayName
                        QuietUninstall  = $Properties.QuietUninstallString
                        UninstallString = $Properties.UninstallString
                    }
                }
            }
            catch {
                Write-Warning "Could not inspect uninstall key $($Item.Name): $($_.Exception.Message)"
            }
        }
    }
}

function Invoke-FirefoxUninstallers {
    $Entries = @(Get-FirefoxUninstallEntries)

    foreach ($Entry in $Entries) {
        $Command = $Entry.QuietUninstall
        if ([string]::IsNullOrWhiteSpace($Command)) {
            $Command = $Entry.UninstallString
        }

        if ([string]::IsNullOrWhiteSpace($Command)) { continue }

        if ($Command -notmatch '(?i)(/S|/quiet|/qn)') {
            $Command = "$Command /S"
        }

        Invoke-Removal -Target "Uninstaller for $($Entry.DisplayName)" -Action {
            Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" `
                -ArgumentList '/c', $Command `
                -Wait `
                -WindowStyle Hidden `
                -ErrorAction Stop
        }
    }
}

function Remove-FirefoxServices {
    $ServiceNames = @('MozillaMaintenance')

    foreach ($ServiceName in $ServiceNames) {
        $Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($null -eq $Service) { continue }

        Invoke-Removal -Target "Service $ServiceName" -Action {
            if ($Service.Status -ne 'Stopped') {
                Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
            }

            & "$env:SystemRoot\System32\sc.exe" delete $ServiceName | Out-Null
        }
    }
}

function Remove-FirefoxScheduledTasks {
    Get-ScheduledTask -ErrorAction SilentlyContinue |
        Where-Object {
            $_.TaskName -match 'Firefox|Mozilla' -or $_.TaskPath -match 'Firefox|Mozilla'
        } |
        ForEach-Object {
            $Task = $_
            Invoke-Removal -Target "Scheduled task $($Task.TaskPath)$($Task.TaskName)" -Action {
                Unregister-ScheduledTask -TaskName $Task.TaskName -TaskPath $Task.TaskPath -Confirm:$false -ErrorAction Stop
            }
        }
}

function Get-TargetUserProfilePaths {
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

if (-not (Test-IsAdministrator)) {
    Write-Error 'Administrator privileges are required. Open PowerShell as Administrator and run this script again.'
    exit 1
}

Write-Host '============================================================'
Write-Host ' Firefox Removal'
Write-Host '============================================================'
Write-Host 'Use -WhatIf first if you have not already reviewed the removal targets.'
Write-Host ''

Stop-FirefoxProcesses

if (-not $SkipUninstaller) {
    Invoke-FirefoxUninstallers
}

Remove-FirefoxServices
Remove-FirefoxScheduledTasks

$MachinePaths = @(
    "$env:ProgramFiles\Mozilla Firefox",
    "${env:ProgramFiles(x86)}\Mozilla Firefox",
    "$env:ProgramFiles\Mozilla Maintenance Service",
    "${env:ProgramFiles(x86)}\Mozilla Maintenance Service",
    "$env:ProgramData\Mozilla",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Firefox.lnk",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Mozilla Firefox.lnk",
    "$env:PUBLIC\Desktop\Firefox.lnk",
    "$env:PUBLIC\Desktop\Mozilla Firefox.lnk"
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

foreach ($Path in $MachinePaths) {
    Remove-PathIfPresent -Path $Path
}

foreach ($UserProfile in Get-TargetUserProfilePaths) {
    $UserPaths = @(
        "$UserProfile\AppData\Roaming\Mozilla\Firefox",
        "$UserProfile\AppData\Roaming\Mozilla\Extensions",
        "$UserProfile\AppData\Roaming\Mozilla\SystemExtensions",
        "$UserProfile\AppData\Roaming\Mozilla\updates",
        "$UserProfile\AppData\Local\Mozilla\Firefox",
        "$UserProfile\AppData\Local\Mozilla\updates",
        "$UserProfile\AppData\Local\Mozilla\Crash Reports",
        "$UserProfile\AppData\LocalLow\Mozilla",
        "$UserProfile\Desktop\Firefox.lnk",
        "$UserProfile\Desktop\Mozilla Firefox.lnk",
        "$UserProfile\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Firefox.lnk",
        "$UserProfile\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Mozilla Firefox.lnk",
        "$UserProfile\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Firefox.lnk",
        "$UserProfile\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Mozilla Firefox.lnk"
    )

    foreach ($Path in $UserPaths) {
        Remove-PathIfPresent -Path $Path
    }
}

$RegistryKeys = @(
    'HKCU:\Software\Mozilla',
    'HKCU:\Software\MozillaPlugins',
    'HKLM:\Software\Mozilla',
    'HKLM:\Software\MozillaPlugins',
    'HKLM:\Software\WOW6432Node\Mozilla',
    'HKLM:\Software\WOW6432Node\MozillaPlugins',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\firefox.exe',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\firefox.exe',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\firefox.exe'
)

foreach ($RegistryKey in $RegistryKeys) {
    Remove-RegistryKeyIfPresent -Path $RegistryKey
}

Write-Host ''
Write-Host '============================================================'
Write-Host ' Firefox Removal Complete'
Write-Host '============================================================'
Write-Host 'Review warnings above. Restart Windows before checking final state.'

if (-not $NoRestart) {
    Write-Host 'No automatic restart was performed.'
}
