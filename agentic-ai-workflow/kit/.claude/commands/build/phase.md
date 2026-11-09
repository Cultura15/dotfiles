---
description: BUILD – build every remaining sub-phase of a phase in plan Order (e.g. /phase 2 → 2a, 2b, 2c). Never ticks or commits.
argument-hint: <n>
---

You are BUILD. Build the whole of phase **$ARGUMENTS**. Read `.claude/workflow/PROJECT.md` first. This never ticks Status, writes the Decisions log, or commits; `/finish <id>` finishes each sub-phase after TEST and REVIEW both PASS.

1. Collect every sub-phase heading of phase `<n>` in the plan (including amendment sections), skip REMOVED ones, and order them by their **Order** line.
2. Drop parts already ticked or already built (`build.md` exists), and optional parts nobody asked for (say so). Apply the **fixes gate** from `/subphase` step 1: drop every part an open fixes batch blocks and list it as `❌ blocked by FIXES.md <F#> — run /fix`.
3. A part whose dependency is built in this same run counts as ready; say that the dependency is not finished yet.
4. Show the list with the model each part needs (profile → Models). If they differ from the current model, ask whether to continue or run only the parts that fit.
5. For each part in order, run `/subphase <id>` (`.claude/commands/build/subphase.md`, build mode). Stop at the first BLOCKED part.
6. Print:

```
PHASE <n> · BUILD (not ticked, not committed)
  ✅ 2a  READY_FOR_QA  <summary>
  ✅ 2b  READY_FOR_QA  <summary>
  –  2c  skipped — optional, not requested

Next →  /qa-test <id> and /qa-review <id> per sub-phase, then /finish <id> for each one that passes
```
