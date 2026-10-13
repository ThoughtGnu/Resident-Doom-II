// ViewArms.cs - "re1convert viewarms": a character's two arms and one
// weapon, seen from their eyes, for the first-person view.
//
//   re1convert viewarms <RE1 USA folder> <mod folder> <jill|chris> <weapon>
//                       <sprite prefix> <weapon class>
//                       [lowered nudge: forward left up] [aimed nudge: forward left up]
//                       [--pose-from <jill|chris>] [--point-forward]
//
// --point-forward (the flamethrower, held at the hip in RE1, which from her
// eyes points up and away and drops out of view while raising): the weapon
// keeps its aimed grip for the whole raise, turned so the barrel points at
// the crosshair, and slides and tilts up smoothly from the lower right - the
// same slide from the lowered spot to the aimed spot the other weapons use.
// The nozzle tip's place is written to the layout (muzzle f l u), so the game
// can start the flame there.
//
// <weapon> is knife, beretta, shotgun, magnum, grenade or rocket; the EMW
// file comes from the character's weapon table (Program.Files).
//
// Model frames, in this order, all RE1's own animations from the EMW:
//   lowered  1 frame   her idle pose (motion 1): weapon down at her side
//   raise    n frames  motion 5, one per 30 Hz tick
//   hold     1 frame   gun motion 7 / knife motion 9: weapon raised
//   fire     n frames  motion 6 (shot with recoil, shotgun pump, knife slash)
// The view position slides from the "lowered" spot to the "aimed" spot during
// the raise, so the weapon comes up into view from the lower right.
//
// Writes, into <mod folder>:
//   models/<char>/arm_<char>_<weapon>.md3   the model (Md3.cs)
//   models/<char>/arm_<char>_<weapon>.txt   the frame layout, read by the game (REWeapon)
//   models/<char>/arm_<char>_<weapon>.mdl   MODELDEF block (modeldef.txt #includes it)
//   sprites/viewarms/<prefix>*   invisible 1x1 pictures: GZDoom needs a sprite
//                                picture for every frame a model replaces
//
// To add another RE weapon: run this with its EMW, add the #include line to
// modeldef.txt and a small REGun subclass in RE_Items.zs.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;

namespace Re1Convert
{
    static class ViewArms
    {
        // RE1 joints: 9-11 left arm, 12-14 right arm (14 = hand with weapon), 1 = head.
        // Forearms and hands only: the upper arms would fill the screen.
        static readonly int[] ArmJoints = { 10, 11, 13, 14 };
        const int HeadJoint = 1, HandJoint = 14, LeftHand = 11;
        const double GripDistance = 160;   // RE1 units from her left hand to the weapon
        const double LowNear = 16, LowSide = 11, LowAngle = 16, AimNear = 8;
        // Knife: where her hand goes (forward, left, up from her eyes), and
        // which way the blade points (forward, toward the middle, up).
        static readonly double[] KnifeAimAt = { 15, -9, -10 }, KnifeLowAt = { 14, -10, -13 };
        static readonly double[] KnifeBlade = { 1, 0.04, 0.12 };   // perspective already leans it toward the middle
        const double HangDrop = 250;       // RE1 units the hand hangs below the elbow
        const double PointDistance = 500;  // --point-forward: map units to the point the barrel aims at
        const double LowTilt = 22;         // --point-forward: degrees the barrel tips down while lowered

