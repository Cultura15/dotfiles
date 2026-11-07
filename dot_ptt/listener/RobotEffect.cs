// @ Jesson
// Robot voice: short feedback comb filter (metallic resonance) plus gentle ring modulation.
// Amount 0 = clean voice, 1 = full robot.

using NAudio.Wave;

namespace Jarvis.Listener;

internal sealed class RobotEffect : ISampleProvider
{
    const double DelaySeconds = 0.006;
    const double RingHz = 45.0;
    const float FeedbackGain = 0.55f;
    const float OutputGain = 0.85f;

    readonly ISampleProvider _source;
    readonly float _amount;
    readonly float _feedback;
    readonly float[] _delay;
    readonly double _phaseStep;
    readonly int _channels;
    int _pos;
    long _frame;

    public WaveFormat WaveFormat => _source.WaveFormat;

    public RobotEffect(ISampleProvider source, float amount)
    {
        int sampleRate = source.WaveFormat.SampleRate;

        _source = source;
        _amount = amount;
        _feedback = FeedbackGain * amount;
        _channels = source.WaveFormat.Channels;
        _delay = new float[Math.Max(1, (int)(sampleRate * DelaySeconds)) * _channels];
        _phaseStep = 2 * Math.PI * RingHz / sampleRate;
    }

    public int Read(Span<float> buffer)
    {
        int count = _source.Read(buffer);
        float combed;
        float ring;
        float modulated;

        for (int i = 0; i < count; i++)
        {
            combed = buffer[i] + _feedback * _delay[_pos];
            _delay[_pos] = combed;
            _pos = (_pos + 1) % _delay.Length;

            if (i % _channels == 0) _frame++;
            ring = (float)Math.Sin(_frame * _phaseStep);
            modulated = combed * (1 - 0.5f * _amount + 0.5f * _amount * ring);
            buffer[i] = Math.Clamp(modulated * OutputGain, -1f, 1f);
        }
        return count;
    }
}
