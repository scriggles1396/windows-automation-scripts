# Git Push Troubleshooting

## Detached worktree push

When using a temporary clean worktree created from `origin/main`, the worktree may be in a
detached HEAD state.

In that state, avoid:

```powershell
git push origin main
```

That command can push the stale local `main` branch from the shared repository instead of the
detached worktree commit.

Use:

```powershell
git fetch origin main
git rev-list --left-right --count HEAD...origin/main
git push origin HEAD:main
```

Expected safe state before pushing:

```text
1    0
```

That means the detached worktree commit is one commit ahead of `origin/main` and the remote is
not ahead.

If GitHub returns `remote: Internal Server Error`, retry after a fresh `git fetch origin main`.
If it repeats, record the GitHub Request ID and retry later.
