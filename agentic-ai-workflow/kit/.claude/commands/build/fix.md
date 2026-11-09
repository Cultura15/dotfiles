---
description: BUILD – immediate fixes from the fixes file (FIXES.md). No id → fixes board + preflight. With an id → build that fix, or fix its QA ❌ items. No tick, no commit.
argument-hint: [<id>]  e.g. f1a, f2b, f1
---

You are BUILD (`.claude/roles/build.md`). This command works on the **fixes file** (immediate fixes and changes between phases), not on the plan's phases. Argument: **$ARGUMENTS**.

Read `.claude/workflow/PROJECT.md` first. "The plan", "checks", "dev server", and "protected paths" mean what the profile says. The fixes file and its section headings come from the profile's **Fixes** section; if the profile has none, use `FIXES.md` with the layout of `.claude/workflow/FIXES.template.md` (0 Context and precedence · 1 How fixes run · 2 Batches · 3 Status · 4 Decisions log). If the profile still has a `<fill me>`, stop and tell the user to run `/build:setup`.

If the fixes file does not exist: say there are no fixes, offer to create it from `.claude/workflow/FIXES.template.md` when the user describes fixes they want, and stop.

Never tick the fixes file's Status, append to its Decisions log, write `docs/fix-*` notes, or commit here: `/finish <id>` does the first three once TEST and REVIEW both PASS, and commits happen only when the user asks.

## 0. Resolve
- Fix ids start with `f`: `f<batch><letter>` (`f1a`). A bare batch (`f1`) builds every unticked, unbuilt fix of that batch in its **Order**, one after another, like `/phase`. Stop if the id has no `### Fix <id>` heading in the fixes file.
- Read `CLAUDE.md`, the plan's context section, the fixes file's sections 0–1, the batch heading (Blocks, Order, any shared notes), the full `### Fix <id>` section, and the fixes Decisions log entries for this id and the fix it depends on.
- If the fix names a model (in its heading, routed per profile → Models) and it differs from yours, say so once and continue unless the user stops you.

## 1. No id: board and preflight (no edits)
Run `bash .claude/scripts/fingerprint.sh` once. For every unticked fix in the fixes Status section, in order, classify it exactly like `/next` does (finish / QA pending / ready / waiting), using `docs/reports/<id>/`. Print:

```
FIXES
  F1 – blocks 3a   (1/2 ticked)
  ✅ Finish:     f1a – both QA PASS → /finish f1a
  ✅ Ready:      f1b – <title> (<model>)
  F2 – blocks 3a   (0/3 ticked)
  ❌ Waiting:    f2a – needs batch F1
Plan blocked from: 3a
```

Then preflight the first **ready** fix in the same `PREFLIGHT` format as `/next`, and end with "Run `/fix <id>`?". If something can be finished or QA is pending, recommend that first and stop.

## 2. With an id: pick the mode
- **build**: no `docs/reports/<id>/build.md` yet. Stop if the fix (or batch) its **Order** line depends on is not ticked.
- **fix**: `build.md` exists and `test.md` or `review.md` has ❌ items. Go to section 4.
- Otherwise (`build.md` exists, QA missing or passed): say so, point to `/qa-test <id>` + `/qa-review <id>` or `/finish <id>`, and stop unless the user asks for a rebuild.

## 3. Build mode
1. Short task list from **Deliverables** and **Acceptance**; for each Owns file note new or edited, and every Hand-off contract name to add or keep.
2. Edit only Owns files. If something outside Owns is required, record it as a gap in `build.md` and continue; ask the user before any Owns deviation. Install only what the fix lists, the way the profile says.
3. New pure logic gets a unit test the way the profile says. If the lint-on-save hook reports problems, fix them.
4. Run the profile's Build, Lint, Unit tests (and Extra, if the fix touches what it checks); all must pass. Then check each Acceptance line the way the profile's "Behaviour checks" says, on the BUILD dev server, including the listed variants. Note what you could not check.
5. Write `docs/reports/<id>/build.md` from `docs/reports/_template/build.md`: title "Fix <id>", status `READY_FOR_QA` (or `BLOCKED`), `commit: uncommitted`, `fingerprint`, the **Proposed Decisions log entry** (for the fixes file's Decisions log), **Docs to write on finish** (`docs/fix-<id>-<topic>.md` or none), and **Suggested commit** `fix-<id>: <summary>`.

## 4. Fix mode
Same as `/subphase` section 3: fix each ❌ with the smallest change inside Owns, mark disagreements "disputed" with a citation, re-run the checks and the failed Acceptance lines, set status `FIXED`, add a "Fix rounds" row per item, and suggest `fix-<id>-fix: <summary>`.

## 5. Adding new fixes (only when the user asks in chat)
Append a new batch at the end of the fixes file's Batches section in the template's format (`### Batch F<n> – …` with **Blocks.** and **Order.**, then one `### Fix f<n><letter> – <title> (<model>)` per fix with Order, Problem, Goal, Owns, Deliverables, Hand-off contract, Acceptance, Prompt), and add its unticked lines to the fixes Status section. Show the batch to the user before building anything. Never rewrite existing batches unless the user asks.

## 6. Report
Print the Summary block from `build.md`, then:

```
Not committed, not ticked.
Next →  TEST:    /qa-test <id>
        REVIEW:  /qa-review <id>
        both PASS → BUILD /finish <id>
```
