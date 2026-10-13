// CastSprites.cs - "re1convert castsprites <RE1 USA folder> <mod folder>":
// Jill and Chris for Doom II's ending cast call (RE_Cast.zs), which can only
// draw flat sprite pictures, not models. Each picture is the character's RE1
// model (body + the Beretta in hand, the same mesh as the game's), posed with
// RE1's own animations and seen from the front, drawn by SoftRenderer:
//   walk   - the Beretta walk (weapon file motion 2), 8 frames of one cycle
//   attack - raise (motion 5, 4 frames), aim (motion 7, 1), fire (motion 6, 3)
//   death  - the death (body motion 4, as in the game), 16 frames, last = on the floor
//            (Chris turns towards his side as he falls: his fall is straight forward)
// Drawn at 4x and scaled back down by textures.cast.txt (XScale / YScale 4), so
// they stand as tall as the game models (0.0249 map units per RE1 unit) next
// to the monsters; the offset puts the feet on the origin.
// Writes graphics/cast/<sprite>.png, textures.cast.txt and, given a third
// argument, a contact sheet of all frames there (for checking).

using System;
using System.Collections.Generic;
using RD.Drawing;
using System.IO;
using System.Linq;
using System.Text;

namespace Re1Convert
{
    static class CastSprites
    {
        const double Scale = 0.0249 * 4;   // pixels per RE1 unit at 4x
        const int W = 360, H = 320;        // picture size (4x)
        const int OX = W / 2, OY = H - 12; // where the feet stand

        class Pose1 { public Skeleton Frames; public int Stored; public double DZ; public double Yaw; }

        public static void Export(string usa, string modDir, string sheetPath = null)
        {
            string outDir = Path.Combine(modDir, "graphics", "cast");
            Directory.CreateDirectory(outDir);
            var tex = new StringBuilder();
            tex.AppendLine("// Jill and Chris for the ending cast call (RE_Cast.zs), written by");
            tex.AppendLine("// \"re1convert castsprites\": pictures drawn at 4x from the RE1 models, shown at");
            tex.AppendLine("// the game models' size. The offset is the feet.");
            var sheetRows = new List<List<Bitmap>>();

            foreach (var who in new[] { "jill", "chris" })
            {
                var files = Program.Files(who);
                var emd = EmdFile.Read(Path.Combine(usa, "Enemy/" + files.Emd));
                var emw = EmwFile.Read(Path.Combine(usa, "Players/" + files.Weapons[2] + ".EMW"));   // the Beretta
                var tris = ModelBuilder.Build(emd, emw.WeaponArm);
                string p = who == "jill" ? "J" : "C";

                var walk = Pick(emw.Skel, emw.Anims.TickFrames(2), 8, false, true);
                var attack = new List<Pose1>();
                attack.AddRange(Pick(emw.Skel, emw.Anims.TickFrames(5), 4, true, true));
                attack.AddRange(Pick(emw.Skel, emw.Anims.TickFrames(7), 1, true, true));
                var fire = emw.Anims.TickFrames(6);
                foreach (int k in new[] { 0, fire.Count / 6, fire.Count / 3 }) attack.Add(new Pose1 { Frames = emw.Skel, Stored = fire[Math.Min(k, fire.Count - 1)] });
                CenterAll(attack, emd.Skel);
                var death = Pick(emd.Skel, emd.Anims.TickFrames(4), 16, true, false);
                // the death keeps its own sideways movement, measured from its first frame
                double dz0 = RootZ(emd.Skel, death[0]);
                foreach (var d in death) d.DZ = dz0;
                // Chris falls forward, straight at the viewer, which a front view can't show:
                // he turns towards his side as he goes down, so the fall crosses the screen
                if (who == "chris") for (int i = 0; i < death.Count; i++) death[i].Yaw = 75.0 * Math.Min(1.0, i / 5.0);

                var row = new List<Bitmap>();
                Write(tex, outDir, p + "CWK", walk, emd, tris, row);
                Write(tex, outDir, p + "CAT", attack, emd, tris, row);
                Write(tex, outDir, p + "CDE", death, emd, tris, row);
                sheetRows.Add(row);
            }
            File.WriteAllText(Path.Combine(modDir, "textures.cast.txt"), tex.ToString());

            // a contact sheet of every frame (half size)
            int cols = sheetRows.Max(r => r.Count);
            using (var sheet = new Bitmap(cols * W / 2, sheetRows.Count * H / 2))
            {
                using (var g = Graphics.FromImage(sheet))
                {
                    g.Clear(Color.FromArgb(255, 70, 70, 70));
                    for (int r = 0; r < sheetRows.Count; r++)
                        for (int c = 0; c < sheetRows[r].Count; c++)
                        {
                            g.DrawImage(sheetRows[r][c], c * W / 2, r * H / 2, W / 2, H / 2);
                            g.DrawLine(Pens.Red, c * W / 2, r * H / 2 + OY / 2, (c + 1) * W / 2, r * H / 2 + OY / 2);
                        }
                }
                if (sheetPath != null) sheet.Save(sheetPath, ImageFormat.Png);
            }
            Console.WriteLine("Wrote " + outDir + ", textures.cast.txt and castsheet.png");
        }

