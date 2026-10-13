// Prop.cs - "re1convert prop typewriter <out folder>": simple low-poly props
// built in code, written as IQM models (the same format as Jill and Chris)
// with a small generated texture, in a PS1 / 1996 look.
//
// The typewriter: a small wooden table with an old black typewriter on it
// (key bank, round keys, carriage with roller, a sheet of paper). Model
// units are map units: X forward (the keys face +X), Y left, Z up, origin on
// the floor in the middle of the table.

using System;
using System.Collections.Generic;
using RD.Drawing;
using System.IO;
using System.Text;

namespace Re1Convert
{
    static class Prop
    {
        // Texture regions in the 128x128 picture: x, y, w, h.
        static readonly int[] Wood = { 0, 0, 64, 64 }, WoodDark = { 0, 64, 32, 32 }, Enamel = { 64, 0, 32, 32 },
            Gold = { 96, 0, 32, 8 }, Chrome = { 96, 8, 32, 24 }, Keys = { 64, 32, 32, 32 }, Paper = { 96, 32, 32, 32 },
            Rubber = { 32, 64, 32, 32 };

        class V { public double[] P; public double U, W; }
        static readonly List<V[]> tris = new List<V[]>();

        public static void Run(string what, string outDir, string re1Usa = null)
        {
            Directory.CreateDirectory(outDir);
            if (what == "herbs") { Herbs(outDir); return; }
            if (what == "vests") { Vests(outDir); return; }
            if (what == "ribbon") { Ribbon(outDir, re1Usa); return; }
            if (what != "typewriter") throw new Exception("prop: typewriter, herbs, vests or ribbon");
            tris.Clear();

            // --- the table: top and four legs (about 20 deep, 28 wide, 26 high)
            Box(-10, -14, 24, 10, 14, 26, Wood);
            Box(-10.5, -14.5, 22.5, 10.5, 14.5, 24, WoodDark);   // apron under the top
            foreach (var lx in new[] { -9.0, 7.0 })
                foreach (var ly in new[] { -13.0, 11.0 })
                    Box(lx, ly, 0, lx + 2, ly + 2, 22.5, WoodDark);

            // --- the typewriter (front edge at x = 7, faces +X)
            double z = 26;
            Box(-5, -8, z, 4, 8, z + 4, Enamel);                  // body
            Box(-6, -8.5, z + 4, -1, 8.5, z + 7, Enamel);         // back housing under the carriage
            Wedge(0, -7.5, z + 4, 6.5, 7.5, z + 1.2, Enamel);     // sloped key bank (high at the back)
            Box(5.5, -7.5, z, 7, 7.5, z + 1.2, Gold);             // gold strip along the front
            for (int row = 0; row < 3; row++)                     // keys: three rows, staggered
                for (int k = 0; k < 7; k++)
                {
                    double kx = 1.2 + row * 1.9, ky = -6 + k * 1.95 + (row % 2) * 0.9;
                    double kz = z + 4 - (kx - 0) * (2.8 / 6.5) + 0.2;
                    Box(kx - 0.6, ky - 0.6, kz, kx + 0.6, ky + 0.6, kz + 0.8, Keys);
                }
            Box(5.6, -3.5, z + 0.1, 6.6, 3.5, z + 0.9, Keys);     // space bar
            Prism(-3.5, z + 8.2, 1.2, -9.5, 9.5, Rubber);         // the roller
            Box(-4, -10, z + 7.6, -3, -9.5, z + 8.8, Chrome);     // roller knobs
            Box(-4, 9.5, z + 7.6, -3, 10, z + 8.8, Chrome);
            Box(-3.2, 9.2, z + 8.6, -1.2, 9.8, z + 10, Chrome);   // carriage return lever
            Box(-1.4, 9.2, z + 9.6, 1.8, 9.8, z + 10.2, Chrome);
            Quad(new[] { -4.3, -5.0, z + 8.6 }, new[] { -4.3, 5.0, z + 8.6 },    // paper, leaning back
                 new[] { -5.6, 5.0, z + 17.0 }, new[] { -5.6, -5.0, z + 17.0 }, Paper);

            string png = Path.Combine(outDir, "typewriter.png");
            WriteTexture(png);
            string iqm = Path.Combine(outDir, "typewriter.iqm");
            WriteIqm(iqm, "typewriter.png");
            Console.WriteLine("Wrote {0}: {1} triangles (both sides)", iqm, tris.Count);
        }

