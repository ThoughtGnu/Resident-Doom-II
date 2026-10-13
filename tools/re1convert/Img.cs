// Img.cs - the converter's own pictures, so it runs the same on Windows and
// on a Mac (where Windows' System.Drawing doesn't work).
//
// The names match the small part of System.Drawing the converter used before
// (Bitmap, Color, Graphics ...), so the rest of the code reads the same; only
// "using System.Drawing" became "using RD.Drawing". Pictures are plain 32-bit
// ARGB pixels, saved and loaded as PNG by the code below (no other libraries).
// The text on preview sheets uses a tiny built-in pixel font.

using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;

namespace RD.Drawing
{
    public struct Color
    {
        public readonly byte A, R, G, B;

        Color(int a, int r, int g, int b)
        {
            if ((a | r | g | b) < 0 || a > 255 || r > 255 || g > 255 || b > 255)
                throw new ArgumentException("colour value outside 0-255");
            A = (byte)a; R = (byte)r; G = (byte)g; B = (byte)b;
        }

        public static Color FromArgb(int a, int r, int g, int b) { return new Color(a, r, g, b); }
        public static Color FromArgb(int r, int g, int b) { return new Color(255, r, g, b); }
        public static Color FromArgb(int a, Color c) { return new Color(a, c.R, c.G, c.B); }
        public static Color FromArgb(int argb) { return new Color((argb >> 24) & 255, (argb >> 16) & 255, (argb >> 8) & 255, argb & 255); }
        public int ToArgb() { return (A << 24) | (R << 16) | (G << 8) | B; }

        // the same values as System.Drawing's named colours
        public static readonly Color Transparent = new Color(0, 255, 255, 255);
        public static readonly Color Black = new Color(255, 0, 0, 0);
        public static readonly Color White = new Color(255, 255, 255, 255);
        public static readonly Color Gray = new Color(255, 128, 128, 128);
        public static readonly Color Magenta = new Color(255, 255, 0, 255);
        public static readonly Color Lime = new Color(255, 0, 255, 0);
        public static readonly Color Red = new Color(255, 255, 0, 0);
        public static readonly Color Orange = new Color(255, 255, 165, 0);
        public static readonly Color Yellow = new Color(255, 255, 255, 0);
    }

    public struct Point
    {
        public int X, Y;
        public Point(int x, int y) { X = x; Y = y; }
    }

    public struct Rectangle
    {
        public int X, Y, Width, Height;
        public Rectangle(int x, int y, int w, int h) { X = x; Y = y; Width = w; Height = h; }
    }

    public enum PixelFormat { Format32bppArgb }
    public enum RotateFlipType { RotateNoneFlipX }
    public enum InterpolationMode { Default, NearestNeighbor, Bilinear, HighQualityBilinear, HighQualityBicubic }
    public sealed class ImageFormat { public static readonly ImageFormat Png = new ImageFormat(); }

    public sealed class Font
    {
        public readonly float Size;
        public Font(string name, float size) { Size = size; }
    }

    public sealed class Brush
    {
        public readonly Color Color;
        public Brush(Color c) { Color = c; }
    }

    public static class Brushes
    {
        public static readonly Brush White = new Brush(Color.White), Yellow = new Brush(Color.Yellow), Black = new Brush(Color.Black);
    }

    public sealed class Pen
    {
        public readonly Color Color;
        public Pen(Color c) { Color = c; }
    }

    public static class Pens
    {
        public static readonly Pen Lime = new Pen(Color.Lime), Gray = new Pen(Color.Gray), Red = new Pen(Color.Red),
            Orange = new Pen(Color.Orange), White = new Pen(Color.White), Yellow = new Pen(Color.Yellow);
    }

    public sealed class Bitmap : IDisposable
    {
        public readonly int Width, Height;
        public readonly int[] Px;   // ARGB, row by row

