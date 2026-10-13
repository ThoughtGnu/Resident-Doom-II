// ---------------------------------------------------------------------------
// RE_Map.zs - the map screen (key M), in the style of RE1's: a dark blue
// screen, the rooms filled in blue (the one you're in brighter), the walls
// drawn clearly in RE1's light blue, doors in orange
// (locked ones in their key's colour), the exit in green, and a blinking
// red arrow showing where you are and which way you face. North is up.
//
// It shows the parts of the level you've seen (Doom marks them as you go).
// After picking up the MAP (Doom's computer area map, RE_DoomKeys.zs) it
// shows the whole level, the parts you haven't been to a little dimmer.
//
// It replaces Doom's automap, which only closed with its own keys. Here M or
// Esc closes it, like the inventory screen, and the game is paused while
// it's open (as in RE1). +/- or the mouse wheel zoom, the arrow keys move.
// ---------------------------------------------------------------------------

class REMapMenu : GenericMenu
{
	double scale;        // screen pixels per map unit
	Vector2 center;      // map point in the middle of the screen
	bool panned;         // moved with the arrows (else it follows the player)

	// RE1's map screen colours
	const BACK = 0xFF081028;
	const WALL = 0xFF8EC8FF;
	const STEP = 0xFF3C6CB0;
	const DOOR = 0xFFFF9A2E;
	const EXIT = 0xFF40E060;
	const ARROW = 0xFFFF3020;
	const PARTNER_COL = 0xFFFF60E0;   // the AI partner's arrow (pink)
	const ROOM = 0xFF1C3E80;      // a room you've seen
	const ROOMHERE = 0xFF3466C0;  // the room you're in
	const ROOMMAP = 0xFF142C58;   // known only from the MAP

	// Each room's floor as triangles (map units), made once when the screen
	// opens: 3 points per triangle, with the sector it belongs to.
	Array<double> triX, triY;
	Array<int> triSector;
	// Solid pillars inside rooms (holes with only walls around them), painted
	// back over the room fill.
	Array<double> holeX, holeY;
	Array<int> holeSector;

	override void Init(Menu parent)
	{
		Super.Init(parent);
		scale = 0;
		let pmo = players[consoleplayer].mo;
		if (pmo != null) center = pmo.pos.xy;
		BuildFills();
		MenuSound("menu/activate");
	}

	// --- room fills -----------------------------------------------------------

	void BuildFills()
	{
		for (int s = 0; s < level.Sectors.Size(); s++)
		{
			Sector sec = level.Sectors[s];
			// the sector's edges, each going with the sector on its right
			Array<int> ea, eb;
			Array<bool> eWall;
			for (int i = 0; i < sec.lines.Size(); i++)
			{
				Line l = sec.lines[i];
				if (l.frontsector == sec && l.backsector == sec) continue;
				bool wall = l.backsector == null;
				if (l.frontsector == sec) { ea.Push(l.v1.Index()); eb.Push(l.v2.Index()); eWall.Push(wall); }
				else if (l.backsector == sec) { ea.Push(l.v2.Index()); eb.Push(l.v1.Index()); eWall.Push(wall); }
			}
			// chain the edges into closed loops
			Array<bool> used;
			for (int i = 0; i < ea.Size(); i++) used.Push(false);
			for (int start = 0; start < ea.Size(); start++)
			{
				if (used[start]) continue;
				Array<double> px, py;
				bool allWalls = true;
				int e = start;
				for (int guard = 0; guard < ea.Size() + 1 && e >= 0; guard++)
				{
					used[e] = true;
					Vector2 p = level.Vertexes[ea[e]].p;
					px.Push(p.x); py.Push(p.y);
					if (!eWall[e]) allWalls = false;
					int next = -1;
					for (int k = 0; k < ea.Size(); k++) if (!used[k] && ea[k] == eb[e]) { next = k; break; }
					e = next;
				}
				if (px.Size() < 3) continue;
				double area = 0;
				for (int k = 0; k < px.Size(); k++) { int k2 = (k + 1) % px.Size(); area += px[k] * py[k2] - px[k2] * py[k]; }
				// the outline goes clockwise (area < 0); a hole inside goes the other way
				bool hole = area > 0;
				if (!hole) { Reverse(px); Reverse(py); }   // clip counter-clockwise
				if (hole && !allWalls) continue;          // another room fills it
				if (hole) EarClip(px, py, s, holeX, holeY, holeSector);
				else EarClip(px, py, s, triX, triY, triSector);
			}
		}
	}

