// ---------------------------------------------------------------------------
// RE_LevelSelect.zs - main menu > Level Select, and the Final Boss start.
//
//   Up / Down      choose a level (the picture shows it)
//   Left / Right   on CHARACTER: Jill or Chris
//   Enter          start that level with that character (a fresh game, at
//                  the current difficulty)
//   Esc            back
//
// The list: Doom II's MAP01-MAP32, then "Mansion - (custom level)" and FINAL
// BOSS (MAP30, starting right in front of the Icon of Sin). The character is
// shown with their ID card from RE1's own character-select screen
// (Data\Select_b.tim, graphics/CARDJILL.png and CARDCHRS.png). Each level's
// picture is graphics/LVxx.png (LVBOSS, LVRE, LV01-LV32): screenshots of the
// level, taken from your own game.
//
// GZDoom only lets a menu run a console command from an option menu that
// holds that command, so this is an option menu with its own drawing.
// ---------------------------------------------------------------------------

class RELevelSelectMenu : OptionMenu
{
	Array<String> pics;     // picture per list item ("" for the character row)
	Array<String> maps;     // map per list item
	TextureID charPic[2];
	int top;                // first row shown

	const ROWS = 16;

	override void Init(Menu parent, OptionMenuDescriptor desc)
	{
		// The level items are added once, to the menu's description.
		if (desc.mItems.Size() <= 1)
		{
			for (int i = 1; i <= 32; i++)
			{
				String map = String.Format("MAP%02d", i);
				if (!LevelInfo.MapExists(map)) continue;
				let info = LevelInfo.FindLevelInfo(map);
				String name = info != null ? info.LookupLevelName() : map;
				Add(desc, String.Format("%s  %s", map, name), "map " .. map, String.Format("LV%02d", i), map);
			}
			Add(desc, "Mansion - (custom level)", "map REMAP01", "LVRE", "REMAP01");
			Add(desc, "FINAL BOSS - Icon of Sin", "re_bossfight", "LVBOSS", "MAP30");
		}
		Super.Init(parent, desc);
		pics.Clear(); maps.Clear();
		for (int i = 0; i < desc.mItems.Size(); i++)
		{
			let c = RELevelItem(desc.mItems[i]);
			pics.Push(c != null ? c.pic : "");
			maps.Push(c != null ? c.map : "");
		}
		charPic[0] = TexMan.CheckForTexture("CARDJILL", TexMan.Type_Any);
		charPic[1] = TexMan.CheckForTexture("CARDCHRS", TexMan.Type_Any);
		// open on a level (Enter does nothing on the character row)
		if (mDesc.mSelectedItem < 1) mDesc.mSelectedItem = 1;
	}

	void Add(OptionMenuDescriptor desc, String label, String cmd, String pic, String map)
	{
		let it = new("RELevelItem");
		it.Init(label, cmd, false, true);
		it.run = cmd;
		it.pic = pic;
		it.map = map;
		desc.mItems.Push(it);
	}

	// Enter on a level: run "playerclass <who>; <its command>" ("map MAPxx",
	// or re_bossfight for the Final Boss). A menu may only run a command
	// held by one of its own items, so a copy of the item with the
	// character added stands in for it while it runs.
	override bool MenuEvent(int mkey, bool fromcontroller)
	{
		// Left / Right switch the character wherever the cursor is.
		if ((mkey == MKEY_Left || mkey == MKEY_Right) && mDesc.mSelectedItem > 0)
		{
			let ch = CVar.FindCVar('re_levelchar');
			// order on screen: Jill, Both (you Jill), Both (you Chris), Chris
			static const int order[] = { 0, 2, 3, 1 };
			int cur = LevelChar();
			int at = 0;
			for (int k = 0; k < 4; k++) if (order[k] == cur) at = k;
			int step = mkey == MKEY_Right ? 1 : -1;
			at = clamp(at + step, 0, 3);
			// Settings > Gameplay > AI partner off: only Jill and Chris
			if (!re_ai_partner) at = step > 0 ? 3 : 0;
			if (ch != null) ch.SetInt(order[at]);
			MenuSound("menu/change");
			return true;
		}
		int sel = mDesc.mSelectedItem;
		if (mkey == MKEY_Enter && sel > 0)
		{
			let orig = RELevelItem(mDesc.mItems[sel]);
			if (orig != null)
			{
				// re_levelchar: 0 Jill, 1 Chris, 2 Both (you Jill), 3 Both (you Chris)
			int lc = LevelChar();
			bool chris = lc == 1 || lc == 3;
			int partner = lc == 2 ? 2 : (lc == 3 ? 1 : 0);
			String cmd = String.Format("playerclass %s; re_partner %d; %s", chris ? "Chris" : "Jill", partner, orig.run);
				let go = new("RELevelItem");
				go.Init(orig.mLabel, cmd, false, true);
				mDesc.mItems[sel] = go;
				go.Activate();
				mDesc.mItems[sel] = orig;
				// Close every menu (the main menu too), straight into the level.
				for (int n = 0; n < 8 && Menu.GetCurrentMenu() != null; n++) Menu.GetCurrentMenu().Close();
				return true;
			}
		}
		return Super.MenuEvent(mkey, fromcontroller);
	}

