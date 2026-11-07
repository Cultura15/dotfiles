// @ Jesson
// Gives the WinExe a console for --console / --transcribe / --say.

using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

namespace Jarvis.Listener;

internal static class NativeConsole
{
    const int ATTACH_PARENT_PROCESS = -1;
    const uint GENERIC_WRITE = 0x40000000;
    const uint FILE_SHARE_WRITE = 2;
    const uint OPEN_EXISTING = 3;
    const string Title = "Jarvis listener (console)";

    [DllImport("kernel32.dll")] static extern bool AttachConsole(int pid);
    [DllImport("kernel32.dll")] static extern bool AllocConsole();
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern SafeFileHandle CreateFile(string name, uint access, uint share, IntPtr sec, uint disposition, uint flags, IntPtr template);

    public static void Attach(bool allocate)
    {
        bool attached;
        SafeFileHandle handle;
        StreamWriter writer;

        // Redirected output (pipes, files) already works for a WinExe.
        if (Console.IsOutputRedirected && Console.IsErrorRedirected) return;

        attached = allocate ? AllocConsole() : AttachConsole(ATTACH_PARENT_PROCESS);
        if (!attached) return;

        handle = CreateFile("CONOUT$", GENERIC_WRITE, FILE_SHARE_WRITE, IntPtr.Zero, OPEN_EXISTING, 0, IntPtr.Zero);
        if (handle.IsInvalid) return;

        writer = new StreamWriter(new FileStream(handle, FileAccess.Write)) { AutoFlush = true };
        if (!Console.IsOutputRedirected) Console.SetOut(writer);
        if (!Console.IsErrorRedirected) Console.SetError(writer);
        if (allocate) Console.Title = Title;
    }
}
