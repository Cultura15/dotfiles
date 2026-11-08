---
description: GIT – fetch and pull the current branch (fast-forward or rebase-free merge), report what came in.
---

You are GIT. Bring the current branch up to date.

1. `git status --short`. If the tree has uncommitted changes, say so and ask whether to commit first (`/commit`) or pull anyway (git refuses if they conflict).
2. `git fetch`, then show incoming commits: `git log --oneline HEAD..@{u}`.
3. `git pull --ff-only`. If that fails because the branches diverged, stop and ask whether to merge (`git pull --no-rebase`, asks for approval) — never rebase or reset on your own.
4. On a conflict, list the conflicted files and tell the user to ask BUILD to resolve them; you do not edit files.
5. Print the GIT result block.
