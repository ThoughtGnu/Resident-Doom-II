// FlameSprites.cs - "re1convert flamesprites <RE1 USA folder> <out folder>":
// RE1's fire burst, the frames its flamethrower and flame rounds burn with
// (Effspr\esp001.tim, the three rows of flame from small and yellow through
// big and orange to dark), as sprites for the game: RFLMA0.png, RFLMB0.png ...
// each with its offset set to its middle (a grAb chunk), on a clear background.
// Writes flamesheet.png to the temp folder too: every frame in order, to check them.

using System;
using System.Collections.Generic;
using RD.Drawing;
using System.IO;
using System.Linq;

namespace Re1Convert
{
    static class FlameSprites
    {
        // where the flame rows are in esp001 (pixels)
        const int Top = 26, Bottom = 100, MinPixels = 30, MaxWidth = 40;

        public static void Export(string re1Usa, string outDir)
        {
            Directory.CreateDirectory(outDir);
            var tim = Tim.Read(Fs.ReadAllBytes(Path.Combine(re1Usa, "Effspr/esp001.tim")), 0);
            int w = tim.Width, h = tim.Height;
            var op = new bool[w, h];
            for (int y = Top; y < Bottom; y++)
                for (int x = 0; x < w; x++) { bool clear; ModelBuilder.TexelColor(tim, 0, x, y, out clear); op[x, y] = !clear; }

            // each separate shape (pixels within 2 of each other) is a frame
            var seen = new bool[w, h];
            var boxes = new List<Rectangle>();
            for (int y = Top; y < Bottom; y++)
                for (int x = 0; x < w; x++)
                {
                    if (!op[x, y] || seen[x, y]) continue;
                    var q = new Queue<Point>(); q.Enqueue(new Point(x, y)); seen[x, y] = true;
                    int x0 = x, x1 = x, y0 = y, y1 = y, n = 0;
                    while (q.Count > 0)
                    {
                        var p = q.Dequeue(); n++;
                        x0 = Math.Min(x0, p.X); x1 = Math.Max(x1, p.X); y0 = Math.Min(y0, p.Y); y1 = Math.Max(y1, p.Y);
                        for (int dy = -2; dy <= 2; dy++)
                            for (int dx = -2; dx <= 2; dx++)
                            {
                                int nx = p.X + dx, ny = p.Y + dy;
                                if (nx < 0 || nx >= w || ny < Top || ny >= Bottom || !op[nx, ny] || seen[nx, ny]) continue;
                                seen[nx, ny] = true; q.Enqueue(new Point(nx, ny));
                            }
                    }
                    if (n < MinPixels) continue;
                    var r = new Rectangle(x0, y0, x1 - x0 + 1, y1 - y0 + 1);
                    if (r.Width > MaxWidth) { boxes.Add(new Rectangle(r.X, r.Y, r.Width / 2, r.Height)); boxes.Add(new Rectangle(r.X + r.Width / 2, r.Y, r.Width - r.Width / 2, r.Height)); }   // two frames touching
                    else boxes.Add(r);
                }
            // reading order: row by row (rows ~25 pixels apart), left to right
            boxes = boxes.OrderBy(b => (b.Y - Top) / 24).ThenBy(b => b.X).ToList();
            if (boxes.Count > 26) boxes = boxes.Take(26).ToList();

            using (var sheet = new Bitmap(40 * boxes.Count, 40))
            {
                for (int i = 0; i < boxes.Count; i++)
                {
                    var r = boxes[i];
                    using (var b = new Bitmap(r.Width, r.Height, PixelFormat.Format32bppArgb))
                    {
                        for (int y = 0; y < r.Height; y++)
                            for (int x = 0; x < r.Width; x++)
                            {
                                bool clear; var c = ModelBuilder.TexelColor(tim, 0, r.X + x, r.Y + y, out clear);
                                b.SetPixel(x, y, clear ? Color.FromArgb(0, 0, 0, 0) : c);
                                if (!clear) sheet.SetPixel(40 * i + x, y, c);
                            }
                        string name = "RFLM" + (char)('A' + i) + "0.png";
                        SavePngWithOffset(b, Path.Combine(outDir, name), r.Width / 2, r.Height / 2);
                    }
                }
                string sheetPath = Path.Combine(Path.GetTempPath(), "flamesheet.png");   // not in the mod: a picture there would be loaded as a sprite
                sheet.Save(sheetPath, ImageFormat.Png);
                Console.WriteLine("Check picture: " + sheetPath);
            }
            Console.WriteLine("Wrote {0} flame frames RFLMA0-RFLM{1}0.png to {2}", boxes.Count, (char)('A' + boxes.Count - 1), outDir);
        }

        // PNG with a grAb chunk (GZDoom's sprite offset) right after the header.
        static void SavePngWithOffset(Bitmap b, string path, int ox, int oy)
        {
            byte[] png;
            using (var ms = new MemoryStream()) { b.Save(ms, ImageFormat.Png); png = ms.ToArray(); }
            int ihdrEnd = 8 + 4 + 4 + 13 + 4;   // signature, IHDR length, type, data, CRC
            var chunk = new List<byte>();
            byte[] type = { (byte)'g', (byte)'r', (byte)'A', (byte)'b' };
            byte[] data = BE(ox).Concat(BE(oy)).ToArray();
            chunk.AddRange(BE(8)); chunk.AddRange(type); chunk.AddRange(data);
            chunk.AddRange(BE((int)Crc(type.Concat(data).ToArray())));
            var o = png.Take(ihdrEnd).Concat(chunk).Concat(png.Skip(ihdrEnd)).ToArray();
            File.WriteAllBytes(path, o);
        }

        static byte[] BE(int v) { return new[] { (byte)(v >> 24), (byte)(v >> 16), (byte)(v >> 8), (byte)v }; }

        static uint Crc(byte[] d)
        {
            uint c = 0xFFFFFFFF;
            foreach (byte x in d)
            {
                c ^= x;
                for (int k = 0; k < 8; k++) c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
            }
            return c ^ 0xFFFFFFFF;
        }
    }
}