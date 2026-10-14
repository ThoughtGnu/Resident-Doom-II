// ---------------------------------------------------------------------------
// RE_ItemBox.zs - RE1's item boxes.
//
// RE1 has one shared item box with 48 slots (BioCard.h itemboxSlots[48]):
// whatever you put in one box, you can take out of any other. Here every map
// gets a box near the player start (it looks like Doom's tall tech column).
// Face it and press Action to open the box screen:
//
//   Left / Right   switch between your items and the box
//   Up / Down      move
//   Enter / click  put the item in the box, or take it out
//   Esc / Tab      close
//
// The box's contents are carried by Jill (REItemBox below), so they go with
// her to the next map and are saved with the game.
// ---------------------------------------------------------------------------

class REItemBox : Inventory
{
	const BOX_SLOTS = 48;
	int boxId[BOX_SLOTS];
	int boxQty[BOX_SLOTS];

	Default
	{
		+INVENTORY.UNDROPPABLE
		+INVENTORY.UNTOSSABLE
		+INVENTORY.UNCLEARABLE
		Inventory.MaxAmount 1;
	}

	void PutIn(REInventory inv, int s)
	{
		if (!inv.ValidSlot(s)) return;
		int b = -1;
		for (int i = 0; i < BOX_SLOTS; i++) if (boxId[i] == RE_ITEM_NONE) { b = i; break; }
		if (b < 0)
		{
			inv.ShowMessage("The box is full.");
			return;
		}
		if (s == inv.equippedSlot) inv.Unequip();   // saves the rounds left in the gun
		boxId[b] = inv.slotId[s];
		boxQty[b] = inv.slotQty[s];
		inv.ClearSlot(s);
		inv.ShowMessage(String.Format("You put the %s in the box.", REItemInfo.GetName(boxId[b])));
	}

	// Items always move, never copy. A non-stackable item (the knife has
	// quantity 0) needs a free slot; a stack moves as much as fits.
	void TakeOut(REInventory inv, int b)
	{
		if (b < 0 || b >= BOX_SLOTS || boxId[b] == RE_ITEM_NONE) return;
		int id = boxId[b];
		int left;
		if (REItemInfo.IsStackable(id) && boxQty[b] > 0)
		{
			left = inv.Store(id, boxQty[b]);
			if (left == boxQty[b]) { inv.ShowMessage("You can't carry any more items."); return; }
		}
		else
		{
			int s = inv.FindFreeSlot();
			if (s < 0) { inv.ShowMessage("You can't carry any more items."); return; }
			inv.SetSlot(s, id, boxQty[b]);
			left = 0;
		}
		inv.ShowMessage(String.Format("You took the %s.", REItemInfo.GetName(id)));
		boxQty[b] = left;
		if (left == 0)
		{
			// Close the gap, so the box list stays in order like RE1's.
			for (int i = b; i < BOX_SLOTS - 1; i++) { boxId[i] = boxId[i + 1]; boxQty[i] = boxQty[i + 1]; }
			boxId[BOX_SLOTS - 1] = RE_ITEM_NONE;
			boxQty[BOX_SLOTS - 1] = 0;
		}
	}
}

// The box you see in the map: RE1's own item box lid on a matching body,
// built from your RE1 files (tools\re1convert\re1convert.exe itembox, model
// mod/models/props/itembox.md3; the IBOX sprites are invisible placeholders).
// About 38 x 57 and 23 high; the front (the long side) faces the player.
// Like RE1, the lid opens before the box screen appears, and closes after.
class REItemBoxActor : Actor
{
	int opener;   // the player who opened it (+1; 0 = closed)

	Default
	{
		Tag "Item Box";
		Radius 20;      // keeps the typewriter's usual spot beside it (RETypewriter.FitAgainstWall)
		Height 32;      // above the 24-unit step height, so nobody can walk up onto it
		+SOLID
	}
	States
	{
	Spawn:
		IBOX A -1;
		Stop;
	Opening:
		// RE1's lid curve (check_itembox_state), about twice as fast
		IBOX BCDEFGHIJK 2;
		IBOX L 1 A_LidOpen;
	Open:
		IBOX L -1;
		Stop;
	Closing:
		IBOX KJIHGFEDCB 1;
		Goto Spawn;
	}

	// E in front of the box (TankPlayer.zs OpenBoxAhead).
	void StartOpening(PlayerPawn who)
	{
		if (opener != 0) return;   // already opening or open
		opener = who.PlayerNumber() + 1;
		A_StartSound("misc/i_pkup", CHAN_BODY, CHANF_DEFAULT, 0.5);
		SetStateLabel("Opening");
	}

	// The lid is open: show the box screen to the player who opened it.
	void A_LidOpen()
	{
		if (opener > 0) EventHandler.SendInterfaceEvent(opener - 1, "re_openbox");
	}

	// The box screen closed (REItemBoxMenu.OnDestroy).
	void StartClosing()
	{
		if (opener == 0) return;
		opener = 0;
		SetStateLabel("Closing");
	}

	// RE1 lighting: kept readable in dark rooms, like the typewriter.
	override void Tick()
	{
		Super.Tick();
		lightlevel = re_dark ? RELightingHandler.Glow(self, 32, 128, 0) : -1;
	}
}

class REItemBoxHandler : EventHandler
{
	// Every map: put a box near the player start, behind them first so it
	// doesn't block the view.
	override void WorldLoaded(WorldEvent e)
	{
		if (e.IsSaveGame) return;   // the box was saved with the map
		let pmo = REMain.Player();
		if (pmo == null) return;
		startPickups.Clear();
		MergeStacked();
		// a hand-placed box (StartLayout): slim, at its spot, facing as given
		for (int i = 0; i < layout.Size(); i++)
		{
			Array<String> f;
			layout[i].Split(f, "|");
			if (f[0] != level.MapName.MakeUpper() || f[1] != "box") continue;
			let box = Spawn("REItemBoxActor", (f[2].ToDouble(), f[3].ToDouble()));
			if (box != null) { box.A_SetSize(16); box.Angle = f[4].ToDouble(); }
			HandPlaced(pmo);
			return;
		}
		// First a spot where the typewriter fits too; in a narrow corridor the
		// box may leave it no room, so then the box gets a slimmer collision
		// (radius 16, as the old box had); failing that, any spot for the box.
		for (int pass = 0; pass < 3; pass++)
		{
			for (int i = 0; i < 16; i++)
			{
				double dist = i < 8 ? 64 : 112;
				Vector2 at = pmo.pos.xy + Actor.AngleToVector(pmo.Angle + 180 + (((i % 8) + 1) / 2) * 45 * ((i % 2) * 2 - 1), dist);
				if (!level.IsPointInLevel((at.x, at.y, pmo.pos.z))) continue;
				let box = Actor.Spawn("REItemBoxActor", (at.x, at.y, pmo.floorz));
				if (box == null) continue;
				if (pass > 0) box.A_SetSize(16);
				box.SetZ(box.floorz);
				if (pass < 2 && abs(box.floorz - pmo.floorz) <= 24 && box.TestMobjLocation() && !NoPocket(box)) SlideToWall(box, pmo);
				if (abs(box.floorz - pmo.floorz) <= 24 && box.TestMobjLocation() && SafeSpot(box) && box.CheckSight(pmo) && (pass == 2 || (NoPocket(box) && !BlocksWalkway(box))))
				{
					if (pass == 2 && re_debugcams) Console.Printf("item box: no spot without a narrow gap");
					box.Angle = box.AngleTo(pmo);   // the front (long side) faces the start
					// A hand-picked start layout (StartLayout), or: a typewriter
					// right beside the box (RE_Typewriter.zs) and the map's start
					// Ink Ribbon beside that.
					if (HandPlaced(pmo)) return;
					Actor tw = PlaceApart(box, pmo, null);   // a few steps from the box, like MAP01
					if (tw == null) tw = PlaceBeside(box, pmo, "RETypewriter");
					if (tw == null) tw = PlaceBeside(pmo, pmo, "RETypewriter");   // no room by the box: by the player
					if (tw != null || pass == 2)
					{
						Actor rib = tw != null ? PlaceBeside(tw, pmo, "REInkRibbonPickup") : null;
						if (rib == null) rib = PlaceBeside(pmo, pmo, "REInkRibbonPickup");
						if (rib != null) startPickups.Push(rib);
						startBox = box; startTw = tw; startRib = rib;
						return;
					}
				}
				box.Destroy();
			}
		}
	}

