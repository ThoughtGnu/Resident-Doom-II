// ---------------------------------------------------------------------------
// RE_Corpses.zs - Flat corpses (Settings > Gameplay, re_flat_corpses).
//
// Doom draws a dead monster's last picture (its corpse or gibs) as a normal
// sprite that always turns to face the camera, so in first person a body spins
// as you walk round it. With this on, that last picture is laid flat on the
// floor (GZDoom's flat sprite) and stays put in the world.
//   0 off (Doom's corpses), 1 first person only, 2 both views
// Only dead things on their final picture (a frame that lasts forever) that
// are resting on the floor are laid down; the death fall plays as before and a
// live monster is never touched. One brought back by an Arch-Vile stands up
// again at once. The map's ready-placed dead bodies get the same treatment.
//
// Direction: the body lies along the killing hit, head end away from whoever
// or whatever killed it (the attacker, the projectile's flight, or away from
// an explosion's centre). Doom's corpse pictures are drawn from the side, so
// HeadSide below says for each final picture which end is the head. The
// picture is spun a quarter turn (roll 90) so its head-to-feet line runs
// along the actor's facing, which is also the line a tilt (pitch) follows.
// Map-placed bodies keep their placed angle.
//
// Fitting: the picture must lie fully on the floor: no part over a drop,
// through a wall or under a low ceiling. On stairs with small steps (no step
// bigger than STEP_MAX under it) it is tilted to follow the slope, resting on
// the step edges, so it lies draped over the stairs. If it doesn't fit as it
// fell it is slid a little (up to SLIDE_MAX), then turned to the nearest of
// 8 directions that fits. If nothing fits it stays an upright Doom corpse,
// pushed fully onto one step so nothing hangs over an edge. Flat bodies are
// re-checked all the time (a lift next to one may move).
// ---------------------------------------------------------------------------

class RECorpseHandler : EventHandler
{
	const EVERY = 4;           // tics between checks
	const SLIDE_STEP = 4;      // a slide tries these distances...
	const SLIDE_MAX = 32;      // ...up to this far
	const PUSH_MAX = 48;       // an upright body may be pushed this far onto one step
	const TOLERANCE = 2;       // floor height differences up to this count as the same floor
	const STEP_MAX = 24;       // the biggest step a body may lie across (Doom's step height)
	const END_GAP = 8;         // the ends of a body on stairs may be at most this far above the step under them
	const MAX_SLOPE = 0.84;    // steepest slope a body follows (about 40 degrees)
	const LOW_CEILING = 8;     // a ceiling closer than this above the body is in the way (a closed door)
	const INNER = 0.85;        // across the body the outer edges of the picture are mostly empty
	const CLEAR = 1;           // a body on stairs lies this much above the step edges (they fall between sample points)
	const ALONG = 13;          // sample points along the body (head to feet)...
	const ACROSS = 3;          // ...and across it

	// the direction each body's head points (fall direction, or a placed body's angle)
	Array<Actor> headActors;
	Array<double> headAngle;
	// bodies that didn't fit anywhere stay upright; tried again once they move (a lift)
	Array<Actor> refused;
	Array<double> refusedX, refusedY, refusedZ;

	// The killing hit: the body falls away from it.
	override void WorldThingDied(WorldEvent e)
	{
		Actor v = e.Thing;
		if (v == null || !v.bISMONSTER) return;
		SetHead(v, FallAngle(v, e.Inflictor));
	}

	static double FallAngle(Actor v, Actor inf)
	{
		if (inf == null || inf == v) return v.angle + 180;   // nothing known: falls backwards
		if (inf.bMISSILE)
		{
			// a projectile: away from where it burst (an explosion's centre), or
			// along its flight when it burst right on the body
			if (inf.Distance2D(v) > v.radius + 8) return inf.AngleTo(v);
			return inf.angle;
		}
		if (inf.Distance2D(v) < 1) return v.angle + 180;
		return inf.AngleTo(v);   // a gun, a bite, a barrel: away from the attacker
	}

	void SetHead(Actor a, double ang)
	{
		int i = headActors.Find(a);
		if (i < headActors.Size()) { headAngle[i] = ang; return; }
		headActors.Push(a); headAngle.Push(ang);
	}

	double HeadOf(Actor a)
	{
		int i = headActors.Find(a);
		if (i < headActors.Size()) return headAngle[i];
		// a map-placed body (or one from an old save): its angle as placed
		headActors.Push(a); headAngle.Push(a.angle);
		return a.angle;
	}

