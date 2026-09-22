# AGENTS.md instructions

Address me as Magos. Be brief, factual, and scope-limited.

This repo is for Windows automation scripts. Default goal: make the smallest safe change that solves the requested task.

Before edits:
1. identify the exact scripts/files likely needed
2. list them
3. copy each touched existing file to `_backups` for easy undo
4. then edit only relevant files

Workflow:
- Use PowerShell first.
- Use `rg` for search.
- Avoid broad repo scans unless narrow search fails.
- Do not refactor unrelated code.
- Do not change script behaviour outside the request.
- Preserve existing comments, parameters, paths, and naming style.
- Prefer reversible changes and clear validation commands.

Validation:
- Run syntax checks where possible.
- For PowerShell, prefer:
  `powershell -NoProfile -ExecutionPolicy Bypass -File .\script.ps1 -WhatIf`
  when supported.
- If a script has no safe dry run, say so and inspect only.

Final reply:
- changed files
- backup location
- validation run/result
- any risk or manual test needed

For each new task in this repo, start with: "Scope only this script/folder unless you prove more is needed."