	// The mouse: hovering a row selects it (as Up/Down would), clicking a
	// level starts it (as Enter), clicking the character row or the ID card
	// steps the character (left half: back, right half: on). The wheel
	// scrolls. Positions are on the screen's 640x400 layout.
	override bool MouseEvent(int type, int x, int y)
	{
		Vector2 p = RECharSelectMenu.ToLayout(x, y, 640, 400);
		int n = mDesc.mItems.Size();
		int hit = -1;
		if (p.x >= 20 && p.x < 320)
		{
			if (p.y >= 40 && p.y < 56) hit = 0;
			int r = int((p.y - 62) / 18);
			if (p.y >= 62 && r < ROWS && top + 1 + r < n) hit = top + 1 + r;
		}
		if (hit >= 0 && hit != mDesc.mSelectedItem)
		{
			mDesc.mSelectedItem = hit;
			MenuSound("menu/cursor");
		}
		if (type != MOUSE_Release) return true;
		bool onCard = p.x >= 330 && p.x < 600 && p.y >= 226 && p.y < 330;
		if (hit == 0 || onCard)
		{
			double mid = hit == 0 ? 170 : 465;
			MenuEvent(p.x < mid ? MKEY_Left : MKEY_Right, false);
			mDesc.mSelectedItem = max(mDesc.mSelectedItem, 1);   // keep a level picked
		}
		else if (hit > 0) MenuEvent(MKEY_Enter, false);
		return true;
	}

	override bool OnUIEvent(UIEvent ev)
	{
		if (ev.Type == UIEvent.Type_WheelUp || ev.Type == UIEvent.Type_WheelDown)
		{
			int n = mDesc.mItems.Size();
			int s = clamp(mDesc.mSelectedItem + (ev.Type == UIEvent.Type_WheelUp ? -1 : 1), 1, n - 1);
			if (s != mDesc.mSelectedItem) { mDesc.mSelectedItem = s; MenuSound("menu/cursor"); }
			return true;
		}
		return Super.OnUIEvent(ev);
	}

	// re_levelchar, with the "Both" choices read as plain Jill / Chris while
	// Settings > Gameplay > AI partner is off.
	int LevelChar()
	{
		if (!re_ai_partner && re_levelchar >= 2) return re_levelchar - 2;
		return re_levelchar;
	}

	String CharLabel()
	{
		switch (LevelChar())
		{
		case 1: return "CHRIS";
		case 2: return "BOTH - you: JILL";
		case 3: return "BOTH - you: CHRIS";
		}
		return "JILL";
	}

	void Words(Font f, int color, double x, double y, String text)
	{
		Screen.DrawText(f, color, x, y, text, DTA_VirtualWidth, 640, DTA_VirtualHeight, 400, DTA_FullscreenScale, FSMode_ScaleToFit43);
	}

	void Pic(TextureID tex, double x, double y, double w, double h)
	{
		Screen.DrawTexture(tex, false, x, y, DTA_VirtualWidth, 640, DTA_VirtualHeight, 400,
			DTA_FullscreenScale, FSMode_ScaleToFit43, DTA_DestWidthF, w, DTA_DestHeightF, h);
	}

