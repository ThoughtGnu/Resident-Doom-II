// Pose.cs - places every joint of an RE1 skeleton for one animation frame.
//
// Port of the decomp's math:
//   rotation:  GteMatrix.cpp RotMatrix -> GteRotationMatrixCalc, called with
//              (0x1000 - rx, ry, 0x1000 - rz)
//   hierarchy: GteMatrix.cpp EntityComputeJointWorldMatrices / rotate_entity:
//              world(child) = world(parent) * local(child)
//   local:     rotation from the frame; translation = the joint's offset from
//              the EMD skeleton (ResetJointTransforms), except joint 0, whose
//              translation is the frame's root offset (Joint_move).
// Angles: 4096 = full turn. All in RE1 units (Y points down).

using System;

namespace Re1Convert
{
    struct Mat
    {
        public double[] R;   // 3x3, row-major
        public double[] T;   // translation

        public static Mat Identity()
        {
            return new Mat { R = new double[] { 1, 0, 0, 0, 1, 0, 0, 0, 1 }, T = new double[3] };
        }

        // Angle convention. The decomp's RotMatrix calls GteRotationMatrixCalc
        // with (0x1000 - x, y, 0x1000 - z); taken literally that spreads Jill's
        // arms sideways when she aims. Using x and z as stored (variant 2)
        // gives RE1's real aiming stance (both hands on the gun, arms forward),
        // checked by rendering all four variants side by side
        // ("re1convert sheet" with RE1_VARIANT=0..3). The decomp presumably
        // undoes the flip elsewhere in its renderer.
        public static int Variant = 2;

        // RotMatrix: the decomp's GteRotationMatrixCalc, in floating point.
        public static Mat FromRe1Angles(int rx, int ry, int rz)
        {
            if (Variant == 2 || Variant == 3) { rx = 0x1000 - rx; rz = 0x1000 - rz; }
            var m0 = FromRe1AnglesRaw(rx, ry, rz);
            if (Variant == 1 || Variant == 3)
            {
                var t = Identity();
                for (int r = 0; r < 3; r++) for (int c = 0; c < 3; c++) t.R[r * 3 + c] = m0.R[c * 3 + r];
                return t;
            }
            return m0;
        }

        static Mat FromRe1AnglesRaw(int rx, int ry, int rz)
        {
            const double k = Math.PI * 2 / 4096.0;
            double ax = ((0x1000 - rx) & 0xFFF) * k, ay = (ry & 0xFFF) * k, az = ((0x1000 - rz) & 0xFFF) * k;
            double sx = Math.Sin(ax), cx = Math.Cos(ax);
            double sy = Math.Sin(ay), cy = Math.Cos(ay);
            double sz = Math.Sin(az), cz = Math.Cos(az);
            var m = Identity();
            m.R[0] = cz * cy;                   m.R[1] = -cy * sz;                  m.R[2] = sy;
            m.R[3] = sx * sy * cz + cx * sz;    m.R[4] = cx * cz - sx * sz * sy;    m.R[5] = -sx * cy;
            m.R[6] = sx * sz - cx * sy * cz;    m.R[7] = sz * sy * cx + sx * cz;    m.R[8] = cx * cy;
            return m;
        }

        // ApplyLVAndMul0Matrix: parent * local.
        public static Mat Mul(Mat p, Mat l)
        {
            var o = Identity();
            for (int r = 0; r < 3; r++)
            {
                for (int c = 0; c < 3; c++)
                    o.R[r * 3 + c] = p.R[r * 3] * l.R[c] + p.R[r * 3 + 1] * l.R[3 + c] + p.R[r * 3 + 2] * l.R[6 + c];
                o.T[r] = p.R[r * 3] * l.T[0] + p.R[r * 3 + 1] * l.T[1] + p.R[r * 3 + 2] * l.T[2] + p.T[r];
            }
            return o;
        }

        public double[] Apply(short[] v)
        {
            return new double[] {
                R[0] * v[0] + R[1] * v[1] + R[2] * v[2] + T[0],
                R[3] * v[0] + R[4] * v[1] + R[5] * v[2] + T[1],
                R[6] * v[0] + R[7] * v[1] + R[8] * v[2] + T[2] };
        }
    }

    static class Poser
    {
        // World matrix of every joint. 'bones' supplies the joint offsets and
        // hierarchy (always Jill's EMD skeleton); 'frames' supplies the frame
        // data (EMD or EMW).
        public static Mat[] Pose(Skeleton bones, Skeleton frames, int frame)
        {
            short[] root; short[,] rot;
            frames.GetFrame(frame, out root, out rot);
            var world = new Mat[bones.JointCount];
            var local = new Mat[bones.JointCount];
            for (int j = 0; j < bones.JointCount; j++)
            {
                local[j] = Mat.FromRe1Angles(rot[j, 0], rot[j, 1], rot[j, 2]);
                if (j == 0) local[j].T = new double[] { root[0], root[1], root[2] };
                else local[j].T = new double[] { bones.Offsets[j, 0], bones.Offsets[j, 1], bones.Offsets[j, 2] };
            }
            world[0] = local[0];
            Walk(bones, 0, world, local);
            return world;
        }

        static void Walk(Skeleton s, int j, Mat[] world, Mat[] local)
        {
            foreach (int c in s.Children[j])
            {
                world[c] = Mat.Mul(world[j], local[c]);
                Walk(s, c, world, local);
            }
        }
    }
}
