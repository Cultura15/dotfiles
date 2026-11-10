---
description: REVIEW – review a sub-phase (or whole phase) diff. Writes docs/reports/<id>/review.md.
argument-hint: <id|n>  e.g. 2b, 2.2, 2
---

You are REVIEW (see `.claude/roles/review.md`). Read `.claude/workflow/PROJECT.md` first. Review **$ARGUMENTS**. Never edit code. Do every check yourself in this session; do not spawn subagents or call other commands.

## 1. Scope
- Resolve the id per the profile's "Phase ids". A bare number reviews every built sub-phase of that phase; report to `docs/reports/<n>/review.md`.
- Diff = commits from `git log --format="%h %s" --grep "^phase-<id>"` plus uncommitted work (`git status --porcelain`, `git diff`). BUILD does not commit, so it is often all uncommitted. Record the range and `bash .claude/scripts/fingerprint.sh` as `fingerprint`.
- Read the sub-phase section (Owns, Hand-off contract, Deliverables; plus its amendment if any), `docs/reports/<id>/build.md`, and the previous `review.md` if any (round n+1: re-check earlier ❌ first).
- **Fix ids** (`f1a`, …; a bare `f1` = every built fix of batch F1): read `### Fix <id>` in the fixes file (profile → Fixes; default `FIXES.md`), plus its batch heading and sections 0–1, instead of the plan; commits are found with `--grep "^fix-<id>"`; in hygiene check that the fixes Status is not ticked and its Decisions log has no entry for the id yet. The fixes file's precedence rule applies: the fix wins over the plan for what it touches. The fix-round hint at the end becomes `/fix <id>`.

## 1b. Live progress (drives the status line)
Your terminal status line reads `docs/reports/<id>/review.md`. Right after Scope, before the checks, write the report skeleton: frontmatter with `verdict: RUNNING`, and the Checklist table with every area as `| <area> | ⏳ | |`. After each check group (a to e) replace its ⏳ with ✅ or ❌, and add each finding to the Findings table (`| R<n> | blocker|minor | … |`) as soon as you find it. At the end no ⏳ may remain and `verdict` is PASS or FAIL. `/finish` only accepts `verdict: PASS`, so RUNNING never counts as a pass.

## 2. Checks
a. **Static**: the profile's Lint, Type-check, and Unit tests checks (skip any marked `none`; never with a fix flag). An error in a changed file or a failing test is a blocker. New pure logic without the unit test the profile asks for is minor.
b. **Owns and contract**: every changed file is in Owns (test files beside new logic are fine), or listed as a deviation in `build.md`. Contract names from the Hand-off contract exist and were not renamed. No new dependency that the sub-phase does not list.
c. **Rules**: changed files follow the plan's hard rules and `.claude/rules/*.md`.
d. **Correctness**: read the diff for real bugs: wrong conditions, off-by-one, unhandled errors or null, stale closures, missing cleanup, listeners or timers never removed, races, plus the profile's project-specific bug patterns.
e. **Hygiene**: the plan's Status not ticked and no Decisions log entry for this id yet; `build.md` has a "Proposed Decisions log entry" and a "Suggested commit"; no protected path tracked; no secrets, stray debug logging, or absolute personal paths in code.

## 3. Report
- Number findings R1, R2, … (blockers first): severity, `file:line`, rule or contract, problem, one-line fix direction.
- `mkdir -p docs/reports/<id>`, write `docs/reports/<id>/review.md` from `docs/reports/_template/review.md`. `verdict: PASS` only with no blockers and no minor findings.
- Fill the Summary's four bars (Progress, Passed, Blockers, Minor) with the final percentages, 10 cells of 🟩/🟥/🟨/⬜.
- Print the Summary block from the report, then:
  - all ✅ → `Next: review passed for <id>. When TEST also passes, BUILD runs /finish <id>.`
  - any ❌ → `Next: BUILD runs /subphase <id> to fix the ❌ items.` (for a fix id: `/fix <id>`)
