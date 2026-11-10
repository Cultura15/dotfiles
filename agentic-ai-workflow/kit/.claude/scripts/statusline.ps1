# Status line for the workflow agents (PowerShell 5.1 and 7+). Claude Code runs it and pipes session JSON on stdin.
#   CLAUDE_AGENT_ROLE=test    -> mono (grayscale) bars: progress / passed / failed / blocked
#   CLAUDE_AGENT_ROLE=review  -> shiny truecolor gradient bars: progress / passed / blockers / minor
#   CLAUDE_AGENT_ROLE=git     -> branch, sync gauge, commit rail, working tree counts
#   anything else (build)     -> one plain line with plan and fixes progress
# The file is ASCII only on purpose (Windows PowerShell 5.1 reads BOM-less files as ANSI): glyphs are built from code points.
$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$E = [char]27
$RST = "$E[0m"
$BOLD = "$E[1m"
$role = "$env:CLAUDE_AGENT_ROLE".ToLower()
if (-not $role) { $role = 'build' }

# ---- glyphs -----------------------------------------------------------------
$FULL = [char]0x2588; $DARK = [char]0x2593; $MED = [char]0x2592; $LIGHT = [char]0x2591
$DOT = [char]0x00B7; $SPARK = [char]0x2726; $WARN = [char]0x26A0; $CHECK = [char]0x2713; $CROSS = [char]0x2717
# NOTE: PowerShell variable names are case-insensitive, so glyph names must not collide with locals ($up, $stash, ...).
$BRANCH = [char]0x2387; $gUp = [char]0x21E1; $gDown = [char]0x21E3; $ARROW = [char]0x2192
$HEADDOT = [char]0x25C9; $COMMIT = [char]0x25CF; $LINK = [char]0x2501
$RXRES = '(' + [char]0x2705 + '|' + [char]0x274C + '|' + [char]0x23F3 + ')'   # result cell: pass | fail | pending
$PLUS = [char]0x271A; $gStash = [char]0x2261; $FLAG = [char]0x2691

# ---- session info -----------------------------------------------------------
$raw = ''
try { $raw = [Console]::In.ReadToEnd() } catch {}
$model = ''
try {
  if ($raw) {
    $info = $raw | ConvertFrom-Json
    if ($info.model.display_name) { $model = [string]$info.model.display_name }
  }
} catch {}

$root = (& git rev-parse --show-toplevel 2>$null)
if (-not $root) { $root = (Get-Location).Path }
Set-Location $root
$key = ($root -replace '[^A-Za-z0-9]', '_')
if ($key.Length -gt 40) { $key = $key.Substring($key.Length - 40) }

function Get-Cached([string]$name, [int]$ttl, [scriptblock]$gen) {
  $p = Join-Path ([IO.Path]::GetTempPath()) "cc-sl-$key-$role-$name.txt"
  if ((Test-Path $p) -and (((Get-Date) - (Get-Item $p).LastWriteTime).TotalSeconds -lt $ttl)) {
    return [IO.File]::ReadAllText($p, [Text.Encoding]::UTF8)
  }
  $v = [string](& $gen)
  try { [IO.File]::WriteAllText($p, $v, (New-Object Text.UTF8Encoding $false)) } catch {}
  return $v
}

# ---- colors -----------------------------------------------------------------
$TC = ("$env:COLORTERM" -match 'truecolor|24bit') -or [bool]$env:WT_SESSION -or [bool]$env:TERM_PROGRAM
function To256([int]$r, [int]$g, [int]$b) {
  [int](16 + 36 * [math]::Round($r / 51) + 6 * [math]::Round($g / 51) + [math]::Round($b / 51))
}
function Fg([int]$r, [int]$g, [int]$b) {
  if ($TC) { return "$E[38;2;$r;$g;${b}m" }
  $n = To256 $r $g $b
  return "$E[38;5;${n}m"
}
function G([int]$n) { "$E[38;5;${n}m" }          # xterm grayscale / 256 index

function Hue([double]$h) {
  $x = 1 - [math]::Abs((($h / 60) % 2) - 1)
  switch ([int]([math]::Floor($h / 60)) % 6) {
    0 { $r = 1; $g = $x; $b = 0 }
    1 { $r = $x; $g = 1; $b = 0 }
    2 { $r = 0; $g = 1; $b = $x }
    3 { $r = 0; $g = $x; $b = 1 }
    4 { $r = $x; $g = 0; $b = 1 }
    default { $r = 1; $g = 0; $b = $x }
  }
  return ,@([int]($r * 255), [int]($g * 255), [int]($b * 255))
}
function Rainbow([string]$s) {
  $sb = New-Object System.Text.StringBuilder
  $n = [math]::Max($s.Length, 1)
  for ($i = 0; $i -lt $s.Length; $i++) {
    $c = Hue (300 * $i / $n)
    [void]$sb.Append((Fg $c[0] $c[1] $c[2])).Append($s[$i])
  }
  [void]$sb.Append($RST)
  $sb.ToString()
}

