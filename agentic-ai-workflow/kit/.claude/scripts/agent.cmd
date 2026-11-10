@echo off
rem Start a workflow agent from cmd or PowerShell:  .claude\scripts\agent.cmd review|git|test [model]
rem (PowerShell users: .\.claude\scripts\agent.ps1 review|git|test [model] does the same, with a themed banner.)
setlocal
cd /d "%~dp0\..\.."
set "ROLE=%~1"
set "MODEL=%~2"
if "%MODEL%"=="" set "MODEL=claude-sonnet-5-5"
rem The status line theme (mono TEST, shiny REVIEW, GIT rail) is picked from this variable.
set "CLAUDE_AGENT_ROLE=%ROLE%"
if /i "%ROLE%"=="review" (
  title REVIEW
  claude --model %MODEL% --settings .claude/permissions/review.json --append-system-prompt-file .claude/roles/review.md
) else if /i "%ROLE%"=="git" (
  title GIT
  claude --model %MODEL% --setting-sources user,project --settings .claude/permissions/git.json --append-system-prompt-file .claude/roles/git.md
) else if /i "%ROLE%"=="test" (
  title TEST
  claude --model %MODEL% --chrome --settings .claude/permissions/test.json --append-system-prompt-file .claude/roles/test.md
) else (
  echo usage: agent.cmd review^|git^|test [model]
  exit /b 1
)
