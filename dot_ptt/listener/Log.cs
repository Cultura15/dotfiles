// @ Jesson
// File log at %LOCALAPPDATA%\JarvisStt\listener.log, rotated at ~1 MB. Never throws.

namespace Jarvis.Listener;

internal static class Log
{
    const string FileName = "listener.log";
    const long MaxBytes = 1_000_000;

    static readonly object Gate = new();

    public static bool ToConsole;

    public static string Dir { get; } =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "JarvisStt");

    public static string FilePath => Path.Combine(Dir, FileName);

    public static void Info(string message) => Write("INFO ", message);

    public static void Error(string message, Exception? e = null) =>
        Write("ERROR", e == null ? message : $"{message}: {e.GetType().Name}: {e.Message}");

    static void Write(string level, string message)
    {
        var line = $"{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff} {level} {message}";

        lock (Gate)
        {
            try
            {
                Directory.CreateDirectory(Dir);
                var file = new FileInfo(FilePath);
                if (file.Exists && file.Length > MaxBytes) File.Move(FilePath, FilePath + ".old", true);
                File.AppendAllText(FilePath, line + Environment.NewLine);
            }
            catch { }

            if (ToConsole)
            {
                try { Console.Error.WriteLine(line); } catch { }
            }
        }
    }
}
