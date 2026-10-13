// ItemProps.cs - pickups made from RE1's own item models.
//
// RE1 shows an item you examine as a small 3D model: Item_m2\IxxV.IVM, a TIM
// (its texture) followed by a TMD (its model). The file for an item comes from
// its inventory picture number (g_ItemImageLookupTable byte 0, the same number
// that picks its ITEM_ALL.PIX picture) through the decomp's
// g_ItemModelFileNames table. Those are the models RE1's inventory pictures
// were drawn from, so they match the pictures in shape and colour.
//
//   re1convert itemsheet <RE1 USA> <out.png>      the models next to RE1's pictures
//   re1convert items <RE1 USA> <out folder>       models/props/item_<name>.iqm + .png

using System;
using System.Collections.Generic;
using RD.Drawing;
using System.IO;
using System.Linq;

namespace Re1Convert
{
    static class ItemProps
    {
        // name, IVM file, ITEM_ALL.PIX row (picture number - 1)
        public static readonly string[][] Items = {
            new[] { "clip",      "I26V", "7"  },
            new[] { "shells",    "I16V", "8"  },
            new[] { "magnum",    "I15V", "10" },
            new[] { "explosive", "I14V", "12" },
            new[] { "acid",      "I12V", "13" },
            new[] { "flame",     "I13V", "14" },
            new[] { "herb_red",  "I66V", "63" },
            new[] { "herb_green","I64V", "64" },
            new[] { "herb_blue", "I65V", "65" },
            new[] { "ribbon",    "I56V", "43" },
            // These come from RE1's own tables (g_ItemImageLookupTable byte 0 ->
            // g_ItemModelFileNames). They stand in for Doom's keys and power-ups
            // (RE_DoomItems.zs); the keys keep their Doom colour as a tint.
            new[] { "spray",      "I23V", "61" },               // First Aid Spray
            new[] { "flamethrower", "I01V", "4" },              // Chris's flamethrower (Doom's chaingun)
            // The other weapons on the floor (g_ItemImageLookupTable byte 0 -> g_ItemModelFileNames)
            new[] { "w_knife",    "I05V", "0" },                // Doom's chainsaw
            new[] { "w_beretta",  "I00V", "1" },                // Doom's pistol
            new[] { "w_shotgun",  "I02V", "2" },
            new[] { "w_python",   "I04V", "3" },                // Doom's super shotgun
            new[] { "w_bazooka",  "I08V", "5" },                // Doom's rocket launcher and plasma rifle
            new[] { "w_rocket",   "I07V", "6" },                // Doom's BFG9000
            new[] { "chemical",   "I43V", "34" },               // Doom's radiation suit
            new[] { "lighter",    "I17V", "44" },               // Doom's light amplification visor
            new[] { "key_armor",  "I28V", "48", "3060FF" },     // blue keycard
            new[] { "key_shield", "I29V", "49", "FF3020" },     // red keycard (RE1's shield key is copper-red)
            new[] { "key_sword",  "I30V", "47", "FFD020" },     // yellow keycard (RE1's sword key is gold)
            new[] { "key_helmet", "I27V", "50", "3060FF" },     // blue skull key
            new[] { "crest_star", "I61V", "41", "FFD020" },     // yellow skull key
            new[] { "crest_sun",  "I59V", "42", "FF3020" },     // red skull key
        };

        public class Model { public Tim Tim; public List<Tri> Tris = new List<Tri>(); public string Modes = ""; }

        public static Model Load(string re1Usa, string file)
        {
            byte[] b = Fs.ReadAllBytes(Path.Combine(re1Usa, "Item_m2/" + file + ".IVM"));
            int flags = Bin.S32(b, 4), p = 8;
            if ((flags & 8) != 0) p += Bin.S32(b, p);
            p += Bin.S32(b, p);                         // the TMD follows the image block
            return FromBytes(b, 0, p);
        }

