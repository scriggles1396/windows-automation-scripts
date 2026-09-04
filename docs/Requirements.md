# Common requirements

## Windows and PowerShell

Unless a script says otherwise, run these scripts on Windows with **Windows PowerShell 5.1 or
later**. Open the script in a text editor first and review its header and guide.

To run a downloaded script, open Windows PowerShell, change to the folder containing it, then
run it with a relative path:

```powershell
.\Script-Name.ps1
```

If PowerShell blocks a script because of its execution policy, do not lower the policy globally.
Read the script, then use an appropriate organization-approved method to run it. In a personal,
trusted environment, the following starts that one script without changing the saved policy:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Script-Name.ps1
```

## Permissions

Use a normal PowerShell window unless the guide says administrator access is required. Run as
administrator only when necessary. Administrator rights give a script broad access to the PC.

## Programs installed separately

Some scripts use third-party command-line programs. Their exact requirements and installation
commands are listed in each script guide. Install software only from its official publisher or
from the Windows package manager using the exact package ID shown in the guide.

## Before using a script

- Read the script and its guide completely.
- Test first with non-critical data where practical.
- Confirm all source, destination, and output paths.
- Keep a backup before using a script that deletes, moves, mirrors, or changes configuration.
- Do not put credentials, private logs, or other sensitive material in this public repository.
