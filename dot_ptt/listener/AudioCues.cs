// @ Jesson
// Listening cues: a short sine beep, plus mp3 playback for the mic-on and intro sounds. Fire and forget.

using NAudio.Wave;
using NAudio.Wave.SampleProviders;

namespace Jarvis.Listener;

internal static class AudioCues
{
    const int SampleRate = 44100;
    const double Gain = 0.12;

    static readonly TimeSpan BeepTimeout = TimeSpan.FromSeconds(2);
    static readonly TimeSpan FileTimeout = TimeSpan.FromSeconds(60);

    public static void Beep(int frequency, int ms) => Task.Run(() =>
    {
        try
        {
            var tone = new SignalGenerator(SampleRate, 1) { Frequency = frequency, Gain = Gain, Type = SignalGeneratorType.Sin }
                .Take(TimeSpan.FromMilliseconds(ms));
            Speaker.Play(tone, BeepTimeout);
        }
        catch (Exception e)
        {
            Log.Error("beep", e);
        }
    });

    public static void PlayFile(string path) => PlayFiles([path]);

    // Plays the files one after another, in order.
    public static void PlayFiles(IEnumerable<string> paths) => Task.Run(() =>
    {
        foreach (var path in paths)
        {
            try
            {
                if (!File.Exists(path))
                {
                    Log.Error($"sound not found: {path}");
                    continue;
                }

                using var reader = new AudioFileReader(path);
                Speaker.Play(reader, FileTimeout);
            }
            catch (Exception e)
            {
                Log.Error("play " + path, e);
            }
        }
    });
}