        public Bitmap(int w, int h)
        {
            if (w <= 0 || h <= 0) throw new ArgumentException("picture size must be at least 1x1");
            Width = w; Height = h; Px = new int[w * h];
        }
        public Bitmap(int w, int h, PixelFormat f) : this(w, h) { }
        public Bitmap(Bitmap src) : this(src.Width, src.Height) { Array.Copy(src.Px, Px, Px.Length); }
        public Bitmap(string path)
        {
            int w, h;
            Px = Png.Read(File.ReadAllBytes(path), out w, out h);
            Width = w; Height = h;
        }

        public Color GetPixel(int x, int y) { Check(x, y); return Color.FromArgb(Px[y * Width + x]); }
        public void SetPixel(int x, int y, Color c) { Check(x, y); Px[y * Width + x] = c.ToArgb(); }

        void Check(int x, int y)
        {
            if (x < 0 || y < 0 || x >= Width || y >= Height)
                throw new ArgumentOutOfRangeException("pixel " + x + "," + y + " outside a " + Width + "x" + Height + " picture");
        }

        public void RotateFlip(RotateFlipType t)
        {
            for (int y = 0; y < Height; y++)
                Array.Reverse(Px, y * Width, Width);
        }

        public void Save(string path, ImageFormat f) { File.WriteAllBytes(path, Png.Write(Px, Width, Height)); }
        public void Save(string path) { Save(path, ImageFormat.Png); }
        public void Save(Stream s, ImageFormat f) { byte[] b = Png.Write(Px, Width, Height); s.Write(b, 0, b.Length); }
        public void Dispose() { }

        // a smaller or bigger copy (for the title picture and the logo)
        public Bitmap Scaled(int w, int h, InterpolationMode mode)
        {
            return Scaled(0, 0, Width, Height, w, h, mode);
        }

        public Bitmap Scaled(double sx0, double sy0, double sw, double sh, int w, int h, InterpolationMode mode)
        {
            var o = new Bitmap(w, h);
            double kx = sw / w, ky = sh / h;
            for (int y = 0; y < h; y++)
                for (int x = 0; x < w; x++)
                {
                    double fx = sx0 + (x + 0.5) * kx - 0.5, fy = sy0 + (y + 0.5) * ky - 0.5;
                    o.Px[y * w + x] = mode == InterpolationMode.NearestNeighbor
                        ? Px[Clamp((int)Math.Floor(fx + 0.5), Width) + Clamp((int)Math.Floor(fy + 0.5), Height) * Width]
                        : Sample(fx, fy, kx, ky, mode == InterpolationMode.HighQualityBicubic);
                }
            return o;
        }

        static int Clamp(int v, int n) { return v < 0 ? 0 : (v >= n ? n - 1 : v); }

        // filtered sample around (fx, fy): when shrinking, the filter widens to
        // cover the source pixels that fall into one output pixel
        int Sample(double fx, double fy, double kx, double ky, bool cubic)
        {
            double sx = Math.Max(1, kx), sy = Math.Max(1, ky);
            double radius = cubic ? 2 : 1;
            int x0 = (int)Math.Floor(fx - radius * sx) + 1, x1 = (int)Math.Floor(fx + radius * sx);
            int y0 = (int)Math.Floor(fy - radius * sy) + 1, y1 = (int)Math.Floor(fy + radius * sy);
            double a = 0, r = 0, g = 0, b = 0, wsum = 0;
            for (int y = y0; y <= y1; y++)
            {
                double wy = Kernel((y - fy) / sy, cubic);
                if (wy == 0) continue;
                for (int x = x0; x <= x1; x++)
                {
                    double wgt = wy * Kernel((x - fx) / sx, cubic);
                    if (wgt == 0) continue;
                    int c = Px[Clamp(x, Width) + Clamp(y, Height) * Width];
                    double ca = (c >> 24) & 255;
                    a += wgt * ca;
                    r += wgt * ((c >> 16) & 255) * ca;
                    g += wgt * ((c >> 8) & 255) * ca;
                    b += wgt * (c & 255) * ca;
                    wsum += wgt;
                }
            }
            if (wsum == 0 || a <= 0) return 0;
            int A = Byte(a / wsum);
            return (A << 24) | (Byte(r / a) << 16) | (Byte(g / a) << 8) | Byte(b / a);
        }

