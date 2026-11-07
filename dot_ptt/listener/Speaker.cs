// @ Jesson
// Speaks replies one at a time on a background thread: SAPI or Piper -> robot effect -> speakers.

using System.Collections.Concurrent;
using System.Diagnostics;
using System.Speech.Synthesis;
using NAudio.Wave;
using NAudio.Wave.SampleProviders;

namespace Jarvis.Listener;

internal sealed class Speaker : IDisposable
{
    const int PiperTimeoutMs = 30_000;
    const int MinRate = -10;
    const int MaxRate = 10;

    static readonly TimeSpan PlayTimeout = TimeSpan.FromSeconds(60);

    readonly Config _config;
    readonly BlockingCollection<string> _queue = new();
    readonly Thread _thread;

    public bool Enabled { get; set; }

    public Speaker(Config config)
    {
        _config = config;
        Enabled = config.Voice.Enabled;
        _thread = new Thread(Run) { IsBackground = true, Name = "speaker" };
        _thread.SetApartmentState(ApartmentState.STA);
        _thread.Start();
    }

    public void Enqueue(string text)
    {
        if (!Enabled || string.IsNullOrWhiteSpace(text) || _queue.IsAddingCompleted) return;
        _queue.Add(text.Trim());
    }

    // Blocking speak, used by the queue and by --say.
    public void SpeakNow(string text)
    {
        var voice = _config.Voice;
        bool usePiper = voice.Engine.Equals("piper", StringComparison.OrdinalIgnoreCase);
        ISampleProvider output;

        using var wav = (usePiper ? Piper(text) : null) ?? Sapi(text);
        wav.Position = 0;
        using var reader = new WaveFileReader(wav);

        output = reader.ToSampleProvider();
        if (voice.Robot) output = new RobotEffect(output, (float)Math.Clamp(voice.RobotAmount, 0, 1));
        output = new VolumeSampleProvider(output) { Volume = Math.Clamp(voice.Volume, 0, 100) / 100f };
        Play(output, PlayTimeout);
    }

    public static void Play(ISampleProvider samples, TimeSpan timeout)
    {
        using var output = new WaveOut();
        using var done = new ManualResetEventSlim();

        output.PlaybackStopped += (_, _) => done.Set();
        output.Init(samples);
        output.Play();
        done.Wait(timeout);
    }

    void Run()
    {
        foreach (var text in _queue.GetConsumingEnumerable())
        {
            try { SpeakNow(text); }
            catch (Exception e) { Log.Error("speak", e); }
        }
    }

    MemoryStream Sapi(string text)
    {
        var voiceName = _config.Voice.Name;
        var wav = new MemoryStream();
        using var synth = new SpeechSynthesizer();

        if (!string.IsNullOrWhiteSpace(voiceName))
        {
            try { synth.SelectVoice(voiceName); }
            catch (Exception e) { Log.Error($"voice '{voiceName}' not found", e); }
        }

        synth.Rate = Math.Clamp(_config.Voice.Rate, MinRate, MaxRate);
        synth.SetOutputToWaveStream(wav);
        synth.Speak(text);
        synth.SetOutputToNull();
        return wav;
    }

    MemoryStream? Piper(string text)
    {
        var exe = _config.Resolve(_config.Voice.PiperExe);
        var model = _config.Resolve(_config.Voice.PiperModel);
        var outFile = Path.Combine(Path.GetTempPath(), $"jarvis-{Guid.NewGuid():N}.wav");
        ProcessStartInfo startInfo;

        if (!File.Exists(exe) || !File.Exists(model))
        {
            Log.Error($"Piper not found ({exe} / {model}); falling back to SAPI. Run install.ps1 -Piper.");
            return null;
        }

        startInfo = new ProcessStartInfo(exe)
        {
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardInput = true,
            RedirectStandardError = true,
            WorkingDirectory = Path.GetDirectoryName(exe)!,
        };
        startInfo.ArgumentList.Add("--model");
        startInfo.ArgumentList.Add(model);
        startInfo.ArgumentList.Add("--output_file");
        startInfo.ArgumentList.Add(outFile);

        try
        {
            using var process = Process.Start(startInfo)!;
            process.StandardInput.WriteLine(text);
            process.StandardInput.Close();
            _ = process.StandardError.ReadToEndAsync();

            if (!process.WaitForExit(PiperTimeoutMs))
            {
                process.Kill();
                Log.Error("piper timed out");
                return null;
            }
            if (!File.Exists(outFile))
            {
                Log.Error($"piper exited {process.ExitCode} with no output");
                return null;
            }
            return new MemoryStream(File.ReadAllBytes(outFile));
        }
        catch (Exception e)
        {
            Log.Error("piper", e);
            return null;
        }
        finally
        {
            try { File.Delete(outFile); } catch { }
        }
    }

    public void Dispose() => _queue.CompleteAdding();
}