        // --- herbs: a small clay pot with a leafy plant, like RE1's herbs -------
        // Three models (green, red, blue leaves) sharing one texture. About
        // 10 units across and 16 high; origin on the floor in the middle.
        static readonly int[] Pot = { 0, 0, 32, 32 }, Soil = { 32, 0, 32, 32 },
            LeafGreen = { 0, 32, 32, 32 }, LeafRed = { 32, 32, 32, 32 }, LeafBlue = { 64, 32, 32, 32 }, Stem = { 64, 0, 32, 32 };

        static void Herbs(string outDir)
        {
            WriteHerbTexture(Path.Combine(outDir, "herb.png"));
            foreach (var v in new[] { new { Name = "green", Leaf = LeafGreen }, new { Name = "red", Leaf = LeafRed }, new { Name = "blue", Leaf = LeafBlue } })
            {
                tris.Clear();
                // the pot: an eight-sided tapered tub with a rim, and soil on top
                for (int i = 0; i < 8; i++)
                {
                    double a0 = i * Math.PI / 4, a1 = (i + 1) * Math.PI / 4;
                    Func<double, double, double, double[]> R = (rad, a, z) => new[] { Math.Cos(a) * rad, Math.Sin(a) * rad, z };
                    Quad(R(3.6, a0, 0), R(3.6, a1, 0), R(5, a1, 5.5), R(5, a0, 5.5), Pot);       // side
                    Quad(R(5, a0, 5.5), R(5, a1, 5.5), R(5.6, a1, 6.5), R(5.6, a0, 6.5), Pot);   // rim
                    double[] c0 = { 0, 0, 6 };
                    var uv = new[] { Soil[0] + 16.0, Soil[1] + 16.0 };
                    Tri(c0, R(5.2, a0, 6), R(5.2, a1, 6), uv, uv, uv);                           // soil
                }
                // the plant: a short stem and leaves fanning out and up
                Box(-0.4, -0.4, 6, 0.4, 0.4, 10, Stem);
                for (int k = 0; k < 9; k++)
                {
                    double a = k * 2 * Math.PI / 9 + (k % 2) * 0.3;
                    double len = 6.5 + (k % 3) * 1.2, rise = 4 + (k % 3) * 2.5, z0 = 6.5 + (k % 3) * 1.5;
                    Leaf(a, len, rise, z0, v.Leaf);
                }
                string iqm = Path.Combine(outDir, "herb_" + v.Name + ".iqm");
                WriteIqm(iqm, "herb.png");
                Console.WriteLine("Wrote {0}: {1} triangles (both sides)", iqm, tris.Count);
            }
        }

        // One leaf: a flat diamond from the stem outwards, rising, with a fold
        // along the middle so it isn't paper-flat.
        static void Leaf(double ang, double len, double rise, double z0, int[] r)
        {
            double cx = Math.Cos(ang), cy = Math.Sin(ang), w = len * 0.28;
            double[] baseP = { cx * 0.4, cy * 0.4, z0 };
            double[] tip = { cx * len, cy * len, z0 + rise };
            double[] mid = { cx * len * 0.5, cy * len * 0.5, z0 + rise * 0.65 + 0.8 };   // the fold, raised
            double[] left = { mid[0] - cy * w, mid[1] + cx * w, mid[2] - 0.8 };
            double[] right = { mid[0] + cy * w, mid[1] - cx * w, mid[2] - 0.8 };
            double u0 = r[0] + 2, u1 = r[0] + r[2] - 2, vm = r[1] + r[3] / 2.0, v0 = r[1] + 2, v1 = r[1] + r[3] - 2;
            Tri(baseP, left, mid, new[] { u0, vm }, new[] { (u0 + u1) / 2, v0 }, new[] { (u0 + u1) / 2, vm });
            Tri(mid, left, tip, new[] { (u0 + u1) / 2, vm }, new[] { (u0 + u1) / 2, v0 }, new[] { u1, vm });
            Tri(baseP, mid, right, new[] { u0, vm }, new[] { (u0 + u1) / 2, vm }, new[] { (u0 + u1) / 2, v1 });
            Tri(mid, tip, right, new[] { (u0 + u1) / 2, vm }, new[] { u1, vm }, new[] { (u0 + u1) / 2, v1 });
        }

