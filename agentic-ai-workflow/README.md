# AI workflow kit (BUILD · TEST · REVIEW · GIT)

A portable copy of the four-agent Claude Code workflow: plan-driven sub-phases, a QA gate with a code fingerprint, report hand-offs, and a git-only agent. Drop it into any project that has (or will have) a phased `PLAN.md`.

```
ai-workflow-kit/
  install.sh          copies kit/ into a project (never overwrites unless --force)
  kit/                exactly what lands in the project root
    .claude/
      commands/build/  subphase, phase, next, finish, setup
      commands/test/   qa-test
      commands/review/ qa-review
      commands/git/    commit, push, sync, undo
      roles/           build, test, review, git role prompts
      permissions/     build, test, review, git settings files
      scripts/         fingerprint.sh, agent.sh, agent.cmd
      hooks/           lint-on-save.cjs (config-driven, off by default)
      workflow/        PROJECT.md (the profile), fingerprint.paths, lint-on-save.json,
                       PLAN.template.md, CLAUDE.section.md
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

## Requirements

- Claude Code (desktop app for BUILD and TEST; CLI for REVIEW and GIT).
- git, and bash (Git Bash on Windows) for `fingerprint.sh` and `agent.sh`.
- Node only for the optional lint-on-save hook.

## Keeping the kit generic

Change behaviour here in `kit/`, not in a project, then reinstall with `--force`. Project facts go in the project's `.claude/workflow/PROJECT.md`, never in commands or roles. Code-style rules (`.claude/rules/*.md`) are per project and are not part of the kit.
