param(
  [string]$Dir = (Get-Location).Path,
  [switch]$CloseCaller
)

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public class Win {
  delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc p, IntPtr l);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hh, bool repaint);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, int x, int y, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern void keybd_event(byte k, byte s, uint f, IntPtr e);
  [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  public struct RECT { public int L, T, R, B; }
  public struct POINT { public int X, Y; }
  public static string Title(IntPtr h) { var t = new StringBuilder(256); GetWindowText(h, t, 256); return t.ToString(); }
  [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
  [DllImport("kernel32.dll")] public static extern bool TerminateProcess(IntPtr h, uint code);
  [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
  public static List<IntPtr> Find(string cls, string proc) { return Find(cls, proc, false); }
  public static List<IntPtr> Find(string cls, string proc, bool untitled) {
    var list = new List<IntPtr>();
    EnumWindows((h, l) => {
      if (!IsWindowVisible(h)) return true;
      var c = new StringBuilder(256); GetClassName(h, c, 256);
      if (c.ToString() != cls) return true;
      var t = new StringBuilder(256); GetWindowText(h, t, 256);
      if ((t.Length == 0) != untitled) return true;
      if (proc != "") {
        uint pid; GetWindowThreadProcessId(h, out pid);
        try { if (System.Diagnostics.Process.GetProcessById((int)pid).ProcessName.ToLower() != proc) return true; }
        catch { return true; }
      }
      list.Add(h); return true;
    }, IntPtr.Zero);
    return list;
  }
}
"@
[Win]::SetProcessDPIAware() | Out-Null

function Wait-Window($cls, $proc, $before, $timeout = 20) {
  $end = (Get-Date).AddSeconds($timeout)
  while ((Get-Date) -lt $end) {
    $now = @([Win]::Find($cls, $proc))
    $new = @($now | Where-Object { $before -notcontains $_ })
    if ($new.Count -gt 0) { return $new[0] }
    if ($before.Count -eq 0 -and $now.Count -gt 0) { return $now[0] }
    Start-Sleep -Milliseconds 400
  }
  return $null
}
function Place($h, $x, $y, $w, $hgt) {
  if ($h) { [Win]::ShowWindow($h, 9) | Out-Null; [Win]::MoveWindow($h, $x, $y, $w, $hgt, $true) | Out-Null }
}
function Pane($title, $command, [switch]$live) {
  $lock = if ($live) { "" } else { "--suppressApplicationTitle " }
  "-p `"$wtProfile`" --title `"$title`" $lock-d `"$Dir`" $sh -NoExit -Command $command"
}
function Git-Command {
  $perms = Join-Path $Dir ".claude\permissions\git.json"
  $role  = Join-Path $Dir ".claude\roles\git.md"
  if ((Test-Path $perms) -and (Test-Path $role)) {
    return "claude --setting-sources user,project --settings .claude/permissions/git.json --append-system-prompt (Get-Content .claude/roles/git.md -Raw)"
  }
  return "claude --model sonnet"
}
function Claude-Windows { @([Win]::Find("Chrome_WidgetWin_1", "claude")) }
function Main-App {
  # The main window is titled "Claude"; popped-out session windows carry the session name.
  $all = Claude-Windows
  $main = @($all | Where-Object { [Win]::Title($_) -eq "Claude" })
  if ($main.Count -gt 0) { return $main[0] }
  if ($all.Count -gt 0) { return $all[0] }
  return $null
}
function Press($vk) {
  [Win]::keybd_event($vk, 0, 0, [IntPtr]::Zero); [Win]::keybd_event($vk, 0, 2, [IntPtr]::Zero)
  Start-Sleep -Milliseconds 300
}
function Click($x, $y) {
  [Win]::SetCursorPos($x, $y) | Out-Null
  [Win]::mouse_event(2, 0, 0, 0, [IntPtr]::Zero); [Win]::mouse_event(4, 0, 0, 0, [IntPtr]::Zero)
}
# Opening a folder through a claude:// link always shows "Trust this workspace?",
# and the button isn't exposed to accessibility. Find its solid white fill
# (wide runs of near-white pixels; text and dark UI never make those) and click it.
# Clicks nothing if no such button shows up.
function Accept-Trust($main, $timeout = 6) {
  if (-not $main) { return $false }
  $end = (Get-Date).AddSeconds($timeout)
  while ((Get-Date) -lt $end) {
    Start-Sleep -Milliseconds 300
    $r = New-Object Win+RECT; [Win]::GetWindowRect($main, [ref]$r) | Out-Null
    $w = $r.R - $r.L; $hh = $r.B - $r.T
    if ($w -le 0 -or $hh -le 0) { continue }
    $bmp = New-Object System.Drawing.Bitmap $w, $hh
    $g = [System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size); $g.Dispose()
    $data = $bmp.LockBits((New-Object System.Drawing.Rectangle 0, 0, $w, $hh), 'ReadOnly', 'Format32bppArgb')
    $px = New-Object byte[] ($data.Stride * $hh)
    [Runtime.InteropServices.Marshal]::Copy($data.Scan0, $px, 0, $px.Length); $bmp.UnlockBits($data); $bmp.Dispose()
    $top = -1; $bot = -1; $left = $w; $right = 0
    for ($y = [int]($hh * 0.2); $y -lt [int]($hh * 0.85); $y++) {
      $run = 0; $o = $y * $data.Stride
      for ($x = [int]($w * 0.2); $x -lt [int]($w * 0.9); $x++) {
        $i = $o + $x * 4
        if ($px[$i] -ge 235 -and $px[$i + 1] -ge 235 -and $px[$i + 2] -ge 235) {
          $run++
          if ($run -ge 60) { if ($top -lt 0) { $top = $y }; $bot = $y; if ($x - $run + 1 -lt $left) { $left = $x - $run + 1 }; if ($x -gt $right) { $right = $x } }
        } else { $run = 0 }
      }
    }
    $bw = $right - $left; $bh = $bot - $top
    if ($top -ge 0 -and $bw -ge 80 -and $bw -le 260 -and $bh -ge 12 -and $bh -le 50) {
      $p = New-Object Win+POINT; [Win]::GetCursorPos([ref]$p) | Out-Null
      Click ($r.L + [int](($left + $right) / 2)) ($r.T + [int](($top + $bot) / 2))
      [Win]::SetCursorPos($p.X, $p.Y) | Out-Null
      Start-Sleep -Milliseconds 400
      return $true
    }
  }
  return $false
}
# The desktop app has no shortcut or deep link for a new window, so drive its
# title-bar menu: ☰ > File > New Session in New Window.
function Open-TestApp($main) {
  if (-not $main) { return $null }
  $before = Claude-Windows
  $r = New-Object Win+RECT; [Win]::GetWindowRect($main, [ref]$r) | Out-Null
  $s = [Win]::GetDpiForWindow($main) / 96.0
  $p = New-Object Win+POINT; [Win]::GetCursorPos([ref]$p) | Out-Null
  [Win]::SetForegroundWindow($main) | Out-Null
  Start-Sleep -Milliseconds 300
  # The open menu is an untitled Claude window; click ☰ until one appears
  # (the first click can be eaten by a popover such as the folder picker).
  $opened = $false
  for ($i = 0; $i -lt 4 -and -not $opened; $i++) {
    $popups = @([Win]::Find("Chrome_WidgetWin_1", "claude", $true))
    Click ($r.L + [int](35 * $s)) ($r.T + [int](17 * $s))
    $end = (Get-Date).AddMilliseconds(1500)
    while (-not $opened -and (Get-Date) -lt $end) {
      Start-Sleep -Milliseconds 150
      $opened = @([Win]::Find("Chrome_WidgetWin_1", "claude", $true) | Where-Object { $popups -notcontains $_ }).Count -gt 0
    }
  }
  if ($opened) {
    Start-Sleep -Milliseconds 300
    Press 0x28; Press 0x27; Press 0x28; Press 0x0D   # Down, Right, Down, Enter
  }
  [Win]::SetCursorPos($p.X, $p.Y) | Out-Null
  if (-not $opened) { return $null }
  return Wait-Window "Chrome_WidgetWin_1" "claude" $before 10
}
function Open-Pane($pane) {
  $before = @([Win]::Find($cls, ""))
  Start-Process wt.exe -ArgumentList ("-w new new-tab $pane")
  return Wait-Window $cls "" $before
}

function Trust-Folder($path) {
  $script = Join-Path $PSScriptRoot "trust-folder.js"
  if (-not (Get-Command node -ErrorAction SilentlyContinue) -or -not (Test-Path $script)) { return }
  node $script $path 2>$null | Out-Null
}

function Close-Caller {
  $me    = Get-CimInstance Win32_Process -Filter "ProcessId=$PID"
  $shell = Get-CimInstance Win32_Process -Filter "ProcessId=$($me.ParentProcessId)"
  if (-not $shell -or @("powershell.exe", "pwsh.exe") -notcontains $shell.Name) { return }
  if ($shell.CreationDate -gt $me.CreationDate) { return }
  $h = [Win]::OpenProcess(0x0001, $false, [uint32]$shell.ProcessId)
  if ($h -ne [IntPtr]::Zero) { [Win]::TerminateProcess($h, 0) | Out-Null; [Win]::CloseHandle($h) | Out-Null }
}

$wa     = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$leftW  = [int]($wa.Width * 0.34)
$gitW   = [int]($wa.Width * 0.285)
$topH   = [int]($wa.Height * 0.39)
$midX   = $wa.X + $leftW
$qaX    = $midX + $gitW
$qaW    = $wa.X + $wa.Width - $qaX
$restW  = $wa.Width - $leftW
$botY   = $wa.Y + $topH
$botH   = $wa.Height - $topH
$hasPwsh = [bool](Get-Command pwsh -ErrorAction SilentlyContinue)
$sh     = if ($hasPwsh) { "pwsh" } else { "powershell" }
$wtProfile = if ($hasPwsh) { "PowerShell" } else { "Windows PowerShell" }
$cls    = "CASCADIA_HOSTING_WINDOW_CLASS"

$halfH  = [int]($wa.Height / 2)

Trust-Folder $Dir

$review = Open-Pane (Pane 'Review' 'claude --model sonnet')
Place $review $wa.X ($wa.Y + $halfH) $leftW ($wa.Height - $halfH)

$git = Open-Pane (Pane 'git' (Git-Command))
Place $git $midX $wa.Y $gitW $topH

$qa = Open-Pane (Pane 'QA' 'claude --model haiku --permission-mode plan')
Place $qa $qaX $wa.Y $qaW $topH

# Main desktop app: reuses the already-open Claude window if there is one.
Start-Process ("claude://code/new?folder=" + [uri]::EscapeDataString($Dir))
$end = (Get-Date).AddSeconds(20)
while (-not ($app = Main-App) -and (Get-Date) -lt $end) { Start-Sleep -Milliseconds 400 }
Place $app $midX $botY $restW $botH
if ($app) { [Win]::SetForegroundWindow($app) | Out-Null }
Accept-Trust $app | Out-Null

# Test: a second Claude desktop window in the old Test terminal slot (top-left).
$test = Open-TestApp $app
Place $test $wa.X $wa.Y $leftW $halfH

if ($CloseCaller) { Close-Caller }