        static void WriteHerbTexture(string path)
        {
            var rnd = new Random(1996);
            using (var b = new Bitmap(128, 128, PixelFormat.Format32bppArgb))
            {
                using (var g = Graphics.FromImage(b)) g.Clear(Color.Black);
                Action<int[], Func<int, int, Color>> Fill = (r, f) =>
                {
                    for (int y = 0; y < r[3]; y++) for (int x = 0; x < r[2]; x++) b.SetPixel(r[0] + x, r[1] + y, f(x, y));
                };
                Func<int, int, int, int, Color> N = (rr, gg, bb, amt) =>
                {
                    int n = rnd.Next(-amt, amt + 1);
                    return Color.FromArgb(255, Clamp(rr + n), Clamp(gg + n), Clamp(bb + n));
                };
                Fill(Pot, (x, y) => y % 10 == 0 ? N(120, 62, 38, 4) : N(168, 88, 52, 8));          // terracotta, with bands
                Fill(Soil, (x, y) => N(52, 36, 24, 10));
                Fill(Stem, (x, y) => N(70, 96, 40, 6));
                // leaves: lighter vein down the middle (texture row 16), darker edges
                Func<int, int, int, int, int, Color> LeafC = (x, y, r0, g0, b0) =>
                {
                    double e = Math.Abs(y - 16) / 16.0;
                    double k = y == 16 || y == 15 ? 1.35 : 1.0 - e * 0.35;
                    return N((int)(r0 * k), (int)(g0 * k), (int)(b0 * k), 8);
                };
                Fill(LeafGreen, (x, y) => LeafC(x, y, 60, 150, 50));
                Fill(LeafRed, (x, y) => LeafC(x, y, 175, 40, 36));
                Fill(LeafBlue, (x, y) => LeafC(x, y, 50, 90, 175));
                b.Save(path, ImageFormat.Png);
            }
        }

        // --- the Ink Ribbon: RE1's own Ink Ribbon tin ---------------------------
        // RE1 shows the Ink Ribbon (inventory picture: Data\ITEM_ALL.PIX row 43,
        // the item's image type 44 - 1, with STATUS.TIM's palette row 2) as a
        // round, flat grey-olive tin with a raised spiral on its lid. Here: a
        // 16-sided tin about 11 across and 2.2 high, its lid textured with that
        // picture (the lid's oval in the picture mapped onto the circle), its
        // side coloured from the tin's own side band in the picture. Origin on
        // the floor in the middle.
        static readonly int[] RIcon = { 0, 0, 80, 60 }, RSide = { 0, 64, 64, 16 };
        // the lid's oval in the 40x30 picture: centre, half-axes, tilt
        const double LidCx = 21.0, LidCy = 14.0, LidA = 13.6, LidB = 8.4, LidTilt = -32.5;

