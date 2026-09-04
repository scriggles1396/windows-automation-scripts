# Script index

This index is the starting point for using the scripts in this repository. Open the guide for a
script before running it; it states what the script needs, what it creates or changes, and known
limitations.

| Script | Purpose | Extra programs needed | Guide |
| --- | --- | --- | --- |
| `Personal/System/Export-All-WindowsEventLogs.ps1` | Exports accessible Windows Event Viewer logs and creates a ZIP archive. | None on supported Windows versions; uses built-in Windows tools. | [Open guide](Personal-System-Export-All-WindowsEventLogs.md) |
| `Personal/System/Robocopy-InteractiveTransfer.ps1` | Copies, moves, or mirrors a folder to one or more locations. | None on supported Windows versions; uses built-in Robocopy. | [Open guide](Personal-System-Robocopy-InteractiveTransfer.md) |
| `Personal/Media/Media-Download-YouTube.ps1` | Downloads a YouTube video or converts it to MP3 audio. | `yt-dlp` and FFmpeg. | [Open guide](Personal-Media-Media-Download-YouTube.md) |

## Adding a guide for a new script

Add a row to this table and a Markdown guide in `docs/` when publishing a script. A guide should
cover:

- purpose and supported environment
- required programs, permissions, and installation instructions
- how to run the script and what its prompts or parameters mean
- output locations and files created
- safety notes, limitations, and common failure messages

Use placeholder hostnames, addresses, usernames, and paths in examples. Never add private
information, credentials, tokens, or real customer data to a guide.
