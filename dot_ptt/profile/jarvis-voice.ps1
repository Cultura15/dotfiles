# @ Jesson
# Jarvis voice layer for PowerShell 5.1 and 7. Dot-sourced from $PROFILE (install.ps1 adds the line).
# Flow: listener presses a hidden chord -> PSReadLine handler pulls the text over the pipe ->
# a whitelisted command from commands.ps1 runs, or the text is just typed for you to review.

$global:JarvisVoice = @{
    Root            = Split-Path $PSScriptRoot -Parent
    RepoRoot        = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    PipeName        = "JarvisStt-$env:USERNAME"
    MutexName       = 'Local\JarvisStt.Listener'
    DataDir         = Join-Path $env:LOCALAPPDATA 'JarvisStt'
    DefaultChord    = 'Ctrl+Shift+F12'
    WakeWords       = '^((hey|ok|okay|yo) )?(jarvis|jervis|jarvez|travis)( |$)'
    Apostrophes     = "['``" + [char]0x2019 + ']'
    HintMaxLength   = 600
    ExactMatchUpTo  = 4
    FuzzyRatio      = 0.2
    PipeTimeoutMs   = 500
    PipeBufferSize  = 1024
    StopWaitSeconds = 5
    Commands        = $null
    Config          = $null
    Synth           = $null
}
$JarvisVoice.ConfigPath   = Join-Path $JarvisVoice.Root 'config.json'
$JarvisVoice.CommandsPath = Join-Path $JarvisVoice.Root 'commands.ps1'
$JarvisVoice.Exe          = Join-Path $JarvisVoice.Root 'bin\Jarvis.Listener.exe'
$JarvisVoice.HintPath     = Join-Path $JarvisVoice.DataDir 'hint.txt'


function Import-JarvisConfig {
    $global:JarvisVoice.Config   = Get-Content -Raw -LiteralPath $JarvisVoice.ConfigPath | ConvertFrom-Json
    $global:JarvisVoice.Commands = & $JarvisVoice.CommandsPath
    Write-JarvisHint
}

function Get-JarvisCommand {
    foreach ($id in $JarvisVoice.Commands.Keys) {
        $entry = $JarvisVoice.Commands[$id]
        [pscustomobject]@{
            Id      = $id
            Phrases = $entry.Phrases -join ' | '
            Reply   = if ($entry.Reply -is [scriptblock]) { '{ ... }' } else { $entry.Reply }
            Confirm = [bool]$entry.Confirm
        }
    }
}

# Command phrases are passed to Whisper as a prompt so it is more likely to hear them right.
function Write-JarvisHint {
    $encoding = New-Object Text.UTF8Encoding($false)
    $phrases  = New-Object Collections.Generic.List[string]
    $hint     = ''

    foreach ($entry in $JarvisVoice.Commands.Values) {
        foreach ($phrase in $entry.Phrases) {
            $phrases.Add("Jarvis, $(ConvertTo-JarvisPhrase $phrase).")
        }
    }

    $hint = ($phrases | Select-Object -Unique) -join ' '
    if ($hint.Length -gt $JarvisVoice.HintMaxLength) {
        $hint = $hint.Substring(0, $JarvisVoice.HintMaxLength)
    }

    try {
        New-Item -ItemType Directory -Force -Path $JarvisVoice.DataDir | Out-Null
        [IO.File]::WriteAllText($JarvisVoice.HintPath, $hint, $encoding)
    } catch { }
}

# "Jarvis, let's go!" -> "lets go"
function ConvertTo-JarvisPhrase([string]$Text) {
    $result = "$Text".ToLowerInvariant()

    $result = $result -replace $JarvisVoice.Apostrophes, ''
    $result = $result -replace '[^a-z0-9 ]', ' '
    $result = ($result -replace '\s+', ' ').Trim()
    $result = $result -replace $JarvisVoice.WakeWords, ''
    $result.Trim()
}