        // n frames spread over an animation (the last one included if 'toEnd');
        // 'inPlace': the sideways root movement taken out frame by frame.
        static List<Pose1> Pick(Skeleton frames, List<int> ticks, int n, bool toEnd, bool inPlace)
        {
            var o = new List<Pose1>();
            for (int i = 0; i < n; i++)
            {
                int k = n == 1 ? 0 : (toEnd ? (int)Math.Round(i * (ticks.Count - 1) / (double)(n - 1)) : i * ticks.Count / n);
                var p = new Pose1 { Frames = frames, Stored = ticks[Math.Min(k, ticks.Count - 1)] };
                if (inPlace) p.DZ = double.NaN;   // per frame (Write)
                o.Add(p);
            }
            return o;
        }

        static void CenterAll(List<Pose1> poses, Skeleton bones) { foreach (var p in poses) p.DZ = double.NaN; }

        static double RootZ(Skeleton bones, Pose1 p)
        {
            short[] root; short[,] rot;
            p.Frames.GetFrame(p.Stored, out root, out rot);
            return root[2];
        }

        static void Write(StringBuilder tex, string outDir, string sprite, List<Pose1> poses, EmdFile emd, List<Tri> tris, List<Bitmap> row)
        {
            for (int i = 0; i < poses.Count; i++)
            {
                var p = poses[i];
                var pose = Poser.Pose(emd.Skel, p.Frames, p.Stored);
                double dz = double.IsNaN(p.DZ) ? pose[0].T[2] : p.DZ;
                foreach (var m in pose) m.T[2] -= dz;   // no sideways drift (front view: z is across)
                var bmp = new Bitmap(W, H, PixelFormat.Format32bppArgb);
                using (var g = Graphics.FromImage(bmp)) g.Clear(Color.Transparent);
                if (p.Yaw == 0) new SoftRenderer(bmp).Draw(tris, pose, emd.Texture, OX, OY, Scale, 0);
                else new SoftRenderer(bmp).DrawTurned(tris, pose, emd.Texture, OX, OY, Scale, -p.Yaw);
                string name = sprite + (char)('A' + i) + "0";
                bmp.Save(Path.Combine(outDir, name + ".png"), ImageFormat.Png);
                tex.AppendLine(string.Format("Sprite \"{0}\", {1}, {2} {{ XScale 4 YScale 4 Offset {3}, {4} Patch \"graphics/cast/{0}.png\", 0, 0 }}", name, W, H, OX, OY));
                row.Add(bmp);
            }
        }
    }
}
