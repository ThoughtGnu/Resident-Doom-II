// Iqm.cs - writes Jill as an IQM model (Inter-Quake Model, version 2), the
// skeletal format GZDoom plays with Actor.SetAnimation.
//
// RE1 models are rigid: every vertex belongs to exactly one joint, so each
// vertex gets one bone with weight 1.0. Bone poses are RE1's own per-frame
// joint rotations (see Pose.cs), converted to GZDoom axes:
//   RE1:    X forward, Y down,  Z sideways
//   GZDoom: X forward, Z up,    Y sideways
//   (x, y, z)_doom = (x, z, -y)_re1 / 32   (32 RE1 units = 1 map unit)

using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace Re1Convert
{
    class IqmAnim
    {
        public string Name;
        public Skeleton Frames;        // where the frame data lives (EMD or EMW)
        public List<int> TickFrames;   // stored frame for every 30 Hz tick
        public bool Loop;
        public List<PoseFrame> Custom; // or: made-up frames (Crouch.cs), one per tick
        public int Count { get { return Custom != null ? Custom.Count : TickFrames.Count; } }
    }

    // A frame given directly: root offset and each joint's local rotation
    // (3x3, row-major), all in RE1 space.
    class PoseFrame
    {
        public double[] Root;
        public double[][] R;
    }

    static class IqmWriter
    {
        const double Scale = 1.0 / 32.0;

        // RE1 -> GZDoom axes for points.
        static double[] P(double x, double y, double z) { return new[] { x * Scale, z * Scale, -y * Scale }; }

        // RE1 -> GZDoom for a rotation: C * R * C^T with C = [[1,0,0],[0,0,1],[0,-1,0]].
        static double[] Rot(double[] r)
        {
            // rows of C*R: row0 = R row0, row1 = R row2, row2 = -R row1
            double[] cr = { r[0], r[1], r[2], r[6], r[7], r[8], -r[3], -r[4], -r[5] };
            // (C*R)*C^T: column0 = col0, column1 = -col2, column2 = col1   (C^T maps y<-z...)
            var o = new double[9];
            for (int row = 0; row < 3; row++)
            {
                o[row * 3 + 0] = cr[row * 3 + 0];
                o[row * 3 + 1] = cr[row * 3 + 2];
                o[row * 3 + 2] = -cr[row * 3 + 1];
            }
            return o;
        }

        static double[] Quat(double[] m)
        {
            double tr = m[0] + m[4] + m[8], x, y, z, w;
            if (tr > 0)
            {
                double s = Math.Sqrt(tr + 1.0) * 2;
                w = 0.25 * s; x = (m[7] - m[5]) / s; y = (m[2] - m[6]) / s; z = (m[3] - m[1]) / s;
            }
            else if (m[0] > m[4] && m[0] > m[8])
            {
                double s = Math.Sqrt(1.0 + m[0] - m[4] - m[8]) * 2;
                w = (m[7] - m[5]) / s; x = 0.25 * s; y = (m[1] + m[3]) / s; z = (m[2] + m[6]) / s;
            }
            else if (m[4] > m[8])
            {
                double s = Math.Sqrt(1.0 + m[4] - m[0] - m[8]) * 2;
                w = (m[2] - m[6]) / s; x = (m[1] + m[3]) / s; y = 0.25 * s; z = (m[5] + m[7]) / s;
            }
            else
            {
                double s = Math.Sqrt(1.0 + m[8] - m[0] - m[4]) * 2;
                w = (m[3] - m[1]) / s; x = (m[2] + m[6]) / s; y = (m[5] + m[7]) / s; z = 0.25 * s;
            }
            if (w < 0) { x = -x; y = -y; z = -z; w = -w; }   // keep one hemisphere
            return new[] { x, y, z, w };
        }

        // 'alt': a second TIM, drawn under the first in the atlas (WriteAtlas),
        // for triangles marked Alt (another character's weapon arm).
        public static void Write(string path, EmdFile emd, List<Tri> tris, List<IqmAnim> anims, string material, Tim alt = null)
        {
            var bones = emd.Skel;
            int nj = bones.JointCount;
            var tim = emd.Texture;
            int topH = tim.Height * tim.ClutH + Vest.BandHeight;     // RE1 palettes + the vest band
            int atlasH = topH + (alt != null ? alt.Height * alt.ClutH : 0);
            int atlasW = alt != null ? Math.Max(tim.Width, alt.Width) : tim.Width;

            // --- text block -------------------------------------------------
            var text = new List<byte> { 0 };
            Func<string, uint> AddText = s =>
            {
                uint at = (uint)text.Count;
                text.AddRange(Encoding.ASCII.GetBytes(s)); text.Add(0);
                return at;
            };
            uint meshName = AddText("jill"), matName = AddText(material);
            var jointNames = new uint[nj];
            for (int j = 0; j < nj; j++) jointNames[j] = AddText("joint" + j);
            var animNames = new uint[anims.Count];
            for (int a = 0; a < anims.Count; a++) animNames[a] = AddText(anims[a].Name);

            // --- parents and bind pose (joint offsets, no rotation) -------------
            var parent = new int[nj];
            for (int j = 0; j < nj; j++) parent[j] = -1;
            for (int j = 0; j < nj; j++) foreach (int c in bones.Children[j]) parent[c] = j;
            var bindT = new double[nj][];
            var bindWorld = new double[nj][];
            for (int j = 0; j < nj; j++)
            {
                bindT[j] = P(bones.Offsets[j, 0], bones.Offsets[j, 1], bones.Offsets[j, 2]);
                bindWorld[j] = parent[j] < 0 ? bindT[j]
                    : new[] { bindWorld[parent[j]][0] + bindT[j][0], bindWorld[parent[j]][1] + bindT[j][1], bindWorld[parent[j]][2] + bindT[j][2] };
            }
            // RE1 hierarchy lists children after parents? Be safe: recompute in tree order.
            Action<int> walk = null;
            walk = j => { foreach (int c in bones.Children[j]) { bindWorld[c] = new[] { bindWorld[j][0] + bindT[c][0], bindWorld[j][1] + bindT[c][1], bindWorld[j][2] + bindT[c][2] }; walk(c); } };
            bindWorld[0] = bindT[0]; walk(0);

            // --- vertices: 3 per triangle -----------------------------------
            int nv = tris.Count * 3;
            var pos = new float[nv * 3]; var uv = new float[nv * 2]; var nrm = new float[nv * 3];
            var bIdx = new byte[nv * 4]; var bW = new byte[nv * 4];
            for (int t = 0; t < tris.Count; t++)
            {
                var tr = tris[t];
                var p3 = new double[3][];
                for (int c = 0; c < 3; c++)
                {
                    var lp = P(tr.V[c][0], tr.V[c][1], tr.V[c][2]);
                    p3[c] = new[] { lp[0] + bindWorld[tr.Joint][0], lp[1] + bindWorld[tr.Joint][1], lp[2] + bindWorld[tr.Joint][2] };
                }
                // face normal
                double ux = p3[1][0] - p3[0][0], uy = p3[1][1] - p3[0][1], uz = p3[1][2] - p3[0][2];
                double vx = p3[2][0] - p3[0][0], vy = p3[2][1] - p3[0][1], vz = p3[2][2] - p3[0][2];
                double nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
                double nl = Math.Sqrt(nx * nx + ny * ny + nz * nz); if (nl < 1e-9) nl = 1;
                for (int c = 0; c < 3; c++)
                {
                    int v = t * 3 + c;
                    for (int k = 0; k < 3; k++) pos[v * 3 + k] = (float)p3[c][k];
                    nrm[v * 3] = (float)(nx / nl); nrm[v * 3 + 1] = (float)(ny / nl); nrm[v * 3 + 2] = (float)(nz / nl);
                    uv[v * 2] = (float)(tr.U[c] / atlasW);
                    uv[v * 2 + 1] = tr.Alt && alt != null
                        ? (float)((topH + tr.W[c] + tr.Palette * alt.Height) / atlasH)
                        : (float)((tr.W[c] + tr.Palette * tim.Height) / atlasH);
                    bIdx[v * 4] = (byte)tr.Joint; bW[v * 4] = 255;
                }
            }

            // --- animation frames: local pose of every joint -------------------
            int numFrames = 0;
            foreach (var a in anims) numFrames += a.Count;
            var frameT = new double[numFrames, nj, 3];
            var frameQ = new double[numFrames, nj, 4];
            int fi = 0;
            foreach (var a in anims)
                for (int k2 = 0; k2 < a.Count; k2++)
                {
                    var pf = a.Custom != null ? a.Custom[k2] : Crouch.FromStored(a.Frames, a.TickFrames[k2]);
                    for (int j = 0; j < nj; j++)
                    {
                        var q = Quat(Rot(pf.R[j]));
                        var t = j == 0 ? P(pf.Root[0], pf.Root[1], pf.Root[2]) : bindT[j];
                        for (int k = 0; k < 3; k++) frameT[fi, j, k] = t[k];
                        for (int k = 0; k < 4; k++) frameQ[fi, j, k] = q[k];
                    }
                    fi++;
                }

            // Channel ranges per joint (10 channels: t xyz, q xyzw, s xyz).
            var chOff = new float[nj, 10]; var chScale = new float[nj, 10];
            for (int j = 0; j < nj; j++)
                for (int ch = 0; ch < 10; ch++)
                {
                    double lo = double.MaxValue, hi = double.MinValue;
                    for (int f = 0; f < numFrames; f++)
                    {
                        double v = Channel(frameT, frameQ, f, j, ch);
                        lo = Math.Min(lo, v); hi = Math.Max(hi, v);
                    }
                    if (numFrames == 0) { lo = hi = 0; }
                    chOff[j, ch] = (float)lo;
                    chScale[j, ch] = (float)((hi - lo) / 65535.0);
                }

            // --- assemble the file ------------------------------------------
            using (var ms = new MemoryStream())
            using (var w = new BinaryWriter(ms))
            {
                w.Write(new byte[124]);   // header, filled in at the end
                Func<int> Here = () => (int)ms.Position;

                int ofsText = Here(); w.Write(text.ToArray()); Pad(w);

                int ofsMeshes = Here();
                w.Write(meshName); w.Write(matName); w.Write(0u); w.Write((uint)nv); w.Write(0u); w.Write((uint)tris.Count);

                // vertex arrays: position, texcoord, normal, blend index, blend weight
                int ofsPos = 0, ofsUv = 0, ofsN = 0, ofsBi = 0, ofsBw = 0;
                int ofsVa = Here();
                w.Write(new byte[5 * 20]);
                ofsPos = Here(); foreach (var f in pos) w.Write(f);
                ofsUv = Here(); foreach (var f in uv) w.Write(f);
                ofsN = Here(); foreach (var f in nrm) w.Write(f);
                ofsBi = Here(); w.Write(bIdx);
                ofsBw = Here(); w.Write(bW); Pad(w);

                int ofsTris = Here();
                for (int t = 0; t < tris.Count; t++) { w.Write((uint)(t * 3)); w.Write((uint)(t * 3 + 1)); w.Write((uint)(t * 3 + 2)); }

                int ofsJoints = Here();
                for (int j = 0; j < nj; j++)
                {
                    w.Write(jointNames[j]); w.Write(parent[j]);
                    w.Write((float)bindT[j][0]); w.Write((float)bindT[j][1]); w.Write((float)bindT[j][2]);
                    w.Write(0f); w.Write(0f); w.Write(0f); w.Write(1f);
                    w.Write(1f); w.Write(1f); w.Write(1f);
                }

                int ofsPoses = Here();
                for (int j = 0; j < nj; j++)
                {
                    w.Write(parent[j]); w.Write(0x3FFu);
                    for (int ch = 0; ch < 10; ch++) w.Write(chOff[j, ch]);
                    for (int ch = 0; ch < 10; ch++) w.Write(chScale[j, ch]);
                }

                int ofsAnims = Here(); int first = 0;
                for (int a = 0; a < anims.Count; a++)
                {
                    w.Write(animNames[a]); w.Write((uint)first); w.Write((uint)anims[a].Count);
                    w.Write(30f); w.Write(anims[a].Loop ? 1u : 0u);
                    first += anims[a].Count;
                }

                int ofsFrames = Here();
                for (int f = 0; f < numFrames; f++)
                    for (int j = 0; j < nj; j++)
                        for (int ch = 0; ch < 10; ch++)
                        {
                            double v = Channel(frameT, frameQ, f, j, ch);
                            double s = chScale[j, ch];
                            int q = s > 0 ? (int)Math.Round((v - chOff[j, ch]) / s) : 0;
                            w.Write((ushort)Math.Max(0, Math.Min(65535, q)));
                        }
                Pad(w);
                int fileSize = Here();

                // vertex array table
                ms.Position = ofsVa;
                WriteVa(w, 0, 7, 3, ofsPos);   // POSITION, FLOAT
                WriteVa(w, 1, 7, 2, ofsUv);    // TEXCOORD, FLOAT
                WriteVa(w, 2, 7, 3, ofsN);     // NORMAL, FLOAT
                WriteVa(w, 4, 1, 4, ofsBi);    // BLENDINDEXES, UBYTE
                WriteVa(w, 5, 1, 4, ofsBw);    // BLENDWEIGHTS, UBYTE

                // header
                ms.Position = 0;
                w.Write(Encoding.ASCII.GetBytes("INTERQUAKEMODEL\0"));
                uint[] h = {
                    2, (uint)fileSize, 0,
                    (uint)text.Count, (uint)ofsText,
                    1, (uint)ofsMeshes,
                    5, (uint)nv, (uint)ofsVa,
                    (uint)tris.Count, (uint)ofsTris, 0,
                    (uint)nj, (uint)ofsJoints,
                    (uint)nj, (uint)ofsPoses,
                    (uint)anims.Count, (uint)ofsAnims,
                    (uint)numFrames, (uint)(nj * 10), (uint)ofsFrames, 0,
                    0, 0, 0, 0 };
                foreach (var x in h) w.Write(x);
                File.WriteAllBytes(path, ms.ToArray());
            }
        }

        static double Channel(double[,,] t, double[,,] q, int f, int j, int ch)
        {
            if (ch < 3) return t[f, j, ch];
            if (ch < 7) return q[f, j, ch - 3];
            return 1.0;
        }

        static void WriteVa(BinaryWriter w, uint type, uint format, uint size, int offset)
        {
            w.Write(type); w.Write(0u); w.Write(format); w.Write(size); w.Write((uint)offset);
        }

        static void Pad(BinaryWriter w)
        {
            while (w.BaseStream.Position % 4 != 0) w.Write((byte)0);
        }

        // The TIM drawn once per palette, stacked top to bottom, as a PNG.
        // With 'alt': that TIM's palettes stacked the same way below (IqmWriter.Write).
        public static void WriteAtlas(string path, Tim tim, Tim alt = null)
        {
            int topH = tim.Height * tim.ClutH + Vest.BandHeight;
            using (var bmp = new RD.Drawing.Bitmap(alt != null ? Math.Max(tim.Width, alt.Width) : tim.Width,
                topH + (alt != null ? alt.Height * alt.ClutH : 0), RD.Drawing.PixelFormat.Format32bppArgb))
            {
                if (alt != null)
                    for (int pal = 0; pal < alt.ClutH; pal++)
                        for (int y = 0; y < alt.Height; y++)
                            for (int x = 0; x < alt.Width; x++)
                            {
                                ushort c = alt.Clut[pal * alt.ClutW + alt.Index(x, y)];
                                byte r, g, b, a;
                                Tim.ToRgba(c, out r, out g, out b, out a);
                                bmp.SetPixel(x, topH + y + pal * alt.Height, RD.Drawing.Color.FromArgb(a, r, g, b));
                            }
                // the vest band (Vest.cs) under the RE1 texture
                for (int y = 0; y < Vest.BandHeight; y++)
                    for (int x = 0; x < tim.Width; x++)
                        bmp.SetPixel(x, tim.Height * tim.ClutH + y, Vest.Pixel(tim.Width, x, y));
                for (int pal = 0; pal < tim.ClutH; pal++)
                    for (int y = 0; y < tim.Height; y++)
                        for (int x = 0; x < tim.Width; x++)
                        {
                            ushort c = tim.Clut[pal * tim.ClutW + tim.Index(x, y)];
                            byte r, g, b, a;
                            Tim.ToRgba(c, out r, out g, out b, out a);
                            bmp.SetPixel(x, y + pal * tim.Height, RD.Drawing.Color.FromArgb(a, r, g, b));
                        }
                bmp.Save(path, RD.Drawing.ImageFormat.Png);
            }
        }
    }
}
