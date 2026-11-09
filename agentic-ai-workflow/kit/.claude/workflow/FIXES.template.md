# <Project name> – Immediate fixes and changes

> `PLAN.md` is the main plan. This file holds **immediate fixes and changes** the user asks for between phases. It uses
> the same format as the plan's sub-phases (Model, Order, Goal, Owns, Deliverables, Hand-off contract, Acceptance, Prompt)
> and the same QA loop. Start every fix chat with:
> `Read the plan's context section and FIXES.md sections 0–1. We are on fix <id>. Do only what that fix says. Touch only the files under its "Owns".`
>
> Ticks, Decisions log entries, and `docs/fix-*` notes are written only by `/finish <id>`, and only after TEST
> and REVIEW both PASS. Commits are made by the GIT agent.

---

## 0. Context and precedence (read this first in every fix chat)

- The plan's context section and hard rules apply to every fix unchanged.
- **Precedence.** Where a fix in this file and a plan spec disagree, the fix wins for the files and behaviour it touches. Everything else in the plan stays as written.
- **Blocking.** Each batch has a **Blocks.** line naming a plan sub-phase. That sub-phase, and every sub-phase after it in the plan's Status order, cannot be built (`/subphase`, `/phase`) until every fix of the batch is ticked in section 3 below. Write `none` if a batch blocks nothing.
- **IDs.** Fix ids start with `f`: `f<batch><letter>` (`f1a`, `f1b`, `f2a`, …). A bare `f1` means every fix of batch F1 in Order. Plan ids never start with `f`, so commands tell them apart by the leading `f`. Reports go in `docs/reports/<id>/`. Commit messages are `fix-<id>: <summary>` (and `fix-<id>-fix: <summary>` for a fix round).
- <project-wide notes that apply to every fix, e.g. a new UI theme that replaces the plan's palette from batch F2 on; or delete this line>

## 1. How fixes run

Same loop as the plan's sub-phases, with `/fix` in place of `/subphase`:

```
/fix f1a  →  /qa-test f1a  +  /qa-review f1a   (in parallel)
any ❌    →  /fix f1a again (fixes the ❌ items)  →  QA again
both ✅   →  /finish f1a  (ticks section 3 here, Decisions log here, docs)  →  GIT /commit f1a
```

- `/fix` with no id shows this file's board and preflights the next ready fix.
- `/next` lists open fixes above the plan board and recommends them first.
- `/subphase` and `/phase` refuse a plan sub-phase while a batch that blocks it is open.
- Writing to this file is append-only. Sections 0–2 change only when the user asks in chat; section 3 ticks and section 4 entries come only from `/finish`. New batches are appended at the end of section 2 when the user asks for new fixes.

## 2. Batches

### Batch F1 – <Fixes|Changes>: <short title> (requested <YYYY-MM-DD>)

**Blocks.** `<plan id>` (and everything after it in the plan's Status).

**Order.** <e.g. f1a and f1b do not depend on each other; build f1a, then f1b.>

---

### Fix f1a – <title> (<model>)

**Order.** <first in F1 · after f1a · after batch F1>

**Problem.** <what is wrong today, with the values, files, or behaviour that cause it>

**Goal.** <the result in one or two sentences>

**Owns.** <the only files this fix may touch; say "values only" where only config values change>

**Deliverables**

- <concrete change 1>
- <concrete change 2>

**Hand-off contract.** <names, props, uniforms, store actions, routes that must stay or be added; "No store, route, or type changes" if none>

**Acceptance.** <observable checks TEST runs: routes, viewport sizes, variants, "no console errors">

**Prompt.** "Read the plan's context section and FIXES.md sections 0–2, then fix f1a. Touch only its Owns. <one-line instruction>."

---

## 3. Status

Ticked only by `/finish <id>` after TEST and REVIEW both PASS.

**Batch F1 – <fixes|changes> – blocks <plan id>**

- [ ] Fix f1a – <title> (<model>)

## 4. Decisions log

Append only. One entry per decision or finished fix: `- <YYYY-MM-DD>: Fix <id>. <what was decided or changed, and why>.`

- <YYYY-MM-DD>: FIXES.md created for immediate fixes between phases. Batch F1 blocks plan <id>.
