---
description: BUILD – build one plan sub-phase and write build.md, or, if QA already failed it, fix the ❌ items. No Status tick, no commit.
argument-hint: <id>  e.g. 2b, 2.2
---

You are BUILD (`.claude/roles/build.md`). Sub-phase **$ARGUMENTS**.

Read `.claude/workflow/PROJECT.md` first. "The plan", "Status", "Decisions log", "checks", "dev server", and "protected paths" below mean what the profile says. If the profile still has a `<fill me>`, stop and tell the user to run `/build:setup`.

Do only what that sub-phase says and touch only the files under its **Owns**. Never tick Status, append to the Decisions log, write `docs/phase-*` notes, or commit here: `/finish <id>` does the first three once TEST and REVIEW both PASS, and commits happen only when the user asks. This holds even if the plan's phase Prompts say "update Status" or "commit".

## 1. Load and pick the mode
- Resolve the id per the profile's "Phase ids". Stop if invalid or marked REMOVED. An id starting with `f` is a fix: stop and point to `/fix <id>`.
- **Fixes gate.** If the fixes file exists (profile → Fixes; default `FIXES.md`), read every batch and its **Blocks.** line. If any batch still has an unticked fix in the fixes Status section and blocks this sub-phase (its Blocks id is this id or comes before it in the plan's Status order), stop and edit nothing. Print `❌ BLOCKED by FIXES.md batch <F#>: <open ids> — run /fix`. The gate applies in fix mode too, except for a sub-phase that was already built before the batch was added.
- Read `CLAUDE.md`, the plan's context section, the full sub-phase section (and its amendment if any), and the Decisions log entries for this id and its Order dependency.
- Pick the mode:
  - **build**: no `docs/reports/<id>/build.md` yet. Stop if the Order dependency is not ticked, or if it is an optional part nobody asked for.
  - **fix**: `build.md` exists and `test.md` or `review.md` has ❌ items. Go to section 3.
  - Otherwise (`build.md` exists, QA missing or passed): say so, point to `/qa-test <id>` + `/qa-review <id>` or `/finish <id>`, and stop unless the user asks for a rebuild.
- If the sub-phase names a model (profile → Models) and it differs from yours, say so once and continue unless the user stops you.

## 2. Build mode
1. Short task list from **Deliverables** and **Acceptance**; for each Owns file note new or edited, and every Hand-off contract name to add or keep.
2. Edit only Owns files. Tunables go where the plan says. If something outside Owns is required, record it as a gap in `build.md` and continue; ask the user before any Owns deviation. Install only listed dependencies, the way the profile says.
3. New pure logic gets a unit test the way the profile says. If the lint-on-save hook reports problems, fix them.
4. Run the profile's Build, Lint, and Unit tests checks; all must pass. Then check each Acceptance line the way the profile's "Behaviour checks" says, on the BUILD dev server, including the listed variants. Note what you could not check.
5. Write `docs/reports/<id>/build.md` from `docs/reports/_template/build.md`: status `READY_FOR_QA` (or `BLOCKED`), `commit: uncommitted`, `fingerprint` from `bash .claude/scripts/fingerprint.sh`, the **Proposed Decisions log entry**, **Docs to write on finish**, and **Suggested commit** `phase-<id>: <summary>`.

## 3. Fix mode
1. Collect every ❌ in `test.md` and `review.md`. Warn if a report's fingerprint differs from `build.md`'s.
2. Fix each with the smallest change inside Owns. No refactoring around it. Items outside Owns become gaps in `build.md`. If you disagree with a finding, do not change code: mark it "disputed" in `build.md` with the plan or rule citation.
3. Re-run the checks and re-check the failed Acceptance lines on the BUILD dev server.
4. Update `build.md`: status `FIXED`, new fingerprint, a row per item in "Fix rounds", and the Proposed Decisions log entry if a fix changed a decision. Suggested commit `phase-<id>-fix: <summary>`.

## 4. Report
Print the Summary block from `build.md`, then:

```
Not committed, not ticked.
Next →  TEST:    /qa-test <id>
        REVIEW:  /qa-review <id>
        both PASS → BUILD /finish <id>
```
