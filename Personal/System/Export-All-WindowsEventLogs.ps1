<#
.SYNOPSIS
    Exports all Windows Event Viewer logs available on the local computer and creates a ZIP archive.

.DESCRIPTION
    Enumerates registered Windows Event Log channels using the built-in wevtutil.exe utility,
    exports accessible channels to native .evtx files, records export results and basic system
    information, and compresses the collection using built-in Windows tools.

    The script does not enable disabled analytic/debug channels or install additional software.

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
    - Windows 10, Windows 11, or Windows Server
    - Windows PowerShell 5.1 or later
    - Administrator privileges recommended/required for access to protected logs
    - Built-in wevtutil.exe

.PARAMETER OutputRoot
    Directory where the export folder and ZIP archive are created. Defaults to the current
    user's Desktop.

.PARAMETER RemoveRawAfterZip
    Removes the uncompressed export directory after a ZIP archive is successfully created.

.EXAMPLE
    PS> .\Export-All-WindowsEventLogs.ps1
    Exports available Event Viewer logs to the Desktop and creates a ZIP archive.

.EXAMPLE
    PS> .\Export-All-WindowsEventLogs.ps1 -OutputRoot 'C:\Temp' -RemoveRawAfterZip
    Exports logs to C:\Temp, creates the ZIP archive, and removes the raw export after success.

.OUTPUTS
    - Native .evtx files
    - EventLog-Manifest.csv
    - Detected-EventLogs.txt
    - Export-Failures.txt
    - System-Information.txt
    - README.txt
    - ZIP archive

.SAFETY
    Event logs can contain usernames, hostnames, IP addresses, application data, file paths,
    and other sensitive information. Review exported data before sharing it with another party
    or publishing it.

    This script reads and exports event logs. It does not clear logs or alter Event Viewer
    channel configuration.

.LICENSE
    MIT License. See the repository LICENSE file.

.NOTES
    Some disabled, analytic, debug, protected, or otherwise unavailable channels may fail to
    export. Failures are recorded and do not stop collection of the remaining logs.
#>

[CmdletBinding()]
param(
    [string]$OutputRoot = "$env:USERPROFILE\Desktop",
    [switch]$RemoveRawAfterZip
)

$ErrorActionPreference = 'Continue'

