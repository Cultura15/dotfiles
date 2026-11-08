## Commands

| What | Command |
|---|---|
| Dev server | <BUILD: `preview_start {name: "dev"}` (port) · TEST: `{name: "qa"}` (port), from `.claude/launch.json`> |
| Build | <profile Build> |
| Lint | <profile Lint> |
| Unit tests | <profile Unit tests> |
| Extra | <profile Extra> |

## Never

- Edit, serve, import, or commit the protected paths in `.claude/workflow/PROJECT.md`.
- Add a library that duplicates one the plan lists.
- Change the original text of the plan unless the user explicitly asks in chat. Otherwise only append: Decisions log entries and Status ticks (both only via `/finish`).
- Tick a Status box, write a sub-phase's Decisions log entry, or write its `docs/phase-*` notes before TEST and REVIEW both PASS. Only `/finish <id>` does that, and it refuses otherwise.
- Commit or push on your own. BUILD may commit only when the user asks in chat. TEST and REVIEW never commit. The GIT agent normally makes commits.

## Agentic workflow

Four Claude Code agents share this checkout. Full guide: `docs/workflow.md`. Project profile (plan headings, checks, servers, protected paths, models): `.claude/workflow/PROJECT.md`.

| Agent | Where | Writes | Role prompt | Permissions |
|---|---|---|---|---|
| **BUILD** | Claude desktop app | code, plan (append), `docs/` | `.claude/roles/build.md` | `.claude/permissions/build.json` |
| **TEST** | Claude desktop app (its own session) | `docs/reports/<id>/test.md` only | `.claude/roles/test.md` | `.claude/permissions/test.json` |
| **REVIEW** | terminal 2 | `docs/reports/<id>/review.md` only | `.claude/roles/review.md` | `.claude/permissions/review.json` |
| **GIT** | terminal 3 | git history only | `.claude/roles/git.md` | `.claude/permissions/git.json` |

If you were not started with a role prompt, you are BUILD.

Loop: `/subphase 2b` → `/qa-test 2b` + `/qa-review 2b` (in parallel) → any ❌: `/subphase 2b` again (fixes the ❌ items) and re-run QA → both ✅ PASS: `/finish 2b` → `/commit 2b` (GIT) → `/next`.

Agents never talk to each other directly; they hand off through `docs/reports/<id>/{build,test,review}.md`.

QA staleness uses a code fingerprint (`bash .claude/scripts/fingerprint.sh`), not the commit, so committing never invalidates a PASS but any code edit does.

Phase ids: the ids in the plan headings (`2b`); dotted form maps by position (`2.2` → `2b`); a bare number (`2`) means the whole phase.

Models: see `.claude/workflow/PROJECT.md` → Models.
