// @ Jesson
// Per-user named pipe: one request line in, one response line out.
// Commands: PING | GET | LAST | STATUS | INTRO | SPEAK text | MUTE on|off|toggle | VOICE on|off|toggle | QUIT

using System.IO.Pipes;
using System.Text;

namespace Jarvis.Listener;

internal sealed class PipeServer : IDisposable
{
    const int BufferSize = 1024;
    const int RetryDelayMs = 1000;

    static readonly TimeSpan ReadTimeout = TimeSpan.FromSeconds(3);
    static readonly UTF8Encoding Encoding = new(false);

    readonly Func<string, string> _handler;
    readonly CancellationTokenSource _cts = new();

    public static string Name => "JarvisStt-" + Environment.UserName;

    public PipeServer(Func<string, string> handler) => _handler = handler;

    public void Start() => _ = Task.Run(LoopAsync);

    async Task LoopAsync()
    {
        NamedPipeServerStream server;

        while (!_cts.IsCancellationRequested)
        {
            try
            {
                server = CreateServer();
            }
            catch (Exception e)
            {
                Log.Error("create pipe", e);
                await Task.Delay(RetryDelayMs);
                continue;
            }

            try
            {
                await server.WaitForConnectionAsync(_cts.Token);
            }
            catch (OperationCanceledException)
            {
                server.Dispose();
                break;
            }
            catch (Exception e)
            {
                Log.Error("pipe wait", e);
                server.Dispose();
                continue;
            }

            _ = Task.Run(() => HandleAsync(server));
        }
    }

    // CurrentUserOnly: other accounts on the machine can't connect.
    static NamedPipeServerStream CreateServer() => new(
        Name,
        PipeDirection.InOut,
        NamedPipeServerStream.MaxAllowedServerInstances,
        PipeTransmissionMode.Byte,
        PipeOptions.Asynchronous | PipeOptions.CurrentUserOnly);

    async Task HandleAsync(NamedPipeServerStream stream)
    {
        string? request;
        string response;

        using (stream)
        {
            try
            {
                using var reader = new StreamReader(stream, Encoding, false, BufferSize, leaveOpen: true);
                using var writer = new StreamWriter(stream, Encoding, BufferSize, leaveOpen: true) { AutoFlush = true };

                request = await reader.ReadLineAsync().WaitAsync(ReadTimeout);
                response = request == null ? "" : _handler(request) ?? "";
                await writer.WriteLineAsync(response);
                stream.WaitForPipeDrain();
            }
            catch (Exception e)
            {
                Log.Error("pipe client", e);
            }
        }
    }

    public void Dispose() => _cts.Cancel();
}