        static double Kernel(double t, bool cubic)
        {
            t = Math.Abs(t);
            if (!cubic) return t < 1 ? 1 - t : 0;
            const double A = -0.5;   // Keys' bicubic (Catmull-Rom)
            if (t < 1) return (A + 2) * t * t * t - (A + 3) * t * t + 1;
            if (t < 2) return A * t * t * t - 5 * A * t * t + 8 * A * t - 4 * A;
            return 0;
        }

        static int Byte(double v) { return v < 0 ? 0 : (v > 255 ? 255 : (int)(v + 0.5)); }
    }

    public sealed class Graphics : IDisposable
    {
        readonly Bitmap target;
        public InterpolationMode InterpolationMode = InterpolationMode.NearestNeighbor;

        Graphics(Bitmap b) { target = b; }
        public static Graphics FromImage(Bitmap b) { return new Graphics(b); }
        public void Dispose() { }

        public void Clear(Color c)
        {
            int v = c.ToArgb();
            for (int i = 0; i < target.Px.Length; i++) target.Px[i] = v;
        }

        // one pixel drawn over another (straight, not premultiplied, alpha)
        void Blend(int x, int y, int src)
        {
            if (x < 0 || y < 0 || x >= target.Width || y >= target.Height) return;
            int sa = (src >> 24) & 255;
            if (sa == 0) return;
            int i = y * target.Width + x;
            if (sa == 255) { target.Px[i] = src; return; }
            int dst = target.Px[i], da = (dst >> 24) & 255;
            int oa = sa + da * (255 - sa) / 255;
            if (oa == 0) { target.Px[i] = 0; return; }
            Func<int, int, int> mix = (s, d) => (s * sa + d * da * (255 - sa) / 255) / oa;
            target.Px[i] = (oa << 24) | (mix((src >> 16) & 255, (dst >> 16) & 255) << 16)
                | (mix((src >> 8) & 255, (dst >> 8) & 255) << 8) | mix(src & 255, dst & 255);
        }

        public void DrawImage(Bitmap img, int x, int y) { DrawImage(img, x, y, img.Width, img.Height); }
        public void DrawImage(Bitmap img, float x, float y, float w, float h) { DrawImage(img, (int)x, (int)y, (int)w, (int)h); }

        public void DrawImage(Bitmap img, int x, int y, int w, int h)
        {
            if (w <= 0 || h <= 0) return;
            var src = (w == img.Width && h == img.Height) ? img : img.Scaled(w, h, InterpolationMode);
            for (int j = 0; j < h; j++)
                for (int i = 0; i < w; i++)
                    Blend(x + i, y + j, src.Px[j * w + i]);
        }

        public void FillRectangle(Brush b, int x, int y, int w, int h)
        {
            int c = b.Color.ToArgb();
            for (int j = 0; j < h; j++) for (int i = 0; i < w; i++) Blend(x + i, y + j, c);
        }

        public void DrawLine(Pen p, float x0, float y0, float x1, float y1) { DrawLine(p, (int)x0, (int)y0, (int)x1, (int)y1); }

        public void DrawLine(Pen p, int x0, int y0, int x1, int y1)
        {
            int c = p.Color.ToArgb();
            int dx = Math.Abs(x1 - x0), dy = -Math.Abs(y1 - y0), sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1, err = dx + dy;
            while (true)
            {
                Blend(x0, y0, c);
                if (x0 == x1 && y0 == y1) break;
                int e2 = 2 * err;
                if (e2 >= dy) { err += dy; x0 += sx; }
                if (e2 <= dx) { err += dx; y0 += sy; }
            }
        }

