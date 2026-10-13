// Program.cs - re1convert: turns Jill's RE1 model files into files GZDoom can load.
//
//   re1convert info <file.emd|file.emw>      print what's inside
//
// Files are only ever read from the RE1 folder; output goes where you say.

using System;
using System.Linq;
using System.Collections.Generic;

namespace Re1Convert
{
    static partial class Program
    {
        static int Main(string[] args)
        {
            // numbers in written files always use a dot (a PC or Mac set to, say,
            // German would otherwise write 0,5 into the model and texture files)
            System.Threading.Thread.CurrentThread.CurrentCulture = System.Globalization.CultureInfo.InvariantCulture;
            System.Threading.Thread.CurrentThread.CurrentUICulture = System.Globalization.CultureInfo.InvariantCulture;
            if (args.Length < 2) { Usage(); return 1; }
            try
            {
                switch (args[0])
                {
                    case "info": Info(args[1]); return 0;
                    case "sheet": Sheet(args[1], args[2], args[3]); return 0;
                    case "character": Character(args[1], args[2], args[3], args.Length > 4 ? args[4] : null); return 0;
                    case "jill": Character("jill", args[1], args[2]); return 0;   // older name
                    case "viewarms": ViewArms.Run(args); return 0;
                    case "items": ItemProps.Export(args[1], args[2]); return 0;
                    case "flamesprites": FlameSprites.Export(args[1], args[2]); return 0;
                    case "timdump": StatusArt.Dump(args[1], args[2]); return 0;
                    case "deathsheet": PartnerKneel.DeathSheet(args[1], args[2], args[3]); return 0;
                    case "crawlsheet": Crouch.CrawlSheet(args[1], args[2], args[3], args.Length > 4 ? int.Parse(args[4]) : 2); return 0;
                    case "statusart": StatusArt.Export(args[1], args[2]); return 0;
                    case "castsprites": CastSprites.Export(args[1], args[2], args.Length > 3 ? args[3] : null); return 0;
                    case "knifesheet": if (args.Length > 4) Crouch.KnifeRef = int.Parse(args[4]); Crouch.KnifeSheet(args[1], args[2], args[3]); return 0;
                    case "carrysheet": if (args.Length > 4 && args[4] == "rocket") { Crouch.SheetGuns = new[] { 6 }; if (args.Length > 5) Crouch.RocketRef = int.Parse(args[5]); Crouch.FlipTest = args.Length > 6; } else if (args.Length > 4) Crouch.RefFrame = int.Parse(args[4]); Crouch.CarrySheet(args[1], args[2], args[3]); return 0;
                    case "armedsheet": Crouch.ArmedSheet(args[1], args[2], args[3]); return 0;
                    case "itemsheet": ItemProps.Sheet(args[1], args[2]); return 0;
                    case "itemboxsheet": ItemBox.Sheet(args[1], args[2]); return 0;
                    case "itembox": ItemBox.Export(args[1], args[2]); return 0;
                    case "bothanim": BothAnim(args[1], args[2]); return 0;
                    case "eyes": Eyes(args[1], args[2], args[3]); return 0;
                    case "portrait":
                        if (args.Length > 7) Portrait(args[1], args[2], args[3], args[4], int.Parse(args[5]), int.Parse(args[6]), args[7] == "1");
                        else Portrait(args[1], args[2], args[3]);
                        return 0;
                    case "prop": if (args.Length > 3) Prop.Run(args[1], args[2], args[3]); else Prop.Run(args[1], args[2]); return 0;
                    case "vestsheet": VestSheet(args[1], args[2], args[3]); return 0;
                    case "all": All(args[1], args[2], args[3]); return 0;
                    case "check": return Check(args[1], args[2]) ? 0 : 3;
                    case "selectart": SelectArt(Usa(args[1]), args[2]); return 0;
                    case "titleart": TitleArt(Usa(args[1]), args[2], args[3]); return 0;
                    case "sounds": Sounds(Usa(args[1]), args[2]); return 0;
                    case "levelshots": LevelShots(args[1], args[2]); return 0;
                    case "crouchsheet": Crouch.Sheet(args[1], args[2], args[3], args.Length > 4 ? Array.IndexOf(WeaponNames, args[4]) : 2); return 0;
                }
                Usage();
                return 1;
            }
            catch (Exception e)
            {
                Console.Error.WriteLine("Error: " + e.Message);
                Console.Error.WriteLine(e.StackTrace);
                return 2;
            }
        }

