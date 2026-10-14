// ---------------------------------------------------------------------------
// RE_Balance.zs - evens out Doom II's item counts for RE-style play, at every
// map start (not a loaded game), after the items have become RE1's.
//
// Only the extremes change; everything else stays in its original Doom spot:
//   - too little healing (fewer than 2 herbs + First Aid Sprays): green herbs
//     are added beside the item box (RE_ItemBox.zs) to make 2
//   - no clips: one clip beside the item box (everyone has the Beretta)
//   - a gun lying in the map with no ammo for it on the map: one pickup of its
//     ammo right beside the gun
//   - poisonous enemies (Arachnotrons, the Spider Mastermind, RE_Poison.zs):
//     blue herbs - 1 for 1-2 of them, 2 for 3-5, 3 for 6 or more - each set
//     beside the green herb nearest one of those enemies (spread over
//     different enemies), or beside the nearest other item if there's no
//     green herb near. No herb is taken away.
//   - flooded: 20 or more of one ammo kind (kept 15), 15 or more herbs (kept
//     12), 20 or more vest patches (kept 12). The extras taken away are spread
//     evenly over the map, so every area keeps some.
// re_debugcams 1 prints the counts before and after.
// ---------------------------------------------------------------------------

class REBalanceHandler : EventHandler
{
	static const class<Actor> kinds[] = {
		"REGreenHerb", "RERedHerb", "REBlueHerb", "REFirstAidSprayPickup",
		"REClipPickup", "REShellsPickup", "REMagnumRoundsPickup", "REExplosiveRoundsPickup",
		"REAcidRoundsPickup", "REFlameRoundsPickup", "REVestPatch" };
	static const String labels[] = { "green", "red", "blue", "spray", "clip", "shells", "magnum", "explosive", "acid", "flame", "patch" };

	override void WorldLoaded(WorldEvent e)
	{
		if (e.IsSaveGame) return;
		let pmo = REMain.Player();
		if (pmo == null) return;
		String before = Counts();

		// Flooded: thin out evenly, keeping the original spots of the rest.
		for (int k = 4; k <= 9; k++) Thin(kinds[k], null, 20, 15, pmo);
		// herbs: only the green ones are thinned (red and blue are rare, all kept)
		if (Count("REHerbPickup") >= 15) Thin("REGreenHerb", null, 0, max(4, 12 - Count("RERedHerb") - Count("REBlueHerb")), pmo);
		Thin(kinds[10], null, 20, 12, pmo);

		// Too little: add beside the item box (or the player).
		Actor box = FindOne("REItemBoxActor");
		Actor near = pmo;
		if (box != null) near = box;
		int healing = Count("REHerbPickup") + Count("REFirstAidSprayPickup");
		for (int i = healing; i < 2; i++) REItemBoxHandler.NoteStartPickup(REItemBoxHandler.PlaceBeside(near, pmo, "REGreenHerb"));
		if (Count("REClipPickup") == 0) REItemBoxHandler.NoteStartPickup(REItemBoxHandler.PlaceBeside(near, pmo, "REClipPickup"));
		NeedAmmo("REShotgunPickup", "REShellsPickup");
		NeedAmmo("REPythonPickup", "REMagnumRoundsPickup");
		NeedAmmo("REBazookaPickup", "REExplosiveRoundsPickup");
		NeedAmmo("REBazookaAcidPickup", "REAcidRoundsPickup");

		BlueHerbs();

		if (re_debugcams) Console.Printf("BALANCE %s | before %s | after %s", level.MapName, before, Counts());
	}

