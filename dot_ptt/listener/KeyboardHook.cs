// @ Jesson
// Low-level keyboard hook for hold-to-talk. RegisterHotKey can't see key-up, WH_KEYBOARD_LL can.
// Must be created on a thread with a message loop (the WinForms UI thread). Keys are never swallowed.

using System.ComponentModel;
using System.Runtime.InteropServices;

namespace Jarvis.Listener;

internal sealed class KeyboardHook : IDisposable
{
    const int WH_KEYBOARD_LL = 13;
    const int WM_KEYDOWN = 0x100;
    const int WM_KEYUP = 0x101;
    const int WM_SYSKEYDOWN = 0x104;
    const int WM_SYSKEYUP = 0x105;
    const uint LLKHF_INJECTED = 0x10;

    delegate IntPtr HookProc(int code, IntPtr wParam, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    struct KBDLLHOOKSTRUCT { public uint vkCode, scanCode, flags, time; public IntPtr extra; }

    [DllImport("user32.dll", SetLastError = true)]
    static extern IntPtr SetWindowsHookEx(int idHook, HookProc fn, IntPtr hMod, uint threadId);
    [DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(IntPtr hook);
    [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr hook, int code, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern IntPtr GetModuleHandle(string? name);

    readonly HookProc _proc; // keep a reference so the GC doesn't collect the delegate
    readonly IntPtr _hook;
    readonly uint _vk;
    bool _down;

    public event Action? Pressed;
    public event Action? Released;
    public event Action? Interrupted;

    public KeyboardHook(Keys key)
    {
        _vk = (uint)key;
        _proc = Callback;
        _hook = SetWindowsHookEx(WH_KEYBOARD_LL, _proc, GetModuleHandle(null), 0);
        if (_hook == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
    }

    IntPtr Callback(int code, IntPtr wParam, IntPtr lParam)
    {
        if (code >= 0) HandleKey((int)wParam, Marshal.PtrToStructure<KBDLLHOOKSTRUCT>(lParam));
        return CallNextHookEx(_hook, code, wParam, lParam);
    }

    void HandleKey(int message, KBDLLHOOKSTRUCT key)
    {
        bool isDown = message is WM_KEYDOWN or WM_SYSKEYDOWN;
        bool isUp = message is WM_KEYUP or WM_SYSKEYUP;
        bool injected = (key.flags & LLKHF_INJECTED) != 0;

        if (injected) return;

        if (key.vkCode != _vk)
        {
            if (isDown && _down) Interrupted?.Invoke();
            return;
        }

        if (isDown && !_down)
        {
            _down = true;
            Pressed?.Invoke();
        }
        else if (isUp && _down)
        {
            _down = false;
            Released?.Invoke();
        }
    }

    public void Dispose() => UnhookWindowsHookEx(_hook);
}