        public void DrawString(string s, Font f, Brush b, float x, float y) { TinyFont.Draw(this, s, b.Color.ToArgb(), (int)x, (int)y, f.Size >= 9 ? 2 : 1); }

        internal void Dot(int x, int y, int c) { Blend(x, y, c); }
    }

    // A 3x5 pixel font for the labels on preview sheets: digits, capitals
    // (small letters are drawn as capitals) and common punctuation.
    static class TinyFont
    {
        static readonly Dictionary<char, string> Glyphs = new Dictionary<char, string>
        {
            { '0', "111101101101111" }, { '1', "010110010010111" }, { '2', "111001111100111" }, { '3', "111001111001111" },
            { '4', "101101111001001" }, { '5', "111100111001111" }, { '6', "111100111101111" }, { '7', "111001010010010" },
            { '8', "111101111101111" }, { '9', "111101111001111" },
            { 'A', "010101111101101" }, { 'B', "110101110101110" }, { 'C', "011100100100011" }, { 'D', "110101101101110" },
            { 'E', "111100110100111" }, { 'F', "111100110100100" }, { 'G', "011100101101011" }, { 'H', "101101111101101" },
            { 'I', "111010010010111" }, { 'J', "001001001101010" }, { 'K', "101101110101101" }, { 'L', "100100100100111" },
            { 'M', "101111111101101" }, { 'N', "110101101101101" }, { 'O', "010101101101010" }, { 'P', "110101110100100" },
            { 'Q', "010101101110011" }, { 'R', "110101110101101" }, { 'S', "011100010001110" }, { 'T', "111010010010010" },
            { 'U', "101101101101111" }, { 'V', "101101101101010" }, { 'W', "101101111111101" }, { 'X', "101101010101101" },
            { 'Y', "101101010010010" }, { 'Z', "111001010100111" },
            { '.', "000000000000010" }, { ',', "000000000010100" }, { ':', "000010000010000" }, { '-', "000000111000000" },
            { '+', "000010111010000" }, { '/', "001001010100100" }, { '(', "010100100100010" }, { ')', "010001001001010" },
            { '%', "101001010100101" }, { '=', "000111000111000" }, { '<', "001010100010001" }, { '>', "100010001010100" },
            { '_', "000000000000111" }, { '!', "010010010000010" }, { '?', "110001010000010" }, { '\'', "010010000000000" },
            { '"', "101101000000000" }, { '[', "110100100100110" }, { ']', "011001001001011" }, { '#', "101111101111101" },
        };

        public static void Draw(Graphics g, string s, int color, int x, int y, int scale)
        {
            int cx = x;
            foreach (char ch0 in s)
            {
                if (ch0 == '\n') { cx = x; y += 6 * scale; continue; }
                char ch = char.ToUpperInvariant(ch0);
                string bits;
                if (Glyphs.TryGetValue(ch, out bits))
                    for (int r = 0; r < 5; r++)
                        for (int c = 0; c < 3; c++)
                            if (bits[r * 3 + c] == '1')
                                for (int dy = 0; dy < scale; dy++)
                                    for (int dx = 0; dx < scale; dx++)
                                        g.Dot(cx + c * scale + dx, y + r * scale + dy, color);
                cx += 4 * scale;
            }
        }
    }

    // PNG: written as 8-bit RGBA; read for the colour types the converter
    // meets (its own pictures and GZDoom's screenshots).
    static class Png
    {
        static readonly uint[] crcTable = MakeCrcTable();

        static uint[] MakeCrcTable()
        {
            var t = new uint[256];
            for (uint n = 0; n < 256; n++)
            {
                uint c = n;
                for (int k = 0; k < 8; k++) c = (c & 1) != 0 ? 0xEDB88320u ^ (c >> 1) : c >> 1;
                t[n] = c;
            }
            return t;
        }