# Request Administrator privileges when needed.
$CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$Principal = New-Object Security.Principal.WindowsPrincipal($CurrentIdentity)
$IsAdmin = $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Write-Host 'Administrator privileges are required. Requesting elevation...'

    if (-not $PSCommandPath) {
        Write-Error 'Unable to determine the script path. Save this as a .ps1 file and run it again.'
        exit 1
    }

    $Arguments = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', "`"$PSCommandPath`"",
        '-OutputRoot', "`"$OutputRoot`""
    )

    if ($RemoveRawAfterZip) {
        $Arguments += '-RemoveRawAfterZip'
    }

    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList ($Arguments -join ' ')
    }
    catch {
        Write-Error "Failed to request Administrator privileges: $($_.Exception.Message)"
    }
    exit
}

$Timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$ComputerNameSafe = $env:COMPUTERNAME -replace '[<>:"/\\|?*]', '_'
$ExportName = "WindowsEventLogs_${ComputerNameSafe}_${Timestamp}"
$ExportFolder = Join-Path $OutputRoot $ExportName
$EventLogFolder = Join-Path $ExportFolder 'EventLogs'
$ManifestFile = Join-Path $ExportFolder 'EventLog-Manifest.csv'
$FailureFile = Join-Path $ExportFolder 'Export-Failures.txt'
$SystemInfoFile = Join-Path $ExportFolder 'System-Information.txt'
$LogListFile = Join-Path $ExportFolder 'Detected-EventLogs.txt'
$SummaryFile = Join-Path $ExportFolder 'README.txt'
$ZipFile = Join-Path $OutputRoot "$ExportName.zip"

try {
    New-Item -Path $EventLogFolder -ItemType Directory -Force | Out-Null
}
catch {
    Write-Error "Unable to create output directory: $ExportFolder"
    exit 1
}

Write-Host '============================================================'
Write-Host ' Windows Event Log Export'
Write-Host '============================================================'
Write-Host "Computer: $env:COMPUTERNAME"
Write-Host "Output:   $ExportFolder"
Write-Host ''
Write-Host 'Scanning Windows for registered Event Viewer logs...'

try {
    $OS = Get-CimInstance Win32_OperatingSystem
    $Computer = Get-CimInstance Win32_ComputerSystem
    $BIOS = Get-CimInstance Win32_BIOS

    @"
Windows Event Log Export
========================

Export Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Computer Name: $env:COMPUTERNAME
Current User: $env:USERDOMAIN\$env:USERNAME
Windows: $($OS.Caption)
Windows Version: $($OS.Version)
Build: $($OS.BuildNumber)
Architecture: $($OS.OSArchitecture)
Manufacturer: $($Computer.Manufacturer)
Model: $($Computer.Model)
Serial Number: $($BIOS.SerialNumber)
PowerShell Version: $($PSVersionTable.PSVersion)
Boot Time: $($OS.LastBootUpTime)
Export Directory: $ExportFolder
"@ | Set-Content -Path $SystemInfoFile -Encoding UTF8
}
catch {
    "System information collection failed: $($_.Exception.Message)" |
        Set-Content -Path $SystemInfoFile -Encoding UTF8
}

try {
    $Logs = @(
        & "$env:SystemRoot\System32\wevtutil.exe" el 2>&1 |
            Where-Object { $_ -and $_.ToString().Trim().Length -gt 0 } |
            ForEach-Object { $_.ToString().Trim() } |
            Sort-Object -Unique
    )
}
catch {
    Write-Error 'Unable to enumerate Windows Event Logs.'
    exit 1
}

if ($Logs.Count -eq 0) {
    Write-Error 'Windows did not return any Event Log channels.'
    exit 1
}

$Logs | Set-Content -Path $LogListFile -Encoding UTF8
Write-Host "Found $($Logs.Count) registered Event Log channels."

$Results = New-Object System.Collections.Generic.List[object]
$SuccessCount = 0
$FailureCount = 0
$Current = 0

foreach ($LogName in $Logs) {
    $Current++
    $Percent = [math]::Round(($Current / $Logs.Count) * 100, 0)

    Write-Progress -Activity 'Exporting Windows Event Logs' `
        -Status "$Current of $($Logs.Count): $LogName" `
        -PercentComplete $Percent

    Write-Host "[$Current/$($Logs.Count)] $LogName"

    $Parts = $LogName -split '/'
    $CurrentDirectory = $EventLogFolder

    if ($Parts.Count -gt 1) {
        for ($i = 0; $i -lt ($Parts.Count - 1); $i++) {
            $SafeDirectory = $Parts[$i] -replace '[<>:"\\|?*]', '_'
            $CurrentDirectory = Join-Path $CurrentDirectory $SafeDirectory
            New-Item -Path $CurrentDirectory -ItemType Directory -Force | Out-Null
        }
    }

    $SafeLeafName = $Parts[-1] -replace '[<>:"/\\|?*]', '_'
    if ([string]::IsNullOrWhiteSpace($SafeLeafName)) {
        $SafeLeafName = 'UnnamedLog'
    }

    $Destination = Join-Path $CurrentDirectory "$SafeLeafName.evtx"
    $Enabled = $null
    $RecordCount = $null
    $FileSize = $null

    try {
        $Metadata = Get-WinEvent -ListLog $LogName -ErrorAction Stop
        $Enabled = $Metadata.IsEnabled
        $RecordCount = $Metadata.RecordCount
        $FileSize = $Metadata.FileSize
    }
    catch {
        # Metadata failure does not prevent wevtutil from attempting export.
    }

    $OutputMessage = $null

    try {
        $ExportOutput = & "$env:SystemRoot\System32\wevtutil.exe" epl "$LogName" "$Destination" '/ow:true' 2>&1
        $ExitCode = $LASTEXITCODE
        $OutputMessage = ($ExportOutput | Out-String).Trim()

        if ($ExitCode -eq 0 -and (Test-Path $Destination)) {
            $ExportedSize = (Get-Item $Destination).Length
            $SuccessCount++
            $Results.Add([PSCustomObject]@{
                LogName        = $LogName
                Enabled        = $Enabled
                RecordCount    = $RecordCount
                SourceFileSize = $FileSize
                Status         = 'Exported'
                ExportedSize   = $ExportedSize
                Destination    = $Destination
                Error          = ''
            })
            Write-Host '    Exported'
        }
        else {
            throw "wevtutil returned exit code $ExitCode. $OutputMessage"
        }
    }
    catch {
        $FailureCount++
        $ErrorMessage = $_.Exception.Message
        if ($OutputMessage) { $ErrorMessage += " $OutputMessage" }

        if (Test-Path $Destination) {
            try {
                if ((Get-Item $Destination).Length -eq 0) {
                    Remove-Item $Destination -Force
                }
            }
            catch {}
        }

        $Results.Add([PSCustomObject]@{
            LogName        = $LogName
            Enabled        = $Enabled
            RecordCount    = $RecordCount
            SourceFileSize = $FileSize
            Status         = 'FAILED'
            ExportedSize   = ''
            Destination    = $Destination
            Error          = $ErrorMessage
        })
        Write-Host "    FAILED: $ErrorMessage"
    }
}

Write-Progress -Activity 'Exporting Windows Event Logs' -Completed
$Results | Export-Csv -Path $ManifestFile -NoTypeInformation -Encoding UTF8

$FailedResults = $Results | Where-Object { $_.Status -eq 'FAILED' }
if ($FailedResults) {
    $FailedResults | ForEach-Object {
@"
Log:
$($_.LogName)

Error:
$($_.Error)

------------------------------------------------------------
"@
    } | Set-Content -Path $FailureFile -Encoding UTF8
}
else {
    'No Event Log export failures were recorded.' | Set-Content -Path $FailureFile -Encoding UTF8
}

@"
WINDOWS EVENT LOG EXPORT
========================

Computer: $env:COMPUTERNAME
Export Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Registered Logs Detected: $($Logs.Count)
Successfully Exported: $SuccessCount
Failed / Unavailable: $FailureCount

CONTENTS
========
EventLogs\               Native Event Viewer .evtx files.
EventLog-Manifest.csv    Complete list of discovered logs and export status.
Detected-EventLogs.txt   Raw list of Event Log channels reported by Windows.
Export-Failures.txt      Channels that could not be exported and reported errors.
System-Information.txt   Basic information about the source computer.

NOTES
=====
A failed export does not necessarily indicate a system problem. Windows contains diagnostic,
analytic, debug, protected, and disabled Event Log channels that cannot always be exported.

Event logs can contain sensitive information. Review this collection before sharing it.
"@ | Set-Content -Path $SummaryFile -Encoding UTF8

Write-Host ''
Write-Host 'Creating ZIP archive...'
$ZipSuccess = $false

try {
    if (Test-Path $ZipFile) { Remove-Item $ZipFile -Force }
    Compress-Archive -Path "$ExportFolder\*" -DestinationPath $ZipFile `
        -CompressionLevel Optimal -Force -ErrorAction Stop

    if (Test-Path $ZipFile) {
        $ZipSuccess = $true
        $ZipSizeMB = [math]::Round((Get-Item $ZipFile).Length / 1MB, 2)
        Write-Host "ZIP created successfully ($ZipSizeMB MB)."
    }
}
catch {
    Write-Warning "Compress-Archive failed: $($_.Exception.Message)"
    Write-Host 'Trying built-in Windows tar.exe instead...'

    try {
        if (Test-Path $ZipFile) { Remove-Item $ZipFile -Force }
        Push-Location $OutputRoot
        try {
            & "$env:SystemRoot\System32\tar.exe" -a -c -f "$ZipFile" "$ExportName"
            $TarExitCode = $LASTEXITCODE
        }
        finally {
            Pop-Location
        }

        if ($TarExitCode -eq 0 -and (Test-Path $ZipFile)) {
            $ZipSuccess = $true
            Write-Host 'ZIP created successfully using tar.exe.'
        }
        else {
            throw "tar.exe returned exit code $TarExitCode"
        }
    }
    catch {
        Write-Warning "Unable to automatically create ZIP archive: $($_.Exception.Message)"
    }
}

if ($RemoveRawAfterZip -and $ZipSuccess) {
    try {
        Remove-Item -Path $ExportFolder -Recurse -Force -ErrorAction Stop
        Write-Host 'Uncompressed export directory removed.'
    }
    catch {
        Write-Warning "Could not remove uncompressed export directory: $($_.Exception.Message)"
    }
}

Write-Host ''
Write-Host '============================================================'
Write-Host ' Export Complete'
Write-Host '============================================================'
Write-Host "Logs detected:  $($Logs.Count)"
Write-Host "Exported:       $SuccessCount"
Write-Host "Failed/skipped: $FailureCount"

if (-not $RemoveRawAfterZip -or -not $ZipSuccess) {
    Write-Host "Raw export:     $ExportFolder"
}

if ($ZipSuccess) {
    Write-Host "ZIP archive:    $ZipFile"
}
else {
    Write-Host 'ZIP archive creation FAILED. The uncompressed export is still available.'
}

Write-Host "Manifest:       $ManifestFile"
Write-Host ''
Read-Host 'Press Enter to close'
