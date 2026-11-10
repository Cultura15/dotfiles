---
description: READ-ONLY (all agents) – list every phase and fix with its label and state, or show one id in detail.
argument-hint: [id]  e.g. (none) · 2b · f1a · 2 · f1
allowed-tools: Read, Glob, Grep, Bash(git status:*), Bash(git log:*), Bash(git rev-parse:*), Bash(bash .claude/scripts/fingerprint.sh)
---

You are running `/check` for **$ARGUMENTS** as whichever agent this session is (BUILD, TEST, REVIEW, or GIT). This command is **read-only**:
- Never write, edit, tick, stage, commit, or run anything but `git status`, `git log`, `git rev-parse`, and `bash .claude/scripts/fingerprint.sh`.
- Never start a dev server or another command. Do not change your own role: just report.
- If `.claude/workflow/PROJECT.md` still has `<fill me>`, say `run /build:setup first` and stop.

Read `.claude/workflow/PROJECT.md` first (plan file, headings, optional marker, fixes file). Run `bash .claude/scripts/fingerprint.sh` once. Use the same state rules as `/next`.

## Labels
- **Plan sub-phase:** `optional` if its **Order** line contains the profile's optional marker, otherwise `mandatory`.
- **Fix:** `mandatory` if its batch's **Blocks.** line names a plan id, `optional` if it says `none`.
- Skip nothing silently: a REMOVED id is listed as `removed`.

## States (first match wins)
`done` (ticked in Status) · `finish` (build.md exists, test.md and review.md both `verdict: PASS` with fingerprint equal to the current one) · `QA pending` (built, a QA report is missing, FAIL, RUNNING, or stale; add which) · `blocked` (an open fixes batch blocks it) · `ready` (not built, its Order dependency is ticked) · `waiting` (dependency not ticked) · `skipped` (optional and not asked for) · `removed`.

---

## `/check` (no id): the list

If `$ARGUMENTS` is empty, print exactly this shape, one line per id, in Status order, fixes after the plan. Draw each bar 10 cells wide with `█` filled and `░` empty:

```
CHECK · <project name> · fp <fingerprint>
PLAN  ██████░░░░ 58%  7/12 done · 1 QA pending · 1 blocked
  ✅ 1    Scaffold                 mandatory   done
  🔄 2b   Settings page            mandatory   QA pending (test ✅ · review ❌ 2 blockers)
  ⛔ 3a   Scene                    mandatory   blocked by F1 (f1a open)
  ⏳ 3b   Particles                optional    waiting on 3a
  ✖  2c   –                        –           removed
FIXES ░░░░░░░░░░ 0%  0/2 done
  🟢 f1a  Header overlap           mandatory   ready (blocks 3a)
  ⏳ f1b  Copy tweaks              optional    waiting on f1a

Mandatory left: <n> · Optional left: <n> · Next: <the one command and the agent that runs it>
Detail: /check <id>
```

Icons: ✅ done · 🟢 ready or finish · 🔄 QA pending · ⛔ blocked · ⏳ waiting · ➖ skipped · ✖ removed. If there is no fixes file, leave out the FIXES block. List mandatory items first within each block only if the plan's Status order already does; otherwise keep Status order.

`Next:` follows `/next`: finish first, then QA pending, then the first ready fix, then the first ready plan sub-phase. Name the agent (`BUILD /finish 2a`, `TEST /qa-test 2b`, `GIT /commit f1a`).

---

## `/check <id>`: the detail card

`<id>` is a plan id (`2b`), a fix id (`f1a`), or a bare number or batch (`2`, `f1`: print one card per sub-phase or fix, then a one-line total). A leading `f` means a fix, read from the fixes file (`### Fix <id>`, its batch heading, sections 0–1); anything else reads the plan sub-phase section (and its amendment, if the profile names one). An unknown id: say so and list the valid ids.

Read the section, `docs/reports/<id>/build.md`, `test.md`, `review.md` (any may be missing: say so), the Decisions log entries for the id, and `git log --format="%h %s" --grep "^phase-<id>" --grep "^fix-<id>"`. Print:

```
CHECK <id> · <title>
Label:    mandatory | optional        State: <state>      Model: <model>
Order:    <Order line>                Blocks: <batch Blocks line, fixes only>
Progress: ██████░░░░ 60%  <done>/<total> deliverables

SUMMARY
  <Goal, one or two lines>

DONE (<n>)
  ✅ <deliverable> — <evidence: build.md line, file, commit>
NOT YET DONE (<n>)
  ⬜ <deliverable> — <why: not built / BLOCKED in build.md / failed in QA>

ACCEPTANCE (what TEST checks)
  ✅ T1  <acceptance line>
  ❌ T3  <acceptance line> — <symptom>
  ⏳ –   <acceptance line> — not run yet

QA
  TEST    round <n> · <PASS|FAIL|RUNNING|missing> · fingerprint <fresh|stale|missing>
  REVIEW  round <n> · <PASS|FAIL|RUNNING|missing> · fingerprint <fresh|stale|missing>
  Open findings: R1 blocker `file:line` — <one line> · R2 minor …

DETAILS
  Owns:        <n> files (<k> exist, <m> new)
  Contract:    <names later parts rely on>
  Deviations:  <from build.md, or none>
  Gaps:        <for other sub-phases, or none>
  Commits:     <hash subject>… or none yet
  Decisions:   <log entries for this id, or none>
  Docs:        <docs to write on /finish, or none>

NEXT  <exact command> — run by <BUILD|TEST|REVIEW|GIT>
```

Rules: every ✅ needs evidence you read (a report line, a file, a commit); if you could not confirm it, mark it ⬜ or ⏳, never ✅. Quote acceptance lines from the plan or fixes file, do not paraphrase them into something easier. Keep it factual: no code suggestions, no edits.