        static uint Crc(byte[] b, int start, int len)
        {
            uint c = 0xFFFFFFFFu;
            for (int i = start; i < start + len; i++) c = crcTable[(c ^ b[i]) & 0xFF] ^ (c >> 8);
            return c ^ 0xFFFFFFFFu;
        }

        static void BE(Stream s, uint v) { s.WriteByte((byte)(v >> 24)); s.WriteByte((byte)(v >> 16)); s.WriteByte((byte)(v >> 8)); s.WriteByte((byte)v); }

        static void Chunk(Stream s, string type, byte[] data)
        {
            var b = new byte[4 + data.Length];
            for (int i = 0; i < 4; i++) b[i] = (byte)type[i];
            Array.Copy(data, 0, b, 4, data.Length);
            BE(s, (uint)data.Length);
            s.Write(b, 0, b.Length);
            BE(s, Crc(b, 0, b.Length));
        }

        public static byte[] Write(int[] px, int w, int h)
        {
            var raw = new byte[(w * 4 + 1) * h];
            int o = 0;
            for (int y = 0; y < h; y++)
            {
                raw[o++] = 0;   // no filter
                for (int x = 0; x < w; x++)
                {
                    int c = px[y * w + x];
                    raw[o++] = (byte)(c >> 16); raw[o++] = (byte)(c >> 8); raw[o++] = (byte)c; raw[o++] = (byte)(c >> 24);
                }
            }
            byte[] z;
            using (var ms = new MemoryStream())
            {
                ms.WriteByte(0x78); ms.WriteByte(0x9C);   // zlib header
                using (var d = new DeflateStream(ms, CompressionMode.Compress, true)) d.Write(raw, 0, raw.Length);
                uint s1 = 1, s2 = 0;                       // Adler-32
                foreach (byte v in raw) { s1 = (s1 + v) % 65521; s2 = (s2 + s1) % 65521; }
                BE(ms, (s2 << 16) | s1);
                z = ms.ToArray();
            }
            using (var outp = new MemoryStream())
            {
                outp.Write(new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 }, 0, 8);
                var ihdr = new byte[13];
                ihdr[0] = (byte)(w >> 24); ihdr[1] = (byte)(w >> 16); ihdr[2] = (byte)(w >> 8); ihdr[3] = (byte)w;
                ihdr[4] = (byte)(h >> 24); ihdr[5] = (byte)(h >> 16); ihdr[6] = (byte)(h >> 8); ihdr[7] = (byte)h;
                ihdr[8] = 8; ihdr[9] = 6;   // 8-bit RGBA
                Chunk(outp, "IHDR", ihdr);
                Chunk(outp, "IDAT", z);
                Chunk(outp, "IEND", new byte[0]);
                return outp.ToArray();
            }
        }

        static int BE32(byte[] b, int o) { return (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3]; }