        public static void Run(string[] a)
        {
            // --pose-from <char>: pose the arms with another character's weapon
            // animations (same skeleton), keeping this character's own meshes.
            bool pointForward = Array.IndexOf(a, "--point-forward") >= 0;
            a = a.Where(s => s != "--point-forward").ToArray();
            string poseFrom = null;
            int pf = Array.IndexOf(a, "--pose-from");
            if (pf >= 0 && pf + 1 < a.Length)
            {
                poseFrom = a[pf + 1];
                a = a.Take(pf).Concat(a.Skip(pf + 2)).ToArray();
            }
            if (a.Length < 7) throw new Exception("viewarms needs at least 6 arguments (see usage)");
            string usa = a[1], mod = a[2], who = a[3], weapon = a[4], prefix = a[5].ToUpperInvariant(), cls = a[6];
            var files = Program.Files(who);
            int wi = Array.IndexOf(Program.WeaponNames, weapon);
            if (wi < 1 || wi >= files.Weapons.Length) throw new Exception("weapon must be one of: knife, beretta, shotgun, magnum, grenade, rocket (and flame for Chris)");
            string emwName = files.Weapons[wi] + ".EMW", name = who + "_" + weapon;
            bool knife = weapon == "knife";
            if (prefix.Length != 3) throw new Exception("sprite prefix must be 3 letters (a digit is added)");
            Func<int, double> D = i => double.Parse(a[i], CultureInfo.InvariantCulture);
            // Placement (map units from her eyes: forward, left, up). Aimed, the
            // weapon hand goes to aimAt. Lowered, the weapon's nearest point is
            // LowNear ahead, its middle LowSide to the right, and its top edge
            // shows LowAngle degrees below the middle of the screen. The
            // optional numbers nudge it from there.
            double[] aimAt = { 18, -6, -8 };
            double[] lowNudge = a.Length > 9 ? new[] { D(7), D(8), D(9) } : new double[3];
            double[] aimNudge = a.Length > 12 ? new[] { D(10), D(11), D(12) } : new double[3];

            var emd = EmdFile.Read(Path.Combine(usa, "Enemy/" + files.Emd));
            var emw = EmwFile.Read(Path.Combine(usa, "Players/" + emwName));
            if (emw.WeaponArm == null) throw new Exception(emwName + " has no weapon mesh");
            var tris = ModelBuilder.Build(emd, emw.WeaponArm).Where(t => ArmJoints.Contains(t.Joint)).ToList();
            // From here on emw is only where the poses come from.
            if (poseFrom != null)
                emw = EmwFile.Read(Path.Combine(usa, "Players/" + Program.Files(poseFrom).Weapons[wi] + ".EMW"));

            var lowered = emw.Anims.TickFrames(1)[0];
            var raise = emw.Anims.TickFrames(5);
            var hold = emw.Anims.TickFrames(knife ? 9 : 7)[0];
            var fire = emw.Anims.TickFrames(Program.FireAnim(wi, 0));   // the flamethrower: its flame loop (14)

            // The knife: RE1 holds it reverse-grip (blade down and back), which
            // from her eyes points at the camera. In first person she holds it
            // forward instead: the knife is turned inside her hand so that, in
            // the ready pose, the blade points into the screen and a little
            // toward the middle. The turn is in the hand's own frame, so it
            // follows RE1's slash. Lowered and raising use the ready pose too.
            if (pointForward)
            {
                lowered = hold;
                for (int i = 0; i < raise.Count; i++) raise[i] = hold;
            }
            if (knife)
            {
                TurnKnifeForward(emd, emw, tris, hold);
                lowered = hold;
                for (int i = 0; i < raise.Count; i++) raise[i] = hold;
            }
            // Her eyes, from the raised pose; the view looks along her facing (RE1 +X).
            double[] eye = Poser.Pose(emd.Skel, emw.Skel, hold)[HeadJoint].Apply(new short[] { 40, -110, 0 });

            Func<int, double[]> Hand = f => ToView(Poser.Pose(emd.Skel, emw.Skel, f)[HandJoint].T, eye, new double[3]);
            Func<double[], double[], double[], double[]> Place = (at, h, nudge) =>
                new[] { at[0] - h[0] + nudge[0], at[1] + h[1] + nudge[1], at[2] - h[2] + nudge[2] };   // h[1] is mirrored
            double[] low = new double[3];
            if (pointForward) { }   // set below, from the aimed spot
            else if (knife)
                low = Place(KnifeLowAt, Hand(hold), lowNudge);   // hand at the bottom right
            else
            {
                var pts = WeaponPoints(emd, emw, tris, lowered, eye);
                var top = pts.OrderByDescending(p => p[2]).First();
                low[0] = LowNear - pts.Min(p => p[0]);
                low[1] = -LowSide + pts.Average(p => p[1]);   // view Y is mirrored
                low[2] = -Math.Tan(LowAngle * Math.PI / 180) * (top[0] + low[0]) - top[2];
                for (int k = 0; k < 3; k++) low[k] += lowNudge[k];
            }
            // Aimed: hand at aimAt, but nothing closer than AimNear to her eyes
            // (the rocket launcher rests on her shoulder, right by her face).
            double[] aim = Place(knife ? KnifeAimAt : aimAt, Hand(hold), aimNudge);
            {
                double near = WeaponPoints(emd, emw, tris, hold, eye).Min(p => p[0]) + aim[0];
                if (near < AimNear) { aim[0] += AimNear - near; aim[1] -= (AimNear - near) * 0.3; }
            }

            if (pointForward) low = new[] { aim[0] - 4 + lowNudge[0], aim[1] - 3 + lowNudge[1], aim[2] - 5 + lowNudge[2] };   // back, right and down from the aim (still in view)
            var ticks = new List<int>(); var shifts = new List<double[]>();
            var raiseT = new List<double>();   // 0 lowered .. 1 aimed, per frame
            ticks.Add(lowered); shifts.Add(low); raiseT.Add(0);
            for (int i = 0; i < raise.Count; i++)
            {
                double t = (i + 1.0) / raise.Count;
                if (pointForward) t = t * t * (3 - 2 * t);   // eased: starts and stops gently
                ticks.Add(raise[i]); shifts.Add(new[] { low[0] + (aim[0] - low[0]) * t, low[1] + (aim[1] - low[1]) * t, low[2] + (aim[2] - low[2]) * t }); raiseT.Add(t);
            }
            ticks.Add(hold); shifts.Add(aim); raiseT.Add(1);
            foreach (int f in fire) { ticks.Add(f); shifts.Add(aim); raiseT.Add(1); }

            // --point-forward: the turn that points the barrel (hand -> tip, in the
            // aimed pose) at the crosshair, PointDistance ahead of her eyes.
            double[] turn = null, muzzle = null;
            if (pointForward)
            {
                var pose = Poser.Pose(emd.Skel, emw.Skel, hold);
                var wpts = tris.Where(t => t.Joint == HandJoint).SelectMany(t => t.V).Select(v => ToView(pose[HandJoint].Apply(v), eye, aim)).ToList();
                var handAt = ToView(pose[HandJoint].T, eye, aim);
                var tip = wpts.OrderByDescending(p => Dist(p, handAt)).First();
                double[] barrel = { tip[0] - handAt[0], tip[1] - handAt[1], tip[2] - handAt[2] };
                double[] toCross = { PointDistance - tip[0], -tip[1], -tip[2] };
                turn = RotationBetween(barrel, toCross);
                var tipTurned = MulR(turn, barrel);
                muzzle = new[] { handAt[0] + tipTurned[0], handAt[1] + tipTurned[1], handAt[2] + tipTurned[2] };
            }

            var frames = new List<double[][]>();
            for (int k = 0; k < ticks.Count; k++)
            {
                var pose = Poser.Pose(emd.Skel, emw.Skel, ticks[k]);
                // The left arm only shows while her left hand is on the weapon
                // (two-handed grip); otherwise it would swing across the view.
                bool leftOn = tris.Where(t => t.Joint == HandJoint).SelectMany(t => t.V)
                    .Any(v => Dist(pose[HandJoint].Apply(v), pose[LeftHand].T) < GripDistance);
                // A forearm hanging straight down (weapon lowered) would only
                // show as a stub in front of the weapon: hide it.
                bool rightDown = pose[HandJoint].T[1] - pose[13].T[1] > HangDrop;
                var fr = new double[tris.Count * 3][];
                for (int t = 0; t < tris.Count; t++)
                    for (int c = 0; c < 3; c++)
                        fr[t * 3 + c] = ((!leftOn && tris[t].Joint < 12) || (rightDown && tris[t].Joint == 13))
                            ? new double[] { -40, 0, 0 }   // tucked away behind her eyes
                            : ToView(pose[tris[t].Joint].Apply(tris[t].V[c]), eye, shifts[k]);
                if (turn != null)
                {
                    // turn about the hand: the barrel to the crosshair, tipped down
                    // by LowTilt while lowered, easing level as it rises
                    var pivot = ToView(pose[HandJoint].T, eye, shifts[k]);
                    double tilt = LowTilt * Math.PI / 180 * (1 - raiseT[k]);
                    double[] down = { Math.Cos(tilt), 0, Math.Sin(tilt), 0, 1, 0, -Math.Sin(tilt), 0, Math.Cos(tilt) };
                    var m = MulM(down, turn);
                    for (int i = 0; i < fr.Length; i++)
                    {
                        if (fr[i][0] == -40 && fr[i][1] == 0 && fr[i][2] == 0) continue;   // tucked away
                        var d = MulR(m, new[] { fr[i][0] - pivot[0], fr[i][1] - pivot[1], fr[i][2] - pivot[2] });
                        fr[i] = new[] { pivot[0] + d[0], pivot[1] + d[1], pivot[2] + d[2] };
                    }
                }
                frames.Add(fr);
            }

            // When the hit happens, in ticks into the fire animation: guns at
            // the start of the recoil (the hand first moves back), the knife
            // where the blade reaches furthest forward.
            var hand = fire.Select(f => ToView(Poser.Pose(emd.Skel, emw.Skel, f)[HandJoint].T, eye, new double[3])[0]).ToList();
            int shot = 0;
            if (knife) shot = hand.IndexOf(hand.Max());
            else for (int i = 1; i < hand.Count; i++) if (hand[i] < hand[i - 1] - 1.5) { shot = i; break; }

            int raiseStart = 1, holdFrame = 1 + raise.Count, fireStart = holdFrame + 1;
            string modelDir = Path.Combine(mod, "models/" + who);
            string md3 = "arm_" + name + ".md3";
            Md3Writer.Write(Path.Combine(modelDir, md3), tris, frames, emd.Texture, who + ".png");

            // Frame layout for the game.
            File.WriteAllText(Path.Combine(modelDir, "arm_" + name + ".txt"), string.Format(
                "// written by re1convert viewarms; read by RE_ViewArms.zs\n" +
                "sprite {0}\nframes {1}\nlowered 0\nraise {2} {3}\nhold {4}\nfire {5} {6}\nshot {7}\n",
                prefix, frames.Count, raiseStart, raise.Count, holdFrame, fireStart, fire.Count, shot)
                + (muzzle != null ? string.Format(CultureInfo.InvariantCulture, "muzzle {0:F2} {1:F2} {2:F2}\n", muzzle[0], muzzle[1], muzzle[2]) : ""));

            // MODELDEF block: frame k is sprite <prefix><k/26>, letter k%26.
            var mdl = new System.Text.StringBuilder();
            mdl.AppendFormat("// {0}: written by re1convert viewarms ({1}). Frame k = sprite {2}<k/26>, letter k%26.\n", cls, emwName, prefix);
            mdl.AppendFormat("Model {0}\n{{\n\tPath \"models/{2}\"\n\tModel 0 \"{1}\"\n\tSkin 0 \"{2}.png\"\n\tScale 1.0 1.0 1.0\n", cls, md3, who);
            for (int k = 0; k < frames.Count; k++)
                mdl.AppendFormat("\tFrameIndex {0}{1} {2} 0 {3}\n", prefix, k / 26, (char)('A' + k % 26), k);
            mdl.Append("}\n");
            File.WriteAllText(Path.Combine(modelDir, "arm_" + name + ".mdl"), mdl.ToString());

            string sprDir = Path.Combine(mod, "sprites/viewarms");
            Directory.CreateDirectory(sprDir);
            using (var bmp = new RD.Drawing.Bitmap(1, 1, RD.Drawing.PixelFormat.Format32bppArgb))
            {
                bmp.SetPixel(0, 0, RD.Drawing.Color.FromArgb(0, 0, 0, 0));
                for (int k = 0; k < frames.Count; k++)
                    bmp.Save(Path.Combine(sprDir, string.Format("{0}{1}{2}0.png", prefix, k / 26, (char)('A' + k % 26))), RD.Drawing.ImageFormat.Png);
            }

            Console.WriteLine("Wrote arm_{0}: {1} triangles, {2} frames (lowered 0, raise {3}-{4}, hold {5}, fire {6}-{7}, hit at fire tick {8})",
                name, tris.Count, frames.Count, raiseStart, raiseStart + raise.Count - 1, holdFrame, fireStart, fireStart + fire.Count - 1, shot);
        }

