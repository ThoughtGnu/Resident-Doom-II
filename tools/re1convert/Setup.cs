// Setup.cs - the steps setup runs, so a fresh copy of Resident Doom can build
// every picture, model and sound from the player's own game files:
//
//   re1convert check <RE1 folder> <doom2.wad>      are these the right files?
//   re1convert all <RE1 folder> <doom2.wad> <mod>  build everything into <mod>
//   re1convert selectart <RE1 folder> <mod>        select screen, ID cards, save prompt
//   re1convert titleart <RE1 folder> <doom wad> <mod>   title picture and menu logo
//   re1convert sounds <RE1 folder> <mod>           RE1's sounds, copied
//   re1convert levelshots <captured folder> <mod>  Level Select pictures
//
// <RE1 folder> is the Resident Evil game folder (with ResidentEvil.exe and
// USA in it), or its USA folder. Files there are only ever read.

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using RD.Drawing;

namespace Re1Convert
{
    static partial class Program
    {
        // RE1's sounds the mod plays (mod/sounds/re1, sndinfo.txt)
        static readonly string[] SoundFiles = {
            "chris04", "flame01", "flame02", "flame03", "gracid02", "gracid03", "grbomb02", "grbomb03", "grfire02", "grfire03",
            "gun01", "jill04", "knife01", "knife02", "magnum01", "rocket01", "rocket03", "shot01", "shot03" };

        // Files the build needs, inside USA (checked before anything is written)
        static readonly string[] NeededFiles = {
            "Enemy/CHAR11.EMD", "Enemy/Char10.EMD",
            "Players/W00.EMW", "Players/W01.EMW", "Players/W02.EMW", "Players/W03.EMW", "Players/W04.EMW", "Players/W05.EMW", "Players/W06.EMW", "Players/W07.EMW",
            "Players/W10.EMW", "Players/W11.EMW", "Players/W12.EMW", "Players/W13.EMW", "Players/W14.EMW", "Players/W16.EMW", "Players/W17.EMW",
            "Data/STATUS.TIM", "Data/Statface.tim", "Data/BLUE.TIM", "Data/fontus.tim", "Data/ITEMBOXn.TIM", "Data/ITEM_ALL.PIX",
            "Data/SEL_BACK.PIX", "Data/Select_b.tim", "Data/TYPE00.TIM", "Data/TITLE.PIX",
            "Effspr/esp001.tim", "Item_m2/MAP00.TIM", "Stage1/ROOM1000.RDT" };

        // doom2.wad releases we know (MD5): others still work if they look like Doom II
        static readonly Dictionary<string, string> KnownDoom2 = new Dictionary<string, string>
        {
            { "25e1459ca71d321525f84628f45ca8cd", "Doom II 1.9 (classic: GOG / Steam DOS version)" },
            { "c3bea40570c23e511a7ed3ebcd9865f7", "Doom II (BFG Edition)" },
            { "64a4c88a871da67492aaa2020a068cd8", "Doom II (DOOM + DOOM II, 2024 re-release)" },
            { "9aa3cbf65b961d0bdac98ec403b832e1", "Doom II (DOOM + DOOM II, 2024 re-release, first version)" },
        };

        // The USA folder, given the game folder or USA itself.
        static string Usa(string folder)
        {
            string f = folder.TrimEnd('/', '\\');
            if (Directory.Exists(Fs.Resolve(Path.Combine(f, "USA")))) return Fs.Resolve(Path.Combine(f, "USA"));
            return Fs.Resolve(f);
        }

        static string Md5(string path)
        {
            using (var md5 = MD5.Create())
            using (var s = File.OpenRead(path))
                return BitConverter.ToString(md5.ComputeHash(s)).Replace("-", "").ToLowerInvariant();
        }