        public static int[] Read(byte[] f, out int w, out int h)
        {
            if (f.Length < 8 || f[0] != 137 || f[1] != 80 || f[2] != 78 || f[3] != 71) throw new Exception("not a PNG picture");
            w = h = 0;
            int depth = 0, type = 0, interlace = 0;
            byte[] pal = null, trns = null;
            var idat = new MemoryStream();
            int p = 8;
            while (p + 8 <= f.Length)
            {
                int len = BE32(f, p);
                string t = System.Text.Encoding.ASCII.GetString(f, p + 4, 4);
                int d = p + 8;
                if (t == "IHDR") { w = BE32(f, d); h = BE32(f, d + 4); depth = f[d + 8]; type = f[d + 9]; interlace = f[d + 12]; }
                else if (t == "PLTE") { pal = new byte[len]; Array.Copy(f, d, pal, 0, len); }
                else if (t == "tRNS") { trns = new byte[len]; Array.Copy(f, d, trns, 0, len); }
                else if (t == "IDAT") idat.Write(f, d, len);
                else if (t == "IEND") break;
                p = d + len + 4;
            }
            if (depth != 8 || interlace != 0) throw new Exception("only 8-bit, non-interlaced PNG pictures are supported");
            int ch = type == 0 ? 1 : type == 2 ? 3 : type == 3 ? 1 : type == 4 ? 2 : type == 6 ? 4 : -1;
            if (ch < 0) throw new Exception("unsupported PNG colour type " + type);
            int stride = w * ch;
            var raw = new byte[(stride + 1) * h];
            idat.Position = 2;   // skip the zlib header
            using (var z = new DeflateStream(idat, CompressionMode.Decompress))
            {
                int got = 0, n;
                while (got < raw.Length && (n = z.Read(raw, got, raw.Length - got)) > 0) got += n;
                if (got < raw.Length) throw new Exception("PNG picture data is cut short");
            }
            var cur = new byte[stride];
            var prev = new byte[stride];
            var px = new int[w * h];
            for (int y = 0; y < h; y++)
            {
                int filter = raw[y * (stride + 1)];
                Array.Copy(raw, y * (stride + 1) + 1, cur, 0, stride);
                for (int i = 0; i < stride; i++)
                {
                    int a = i >= ch ? cur[i - ch] : 0, b = prev[i], c = i >= ch ? prev[i - ch] : 0;
                    int v = cur[i];
                    switch (filter)
                    {
                        case 1: v += a; break;
                        case 2: v += b; break;
                        case 3: v += (a + b) / 2; break;
                        case 4:
                            int pp = a + b - c, pa = Math.Abs(pp - a), pb = Math.Abs(pp - b), pc = Math.Abs(pp - c);
                            v += pa <= pb && pa <= pc ? a : (pb <= pc ? b : c);
                            break;
                    }
                    cur[i] = (byte)v;
                }
                for (int x = 0; x < w; x++)
                {
                    int A = 255, R, G, B;
                    int o = x * ch;
                    switch (type)
                    {
                        case 0: R = G = B = cur[o]; break;
                        case 4: R = G = B = cur[o]; A = cur[o + 1]; break;
                        case 2: R = cur[o]; G = cur[o + 1]; B = cur[o + 2]; break;
                        case 3:
                            int ix = cur[o];
                            R = pal[ix * 3]; G = pal[ix * 3 + 1]; B = pal[ix * 3 + 2];
                            if (trns != null && ix < trns.Length) A = trns[ix];
                            break;
                        default: R = cur[o]; G = cur[o + 1]; B = cur[o + 2]; A = cur[o + 3]; break;
                    }
                    px[y * w + x] = (A << 24) | (R << 16) | (G << 8) | B;
                }
                var tmp = prev; prev = cur; cur = tmp;
            }
            return px;
        }
    }
}

namespace Re1Convert
{
    // Files from the player's RE1 folder, found even when the letters' case
    // differs from the name in the code (on a Mac disk that tells them apart).
    static class Fs
    {
        public static string Resolve(string path)
        {
            if (File.Exists(path) || Directory.Exists(path)) return path;
            string full = Path.GetFullPath(path);
            string root = Path.GetPathRoot(full);
            string cur = root;
            foreach (string part in full.Substring(root.Length).Split(new[] { '/', '\\' }, StringSplitOptions.RemoveEmptyEntries))
            {
                string next = Path.Combine(cur, part);
                if (!File.Exists(next) && !Directory.Exists(next) && Directory.Exists(cur))
                    foreach (string e in Directory.GetFileSystemEntries(cur))
                        if (string.Equals(Path.GetFileName(e), part, StringComparison.OrdinalIgnoreCase)) { next = e; break; }
                cur = next;
            }
            return cur;
        }

        public static byte[] ReadAllBytes(string path)
        {
            string p = Resolve(path);
            if (!File.Exists(p)) throw new FileNotFoundException("missing file: " + path);
            return File.ReadAllBytes(p);
        }

        public static bool Exists(string path) { return File.Exists(Resolve(path)); }
    }
}