        static void Ribbon(string outDir, string re1Usa)
        {
            var icon = ItemIcon(re1Usa, 43);
            tris.Clear();
            const int seg = 16;
            double rad = 5.5, h = 2.2, t = LidTilt * Math.PI / 180;
            Func<double, double[]> LidUv = a =>
            {
                double ex = Math.Cos(a) * LidA, ey = Math.Sin(a) * LidB;
                double ix = LidCx + ex * Math.Cos(t) - ey * Math.Sin(t), iy = LidCy + ex * Math.Sin(t) + ey * Math.Cos(t);
                return new[] { RIcon[0] + ix * 2, RIcon[1] + iy * 2 };   // the picture is stored at 2x
            };
            var cuv = new[] { RIcon[0] + LidCx * 2, RIcon[1] + LidCy * 2 };
            for (int i = 0; i < seg; i++)
            {
                double a0 = i * 2 * Math.PI / seg, a1 = (i + 1) * 2 * Math.PI / seg;
                double[] b0 = { Math.Cos(a0) * rad, Math.Sin(a0) * rad, 0 }, b1 = { Math.Cos(a1) * rad, Math.Sin(a1) * rad, 0 };
                double[] t0 = { b0[0], b0[1], h }, t1 = { b1[0], b1[1], h };
                Tri(new double[] { 0, 0, h }, t0, t1, cuv, LidUv(a0), LidUv(a1));          // lid
                double u0 = RSide[0] + RSide[2] * (double)i / seg, u1 = RSide[0] + RSide[2] * (double)(i + 1) / seg;
                double v0 = RSide[1] + 0.5, v1 = RSide[1] + RSide[3] - 0.5;
                Tri(b0, b1, t1, new[] { u0, v1 }, new[] { u1, v1 }, new[] { u1, v0 });      // side
                Tri(b0, t1, t0, new[] { u0, v1 }, new[] { u1, v0 }, new[] { u0, v0 });
                var bc = new[] { RSide[0] + 2.0, RSide[1] + RSide[3] - 1.0 };
                Tri(new double[] { 0, 0, 0 }, b1, b0, bc, bc, bc);                          // bottom
            }
            string png = Path.Combine(outDir, "ribbon.png");
            WriteRibbonTexture(png, icon);
            string iqm = Path.Combine(outDir, "ribbon.iqm");
            WriteIqm(iqm, "ribbon.png");
            Console.WriteLine("Wrote {0}: {1} triangles (both sides)", iqm, tris.Count);
        }

        // One 40x30 inventory picture from ITEM_ALL.PIX (8-bit, 1200 bytes a row)
        // with STATUS.TIM's palette row 2 (the decomp's dump_item_pix.py).
        public static Color[,] ItemIconPublic(string re1Usa, int row) { return ItemIcon(re1Usa, row); }
        static Color[,] ItemIcon(string re1Usa, int row)
        {
            byte[] tim = Fs.ReadAllBytes(Path.Combine(re1Usa, "Data/STATUS.TIM"));
            int cw = BitConverter.ToUInt16(tim, 16);
            int pbase = 20 + 2 * cw * 2;
            byte[] pix = Fs.ReadAllBytes(Path.Combine(re1Usa, "Data/ITEM_ALL.PIX"));
            var o = new Color[40, 30];
            for (int y = 0; y < 30; y++)
                for (int x = 0; x < 40; x++)
                {
                    int v = BitConverter.ToUInt16(tim, pbase + 2 * pix[row * 1200 + y * 40 + x]);
                    o[x, y] = Color.FromArgb(255, (v & 31) * 255 / 31, ((v >> 5) & 31) * 255 / 31, ((v >> 10) & 31) * 255 / 31);
                }
            return o;
        }

        static bool InLid(double x, double y)
        {
            double t = LidTilt * Math.PI / 180, dx = x - LidCx, dy = y - LidCy;
            double ex = dx * Math.Cos(t) + dy * Math.Sin(t), ey = -dx * Math.Sin(t) + dy * Math.Cos(t);
            return ex * ex / (LidA * LidA) + ey * ey / (LidB * LidB) <= 1;
        }

