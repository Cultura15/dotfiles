// @ Jesson
// Entry point.
//   Jarvis.Listener.exe [--config path] [--console]   run the tray listener
//   Jarvis.Listener.exe --transcribe file.wav          print a transcript and exit
//   Jarvis.Listener.exe --say "text"                   speak with the robot voice and exit

using System.Diagnostics;

namespace Jarvis.Listener;

internal static class Program
{
    public const string MutexName = @"Local\JarvisStt.Listener";

    const int ExitOk = 0;
    const int ExitModelError = 1;
    const int ExitConfigError = 2;

    [STAThread]
    static int Main(string[] args)
    {
        string? configPath = null;
        string? transcribeFile = null;
        string? sayText = null;
        bool console = false;
        Config config;

        for (int i = 0; i < args.Length; i++)
        {
            switch (args[i].ToLowerInvariant())
            {
                case "--config" when i + 1 < args.Length: configPath = args[++i]; break;
                case "--transcribe" when i + 1 < args.Length: transcribeFile = args[++i]; break;
                case "--say" when i + 1 < args.Length: sayText = args[++i]; break;
                case "--console": console = true; break;
            }
        }

        if (console || transcribeFile != null || sayText != null) NativeConsole.Attach(allocate: console);
        Log.ToConsole = console;

        try
        {
            config = Config.Load(configPath);
        }
        catch (Exception e)
        {
            Log.Error("config.json is invalid", e);
            Console.Error.WriteLine($"config.json is invalid: {e.Message}");
            return ExitConfigError;
        }

        if (transcribeFile != null) return RunTranscribe(config, transcribeFile);
        if (sayText != null) return RunSay(config, sayText);
        return RunTray(config, console);
    }

    static int RunTray(Config config, bool console)
    {
        using var mutex = new Mutex(true, MutexName, out bool created);
        if (!created)
        {
            Log.Info("listener already running; exiting");
            return ExitOk;
        }

        ApplicationConfiguration.Initialize();
        Application.ThreadException += (_, e) => Log.Error("UI thread", e.Exception);
        AppDomain.CurrentDomain.UnhandledException += (_, e) => Log.Error("unhandled", e.ExceptionObject as Exception);
        Application.Run(new TrayApp(config, console));
        return ExitOk;
    }

    static int RunTranscribe(Config config, string file)
    {
        using var transcriber = new Transcriber(config);
        var hintPath = Path.Combine(Log.Dir, "hint.txt");
        var stopwatch = Stopwatch.StartNew();
        string? hint;
        string text;

        if (!transcriber.Ready)
        {
            Console.Error.WriteLine(transcriber.Error);
            return ExitModelError;
        }

        hint = File.Exists(hintPath) ? File.ReadAllText(hintPath) : null;
        text = transcriber.TranscribeAsync(Transcriber.LoadFile(file), hint).GetAwaiter().GetResult();

        Console.WriteLine(text);
        Console.Error.WriteLine($"({stopwatch.ElapsedMilliseconds} ms)");
        return ExitOk;
    }

    static int RunSay(Config config, string text)
    {
        using var speaker = new Speaker(config);
        speaker.SpeakNow(text);
        return ExitOk;
    }
}
