// StatusArt.cs - RE1's status screen and item box art, from the player's own
// RE1 files, for the "RE1 Classic" inventory style (RE_InvClassic.zs).
//
//   re1convert timdump <file.tim> <out folder>     every palette of a TIM as a PNG (for looking)

using System;
using System.Collections.Generic;
using RD.Drawing;
using System.IO;
using System.Linq;
using System.Text;

namespace Re1Convert
{
    static class StatusArt
    {
        // A TIM drawn with palette row 'pal' (16-bit TIMs ignore it).
        public static Bitmap TimBitmap(Tim t, int pal, bool see0 = true)
        {
            var bmp = new Bitmap(t.Width, t.Height, PixelFormat.Format32bppArgb);
            for (int y = 0; y < t.Height; y++)
                for (int x = 0; x < t.Width; x++)
                {
                    ushort c;
                    if (t.Bpp == 16) c = (ushort)(t.Pixels[(y * t.Width + x) * 2] | (t.Pixels[(y * t.Width + x) * 2 + 1] << 8));
                    else c = t.Clut[Math.Min(pal, t.ClutH - 1) * t.ClutW + t.Index(x, y)];
                    byte r, g, b, a;
                    Tim.ToRgba(c, out r, out g, out b, out a);
                    if (!see0) a = 255;
                    bmp.SetPixel(x, y, Color.FromArgb(a, r, g, b));
                }
            return bmp;
        }

        // --- "re1convert statusart <RE1 USA> <mod>" ---------------------------------
        // Writes mod/graphics/re1status/:
        //   RESTATUS.png  STATUS.TIM (palette 0): tabs, command buttons, condition
        //                 words, digits, cursors, frame pieces - drawn by the game
        //                 piece by piece with the same source rectangles RE1 uses
        //   REGIVE.png    a GIVE button for the partner (RE1 has none), put together
        //                 from STATUS.TIM's own command buttons (GiveButton)
        //   REFACE.png    Statface.tim (the portraits, 30x30 each)
        //   REBLUE.png    BLUE.TIM (an empty slot)
        //   REITEMS.png   ITEM_ALL.PIX: every 40x30 item picture, one under another
        //   REFONT.png    fontus.tim (RE1's 8x8 text font, rows from ' ')
        //   REBOXART.png  ITEMBOXn.TIM (the item box screen's frame)
        //   STFRAMEJ.png / STFRAMEC.png  the status screen's whole frame on RE1's
        //                 320x240 screen, put together the way RE1's
        //                 menu_draw_inventory does (decomp MainMenu.cpp, with its
        //                 table g_MenuFrameDataBlock from MenuData.cpp): Jill's
        //                 8-slot border, Chris's 6-slot border
        public static void Export(string usa, string modDir, string sheet = null)
        {
            string data = Path.Combine(usa, "Data");
            string outDir = Path.Combine(modDir, "graphics", "re1status");
            Directory.CreateDirectory(outDir);
            var status = Tim.Read(Fs.ReadAllBytes(Path.Combine(data, "STATUS.TIM")), 0);
            var face = Tim.Read(Fs.ReadAllBytes(Path.Combine(data, "Statface.tim")), 0);
            var blue = Tim.Read(Fs.ReadAllBytes(Path.Combine(data, "BLUE.TIM")), 0);
            var font = Tim.Read(Fs.ReadAllBytes(Path.Combine(data, "fontus.tim")), 0);
            var box = Tim.Read(Fs.ReadAllBytes(Path.Combine(data, "ITEMBOXn.TIM")), 0);
            using (var b = TimBitmap(status, 0))
            {
                b.Save(Path.Combine(outDir, "RESTATUS.png"), ImageFormat.Png);
                using (var give = GiveButton(b)) give.Save(Path.Combine(outDir, "REGIVE.png"), ImageFormat.Png);
            }
            using (var b = TimBitmap(face, 0)) b.Save(Path.Combine(outDir, "REFACE.png"), ImageFormat.Png);
            using (var b = TimBitmap(blue, 0, false)) b.Save(Path.Combine(outDir, "REBLUE.png"), ImageFormat.Png);
            using (var b = TimBitmap(box, 0)) b.Save(Path.Combine(outDir, "REBOXART.png"), ImageFormat.Png);
            // the font: white on see-through (colour 0 is the background)
            using (var b = TimBitmap(font, 0)) b.Save(Path.Combine(outDir, "REFONT.png"), ImageFormat.Png);
            // the item pictures
            int icons = (int)(new FileInfo(Fs.Resolve(Path.Combine(data, "ITEM_ALL.PIX"))).Length / 1200);
            using (var b = new Bitmap(40, 30 * icons, PixelFormat.Format32bppArgb))
            {
                for (int r = 0; r < icons; r++)
                {
                    var ic = Prop.ItemIconPublic(usa, r);
                    for (int y = 0; y < 30; y++) for (int x = 0; x < 40; x++) b.SetPixel(x, r * 30 + y, ic[x, y]);
                }
                b.Save(Path.Combine(outDir, "REITEMS.png"), ImageFormat.Png);
            }
            using (var j = Frame(status, true)) j.Save(Path.Combine(outDir, "STFRAMEJ.png"), ImageFormat.Png);
            using (var c = Frame(status, false)) c.Save(Path.Combine(outDir, "STFRAMEC.png"), ImageFormat.Png);
            WriteIconTable(usa, modDir, icons);
            Console.WriteLine("Wrote {0} ({1} item pictures)", outDir, icons);
        }