	// No picture for this level (setup's capture was skipped or failed): a
	// plain dark card with the level's name. Any Doom II flat, painted one colour.
	void Card(double x, double y, double w, double h, String label)
	{
		TextureID flat = TexMan.CheckForTexture("FLAT5_4", TexMan.Type_Flat);
		if (flat.IsValid())
			Screen.DrawTexture(flat, false, x, y, DTA_VirtualWidth, 640, DTA_VirtualHeight, 400,
				DTA_FullscreenScale, FSMode_ScaleToFit43, DTA_DestWidthF, w, DTA_DestHeightF, h, DTA_FillColor, Color(255, 28, 28, 34));
		int dash = label.IndexOf("  ");
		String lvName = dash > 0 ? label.Mid(dash + 2) : label;
		String lvId = dash > 0 ? label.Left(dash) : "";
		if (lvId.Length() > 0) Words(SmallFont, Font.CR_DARKRED, x + (w - SmallFont.StringWidth(lvId)) / 2, y + h / 2 - 14, lvId);
		if (lvName.Length() > 28) lvName = lvName.Left(27) .. ".";
		Words(SmallFont, Font.CR_GRAY, x + (w - SmallFont.StringWidth(lvName)) / 2, y + h / 2, lvName);
	}

	override void Drawer()
	{
		Screen.Dim(Color(255, 0, 0, 0), 0.9, 0, 0, Screen.GetWidth(), Screen.GetHeight());
		int sel = mDesc.mSelectedItem;
		int n = mDesc.mItems.Size();

		Words(BigFont, Font.CR_RED, 20, 10, "LEVEL SELECT");

		// Character row
		bool onChar = sel == 0;
		Words(SmallFont, onChar ? Font.CR_GOLD : Font.CR_GRAY, 20, 42,
			String.Format("%sCHARACTER:  < %s >", onChar ? "> " : "  ", CharLabel()));

		// Level list
		if (sel > 0)
		{
			if (sel - 1 < top) top = sel - 1;
			if (sel - 1 >= top + ROWS) top = sel - ROWS;
		}
		for (int r = 0; r < ROWS && top + 1 + r < n; r++)
		{
			int i = top + 1 + r;
			bool on = i == sel;
			bool boss = i < pics.Size() && pics[i] == "LVBOSS";
			int col = on ? Font.CR_GOLD : (boss ? Font.CR_RED : Font.CR_WHITE);
			String label = mDesc.mItems[i].mLabel;
			if (label.Length() > 34) label = label.Left(33) .. ".";
			Words(SmallFont, col, 20, 62 + r * 18, (on ? "> " : "  ") .. label);
		}
		if (top > 0) Words(SmallFont, Font.CR_DARKGRAY, 20, 54, "  ...");
		if (top + 1 + ROWS < n) Words(SmallFont, Font.CR_DARKGRAY, 20, 62 + ROWS * 18, "  ...");

		// Preview of the highlighted level, and who you'll play
		double px = 330, py = 58, pw = 232, ph = 145;
		String picName = sel > 0 && sel < pics.Size() ? pics[sel] : (pics.Size() > 1 ? pics[1] : "");
		TextureID tex = TexMan.CheckForTexture(picName, TexMan.Type_Any);
		if (tex.IsValid()) Pic(tex, px, py, pw, ph);
		else Card(px, py, pw, ph, sel > 0 && sel < mDesc.mItems.Size() ? mDesc.mItems[sel].mLabel : "");
		if (sel > 0) Words(SmallFont, Font.CR_WHITE, px, py + ph + 6, mDesc.mItems[sel].mLabel);
		if (sel > 0 && sel < pics.Size() && pics[sel] == "LVBOSS")
			Words(SmallFont, Font.CR_RED, px, py + ph + 20, "Starts at the Icon. Shoot its brain!");
		// The character's ID card (RE1's character-select picture)
		int lc = LevelChar();
		if (lc >= 2)
		{
			// Both: the two ID cards, the one you play in front
			int youC = lc == 3 ? 1 : 0;
			Pic(charPic[1 - youC], px + 52, 226, 96, 108);
			Pic(charPic[youC], px, 262, 96, 108);
		}
		else Pic(charPic[lc == 1 ? 1 : 0], px, 232, 128, 144);
		Words(SmallFont, Font.CR_GOLD, px + 156, 296, "< " .. CharLabel() .. " >");
		Words(SmallFont, Font.CR_DARKGRAY, px + 140, 312, "LEFT / RIGHT");

		Words(SmallFont, Font.CR_DARKGRAY, 20, 384, "UP/DOWN choose   LEFT/RIGHT character   ENTER start   ESC back");
	}
}

