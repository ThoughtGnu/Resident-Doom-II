// ItemBox.cs - the item box, from RE1's own item box.
//
// RE1 paints the item box's body into its pre-rendered room backgrounds; the
// only 3D part is the lid, a room object ("omodel") that check_itembox_state
// (decomp RoomEvents.cpp) swings open while the box screen opens. Every room
// with an item box (room action type 8, open_itembox) carries the same lid as
// its first object model: RDT header +0x50 -> {TMD, TIM} pairs.
//
//   re1convert itembox <RE1 USA> <out folder>        models/props/itembox.md3 + .png
//   re1convert itemboxsheet <RE1 USA> <out.png>      the lid as RE1 has it, and our box

using System;
using System.Collections.Generic;
using RD.Drawing;
using System.IO;
using System.Linq;

namespace Re1Convert
{
    static class ItemBox
    {
        // Rooms with an item box, in the order to try them.
        static readonly string[] Rooms = { "Stage1/ROOM1000.RDT", "Stage1/ROOM1180.RDT", "Stage3/ROOM30E0.RDT",
            "Stage4/ROOM4030.RDT", "Stage5/ROOM50E0.RDT", "Stage6/ROOM6000.RDT", "Stage6/ROOM6180.RDT" };

        public static ItemProps.Model LoadLid(string re1Usa, out string from)
        {
            foreach (var r in Rooms)
            {
                string path = Path.Combine(re1Usa, r);
                if (!Fs.Exists(path)) continue;
                byte[] b = Fs.ReadAllBytes(path);
                if (b.Length < 0x94 || b[2] < 1) continue;   // no object models
                int om = Bin.S32(b, 0x50);
                int tmd = Bin.S32(b, om), tim = Bin.S32(b, om + 4);
                if (tmd <= 0 || tim <= 0 || Bin.S32(b, tmd) != 0x41) continue;
                from = r;
                return ItemProps.FromBytes(b, tim, tmd);
            }
            throw new Exception("No RE1 room with an item box found in " + re1Usa);
        }

        // --- the game model ----------------------------------------------------
        // Map units: X forward (the front faces +X, the hinge is at the back),
        // Y left, Z up, origin on the floor in the middle. RE1 units are 32 to
        // a map unit (like the characters), times Scale.
        const double Scale = 0.85 / 32;
        const double LidX = 1440, LidZ = 2160;   // the lid's size in RE1 units (x across, z along)
        const double BodyH = 760;                // the body's height in RE1 units, about Jill's thigh
        const double Wall = 78;                  // the wall thickness: the lid's inner recess is 78 in from its edge
        const double InsideDepth = 560;          // how deep the inside is, from the rim
        public const int Frames = 12;            // closed, then the lid opening (RE1's own curve)

        // Texture regions in the lid's TIM (128 x 256), from its own UVs:
        //   top: rust panel with the light ornate frame, u 2-123 v 6-162, frame about 21 texels wide
        //   underside: dark panel with a thin dark frame, u 5-120 v 174-251
        //   the light frame strip along the lid's edges: u 1-125 v 7-19
        static readonly double[] TopTex = { 2, 6, 123, 162 }, UnderTex = { 5, 174, 120, 251 }, RimTex = { 1, 7, 125, 19 };
        const double FrameTexels = 21;

        class Face { public double[][] P = new double[3][]; public double[][] T = new double[3][]; public bool Lid; }

        // RE1's lid angle for each frame: check_itembox_state turns the lid by
        // a growing step (1, 2, 3, ...) until it is past 199 (of 4096 to a
        // turn), then by a shrinking one until the step reaches 0: it eases
        // open to about 39 degrees. The frames sample that curve evenly in time.
        static double[] LidAngles()
        {
            var curve = new List<int> { 0 };
            int angle = 0, step = 1, inc = 1;
            bool back = false;
            while (true)
            {
                angle += step; step += inc;
                curve.Add(angle);
                if (!back && angle > 199) { back = true; inc = -inc; }
                else if (back && step < 1) break;
            }
            var a = new double[Frames];
            for (int f = 0; f < Frames; f++)
                a[f] = curve[(int)Math.Round((double)f * (curve.Count - 1) / (Frames - 1))] * 360.0 / 4096;
            return a;
        }

