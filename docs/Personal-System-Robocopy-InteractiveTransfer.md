# Robocopy interactive transfer

Script: [`Personal/System/Robocopy-InteractiveTransfer.ps1`](../Personal/System/Robocopy-InteractiveTransfer.ps1)

## What it does

Guides you through copying, moving, or mirroring one source folder to one or more destination
folders. It includes all subfolders, including empty ones, and displays Robocopy's progress and
final status.

## Requirements

- Windows PowerShell 5.1 or later
- Windows built-in `robocopy.exe` (included with supported Windows versions)
- Read access to the source folder and write access to every destination
- A working network connection for UNC destinations such as `\\server\share\backup`

No additional download or installation is needed.

## How to run it

1. Open PowerShell in the folder containing the script.
2. Run:

   ```powershell
   .\Robocopy-InteractiveTransfer.ps1
   ```

3. Enter the source folder, how many destinations to use, then each destination folder.
4. Select one transfer type and review the confirmation summary before entering `Y`.

If a destination folder does not exist, the script offers to create it. It rejects a destination
that is the source folder, inside the source folder, or contains the source folder. This prevents
an accidental recursive copy.

## Transfer types

| Type | Result |
| --- | --- |
| Copy | Copies source contents to every destination. Source files remain in place. |
| Move | Copies source contents to every destination first. It removes the source contents only if every copy succeeds. The empty source folder is kept. |
| Mirror | Makes each destination match the source. It copies changed files and deletes destination files or folders that are absent from the source. |

## Built-in settings

- Includes all subfolders, including empty folders
- Retries a failed file up to three times
- Waits five seconds between retries
- Preserves file data, attributes, and timestamps
- Uses restartable copying where available
- Shows Robocopy's progress and estimated time

## Logging

Choose **Save a log file** when prompted if you need a record. The script asks for a folder and
creates a timestamped `Robocopy-Transfer-YYYYMMDD-HHMMSS.log` file there. It does not create a
log when you choose `N`.

## Safety notes

- Review source and destination paths carefully before starting.
- A Move is not a substitute for a verified backup.
- Mirror is destructive. The script requires you to type `MIRROR`, then confirm the transfer
  separately, before it begins.
- For a multi-destination Move, a failure at any destination leaves source contents in place.
- A Robocopy exit code from `0` through `7` is not a transfer failure. Codes `8` and higher mean
  that at least one file failed to copy.

## Common problems

| Problem | What to check |
| --- | --- |
| Source folder does not exist | Confirm the path and drive letter. For a network location, confirm it is connected and accessible in File Explorer. |
| Destination cannot be created | Confirm the parent path exists and that you have write permission. |
| Network destination fails | Open the UNC path in File Explorer first. Confirm the server, share name, network connection, and permissions. |
| Robocopy reports a failure | Read the console output and optional log. Check free space, file permissions, files held open by another program, and network reliability. |
| Destination is rejected as unsafe | Choose a folder that is separate from the source. Do not use a subfolder of the source or its parent folder. |