// One level in the list: a menu command plus its picture.
class RELevelItem : OptionMenuItemCommand
{
	String run;     // its console command
	String pic;
	String map;
}

// Final Boss: put the player in front of the Icon of Sin, in sight of its
// brain, as soon as MAP30 starts (re_bossfight sets re_finalboss).
class REFinalBossHandler : EventHandler
{
	bool bossRun;   // this MAP30 run is the Final Boss (its own record, RE_Records.zs)
	bool liftHinted;   // MAP30: the "switch on the back ledge" hint was shown
	// MAP30 after the Final Boss start or a Continue (ReadyBossLift): the centre
	// lift waits down at floor level and E raises it to liftTop; Doom's own
	// lift lines are off (it can't drop you from the top). False: as Doom made it.
	bool liftReady;
	double liftTop, liftBottom;
	int liftMsg;          // the lift message shown for where you are now (0 none, 1 raise, 2 bring down)
	int liftMsgAgain;     // level.maptime when it's shown again if you're still there
	bool useWasDown;

	// MAP30's way to the brain: the lift in the middle of the arena (tag 2).
	// In Doom a switch in the small alcove on the back ledge raises it 512 (once);
	// after that, Action on its side brings it down and it carries you back up.
	const LIFT_X = 2880;
	const LIFT_Y = 832;

	static int LiftTag()
	{
		return level.PointInSector((LIFT_X, LIFT_Y)).GetTag(0);
	}

	// The alcove switch for that lift, while it's still unused (Doom clears a
	// one-time switch's special once it has worked).
	static Line LiftSwitch(int tag)
	{
		for (int i = 0; i < level.lines.Size(); i++)
		{
			Line l = level.lines[i];
			if (l.special == Floor_RaiseByValueTimes8 && l.args[0] == tag) return l;
		}
		return null;
	}

	// Mark that switch as used, as Doom does when it's pressed: its picture
	// flips (SW1... to SW2...) and it does nothing any more.
	static void UseUpSwitch(Line l)
	{
		for (int s = 0; s < 2; s++)
		{
			Side sd = l.sidedef[s];
			if (sd == null) continue;
			for (int part = Side.top; part <= Side.bottom; part++)
			{
				String tex = TexMan.GetName(sd.GetTexture(part));
				if (!(tex.Left(3) ~== "SW1")) continue;
				TextureID on = TexMan.CheckForTexture("SW2" .. tex.Mid(3), TexMan.Type_Wall);
				if (on.IsValid()) sd.SetTexture(part, on);
			}
		}
		l.special = 0;
	}

	// The first time you use the lift's side before the switch was pressed, a
	// hint: on its own the lift only dips a little and comes back.
	override void WorldLineActivated(WorldEvent e)
	{
		if (liftHinted || !(level.MapName ~== "MAP30") || e.ActivatedLine == null || e.Thing == null || e.Thing.player == null) return;
		Line l = e.ActivatedLine;
		int tag = LiftTag();
		if (tag == 0 || l.special != Plat_DownWaitUpStayLip || l.args[0] != tag || LiftSwitch(tag) == null) return;
		liftHinted = true;
		let inv = REInventory(e.Thing.FindInventory("REInventory"));
		if (inv != null) inv.ShowMessage("Press the switch on the back ledge first.");
	}

	// The alcove switch pressed while the lift is still moving (going down or
	// coming back): Doom doesn't start it then and the switch stays unused, so
	// say to press it again.
	override void WorldLinePreActivated(WorldEvent e)
	{
		if (!(level.MapName ~== "MAP30") || e.ActivatedLine == null || e.Thing == null || e.Thing.player == null) return;
		Line l = e.ActivatedLine;
		int tag = LiftTag();
		// The ready lift (after the Final Boss start or a Continue) is run by
		// WorldTick: Doom's own "down, wait, up" on its sides stays off, so it
		// never drops you from the top.
		if (liftReady && l.special == Plat_DownWaitUpStayLip && l.args[0] == tag) { e.ShouldActivate = false; return; }
		if (tag == 0 || l.special != Floor_RaiseByValueTimes8 || l.args[0] != tag) return;
		Sector lift = level.PointInSector((LIFT_X, LIFT_Y));
		if (lift.floordata == null) return;
		let inv = REInventory(e.Thing.FindInventory("REInventory"));
		if (inv != null) inv.ShowMessage("The lift is moving. Press it again.");
	}

