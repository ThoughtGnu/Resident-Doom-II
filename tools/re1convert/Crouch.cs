// Crouch.cs - crouching for Jill and Chris, built on their RE1 skeletons.
//
// RE1 has no crouch, so it is posed here, joint by joint, on each character's
// own skeleton and idle pose (1996 look: rigid parts, RE1's own arm poses):
//   kneel       one knee down. Back (right) knee on the floor, back foot on
//               its toes behind; front (left) foot flat with the shin
//               vertical (knee about 90 degrees); torso upright from RE1's
//               idle, not twisted.
//   crouch_down standing -> step the right foot straight back -> lower that
//               knee to the floor (15 frames, 0.5 s); crouch_up is the reverse
//   crouch_walk a low bent-knee walk, both feet on the floor (16 frames);
//               crouch_rise / crouch_settle go between it and the kneel
//   crouch_aim / crouch_fire  RE1's own aiming / firing upper body (arms
//               forward, two-handed for the guns) on the kneeling legs
// Floor contact is solved, not guessed: in every frame the body is lowered or
// raised so the lowest point of the feet / knee touches the floor (the height
// of RE1's own standing feet), and in the kneel the front thigh angle is
// solved so the front foot lands flat on that same floor.
//
// Joints: 2 hips; 3-5 left thigh / shin / foot; 6-8 right thigh / shin / foot.
// Directions are in the model's space: X forward, Y down (RE1 axes).

using System;
using System.Collections.Generic;
using System.Linq;

namespace Re1Convert
{
    static class Crouch
    {
        const int FT = 3, FS = 4, FF = 5;   // front leg: left
        const int BT = 6, BS = 7, BF = 8;   // back leg: right (the knee that goes down)

        public static PoseFrame FromStored(Skeleton frames, int stored)
        {
            short[] root; short[,] rot;
            frames.GetFrame(stored, out root, out rot);
            int nj = frames.JointCount;
            var pf = new PoseFrame { Root = new double[] { root[0], root[1], root[2] }, R = new double[nj][] };
            for (int j = 0; j < nj; j++) pf.R[j] = Mat.FromRe1Angles(rot[j, 0], rot[j, 1], rot[j, 2]).R;
            return pf;
        }

        static PoseFrame Copy(PoseFrame f)
        {
            return new PoseFrame { Root = (double[])f.Root.Clone(), R = f.R.Select(r => (double[])r.Clone()).ToArray() };
        }

        // --- the leg poser ------------------------------------------------------

        // Everything a character's crouch needs: skeleton, mesh (for floor
        // contact), the standing idle pose and the floor height.
        public class Rig
        {
            public Skeleton Bones;
            public List<Tri> Tris;
            public PoseFrame Idle;
            public double Floor;          // lowest foot point standing (RE1 Y, down = +)
            public double[] FootFlat;     // feet''s world rotation standing (left, right)
            public double[] FootFlatR;
            public double ChestFront;     // the front of the chest mesh (chest joint's own X)
            public double ShoulderHalf;   // half the distance between the shoulder joints
        }

        public static Rig MakeRig(EmdFile emd, EmwFile set)
        {
            var rig = new Rig { Bones = emd.Skel, Tris = ModelBuilder.Build(emd, null), Idle = FromStored(set.Skel, set.Anims.TickFrames(1)[0]) };
            var w = Pose(rig.Bones, rig.Idle);
            rig.Floor = Lowest(rig, rig.Idle, new[] { FF, BF });
            rig.FootFlat = w[FF].R;
            rig.FootFlatR = w[BF].R;
            rig.ChestFront = rig.Tris.Where(t => t.Joint == 0).SelectMany(t => t.V).Max(v => (double)v[0]);
            rig.ShoulderHalf = Math.Abs(emd.Skel.Offsets[12, 2] - emd.Skel.Offsets[9, 2]) / 2;
            return rig;
        }

        static double[] Dir(double deg)   // straight down = 0, forward = +90, back = -90
        {
            double a = deg * Math.PI / 180;
            return new[] { Math.Sin(a), Math.Cos(a), 0 };
        }

        // Sets one leg: thigh and shin directions (degrees from straight down,
        // forward positive) and the foot''s world rotation.
        static void Leg(PoseFrame f, Rig rig, int t, double thighDeg, double shinDeg, double[] footWorld)
        {
            var w = Pose(rig.Bones, f);
            double[] hips = w[2].R;                                     // world rotation of the hips
            double[] off1 = Off(rig.Bones, t + 1), off2 = Off(rig.Bones, t + 2);
            // thigh: hips * R_t * off1 points along Dir(thighDeg)
            f.R[t] = RotationBetween(off1, Mul(Transpose(hips), Dir(thighDeg)));
            double[] wt = Mul(hips, f.R[t]);
            // shin: wt * R_s * off2 points along Dir(shinDeg)
            double[] g = RotationBetween(off2, Dir(shinDeg));
            f.R[t + 1] = Mul(Transpose(wt), g);
            // foot: wt * R_s * R_f = footWorld
            f.R[t + 2] = Mul(Transpose(Mul(wt, f.R[t + 1])), footWorld);
        }


        // Two-bone IK for the chain t -> t+1 -> t+2 (thigh/shin or upper arm/
        // forearm): puts joint t+2 at 'target' (model space) with the middle
        // joint (knee or elbow) bending towards 'bendDir', end turned to endWorld
        // (or, if null, keeping its local rotation).
        static void ChainTo(PoseFrame f, Rig rig, int t, int parent, double[] target, double[] bendDir, double[] endWorld)
        {
            var w = Pose(rig.Bones, f);
            double[] root = w[t].T;
            double l1 = Len(Off(rig.Bones, t + 1)), l2 = Len(Off(rig.Bones, t + 2));
            double[] v = { target[0] - root[0], target[1] - root[1], target[2] - root[2] };
            double dist = Math.Max(1, Math.Min(Len(v), l1 + l2 - 1));
            double[] n = Norm(v);
            double bn = bendDir[0] * n[0] + bendDir[1] * n[1] + bendDir[2] * n[2];
            double[] p = Norm(new[] { bendDir[0] - bn * n[0], bendDir[1] - bn * n[1], bendDir[2] - bn * n[2] });
            double ca = Math.Max(-1, Math.Min(1, (l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist)));
            double sa = Math.Sqrt(1 - ca * ca);
            double[] d1 = { n[0] * ca + p[0] * sa, n[1] * ca + p[1] * sa, n[2] * ca + p[2] * sa };
            double[] mid = { root[0] + d1[0] * l1, root[1] + d1[1] * l1, root[2] + d1[2] * l1 };
            double[] end = { root[0] + n[0] * dist, root[1] + n[1] * dist, root[2] + n[2] * dist };
            double[] d2 = Norm(new[] { end[0] - mid[0], end[1] - mid[1], end[2] - mid[2] });
            double[] pw = w[parent].R;
            f.R[t] = RotationBetween(Off(rig.Bones, t + 1), Mul(Transpose(pw), d1));
            double[] w1 = Mul(pw, f.R[t]);
            f.R[t + 1] = Mul(Transpose(w1), RotationBetween(Off(rig.Bones, t + 2), d2));
            if (endWorld != null) f.R[t + 2] = Mul(Transpose(Mul(w1, f.R[t + 1])), endWorld);
        }

