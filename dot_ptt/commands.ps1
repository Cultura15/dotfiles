# @ Jesson
# Voice command whitelist. Only entries here can run; any other speech is just typed into the prompt.
# Phrases = what you say, Reply = spoken text or scriptblock, Action = scriptblock, Confirm = wait for Enter.

[ordered]@{
    'lets-go' = @{
        Phrases = 'jarvis lets go', 'lets go', 'wake up'
        Action  = {
            Send-JarvisMessage 'INTRO' | Out-Null

            $launcher = Join-Path $JarvisVoice.RepoRoot 'dot_jarvis\launch-claude-workspace.ps1'
            $workDir  = (Get-Location).Path

            Start-Process powershell -WindowStyle Hidden -ArgumentList @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass',
                '-File', "`"$launcher`"",
                '-Dir', "`"$workDir`""
            )
        }
    }

    'clear' = @{
        Phrases = 'clear screen', 'clear the screen', 'clear'
        Action  = { Clear-Host }
    }

    'status' = @{
        Phrases = 'status report', 'system status'
        Reply   = { "All systems operational. It is $(Get-Date -Format 'h:mm tt')." }
    }

    'time' = @{
        Phrases = 'what time is it', 'time'
        Reply   = { "It is $(Get-Date -Format 'h:mm tt')." }
    }

    'git-status' = @{
        Phrases = 'git status', 'repo status'
        Action  = { git status }
    }

    'home' = @{
        Phrases = 'go home'
        Action  = { Set-Location ~ }
    }

    'sleep' = @{
        Phrases = 'go to sleep', 'mute yourself'
        Reply   = 'Going quiet.'
        Action  = { Set-JarvisMute on }
    }

    'close' = @{
        Phrases = 'close terminal', 'close this window'
        Confirm = $true
        Action  = { exit }
    }
}