	// Ink Ribbons: one per pickup, one by the start typewriter on every map
	// and one by the halfway typewriter on long maps (RE_MidTypewriter.zs).

	// --- hand-picked start layouts ---------------------------------------------
	// A few maps place their start typewriter and ribbons by hand (the item
	// box stays automatic). Each entry: what, x, y, angle. "herb" means: the
	// green herb nearest (x, y) becomes the start ribbon.
	static const String layout[] = {
		"MAP01|typewriter|-290|905|30",
		"MAP01|herb|96|1056|0",
		"MAP01|ribbon|-500|862|0",
		"MAP07|box|88|-292|180",   // the start corridor is only 80 wide: a slim box flat against the east wall
		"MAP07|typewriter|40|-358|90",
		// small start rooms where no automatic spot showed both in the opening shot
		"MAP03|box|1950|3552|270",
		"MAP03|typewriter|1872|3488|45",   // the south-west corner: clear of the west door, of the box, and of the way to the crawl gap and the east door
		"MAP04|box|-1000|1712|335",       // the north-west corner (it stood right in front of the south door)
		"MAP04|typewriter|-872|1710|270",
		"MAP06|box|1456|752|200",         // the north-east corner, behind the start (it stood in front of the recess drawn as a door)
		"MAP06|typewriter|1360|750|270",
		"MAP06|partner|1440|660|90",
		"MAP09|box|352|352|180",          // a small stone cross in the liquid: the box on its east arm,
		"MAP09|typewriter|288|416|270",   // the typewriter on its north arm,
		"MAP09|partner|288|276|90",       // the partner on its south arm
		"MAP17|box|-1808|-3770|0",
		"MAP17|typewriter|-1712|-3760|180",
		"MAP17|partner|-1726|-3796|90",   // the room is tiny: beside her, clear of the camera's view of her, the box and the typewriter
		"MAP29|box|1040|372|0",
		"MAP29|typewriter|1100|440|270",
		"MAP29|partner|1064|418|300"
	};

	bool HandPlaced(Actor pmo)
	{
		String m = level.MapName.MakeUpper();
		bool any = false, ribbons = false;
		Actor tw;
		for (int i = 0; i < layout.Size(); i++)
		{
			Array<String> f;
			layout[i].Split(f, "|");
			if (f[0] != m || f[1] == "box" || f[1] == "partner") continue;   // (the partner's spot: REStartLayoutHandler)
			any = true;
			Vector2 at = (f[2].ToDouble(), f[3].ToDouble());
			if (f[1] != "typewriter") ribbons = true;
			if (f[1] == "herb")
			{
				// replace the nearest green herb with the ribbon
				let it = ThinkerIterator.Create("REGreenHerb");
				Actor h, best;
				while (h = Actor(it.Next())) if (!best || (h.pos.xy - at).Length() < (best.pos.xy - at).Length()) best = h;
				if (best && (best.pos.xy - at).Length() < 128)
				{
					Actor.Spawn("REInkRibbonPickup", best.pos);
					best.Destroy();
				}
				else Spawn("REInkRibbonPickup", at);
				continue;
			}
			if (f[1] == "ribbon") ClearSpot(at, 48);   // the ribbon alone on its spot (MAP01's balcony: no chainsaw-spot ammo)
			Actor mo = Spawn(f[1] == "typewriter" ? "RETypewriter" : "REInkRibbonPickup", at);
			if (mo != null) mo.Angle = f[4].ToDouble();
			if (f[1] == "typewriter") tw = mo;
		}
		// only the typewriter hand-placed: the start ribbon goes beside it as usual
		if (any && !ribbons && tw != null) NoteStartPickup(PlaceBeside(tw, pmo, "REInkRibbonPickup"));
		return any;
	}

	// Is there an item lying within 'r' of a spot?
	static bool PickupNear(Vector2 at, double r)
	{
		let it = ThinkerIterator.Create("Actor");
		Actor p;
		while (p = Actor(it.Next()))
		{
			bool pickup = p is "REPickup" || (p is "Inventory" && Inventory(p).owner == null && !(p is "HexenArmor") && !(p is "BasicArmor"));
			if (pickup && (p.pos.xy - at).Length() < r) return true;
		}
		return false;
	}

	// Removes the pickups (and Doom items still to be turned into ours) within
	// 'r' of a spot.
	static void ClearSpot(Vector2 at, double r)
	{
		let it = ThinkerIterator.Create("Actor");
		Actor p;
		while (p = Actor(it.Next()))
		{
			bool pickup = p is "REPickup" || (p is "Inventory" && Inventory(p).owner == null);
			if (!pickup || (p.pos.xy - at).Length() > r) continue;
			if (re_debugcams) Console.Printf("ribbon spot (%.0f, %.0f): removed %s", at.x, at.y, p.GetClassName());
			p.ClearCounters();   // out of the items % total (once)
			p.Destroy();
		}
	}

	static Actor Spawn(class<Actor> what, Vector2 at)
	{
		let mo = Actor.Spawn(what, (at.x, at.y, 0));
		if (mo != null) mo.SetZ(mo.floorz);
		return mo;
	}

	// --- start pickups visible from the opening camera ---------------------------
	// The start ribbon and Item Balance's herbs and clip (RE_Balance.zs) are
	// checked while the map loads, once the opening camera is chosen
	// (REStartLayoutHandler, before the first picture: nothing moves once the
	// map is shown): each must be in its picture, with nothing (a wall, the
	// box, the typewriter, Jill, Chris or the partner) in the way, and on safe
	// floor (SafeSpot). One that isn't moves to the nearest spot by the player
	// that is.
	Array<Actor> startPickups;

	static void NoteStartPickup(Actor a)
	{
		let me = REItemBoxHandler(EventHandler.Find("REItemBoxHandler"));
		if (me != null && a != null) me.startPickups.Push(a);
	}

	Actor startBox, startTw, startRib;   // placed automatically this map (not hand-placed)