        // Turns the knife (the joint 14 mesh, in the hand's own coordinates)
        // so that in pose 'frame' the blade tip - the point furthest from the
        // hand - points along KnifeBlade.
        static void TurnKnifeForward(EmdFile emd, EmwFile emw, List<Tri> tris, int frame)
        {
            var hand = Poser.Pose(emd.Skel, emw.Skel, frame)[HandJoint];
            var verts = tris.Where(t => t.Joint == HandJoint).SelectMany(t => t.V).ToList();
            var tip = verts.OrderByDescending(v => (double)v[0] * v[0] + (double)v[1] * v[1] + (double)v[2] * v[2]).First();
            double[] d = MulR(hand.R, new double[] { tip[0], tip[1], tip[2] });         // blade, RE1 world axes
            // KnifeBlade is (forward, left, up); RE1 axes are (forward, down, left).
            double[] want = { KnifeBlade[0], -KnifeBlade[2], KnifeBlade[1] };
            double[] rw = RotationBetween(d, want);
            // In the hand's frame: R_local = H^T * R_world * H
            double[] rl = MulM(Transpose(hand.R), MulM(rw, hand.R));
            var done = new HashSet<short[]>();
            foreach (var t in tris.Where(t => t.Joint == HandJoint))
                for (int c = 0; c < 3; c++)
                {
                    if (done.Contains(t.V[c])) continue;   // vertices are shared between triangles
                    var p = MulR(rl, new double[] { t.V[c][0], t.V[c][1], t.V[c][2] });
                    for (int k = 0; k < 3; k++) t.V[c][k] = (short)Math.Round(p[k]);
                    done.Add(t.V[c]);
                }
        }

