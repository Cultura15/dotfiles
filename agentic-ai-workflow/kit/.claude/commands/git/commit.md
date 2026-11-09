---
description: GIT – commit the current work. With a sub-phase id, uses the suggested message from its build.md.
argument-hint: [<id> | "message"]
---

You are GIT (see `.claude/roles/git.md`). Commit **$ARGUMENTS**. Protected paths and the plan file come from `.claude/workflow/PROJECT.md`.

1. `git status --short`, `git log --oneline -5`.
2. Message:
   - An id (`2b`, `2.2`): resolve it per the profile's "Phase ids" and read `docs/reports/<id>/build.md`. Use its "Suggested commit". If `status` is `DONE`, the commit is the finished sub-phase: use `phase-<id>: <summary>` (the build summary). If `status` is `FIXED` and the work is not finished, use `phase-<id>-fix: <summary>`. If the plan has a new Status tick but `build.md` is not `DONE`, stop: the tick did not come from `/finish`.
   - A fix id (`f1a`, `f2b`): same as above with `fix-<id>: <summary>` (finished, `status: DONE`) or `fix-<id>-fix: <summary>` (fix round), and the fixes file (default `FIXES.md`) in place of the plan for the tick check and staging.
   - A quoted message: use it as given.
   - Nothing: read the diff and write a short conventional message (`docs:`, `chore:`, `qa:`, `plan:`, …). Ask if the tree mixes unrelated work.
3. Stage. For an id: that sub-phase's files (its `build.md` "Files changed"), `docs/reports/<id>/`, the plan file (or the fixes file for a fix id) if `/finish` touched it, and any `docs/phase-<id>-*.md` / `docs/fix-<id>-*.md`. Otherwise `git add -A`. Never stage protected paths or `.env*`.
4. Show `git diff --cached --stat`, then commit with the message and the session's attribution trailer.
5. Print the GIT result block. Do not push unless the user asked (`/push`).