        static void Usage()
        {
            Console.WriteLine("re1convert info <file.emd|file.emw>");
            Console.WriteLine("re1convert prop typewriter <output folder>   (the low-poly typewriter on its table)");
            Console.WriteLine("re1convert sheet <jill.emd> <weapon.emw|-> <out.png>   (pose check picture)");
            Console.WriteLine("re1convert character <jill|chris> <RE1 USA folder> <output folder> [weapon]   (IQM models for every weapon, or just one, + texture)");
            Console.WriteLine("re1convert viewarms <RE1 USA folder> <mod folder> <name> <Wxx.EMW> <sprite prefix> <weapon class> <gun|knife> [lowered f l u] [aimed f l u]");
        }

        // A playable character's file names (EntityModelLoader.cpp: the model
        // table and g_weaponPathTable, which is indexed by item id).
        public class CharFiles
        {
            public string Emd;
            public string[] Weapons;   // unarmed, knife, Beretta, shotgun, Python, bazooka, rocket launcher[, flamethrower]
        }

        public static CharFiles Files(string who)
        {
            switch (who)
            {
                case "jill":  return new CharFiles { Emd = "CHAR11.EMD", Weapons = new[] { "W10", "W11", "W12", "W13", "W14", "W16", "W17" } };
                // Chris also has RE1's flamethrower (W05); Jill has none of her own in RE1
                // (her W15 is the same placeholder file as W25 and W35).
                case "chris": return new CharFiles { Emd = "Char10.EMD", Weapons = new[] { "W00", "W01", "W02", "W03", "W04", "W06", "W07", "W05" } };
            }
            throw new Exception("unknown character '" + who + "' (jill or chris)");
        }

        public static readonly string[] WeaponNames = { "unarmed", "knife", "beretta", "shotgun", "magnum", "grenade", "rocket", "flame" };
        public const int Flame = 7;   // the flamethrower's index above

        // Its RE1 motions (W05): 5 raise, 7 hold, and while fire is held the
        // flame loops 14 / 15 / 16 (straight / up / down), with 8-10 / 11-13
        // into and holding aim up / down like the other guns.
        public static int FireAnim(int w, int dir) { return w == Flame ? 14 + dir : (dir == 0 ? 6 : (dir == 1 ? 9 : 12)); }

