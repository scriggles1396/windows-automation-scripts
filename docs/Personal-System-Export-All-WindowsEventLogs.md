# Export all Windows Event Logs

Script: [`Personal/System/Export-All-WindowsEventLogs.ps1`](../Personal/System/Export-All-WindowsEventLogs.ps1)

## What it does

Finds Windows Event Viewer channels registered on the local PC, exports channels it can access to
native `.evtx` files, records results and basic system information, and creates a ZIP archive.
It does not clear Event Viewer logs or enable disabled analytic or debug channels.

## Requirements

- Windows 10, Windows 11, or Windows Server
- Windows PowerShell 5.1 or later
- Built-in `wevtutil.exe`
- Administrator access; the script requests elevation when required

No third-party programs are required. Administrator access improves access to protected Event
Viewer channels, but some channels may still be unavailable by design.

## How to run it

Open PowerShell in the script folder and run one of the following:

```powershell
.\Export-All-WindowsEventLogs.ps1
```

This creates the export on the current user's Desktop.

```powershell
.\Export-All-WindowsEventLogs.ps1 -OutputRoot 'C:\Temp'
```

This writes the export folder and ZIP archive under `C:\Temp`.

```powershell
.\Export-All-WindowsEventLogs.ps1 -OutputRoot 'C:\Temp' -RemoveRawAfterZip
```

This removes the uncompressed export folder only after a ZIP archive is successfully created.

## Output

The script creates a timestamped folder named similar to
`WindowsEventLogs_COMPUTERNAME_YYYY-MM-DD_HH-mm-ss`, plus a ZIP file with the same name.

| File | Contents |
| --- | --- |
| `EventLogs\` | Exported native `.evtx` event log files. |
| `EventLog-Manifest.csv` | Every detected log and its export result. |
| `Detected-EventLogs.txt` | Raw list of channels reported by Windows. |
| `Export-Failures.txt` | Channels that could not be exported and their reported errors. |
| `System-Information.txt` | Basic computer and Windows information collected during export. |
| `README.txt` | Summary of the collection. |

## Safety and privacy

Event logs can contain usernames, computer names, IP addresses, file paths, application details,
and other sensitive information. Review the archive before sharing it. Do not commit exported logs
or ZIP archives to this repository.

An export failure does not necessarily mean the PC has a problem. Windows can register protected,
disabled, analytic, and debug channels that cannot be exported in every environment. Check
`Export-Failures.txt` for the exact channels and messages.