	void FinishStart(PlayerPawn pmo)
	{
		let cam = REFixedCamera(players[REMain.Number()].camera);
		if (pmo == null || cam == null) { startPickups.Clear(); startTw = null; startBox = null; startRib = null; return; }
		if (re_debugcams && startTw != null && startBox != null)
			Console.Printf("start props: tw (%.0f,%.0f) %d, box (%.0f,%.0f) %d, cam (%.0f,%.0f,%.0f) ang %.0f", startTw.pos.x, startTw.pos.y, Visible(cam, startTw), startBox.pos.x, startBox.pos.y, Visible(cam, startBox), cam.pos.x, cam.pos.y, cam.pos.z, cam.Angle);
		// the typewriter and the box both in the opening camera's picture; if
		// not, the typewriter moves (a few steps from the box) to where they are,
		// and its ribbon goes with it
		if (startTw != null && startBox != null && !(Visible(cam, startTw) && Visible(cam, startBox) && SafeSpot(startTw) && SafeSpot(startBox) && ScreenApart(cam, startTw, startBox)))
		{
			bool moved = PlaceApart(startBox, pmo, cam, startTw) != null;
			// the box itself at the edge of the picture (or out of it): the box
			// moves too, to a spot by the player that's in the picture
			if (!moved) moved = MoveBoxIntoShot(startBox, startTw, pmo, cam);
			// still no: another camera spot that shows all three (AutoCamera.zs)
			if (!moved)
			{
				let ch = RECameraHandler(EventHandler.Find("RECameraHandler"));
				moved = ch != null && ch.FrameStartProps(pmo, startBox, startTw);
				if (moved) cam = REFixedCamera(players[REMain.Number()].camera);
			}
			if (moved && startRib != null)
			{
				let rib = PlaceBeside(startTw, pmo, "REInkRibbonPickup");
				if (rib != null)
				{
					int i = startPickups.Find(startRib);
					startRib.Destroy();
					startRib = rib;
					if (i < startPickups.Size()) startPickups[i] = rib; else startPickups.Push(rib);
				}
			}
			if (re_debugcams) Console.Printf("start typewriter: %s", moved ? "moved into the opening shot" : "no spot in the opening shot");
		}
		else if (startTw == null && !(level.MapName ~== "MAP01") && !(level.MapName ~== "MAP07"))   // (those two keep the opening shot you chose)
		{
			// hand-placed (StartLayout): they stay put; if this camera doesn't
			// show them side by side, another camera spot that does
			Actor box = null, tw = null;
			let bi = ThinkerIterator.Create("REItemBoxActor");
			Actor b;
			while (b = Actor(bi.Next())) if (b.Distance2D(pmo) < 400 && (box == null || b.Distance2D(pmo) < box.Distance2D(pmo))) box = b;
			let ti = ThinkerIterator.Create("RETypewriter");
			while (b = Actor(ti.Next())) if (b.Distance2D(pmo) < 400 && (tw == null || b.Distance2D(pmo) < tw.Distance2D(pmo))) tw = b;
			if (box != null && tw != null && !(Visible(cam, box) && Visible(cam, tw) && ScreenApart(cam, tw, box)))
			{
				let ch = RECameraHandler(EventHandler.Find("RECameraHandler"));
				bool found = ch != null && ch.FrameStartProps(pmo, box, tw, false);
				if (found) cam = REFixedCamera(players[REMain.Number()].camera);
				if (re_debugcams) Console.Printf("hand-placed start: %s", found ? "another camera shows the box and typewriter" : "no camera shows both side by side");
			}
		}
		startTw = null; startBox = null; startRib = null;
		if (startPickups.Size() == 0) return;
		for (int i = 0; i < startPickups.Size(); i++)
		{
			let a = startPickups[i];
			if (a == null) continue;
			if (Visible(cam, a) && SafeSpot(a)) continue;
			Vector3 was = a.pos;
			bool moved = false;
			// in the picture and on safe floor; failing that, on safe floor at least
			for (int pass = 0; pass < 2 && !moved; pass++)
			{
				for (int k = 0; k < 32 && !moved; k++)
				{
					double dist = 40 + (k / 8) * 24;
					Vector2 at = pmo.pos.xy + Actor.AngleToVector(k * 45 + (k / 8) * 22.5, dist);
					if (!level.IsPointInLevel((at.x, at.y, pmo.pos.z))) continue;
					a.SetOrigin((at.x, at.y, pmo.floorz), false);
					a.SetZ(a.floorz);
					if (abs(a.floorz - pmo.floorz) <= 24 && a.TestMobjLocation() && SafeSpot(a) && (pass == 1 || Visible(cam, a)) && ClearOfProps(a, pmo)) moved = true;
				}
			}
			if (!moved) a.SetOrigin(was, false);
			a.ClearInterpolation();
			if (re_debugcams) Console.Printf("start pickup %s: %s", a.GetClassName(), moved ? "moved into view" : "no better spot");
		}
		startPickups.Clear();
	}

	// --- safe floor ---------------------------------------------------------------
	// Never in liquid (Doom's nukage, water, lava, blood, slime) or on a floor
	// that hurts, and never on or under Jill, Chris or the partner.
	static bool SafeSpot(Actor a)
	{
		// Doom II's liquid flats (its SLIME09-16 are plain stone and metal floors)
		static const String liquids[] = { "NUKAGE1", "NUKAGE2", "NUKAGE3", "FWATER1", "FWATER2", "FWATER3", "FWATER4",
			"SWATER1", "SWATER2", "SWATER3", "SWATER4", "LAVA1", "LAVA2", "LAVA3", "LAVA4", "BLOOD1", "BLOOD2", "BLOOD3",
			"SLIME01", "SLIME02", "SLIME03", "SLIME04", "SLIME05", "SLIME06", "SLIME07", "SLIME08" };
		Sector s = level.PointInSector(a.pos.xy);
		if (s.damageamount > 0) return false;
		String flat = TexMan.GetName(s.GetTexture(Sector.floor));
		flat = flat.MakeUpper();
		for (int i = 0; i < liquids.Size(); i++) if (flat == liquids[i]) return false;
		for (int k = 0; k < 2; k++)
		{
			let it = ThinkerIterator.Create(k == 0 ? 'PlayerPawn' : 'REPartner');
			Actor p;
			while (p = Actor(it.Next()))
				if (p != a && p.health > 0 && a.Distance2D(p) < a.radius + p.radius + 8) return false;
		}
		return true;
	}

	static bool Visible(REFixedCamera cam, Actor a)
	{
		if (cam.ViewScore(a) <= 0) return false;
		// the box, a typewriter, the player or the partner between the lens and
		// the item (in 3D: the line of sight must pass below the top of it to
		// be blocked)
		static const Name blockers[] = { 'REItemBoxActor', 'RETypewriter', 'PlayerPawn', 'REPartner' };
		Vector3 to = a.pos + (0, 0, a.Height * 0.5);
		Vector3 d = to - cam.pos;
		double len = d.Length();
		if (len < 1) return true;
		for (int k = 0; k < blockers.Size(); k++)
		{
			let it = ThinkerIterator.Create(blockers[k]);
			Actor p;
			while (p = Actor(it.Next()))
			{
				if (p == a) continue;
				Vector3 rel = p.pos - cam.pos;
				double t = (rel.xy dot d.xy) / max(1, d.xy dot d.xy);
				if (t <= 0 || t >= 1) continue;
				Vector2 off = rel.xy - d.xy * t;
				if (off.Length() > p.radius + 4) continue;
				double z = cam.pos.z + d.z * t;
				if (z < p.pos.z + p.Height + 2) return false;
			}
		}
		return true;
	}

	// Puts a thing next to another (either side, a little further out if
	// needed), on the same floor and in sight of the player (pmo; null = no
	// sight needed, e.g. beside the halfway typewriter).
	static Actor PlaceBeside(Actor next, Actor pmo, class<Actor> what)
	{
		Actor face = pmo != null ? pmo : next;
		// beside it first (either side), then all the way round, a little further out
		double side = next.AngleTo(face) + 90;
		for (int i = 0; i < 26; i++)
		{
			double dist = i < 2 ? 44 : (i < 10 ? 48 : (i < 18 ? 64 : 88));
			double ang = i < 2 ? side + i * 180 : side + ((i - 2) % 8) * 45;
			Vector2 at = next.pos.xy + Actor.AngleToVector(ang, dist);
			if (!level.IsPointInLevel((at.x, at.y, next.pos.z))) continue;
			let mo = Actor.Spawn(what, (at.x, at.y, next.floorz));
			if (mo == null) continue;
			mo.SetZ(mo.floorz);
			mo.Angle = mo.AngleTo(face);
			if (abs(mo.floorz - next.floorz) <= 24 && mo.TestMobjLocation() && SafeSpot(mo) && (pmo == null || mo.CheckSight(pmo))
				&& (!(mo is "RETypewriter") || (RETypewriter.FitAgainstWall(mo) && NoPocket(mo) && !BlocksWalkway(mo)))
				&& (!(mo is "REPickup") || ClearOfProps(mo, pmo)))
				return mo;
			mo.Destroy();
		}
		return null;
	}

