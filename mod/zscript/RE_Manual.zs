// ---------------------------------------------------------------------------
// RE_Manual.zs - Main menu > Extras > Manual: the game manual, in pages you flip
// through, in the Records screen's RE1 style (REDraw's 640x400 canvas).
// The same text is in MANUAL.md; change both together.
//
// Keys: Left / Right turn the page, Up / Down jump to the previous / next
// section, Esc goes back (Enter does nothing). Mouse: click a section tab,
// PREV, NEXT or BACK; the wheel turns pages; right-click goes back.
// ---------------------------------------------------------------------------

class REManualMenu : GenericMenu
{
	static const String sections[] = { "CONTROLS", "CHARACTERS", "ITEMS", "WEAPONS", "SAVING", "LIGHTING", "RECORDS", "CHEATS" };

	// The pages. "@n|Title" starts a page of section n. On a page:
	//   "#Heading"      a gold heading
	//   "key|text"      a key or name, and what it does (the text wraps)
	//   "!text"         a gray note
	//   "*"             the right-hand column starts here
	//   ""              a small gap
	//   anything else   a paragraph (wraps)
	static const String text[] = {
		"@0|Controls",
		"#MOVING (fixed cameras)",
		"Up / W|walk forward",
		"Down / S|back up",
		"Left, Right / A, D|turn",
		"Shift (hold)|run",
		"Space|jump",
		"C (hold)|crouch",
		"#FIGHTING",
		"Ctrl / right mouse|aim (hold)",
		"E while aiming|fire",
		"Up / Down|aim up / down (while aiming)",
		"1-7, mouse wheel|switch weapons (All Weapons cheat only; 7 = flamethrower)",
		"!Without the cheat, equip a weapon in the inventory.",
		"!Mac: hold Control to aim and press E to fire. On a trackpad, a two-finger click also aims.",
		"*",
		"#ACTIONS",
		"E|pick up, open doors, use typewriters and the item box",
		"Tab / I|inventory (pauses the game)",
		"M|map screen (pauses the game)",
		"#VIEW AND OTHER KEYS",
		"V|first person / fixed cameras",
		"L|lighting: Doom / RE1",
		"F6|quicksave",
		"Esc|main menu",
		"~ (tilde)|console (for cheat codes)",
		"CapsLock|always run on / off",

		"@0|First person and settings",
		"#FIRST PERSON (after V)",
		"Mouse|look around",
		"Up, Down / W, S|walk forward, back",
		"Q / R|step left / right",
		"Left mouse|fire while aiming (or E)",
		"*",
		"#SETTINGS",
		"Field of View|Settings > Video > Field of View (first person, 75-120)",
		"Starting view|Settings > Gameplay: third or first person at every start",
		"Flat corpses|Settings > Gameplay: dead monsters lie flat, not turning to face you",
		"",
		"Your current keys: Settings > Controls. To change them: Settings > Customize Controls.",

		"@1|Characters",
		"#JILL VALENTINE",
		"Health|96",
		"Item slots|8",
		"#CHRIS REDFIELD",
		"Health|140",
		"Item slots|6",
		"Aiming|turns faster while aiming",
		"Flamethrower|only Chris can use it",
		"",
		"*",
		"#STARTING OUT",
		"Both start with a knife, a Beretta (15 rounds) and a First Aid Spray. Nothing is equipped at first: press Tab, pick the Beretta and choose EQUIP.",
		"",
		"New Game asks Third person or First person after you pick the character. It sets Settings > Gameplay > Starting view.",

		"@1|The AI partner",
		"#BOTH",
		"On the character select screen, BOTH gives you a partner. Pick who you play; the other one follows you and fights.",
		"",
		"The partner can't be hurt, never runs out of ammo, and you can walk through each other. They open normal doors to keep up, key doors while you carry the key, and secret doors you've found, but never switches or lifts. They crawl through low gaps on hands and knees, like you.",
		"#GIVING A GUN",
		"Stand close, open the inventory, pick the gun and choose GIVE TO. They hand you back the gun they had.",
		"*",
		"#SETTINGS > GAMEPLAY",
		"AI partner|Off means no partner and no BOTH choice.",
		"Partner pickups|On (RE5 style): when no enemy is in sight, they walk over to ammo for their own gun near your path and pick it up. You get it with their gun when you swap.",

		"@1|Online co-op",
		"#TWO PLAYERS, TWO COMPUTERS",
		"The host starts host_coop (Jill), the friend starts join_coop (Chris) and types the host's address. README.md explains the addresses.",
		"",
		"Both need the same Resident Doom, the same DOOM II (setup prints its file ID) and the same kind of computer (Windows with Windows, Mac with Mac).",
		"*",
		"#ONLINE",
		"Camera|each player has their own",
		"Items|each player has their own inventory and item box",
		"Saving|none: typewriters and F6 say so",
		"Dying|Space or E: back at the level start",
		"Settings|the host's apply to both",
		"!The game doesn't pause for the inventory, map or menu. No AI partner, records or cheats online.",

		"@2|Herbs, healing and poison",
		"#HERBS",
		"Green Herb|restores a third of your health",
		"Red Herb|does nothing alone; mix it with a green one",
		"Blue Herb|cures poison",
		"First Aid Spray|restores all of your health",
		"!A healing item is only used up if it does something.",
		"#MIXING",
		"In the inventory, pick a herb, choose COMBINE, then pick the other herb. Mixing saves slots.",
		"*",
		"#MIXES",
		"Green + Green|two thirds of your health",
		"Green + Red|all of your health",
		"Green + Blue|a third, and cures poison",
		"3 Greens|all of your health",
		"2 Greens + Blue|two thirds, and cures poison",
		"Green + Red + Blue|all, and cures poison",
		"#POISON",
		"Arachnotrons and the Spider Mastermind poison you. Like RE1, you lose 2 health every 4 seconds, and the inventory shows POISON in purple.",
		"",
		"Poison alone stops at 1 health, but any hit after that can kill you. A Blue Herb, or a mix with one, cures it.",

		"@2|Other items",
		"#TYPEWRITERS AND INK RIBBONS",
		"Every map has a typewriter near the start, and long maps a second one about halfway. Face it and press E to save. One Ink Ribbon lies by the start typewriter and one by each halfway typewriter; they stack 3 to a slot. See SAVING.",
		"#INVENTORY STYLE",
		"Settings > Gameplay > Inventory style: Resident Doom (default) or RE1 Classic, a recreation of RE1's own status and item box screens with its pictures, portrait, ECG and MAP / FILE / EXIT tabs (MAP opens the map, FILE this Manual). Both do exactly the same things.",
		"*",
		"#MAP",
		"Press M for the map screen. It shows what you've seen; the MAP item shows the whole level. Arrows move, + / - or the wheel zoom, M or Esc closes.",
		"#CHEMICAL",
		"Protects you from toxic floors for 1 minute.",
		"#LIGHTER",
		"A small flame that lights the dark around you for 2 minutes.",
		"",
		"The Chemical and the Lighter work as soon as you pick them up. Their time left shows at the top left and blinks orange near the end.",

		"@2|Item box and keys",
		"#ITEM BOX",
		"The wooden chest near the start of every map. Face it and press E: the lid opens and the box screen appears. All boxes share the same 48 slots, so what you store waits for you on the next map.",
		"*",
		"#KEYS",
		"Doom's keycards and skull keys are RE1 keys and crests (Armor, Sword, Shield and Helmet Keys, Star and Sun Crests). Walk over them. They take no slot and open the doors of their colour.",

		"@3|Weapons",
		"To use a weapon: Tab, pick it, EQUIP. Hold Aim, then press E to fire. To reload, COMBINE its ammo with the gun.",
		"#WEAPON|HOLDS (DAMAGE)",
		"Knife|never runs out (8)",
		"Beretta|15 rounds (9)",
		"Shotgun|7 shells, hits a wide area (53)",
		"Colt Python|6 magnum rounds (130)",
		"Bazooka|6 explosive (201), acid or flame (95) rounds; COMBINE another kind of round to switch",
		"Rocket launcher|4 rockets, can't be reloaded (900)",
		"Flamethrower|Chris only. 240 fuel, 9 seconds of flame. Hold Aim and hold E. Another flamethrower fills it up.",
		"*",
		"#DOOM'S WEAPONS BECOME",
		"Pistol|Beretta",
		"Shotgun|Shotgun",
		"Super shotgun|Colt Python",
		"Rocket launcher|Bazooka (explosive)",
		"Plasma rifle|Bazooka (acid)",
		"BFG9000|Rocket launcher",
		"Chaingun|Flamethrower (Chris), a clip (Jill)",
		"Chainsaw|Ammo for a gun you carry",
		"",
		"Picking up a gun you already have gives you its ammo.",
		"!Damage is RE1's, against a zombie.",

		"@4|Saving",
		"Choose the save mode in Settings > Gameplay > Save mode.",
		"#SAVE MODES",
		"Normal (default)|save any time: Save Game, F6 or a typewriter",
		"Typewriter|save only at a typewriter; no ribbon needed",
		"Classic RE|save only at a typewriter, and each save uses an Ink Ribbon, like RE1. A new game starts with none: find them by the typewriters.",
		"",
		"In Typewriter and Classic RE, Save Game and F6 only tell you to find a typewriter.",
		"*",
		"#IF YOU DIE",
		"Press SPACE or E to continue. Saved on this level: back to your most recent save. Not yet: the level starts again with exactly what you had when you entered it. Continuing never uses an Ink Ribbon.",
		"#AT A TYPEWRITER",
		"Face it and press E, then pick a save slot. If you back out without saving, you keep your Ink Ribbon.",
		"#LOADING",
		"Main menu > Load Game. GZDoom also saves by itself at the start of each map.",

		"@5|Lighting",
		"Press L, or use Settings > Gameplay > Lighting. The game remembers your choice.",
		"#LIGHTING MODES",
		"Doom (default)|the levels lit exactly as Doom made them",
		"RE1|darker rooms everywhere, and a faint light that follows you. Items stay just visible.",
		"",
		"The Lighter (see ITEMS) lights up the dark around you in both modes.",
		"!Muzzle flashes look the same in both modes.",

		"@6|Records",
		"Main menu > Extras > Records: your best clear of each map, kept on this PC.",
		"#WHAT IS KEPT",
		"For each map, character and difficulty: your fastest time, with that run's kills, secrets, items, saves made and the date.",
		"",
		"A map counts when you reach its exit (MAP30: when you destroy the Icon of Sin). The level-end screen says NEW RECORD.",
		"",
		"The Mansion has no exit yet, so it has no record.",
		"*",
		"#CHEATS",
		"A run where any cheat was on, even for a moment, sets no record.",
		"#WHEN RECORDS ARE SAVED",
		"New records are written to disk when you quit normally: with Quit Game or by closing the window. Only a crash loses that session's new records.",
		"",
		"Records can be cleared on the Records screen (CLEAR RECORDS).",

		"@7|Cheats",
		"Main menu > Extras > Cheats. Cheats switch off when you quit, and a run with a cheat on sets no record.",
		"#IN THE CHEATS MENU",
		"Infinite Ammo|guns never run out",
		"Invincibility|no damage",
		"Super Jump|much higher jumps",
		"All Weapons|every weapon, fully loaded, on keys 1-7 and the wheel (7 = flamethrower, Chris only); ammo runs out",
		"*",
		"#CHEAT CODES",
		"Open the console (~), type a code and press Enter.",
		"starsteam|invincibility on / off",
		"rocketman|all weapons",
		"jillsandwich|full health",
		"inkribbon|3 Ink Ribbons",
		"re_jillflamer|gives Jill the flamethrower",
		"re_castcall|the ending cast call (re_castcall_jill / _chris / _both for one version)",
		"",
		"Cheats > Cheat List shows every cheat and its console command."
	};