function Pct([int]$n, [int]$total) { if ($total -le 0) { 0 } else { [int][math]::Min(100, [math]::Round(100 * $n / $total)) } }

# Mono bar: one gray + one glyph, percentage on the right.
function Bar-Mono([int]$pct, [int]$gray, $glyph, [int]$w = 20) {
  $f = [int][math]::Round($pct / 100 * $w); if ($pct -gt 0 -and $f -eq 0) { $f = 1 }
  (G $gray) + ([string]$glyph * $f) + (G 236) + ([string]$LIGHT * ($w - $f)) + $RST
}
# Shiny bar: gradient from c1 to c2 across the filled part.
function Bar-Grad([int]$pct, $c1, $c2, [int]$w = 20) {
  $f = [int][math]::Round($pct / 100 * $w); if ($pct -gt 0 -and $f -eq 0) { $f = 1 }
  $sb = New-Object System.Text.StringBuilder
  for ($i = 0; $i -lt $f; $i++) {
    $t = 0.0; if ($f -gt 1) { $t = $i / ($f - 1) }
    $r = [int]($c1[0] + ($c2[0] - $c1[0]) * $t); $g = [int]($c1[1] + ($c2[1] - $c1[1]) * $t); $b = [int]($c1[2] + ($c2[2] - $c1[2]) * $t)
    [void]$sb.Append((Fg $r $g $b)).Append($FULL)
  }
  [void]$sb.Append((G 237)).Append([string]$LIGHT * ($w - $f)).Append($RST)
  $sb.ToString()
}
function Label([int]$pct) { ('{0,3}%' -f $pct) }

# ---- fingerprint (needs Git Bash; never WSL bash) -----------------------------
function Find-Bash {
  try {
    $ex = (& git --exec-path 2>$null)
    if ($ex) {
      $gr = Split-Path (Split-Path (Split-Path $ex))
      $b = Join-Path $gr 'bin\bash.exe'
      if (Test-Path $b) { return $b }
    }
  } catch {}
  $c = Get-Command bash -ErrorAction SilentlyContinue
  if ($c -and $c.Source -notmatch 'System32') { return $c.Source }
  return $null
}
function Get-Fp {
  Get-Cached 'fp' 10 {
    $b = Find-Bash
    if ($b -and (Test-Path '.claude/scripts/fingerprint.sh')) { ((& $b '.claude/scripts/fingerprint.sh' 2>$null) | Select-Object -First 1) } else { '' }
  }
}

# ---- plan / fixes progress ---------------------------------------------------
function Get-Ticks([string]$file, [string]$word) {
  if (-not (Test-Path $file)) { return $null }
  $done = 0; $tot = 0
  foreach ($l in (Get-Content $file -Encoding UTF8)) {
    if ($l -match "^\s*-\s*\[[ xX]\]\s*$word\b" -and $l -notmatch 'REMOVED') {
      $tot++; if ($l -match '^\s*-\s*\[[xX]\]') { $done++ }
    }
  }
  if ($tot -eq 0) { return $null }
  return @{ Done = $done; Total = $tot }
}
function Plan-Line([scriptblock]$bar) {
  $parts = @()
  $p = Get-Ticks 'PLAN.md' 'Phase'
  if ($p) { $pc = Pct $p.Done $p.Total; $parts += ('Plan  ' + (& $bar $pc) + ' ' + (Label $pc) + "  $($p.Done)/$($p.Total)") }
  $f = Get-Ticks 'FIXES.md' 'Fix'
  if ($f) { $open = $f.Total - $f.Done; $fc = Pct $f.Done $f.Total; $parts += ('Fixes ' + (& $bar $fc) + ' ' + (Label $fc) + "  $open open") }
  return $parts
}