        // Plain-language checks; every problem is printed, then the answer.
        static bool Check(string re1, string wad)
        {
            bool ok = true;
            Action<string> bad = m => { Console.WriteLine("PROBLEM: " + m); ok = false; };
            Console.WriteLine("Checking your Resident Evil folder: " + re1);
            if (!Directory.Exists(Fs.Resolve(re1)))
                bad("That folder doesn't exist. Pick the Resident Evil folder from GOG (it has ResidentEvil.exe and a USA folder in it).");
            else
            {
                string usa = Usa(re1);
                if (!Directory.Exists(usa) || !Directory.Exists(Fs.Resolve(Path.Combine(usa, "Players"))))
                    bad("No USA folder with RE1's data in it. Pick the folder that contains ResidentEvil.exe and USA (the GOG version of Resident Evil).");
                else
                {
                    var missing = NeededFiles.Concat(SoundFiles.Select(s => "Sound/" + s + ".wav"))
                        .Where(n => !Fs.Exists(Path.Combine(usa, n))).ToList();
                    foreach (var m in missing.Take(8)) bad("USA/" + m + " is missing.");
                    if (missing.Count > 8) bad("... and " + (missing.Count - 8) + " more files are missing.");
                    if (missing.Count > 0) Console.WriteLine("  This doesn't look like a complete GOG Resident Evil. Reinstall it from GOG, or copy the whole folder again.");
                    string exe = Path.Combine(Path.GetDirectoryName(usa), "ResidentEvil.exe");
                    if (!Fs.Exists(exe) && !Fs.Exists(Path.Combine(usa, "ResidentEvil.exe")))
                        bad("ResidentEvil.exe is missing next to the USA folder (the inventory art reads RE1's item table from it). Copy the whole Resident Evil folder, not just USA.");
                }
            }
            Console.WriteLine("Checking your doom2.wad: " + wad);
            string w = Fs.Resolve(wad);
            if (!File.Exists(w)) bad("That file doesn't exist. Pick doom2.wad from your GOG or Steam DOOM II (or DOOM + DOOM II).");
            else
            {
                var lumps = WadLumps(w);
                if (lumps == null) bad("That file isn't a Doom WAD file.");
                else
                {
                    bool iwad = File.ReadAllBytes(w).Take(4).SequenceEqual(new[] { (byte)'I', (byte)'W', (byte)'A', (byte)'D' });
                    int maps = Enumerable.Range(1, 32).Count(i => lumps.ContainsKey(string.Format("MAP{0:00}", i)));
                    if (!iwad) bad("That WAD is an add-on (PWAD), not the game itself. Pick doom2.wad.");
                    else if (lumps.ContainsKey("E1M1")) bad("That's DOOM (doom.wad), not DOOM II. Pick doom2.wad.");
                    else if (maps < 32 || !lumps.ContainsKey("PLAYPAL") || !lumps.ContainsKey("M_DOOM")) bad("That doesn't look like DOOM II (it needs MAP01-MAP32).");
                    else if (lumps.ContainsKey("CAVERN1") || lumps.ContainsKey("TNT1")) bad("That looks like Final Doom (TNT or Plutonia), not DOOM II. Pick doom2.wad.");
                    else
                    {
                        string known;
                        string md5 = Md5(w);
                        if (KnownDoom2.TryGetValue(md5, out known)) Console.WriteLine("  Found " + known + ".");
                        else Console.WriteLine("  Note: a DOOM II version we haven't tested (MD5 " + md5 + "). It should still work.");
                    }
                }
            }
            Console.WriteLine(ok ? "Files OK." : "Please fix the problems above and run setup again.");
            return ok;
        }

        // A WAD's lump directory (name -> offset, size), or null if it isn't one.
        static Dictionary<string, int[]> WadLumps(string path)
        {
            byte[] b = File.ReadAllBytes(path);
            if (b.Length < 12) return null;
            string id = System.Text.Encoding.ASCII.GetString(b, 0, 4);
            if (id != "IWAD" && id != "PWAD") return null;
            int n = BitConverter.ToInt32(b, 4), dir = BitConverter.ToInt32(b, 8);
            if (n < 0 || dir < 12 || dir + n * 16L > b.Length) return null;
            var d = new Dictionary<string, int[]>();
            for (int i = 0; i < n; i++)
            {
                int o = dir + i * 16;
                string name = System.Text.Encoding.ASCII.GetString(b, o + 8, 8).TrimEnd('\0').ToUpperInvariant();
                if (!d.ContainsKey(name)) d[name] = new[] { BitConverter.ToInt32(b, o), BitConverter.ToInt32(b, o + 4) };
            }
            return d;
        }

