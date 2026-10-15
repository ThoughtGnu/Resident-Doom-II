// ---------------------------------------------------------------------------
// AutoCamera.zs - automatic fixed cameras for maps without a recams.txt entry
// (Doom II's own MAP01 onward).
//
// Doom maps aren't made of rooms, so cameras can't be hand-placed per room.
// Instead:
//   1. At map load, candidate camera spots are made just inside every wall
//      of every sector (near both ends, plus the middle of long walls),
//      raised toward the ceiling.
//   2. The active camera stays put but slowly turns to keep Jill framed, like
//      a security camera.
//   3. It keeps the same spot while it has a clear view of Jill at a sensible
//      distance. When the view is blocked, she teleports, or a much
//      better spot has been available for a while, it cuts to the best spot.
//
// Scoring prefers spots ~320 units away, looking down at 15-45 degrees, in
// the sector Jill is standing in.
// ---------------------------------------------------------------------------

extend class RECameraHandler
{
	bool autoMode;
	Array<double> candX;
	Array<double> candY;
	Array<double> candZ;
	Array<int> candSector;
	REFixedCamera autoCam;
	REFixedCamera autoProbe;   // invisible helper for testing spots (never viewed)
	int autoCand;           // index of the spot in use, -1 = none yet
	int autoBlocked;        // tics the current spot has been unable to see Jill
	int autoNextCheck;      // level.maptime of the next "is there a better spot" check
	Vector3 autoLastPos;

	const AUTO_BEST_DIST  = 320.0;
	const AUTO_MIN_DIST   = 120.0;
	const AUTO_CLOSE_DIST = 40.0;
	const AUTO_HALF_HEIGHT  = 28.0;    // half of the player's 56-unit height
	bool autoClose;                  // current spot only passed the close-shot rules
	const AUTO_MAX_DIST   = 1100.0;
	const AUTO_BLOCK_TICS = 1;    // cut as soon as a wall gets in the way
	const AUTO_FOV        = 75.0;
	const AUTO_MIN_FOV    = 48.0;   // the most the lens zooms in
	const AUTO_SIZE       = 0.2;    // her height as a share of the picture, from far away
	const AUTO_GOOD       = 1.0;    // a spot scoring less (walls in the way, partner in front...) loses to the follow view

	// ---------------------------------------------------------------------
	void BuildAutoCameras()
	{
		autoMode = true;
		autoCand = -1;
		Map<int, int> used;   // one spot per 48x48 cell is enough

		for (int si = 0; si < level.Sectors.Size(); si++)
		{
			Sector s = level.Sectors[si];
			int n = s.lines.Size();
			if (n < 3) continue;

			// centre and size of the sector
			double minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
			Vector2 centre = (0, 0);
			for (int i = 0; i < n; i++)
			{
				Vector2 v = s.lines[i].v1.p;
				centre += v;
				minX = min(minX, v.x); maxX = max(maxX, v.x);
				minY = min(minY, v.y); maxY = max(maxY, v.y);
			}
			centre /= n;
			if (maxX - minX < 48 && maxY - minY < 48) continue;   // too small (steps, pillars)

			double fz = s.CenterFloor(), cz = s.CenterCeiling();
			if (cz - fz < 56) continue;                            // closed doors, crawlspaces
			bool sky = s.GetTexture(Sector.ceiling) == skyflatnum;
			double z = sky ? fz + 160 : min(fz + 128, cz - 10);
			z = max(z, fz + 44);

			// Spots just inside every wall: near both ends (= the room's
			// corners, including corners of side pockets) and, on long walls,
			// in the middle. "Inside" is the wall's own side facing this
			// sector, so L-shaped and odd sectors get spots in every part.
			for (int i = 0; i < n; i++)
			{
				Line ln = s.lines[i];
				Vector2 a = ln.v1.p, b = ln.v2.p;
				Vector2 along = b - a;
				double len = along.Length();
				if (len < 8) continue;
				along /= len;
				Vector2 inward = (along.y, -along.x);          // right of v1->v2 = front side
				if (ln.frontsector != s) inward = -inward;

				double inset = min(28.0, len * 0.5);
				Array<double> ts;
				ts.Push(inset);
				ts.Push(len - inset);
				if (len > 256) ts.Push(len * 0.5);
				for (int k = 0; k < ts.Size(); k++)
				{
					Vector2 p = a + along * ts[k] + inward * 28;
					if (!InsideSector(s, p)) continue;

					int key = (int(p.x / 48) + 2048) * 4096 + (int(p.y / 48) + 2048);
					if (used.CheckKey(key)) continue;
					used.Insert(key, 1);

					candX.Push(p.x); candY.Push(p.y); candZ.Push(z); candSector.Push(si);
				}
			}

			// Big open rooms and yards: spots inside them too, on a grid, so
			// there is always one at a sensible distance, not only along walls
			// far away (MAP12's hall).
			if (maxX - minX > 512 || maxY - minY > 512)
			{
				for (double gx = minX + 96; gx < maxX; gx += 192)
				{
					for (double gy = minY + 96; gy < maxY; gy += 192)
					{
						Vector2 p = (gx, gy);
						if (!InsideSector(s, p)) continue;
						int key = (int(p.x / 48) + 2048) * 4096 + (int(p.y / 48) + 2048);
						if (used.CheckKey(key)) continue;
						used.Insert(key, 1);
						candX.Push(p.x); candY.Push(p.y); candZ.Push(z); candSector.Push(si);
					}
				}
			}
		}

		autoCam = REFixedCamera(Actor.Spawn("REFixedCamera", (0, 0, 0)));
		if (autoCam != null) autoCam.CameraFOV = AUTO_FOV;
		autoProbe = REFixedCamera(Actor.Spawn("REFixedCamera", (0, 0, 0)));
		Console.Printf("Resident Doom II: no hand-made cameras for %s, using %d automatic camera spots.",
			level.MapName, candX.Size());
	}

	// Is p really inside sector s? (level.PointInSector also answers for
	// points in the empty void between rooms, so count how many of the
	// sector's walls a ray from p crosses: odd = inside.)
	static bool InsideSector(Sector s, Vector2 p)
	{
		if (level.PointInSector(p) != s) return false;
		bool inside = false;
		for (int i = 0; i < s.lines.Size(); i++)
		{
			Line ln = s.lines[i];
			if (ln.frontsector == ln.backsector) continue;   // both sides the same sector: not a border
			Vector2 a = ln.v1.p, b = ln.v2.p;
			if ((a.y > p.y) != (b.y > p.y))
			{
				double x = a.x + (p.y - a.y) * (b.x - a.x) / (b.y - a.y);
				if (x > p.x) inside = !inside;
			}
		}
		return inside;
	}

	// How good spot i is for showing the player (-1 = can't see her).
	// 'close' allows nearer, steeper shots, for tight spots such as small
	// low alcoves where no spot passes the normal rules.
	double AutoScore(int i, Actor pmo, bool close = false)
	{
		Vector3 cam = (candX[i], candY[i], candZ[i]);
		Vector3 target = pmo.pos + (0, 0, pmo.Height * 0.5);
		Vector3 d = cam - target;               // from Jill to the camera
		double horiz = d.xy.Length();
		double dist = d.Length();
		if (dist < (close ? AUTO_CLOSE_DIST : AUTO_MIN_DIST) || dist > AUTO_MAX_DIST) return -1;

		double down = VectorAngle(horiz, d.z);   // how steeply the camera looks down at her
		if (down > (close ? 88 : 65) || down < -10) return -1;   // close: up to almost straight down (pits)

		// Would this spot really show her? Put an invisible probe camera there,
		// aimed and zoomed the way the real one would be, and run the same
		// whole-body-in-the-picture check the live camera uses (ViewScore).
		// Tracing from the camera's side matters: with Doom's fake floors a
		// line can be clear one way and blocked the other.
		if (autoProbe == null) return -1;
		autoProbe.SetOrigin(cam, false);
		autoProbe.LookAt(target);
		autoProbe.CameraFOV = AutoFov(dist);
		if (autoProbe.ViewScore(pmo) <= 0) return -1;

		double score = 1.0 - abs(dist - AUTO_BEST_DIST) / 800.0;
		score -= max(0, dist - 640) / 600.0;   // far away: she's tiny on screen
		if (down >= 15 && down <= 45) score += 0.3;
		if (pmo.CurSector == level.Sectors[candSector[i]]) score += 0.2;
		else if (dist > 400) score -= 0.25;    // from another room far away (through a window or doorway)
		// A wall right in front of the lens covering part of the picture.
		score -= 0.15 * AutoClutter(cam, target, autoProbe.CameraFOV);
		// Two characters: a view that also shows the AI partner is better,
		// unless the partner is right in front of the lens or blocking her.
		let partner = REPartner.Find();
		if (partner != null)
		{
			Vector3 pm = partner.pos + (0, 0, partner.Height * 0.5);
			Vector3 dir = (target - cam) / dist;
			double pd = max((pm - cam).Length(), 1);
			double along = (pm - cam) dot dir;                       // how far ahead of the lens
			Vector3 off = (pm - cam) - dir * along;                  // how far from the line to her
			bool inView = along > 0 && acos(clamp(along / pd, -1, 1)) < autoProbe.CameraFOV * 0.5 + 10;
			if (inView && pd < 160) return -1;                       // right in front of the lens: not this spot (the chase view steps around the partner)
			else if (inView && along < dist && off.Length() < partner.radius + pmo.radius + 4) score -= 0.5;   // standing in front of her
			else if (autoProbe.ViewScore(partner) > 0) score += 0.35;   // both of them in the picture
		}
		return score;
	}

	// How many of 8 lines across the picture hit a wall close to the lens (a
	// pillar or corner in the foreground covering the view). Floors and
	// ceilings don't count: looking down at the floor is normal.
	int AutoClutter(Vector3 cam, Vector3 target, double fov)
	{
		static const double fx[] = { -0.7, 0, 0.7, -0.7, 0.7, -0.7, 0, 0.7 };
		static const double fy[] = { -0.6, -0.6, -0.6, 0, 0, 0.6, 0.6, 0.6 };
		Vector3 d = target - cam;
		double ang = VectorAngle(d.x, d.y);
		double pit = -VectorAngle(d.xy.Length(), d.z);
		double near = clamp(d.Length() * 0.7, 64, 320);
		int hits = 0;
		for (int i = 0; i < 8; i++)
		{
			FLineTraceData t;
			autoProbe.LineTrace(ang + fx[i] * fov * 0.5, near, pit + fy[i] * fov * 0.5 * 0.6, TRF_THRUACTORS, 0, 0, 0, t);
			if (t.HitType == TRACE_HitWall) hits++;
		}
		return hits;
	}

	int AutoFindBest(Actor pmo, out double bestScore)
	{
		int best = -1;
		bestScore = -1;
		double maxSq = AUTO_MAX_DIST * AUTO_MAX_DIST;
		for (int pass = 0; pass < 2 && best < 0; pass++)   // normal rules, then close shots
		{
			for (int i = 0; i < candX.Size(); i++)
			{
				double dx = candX[i] - pmo.pos.x, dy = candY[i] - pmo.pos.y;
				if (dx * dx + dy * dy > maxSq) continue;
				double s = AutoScore(i, pmo, pass == 1);
				if (s > bestScore) { bestScore = s; best = i; }
			}
		}
		autoClose = best >= 0 && AutoScore(best, pmo) < 0;
		return best;
	}

	// Lens width so her whole body fits: 75 degrees normally, wider up close
	// (up to 110). Uses the same picture shape as ViewScore.
	double AutoFov(double dist)
	{
		// Measure to the nearest part of her body (her head is closer to a
		// camera above her than her middle is), with a margin.
		double tanV = (AUTO_HALF_HEIGHT + 10) / max(dist - AUTO_HALF_HEIGHT, 1.0);
		double fit = 2 * atan(tanV / (0.75 / 1.2)) * 1.25;
		// From further away, zoom in so she is about a fifth of the picture's
		// height (at 75 degrees she'd be tiny from across a big room).
		double zoom = 2 * atan((AUTO_HALF_HEIGHT * 2 / (2 * max(dist, 1.0) * AUTO_SIZE)) / 0.75);
		return clamp(max(fit, min(zoom, AUTO_FOV)), AUTO_MIN_FOV, 110.0);
	}

	void AutoSwitch(int i, Actor pmo)
	{
		autoCand = i;
		autoBlocked = 0;
		autoCam.SetOrigin((candX[i], candY[i], candZ[i]), false);
		autoCam.LookAt(pmo.pos + (0, 0, pmo.Height * 0.5));
		// the same distance AutoAim uses (to her middle), so the lens doesn't
		// change a moment after the cut
		autoCam.CameraFOV = AutoFov((autoCam.pos - (pmo.pos + (0, 0, pmo.Height * 0.5))).Length());
		autoCam.ClearInterpolation();
		if (re_debugcams)
		{
			int nearby = 0;
			for (int k = 0; k < candX.Size(); k++) if ((candX[k] - pmo.pos.x) ** 2 + (candY[k] - pmo.pos.y) ** 2 < 600 * 600) nearby++;
			Console.Printf("auto camera %d: %.0f away, score %.2f, clutter %d, %d spots within 600",
				i, (autoCam.pos - pmo.pos).Length(), AutoScore(i, pmo, autoClose), AutoClutter(autoCam.pos, pmo.pos + (0, 0, pmo.Height * 0.5), autoCam.CameraFOV), nearby);
		}
	}

	const AUTO_CHASE = -2;
	const AUTO_OPENING = -3;
	bool autoOpenTried;

	// The opening shot, hand-picked, for maps whose automatic one was poor
	// (MAP12: tiny in a big dark hall; MAP16: half the picture a wall; MAP14:
	// the lens right above the item box). Only
	// the first shot of the map: every other camera stays automatic.
	static bool, Vector3 OpeningSpot()
	{
		String m = level.MapName.MakeUpper();
		if (m == "MAP12") return true, (1700, 2700, 96);
		if (m == "MAP16") return true, (55, 226, 136);
		if (m == "MAP14") return true, (110, 420, 280);   // from the room in front: the start alcove has no room behind the box
		if (m == "MAP06") return true, (1308, 668, 102);   // small start rooms with a hand-placed box and typewriter
		if (m == "MAP29") return true, (1207, 281, 664);   // (StartLayout, RE_ItemBox.zs): the shot that shows both
		if (m == "MAP09") return true, (484, 476, -128);   // over the liquid: the whole stone cross with her, the box and the typewriter
		if (m == "MAP17") return true, (-1760, -3696, 104);   // from the room's north opening: her, the box and the typewriter all in view
		if (m == "MAP03") return true, (2052, 3500, 62);   // down the narrow start room from its door: her, the box and the typewriter all in view
		return false, (0, 0, 0);
	}

	// --- MAP30: the Icon of Sin ---------------------------------------------
	// Hand-placed camera spots high around the arena. While the Icon lives,
	// the camera is the spot that shows both her (whole) and the face with
	// the brain's hole (FACE below) best - the nearest with a clear view of
	// both - aimed between the two, the lens just wide enough for both. It
	// stays on a spot while that still works. Elsewhere on the map (the start
	// room) no spot sees the face, and the usual cameras are used.
	const AUTO_BOSS = -4;
	// 5 across x 5 deep over the arena (from the south wall up to near the
	// face), each low and high
	static const double bossX[] = {
		2400, 2640, 2880, 3120, 3360, 2400, 2640, 2880, 3120, 3360, 2400, 2640, 2880, 3120, 3360, 2400, 2640, 2880, 3120, 3360, 2400, 2640, 2880, 3120, 3360,
		2400, 2640, 2880, 3120, 3360, 2400, 2640, 2880, 3120, 3360, 2400, 2640, 2880, 3120, 3360, 2400, 2640, 2880, 3120, 3360, 2400, 2640, 2880, 3120, 3360 };
	static const double bossY[] = {
		-250, -250, -250, -250, -250, 100, 100, 100, 100, 100, 450, 450, 450, 450, 450, 700, 700, 700, 700, 700, 1000, 1000, 1000, 1000, 1000,
		-250, -250, -250, -250, -250, 100, 100, 100, 100, 100, 450, 450, 450, 450, 450, 700, 700, 700, 700, 700, 1000, 1000, 1000, 1000, 1000 };
	static const double bossZ[] = {
		200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200,
		500, 500, 500, 500, 500, 500, 500, 500, 500, 500, 500, 500, 500, 500, 500, 500, 500, 500, 500, 500, 500, 500, 500, 500, 500 };
	// ... and spots that follow her: behind her on the far side from the
	// face, so she stands big in front and the face rises behind her
	static const double followDist[] = { 200, 260, 160, 120, 340, 440 };
	static const double followSide[] = { 0, 25, -25, 50, -50, 80, -80, 110, -110 };
	static const double followUp[] = { 48, 110 };
	int bossSpot;
	int bossNextCheck;

	int BossSpots() { return bossX.Size() + followDist.Size() * followSide.Size() * followUp.Size(); }

	Vector3 BossSpotAt(int i, Actor pmo)
	{
		if (i < bossX.Size()) return (bossX[i], bossY[i], bossZ[i]);
		i -= bossX.Size();
		int du = i % followUp.Size(); i /= followUp.Size();
		int ds = i % followSide.Size(); i /= followSide.Size();
		Vector3 face = BossFace();
		Vector2 away = pmo.pos.xy - face.xy;
		double ang = VectorAngle(away.x, away.y) + followSide[ds];
		Vector2 at = pmo.pos.xy + Actor.AngleToVector(ang, followDist[i]);
		return (at.x, at.y, pmo.pos.z + followUp[du]);
	}

	static bool BossFight()
	{
		if (!(level.MapName ~== "MAP30")) return false;
		let it = ThinkerIterator.Create("BossBrain");
		Actor b = Actor(it.Next());
		return b != null && b.health > 0;
	}

	// The middle of the face: the brain's hole in the wall (DBRAIN4, z 384-416).
	static Vector3 BossFace() { return (2880, 1400, 400); }

	// Point a camera at 'spot' between her and the face; how good the view
	// is (-1: it can't show both).
	double BossAim(REFixedCamera c, Vector3 spot, Actor pmo, bool glide = false)
	{
		if (!level.IsPointInLevel(spot)) return -1;
		Sector s = level.PointInSector(spot.xy);
		spot.z = min(spot.z, s.ceilingplane.ZAtPoint(spot.xy) - 16);
		if (spot.z < s.floorplane.ZAtPoint(spot.xy) + 32) return -1;
		c.SetOrigin(spot, glide);   // glide: a follow spot moving with her, drawn smoothly
		Vector3 mid = pmo.pos + (0, 0, pmo.Height * 0.5);
		let partner = REPartner.Find();
		if (partner != null && PartnerBlocks(partner, spot, mid, pmo)) return -1;
		// the lens's own clear line to her (the follow spots can be behind a wall)
		if (!c.ClearLineTo(mid)) return -1;
		Vector3 face = BossFace();
		Vector3 up = (mid - spot).Unit(), uf = (face - spot).Unit();
		Vector3 d = up + uf;
		c.Angle = VectorAngle(d.x, d.y);
		c.Pitch = -VectorAngle(d.xy.Length(), d.z);
		// wide enough for both, her whole body included, with a margin
		double spread = acos(clamp(up dot uf, -1, 1));
		double dist = (mid - spot).Length();
		c.CameraFOV = clamp(spread * 1.9 + 2 * atan(AUTO_HALF_HEIGHT * 2 / max(dist, 1.0)) + 12, 50, 115);
		if (c.ViewScore(pmo) <= 0 || !c.ClearLineTo(face)) return -1;
		double x, y, depth;
		[x, y, depth] = c.ToView(face);
		double tanH = tan(c.CameraFOV / 2), tanV = tanH * 0.75 / 1.2;
		if (depth < 16 || abs(x) / depth > tanH * 0.95 || abs(y) / depth > tanV * 0.95) return -1;
		// how big she looks: her height as a share of the picture's height
		double score = AUTO_HALF_HEIGHT * 2 / (dist * tanV * 2);
		if (partner != null && c.ViewScore(partner) > 0) score += 0.05;
		if (spread < atan(40.0 / max(dist, 1.0)) * 1.5) score *= 0.5;   // she would hide the brain's hole
		return score;
	}

	// Every tic of the fight: true while a spot shows both (the camera is set).
	bool BossTick(PlayerPawn pmo)
	{
		if (autoProbe == null || autoCam == null) return false;
		bool keep = autoCand == AUTO_BOSS && level.maptime < bossNextCheck;
		if (keep && BossAim(autoCam, BossSpotAt(bossSpot, pmo), pmo, true) >= 0) return true;
		int best = -1;
		double bestScore = -1;
		for (int i = 0; i < BossSpots(); i++)
		{
			double s = BossAim(autoProbe, BossSpotAt(i, pmo), pmo);
			if (autoCand == AUTO_BOSS && i == bossSpot && s >= 0) s *= 1.25;   // stay unless clearly better
			if (s > bestScore) { bestScore = s; best = i; }
		}
		if (best < 0 || bestScore < 0) return false;
		bool cut = autoCand != AUTO_BOSS || best != bossSpot;
		bossSpot = best;
		autoCand = AUTO_BOSS;
		bossNextCheck = level.maptime + 35;
		BossAim(autoCam, BossSpotAt(best, pmo), pmo, !cut);
		if (cut) autoCam.ClearInterpolation();
		if (cut && re_debugcams) Console.Printf("boss camera %d at (%.0f, %.0f, %.0f), fov %.0f", best, autoCam.pos.x, autoCam.pos.y, autoCam.pos.z, autoCam.CameraFOV);
		return true;
	}

	// Map start, while the map loads (REStartLayoutHandler): the opening
	// camera chosen, placed and aimed before the first picture is drawn, so
	// nothing moves once the map is shown (the first picture stays on screen
	// through Doom's screen melt).
	void PickOpening(PlayerPawn pmo)
	{
		if (!autoMode)
		{
			let best = BestCamera(pmo);
			if (best == null) return;
			SwitchTo(best.camId);
			for (int i = 0; i < MAXPLAYERS; i++) if (playeringame[i]) players[i].camera = best;
			return;
		}
		if (autoCam == null || candX.Size() == 0) return;
		autoLastPos = pmo.pos;   // the first tic is not a jump
		autoOpenTried = true;
		autoCand = -1;
		if (BossFight() && BossTick(pmo))   // MAP30: her and the Icon of Sin
		{
			for (int i = 0; i < MAXPLAYERS; i++) if (playeringame[i]) players[i].camera = autoCam;
			return;
		}
		bool has; Vector3 spot;
		[has, spot] = OpeningSpot();
		if (has)
		{
			autoCand = AUTO_OPENING;
			autoCam.SetOrigin(spot, false);
			AimNow(pmo);
			if (autoCam.ViewScore(pmo) <= 0) autoCand = -1;
		}
		if (autoCand == -1)
		{
			double s;
			int best = AutoFindBest(pmo, s);
			if (best >= 0 && (s >= AUTO_GOOD || !AutoChaseClear(pmo))) AutoSwitch(best, pmo);
			else AutoChase(pmo);
		}
		AimNow(pmo);
		for (int i = 0; i < MAXPLAYERS; i++) if (playeringame[i]) players[i].camera = autoCam;
	}

	// Looking straight at her middle, zoomed for the distance, no turning in.
	void AimNow(Actor pmo)
	{
		Vector3 d = pmo.pos + (0, 0, pmo.Height * 0.5) - autoCam.pos;
		autoCam.Angle = VectorAngle(d.x, d.y);
		autoCam.Pitch = -VectorAngle(d.xy.Length(), d.z);
		autoCam.CameraFOV = AutoFov(d.Length());
		autoCam.ClearInterpolation();
	}

	// The start item box and typewriter (RE_ItemBox.zs) both in the opening
	// shot, when the automatic first pick can't show them: the best spot that
	// shows her and both props as they stand; failing that, the best few spots
	// each get a try with the typewriter (then the box too) moved to suit
	// them. True if the camera now shows all three.
	bool autoHold;
	Vector3 autoHoldPos;

	bool FrameStartProps(Actor pmo, Actor box, Actor tw, bool canMove = true)
	{
		if (!autoMode || autoProbe == null || autoCam == null) return false;
		// every spot that can show her, best first (normal rules, then close shots)
		Array<int> idx; Array<double> sc; Array<int> closeOnly;
		double maxSq = AUTO_MAX_DIST * AUTO_MAX_DIST;
		for (int pass = 0; pass < 2; pass++)
		{
			for (int i = 0; i < candX.Size(); i++)
			{
				if ((candX[i] - pmo.pos.x) ** 2 + (candY[i] - pmo.pos.y) ** 2 > maxSq) continue;
				if (pass == 1 && AutoScore(i, pmo) >= 0) continue;   // already listed
				double s = AutoScore(i, pmo, pass == 1);
				if (s < AUTO_GOOD) continue;   // only a good view of her (no doorway peeks, no walls in front)
				if (pass == 1) s -= 10;   // close shots after every normal one
				int at = 0;
				while (at < sc.Size() && sc[at] >= s) at++;
				idx.Insert(at, i); sc.Insert(at, s); closeOnly.Insert(at, pass);
			}
		}
		for (int step = 0; step < (canMove ? 2 : 1); step++)   // hand-placed props (StartLayout) stay where they are
		{
			for (int n = 0; n < idx.Size() && (step == 0 || n < 12); n++)
			{
				AutoScore(idx[n], pmo, closeOnly[n] == 1);   // aims the probe as the real camera would be
				bool ok = step == 0
					? REItemBoxHandler.Visible(autoProbe, box) && REItemBoxHandler.Visible(autoProbe, tw) && REItemBoxHandler.Visible(autoProbe, pmo) && REItemBoxHandler.ScreenApart(autoProbe, tw, box)
					: REItemBoxHandler.PlaceApart(box, pmo, autoProbe, tw) != null || REItemBoxHandler.MoveBoxIntoShot(box, tw, pmo, autoProbe);
				if (!ok) continue;
				autoClose = closeOnly[n] == 1;
				AutoSwitch(idx[n], pmo);
				for (int i = 0; i < MAXPLAYERS; i++) if (playeringame[i]) players[i].camera = autoCam;
				autoHold = true;
				autoHoldPos = pmo.pos;
				return true;
			}
		}
		return false;
	}

	// Last resort: a camera behind and above her, pulled in until the view is
	// clear (tight spots where no generated spot can see her).
	// Straight behind her first, then from either side, then from in front. With the AI partner
	// (who follows right behind her), a spot where the partner would stand in
	// front of the lens is skipped; the side last used is tried first, so the
	// view doesn't jump around.
	int autoChaseSide;
	void AutoChase(Actor pmo)
	{
		bool found; Vector3 cam; int sd;
		[found, cam, sd] = FindChase(pmo, false);
		if (!found) { AutoPartial(pmo); return; }
		Vector3 mid = pmo.pos + (0, 0, pmo.Height * 0.5);
		autoChaseSide = sd;
		autoCand = AUTO_CHASE;
		autoBlocked = 0;
		autoCam.SetOrigin(cam, true);
		autoCam.LookAt(mid);
		autoCam.CameraFOV = AutoFov((cam - mid).Length());
	}

	// Is there a follow view with a clear line to her and nobody in front of the lens?
	bool AutoChaseClear(Actor pmo)
	{
		bool found; Vector3 cam; int sd;
		[found, cam, sd] = FindChase(pmo, true);
		return found;
	}

	// The follow-view spot: found?, where, and which side. 'strict': only
	// spots the partner doesn't block (otherwise, as a last try, any clear one).
	bool, Vector3, int FindChase(Actor pmo, bool strict)
	{
		static const double back[] = { 160, 120, 90, 60 };
		static const double up[] = { 72, 56, 40, 30 };
		static const double side[] = { 0, 40, -40, 75, -75, 180, 140, -140 };   // last three: from in front of her
		let partner = REPartner.Find();
		Vector3 mid = pmo.pos + (0, 0, pmo.Height * 0.5);
		for (int pass = 0; pass < (strict ? 1 : 2); pass++)   // pass 0: nothing may block the view
		{
			for (int k = 0; k < side.Size(); k++)
			{
				int sd = k == 0 ? autoChaseSide : (k <= autoChaseSide ? k - 1 : k);
				for (int i = 0; i < 4; i++)
				{
					Vector2 xy = pmo.pos.xy - Actor.AngleToVector(pmo.Angle + side[sd], back[i]);
					Sector s = level.PointInSector(xy);
					double z = min(pmo.pos.z + up[i] + pmo.Height * 0.5, s.CenterCeiling() - 8);
					Vector3 cam = (xy.x, xy.y, z);
					Vector3 d = cam - mid;
					// pass 0 also stops at things in the way (the item box's column, a
					// typewriter, the partner); the last try only at walls
					if (pmo.LineTrace(VectorAngle(d.x, d.y), d.Length(), -VectorAngle(d.xy.Length(), d.z),
						pass == 0 ? 0 : TRF_THRUACTORS, pmo.Height * 0.5)) continue;
					if (pass == 0 && partner != null && PartnerBlocks(partner, cam, mid, pmo)) continue;
					if (pass == 0 && PropBlocks(cam, mid)) continue;
					return true, cam, sd;
				}
			}
		}
		return false, (0, 0, 0), 0;
	}

	// Is an item box column or a typewriter between a lens at 'cam' and her?
	// (They are actors, which the wall checks don't see.)
	bool PropBlocks(Vector3 cam, Vector3 mid)
	{
		Vector2 dir = mid.xy - cam.xy;
		double len = dir.Length();
		if (len < 1) return false;
		dir /= len;
		for (int k = 0; k < 2; k++)
		{
			let it = ThinkerIterator.Create(k == 0 ? 'REItemBoxActor' : 'RETypewriter');
			Actor a;
			while (a = Actor(it.Next()))
			{
				Vector2 rel = a.pos.xy - cam.xy;
				double along = rel dot dir;
				if (along <= 0 || along >= len - 8) continue;
				Vector2 off = rel - dir * along;
				if (off.Length() < a.radius + 10) return true;
			}
		}
		return false;
	}

	// Would the partner stand in front of a lens at 'cam' looking at her middle?
	static bool PartnerBlocks(Actor partner, Vector3 cam, Vector3 mid, Actor pmo)
	{
		Vector3 pm = partner.pos + (0, 0, partner.Height * 0.5);
		double dist = (mid - cam).Length();
		if (dist < 1) return false;
		Vector3 dir = (mid - cam) / dist;
		double along = (pm - cam) dot dir;
		if (along <= 0) return false;                     // behind the lens
		if ((pm - cam).Length() < 80) return true;        // right at the lens
		if (along >= dist) return false;                  // behind her
		Vector3 off = (pm - cam) - dir * along;
		return off.xy.Length() < partner.radius + pmo.radius + 10;
	}

	// Very last resort, for boxes barely taller than Jill (e.g. a lift raised
	// into a closed shaft), where no camera can fit her whole body: the
	// nearest spot with a clear line to her middle, at the widest lens. She is
	// on screen, just cropped.
	void AutoPartial(Actor pmo)
	{
		if (autoProbe == null) return;
		Vector3 mid = pmo.pos + (0, 0, pmo.Height * 0.5);
		int best = -1;
		double bestDist = 300;
		for (int i = 0; i < candX.Size(); i++)
		{
			Vector3 cam = (candX[i], candY[i], candZ[i]);
			double dist = (cam - mid).Length();
			if (dist >= bestDist) continue;
			autoProbe.SetOrigin(cam, false);
			if (!autoProbe.ClearLineTo(mid)) continue;
			best = i;
			bestDist = dist;
		}
		if (best < 0) return;
		if (best != autoCand) AutoSwitch(best, pmo);
		autoCam.CameraFOV = 110;
		autoBlocked = 0;
	}

	// Turn smoothly to keep her framed (a third of the way each tic).
	void AutoAim(Actor pmo)
	{
		if (autoCand < 0) return;   // none yet, or chasing (aimed directly)
		Vector3 d = pmo.pos + (0, 0, pmo.Height * 0.5) - autoCam.pos;
		double wantAngle = VectorAngle(d.x, d.y);
		double wantPitch = -VectorAngle(d.xy.Length(), d.z);
		autoCam.CameraFOV = AutoFov(d.Length());
		autoCam.A_SetAngle(autoCam.Angle + Actor.DeltaAngle(autoCam.Angle, wantAngle) * 0.3, SPF_INTERPOLATE);
		autoCam.A_SetPitch(autoCam.Pitch + Actor.DeltaAngle(autoCam.Pitch, wantPitch) * 0.3, SPF_INTERPOLATE);
	}

	// ---------------------------------------------------------------------
	void AutoTick(PlayerPawn pmo)
	{
		if (autoCam == null || candX.Size() == 0) return;

		bool teleported = (pmo.pos - autoLastPos).Length() > 150;
		autoLastPos = pmo.pos;

		// MAP30: her and the Icon of Sin together, while it lives (BossTick)
		if (BossFight())
		{
			if (BossTick(pmo))
			{
				for (int i = 0; i < MAXPLAYERS; i++) if (playeringame[i] && players[i].camera != autoCam) players[i].camera = autoCam;
				return;
			}
			if (autoCand == AUTO_BOSS) autoCand = -1;   // no spot sees both from here: the usual cameras
		}
		else if (autoCand == AUTO_BOSS) autoCand = -1;   // the Icon is dead

		AutoAim(pmo);

		// The spot counts as "seeing" her only if her whole body is actually
		// in the picture right now (ViewScore, FixedCamera.zs).
		double curScore = autoCand >= 0 ? AutoScore(autoCand, pmo, autoClose) : -1;
		if (curScore >= 0 && autoCam.ViewScore(pmo) <= 0) curScore = -1;

		// Hand-picked opening shot on a few maps (OpeningSpot); the normal
		// cameras take over once she leaves it.
		if (!autoOpenTried && autoCand < 0)
		{
			autoOpenTried = true;
			bool has; Vector3 spot;
			[has, spot] = OpeningSpot();
			if (has)
			{
				autoCand = AUTO_OPENING;
				teleported = false;   // the first frame of the map always looks like a jump
				autoCam.SetOrigin(spot, false);
				autoCam.ClearInterpolation();
			}
		}
		if (autoCand == AUTO_OPENING)
		{
			Vector3 mid = pmo.pos + (0, 0, pmo.Height * 0.5);
			Vector3 d = mid - autoCam.pos;
			autoCam.A_SetAngle(VectorAngle(d.x, d.y), SPF_INTERPOLATE);
			autoCam.A_SetPitch(-VectorAngle(d.xy.Length(), d.z), SPF_INTERPOLATE);
			autoCam.CameraFOV = AutoFov(d.Length());
			if (teleported || d.Length() > 500 || autoCam.ViewScore(pmo) <= 0)
			{
				if (re_debugcams) Console.Printf("opening shot ends: moved %d, %.0f away, view %.2f", teleported, d.Length(), autoCam.ViewScore(pmo));
				autoCand = -1;   // back to the normal cameras
			}
			else
			{
				for (int i = 0; i < MAXPLAYERS; i++) if (playeringame[i] && players[i].camera != autoCam) players[i].camera = autoCam;
				return;
			}
		}

		if (autoCand == AUTO_CHASE)
		{
			// No spot could see her last time: follow from behind, and look
			// for a proper spot again every few tics.
			double s;
			int best = level.maptime % 5 == 0 ? AutoFindBest(pmo, s) : -1;
			if (best >= 0 && (s >= AUTO_GOOD || !AutoChaseClear(pmo))) AutoSwitch(best, pmo);
			else AutoChase(pmo);
		}
		else if (autoCand < 0 || teleported)
		{
			double s;
			int best = AutoFindBest(pmo, s);
			if (best >= 0 && (s >= AUTO_GOOD || !AutoChaseClear(pmo))) AutoSwitch(best, pmo);
			else AutoChase(pmo);
		}
		else if (curScore < 0)
		{
			// Lost sight of her: cut quickly.
			if (++autoBlocked >= AUTO_BLOCK_TICS)
			{
				double s;
				int best = AutoFindBest(pmo, s);
				if (best >= 0) AutoSwitch(best, pmo);
				else AutoChase(pmo);
			}
		}
		else
		{
			autoBlocked = 0;
			// the opening shot picked to show the start box and typewriter
			// (FrameStartProps) stays until she walks off
			if (autoHold && (pmo.pos.xy - autoHoldPos.xy).Length() < 32) autoNextCheck = level.maptime + 35;
			else autoHold = false;
			// Once a second, cut to a clearly better spot (avoids flicker).
			if (level.maptime >= autoNextCheck)
			{
				autoNextCheck = level.maptime + 35;
				double s;
				int best = AutoFindBest(pmo, s);
				if (re_debugcams) Console.Printf("auto camera check: current %d scores %.2f, best %d scores %.2f", autoCand, curScore, best, s);
				if (best >= 0 && best != autoCand && s > curScore + 0.35) AutoSwitch(best, pmo);
			}
		}

		for (int i = 0; i < MAXPLAYERS; i++)
		{
			if (playeringame[i] && players[i].camera != autoCam) players[i].camera = autoCam;
		}
	}
}
