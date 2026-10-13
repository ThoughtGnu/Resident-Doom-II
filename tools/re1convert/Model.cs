// Model.cs - Jill's triangles (mesh part n hangs on joint n) and a tiny
// software renderer used to check poses before making game files.

using System;
using System.Collections.Generic;
using RD.Drawing;

namespace Re1Convert
{
    class Tri
    {
        public int Joint;
        public short[][] V = new short[3][];   // joint-local positions
        public double[] U = new double[3];     // texel x inside the TIM image
        public double[] W = new double[3];     // texel y inside the TIM image
        public int Palette;                    // row of the TIM palette block
        public bool Alt;                       // textured from the second TIM (IqmWriter.Write 'alt')
    }

    static class ModelBuilder
    {
        // Joint j uses TMD object j. If 'arm' is given (from a weapon EMW) it
        // replaces object 14, like LoadEquippedWeaponAnimation does.
        // 'armTim': the arm comes from another character's weapon file (Jill with
        // Chris's flamethrower, W05): its texels are in that character's TIM, so
        // its triangles are marked Alt.
        public static List<Tri> Build(EmdFile emd, Tmd arm, Tim armTim = null)
        {
            var tris = new List<Tri>();
            for (int j = 0; j < emd.Skel.JointCount; j++)
            {
                bool alt = j == 14 && arm != null && armTim != null;
                var tim = alt ? armTim : emd.Texture;
                TmdObject obj = (j == 14 && arm != null) ? arm.Objects[0] : emd.Mesh.Objects[j];
                foreach (var p in obj.Prims)
                {
                    // tsb: bits 0-4 = page x (64 halfwords = 128 8-bit texels), bit 4 = page y.
                    int pageX = (p.TPage & 0x0F) * 64 * (tim.Bpp == 8 ? 2 : 4) - tim.ImgX * (tim.Bpp == 8 ? 2 : 4);
                    int pageY = ((p.TPage >> 4) & 1) * 256 - tim.ImgY;
                    // cba: bits 6-14 = palette y in VRAM.
                    int palRow = (p.Clut >> 6) - tim.ClutY;
                    var t = new Tri { Joint = j, Palette = Math.Max(0, Math.Min(tim.ClutH - 1, palRow)), Alt = alt };
                    for (int c = 0; c < 3; c++)
                    {
                        t.V[c] = obj.Verts[p.Verts[c]];
                        t.U[c] = p.U[c] + pageX;
                        t.W[c] = p.V[c] + pageY;
                    }
                    tris.Add(t);
                }
            }
            return tris;
        }

        public static Color TexelColor(Tim tim, int palette, int x, int y, out bool clear)
        {
            if (palette >= tim.ClutH)   // the vest band (Vest.cs)
            {
                clear = false;
                return Vest.Pixel(tim.Width, Math.Max(0, Math.Min(tim.Width - 1, x)), Math.Max(0, Math.Min(Vest.BandHeight - 1, y)));
            }
            x = Math.Max(0, Math.Min(tim.Width - 1, x));
            y = Math.Max(0, Math.Min(tim.Height - 1, y));
            ushort c = tim.Clut[palette * tim.ClutW + tim.Index(x, y)];
            byte r, g, b, a;
            Tim.ToRgba(c, out r, out g, out b, out a);
            clear = a == 0;
            return Color.FromArgb(255, r, g, b);
        }
    }

    // Draws posed triangles into a bitmap (orthographic, with a depth buffer).
    class SoftRenderer
    {
        readonly Bitmap bmp;
        readonly double[] depth;
        readonly int w, h;

        public SoftRenderer(Bitmap target)
        {
            bmp = target; w = target.Width; h = target.Height;
            depth = new double[w * h];
            for (int i = 0; i < depth.Length; i++) depth[i] = double.NegativeInfinity;
        }

        // view: 0 = from the front (looking along -X), 1 = from her right side.
        public void Draw(List<Tri> tris, Mat[] pose, Tim tim, int ox, int oy, double scale, int view)
        {
            foreach (var t in tris)
            {
                var sx = new double[3]; var sy = new double[3]; var sz = new double[3];
                for (int c = 0; c < 3; c++)
                {
                    double[] p = pose[t.Joint].Apply(t.V[c]);
                    double across = view == 0 ? -p[2] : p[0];
                    double toward = view == 0 ? p[0] : p[2];
                    sx[c] = ox + across * scale;
                    sy[c] = oy + p[1] * scale;      // RE1 Y points down, like the screen
                    sz[c] = toward;
                }
                Raster(t, sx, sy, sz, tim);
            }
        }

        // Seen from the front, with the model first turned by yawDeg about the
        // vertical axis (+90 = facing screen-left, -90 = facing screen-right).
        public void DrawTurned(List<Tri> tris, Mat[] pose, Tim tim, double ox, double oy, double scale, double yawDeg)
        {
            double a = yawDeg * Math.PI / 180, c = Math.Cos(a), s = Math.Sin(a);
            foreach (var t in tris)
            {
                var sx = new double[3]; var sy = new double[3]; var sz = new double[3];
                for (int k = 0; k < 3; k++)
                {
                    double[] p = pose[t.Joint].Apply(t.V[k]);
                    double x = p[0] * c - p[2] * s, z = p[0] * s + p[2] * c;
                    sx[k] = ox - z * scale;
                    sy[k] = oy + p[1] * scale;
                    sz[k] = x;
                }
                Raster(t, sx, sy, sz, tim);
            }
        }

        void Raster(Tri t, double[] x, double[] y, double[] z, Tim tim)
        {
            int minX = (int)Math.Max(0, Math.Floor(Math.Min(x[0], Math.Min(x[1], x[2]))));
            int maxX = (int)Math.Min(w - 1, Math.Ceiling(Math.Max(x[0], Math.Max(x[1], x[2]))));
            int minY = (int)Math.Max(0, Math.Floor(Math.Min(y[0], Math.Min(y[1], y[2]))));
            int maxY = (int)Math.Min(h - 1, Math.Ceiling(Math.Max(y[0], Math.Max(y[1], y[2]))));
            double area = (x[1] - x[0]) * (y[2] - y[0]) - (x[2] - x[0]) * (y[1] - y[0]);
            if (Math.Abs(area) < 1e-6) return;
            for (int py = minY; py <= maxY; py++)
                for (int px = minX; px <= maxX; px++)
                {
                    double cx = px + 0.5, cy = py + 0.5;
                    double b0 = ((x[1] - cx) * (y[2] - cy) - (x[2] - cx) * (y[1] - cy)) / area;
                    double b1 = ((x[2] - cx) * (y[0] - cy) - (x[0] - cx) * (y[2] - cy)) / area;
                    double b2 = 1 - b0 - b1;
                    if (b0 < 0 || b1 < 0 || b2 < 0) continue;
                    double d = b0 * z[0] + b1 * z[1] + b2 * z[2];
                    int i = py * w + px;
                    if (d <= depth[i]) continue;
                    double u = b0 * t.U[0] + b1 * t.U[1] + b2 * t.U[2];
                    double v = b0 * t.W[0] + b1 * t.W[1] + b2 * t.W[2];
                    bool clear;
                    Color col = ModelBuilder.TexelColor(tim, t.Palette, (int)u, (int)v, out clear);
                    if (clear) continue;
                    depth[i] = d;
                    bmp.SetPixel(px, py, col);
                }
        }
    }
}
