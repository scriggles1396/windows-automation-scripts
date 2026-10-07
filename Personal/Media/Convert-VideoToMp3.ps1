<#
.SYNOPSIS
    Converts local video files to MP3 audio on Windows.

.DESCRIPTION
    Converts one video file or a folder of video files to MP3 using FFmpeg. When no input path
    is supplied, the script opens a simple menu for single-file or whole-folder conversion.
    If FFmpeg is not found, the script attempts to install it with Windows Package Manager
    (winget).

    The script is designed for Windows desktop use, supports -WhatIf, avoids overwriting
    existing MP3 files unless requested, and saves MP3 files to Music\YouTube by default.

.AUTHOR
    scriggles1396

.VERSION
    1.0.0

.LAST UPDATED
    2026-10-05

.AI ASSISTANCE
    AI-assisted:
    Portions of this script and/or its documentation were created with assistance from
    ChatGPT by OpenAI. The output should be reviewed and tested by a human before publication
    or production use.

.REQUIREMENTS
    - Windows 10 or Windows 11
    - Windows PowerShell 5.1 or later
    - FFmpeg, installed automatically with winget if missing

.PARAMETER Path
    Video file or folder to convert. If omitted, the script prompts for single-file or
    whole-folder mode.

.PARAMETER OutputFolder
    Folder where MP3 files are saved. Defaults to the current user's Music\YouTube folder.

.PARAMETER Recurse
    Converts supported video files inside child folders.

.PARAMETER Bitrate
    MP3 audio bitrate. Defaults to 192k.

.PARAMETER Overwrite
    Replaces existing MP3 files.

.EXAMPLE
    PS> .\Convert-VideoToMp3.ps1 -Path "D:\Videos\clip.mp4"
    Converts clip.mp4 to Music\YouTube\clip.mp3.

.EXAMPLE
    PS> .\Convert-VideoToMp3.ps1 -Path "D:\Videos" -Recurse -Bitrate 256k
    Converts supported video files under D:\Videos to MP3 at 256 kbps, saved in Music\YouTube.

.EXAMPLE
    PS> .\Convert-VideoToMp3.ps1 -Path "D:\Videos" -WhatIf
    Shows what would be installed or converted without changing files.

.OUTPUTS
    MP3 files and console conversion status.

.SAFETY
    This script reads source video files and creates MP3 copies. It does not delete source
    videos. Use -Overwrite only when replacing existing MP3 files is intended.

.LICENSE
    MIT License. See the repository LICENSE file.

.NOTES
    Supported input extensions are listed in $VideoExtensions inside the script.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$Path,

    [string]$OutputFolder,

    [switch]$Recurse,

    [ValidatePattern('^\d+k$')]
    [string]$Bitrate = '192k',

    [switch]$Overwrite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$VideoExtensions = @(
    '.3g2',
    '.3gp',
    '.avi',
    '.flv',
    '.m4v',
    '.mkv',
    '.mov',
    '.mp4',
    '.mpeg',
    '.mpg',
    '.ts',
    '.webm',
    '.wmv'
)

function Find-Program {
    param([Parameter(Mandatory = $true)][string]$ProgramName)

    $Command = Get-Command $ProgramName -ErrorAction SilentlyContinue
    if ($Command -and $Command.Source) {
        return $Command.Source
    }

    $WingetLink = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links\$ProgramName"
    if (Test-Path -LiteralPath $WingetLink) {
        return $WingetLink
    }

    $WingetPackages = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    if (Test-Path -LiteralPath $WingetPackages) {
        $Found = Get-ChildItem -LiteralPath $WingetPackages -Filter $ProgramName -File -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($Found) {
            return $Found.FullName
        }
    }

    return $null
}

function Test-IsAdministrator {
    $CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentIdentity)
    return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-WingetInstall {
    param(
        [Parameter(Mandatory = $true)][string]$PackageId,
        [Parameter(Mandatory = $true)][string]$DisplayName
    )

    $Winget = Find-Program -ProgramName 'winget.exe'
    if (-not $Winget) {
        throw "$DisplayName was not found and winget.exe is not available. Install $DisplayName manually, then run this script again."
    }

    $Arguments = @(
        'install',
        '--id', $PackageId,
        '--exact',
        '--source', 'winget',
        '--accept-package-agreements',
        '--accept-source-agreements'
    )

    Write-Host "$DisplayName not found. Installing with winget..."
    & $Winget @Arguments
    if ($LASTEXITCODE -eq 0) {
        return
    }

    if (Test-IsAdministrator) {
        throw "winget failed to install $DisplayName. Exit code: $LASTEXITCODE"
    }

    Write-Host ''
    Write-Host "winget could not install $DisplayName without elevation."
    $Answer = Read-Host 'Open an Administrator install prompt now? (Y/N)'
    if ($Answer -notmatch '^[Yy]') {
        throw "$DisplayName installation was cancelled."
    }

    $ElevatedCommand = "& `"$Winget`" $($Arguments -join ' '); Write-Host ''; Read-Host 'Press Enter to close'"
    Start-Process -FilePath 'powershell.exe' `
        -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $ElevatedCommand `
        -Verb RunAs `
        -Wait
}

function Install-FfmpegWithWinget {
    if ($PSCmdlet.ShouldProcess('Gyan.FFmpeg', 'Install FFmpeg with winget')) {
        Invoke-WingetInstall -PackageId 'Gyan.FFmpeg' -DisplayName 'FFmpeg'
    }
}