        // A model from a TIM and a TMD anywhere in a file (an IVM, or a room
        // object in an RDT: ItemBox.cs).
        public static Model FromBytes(byte[] b, int timAt, int tmdAt)
        {
            var m = new Model { Tim = Tim.Read(b, timAt) };
            var tmd = Tmd.Read(b, tmdAt);
            m.Modes = string.Join(" ", tmd.ModeCounts.Select(kv => string.Format("{0:X4}x{1}", kv.Key, kv.Value)));
            var tim = m.Tim;
            int mul = tim.Bpp == 8 ? 2 : tim.Bpp == 4 ? 4 : 1;
            foreach (var obj in tmd.Objects)
                foreach (var pr in obj.Prims)
                {
                    int pageX = (pr.TPage & 0x0F) * 64 * mul - tim.ImgX * mul;
                    int pageY = ((pr.TPage >> 4) & 1) * 256 - tim.ImgY;
                    int palRow = Math.Max(0, Math.Min(tim.ClutH - 1, (pr.Clut >> 6) - tim.ClutY));
                    // a quad's corners are 0 1 2 3 in a Z: triangles 0 1 2 and 1 3 2
                    int[][] faces = pr.Verts.Length == 4 ? new[] { new[] { 0, 1, 2 }, new[] { 1, 3, 2 } } : new[] { new[] { 0, 1, 2 } };
                    foreach (var f in faces)
                    {
                        var t = new Tri { Joint = 0, Palette = palRow };
                        for (int c = 0; c < 3; c++)
                        {
                            t.V[c] = obj.Verts[pr.Verts[f[c]]];
                            t.U[c] = pr.U[f[c]] + pageX;
                            t.W[c] = pr.V[f[c]] + pageY;
                        }
                        m.Tris.Add(t);
                    }
                }
            return m;
        }

        // A copy of the triangles turned by a 3x3 matrix (row-major).
        public static List<Tri> Turn(List<Tri> tris, double[] r)
        {
            var o = new List<Tri>();
            foreach (var t in tris)
            {
                var n = new Tri { Joint = t.Joint, Palette = t.Palette, U = (double[])t.U.Clone(), W = (double[])t.W.Clone() };
                for (int c = 0; c < 3; c++)
                {
                    var v = t.V[c];
                    n.V[c] = new short[] {
                        (short)Math.Round(r[0] * v[0] + r[1] * v[1] + r[2] * v[2]),
                        (short)Math.Round(r[3] * v[0] + r[4] * v[1] + r[5] * v[2]),
                        (short)Math.Round(r[6] * v[0] + r[7] * v[1] + r[8] * v[2]) };
                }
                o.Add(n);
            }
            return o;
        }

        // --- the game files ---------------------------------------------------

        // Lying flat on the floor (thinnest side down) instead of standing as
        // RE1 shows it; and the size of its longest side in map units (herbs
        // about 16, everything else about 10-11, like the old herb props).
        static bool LaysFlat(string name) { return name.StartsWith("w_") || name == "clip" || name == "ribbon" || name == "flamethrower" || name.StartsWith("key_") || name.StartsWith("crest_"); }
        static double Size(string name)
        {
            if (name.StartsWith("herb")) return 16;
            if (name == "chemical" || name == "spray") return 16;   // as big as a herb, to be seen from a distance
            if (name == "shells") return 12;
            if (name == "ribbon") return 11;
            if (name.StartsWith("key_")) return 16;      // much bigger than RE1's, so a key on the floor is spotted
            if (name.StartsWith("crest_")) return 14;
            if (name == "lighter") return 10;
            if (name == "flamethrower") return 30;
            if (name == "w_knife" || name == "w_beretta") return 13;
            if (name == "w_python") return 15;
            if (name == "w_shotgun" || name == "w_bazooka") return 30;
            if (name == "w_rocket") return 34;
            return 10;
        }