	Array<int> pageFirst, pageLast, pageSection;
	Array<String> pageTitle;
	int page;
	int hover;    // what the mouse is over: -1 nothing, 0-7 a tab, or one of the buttons
	int overflowWarned;   // the page last reported as too long (-1 none)

	const TS = 0.68;         // body text size
	const BODY_X = 20;
	const BODY_Y = 64;
	const BODY_W = 600;
	const BODY_H = 274;
	const TAB_Y = 42;
	const TAB_W = 75;
	const TAB_H = 16;
	const BUTTON_Y = 346;
	const PREV_X = 20;
	const NEXT_X = 116;
	const BACK_X = 540;
	const BUTTON_W = 80;
	enum EButtons { HOVER_PREV = 100, HOVER_NEXT, HOVER_BACK }

	override void Init(Menu parent)
	{
		Super.Init(parent);
		for (int i = 0; i < text.Size(); i++)
		{
			String t = text[i];
			if (t.Left(1) != "@") continue;
			if (pageFirst.Size() > 0) pageLast.Push(i);
			int bar = t.IndexOf("|");
			pageSection.Push(t.Mid(1, bar - 1).ToInt());
			pageTitle.Push(t.Mid(bar + 1));
			pageFirst.Push(i + 1);
		}
		pageLast.Push(text.Size());
		page = 0;
		hover = -1;
		overflowWarned = -1;
		MenuSound("menu/activate");
	}