        // Which RE1 animation each of our names uses. Numbers are the
        // animation index RE1 plays for that move (PlayerAnimations.cpp):
        //   from the weapon file (Wxx.EMW): 1 idle loop, 2 walk (also turning
        //   in place), 3 run, 5 raise weapon; guns 7/6 hold/fire, knife 9/6
        //   hold/slash.
        //   from the character's own file (CHARxx.EMD): 3 back up, 1 hit, 4 death.
        static void Character(string who, string re1Usa, string outDir, string only = null)
        {
            var files = Files(who);
            var emd = EmdFile.Read(System.IO.Path.Combine(re1Usa, "Enemy/" + files.Emd));
            System.IO.Directory.CreateDirectory(outDir);
            IqmWriter.WriteAtlas(System.IO.Path.Combine(outDir, who + ".png"), emd.Texture);
            var pistolFile = EmwFile.Read(System.IO.Path.Combine(re1Usa, "Players/" + files.Weapons[2] + ".EMW"));
            var knifeFile = EmwFile.Read(System.IO.Path.Combine(re1Usa, "Players/" + files.Weapons[1] + ".EMW"));

            for (int w = 0; w < WeaponNames.Length; w++)
            {
                if (only != null && WeaponNames[w] != only) continue;   // [weapon]: just that one
                // Jill has no flamethrower in RE1 (the re_jillflamer cheat): Chris's
                // (W05) - his flamethrower arm and its motions, on her own body and
                // skeleton, posed the way his is; the arm keeps his texture
                // (<who>_flame.png: her texture with his below it).
                bool borrowed = w == Flame && w >= files.Weapons.Length;
                if (w >= files.Weapons.Length && !borrowed) continue;
                var armFiles = borrowed ? Files("chris") : files;
                string poseWho = borrowed ? "chris" : who;
                Tim armTim = borrowed ? EmdFile.Read(System.IO.Path.Combine(re1Usa, "Enemy/" + armFiles.Emd)).Texture : null;
                // Every gun: 5 raise, 7 hold, 6 fire (player_behavior_13_gun_hold_input).
                int[] aim = w == 0 ? new int[0] : w == 1 ? new[] { 5, 9, 6 } : new[] { 5, 7, 6 };
                var emw = EmwFile.Read(System.IO.Path.Combine(re1Usa, "Players/" + armFiles.Weapons[w] + ".EMW"));
                var tris = ModelBuilder.Build(emd, aim.Length > 0 ? emw.WeaponArm : null, armTim);
                if (borrowed) IqmWriter.WriteAtlas(System.IO.Path.Combine(outDir, who + "_" + WeaponNames[w] + ".png"), emd.Texture, armTim);
                var anims = new System.Collections.Generic.List<IqmAnim>();
                Func<string, Skeleton, AnimSet, int, bool, IqmAnim> A = (n, s, a, i, loop) =>
                    new IqmAnim { Name = n, Frames = s, TickFrames = a.TickFrames(i), Loop = loop };
                // Standing still: RE1's idle unarmed or with the knife; with a gun,
                // the armed idle (Crouch.ArmedIdle: gun low, never against the body).
                // Shotgun and bazooka (w 3, 5): the two-handed carry from Jill's RE1
                // forward walk on the idle, walk (also turning) and backwards walk.
                bool carryGun = w == 3 || w == 5 || w == 6 || w == Flame;   // two-handed
                var carry = carryGun ? Crouch.MakeCarry(re1Usa, poseWho, Crouch.MakeRig(emd, emw), emw, w) : null;
                if (w >= 2)
                    anims.Add(new IqmAnim { Name = "idle", Custom = Crouch.ArmedIdle(Crouch.MakeRig(emd, emw), emw,
                        EmwFile.Read(System.IO.Path.Combine(re1Usa, "Players/" + files.Weapons[0] + ".EMW")), w, carry), Loop = true });
                else if (w == 1 && who == "jill")
                {
                    // Jill: RE1's own knife idle, as RE1 has it (left hand on the hip,
                    // the knife low in the right hand, reverse grip); her knife walk
                    // holds it the same way, so the two match
                    anims.Add(A("idle", emw.Skel, emw.Anims, 1, true));
                }
                else if (w == 1)
                {
                    // the knife: RE1's idle breathing with the arms of its own knife walk
                    Crouch.KnifeRef = Crouch.KnifeRefFor(who);
                    anims.Add(new IqmAnim { Name = "idle", Custom = Crouch.KnifeIdle(emw, emd.Skel), Loop = true });
                }
                else if (who == "chris")
                    anims.Add(new IqmAnim { Name = "idle", Custom = Crouch.RelaxedIdle(emw), Loop = true });   // unarmed Chris: arms at his sides (Crouch.RelaxedIdle)
                else anims.Add(A("idle", emw.Skel, emw.Anims, 1, true));   // unarmed Jill: RE1's own idle (hand on hip)
                if (carryGun)
                {
                    anims.Add(new IqmAnim { Name = "walk", Custom = Crouch.CarryWalk(Crouch.MakeRig(emd, emw), emw, re1Usa, poseWho, w, false, who), Loop = true });
                    anims.Add(A("run", emw.Skel, emw.Anims, 3, true));
                    anims.Add(new IqmAnim { Name = "back", Custom = Crouch.CarryWalk(Crouch.MakeRig(emd, emw), emw, re1Usa, poseWho, w, true, who), Loop = true });
                }
                else
                {
                    anims.Add(A("walk", emw.Skel, emw.Anims, 2, true));
                    anims.Add(A("run", emw.Skel, emw.Anims, 3, true));
                    anims.Add(A("back", emd.Skel, emd.Anims, 3, true));
                }
                anims.Add(A("pain", emd.Skel, emd.Anims, 1, false));
                anims.Add(A("death", emd.Skel, emd.Anims, 4, false));
                if (aim.Length > 0)
                {
                    anims.Add(A("aim_raise", emw.Skel, emw.Anims, aim[0], false));
                    anims.Add(A("aim_hold", emw.Skel, emw.Anims, aim[1], true));
                    anims.Add(A("fire", emw.Skel, emw.Anims, w == Flame ? FireAnim(w, 0) : aim[2], false));
                    // RE1's aiming up and down (attackAnim = dir * 3 + 5): guns
                    // 8 / 10 / 9 = into / hold / fire up, 11 / 13 / 12 = down.
                    // The knife: 7 slashes high, 8 slashes low (it holds its
                    // usual ready pose for both).
                    bool knifeSet = w == 1;
                    anims.Add(A("aim_up", emw.Skel, emw.Anims, knifeSet ? 9 : 8, false));
                    anims.Add(A("aim_up_hold", emw.Skel, emw.Anims, knifeSet ? 9 : 10, true));
                    anims.Add(A("fire_up", emw.Skel, emw.Anims, knifeSet ? 7 : FireAnim(w, 1), false));
                    anims.Add(A("aim_down", emw.Skel, emw.Anims, knifeSet ? 9 : 11, false));
                    anims.Add(A("aim_down_hold", emw.Skel, emw.Anims, knifeSet ? 9 : 13, true));
                    anims.Add(A("fire_down", emw.Skel, emw.Anims, knifeSet ? 8 : FireAnim(w, 2), false));
                }
                // Crouching (Crouch.cs): a one-knee kneel posed on this
                // character's own skeleton, with its transitions and low walk.
                {
                    var rig = Crouch.MakeRig(emd, emw);
                    Func<int, List<PoseFrame>> Frames = an => emw.Anims.TickFrames(an).Select(f => Crouch.FromStored(emw.Skel, f)).ToList();
                    Func<string, List<PoseFrame>, bool, IqmAnim> C = (n, fr, loop) => new IqmAnim { Name = n, Custom = fr, Loop = loop };
                    var idleUp = rig.Idle;
                    var arms = new Crouch.Arms(rig, pistolFile, emw, w);   // the crouched high-ready
                    var kneel = Crouch.Kneel(rig, idleUp, arms);
                    var down = Crouch.Down(rig, idleUp, arms);
                    var up = new List<PoseFrame>(down); up.Reverse();
                    var walk = Crouch.SquatWalk(rig, arms, false);
                    var back = Crouch.SquatWalk(rig, arms, true);
                    var walkIn = Crouch.StandToWalk(rig, idleUp, walk[0]);
                    var walkOut = new List<PoseFrame>(walkIn); walkOut.Reverse();
                    var settle = Crouch.Settle(rig, walk[0], kneel);
                    var rise = new List<PoseFrame>(settle); rise.Reverse();
                    anims.Add(C("crouch", new List<PoseFrame> { kneel }, true));
                    anims.Add(C("crouch_down", down, false));
                    anims.Add(C("crouch_up", up, false));
                    anims.Add(C("crouch_walk", walk, true));
                    anims.Add(C("crouch_back", back, true));
                    anims.Add(C("crouch_walkin", walkIn, false));
                    anims.Add(C("crouch_walkout", walkOut, false));
                    anims.Add(C("crouch_settle", settle, false));
                    anims.Add(C("crouch_rise", rise, false));
                    // Crawling on hands and knees through a gap too low to crouch in
                    // (Crouch.Crawl): the cycle, holding still, getting down from
                    // standing (the partner) or from the squat walk (the player), and back.
                    var crawl = Crouch.Crawl(rig, idleUp, Crouch.CrawlGunHand(rig, emw, w));
                    var crawlDown = Crouch.CrawlDown(rig, idleUp, arms, crawl[0]);
                    var crawlUp = new List<PoseFrame>(crawlDown); crawlUp.Reverse();
                    var crawlIn = Crouch.CrawlIn(rig, walk[0], crawl[0]);
                    var crawlOut = new List<PoseFrame>(crawlIn); crawlOut.Reverse();
                    anims.Add(C("crawl", crawl, true));
                    anims.Add(C("crawl_still", new List<PoseFrame> { crawl[0] }, true));
                    anims.Add(C("crawl_down", crawlDown, false));
                    anims.Add(C("crawl_up", crawlUp, false));
                    anims.Add(C("crawl_in", crawlIn, false));
                    anims.Add(C("crawl_out", crawlOut, false));
                    if (aim.Length > 0)
                    {
                        anims.Add(C("crouch_aim", new List<PoseFrame> { Crouch.CombineOnFloor(rig, Frames(aim[1])[0], kneel) }, true));
                        anims.Add(C("crouch_fire", Frames(w == Flame ? FireAnim(w, 0) : aim[2]).Select(f => Crouch.CombineOnFloor(rig, f, kneel)).ToList(), false));
                    }
                }
                // GZDoom won't play a one-frame animation: give those a second, identical frame.
                foreach (var a in anims)
                {
                    if (a.Custom != null && a.Custom.Count == 1) a.Custom.Add(a.Custom[0]);
                    else if (a.Custom == null && a.TickFrames.Count == 1) a.TickFrames.Add(a.TickFrames[0]);
                }

                // plain, light vest (green armor), heavy vest (blue armor) - Vest.cs
                for (int vest = 0; vest <= 2; vest++)
                {
                    var t = vest == 0 ? tris : tris.Concat(Vest.Make(emd, vest)).ToList();
                    string path = System.IO.Path.Combine(outDir, who + "_" + WeaponNames[w] + (vest == 0 ? "" : "_vest" + vest) + ".iqm");
                    IqmWriter.Write(path, emd, t, anims, borrowed ? who + "_" + WeaponNames[w] + ".png" : who + ".png", armTim);
                    if (vest == 0)
                        Console.WriteLine("Wrote {0}: {1} triangles, animations: {2} (+ _vest1, _vest2)", path, tris.Count,
                            string.Join(", ", anims.Select(a => a.Name + "(" + a.Count + ")")));
                }
            }
        }
        // A picture of the character standing (first frame of their idle
        // animation, seen from the front), on a transparent background, for the
        // character-select screen.
        // Optional: [weapon] [animation] [view 0 front / 1 side] [mirror 0/1] -
        // e.g. "portrait jill <RE1> out.png beretta 7 1 0" shows her aiming
        // the Beretta, seen from the side.
        static void Portrait(string who, string re1Usa, string outPath, string weapon = "unarmed", int anim = 1, int view = 0, bool mirror = false)
        {
            var files = Files(who);
            int wi = Math.Max(0, Array.IndexOf(WeaponNames, weapon));
            var emd = EmdFile.Read(System.IO.Path.Combine(re1Usa, "Enemy/" + files.Emd));
            var emw = EmwFile.Read(System.IO.Path.Combine(re1Usa, "Players/" + files.Weapons[wi] + ".EMW"));
            var tris = ModelBuilder.Build(emd, wi > 0 ? emw.WeaponArm : null);
            using (var bmp = new RD.Drawing.Bitmap(240, 420, RD.Drawing.PixelFormat.Format32bppArgb))
            {
                using (var g = RD.Drawing.Graphics.FromImage(bmp)) g.Clear(RD.Drawing.Color.Transparent);
                var pose = Poser.Pose(emd.Skel, emw.Skel, emw.Anims.Anims[anim][0]);
                new SoftRenderer(bmp).Draw(tris, pose, emd.Texture, 120, 412, 0.13, view);
                if (mirror) bmp.RotateFlip(RD.Drawing.RotateFlipType.RotateNoneFlipX);
                bmp.Save(outPath, RD.Drawing.ImageFormat.Png);
            }
            Console.WriteLine("Wrote " + outPath);
        }

