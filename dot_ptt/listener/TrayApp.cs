// @ Jesson
// The whole listener: tray icon, hold-to-talk hook, recorder, Whisper, pipe and speech.
// UI work runs on the WinForms thread; transcription runs on the thread pool.

using System.Diagnostics;
using System.Drawing.Drawing2D;

namespace Jarvis.Listener;

internal enum ListenState { Loading, Idle, Listening, Transcribing, Muted, Error }

internal sealed class TrayApp : ApplicationContext
{
    const string AppName = "Jarvis voice";
    const float SilenceRms = 0.004f;
    const int StopBeepHz = 620;
    const int BeepMs = 70;
    const int HeardBalloonMs = 2500;
    const int ErrorBalloonMs = 5000;
    const int LastItemLength = 60;
    const int StatusItemLength = 80;
    const int TooltipLength = 120;

    static readonly TimeSpan PendingTtl = TimeSpan.FromSeconds(15);
    static readonly string HintPath = Path.Combine(Log.Dir, "hint.txt");

    readonly Config _config;
    readonly bool _console;
    readonly Control _ui = new();
    readonly Recorder _recorder = new();
    readonly System.Windows.Forms.Timer _holdTimer = new();
    readonly Dictionary<ListenState, Icon> _icons;
    readonly Speaker _speaker;
    readonly ToolStripMenuItem _statusItem;
    readonly ToolStripMenuItem _lastItem;
    readonly ToolStripMenuItem _muteItem;
    readonly ToolStripMenuItem _voiceItem;
    readonly NotifyIcon _tray;
    readonly KeyboardHook? _hook;
    readonly PipeServer _pipe;
    readonly object _pendingGate = new();

    Transcriber? _transcriber;
    ListenState _state = ListenState.Loading;
    string? _error;
    bool _muted;
    bool _interrupted;
    bool _armed;
    bool _busy;
    DateTime _pressedAt;
    string? _pending;
    DateTime _pendingAt;
    string _last = "";

    public TrayApp(Config config, bool console)
    {
        _config = config;
        _console = console;
        _ = _ui.Handle; // create the handle so BeginInvoke works

        _icons = CreateIcons();
        _speaker = new Speaker(config);

        _statusItem = new ToolStripMenuItem("Starting...") { Enabled = false };
        _lastItem = new ToolStripMenuItem("Last: (nothing yet)") { Enabled = false };
        _muteItem = new ToolStripMenuItem("Mute listening", null, (_, _) => SetMuted(!_muted));
        _voiceItem = new ToolStripMenuItem("Voice replies", null, (_, _) => SetVoice(!_speaker.Enabled)) { Checked = _speaker.Enabled };

        _tray = new NotifyIcon { Icon = _icons[ListenState.Loading], Visible = true, ContextMenuStrip = CreateMenu(), Text = AppName };
        _tray.MouseClick += (_, e) => { if (e.Button == MouseButtons.Left) SetMuted(!_muted); };

        _holdTimer.Tick += (_, _) => { _holdTimer.Stop(); Arm(); };
        _hook = CreateHook();

        _pipe = new PipeServer(HandleMessage);
        _pipe.Start();

        Task.Run(LoadTranscriber);

        Log.Info($"listener started; hotkey={config.Hotkey}, pipe={PipeServer.Name}, config={config.FilePath}");
        Print($"Jarvis listener started. Hold {config.Hotkey} to talk.");
    }

    static Dictionary<ListenState, Icon> CreateIcons() => new()
    {
        [ListenState.Loading] = MakeIcon(Color.SlateGray, false),
        [ListenState.Idle] = MakeIcon(Color.FromArgb(0, 150, 220), false),
        [ListenState.Listening] = MakeIcon(Color.FromArgb(230, 40, 40), false),
        [ListenState.Transcribing] = MakeIcon(Color.FromArgb(245, 160, 0), false),
        [ListenState.Muted] = MakeIcon(Color.DimGray, true),
        [ListenState.Error] = MakeIcon(Color.FromArgb(150, 30, 30), true),
    };

    ContextMenuStrip CreateMenu()
    {
        var menu = new ContextMenuStrip();

        menu.Items.AddRange(new ToolStripItem[]
        {
            _statusItem,
            _lastItem,
            new ToolStripSeparator(),
            _muteItem,
            _voiceItem,
            new ToolStripSeparator(),
            new ToolStripMenuItem("Open config", null, (_, _) => Open(_config.FilePath)),
            new ToolStripMenuItem("Open log", null, (_, _) => Open(Log.FilePath)),
            new ToolStripSeparator(),
            new ToolStripMenuItem("Quit", null, (_, _) => ExitThread()),
        });
        return menu;
    }

