<#
.SYNOPSIS
    Losslessly reduces the size of JPEG and PNG files in a folder.

.DESCRIPTION
    Creates optimized JPEG and PNG copies without changing their rendered
    pixels. Original files are left untouched by default; use -InPlace only
    when replacement is intended. Required command-line tools are downloaded
    from their public GitHub releases on first use.

.AUTHOR
    scriggles1396

.VERSION
    1.0.0

.LAST UPDATED
    2026-09-09

.AI ASSISTANCE
    AI-assisted:
    Portions of this script and/or its documentation were created with
    assistance from ChatGPT by OpenAI.

.REQUIREMENTS
    - Windows PowerShell 5.1 or later
    - Internet access on first use to download oxipng and MozJPEG

.PARAMETER Path
    Folder to scan. Defaults to the folder containing this script.

.PARAMETER Recurse
    Include subfolders.

.PARAMETER InPlace
    Replace files only when a smaller lossless version is produced.

.PARAMETER OutputPath
    Destination for optimized copies. Defaults to an optimized subfolder.

.OUTPUTS
    Smaller JPEG and PNG copies, plus downloaded tools in .image-tools.

.SAFETY
    The default behavior retains originals. GIF, WebP, HEIC, TIFF, BMP, and
    SVG files are skipped rather than applying transformations that could alter
    their appearance, animation, metadata, or editability.

.LICENSE
    MIT License. See the repository LICENSE file.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Position = 0)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$Path = $PSScriptRoot,

    [switch]$Recurse,
    [switch]$InPlace,
    [string]$OutputPath,
    [string]$ToolDirectory = (Join-Path $PSScriptRoot '.image-tools')
)

$ErrorActionPreference = 'Stop'

if ($WhatIfPreference) {
    Write-Host 'WhatIf: no files or tools will be downloaded or changed.'
    return
}

function Get-GitHubReleaseAsset {
    param(
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][string]$AssetPattern,
        [Parameter(Mandatory)][string]$DestinationDirectory
    )

    New-Item -ItemType Directory -Force -Path $DestinationDirectory | Out-Null
    $headers = @{ 'User-Agent' = 'lossless-image-optimizer' }
    $release = Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/$Repository/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -match $AssetPattern } | Select-Object -First 1
    if (-not $asset) {
        throw "No release asset matching '$AssetPattern' was found for $Repository."
    }

    $archive = Join-Path $env:TEMP $asset.name
    Invoke-WebRequest -Headers $headers -Uri $asset.browser_download_url -OutFile $archive
    Expand-Archive -LiteralPath $archive -DestinationPath $DestinationDirectory -Force
    Remove-Item -LiteralPath $archive -Force
}

function Find-Tool {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][string]$AssetPattern
    )

    $installed = Get-Command $Name -ErrorAction SilentlyContinue
    if ($installed) { return $installed.Source }

    $candidate = Get-ChildItem -Path $ToolDirectory -Filter $Name -File -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $candidate) {
        Write-Host "Downloading $Name from the latest $Repository release..."
        Get-GitHubReleaseAsset -Repository $Repository -AssetPattern $AssetPattern -DestinationDirectory $ToolDirectory
        $candidate = Get-ChildItem -Path $ToolDirectory -Filter $Name -File -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1
    }
    if (-not $candidate) { throw "$Name was not found after download." }
    return $candidate.FullName
}

function Get-TargetPath {
    param([System.IO.FileInfo]$File)
    if ($InPlace) { return $File.FullName }
    $relative = [System.IO.Path]::GetRelativePath($sourceRoot, $File.FullName)
    $target = Join-Path $OutputPath $relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    return $target
}

function Optimize-Jpeg {
    param([System.IO.FileInfo]$File, [string]$Target, [string]$Jpegtran)
    $temp = Join-Path ([System.IO.Path]::GetDirectoryName($Target)) ('.' + [Guid]::NewGuid().ToString() + '.jpg')
    & $Jpegtran -copy all -optimize -progressive -outfile $temp $File.FullName | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "jpegtran failed for $($File.FullName)." }
    return $temp
}

function Optimize-Png {
    param([System.IO.FileInfo]$File, [string]$Target, [string]$Oxipng)
    $temp = Join-Path ([System.IO.Path]::GetDirectoryName($Target)) ('.' + [Guid]::NewGuid().ToString() + '.png')
    & $Oxipng -o max --preserve --out $temp $File.FullName | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "oxipng failed for $($File.FullName)." }
    return $temp
}

$sourceRoot = (Resolve-Path -LiteralPath $Path).Path
if (-not $OutputPath) { $OutputPath = Join-Path $sourceRoot 'optimized' }
if (-not $InPlace) {
    $OutputPath = [System.IO.Path]::GetFullPath($OutputPath)
    New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null
}

$searchOptions = @{ LiteralPath = $sourceRoot; File = $true }
if ($Recurse) { $searchOptions.Recurse = $true }
$files = Get-ChildItem @searchOptions | Where-Object {
    $_.Extension.ToLowerInvariant() -in '.jpg', '.jpeg', '.png' -and
    ($InPlace -or -not $_.FullName.StartsWith($OutputPath, [System.StringComparison]::OrdinalIgnoreCase))
}

if (-not $files) {
    Write-Host 'No JPEG or PNG files found.'
    return
}

$jpegFiles = @($files | Where-Object { $_.Extension.ToLowerInvariant() -in '.jpg', '.jpeg' })
$pngFiles = @($files | Where-Object { $_.Extension.ToLowerInvariant() -eq '.png' })
$jpegtran = if ($jpegFiles) { Find-Tool -Name 'jpegtran-static.exe' -Repository 'garyzyg/mozjpeg-windows' -AssetPattern 'mozjpeg-x64\.zip$' }
$oxipng = if ($pngFiles) { Find-Tool -Name 'oxipng.exe' -Repository 'shssoichiro/oxipng' -AssetPattern 'x86_64-pc-windows-msvc\.zip$' }

$savedBytes = [Int64]0
$changed = 0
foreach ($file in $files) {
    $target = Get-TargetPath -File $file
    $temp = $null
    try {
        $temp = if ($file.Extension.ToLowerInvariant() -eq '.png') {
            Optimize-Png -File $file -Target $target -Oxipng $oxipng
        } else {
            Optimize-Jpeg -File $file -Target $target -Jpegtran $jpegtran
        }
        $optimizedLength = (Get-Item -LiteralPath $temp).Length
        if ($optimizedLength -lt $file.Length) {
            if ($PSCmdlet.ShouldProcess($target, "Save losslessly optimized copy of $($file.Name)")) {
                Move-Item -LiteralPath $temp -Destination $target -Force
                $savedBytes += $file.Length - $optimizedLength
                $changed++
                Write-Host "Optimized: $($file.Name)"
            }
        } elseif (-not $InPlace -and $PSCmdlet.ShouldProcess($target, "Copy $($file.Name), already smallest")) {
            Copy-Item -LiteralPath $file.FullName -Destination $target -Force
            Write-Host "Copied unchanged: $($file.Name)"
        } else {
            Write-Host "Already smallest: $($file.Name)"
        }
    } finally {
        if ($temp -and (Test-Path -LiteralPath $temp)) { Remove-Item -LiteralPath $temp -Force }
    }
}

Write-Host ("Finished. {0} file(s) made smaller; saved {1:N0} bytes." -f $changed, $savedBytes)