	static void Reverse(Array<double> a)
	{
		for (int i = 0, j = a.Size() - 1; i < j; i++, j--) { double t = a[i]; a[i] = a[j]; a[j] = t; }
	}

	// Cuts a counter-clockwise polygon into triangles (ear clipping).
	static void EarClip(Array<double> px, Array<double> py, int sec, Array<double> ox, Array<double> oy, Array<int> os)
	{
		Array<int> idx;
		for (int i = 0; i < px.Size(); i++) idx.Push(i);
		for (int guard = 0; idx.Size() > 3 && guard < 20000; guard++)
		{
			int n = idx.Size();
			bool cut = false;
			for (int i = 0; i < n && !cut; i++)
			{
				int a = idx[(i + n - 1) % n], b = idx[i], c = idx[(i + 1) % n];
				double turn = (px[b] - px[a]) * (py[c] - py[a]) - (py[b] - py[a]) * (px[c] - px[a]);
				if (turn <= 1e-6) continue;   // a corner pointing inwards, or a straight run
				bool inside = false;
				for (int j = 0; j < n && !inside; j++)
				{
					int q = idx[j];
					if (q == a || q == b || q == c) continue;
					inside = InTri(px[q], py[q], px[a], py[a], px[b], py[b], px[c], py[c]);
				}
				if (inside) continue;
				ox.Push(px[a]); oy.Push(py[a]); ox.Push(px[b]); oy.Push(py[b]); ox.Push(px[c]); oy.Push(py[c]); os.Push(sec);
				idx.Delete(i);
				cut = true;
			}
			if (!cut)
			{
				// only straight runs or odd shapes left: drop a straight point, else fan out the rest
				bool dropped = false;
				for (int i = 0; i < n && !dropped; i++)
				{
					int a = idx[(i + n - 1) % n], b = idx[i], c = idx[(i + 1) % n];
					if (abs((px[b] - px[a]) * (py[c] - py[a]) - (py[b] - py[a]) * (px[c] - px[a])) <= 1e-6) { idx.Delete(i); dropped = true; }
				}
				if (!dropped)
				{
					for (int i = 1; i + 1 < n; i++) { ox.Push(px[idx[0]]); oy.Push(py[idx[0]]); ox.Push(px[idx[i]]); oy.Push(py[idx[i]]); ox.Push(px[idx[i + 1]]); oy.Push(py[idx[i + 1]]); os.Push(sec); }
					return;
				}
			}
		}
		if (idx.Size() == 3) { for (int k = 0; k < 3; k++) { ox.Push(px[idx[k]]); oy.Push(py[idx[k]]); } os.Push(sec); }
	}

	static bool InTri(double x, double y, double ax, double ay, double bx, double by, double cx, double cy)
	{
		double d1 = (bx - ax) * (y - ay) - (by - ay) * (x - ax);
		double d2 = (cx - bx) * (y - by) - (cy - by) * (x - bx);
		double d3 = (ax - cx) * (y - cy) - (ay - cy) * (x - cx);
		return d1 > 1e-6 && d2 > 1e-6 && d3 > 1e-6;
	}

	// Is a sector known? 1: you've been in it, or seen at least half of its
	// walls (by length), so a far-off glimpse of one wall doesn't fill the
	// whole room; 2: known only from the MAP; 0: not known. Areas whose walls
	// the level hides from the map are never filled.
	const SEEN_PART = 0.5;
	static int Known(Sector s, REMapKeyHandler visits)
	{
		if (visits != null && visits.WasIn(s.Index())) return 1;
		double total = 0, seen = 0;
		for (int i = 0; i < s.lines.Size(); i++)
		{
			Line l = s.lines[i];
			if (l.flags & Line.ML_DONTDRAW) continue;
			double len = l.delta.Length();
			total += len;
			if (l.flags & Line.ML_MAPPED) seen += len;
		}
		if (total <= 0) return 0;
		if (seen >= total * SEEN_PART) return 1;
		return level.allmap ? 2 : 0;
	}

