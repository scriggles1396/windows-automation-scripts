<#
.SYNOPSIS
    Downloads YouTube videos or MP3 audio.

.DESCRIPTION
    Uses yt-dlp and FFmpeg.

    Download options:
    - Video up to 1080p
    - MP3 at 128 kbps

    Filename options:
    - Clean/simple filename
    - Original-style filename

    Downloads are stored in:
    - Videos\YouTube Videos
    - Music\YouTube

.REQUIREMENTS
    - yt-dlp
    - FFmpeg

.AUTHOR
    scriggles1396

.VERSION
    1.4.1

.LASTUPDATED
    2026-08-26

.NOTES
    AI assistance disclosure:
    Portions of this script and its documentation were created with assistance
    from ChatGPT by OpenAI. The output was reviewed and tested by a human before
    publication. Users should independently review and safely test the script
    before running it in their environment.
#>

# ==========================================
# GLOBAL SETTINGS
# ==========================================

$ErrorActionPreference = "Stop"

# ==========================================
# FUNCTIONS
# ==========================================

function Wait-BeforeExit {
    Write-Host ""
    Read-Host "Press Enter to close"
}

function Find-Program {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ProgramName
    )

    # ------------------------------------------
    # 1. Check normal PATH
    # ------------------------------------------

    $command = Get-Command $ProgramName -ErrorAction SilentlyContinue

    if ($command -and $command.Source) {
        return $command.Source
    }

    # ------------------------------------------
    # 2. Check WinGet Links
    # ------------------------------------------

    $wingetLink = Join-Path `
        $env:LOCALAPPDATA `
        "Microsoft\WinGet\Links\$ProgramName"

    if (Test-Path $wingetLink) {
        return $wingetLink
    }

    # ------------------------------------------
    # 3. Search WinGet package directory
    # ------------------------------------------

    $wingetPackages = Join-Path `
        $env:LOCALAPPDATA `
        "Microsoft\WinGet\Packages"

    if (Test-Path $wingetPackages) {

        $found = Get-ChildItem `
            -Path $wingetPackages `
            -Filter $ProgramName `
            -File `
            -Recurse `
            -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($found) {
            return $found.FullName
        }
    }

    return $null
}

function Show-Header {

    Clear-Host

    Write-Host "========================================"
    Write-Host "          YouTube Downloader"
    Write-Host "========================================"
    Write-Host ""
}

# ==========================================
# MAIN SCRIPT
# ==========================================

try {

    Show-Header

    Write-Host "Checking required programs..."
    Write-Host ""

    # ==========================================
    # FIND YT-DLP
    # ==========================================

    $ytDlp = Find-Program "yt-dlp.exe"

    if (-not $ytDlp) {

        Write-Host "ERROR: yt-dlp could not be found."
        Write-Host ""
        Write-Host "Install it with:"
        Write-Host ""
        Write-Host "winget install --id yt-dlp.yt-dlp -e --source winget"
        Write-Host ""

        Wait-BeforeExit
        exit
    }

    Write-Host "yt-dlp found:"
    Write-Host $ytDlp
    Write-Host ""

    # ==========================================
    # FIND FFMPEG
    # ==========================================

    $ffmpeg = Find-Program "ffmpeg.exe"

    if (-not $ffmpeg) {

        Write-Host "ERROR: FFmpeg could not be found."
        Write-Host ""
        Write-Host "Install it with:"
        Write-Host ""
        Write-Host "winget install --id Gyan.FFmpeg -e --source winget"
        Write-Host ""

        Wait-BeforeExit
        exit
    }

    Write-Host "FFmpeg found:"
    Write-Host $ffmpeg
    Write-Host ""

    # yt-dlp wants the directory containing ffmpeg.exe
    $ffmpegFolder = Split-Path $ffmpeg -Parent

    # ==========================================
    # WINDOWS DOWNLOAD FOLDERS
    # ==========================================

    $videosFolder = [Environment]::GetFolderPath("MyVideos")
    $musicFolder  = [Environment]::GetFolderPath("MyMusic")

    if ([string]::IsNullOrWhiteSpace($videosFolder)) {
        throw "Windows Videos folder could not be located."
    }

    if ([string]::IsNullOrWhiteSpace($musicFolder)) {
        throw "Windows Music folder could not be located."
    }

    $videoDownloadFolder = Join-Path `
        $videosFolder `
        "YouTube Videos"

    $audioDownloadFolder = Join-Path `
        $musicFolder `
        "YouTube"

    # ==========================================
    # CREATE DOWNLOAD FOLDERS
    # ==========================================

    if (-not (Test-Path $videoDownloadFolder)) {

        New-Item `
            -ItemType Directory `
            -Path $videoDownloadFolder `
            -Force |
            Out-Null
    }

    if (-not (Test-Path $audioDownloadFolder)) {

        New-Item `
            -ItemType Directory `
            -Path $audioDownloadFolder `
            -Force |
            Out-Null
    }

    # ==========================================
    # MAIN DOWNLOAD LOOP
    # ==========================================

    $keepGoing = $true

    while ($keepGoing) {

        Show-Header

        Write-Host "Videos:"
        Write-Host $videoDownloadFolder
        Write-Host ""

        Write-Host "Music:"
        Write-Host $audioDownloadFolder
        Write-Host ""

        # ======================================
        # URL
        # ======================================

        $url = Read-Host "Paste YouTube URL"

        if ([string]::IsNullOrWhiteSpace($url)) {

            Write-Host ""
            Write-Host "No URL entered."
            Write-Host ""

            Start-Sleep -Seconds 2
            continue
        }

        # ======================================
        # DOWNLOAD FORMAT
        # ======================================

        Write-Host ""
        Write-Host "Select download format:"
        Write-Host ""
        Write-Host "1. Video - up to 1080p"
        Write-Host "2. MP3   - 128 kbps"
        Write-Host ""

        $choice = Read-Host "Select 1 or 2"

        if ($choice -ne "1" -and $choice -ne "2") {

            Write-Host ""
            Write-Host "Invalid selection."
            Start-Sleep -Seconds 2
            continue
        }

        # ======================================
        # FILENAME STYLE
        # ======================================

        Write-Host ""
        Write-Host "Select filename style:"
        Write-Host ""
        Write-Host "1. Clean filename"
        Write-Host "   Simple characters and shorter names"
        Write-Host ""
        Write-Host "2. Original-style filename"
        Write-Host "   Keeps more of the original YouTube title"
        Write-Host ""

        $filenameChoice = Read-Host "Select 1 or 2"

        if (
            $filenameChoice -ne "1" -and
            $filenameChoice -ne "2"
        ) {

            Write-Host ""
            Write-Host "Invalid selection."
            Start-Sleep -Seconds 2
            continue
        }

        # ======================================
        # FILENAME OPTIONS
        # ======================================

        $filenameArgs = @(
            "--windows-filenames"
            "--trim-filenames"
            "80"
        )

        if ($filenameChoice -eq "1") {
            $filenameArgs += "--restrict-filenames"
        }

        Write-Host ""

        # ======================================
        # VIDEO DOWNLOAD
        # ======================================

        if ($choice -eq "1") {

            Write-Host "Downloading video at up to 1080p..."
            Write-Host ""
            Write-Host "Saving to:"
            Write-Host $videoDownloadFolder
            Write-Host ""

            & $ytDlp `
                --ffmpeg-location $ffmpegFolder `
                --force-ipv4 `
                @filenameArgs `
                -f "bv*[height<=1080]+ba/b[height<=1080]" `
                --merge-output-format mp4 `
                -o "$videoDownloadFolder\%(title)s.%(ext)s" `
                $url
        }

        # ======================================
        # MP3 DOWNLOAD
        # ======================================

        elseif ($choice -eq "2") {

            Write-Host "Downloading MP3 at 128 kbps..."
            Write-Host ""
            Write-Host "Saving to:"
            Write-Host $audioDownloadFolder
            Write-Host ""

            & $ytDlp `
                --ffmpeg-location $ffmpegFolder `
                --force-ipv4 `
                @filenameArgs `
                -x `
                --audio-format mp3 `
                --audio-quality 128K `
                -o "$audioDownloadFolder\%(title)s.%(ext)s" `
                $url
        }

        # ======================================
        # CHECK DOWNLOAD RESULT
        # ======================================

        $downloadExitCode = $LASTEXITCODE

        Write-Host ""

        if ($downloadExitCode -eq 0) {

            Write-Host "========================================"
            Write-Host "          Download Finished"
            Write-Host "========================================"
        }
        else {

            Write-Host "========================================"
            Write-Host "           Download Failed"
            Write-Host "========================================"
            Write-Host ""
            Write-Host "yt-dlp returned exit code:"
            Write-Host $downloadExitCode
            Write-Host ""
            Write-Host "The program will remain open so you"
            Write-Host "can review the error above."
        }

        # ======================================
        # DOWNLOAD ANOTHER?
        # ======================================

        Write-Host ""
        $again = Read-Host "Download another? (Y/N)"

        if ($again -notmatch "^[Yy]") {
            return
        }
    }
}

# ==========================================
# CATCH ANY RUNTIME ERROR
# ==========================================

catch {

    Write-Host ""
    Write-Host "========================================"
    Write-Host "              SCRIPT ERROR"
    Write-Host "========================================"
    Write-Host ""

    Write-Host "An unexpected error occurred:"
    Write-Host ""

    Write-Host $_.Exception.Message
    Write-Host ""

    if ($_.InvocationInfo.ScriptLineNumber) {

        Write-Host "Script line:"
        Write-Host $_.InvocationInfo.ScriptLineNumber
        Write-Host ""
    }

    if ($_.InvocationInfo.Line) {

        Write-Host "Command:"
        Write-Host $_.InvocationInfo.Line
        Write-Host ""
    }

    Write-Host "The window will remain open so the"
    Write-Host "error can be reviewed."
    Write-Host ""

    Wait-BeforeExit
}

