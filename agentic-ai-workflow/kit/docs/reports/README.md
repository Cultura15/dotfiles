# QA reports

One folder per sub-phase or fix id (`docs/reports/2b/`, `docs/reports/f1a/`). Each agent writes only its own file:

| File | Written by | Command |
|---|---|---|
| `build.md` | BUILD | `/subphase` or `/fix` (build and fix rounds), `/finish` (sets `DONE`) |
| `test.md` | TEST | `/qa-test` |
| `review.md` | REVIEW | `/qa-review` |

A whole-phase QA run (`/qa-test 2`) writes to `docs/reports/2/`.

Templates are in `_template/`. Every report starts with a `## Summary` block of ✅ passed / ❌ failed items, and the same block is printed in the agent's terminal. Each report has a `round` in its front matter; a new round overwrites the file and bumps it (history is in git).

A sub-phase is QA-done when `test.md` and `review.md` both have `verdict: PASS` and their `fingerprint` equals the current `bash .claude/scripts/fingerprint.sh`. Only then does `/finish <id>` tick its Status box and write its Decisions log entry and docs (in `FIXES.md` for `f` ids).
