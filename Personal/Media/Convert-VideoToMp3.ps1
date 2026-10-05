<#
.SYNOPSIS
    Converts local video files to MP3 audio on Windows.

.DESCRIPTION
    Converts one video file or a folder of video files to MP3 using FFmpeg. If FFmpeg is not
    found, the script attempts to install it with Windows Package Manager (winget).

    The script is designed for Windows desktop use, supports -WhatIf, avoids overwriting
    existing MP3 files unless requested, and keeps output paths simple.

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
    Video file or folder to convert.

.PARAMETER OutputFolder
    Folder where MP3 files are saved. Defaults to an MP3 folder beside the source file or
    inside the source folder.

.PARAMETER Recurse
    Converts supported video files inside child folders.

.PARAMETER Bitrate
    MP3 audio bitrate. Defaults to 192k.

.PARAMETER Overwrite
    Replaces existing MP3 files.

.EXAMPLE
    PS> .\Convert-VideoToMp3.ps1 -Path "D:\Videos\clip.mp4"
    Converts clip.mp4 to D:\Videos\MP3\clip.mp3.

.EXAMPLE
    PS> .\Convert-VideoToMp3.ps1 -Path "D:\Videos" -Recurse -Bitrate 256k
    Converts supported video files under D:\Videos to MP3 at 256 kbps.

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
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
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

function Install-FfmpegWithWinget {
    $Winget = Find-Program -ProgramName 'winget.exe'
    if (-not $Winget) {
        throw 'FFmpeg was not found and winget.exe is not available. Install FFmpeg manually, then run this script again.'
    }

    if ($PSCmdlet.ShouldProcess('Gyan.FFmpeg', 'Install FFmpeg with winget')) {
        Write-Host 'FFmpeg not found. Installing with winget...'
        & $Winget install --id Gyan.FFmpeg --exact --source winget --accept-package-agreements --accept-source-agreements

        if ($LASTEXITCODE -ne 0) {
            throw "winget failed to install FFmpeg. Exit code: $LASTEXITCODE"
        }
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
    param([Parameter(Mandatory = $true)][System.IO.FileSystemInfo]$FirstInput)

    if ($FirstInput.PSIsContainer) {
        return Join-Path $FirstInput.FullName 'MP3'
    }

    return Join-Path $FirstInput.DirectoryName 'MP3'
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
    $ResolvedInput = Resolve-Path -LiteralPath $Path -ErrorAction Stop
    $InputItem = Get-Item -LiteralPath $ResolvedInput.ProviderPath -ErrorAction Stop
    $Files = @(Get-VideoFiles -InputPath $InputItem.FullName)

    if ($Files.Count -eq 0) {
        throw 'No supported video files were found.'
    }

    if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
        $OutputFolder = Get-DefaultOutputFolder -FirstInput $InputItem
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