        public static void Export(string re1Usa, string outDir)
        {
            Directory.CreateDirectory(outDir);
            string from;
            var lid = LoadLid(re1Usa, out from);
            var faces = new List<Face>();
            double hx = LidX / 2 * Scale, hy = LidZ / 2 * Scale, top = BodyH * Scale;

            // the lid, RE1's own: RE1 (x, y down, z) -> ours (x - 720, z, top - y)
            foreach (var t in lid.Tris)
            {
                var f = new Face { Lid = true };
                for (int c = 0; c < 3; c++)
                {
                    f.P[c] = new[] { (t.V[c][0] - LidX / 2) * Scale, t.V[c][2] * Scale, top - t.V[c][1] * Scale };
                    f.T[c] = new[] { t.U[c] + 0.5, t.W[c] + 0.5 };
                }
                faces.Add(f);
            }

            // the body: outer walls (the lid's top panel, its frame kept at its
            // real width), the rim, inner walls and the floor of the inside
            double w = Wall * Scale, bottom = top - InsideDepth * Scale;
            double frame = FrameTexels / (TopTex[2] - TopTex[0]) * LidX * Scale;   // the frame's width in map units
            Panel(faces, new[] { hx, -hy, 0.0 }, new[] { hx, hy, 0.0 }, new[] { hx, hy, top }, new[] { hx, -hy, top }, TopTex, frame);      // front (+X)
            Panel(faces, new[] { -hx, hy, 0.0 }, new[] { -hx, -hy, 0.0 }, new[] { -hx, -hy, top }, new[] { -hx, hy, top }, TopTex, frame);   // back
            Panel(faces, new[] { -hx, -hy, 0.0 }, new[] { hx, -hy, 0.0 }, new[] { hx, -hy, top }, new[] { -hx, -hy, top }, TopTex, frame);   // right end
            Panel(faces, new[] { hx, hy, 0.0 }, new[] { -hx, hy, 0.0 }, new[] { -hx, hy, top }, new[] { hx, hy, top }, TopTex, frame);       // left end
            double ix = hx - w, iy = hy - w;
            // the rim: four strips between the outer and inner edges
            Quad(faces, new[] { ix, -iy, top }, new[] { hx, -hy, top }, new[] { hx, hy, top }, new[] { ix, iy, top }, RimTex);
            Quad(faces, new[] { -hx, -hy, top }, new[] { -ix, -iy, top }, new[] { -ix, iy, top }, new[] { -hx, hy, top }, RimTex);
            Quad(faces, new[] { -hx, -hy, top }, new[] { hx, -hy, top }, new[] { ix, -iy, top }, new[] { -ix, -iy, top }, RimTex);
            Quad(faces, new[] { -ix, iy, top }, new[] { ix, iy, top }, new[] { hx, hy, top }, new[] { -hx, hy, top }, RimTex);
            // inside: walls facing in, and the floor
            Quad(faces, new[] { ix, iy, bottom }, new[] { ix, -iy, bottom }, new[] { ix, -iy, top }, new[] { ix, iy, top }, UnderTex);
            Quad(faces, new[] { -ix, -iy, bottom }, new[] { -ix, iy, bottom }, new[] { -ix, iy, top }, new[] { -ix, -iy, top }, UnderTex);
            Quad(faces, new[] { ix, -iy, bottom }, new[] { -ix, -iy, bottom }, new[] { -ix, -iy, top }, new[] { ix, -iy, top }, UnderTex);
            Quad(faces, new[] { -ix, iy, bottom }, new[] { ix, iy, bottom }, new[] { ix, iy, top }, new[] { -ix, iy, top }, UnderTex);
            Quad(faces, new[] { -ix, -iy, bottom }, new[] { ix, -iy, bottom }, new[] { ix, iy, bottom }, new[] { -ix, iy, bottom }, UnderTex);

            // both sides of every face (the walls are seen from inside too when open)
            var all = new List<Face>();
            foreach (var f in faces)
            {
                all.Add(f);
                all.Add(new Face { Lid = f.Lid, P = new[] { f.P[0], f.P[2], f.P[1] }, T = new[] { f.T[0], f.T[2], f.T[1] } });
            }

            // the frames: the lid turns about the hinge (back top edge), front rising
            var angles = LidAngles();
            var frames = new List<double[][]>();
            foreach (var deg in angles)
            {
                double a = deg * Math.PI / 180, ca = Math.Cos(a), sa = Math.Sin(a);
                var fr = new List<double[]>();
                foreach (var f in all)
                    foreach (var p in f.P)
                    {
                        if (!f.Lid) { fr.Add(p); continue; }
                        double dx = p[0] + hx, dz = p[2] - top;
                        fr.Add(new[] { -hx + dx * ca - dz * sa, p[1], top + dx * sa + dz * ca });
                    }
                frames.Add(fr.ToArray());
            }
            var tris = all.Select(f => new Tri { Palette = 0, U = new[] { f.T[0][0], f.T[1][0], f.T[2][0] }, W = new[] { f.T[0][1], f.T[1][1], f.T[2][1] } }).ToList();
            WriteTexture(Path.Combine(outDir, "itembox.png"), lid.Tim);
            Md3Writer.Write(Path.Combine(outDir, "itembox.md3"), tris, frames, lid.Tim, "itembox.png", lid.Tim.Width, lid.Tim.Height, false);
            Console.WriteLine("Wrote itembox.md3: RE1's lid from {0} on a matching body, {1} triangles, {2:F1} x {3:F1} x {4:F1} map units, {5} frames (lid 0 to {6:F1} degrees)",
                from, tris.Count, hx * 2, hy * 2, top + 90 * Scale, Frames, angles[Frames - 1]);
        }

