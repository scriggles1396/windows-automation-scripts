<#
.SYNOPSIS
    Compresses PNG, JPEG, and WebP images in a folder.

.DESCRIPTION
    Creates compressed copies in a separate output folder. Original files are never changed.
    ImageMagick is used when available. If it is missing, the script installs it with WinGet.

.AUTHOR
    scriggles1396

.VERSION
    1.0.0

.LAST UPDATED
    2026-09-19

.AI ASSISTANCE
    Portions of this script and its documentation were created with assistance from ChatGPT by OpenAI.
    The output was reviewed and tested by a human before publication.

.REQUIREMENTS
    - Windows PowerShell 5.1 or PowerShell 7
    - ImageMagick, installed automatically with WinGet when needed

.PARAMETER SourcePath
    Folder containing images to compress.

.PARAMETER OutputPath
    Destination folder. Default: a sibling folder named <source>-compressed.

.PARAMETER Recursive
    Include images in subfolders. Folder layout is preserved in output.

.EXAMPLE
    PS> .\Compress-ImageFolder.ps1 -SourcePath 'C:\Pictures'
    Compresses images directly in C:\Pictures into C:\Pictures-compressed.

.EXAMPLE
    PS> .\Compress-ImageFolder.ps1 -SourcePath 'C:\Pictures' -Recursive
    Also compresses images in subfolders.

.OUTPUTS
    Compressed image copies and a summary in the destination folder.

.SAFETY
    Original files are not changed. Review output before replacing any original files.

.LICENSE
    MIT License. See the repository LICENSE file.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$SourcePath,

    [string]$OutputPath,

    [switch]$Recursive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Find-ImageMagick {
    $command = Get-Command magick.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $programFiles = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ }
    foreach ($root in $programFiles) {
        $candidate = Get-ChildItem -LiteralPath $root -Directory -Filter 'ImageMagick-*' -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName 'magick.exe' } |
            Where-Object { Test-Path -LiteralPath $_ } |
            Select-Object -First 1

        if ($candidate) {
            return $candidate
        }
    }

    return $null
}

function Test-IsAdministrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-WingetInstall {
    param(
        [Parameter(Mandatory)]
        [string]$PackageId,

        [Parameter(Mandatory)]
        [string]$DisplayName
    )

    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw "$DisplayName is required, but WinGet is unavailable. Install $DisplayName, then run this script again."
    }

    $arguments = @(
        'install',
        '--id', $PackageId,
        '--exact',
        '--source', 'winget',
        '--silent',
        '--accept-package-agreements',
        '--accept-source-agreements'
    )

    Write-Host "Installing $DisplayName..."
    & $winget.Source @arguments
    if ($LASTEXITCODE -eq 0) {
        return
    }

    if (Test-IsAdministrator) {
        throw "$DisplayName installation failed with exit code $LASTEXITCODE."
    }

    Write-Host ''
    Write-Host "$DisplayName could not install without elevation."
    $answer = Read-Host 'Open an Administrator install prompt now? (Y/N)'
    if ($answer -notmatch '^[Yy]') {
        throw "$DisplayName installation was cancelled."
    }

    $elevatedCommand = "& `"$($winget.Source)`" $($arguments -join ' '); Write-Host ''; Read-Host 'Press Enter to close'"
    Start-Process -FilePath 'powershell.exe' `
        -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $elevatedCommand `
        -Verb RunAs `
        -Wait
}

function Install-ImageMagick {
    Invoke-WingetInstall -PackageId 'ImageMagick.ImageMagick' -DisplayName 'ImageMagick'

    $imageMagick = Find-ImageMagick
    if (-not $imageMagick) {
        throw 'ImageMagick installed, but magick.exe was not found. Close and reopen PowerShell, then run this script again.'
    }

    return $imageMagick
}

function Get-OutputFilePath {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string]$SourceRoot,

        [Parameter(Mandatory)]
        [string]$DestinationRoot
    )

    $relativePath = $FilePath.Substring($SourceRoot.Length).TrimStart([char[]]'\\/')
    return Join-Path $DestinationRoot $relativePath
}

$sourceRoot = (Resolve-Path -LiteralPath $SourcePath).Path.TrimEnd([char[]]'\\/')
if (-not $OutputPath) {
    $OutputPath = "$sourceRoot-compressed"
}

$destinationRoot = [System.IO.Path]::GetFullPath($OutputPath).TrimEnd([char[]]'\\/')
if ($destinationRoot -eq $sourceRoot) {
    throw 'OutputPath must be different from SourcePath.'
}
if ($destinationRoot.StartsWith("$sourceRoot\\", [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'OutputPath must not be inside SourcePath.'
}

$imageMagick = Find-ImageMagick
if (-not $imageMagick) {
    $imageMagick = Install-ImageMagick
}

$searchOptions = if ($Recursive) { 'AllDirectories' } else { 'TopDirectoryOnly' }
$extensions = @('.png', '.jpg', '.jpeg', '.webp')
$images = [System.IO.Directory]::EnumerateFiles($sourceRoot, '*', [System.IO.SearchOption]::$searchOptions) |
    Where-Object { $extensions -contains [System.IO.Path]::GetExtension($_).ToLowerInvariant() } |
    ForEach-Object { (Resolve-Path -LiteralPath $_).Path }

$processed = 0
$failed = 0
$sourceBytes = [int64]0
$outputBytes = [int64]0

foreach ($imagePath in $images) {
    $image = Get-Item -LiteralPath $imagePath
    $outputFile = Get-OutputFilePath -FilePath $imagePath -SourceRoot $sourceRoot -DestinationRoot $destinationRoot
    $outputDirectory = Split-Path -Parent $outputFile
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

    $arguments = @($image.FullName, '-strip')
    switch ($image.Extension.ToLowerInvariant()) {
        '.png' { $arguments += @('-define', 'png:compression-level=9', '-define', 'png:compression-filter=5') }
        '.jpg' { $arguments += @('-interlace', 'Plane', '-quality', '85', '-sampling-factor', '4:2:0') }
        '.jpeg' { $arguments += @('-interlace', 'Plane', '-quality', '85', '-sampling-factor', '4:2:0') }
        '.webp' { $arguments += @('-quality', '85', '-define', 'webp:method=6') }
    }
    $arguments += $outputFile

    Write-Host "Compressing: $($image.FullName)"
    & $imageMagick @arguments
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $outputFile -PathType Leaf)) {
        Write-Warning "Failed: $($image.FullName)"
        $failed++
        continue
    }

    $processed++
    $sourceBytes += $image.Length
    $outputBytes += (Get-Item -LiteralPath $outputFile).Length
}

if ($processed -eq 0) {
    Write-Warning 'No PNG, JPEG, or WebP images found.'
    return
}

$savedBytes = $sourceBytes - $outputBytes
$savedPercent = [math]::Round(($savedBytes / $sourceBytes) * 100, 1)
Write-Host "Completed: $processed image(s); $savedPercent% smaller; output: $destinationRoot"
if ($failed -gt 0) {
    Write-Warning "$failed image(s) failed. Originals remain unchanged."
}