        // Every generated file, in order. Stops at the first step that fails,
        // saying which one.
        static void All(string re1, string wad, string mod)
        {
            string usa = Usa(re1);
            Action<string, Action> step = (name, act) =>
            {
                Console.WriteLine();
                Console.WriteLine("== " + name);
                try { act(); }
                catch (Exception e) { throw new Exception("step \"" + name + "\" failed: " + e.Message, e); }
            };
            Func<string, string> M = rel => Path.Combine(mod, rel.Replace('/', Path.DirectorySeparatorChar));
            step("Jill's models", () => Character("jill", usa, M("models/jill")));
            step("Chris's models", () => Character("chris", usa, M("models/chris")));
            string[][] arms = {
                new[] { "jill", "knife", "JKN", "REKnife" }, new[] { "jill", "beretta", "JBR", "REHandgun" },
                new[] { "jill", "shotgun", "JSG", "REShotgun", "0", "0", "5" }, new[] { "jill", "magnum", "JMG", "REMagnum" },
                new[] { "jill", "grenade", "JGL", "REGrenadeLauncher" }, new[] { "jill", "rocket", "JRL", "RERocketLauncher", "0", "0", "0", "38", "-8", "-17" },
                new[] { "chris", "knife", "CKN", "REKnife", "--pose-from", "jill" }, new[] { "chris", "beretta", "CBR", "REHandgun", "--pose-from", "jill" },
                new[] { "chris", "shotgun", "CSG", "REShotgun", "0", "0", "5", "--pose-from", "jill" }, new[] { "chris", "magnum", "CMG", "REMagnum", "--pose-from", "jill" },
                new[] { "chris", "grenade", "CGL", "REGrenadeLauncher", "--pose-from", "jill" },
                new[] { "chris", "rocket", "CRL", "RERocketLauncher", "0", "0", "0", "38", "-8", "-17", "--pose-from", "jill" },
                new[] { "chris", "flame", "CFL", "REFlamethrower", "0", "0", "0", "4", "-6", "-4", "--point-forward" } };
            step("first-person arms", () =>
            {
                foreach (var a in arms)
                    ViewArms.Run(new[] { "viewarms", usa, mod }.Concat(a).ToArray());
            });
            step("items", () => ItemProps.Export(usa, M("models/props/items")));
            step("herbs, vests, typewriter, ink ribbon", () =>
            {
                Prop.Run("herbs", M("models/props"));
                Prop.Run("vests", M("models/props"));
                Prop.Run("typewriter", M("models/props"));
                Prop.Run("ribbon", M("models/props"), usa);
            });
            step("item box", () => ItemBox.Export(usa, M("models/props")));
            step("flamethrower fire", () => FlameSprites.Export(usa, M("sprites/re")));
            step("cast-call sprites", () => CastSprites.Export(usa, mod));
            step("RE1 Classic inventory art", () => StatusArt.Export(usa, mod));
            step("select screen", () =>
            {
                BothAnim(usa, M("graphics"));
                Portrait("jill", usa, M("graphics/SELJILL.png"));
                Portrait("chris", usa, M("graphics/SELCHRIS.png"));
                SelectArt(usa, mod);
            });
            step("title picture and menu logo", () => TitleArt(usa, wad, mod));
            step("sounds", () => Sounds(usa, mod));
            Console.WriteLine();
            Console.WriteLine("All files built.");
        }

