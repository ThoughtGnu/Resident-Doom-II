// Formats.cs - readers for Resident Evil 1 (PC, 1997) model files.
//
// Every layout here follows the RE1 PC decomp in reference/re1-decomp:
//   EMD file directory  - EntityModelLoader.cpp, LoadEntityEMD
//   EMW file directory  - EntityModelLoader.cpp, LoadEquippedWeaponAnimation
//   skeleton / frames   - PlayerAnimations.cpp, Joint_move
//   joint hierarchy     - GteMatrix.cpp, EntityComputeJointWorldMatrices / rotate_entity
//   rotation matrix     - GteMatrix.cpp, RotMatrix / GteRotationMatrixCalc
// TMD (mesh) and TIM (texture) are the standard PlayStation formats.

using System;
using System.Collections.Generic;
using System.IO;

namespace Re1Convert
{
    static class Bin
    {
        public static ushort U16(byte[] b, int o) { return BitConverter.ToUInt16(b, o); }
        public static short S16(byte[] b, int o) { return BitConverter.ToInt16(b, o); }
        public static uint U32(byte[] b, int o) { return BitConverter.ToUInt32(b, o); }
        public static int S32(byte[] b, int o) { return BitConverter.ToInt32(b, o); }
    }

    // ------------------------------------------------------------------
    // Skeleton + animation frames ("animHeader" in the decomp).
    //   +0 u16  offset of the joint hierarchy
    //   +2 u16  offset of the frame data
    //   +4 u16  joint count
    //   +6 u16  bytes per frame
    //   +8      joint offsets from their parent: count x (x, y, z) shorts
    // Hierarchy: per joint 4 bytes {u8 childCount, pad, u16 childListOffset},
    // child lists are bytes of joint indices (offsets from the hierarchy start).
    // Frame: 6 shorts (root x, y, z, then 3 unused here), then 3 shorts of
    // rotation (x, y, z; 4096 = full turn) per joint.
    // ------------------------------------------------------------------
    class Skeleton
    {
        public int JointCount;
        public int FrameStride;
        public short[,] Offsets;          // [joint, xyz]
        public List<int>[] Children;
        public byte[] Data;
        public int Base;                  // where this skeleton starts in Data
        public int FrameDataOffset;

        public static Skeleton Read(byte[] b, int at)
        {
            var s = new Skeleton { Data = b, Base = at };
            int hier = Bin.U16(b, at + 0) & ~3;
            s.FrameDataOffset = Bin.U16(b, at + 2) & ~3;
            s.JointCount = Bin.U16(b, at + 4);
            s.FrameStride = Bin.U16(b, at + 6);
            s.Offsets = new short[s.JointCount, 3];
            for (int j = 0; j < s.JointCount; j++)
                for (int k = 0; k < 3; k++)
                    s.Offsets[j, k] = Bin.S16(b, at + 8 + j * 6 + k * 2);
            s.Children = new List<int>[s.JointCount];
            for (int j = 0; j < s.JointCount; j++)
            {
                s.Children[j] = new List<int>();
                int count = b[at + hier + j * 4];
                int list = Bin.U16(b, at + hier + j * 4 + 2);
                for (int c = 0; c < count; c++) s.Children[j].Add(b[at + hier + list + c]);
            }
            return s;
        }

        public int FrameCountInData(int limit)
        {
            return (limit - FrameDataOffset) / FrameStride;
        }

        // Root translation and per-joint rotations for one stored frame.
        public void GetFrame(int frame, out short[] root, out short[,] rot)
        {
            int at = Base + FrameDataOffset + frame * FrameStride;
            root = new short[] { Bin.S16(Data, at), Bin.S16(Data, at + 2), Bin.S16(Data, at + 4) };
            rot = new short[JointCount, 3];
            for (int j = 0; j < JointCount; j++)
                for (int k = 0; k < 3; k++)
                    rot[j, k] = Bin.S16(Data, at + 12 + j * 6 + k * 2);
        }
    }

    // Animation list ("animBase"): per animation {u16 frameCount, u16 offset},
    // and at that offset frameCount entries of {u16 frameIndex, u16 holdTicks}.
    class AnimSet
    {
        public List<List<int>> Anims = new List<List<int>>();   // stored frame index per step
        public List<List<int>> Holds = new List<List<int>>();   // ticks each step is held (Joint_move timing)