	// Doom maps sometimes stack several copies of an item on one spot (MAP07
	// has nine backpacks on top of each other). Here every pickup is an item
	// you take one at a time, so a stack looked like one pickup that never
	// went away. Keep one of each kind per spot.
	static void MergeStacked()
	{
		Array<REPickup> seen;
		let it = ThinkerIterator.Create("REPickup");
		REPickup p;
		while (p = REPickup(it.Next()))
		{
			bool dup = false;
			for (int i = 0; i < seen.Size() && !dup; i++)
				if (seen[i].GetClass() == p.GetClass() && (seen[i].pos - p.pos).Length() < 4) dup = true;
			if (!dup) { seen.Push(p); continue; }
			p.ClearCounters();   // out of the items % total (once)
			p.Destroy();
		}
	}

	// The start typewriter a few steps from the box (80-180 units), both in
	// plain sight: in the player's line of sight, neither prop hiding the
	// other, no narrow gaps (NoPocket). With a camera, also in its picture.
	// Spawns a new typewriter, or (move) moves that one.
	static Actor PlaceApart(Actor box, Actor pmo, REFixedCamera cam, Actor move = null)
	{
		static const double dists[] = { 128, 112, 144, 96, 160, 176 };
		Vector3 old = move != null ? move.pos : (0, 0, 0);
		for (int d = 0; d < dists.Size(); d++)
		{
			for (int k = 0; k < 16; k++)
			{
				// start on the player's side of the box, then all the way round
				double ang = box.AngleTo(pmo) + ((k + 1) / 2) * 22.5 * ((k % 2) * 2 - 1);
				Vector2 at = box.pos.xy + Actor.AngleToVector(ang, dists[d]);
				if (!level.IsPointInLevel((at.x, at.y, box.pos.z))) continue;
				Actor tw = move;
				if (tw == null) tw = Actor.Spawn("RETypewriter", (at.x, at.y, box.floorz));
				else tw.SetOrigin((at.x, at.y, box.floorz), false);
				if (tw == null) continue;
				tw.SetZ(tw.floorz);
				tw.Angle = tw.AngleTo(pmo);
				bool ok = abs(tw.floorz - box.floorz) <= 24 && tw.TestMobjLocation() && SafeSpot(tw) && tw.CheckSight(pmo)
					&& RETypewriter.FitAgainstWall(tw) && NoPocket(tw) && !BlocksWalkway(tw)
					&& tw.Distance2D(box) >= 80 && tw.Distance2D(pmo) >= 48
					&& !Between(box, pmo, tw) && !Between(tw, pmo, box)
					&& (cam == null || (Visible(cam, tw) && Visible(cam, box) && Visible(cam, pmo) && ScreenApart(cam, tw, box)));
				if (ok) return tw;
				if (move == null) tw.Destroy();
			}
		}
		if (move != null) move.SetOrigin(old, false);
		return null;
	}

	// The box somewhere near the player in the camera's picture (the same rules
	// as at the start: its own floor, in the player's sight, no narrow gaps),
	// with a spot for the typewriter a few steps away (PlaceApart). Both stay
	// where they were if there is none.
	static bool MoveBoxIntoShot(Actor box, Actor tw, Actor pmo, REFixedCamera cam)
	{
		static const double dists[] = { 64, 96, 128, 160 };
		Vector3 old = box.pos;
		double oldAngle = box.Angle;
		for (int d = 0; d < dists.Size(); d++)
		{
			for (int k = 0; k < 16; k++)
			{
				Vector2 at = pmo.pos.xy + Actor.AngleToVector(pmo.Angle + 180 + ((k + 1) / 2) * 22.5 * ((k % 2) * 2 - 1), dists[d]);
				if (!level.IsPointInLevel((at.x, at.y, pmo.pos.z))) continue;
				box.SetOrigin((at.x, at.y, pmo.floorz), false);
				box.SetZ(box.floorz);
				box.Angle = box.AngleTo(pmo);
				if (abs(box.floorz - pmo.floorz) <= 24 && box.TestMobjLocation() && SafeSpot(box) && box.CheckSight(pmo) && NoPocket(box) && !BlocksWalkway(box)
					&& Visible(cam, box) && PlaceApart(box, pmo, cam, tw) != null)
					return true;
			}
		}
		box.SetOrigin(old, false);
		box.Angle = oldAngle;
		return false;
	}

	// The box and the typewriter side by side in the camera's picture, with a
	// gap between them (not one drawn over the other).
	static bool ScreenApart(Actor cam, Actor a, Actor b)
	{
		Vector3 da = a.pos + (0, 0, a.Height * 0.5) - cam.pos;
		Vector3 db = b.pos + (0, 0, b.Height * 0.5) - cam.pos;
		double la = da.Length(), lb = db.Length();
		if (la < 1 || lb < 1) return false;
		double apart = acos(clamp((da dot db) / (la * lb), -1, 1));
		double ra = a is "REItemBoxActor" ? 36 : 24, rb = b is "REItemBoxActor" ? 36 : 24;   // how wide they look
		return apart >= atan(ra / la) + atan(rb / lb) + 2;
	}

	// Is prop p standing between the player and actor a (as seen from above)?
	static bool Between(Actor p, Actor pmo, Actor a)
	{
		Vector2 d = a.pos.xy - pmo.pos.xy;
		double len2 = d dot d;
		if (len2 < 1) return false;
		double t = ((p.pos.xy - pmo.pos.xy) dot d) / len2;
		if (t <= 0 || t >= 1) return false;
		return (pmo.pos.xy + d * t - p.pos.xy).Length() < p.radius + a.radius;
	}

	// --- no squeeze-in pockets -------------------------------------------------------
	// A gap between a prop (the box or a typewriter) and a wall, or another
	// prop, must be either too narrow for anyone to enter or comfortably
	// walkable: never a space you can squeeze into and get stuck in.
	const GAP_CLOSED = 30;     // narrower: nobody fits (players are 32 wide)
	const GAP_OPEN = 48;       // wider: walk through freely

	static bool GapOk(double gap) { return gap <= GAP_CLOSED || gap >= GAP_OPEN; }

	static bool NoPocket(Actor prop)
	{
		Vector2 c = prop.pos.xy;
		double fz = prop.floorz;
		// standing fully on its own floor: not hanging over a step or ledge
		for (int a = 0; a < 360; a += 45)
		{
			Vector2 p = c + Actor.AngleToVector(a, prop.radius);
			Sector s = level.PointInSector(p);
			if (abs(s.floorplane.ZatPoint(p) - fz) > 2) return false;
		}
		let it = BlockLinesIterator.Create(prop, GAP_OPEN + prop.radius);
		while (it.Next())
		{
			Line l = it.CurLine;
			if (!BlocksPlayer(l, fz)) continue;
			double gap = SegmentDistance(c, l.v1.p, l.v2.p) - prop.radius;
			if (!GapOk(gap)) return false;
		}
		// the other props near it (box, typewriters)
		for (int k = 0; k < 2; k++)
		{
			let ti = ThinkerIterator.Create(k == 0 ? 'REItemBoxActor' : 'RETypewriter');
			Actor o;
			while (o = Actor(ti.Next()))
			{
				if (o == prop) continue;
				double gap = (o.pos.xy - c).Length() - o.radius - prop.radius;
				if (gap < GAP_OPEN + 8 && !GapOk(gap)) return false;
			}
		}
		return true;
	}

