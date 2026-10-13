// PartnerKneel.cs - the AI partner's kneel for low gaps, from RE1's own
// death fall (the character's EMD animation 4: its first frames are the knees
// giving way, before the fall forward).
//
//   re1convert deathsheet <jill|chris> <RE1 USA> <out.png>
//       every frame of the death fall seen from the side, with its height
//       above the floor and its width (map units), for choosing the kneel

using System;
using System.Collections.Generic;
using RD.Drawing;
using System.Linq;

namespace Re1Convert
{
    static class PartnerKneel
    {
        public const double ToMap = 1.0 / 32.0;   // RE1 units -> map units (Iqm.cs Scale)

        // Height above the floor (map units), and half the width across the body
        // and the reach forward / back of the root (map units).
        public static void Measure(List<Tri> tris, Mat[] pose, double floor, out double height, out double halfWidth, out double fwd, out double back)
        {
            double minY = double.MaxValue, maxSide = 0, maxF = double.MinValue, minF = double.MaxValue;
            double rootX = pose[0].T[0], rootZ = pose[0].T[2];
            foreach (var t in tris)
                for (int c = 0; c < 3; c++)
                {
                    double[] p = pose[t.Joint].Apply(t.V[c]);
                    minY = Math.Min(minY, p[1]);
                    maxSide = Math.Max(maxSide, Math.Abs(p[2] - rootZ));
                    maxF = Math.Max(maxF, p[0] - rootX);
                    minF = Math.Min(minF, p[0] - rootX);
                }
            height = (floor - minY) * ToMap;
            halfWidth = maxSide * ToMap;
            fwd = maxF * ToMap;
            back = -minF * ToMap;
        }

        static double Lowest(List<Tri> tris, Mat[] pose)
        {
            double maxY = double.MinValue;
            foreach (var t in tris) for (int c = 0; c < 3; c++) maxY = Math.Max(maxY, pose[t.Joint].Apply(t.V[c])[1]);
            return maxY;
        }

        public static void DeathSheet(string who, string re1Usa, string outPng)
        {
            var files = Program.Files(who);
            var emd = EmdFile.Read(System.IO.Path.Combine(re1Usa, "Enemy/" + files.Emd));
            var tris = ModelBuilder.Build(emd, null);
            var frames = emd.Anims.TickFrames(4);
            double floor = Lowest(tris, Poser.Pose(emd.Skel, emd.Skel, frames[0]));
            int cols = 8, cw = 200, ch = 260;
            int rows = (frames.Count + cols - 1) / cols;
            using (var bmp = new Bitmap(cols * cw, rows * ch, PixelFormat.Format32bppArgb))
            {
                using (var g = Graphics.FromImage(bmp)) g.Clear(Color.FromArgb(40, 40, 48));
                var r = new SoftRenderer(bmp);
                for (int i = 0; i < frames.Count; i++)
                {
                    var pose = Poser.Pose(emd.Skel, emd.Skel, frames[i]);
                    int ox = (i % cols) * cw + cw / 2, oy = (i / cols) * ch + ch - 20;
                    // the floor line at oy: shift so the standing floor sits there
                    int view = Environment.GetEnvironmentVariable("RE1_VIEW") == "0" ? 0 : 1;
                    r.Draw(tris, pose, emd.Texture, ox - (int)((view == 1 ? pose[0].T[0] : -pose[0].T[2]) * 0.1), oy - (int)(floor * 0.1), 0.1, view);
                    double hgt, half, f, b;
                    Measure(tris, pose, floor, out hgt, out half, out f, out b);
                    using (var g = Graphics.FromImage(bmp))
                    {
                        var font = new Font("Arial", 9);
                        g.DrawLine(Pens.Gray, (i % cols) * cw, oy, (i % cols) * cw + cw, oy);
                        g.DrawString(string.Format("{0}: h {1:0} w {2:0} f {3:0}/{4:0}", i, hgt, half * 2, f, b), font, Brushes.Yellow, (i % cols) * cw + 2, (i / cols) * ch + 2);
                    }
                    Console.WriteLine("frame {0}: height {1:0.0}, width {2:0.0}, forward {3:0.0}, back {4:0.0}", i, hgt, half * 2, f, b);
                }
                bmp.Save(outPng, ImageFormat.Png);
            }
            Console.WriteLine("Wrote " + outPng);
        }
    }
}