	// Screen.DrawShapeFill takes red and blue the other way round from
	// DrawThickLine, so colours for it are given swapped.
	static Color FillColor(int col)
	{
		return Color(255, col & 255, (col >> 8) & 255, (col >> 16) & 255);
	}

	void FillTriangles(Array<double> tx, Array<double> ty, Array<int> ts, Array<int> known, int here, Vector2 mid, bool holes)
	{
		// one shape per colour
		for (int pass = 0; pass < (holes ? 1 : 3); pass++)
		{
			let sh = new("Shape2D");
			int nv = 0;
			for (int t = 0; t < ts.Size(); t++)
			{
				int k = known[ts[t]];
				if (k == 0) continue;
				int want = holes ? 0 : (ts[t] == here ? 2 : (k == 2 ? 0 : 1));
				if (!holes && want != pass) continue;
				for (int v = 0; v < 3; v++) { sh.PushVertex(ToScreen((tx[t * 3 + v], ty[t * 3 + v]), mid)); sh.PushCoord((0, 0)); }
				sh.PushTriangle(nv, nv + 1, nv + 2);
				nv += 3;
			}
			if (nv == 0) continue;
			int col = holes ? BACK : (pass == 2 ? ROOMHERE : (pass == 1 ? ROOM : ROOMMAP));
			Screen.DrawShapeFill(FillColor(col), 1.0, sh);
		}
	}

	override bool MenuEvent(int mkey, bool fromcontroller)
	{
		double step = 64 / max(scale, 0.01);
		switch (mkey)
		{
		case MKEY_Back:  Close(); MenuSound("menu/backup"); return true;
		case MKEY_Up:    center.y += step; return true;
		case MKEY_Down:  center.y -= step; return true;
		case MKEY_Left:  center.x -= step; return true;
		case MKEY_Right: center.x += step; return true;
		}
		return Super.MenuEvent(mkey, fromcontroller);
	}

	override bool OnUIEvent(UIEvent ev)
	{
		if (ev.Type == UIEvent.Type_KeyDown)
		{
			// the key bound to the map (M) closes it again
			int k1, k2;
			[k1, k2] = Bindings.GetKeysForCommand("re_map");
			int t1, t2;
			[t1, t2] = Bindings.GetKeysForCommand("togglemap");
			int ch = ev.KeyChar >= 65 && ev.KeyChar <= 90 ? ev.KeyChar + 32 : ev.KeyChar;   // upper case: as lower case
			if (ch == 109 || (k1 && ch == KeyChar(k1)) || (k2 && ch == KeyChar(k2)) || (t1 && ch == KeyChar(t1)) || (t2 && ch == KeyChar(t2))) { Close(); MenuSound("menu/backup"); return true; }   // m, or a rebound key
			if (ev.KeyChar == 0x2B || ev.KeyChar == 0x3D) { scale *= 1.25; return true; }   // + or =
			if (ev.KeyChar == 0x2D) { scale /= 1.25; return true; }                        // -
		}
		if (ev.Type == UIEvent.Type_WheelUp) { scale *= 1.25; return true; }
		if (ev.Type == UIEvent.Type_WheelDown) { scale /= 1.25; return true; }
		return Super.OnUIEvent(ev);
	}

	// The character a key types (for letters and digits: itself, lower case).
	static int KeyChar(int scan)
	{
		String name = KeyBindings.NameKeys(scan, 0);
		if (name.Length() != 1) return -1;
		return name.MakeLower().ByteAt(0);
	}

