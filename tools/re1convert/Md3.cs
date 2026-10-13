// Md3.cs - writes a first-person "view arm" as an MD3 model (vertex
// animation), which GZDoom can draw in place of a weapon sprite.
//
// The arm is Jill's own: her upper arm, forearm and the weapon hand from the
// EMW file (joints 12, 13, 14), posed by RE1's own animations and seen from
// her eyes. Model axes: X forward, Y left, Z up, origin at her eyes, in map
// units (32 RE1 units = 1 map unit, like Iqm.cs).

using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace Re1Convert
{
    static class Md3Writer
    {
        // frames[f][v] = position of vertex v in frame f (3 vertices per triangle).
        // texW / texH: the skin picture's size when it isn't the characters'
        // atlas (palette rows plus the vest band); mirrored: the view arms are
        // drawn mirrored, other models (the item box) aren't.
        public static void Write(string path, List<Tri> tris, List<double[][]> frames, Tim tim, string skin,
            int texW = 0, int texH = 0, bool mirrored = true)
        {
            int nv = tris.Count * 3, nf = frames.Count;
            int atlasH = texH > 0 ? texH : tim.Height * tim.ClutH + Vest.BandHeight;   // same atlas as the IQMs
            int atlasW = texW > 0 ? texW : tim.Width;
            using (var ms = new MemoryStream())
            using (var w = new BinaryWriter(ms))
            {
                Func<int> Here = () => (int)ms.Position;
                // --- header (108 bytes), filled in later
                w.Write(new byte[108]);

                // --- frames: bounds, origin, radius, name
                int ofsFrames = Here();
                foreach (var fr in frames)
                {
                    double[] lo = { 1e9, 1e9, 1e9 }, hi = { -1e9, -1e9, -1e9 }; double r = 0;
                    foreach (var p in fr)
                        for (int k = 0; k < 3; k++) { lo[k] = Math.Min(lo[k], p[k]); hi[k] = Math.Max(hi[k], p[k]); }
                    foreach (var p in fr) r = Math.Max(r, Math.Sqrt(p[0] * p[0] + p[1] * p[1] + p[2] * p[2]));
                    foreach (var v in lo) w.Write((float)v);
                    foreach (var v in hi) w.Write((float)v);
                    w.Write(0f); w.Write(0f); w.Write(0f);
                    w.Write((float)r);
                    Name(w, "frame", 16);
                }

                // --- one surface
                int ofsSurf = Here();
                w.Write(Encoding.ASCII.GetBytes("IDP3"));
                Name(w, "arm", 64);
                w.Write(0); w.Write(nf); w.Write(1); w.Write(nv); w.Write(tris.Count);
                int fix = Here();
                w.Write(new byte[5 * 4]);   // ofs_triangles, ofs_shaders, ofs_st, ofs_xyznormal, ofs_end
                int sTris = Here() - ofsSurf;
                // reversed order: the view arm is mirrored (see ViewArm)
                for (int t = 0; t < tris.Count; t++)
                {
                    w.Write(t * 3);
                    if (mirrored) { w.Write(t * 3 + 2); w.Write(t * 3 + 1); } else { w.Write(t * 3 + 1); w.Write(t * 3 + 2); }
                }
                int sShaders = Here() - ofsSurf;
                Name(w, skin, 64); w.Write(0);
                int sSt = Here() - ofsSurf;
                foreach (var tr in tris)
                    for (int c = 0; c < 3; c++)
                    {
                        w.Write((float)(tr.U[c] / atlasW));
                        w.Write((float)((tr.W[c] + tr.Palette * tim.Height) / atlasH));
                    }
                int sXyz = Here() - ofsSurf;
                foreach (var fr in frames)
                    for (int t = 0; t < tris.Count; t++)
                    {
                        var a = fr[t * 3]; var b = fr[t * 3 + 1]; var c = fr[t * 3 + 2];
                        double ux = b[0] - a[0], uy = b[1] - a[1], uz = b[2] - a[2];
                        double vx = c[0] - a[0], vy = c[1] - a[1], vz = c[2] - a[2];
                        double nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
                        double nl = Math.Sqrt(nx * nx + ny * ny + nz * nz); if (nl < 1e-9) nl = 1;
                        nx /= nl; ny /= nl; nz /= nl;
                        int lat = (int)Math.Round(Math.Atan2(ny, nx) * 255 / (2 * Math.PI)) & 255;
                        int lng = (int)Math.Round(Math.Acos(Math.Max(-1, Math.Min(1, nz))) * 255 / (2 * Math.PI)) & 255;
                        foreach (var p in new[] { a, b, c })
                        {
                            for (int k = 0; k < 3; k++) w.Write((short)Math.Round(p[k] * 64));
                            w.Write((short)((lat << 8) | lng));
                        }
                    }
                int sEnd = Here() - ofsSurf;
                int eof = Here();
                ms.Position = fix;
                w.Write(sTris); w.Write(sShaders); w.Write(sSt); w.Write(sXyz); w.Write(sEnd);

                ms.Position = 0;
                w.Write(Encoding.ASCII.GetBytes("IDP3")); w.Write(15);
                Name(w, Path.GetFileNameWithoutExtension(path), 64);
                w.Write(0); w.Write(nf); w.Write(0); w.Write(1); w.Write(0);
                w.Write(ofsFrames); w.Write(ofsSurf); w.Write(ofsSurf); w.Write(eof);
                File.WriteAllBytes(path, ms.ToArray());
            }
        }

        static void Name(BinaryWriter w, string s, int len)
        {
            var b = new byte[len];
            var src = Encoding.ASCII.GetBytes(s);
            Array.Copy(src, b, Math.Min(src.Length, len - 1));
            w.Write(b);
        }
    }
}