	// --- not in the way ---------------------------------------------------------------
	// A prop (the box or a typewriter) must leave the way free for you and the
	// partner:
	//   - not across a narrow corridor: on some axis with walls close on both
	//     sides and the way open ahead and behind, at least one side wide
	//     enough to walk past (WALK_PAST)
	//   - not in front of a narrow opening (a doorway or a crawl gap: a short
	//     passable line with walls at both ends), unless there's still room to
	//     walk past it on one side
	const WALK_PAST = 40;      // a player (32) and a little room
	const OPENING_MAX = 128;   // wider than this isn't a narrow opening

	static bool BlocksWalkway(Actor prop)
	{
		double r = prop.radius;
		// a narrow corridor across it
		for (int a = 0; a < 180; a += 45)
		{
			double s1 = FreeDist(prop, a), s2 = FreeDist(prop, a + 180);
			if (max(s1, s2) - r >= WALK_PAST) continue;          // room to pass on one side
			double ahead = FreeDist(prop, a + 90), behind = FreeDist(prop, a + 270);
			if (ahead - r >= 48 && behind - r >= 48) { if (re_debugcams) Console.Printf("in the way: %s (%.0f, %.0f) across a corridor (axis %d)", prop.GetClassName(), prop.pos.x, prop.pos.y, a); return true; }   // a way through on both ends: a walkway
		}
		// right in front of a narrow opening, or a door (even a wall that only
		// looks like one: a typewriter in front of it looks like it's in the way)
		let it = BlockLinesIterator.Create(prop, r + WALK_PAST + 8);
		while (it.Next())
		{
			Line l = it.CurLine;
			if (LooksLikeDoor(l))
			{
				Vector2 da = l.v1.p, dab = l.v2.p - l.v1.p;
				double dl = dab.Length();
				double dt = dl > 0 ? ((prop.pos.xy - da) dot dab) / (dl * dl) : -1;
				if (dt > 0 && dt < 1 && SegmentDistance(prop.pos.xy, l.v1.p, l.v2.p) < r + 32) { if (re_debugcams) Console.Printf("in the way: %s (%.0f, %.0f) in front of a door (line %d)", prop.GetClassName(), prop.pos.x, prop.pos.y, l.Index()); return true; }
			}
			if (l.backsector == null || (l.flags & (Line.ML_BLOCKING | Line.ML_BLOCKEVERYTHING | Line.ML_BLOCK_PLAYERS))) continue;
			double f = max(l.frontsector.CenterFloor(), l.backsector.CenterFloor());
			double c = min(l.frontsector.CenterCeiling(), l.backsector.CenterCeiling());
			if (abs(l.frontsector.CenterFloor() - l.backsector.CenterFloor()) > 24 || c - f < 28) continue;   // not a way through
			Vector2 a = l.v1.p, ab = l.v2.p - l.v1.p;
			double len = ab.Length();
			if (len < 1 || len > OPENING_MAX) continue;
			if (!WallAt(l.v1, l) || !WallAt(l.v2, l)) continue;   // not walls on both ends: an open floor line
			double t = ((prop.pos.xy - a) dot ab) / (len * len);
			if (t < 0 || t > 1) continue;                          // beside the opening, not in front of it
			double toLine = SegmentDistance(prop.pos.xy, l.v1.p, l.v2.p);
			if (toLine > r + WALK_PAST) continue;
			// it must lead somewhere: room beyond it, not a shallow recess
			Vector2 near = a + ab * t;
			if (FreeDist(prop, VectorAngle(near.x - prop.pos.x, near.y - prop.pos.y)) - toLine < WALK_PAST) continue;
			// room left in the opening beside the prop, on its better side
			double along = t * len;
			if (max(along - r, len - along - r) < WALK_PAST) { if (re_debugcams) Console.Printf("in the way: %s (%.0f, %.0f) in front of an opening (line %d)", prop.GetClassName(), prop.pos.x, prop.pos.y, l.Index()); return true; }
		}
		return false;
	}

	// A door, or a wall drawn as one (Doom's door textures, the door specials).
	static bool LooksLikeDoor(Line l)
	{
		int s = l.special;
		if (s == 10 || s == 11 || s == 12 || s == 13 || s == 14 || s == 202) return true;
		for (int side = 0; side < 2; side++)
		{
			if (l.sidedef[side] == null) continue;
			for (int part = 0; part < 3; part++)
			{
				String tex = TexMan.GetName(l.sidedef[side].GetTexture(part));
				tex = tex.MakeUpper();
				if (tex.Left(4) == "DOOR" || tex.Left(7) == "BIGDOOR" || tex.Left(7) == "SPCDOOR") return true;
			}
		}
		return false;
	}

	// How far the way is free from a prop in a direction (knee height, up to 160).
	static double FreeDist(Actor prop, double ang)
	{
		FLineTraceData t;
		if (prop.LineTrace(ang, 160, 0, TRF_THRUACTORS, 8, data: t) && t.HitType == TRACE_HitWall) return t.Distance;
		return 160;
	}

	// Does a wall (anything a player can't walk across) meet this vertex?
	static bool WallAt(Vertex v, Line except)
	{
		let it = BlockLinesIterator.CreateFromPos((v.p.x, v.p.y, 0), 0, 4, null);
		while (it.Next())
		{
			Line l = it.CurLine;
			if (l == except || (l.v1 != v && l.v2 != v)) continue;
			if (l.backsector == null || (l.flags & (Line.ML_BLOCKING | Line.ML_BLOCKEVERYTHING | Line.ML_BLOCK_PLAYERS))) return true;
			if (abs(l.frontsector.CenterFloor() - l.backsector.CenterFloor()) > 24) return true;
			double c = min(l.frontsector.CenterCeiling(), l.backsector.CenterCeiling()), f = max(l.frontsector.CenterFloor(), l.backsector.CenterFloor());
			if (c - f < 28) return true;
		}
		return false;
	}

	// In a narrow corridor: push the box flat against the nearest wall, so the
	// gap on that side closes and the other side stays as wide as it can be.
	static void SlideToWall(Actor box, Actor pmo)
	{
		double bestDist = 1e9, bestAng = 0;
		for (int a = 0; a < 360; a += 45)
		{
			FLineTraceData t;
			box.LineTrace(a, 96, 0, TRF_THRUACTORS, 8, data: t);
			if (t.HitType == TRACE_HitWall && t.Distance < bestDist) { bestDist = t.Distance; bestAng = a; }
		}
		double move = bestDist - box.radius - 0.25;
		if (bestDist >= 96 || move <= 0) return;
		Vector3 old = box.pos;
		box.SetOrigin((box.Vec2Angle(move, bestAng), box.pos.z), false);
		box.SetZ(box.floorz);
		if (!box.TestMobjLocation() || abs(box.floorz - old.z) > 2) box.SetOrigin(old, false);
	}

	// Can a player not walk across this line here (wall, ledge too high, too
	// low a ceiling, or a blocking line)?
	static bool BlocksPlayer(Line l, double fz)
	{
		if (l.backsector == null) return true;
		if (l.flags & (Line.ML_BLOCKING | Line.ML_BLOCKEVERYTHING | Line.ML_BLOCK_PLAYERS)) return true;
		double f = max(l.frontsector.CenterFloor(), l.backsector.CenterFloor());
		double c = min(l.frontsector.CenterCeiling(), l.backsector.CenterCeiling());
		return f - fz > 24 || c - f < 56;
	}