        // A wall panel from corners a b c d (counter-clockwise from the bottom
        // left, seen from outside), textured with region r, split 3 x 3 so the
        // frame keeps its width (frame map units = FrameTexels texels) and only
        // the middle stretches. a-b runs along the region's v axis, a-d along u.
        static void Panel(List<Face> faces, double[] a, double[] b, double[] c, double[] d, double[] r, double frame)
        {
            double len = Dist(a, b), hgt = Dist(a, d);
            double fl = Math.Min(frame, len / 3), fh = Math.Min(frame, hgt / 3);
            double[] sAlong = { 0, fl / len, 1 - fl / len, 1 }, sUp = { 0, fh / hgt, 1 - fh / hgt, 1 };
            double[] tv = { r[1], r[1] + FrameTexels, r[3] - FrameTexels, r[3] };
            double[] tu = { r[0], r[0] + FrameTexels, r[2] - FrameTexels, r[2] };
            for (int i = 0; i < 3; i++)
                for (int j = 0; j < 3; j++)
                {
                    Func<int, int, double[]> P = (ii, jj) => Lerp(Lerp(a, b, sAlong[ii]), Lerp(d, c, sAlong[ii]), sUp[jj]);
                    Func<int, int, double[]> T = (ii, jj) => new[] { tu[jj], tv[ii] };
                    AddQuad(faces, P(i, j), P(i + 1, j), P(i + 1, j + 1), P(i, j + 1), T(i, j), T(i + 1, j), T(i + 1, j + 1), T(i, j + 1));
                }
        }

        // A quad from corners a b c d, the whole region r stretched over it.
        static void Quad(List<Face> faces, double[] a, double[] b, double[] c, double[] d, double[] r)
        {
            AddQuad(faces, a, b, c, d, new[] { r[0], r[3] }, new[] { r[2], r[3] }, new[] { r[2], r[1] }, new[] { r[0], r[1] });
        }

        static void AddQuad(List<Face> faces, double[] a, double[] b, double[] c, double[] d, double[] ta, double[] tb, double[] tc, double[] td)
        {
            faces.Add(new Face { P = new[] { a, b, c }, T = new[] { ta, tb, tc } });
            faces.Add(new Face { P = new[] { a, c, d }, T = new[] { ta, tc, td } });
        }

        static double Dist(double[] a, double[] b) { return Math.Sqrt((a[0] - b[0]) * (a[0] - b[0]) + (a[1] - b[1]) * (a[1] - b[1]) + (a[2] - b[2]) * (a[2] - b[2])); }
        static double[] Lerp(double[] a, double[] b, double t) { return new[] { a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t }; }