# ---- report parsing ----------------------------------------------------------
function Get-Report([string]$kind) {
  $f = Get-ChildItem -Path 'docs/reports' -Filter "$kind.md" -File -Recurse | Where-Object { $_.Directory.Name -ne '_template' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $f) { return $null }
  $txt = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
  $fm = @{}
  if ($txt -match '(?s)^---\r?\n(.*?)\r?\n---') {
    foreach ($l in ($Matches[1] -split '\r?\n')) { if ($l -match '^(\w+):\s*(.*?)\s*(#.*)?$') { $fm[$Matches[1]] = $Matches[2].Trim() } }
  }
  $r = @{ Id = $f.Directory.Name; Round = $fm['round']; Verdict = $fm['verdict']; Fp = $fm['fingerprint']
          Pass = 0; Fail = 0; Blocked = 0; Pending = 0; Blockers = 0; Minor = 0; FailIds = @(); BlockIds = @(); FindIds = @() }
  foreach ($l in ($txt -split '\r?\n')) {
    if ($kind -eq 'test') {
      if ($l -match ('^\|\s*(T\d+)\s*\|[^|]*\|[^|]*\|\s*' + $RXRES + '\s*\|(.*)$')) {
        $id = $Matches[1]; $res = $Matches[2]
        if ($res -eq [string][char]0x2705) { $r.Pass++ }
        elseif ($res -eq [string][char]0x23F3) { $r.Pending++ }
        elseif ($Matches[3] -match 'not verified') { $r.Blocked++; $r.BlockIds += $id }
        else { $r.Fail++; $r.FailIds += $id }
      }
    } else {
      if ($l -match '^\|\s*(R\d+)\s*\|\s*(blocker|minor)\s*\|') {
        if ($Matches[2] -eq 'blocker') { $r.Blockers++ } else { $r.Minor++ }
        $r.FindIds += $Matches[1]
      } elseif ($l -match ('^\|\s*([^|]+?)\s*\|\s*' + $RXRES + '\s*\|') -and $Matches[1] -notmatch '^(R\d+|#|Area)$') {
        $res = $Matches[2]
        if ($res -eq [string][char]0x2705) { $r.Pass++ }
        elseif ($res -eq [string][char]0x23F3) { $r.Pending++ }
        else { $r.Fail++ }
      }
    }
  }
  $r.Total = $r.Pass + $r.Fail + $r.Blocked + $r.Pending
  return $r
}
function Fresh([string]$reportFp) {
  $cur = Get-Fp
  if (-not $cur -or -not $reportFp -or $reportFp -match '[<>]') { return '?' }
  if ($cur -eq $reportFp) { return 'fresh' } else { return 'stale' }
}
function Fresh-Text([string]$state, [bool]$color) {
  switch ($state) {
    'fresh' { return $(if ($color) { (Fg 80 230 140) } else { (G 255) }) + "$CHECK fresh" + $RST }
    'stale' { return $(if ($color) { (Fg 255 90 90) } else { (G 244) }) + "$CROSS stale" + $RST }
    default { return (G 244) + '? fp' + $RST }
  }
}
function Ids($arr) { if ($arr -and $arr.Count) { (($arr | Select-Object -First 4) -join ' ') + $(if ($arr.Count -gt 4) { ' +' + ($arr.Count - 4) } else { '' }) } else { '' } }

# ---- role renderers ----------------------------------------------------------
function Render-Test {
  $rep = Get-Report 'test'
  if (-not $rep) { return (G 255) + $BOLD + 'TEST' + $RST + (G 244) + " $DOT no test report yet - run /qa-test <id>" + $RST }
  $t = $rep.Total
  $done = $rep.Pass + $rep.Fail + $rep.Blocked
  $verdict = $rep.Verdict
  $head = (G 255) + $BOLD + 'TEST' + $RST + (G 250) + " $DOT $($rep.Id) $DOT round $($rep.Round) $DOT $verdict $DOT " + (Fresh-Text (Fresh $rep.Fp) $false)
  $lines = @($head)
  $lines += '  ' + (G 250) + 'Progress ' + (Bar-Mono (Pct $done $t) 250 $FULL) + ' ' + (G 250) + (Label (Pct $done $t)) + (G 244) + "   $done/$t checks" + $RST
  $lines += '  ' + (G 255) + 'Passed   ' + (Bar-Mono (Pct $rep.Pass $t) 255 $FULL) + ' ' + (G 255) + (Label (Pct $rep.Pass $t)) + (G 244) + "   $($rep.Pass) checks" + $RST
  $lines += '  ' + (G 244) + 'Failed   ' + (Bar-Mono (Pct $rep.Fail $t) 244 $DARK) + ' ' + (G 244) + (Label (Pct $rep.Fail $t)) + (G 240) + "   $(Ids $rep.FailIds)" + $RST
  $lines += '  ' + (G 240) + 'Blocked  ' + (Bar-Mono (Pct $rep.Blocked $t) 240 $MED) + ' ' + (G 240) + (Label (Pct $rep.Blocked $t)) + (G 238) + "   $(Ids $rep.BlockIds)" + $RST
  $plan = Plan-Line { param($p) Bar-Mono $p 250 $FULL 10 }
  if ($plan.Count) { $lines += '  ' + (G 244) + ($plan -join "   $DOT   ") + $RST }
  return ($lines -join "`n")
}