	static double SegmentDistance(Vector2 p, Vector2 a, Vector2 b)
	{
		Vector2 ab = b - a;
		double t = ab dot ab > 0 ? clamp(((p - a) dot ab) / (ab dot ab), 0, 1) : 0;
		return (a + ab * t - p).Length();
	}

	// A start pickup must not sit in a corner behind the box or a typewriter:
	// at least a player's width from them, and not hidden behind one as seen
	// from the player.
	static bool ClearOfProps(Actor a, Actor pmo)
	{
		for (int k = 0; k < 2; k++)
		{
			let ti = ThinkerIterator.Create(k == 0 ? 'REItemBoxActor' : 'RETypewriter');
			Actor o;
			while (o = Actor(ti.Next()))
			{
				if ((o.pos.xy - a.pos.xy).Length() < o.radius + 24) return false;
				if (pmo == null) continue;
				Vector2 d = a.pos.xy - pmo.pos.xy;
				double len2 = d dot d;
				if (len2 < 1) continue;
				double t = ((o.pos.xy - pmo.pos.xy) dot d) / len2;
				if (t <= 0 || t >= 1) continue;
				if ((pmo.pos.xy + d * t - o.pos.xy).Length() < o.radius + 8) return false;
			}
		}
		return true;
	}

	// Action pressed in front of a box (TankPlayer.zs TryPickUpAhead).
	override void InterfaceProcess(ConsoleEvent e)
	{
		// (only ever sent to the player who opened the box, once its lid is open)
		if (e.Name ~== "re_openbox") Menu.SetMenu('REItemBoxMenu');
	}

	// The box screen closed: close the lid of the box this player opened.
	override void NetworkProcess(ConsoleEvent e)
	{
		if (!(e.Name ~== "re_closebox")) return;
		let it = ThinkerIterator.Create("REItemBoxActor");
		REItemBoxActor box;
		while (box = REItemBoxActor(it.Next())) if (box.opener == e.Player + 1) box.StartClosing();
	}
}

// The box screen.
class REItemBoxMenu : GenericMenu
{
	int column;      // 0 = your items, 1 = the box
	int cursor;      // your slot
	int boxCursor;   // box slot
	int boxTop;      // first box row shown

	int lastMessageId;
	int messageUntil;
	String shownMessage;

	const BOX_ROWS = 10;

	override void Init(Menu parent)
	{
		Super.Init(parent);
		let inv = GetInv();
		lastMessageId = inv != null ? inv.messageId : 0;
		MenuSound("menu/activate");
	}

	REInventory GetInv()
	{
		let pmo = players[consoleplayer].mo;
		return pmo != null ? REInventory(pmo.FindInventory("REInventory")) : null;
	}

	// However the screen closes (Esc, Tab, right-click), the lid closes too.
	override void OnDestroy()
	{
		EventHandler.SendNetworkEvent("re_closebox");
		Super.OnDestroy();
	}

	REItemBox GetBox()
	{
		let pmo = players[consoleplayer].mo;
		return pmo != null ? REItemBox(pmo.FindInventory("REItemBox")) : null;
	}

	override bool OnUIEvent(UIEvent ev)
	{
		if (ev.Type == UIEvent.Type_KeyDown)
		{
			if (ev.KeyChar == UIEvent.Key_Tab || ev.KeyChar == 105 || ev.KeyChar == 73)
			{
				Close();
				MenuSound("menu/clear");
				return true;
			}
		}
		if (ev.Type == UIEvent.Type_RButtonDown) { Close(); MenuSound("menu/backup"); return true; }   // right-click: back
		if (ev.Type == UIEvent.Type_WheelUp || ev.Type == UIEvent.Type_WheelDown)
		{
			// the wheel scrolls the box list
			int d = ev.Type == UIEvent.Type_WheelUp ? -1 : 1;
			boxTop = clamp(boxTop + d, 0, REItemBox.BOX_SLOTS - BOX_ROWS);
			boxCursor = clamp(boxCursor, boxTop, boxTop + BOX_ROWS - 1);
			return true;
		}
		return Super.OnUIEvent(ev);
	}

	// The mouse: hovering picks a line on either side, a click puts it in or takes it out.
	override bool MouseEvent(int type, int x, int y)
	{
		let inv = GetInv();
		if (inv == null) return true;
		if (RE1Classic.On())
		{
			// RE1 Classic: your slots; the box list's three rows (the top / bottom
			// one steps the list); its picture is the chosen box slot
			Vector2 q = RE1Classic.ToLayout(x, y);
			int side = -1, line = -1;
			for (int s = 0; s < inv.numSlots; s++) if (RE1Classic.Inside(q, RE1Classic.SlotX(inv, s), RE1Classic.SlotY(inv, s), 40, 30)) { side = 0; line = s; }
			for (int r = -1; r <= 1; r++)
				if (RE1Classic.Inside(q, RE1Classic.BOX_LIST_X, RE1Classic.BOX_LIST_Y + (r + 1) * RE1Classic.BOX_ROW_H, 128, RE1Classic.BOX_ROW_H)) { side = 1; line = clamp(boxCursor + r, 0, REItemBox.BOX_SLOTS - 1); }
			if (RE1Classic.Inside(q, RE1Classic.BOX_PIC_X - 1, RE1Classic.BOX_PIC_Y - 1, 42, 32)) { side = 1; line = boxCursor; }
			if (side < 0) return true;
			int was = side == 0 ? cursor : boxCursor;
			if (side != column || line != was) MenuSound("menu/cursor");
			column = side;
			if (side == 0) cursor = line;
			else if (line != boxCursor) { boxCursor = line; return true; }   // a click on the top / bottom row only scrolls
			if (type == MOUSE_Release) MenuEvent(MKEY_Enter, false);
			return true;
		}
		Vector2 p = RERecordsMenu.ToCanvas(x, y);
		int side = -1, line = -1;
		for (int s = 0; s < inv.numSlots; s++) if (RERecordsMenu.Inside(p, 20, 66 + s * 28, 260, 24)) { side = 0; line = s; }
		for (int r = 0; r < BOX_ROWS; r++) if (RERecordsMenu.Inside(p, 320, 66 + r * 22, 300, 19)) { side = 1; line = boxTop + r; }
		if (side < 0) return true;
		int was = side == 0 ? cursor : boxCursor;
		if (side != column || line != was) MenuSound("menu/cursor");
		column = side;
		if (side == 0) cursor = line; else boxCursor = line;
		if (type == MOUSE_Release) MenuEvent(MKEY_Enter, false);
		return true;
	}

	override bool MenuEvent(int mkey, bool fromcontroller)
	{
		let inv = GetInv();
		let box = GetBox();
		if (inv == null || box == null) return Super.MenuEvent(mkey, fromcontroller);

		if (mkey == MKEY_Left || mkey == MKEY_Right)
		{
			column = mkey == MKEY_Left ? 0 : 1;
			MenuSound("menu/cursor");
			return true;
		}
		if (mkey == MKEY_Up || mkey == MKEY_Down)
		{
			int d = mkey == MKEY_Up ? -1 : 1;
			if (column == 0) cursor = clamp(cursor + d, 0, inv.numSlots - 1);
			else
			{
				boxCursor = clamp(boxCursor + d, 0, REItemBox.BOX_SLOTS - 1);
				if (boxCursor < boxTop) boxTop = boxCursor;
				if (boxCursor >= boxTop + BOX_ROWS) boxTop = boxCursor - BOX_ROWS + 1;
			}
			MenuSound("menu/cursor");
			return true;
		}
		if (mkey == MKEY_Enter)
		{
			bool ok = column == 0 ? inv.slotId[cursor] != RE_ITEM_NONE : box.boxId[boxCursor] != RE_ITEM_NONE;
			if (ok)
			{
				EventHandler.SendNetworkEvent(column == 0 ? "re_boxput" : "re_boxtake", column == 0 ? cursor : boxCursor);
				MenuSound("menu/choose");
			}
			else MenuSound("menu/invalid");
			return true;
		}
		return Super.MenuEvent(mkey, fromcontroller);
	}

