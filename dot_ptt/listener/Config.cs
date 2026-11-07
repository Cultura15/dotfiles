// @ Jesson
// Listener settings loaded from dot_ptt\config.json. The exe lives in dot_ptt\bin (or deeper while
// developing), so the file is found by walking up from the exe folder.

using System.Text.Json;
using System.Text.Json.Serialization;

namespace Jarvis.Listener;

public sealed class Config
{
    const string FileName = "config.json";
    const int SearchDepth = 7;

    static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        ReadCommentHandling = JsonCommentHandling.Skip,
        AllowTrailingCommas = true,
    };

    public string Hotkey { get; set; } = "RControlKey";
    public int MinHoldMs { get; set; } = 250;
    public int MaxRecordSeconds { get; set; } = 15;
    public int MicDevice { get; set; } = -1;
    public string Model { get; set; } = "models/ggml-base.en.bin";
    public string Language { get; set; } = "en";
    public int Threads { get; set; } = 4;
    public bool Beep { get; set; } = true;
    public string MicOnSound { get; set; } = "sounds/mic-on.mp3";
    public string[] IntroSounds { get; set; } = ["sounds/jarvis-intro-1.mp3", "sounds/jarvis-intro.mp3"];
    public string InjectChord { get; set; } = "Ctrl+Shift+F12";
    public string[] TargetWindowClasses { get; set; } = ["CASCADIA_HOSTING_WINDOW_CLASS", "ConsoleWindowClass"];
    public bool AutoStart { get; set; } = true;
    public VoiceConfig Voice { get; set; } = new();

    [JsonIgnore] public string FilePath { get; private set; } = "";
    [JsonIgnore] public string BaseDir { get; private set; } = AppContext.BaseDirectory;

    public static Config Load(string? path)
    {
        Config config;

        path ??= Find();
        if (path == null || !File.Exists(path))
        {
            Log.Info($"{FileName} not found ({path ?? "searched up from exe"}); using defaults");
            return new Config();
        }

        config = JsonSerializer.Deserialize<Config>(File.ReadAllText(path), JsonOptions) ?? new Config();
        config.FilePath = Path.GetFullPath(path);
        config.BaseDir = Path.GetDirectoryName(config.FilePath)!;
        return config;
    }

    public string Resolve(string path) =>
        Path.IsPathRooted(path) ? path : Path.GetFullPath(Path.Combine(BaseDir, path));

    static string? Find()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        string candidate;

        for (int i = 0; i < SearchDepth && dir != null; i++, dir = dir.Parent)
        {
            candidate = Path.Combine(dir.FullName, FileName);
            if (File.Exists(candidate)) return candidate;
        }
        return null;
    }
}
