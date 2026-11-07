// @ Jesson
// "voice" section of config.json: how Jarvis speaks replies.

namespace Jarvis.Listener;

public sealed class VoiceConfig
{
    public bool Enabled { get; set; } = true;
    public string Engine { get; set; } = "sapi";
    public string Name { get; set; } = "";
    public int Rate { get; set; }
    public int Volume { get; set; } = 100;
    public bool Robot { get; set; } = true;
    public double RobotAmount { get; set; } = 0.6;
    public string PiperExe { get; set; } = "piper/piper.exe";
    public string PiperModel { get; set; } = "piper/en_GB-alan-medium.onnx";
}