	RE1Ecg ecg;   // RE1 Classic: the status screen's ECG keeps beating under the box

	override void Ticker()
	{
		Super.Ticker();
		let pmo = players[consoleplayer].mo;
		if (!RE1Classic.On() || pmo == null) return;
		if (ecg == null) ecg = new("RE1Ecg");
		ecg.Tick(pmo);
	}

	override void Drawer()
	{
		Screen.Dim(Color(255, 0, 0, 0), RE1Classic.On() ? 1.0 : 0.85, 0, 0, Screen.GetWidth(), Screen.GetHeight());
		let inv = GetInv();
		let box = GetBox();
		if (inv == null || box == null) return;

		if (inv.messageId != lastMessageId)
		{
			lastMessageId = inv.messageId;
			shownMessage = inv.message;
			messageUntil = MenuTime() + 35 * 3;
		}
		if (RE1Classic.On())
		{
			// RE1 Classic: the box list over RE1's status screen (RE_InvClassic.zs)
			let pmo = players[consoleplayer].mo;
			int eid = inv.equippedSlot >= 0 ? inv.slotId[inv.equippedSlot] : RE_ITEM_NONE;
			int eqty = inv.equippedSlot >= 0 ? inv.slotQty[inv.equippedSlot] : 0;
			RE1Classic.DrawBase(inv, pmo, eid, eqty);
			RE1Classic.DrawBox(box, boxCursor, column == 1, MenuTime());
			if (ecg != null) ecg.Draw();
			if (column == 0) RE1Classic.Cursor(RE1Classic.SlotX(inv, cursor), RE1Classic.SlotY(inv, cursor), MenuTime());
			String line = "";
			if (MenuTime() < messageUntil && shownMessage.Length() > 0) line = shownMessage;
			else
			{
				int id = column == 0 ? inv.slotId[cursor] : box.boxId[boxCursor];
				if (id != RE_ITEM_NONE) line = REItemInfo.GetName(id);
			}
			RE1Classic.BottomLine(line);
			return;
		}

		Color gray = Color(255, 110, 110, 110);
		Color dark = Color(255, 20, 20, 24);
		Color gold = Color(255, 255, 220, 0);

		REDraw.Text(20, 18, "ITEM BOX", Font.CR_GOLD, 2.0);

		// Your items, one column.
		REDraw.Text(20, 50, "YOUR ITEMS", column == 0 ? Font.CR_GOLD : Font.CR_GRAY);
		for (int s = 0; s < inv.numSlots; s++)
		{
			double y = 66 + s * 28;
			REDraw.Box(20, y, 260, 24, dark, 0.9);
			REDraw.Frame(20, y, 260, 24, (column == 0 && s == cursor) ? gold : gray);
			ItemLine(28, y + 6, inv.slotId[s], inv.slotQty[s], s == inv.equippedSlot);
		}

		// The box, scrolling list of 48.
		REDraw.Text(320, 50, String.Format("BOX   %d-%d of %d", boxTop + 1, boxTop + BOX_ROWS, REItemBox.BOX_SLOTS),
			column == 1 ? Font.CR_GOLD : Font.CR_GRAY);
		for (int r = 0; r < BOX_ROWS; r++)
		{
			int b = boxTop + r;
			double y = 66 + r * 22;
			REDraw.Box(320, y, 300, 19, dark, 0.9);
			REDraw.Frame(320, y, 300, 19, (column == 1 && b == boxCursor) ? gold : gray);
			ItemLine(328, y + 4, box.boxId[b], box.boxQty[b], false);
		}

		REDraw.Box(20, 300, 600, 64, dark, 0.9);
		REDraw.Frame(20, 300, 600, 64, gray);
		if (MenuTime() < messageUntil && shownMessage.Length() > 0)
			REDraw.Text(32, 320, shownMessage, Font.CR_WHITE, 1.4);
		else
		{
			int id = column == 0 ? inv.slotId[cursor] : box.boxId[boxCursor];
			if (id != RE_ITEM_NONE) REDraw.Text(32, 320, REItemInfo.GetDescription(id), Font.CR_WHITE, 1.2);
		}
		REDraw.Text(20, 372, "LEFT/RIGHT switch side    UP/DOWN move    ENTER put in / take out    TAB close", Font.CR_DARKGRAY, 0.85);
		REDraw.Text(20, 385, "MOUSE: click an item to put it in / take it out    WHEEL scrolls the box    RIGHT-CLICK back", Font.CR_DARKGRAY, 0.85);
	}

	void ItemLine(double x, double y, int id, int qty, bool equipped)
	{
		if (id == RE_ITEM_NONE) return;
		String t = REItemInfo.GetName(id);
		if (REItemInfo.ShowsQuantity(id)) t = String.Format("%s   %d", t, qty);
		if (equipped) t = t .. "   (E)";
		REDraw.Text(x, y, t, Font.CR_WHITE);
	}
}

// Every map start (not a loaded game), last of all the map-start work (the
// last handler in mapinfo.txt, so the box, typewriter, ribbons, Item
// Balance's pickups and the partner are all in place): the opening camera is
// chosen and aimed, then the start props and pickups are checked against it
// and moved if needed - all while the map loads, before its first picture,
// so nothing moves or jumps once the map is shown.
class REStartLayoutHandler : EventHandler
{
	override void WorldLoaded(WorldEvent e)
	{
		if (e.IsSaveGame) return;
		let pmo = REMain.Player();
		if (pmo == null) return;
		if (re_debugcams) Console.Printf("start layout: %s, tic %d", level.MapName, level.maptime);

		// Doom's first picture of a map (it stays up through the screen melt) is
		// drawn before the first tic, so whatever things would set up at that
		// tic is done now: Doom items that become something else, and how Jill,
		// Chris and the partner look.
		for (int k = 0; k < 2; k++)
		{
			let it = ThinkerIterator.Create(k == 0 ? 'REKnifePickup' : 'REFlamethrowerPickup');
			Actor a;
			while (a = Actor(it.Next()))
			{
				if (a is "REKnifePickup") REKnifePickup(a).Convert();
				else REFlamethrowerPickup(a).Convert();
			}
		}
		let rp = RETankPlayer(pmo);
		if (rp != null) rp.PrimeLook();
		let pt = REPartner.Find();
		bool ptPlaced = false;
		if (pt != null)
		{
			// a hand-picked spot for the partner (StartLayout, tiny start rooms)
			for (int i = 0; i < REItemBoxHandler.layout.Size(); i++)
			{
				Array<String> f;
				REItemBoxHandler.layout[i].Split(f, "|");
				if (f[0] != level.MapName.MakeUpper() || f[1] != "partner") continue;
				Vector3 was = pt.pos;
				pt.SetOrigin((f[2].ToDouble(), f[3].ToDouble(), pt.pos.z), false);
				pt.SetZ(pt.floorz);
				if (pt.TestMobjLocation()) { pt.Angle = f[4].ToDouble(); pt.ClearInterpolation(); ptPlaced = true; }
				else pt.SetOrigin(was, false);
			}
			pt.PrimeLook();
		}

		let ch = RECameraHandler(EventHandler.Find("RECameraHandler"));
		if (ch != null) ch.PickOpening(pmo);
		// the partner right in front of the lens: another spot by the player
		let cam = players[REMain.Number()].camera;
		if (pt != null && !ptPlaced && cam != null && cam != pmo && (REPartnerHandler.NearLens(pt, cam) || REPartnerHandler.HidesFromCamera(pt, pmo, cam)))
		{
			bool ok = REPartnerHandler.Place(pt, pmo, cam);
			if (re_debugcams) Console.Printf("partner: %s", ok ? "moved away from the lens" : "no spot away from the lens");
			if (ok && ch != null) ch.PickOpening(pmo);   // the camera again, for where they stand now
		}
		let ib = REItemBoxHandler(EventHandler.Find("REItemBoxHandler"));
		if (ib != null) ib.FinishStart(pmo);

		// Last (once nothing moves any more): every item's angle on the floor
		// and its RE1-lighting glow, as their first tic would set them.
		let it = ThinkerIterator.Create("Actor");
		Actor a;
		while (a = Actor(it.Next()))
		{
			if (a is "REItemBoxActor" || a is "RETypewriter") { REPickup.PrimeGlow(a, 32, 128, 0); continue; }
			if (a is "REVestLightPickup" || a is "REVestPatch" || a is "REVestHeavyPickup")
			{
				if (Inventory(a).owner != null) continue;
				a.Angle = REPickup.FloorAngle(a);
				REPickup.PrimeGlow(a, 32, 120);
				continue;
			}
			bool item = a is "REPickup" || a is "REKeyPickup" || a is "REChemicalPickup" || a is "RELighterPickup" || a is "REMapPickup";
			if (!item || (a is "Inventory" && Inventory(a).owner != null)) continue;
			if (!(a is "REFirstAidSprayPickup")) a.Angle = REPickup.FloorAngle(a);   // the spray keeps its map angle (no turning of its own)
			REPickup.PrimeGlow(a);
		}
		if (re_debugcams) Snapshot(pmo);
	}