        // The lid's TIM as a picture (palette 0), a little brighter: RE1's room
        // objects are unlit textures, and GZDoom darkens them with the room.
        static void WriteTexture(string path, Tim tim)
        {
            using (var b = new Bitmap(tim.Width, tim.Height, PixelFormat.Format32bppArgb))
            {
                for (int y = 0; y < tim.Height; y++)
                    for (int x = 0; x < tim.Width; x++)
                    {
                        bool clear; var c = ModelBuilder.TexelColor(tim, 0, x, y, out clear);
                        b.SetPixel(x, y, Color.FromArgb(255, Math.Min(255, c.R * 6 / 5), Math.Min(255, c.G * 6 / 5), Math.Min(255, c.B * 6 / 5)));
                    }
                b.Save(path, ImageFormat.Png);
            }
        }

        public static void Sheet(string re1Usa, string outPath)
        {
            string from;
            var m = LoadLid(re1Usa, out from);
            double[] lo = { 1e9, 1e9, 1e9 }, hi = { -1e9, -1e9, -1e9 };
            foreach (var t in m.Tris) foreach (var v in t.V) for (int k = 0; k < 3; k++) { lo[k] = Math.Min(lo[k], v[k]); hi[k] = Math.Max(hi[k], v[k]); }
            Console.WriteLine("Lid from {0}: {1} triangles, modes {2}, tim {3}x{4} {5}bpp {6} palettes at {7},{8}, box x {9}..{10} y {11}..{12} z {13}..{14}",
                from, m.Tris.Count, m.Modes, m.Tim.Width, m.Tim.Height, m.Tim.Bpp, m.Tim.ClutH, m.Tim.ImgX, m.Tim.ImgY, lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]);
            var palettes = m.Tris.Select(t => t.Palette).Distinct().OrderBy(p => p);
            Console.WriteLine("Palettes used: " + string.Join(" ", palettes));
            foreach (var g in m.Tris.GroupBy(t => string.Format("u {0:F0}-{1:F0} v {2:F0}-{3:F0}", t.U.Min(), t.U.Max(), t.W.Min(), t.W.Max())))
            {
                var t0 = g.First();
                Console.WriteLine("  {0}: {1} tris, e.g. corners ({2}) ({3}) ({4})", g.Key, g.Count(),
                    string.Join(",", t0.V[0]), string.Join(",", t0.V[1]), string.Join(",", t0.V[2]));
            }
            const int cw = 360, ch = 300;
            var id = new[] { Mat.Identity() };
            var views = new[] {
                new double[] { 1, 0, 0, 0, 1, 0, 0, 0, 1 },
                new double[] { 1, 0, 0, 0, 0, -1, 0, 1, 0 },
                new double[] { 0, -1, 0, 1, 0, 0, 0, 0, 1 } };
            int texScale = 2;
            using (var bmp = new Bitmap(cw * 3 + m.Tim.Width * texScale + 20, Math.Max(ch, m.Tim.Height * m.Tim.ClutH * texScale + 20)))
            {
                using (var g = Graphics.FromImage(bmp)) g.Clear(Color.FromArgb(40, 40, 48));
                double ext = 1;
                foreach (var t in m.Tris) foreach (var v in t.V) ext = Math.Max(ext, Math.Max(Math.Abs(v[0]), Math.Max(Math.Abs(v[1]), Math.Abs(v[2]))));
                var ren = new SoftRenderer(bmp);
                for (int k = 0; k < views.Length; k++)
                    ren.DrawTurned(ItemProps.Turn(m.Tris, views[k]), id, m.Tim, cw * k + cw / 2, ch / 2, (ch * 0.4) / ext, 30);
                for (int p = 0; p < m.Tim.ClutH; p++)
                    for (int y = 0; y < m.Tim.Height; y++)
                        for (int x = 0; x < m.Tim.Width; x++)
                        {
                            bool clear; var c = ModelBuilder.TexelColor(m.Tim, p, x, y, out clear);
                            for (int dy = 0; dy < texScale; dy++) for (int dx = 0; dx < texScale; dx++)
                                    bmp.SetPixel(cw * 3 + 10 + x * texScale + dx, 10 + (p * m.Tim.Height + y) * texScale + dy, clear ? Color.Magenta : c);
                        }
                bmp.Save(outPath, ImageFormat.Png);
            }
        }
    }
}
