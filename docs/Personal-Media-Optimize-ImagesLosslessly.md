# Lossless image optimizer

Script: [`Personal/Media/Optimize-ImagesLosslessly.ps1`](../Personal/Media/Optimize-ImagesLosslessly.ps1)

## What it does

Creates smaller copies of JPEG and PNG images without changing their rendered pixels. The original files remain unchanged unless you explicitly use `-InPlace`.

On its first run, the script downloads the required Windows tools from their public GitHub releases into a `.image-tools` folder alongside the script.

## Requirements

- Windows PowerShell 5.1 or later
- Internet access on the first run
- Permission to write to the selected output folder

## How to run it

To optimize pictures in a folder, open PowerShell and run:

```powershell
.\Optimize-ImagesLosslessly.ps1 -Path C:\Pictures -Recurse
```

This creates optimized copies in `C:\Pictures\optimized`. To use a different output folder:

```powershell
.\Optimize-ImagesLosslessly.ps1 -Path C:\Pictures -Recurse -OutputPath C:\Pictures-Optimized
```

Use `-InPlace` only after confirming the results. It replaces an original only if the new lossless version is smaller:

```powershell
.\Optimize-ImagesLosslessly.ps1 -Path C:\Pictures -Recurse -InPlace
```

## Safety and limitations

- JPEG and PNG are the only optimized formats.
- GIF, WebP, HEIC, TIFF, BMP, and SVG files are left alone to avoid altering appearance, animation, metadata, or editability.
- Run the script with `-WhatIf` to confirm its behavior without downloading tools or changing files.
- When using the default output folder, the script does not modify the originals.
