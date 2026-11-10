---
id: <id>
agent: review
round: 1
date: <YYYY-MM-DD>
range: <first sha>^..<last sha> (+ uncommitted)
fingerprint: <bash .claude/scripts/fingerprint.sh at the start of the run>
verdict: RUNNING | PASS | FAIL   # RUNNING while areas are ⏳ (status line shows it live); never left as RUNNING
---

# Phase <id> – REVIEW

## Summary

```
PHASE <id> · REVIEW · round <n> · <range>
VERDICT: ✅ PASS            (or)   VERDICT: ❌ FAIL — <b> blockers, <m> minor

Progress 🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩 100%   10/10 areas
Passed   🟩🟩🟩🟩🟩🟩🟩⬜⬜⬜  70%   7 areas clean
Blockers 🟥🟥⬜⬜⬜⬜⬜⬜⬜⬜  20%   R1 R2
Minor    🟨⬜⬜⬜⬜⬜⬜⬜⬜⬜  10%   R3

✅ Passed (<n>)
  ✅ Lint
  ✅ Type-check
  ✅ Unit tests
  ✅ Owns — all <n> files inside Owns
  ✅ Hand-off contract
  ✅ Hard rules
  ✅ .claude/rules
  ✅ Dependencies
  ✅ Plan hygiene (no early tick or Decisions entry; proposed entry and commit message in build.md)
  ✅ Repo hygiene (no protected paths, secrets, debug logging)

❌ Blockers — BUILD must fix (<n>)
  ❌ R1  <path>:42 — <rule> — <one line>

❌ Minor — BUILD should fix (<n>)
  ❌ R4  <path>:10 — <rule> — <one line>

Next: <"BUILD runs /subphase <id> to fix" | "review gate passed">
```

## Findings

| # | Severity | Where | Rule / contract | Problem | Fix direction |
|---|---|---|---|---|---|
| R1 | blocker | `<path>:42` | Hard rule 3 | <what is wrong and why it matters> | <one line> |

## Checklist

| Area | Result | Notes |
|---|---|---|
| Lint | ✅ | |
| Type-check | ✅ | |
| Unit tests | ✅ | |
| Owns | ✅ | |
| Hand-off contract | ✅ | |
| Hard rules | ✅ | |
| `.claude/rules` | ✅ | |
| Dependencies | ✅ | |
| Plan hygiene | ✅ | |
| Repo hygiene | ✅ | |

Checklist Result is ✅, ❌, or ⏳ (not checked yet, only while `verdict: RUNNING`). Keep the Findings and Checklist row shapes: the status line parses them. Bar percentages are of the checklist's area count.

## Notes

Non-blocking observations. Not counted as ❌.