        public static AnimSet Read(byte[] b, int at)
        {
            var a = new AnimSet();
            int firstOffset = Bin.U16(b, at + 2);
            int count = firstOffset / 4;
            for (int i = 0; i < count; i++)
            {
                int frames = Bin.U16(b, at + i * 4);
                int off = Bin.U16(b, at + i * 4 + 2) & ~3;
                var list = new List<int>();
                var holds = new List<int>();
                for (int f = 0; f < frames; f++)
                {
                    list.Add(Bin.U16(b, at + off + f * 4));
                    holds.Add(Bin.U16(b, at + off + f * 4 + 2));
                }
                a.Anims.Add(list);
                a.Holds.Add(holds);
            }
            return a;
        }

        // Stored frame for every game tick: a step with hold > 1 is shown for
        // that many ticks (Joint_move waits while timing_control > 1).
        public List<int> TickFrames(int anim)
        {
            var o = new List<int>();
            for (int i = 0; i < Anims[anim].Count; i++)
            {
                int n = Math.Max(1, Holds[anim][i]);
                for (int k = 0; k < n; k++) o.Add(Anims[anim][i]);
            }
            return o;
        }
    }

    // ------------------------------------------------------------------
    // PlayStation TMD mesh. One "object" per joint.
    // ------------------------------------------------------------------
    class TmdPrim
    {
        public int Mode, Flag;
        public int[] Verts;               // 3 or 4 vertex indices
        public int[] U, V;                // texture coords (0..255 inside the page)
        public int Clut, TPage;           // raw cba / tsb
        public bool Textured;
    }

    class TmdObject
    {
        public List<short[]> Verts = new List<short[]>();
        public List<TmdPrim> Prims = new List<TmdPrim>();
    }

    class Tmd
    {
        public List<TmdObject> Objects = new List<TmdObject>();
        public Dictionary<int, int> ModeCounts = new Dictionary<int, int>();

        // 'at' points at the TMD header (id 0x41, flags, object count).
        public static Tmd Read(byte[] b, int at)
        {
            var t = new Tmd();
            int nobj = Bin.S32(b, at + 8);
            int table = at + 12;
            for (int o = 0; o < nobj; o++)
            {
                int e = table + o * 28;
                int vTop = Bin.S32(b, e), nVert = Bin.S32(b, e + 4);
                int pTop = Bin.S32(b, e + 16), nPrim = Bin.S32(b, e + 20);
                var obj = new TmdObject();
                for (int v = 0; v < nVert; v++)
                {
                    int p = table + vTop + v * 8;
                    obj.Verts.Add(new short[] { Bin.S16(b, p), Bin.S16(b, p + 2), Bin.S16(b, p + 4) });
                }
                int q = table + pTop;
                for (int i = 0; i < nPrim; i++)
                {
                    int olen = b[q], ilen = b[q + 1], flag = b[q + 2], mode = b[q + 3];
                    int key = (mode << 8) | flag;
                    int n; t.ModeCounts.TryGetValue(key, out n); t.ModeCounts[key] = n + 1;
                    var prim = DecodePrim(b, q + 4, mode, flag);
                    if (prim != null) obj.Prims.Add(prim);
                    q += 4 + ilen * 4;
                }
                t.Objects.Add(obj);
            }
            return t;
        }

        // Standard TMD packet layouts (PlayStation "File Formats" manual).
        // Only the kinds RE1 character models use are decoded; anything else
        // is reported by the "info" command and skipped.
        static TmdPrim DecodePrim(byte[] b, int p, int mode, int flag)
        {
            int code = mode & 0xFC;
            bool gouraud = (mode & 0x10) != 0;
            bool quad = (mode & 0x08) != 0;
            bool textured = (mode & 0x04) != 0;
            bool lit = (flag & 0x01) == 0;        // light source calculation on
            if ((mode & 0xE0) != 0x20) return null; // not a polygon
            if (!textured || !lit) return null;     // RE1 models: textured + lit

            var pr = new TmdPrim { Mode = mode, Flag = flag, Textured = true };
            int corners = quad ? 4 : 3;
            pr.U = new int[corners]; pr.V = new int[corners];
            // uv block: u0 v0 cba | u1 v1 tsb | u2 v2 pad | (u3 v3 pad)
            pr.U[0] = b[p]; pr.V[0] = b[p + 1]; pr.Clut = Bin.U16(b, p + 2);
            pr.U[1] = b[p + 4]; pr.V[1] = b[p + 5]; pr.TPage = Bin.U16(b, p + 6);
            pr.U[2] = b[p + 8]; pr.V[2] = b[p + 9];
            int after = p + 12;
            if (quad) { pr.U[3] = b[p + 12]; pr.V[3] = b[p + 13]; after = p + 16; }
            // then normals and vertices as u16: flat = n0 v0 v1 v2 (v3),
            // gouraud = n0 v0 n1 v1 n2 v2 (n3 v3)
            pr.Verts = new int[corners];
            for (int c = 0; c < corners; c++)
            {
                if (gouraud) pr.Verts[c] = Bin.U16(b, after + c * 4 + 2);
                else pr.Verts[c] = Bin.U16(b, after + 2 + c * 2);
            }
            return pr;
        }
    }