	override void WorldLoaded(WorldEvent e)
	{
		if (e.IsSaveGame || !re_finalboss) return;
		CVar.FindCVar('re_finalboss').SetInt(0);   // one go only
		if (!(level.MapName ~== "MAP30")) return;
		bossRun = true;
		let pmo = players[consoleplayer].mo;
		if (pmo != null) ReadyBossLift(pmo);
	}

	// MAP30's own way to the brain is the lift in the middle of the arena: it
	// carries you up until the brain shows through its opening. After the Final
	// Boss start or a Continue, the lift is ready for that: it goes down to
	// floor level and waits; E raises it to the lowest height that has the
	// brain in view, plus a margin (TickLift). Its alcove switch counts as used.
	// 'rider' (the Final Boss start) is put on the lift, facing the brain;
	// without one (a Continue restart, REContinueHandler) you start in the
	// start room as usual. False if this MAP30 has no such lift.
	static bool ReadyBossLift(Actor rider = null)
	{
		let brain = Actor(ThinkerIterator.Create("BossBrain").Next());
		if (brain == null) return false;
		Vector2 lift = (LIFT_X, LIFT_Y);
		Sector ls = level.PointInSector(lift);
		int tag = ls.GetTag(0);
		double floor = ls.floorplane.ZAtPoint(lift);
		double top = ls.ceilingplane.ZAtPoint(lift) - 60;
		let probe = Actor.Spawn("REBossProbe", (lift.x, lift.y, floor));
		double h = floor;
		bool seen = false;
		for (; h <= top; h += 8)
		{
			probe.SetOrigin((lift.x, lift.y, h), false);
			if (REAim.BrainOpenFrom(probe, brain, 41)) { seen = true; break; }
		}
		probe.Destroy();
		if (!seen || tag == 0)
		{
			Console.Printf("Resident Doom: no view of the Icon from the lift; normal start.");
			return false;
		}
		h += 16;   // a little margin so the opening is well in view
		// floor level: the lowest floor around the lift (the pit), so you can
		// walk onto it
		double bottom = floor;
		for (int i = 0; i < ls.lines.Size(); i++)
		{
			Line sl = ls.lines[i];
			Sector o = sl.frontsector == ls ? sl.backsector : sl.frontsector;
			if (o != null) bottom = min(bottom, o.floorplane.ZAtPoint(lift));
		}
		if (rider != null)
		{
			rider.SetOrigin((lift.x, lift.y, floor), false);
			rider.Vel = (0, 0, 0);
			rider.Angle = rider.AngleTo(brain);
		}
		if (bottom < floor) level.ExecuteSpecial(Floor_MoveToValue, rider, null, false, tag, 64, int(abs(bottom)), bottom < 0);
		// The lift is already up, so its alcove switch counts as pressed: used
		// again, it would push the lift 512 higher, into the ceiling, and the
		// lift could never carry you up again. Now Action on the lift's side
		// always brings it down and back up to this height.
		Line sw = LiftSwitch(tag);
		if (sw != null) UseUpSwitch(sw);
		let me = REFinalBossHandler(EventHandler.Find('REFinalBossHandler'));
		if (me != null)
		{
			me.liftHinted = true;
			me.liftReady = true;
			me.liftTop = h;
			me.liftBottom = bottom;
			me.liftMsg = 0;
		}
		if (re_debugcams) Console.Printf("MAP30 lift ready: down at %.0f, E raises it to %.0f%s", bottom, h, rider != null ? " (Final Boss start)" : "");
		return true;
	}