        // The select screen's "Both" animation (graphics/SELBT00.png ...): Jill
        // (Beretta) and Chris (shotgun) side by side facing you turn until they
        // stand back to back - Jill facing left, Chris right - sliding together,
        // then raise their weapons with RE1's own raise motion (5) into the aim
        // stance (7). One picture, one depth buffer, transparent background,
        // 640x600 (twice the size it is drawn on the 640x480 select screen).
        const int BothTurn = 12, BothRaise = 12;
        static void BothAnim(string re1Usa, string outDir)
        {
            System.IO.Directory.CreateDirectory(outDir);
            var who = new[] { "jill", "chris" };
            var wpn = new[] { 2, 3 };                      // Beretta, shotgun
            var emd = new EmdFile[2]; var emw = new EmwFile[2]; var tris = new List<Tri>[2];
            for (int i = 0; i < 2; i++)
            {
                var files = Files(who[i]);
                emd[i] = EmdFile.Read(System.IO.Path.Combine(re1Usa, "Enemy/" + files.Emd));
                emw[i] = EmwFile.Read(System.IO.Path.Combine(re1Usa, "Players/" + files.Weapons[wpn[i]] + ".EMW"));
                tris[i] = ModelBuilder.Build(emd[i], emw[i].WeaponArm);
            }
            const int W = 640, H = 600;
            const double scale = 0.186, floorY = 588;
            double[] startX = { 196, 444 }, endX = { 270, 376 };   // side by side -> back to back
            double[] endYaw = { 90, -90 };                          // Jill faces left, Chris right
            int total = BothTurn + BothRaise + 1;
            for (int f = 0; f < total; f++)
            {
                using (var bmp = new RD.Drawing.Bitmap(W, H, RD.Drawing.PixelFormat.Format32bppArgb))
                {
                    using (var g = RD.Drawing.Graphics.FromImage(bmp)) g.Clear(RD.Drawing.Color.Transparent);
                    var ren = new SoftRenderer(bmp);
                    double t = f < BothTurn ? f / (double)(BothTurn - 1) : 1;
                    t = t * t * (3 - 2 * t);
                    for (int i = 0; i < 2; i++)
                    {
                        int stored;
                        if (f < BothTurn) stored = emw[i].Anims.TickFrames(1)[0];                 // idle while turning
                        else if (f < BothTurn + BothRaise)
                        {
                            var raise = emw[i].Anims.TickFrames(5);
                            int k = f - BothTurn;
                            stored = raise[(int)Math.Round(k * (raise.Count - 1) / (double)(BothRaise - 1))];
                        }
                        else stored = emw[i].Anims.TickFrames(7)[0];                              // aim stance
                        var pose = Poser.Pose(emd[i].Skel, emw[i].Skel, stored);
                        ren.DrawTurned(tris[i], pose, emd[i].Texture, startX[i] + (endX[i] - startX[i]) * t, floorY, scale, endYaw[i] * t);
                    }
                    bmp.Save(System.IO.Path.Combine(outDir, string.Format("SELBT{0:00}.png", f)), RD.Drawing.ImageFormat.Png);
                }
            }
            Console.WriteLine("Wrote SELBT00-SELBT{0:00}.png to {1}", total - 1, outDir);
        }

