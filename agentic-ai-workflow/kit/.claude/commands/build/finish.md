---
description: BUILD – finish a sub-phase after TEST and REVIEW both PASS - Decisions log, docs, Status tick. Refuses otherwise.
argument-hint: <id>  e.g. 2b, 2.2
---

You are BUILD. Finish sub-phase **$ARGUMENTS**. Read `.claude/workflow/PROJECT.md` first.

This is the **only** command that ticks a Status box in the plan, appends a sub-phase's Decisions log entry, and writes its `docs/` notes. It never commits or pushes.

## 1. Gate (refuse unless every check is ✅)

Resolve the id per the profile's "Phase ids". A whole phase (`2`) is not accepted unless it is itself a sub-phase: finish each sub-phase on its own. Then check:

| # | Check | How |
|---|---|---|
| G1 | id is a live sub-phase | its heading exists and is not marked REMOVED |
| G2 | not already finished | its Status line is `- [ ]` |
| G3 | build handed off | `docs/reports/<id>/build.md` exists, `status` is `READY_FOR_QA` or `FIXED` |
| G4 | TEST passed | `docs/reports/<id>/test.md` front matter `verdict: PASS` |
| G5 | REVIEW passed | `docs/reports/<id>/review.md` front matter `verdict: PASS` |
| G6 | not stale | `bash .claude/scripts/fingerprint.sh` equals the `fingerprint` in **both** test.md and review.md |
| G7 | nothing open | test.md has no ❌ under "Failed" or "Not verified"; review.md has no ❌ under "Blockers" or "Minor" |
| G8 | dependency finished | the sub-phase its **Order** line depends on is ticked (or REMOVED / skipped optional) |

**Legacy sub-phases** (built before this workflow was installed, with a Decisions log entry but no `build.md`): G3 is met by that existing entry. In step 2 append only `- <date>: Phase <id> passed QA (test r<n>, review r<n>, fingerprint <hash>).` plus anything QA fixes changed. Create a minimal `build.md` with `status: DONE` in step 4.

If any check fails, **stop and edit nothing.** Print:

```
FINISH <id> · ❌ REFUSED
  ✅ G3  build.md READY_FOR_QA
  ❌ G4  test.md verdict FAIL (round 2) — run /subphase <id> to fix, then /qa-test <id>
  ❌ G6  review.md fingerprint 1a2b3c4d5e6f ≠ current 9f8e7d6c5b4a — code changed after review; rerun /qa-review <id>
```

Never tick, log, or document a sub-phase that did not pass, even when the user asks. Explain the gate and name the missing QA.

## 2. Decisions log

Append one entry at the end of the plan's Decisions log, in the style of existing entries: `- <YYYY-MM-DD>: Phase <id>. …`. Build it from `build.md`'s "Proposed Decisions log entry", updated with fix-round changes and disputed items, citing the test/review rounds and fingerprint. Do not edit any other plan text.

## 3. Docs

If the sub-phase made something a later agent or person needs that does not fit in the Decisions log (a technique, a procedure, tuning notes), write `docs/phase-<id>-<topic>.md` in the style of existing `docs/phase-*` notes. Otherwise write none.

## 4. Tick and close

- Tick the sub-phase in the Status section: `- [ ]` → `- [x]`, and drop any "unticked until …" note on that line.
- In `docs/reports/<id>/build.md` set `status: DONE` and add `finished: <YYYY-MM-DD>`.
- `git diff -- <plan file>` must show only the tick and the appended entry.

## 5. Report

```
FINISH <id> · ✅ DONE
  ✅ Gate      test r<n> PASS · review r<n> PASS · fingerprint <hash>
  ✅ Status    [x] Phase <id> – …
  ✅ Decisions appended
  ✅ Docs      docs/phase-<id>-<topic>.md   (or "none needed")

Not committed. Next →  GIT: /commit <id>   then BUILD: /next
```
