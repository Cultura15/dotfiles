// @ Jesson
// Checks the focused window and presses the hidden chord the PowerShell profile listens for.

using System.Runtime.InteropServices;
using System.Text;

namespace Jarvis.Listener;

internal static class Injector
{
    const uint INPUT_KEYBOARD = 1;
    const uint KEYEVENTF_KEYUP = 0x2;
    const ushort VK_SHIFT = 0x10;
    const ushort VK_CONTROL = 0x11;
    const ushort VK_MENU = 0x12;
    const ushort VK_LWIN = 0x5B;
    const int KEY_DOWN_BIT = 0x8000;
    const int ReleaseWaitMs = 500;
    const int ClassNameLength = 256;

    [StructLayout(LayoutKind.Sequential)]
    struct INPUT { public uint type; public InputUnion u; }

    [StructLayout(LayoutKind.Explicit)]
    struct InputUnion { [FieldOffset(0)] public MOUSEINPUT mi; [FieldOffset(0)] public KEYBDINPUT ki; }

    [StructLayout(LayoutKind.Sequential)]
    struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr extra; }

    [StructLayout(LayoutKind.Sequential)]
    struct KEYBDINPUT { public ushort wVk, wScan; public uint dwFlags, time; public IntPtr extra; }

    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", SetLastError = true)] static extern uint SendInput(uint n, INPUT[] inputs, int size);
    [DllImport("user32.dll")] static extern uint MapVirtualKey(uint code, uint mapType);
    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int vk);

    public static string ForegroundClass()
    {
        var name = new StringBuilder(ClassNameLength);
        GetClassName(GetForegroundWindow(), name, name.Capacity);
        return name.ToString();
    }

    public static bool ForegroundIsTarget(IEnumerable<string> classes)
    {
        var current = ForegroundClass();
        return classes.Any(c => string.Equals(c, current, StringComparison.OrdinalIgnoreCase));
    }

    public static bool SendChord(string chord)
    {
        var keys = ParseChord(chord);
        var inputs = new List<INPUT>();
        INPUT[] batch;

        WaitForModifiersReleased();

        foreach (var vk in keys) inputs.Add(Key(vk, up: false));
        for (int i = keys.Count - 1; i >= 0; i--) inputs.Add(Key(keys[i], up: true));

        batch = inputs.ToArray();
        return SendInput((uint)batch.Length, batch, Marshal.SizeOf<INPUT>()) == batch.Length;
    }

    // "Ctrl+Shift+F12" -> virtual-key codes
    static List<ushort> ParseChord(string chord)
    {
        var keys = new List<ushort>();
        var parts = chord.Split('+', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);

        foreach (var part in parts)
        {
            ushort vk = part.ToLowerInvariant() switch
            {
                "ctrl" or "control" => VK_CONTROL,
                "shift" => VK_SHIFT,
                "alt" => VK_MENU,
                "win" => VK_LWIN,
                _ => Enum.TryParse<Keys>(part, true, out var key)
                    ? (ushort)key
                    : throw new FormatException($"Unknown key '{part}' in chord '{chord}'"),
            };
            keys.Add(vk);
        }
        return keys;
    }

    static void WaitForModifiersReleased()
    {
        var deadline = DateTime.UtcNow.AddMilliseconds(ReleaseWaitMs);
        while (DateTime.UtcNow < deadline && AnyModifierDown()) Thread.Sleep(10);
    }

    static bool AnyModifierDown()
    {
        int state = (ushort)GetAsyncKeyState(VK_CONTROL) | (ushort)GetAsyncKeyState(VK_SHIFT) | (ushort)GetAsyncKeyState(VK_MENU);
        return (state & KEY_DOWN_BIT) != 0;
    }

    static INPUT Key(ushort vk, bool up) => new()
    {
        type = INPUT_KEYBOARD,
        u = new InputUnion
        {
            ki = new KEYBDINPUT { wVk = vk, wScan = (ushort)MapVirtualKey(vk, 0), dwFlags = up ? KEYEVENTF_KEYUP : 0 },
        },
    };
}