        static void WriteRibbonTexture(string path, Color[,] icon)
        {
            using (var b = new Bitmap(128, 128, PixelFormat.Format32bppArgb))
            {
                using (var g = Graphics.FromImage(b)) g.Clear(Color.Black);
                for (int y = 0; y < 60; y++) for (int x = 0; x < 80; x++) b.SetPixel(x, y, icon[x / 2, y / 2]);
                // the side band: the tin's pixels outside the lid oval (not the blue backdrop)
                var side = new List<Color>();
                for (int y = 0; y < 30; y++)
                    for (int x = 0; x < 40; x++)
                    {
                        var c = icon[x, y];
                        bool backdrop = (c.B > c.R + 30 && c.B > c.G + 30) || c.R + c.G + c.B < 30;
                        if (!backdrop && !InLid(x, y)) side.Add(c);
                    }
                double r0 = 0, g0 = 0, b0 = 0;
                foreach (var c in side) { r0 += c.R; g0 += c.G; b0 += c.B; }
                int n = Math.Max(1, side.Count);
                var rnd = new Random(1996);
                for (int y = 0; y < RSide[3]; y++)
                    for (int x = 0; x < RSide[2]; x++)
                    {
                        // a lighter rolled edge at the top, darker towards the floor
                        double k = y < 2 ? 1.35 : 1.0 - (y - 2) * 0.025;
                        var s = side.Count > 0 ? side[rnd.Next(side.Count)] : Color.Gray;
                        int rr = (int)((r0 / n * 0.6 + s.R * 0.4) * k), gg = (int)((g0 / n * 0.6 + s.G * 0.4) * k), bb = (int)((b0 / n * 0.6 + s.B * 0.4) * k);
                        b.SetPixel(RSide[0] + x, RSide[1] + y, Color.FromArgb(255, Clamp(rr), Clamp(gg), Clamp(bb)));
                    }
                b.Save(path, ImageFormat.Png);
                Console.WriteLine("Ink Ribbon side colour from {0} pixels of the RE1 picture", side.Count);
            }
        }
        // --- vest pickups: a S.T.A.R.S. vest lying flat on the floor ------------
        // Light (green armor): navy cloth with pockets and the white patch.
        // Heavy (blue armor): olive-black plates, thicker, with shoulder pads.
        // Texture vest.png: the same band picture as the vests worn (Vest.cs).
        static readonly int[] VLCloth = { 0, 0, 64, 32 }, VLPocket = { 0, 40, 32, 20 }, VLPatch = { 70, 8, 34, 10 },
            VHPlate = { 128, 0, 64, 40 }, VHPad = { 136, 8, 32, 16 }, VStrap = { 128, 44, 32, 4 };

        static void Vests(string outDir)
        {
            using (var b = new Bitmap(256, Vest.BandHeight, PixelFormat.Format32bppArgb))
            {
                for (int y = 0; y < Vest.BandHeight; y++) for (int x = 0; x < 256; x++) b.SetPixel(x, y, Vest.Pixel(256, x, y));
                b.Save(Path.Combine(outDir, "vest.png"), ImageFormat.Png);
            }
            for (int heavy = 0; heavy <= 1; heavy++)
            {
                tris.Clear();
                double t = heavy == 1 ? 3.2 : 2.0;   // thickness
                int[] cloth = heavy == 1 ? VHPlate : VLCloth;
                // back panel, and two front panels with a gap down the middle
                Box(-9, -8, 0, 9, 8, t * 0.5, cloth);
                Box(-8.5, -7.5, t * 0.5, 8.5, -0.6, t, cloth);
                Box(-8.5, 0.6, t * 0.5, 8.5, 7.5, t, cloth);
                // shoulder straps at the top (+X), and the neck opening between them
                Box(9, -7, 0.2, 12, -3.5, t * 0.8, heavy == 1 ? VHPad : cloth);
                Box(9, 3.5, 0.2, 12, 7, t * 0.8, heavy == 1 ? VHPad : cloth);
                // pockets / plates on the front
                for (int k = 0; k < 2; k++)
                    foreach (double side in new[] { -1.0, 1.0 })
                    {
                        double y0 = side < 0 ? -6.8 : 1.4;
                        Box(-6 + k * 5.5, y0, t, -1.8 + k * 5.5, y0 + 5.4, t + (heavy == 1 ? 1.2 : 0.9), heavy == 1 ? VHPad : VLPocket);
                    }
                if (heavy == 0) Box(4.5, -6.6, t, 7.5, -1.4, t + 0.3, VLPatch);       // S.T.A.R.S. patch
                // a waist strap with buckle
                Box(-9.4, -8.4, 0.1, -7.6, 8.4, t + 0.4, VStrap);
                string iqm = Path.Combine(outDir, heavy == 1 ? "vest_heavy.iqm" : "vest_light.iqm");
                WriteIqmSized(iqm, "vest.png", 256, Vest.BandHeight);
                Console.WriteLine("Wrote {0}: {1} triangles (both sides)", iqm, tris.Count);
            }
        }

