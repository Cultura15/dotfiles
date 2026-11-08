---
description: BUILD – show where every sub-phase stands, then preflight the next one that is ready. No edits.
---

You are BUILD. Read `.claude/workflow/PROJECT.md` first. Do not edit any file and do not tick anything (only `/finish <id>` ticks).

## 1. Board
Read the plan's Status section and each sub-phase's **Order** line (skip REMOVED ids). Run `bash .claude/scripts/fingerprint.sh` once. For every unticked sub-phase, in Status order, decide:
- **finish**: `build.md` exists, and `test.md` and `review.md` both say `verdict: PASS` with no ❌ and a `fingerprint` equal to the current one → needs `/finish <id>`
- **QA pending**: built, but a QA report is missing, FAIL, or stale (fingerprint differs)
- **ready**: not built, and its Order dependency is ticked
- **waiting**: dependency not ticked · **skipped**: optional and not asked for

Print:

```
NEXT
  ✅ Finish:     2a – both QA PASS → /finish 2a
  ❌ QA pending: 2b (test missing, review FAIL)
  ✅ Ready:      3a – <title> (<model>)
  ❌ Waiting:    3b – needs 3a
  –  Skipped:    2c · Removed: 1b
```

## 2. Preflight
If something can be finished, recommend `/finish <id>` first and stop. If QA is pending, recommend finishing it before new work and stop. Otherwise, for the first **ready** sub-phase, read its section, check which Owns files exist today, and print:

```
PREFLIGHT <id> – <title>
Model:      <from profile → Models>  (current: <you>)
Owns:       <n> files (<k> exist, <m> new)
Contract:   <fields/functions to add or keep>
Risks:      <top 3, one line each>
Acceptance: <numbered — what TEST will check>
```

End with: "Run `/subphase <id>`?"