        // Rotation (3x3, row-major) turning direction a onto direction b.
        static double[] RotationBetween(double[] a, double[] b)
        {
            a = Norm(a); b = Norm(b);
            double[] v = { a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0] };
            double cos = a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
            double[] k = { 0, -v[2], v[1], v[2], 0, -v[0], -v[1], v[0], 0 };
            double[] kk = MulM(k, k);
            double f = 1 / (1 + cos);
            var r = new double[9];
            for (int i = 0; i < 9; i++) r[i] = (i % 4 == 0 ? 1 : 0) + k[i] + kk[i] * f;
            return r;
        }

        static double[] Norm(double[] v)
        {
            double l = Math.Sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
            return new[] { v[0] / l, v[1] / l, v[2] / l };
        }

        static double[] MulR(double[] m, double[] v)
        {
            return new[] { m[0] * v[0] + m[1] * v[1] + m[2] * v[2], m[3] * v[0] + m[4] * v[1] + m[5] * v[2], m[6] * v[0] + m[7] * v[1] + m[8] * v[2] };
        }

        static double[] MulM(double[] a, double[] b)
        {
            var o = new double[9];
            for (int r = 0; r < 3; r++) for (int c = 0; c < 3; c++)
                o[r * 3 + c] = a[r * 3] * b[c] + a[r * 3 + 1] * b[3 + c] + a[r * 3 + 2] * b[6 + c];
            return o;
        }

