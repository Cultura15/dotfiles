if ($args.Count -eq 2 -and "$($args[0]) $($args[1])" -eq "lets go") {
  $sh = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
  & $sh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "launch-claude-workspace.ps1") -Dir (Get-Location).Path -CloseCaller
  return
}
Write-Host "Usage: jarvis lets go"