	override void WorldTick()
	{
		if (level.maptime % EVERY) return;
		int mode = CVar.FindCVar("re_flat_corpses").GetInt();
		bool firstPerson = false;
		for (int i = 0; i < MAXPLAYERS; i++)
		{
			if (!playeringame[i]) continue;
			let pl = RETankPlayer(players[i].mo);
			if (pl != null) { firstPerson = pl.bREFirstPerson; break; }
		}
		// Online co-op: "first person only" counts as both views (each player has their own view).
		bool on = mode == 2 || (mode == 1 && (firstPerson || REMain.Online()));
		double stretch = clamp(CVar.FindCVar("re_flat_corpse_stretch").GetFloat(), 0.5, 3);

		let it = ThinkerIterator.Create("Actor");
		Actor a;
		while (a = Actor(it.Next()))
		{
			bool mine = a.bISMONSTER || IsMapCorpse(a);
			if (!mine) continue;
			if (!on || !LiesDead(a))
			{
				if (a.bFLATSPRITE) StandUp(a);
				continue;
			}
			double sy = GetDefaultByType(a.GetClass()).scale.y * stretch;
			double pz, slope;
			if (a.bFLATSPRITE)
			{
				// still lying properly? (a lift under or next to it may have moved)
				if (FitPlane(a, a.angle, a.pos.xy, sy, pz, slope)) { Tilt(a, pz, slope); continue; }
				if (!Place(a, HeadOf(a), sy)) { StandUp(a); Refuse(a); }
				continue;
			}
			int r = refused.Find(a);
			if (r < refused.Size())
			{
				if (a.pos == (refusedX[r], refusedY[r], refusedZ[r])) continue;
				Forget(r);
			}
			if (!Place(a, HeadOf(a), sy)) Refuse(a);
		}
		// forget removed bodies
		for (int i = refused.Size() - 1; i >= 0; i--) if (refused[i] == null) Forget(i);
		for (int i = headActors.Size() - 1; i >= 0; i--) if (headActors[i] == null) { headActors.Delete(i); headAngle.Delete(i); }
	}

	// Stays upright: pushed fully onto one step first, so nothing hangs over an edge.
	void Refuse(Actor a)
	{
		PushOntoStep(a);
		refused.Push(a);
		refusedX.Push(a.pos.x); refusedY.Push(a.pos.y); refusedZ.Push(a.pos.z);
	}

	void Forget(int i)
	{
		refused.Delete(i); refusedX.Delete(i); refusedY.Delete(i); refusedZ.Delete(i);
	}

	static void StandUp(Actor a)
	{
		a.bFLATSPRITE = false;
		a.bROLLSPRITE = false;
		a.roll = 0;
		a.pitch = 0;
		a.WorldOffset = (0, 0, 0);
		a.scale.y = GetDefaultByType(a.GetClass()).scale.y;
	}

	// The picture lies along 'facing' (head to feet; see HeadSide), tilted to
	// height pz at the body's spot rising 'slope' per unit along the facing.
	static void LayDown(Actor a, double facing, double sy, double pz, double slope)
	{
		a.bFLATSPRITE = true;
		a.bROLLSPRITE = true;
		a.roll = 90;        // the picture's head-to-feet line along the facing
		a.angle = facing;
		a.scale.y = sy;     // the picture's height becomes the body's width on the floor
		Tilt(a, pz, slope);
	}

	static void Tilt(Actor a, double pz, double slope)
	{
		a.pitch = -atan(slope);   // negative pitch raises the end the actor faces
		a.WorldOffset = (0, 0, pz - a.pos.z);
	}

	// Doom's ready-placed dead bodies (they use the monsters' corpse pictures).
	static bool IsMapCorpse(Actor a)
	{
		return a is "DeadZombieMan" || a is "DeadShotgunGuy" || a is "DeadDoomImp"
			|| a is "DeadDemon" || a is "DeadCacodemon" || a is "DeadMarine"
			|| a is "GibbedMarine" || a is "GibbedMarineExtra";
	}

	// Dead, on the picture that stays forever, and resting on the floor.
	static bool LiesDead(Actor a)
	{
		if (a.tics != -1 || a.curstate == null) return false;
		if (a.bISMONSTER && (a.health > 0 || !a.bCORPSE)) return false;
		return a.pos.z <= a.floorz + 1;
	}

	// Which end of a final corpse/gib picture is the head, as drawn: 1 the
	// left end, -1 the right end, 0 no clear head (a pile, a round body).
	static int HeadSide(Actor a)
	{
		static const String HEAD_SPRITE[] = { "POSS","POSS","SPOS","SPOS","CPOS","CPOS","TROO","TROO","SARG","HEAD","BOS2","BOSS","BSPI","SKEL","FATT","VILE","SPID","CYBR","SSWV","SSWV","PLAY","PLAY","POL5" };
		static const int HEAD_FRAME[] = { 11, 20, 11, 20, 13, 19, 12, 20, 13, 11, 14, 14, 15, 15, 19, 25, 18, 15, 12, 22, 13, 22, 0 };
		static const int HEAD_END[] = { -1, -1, -1, -1, -1, -1, 1, -1, 0, 0, 0, 0, -1, 0, 0, 1, 1, 1, 1, 0, 1, -1, 0 };
		for (int i = 0; i < HEAD_SPRITE.Size(); i++)
			if (a.frame == HEAD_FRAME[i] && a.sprite == Actor.GetSpriteIndex(Name(HEAD_SPRITE[i]))) return HEAD_END[i];
		return 0;
	}

