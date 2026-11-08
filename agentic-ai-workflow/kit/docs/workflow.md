# Agentic workflow: build, test, review, git

Four Claude Code sessions work on this repo, each with one job and its own permissions. They hand work to each other through report files in `docs/reports/<id>/`, not chat. Everything project-specific (plan headings, check commands, dev servers, protected paths, models) is in `.claude/workflow/PROJECT.md`.

```
 BUILD (desktop app)          TEST (desktop app)        REVIEW (terminal 2)
 /subphase 2b ──────────────▶ /qa-test 2b               /qa-review 2b
   └ build.md                   └ test.md                 └ review.md
                                      │                         │
 any ❌ → /subphase 2b again ◀────────┴─────────────────────────┘
          (fixes the ❌ items, then QA runs again)
 both ✅ → /finish 2b   (ticks 2b, Decisions log, docs)  → /next
                                                   GIT (terminal 3): /commit 2b → /push
```

Rules of the loop:

1. A sub-phase is done only when `/finish <id>` has ticked it. `/finish` ticks only sub-phases whose `test.md` and `review.md` both say `verdict: PASS` **and** whose `fingerprint` equals the current `bash .claude/scripts/fingerprint.sh` (a content hash of the paths in `.claude/workflow/fingerprint.paths`; committing does not change it, editing code does).
2. `/subphase` and `/phase` never tick Status, write the Decisions log, or write `docs/phase-*` notes. They put a proposed Decisions entry and a suggested commit message in `build.md`.
3. BUILD does not start the next sub-phase while QA for the current one is running (they share one working tree).
4. TEST and REVIEW can run at the same time.
5. GIT commits, usually right after `/finish`. BUILD may also commit, but only when you ask it to in chat; it never commits or pushes on its own.

## Commands

Commands live in `.claude/commands/<agent>/`, so their full names are `/build:subphase`, `/test:qa-test`, `/git:commit`, … The short form (`/subphase`) works when it is unambiguous.

| Agent | Command | What it does |
|---|---|---|
| BUILD | `/setup [plan]` | Adapt the workflow to this project: fill the profile, fingerprint paths, dev servers, lint hook, protected-path denies, CLAUDE.md section. Run once after installing. |
| BUILD | `/subphase <id>` | Build one sub-phase and write `build.md`. If QA already failed it, fix the ❌ items instead. |
| BUILD | `/phase <n>` | Build every remaining sub-phase of phase n in Order. |
| BUILD | `/next` | Show where every sub-phase stands, preflight the next ready part. No edits. |
| BUILD | `/finish <id>` | Gate: test + review PASS on the current fingerprint, else refuse. Then Decisions log, docs, Status tick, `build.md` DONE. |
| TEST | `/qa-test <id\|n>` | Profile checks, then each Acceptance line (browser, CLI, or API per the profile). Writes `test.md`. |
| REVIEW | `/qa-review <id\|n>` | Static checks, Owns, contract, hard rules, correctness, hygiene. Writes `review.md`. |
| GIT | `/commit [id\|"msg"]` | Commit; with an id uses `build.md`'s suggested message and that sub-phase's files. |
| GIT | `/push` | Push the current branch (never force). |
| GIT | `/undo [n]` | Undo the last n commits: soft reset if unpushed, revert if pushed. |
| GIT | `/sync` | Fetch and fast-forward pull. |

Ids: `2b` or `2.2` for a sub-phase, `2` for a whole phase. Use `/clear` between sub-phases to keep context small.

## Starting the agents

All four run from the repo root.

### BUILD – Claude desktop app (Code tab)

Open this folder. It loads `CLAUDE.md`, `.claude/settings.json`, and `.claude/settings.local.json`. The build permissions are mirrored into `.claude/settings.local.json` (git-ignored). When you change `.claude/permissions/build.json`, copy it over:

```bash
cp .claude/permissions/build.json .claude/settings.local.json
```

That local file also loads in the TEST and REVIEW terminals; their permission files deny every write the build file allows, and a deny always wins. The GIT terminal skips it (`--setting-sources user,project`).

### TEST – Claude desktop app (second session)