        public static void Export(string re1Usa, string outDir)
        {
            Directory.CreateDirectory(outDir);
            foreach (var it in Items)
            {
                string name = it[0];
                var m = Load(re1Usa, it[1]);
                // RE1 (x, y down, z) -> Doom (x, z, -y): stand up as RE1 shows it
                var pts = new List<double[][]>();
                foreach (var t in m.Tris) pts.Add(t.V.Select(v => new double[] { v[0], v[2], -v[1] }).ToArray());
                if (LaysFlat(name)) pts = LayFlat(pts);
                // the Magnum rounds canister lies on its side, as in RE1's picture (its axis level)
                if (name == "magnum") pts = pts.Select(tri => tri.Select(p => new[] { p[0], p[2], -p[1] }).ToArray()).ToList();
                // scale, centre, and set on the floor
                double[] lo = { 1e9, 1e9, 1e9 }, hi = { -1e9, -1e9, -1e9 };
                foreach (var tri in pts) foreach (var p in tri) for (int k = 0; k < 3; k++) { lo[k] = Math.Min(lo[k], p[k]); hi[k] = Math.Max(hi[k], p[k]); }
                double longest = Math.Max(hi[0] - lo[0], Math.Max(hi[1] - lo[1], hi[2] - lo[2]));
                double s = Size(name) / longest;
                var pos = new List<double[][]>(); var uv = new List<double[][]>();
                for (int i = 0; i < pts.Count; i++)
                {
                    pos.Add(pts[i].Select(p => new[] { (p[0] - (lo[0] + hi[0]) / 2) * s, (p[1] - (lo[1] + hi[1]) / 2) * s, (p[2] - lo[2]) * s }).ToArray());
                    var t = m.Tris[i];
                    uv.Add(new[] { new[] { t.U[0] + 0.5, t.W[0] + 0.5 }, new[] { t.U[1] + 0.5, t.W[1] + 0.5 }, new[] { t.U[2] + 0.5, t.W[2] + 0.5 } });
                }
                double[] gain;
                string png = name + ".png";
                WriteTexture(Path.Combine(outDir, png), m, Prop.ItemIconPublic(re1Usa, int.Parse(it[2])), out gain);
                if (it.Length > 3) Tint(Path.Combine(outDir, png), it[3]);
                Prop.WriteTriangles(Path.Combine(outDir, name + ".iqm"), png, pos, uv, m.Tim.Width, m.Tim.Height);
                Console.WriteLine("Wrote {0}.iqm: {1} triangles, {2:F1} x {3:F1} x {4:F1} map units, colour gain {5:F2} {6:F2} {7:F2}",
                    name, m.Tris.Count, (hi[0] - lo[0]) * s, (hi[1] - lo[1]) * s, (hi[2] - lo[2]) * s, gain[0], gain[1], gain[2]);
            }
            WriteMap(re1Usa, outDir);
        }

        // A key's colour: each texel moves 45% of the way to the tint, at its
        // own brightness, so the key's shape and detail stay readable.
        static void Tint(string path, string hex)
        {
            int tr = Convert.ToInt32(hex.Substring(0, 2), 16), tg = Convert.ToInt32(hex.Substring(2, 2), 16), tb = Convert.ToInt32(hex.Substring(4, 2), 16);
            Bitmap b;
            using (var src = new Bitmap(path)) b = new Bitmap(src);
            using (b)
            {
                for (int y = 0; y < b.Height; y++)
                    for (int x = 0; x < b.Width; x++)
                    {
                        var c = b.GetPixel(x, y);
                        if (c.A == 0) continue;
                        double lum = (0.3 * c.R + 0.59 * c.G + 0.11 * c.B) / 160.0;
                        b.SetPixel(x, y, Color.FromArgb(255, Clamp(c.R * 0.55 + tr * lum * 0.45), Clamp(c.G * 0.55 + tg * lum * 0.45), Clamp(c.B * 0.55 + tb * lum * 0.45)));
                    }
                b.Save(path, ImageFormat.Png);
            }
        }