        // Eye level for the first-person view: the head (joint 1) standing (RE1
        // idle) and kneeling (the crouch pose), measured above the floor (the
        // lowest foot point). The eyes are taken at 45% of the way down from
        // the crown to the chin. Prints RE1 units and Doom units (/32), and
        // draws the head from the side with a line at that height.
        static void Eyes(string who, string re1Usa, string outPath)
        {
            var files = Files(who);
            var emd = EmdFile.Read(System.IO.Path.Combine(re1Usa, "Enemy/" + files.Emd));
            var emw = EmwFile.Read(System.IO.Path.Combine(re1Usa, "Players/" + files.Weapons[0] + ".EMW"));
            var tris = ModelBuilder.Build(emd, null);
            var rig = Crouch.MakeRig(emd, emw);
            var poses = new[] { Crouch.Pose(emd.Skel, rig.Idle), Crouch.Pose(emd.Skel, Crouch.Kneel(rig, rig.Idle)) };
            string[] names = { "standing", "kneeling" };
            using (var bmp = new RD.Drawing.Bitmap(600, 330))
            {
                using (var g = RD.Drawing.Graphics.FromImage(bmp)) g.Clear(RD.Drawing.Color.FromArgb(40, 40, 48));
                var ren = new SoftRenderer(bmp);
                for (int k = 0; k < 2; k++)
                {
                    var pose = poses[k];
                    double crown = double.MaxValue, chin = double.MinValue, floor = double.MinValue;
                    foreach (var t in tris)
                        foreach (var v in t.V)
                        {
                            double y = pose[t.Joint].Apply(v)[1];
                            if (t.Joint == 1) { crown = Math.Min(crown, y); chin = Math.Max(chin, y); }
                            floor = Math.Max(floor, y);
                        }
                    double eye = crown + 0.45 * (chin - crown);
                    Console.WriteLine("{0} {1}: floor {2:F0}, crown {3:F0}, chin {4:F0}, eye {5:F0} RE1 units above the floor = {6:F1} Doom units (x1.2 drawn = {7:F1})",
                        who, names[k], floor, floor - crown, floor - chin, floor - eye, (floor - eye) / 32, (floor - eye) / 32 * 1.2);
                    int ox = 150 + k * 300, oy = 320;
                    double scale = 0.16;
                    ren.Draw(tris, pose, emd.Texture, ox, oy - (int)(floor * scale), scale, 1);
                    using (var g = RD.Drawing.Graphics.FromImage(bmp))
                    {
                        float ly = (float)(oy - (floor - eye) * scale);
                        g.DrawLine(RD.Drawing.Pens.Lime, ox - 80, ly, ox + 80, ly);
                    }
                }
                bmp.Save(outPath, RD.Drawing.ImageFormat.Png);
            }
        }

