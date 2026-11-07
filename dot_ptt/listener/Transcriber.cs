// @ Jesson
// Offline speech-to-text with Whisper.net. Not thread-safe: one transcription at a time.

using System.Text;
using System.Text.RegularExpressions;
using NAudio.Wave;
using NAudio.Wave.SampleProviders;
using Whisper.net;

namespace Jarvis.Listener;

internal sealed partial class Transcriber : IDisposable
{
    const int SampleRate = 16000;
    const int MinSamples = SampleRate + SampleRate / 10; // Whisper wants at least ~1 s of audio

    readonly Config _config;
    readonly WhisperFactory? _factory;

    public string? Error { get; }
    public bool Ready => _factory != null;

    public Transcriber(Config config)
    {
        var model = config.Resolve(config.Model);

        _config = config;
        if (!File.Exists(model))
        {
            Error = $"Whisper model not found: {model}. Run install.ps1.";
            return;
        }

        try
        {
            _factory = WhisperFactory.FromPath(model);
            Log.Info($"Whisper model loaded: {model}");
        }
        catch (Exception e)
        {
            Error = $"Could not load Whisper model: {e.Message}";
            Log.Error("load model", e);
        }
    }

    public async Task<string> TranscribeAsync(float[] samples, string? prompt, CancellationToken ct = default)
    {
        var text = new StringBuilder();
        WhisperProcessorBuilder builder;

        if (_factory == null) throw new InvalidOperationException(Error);
        if (samples.Length < MinSamples) Array.Resize(ref samples, MinSamples);

        builder = _factory.CreateBuilder()
            .WithLanguage(_config.Language)
            .WithThreads(Math.Max(1, _config.Threads))
            .WithNoContext()
            .WithSingleSegment();
        if (!string.IsNullOrWhiteSpace(prompt)) builder = builder.WithPrompt(prompt);

        await using var processor = builder.Build();
        await foreach (var segment in processor.ProcessAsync(samples, ct))
            text.Append(segment.Text);
        return Clean(text.ToString());
    }

    // Loads any audio file as 16 kHz mono floats (for --transcribe).
    public static float[] LoadFile(string path)
    {
        var all = new List<float>();
        var chunk = new float[SampleRate];
        int read;
        using var reader = new AudioFileReader(path);
        ISampleProvider source = reader;

        if (source.WaveFormat.Channels == 2) source = new StereoToMonoSampleProvider(source);
        if (source.WaveFormat.SampleRate != SampleRate) source = new WdlResamplingSampleProvider(source, SampleRate);

        while ((read = source.Read(chunk.AsSpan())) > 0)
            all.AddRange(chunk.AsSpan(0, read).ToArray());
        return all.ToArray();
    }

    // Drops Whisper's non-speech markers like [BLANK_AUDIO] or (music).
    static string Clean(string text)
    {
        text = Annotation().Replace(text, " ");
        return Spaces().Replace(text, " ").Trim();
    }

    [GeneratedRegex(@"\[[^\]]*\]|\([^)]*\)|\*[^*]*\*")] private static partial Regex Annotation();
    [GeneratedRegex(@"\s+")] private static partial Regex Spaces();

    public void Dispose() => _factory?.Dispose();
}