        // A 16-bit PIX picture (15-bit colour, 0..31 -> 0..255).
        static Bitmap Pix(string path, int w, int h)
        {
            byte[] b = Fs.ReadAllBytes(path);
            var bmp = new Bitmap(w, h);
            for (int y = 0; y < h; y++)
                for (int x = 0; x < w; x++)
                {
                    int c = b[(y * w + x) * 2] | (b[(y * w + x) * 2 + 1] << 8);
                    bmp.SetPixel(x, y, Color.FromArgb(255, (c & 31) * 255 / 31, ((c >> 5) & 31) * 255 / 31, ((c >> 10) & 31) * 255 / 31));
                }
            return bmp;
        }

        // A 16-bit TIM picture, every pixel opaque (colour 0..31 -> x8).
        static Bitmap Tim16(string path)
        {
            byte[] b = Fs.ReadAllBytes(path);
            uint flags = BitConverter.ToUInt32(b, 4);
            int o = 8;
            if ((flags & 8) != 0) o = 8 + (int)BitConverter.ToUInt32(b, 8);
            int w = BitConverter.ToUInt16(b, o + 8), h = BitConverter.ToUInt16(b, o + 10), d = o + 12;
            if ((flags & 3) != 2) throw new Exception(Path.GetFileName(path) + " isn't a 16-bit picture");
            var bmp = new Bitmap(w, h);
            for (int y = 0; y < h; y++)
                for (int x = 0; x < w; x++)
                {
                    int c = BitConverter.ToUInt16(b, d + (y * w + x) * 2);
                    bmp.SetPixel(x, y, Color.FromArgb(255, (c & 31) * 8, ((c >> 5) & 31) * 8, ((c >> 10) & 31) * 8));
                }
            return bmp;
        }

        static Bitmap Crop(Bitmap s, int x0, int y0, int w, int h)
        {
            var o = new Bitmap(w, h);
            for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) o.Px[y * w + x] = s.Px[(y0 + y) * s.Width + x0 + x];
            return o;
        }

        // The character-select background (SEL_BACK.PIX), the S.T.A.R.S. ID
        // cards on the Level Select screen (Select_b.tim) and the save prompt's
        // background (TYPE00.TIM).
        static void SelectArt(string usa, string mod)
        {
            string g = Path.Combine(mod, "graphics");
            Directory.CreateDirectory(g);
            using (var b = Pix(Path.Combine(usa, "Data/SEL_BACK.PIX"), 320, 240)) b.Save(Path.Combine(g, "SELBACK.png"));
            using (var cards = Tim16(Path.Combine(usa, "Data/Select_b.tim")))
            {
                Crop(cards, 80, 0, 112, 126).Save(Path.Combine(g, "CARDCHRS.png"));
                Crop(cards, 0, 128, 112, 126).Save(Path.Combine(g, "CARDJILL.png"));
            }
            using (var t = Tim16(Path.Combine(usa, "Data/TYPE00.TIM"))) t.Save(Path.Combine(g, "TYPEBACK.png"));
            Console.WriteLine("Wrote SELBACK, CARDJILL, CARDCHRS and TYPEBACK to " + g);
        }

        // A Doom picture lump (columns of posts) in the WAD's palette.
        static Bitmap DoomPatch(string wad, string lump)
        {
            var l = WadLumps(wad);
            byte[] b = File.ReadAllBytes(wad);
            int pal = l["PLAYPAL"][0], p = l[lump][0];
            int w = BitConverter.ToUInt16(b, p), h = BitConverter.ToUInt16(b, p + 2);
            var bmp = new Bitmap(w, h);
            for (int x = 0; x < w; x++)
            {
                int c = p + BitConverter.ToInt32(b, p + 8 + 4 * x);
                while (b[c] != 255)
                {
                    int top = b[c], len = b[c + 1];
                    for (int k = 0; k < len; k++)
                    {
                        int ix = b[c + 3 + k];
                        bmp.SetPixel(x, top + k, Color.FromArgb(255, b[pal + 3 * ix], b[pal + 3 * ix + 1], b[pal + 3 * ix + 2]));
                    }
                    c += len + 4;
                }
            }
            return bmp;
        }

