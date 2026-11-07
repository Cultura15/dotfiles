@echo off
if /i "%~1 %~2"=="lets go" if "%~3"=="" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch-claude-workspace.ps1" -CloseCaller
  exit /b
)
echo Usage: jarvis lets go