	// The ready lift (liftReady), every tic: a message when you come near it,
	// and E (Action) on it or next to it:
	//   - down: up to liftTop, with you on it;
	//   - up, you on top: nothing (so you can't drop yourself into the pit);
	//   - up, you below it (you fell off): down again, to ride back up.
	// E while aiming fires, so it's left alone then.
	override void WorldTick()
	{
		if (!liftReady || !(level.MapName ~== "MAP30")) return;
		let pmo = players[consoleplayer].mo;
		if (pmo == null || pmo.health <= 0) return;
		bool useDown = (players[consoleplayer].cmd.buttons & BT_USE) != 0;
		bool pressed = useDown && !useWasDown;
		useWasDown = useDown;

		Vector2 lift = (LIFT_X, LIFT_Y);
		Sector ls = level.PointInSector(lift);
		double lf = ls.floorplane.ZAtPoint(lift);
		bool moving = ls.floordata != null;
		bool down = lf <= liftBottom + 1;
		bool up = lf >= liftTop - 1;
		Vector2 d = pmo.pos.xy - lift;
		bool near = abs(d.x) <= LIFT_HALF + 40 && abs(d.y) <= LIFT_HALF + 40;
		bool onTop = abs(d.x) <= LIFT_HALF + pmo.radius && abs(d.y) <= LIFT_HALF + pmo.radius && pmo.pos.z >= lf - 2;
		let inv = REInventory(pmo.FindInventory("REInventory"));

		// while you're near it: the message for where you are, again every 8
		// seconds until you press E or walk away (one shown as the level fades
		// in is easy to miss)
		if (!near) liftMsg = 0;
		else if (!moving)
		{
			int want = down ? 1 : ((up && !onTop) ? 2 : 0);
			if (want != 0 && (want != liftMsg || level.maptime >= liftMsgAgain) && inv != null)
			{
				inv.ShowMessage(want == 1 ? "Press E to raise the lift." : "Press E to bring the lift down.");
				liftMsgAgain = level.maptime + 35 * 8;
			}
			liftMsg = want;
		}

		let tank = RETankPlayer(pmo);
		if (!pressed || !near || moving || (tank != null && tank.bREAiming)) return;
		int tag = ls.GetTag(0);
		if (down) level.ExecuteSpecial(Floor_MoveToValue, pmo, null, false, tag, LIFT_SPEED, int(abs(liftTop)), liftTop < 0);
		else if (up && !onTop) level.ExecuteSpecial(Floor_MoveToValue, pmo, null, false, tag, LIFT_SPEED, int(abs(liftBottom)), liftBottom < 0);
	}
	const LIFT_HALF = 64;    // the lift is 128 square
	const LIFT_SPEED = 32;   // Doom's own speed for this lift (its lines: Plat_DownWaitUpStayLip 32)
	// Setup's Level Select picture (LVBOSS, "netevent re_capbossview" on MAP30):
	// the same view on every computer. It does what the Final Boss start does,
	// with its numbers fixed instead of searched for: stand on the lift in the
	// middle of the arena (2880, 832), face the Icon's brain, and raise the lift
	// to 312 (where this start ends up), so its opening frames the Icon.
	const CAP_LIFT_TOP = 312;

	override void NetworkProcess(ConsoleEvent e)
	{
		if (!(e.Name ~== "re_capbossview") || e.Player < 0 || !playeringame[e.Player]) return;
		let pmo = players[e.Player].mo;
		if (pmo == null || !(level.MapName ~== "MAP30")) return;
		let brain = Actor(ThinkerIterator.Create("BossBrain").Next());
		Vector2 lift = (2880, 832);
		Sector ls = level.PointInSector(lift);
		pmo.SetOrigin((lift.x, lift.y, ls.floorplane.ZAtPoint(lift)), false);
		pmo.Vel = (0, 0, 0);
		pmo.Angle = brain != null ? pmo.AngleTo(brain) : 90;
		pmo.Pitch = 0;
		level.ExecuteSpecial(Floor_MoveToValue, pmo, null, false, ls.GetTag(0), 64, CAP_LIFT_TOP, 0);
		Console.Printf("Resident Doom: Level Select picture view of the Icon of Sin");
	}
}
// An invisible stand-in the size of the player, to test spots.
class REBossProbe : Actor
{
	Default
	{
		Radius 16;
		Height 56;
		+NOGRAVITY
		+NOBLOCKMAP
		+INVISIBLE
	}
	States { Spawn: TNT1 A -1; Stop; }
}

// A main-menu item only shown while a game is being played (pause menu >
// Main Menu): ends the game and goes back to the title screen, after GZDoom's
// own "are you sure" question (text in language.txt, ENDGAME).
class ListMenuItemREIngameItem : ListMenuItemTextItem
{
	override bool Selectable() { return gamestate == GS_LEVEL && Super.Selectable(); }
	override void Draw(bool selected, ListMenuDescriptor desc)
	{
		if (gamestate == GS_LEVEL) Super.Draw(selected, desc);
	}
}