function Get-JarvisDistance([string]$a, [string]$b) {
    $n        = $a.Length
    $m        = $b.Length
    $previous = [int[]](0..$m)
    $current  = $null
    $cost     = 0

    if ($n -eq 0) { return $m }
    if ($m -eq 0) { return $n }

    for ($i = 1; $i -le $n; $i++) {
        $current    = New-Object int[] ($m + 1)
        $current[0] = $i
        for ($j = 1; $j -le $m; $j++) {
            $cost        = if ($a[$i - 1] -ceq $b[$j - 1]) { 0 } else { 1 }
            $current[$j] = [Math]::Min([Math]::Min($current[$j - 1] + 1, $previous[$j] + 1), $previous[$j - 1] + $cost)
        }
        $previous = $current
    }
    $previous[$m]
}

function Find-JarvisCommand([string]$Text) {
    $said     = ConvertTo-JarvisPhrase $Text
    $best     = $null
    $want     = ''
    $distance = 0
    $limit    = 0

    if (-not $said) { return $null }

    foreach ($id in $JarvisVoice.Commands.Keys) {
        $entry = $JarvisVoice.Commands[$id]
        foreach ($phrase in $entry.Phrases) {
            $want = ConvertTo-JarvisPhrase $phrase
            if (-not $want) { continue }

            $distance = Get-JarvisDistance $said $want
            $limit    = 0
            if ($want.Length -gt $JarvisVoice.ExactMatchUpTo) {
                $limit = [Math]::Max(1, [int][Math]::Floor($want.Length * $JarvisVoice.FuzzyRatio))
            }

            if ($distance -gt $limit) { continue }
            if ($best -and $distance -ge $best.Distance) { continue }

            $best = [pscustomobject]@{ Id = $id; Entry = $entry; Phrase = $phrase; Distance = $distance; Heard = $Text }
        }
    }
    $best
}

function Invoke-JarvisCommand([Parameter(Mandatory)][string]$Id) {
    $entry = $JarvisVoice.Commands[$Id]
    $reply = $null

    if (-not $entry) {
        Write-Warning "No Jarvis command '$Id'."
        return
    }

    $reply = if ($entry.Reply -is [scriptblock]) { & $entry.Reply } else { $entry.Reply }
    if ($reply) { Speak $reply }
    if ($entry.Action) { & $entry.Action }
}