    KeyboardHook? CreateHook()
    {
        KeyboardHook hook;

        if (!Enum.TryParse<Keys>(_config.Hotkey, true, out var key))
        {
            Fail($"Unknown hotkey '{_config.Hotkey}' in config.json");
            return null;
        }

        try
        {
            hook = new KeyboardHook(key);
        }
        catch (Exception e)
        {
            Fail($"Keyboard hook failed: {e.Message}");
            return null;
        }

        hook.Pressed += () => _ui.BeginInvoke(OnPressed);
        hook.Released += () => _ui.BeginInvoke(OnReleased);
        hook.Interrupted += () => _ui.BeginInvoke(OnInterrupted);
        return hook;
    }

    void LoadTranscriber()
    {
        var transcriber = new Transcriber(_config);

        _ui.BeginInvoke(() =>
        {
            _transcriber = transcriber;
            if (!transcriber.Ready) Fail(transcriber.Error ?? "Whisper failed to load");
            else if (_state == ListenState.Loading) SetState(ListenState.Idle);
        });
    }

    void OnPressed()
    {
        if (_muted || _busy || _transcriber?.Ready != true) return;

        _interrupted = false;
        _armed = false;
        _pressedAt = DateTime.UtcNow;

        try
        {
            _recorder.Start(_config.MicDevice, _config.MaxRecordSeconds);
        }
        catch (Exception e)
        {
            Fail($"Microphone error: {e.Message}");
            return;
        }

        // Only beep / show "listening" once it's clearly a hold, not a Right Ctrl+C.
        _holdTimer.Interval = Math.Max(1, _config.MinHoldMs);
        _holdTimer.Start();
    }

    void Arm()
    {
        if (!_recorder.IsRecording || _interrupted) return;

        _armed = true;
        SetState(ListenState.Listening);
        if (_config.Beep) AudioCues.PlayFile(_config.Resolve(_config.MicOnSound));
    }

    void OnInterrupted()
    {
        if (!_recorder.IsRecording) return;

        _interrupted = true;
        _holdTimer.Stop();
        _recorder.Stop();
        SetState(ListenState.Idle);
    }

    void OnReleased()
    {
        float[] samples;
        TimeSpan held;
        float rms;

        if (!_recorder.IsRecording) return;

        _holdTimer.Stop();
        samples = _recorder.Stop();
        held = DateTime.UtcNow - _pressedAt;

        if (_interrupted || !_armed || held.TotalMilliseconds < _config.MinHoldMs)
        {
            SetState(ListenState.Idle);
            return;
        }

        if (_config.Beep) AudioCues.Beep(StopBeepHz, BeepMs);

        rms = Recorder.Rms(samples);
        if (rms < SilenceRms)
        {
            Log.Info($"ignored near-silent clip (rms {rms:F4})");
            SetState(ListenState.Idle);
            return;
        }

        _busy = true;
        SetState(ListenState.Transcribing);
        Transcribe(_transcriber!, samples, held, ReadHint());
    }

    void Transcribe(Transcriber transcriber, float[] samples, TimeSpan held, string? hint) => Task.Run(async () =>
    {
        var stopwatch = Stopwatch.StartNew();
        string text = "";

        try { text = await transcriber.TranscribeAsync(samples, hint); }
        catch (Exception e) { Log.Error("transcribe", e); }

        Log.Info($"heard \"{text}\" ({held.TotalSeconds:F1}s audio, {stopwatch.ElapsedMilliseconds} ms)");
        _ui.BeginInvoke(() => Deliver(text));
    });

    void Deliver(string text)
    {
        _busy = false;
        SetState(_muted ? ListenState.Muted : ListenState.Idle);
        if (string.IsNullOrWhiteSpace(text)) return;

        _last = text;
        _lastItem.Text = "Last: " + Truncate(text, LastItemLength);
        if (_console) Console.WriteLine($"> {text}");

        lock (_pendingGate)
        {
            _pending = text;
            _pendingAt = DateTime.UtcNow;
        }

        // Only the focused terminal gets it; anywhere else we just show what was heard.
        if (!Injector.ForegroundIsTarget(_config.TargetWindowClasses))
        {
            Log.Info($"focused window is '{Injector.ForegroundClass()}', not a terminal; not sending");
            _tray.ShowBalloonTip(HeardBalloonMs, "Jarvis heard (no terminal focused)", text, ToolTipIcon.Info);
            return;
        }

        try
        {
            if (!Injector.SendChord(_config.InjectChord)) Log.Error("SendInput was blocked");
        }
        catch (Exception e)
        {
            Log.Error("send chord", e);
        }
    }

    static string? ReadHint()
    {
        try { return File.Exists(HintPath) ? File.ReadAllText(HintPath) : null; }
        catch { return null; }
    }

