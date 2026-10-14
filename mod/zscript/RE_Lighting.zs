// ---------------------------------------------------------------------------
// RE_Lighting.zs - the lighting modes (re_dark): Doom (default, 0) leaves
// everything as Doom made it; RE1 (1) is darker, Resident Evil 1 style lighting:
//
// When a map starts, every sector's brightness is multiplied by re_rooms_dark
// (0.6 = 60%). Outdoor (sky) areas use re_rooms_dark_sky. But no area loses more
// than re_rooms_cut, so bright areas seen far down a corridor don't fade to
// black, and nothing goes below re_rooms_keep (areas already that dim are left
// alone), so you can always see where you're going. Jill herself is drawn at least
// re_char_minlight bright, like RE1 where characters stay readable.
// A faint, small light follows Jill (and the partner): just enough to see them.
//
// Switch at any time: press L, type re_lights in the console, or use main
// menu > Settings > Gameplay > Lighting. (Setting: re_dark.) In Doom mode the
// player's light, the characters' minimum brightness and the pickups' glow
// (RE_Items.zs, RE_Partner.zs) are off too.
//
// Change the darkness settings in the console (~), e.g. "re_rooms_dark 0.4",
// then restart the map (or start a new game) to see the difference.
//
// Note: Doom's flickering/strobe lights reset their sector to their own
// bright and dark values, so those spots flicker at Doom brightness.
// ---------------------------------------------------------------------------

class RELightingHandler : EventHandler
{
	Array<int> original;   // every sector's brightness as the map made it
	bool darkened;         // the darkening is applied right now

	override void WorldLoaded(WorldEvent e)
	{
		if (e.IsSaveGame) return;   // brightness and these fields were saved with the game
		original.Clear();
		for (int i = 0; i < level.Sectors.Size(); i++) original.Push(level.Sectors[i].lightlevel);
		BrightenBossArena();
		darkened = false;
		if (re_dark) Darken();
	}

	// MAP30 (Icon of Sin): Doom lights the arena dimly (112-160), and the
	// third-person cameras look across it from far away, where Doom's light
	// fades with distance, so the far side was almost black from the top of
	// the lift. Its open areas (the arena's 640-high ceiling) count as at least
	// ARENA_LIGHT bright in both modes; RE1 lighting still darkens them from there.
	const ARENA_LIGHT = 176;

	void BrightenBossArena()
	{
		if (!(level.MapName ~== "MAP30")) return;
		for (int i = 0; i < level.Sectors.Size(); i++)
		{
			Sector s = level.Sectors[i];
			if (s.CenterCeiling() < 600 || original[i] >= ARENA_LIGHT) continue;
			original[i] = ARENA_LIGHT;
			s.SetLightLevel(ARENA_LIGHT);
		}
	}

	// A sector's brightness in RE1 lighting.
	int DarkLevel(int i)
	{
		double indoor = clamp(re_rooms_dark, 0.05, 1.0);
		double outdoor = clamp(re_rooms_dark_sky, 0.05, 1.0);
		// Areas that are already dim (at or below re_rooms_keep) stay as the
		// map made them; only brighter areas are darkened, down to that level.
		int keep = clamp(re_rooms_keep, 0, 255);
		int l = original[i];
		bool sky = level.Sectors[i].GetTexture(Sector.ceiling) == skyflatnum;
		int lit = int(l * (sky ? outdoor : indoor));
		if (re_rooms_cut > 0) lit = max(lit, l - re_rooms_cut);   // bright areas lose at most re_rooms_cut
		return max(lit, min(keep, l));
	}

	// Sets every sector to the current lighting: Doom's or RE1's.
	void Apply()
	{
		for (int i = 0; i < level.Sectors.Size() && i < original.Size(); i++)
			level.Sectors[i].SetLightLevel(darkened ? DarkLevel(i) : original[i]);
	}

	void Darken() { darkened = true; Apply(); }
	void Restore() { darkened = false; Apply(); }

	// RE1 lighting: how bright a character or pickup is drawn: a bit above its
	// room and at least 'least' (readable in the dark), but never as bright as
	// it would be in Doom lighting ('below' under it; 0 = up to the same).
	static int Glow(Actor a, int add, int least, int below = 16)
	{
		if (a.CurSector == null) return -1;
		int room = a.CurSector.lightlevel;
		int doom = room;
		let h = RELightingHandler(EventHandler.Find('RELightingHandler'));
		int i = a.CurSector.Index();
		if (h != null && i < h.original.Size()) doom = h.original[i];
		return clamp(max(room, min(max(room + add, least), doom - below)), 0, 255);
	}

	override void WorldTick()
	{
		// The L key / re_lights / the Settings menu flip re_dark; follow it.
		if (re_dark == darkened) return;
		if (original.Size() == 0)
		{
			// A game saved before this toggle existed: nothing to restore from.
			darkened = re_dark;
			Console.MidPrint(null, "The lighting can be switched from the next map on.");
			return;
		}
		if (re_dark) Darken();
		else Restore();
		Console.MidPrint(null, re_dark ? "Lighting: RE1" : "Lighting: Doom");
	}}
extend class RETankPlayer
{
	// RE1 keeps its characters readable however dark the room is. Jill is
	// drawn slightly brighter than her surroundings and never darker than
	// re_char_minlight, but never as bright as in Doom lighting (0 = room light).
	override void Tick()
	{
		Super.Tick();
		UpdateREPlayerLight();
		if (!re_dark || re_char_minlight <= 0) { lightlevel = -1; return; }
		lightlevel = RELightingHandler.Glow(self, 16, re_char_minlight);
	}
}

extend class RETankPlayer
{
	// A dim warm light around Jill (like RE1, where characters stay readable
	// against the dark backgrounds).
	// RE1 lighting only; follows the setting while playing.
	bool reLightOn;
	void UpdateREPlayerLight()
	{
		bool want = re_dark && re_jill_light;
		if (want == reLightOn) return;
		reLightOn = want;
		if (want) A_AttachLight('REJillLight', DynamicLight.PointLight, Color(255, 44, 40, 34), 56, 56, 0, (0, 0, 44));   // faint: just the character
		else A_RemoveLight('REJillLight');
	}
}
