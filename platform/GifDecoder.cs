using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Text;

// Converts a GIF into bounded, full-canvas PNG frames. Never loads executable content.
internal static class GifDecoder {
    private static int Main(string[] args) {
        if (args.Length != 2 || !Directory.Exists(args[1])) return 2;
        try {
            if (new FileInfo(args[0]).Length > 16777216) throw new Exception("GIF exceeds 16 MB.");
            using (Image image = Image.FromFile(args[0])) {
                int count = image.GetFrameCount(FrameDimension.Time);
                if (count < 1 || count > 256 || image.Width > 2048 || image.Height > 2048 || (long)image.Width * image.Height * count > 50331648)
                    throw new Exception("GIF exceeds the frame or decoded-size limit. Use up to 256 frames and smaller artwork.");
                byte[] delays = null;
                try { delays = image.GetPropertyItem(0x5100).Value; } catch (ArgumentException) { }
                var manifest = new StringBuilder("{\"frames\":[");
                for (int i = 0; i < count; i++) {
                    image.SelectActiveFrame(FrameDimension.Time, i);
                    string name = "frame_" + i.ToString("D4") + ".png";
                    using (var frame = new Bitmap(image.Width, image.Height, PixelFormat.Format32bppArgb)) {
                        using (var graphics = Graphics.FromImage(frame)) {
                            graphics.CompositingMode = System.Drawing.Drawing2D.CompositingMode.SourceCopy;
                            graphics.DrawImage(image, 0, 0, image.Width, image.Height);
                        }
                        frame.Save(Path.Combine(args[1], name), ImageFormat.Png);
                    }
                    int delay = delays != null && delays.Length >= (i + 1) * 4 ? BitConverter.ToInt32(delays, i * 4) : 10;
                    delay = Math.Max(2, Math.Min(1000, delay));
                    if (i > 0) manifest.Append(',');
                    manifest.Append("{\"file\":\"").Append(name).Append("\",\"milliseconds\":").Append(delay * 10).Append('}');
                }
                manifest.Append("]}");
                File.WriteAllText(Path.Combine(args[1], "manifest.json"), manifest.ToString());
            }
            return 0;
        } catch (Exception error) {
            File.WriteAllText(Path.Combine(args[1], "error.txt"), error.Message);
            return 1;
        }
    }
}