        // Which ITEM_ALL.PIX picture each RE1 item id uses: byte 0 of its
        // g_ItemImageLookupTable record (picture number + 1), read from the
        // player's own ResidentEvil.exe (found by the table's first records).
        // Written to mod/re1status.txt as "icon <item id> <picture row>".
        static void WriteIconTable(string usa, string modDir, int icons)
        {
            string exe = Path.Combine(Path.GetDirectoryName(usa.TrimEnd('\\', '/')), "ResidentEvil.exe");
            if (!Fs.Exists(exe)) exe = Path.Combine(usa, "ResidentEvil.exe");
            byte[] b = Fs.ReadAllBytes(exe);
            byte[] pat = { 0x00, 0x00, 0x00, 0x00, 0x01, 0x80, 0x80, 0x0F, 0x02, 0x00, 0x80, 0x07, 0x03, 0x01, 0x80, 0x06 };
            int at = -1;
            for (int i = 0; i + pat.Length < b.Length && at < 0; i++)
            {
                int k = 0;
                while (k < pat.Length && b[i + k] == pat[k]) k++;
                if (k == pat.Length) at = i;
            }
            if (at < 0) throw new Exception("item picture table not found in " + exe);
            var sb = new StringBuilder();
            sb.AppendLine("// Written by \"re1convert statusart\" from your ResidentEvil.exe (RE1's item picture table):");
            sb.AppendLine("// icon <RE1 item id> <ITEM_ALL.PIX picture row>");
            for (int id = 1; id < 0x4d; id++)
            {
                int row = b[at + id * 4] - 1;
                if (row >= 0 && row < icons) sb.AppendLine(string.Format("icon {0} {1}", id, row));
            }
            File.WriteAllText(Path.Combine(modDir, "re1status.txt"), sb.ToString());
        }