function Render-Review {
  $rep = Get-Report 'review'
  $gold = @(253, 224, 71)
  if (-not $rep) { return (Rainbow "$SPARK REVIEW") + (Fg 160 160 200) + " $DOT no review report yet - run /qa-review <id>" + $RST }
  $t = $rep.Total
  $done = $rep.Pass + $rep.Fail + $rep.Pending * 0
  $head = (Rainbow "$SPARK REVIEW") + (Fg 190 190 255) + " $DOT $($rep.Id) $DOT round $($rep.Round) $DOT " + $rep.Verdict + " $DOT " + (Fresh-Text (Fresh $rep.Fp) $true)
  if ($rep.Verdict -eq 'PASS' -and $rep.Fail -eq 0 -and $t -gt 0) { $head = (Rainbow "$SPARK REVIEW $SPARK $($rep.Id) PASS") + ' ' + (Fresh-Text (Fresh $rep.Fp) $true) }
  $lines = @($head)
  $pp = Pct $done $t
  $sp = ''; if ($pp -ge 100 -and $t -gt 0) { $sp = ' ' + (Fg 253 224 71) + $SPARK }
  $lines += '  ' + (Fg 168 85 247) + 'Progress ' + (Bar-Grad $pp @(168, 85, 247) @(34, 211, 238)) + ' ' + (Fg 34 211 238) + (Label $pp) + $sp + (Fg 150 150 190) + "   $done/$t areas" + $RST
  $ps = Pct $rep.Pass $t
  $lines += '  ' + (Fg 34 255 136) + 'Passed   ' + (Bar-Grad $ps @(34, 255, 136) @(20, 184, 166)) + ' ' + (Fg 34 255 136) + (Label $ps) + (Fg 150 190 170) + "   $($rep.Pass) areas clean" + $RST
  $pb = Pct $rep.Blockers $t
  $wm = ''; if ($rep.Blockers -gt 0) { $wm = ' ' + (Fg 255 59 59) + $WARN }
  $lines += '  ' + (Fg 255 45 149) + 'Blockers ' + (Bar-Grad $pb @(255, 45, 149) @(255, 59, 59)) + ' ' + (Fg 255 59 59) + (Label $pb) + $wm + (Fg 200 140 160) + "   $($rep.Blockers) $(Ids $rep.FindIds)" + $RST
  $pm = Pct $rep.Minor $t
  $lines += '  ' + (Fg 245 158 11) + 'Minor    ' + (Bar-Grad $pm @(245, 158, 11) $gold) + ' ' + (Fg 253 224 71) + (Label $pm) + (Fg 200 180 120) + "   $($rep.Minor)" + $RST
  $plan = Plan-Line { param($p) Bar-Grad $p @(168, 85, 247) @(34, 211, 238) 10 }
  if ($plan.Count) { $lines += '  ' + (Fg 150 150 190) + ($plan -join "   $DOT   ") + $RST }
  return ($lines -join "`n")
}