        // The MAP pickup (Doom's computer area map). RE1 has no map item model,
        // so it's a sheet lying on the floor showing RE1's own map picture
        // (Item_m2\MAP00.TIM, the mansion's first floor).
        static void WriteMap(string re1Usa, string outDir)
        {
            var tim = Tim.Read(Fs.ReadAllBytes(Path.Combine(re1Usa, "Item_m2/MAP00.TIM")), 0);
            using (var b = new Bitmap(tim.Width, tim.Height, PixelFormat.Format32bppArgb))
            {
                for (int y = 0; y < tim.Height; y++)
                    for (int x = 0; x < tim.Width; x++)
                    {
                        bool clear; var c = ModelBuilder.TexelColor(tim, 0, x, y, out clear);
                        b.SetPixel(x, y, clear ? Color.FromArgb(255, 18, 26, 52) : c);   // see-through: the dark blue of RE1's map screen
                    }
                b.Save(Path.Combine(outDir, "map.png"), ImageFormat.Png);
            }
            double w = 24, h = w * tim.Height / tim.Width, z = 0.3;
            var p = new[] { new[] { -w / 2, -h / 2, z }, new[] { w / 2, -h / 2, z }, new[] { w / 2, h / 2, z }, new[] { -w / 2, h / 2, z } };
            var t = new[] { new double[] { 0, tim.Height }, new double[] { tim.Width, tim.Height }, new double[] { tim.Width, 0 }, new double[] { 0, 0 } };
            var pos = new List<double[][]>(); var uv = new List<double[][]>();
            foreach (var f in new[] { new[] { 0, 1, 2 }, new[] { 0, 2, 3 }, new[] { 0, 2, 1 }, new[] { 0, 3, 2 } })   // both sides
            {
                pos.Add(f.Select(i => p[i]).ToArray());
                uv.Add(f.Select(i => t[i]).ToArray());
            }
            Prop.WriteTriangles(Path.Combine(outDir, "map.iqm"), "map.png", pos, uv, tim.Width, tim.Height);
            Console.WriteLine("Wrote map.iqm: {0:F0} x {1:F0} map units, RE1's MAP00 picture", w, h);
        }

        // Turn so the thinnest side of the model points up.
        static List<double[][]> LayFlat(List<double[][]> pts)
        {
            double[] lo = { 1e9, 1e9, 1e9 }, hi = { -1e9, -1e9, -1e9 };
            foreach (var tri in pts) foreach (var p in tri) for (int k = 0; k < 3; k++) { lo[k] = Math.Min(lo[k], p[k]); hi[k] = Math.Max(hi[k], p[k]); }
            int thin = 0;
            for (int k = 1; k < 3; k++) if (hi[k] - lo[k] < hi[thin] - lo[thin]) thin = k;
            if (thin == 2) return pts;
            // swap the thin axis with Z (keeping the turn proper: one axis negated)
            return pts.Select(tri => tri.Select(p => thin == 0 ? new[] { -p[2], p[1], p[0] } : new[] { p[0], -p[2], p[1] }).ToArray()).ToList();
        }

        // The model's texture (palette 0), each colour channel scaled so the
        // texels the model uses average the same colour as RE1's inventory
        // picture of it (the picture was drawn lit; the texture is unlit, and
        // GZDoom lights it again with the room). Clear texels stay clear.
        static void WriteTexture(string path, Model m, Color[,] icon, out double[] gain)
        {
            var tim = m.Tim;
            int w = tim.Width, h = tim.Height;
            var used = new bool[w, h];
            foreach (var t in m.Tris)
            {
                int x0 = (int)Math.Floor(t.U.Min()), x1 = (int)Math.Ceiling(t.U.Max()), y0 = (int)Math.Floor(t.W.Min()), y1 = (int)Math.Ceiling(t.W.Max());
                double area = (t.U[1] - t.U[0]) * (t.W[2] - t.W[0]) - (t.U[2] - t.U[0]) * (t.W[1] - t.W[0]);
                for (int y = Math.Max(0, y0); y <= Math.Min(h - 1, y1); y++)
                    for (int x = Math.Max(0, x0); x <= Math.Min(w - 1, x1); x++)
                    {
                        if (Math.Abs(area) < 1e-6) { used[x, y] = true; continue; }
                        double cx = x + 0.5, cy = y + 0.5;
                        double b0 = ((t.U[1] - cx) * (t.W[2] - cy) - (t.U[2] - cx) * (t.W[1] - cy)) / area;
                        double b1 = ((t.U[2] - cx) * (t.W[0] - cy) - (t.U[0] - cx) * (t.W[2] - cy)) / area;
                        if (b0 >= -0.05 && b1 >= -0.05 && 1 - b0 - b1 >= -0.05) used[x, y] = true;
                    }
            }
            double[] tex = new double[3], ico = new double[3];
            int nt = 0, ni = 0;
            for (int y = 0; y < h; y++)
                for (int x = 0; x < w; x++)
                {
                    if (!used[x, y]) continue;
                    bool clear; var c = ModelBuilder.TexelColor(tim, 0, x, y, out clear);
                    if (clear) continue;
                    tex[0] += c.R; tex[1] += c.G; tex[2] += c.B; nt++;
                }
            for (int y = 0; y < 30; y++)
                for (int x = 0; x < 40; x++)
                {
                    var c = icon[x, y];
                    if ((c.B > c.R + 30 && c.B > c.G + 30) || c.R + c.G + c.B < 30) continue;   // RE1's blue backdrop
                    ico[0] += c.R; ico[1] += c.G; ico[2] += c.B; ni++;
                }
            gain = new double[3];
            // one brightness factor (keeps RE1's own texture colours), then each
            // channel nudged at most 10% towards the picture's colour cast
            for (int k = 0; k < 3; k++) { ico[k] = ico[k] / Math.Max(1, ni) + 1; tex[k] = tex[k] / Math.Max(1, nt) + 1; }
            double yi = 0.3 * ico[0] + 0.59 * ico[1] + 0.11 * ico[2], yt = 0.3 * tex[0] + 0.59 * tex[1] + 0.11 * tex[2];
            double lum = Math.Max(0.6, Math.Min(3.0, yi / yt));
            for (int k = 0; k < 3; k++) gain[k] = lum * Math.Max(0.9, Math.Min(1.1, (ico[k] / yi) / (tex[k] / yt)));
            using (var b = new Bitmap(w, h, PixelFormat.Format32bppArgb))
            {
                for (int y = 0; y < h; y++)
                    for (int x = 0; x < w; x++)
                    {
                        bool clear; var c = ModelBuilder.TexelColor(tim, 0, x, y, out clear);
                        b.SetPixel(x, y, clear ? Color.FromArgb(0, 0, 0, 0) : Color.FromArgb(255,
                            Clamp(c.R * gain[0]), Clamp(c.G * gain[1]), Clamp(c.B * gain[2])));
                    }
                b.Save(path, ImageFormat.Png);
            }
        }