        static int Cl(double v) { return Math.Max(0, Math.Min(255, (int)v)); }
        static bool TitleRed(Color c) { return c.R > 70 && c.R > 2 * c.G && c.R > 2 * c.B; }

        static Bitmap Tint(Bitmap s, Color c)
        {
            var o = new Bitmap(s.Width, s.Height);
            for (int i = 0; i < s.Px.Length; i++)
            {
                int a = (s.Px[i] >> 24) & 255;
                if (a > 0) o.Px[i] = Color.FromArgb(a * c.A / 255, c.R, c.G, c.B).ToArgb();
            }
            return o;
        }

        // The title screen (hires/TITLEPIC.png, 1120x400): RE1's title art with
        // its RESIDENT EVIL lettering painted out, RESIDENT put back above the
        // DOOM logo, wide sides from the same art blurred and darkened. The DOOM
        // logo is the original DOOM's (doom.wad, next to doom2.wad in the DOOM +
        // DOOM II releases); without it, DOOM II's own logo. Then the menu logo
        // (graphics/RELOGOHR.png, 492x575) cut from it.
        static void TitleArt(string usa, string doomWad, string mod)
        {
            string wad = Fs.Resolve(doomWad);
            string doom1 = Fs.Resolve(Path.Combine(Path.GetDirectoryName(Path.GetFullPath(wad)), "doom.wad"));
            bool haveDoom1 = File.Exists(doom1) && WadLumps(doom1) != null && WadLumps(doom1).ContainsKey("M_DOOM");
            var logo = DoomPatch(haveDoom1 ? doom1 : wad, "M_DOOM");
            Console.WriteLine(haveDoom1 ? "DOOM logo: from doom.wad" : "DOOM logo: doom.wad not found next to doom2.wad, using DOOM II's logo");

            const int W = 320, H = 240;
            var src = Pix(Path.Combine(usa, "Data/TITLE.PIX"), W, H);
            // the lettering (and its shadow) painted out by filling in from around it
            var red = new bool[W, H];
            var mask = new bool[W, H];
            for (int y = 60; y < 180; y++) for (int x = 0; x < W; x++) red[x, y] = TitleRed(src.GetPixel(x, y));
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                {
                    if (!red[x, y]) continue;
                    for (int dy = -2; dy <= 6; dy++)
                        for (int dx = -2; dx <= 6; dx++)
                        {
                            int px = x + dx, py = y + dy;
                            if (px >= 0 && px < W && py >= 0 && py < H) mask[px, py] = true;
                        }
                }
            var r = new double[W, H]; var gg = new double[W, H]; var bb = new double[W, H];
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                {
                    var c = src.GetPixel(x, y);
                    r[x, y] = c.R; gg[x, y] = c.G; bb[x, y] = c.B;
                    if (mask[x, y]) r[x, y] = gg[x, y] = bb[x, y] = 0;
                }
            for (int it = 0; it < 600; it++)
                for (int y = 1; y < H - 1; y++)
                    for (int x = 1; x < W - 1; x++)
                        if (mask[x, y])
                        {
                            r[x, y] = (r[x - 1, y] + r[x + 1, y] + r[x, y - 1] + r[x, y + 1]) / 4;
                            gg[x, y] = (gg[x - 1, y] + gg[x + 1, y] + gg[x, y - 1] + gg[x, y + 1]) / 4;
                            bb[x, y] = (bb[x - 1, y] + bb[x + 1, y] + bb[x, y - 1] + bb[x, y + 1]) / 4;
                        }
            var bg = new Bitmap(W, H);
            var rnd = new Random(7);
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                {
                    double n = mask[x, y] ? rnd.Next(-6, 7) : 0;   // a little grain so the fill isn't flat
                    bg.SetPixel(x, y, Color.FromArgb(255, Cl(r[x, y] + n), Cl(gg[x, y] + n), Cl(bb[x, y] + n)));
                }
            // RESIDENT: the red letters left of x 214
            int rx0 = W, rx1 = 0, ry0 = H, ry1 = 0;
            for (int y = 0; y < H; y++) for (int x = 0; x < 214; x++) if (red[x, y]) { rx0 = Math.Min(rx0, x); rx1 = Math.Max(rx1, x); ry0 = Math.Min(ry0, y); ry1 = Math.Max(ry1, y); }
            var word = new Bitmap(rx1 - rx0 + 1, ry1 - ry0 + 1);
            for (int y = ry0; y <= ry1; y++) for (int x = rx0; x <= rx1; x++) if (red[x, y]) word.SetPixel(x - rx0, y - ry0, src.GetPixel(x, y));

            // composed at 2x (640x480, square pixels), then squashed to 640x400
            const int S = 2;
            var comp = new Bitmap(W * S, H * S);
            using (var g = Graphics.FromImage(comp))
            {
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g.DrawImage(bg, 0, 0, W * S, H * S);
                // darker towards the bottom, so the logo stands out
                for (int y = H * S / 2; y < H * S; y++)
                {
                    int a = (int)(150 * (y - H * S / 2 + 0.5) / (H * S / 2));
                    g.FillRectangle(new Brush(Color.FromArgb(a, 0, 0, 0)), 0, y, W * S, 1);
                }
                int ww = word.Width * S, wh = word.Height * S, wx = (W * S - ww) / 2, wy = 34 * S;
                g.InterpolationMode = InterpolationMode.NearestNeighbor;
                g.DrawImage(Tint(word, Color.FromArgb(200, 0, 0, 0)), wx + 3 * S, wy + 3 * S, ww, wh);
                g.DrawImage(word, wx, wy, ww, wh);
                // Doom's pixels are 1.2x taller than wide
                double ls = haveDoom1 ? 1.55 : 1.4;   // DOOM II's logo is taller (the II under it)
                int lw = (int)(logo.Width * ls * S), lh = (int)(logo.Height * ls * 1.2 * S);
                int lx = (W * S - lw) / 2, ly = wy + wh + 6 * S;
                g.DrawImage(Tint(logo, Color.FromArgb(170, 0, 0, 0)), lx + 3 * S, ly + 3 * S, lw, lh);
                g.DrawImage(logo, lx, ly, lw, lh);
            }
            var core = comp.Scaled(640, 400, InterpolationMode.HighQualityBicubic);
            const int WW = 1120, HH = 400, cx = (WW - 640) / 2;
            var title = new Bitmap(WW, HH);
            using (var g = Graphics.FromImage(title))
            {
                var small = bg.Scaled(0, 40, 320, 160, 56, 20, InterpolationMode.HighQualityBilinear);
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g.DrawImage(small, -40, -20, WW + 80, HH + 40);
                g.FillRectangle(new Brush(Color.FromArgb(140, 0, 0, 0)), 0, 0, WW, HH);
                g.DrawImage(core, cx, 0, 640, 400);
                for (int i = 0; i < 40; i++)
                {
                    int a = (int)(140 * (1 - i / 40.0) * 0.6);
                    var pen = new Pen(Color.FromArgb(a, 0, 0, 0));
                    g.DrawLine(pen, cx + i, 0, cx + i, HH);
                    g.DrawLine(pen, cx + 640 - 1 - i, 0, cx + 640 - 1 - i, HH);
                }
            }
            string hires = Path.Combine(mod, "hires");
            Directory.CreateDirectory(hires);
            title.Save(Path.Combine(hires, "TITLEPIC.png"));
            Console.WriteLine("Wrote " + Path.Combine(hires, "TITLEPIC.png"));
            MenuLogo(title, logo, mod);
        }

