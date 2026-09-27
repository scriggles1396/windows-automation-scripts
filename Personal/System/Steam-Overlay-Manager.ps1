<#
.SYNOPSIS
    Enables, disables, or reports the global Steam Overlay setting for local Steam users.

.DESCRIPTION
    Locates the Steam installation, finds Steam userdata localconfig.vdf files, and manages
    the EnableGameOverlay setting for each detected Steam account.

    The script closes Steam before editing configuration, backs up every modified
    localconfig.vdf file, preserves unrelated Steam configuration content, and can restart
    Steam when finished.

.AUTHOR
    scriggles1396

.VERSION
    1.0.0

.LAST UPDATED
    2026-09-27

.AI ASSISTANCE
    AI-assisted:
    Portions of this script and/or its documentation were created with assistance from
    ChatGPT by OpenAI. The output should be reviewed and tested by a human before publication
    or production use.

.REQUIREMENTS
    - Windows 10 or Windows 11
    - Windows PowerShell 5.1 or later
    - Steam installed locally

.EXAMPLE
    PS> .\Steam-Overlay-Manager.ps1
    Starts the interactive Steam Overlay Manager menu.

.OUTPUTS
    Console output showing detected Steam users, overlay status, backups, and changes.

.SAFETY
    Disabling Steam Overlay can disable Steam-dependent in-game features, including overlay
    interfaces, screenshots, invites, controller overlays, and some in-game purchasing flows.

    Backups are created next to each edited localconfig.vdf before changes are written.

.LICENSE
    MIT License. See the repository LICENSE file.

.NOTES
    Steam stores this setting in user configuration under:
    Steam\userdata\<SteamID>\config\localconfig.vdf
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-SteamInstallPath {
    $CandidatePaths = New-Object System.Collections.Generic.List[string]

    $RegistryPaths = @(
        'HKCU:\Software\Valve\Steam',
        'HKLM:\Software\Valve\Steam',
        'HKLM:\Software\WOW6432Node\Valve\Steam'
    )

    foreach ($RegistryPath in $RegistryPaths) {
        try {
            if (Test-Path -LiteralPath $RegistryPath) {
                $Properties = Get-ItemProperty -LiteralPath $RegistryPath -ErrorAction Stop
                foreach ($PropertyName in @('SteamPath', 'InstallPath')) {
                    if ($Properties.PSObject.Properties.Name -contains $PropertyName) {
                        $Path = [string]$Properties.$PropertyName
                        if (-not [string]::IsNullOrWhiteSpace($Path)) {
                            $CandidatePaths.Add($Path)
                        }
                    }
                }
            }
        }
        catch {
            Write-Warning "Could not read ${RegistryPath}: $($_.Exception.Message)"
        }
    }

    $DefaultPaths = @(
        "$env:ProgramFiles(x86)\Steam",
        "$env:ProgramFiles\Steam"
    )

    foreach ($Path in $DefaultPaths) {
        if (-not [string]::IsNullOrWhiteSpace($Path)) {
            $CandidatePaths.Add($Path)
        }
    }

    foreach ($CandidatePath in ($CandidatePaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)) {
        $ResolvedPath = $CandidatePath -replace '/', '\'
        if ((Test-Path -LiteralPath $ResolvedPath) -and
            (Test-Path -LiteralPath (Join-Path $ResolvedPath 'userdata'))) {
            return $ResolvedPath
        }
    }

    return $null
}

function Get-SteamExecutablePath {
    param([Parameter(Mandatory = $true)][string]$SteamPath)

    $SteamExe = Join-Path $SteamPath 'steam.exe'
    if (Test-Path -LiteralPath $SteamExe) {
        return $SteamExe
    }

    return $null
}

