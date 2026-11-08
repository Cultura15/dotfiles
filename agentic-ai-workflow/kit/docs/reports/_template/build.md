---
id: <id>
agent: build
round: 1
date: <YYYY-MM-DD>
commit: <short sha, or "uncommitted">
fingerprint: <bash .claude/scripts/fingerprint.sh>
model: <model that built it>
status: READY_FOR_QA | BLOCKED | FIXED | DONE   # DONE is set only by /finish
---

# Phase <id> – BUILD

## Summary

```
PHASE <id> · BUILD · round <n> · <commit>
STATUS: ✅ READY FOR QA      (or)   ❌ BLOCKED — <reason>

✅ Done (<n>)
  ✅ <deliverable>
  ✅ Build check
  ✅ Lint check

❌ Not done / blocked (<n>)
  ❌ <deliverable or acceptance line> — <why>

Next: run /qa-test <id> and /qa-review <id>
```

## Files changed

| File | Owns? | What changed |
|---|---|---|

## Deviations from the plan

Each one also goes into the Proposed Decisions log entry below. "None" if none.

## Gaps for other sub-phases

Missing fields, props, functions, endpoints, or mounts another sub-phase must add.

## How to verify

Routes, commands, steps, and parameters QA should use for each Acceptance line.

## Proposed Decisions log entry

`/finish` appends this to the plan's Decisions log once TEST and REVIEW both PASS. Do not write it to the plan yourself.

```
- <YYYY-MM-DD>: Phase <id>. …
```

## Docs to write on /finish

`docs/phase-<id>-<topic>.md` topics, or "none".

## Suggested commit

For the GIT agent: `phase-<id>: <summary>` (fix rounds: `phase-<id>-fix: <summary>`).

## Fix rounds

| Round | QA item | Fix | Fingerprint |
|---|---|---|---|