        // RE1's frame data block (MenuData.cpp g_MenuFrameDataBlock, original 0x004c26d0), read
        // backwards from labels inside it, exactly as menu_draw_inventory does.
        static readonly byte[] Block = {
            0x08,0x00,0x0c,0x00,0x08,0x00,0x08,0x00,0x50,0x00,0x78,0x00, 0x08,0x00,0x84,0x00,0x08,0x00,0x08,0x00,0x58,0x00,0x78,0x00,
            0xC0,0x00,0x0C,0x00,0x08,0x00,0x08,0x00,0x60,0x00,0x70,0x00, 0xC0,0x00,0x84,0x00,0x08,0x00,0x08,0x00,0x60,0x00,0x78,0x00,
            0x10,0x00,0x0C,0x00,0x10,0x00,0x08,0x00,0x30,0x00,0x78,0x00, 0x10,0x00,0x84,0x00,0x10,0x00,0x08,0x00,0x40,0x00,0x78,0x00,
            0x08,0x00,0x14,0x00,0x18,0x00,0x70,0x00,0x98,0x00,0x00,0x00, 0xC0,0x00,0x14,0x00,0x08,0x00,0x70,0x00,0xB0,0x00,0x00,0x00,
            0x20,0x00,0x0C,0x00,0xA0,0x00,0x0C,0x00,0x00,0x00,0x98,0x00, 0x08,0x00,0x8C,0x00,0x80,0x00,0x28,0x00,0x00,0x00,0xB8,0x00,
            0x94,0x00,0x8E,0x00,0x3C,0x00,0x26,0x00,0x84,0x00,0xBA,0x00, 0xCC,0x00,0x0C,0x00,0x68,0x00,0x04,0x00,0x00,0x00,0x80,0x00,
            0xCC,0x00,0x30,0x00,0x68,0x00,0x04,0x00,0x00,0x00,0x84,0x00, 0xD0,0x00,0x92,0x00,0x08,0x00,0x1E,0x00,0xB8,0x00,0x2E,0x00,
            0xD8,0x00,0xB0,0x00,0x04,0x00,0x08,0x00,0x68,0x00,0x80,0x00, 0x2C,0x01,0xB0,0x00,0x04,0x00,0x08,0x00,0x7C,0x00,0x80,0x00,
            0xD0,0x00,0xB0,0x00,0x08,0x00,0x08,0x00,0x88,0x00,0x50,0x00, 0x30,0x01,0xB0,0x00,0x08,0x00,0x08,0x00,0x90,0x00,0x50,0x00,
            0x00,0x00,0xB6,0x00,0xC0,0x00,0x02,0x00,0x00,0x00,0xA6,0x00, 0xC0,0x00,0xB6,0x00,0x80,0x00,0x02,0x00,0x00,0x00,0xA6,0x00,
            0x00,0x00,0xD8,0x00,0x78,0x00,0x10,0x00,0x00,0x00,0x88,0x00, 0x78,0x00,0xD8,0x00,0xC8,0x00,0x10,0x00,0x00,0x00,0xA8,0x00,
            // 264: g_MainMenuFrames2Pos (here: the four tab buttons)
            0xd0,0x00,0x10,0x00,0x30,0x00,0x10,0x00,0x00,0x00,0x00,0x00, 0x00,0x01,0x10,0x00,0x30,0x00,0x10,0x00,0x00,0x00,0x20,0x00,
            0xd0,0x00,0x20,0x00,0x30,0x00,0x10,0x00,0x00,0x00,0x10,0x00, 0x00,0x01,0x20,0x00,0x30,0x00,0x10,0x00,0x00,0x00,0x30,0x00,
            // 312: g_MainMenuTopOptionsPos
            0x20,0x00,0x80,0x00, 0xa0,0x00,0x0c,0x00, 0x00,0x00,0x98,0x00, 0x40,0x01,0xcc,0x00, 0x10,0x00,0x04,0x00, 0x10,0x00,0x78,0x00,
            0x88,0x00,0x00,0x82, 0x30,0x01,0x10,0x00, 0x04,0x00,0x10,0x00, 0x7c,0x00,0x88,0x00, 0x00,0x82,0xdc,0x00, 0xb0,0x00,0x10,0x00,
            0x08,0x00,0x6c,0x00, 0x80,0x00, 0x00,0x05,
            // 368: g_MainMenuFrames3Pos (Chris's 6-slot border)
            0xd0,0x00,0x4e,0x00, 0x08,0x00,0x08,0x00, 0x60,0x00,0x58,0x00, 0x00,0x01,0xd8,0x00, 0x4e,0x00,0x04,0x00, 0x08,0x00,0x68,0x00,
            0x58,0x00,0x00,0x01, 0xdc,0x00,0x4e,0x00, 0x10,0x00,0x08,0x00, 0x6c,0x00,0x58,0x00, 0x00,0x05,0x2c,0x01, 0x4e,0x00,0x04,0x00,
            0x08,0x00,0x7c,0x00, 0x58,0x00,0x00,0x01, 0x30,0x01,0x4e,0x00, 0x08,0x00,0x08,0x00, 0x80,0x00,0x50,0x00, 0x00,0x01,0xd0,0x00,
            0x56,0x00,0x08,0x00, 0x0f,0x00,0xb8,0x00, 0x28,0x00,0x00,0x84, 0xd8,0x00,0x56,0x00, 0x04,0x00,0x1e,0x00, 0x68,0x00,0x60,0x00,
            0x00,0x83,0x2c,0x01, 0x56,0x00,0x04,0x00, 0x1e,0x00,0x7c,0x00, 0x60,0x00,0x00,0x83, 0x30,0x01,0x56,0x00, 0x08,0x00,0x0f,0x00,
            0x60,0x00, 0x60,0x00, 0x00,0x86,0x00,0x00,
            // 496: g_MainMenuFrames4Pos (Jill's 8-slot border)
            0xd0,0x00,0x30,0x00, 0x08,0x00,0x08,0x00, 0x60,0x00,0x58,0x00, 0x00,0x01,0xd8,0x00, 0x30,0x00,0x04,0x00, 0x08,0x00,0x68,0x00,
            0x58,0x00,0x00,0x01, 0xdc,0x00,0x30,0x00, 0x10,0x00,0x08,0x00, 0x6c,0x00,0x58,0x00, 0x00,0x05,0x2c,0x01, 0x30,0x00,0x04,0x00,
            0x08,0x00,0x7c,0x00, 0x58,0x00,0x00,0x01, 0x30,0x01,0x30,0x00, 0x08,0x00,0x08,0x00, 0x80,0x00,0x50,0x00, 0x00,0x01,0xd0,0x00,
            0x38,0x00,0x08,0x00, 0x0f,0x00,0xb8,0x00, 0x28,0x00,0x00,0x86, 0xd8,0x00,0x38,0x00, 0x04,0x00,0x1e,0x00, 0x68,0x00,0x60,0x00,
            0x00,0x84,0x2c,0x01, 0x38,0x00,0x04,0x00, 0x1e,0x00,0x7c,0x00, 0x60,0x00,0x00,0x84, 0x30,0x01,0x38,0x00, 0x08,0x00,0x0f,0x00,
            0x60,0x00,0x60,0x00, 0x00,0x88,0x00,0x00,
            // 624: DAT_004c2940 (the black background rectangles)
            0x00,0x00,0x00,0x00,0x40,0x01,0x0c,0x00, 0x00,0x00,0x0c,0x00,0x09,0x00,0x80,0x00,
            0xc7,0x00,0x0c,0x00,0x79,0x00,0x80,0x00, 0x00,0x00,0x8c,0x00,0x40,0x01,0x64,0x00,
        };

