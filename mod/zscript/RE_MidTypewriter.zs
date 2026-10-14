// ---------------------------------------------------------------------------
// RE_MidTypewriter.zs - a second typewriter about halfway through long maps.
//
// When a map starts, the route from the player start to the exit is found
// by walking the map's own areas (sectors) through their openings and doors,
// like a player would (no new rooms). Maps whose route is longer than
// RE_MID_MIN_ROUTE map units get a typewriter at a quiet spot near the middle
// of that route: on an open floor, with no monster within RE_MID_QUIET units
// or in sight, and not on a damaging floor. The exit is the line that ends the
// level (Exit_Normal / Exit_Secret / Teleport_NewMap); a map without one uses
// the area furthest from the start.
// ---------------------------------------------------------------------------

const RE_MID_MIN_ROUTE = 2500;
const RE_MID_QUIET = 256;      // no monster starts closer than this, or in the same area
const RE_MID_MIN_SECTORS = 150; // ... or a map this big counts as long too

class REMidTypewriterHandler : EventHandler
{
	override void WorldLoaded(WorldEvent e)
	{
		if (e.IsSaveGame) return;   // already placed, saved with the map
		let pmo = REMain.Player();
		if (pmo == null) return;

		int n = level.Sectors.Size();
		Array<double> cx; Array<double> cy;
		cx.Resize(n); cy.Resize(n);
		for (int i = 0; i < n; i++)
		{
			Sector s = level.Sectors[i];
			Vector2 c = (0, 0);
			for (int k = 0; k < s.lines.Size(); k++) c += s.lines[k].v1.p;
			c /= max(1, s.lines.Size());
			cx[i] = c.x; cy[i] = c.y;
		}

		// Shortest route over the sector graph (Dijkstra, distances between
		// sector middles).
		Array<double> dist; Array<int> prev; Array<bool> done;
		dist.Resize(n); prev.Resize(n); done.Resize(n);
		for (int i = 0; i < n; i++) { dist[i] = 1e12; prev[i] = -1; done[i] = false; }
		int start = pmo.CurSector.Index();
		dist[start] = 0;
		for (int step = 0; step < n; step++)
		{
			int u = -1;
			for (int i = 0; i < n; i++) if (!done[i] && dist[i] < 1e12 && (u < 0 || dist[i] < dist[u])) u = i;
			if (u < 0) break;
			done[u] = true;
			Sector s = level.Sectors[u];
			for (int k = 0; k < s.lines.Size(); k++)
			{
				Line ln = s.lines[k];
				if (ln.backsector == null) continue;
				Sector o = ln.frontsector == s ? ln.backsector : ln.frontsector;
				if (o == null || o == s || !Passable(ln, s, o)) continue;
				int v = o.Index();
				double d = dist[u] + (cx[u] - cx[v], cy[u] - cy[v]).Length();
				if (d < dist[v]) { dist[v] = d; prev[v] = u; }
			}
		}

		// The goal: the exit closest by route, else the furthest area.
		int goal = -1;
		for (int i = 0; i < level.Lines.Size(); i++)
		{
			Line ln = level.Lines[i];
			if (ln.special != Exit_Normal && ln.special != Exit_Secret && ln.special != Teleport_NewMap) continue;
			for (int side = 0; side < 2; side++)
			{
				Sector s = side == 0 ? ln.frontsector : ln.backsector;
				if (s == null || dist[s.Index()] >= 1e12) continue;
				if (goal < 0 || dist[s.Index()] < dist[goal]) goal = s.Index();
			}
		}
		if (goal < 0)
			for (int i = 0; i < n; i++)
				if (dist[i] < 1e12 && (goal < 0 || dist[i] > dist[goal])) goal = i;
		if (re_debugcams) Console.Printf("Mid typewriter: %s route %.0f, %d sectors", level.MapName, goal >= 0 ? dist[goal] : 0, n);
		if (goal < 0 || (dist[goal] < RE_MID_MIN_ROUTE && n < RE_MID_MIN_SECTORS))
		{
			if (re_debugcams) Console.Printf("Mid typewriter: map too short (%.0f)", goal >= 0 ? dist[goal] : 0);
			return;
		}


		// Look at spots in every area that is between a quarter and three
		// quarters of the way (counted along the way there, so side rooms
		// count too) and keep the quietest: furthest from any monster start.
		double bestScore = -1;
		Vector3 best;
		for (int i = 0; i < n; i++)
		{
			double d = dist[i];
			if (d >= 1e12 || d < dist[goal] / 4 || d > dist[goal] * 3 / 4) continue;
			Sector s = level.Sectors[i];
			for (int t = 0; t < 50; t++)   // the middle and the whole grid: maps with a lot of water have few dry, quiet spots (MAP14)
			{
				if (!FreeSpot(s, t)) continue;
				double score = Quietness(spotFound);
				if (score > bestScore) { bestScore = score; best = spotFound; }
			}
		}
		if (bestScore < RE_MID_QUIET)
		{
			if (re_debugcams) Console.Printf("Mid typewriter: no quiet spot found (best %.0f)", bestScore);
			return;
		}
		let tw = Actor.Spawn("RETypewriter", best);
		if (tw != null)
		{
			tw.Angle = random[mid](0, 359);
			// the map's second Ink Ribbon, beside it (RE_ItemBox.zs),
			// or if there's no room beside it, on another free spot in its area
			if (REItemBoxHandler.PlaceBeside(tw, null, "REInkRibbonPickup") == null)
			{
				Sector s = tw.CurSector;
				for (int t = 1; t <= 48; t++)
				{
					if (!FreeSpot(s, t) || (spotFound.xy - tw.pos.xy).Length() < 40) continue;
					Actor.Spawn("REInkRibbonPickup", spotFound);
					break;
				}
			}
			if (re_debugcams) Console.Printf("Mid typewriter placed (%.0f, %.0f), nearest monster %.0f away", best.x, best.y, bestScore);
		}
	}
	// Can a player get from sector a to sector b over this line? Doors count
	// as open; lifts and stairs too (a rough rule, enough for "halfway").
	static bool Passable(Line ln, Sector a, Sector b)
	{
		if (ln.flags & (Line.ML_BLOCKING | Line.ML_BLOCK_PLAYERS)) return false;
		double gap = min(a.CenterCeiling(), b.CenterCeiling()) - max(a.CenterFloor(), b.CenterFloor());
		if (gap >= 56) return true;
		// a closed door or lift: some line around b opens it, or b is tagged
		return b.GetTag(0) != 0 || IsDoorLine(ln);
	}

