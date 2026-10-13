// Vest.cs - S.T.A.R.S. tactical vests worn over a character's chest (armor).
//
// The vest is made from the character's own chest mesh (RE1 joint 0, the
// chest: its children are the head, hips and both arms), pushed out from its
// middle so it sits over the shirt and retextured as a vest. The heavy vest
// is pushed out further and gets shoulder pads and a collar. Everything is
// bound to joint 0, so it moves with every RE1 animation.
//
// Its picture is a band added below the character's RE1 texture (the atlas,
// Iqm.cs WriteAtlas): left half the light vest, right half the heavy one.
// Vest triangles use "palette row" = the number of RE1 palettes, i.e. that band.

using System;
using System.Collections.Generic;
using RD.Drawing;
using System.Linq;

namespace Re1Convert
{
    static class Vest
    {
        public const int BandHeight = 64;

        // level 1 = light vest (green armor), 2 = heavy vest (blue armor)
        public static List<Tri> Make(EmdFile emd, int level)
        {
            var tim = emd.Texture;
            var chest = ModelBuilder.Build(emd, null).Where(t => t.Joint == 0).ToList();
            var all = chest.SelectMany(t => t.V).ToList();
            double cx = all.Average(v => v[0]), cy = all.Average(v => v[1]), cz = all.Average(v => v[2]);
            double minY = all.Min(v => v[1]), maxY = all.Max(v => v[1]);
            double minZ = all.Min(v => v[2]), maxZ = all.Max(v => v[2]);
            double scale = level == 1 ? 1.10 : 1.16;
            int rx = level == 1 ? 0 : tim.Width / 2;   // texture half for this vest

            var o = new List<Tri>();
            foreach (var t in chest)
            {
                var n = new Tri { Joint = 0, Palette = tim.ClutH };
                for (int c = 0; c < 3; c++)
                {
                    var v = t.V[c];
                    n.V[c] = new short[] {
                        (short)(cx + (v[0] - cx) * scale), (short)(cy + (v[1] - cy) * scale * 0.98), (short)(cz + (v[2] - cz) * scale) };
                    n.U[c] = rx + 4 + (v[2] - minZ) / Math.Max(1, maxZ - minZ) * (tim.Width / 2 - 8);
                    n.W[c] = 4 + (v[1] - minY) / Math.Max(1, maxY - minY) * (BandHeight - 8);
                }
                o.Add(n);
            }

            if (level == 2)
            {
                // shoulder pads where the arms join (joints 9 and 12), and a collar
                foreach (int arm in new[] { 9, 12 })
                {
                    double ax = emd.Skel.Offsets[arm, 0], ay = emd.Skel.Offsets[arm, 1], az = emd.Skel.Offsets[arm, 2];
                    double side = Math.Sign(az);
                    Box(o, tim, ax - 80, ay - 70, az - side * 40 - 70, ax + 80, ay + 10, az - side * 40 + 70, rx);
                }
                double nx = emd.Skel.Offsets[1, 0], ny = emd.Skel.Offsets[1, 1];
                Box(o, tim, nx - 130, ny + 10, -140, nx - 40, ny + 70, 140, rx);
            }
            return o;
        }

        static void Box(List<Tri> o, Tim tim, double x0, double y0, double z0, double x1, double y1, double z1, int rx)
        {
            Func<double, double, double, short[]> P = (x, y, z) => new[] { (short)x, (short)y, (short)z };
            var faces = new[] {
                new[] { P(x0, y0, z0), P(x1, y0, z0), P(x1, y0, z1), P(x0, y0, z1) },
                new[] { P(x0, y1, z0), P(x0, y1, z1), P(x1, y1, z1), P(x1, y1, z0) },
                new[] { P(x1, y0, z0), P(x1, y1, z0), P(x1, y1, z1), P(x1, y0, z1) },
                new[] { P(x0, y0, z0), P(x0, y0, z1), P(x0, y1, z1), P(x0, y1, z0) },
                new[] { P(x0, y0, z0), P(x0, y1, z0), P(x1, y1, z0), P(x1, y0, z0) },
                new[] { P(x0, y0, z1), P(x1, y0, z1), P(x1, y1, z1), P(x0, y1, z1) } };
            // the pads use the plate part of the heavy vest's picture
            double u0 = rx + 8, u1 = rx + 40, w0 = 8, w1 = 24;
            foreach (var f in faces)
                foreach (var flip in new[] { false, true })   // both sides
                {
                    AddTri(o, tim, f[0], flip ? f[2] : f[1], flip ? f[1] : f[2], u0, w0, u1, w0, u1, w1, flip);
                    AddTri(o, tim, f[0], flip ? f[3] : f[2], flip ? f[2] : f[3], u0, w0, u1, w1, u0, w1, flip);
                }
        }

        static void AddTri(List<Tri> o, Tim tim, short[] a, short[] b, short[] c, double ua, double wa, double ub, double wb, double uc, double wc, bool flip)
        {
            var t = new Tri { Joint = 0, Palette = tim.ClutH };
            t.V[0] = a; t.V[1] = b; t.V[2] = c;
            t.U[0] = ua; t.W[0] = wa;
            t.U[1] = flip ? uc : ub; t.W[1] = flip ? wc : wb;
            t.U[2] = flip ? ub : uc; t.W[2] = flip ? wb : wc;
            o.Add(t);
        }

        // The band's colours (width = the RE1 texture's width). Low colour,
        // 1996-style: stitched navy cloth with pockets and a S.T.A.R.S. patch
        // (light), black-olive armour plates (heavy).
        public static Color Pixel(int width, int x, int y)
        {
            int half = width / 2;
            bool heavy = x >= half;
            int lx = heavy ? x - half : x;
            int n = (int)((Hash(x, y) & 15) - 8);
            if (!heavy)
            {
                // pockets: two rows of stitched boxes on the lower half
                bool pocket = y > 36 && y < 58 && (lx % 32) > 4 && (lx % 32) < 28;
                bool stitch = pocket && ((lx % 32) == 5 || (lx % 32) == 27 || y == 37 || y == 57);
                bool patch = y > 8 && y < 18 && lx > 70 && lx < 104;       // white S.T.A.R.S. strip
                if (patch) return ((lx + y) % 5 == 0) ? C(30, 40, 90, n) : C(225, 225, 215, n);
                if (stitch) return C(120, 130, 160, n);
                if (pocket) return C(40, 50, 82, n);
                return y % 6 == 0 ? C(28, 34, 60, n) : C(34, 42, 72, n);
            }
            // heavy: plates with dark seams and bolts
            bool seam = lx % 32 < 2 || y % 20 < 2;
            bool bolt = (lx % 32 == 4 || lx % 32 == 28) && (y % 20 == 4 || y % 20 == 16);
            if (bolt) return C(150, 150, 140, n);
            if (seam) return C(10, 12, 10, n);
            return C(46, 52, 38, n);
        }

        static Color C(int r, int g, int b, int n)
        {
            return Color.FromArgb(255, Math.Max(0, Math.Min(255, r + n)), Math.Max(0, Math.Min(255, g + n)), Math.Max(0, Math.Min(255, b + n)));
        }

        static uint Hash(int x, int y)
        {
            uint h = (uint)(x * 374761393 + y * 668265263);
            h = (h ^ (h >> 13)) * 1274126177;
            return h ^ (h >> 16);
        }
    }
}