        // --- shapes ------------------------------------------------------------

        static void Tri(double[] a, double[] b, double[] c, double[] ua, double[] ub, double[] uc)
        {
            tris.Add(new[] { new V { P = a, U = ua[0], W = ua[1] }, new V { P = b, U = ub[0], W = ub[1] }, new V { P = c, U = uc[0], W = uc[1] } });
            tris.Add(new[] { new V { P = a, U = ua[0], W = ua[1] }, new V { P = c, U = uc[0], W = uc[1] }, new V { P = b, U = ub[0], W = ub[1] } });
        }

        // A four-cornered face mapped over a whole texture region.
        static void Quad(double[] a, double[] b, double[] c, double[] d, int[] r)
        {
            double u0 = r[0] + 0.5, v0 = r[1] + 0.5, u1 = r[0] + r[2] - 0.5, v1 = r[1] + r[3] - 0.5;
            Tri(a, b, c, new[] { u0, v1 }, new[] { u1, v1 }, new[] { u1, v0 });
            Tri(a, c, d, new[] { u0, v1 }, new[] { u1, v0 }, new[] { u0, v0 });
        }

        static void Box(double x0, double y0, double z0, double x1, double y1, double z1, int[] r)
        {
            Func<double, double, double, double[]> P = (x, y, zz) => new[] { x, y, zz };
            Quad(P(x0, y0, z1), P(x1, y0, z1), P(x1, y1, z1), P(x0, y1, z1), r);   // top
            Quad(P(x0, y1, z0), P(x1, y1, z0), P(x1, y0, z0), P(x0, y0, z0), r);   // bottom
            Quad(P(x1, y0, z0), P(x1, y1, z0), P(x1, y1, z1), P(x1, y0, z1), r);   // front
            Quad(P(x0, y1, z0), P(x0, y0, z0), P(x0, y0, z1), P(x0, y1, z1), r);   // back
            Quad(P(x0, y0, z0), P(x1, y0, z0), P(x1, y0, z1), P(x0, y0, z1), r);   // right
            Quad(P(x1, y1, z0), P(x0, y1, z0), P(x0, y1, z1), P(x1, y1, z1), r);   // left
        }

        // Sloped block: height zBack at x0, falling to zFront at x1.
        static void Wedge(double x0, double y0, double zBack, double x1, double y1, double zFront, int[] r)
        {
            double zb = zFront - 1;
            Func<double, double, double, double[]> P = (x, y, zz) => new[] { x, y, zz };
            Quad(P(x0, y0, zBack), P(x1, y0, zFront), P(x1, y1, zFront), P(x0, y1, zBack), r);   // slope
            Quad(P(x1, y0, zb), P(x1, y1, zb), P(x1, y1, zFront), P(x1, y0, zFront), r);         // front
            Quad(P(x0, y0, zb), P(x1, y0, zb), P(x1, y0, zFront), P(x0, y0, zBack), r);          // sides
            Quad(P(x1, y1, zb), P(x0, y1, zb), P(x0, y1, zBack), P(x1, y1, zFront), r);
        }

        // Eight-sided cylinder along Y (the roller).
        static void Prism(double cx, double cz, double rad, double y0, double y1, int[] r)
        {
            for (int i = 0; i < 8; i++)
            {
                double a0 = i * Math.PI / 4, a1 = (i + 1) * Math.PI / 4;
                double[] p0 = { cx + Math.Cos(a0) * rad, y0, cz + Math.Sin(a0) * rad }, p1 = { cx + Math.Cos(a1) * rad, y0, cz + Math.Sin(a1) * rad };
                double[] q0 = { p0[0], y1, p0[2] }, q1 = { p1[0], y1, p1[2] };
                Quad(p0, q0, q1, p1, r);
                double[] c0 = { cx, y0, cz }, c1 = { cx, y1, cz };
                var uv = new[] { r[0] + r[2] / 2.0, r[1] + r[3] / 2.0 };
                Tri(c0, p1, p0, uv, uv, uv);
                Tri(c1, q0, q1, uv, uv, uv);
            }
        }