        // Plain / light vest / heavy vest, front and side, in the idle pose.
        static void VestSheet(string who, string re1Usa, string outPath)
        {
            var files = Files(who);
            var emd = EmdFile.Read(System.IO.Path.Combine(re1Usa, "Enemy/" + files.Emd));
            var emw = EmwFile.Read(System.IO.Path.Combine(re1Usa, "Players/" + files.Weapons[0] + ".EMW"));
            var pose = Poser.Pose(emd.Skel, emw.Skel, emw.Anims.Anims[1][0]);
            using (var bmp = new RD.Drawing.Bitmap(6 * 150, 300))
            {
                using (var g = RD.Drawing.Graphics.FromImage(bmp)) g.Clear(RD.Drawing.Color.FromArgb(40, 40, 48));
                var ren = new SoftRenderer(bmp);
                for (int vest = 0; vest <= 2; vest++)
                {
                    var tris = ModelBuilder.Build(emd, null);
                    if (vest > 0) tris.AddRange(Vest.Make(emd, vest));
                    for (int view = 0; view < 2; view++)
                        ren.Draw(tris, pose, emd.Texture, 75 + (vest * 2 + view) * 150, 292, 0.09, view);
                }
                bmp.Save(outPath, RD.Drawing.ImageFormat.Png);
            }
            Console.WriteLine("Wrote " + outPath);
        }