	override void Drawer()
	{
		int sw = Screen.GetWidth(), sh = Screen.GetHeight();
		Screen.Dim(BACK, 1.0, 0, 0, sw, sh);
		let pmo = players[consoleplayer].mo;
		if (pmo == null) return;
		if (scale <= 0) scale = sh / 1600.0;            // about 1600 map units top to bottom
		scale = clamp(scale, sh / 12000.0, sh / 200.0);
		double unit = sh / 400.0;                          // the size of 1 unit on the 640x400 canvas
		double thick = max(3.0, unit * 2.6), thin = max(1.5, unit * 1.2);
		Vector2 mid = (sw / 2.0, sh / 2.0);

		// the rooms
		Array<int> known;
		let seenRooms = REMapKeyHandler(EventHandler.Find("REMapKeyHandler"));
		for (int s = 0; s < level.Sectors.Size(); s++) known.Push(Known(level.Sectors[s], seenRooms));
		int here = pmo.CurSector != null ? pmo.CurSector.Index() : -1;
		FillTriangles(triX, triY, triSector, known, here, mid, false);
		FillTriangles(holeX, holeY, holeSector, known, here, mid, true);

		// the walls: one-sided lines; two-sided ones only where the floor or
		// ceiling changes (steps, ledges); never lines marked "don't draw"
		for (int i = 0; i < level.Lines.Size(); i++)
		{
			Line l = level.Lines[i];
			if (l.flags & Line.ML_DONTDRAW) continue;
			bool seen = (l.flags & Line.ML_MAPPED) != 0;
			if (!seen && !level.allmap) continue;
			Vector2 a = ToScreen(l.v1.p, mid), b = ToScreen(l.v2.p, mid);
			if (max(a.x, b.x) < 0 || min(a.x, b.x) > sw || max(a.y, b.y) < 0 || min(a.y, b.y) > sh) continue;

			int col = 0;
			double w = thick;
			int lock = LockOf(l);
			if (IsExit(l)) col = EXIT;
			else if (lock != 0) col = KeyColor(lock);
			else if (IsDoor(l)) col = DOOR;
			else if (l.backsector == null || (l.flags & Line.ML_SECRET)) col = WALL;
			else
			{
				Sector f = l.frontsector, k = l.backsector;
				if (f.floorplane.ZAtPoint(l.v1.p) == k.floorplane.ZAtPoint(l.v1.p) && f.ceilingplane.ZAtPoint(l.v1.p) == k.ceilingplane.ZAtPoint(l.v1.p)) continue;
				col = STEP; w = thin;
			}
			Screen.DrawThickLine(int(a.x), int(a.y), int(b.x), int(b.y), w, col, seen ? 255 : 130);   // not yet visited: dimmer
		}

		// the AI partner: a smaller pink arrow (drawn under yours)
		let visits = REMapKeyHandler(EventHandler.Find("REMapKeyHandler"));
		bool showPartner = visits != null && visits.hasPartner;
		if (showPartner) DrawArrow(ToScreen(visits.partnerPos, mid), visits.partnerAngle, max(5.0, unit * 5), PARTNER_COL, 1.0, thin);

		// you: a red arrow pointing the way you face, pulsing like RE1's (never gone)
		DrawArrow(ToScreen(pmo.pos.xy, mid), pmo.Angle, max(7.0, unit * 7), ARROW, (MenuTime() / 10) % 3 == 2 ? 0.55 : 1.0, thin);

		// title, legend and keys, on the 640x400 canvas
		REDraw.Box(0, 0, 640, 30, Color(255, 0, 0, 0), 0.6);
		REDraw.Text(16, 6, "MAP", Font.CR_GOLD, 1.6);
		REDraw.Text(80, 9, String.Format("%s  %s", level.MapName, level.LevelName), Font.CR_WHITE, 1.1);
		if (!level.allmap) REDraw.Text(380, 9, "Only the areas you've seen", Font.CR_DARKGRAY, 1.0);
		REDraw.Box(0, 368, 640, 32, Color(255, 0, 0, 0), 0.6);
		double x = 16;
		x = Legend(x, 374, ARROW, "You");
		if (showPartner) x = Legend(x, 374, PARTNER_COL, visits.partnerName);
		x = Legend(x, 374, WALL, "Wall");
		x = Legend(x, 374, DOOR, "Door");
		x = Legend(x, 374, KeyColor(2), "Locked (key colour)");
		x = Legend(x, 374, EXIT, "Exit");
		REDraw.Text(16, 388, "M or ESC close     +/- or wheel zoom     ARROWS move", Font.CR_DARKGRAY, 0.8);
	}

