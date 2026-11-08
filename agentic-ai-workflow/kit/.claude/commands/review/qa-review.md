---
description: REVIEW – review a sub-phase (or whole phase) diff. Writes docs/reports/<id>/review.md.
argument-hint: <id|n>  e.g. 2b, 2.2, 2
---

You are REVIEW (see `.claude/roles/review.md`). Read `.claude/workflow/PROJECT.md` first. Review **$ARGUMENTS**. Never edit code. Do every check yourself in this session; do not spawn subagents or call other commands.

## 1. Scope
- Resolve the id per the profile's "Phase ids". A bare number reviews every built sub-phase of that phase; report to `docs/reports/<n>/review.md`.
- Diff = commits from `git log --format="%h %s" --grep "^phase-<id>"` plus uncommitted work (`git status --porcelain`, `git diff`). BUILD does not commit, so it is often all uncommitted. Record the range and `bash .claude/scripts/fingerprint.sh` as `fingerprint`.
- Read the sub-phase section (Owns, Hand-off contract, Deliverables; plus its amendment if any), `docs/reports/<id>/build.md`, and the previous `review.md` if any (round n+1: re-check earlier ❌ first).

## 2. Checks
a. **Static**: the profile's Lint, Type-check, and Unit tests checks (skip any marked `none`; never with a fix flag). An error in a changed file or a failing test is a blocker. New pure logic without the unit test the profile asks for is minor.
b. **Owns and contract**: every changed file is in Owns (test files beside new logic are fine), or listed as a deviation in `build.md`. Contract names from the Hand-off contract exist and were not renamed. No new dependency that the sub-phase does not list.
c. **Rules**: changed files follow the plan's hard rules and `.claude/rules/*.md`.
d. **Correctness**: read the diff for real bugs: wrong conditions, off-by-one, unhandled errors or null, stale closures, missing cleanup, listeners or timers never removed, races, plus the profile's project-specific bug patterns.
e. **Hygiene**: the plan's Status not ticked and no Decisions log entry for this id yet; `build.md` has a "Proposed Decisions log entry" and a "Suggested commit"; no protected path tracked; no secrets, stray debug logging, or absolute personal paths in code.

## 3. Report
- Number findings R1, R2, … (blockers first): severity, `file:line`, rule or contract, problem, one-line fix direction.
- `mkdir -p docs/reports/<id>`, write `docs/reports/<id>/review.md` from `docs/reports/_template/review.md`. `verdict: PASS` only with no blockers and no minor findings.
- Print the Summary block from the report, then:
  - all ✅ → `Next: review passed for <id>. When TEST also passes, BUILD runs /finish <id>.`
  - any ❌ → `Next: BUILD runs /subphase <id> to fix the ❌ items.`