        static int Clamp(double v) { return (int)Math.Max(0, Math.Min(255, Math.Round(v))); }

        public static void Sheet(string re1Usa, string outPath)
        {
            var id = new[] { Mat.Identity() };
            var views = new[] {
                new double[] { 1, 0, 0, 0, 1, 0, 0, 0, 1 },        // as stored
                new double[] { 1, 0, 0, 0, 0, -1, 0, 1, 0 },       // tipped 90 about X
                new double[] { 0, -1, 0, 1, 0, 0, 0, 0, 1 } };     // turned 90 about Z
            const int cw = 200, ch = 160;
            using (var bmp = new Bitmap(cw * 4, ch * Items.Length))
            {
                using (var g = Graphics.FromImage(bmp)) g.Clear(Color.FromArgb(40, 40, 48));
                for (int i = 0; i < Items.Length; i++)
                {
                    var m = Load(re1Usa, Items[i][1]);
                    double ext = 1;
                    foreach (var t in m.Tris) foreach (var v in t.V) ext = Math.Max(ext, Math.Max(Math.Abs(v[0]), Math.Max(Math.Abs(v[1]), Math.Abs(v[2]))));
                    double scale = (ch * 0.42) / ext;
                    var ren = new SoftRenderer(bmp);
                    for (int k = 0; k < views.Length; k++)
                        ren.DrawTurned(Turn(m.Tris, views[k]), id, m.Tim, cw * (k + 1) + cw / 2, ch * i + ch / 2, scale, 30);
                    var icon = Prop.ItemIconPublic(re1Usa, int.Parse(Items[i][2]));
                    for (int y = 0; y < 30; y++) for (int x = 0; x < 40; x++)
                            for (int dy = 0; dy < 4; dy++) for (int dx = 0; dx < 4; dx++) bmp.SetPixel(20 + x * 4 + dx, ch * i + 20 + y * 4 + dy, icon[x, y]);
                    using (var g = Graphics.FromImage(bmp))
                        g.DrawString(Items[i][0] + " " + Items[i][1], new Font("Segoe UI", 9), Brushes.White, 4, ch * i + 2);
                    Console.WriteLine("{0} {1}: {2} triangles, size +-{3}, tim {4}x{5} {6}bpp {7} palettes, prim modes {8}",
                        Items[i][0], Items[i][1], m.Tris.Count, ext, m.Tim.Width, m.Tim.Height, m.Tim.Bpp, m.Tim.ClutH, m.Modes);
                }
                bmp.Save(outPath, ImageFormat.Png);
            }
        }
    }
}
