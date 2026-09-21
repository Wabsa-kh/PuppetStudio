// Windows-only input adapter. Polls only explicit app shortcuts; no text capture.
using System;
using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

internal static class InputBridge {
    [DllImport("user32.dll")]
    private static extern short GetAsyncKeyState(int key);
    private static bool Down(int key) { return (GetAsyncKeyState(key) & 0x8000) != 0; }
    private static int Main(string[] args) {
        if (args.Length != 3) return 2;
        int port, parentId;
        if (!int.TryParse(args[0], out port) || !int.TryParse(args[1], out parentId)) return 2;
        if (port < 1024 || port > 65535 || args[2].Length < 20) return 2;
        try {
            var parent = Process.GetProcessById(parentId);
            using (var udp = new UdpClient()) {
                udp.Connect(IPAddress.Loopback, port);
                int[] keys = {0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x4D,0x42,0x20};
                bool[] previous = new bool[keys.Length];
                int ticks = 0;
                while (!parent.HasExited) {
                    bool modifiers = Down(0x11) && Down(0x12);
                    for (int i = 0; i < keys.Length; i++) {
                        bool pressed = modifiers && Down(keys[i]);
                        if (pressed != previous[i]) {
                            string action = i < 9 ? "expression:" + i : i == 9 ? "mute" : i == 10 ? "blink" : "ptt";
                            string message = args[2] + "|" + action + "|" + (pressed ? "1" : "0");
                            byte[] bytes = Encoding.UTF8.GetBytes(message);
                            udp.Send(bytes, bytes.Length);
                            previous[i] = pressed;
                        }
                    }
                    if (++ticks % 30 == 0) {
                        byte[] bytes = Encoding.UTF8.GetBytes(args[2] + "|heartbeat|1");
                        udp.Send(bytes, bytes.Length);
                    }
                    Thread.Sleep(16);
                }
            }
            return 0;
        } catch { return 1; }
    }
}