        // --- texture: flat colour blocks with a little noise, PS1-style -------

        static void WriteTexture(string path)
        {
            var rnd = new Random(1996);
            using (var b = new Bitmap(128, 128, PixelFormat.Format32bppArgb))
            {
                Action<int[], Func<int, int, Color>> Fill = (r, f) =>
                {
                    for (int y = 0; y < r[3]; y++) for (int x = 0; x < r[2]; x++) b.SetPixel(r[0] + x, r[1] + y, f(x, y));
                };
                Func<int, int, int, int, Color> N = (rr, gg, bb, amt) =>
                {
                    int n = rnd.Next(-amt, amt + 1);
                    return Color.FromArgb(255, Clamp(rr + n), Clamp(gg + n), Clamp(bb + n));
                };
                // wood: warm brown with grain lines
                Fill(Wood, (x, y) =>
                {
                    double g = Math.Sin(y * 0.55 + Math.Sin(x * 0.12) * 2.2) * 0.5 + 0.5;
                    return N((int)(96 + g * 34), (int)(58 + g * 20), (int)(30 + g * 10), 6);
                });
                Fill(WoodDark, (x, y) => { double g = Math.Sin(y * 0.6 + x * 0.05) * 0.5 + 0.5; return N((int)(62 + g * 20), (int)(36 + g * 12), (int)(20 + g * 6), 5); });
                Fill(Enamel, (x, y) => N(24, 24, 28, 4));
                Fill(Gold, (x, y) => (x % 8 < 6 && y > 1 && y < 6) ? N(190, 150, 60, 10) : N(30, 28, 26, 3));
                Fill(Chrome, (x, y) => N(150 + y * 3, 150 + y * 3, 158 + y * 3, 8));
                Fill(Keys, (x, y) =>
                {
                    int dx = x % 8 - 4, dy = y % 8 - 4;
                    bool cap = dx * dx + dy * dy <= 9;
                    return cap ? N(214, 204, 176, 6) : N(40, 38, 36, 4);
                });
                Fill(Paper, (x, y) => (y > 6 && y < 26 && y % 4 == 0 && x > 4 && x < 26 && rnd.Next(5) > 0) ? N(70, 70, 80, 8) : N(232, 228, 214, 4));
                Fill(Rubber, (x, y) => N(18, 18, 18, 3));
                b.Save(path, ImageFormat.Png);
            }
        }

        static int Clamp(int v) { return Math.Max(0, Math.Min(255, v)); }

        // --- IQM: one joint, one frame, so GZDoom draws it like Jill's models -

        static void WriteIqm(string path, string material) { WriteIqmSized(path, material, 128, 128); }

        // A ready-made triangle list (positions in map units, uv in texture
        // pixels) written the same way (ItemProps.cs).
        public static void WriteTriangles(string path, string material, List<double[][]> pos, List<double[][]> uv, int texW, int texH)
        {
            tris.Clear();
            for (int i = 0; i < pos.Count; i++) Tri(pos[i][0], pos[i][1], pos[i][2], uv[i][0], uv[i][1], uv[i][2]);
            WriteIqmSized(path, material, texW, texH);
        }

