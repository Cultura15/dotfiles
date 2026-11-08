# Workflow project profile

Every workflow command (BUILD, TEST, REVIEW, GIT) reads this file first. It is the only place that knows about this project. The commands and roles stay generic.

Fill it with `/build:setup` (it reads your plan, CLAUDE.md, and package files and proposes values), or by hand. Replace every `<fill me>`. Write `none` for anything the project does not have. Commands refuse to run while a `<fill me>` is left.

## Project

- **Name:** <fill me>
- **One line:** <fill me — what the project is>
- **Shell:** <fill me — e.g. Git Bash on Windows, forward slashes>

## Plan

- **Plan file:** `PLAN.md`
- **Context section** (read before any work): <fill me — e.g. `## 0. Project context`>
- **Hard rules** (REVIEW checks them): <fill me — e.g. "section 0, Hard rules 1–6">
- **Sub-phase heading:** `### Phase <id> – <title>` <adjust if your plan differs>
- **Sub-phase fields:** `**Order.**`, `**Owns.**`, `**Deliverables**`, `**Hand-off contract.**`, `**Acceptance.**` <adjust names; write "missing" for any your plan does not use>
- **Removed marker:** a heading containing `REMOVED`
- **Optional marker:** an Order line containing `optional`
- **Amendments:** <fill me — e.g. "section 12 may amend a sub-phase; read it too", or none>
- **Status section:** <fill me — e.g. `## 8. Status`> (one `- [ ] Phase <id> – …` line per sub-phase)
- **Decisions log section:** <fill me — e.g. `## 9. Decisions log`> (entries: `- <YYYY-MM-DD>: Phase <id>. …`)
- **Model routing section:** <fill me — e.g. `## 7. Model routing`, or none>
- **Append-only:** the original plan text never changes unless the user asks in chat. Only `/finish` appends Decisions entries and ticks Status.

## Phase ids

- Sub-phase ids are the ids in the plan headings: `<fill me — e.g. 0, 1, 2a, 2b, 3a>`.
- Dotted form maps by letter position: `2.1` → `2a`, `2.2` → `2b`.
- A bare number (`2`) means the whole phase: every sub-phase whose id starts with that number, in Order.
- A phase without letters (`1`) is itself a sub-phase.

## Checks

The commands BUILD, TEST, and REVIEW run. Write `none` to skip one.

| Check | Command | Who runs it |
|---|---|---|
| Build | <fill me — e.g. `npm run build`> | BUILD, TEST |
| Lint | <fill me — e.g. `npm run lint`> | BUILD, TEST, REVIEW |
| Type-check | <fill me — e.g. `npx tsc --noEmit`, or none> | REVIEW |
| Unit tests | <fill me — e.g. `npm test`> | BUILD, TEST, REVIEW |
| Extra | <fill me — e.g. `npm run validate:data`, or none> | TEST |

- **Unit tests for new pure logic:** <fill me — e.g. "vitest file beside it: `src/<path>/<name>.test.ts`", or none>
- **Lint fix flag REVIEW/TEST must never use:** `--fix`
- **Package install:** <fill me — e.g. `npm install <pkg> --legacy-peer-deps`>. Install only what the sub-phase lists.

## Behaviour checks (TEST)

- **Kind:** <fill me — `browser` (web app), `cli` (run commands), `api` (HTTP calls), or `none`>
- **BUILD dev server:** <fill me — e.g. `preview_start {name: "dev"}`, port 5173>
- **TEST dev server:** <fill me — e.g. `preview_start {name: "qa"}`, port 5174; terminal fallback `npm run dev -- --port 5174 --strictPort`>
- **Variants to check:** <fill me — e.g. `?tier=low` always, `?tier=high` for visual lines; or none>
- **Regression smoke:** <fill me — e.g. routes `/` and `/about` load with no console errors>
- **Do not run:** <fill me — slow or destructive scripts TEST must skip, e.g. `npm run bake:assets`; or none>

## Paths

- **Code** (what BUILD writes): <fill me — e.g. `src/`, `public/`>
- **Never edit, serve, import, or stage:** <fill me — e.g. `art-source/`, `dist/`, `.env*`>
- **Never edit by hand:** <fill me — e.g. `node_modules/`, `package-lock.json`>
- **Fingerprint inputs:** `.claude/workflow/fingerprint.paths`
- **Reports:** `docs/reports/<id>/{build,test,review}.md`, templates in `docs/reports/_template/`
- **Finish notes:** `docs/phase-<id>-<topic>.md`, only when needed

## Review rules

What REVIEW checks besides the hard rules, in priority order:

1. Correctness bugs in the diff.
2. The sub-phase's Owns, Hand-off contract, and Deliverables.
3. The plan's hard rules.
4. `.claude/rules/*.md`, if the project has any.
5. Hygiene: no early tick or Decisions entry, `build.md` complete, nothing protected tracked, no secrets, no debug logging, no absolute personal paths in code.

**Project-specific bug patterns to look for:** <fill me — e.g. "missing effect cleanup, listeners never removed, allocation inside render loops"; or none>

## Commits

- Sub-phase finished: `phase-<id>: <summary>`
- Fix round checkpoint: `phase-<id>-fix: <summary>`
- Other: `docs:`, `chore:`, `qa:`, `plan:`
- Branch: <fill me — e.g. work on `main`, push to `origin`>

## Models

| Work | Model |
|---|---|
| <fill me — e.g. shaders / hard algorithms> | <fill me — e.g. Fable 5.1> |
| <fill me — e.g. architecture, state, scene> | <fill me — e.g. Opus 5.5> |
| <fill me — e.g. UI, config, cleanup> | <fill me — e.g. Sonnet 5.5> |
| TEST, REVIEW | Sonnet 5.5 (Opus 5.5 to review the hardest parts) |
| GIT | Sonnet 5.5 |