	void TurnTo(int p)
	{
		p = clamp(p, 0, pageFirst.Size() - 1);
		if (p == page) return;
		page = p;
		MenuSound("menu/change");
	}

	// the first page of a section
	void GoSection(int s)
	{
		for (int p = 0; p < pageSection.Size(); p++) if (pageSection[p] == s) { TurnTo(p); return; }
	}

	void Back() { Close(); MenuSound("menu/backup"); }

	override bool MenuEvent(int mkey, bool fromcontroller)
	{
		switch (mkey)
		{
		case MKEY_Left:
		case MKEY_PageUp:   TurnTo(page - 1); return true;
		case MKEY_Right:
		case MKEY_PageDown: TurnTo(page + 1); return true;
		case MKEY_Enter:    return true;   // only the arrows and the mouse turn pages
		case MKEY_Up:
		{
			// to the start of this section, or if already there, the one before
			int s = pageSection[page];
			if (page > 0 && pageSection[page - 1] == s) GoSection(s);
			else GoSection(max(0, s - 1));
			return true;
		}
		case MKEY_Down: GoSection(min(sections.Size() - 1, pageSection[page] + 1)); return true;
		}
		return Super.MenuEvent(mkey, fromcontroller);
	}

	override bool OnUIEvent(UIEvent ev)
	{
		if (ev.Type == UIEvent.Type_WheelUp) { TurnTo(page - 1); return true; }
		if (ev.Type == UIEvent.Type_WheelDown) { TurnTo(page + 1); return true; }
		if (ev.Type == UIEvent.Type_RButtonDown) { Back(); return true; }
		return Super.OnUIEvent(ev);
	}

