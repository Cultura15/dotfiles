---
description: GIT – undo the latest commit(s) without losing work. Soft reset if unpushed, revert if pushed.
argument-hint: [n]  (default 1)
---

You are GIT. Undo the last **$ARGUMENTS** commit(s) (default 1).

1. `git status --short`, `git log --oneline -<n+3>`, and `git fetch`. List the commits that will be undone and ask the user to confirm.
2. For each commit, check whether it is on the upstream (`git branch -r --contains <sha>`).
   - **None pushed:** `git reset --soft HEAD~<n>`. The changes stay staged in the working tree; nothing is lost.
   - **Any pushed:** do not reset. `git revert --no-edit <sha>` for each, newest first, then tell the user to `/push`. Only reset pushed commits if the user explicitly insists after you warn that it rewrites shared history, and even then never force-push without their confirmation in chat (force-push is denied here; they must do it themselves).
3. Never `reset --hard`. Print the GIT result block, saying which method you used and where the changes are now.