	static bool IsDoorLine(Line ln)
	{
		int sp = ln.special;
		return sp == Door_Raise || sp == Door_Open || sp == Door_LockedRaise || sp == Generic_Door
			|| sp == Door_Animated;
	}

	Vector3 spotFound;   // set by FreeSpot

	// Try number t for a free floor spot in this sector (0 = its middle).
	bool FreeSpot(Sector s, int t)
	{
		if (s.damageamount > 0) return false;
		if (s.CenterCeiling() - s.CenterFloor() < 64) return false;
		double x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
		for (int k = 0; k < s.lines.Size(); k++)
		{
			Vector2 v = s.lines[k].v1.p;
			x0 = min(x0, v.x); y0 = min(y0, v.y); x1 = max(x1, v.x); y1 = max(y1, v.y);
		}
		if (x1 - x0 < 64 || y1 - y0 < 64) return false;
		// 0: the middle; then an even 7 x 7 grid over the area (the same spots every time)
		int g = (t - 1) % 49;
		Vector2 p = t == 0 ? ((x0 + x1) / 2, (y0 + y1) / 2) : (x0 + 24 + (g % 7) * (x1 - x0 - 48) / 6, y0 + 24 + (g / 7) * (y1 - y0 - 48) / 6);
		if (level.PointInSector(p) != s) return false;
		double fz = s.floorplane.ZAtPoint(p);
		let probe = Actor.Spawn("RETypewriter", (p.x, p.y, fz));
		if (probe == null) return false;
		probe.Angle = random[mid](0, 359);
		bool ok = probe.TestMobjLocation() && RETypewriter.LeavesRoom(probe) && REItemBoxHandler.SafeSpot(probe)   // never in liquid (RE_ItemBox.zs)
			&& !REItemBoxHandler.BlocksWalkway(probe);   // never in the way (a narrow corridor or opening)
		probe.Destroy();
		if (ok) spotFound = (p.x, p.y, fz);
		return ok;
	}

	// How quiet a spot is: the distance to the nearest monster's start
	// (a monster starting in the same area counts as right there).
	double Quietness(Vector3 at)
	{
		Sector here = level.PointInSector(at.xy);
		double nearest = 1e6;
		let it = ThinkerIterator.Create("Actor");
		Actor mo;
		while (mo = Actor(it.Next()))
		{
			if (!mo.bIsMonster || mo.health <= 0) continue;
			double d = (mo.pos.xy - at.xy).Length();
			if (mo.CurSector == here) d = 0;
			nearest = min(nearest, d);
		}
		return nearest;
	}
}
