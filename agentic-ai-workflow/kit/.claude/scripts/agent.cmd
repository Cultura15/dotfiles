@echo off
rem Start a workflow agent from cmd or PowerShell:  .claude\scripts\agent.cmd review|git|test [model]
setlocal
cd /d "%~dp0\..\.."
set "ROLE=%~1"
set "MODEL=%~2"
if "%MODEL%"=="" set "MODEL=claude-sonnet-5-5"
if /i "%ROLE%"=="review" (
  claude --model %MODEL% --settings .claude/permissions/review.json --append-system-prompt-file .claude/roles/review.md
) else if /i "%ROLE%"=="git" (
  claude --model %MODEL% --setting-sources user,project --settings .claude/permissions/git.json --append-system-prompt-file .claude/roles/git.md
) else if /i "%ROLE%"=="test" (
  claude --model %MODEL% --chrome --settings .claude/permissions/test.json --append-system-prompt-file .claude/roles/test.md
) else (
  echo usage: agent.cmd review^|git^|test [model]
  exit /b 1
)
