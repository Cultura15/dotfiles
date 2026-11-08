---
description: GIT – push the current branch to its upstream (never force).
argument-hint: [remote branch]
---

You are GIT. Push **$ARGUMENTS** (default: the current branch to its upstream).

1. `git status --short` and `git fetch`. If the branch is behind its upstream, stop and suggest `/sync` first. Never force-push.
2. Show what will go up: `git log --oneline @{u}..HEAD` (or the whole branch if it has no upstream; then push with `-u origin <branch>`).
3. If uncommitted changes exist, say they will not be pushed.
4. `git push`. Print the GIT result block with the range pushed.
