# <Project name> – <one-line product>

> Single source of truth for this project. Each sub-phase is built in a fresh chat by BUILD (`/subphase <id>`), checked by TEST and REVIEW, and finished by `/finish <id>`.
> Ticking Status, writing the Decisions log, and committing never happen during a build: only `/finish <id>` ticks and logs (after TEST and REVIEW both PASS), and the GIT agent commits.

---

## 0. Project context (read this first in every chat)

**Product.** <what it is, who it is for, the core flow>

**Stack.** <languages, frameworks, libraries. Do not add a library that duplicates one listed here.>

**Current repo state.** <what exists today>

**Hard rules for every phase** (REVIEW checks these)

1. <e.g. Tunables live in `src/config/`; no magic numbers in components.>
2. <e.g. Data lives in `src/data/` and is typed in `src/types/`; nothing hardcoded.>
3. <e.g. Clean up every listener, timer, and subscription you create.>
4. <…>

## 1. Experience / feature flow

<the user journey or system flow, step by step>

## 2. Target file structure

```
src/
  ...
```

## 3. Data schemas

<types, JSON shapes, API contracts>

## 4. Technical notes

<algorithms, techniques, constraints that several phases share>

## 5. Phases

Each sub-phase lists **Order**, **Goal**, **Owns**, **Deliverables**, **Hand-off contract**, **Acceptance**, and a **Prompt**. Ids are `<number><letter>` (`2a`, `2b`); a phase with one part can be just a number (`1`). Mark a dropped part `### Phase 2c – REMOVED (was: …)` instead of deleting it.

### Phase 1 – <title> (<model>)

**Order.** first

**Goal.** <one paragraph: what changes for the user>

**Owns.** `<path>`; `<path>` (<what in it>); …  — the only files this part may touch.

**Deliverables**

- <concrete file or behaviour>
- <…>

**Hand-off contract.** <names, fields, functions, events later parts rely on. Do not rename them.>

**Acceptance.** <observable checks, one per sentence. TEST turns each into one check, so make each one something you can see or run.>

**Prompt.** "Read PLAN.md. We are in Phase 1. Do only what that sub-phase says. Touch only the files under its Owns. <task specifics>."

---

### Phase 2a – <title> (<model>)

**Order.** after 1

**Goal.** …

**Owns.** …

**Deliverables**

- …

**Hand-off contract.** …

**Acceptance.** …

**Prompt.** "…"

---

### Phase 2b – <title> (<model>)

**Order.** optional, only if 2a asks

…

## 6. Backlog (post-MVP)

- <ideas not scheduled yet>

## 7. Model routing

- **<strongest model>:** <hardest parts: algorithms, shaders, tricky math>
- **<architecture model>:** <state, data flow, integration>
- **<fast model>:** <UI, config values, docs, cleanup>

## 8. Status

- [ ] Phase 1 – <title>
- [ ] Phase 2a – <title>
- [ ] Phase 2b – <title> (optional)

## 9. Decisions log

Append only. One entry per decision or finished sub-phase: `- <YYYY-MM-DD>: Phase <id>. <what was decided or changed, and why>.`

- <YYYY-MM-DD>: Plan created.

## 10. Agentic workflow

BUILD / TEST / REVIEW / GIT loop, see `docs/workflow.md`. Project profile: `.claude/workflow/PROJECT.md`.
