---
description: TEST – test a sub-phase (or whole phase) against plan Acceptance. Writes docs/reports/<id>/test.md.
argument-hint: <id|n>  e.g. 2b, 2.2, 2
---

You are TEST. Read `.claude/roles/test.md` first and follow it (the desktop app does not append it for you). Then read `.claude/workflow/PROJECT.md`. Test **$ARGUMENTS**. Never edit code. Work in this session; do not spawn subagents.

## 1. Scope
- Resolve the id per the profile's "Phase ids". A bare number covers every built sub-phase of that phase (a `build.md` exists); write to `docs/reports/<n>/test.md`.
- Read the sub-phase's **Acceptance** and **Deliverables** (and its amendment if any), and `docs/reports/<id>/build.md` ("How to verify", "Deviations").
- Record HEAD short sha (plus "+ uncommitted" if dirty) as `commit`, and `bash .claude/scripts/fingerprint.sh` as `fingerprint`. If the fingerprint differs at the end, BUILD changed code during your run: say so and do not give PASS.
- If `test.md` exists, this is round n+1: re-check the earlier ❌ items first.

## 2. Checks (number them T1, T2, …)
1. **Static**: the profile's Build, Lint, Extra, and Unit tests checks (skip any marked `none`). If the build fails, record it and skip to step 3.
2. **Acceptance**: one check per Acceptance line (split compound lines). Quote it.
3. **Regression**: the profile's "Regression smoke", plus whatever this sub-phase changes, with no errors.

Behaviour checks (2 and 3) follow the profile's **Kind**:
- `browser`: in the Claude desktop app, start the TEST dev server with `preview_start` (`.claude/launch.json` `qa` entry), then check with the `mcp__Claude_Browser__*` tools (`navigate`, `computer`, `read_page`, `javascript_tool`, `read_console_messages`) on the profile's variants. Do one pass through the app, not one page load per check. Stop the server with `preview_stop` when done. If the pane tools are missing (terminal session), fall back to Claude in Chrome on the TEST server started from the shell, and stop it afterwards. If no browser is available, mark those checks `❌ not verified: no browser tools`.
- `cli`: run the commands the Acceptance lines describe and compare output.
- `api`: start the TEST server, call the endpoints, compare responses, stop the server.
- `none`: only static checks; mark behaviour-only Acceptance lines `❌ not verified: no behaviour checks configured`.

Skip anything not listed: no performance measurements, bundle comparisons, or accessibility sweeps beyond what an Acceptance line asks. Never run the profile's "Do not run" scripts.

## 3. Report
- `mkdir -p docs/reports/<id>`, write `docs/reports/<id>/test.md` from `docs/reports/_template/test.md`. `verdict: PASS` only if every check is ✅.
- Print the Summary block from the report, then:
  - all ✅ → `Next: test passed for <id>. When REVIEW also passes, BUILD runs /finish <id>.`
  - any ❌ → `Next: BUILD runs /subphase <id> to fix the ❌ items.`