# Test matching without a mic: Invoke-JarvisPhrase jarvis lets go
function Invoke-JarvisPhrase([Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$Text) {
    $said  = $Text -join ' '
    $match = Find-JarvisCommand $said

    if (-not $match) {
        Write-Host "[jarvis] no command matched '$said' (normalized: '$(ConvertTo-JarvisPhrase $said)')" -ForegroundColor DarkYellow
        return
    }

    Write-Host "[jarvis] '$said' -> $($match.Id) (distance $($match.Distance))" -ForegroundColor DarkCyan
    Invoke-JarvisCommand $match.Id
}

function Test-JarvisListener {
    $mutex = $null

    if ([Threading.Mutex]::TryOpenExisting($JarvisVoice.MutexName, [ref]$mutex)) {
        $mutex.Dispose()
        return $true
    }
    $false
}

function Send-JarvisMessage([string]$Message, [int]$TimeoutMs = $JarvisVoice.PipeTimeoutMs) {
    $encoding = New-Object Text.UTF8Encoding($false)
    $size     = $JarvisVoice.PipeBufferSize
    $client   = $null
    $writer   = $null
    $reader   = $null

    if (-not (Test-JarvisListener)) { return $null }

    $client = New-Object IO.Pipes.NamedPipeClientStream('.', $JarvisVoice.PipeName, [IO.Pipes.PipeDirection]::InOut)
    try {
        $client.Connect($TimeoutMs)
        $writer = New-Object IO.StreamWriter($client, $encoding, $size, $true)
        $reader = New-Object IO.StreamReader($client, $encoding, $false, $size, $true)
        $writer.AutoFlush = $true
        $writer.WriteLine(($Message -replace '[\r\n]+', ' '))
        $reader.ReadLine()
    } catch {
        $null
    } finally {
        $client.Dispose()
    }
}

function Start-JarvisListener([switch]$Quiet) {
    $arguments = @('--config', "`"$($JarvisVoice.ConfigPath)`"")

    if (Test-JarvisListener) { return }

    if (-not (Test-Path $JarvisVoice.Exe)) {
        if (-not $Quiet) {
            Write-Warning "Jarvis listener isn't built yet. Run: $(Join-Path $JarvisVoice.Root 'install.ps1')"
        }
        return
    }

    Write-JarvisHint
    Start-Process -FilePath $JarvisVoice.Exe -ArgumentList $arguments -WindowStyle Hidden
}

function Stop-JarvisListener {
    if ((Send-JarvisMessage 'QUIT') -ne 'OK') {
        Get-Process Jarvis.Listener -ErrorAction SilentlyContinue | Stop-Process -Force
    }
}

function Restart-JarvisListener {
    $deadline = (Get-Date).AddSeconds($JarvisVoice.StopWaitSeconds)

    Stop-JarvisListener
    while ((Test-JarvisListener) -and (Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 100
    }
    Import-JarvisConfig
    Start-JarvisListener
}

function Get-JarvisStatus {
    if (-not (Test-JarvisListener)) { return 'not running' }
    Send-JarvisMessage 'STATUS'
}

function Set-JarvisMute([ValidateSet('on', 'off', 'toggle')][string]$State = 'toggle') {
    Send-JarvisMessage "MUTE $State" | Out-Null
}

# Speaks through the listener (robot voice, non-blocking). Falls back to System.Speech, then plain text.
function Speak([Parameter(ValueFromRemainingArguments)][string[]]$Text) {
    $message = ($Text -join ' ').Trim()

    if (-not $message) { return }
    if ((Send-JarvisMessage "SPEAK $message") -eq 'OK') { return }

    if ($PSVersionTable.PSEdition -ne 'Core') {
        try {
            Add-Type -AssemblyName System.Speech
            if (-not $JarvisVoice.Synth) {
                $global:JarvisVoice.Synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
            }
            $JarvisVoice.Synth.SpeakAsync($message) | Out-Null
            return
        } catch { }
    }

    Write-Host "[jarvis] $message" -ForegroundColor Cyan
}

function Register-JarvisKeyHandler {
    $chord = $JarvisVoice.DefaultChord

    if (-not (Get-Module PSReadLine)) { return }
    if ($JarvisVoice.Config.injectChord) { $chord = $JarvisVoice.Config.injectChord }

    Set-PSReadLineKeyHandler -Chord $chord -BriefDescription 'JarvisVoice' -Description 'Receive text from the Jarvis voice listener' -ScriptBlock {
        $text   = Send-JarvisMessage 'GET'
        $line   = $null
        $cursor = $null
        $match  = $null
        $insert = ''

        if ([string]::IsNullOrWhiteSpace($text)) { return }

        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        $match = Find-JarvisCommand $text

        if ($match -and [string]::IsNullOrWhiteSpace($line)) {
            [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("Invoke-JarvisCommand '$($match.Id)'")
            if (-not $match.Entry.Confirm) {
                [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
            }
            return
        }

        $insert = $text.Trim() -replace '[.!?]+$', ''
        if ($line -and $cursor -gt 0 -and $line[$cursor - 1] -ne ' ') {
            $insert = " $insert"
        }
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($insert)
    }
}


try {
    Import-JarvisConfig
    if ($Host.Name -eq 'ConsoleHost') {
        Register-JarvisKeyHandler
        if ($JarvisVoice.Config.autoStart) {
            Start-JarvisListener -Quiet
        }
    }
} catch {
    Write-Warning "Jarvis voice failed to load: $_"
}