	// --- the mouse ---------------------------------------------------------------

	override bool MouseEvent(int type, int x, int y)
	{
		Vector2 p = RERecordsMenu.ToCanvas(x, y);
		int over = -1;
		if (RERecordsMenu.Inside(p, BODY_X, TAB_Y, sections.Size() * TAB_W, TAB_H)) over = int((p.x - BODY_X) / TAB_W);
		else if (RERecordsMenu.Inside(p, PREV_X, BUTTON_Y, BUTTON_W, 20)) over = HOVER_PREV;
		else if (RERecordsMenu.Inside(p, NEXT_X, BUTTON_Y, BUTTON_W, 20)) over = HOVER_NEXT;
		else if (RERecordsMenu.Inside(p, BACK_X, BUTTON_Y, BUTTON_W, 20)) over = HOVER_BACK;
		if (over != hover && over >= 0 && type == MOUSE_Move) MenuSound("menu/cursor");
		hover = over;
		if (type != MOUSE_Release || over < 0) return true;
		if (over == HOVER_PREV) TurnTo(page - 1);
		else if (over == HOVER_NEXT) TurnTo(page + 1);
		else if (over == HOVER_BACK) Back();
		else GoSection(over);
		return true;
	}

	// --- drawing -------------------------------------------------------------------

	static double LineH() { return NewSmallFont.GetHeight() * TS + 1; }

	// One column of a page (text rows from..to), drawn from (x, y), w wide.
	// Returns the y under its last line.
	double DrawColumn(int from, int to, double x, double y, double w)
	{
		// the key column fits the widest key in this column, at most 45% of it
		double keyW = 0;
		for (int i = from; i < to; i++)
		{
			String r = text[i];
			int bar = r.IndexOf("|");
			if (bar > 0 && r.Left(1) != "#") keyW = max(keyW, REDraw.TextWidth(r.Left(bar), TS));
		}
		keyW = min(keyW + 10, w * 0.45);
		double lh = LineH();
		for (int i = from; i < to; i++)
		{
			String r = text[i];
			if (r.Length() == 0) { y += lh * 0.5; continue; }
			if (r.Left(1) == "#")
			{
				if (i > from) y += lh * 0.4;
				String head = r.Mid(1);
				int hb = head.IndexOf("|");
				if (hb > 0)   // a heading over both the key and text columns
				{
					REDraw.Text(x, y, head.Left(hb), Font.CR_GOLD, TS);
					REDraw.Text(x + keyW, y, head.Mid(hb + 1), Font.CR_GOLD, TS);
				}
				else REDraw.Text(x, y, head, Font.CR_GOLD, TS);
				y += lh + 2;
				continue;
			}
			int bar = r.IndexOf("|");
			if (bar > 0)
			{
				REDraw.Text(x, y, r.Left(bar), Font.CR_WHITE, TS);
				y = Wrapped(r.Mid(bar + 1), x + keyW, y, w - keyW, Font.CR_GRAY);
				continue;
			}
			if (r.Left(1) == "!") { y = Wrapped(r.Mid(1), x, y, w, Font.CR_DARKGRAY); continue; }
			y = Wrapped(r, x, y, w, Font.CR_WHITE);
		}
		return y;
	}

