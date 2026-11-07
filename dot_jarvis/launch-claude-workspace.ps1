param(
  [string]$Dir = (Get-Location).Path,
  [switch]$CloseCaller
)

Add-Type -AssemblyName System.Windows.Forms
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
  [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
  [DllImport("kernel32.dll")] public static extern bool TerminateProcess(IntPtr h, uint code);
  [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
  public static List<IntPtr> Find(string cls, string proc) {
    var list = new List<IntPtr>();
    EnumWindows((h, l) => {
      if (!IsWindowVisible(h)) return true;
      var c = new StringBuilder(256); GetClassName(h, c, 256);
      if (c.ToString() != cls) return true;
      var t = new StringBuilder(256); GetWindowText(h, t, 256);
      if (t.Length == 0) return true;
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
function Pane($title, $model, $extra = "", [switch]$live) {
  $lock = if ($live) { "" } else { "--suppressApplicationTitle " }
  "--title `"$title`" $lock-d `"$Dir`" $sh -NoExit -Command claude --model $model $extra"
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
  $cmd   = Get-CimInstance Win32_Process -Filter "ProcessId=$($me.ParentProcessId)"
  if (-not $cmd -or $cmd.Name -ne "cmd.exe") { return }
  $shell = Get-CimInstance Win32_Process -Filter "ProcessId=$($cmd.ParentProcessId)"
  if (-not $shell -or @("powershell.exe", "pwsh.exe", "cmd.exe") -notcontains $shell.Name) { return }
  if ($shell.CreationDate -gt $cmd.CreationDate) { return }
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
$sh     = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
$cls    = "CASCADIA_HOSTING_WINDOW_CLASS"

$halfH  = [int]($wa.Height / 2)

Trust-Folder $Dir

$test = Open-Pane (Pane 'Test' 'sonnet')
Place $test $wa.X $wa.Y $leftW $halfH

$review = Open-Pane (Pane 'Review' 'sonnet')
Place $review $wa.X ($wa.Y + $halfH) $leftW ($wa.Height - $halfH)

$git = Open-Pane (Pane 'git' 'sonnet')
Place $git $midX $wa.Y $gitW $topH

$qa = Open-Pane (Pane 'QA' 'haiku' '--permission-mode plan')
Place $qa $qaX $wa.Y $qaW $topH

Start-Process ("claude://code/new?folder=" + [uri]::EscapeDataString($Dir))
$app = Wait-Window "Chrome_WidgetWin_1" "claude" @()
Place $app $midX $botY $restW $botH

if ($CloseCaller) { Close-Caller }