	void DrawArrow(Vector2 p, double ang, double r, int col, double alpha, double thin)
	{
		Vector2 tip = p + Dir(ang) * r * 1.4, l = p + Dir(ang + 140) * r, rr = p + Dir(ang - 140) * r, back = p + Dir(ang + 180) * r * 0.4;
		let s = new("Shape2D");
		s.PushVertex(tip); s.PushVertex(l); s.PushVertex(back); s.PushVertex(rr);
		for (int v = 0; v < 4; v++) s.PushCoord((0, 0));
		s.PushTriangle(0, 1, 2); s.PushTriangle(0, 2, 3);
		Screen.DrawShapeFill(FillColor(col), alpha, s);
		int o = 0xFFFFFFFF;
		Screen.DrawThickLine(int(tip.x), int(tip.y), int(l.x), int(l.y), thin, o, 255);
		Screen.DrawThickLine(int(l.x), int(l.y), int(back.x), int(back.y), thin, o, 255);
		Screen.DrawThickLine(int(back.x), int(back.y), int(rr.x), int(rr.y), thin, o, 255);
		Screen.DrawThickLine(int(rr.x), int(rr.y), int(tip.x), int(tip.y), thin, o, 255);
	}

	double Legend(double x, double y, int col, String text)
	{
		REDraw.Box(x, y + 3, 14, 4, col, 1.0);
		REDraw.Text(x + 18, y - 1, text, Font.CR_GRAY, 0.9);
		return x + 18 + REDraw.TextWidth(text, 0.9) + 18;
	}

	Vector2 ToScreen(Vector2 p, Vector2 mid)
	{
		return (mid.x + (p.x - center.x) * scale, mid.y - (p.y - center.y) * scale);
	}

	static Vector2 Dir(double ang) { return (cos(ang), -sin(ang)); }   // screen y points down

	// Doors and locks (Doom's specials as GZDoom translates them). Only a door
	// you open yourself (no tag: the line is the door). Lines with a tag are
	// triggers - a switch, or a line on the floor you walk over - that open a
	// door somewhere else, and aren't marked.
	static bool IsDoor(Line l)
	{
		int s = l.special;
		bool door = (s >= 10 && s <= 14) || s == 202 || s == 249 || s == 105 || s == 106;
		return door && l.args[0] == 0;
	}
	static int LockOf(Line l)
	{
		if (l.args[0] != 0) return 0;
		if (l.special == 13) return l.args[3];
		if (l.special == 202) return l.args[4];
		return 0;
	}
	static bool IsExit(Line l) { return l.special == 243 || l.special == 244; }
	static int KeyColor(int lock)
	{
		switch (lock % 128)
		{
		case 1: case 4: return 0xFFFF3830;   // red card / skull: Shield Key, Sun Crest
		case 2: case 5: return 0xFF4878FF;   // blue: Armor Key, Helmet Key
		case 3: case 6: return 0xFFFFD030;   // yellow: Sword Key, Star Crest
		}
		return DOOR;
	}
}

// Keys still bound to Doom's automap (an older version put it on M, and
// GZDoom keeps that in its settings file, ahead of keys.cfg) open the map
// screen instead, so Doom's automap - which those keys couldn't close -
// never comes up. Bindings themselves are left alone. It also remembers
// which rooms you've stood in, for the map screen.
class REMapKeyHandler : EventHandler
{
	// The rooms (sectors) you've stood in on this map; saved with the game.
	Array<bool> visited;

	override void WorldLoaded(WorldEvent e)
	{
		if (e.IsSaveGame) return;
		visited.Clear();
		for (int i = 0; i < level.Sectors.Size(); i++) visited.Push(false);
	}

	override void WorldTick()
	{
		let pmo = players[consoleplayer].mo;
		if (pmo == null || pmo.CurSector == null) return;
		int i = pmo.CurSector.Index();
		if (i < visited.Size()) visited[i] = true;
		let partner = REPartner.Find();
		hasPartner = partner != null;
		if (hasPartner) { partnerPos = partner.pos.xy; partnerAngle = partner.Angle; partnerName = partner.GetTag(); }
	}

	// The AI partner, for their arrow on the map screen.
	bool hasPartner;
	Vector2 partnerPos;
	double partnerAngle;
	String partnerName;

	clearscope bool WasIn(int i) { return i >= 0 && i < visited.Size() && visited[i]; }

	override bool InputProcess(InputEvent e)
	{
		if (e.Type != InputEvent.Type_KeyDown || gamestate != GS_LEVEL || automapactive || Menu.GetCurrentMenu() != null) return false;
		int k1, k2;
		[k1, k2] = Bindings.GetKeysForCommand("togglemap");
		if (e.KeyScan != k1 && e.KeyScan != k2) return false;
		Menu.SetMenu('REMapMenu');
		return true;
	}
}