Open a second Code tab session on this folder and run `/qa-test <id>` there. The command tells it to read `.claude/roles/test.md`. For web projects it starts its own dev server with `preview_start` `{name: "qa"}` (`.claude/launch.json`), checks in the built-in browser pane, and stops the server with `preview_stop`. BUILD's server is `dev`, on a different port, so the two never share one.

The desktop app cannot load `.claude/permissions/test.json`; a desktop TEST session runs with the BUILD settings. The "write only `test.md`" limit is then held by the role prompt. If you want it enforced, run TEST in a terminal instead (browser checks then use Claude in Chrome):

```bash
bash .claude/scripts/agent.sh test
```

### REVIEW – terminal 2

```bash
bash .claude/scripts/agent.sh review
```

### GIT – terminal 3

```bash
bash .claude/scripts/agent.sh git
```

From cmd or PowerShell use `.claude\scripts\agent.cmd review` (or `git`, `test`). A second argument overrides the model: `agent.sh review claude-opus-5-5`.

Name the terminal tabs `TEST`, `REVIEW`, and `GIT`.

## Reading a QA summary

Every TEST and REVIEW run ends with the same block in the terminal and at the top of its report:

```
PHASE 2b · TEST · round 1 · a1b2c3d
VERDICT: ❌ FAIL — 1 to fix

✅ Passed (6)
  ✅ T1  Build
  ...
❌ Failed — BUILD must fix (1)
  ❌ T5  Esc closes the dialog — goes back two levels

Next: BUILD runs /subphase 2b to fix the ❌ items.
```

✅ = observed and correct. ❌ = failed or could not be verified. Nothing is marked ✅ unless the agent saw it.

## Files

| File | Project-specific? | What it is |
|---|---|---|
| `.claude/workflow/PROJECT.md` | **yes** | Project profile every command reads |
| `.claude/workflow/fingerprint.paths` | **yes** | Inputs of the QA fingerprint |
| `.claude/workflow/lint-on-save.json` | **yes** | Lint command for the BUILD save hook (off by default) |
| `.claude/launch.json` | **yes** | `dev` (BUILD) and `qa` (TEST) dev servers for the desktop browser pane |
| `.claude/workflow/PLAN.template.md` | template | Plan skeleton with the sections the workflow expects |
| `.claude/workflow/CLAUDE.section.md` | template | Workflow section `/setup` appends to CLAUDE.md |
| `.claude/commands/**`, `.claude/roles/*.md` | no | Commands and role prompts |
| `.claude/permissions/*.json`, `.claude/settings.json` | partly | Generic denies; `/setup` adds the project's protected paths |
| `.claude/scripts/fingerprint.sh`, `agent.sh`, `agent.cmd` | no | Fingerprint and agent launchers |
| `.claude/hooks/lint-on-save.cjs` | no | PostToolUse hook (needs Node) |
| `docs/reports/_template/*`, `docs/reports/README.md` | no | Report templates |

## Permissions

| File | Loaded by | Summary |
|---|---|---|
| `.claude/settings.json` | everyone | read-only allows, shared denies (`.env`, `dist`, lockfiles, force-push, `git clean`, `rm -rf`, plus protected paths) |
| `.claude/permissions/build.json` (→ `settings.local.json`) | BUILD | `acceptEdits`: edits anywhere except protected paths; every shell command without asking. Asks before installs, downloads, `rm -r`, push, pull, reset, revert, rebase, merge, checkout, switch, tag, branch delete, amend. Denies force-push, `reset --hard`, `clean`, `rm -rf`, `--no-verify`, `.env` |
| `.claude/permissions/test.json` | TEST (terminal only) | `bypassPermissions`: never prompts. Deny list blocks writing anything but `docs/reports/*/test.md`, installs, lint fixes, and git writes |
| `.claude/permissions/review.json` | REVIEW | `bypassPermissions`: never prompts. Deny list blocks writing anything but `docs/reports/*/review.md`, dev/build servers, installs, lint fixes, and git writes |
| `.claude/permissions/git.json` | GIT | no file writes; git status/log/diff, add, commit, push, pull, revert, soft reset |

The TEST and REVIEW deny lists name common code folders (`src`, `app`, `lib`, `public`, `scripts`, `tests`) and root config files. If your code lives elsewhere, `/setup` adds it.