        // The RESIDENT DOOM logo above the menus: RESIDENT cut from the title
        // picture by colour, DOOM 4x below it; always 492x575 (textures.txt).
        static void MenuLogo(Bitmap t, Bitmap doom, string mod)
        {
            var res = new Bitmap(t.Width, t.Height);
            var rowCount = new int[t.Height];
            int lim = (int)(t.Height * 0.47);   // only above the DOOM logo
            for (int y = 0; y < lim; y++)
                for (int x = 0; x < t.Width; x++)
                {
                    var c = t.GetPixel(x, y);
                    int redness = c.R - Math.Max(c.G, c.B);
                    if (redness > 40)
                    {
                        int a = Math.Min(255, (redness - 40) * 255 / 50);
                        res.SetPixel(x, y, Color.FromArgb(a, c.R, c.G, c.B));
                        if (a > 128) rowCount[y]++;
                    }
                }
            int minX = 9999, minY = 9999, maxX = 0, maxY = 0;
            for (int y = 0; y < lim; y++) if (rowCount[y] > 40) { minY = Math.Min(minY, y); maxY = Math.Max(maxY, y); }
            for (int y = minY; y <= maxY; y++) for (int x = 0; x < t.Width; x++) if (res.GetPixel(x, y).A > 128) { minX = Math.Min(minX, x); maxX = Math.Max(maxX, x); }
            if (minY > maxY || minX > maxX) throw new Exception("RESIDENT not found in the title picture");
            // the title picture is shown 4:3 (1120x400 -> 748x561)
            double rw = (maxX - minX + 1) * 0.6679, rh = (maxY - minY + 1) * 1.4025;
            const int DW = 492, DH = 240;   // DOOM at 4x (DOOM's logo is 123x60)
            double k = DW / rw;
            int rH = (int)(rh * k), gap = (int)(DW * 0.025);
            int height = 575;
            var logo = new Bitmap(DW, height);
            var word = res.Scaled(minX, minY, maxX - minX + 1, maxY - minY + 1, DW, Math.Min(rH, height - gap - DH), InterpolationMode.HighQualityBicubic);
            using (var g = Graphics.FromImage(logo))
            {
                g.DrawImage(word, 0, 0);
                g.InterpolationMode = InterpolationMode.NearestNeighbor;
                g.DrawImage(doom, 0, height - DH, DW, DH);
            }
            string outp = Path.Combine(mod, "graphics", "RELOGOHR.png");
            Directory.CreateDirectory(Path.GetDirectoryName(outp));
            logo.Save(outp);
            Console.WriteLine("Wrote " + outp);
        }