	// Text wrapped to w; returns the y under it.
	double Wrapped(String t, double x, double y, double w, int fontColor)
	{
		BrokenLines lines = NewSmallFont.BreakLines(t, int(w / TS));
		for (int i = 0; i < lines.Count(); i++)
		{
			REDraw.Text(x, y, lines.StringAt(i), fontColor, TS);
			y += LineH();
		}
		return y;
	}

	void Button(double x, String label, bool on, bool usable)
	{
		REDraw.Box(x, BUTTON_Y, BUTTON_W, 20, on && usable ? Color(255, 60, 52, 10) : Color(255, 20, 20, 24), 0.9);
		REDraw.Frame(x, BUTTON_Y, BUTTON_W, 20, on && usable ? Color(255, 255, 220, 0) : Color(255, 110, 110, 110));
		int c = !usable ? Font.CR_DARKGRAY : (on ? Font.CR_GOLD : Font.CR_WHITE);
		REDraw.Text(x + (BUTTON_W - REDraw.TextWidth(label)) / 2, BUTTON_Y + 5, label, c);
	}

	override void Drawer()
	{
		Screen.Dim(Color(255, 0, 0, 0), 0.92, 0, 0, Screen.GetWidth(), Screen.GetHeight());
		Color gray = Color(255, 110, 110, 110), dark = Color(255, 20, 20, 24), sel = Color(255, 255, 220, 0), selBox = Color(255, 60, 52, 10);
		REDraw.Text(20, 12, "MANUAL", Font.CR_GOLD, 2.0);
		REDraw.Text(180, 20, "how to play Resident Doom", Font.CR_DARKGRAY);

		// the section tabs
		int section = pageSection[page];
		for (int s = 0; s < sections.Size(); s++)
		{
			double tx = BODY_X + s * TAB_W;
			bool on = s == section;
			REDraw.Box(tx, TAB_Y, TAB_W, TAB_H, on ? selBox : dark, 0.9);
			REDraw.Frame(tx, TAB_Y, TAB_W, TAB_H, on || s == hover ? sel : gray);
			int c = on ? Font.CR_GOLD : (s == hover ? Font.CR_WHITE : Font.CR_GRAY);
			REDraw.Text(tx + (TAB_W - REDraw.TextWidth(sections[s], 0.7)) / 2, TAB_Y + 4, sections[s], c, 0.7);
		}

		// the page
		REDraw.Box(BODY_X, BODY_Y, BODY_W, BODY_H, dark, 0.9);
		REDraw.Frame(BODY_X, BODY_Y, BODY_W, BODY_H, gray);
		REDraw.Text(BODY_X + 12, BODY_Y + 8, pageTitle[page], Font.CR_RED, 1.2);
		int first = pageFirst[page], last = pageLast[page], split = -1;
		for (int i = first; i < last; i++) if (text[i] == "*") split = i;
		double top = BODY_Y + 32, bottom;
		if (split < 0) bottom = DrawColumn(first, last, BODY_X + 12, top, BODY_W - 24);
		else
		{
			bottom = DrawColumn(first, split, BODY_X + 12, top, 278);
			bottom = max(bottom, DrawColumn(split + 1, last, BODY_X + 312, top, 276));
		}
		// a page whose text runs past its box says so in the console (for checking)
		if (bottom > BODY_Y + BODY_H - 4 && page != overflowWarned)
		{
			overflowWarned = page;
			Console.Printf("MANUAL OVERFLOW: page %d (%s) ends at %.0f, the box at %d", page + 1, pageTitle[page], bottom, BODY_Y + BODY_H);
		}

		// buttons and help
		Button(PREV_X, "< PREV", hover == HOVER_PREV, page > 0);
		Button(NEXT_X, "NEXT >", hover == HOVER_NEXT, page < pageFirst.Size() - 1);
		Button(BACK_X, "BACK", hover == HOVER_BACK, true);
		String count = String.Format("Page %d of %d", page + 1, pageFirst.Size());
		REDraw.Text(212, BUTTON_Y + 5, count, Font.CR_GRAY);
		REDraw.Text(20, 372, "LEFT/RIGHT turn the page    UP/DOWN change section    ESC back", Font.CR_DARKGRAY, 0.72);
		REDraw.Text(20, 385, "MOUSE: click a tab, PREV, NEXT or BACK    WHEEL turns pages    RIGHT-CLICK back", Font.CR_DARKGRAY, 0.72);
	}
}