	// Blue herbs near the poisonous enemies, beside existing items.
	void BlueHerbs()
	{
		Array<Actor> spiders;
		let it = ThinkerIterator.Create("Actor");
		Actor mo;
		while (mo = Actor(it.Next())) if (REPoison.IsPoisoner(mo) && mo.health > 0) spiders.Push(mo);
		int n = spiders.Size();
		if (n == 0) return;
		int want = n <= 2 ? 1 : (n <= 5 ? 2 : 3);

		// spread out: the first enemy, then each time the one farthest from those picked
		Array<Actor> picked;
		picked.Push(spiders[0]);
		while (picked.Size() < want)
		{
			Actor far = null;
			double farDist = -1;
			for (int i = 0; i < n; i++)
			{
				double d = 1e9;
				for (int k = 0; k < picked.Size(); k++) d = min(d, spiders[i].Distance2D(picked[k]));
				if (d > farDist) { farDist = d; far = spiders[i]; }
			}
			picked.Push(far);
		}

		Array<Actor> used;   // items already given a blue herb
		for (int k = 0; k < picked.Size(); k++)
		{
			Actor next = Nearest("REGreenHerb", picked[k], used, 1536);
			if (next == null) next = Nearest("REPickup", picked[k], used, 1536);
			Actor blue = null;
			if (next != null) { used.Push(next); blue = REItemBoxHandler.PlaceBeside(next, null, "REBlueHerb"); }
			if (blue == null) blue = REItemBoxHandler.PlaceBeside(picked[k], null, "REBlueHerb");   // last resort: by the enemy's spot
			if (re_debugcams) Console.Printf("BLUEHERB %s: %d poisonous, #%d near %s at (%d, %d): %s", level.MapName, n, k + 1, picked[k].GetClassName(),
				int(picked[k].pos.x), int(picked[k].pos.y), blue == null ? "no room" : String.Format("placed at (%d, %d) beside %s", int(blue.pos.x), int(blue.pos.y), next != null ? next.GetTag() : "the enemy"));
		}
	}

	// The nearest item of a kind (not a blue herb, not one in 'skip') within range.
	static Actor Nearest(class<Actor> what, Actor to, Array<Actor> skip, double range)
	{
		Actor best = null;
		double bestDist = range;
		let it = ThinkerIterator.Create(what);
		Actor mo;
		while (mo = Actor(it.Next()))
		{
			if (mo is "REBlueHerb" || skip.Find(mo) != skip.Size()) continue;
			double d = mo.Distance3D(to);
			if (d < bestDist) { bestDist = d; best = mo; }
		}
		return best;
	}

	String Counts()
	{
		String s = "";
		for (int k = 0; k < kinds.Size(); k++) s = s .. String.Format("%s %d ", labels[k], Count(kinds[k]));
		return s;
	}

	static int Count(class<Actor> what)
	{
		int n = 0;
		let it = ThinkerIterator.Create(what);
		while (it.Next()) n++;
		return n;
	}

	static Actor FindOne(class<Actor> what)
	{
		let it = ThinkerIterator.Create(what);
		return Actor(it.Next());
	}

	// A gun in the map whose ammo is nowhere on it: one pickup beside the gun.
	void NeedAmmo(class<Actor> gun, class<Actor> ammo)
	{
		if (Count(ammo) > 0) return;
		Actor g = FindOne(gun);
		if (g != null) REItemBoxHandler.PlaceBeside(g, null, ammo);
	}

	// More than 'limit': keep 'keep', taking away evenly spread ones (in order
	// of distance from the start, every n-th).
	void Thin(class<Actor> what, Actor unused, int limit, int keep, Actor pmo)
	{
		Array<Actor> all;
		let it = ThinkerIterator.Create(what);
		Actor mo;
		while (mo = Actor(it.Next())) all.Push(mo);
		if (all.Size() < limit) return;
		// sort by distance from the start
		for (int i = 1; i < all.Size(); i++)
			for (int j = i; j > 0 && all[j].Distance3D(pmo) < all[j - 1].Distance3D(pmo); j--)
			{
				let t = all[j]; all[j] = all[j - 1]; all[j - 1] = t;
			}
		int n = all.Size(), drop = n - keep;
		for (int d = 0; d < drop; d++) { all[(d * n) / drop].ClearCounters(); all[(d * n) / drop].Destroy(); }   // (items %: gone from the total too)
	}
}