        static double[] Transpose(double[] m)
        {
            return new[] { m[0], m[3], m[6], m[1], m[4], m[7], m[2], m[5], m[8] };
        }

        // The weapon-hand mesh (joint 14) in one frame, view axes, no shift.
        static List<double[]> WeaponPoints(EmdFile emd, EmwFile emw, List<Tri> tris, int frame, double[] eye)
        {
            var pose = Poser.Pose(emd.Skel, emw.Skel, frame);
            return tris.Where(t => t.Joint == HandJoint).SelectMany(t => t.V)
                .Select(v => ToView(pose[HandJoint].Apply(v), eye, new double[3])).ToList();
        }

        static double Dist(double[] a, double[] b)
        {
            double x = a[0] - b[0], y = a[1] - b[1], z = a[2] - b[2];
            return Math.Sqrt(x * x + y * y + z * z);
        }

        // RE1 point -> view-model point: relative to her eyes, Doom axes
        // (forward, left, up) in map units, moved by 'shift'. GZDoom draws
        // first-person models with left and right swapped, so Y is negated
        // (Md3Writer reverses the triangles to match).
        static double[] ToView(double[] p, double[] eye, double[] shift)
        {
            double x = p[0] - eye[0], y = p[1] - eye[1], z = p[2] - eye[2];
            return new[] { x / 32.0 + shift[0], -(z / 32.0 + shift[1]), -y / 32.0 + shift[2] };
        }
    }
}
