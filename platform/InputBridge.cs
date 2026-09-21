// Windows-only input adapter. Polls only explicit app shortcuts; no text capture.
using System;
using System.Diagnostics;
using System.Collections.Generic;
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
        if (args.Length < 3 || args.Length > 4) return 2;
        int port, parentId;
        if (!int.TryParse(args[0], out port) || !int.TryParse(args[1], out parentId)) return 2;
        if (port < 1024 || port > 65535 || args[2].Length < 20) return 2;
        try {
            var parent = Process.GetProcessById(parentId);
            using (var udp = new UdpClient()) {
                udp.Connect(IPAddress.Loopback, port);
                var keyList = new List<int>();
                var maskList = new List<int>();
                var actions = new List<string>();
                string configuration = args.Length == 4 ? args[3] : "";
                if (configuration.Length == 0) {
                    for (int i = 0; i < 9; i++) configuration += "expression:" + i + "," + (0x31+i) + ",3;";
                    configuration += "mute,77,3;blink,66,3;ptt,32,3;";
                    for (int i = 0; i < 9; i++) configuration += "costume:" + i + "," + (0x70+i) + ",3;";
                }
                foreach (string binding in configuration.Split(';')) {
                    if (binding.Length == 0) continue;
                    var parts = binding.Split(','); int key, mask;
                    if (parts.Length != 3 || !int.TryParse(parts[1], out key) || !int.TryParse(parts[2], out mask)) return 2;
                    if (key < 8 || key > 254 || mask < 0 || mask > 7 || parts[0].Length > 100 || keyList.Count >= 128) return 2;
                    keyList.Add(key); maskList.Add(mask); actions.Add(parts[0]);
                }
                int[] keys = keyList.ToArray();
                bool[] previous = new bool[keys.Length];
                int ticks = 0;
                while (!parent.HasExited) {
                    int modifiers = (Down(0x11) ? 1 : 0) | (Down(0x12) ? 2 : 0) | (Down(0x10) ? 4 : 0);
                    for (int i = 0; i < keys.Length; i++) {
                        bool pressed = modifiers == maskList[i] && Down(keys[i]);
                        if (pressed != previous[i]) {
                            string action = actions[i];
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