        class Piece { public int X, Y, W, H, U, V, Depth, Order; public bool FlipX, FlipY; public bool Rect; }

        static int S16(int at) { return (short)(Block[at] | (Block[at + 1] << 8)); }

        // One frame part record ending at 'end' (load_main_menu_frame_part_tex_area).
        static Piece Load(int end)
        {
            return new Piece { X = S16(end - 12), Y = S16(end - 10), W = S16(end - 8), H = S16(end - 6), U = Block[end - 4], V = Block[end - 2] };
        }

        static Bitmap Frame(Tim status, bool jill)
        {
            var parts = new List<Piece>();
            int order = 0;
            Action<Piece, int> add = (p, d) => { p.Depth = d; p.Order = order++; parts.Add(p); };
            // the frame parts below the tab buttons, drawn at depth 21
            for (int end = 264; end > 0; end -= 12) add(Load(end), 0x15);
            // tiled border runs: 12-byte part + flags byte + count byte (bit 7: down, not across)
            Action<int, int, int> runs = (from, to, depthBase) =>
            {
                for (int end = from; end > to; end -= 14)
                {
                    int flags = Block[end - 2], count = Block[end - 1];
                    var p0 = Load(end - 2);
                    bool down = (count & 0x80) != 0;
                    count &= 0x7f;
                    for (int k = 0; k < count; k++)
                    {
                        var p = new Piece { X = p0.X + (down ? 0 : k * p0.W), Y = p0.Y + (down ? k * p0.H : 0), W = p0.W, H = p0.H, U = p0.U, V = p0.V,
                            FlipX = (flags & 0x40) != 0, FlipY = (flags & 0x80) != 0 };
                        add(p, depthBase < 0 ? -depthBase : count - k + depthBase);
                    }
                }
            };
            runs(368, 312, 10);                       // the main frame's bottom, tab sides
            runs(jill ? 496 + 126 : 368 + 126, jill ? 496 : 368, -0x14);   // the item panel's border
            // the black background
            for (int end = 656; end > 624; end -= 8)
                add(new Piece { X = S16(end - 8), Y = S16(end - 6), W = S16(end - 4), H = S16(end - 2), Rect = true }, 0x1e);
            // the PlayStation draws the ordering table from the highest depth down; within one depth
            // the part added last is drawn first
            var draw = parts.OrderByDescending(p => p.Depth).ThenByDescending(p => p.Order).ToList();
            using (var src = TimBitmap(status, 0))
            {
                var bmp = new Bitmap(320, 240, PixelFormat.Format32bppArgb);
                using (var g = Graphics.FromImage(bmp)) g.Clear(Color.Transparent);
                foreach (var p in draw)
                    for (int y = 0; y < p.H; y++)
                        for (int x = 0; x < p.W; x++)
                        {
                            int sx = p.X + x, sy = p.Y + y;
                            if (sx < 0 || sy < 0 || sx >= 320 || sy >= 240) continue;
                            if (p.Rect) { bmp.SetPixel(sx, sy, Color.Black); continue; }
                            int u = p.U + (p.FlipX ? p.W - 1 - x : x), v = p.V + (p.FlipY ? p.H - 1 - y : y);
                            if (u > 255 || v > 255) continue;
                            var c = src.GetPixel(u, v);
                            if (c.A != 0) bmp.SetPixel(sx, sy, c);
                        }
                return bmp;
            }
        }