        static void WriteIqmSized(string path, string material, int texW, int texH)
        {
            var text = new List<byte> { 0 };
            Func<string, uint> AddText = s => { uint at = (uint)text.Count; text.AddRange(Encoding.ASCII.GetBytes(s)); text.Add(0); return at; };
            uint meshName = AddText("prop"), matName = AddText(material), jointName = AddText("root"), animName = AddText("idle");

            int nv = tris.Count * 3;
            using (var ms = new MemoryStream())
            using (var w = new BinaryWriter(ms))
            {
                w.Write(new byte[124]);
                Func<int> Here = () => (int)ms.Position;
                int ofsText = Here(); w.Write(text.ToArray()); Pad(w);
                int ofsMeshes = Here();
                w.Write(meshName); w.Write(matName); w.Write(0u); w.Write((uint)nv); w.Write(0u); w.Write((uint)tris.Count);
                int ofsVa = Here(); w.Write(new byte[5 * 20]);
                int ofsPos = Here();
                foreach (var t in tris) foreach (var v in t) { w.Write((float)v.P[0]); w.Write((float)v.P[1]); w.Write((float)v.P[2]); }
                int ofsUv = Here();
                foreach (var t in tris) foreach (var v in t) { w.Write((float)(v.U / texW)); w.Write((float)(v.W / texH)); }
                int ofsN = Here();
                foreach (var t in tris)
                {
                    double ux = t[1].P[0] - t[0].P[0], uy = t[1].P[1] - t[0].P[1], uz = t[1].P[2] - t[0].P[2];
                    double vx = t[2].P[0] - t[0].P[0], vy = t[2].P[1] - t[0].P[1], vz = t[2].P[2] - t[0].P[2];
                    double nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
                    double nl = Math.Sqrt(nx * nx + ny * ny + nz * nz); if (nl < 1e-9) nl = 1;
                    for (int c = 0; c < 3; c++) { w.Write((float)(nx / nl)); w.Write((float)(ny / nl)); w.Write((float)(nz / nl)); }
                }
                int ofsBi = Here(); for (int i = 0; i < nv; i++) w.Write(0u);
                int ofsBw = Here(); for (int i = 0; i < nv; i++) { w.Write((byte)255); w.Write((byte)0); w.Write((byte)0); w.Write((byte)0); }
                Pad(w);
                int ofsTris = Here();
                for (int t = 0; t < tris.Count; t++) { w.Write((uint)(t * 3)); w.Write((uint)(t * 3 + 1)); w.Write((uint)(t * 3 + 2)); }
                int ofsJoints = Here();
                w.Write(jointName); w.Write(-1);
                w.Write(0f); w.Write(0f); w.Write(0f); w.Write(0f); w.Write(0f); w.Write(0f); w.Write(1f); w.Write(1f); w.Write(1f); w.Write(1f);
                int ofsPoses = Here();
                w.Write(-1); w.Write(0x3FFu);
                float[] off = { 0, 0, 0, 0, 0, 0, 1, 1, 1, 1 };
                foreach (var f in off) w.Write(f);
                for (int c = 0; c < 10; c++) w.Write(0f);
                int ofsAnims = Here();
                w.Write(animName); w.Write(0u); w.Write(1u); w.Write(1f); w.Write(1u);
                int ofsFrames = Here();
                for (int c = 0; c < 10; c++) w.Write((ushort)0);
                Pad(w);
                int fileSize = Here();

                ms.Position = ofsVa;
                WriteVa(w, 0, 7, 3, ofsPos); WriteVa(w, 1, 7, 2, ofsUv); WriteVa(w, 2, 7, 3, ofsN);
                WriteVa(w, 4, 1, 4, ofsBi); WriteVa(w, 5, 1, 4, ofsBw);
                ms.Position = 0;
                w.Write(Encoding.ASCII.GetBytes("INTERQUAKEMODEL\0"));
                uint[] h = { 2, (uint)fileSize, 0, (uint)text.Count, (uint)ofsText, 1, (uint)ofsMeshes, 5, (uint)nv, (uint)ofsVa,
                    (uint)tris.Count, (uint)ofsTris, 0, 1, (uint)ofsJoints, 1, (uint)ofsPoses, 1, (uint)ofsAnims,
                    1, 10, (uint)ofsFrames, 0, 0, 0, 0, 0 };
                foreach (var x in h) w.Write(x);
                File.WriteAllBytes(path, ms.ToArray());
            }
        }

        static void WriteVa(BinaryWriter w, uint type, uint format, uint size, int offset)
        {
            w.Write(type); w.Write(0u); w.Write(format); w.Write(size); w.Write((uint)offset);
        }

        static void Pad(BinaryWriter w) { while (w.BaseStream.Position % 4 != 0) w.Write((byte)0); }
    }
}