function Render-Git {
  $st = @(& git status --porcelain -b 2>$null)
  if (-not $st.Count) { return (Fg 80 220 120) + $BOLD + "$BRANCH git" + $RST + ' (not a repo)' }
  $br = 'HEAD'; $up = ''; $ahead = 0; $behind = 0
  if ($st[0] -match '^## (?<br>[^\s.]+)(?:\.\.\.(?<up>\S+))?(?: \[(?<ab>[^\]]+)\])?') {
    $br = $Matches['br']; $up = $Matches['up']
    if ($Matches['ab'] -match 'ahead (\d+)') { $ahead = [int]$Matches[1] }
    if ($Matches['ab'] -match 'behind (\d+)') { $behind = [int]$Matches[1] }
  }
  $staged = 0; $mod = 0; $untr = 0; $conf = 0
  foreach ($l in ($st | Select-Object -Skip 1)) {
    if ($l -match '^(UU|AA|DD|AU|UA|DU|UD)') { $conf++ }
    elseif ($l -match '^\?\?') { $untr++ }
    else { if ($l -match '^[MADRC]') { $staged++ }; if ($l -match '^.[MD]') { $mod++ } }
  }
  $stash = @(& git stash list 2>$null).Count
  $gd = (& git rev-parse --git-dir 2>$null)
  $state = ''
  foreach ($pair in @(@('MERGE_HEAD', 'MERGING'), @('rebase-merge', 'REBASING'), @('rebase-apply', 'REBASING'), @('CHERRY_PICK_HEAD', 'CHERRY-PICKING'), @('REVERT_HEAD', 'REVERTING'))) {
    if ($gd -and (Test-Path (Join-Path $gd $pair[0]))) { $state = $pair[1]; break }
  }
  $green = Fg 80 220 120; $red = Fg 255 90 90; $yel = Fg 240 200 80; $gray = Fg 150 150 150; $cyan = Fg 90 220 230
  $syncCol = $green; if ($ahead -gt 0 -and $behind -gt 0) { $syncCol = $red } elseif ($ahead -gt 0 -or $behind -gt 0) { $yel = $yel; $syncCol = $yel }
  $upTxt = ''; if ($up) { $upTxt = " $ARROW $up" }
  # commit rail: HEAD first, colored by message prefix
  $subs = @(& git log -5 --format='%s' 2>$null)
  $rail = ''
  for ($i = 0; $i -lt $subs.Count; $i++) {
    $s = [string]$subs[$i]
    if ($s -match '^phase-') { $c = Fg 80 220 120 } elseif ($s -match '^fix-') { $c = Fg 255 150 50 } elseif ($s -match '^docs') { $c = Fg 90 150 255 }
    elseif ($s -match '^qa') { $c = Fg 170 110 255 } elseif ($s -match '^(chore|plan)') { $c = Fg 150 150 150 } else { $c = Fg 230 230 230 }
    $g = $COMMIT; if ($i -eq 0) { $g = $HEADDOT }
    if ($i -gt 0) { $rail += $gray + $LINK }
    $rail += $c + $g
  }
  $last = (& git log -1 --format='%h|%s|%cr' 2>$null)
  $lastTxt = ''
  if ($last) { $p = ([string]$last) -split '\|', 3; $lastTxt = $yel + $p[0] + $RST + (Fg 220 220 220) + ' ' + $p[1] + $gray + " $DOT " + $p[2] }
  $line1 = $green + $BOLD + "$BRANCH $br" + $RST + $syncCol + " $gUp$ahead $gDown$behind" + $gray + $upTxt + $RST + '   ' + $rail + $RST + '   ' + $lastTxt + $RST
  $line2 = '  ' + $green + "$COMMIT $staged staged" + '   ' + $yel + "$PLUS $mod modified" + '   ' + $gray + "? $untr untracked" + '   ' + $cyan + "$gStash $stash stash" + $RST
  # ids finished by BUILD (status DONE) with no commit yet
  $ready = @()
  foreach ($bf in (Get-ChildItem -Path 'docs/reports' -Filter 'build.md' -File -Recurse | Where-Object { $_.Directory.Name -ne '_template' })) {
    $t = [IO.File]::ReadAllText($bf.FullName, [Text.Encoding]::UTF8)
    if ($t -match '(?m)^status:\s*DONE') {
      $id = $bf.Directory.Name
      $hit = (& git log -1 --format=%h --grep="^phase-$id" --grep="^fix-$id" 2>$null)
      if (-not $hit) { $ready += $id }
    }
  }
  if ($ready.Count) { $line2 += '   ' + (Fg 255 150 50) + "$FLAG ready to commit: " + ($ready -join ', ') + $RST }
  $lines = @($line1, $line2)
  if ($conf -gt 0) { $lines += '  ' + $red + $BOLD + "$WARN $conf conflicted file(s)" + $RST }
  if ($state) { $lines += '  ' + $red + $BOLD + "$WARN $state in progress" + $RST }
  return ($lines -join "`n")
}

function Render-Build {
  $b = (& git rev-parse --abbrev-ref HEAD 2>$null)
  $plan = Plan-Line { param($p) Bar-Mono $p 250 $FULL 10 }
  return (G 255) + $BOLD + 'BUILD' + $RST + (G 244) + " $DOT $b" + $(if ($plan.Count) { "  $DOT  " + ($plan -join "  $DOT  ") } else { '' }) + $RST
}

# ---- output ------------------------------------------------------------------
$body = Get-Cached 'body' 3 {
  switch ($role) {
    'test'   { Render-Test }
    'review' { Render-Review }
    'git'    { Render-Git }
    default  { Render-Build }
  }
}
$nl = $body.IndexOf("`n")
if ($model) {
  $tag = (G 244) + "  $DOT $model" + $RST
  if ($nl -ge 0) { $body = $body.Substring(0, $nl) + $tag + $body.Substring($nl) } else { $body = $body + $tag }
}
[Console]::Out.Write($body)