	// Find a spot for the flat picture: head toward 'head' as it fell, then
	// slid a little, then each of the other 7 directions (nearest first), each
	// also with a slide. Lays the body down at the first that fits.
	static bool Place(Actor a, double head, double sy)
	{
		bool headRight = HeadSide(a) < 0;
		for (int k = 0; k < 8; k++)
		{
			double dir = head + (k == 0 ? 0 : ((k & 1) ? 1 : -1) * 45 * ((k + 1) / 2));
			double facing = headRight ? dir + 180 : dir;   // roll 90 puts the picture's left end toward the facing
			double pz, slope;
			if (FitPlane(a, facing, a.pos.xy, sy, pz, slope)) { LayDown(a, facing, sy, pz, slope); return true; }
			for (double d = SLIDE_STEP; d <= SLIDE_MAX; d += SLIDE_STEP)
			{
				for (int s = 0; s < 8; s++)
				{
					Vector2 at = a.pos.xy + Actor.AngleToVector(s * 45, d);
					if (!FitPlane(a, facing, at, sy, pz, slope)) continue;
					if (CrossesWall(a, a.pos.xy, at)) continue;
					a.SetOrigin((at, a.GetZAt(at.x, at.y, 0, GZF_ABSOLUTEPOS)), false);
					LayDown(a, facing, sy, pz, slope);
					return true;
				}
			}
		}
		return false;
	}

	// The picture's extent around the body's spot, before the quarter turn:
	// up (fwd), down (back), left and right, from its size and offsets.
	static bool Extent(Actor a, double sy, out double fwd, out double back, out double lft, out double rgt)
	{
		fwd = back = lft = rgt = 0;
		TextureID tex; bool flip; Vector2 sc;
		[tex, flip, sc] = a.curstate.GetSpriteTexture(0);
		if (!tex.IsValid()) return false;
		Vector2 size = TexMan.GetScaledSize(tex);
		Vector2 ofs = TexMan.GetScaledOffset(tex);
		double sx = abs(a.scale.x);
		sy = abs(sy);
		fwd = ofs.y * sy; back = (size.y - ofs.y) * sy;
		lft = ofs.x * sx; rgt = (size.x - ofs.x) * sx;
		if (flip) { double t = lft; lft = rgt; rgt = t; }
		return true;
	}

