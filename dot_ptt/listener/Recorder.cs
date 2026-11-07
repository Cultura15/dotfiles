// @ Jesson
// Captures 16 kHz mono 16-bit microphone audio, the format Whisper expects.

using NAudio.Wave;

namespace Jarvis.Listener;

internal sealed class Recorder : IDisposable
{
    const int SampleRate = 16000;
    const int BitsPerSample = 16;
    const int Channels = 1;
    const int BufferMilliseconds = 50;
    const float Int16Scale = 32768f;

    public static readonly WaveFormat Format = new(SampleRate, BitsPerSample, Channels);

    readonly object _gate = new();
    WaveIn? _wave;
    MemoryStream _buffer = new();
    long _maxBytes;

    public bool IsRecording => _wave != null;

    public void Start(int device, int maxSeconds)
    {
        lock (_gate)
        {
            StopDevice();
            _buffer = new MemoryStream();
            _maxBytes = (long)Format.AverageBytesPerSecond * Math.Max(1, maxSeconds);
            _wave = new WaveIn { DeviceNumber = device, WaveFormat = Format, BufferMilliseconds = BufferMilliseconds };
            _wave.DataAvailable += OnData;
            _wave.RecordingStopped += OnStopped;
            _wave.StartRecording();
        }
    }

    // Returns the recorded samples as floats in [-1, 1].
    public float[] Stop()
    {
        byte[] bytes;
        float[] samples;

        lock (_gate)
        {
            StopDevice();
            bytes = _buffer.ToArray();
        }

        samples = new float[bytes.Length / 2];
        for (int i = 0; i < samples.Length; i++)
            samples[i] = BitConverter.ToInt16(bytes, i * 2) / Int16Scale;
        return samples;
    }

    public static float Rms(float[] samples)
    {
        double sum = 0;

        if (samples.Length == 0) return 0;
        foreach (var s in samples) sum += s * s;
        return (float)Math.Sqrt(sum / samples.Length);
    }

    void OnData(object? sender, WaveInEventArgs e)
    {
        lock (_gate)
        {
            if (_buffer.Length < _maxBytes)
                _buffer.Write(e.Buffer, 0, (int)Math.Min(e.BytesRecorded, _maxBytes - _buffer.Length));
        }
    }

    static void OnStopped(object? sender, StoppedEventArgs e)
    {
        if (e.Exception != null) Log.Error("recording stopped", e.Exception);
    }

    void StopDevice()
    {
        if (_wave == null) return;
        try
        {
            _wave.DataAvailable -= OnData;
            _wave.StopRecording();
        }
        catch { }
        _wave.Dispose();
        _wave = null;
    }

    public void Dispose()
    {
        lock (_gate) StopDevice();
    }
}