// Secret areas (Doom's secret sectors): the map's first secret (lowest sector
// number) always holds a S.T.A.R.S. vest - the light one up to MAP20, the heavy
// one from MAP21 - unless it already has armor. re_debugcams 1 lists every
// secret and what is in it.
class RESecretVestHandler : EventHandler
{
	override void WorldLoaded(WorldEvent e)
	{
		if (e.IsSaveGame) return;
		Array<Sector> secrets;
		for (int i = 0; i < level.Sectors.Size(); i++) if (level.Sectors[i].IsSecret()) secrets.Push(level.Sectors[i]);
		if (secrets.Size() == 0) { if (re_debugcams) Console.Printf("SECRETS %s: 0", level.MapName); return; }

		// what each secret holds (before anything is added)
		Array<String> contents;
		for (int s = 0; s < secrets.Size(); s++)
		{
			String items = "";
			let it = ThinkerIterator.Create("Actor");
			Actor mo;
			while (mo = Actor(it.Next()))
			{
				if (mo.CurSector != secrets[s] || mo.bIsMonster || mo.player) continue;
				let inv = Inventory(mo);
				if ((inv != null && inv.Owner == null && !(inv is "HexenArmor") && !(inv is "BasicArmor")) || mo is "REPickup")
					items = items .. mo.GetTag() .. ", ";
			}
			contents.Push(items.Length() > 0 ? items.Left(items.Length() - 2) : "empty");
		}

		Sector first = secrets[0];
		bool armored = HasArmor(first);
		String added = armored ? "  (has armor, left as is)" : "";
		if (!armored)
		{
			class<Actor> vest = level.levelnum >= 21 && level.levelnum <= 32 ? "REVestHeavyPickup" : "REVestLightPickup";
			// the first secret; if it has no room (a closed door or a tiny
			// spot), the next one
			Actor v = null;
			int at = 0;
			bool done = false;
			for (; at < secrets.Size() && v == null; at++)
			{
				if (at > 0 && HasArmor(secrets[at])) { done = true; break; }   // a later secret with armor already
				v = PlaceIn(secrets[at], vest);
			}
			if (!done) at--;
			if (v == null && !done) { v = PlaceAnyway(first, vest); at = 0; }
			if (done) added = String.Format("  (no room here; secret #%d already has armor)", at + 1);
			else if (v == null) added = "  (no room for a vest in any secret)";
			else if (at == 0) added = String.Format("  + added %s", v.GetTag());
			else { added = String.Format("  (no room here: %s added in secret #%d)", v.GetTag(), at + 1); contents[at] = contents[at] .. String.Format("  + added %s", v.GetTag()); }
		}
		if (!re_debugcams) return;
		Console.Printf("SECRETS %s: %d", level.MapName, secrets.Size());
		for (int s = 0; s < secrets.Size(); s++)
			Console.Printf("SECRET %s #%d (sector %d): %s%s", level.MapName, s + 1, secrets[s].Index(), contents[s], s == 0 ? added : "");
	}
	static bool HasArmor(Sector s)
	{
		let it = ThinkerIterator.Create("BasicArmorPickup");
		Actor mo;
		while (mo = Actor(it.Next())) if (mo.CurSector == s) return true;
		return false;
	}

	// Last resort: on an item already lying in the secret, else its middle.
	static Actor PlaceAnyway(Sector s, class<Actor> what)
	{
		let it = ThinkerIterator.Create("Inventory");
		Inventory inv;
		while (inv = Inventory(it.Next())) if (inv.Owner == null && inv.CurSector == s) return Actor.Spawn(what, inv.pos);
		let it2 = ThinkerIterator.Create("REPickup");
		Actor rp;
		while (rp = Actor(it2.Next())) if (rp.CurSector == s) return Actor.Spawn(what, rp.pos);
		for (int k = 0; k < s.lines.Size(); k++)
		{
			Vector2 p = (s.lines[k].v1.p + s.lines[k].v2.p) / 2;
			Vector2 c = s.CenterSpot;
			Vector2 q = p + (c - p).Unit() * 8;
			if (level.PointInSector(q) == s) return Actor.Spawn(what, (q.x, q.y, s.floorplane.ZAtPoint(q)));
		}
		return null;
	}

	// A free spot on the sector's floor: its middle, else random points in it.
	static Actor PlaceIn(Sector s, class<Actor> what)
	{
		double x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
		for (int k = 0; k < s.lines.Size(); k++)
		{
			Vector2 v = s.lines[k].v1.p;
			x0 = min(x0, v.x); y0 = min(y0, v.y); x1 = max(x1, v.x); y1 = max(y1, v.y);
		}
		for (int t = 0; t < 128; t++)
		{
			double m = t < 64 ? 16 : 4;   // then nearer the edges
			Vector2 p = t == 0 ? ((x0 + x1) / 2, (y0 + y1) / 2) : (frandom[secret](x0 + m, max(x0 + m, x1 - m)), frandom[secret](y0 + m, max(y0 + m, y1 - m)));
			if (level.PointInSector(p) != s) continue;
			let mo = Actor.Spawn(what, (p.x, p.y, s.floorplane.ZAtPoint(p)));
			if (mo == null) continue;
			// a closed secret door or lift (ceiling down at the start) still counts: it opens
			if (mo.TestMobjLocation() && REItemBoxHandler.SafeSpot(mo)) return mo;   // never in liquid / on a hurting floor
			mo.Destroy();
		}
		return null;
	}
}