        static void Sounds(string usa, string mod)
        {
            string dir = Path.Combine(mod, "sounds", "re1");
            Directory.CreateDirectory(dir);
            foreach (var s in SoundFiles)
                File.WriteAllBytes(Path.Combine(dir, s + ".wav"), Fs.ReadAllBytes(Path.Combine(usa, "Sound/" + s + ".wav")));
            Console.WriteLine("Copied " + SoundFiles.Length + " sounds to " + dir);
        }

        // Level Select pictures: GZDoom's screenshots of each map's start
        // (named LV01.png ... LVRE.png, LVBOSS.png by the capture), scaled to
        // 320x200 into graphics/.
        static void LevelShots(string shots, string mod)
        {
            string g = Path.Combine(mod, "graphics");
            Directory.CreateDirectory(g);
            int n = 0;
            foreach (var f in Directory.GetFiles(shots, "LV*.png"))
            {
                using (var b = new Bitmap(f))
                {
                    // fill 320x200, cutting the sides of a wider screenshot
                    double want = 320.0 / 200, have = (double)b.Width / b.Height;
                    double sw = have > want ? b.Height * want : b.Width, sh = have > want ? b.Height : b.Width / want;
                    b.Scaled((b.Width - sw) / 2, (b.Height - sh) / 2, sw, sh, 320, 200, InterpolationMode.HighQualityBilinear)
                        .Save(Path.Combine(g, Path.GetFileName(f).ToUpperInvariant().Replace(".PNG", ".png")));
                    n++;
                }
            }
            Console.WriteLine("Wrote " + n + " Level Select pictures to " + g);
        }
    }
}
