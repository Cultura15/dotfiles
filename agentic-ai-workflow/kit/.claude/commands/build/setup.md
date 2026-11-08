---
description: BUILD – adapt the AI workflow to this project - fill the project profile, fingerprint inputs, dev servers, lint hook, and the CLAUDE.md workflow section.
argument-hint: [plan file]  default PLAN.md
---

You are BUILD. Adapt the installed workflow to this project. Plan file: **$ARGUMENTS** (default `PLAN.md`).

The commands, roles, and permission files are generic. Everything project-specific lives in the files this command fills. Do not edit `.claude/commands/`, `.claude/roles/`, or `docs/reports/_template/`.

## 1. Read
- The plan file. If it does not exist, say so and offer to create it from `.claude/workflow/PLAN.template.md`. Do not invent phases; ask the user for them.
- `CLAUDE.md`, `README.md`, `.claude/rules/*.md`, `.gitignore`.
- The package / build files that exist: `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Makefile`, `composer.json`, lint and test configs.
- The current `.claude/workflow/PROJECT.md`, `.claude/workflow/fingerprint.paths`, `.claude/workflow/lint-on-save.json`, `.claude/launch.json`.

## 2. Map the plan
Find, and quote back the exact headings for: the context section, hard rules, sub-phase heading format, the field names (Order, Owns, Deliverables, Hand-off contract, Acceptance or their equivalents), amendments, Status, Decisions log, model routing. If the plan lacks Status or a Decisions log, propose appending them (the plan is append-only; ask first). If sub-phases lack Owns or Acceptance, say the gate is weaker without them and ask whether to add them per phase later.

## 3. Propose, then write
Show the user one short table of every value you will write, marking guesses. After they confirm (or correct), write:

1. **`.claude/workflow/PROJECT.md`**: every `<fill me>` replaced. Keep the section layout.
2. **`.claude/workflow/fingerprint.paths`**: the code and build-config paths TEST and REVIEW check; exclude docs, reports, the plan, and `.claude`. Run `bash .claude/scripts/fingerprint.sh` and confirm it prints a 12-char hash.
3. **`.claude/launch.json`**: a `dev` (BUILD) and a `qa` (TEST) configuration on two different ports, for the project's dev server. Remove it if the project has no server.
4. **`.claude/workflow/lint-on-save.json`**: enable it with the project's single-file lint command and file pattern, or leave `enabled: false`. Test it on one file.
5. **Permissions**: add the profile's protected paths as `Edit(<path>/**)` denies to `.claude/settings.json`, `.claude/permissions/build.json`, `test.json`, `review.json`, and as `Bash(git add <path>*)` / `Bash(git add * <path>*)` denies to `git.json`. Add the profile's "Do not run" scripts as Bash denies in `test.json` and `review.json`. Copy `.claude/permissions/build.json` to `.claude/settings.local.json` and make sure `.claude/settings.local.json` is in `.gitignore`.
6. **`CLAUDE.md`**: append `.claude/workflow/CLAUDE.section.md` if CLAUDE.md has no "Agentic workflow" section yet (create `CLAUDE.md` with a one-line project intro if missing). Fill its Commands table from the profile. Skip any of its headings CLAUDE.md already covers, and do not change other CLAUDE.md text.

## 4. Report

```
SETUP · ✅ DONE
  ✅ Profile        .claude/workflow/PROJECT.md (0 <fill me> left)
  ✅ Plan map       Status: <heading> · Decisions: <heading> · <n> sub-phases found
  ✅ Fingerprint    <hash>  (<n> files)
  ✅ Dev servers    dev :<port> · qa :<port>   (or "none")
  ✅ Lint on save   <command>   (or "off")
  ✅ Permissions    <n> protected paths denied
  ✅ CLAUDE.md      workflow section appended

Not committed. Next →  /next
```