    // ------------------------------------------------------------------
    // PlayStation TIM texture.
    // ------------------------------------------------------------------
    class Tim
    {
        public int Bpp;                   // 4, 8 or 16
        public int ClutX, ClutY, ClutW, ClutH;
        public ushort[] Clut;             // ClutW * ClutH colours (ABGR1555)
        public int ImgX, ImgY, Width, Height;   // Width in pixels
        public byte[] Pixels;             // raw image block

        public static Tim Read(byte[] b, int at)
        {
            var t = new Tim();
            int flags = Bin.S32(b, at + 4);
            int pmode = flags & 3;
            t.Bpp = pmode == 0 ? 4 : pmode == 1 ? 8 : 16;
            int p = at + 8;
            if ((flags & 8) != 0)
            {
                int len = Bin.S32(b, p);
                t.ClutX = Bin.U16(b, p + 4); t.ClutY = Bin.U16(b, p + 6);
                t.ClutW = Bin.U16(b, p + 8); t.ClutH = Bin.U16(b, p + 10);
                t.Clut = new ushort[t.ClutW * t.ClutH];
                for (int i = 0; i < t.Clut.Length; i++) t.Clut[i] = Bin.U16(b, p + 12 + i * 2);
                p += len;
            }
            int ilen = Bin.S32(b, p);
            t.ImgX = Bin.U16(b, p + 4); t.ImgY = Bin.U16(b, p + 6);
            int wHalfwords = Bin.U16(b, p + 8);
            t.Height = Bin.U16(b, p + 10);
            t.Width = wHalfwords * (t.Bpp == 4 ? 4 : t.Bpp == 8 ? 2 : 1);
            t.Pixels = new byte[ilen - 12];
            Array.Copy(b, p + 12, t.Pixels, 0, t.Pixels.Length);
            return t;
        }

        // Palette index of pixel (x, y).
        public int Index(int x, int y)
        {
            if (Bpp == 8) return Pixels[y * Width + x];
            int bt = Pixels[(y * Width + x) / 2];
            return (x & 1) == 0 ? (bt & 15) : (bt >> 4);
        }

        public static void ToRgba(ushort c, out byte r, out byte g, out byte b, out byte a)
        {
            r = (byte)((c & 31) * 255 / 31);
            g = (byte)(((c >> 5) & 31) * 255 / 31);
            b = (byte)(((c >> 10) & 31) * 255 / 31);
            a = (byte)(c == 0 ? 0 : 255);   // colour 0x0000 is see-through on the PS1
        }
    }

    // ------------------------------------------------------------------
    // RE1 file directories.
    // ------------------------------------------------------------------
    class EmdFile
    {
        public Skeleton Skel;
        public AnimSet Anims;
        public Tmd Mesh;
        public Tim Texture;

        // The last 5 dwords of an EMD: {extra, skeleton, anims, TMD, TIM}.
        public static EmdFile Read(string path)
        {
            byte[] b = Fs.ReadAllBytes(path);
            int dir = (b.Length & ~3) - 0x14;
            int skel = (int)(Bin.U32(b, dir + 4) & ~3u);
            int anim = (int)(Bin.U32(b, dir + 8) & ~3u);
            int tmd = (int)(Bin.U32(b, dir + 12) & ~3u);
            int tim = (int)(Bin.U32(b, dir + 16) & ~3u);
            return new EmdFile
            {
                Skel = Skeleton.Read(b, skel),
                Anims = AnimSet.Read(b, anim),
                Mesh = Tmd.Read(b, tmd),
                Texture = Tim.Read(b, tim),
            };
        }
    }

    class EmwFile
    {
        public Skeleton Skel;
        public AnimSet Anims;
        public Tmd WeaponArm;      // replaces joint 14 (null for the unarmed set)

        // Skeleton at 0; the last 2 dwords: {anims, weapon-arm TMD}.
        public static EmwFile Read(string path)
        {
            byte[] b = Fs.ReadAllBytes(path);
            int tail = (b.Length & ~3) - 8;
            int anim = (int)(Bin.U32(b, tail) & ~3u);
            int arm = (int)(Bin.U32(b, tail + 4) & ~3u);
            var e = new EmwFile { Skel = Skeleton.Read(b, 0), Anims = AnimSet.Read(b, anim) };
            if (arm > 0 && arm < b.Length && Bin.U32(b, arm) == 0x41) e.WeaponArm = Tmd.Read(b, arm);
            return e;
        }
    }
}