        // One row per animation: 6 frames spread over it seen from the front,        // then the first frame from the side.
        static void Sheet(string emdPath, string emwPath, string outPath)
        {
            var emd = EmdFile.Read(emdPath);
            var v = Environment.GetEnvironmentVariable("RE1_VARIANT");
            if (!string.IsNullOrEmpty(v)) Mat.Variant = int.Parse(v);
            Skeleton frames = emd.Skel; AnimSet anims = emd.Anims; Tmd arm = null;
            if (emwPath != "-")
            {
                var emw = EmwFile.Read(emwPath);
                frames = emw.Skel; anims = emw.Anims; arm = emw.WeaponArm;
            }
            var tris = ModelBuilder.Build(emd, arm);
            int rows = anims.Anims.Count, cols = 7, cw = 110, ch = 170;
            double scale = 0.07;
            using (var bmp = new RD.Drawing.Bitmap(cols * cw + 40, rows * ch))
            {
                using (var g = RD.Drawing.Graphics.FromImage(bmp))
                {
                    g.Clear(RD.Drawing.Color.FromArgb(40, 40, 48));
                    for (int r = 0; r < rows; r++)
                        g.DrawString(r.ToString(), new RD.Drawing.Font("Arial", 10), RD.Drawing.Brushes.White, 2, r * ch + 4);
                }
                var ren = new SoftRenderer(bmp);
                for (int r = 0; r < rows; r++)
                {
                    var a = anims.Anims[r];
                    for (int c = 0; c < cols; c++)
                    {
                        int step = c < 6 ? (a.Count - 1) * c / 5 : 0;
                        var pose = Poser.Pose(emd.Skel, frames, a[step]);
                        ren.Draw(tris, pose, emd.Texture, 40 + c * cw + cw / 2, r * ch + ch - 12, scale, c < 6 ? 0 : 1);
                    }
                }
                bmp.Save(outPath, RD.Drawing.ImageFormat.Png);
            }
            Console.WriteLine("Wrote " + outPath);
        }

