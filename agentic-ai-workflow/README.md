# AI workflow kit (BUILD · TEST · REVIEW · GIT)

A portable copy of the four-agent Claude Code workflow: plan-driven sub-phases, a QA gate with a code fingerprint, report hand-offs, and a git-only agent. Drop it into any project that has (or will have) a phased `PLAN.md`.

```
ai-workflow-kit/
  install.sh          copies kit/ into a project (never overwrites unless --force)
  kit/                exactly what lands in the project root
    .claude/
      commands/build/  subphase, phase, fix, next, finish, setup
      commands/test/   qa-test
      commands/review/ qa-review
      commands/git/    commit, push, sync, undo
      commands/check.md  /check and /check <id> (read-only, every agent)
      roles/           build, test, review, git role prompts
      permissions/     build, test, review, git settings files
      scripts/         fingerprint.sh, agent.sh, agent.cmd, agent.ps1, statusline.ps1
      hooks/           lint-on-save.cjs (config-driven, off by default)
      workflow/        PROJECT.md (the profile), fingerprint.paths, lint-on-save.json,
                       PLAN.template.md, FIXES.template.md, CLAUDE.section.md
      settings.json    shared read-only allows and safety denies
      launch.json      dev (BUILD) + qa (TEST) servers for the desktop browser pane
    docs/
      workflow.md      full guide (how to start each agent, permissions, loop)
      reports/         README + _template/{build,test,review}.md
```

## How it adapts to a project

The commands and roles are generic. Every command reads **`.claude/workflow/PROJECT.md`** first, which names:

- the plan file and its headings (context, hard rules, sub-phase format, Status, Decisions log, model routing)
- the phase id scheme
- the check commands (build, lint, type-check, unit tests, extras)
- how TEST verifies behaviour (`browser`, `cli`, `api`, or `none`), dev servers, regression smoke
- protected paths, commit format, and model routing

`/build:setup` fills that profile by reading the project's `PLAN.md`, `CLAUDE.md`, and package files, then shows you the values before writing. It also sets the fingerprint inputs, `launch.json`, the lint hook, protected-path denies, and appends the workflow section to `CLAUDE.md`. Commands refuse to run while the profile still has `<fill me>`.

## Install into a project

```bash
bash ai-workflow-kit/install.sh /path/to/other-project
```

Then open that project in the Claude desktop app and run:

```
/build:setup
```

No `PLAN.md` yet? `/build:setup` offers to start one from `.claude/workflow/PLAN.template.md` (sections 0–10 in the same shape as before: context and hard rules, phases with Order / Owns / Deliverables / Hand-off contract / Acceptance / Prompt, model routing, Status, Decisions log).

Re-installing after you improve the kit:

```bash
bash ai-workflow-kit/install.sh /path/to/other-project --force
```

`--force` replaces commands, roles, scripts, hooks, and templates, but never the project-specific files (profile, fingerprint paths, lint config, `launch.json`, `settings.json`, permissions).

## Daily loop

```
BUILD   /next → /subphase 2b
TEST    /qa-test 2b          (second desktop session)
REVIEW  /qa-review 2b        (bash .claude/scripts/agent.sh review)
        any ❌ → BUILD /subphase 2b again, re-run QA
BUILD   /finish 2b           (only after both PASS on the current fingerprint)
GIT     /commit 2b → /push   (bash .claude/scripts/agent.sh git)
```

Full guide: `kit/docs/workflow.md`.

## Immediate fixes (`/fix` and `FIXES.md`)

For fixes and changes you want between phases without rewriting `PLAN.md`. Ask BUILD in chat for the fixes; it creates `FIXES.md` from `.claude/workflow/FIXES.template.md` (or appends a new batch): batches F1, F2, … of fixes `f1a`, `f1b`, … in the plan's sub-phase format, each batch with a **Blocks.** line naming the plan sub-phase it must land before.