	// re_debugcams: what the first picture shows (the camera, and the props and
	// items near the start), checked again a second later - nothing may have
	// moved - and whether any of them is on an unsafe spot (SafeSpot).
	Array<Actor> snapActors;
	Array<double> snapX, snapY, snapZ, snapA;
	Array<Name> snapName;
	Vector3 snapCamPos, snapPlayer;
	double snapCamAngle, snapCamFov;

	void Snapshot(Actor pmo)
	{
		let cam = players[REMain.Number()].camera;
		if (cam != null) { snapCamPos = cam.pos; snapCamAngle = cam.Angle; snapCamFov = cam.CameraFOV; }
		snapPlayer = (pmo.pos.x, pmo.pos.y, pmo.pos.z + pmo.Height * 0.5);
		int unsafe = 0;
		let it = ThinkerIterator.Create("Actor");
		Actor a;
		while (a = Actor(it.Next()))
		{
			bool watch = a is "REItemBoxActor" || a is "RETypewriter" || ((a is "REPickup" || a is "Inventory") && a.Distance2D(pmo) < 768);
			if (!watch || (a is "Inventory" && Inventory(a).owner != null) || a is "HexenArmor" || a is "BasicArmor") continue;   // (the player's own armor counters, between maps)
			snapActors.Push(a); snapX.Push(a.pos.x); snapY.Push(a.pos.y); snapZ.Push(a.pos.z); snapA.Push(a.Angle); snapName.Push(a.GetClassName());
			if (a.Distance2D(pmo) < 400 && !REItemBoxHandler.SafeSpot(a))
			{
				unsafe++;
				Sector s = level.PointInSector(a.pos.xy);
				Console.Printf("STARTUNSAFE %s %s at (%.0f, %.0f): floor %s, damage %d, %.0f from the player", level.MapName, a.GetClassName(), a.pos.x, a.pos.y,
					TexMan.GetName(s.GetTexture(Sector.floor)), s.damageamount, a.Distance2D(pmo));
			}
		}
		Console.Printf("STARTSNAP %s: %d things watched, %d unsafe", level.MapName, snapActors.Size(), unsafe);
		// the start box and typewriter from the opening camera
		Actor box = null, tw = null;
		let bi = ThinkerIterator.Create("REItemBoxActor");
		Actor b;
		while (b = Actor(bi.Next())) if (box == null || b.Distance2D(pmo) < box.Distance2D(pmo)) box = b;
		let ti = ThinkerIterator.Create("RETypewriter");
		while (b = Actor(ti.Next())) if (tw == null || b.Distance2D(pmo) < tw.Distance2D(pmo)) tw = b;
		let fc = REFixedCamera(cam);
		if (box != null && tw != null && fc != null)
		{
			bool vb = REItemBoxHandler.Visible(fc, box), vt = REItemBoxHandler.Visible(fc, tw), apart = REItemBoxHandler.ScreenApart(fc, tw, box);
			Console.Printf("STARTPROPS %s: box %s, typewriter %s, %s, %.0f apart", level.MapName, vb ? "in view" : "NOT IN VIEW", vt ? "in view" : "NOT IN VIEW",
				apart ? "side by side" : "OVERLAPPING", box.Distance2D(tw));
		}
		let ri = ThinkerIterator.Create("REInkRibbonPickup");
		Actor r;
		while (r = Actor(ri.Next())) Console.Printf("STARTRIBBON %s at (%.0f, %.0f)%s", level.MapName, r.pos.x, r.pos.y, REItemBoxHandler.SafeSpot(r) ? "" : " UNSAFE");
	}

	override void WorldTick()
	{
		if (!re_debugcams || level.maptime != 35 || snapActors.Size() == 0) return;
		int moved = 0;
		for (int i = 0; i < snapActors.Size(); i++)
		{
			let a = snapActors[i];
			if (a == null) { moved++; Console.Printf("STARTMOVED %s: %s at (%.0f, %.0f) was removed", level.MapName, snapName[i], snapX[i], snapY[i]); continue; }
			if (a is "Inventory" && Inventory(a).owner != null) continue;   // picked up
			if ((a.pos - (snapX[i], snapY[i], snapZ[i])).Length() > 1 || abs(Actor.DeltaAngle(a.Angle, snapA[i])) > 1)
			{
				moved++;
				Console.Printf("STARTMOVED %s %s from (%.0f, %.0f) to (%.0f, %.0f), angle %.0f -> %.0f", level.MapName, a.GetClassName(), snapX[i], snapY[i], a.pos.x, a.pos.y, snapA[i], a.Angle);
			}
		}
		let cam = players[REMain.Number()].camera;
		bool camMoved = cam == null || (cam.pos - snapCamPos).Length() > 1 || abs(Actor.DeltaAngle(cam.Angle, snapCamAngle)) > 0.5 || abs(cam.CameraFOV - snapCamFov) > 0.3;
		if (camMoved && cam != null) Console.Printf("STARTMOVED %s camera from (%.0f, %.0f, %.0f) %.0f fov %.0f to (%.0f, %.0f, %.0f) %.0f fov %.0f", level.MapName,
			snapCamPos.x, snapCamPos.y, snapCamPos.z, snapCamAngle, snapCamFov, cam.pos.x, cam.pos.y, cam.pos.z, cam.Angle, cam.CameraFOV);
		let pmo = REMain.Player();
		if (camMoved && pmo != null) Console.Printf("STARTMOVED %s player middle from (%.1f, %.1f, %.1f) to (%.1f, %.1f, %.1f)", level.MapName,
			snapPlayer.x, snapPlayer.y, snapPlayer.z, pmo.pos.x, pmo.pos.y, pmo.pos.z + pmo.Height * 0.5);
		Console.Printf("STARTCHECK %s: %d moved, camera %s", level.MapName, moved, camMoved ? "MOVED" : "still");
		snapActors.Clear(); snapX.Clear(); snapY.Clear(); snapZ.Clear(); snapA.Clear(); snapName.Clear();
	}
}