        static void Info(string path)
        {
            bool emw = path.EndsWith(".emw", StringComparison.OrdinalIgnoreCase);
            Skeleton skel; AnimSet anims; Tmd mesh; Tim tex = null;
            if (emw)
            {
                var e = EmwFile.Read(path);
                skel = e.Skel; anims = e.Anims; mesh = e.WeaponArm;
            }
            else
            {
                var e = EmdFile.Read(path);
                skel = e.Skel; anims = e.Anims; mesh = e.Mesh; tex = e.Texture;
            }

            Console.WriteLine("Skeleton: {0} joints, {1} bytes per frame", skel.JointCount, skel.FrameStride);
            for (int j = 0; j < skel.JointCount; j++)
                Console.WriteLine("  joint {0,2}: offset ({1,5},{2,5},{3,5}) children [{4}]", j,
                    skel.Offsets[j, 0], skel.Offsets[j, 1], skel.Offsets[j, 2], string.Join(",", skel.Children[j]));

            Console.WriteLine("Animations: {0}", anims.Anims.Count);
            for (int i = 0; i < anims.Anims.Count; i++)
            {
                var a = anims.Anims[i];
                Console.WriteLine("  anim {0,2}: {1,3} frames (stored frames {2}..{3})", i, a.Count,
                    a.Count > 0 ? a.Min() : -1, a.Count > 0 ? a.Max() : -1);
            }

            if (mesh != null)
            {
                Console.WriteLine("Mesh: {0} objects", mesh.Objects.Count);
                for (int o = 0; o < mesh.Objects.Count; o++)
                    Console.WriteLine("  object {0,2}: {1,4} vertices, {2,4} textured polygons", o,
                        mesh.Objects[o].Verts.Count, mesh.Objects[o].Prims.Count);
                Console.WriteLine("  primitive kinds (mode/flag: count):");
                foreach (var kv in mesh.ModeCounts.OrderBy(k => k.Key))
                    Console.WriteLine("    mode 0x{0:X2} flag 0x{1:X2}: {2}", kv.Key >> 8, kv.Key & 0xFF, kv.Value);
                var pages = mesh.Objects.SelectMany(o => o.Prims).Select(p => p.TPage).Distinct();
                var cluts = mesh.Objects.SelectMany(o => o.Prims).Select(p => p.Clut).Distinct();
                Console.WriteLine("  texture pages used: " + string.Join(", ", pages.Select(p => "0x" + p.ToString("X4"))));
                Console.WriteLine("  palettes used:      " + string.Join(", ", cluts.Select(p => "0x" + p.ToString("X4"))));
            }

            if (tex != null)
                Console.WriteLine("Texture: {0}x{1}, {2}-bit, palette block {3}x{4} at ({5},{6}), image at ({7},{8})",
                    tex.Width, tex.Height, tex.Bpp, tex.ClutW, tex.ClutH, tex.ClutX, tex.ClutY, tex.ImgX, tex.ImgY);
        }
    }
}