function Get-FfmpegPath {
    $Ffmpeg = Find-Program -ProgramName 'ffmpeg.exe'
    if ($Ffmpeg) {
        return $Ffmpeg
    }

    Install-FfmpegWithWinget

    $Ffmpeg = Find-Program -ProgramName 'ffmpeg.exe'
    if ($Ffmpeg) {
        return $Ffmpeg
    }

    throw 'FFmpeg install completed, but ffmpeg.exe was not found. Open a new PowerShell window or add FFmpeg to PATH.'
}

function Get-VideoFiles {
    param([Parameter(Mandatory = $true)][string]$InputPath)

    $ResolvedPath = Resolve-Path -LiteralPath $InputPath -ErrorAction Stop
    $Item = Get-Item -LiteralPath $ResolvedPath.ProviderPath -ErrorAction Stop

    if (-not $Item.PSIsContainer) {
        if ($VideoExtensions -notcontains $Item.Extension.ToLowerInvariant()) {
            throw "Unsupported video file extension: $($Item.Extension)"
        }

        return @($Item)
    }

    $ChildParams = @{
        LiteralPath = $Item.FullName
        File        = $true
        ErrorAction = 'SilentlyContinue'
    }

    if ($Recurse) {
        $ChildParams.Recurse = $true
    }

    return @(
        Get-ChildItem @ChildParams |
            Where-Object { $VideoExtensions -contains $_.Extension.ToLowerInvariant() } |
            Sort-Object FullName
    )
}

function Get-DefaultOutputFolder {
    $MusicFolder = [Environment]::GetFolderPath('MyMusic')

    if ([string]::IsNullOrWhiteSpace($MusicFolder)) {
        $MusicFolder = Join-Path $env:USERPROFILE 'Music'
    }

    return Join-Path $MusicFolder 'YouTube'
}

function Read-InputPath {
    Write-Host '========================================'
    Write-Host ' Video to MP3 Converter'
    Write-Host '========================================'
    Write-Host ''
    Write-Host '1. Convert a single video file'
    Write-Host '2. Convert every supported video in a folder'
    Write-Host ''

    $Choice = Read-Host 'Select 1 or 2'

    switch ($Choice) {
        '1' {
            $Script:Recurse = $false
            return Read-Host 'Enter full path to the video file'
        }
        '2' {
            $FolderPath = Read-Host 'Enter full path to the folder'
            $RecursiveChoice = Read-Host 'Include subfolders? (Y/N)'
            if ($RecursiveChoice -match '^[Yy]') {
                $Script:Recurse = $true
            }
            return $FolderPath
        }
        default {
            throw 'Invalid selection. Choose 1 or 2.'
        }
    }
}

function Normalize-InputPath {
    param([string]$InputPath)

    if ([string]::IsNullOrWhiteSpace($InputPath)) {
        return $InputPath
    }

    return $InputPath.Trim().Trim('"').Trim("'")
}

function Get-SafeOutputPath {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$InputFile,
        [Parameter(Mandatory = $true)][string]$DestinationFolder
    )

    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile.Name)
    $OutputPath = Join-Path $DestinationFolder "$BaseName.mp3"

    if ($Overwrite -or -not (Test-Path -LiteralPath $OutputPath)) {
        return $OutputPath
    }

    $Counter = 1
    do {
        $OutputPath = Join-Path $DestinationFolder "$BaseName ($Counter).mp3"
        $Counter++
    } while (Test-Path -LiteralPath $OutputPath)

    return $OutputPath
}

try {
    if ([string]::IsNullOrWhiteSpace($Path)) {
        $Path = Read-InputPath
    }

    $Path = Normalize-InputPath -InputPath $Path

    $ResolvedInput = Resolve-Path -LiteralPath $Path -ErrorAction Stop
    $InputItem = Get-Item -LiteralPath $ResolvedInput.ProviderPath -ErrorAction Stop
    $Files = @(Get-VideoFiles -InputPath $InputItem.FullName)

    if ($Files.Count -eq 0) {
        throw 'No supported video files were found.'
    }

    if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
        $OutputFolder = Get-DefaultOutputFolder
    }

    if ($PSCmdlet.ShouldProcess($OutputFolder, 'Create output folder')) {
        New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
    }

    $Ffmpeg = Get-FfmpegPath

    Write-Host '========================================'
    Write-Host ' Video to MP3 Converter'
    Write-Host '========================================'
    Write-Host "Input files: $($Files.Count)"
    Write-Host "Output:      $OutputFolder"
    Write-Host "Bitrate:     $Bitrate"
    Write-Host "FFmpeg:      $Ffmpeg"
    Write-Host ''

    $Converted = 0
    $Failed = 0

    foreach ($File in $Files) {
        $OutputPath = Get-SafeOutputPath -InputFile $File -DestinationFolder $OutputFolder
        $FfmpegArguments = @(
            '-hide_banner',
            '-y',
            '-i', $File.FullName,
            '-vn',
            '-codec:a', 'libmp3lame',
            '-b:a', $Bitrate,
            $OutputPath
        )

        if (-not $Overwrite -and (Test-Path -LiteralPath $OutputPath)) {
            Write-Warning "Skipped existing file: $OutputPath"
            continue
        }

        if ($PSCmdlet.ShouldProcess($File.FullName, "Convert to $OutputPath")) {
            Write-Host "Converting: $($File.Name)"

            & $Ffmpeg @FfmpegArguments
            if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $OutputPath)) {
                $Converted++
                Write-Host "Created: $OutputPath"
            }
            else {
                $Failed++
                Write-Warning "Failed to convert: $($File.FullName)"
            }

            Write-Host ''
        }
    }

    Write-Host '========================================'
    Write-Host ' Conversion Complete'
    Write-Host '========================================'
    Write-Host "Converted: $Converted"
    Write-Host "Failed:    $Failed"
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
