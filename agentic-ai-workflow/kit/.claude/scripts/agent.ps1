# Start a workflow agent from PowerShell (5.1 or 7+) at the repo root.
#   .\.claude\scripts\agent.ps1 review          # REVIEW, shiny bars
#   .\.claude\scripts\agent.ps1 git             # GIT, branch + commit rail
#   .\.claude\scripts\agent.ps1 test            # TEST, mono bars (uses Claude in Chrome)
# Optional second arg overrides the model, e.g. `agent.ps1 review claude-opus-5-5`.
param(
  [Parameter(Position = 0)][string]$Role = '',
  [Parameter(Position = 1)][string]$Model = 'claude-sonnet-5-5'
)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
Set-Location (Join-Path $PSScriptRoot '..\..')

$Role = $Role.ToLower()
if ($Role -notin @('review', 'git', 'test')) {
  Write-Host 'usage: agent.ps1 review|git|test [model]'
  exit 1
}

$env:CLAUDE_AGENT_ROLE = $Role   # statusline.ps1 picks the theme from this
$project = Split-Path -Leaf (Get-Location).Path
$Host.UI.RawUI.WindowTitle = "$($Role.ToUpper()) - $project"

# banner (code points only, so this file stays ASCII)
$E = [char]27
$spark = [char]0x2726; $branch = [char]0x2387; $full = [char]0x2588
switch ($Role) {
  'test'   { Write-Host "$E[38;5;255m$E[1m$full$full$full TEST$E[0m$E[38;5;244m  mono theme  |  $project  |  /qa-test <id>  |  /check$E[0m" }
  'review' {
    $word = "$spark REVIEW $spark"
    $out = ''
    for ($i = 0; $i -lt $word.Length; $i++) {
      $h = 300 * $i / $word.Length
      $x = 1 - [math]::Abs((($h / 60) % 2) - 1)
      switch ([int]([math]::Floor($h / 60)) % 6) { 0 { $r = 1; $g = $x; $b = 0 } 1 { $r = $x; $g = 1; $b = 0 } 2 { $r = 0; $g = 1; $b = $x } 3 { $r = 0; $g = $x; $b = 1 } 4 { $r = $x; $g = 0; $b = 1 } default { $r = 1; $g = 0; $b = $x } }
      $out += "$E[38;2;$([int]($r*255));$([int]($g*255));$([int]($b*255))m" + $word[$i]
    }
    Write-Host "$out$E[0m$E[38;2;150;150;190m  shiny theme  |  $project  |  /qa-review <id>  |  /check$E[0m"
  }
  'git'    { Write-Host "$E[38;2;80;220;120m$E[1m$branch GIT$E[0m$E[38;2;150;150;150m  commit rail theme  |  $project  |  /commit <id>  /push  |  /check$E[0m" }
}

switch ($Role) {
  'review' { & claude --model $Model --settings .claude/permissions/review.json --append-system-prompt-file .claude/roles/review.md }
  'git'    { & claude --model $Model --setting-sources user,project --settings .claude/permissions/git.json --append-system-prompt-file .claude/roles/git.md }
  'test'   { & claude --model $Model --chrome --settings .claude/permissions/test.json --append-system-prompt-file .claude/roles/test.md }
}