```
BUILD   /fix                 (fixes board + preflight)
BUILD   /fix f1a             (build the fix; again after a QA ❌ to fix the items)
TEST    /qa-test f1a   +   REVIEW  /qa-review f1a
BUILD   /finish f1a          (ticks FIXES.md section 3, Decisions log in FIXES.md section 4)
GIT     /commit f1a          (fix-f1a: <summary>)
```

- While a batch has an unticked fix, `/subphase` and `/phase` refuse its Blocks sub-phase and every later one; `/next` shows fixes first and marks those plan parts blocked.
- Where a fix and the plan disagree, the fix wins for what it touches.
- The fixes file and its headings live in the profile's **Fixes** section. Projects installed before `/fix` existed keep their `PROJECT.md` on `--force` reinstall; the commands then use the defaults (`FIXES.md`, the template's layout), so nothing else is needed. Copy the Fixes section from `kit/.claude/workflow/PROJECT.md` only if you use a different file or headings.
- If a project has no `FIXES.md`, nothing changes: the gate is skipped.

## Agent terminal themes (PowerShell)

Start the terminal agents from PowerShell; each gets its own status line (Windows PowerShell 5.1 and PowerShell 7 both work):

```powershell
.\.claude\scripts\agent.ps1 test      # mono (grayscale) bars
.\.claude\scripts\agent.ps1 review    # shiny truecolor gradient bars
.\.claude\scripts\agent.ps1 git       # branch, sync gauge, commit rail, tree counts
```

`agent.ps1` sets `CLAUDE_AGENT_ROLE`, the tab title, and a banner; `.claude/settings.json` points `statusLine` at `statusline.ps1`, which picks the theme from that variable.

| Agent | Bars (percentage on the right) | Source |
|---|---|---|
| TEST (mono) | Progress · Passed · Failed · Blocked/not verified, plus plan and fixes bars | newest `docs/reports/*/test.md` |
| REVIEW (shiny) | Progress · Passed · Blockers · Minor, `✦` at 100%, rainbow header on PASS, `⚠` on blockers | newest `docs/reports/*/review.md` |
| GIT | `⎇ branch ⇡ahead ⇣behind`, commit rail `◉━●━●` colored by `phase-` / `fix-` / `docs` / `qa` / `chore`, staged / modified / untracked / stash counts, `⚑ ready to commit` ids, red banner on merge/rebase/conflicts | git |

Bars move live: `/qa-test` and `/qa-review` write the report first with `verdict: RUNNING` and ⏳ rows, then tick them as they work. `/finish` only accepts `verdict: PASS`, so a running report never passes the gate. The fresh/stale marker needs Git Bash (for `fingerprint.sh`); without it the marker shows `? fp`. Report row shapes in `_template/` are what the status line parses, so keep them.

On macOS/Linux swap `powershell` for `pwsh` in the `statusLine` command. The desktop app has no status line; there the Summary blocks carry the same bars as text (`▰▱` for TEST, 🟩🟥🟨⬜ for REVIEW).

## `/check` (read-only, every agent)

- `/check` lists every plan sub-phase and fix, in Status order, with a **mandatory / optional** label and a state (done, finish, QA pending, blocked, ready, waiting, skipped, removed), plus plan and fixes progress bars and the next command.
- `/check <id>` (`2b`, `f1a`, or a bare `2` / `f1`) prints the detail card: done and not-yet-done deliverables, Acceptance with TEST results, open REVIEW findings, round and fingerprint freshness, Owns files, deviations, gaps, commits, Decisions entries, and the exact next command.
- Plan items are optional when their Order line has the optional marker; fixes are mandatory when their batch **Blocks.** a plan id. The command only reads and may run `git status`, `git log`, and `fingerprint.sh`.

## Requirements

- Claude Code (desktop app for BUILD and TEST; CLI for REVIEW and GIT).
- git, and bash (Git Bash on Windows) for `fingerprint.sh` and `agent.sh`.
- Node only for the optional lint-on-save hook.

## Keeping the kit generic

Change behaviour here in `kit/`, not in a project, then reinstall with `--force`. Project facts go in the project's `.claude/workflow/PROJECT.md`, never in commands or roles. Code-style rules (`.claude/rules/*.md`) are per project and are not part of the kit.