        // A GIVE button in the style of RE1's EQUIP / USE / CHECK / COMBN (48x24 each,
        // at u 48, v 0 / 24 / 48 / 72 in STATUS.TIM), made only from their pixels:
        //   - the blue background: at each pixel, a button that shows background
        //     there (no letter), or the mirrored pixel (the buttons are symmetric)
        //   - G: CHECK's C, with the inner bar and the lower right stroke from its H
        //   - I: EQUIP's I;  E: CHECK's E
        //   - V: USE's U strokes, drawn closer together row by row down to a point
        static Bitmap GiveButton(Bitmap s)
        {
            const int EQUIP = 0, USE = 1, CHECK = 2;
            Func<int, int, int, Color> px = (b, x, y) => s.GetPixel(48 + x, b * 24 + y);
            Func<Color, bool> back = c => c.A != 0 && c.B > c.R + 40;   // the blue, not a letter
            var bmp = new Bitmap(48, 24, PixelFormat.Format32bppArgb);
            int[] order = { USE, EQUIP, CHECK, 3 };
            for (int y = 0; y < 24; y++)
                for (int x = 0; x < 48; x++)
                {
                    Color c = px(USE, x, y);
                    bool found = !(y >= 4 && y < 20) || back(c);
                    foreach (int b in order) if (!found && back(px(b, x, y))) { c = px(b, x, y); found = true; }
                    foreach (int b in order) if (!found && back(px(b, 47 - x, y))) { c = px(b, 47 - x, y); found = true; }
                    // else the nearest background pixel in the same row
                    for (int d = 1; d < 24 && !found; d++)
                        foreach (int b in order)
                            foreach (int xx in new[] { x - d, x + d })
                                if (!found && xx >= 0 && xx < 48 && back(px(b, xx, y))) { c = px(b, xx, y); found = true; }
                    bmp.SetPixel(x, y, c);
                }
            // copies a letter's pixels (not its background) from button b
            Action<int, int, int, int, int, int> glyph = (b, sx, sy, w, h, dx) =>
            {
                for (int j = 0; j < h; j++)
                    for (int i = 0; i < w; i++)
                    {
                        var c = px(b, sx + i, sy + j);
                        if (!back(c)) bmp.SetPixel(dx + i, sy + j, c);
                    }
            };
            // G at x 9..15
            glyph(CHECK, 4, 6, 7, 14, 9);
            glyph(CHECK, 15, 12, 4, 1, 12);   // the inner bar (H's crossbar)
            glyph(CHECK, 17, 13, 2, 3, 14);   // down to the C's lower end (H's right stroke)
            // I at x 18..19
            glyph(EQUIP, 32, 6, 2, 14, 18);
            // V at x 22..30: U's left stroke (x 8..10) and right stroke (x 14..16), 3 px in at the bottom
            int[] inset = { 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 3, 3 };   // rows 6..18
            for (int y = 6; y < 19; y++)
            {
                int k = inset[y - 6];
                for (int i = 0; i < 3; i++)
                {
                    var l = px(USE, 8 + i, 9);
                    var r = px(USE, 14 + i, 9);
                    if (!back(l) && (i < 2 || k == 0)) bmp.SetPixel(22 + k + i, y, l);   // (its shadow only where the arms are apart)
                    if (!back(r)) bmp.SetPixel(28 - k + i, y, r);
                }
            }
            for (int i = 0; i < 5; i++) { var c = px(USE, 10 + i, 19); if (!back(c)) bmp.SetPixel(24 + i, 19, c); }   // its bottom shading
            // E at x 32..37
            glyph(CHECK, 21, 6, 6, 14, 32);
            return bmp;
        }

        public static void Dump(string file, string outDir)
        {
            Directory.CreateDirectory(outDir);
            var t = Tim.Read(Fs.ReadAllBytes(file), 0);
            Console.WriteLine("{0}: {1}x{2} {3}bpp, clut {4}x{5} at ({6},{7}), image at ({8},{9})",
                Path.GetFileName(file), t.Width, t.Height, t.Bpp, t.ClutW, t.ClutH, t.ClutX, t.ClutY, t.ImgX, t.ImgY);
            int pals = t.Bpp == 16 ? 1 : t.ClutH;
            for (int p = 0; p < pals; p++)
                using (var b = TimBitmap(t, p, false))
                    b.Save(Path.Combine(outDir, Path.GetFileNameWithoutExtension(file) + "_p" + p + ".png"), ImageFormat.Png);
        }
    }
}
