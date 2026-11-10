---
id: <id>
agent: test
round: 1
date: <YYYY-MM-DD>
commit: <short sha tested, plus "+ uncommitted" if the tree was dirty>
fingerprint: <bash .claude/scripts/fingerprint.sh at the start of the run>
verdict: RUNNING | PASS | FAIL   # RUNNING while checks are ⏳ (status line shows it live); never left as RUNNING
---

# Phase <id> – TEST

## Summary

```
PHASE <id> · TEST · round <n> · <commit>
VERDICT: ✅ PASS            (or)   VERDICT: ❌ FAIL — <n> to fix

Progress ▰▰▰▰▰▰▰▰▱▱  80%   12/15 checks
Passed   ▰▰▰▰▰▰▰▱▱▱  70%   10 checks
Failed   ▰▱▱▱▱▱▱▱▱▱  13%   T5, T7
Blocked  ▰▱▱▱▱▱▱▱▱▱   7%   T8 not verified

✅ Passed (<n>)
  ✅ T1  Build
  ✅ T2  Lint
  ✅ ...

❌ Failed — BUILD must fix (<n>)
  ❌ T5  <check> — <one-line symptom>

❌ Not verified (<n>)
  ❌ T8  <check> — not verified: <reason>

Next: <"BUILD runs /subphase <id> to fix" | "test gate passed" | what the user must do>
```

## Checks

| # | Check | Source | Result | Evidence |
|---|---|---|---|---|
| T1 | Build (`<profile command>`) | static | ✅ | exit 0, <time> |
| T2 | Lint (`<profile command>`) | static | ✅ | 0 problems |
| T3 | Extra (`<profile command>`) | static | ✅ | |
| T4 | Unit tests (`<profile command>`) | static | ✅ | 10/10 |
| T5 | <Acceptance line, verbatim or close> | Acceptance | ❌ | <what you observed> |

Source is one of: `static`, `Acceptance`, `regression`. Result is ✅, ❌, or ⏳ (not run yet, only while `verdict: RUNNING`). A ❌ whose Evidence says `not verified` counts as Blocked. Keep these row and column shapes: the status line parses them.

## Failures

### T5 – <check>

- **Steps:** 1. … 2. … 3. …
- **Expected:** …
- **Actual:** …
- **Likely area:** `<path>` (one line, no patch)

## Not covered

What this pass did not check and why (no browser tools, needs a real device, etc.).