	// Can the picture lie with the body at 'at' facing 'facing'? After the
	// quarter turn its left end points along the facing (u from -rgt to lft)
	// and its top to the facing's right (v from -back to fwd). The floor under
	// each row across the body must be level; along the body it may step by
	// at most STEP_MAX, always the same way (stairs), and the picture is then
	// tilted to rest on the step edges. Gives the picture's height at 'at'
	// (pz) and its slope along the facing.
	static bool FitPlane(Actor a, double facing, Vector2 at, double sy, out double pz, out double slope)
	{
		pz = a.pos.z; slope = 0;
		double fwd, back, lft, rgt;
		if (!Extent(a, sy, fwd, back, lft, rgt)) return true;
		fwd *= INNER; back *= INNER;   // along the body: its full length
		Vector2 du = Actor.AngleToVector(facing), dv = Actor.AngleToVector(facing - 90);
		double h[ALONG], u[ALONG], ceil[ALONG];
		for (int i = 0; i < ALONG; i++)
		{
			u[i] = -rgt + (lft + rgt) * i / (ALONG - 1);
			double lo = 1e9, hi = -1e9, cz = 1e9;
			for (int j = 0; j < ACROSS; j++)
			{
				double v = -back + (fwd + back) * j / (ACROSS - 1);
				Vector2 p = at + du * u[i] + dv * v;
				double fz = a.GetZAt(p.x, p.y, 0, GZF_ABSOLUTEPOS | GZF_3DRESTRICT);
				lo = min(lo, fz); hi = max(hi, fz);
				cz = min(cz, a.GetZAt(p.x, p.y, 0, GZF_ABSOLUTEPOS | GZF_CEILING | GZF_3DRESTRICT));
			}
			if (hi - lo > TOLERANCE) return false;   // an edge running along the body
			h[i] = hi; ceil[i] = cz;
		}
		// along the body: level, or stairs going one way with small steps
		int dirSign = 0;
		for (int i = 1; i < ALONG; i++)
		{
			double dz = h[i] - h[i - 1];
			if (abs(dz) <= TOLERANCE) continue;
			if (abs(dz) > STEP_MAX) return false;
			int sgn = dz > 0 ? 1 : -1;
			if (dirSign != 0 && sgn != dirSign) return false;   // up and down: a bump or a dip
			dirSign = sgn;
		}
		double b = 0, top = -1e9;
		if (dirSign != 0)
		{
			b = (h[ALONG - 1] - h[0]) / (u[ALONG - 1] - u[0]);
			if (abs(b) > MAX_SLOPE) return false;
		}
		for (int i = 0; i < ALONG; i++) top = max(top, h[i] - b * u[i]);
		if (dirSign != 0) top += CLEAR;
		for (int i = 0; i < ALONG; i++)
		{
			double z = top + b * u[i];
			double gap = z - h[i];
			if (dirSign == 0 && gap > TOLERANCE) return false;
			if (gap > STEP_MAX + TOLERANCE) return false;
			if ((i == 0 || i == ALONG - 1) && gap > END_GAP) return false;   // an end in the air
			if (ceil[i] - z < LOW_CEILING) return false;
		}
		// the outline and the lines from the body to the corners cross no wall
		double c = 1 / sqrt(1 + b * b);   // the tilt shortens it a little on the floor
		Vector2 c0 = at + du * (lft * c) + dv * -back, c1 = at + du * (lft * c) + dv * fwd;
		Vector2 c2 = at + du * (-rgt * c) + dv * fwd, c3 = at + du * (-rgt * c) + dv * -back;
		if (CrossesWall(a, c0, c1) || CrossesWall(a, c1, c2) || CrossesWall(a, c2, c3) || CrossesWall(a, c3, c0)
			|| CrossesWall(a, at, c0) || CrossesWall(a, at, c1) || CrossesWall(a, at, c2) || CrossesWall(a, at, c3)) return false;
		pz = top;
		slope = b;
		return true;
	}

	// An upright body standing over an edge (Doom keeps a body at the highest
	// floor under it) is pushed to the nearest spot where all the floor under
	// it is one level.
	static void PushOntoStep(Actor a)
	{
		double r = max(a.radius, 12);
		if (OneLevel(a, a.pos.xy, r)) return;
		for (double d = SLIDE_STEP; d <= PUSH_MAX; d += SLIDE_STEP)
		{
			for (int s = 0; s < 8; s++)
			{
				Vector2 at = a.pos.xy + Actor.AngleToVector(s * 45, d);
				if (!OneLevel(a, at, r) || CrossesWall(a, a.pos.xy, at)) continue;
				a.SetOrigin((at, a.GetZAt(at.x, at.y, 0, GZF_ABSOLUTEPOS)), false);
				return;
			}
		}
	}

	static bool OneLevel(Actor a, Vector2 at, double r)
	{
		double z0 = a.GetZAt(at.x, at.y, 0, GZF_ABSOLUTEPOS);
		for (int s = 0; s < 8; s++)
		{
			Vector2 p = at + Actor.AngleToVector(s * 45, r);
			if (abs(a.GetZAt(p.x, p.y, 0, GZF_ABSOLUTEPOS) - z0) > TOLERANCE) return false;
			if (CrossesWall(a, at, p)) return false;
		}
		return true;
	}

	// Does the segment p0-p1 cross a solid wall (a one-sided line, or one that
	// blocks everything)?
	static bool CrossesWall(Actor a, Vector2 p0, Vector2 p1)
	{
		Vector2 mid = (p0 + p1) / 2;
		double r = (p1 - p0).Length() / 2 + 8;
		let bl = BlockLinesIterator.CreateFromPos((mid, a.pos.z), 1, r);
		while (bl.Next())
		{
			Line ln = bl.curline;
			bool solid = ln.sidedef[1] == null || (ln.flags & Line.ML_BLOCKEVERYTHING);
			if (!solid) continue;
			if (SegmentsCross(p0, p1, ln.v1.p, ln.v2.p)) return true;
		}
		return false;
	}

	static bool SegmentsCross(Vector2 a0, Vector2 a1, Vector2 b0, Vector2 b1)
	{
		double d1 = Side(b0, b1, a0), d2 = Side(b0, b1, a1);
		double d3 = Side(a0, a1, b0), d4 = Side(a0, a1, b1);
		return ((d1 > 0) != (d2 > 0)) && ((d3 > 0) != (d4 > 0)) && d1 != 0 && d2 != 0;
	}

	static double Side(Vector2 p0, Vector2 p1, Vector2 q)
	{
		return (p1.x - p0.x) * (q.y - p0.y) - (p1.y - p0.y) * (q.x - p0.x);
	}
}
