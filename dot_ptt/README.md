# dot_ptt: Jarvis voice for PowerShell

A push-to-talk voice layer for PowerShell. Hold **Right Ctrl** and talk, then let go. The
listener transcribes what you said offline with Whisper. If it matches a command in
`commands.ps1`, the focused PowerShell window runs that command and Jarvis replies in a robot
voice. If it doesn't match, the text is only typed into the prompt, and you press Enter yourself.

```
hold Right Ctrl ──► Jarvis.Listener.exe (tray)               PowerShell profile
                    record mic (NAudio, 16 kHz)
release ─────────►  Whisper.net ─► "Jarvis, let's go."
                    focused window is a terminal?
                      yes ─► presses Ctrl+Shift+F12 ───────► PSReadLine handler
                                                              GET over named pipe
                                                              match commands.ps1
                                                              Invoke-JarvisCommand 'lets-go'
                    INTRO / SPEAK ... ◄──────────────── Speak (pipe)
                    SAPI / Piper ─► robot effect ─► speakers
```

## Install

Needs the .NET 10 SDK (`winget install Microsoft.DotNet.SDK.10`). PowerShell 7 is recommended, and 5.1 also works.

```powershell
.\install.ps1              # build, download ggml-base.en (~140 MB), add one line to both profiles
.\install.ps1 -Piper       # optional: Piper neural voice (en_GB alan)
.\install.ps1 -Startup     # optional: start the listener at logon
.\uninstall.ps1 [-Purge]
```

## Files

| Path | What |
|---|---|
| `config.json` | Hotkey, model, injection chord, voice settings |
| `commands.ps1` | Voice command map, which is also the whitelist of what voice can run |
| `profile/jarvis-voice.ps1` | Dot-sourced by `$PROFILE`: matching, `Speak`, PSReadLine handler, listener control |
| `listener/` | C# tray app: keyboard hook, mic, Whisper.net, named pipe, speech + robot effect |
| `bin/`, `models/`, `piper/` | Build output and downloads (gitignored) |
| `%LOCALAPPDATA%\JarvisStt\listener.log` | Listener log (also in the tray menu) |

## Commands in your shell

```powershell
Invoke-JarvisPhrase "jarvis lets go"   # test matching by typing, no mic needed
Get-JarvisCommand                      # list voice commands
Speak "Hello master"                   # robot voice
Get-JarvisStatus                       # listener state
Set-JarvisMute on|off|toggle
Start-JarvisListener / Stop-JarvisListener / Restart-JarvisListener   # restart after editing config/commands
```

Listener test modes:

```powershell
.\bin\Jarvis.Listener.exe --console               # live, with a console that prints what it hears
.\bin\Jarvis.Listener.exe --transcribe clip.wav   # transcribe a file
.\bin\Jarvis.Listener.exe --say "Hello master"    # speak once
```

## Config notes (`config.json`, no comments allowed)

- `hotkey`: a [`Keys`](https://learn.microsoft.com/dotnet/api/system.windows.forms.keys) name. For example `RControlKey` (default), `RMenu` (Right Alt), `F13`, `Scroll`.
  Pressing any other key while holding it cancels the recording, so Right Ctrl+C still works normally.
- `minHoldMs`: taps shorter than this are ignored.
- `injectChord`: the hidden key the listener presses in the terminal. If you change it, restart both the listener and your shells.
- `targetWindowClasses`: which windows count as a terminal. Defaults are Windows Terminal and the classic console.
- `model`: `models/ggml-tiny.en.bin` / `base.en` / `small.en` (re-run `install.ps1 -Model small.en`).
- `voice.engine`: `sapi` or `piper`. `voice.robot`/`robotAmount` set the robot effect (0 = clean voice).

## Safety

- Voice only ever runs entries in `commands.ps1`. Any other speech is just typed into the prompt.
- Entries with `Confirm = $true` get typed into the prompt, but you press Enter yourself.
- A command only runs when the prompt line is empty. If you were typing something, the transcript is appended to it.
- Only the focused terminal receives anything. If another app is focused, you get a tray balloon instead.
- The named pipe is per-user (`CurrentUserOnly`), and a transcript expires 15 s after you speak.