function Get-LocalConfigFiles {
    param([Parameter(Mandatory = $true)][string]$SteamPath)

    $UserDataPath = Join-Path $SteamPath 'userdata'
    if (-not (Test-Path -LiteralPath $UserDataPath)) {
        return @()
    }

    Get-ChildItem -LiteralPath $UserDataPath -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d+$' } |
        ForEach-Object {
            $ConfigPath = Join-Path $_.FullName 'config\localconfig.vdf'
            [PSCustomObject]@{
                SteamId    = $_.Name
                ConfigPath = $ConfigPath
                Exists     = Test-Path -LiteralPath $ConfigPath
            }
        }
}

function Get-OverlayStatus {
    param([Parameter(Mandatory = $true)][string]$ConfigPath)

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        return 'Missing localconfig.vdf'
    }

    try {
        $Content = Get-Content -LiteralPath $ConfigPath -Raw -ErrorAction Stop
        $Match = [regex]::Match($Content, '(?m)^\s*"EnableGameOverlay"\s+"(?<Value>[01])"\s*$')

        if (-not $Match.Success) {
            return 'Not set'
        }

        if ($Match.Groups['Value'].Value -eq '1') {
            return 'Enabled'
        }

        return 'Disabled'
    }
    catch {
        return "Unreadable: $($_.Exception.Message)"
    }
}

function Stop-Steam {
    $Processes = @(Get-Process -Name 'steam', 'steamwebhelper' -ErrorAction SilentlyContinue)

    if ($Processes.Count -eq 0) {
        return
    }

    Write-Host ''
    Write-Host 'Steam must be fully closed before configuration changes.'
    $Answer = Read-Host 'Close Steam now? [Y/N]'
    if ($Answer -notmatch '^(?i)y(?:es)?$') {
        throw 'Steam is still running. No changes were made.'
    }

    foreach ($Process in $Processes) {
        try {
            Stop-Process -Id $Process.Id -Force -ErrorAction Stop
        }
        catch {
            Write-Warning "Could not stop $($Process.ProcessName) ($($Process.Id)): $($_.Exception.Message)"
        }
    }

    Start-Sleep -Seconds 3
}

function Backup-LocalConfig {
    param([Parameter(Mandatory = $true)][string]$ConfigPath)

    $Timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $BackupPath = "$ConfigPath.backup-$Timestamp"
    Copy-Item -LiteralPath $ConfigPath -Destination $BackupPath -Force -ErrorAction Stop
    return $BackupPath
}