        static double Len(double[] v) { return Math.Sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]); }

        public const double Lean = 35;          // torso forward, degrees
        public const int WalkFrames = 12;       // one step cycle (30 a second)
        const double FootLift = 30;             // RE1 units: a shuffle
        const double FeetWidth = 0.85;          // ankles apart = this x the shoulder joints' spacing

        // Squat walk. Hips held level at the standing knee height (no bob),
        // pelvis square to the front, knees bent and pointing forward, torso
        // leaning forward. Each foot is planted for half the cycle (moving back
        // under the body at exactly the walking speed: no sliding) and shuffles
        // forward, barely lifted, for the other half.
        public static List<PoseFrame> LowWalk(Rig rig, PoseFrame upper, double stride, bool backwards)
        {
            var wIdle = Pose(rig.Bones, rig.Idle);
            double ankleUp = rig.Floor - wIdle[FF].T[1];                  // ankle height above the floor
            double kneeUp = rig.Floor - wIdle[FS].T[1];                   // standing knee height
            double[] hipsWorld = wIdle[2].R;                              // pelvis square, as standing
            var o = new List<PoseFrame>();
            for (int i = 0; i < WalkFrames; i++)
            {
                var f = Copy(upper);
                f.R[0] = Mul(Pitch(Lean), upper.R[0]);   // tips the chest forward
                f.R[2] = Mul(Transpose(f.R[0]), hipsWorld);
                // hips at knee height: move the body so the hip joints are there
                var w = Pose(rig.Bones, f);
                double hipY = (w[FT].T[1] + w[BT].T[1]) / 2;
                f.Root[1] += (rig.Floor - kneeUp) - hipY;
                w = Pose(rig.Bones, f);
                double ph = i / (double)WalkFrames;
                for (int leg = 0; leg < 2; leg++)
                {
                    int t = leg == 0 ? FT : BT;
                    double q = (ph + leg * 0.5) % 1.0;
                    double x, lift;
                    if (q < 0.5) { x = stride / 2 - stride * (q / 0.5); lift = 0; }
                    else { double s = (q - 0.5) / 0.5; x = -stride / 2 + stride * Ease(s); lift = FootLift * Math.Sin(s * Math.PI); }
                    if (backwards) x = -x;
                    double[] hip = w[t].T;
                    double side = Math.Sign(hip[2] - w[2].T[2]);
                    // feet about shoulder width apart, each on its own side of the middle
                    double[] ankle = { hip[0] + 60 + x, rig.Floor - ankleUp - lift, w[2].T[2] + side * rig.ShoulderHalf * FeetWidth };
                    ChainTo(f, rig, t, 2, ankle, new double[] { 1, 0, 0 }, leg == 0 ? rig.FootFlat : rig.FootFlatR);
                }
                o.Add(f);
            }
            if (backwards) o.Reverse();
            return o;
        }

        // The crouched arms (kneeling and squat-walking): a compressed
        // high-ready, the same for every weapon. Both hands together a hand's
        // width in front of the chest, between chest and chin, elbows bent and
        // tucked down. The two hands always hold RE1's own two-handed pistol
        // grip (its aim pose's hand angles and the left hand's place on the
        // right): with a gun it points straight forward, the knife is turned
        // in that grip so its blade points forward, and empty hands keep the
        // same grip with nothing in it. Nothing comes from the RE1 idle pose.
        public class Arms
        {
            Rig rig; double[] rRot, lRot, grip; bool gun;

            // pistol: the character's Beretta file (its aim-hold frame gives the
            // grip); weapon as in Program.WeaponNames, set = that weapon's file.
            public Arms(Rig rig, EmwFile pistol, EmwFile set, int weapon)
            {
                this.rig = rig;
                gun = weapon >= 2;
                var aimSet = gun ? set : pistol;
                var wa = Pose(rig.Bones, FromStored(aimSet.Skel, aimSet.Anims.TickFrames(7)[0]));
                rRot = wa[14].R; lRot = wa[11].R;
                grip = Mul(Transpose(rRot), new[] { wa[11].T[0] - wa[14].T[0], wa[11].T[1] - wa[14].T[1], wa[11].T[2] - wa[14].T[2] });
                if (weapon == 1 && set.WeaponArm != null)
                {
                    // the knife's tip is its furthest point from the hand; turn the
                    // hand (about the wrist) so it points level ahead, a little up
                    var v = set.WeaponArm.Objects.SelectMany(o => o.Verts).OrderByDescending(p => (double)p[0] * p[0] + (double)p[1] * p[1] + (double)p[2] * p[2]).First();
                    double[] turn = RotationBetween(Mul(rRot, new double[] { v[0], v[1], v[2] }), new[] { 1.0, -0.15, 0.0 });
                    rRot = Mul(turn, rRot); lRot = Mul(turn, lRot);   // the left hand turns with it
                }
            }

            public void Apply(PoseFrame f)
            {
                var w = Pose(rig.Bones, f);
                double[] chest = w[0].R, c0 = w[0].T;
                double sr = Math.Sign(rig.Bones.Offsets[12, 2] - rig.Bones.Offsets[9, 2]), sl = -sr;
                double shoulderY = (rig.Bones.Offsets[9, 1] + rig.Bones.Offsets[12, 1]) / 2;
                // the right wrist, in the chest's own frame: just in front of the
                // chest (the fist and gun reach further), between chest and chin
                double[] local = { rig.ChestFront + 40, shoulderY + (gun ? 90 : 120), 0 };
                // the two hands centred on the body
                double[] g = Mul(Transpose(chest), Mul(rRot, grip));
                local[2] = -g[2] / 2;
                double[] off = Mul(chest, local);
                double[] rHand = { c0[0] + off[0], c0[1] + off[1], c0[2] + off[2] };
                double[] gw = Mul(rRot, grip);
                double[] lHand = { rHand[0] + gw[0], rHand[1] + gw[1], rHand[2] + gw[2] };
                ChainTo(f, rig, 12, 0, rHand, Mul(chest, new[] { -0.3, 1.0, sr * 0.3 }), rRot);   // elbows down, tucked; gun level ahead
                ChainTo(f, rig, 9, 0, lHand, Mul(chest, new[] { -0.3, 1.0, sl * 0.3 }), lRot);
            }
        }

        // --- the armed idle (standing still with a gun, not aiming) -------------
        // RE1's own idle for the body and legs (each tick of the weapon set's
        // idle, so it still breathes), and the arms re-posed:
        //   one-handed (Beretta, Colt Python): the gun hangs at the side in the
        //     right hand, pointing at the floor; the left arm as in RE1's
        //     unarmed idle.
        //   two-handed (shotgun, bazooka, rocket launcher): held low across the
        //     body, both hands on it with RE1's own two-handed grip (from the
        //     aim pose), muzzle down to the left.
        // The numbers are tuned on "re1convert armedsheet" pictures.
        public static double SideFwd = 90, SideDown = 0.9, SideOut = 120, SidePitch = 95;
        public static double LowFwd = 220, LowDown = 0.85, LowSide = 90, LowYaw = -50, LowPitch = 35;
        // shotgun and bazooka diagonal low-ready across the front: rear hand on the stock at the right hip, front hand low on the left, barrel ~45 degrees
        // down and forward, a little across the body (pitch: more = barrel lower)
        public static double ReadyFwd = 150, ReadyDown = 0.95, ReadySide = 140, ReadyYaw = 45, ReadyPitch = 42;

        public static List<PoseFrame> ArmedIdle(Rig rig, EmwFile set, EmwFile unarmed, int weapon, Carry carry = null)
        {
            bool twoHanded = weapon == 3 || weapon == 5 || weapon == 6 || weapon == Program.Flame;
            var aim = Pose(rig.Bones, FromStored(set.Skel, set.Anims.TickFrames(7)[0]));
            double[] rAim = aim[14].R, lAim = aim[11].R;
            double[] grip = Mul(Transpose(rAim), new[] { aim[11].T[0] - aim[14].T[0], aim[11].T[1] - aim[14].T[1], aim[11].T[2] - aim[14].T[2] });
            var calm = unarmed.Anims.TickFrames(1);
            double armLen = Len(Off(rig.Bones, 13)) + Len(Off(rig.Bones, 14));
            double sr = Math.Sign(rig.Bones.Offsets[12, 2] - rig.Bones.Offsets[9, 2]);
            var o = new List<PoseFrame>();
            var ticks = set.Anims.TickFrames(1);
            for (int i = 0; i < ticks.Count; i++)
            {
                var f = FromStored(set.Skel, ticks[i]);
                // shotgun / bazooka: the two-handed carry from Jill's walk (Carry above)
                if (carry != null && (weapon == 3 || weapon == 5 || weapon == 6 || weapon == Program.Flame)) { carry.Apply(f); o.Add(f); continue; }
                var relaxed = FromStored(unarmed.Skel, calm[i % calm.Count]);
                var w = Pose(rig.Bones, f);
                double[] chest = w[0].R, sh = w[12].T;
                if (!twoHanded)
                {
                    // the left arm hangs relaxed at the side
                    for (int j = 9; j <= 11; j++) f.R[j] = (double[])relaxed.R[j].Clone();
                    double[] lsh = w[9].T;
                    double[] loff = Mul(chest, new[] { SideFwd * 0.6, armLen * SideDown, -sr * SideOut * 0.8 });
                    ChainTo(f, rig, 9, 0, new[] { lsh[0] + loff[0], lsh[1] + loff[1], lsh[2] + loff[2] }, Mul(chest, new[] { -1.0, 0.0, -sr * 0.3 }), null);
                    f.R[11] = new double[] { 1, 0, 0, 0, 1, 0, 0, 0, 1 };   // the hand straight on from the forearm
                    w = Pose(rig.Bones, f);
                    double[] off = Mul(chest, new[] { SideFwd, armLen * SideDown, sr * SideOut });
                    double[] hand = { sh[0] + off[0], sh[1] + off[1], sh[2] + off[2] };
                    double[] r = Mul(Mul(chest, Pitch(SidePitch)), Mul(Transpose(Pose(rig.Bones, FromStored(set.Skel, ticks[i]))[0].R), rAim));
                    ChainTo(f, rig, 12, 0, hand, Mul(chest, new[] { -1.0, 0.0, sr * 0.3 }), r);
                }
                else
                {
                    double[] mid = { (w[9].T[0] + w[12].T[0]) / 2, (w[9].T[1] + w[12].T[1]) / 2, (w[9].T[2] + w[12].T[2]) / 2 };
                    double[] off = weapon == 6 ? Mul(chest, new[] { LowFwd + 160, armLen * 1.0, sr * LowSide })
                        : Mul(chest, new[] { ReadyFwd, armLen * ReadyDown, sr * ReadySide });   // shotgun / bazooka: low-ready, stock at the hip   // the rocket launcher is bulky
                    double[] hand = { mid[0] + off[0], mid[1] + off[1], mid[2] + off[2] };
                    double yaw = weapon == 6 ? -80 : ReadyYaw, pitch = weapon == 6 ? 12 : ReadyPitch;   // the long rocket tube: nearly level across the body, clear of chest and face
                    double[] turn = Mul(chest, Mul(Rot(1, yaw * Math.PI / 180 * sr), Pitch(pitch)));
                    double[] r = Mul(turn, rAim), l = Mul(turn, lAim);
                    double[] g = Mul(r, grip);
                    ChainTo(f, rig, 12, 0, hand, Mul(chest, new[] { -0.6, 1.0, sr * 0.5 }), r);
                    ChainTo(f, rig, 9, 0, new[] { hand[0] + g[0], hand[1] + g[1], hand[2] + g[2] }, Mul(chest, new[] { -0.6, 1.0, -sr * 0.5 }), l);
                }
                o.Add(f);
            }
            return o;
        }

        // --- carrying a two-handed gun (shotgun, bazooka) -----------------------
        // The single reference: Jill's RE1 forward walk with the shotgun
        // (W13 motion 2, frame RefFrame), the gun carried diagonally across the
        // front of her body. Its arms (joints 9-14) are put on every frame of the
        // idle, the forward walk (also used to turn in place) and the backwards
        // walk; the legs and body keep their own animation. Jill gets the
        // reference arm angles as they are. Other skeletons (Chris) get the same
        // hand placement relative to the chest, scaled to their arm length, with
        // their own two-handed grip from their RE1 aim pose, by IK.
        public static int RefFrame = 0;

        public class Carry
        {
            PoseFrame refFrame; bool same;
            Rig rig; double[] rOff, rRot, rBend, lBend, grip, lRel;
            static readonly int[] armJoints = { 9, 10, 11, 12, 13, 14 };

            public Carry(string re1Usa, string who, Rig targetRig, EmwFile targetSet, int refWeapon = 3, int refFrameIndex = -1, double[] flip = null)
            {
                var jf = Program.Files("jill");
                var jemd = EmdFile.Read(System.IO.Path.Combine(re1Usa, "Enemy/" + jf.Emd));
                var jset = EmwFile.Read(System.IO.Path.Combine(re1Usa, "Players/" + jf.Weapons[refWeapon] + ".EMW"));
                var walk = jset.Anims.TickFrames(2);
                refFrame = FromStored(jset.Skel, walk[Math.Min(refFrameIndex >= 0 ? refFrameIndex : RefFrame, walk.Count - 1)]);
                same = who == "jill";
                rig = targetRig;
                var w = Pose(jemd.Skel, refFrame);
                double[] cT = Transpose(w[0].R);
                double armJ = Len(Off(jemd.Skel, 13)) + Len(Off(jemd.Skel, 14));
                rOff = Mul(cT, Sub(w[14].T, w[12].T)); for (int k = 0; k < 3; k++) rOff[k] /= armJ;
                rRot = Mul(cT, w[14].R);
                if (flip != null) rRot = Mul(rRot, flip);   // the target's weapon mesh sits the other way round in its hand
                rBend = Mul(cT, Sub(w[13].T, Mid(w[12].T, w[14].T)));
                lBend = Mul(cT, Sub(w[10].T, Mid(w[9].T, w[11].T)));
                // the target's own grip: left hand relative to the right, from its aim pose
                var aim = Pose(rig.Bones, FromStored(targetSet.Skel, targetSet.Anims.TickFrames(7)[0]));
                grip = Mul(Transpose(aim[14].R), Sub(aim[11].T, aim[14].T));
                lRel = Mul(Transpose(aim[14].R), aim[11].R);
            }

            // The character's own RE1 pose as the reference (same skeleton): the
            // rocket launcher from its aim hold (motion 7), resting on the right
            // shoulder, the four-barrel end forward.
            public static double ShoulderDown = 220, ShoulderOut = 90;
            double shDown, shOut;
            public Carry(EmwFile ownSet, int motion, Rig ownRig)
            {
                refFrame = FromStored(ownSet.Skel, ownSet.Anims.TickFrames(motion)[0]);
                same = true;
                // the aim pose raises it to the eye: lower it onto the shoulder and
                // move it out a little, clear of the head (hands keep their angles)
                rig = ownRig; shDown = ShoulderDown; shOut = ShoulderOut;
                // the launcher's long axis in the hand (principal axis of its mesh)
                if (ownSet.WeaponArm != null)
                {
                    var vs = ownSet.WeaponArm.Objects[0].Verts;
                    double[] m = new double[3];
                    foreach (var v in vs) for (int k = 0; k < 3; k++) m[k] += v[k] / (double)vs.Count;
                    double[] ax = { 1, 0.3, 0.2 };
                    for (int it = 0; it < 50; it++)
                    {
                        double[] n = new double[3];
                        foreach (var v in vs)
                        {
                            double[] q = { v[0] - m[0], v[1] - m[1], v[2] - m[2] };
                            double dot = q[0] * ax[0] + q[1] * ax[1] + q[2] * ax[2];
                            for (int k = 0; k < 3; k++) n[k] += q[k] * dot;
                        }
                        ax = Norm(n);
                    }
                    tubeAxis = ax;
                }
            }
            double[] tubeAxis;

            static double[] Sub(double[] a, double[] b) { return new[] { a[0] - b[0], a[1] - b[1], a[2] - b[2] }; }
            static double[] Mid(double[] a, double[] b) { return new[] { (a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2 }; }

            public void Apply(PoseFrame f)
            {
                if (same)
                {
                    foreach (int j in armJoints) f.R[j] = (double[])refFrame.R[j].Clone();
                    if (rig == null || (shDown == 0 && shOut == 0)) return;
                    var a = Pose(rig.Bones, f);
                    if (tubeAxis != null)
                    {
                        // turn about the chest's vertical axis through the right shoulder
                        // until the tube points straight forward (no sideways part)
                        double[] loc = Mul(Transpose(a[0].R), Mul(a[14].R, tubeAxis));
                        double best = 0, bestZ = Math.Abs(loc[2]);
                        for (double th = -90; th <= 90; th += 0.5)
                        {
                            var t = Mul(Rot(1, th * Math.PI / 180), loc);
                            double h = Math.Sqrt(t[0] * t[0] + t[2] * t[2]);
                            if (h > 1e-6 && Math.Abs(t[2]) / h < bestZ / Math.Max(1e-6, Math.Sqrt(loc[0] * loc[0] + loc[2] * loc[2])) + 1e-9 && Math.Abs(t[2]) < bestZ) { bestZ = Math.Abs(t[2]); best = th; }
                        }
                        double[] Rw = Mul(a[0].R, Mul(Rot(1, best * Math.PI / 180), Transpose(a[0].R)));
                        double[] P = a[12].T;
                        double[] r14 = Mul(Rw, Sub(a[14].T, P)), r11 = Mul(Rw, Sub(a[11].T, P));
                        double[] nr = { P[0] + r14[0], P[1] + r14[1], P[2] + r14[2] }, nl = { P[0] + r11[0], P[1] + r11[1], P[2] + r11[2] };
                        ChainTo(f, rig, 12, 0, nr, Sub(a[13].T, Mid(a[12].T, a[14].T)), Mul(Rw, a[14].R));
                        ChainTo(f, rig, 9, 0, nl, Sub(a[10].T, Mid(a[9].T, a[11].T)), Mul(Rw, a[11].R));
                        a = Pose(rig.Bones, f);
                    }
                    double s = Math.Sign(rig.Bones.Offsets[12, 2] - rig.Bones.Offsets[9, 2]);
                    double[] mv = Mul(a[0].R, new[] { 0.0, shDown, s * shOut });
                    double[] rh = { a[14].T[0] + mv[0], a[14].T[1] + mv[1], a[14].T[2] + mv[2] }, lh = { a[11].T[0] + mv[0], a[11].T[1] + mv[1], a[11].T[2] + mv[2] };
                    double[] rR = a[14].R, lR = a[11].R;
                    ChainTo(f, rig, 12, 0, rh, Sub(a[13].T, Mid(a[12].T, a[14].T)), rR);
                    ChainTo(f, rig, 9, 0, lh, Sub(a[10].T, Mid(a[9].T, a[11].T)), lR);
                    return;
                }
                var w = Pose(rig.Bones, f);
                double[] chest = w[0].R, sh = w[12].T;
                double arm = Len(Off(rig.Bones, 13)) + Len(Off(rig.Bones, 14));
                double[] o = Mul(chest, rOff);
                double[] hand = { sh[0] + o[0] * arm, sh[1] + o[1] * arm, sh[2] + o[2] * arm };
                double[] r = Mul(chest, rRot);
                ChainTo(f, rig, 12, 0, hand, Mul(chest, rBend), r);
                double[] g = Mul(r, grip);
                ChainTo(f, rig, 9, 0, new[] { hand[0] + g[0], hand[1] + g[1], hand[2] + g[2] }, Mul(chest, lBend), Mul(r, lRel));
            }

            public List<PoseFrame> ApplyAll(List<PoseFrame> frames) { foreach (var f in frames) Apply(f); return frames; }
        }

        // The carry for a weapon: shotgun and bazooka from Jill's shotgun walk,
        // the rocket launcher from Jill's rocket launcher walk (on the shoulder).
        public static int RocketRef = 0;
        public static bool FlipTest = false;
        public static Carry MakeCarry(string usa, string who, Rig rig, EmwFile set, int weapon)
        {
            if (weapon != 6) return new Carry(usa, who, rig, set);
            return new Carry(set, 7, rig);   // the rocket launcher: on the shoulder, from the character's own aim hold
        }

        // Standing, walking forward and backwards with the shotgun and bazooka
        // (or the rocket launcher alone), front and side.
        public static int[] SheetGuns = { 3, 5 };
        public static void CarrySheet(string who, string usa, string outPath)
        {
            var files = Program.Files(who);
            var emd = EmdFile.Read(System.IO.Path.Combine(usa, "Enemy/" + files.Emd));
            var unarmed = EmwFile.Read(System.IO.Path.Combine(usa, "Players/" + files.Weapons[0] + ".EMW"));
            int[] guns = SheetGuns;
            using (var bmp = new RD.Drawing.Bitmap(6 * 200, guns.Length * 330))
            {
                using (var g = RD.Drawing.Graphics.FromImage(bmp)) g.Clear(RD.Drawing.Color.FromArgb(40, 40, 48));
                var ren = new SoftRenderer(bmp);
                for (int k = 0; k < guns.Length; k++)
                {
                    var set = EmwFile.Read(System.IO.Path.Combine(usa, "Players/" + files.Weapons[guns[k]] + ".EMW"));
                    var rig = MakeRig(emd, set);
                    var tris = ModelBuilder.Build(emd, set.WeaponArm);
                    var frames = new[] {
                        ArmedIdle(rig, set, unarmed, guns[k], MakeCarry(usa, who, rig, set, guns[k]))[0],
                        CarryWalk(rig, set, usa, who, guns[k], false)[4],
                        CarryWalk(rig, set, usa, who, guns[k], true)[4] };
                    string[] names = { "standing", "walk", "back" };
                    for (int v = 0; v < 3; v++)
                    {
                        var fr = Copy(frames[v]); fr.Root[1] -= rig.Floor;
                        ren.Draw(tris, Pose(emd.Skel, fr), emd.Texture, 400 * v + 100, 330 * k + 320, 0.1, 0);
                        ren.Draw(tris, Pose(emd.Skel, fr), emd.Texture, 400 * v + 300, 330 * k + 320, 0.1, 1);
                        using (var g = RD.Drawing.Graphics.FromImage(bmp))
                            g.DrawString(Program.WeaponNames[guns[k]] + " " + names[v], new RD.Drawing.Font("Segoe UI", 10), RD.Drawing.Brushes.White, 400 * v + 4, 330 * k + 4);
                    }
                }
                bmp.Save(outPath, RD.Drawing.ImageFormat.Png);
            }
        }

        // The forward walk (weapon file motion 2) or backwards walk (character
        // file motion 3) with the two-handed carry on the arms. Jill's forward
        // walk is the reference itself and stays RE1's.
        // bodyWho: whose own back-up motion (CHARxx.EMD) to use, if not who's
        // (Jill posed like Chris with his flamethrower).
        public static List<PoseFrame> CarryWalk(Rig rig, EmwFile set, string usa, string who, int weapon, bool backwards, string bodyWho = null)
        {
            var files = Program.Files(bodyWho ?? who);
            var emd = EmdFile.Read(System.IO.Path.Combine(usa, "Enemy/" + files.Emd));
            var frames = backwards ? emd.Anims.TickFrames(3).Select(s => FromStored(emd.Skel, s)).ToList()
                                   : set.Anims.TickFrames(2).Select(s => FromStored(set.Skel, s)).ToList();
            if (!backwards && who == "jill" && weapon != 6) return frames;
            return MakeCarry(usa, who, rig, set, weapon).ApplyAll(frames);
        }

        // --- the knife-ready idle -------------------------------------------------
        // Standing with the knife: RE1's idle (its breathing motion) with the
        // arms of the character's own knife walk (weapon file motion 2, frame
        // KnifeRef): knife low in the right hand, blade forward and down, left
        // arm at the side.
        public static int KnifeRef = 0;
        // the knife walk frame used for the arms: Chris 0, Jill 20 (arms by her side)
        public static int KnifeRefFor(string who) { return who == "jill" ? 20 : 0; }
        public static List<PoseFrame> KnifeIdle(EmwFile set, Skeleton bones = null)
        {
            var walk = set.Anims.TickFrames(2);
            var arms = FromStored(set.Skel, walk[Math.Min(KnifeRef, walk.Count - 1)]);
            // the blade forward and down whichever way RE1's walk holds it (Jill's
            // points back): turn the hand so the knife's tip (its furthest point
            // from the hand) points forward and down, relative to the chest
            if (bones != null && set.WeaponArm != null)
            {
                var v = set.WeaponArm.Objects[0].Verts.OrderByDescending(p => (double)p[0] * p[0] + (double)p[1] * p[1] + (double)p[2] * p[2]).First();
                var w = Pose(bones, arms);
                double[] tip = Mul(w[14].R, new double[] { v[0], v[1], v[2] });
                double[] want = Mul(w[0].R, new[] { 0.8, 0.6, 0.0 });
                double[] world = Mul(RotationBetween(tip, want), w[14].R);
                arms.R[14] = Mul(Transpose(w[13].R), world);
            }
            var o = new List<PoseFrame>();
            foreach (int t in set.Anims.TickFrames(1))
            {
                var f = FromStored(set.Skel, t);
                for (int j = 9; j <= 14; j++) f.R[j] = (double[])arms.R[j].Clone();
                o.Add(f);
            }
            return o;
        }

        // Chris standing with nothing in his hands. RE1's own unarmed idle for him
        // (W00 motion 1) is a "thinking" pose: one arm folded across his chest,
        // the gloved hand at his chin. From the game's cameras that read as him
        // holding a shotgun across his chest a moment after every map started.
        // Here: that idle's breathing motion for the body and legs, with the
        // arms of his own unarmed walk (motion 2, frame armsFrame: hanging at
        // his sides).
        public static List<PoseFrame> RelaxedIdle(EmwFile set, int armsFrame = 0)
        {
            var walk = set.Anims.TickFrames(2);
            var arms = FromStored(set.Skel, walk[Math.Min(armsFrame, walk.Count - 1)]);
            var o = new List<PoseFrame>();
            foreach (int t in set.Anims.TickFrames(1))
            {
                var f = FromStored(set.Skel, t);
                for (int j = 9; j <= 14; j++) f.R[j] = (double[])arms.R[j].Clone();
                o.Add(f);
            }
            return o;
        }

        // The RE1 knife idle and the knife walk's frames, front and side.
        public static void KnifeSheet(string who, string usa, string outPath)
        {
            var files = Program.Files(who);
            var emd = EmdFile.Read(System.IO.Path.Combine(usa, "Enemy/" + files.Emd));
            var set = EmwFile.Read(System.IO.Path.Combine(usa, "Players/" + files.Weapons[1] + ".EMW"));
            var rig = MakeRig(emd, set);
            var tris = ModelBuilder.Build(emd, set.WeaponArm);
            var walk = set.Anims.TickFrames(2);
            var shots = new List<Tuple<PoseFrame, string>>();
            shots.Add(Tuple.Create(FromStored(set.Skel, set.Anims.TickFrames(1)[0]), "RE1 idle"));
            for (int i = 0; i < walk.Count; i += 4) shots.Add(Tuple.Create(FromStored(set.Skel, walk[i]), "walk " + i));
            shots.Add(Tuple.Create(KnifeIdle(set, emd.Skel)[0], "new idle (walk " + KnifeRef + ")"));
            using (var bmp = new RD.Drawing.Bitmap(shots.Count * 180, 600))
            {
                using (var g = RD.Drawing.Graphics.FromImage(bmp)) g.Clear(RD.Drawing.Color.FromArgb(40, 40, 48));
                var ren = new SoftRenderer(bmp);
                for (int i = 0; i < shots.Count; i++)
                {
                    var fr = Copy(shots[i].Item1); fr.Root[1] -= rig.Floor; fr.Root[0] = 0; fr.Root[2] = 0;
                    ren.Draw(tris, Pose(emd.Skel, fr), emd.Texture, 180 * i + 90, 290, 0.1, 0);
                    ren.Draw(tris, Pose(emd.Skel, fr), emd.Texture, 180 * i + 90, 590, 0.1, 1);
                    using (var g = RD.Drawing.Graphics.FromImage(bmp))
                        g.DrawString(shots[i].Item2, new RD.Drawing.Font("Segoe UI", 9), RD.Drawing.Brushes.White, 180 * i + 4, 4);
                }
                bmp.Save(outPath, RD.Drawing.ImageFormat.Png);
            }
        }

        // Each weapon's armed idle, front and side (and the RE1 idle for comparison).
        public static void ArmedSheet(string who, string usa, string outPath)
        {
            var files = Program.Files(who);
            var emd = EmdFile.Read(System.IO.Path.Combine(usa, "Enemy/" + files.Emd));
            var unarmed = EmwFile.Read(System.IO.Path.Combine(usa, "Players/" + files.Weapons[0] + ".EMW"));
            int[] guns = { 2, 4, 3, 5, 6 };
            using (var bmp = new RD.Drawing.Bitmap(guns.Length * 300, 460))
            {
                using (var g = RD.Drawing.Graphics.FromImage(bmp)) g.Clear(RD.Drawing.Color.FromArgb(40, 40, 48));
                var ren = new SoftRenderer(bmp);
                for (int k = 0; k < guns.Length; k++)
                {
                    var set = EmwFile.Read(System.IO.Path.Combine(usa, "Players/" + files.Weapons[guns[k]] + ".EMW"));
                    var rig = MakeRig(emd, set);
                    var tris = ModelBuilder.Build(emd, set.WeaponArm);
                    var fr = ArmedIdle(rig, set, unarmed, guns[k])[0];
                    if (Environment.GetEnvironmentVariable("RE_MUZZLE") != null)
                    {
                        var far = set.WeaponArm.Objects[0].Verts.OrderByDescending(p => (double)p[0] * p[0] + (double)p[1] * p[1] + (double)p[2] * p[2]).First();
                        var pw = Pose(rig.Bones, fr);
                        var dir = Mul(pw[14].R, new double[] { far[0], far[1], far[2] });
                        var chestInv = Transpose(pw[0].R);
                        var local = Mul(chestInv, dir); double l = Math.Sqrt(local[0] * local[0] + local[1] * local[1] + local[2] * local[2]);
                        Console.WriteLine("{0}: muzzle direction (body frame) forward {1:F2}, down {2:F2}, side {3:F2} -> {4:F0} degrees below level", Program.WeaponNames[guns[k]], local[0] / l, local[1] / l, local[2] / l, Math.Asin(local[1] / l) * 180 / Math.PI);
                    }
                    var old = FromStored(set.Skel, set.Anims.TickFrames(1)[0]);
                    fr.Root[1] -= rig.Floor; old.Root[1] -= rig.Floor;
                    ren.Draw(tris, Pose(emd.Skel, fr), emd.Texture, 300 * k + 75, 440, 0.13, 0);
                    ren.Draw(tris, Pose(emd.Skel, fr), emd.Texture, 300 * k + 225, 440, 0.13, 1);
                    ren.Draw(tris, Pose(emd.Skel, old), emd.Texture, 300 * k + 150, 120, 0.05, 0);
                    using (var g = RD.Drawing.Graphics.FromImage(bmp))
                        g.DrawString(Program.WeaponNames[guns[k]] + " (small: RE1 idle)", new RD.Drawing.Font("Segoe UI", 10), RD.Drawing.Brushes.White, 300 * k + 4, 4);
                }
                bmp.Save(outPath, RD.Drawing.ImageFormat.Png);
            }
        }

        // The squat walk for one weapon: legs as LowWalk, the arms above.
        public static List<PoseFrame> SquatWalk(Rig rig, Arms arms, bool backwards)
        {
            var frames = LowWalk(rig, rig.Idle, Stride(backwards ? CrouchBackSpeed : CrouchWalkSpeed), backwards);
            foreach (var f in frames) arms.Apply(f);
            return frames;
        }
        // How far a planted foot travels in half a cycle = the distance the body
        // moves in that time: speed (map units per tic) x 35 tics a second x
        // half a cycle in seconds x 32 (RE1 units per map unit).
        public static double Stride(double mapUnitsPerTic) { return mapUnitsPerTic * 35 * (WalkFrames / 2 / 30.0) * 32; }
        public const double CrouchWalkSpeed = 2.491071429 * 0.5, CrouchBackSpeed = 1.714285714 * 0.5;   // RE_Const.zs / TankPlayer.zs

        static double[] Off(Skeleton s, int j) { return new double[] { s.Offsets[j, 0], s.Offsets[j, 1], s.Offsets[j, 2] }; }

        // The lowest (largest Y) mesh point of the given joints.
        static double Lowest(Rig rig, PoseFrame f, int[] joints)
        {
            var w = Pose(rig.Bones, f);
            double y = double.MinValue;
            foreach (var t in rig.Tris)
            {
                if (Array.IndexOf(joints, t.Joint) < 0) continue;
                foreach (var v in t.V) y = Math.Max(y, w[t.Joint].Apply(v)[1]);
            }
            return y;
        }

        // Moves the body up or down so the lowest leg point touches the floor.
        static void OnFloor(Rig rig, PoseFrame f, int[] joints = null)
        {
            double low = Lowest(rig, f, joints ?? new[] { FS, FF, BS, BF });
            f.Root[1] += rig.Floor - low;
        }

        // Rotation about the model''s sideways axis (Z): tips a foot''s toes down.
        static double[] Pitch(double deg) { return Rot(2, deg * Math.PI / 180); }

        // --- the poses ------------------------------------------------------------

        // One knee down. The back thigh hangs nearly straight down, the back shin
        // lies back along the floor, the foot is on its toes; the front shin is
        // vertical and the front thigh angle is solved so the front foot is flat
        // on the floor.
        public static PoseFrame Kneel(Rig rig, PoseFrame upper, Arms arms = null)
        {
            var f = Copy(upper);
            if (arms != null) arms.Apply(f);
            // the front leg folded up out of the way while the back knee alone
            // sets the body height (its shin's lowest point on the floor)
            Leg(f, rig, FT, 100, 0, rig.FootFlat);
            Leg(f, rig, BT, -8, -78, Mul(Pitch(-62), rig.FootFlatR));
            OnFloor(rig, f, new[] { BS });
            double kneeFloor = f.Root[1];
            // front leg: solve the thigh angle so the flat front foot meets the floor
            double lo = 0, hi = 140;
            for (int i = 0; i < 40; i++)
            {
                double mid = (lo + hi) / 2;
                Leg(f, rig, FT, mid, 0, rig.FootFlat);
                double foot = Lowest(rig, f, new[] { FF });
                if (foot > rig.Floor) lo = mid; else hi = mid;   // foot below the floor: lift the knee
            }
            Leg(f, rig, FT, (lo + hi) / 2, 0, rig.FootFlat);
            // the toes of the back foot just touch the floor
            double plo = -89, phi = 0;
            for (int i = 0; i < 30; i++)
            {
                double mid = (plo + phi) / 2;
                Leg(f, rig, BT, -8, -78, Mul(Pitch(mid), rig.FootFlatR));
                f.Root[1] = kneeFloor;
                if (Lowest(rig, f, new[] { BF }) > rig.Floor) plo = mid; else phi = mid;
            }
            Leg(f, rig, BT, -8, -78, Mul(Pitch((plo + phi) / 2), rig.FootFlatR));
            f.Root[1] = kneeFloor;
            return f;
        }

        // Standing with the right foot stepped straight back (both feet flat).
        static PoseFrame StepBack(Rig rig, PoseFrame upper, Arms arms = null)
        {
            var f = Copy(upper);
            if (arms != null) arms.Apply(f);
            Leg(f, rig, FT, 6, 0, rig.FootFlat);
            Leg(f, rig, BT, -22, -22, rig.FootFlatR);
            OnFloor(rig, f);
            return f;
        }

        // The low bent-knee walk stance at a step phase (0..1).
        static PoseFrame LowStep(Rig rig, PoseFrame upper, double phase)
        {
            var f = Copy(upper);
            double s = Math.Sin(phase * 2 * Math.PI);
            // knees bent about 70 degrees; legs swing in turn
            Leg(f, rig, FT, 38 + 16 * s, -32 + 10 * Math.Max(0, -s), rig.FootFlat);
            Leg(f, rig, BT, 38 - 16 * s, -32 + 10 * Math.Max(0, s), rig.FootFlatR);
            OnFloor(rig, f);
            return f;
        }

        // A blend of two poses (rotations interpolated as quaternions), set back on the floor.
        static PoseFrame Blend(Rig rig, PoseFrame a, PoseFrame b, double t)
        {
            var f = Copy(a);
            for (int k = 0; k < 3; k++) f.Root[k] = a.Root[k] + (b.Root[k] - a.Root[k]) * t;
            for (int j = 0; j < f.R.Length; j++) f.R[j] = Slerp(a.R[j], b.R[j], t);
            OnFloor(rig, f);
            return f;
        }

        // standing -> step back -> kneel, 15 frames (0.5 s at RE1''s 30 a second)
        public static List<PoseFrame> Down(Rig rig, PoseFrame upper, Arms arms = null)
        {
            var stand = Copy(rig.Idle);
            for (int j = 0; j < stand.R.Length; j++) if (j < 2 || j > 8) stand.R[j] = upper.R[j];
            OnFloor(rig, stand);
            var step = StepBack(rig, upper, arms);
            var kneel = Kneel(rig, upper, arms);
            var o = new List<PoseFrame>();
            for (int i = 0; i < 6; i++) o.Add(Blend(rig, stand, step, (i + 1) / 6.0));
            for (int i = 0; i < 9; i++) o.Add(Blend(rig, step, kneel, Ease((i + 1) / 9.0)));
            return o;
        }

        public static List<PoseFrame> Walk(Rig rig, List<PoseFrame> walkUpper, PoseFrame idleUpper)
        {
            var o = new List<PoseFrame>();
            for (int i = 0; i < 16; i++)
            {
                // upper body: the walk''s arm swing, torso kept from the idle (no twist)
                var up = Copy(walkUpper[i * walkUpper.Count / 16]);
                up.R[0] = idleUpper.R[0];
                up.Root = (double[])idleUpper.Root.Clone();
                o.Add(LowStep(rig, up, i / 16.0));
            }
            return o;
        }

        // low walk stance -> kneel, 9 frames (crouch_settle); reversed: crouch_rise
        // low walk -> kneel, 9 frames (crouch_settle); reversed: crouch_rise. The
        // hips are already at the kneel's height, so it's only the legs and arms.
        public static List<PoseFrame> Settle(Rig rig, PoseFrame walkStart, PoseFrame kneel)
        {
            var o = new List<PoseFrame>();
            for (int i = 0; i < 9; i++)
            {
                double t = Ease((i + 1) / 9.0);
                var f = Copy(walkStart);
                for (int k = 0; k < 3; k++) f.Root[k] = walkStart.Root[k] + (kneel.Root[k] - walkStart.Root[k]) * t;
                for (int j = 0; j < f.R.Length; j++) f.R[j] = Slerp(walkStart.R[j], kneel.R[j], t);
                o.Add(f);
            }
            return o;
        }

        // standing -> squat walk (9 frames): crouching while already moving.
        public static List<PoseFrame> StandToWalk(Rig rig, PoseFrame upper, PoseFrame walkStart)
        {
            var stand = Copy(rig.Idle);
            for (int j = 0; j < stand.R.Length; j++) if (j < 2 || j > 8) stand.R[j] = upper.R[j];
            OnFloor(rig, stand);
            var o = new List<PoseFrame>();
            for (int i = 0; i < 9; i++)
            {
                double t = Ease((i + 1) / 9.0);
                var f = Copy(stand);
                for (int k = 0; k < 3; k++) f.Root[k] = stand.Root[k] + (walkStart.Root[k] - stand.Root[k]) * t;
                for (int j = 0; j < f.R.Length; j++) f.R[j] = Slerp(stand.R[j], walkStart.R[j], t);
                o.Add(f);
            }
            return o;
        }

        static double Ease(double t) { return t * t * (3 - 2 * t); }

        // --- maths ------------------------------------------------------------------

        public static double[] Rot(int axis, double a)
        {
            double c = Math.Cos(a), s = Math.Sin(a);
            if (axis == 0) return new[] { 1, 0, 0, 0, c, -s, 0, s, c };
            if (axis == 1) return new[] { c, 0, s, 0, 1, 0, -s, 0, c };
            return new[] { c, -s, 0, s, c, 0, 0, 0, 1 };
        }

        public static double[] Mul(double[] a, double[] b)
        {
            if (b.Length == 3)
                return new[] { a[0] * b[0] + a[1] * b[1] + a[2] * b[2], a[3] * b[0] + a[4] * b[1] + a[5] * b[2], a[6] * b[0] + a[7] * b[1] + a[8] * b[2] };
            var o = new double[9];
            for (int r = 0; r < 3; r++) for (int c = 0; c < 3; c++)
                o[r * 3 + c] = a[r * 3] * b[c] + a[r * 3 + 1] * b[3 + c] + a[r * 3 + 2] * b[6 + c];
            return o;
        }

        static double[] Transpose(double[] m) { return new[] { m[0], m[3], m[6], m[1], m[4], m[7], m[2], m[5], m[8] }; }

        static double[] RotationBetween(double[] a, double[] b)
        {
            a = Norm(a); b = Norm(b);
            double[] v = { a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0] };
            double cos = a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
            if (cos < -0.9999) return Rot(2, Math.PI);
            double[] k = { 0, -v[2], v[1], v[2], 0, -v[0], -v[1], v[0], 0 };
            double[] kk = Mul(k, k);
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

        // Rotation-matrix interpolation through quaternions.
        static double[] Slerp(double[] a, double[] b, double t)
        {
            var qa = Q(a); var qb = Q(b);
            double dot = qa[0] * qb[0] + qa[1] * qb[1] + qa[2] * qb[2] + qa[3] * qb[3];
            if (dot < 0) { for (int i = 0; i < 4; i++) qb[i] = -qb[i]; dot = -dot; }
            var q = new double[4];
            if (dot > 0.9995) for (int i = 0; i < 4; i++) q[i] = qa[i] + (qb[i] - qa[i]) * t;
            else
            {
                double th = Math.Acos(dot), s = Math.Sin(th);
                double wa = Math.Sin((1 - t) * th) / s, wb = Math.Sin(t * th) / s;
                for (int i = 0; i < 4; i++) q[i] = qa[i] * wa + qb[i] * wb;
            }
            double l = Math.Sqrt(q.Sum(x => x * x));
            for (int i = 0; i < 4; i++) q[i] /= l;
            double x0 = q[0], y = q[1], z = q[2], w = q[3];
            return new[] { 1 - 2 * (y * y + z * z), 2 * (x0 * y - z * w), 2 * (x0 * z + y * w),
                           2 * (x0 * y + z * w), 1 - 2 * (x0 * x0 + z * z), 2 * (y * z - x0 * w),
                           2 * (x0 * z - y * w), 2 * (y * z + x0 * w), 1 - 2 * (x0 * x0 + y * y) };
        }

        static double[] Q(double[] m)
        {
            double tr = m[0] + m[4] + m[8], x, y, z, w;
            if (tr > 0) { double s = Math.Sqrt(tr + 1) * 2; w = s / 4; x = (m[7] - m[5]) / s; y = (m[2] - m[6]) / s; z = (m[3] - m[1]) / s; }
            else if (m[0] > m[4] && m[0] > m[8]) { double s = Math.Sqrt(1 + m[0] - m[4] - m[8]) * 2; w = (m[7] - m[5]) / s; x = s / 4; y = (m[1] + m[3]) / s; z = (m[2] + m[6]) / s; }
            else if (m[4] > m[8]) { double s = Math.Sqrt(1 + m[4] - m[0] - m[8]) * 2; w = (m[2] - m[6]) / s; x = (m[1] + m[3]) / s; y = s / 4; z = (m[5] + m[7]) / s; }
            else { double s = Math.Sqrt(1 + m[8] - m[0] - m[4]) * 2; w = (m[3] - m[1]) / s; x = (m[2] + m[6]) / s; y = (m[5] + m[7]) / s; z = s / 4; }
            return new[] { x, y, z, w };
        }

        // World matrices of every joint for a frame.
        public static Mat[] Pose(Skeleton bones, PoseFrame f)
        {
            int nj = bones.JointCount;
            var local = new Mat[nj]; var world = new Mat[nj];
            for (int j = 0; j < nj; j++)
            {
                local[j] = Mat.Identity();
                local[j].R = f.R[j];
                local[j].T = j == 0 ? f.Root : new double[] { bones.Offsets[j, 0], bones.Offsets[j, 1], bones.Offsets[j, 2] };
            }
            world[0] = local[0];
            WalkTree(bones, 0, world, local);
            return world;
        }

        static void WalkTree(Skeleton s, int j, Mat[] world, Mat[] local)
        {
            foreach (int c in s.Children[j]) { world[c] = Mat.Mul(world[j], local[c]); WalkTree(s, c, world, local); }
        }

        // "re1convert crouchsheet <jill|chris> <RE1> <out.png>": side views of the
        // kneel, the step-down (5 frames), crouch-aim, low walk (4 frames), and a
        // front view of the kneel and the aim. A red line marks the floor.
        public static void Sheet(string who, string usa, string outPath, int weapon = 2)
        {
            var files = Program.Files(who);
            var emd = EmdFile.Read(System.IO.Path.Combine(usa, "Enemy/" + files.Emd));
            var set = EmwFile.Read(System.IO.Path.Combine(usa, "Players/" + files.Weapons[weapon] + ".EMW"));
            var rig = MakeRig(emd, set);
            var tris = ModelBuilder.Build(emd, weapon > 0 ? set.WeaponArm : null);
            var idle = rig.Idle;
            var pistol = EmwFile.Read(System.IO.Path.Combine(usa, "Players/" + files.Weapons[2] + ".EMW"));
            var arms = new Arms(rig, pistol, set, weapon);
            var kneel = Kneel(rig, idle, arms);
            var walk = SquatWalk(rig, arms, false);
            var shots = new List<Tuple<PoseFrame, int>>();
            shots.Add(Tuple.Create(kneel, 1));
            for (int i = 0; i < WalkFrames; i += 2) shots.Add(Tuple.Create(walk[i], 1));
            shots.Add(Tuple.Create(kneel, 0));
            for (int i = 0; i < WalkFrames; i += 3) shots.Add(Tuple.Create(walk[i], 0));
            if (weapon >= 1)
            {
                var aim = FromStored(set.Skel, set.Anims.TickFrames(weapon == 1 ? 9 : 7)[0]);
                shots.Add(Tuple.Create(CombineOnFloor(rig, aim, kneel), 1));
            }
            double scale = 0.085, baseY = 200;
            using (var bmp = new RD.Drawing.Bitmap(shots.Count * 100, 215))
            {
                using (var g = RD.Drawing.Graphics.FromImage(bmp))
                {
                    g.Clear(RD.Drawing.Color.FromArgb(40, 40, 48));
                    g.DrawLine(RD.Drawing.Pens.Red, 0, (float)baseY, bmp.Width, (float)baseY);
                }
                var ren = new SoftRenderer(bmp);
                for (int i = 0; i < shots.Count; i++)
                {
                    var fr = Copy(shots[i].Item1);
                    fr.Root[1] -= rig.Floor;
                    ren.Draw(tris, Pose(emd.Skel, fr), emd.Texture, 50 + i * 100, (int)baseY, scale, shots[i].Item2);
                }
                bmp.Save(outPath, RD.Drawing.ImageFormat.Png);
            }
            Console.WriteLine("Wrote " + outPath);
        }
        // Combine, then set back on the floor (the upper body's lean can move it).
        public static PoseFrame CombineOnFloor(Rig rig, PoseFrame upper, PoseFrame legs)
        {
            var f = Combine(upper, legs);
            OnFloor(rig, f);
            return f;
        }

        // Upper body from 'upper', hips and legs (with the body height) from 'legs'.
        public static PoseFrame Combine(PoseFrame upper, PoseFrame legs)
        {
            int nj = upper.R.Length;
            var o = new PoseFrame { Root = new[] { upper.Root[0], legs.Root[1], upper.Root[2] }, R = new double[nj][] };
            for (int j = 0; j < nj; j++) o.R[j] = upper.R[j];
            o.R[2] = Mul(Transpose(upper.R[0]), Mul(legs.R[0], legs.R[2]));
            for (int j = 3; j <= 8; j++) o.R[j] = legs.R[j];
            return o;
        }

        // --- crawling (low gaps) ---------------------------------------------------
        // Through a gap too low to kneel in (the models are ~88 map units tall; the
        // gaps 32-48), on hands and knees, posed on the character's own skeleton:
        //   torso nearly level (CrawlLean), head raised to look ahead; thighs
        //   down from the hips to the knees on the floor, shins back along the
        //   floor, toes down; arms straight down from the shoulders, hands flat on
        //   the floor a little ahead of them.
        //   crawl: a 16-frame cycle, left hand with right knee then right hand with
        //     left knee; a planted hand or knee moves back at exactly the crawling
        //     speed (no sliding), the other swings forward, barely lifted
        //   crawl_down: standing -> RE1-style one knee down (Kneel) -> on all fours
        //     (crawl_up is the reverse); crawl_in / crawl_out: the squat walk's
        //     first frame <-> on all fours (the player, already crouched)
        public static double CrawlLean = 96, CrawlHead = -62, CrawlThigh = -70, CrawlHandFwd = 150, CrawlElbow = 1.4;   // tuned on crawlsheet: at most 28.3 high, 55 wide (the lowest gap is 32, the narrowest 64)
        static double EnvD(string n, double d) { var s = Environment.GetEnvironmentVariable(n); double v; return s != null && double.TryParse(s, System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out v) ? v : d; }
        public static void CrawlFromEnv()
        {
            CrawlLean = EnvD("CRAWL_LEAN", CrawlLean); CrawlHead = EnvD("CRAWL_HEAD", CrawlHead); CrawlThigh = EnvD("CRAWL_THIGH", CrawlThigh);
            CrawlHandFwd = EnvD("CRAWL_HANDFWD", CrawlHandFwd); CrawlElbow = EnvD("CRAWL_ELBOW", CrawlElbow);
        }
        public const int CrawlFrames = 16;
        const double CrawlLift = 40;

        static PoseFrame CrawlPose(Rig rig, PoseFrame upper, double phase, double stride, double[] gunHand)
        {
            var wIdle = Pose(rig.Bones, rig.Idle);
            var f = Copy(upper);
            // torso nearly level, the pelvis turned with it, the head raised to look ahead
            f.R[0] = Mul(Pitch(CrawlLean), rig.Idle.R[0]);
            f.R[2] = Mul(Transpose(f.R[0]), Mul(Pitch(CrawlLean - 8), wIdle[2].R));
            f.R[1] = Mul(Pitch(CrawlHead), rig.Idle.R[1]);
            double thighLen = Len(Off(rig.Bones, FS));
            // legs: knee x offset from the hip for each side's phase
            for (int leg = 0; leg < 2; leg++)
            {
                int t = leg == 0 ? FT : BT;
                double q = (phase + (leg == 0 ? 0.5 : 0)) % 1.0;   // the left knee with the right hand
                double x, lift;
                if (q < 0.5) { x = stride / 2 - stride * (q / 0.5); lift = 0; }
                else { double s = (q - 0.5) / 0.5; x = -stride / 2 + stride * Ease(s); lift = CrawlLift * Math.Sin(s * Math.PI); }
                double th = CrawlThigh + Math.Asin(Math.Max(-0.9, Math.Min(0.9, x / thighLen))) * 180 / Math.PI;
                Leg(f, rig, t, th, -86 + lift * 0.1, Mul(Pitch(-84), t == FT ? rig.FootFlat : rig.FootFlatR));
            }
            // the knees on the floor (the lowest shin point; a swinging knee is lifted a little)
            OnFloor(rig, f, new[] { FS, BS });
            // arms: hands flat on the floor a little ahead of the shoulders
            var w = Pose(rig.Bones, f);
            double sr = Math.Sign(rig.Bones.Offsets[12, 2] - rig.Bones.Offsets[9, 2]);
            for (int arm = 0; arm < 2; arm++)
            {
                int t = arm == 0 ? 9 : 12;
                double q = (phase + (arm == 0 ? 0 : 0.5)) % 1.0;
                double x, lift;
                if (q < 0.5) { x = stride / 2 - stride * (q / 0.5); lift = 0; }
                else { double s = (q - 0.5) / 0.5; x = -stride / 2 + stride * Ease(s); lift = CrawlLift * Math.Sin(s * Math.PI); }
                double[] sh = w[t].T;
                double side = arm == 0 ? -sr : sr;
                double[] wrist = { sh[0] + CrawlHandFwd + x, rig.Floor - 70 - lift, sh[2] + side * 20 };
                double[] handWorld = Mul(Pitch(70), wIdle[t + 2].R);   // palm down, fingers ahead
                if (t == 12 && gunHand != null) handWorld = gunHand;   // the gun hand: RE1's aiming grip, the gun level along the floor, pointing ahead
                ChainTo(f, rig, t, 0, wrist, new[] { -1.0 + CrawlElbow * 0.7, CrawlElbow, side * 0.3 }, handWorld);   // CrawlElbow > 0: elbows down to the floor (on the forearms)
            }
            return f;
        }

        // The gun hand's world rotation for the crawl: RE1's aim hold (motion 7), or null (knife, empty hands).
        public static double[] CrawlGunHand(Rig rig, EmwFile set, int weapon)
        {
            if (weapon < 2) return null;
            return Pose(rig.Bones, FromStored(set.Skel, set.Anims.TickFrames(7)[0]))[14].R;
        }

        public static List<PoseFrame> Crawl(Rig rig, PoseFrame upper, double[] gunHand = null)
        {
            var o = new List<PoseFrame>();
            double stride = Stride(CrouchWalkSpeed) * (CrawlFrames / (double)WalkFrames);
            for (int i = 0; i < CrawlFrames; i++) o.Add(CrawlPose(rig, upper, i / (double)CrawlFrames, stride, gunHand));
            return o;
        }

        // standing -> one knee down -> on all fours (24 frames); reversed: crawl_up
        public static List<PoseFrame> CrawlDown(Rig rig, PoseFrame upper, Arms arms, PoseFrame crawlStart)
        {
            var down = Down(rig, upper, arms);              // RE1-style kneel, 15 frames
            var kneel = down[down.Count - 1];
            var o = new List<PoseFrame>(down);
            for (int i = 0; i < 9; i++) o.Add(BlendFree(kneel, crawlStart, Ease((i + 1) / 9.0)));
            return o;
        }

        // the squat walk's first frame -> on all fours (9 frames); reversed: crawl_out
        public static List<PoseFrame> CrawlIn(Rig rig, PoseFrame walkStart, PoseFrame crawlStart)
        {
            var o = new List<PoseFrame>();
            for (int i = 0; i < 9; i++) o.Add(BlendFree(walkStart, crawlStart, Ease((i + 1) / 9.0)));
            return o;
        }

        // A blend of two poses without re-placing it on the floor (both ends are).
        static PoseFrame BlendFree(PoseFrame a, PoseFrame b, double t)
        {
            var f = Copy(a);
            for (int k = 0; k < 3; k++) f.Root[k] = a.Root[k] + (b.Root[k] - a.Root[k]) * t;
            for (int j = 0; j < f.R.Length; j++) f.R[j] = Slerp(a.R[j], b.R[j], t);
            return f;
        }

        // "re1convert crawlsheet <jill|chris> <RE1 USA> <out.png> [weapon]": the crawl
        // cycle side and front, the get-down; with each frame's height and width.
        public static void CrawlSheet(string who, string usa, string outPath, int weapon = 2)
        {
            CrawlFromEnv();
            var files = Program.Files(who);
            var emd = EmdFile.Read(System.IO.Path.Combine(usa, "Enemy/" + files.Emd));
            var set = EmwFile.Read(System.IO.Path.Combine(usa, "Players/" + files.Weapons[weapon] + ".EMW"));
            var rig = MakeRig(emd, set);
            var tris = ModelBuilder.Build(emd, weapon > 0 ? set.WeaponArm : null);
            var pistol = EmwFile.Read(System.IO.Path.Combine(usa, "Players/" + files.Weapons[2] + ".EMW"));
            var arms = new Arms(rig, pistol, set, weapon);
            var crawl = Crawl(rig, rig.Idle, CrawlGunHand(rig, set, weapon));
            var down = CrawlDown(rig, rig.Idle, arms, crawl[0]);
            var shots = new List<Tuple<PoseFrame, int, string>>();
            for (int i = 0; i < CrawlFrames; i += 2) shots.Add(Tuple.Create(crawl[i], 1, "crawl " + i));
            shots.Add(Tuple.Create(crawl[0], 0, "front"));
            shots.Add(Tuple.Create(crawl[4], 0, "front 4"));
            for (int i = 0; i < down.Count; i += 4) shots.Add(Tuple.Create(down[i], 1, "down " + i));
            Console.WriteLine("children of 0: " + string.Join(",", emd.Skel.Children[0]));
            double scale = 0.1, baseY = 260;
            int cw = 170;
            using (var bmp = new RD.Drawing.Bitmap(shots.Count * cw, 290))
            {
                using (var g = RD.Drawing.Graphics.FromImage(bmp))
                {
                    g.Clear(RD.Drawing.Color.FromArgb(40, 40, 48));
                    g.DrawLine(RD.Drawing.Pens.Red, 0, (float)baseY, bmp.Width, (float)baseY);
                    // the lowest gap (32 map units) as a line
                    float gy = (float)(baseY - 32 * 32 * scale);
                    g.DrawLine(RD.Drawing.Pens.Orange, 0, gy, bmp.Width, gy);
                }
                var ren = new SoftRenderer(bmp);
                for (int i = 0; i < shots.Count; i++)
                {
                    var fr = Copy(shots[i].Item1);
                    fr.Root[1] -= rig.Floor;
                    var pose = Pose(emd.Skel, fr);
                    ren.Draw(tris, pose, emd.Texture, cw / 2 + i * cw - (shots[i].Item2 == 1 ? (int)(fr.Root[0] * scale) : 0), (int)baseY, scale, shots[i].Item2);
                    double h, half, fw, bk;
                    PartnerKneel.Measure(tris, Pose(emd.Skel, shots[i].Item1), rig.Floor, out h, out half, out fw, out bk);
                    using (var g = RD.Drawing.Graphics.FromImage(bmp))
                        g.DrawString(string.Format("{0}\nh {1:0.0} w {2:0}", shots[i].Item3, h, half * 2), new RD.Drawing.Font("Arial", 9), RD.Drawing.Brushes.Yellow, i * cw + 2, 2);
                    Console.WriteLine("{0}: height {1:0.0}, width {2:0.0}, length {3:0.0}", shots[i].Item3, h, half * 2, fw + bk);
                }
                bmp.Save(outPath, RD.Drawing.ImageFormat.Png);
            }
            Console.WriteLine("Wrote " + outPath);
        }
    }
}