    // Runs on a pool thread; UI changes are marshalled with BeginInvoke.
    string HandleMessage(string line)
    {
        var space = line.IndexOf(' ');
        var command = (space < 0 ? line : line[..space]).Trim().ToUpperInvariant();
        var argument = space < 0 ? "" : line[(space + 1)..].Trim();

        switch (command)
        {
            case "PING":
                return "PONG";
            case "GET":
                return TakePending();
            case "LAST":
                return _last;
            case "INTRO":
                AudioCues.PlayFiles(_config.IntroSounds.Select(_config.Resolve));
                return "OK";
            case "SPEAK":
                _speaker.Enqueue(argument);
                return "OK";
            case "STATUS":
                return Status();
            case "MUTE":
                _ui.BeginInvoke(() => SetMuted(Toggle(argument, _muted)));
                return "OK";
            case "VOICE":
                _ui.BeginInvoke(() => SetVoice(Toggle(argument, _speaker.Enabled)));
                return "OK";
            case "QUIT":
                _ui.BeginInvoke(ExitThread);
                return "OK";
            default:
                return "ERR unknown command";
        }
    }

    string TakePending()
    {
        string text;

        lock (_pendingGate)
        {
            text = _pending != null && DateTime.UtcNow - _pendingAt < PendingTtl ? _pending : "";
            _pending = null;
        }
        return text;
    }

    string Status()
    {
        var status = $"{_state}; muted={_muted}; voice={_speaker.Enabled}; hotkey={_config.Hotkey}; last=\"{_last}\"";
        return _error == null ? status : $"{status}; error={_error}";
    }

    static bool Toggle(string argument, bool current) => argument.ToLowerInvariant() switch
    {
        "on" or "true" or "1" => true,
        "off" or "false" or "0" => false,
        _ => !current,
    };

    void SetMuted(bool muted)
    {
        _muted = muted;
        _muteItem.Checked = muted;

        if (muted && _recorder.IsRecording)
        {
            _recorder.Stop();
            _holdTimer.Stop();
        }
        if (_state is not (ListenState.Error or ListenState.Loading or ListenState.Transcribing))
            SetState(muted ? ListenState.Muted : ListenState.Idle);

        Log.Info(muted ? "muted" : "unmuted");
    }

    void SetVoice(bool on)
    {
        _speaker.Enabled = on;
        _voiceItem.Checked = on;
    }

    void SetState(ListenState state)
    {
        string label;

        if (state == ListenState.Idle && _muted) state = ListenState.Muted;
        if (state == ListenState.Idle && _error != null) state = ListenState.Error;

        label = state switch
        {
            ListenState.Loading => "Loading Whisper model...",
            ListenState.Idle => $"Ready - hold {_config.Hotkey} to talk",
            ListenState.Listening => "Listening...",
            ListenState.Transcribing => "Transcribing...",
            ListenState.Muted => "Muted (click the icon to unmute)",
            ListenState.Error => "Error: " + _error,
            _ => state.ToString(),
        };

        _state = state;
        _tray.Icon = _icons[state];
        _statusItem.Text = Truncate(label, StatusItemLength);
        _tray.Text = Truncate($"{AppName}: {label}", TooltipLength);
    }

    void Fail(string message)
    {
        _error = message;
        Log.Error(message);
        SetState(ListenState.Error);
        _tray.ShowBalloonTip(ErrorBalloonMs, AppName, message, ToolTipIcon.Error);
        Print(message);
    }

    void Print(string message)
    {
        if (_console) Console.WriteLine(message);
    }

    static string Truncate(string text, int max) => text.Length <= max ? text : text[..(max - 3)] + "...";

    static void Open(string path)
    {
        if (string.IsNullOrEmpty(path) || !File.Exists(path)) return;

        try { Process.Start(new ProcessStartInfo(path) { UseShellExecute = true }); }
        catch (Exception e) { Log.Error("open " + path, e); }
    }

    static Icon MakeIcon(Color color, bool slash)
    {
        using var bitmap = new Bitmap(32, 32);
        using (var g = Graphics.FromImage(bitmap))
        using (var fill = new SolidBrush(color))
        using (var ring = new Pen(Color.White, 2.5f))
        using (var mic = new SolidBrush(Color.White))
        using (var slashPen = new Pen(Color.White, 3.5f))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.Clear(Color.Transparent);
            g.FillEllipse(fill, 2, 2, 28, 28);
            g.DrawEllipse(ring, 2, 2, 28, 28);
            g.FillRectangle(mic, 13, 8, 6, 11);
            g.FillEllipse(mic, 13, 5, 6, 6);
            g.FillEllipse(mic, 13, 16, 6, 6);
            g.FillRectangle(mic, 15, 21, 2, 4);
            g.FillRectangle(mic, 11, 24, 10, 2);
            if (slash) g.DrawLine(slashPen, 7, 25, 25, 7);
        }
        return Icon.FromHandle(bitmap.GetHicon());
    }

    protected override void ExitThreadCore()
    {
        Log.Info("listener stopping");
        _tray.Visible = false;
        _hook?.Dispose();
        _pipe.Dispose();
        _recorder.Dispose();
        _speaker.Dispose();
        _transcriber?.Dispose();
        _tray.Dispose();
        base.ExitThreadCore();
    }
}