function Set-OverlaySetting {
    param(
        [Parameter(Mandatory = $true)][string]$ConfigPath,
        [Parameter(Mandatory = $true)][ValidateSet('0', '1')][string]$Value
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Missing localconfig.vdf: $ConfigPath"
    }

    $OriginalContent = Get-Content -LiteralPath $ConfigPath -Raw -ErrorAction Stop
    $Pattern = '(?m)^(\s*"EnableGameOverlay"\s+")([01])("\s*)$'

    if ($OriginalContent -match $Pattern) {
        $NewContent = [regex]::Replace($OriginalContent, $Pattern, "`${1}$Value`${3}", 1)
    }
    else {
        $NewLine = "`t`t`"EnableGameOverlay`"`t`t`"$Value`""
        $FriendsPattern = '(?m)^(\s*"Friends"\s*\r?\n\s*\{\s*\r?\n)'

        if ($OriginalContent -match $FriendsPattern) {
            $NewContent = [regex]::Replace($OriginalContent, $FriendsPattern, "`${1}$NewLine`r`n", 1)
        }
        else {
            $NewContent = $OriginalContent.TrimEnd() + "`r`n`"Friends`"`r`n{`r`n$NewLine`r`n}`r`n"
        }
    }

    if ($NewContent -eq $OriginalContent) {
        return [PSCustomObject]@{
            Changed    = $false
            BackupPath = $null
        }
    }

    $BackupPath = Backup-LocalConfig -ConfigPath $ConfigPath
    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($ConfigPath, $NewContent, $Utf8NoBom)

    return [PSCustomObject]@{
        Changed    = $true
        BackupPath = $BackupPath
    }
}

function Show-CurrentStatus {
    param([Parameter(Mandatory = $true)][array]$Configs)

    Write-Host ''
    Write-Host 'Current Steam Overlay status:'
    Write-Host ''

    foreach ($Config in $Configs) {
        $Status = if ($Config.Exists) {
            Get-OverlayStatus -ConfigPath $Config.ConfigPath
        }
        else {
            'Missing localconfig.vdf'
        }

        Write-Host "SteamID $($Config.SteamId): $Status"
        Write-Host "  $($Config.ConfigPath)"
    }
}

function Set-OverlayForAllUsers {
    param(
        [Parameter(Mandatory = $true)][array]$Configs,
        [Parameter(Mandatory = $true)][ValidateSet('0', '1')][string]$Value
    )

    Stop-Steam

    foreach ($Config in ($Configs | Where-Object { $_.Exists })) {
        try {
            $Before = Get-OverlayStatus -ConfigPath $Config.ConfigPath
            $Result = Set-OverlaySetting -ConfigPath $Config.ConfigPath -Value $Value
            $After = Get-OverlayStatus -ConfigPath $Config.ConfigPath

            Write-Host ''
            Write-Host "SteamID $($Config.SteamId): $Before -> $After"

            if ($Result.Changed) {
                Write-Host "Backup: $($Result.BackupPath)"
            }
            else {
                Write-Host 'No change needed.'
            }
        }
        catch {
            Write-Warning "Failed SteamID $($Config.SteamId): $($_.Exception.Message)"
        }
    }
}

function Restart-SteamIfWanted {
    param([string]$SteamExe)

    if ([string]::IsNullOrWhiteSpace($SteamExe)) {
        return
    }

    $Answer = Read-Host 'Restart Steam now? [Y/N]'
    if ($Answer -match '^(?i)y(?:es)?$') {
        Start-Process -FilePath $SteamExe
    }
}

function Show-Menu {
    Clear-Host
    Write-Host '================================'
    Write-Host ' Steam Overlay Manager'
    Write-Host '================================'
    Write-Host ''
    Write-Host '[1] Disable Steam Overlay'
    Write-Host '[2] Enable Steam Overlay'
    Write-Host '[3] Show Current Status'
    Write-Host '[4] Exit'
    Write-Host ''
}

$SteamPath = Get-SteamInstallPath
if ([string]::IsNullOrWhiteSpace($SteamPath)) {
    Write-Error 'Could not locate Steam. Install Steam or check the Steam registry/install path.'
    exit 1
}

$SteamExe = Get-SteamExecutablePath -SteamPath $SteamPath
$Configs = @(Get-LocalConfigFiles -SteamPath $SteamPath)

if ($Configs.Count -eq 0) {
    Write-Error "No Steam userdata directories were found under: $(Join-Path $SteamPath 'userdata')"
    exit 1
}

:MenuLoop while ($true) {
    Show-Menu
    Write-Host "Steam path: $SteamPath"
    Write-Host "Accounts:   $($Configs.Count)"
    Write-Host ''

    $Choice = Read-Host 'Select an option'

    switch ($Choice) {
        '1' {
            Set-OverlayForAllUsers -Configs $Configs -Value '0'
            Restart-SteamIfWanted -SteamExe $SteamExe
            Read-Host 'Press Enter to continue'
        }
        '2' {
            Set-OverlayForAllUsers -Configs $Configs -Value '1'
            Restart-SteamIfWanted -SteamExe $SteamExe
            Read-Host 'Press Enter to continue'
        }
        '3' {
            Show-CurrentStatus -Configs $Configs
            Read-Host 'Press Enter to continue'
        }
        '4' {
            break MenuLoop
        }
        default {
            Write-Host 'Invalid option.'
            Start-Sleep -Seconds 1
        }
    }
}
