// ---------------------------------------------------------------------------
// RE_Typewriter.zs - RE1's typewriter saves, Ink Ribbons and the save modes.
//
// Every map has a typewriter next to its item box (RE_ItemBox.zs): a small
// low-poly 3D model of a typewriter on a wooden table (models/props, made by
// re1convert prop typewriter). Face it and press E:
//   Classic RE saves (re_save_classic 1): "Will you use an INK RIBBON?" - YES
//     uses one ribbon and opens the save screen. Backing out of the save
//     screen without saving gives the ribbon back. Like RE1
//     (check_typewriter), no ribbon means no save. The main menu's Save Game
//     and F6 then only say to find a typewriter.
//   Typewriter (re_save_classic 2): like Classic, saving only at a
//     typewriter, but no Ink Ribbon is needed ("Save your progress?").
//   Normal saves anytime (re_save_classic 0, the default): the typewriter
//     saves without a ribbon, and the menu and F6 work as usual.
// Doom's armor bonuses are Ink Ribbons (RE_DoomItems.zs).
// ---------------------------------------------------------------------------

class RETypewriter : Actor
{
	// The save modes (re_save_classic: 0 Normal, 2 Typewriter, 1 Classic RE).
	static clearscope bool TypewriterOnly() { return re_save_classic != 0; }   // Typewriter and Classic
	static clearscope bool NeedsRibbon() { return re_save_classic == 1; }      // Classic only

	Default
	{
		Tag "Typewriter";
		Radius 16;      // the table is 20 x 28
		Height 40;
		+SOLID
	}
	States
	{
	Spawn:
		TYPW A -1;      // invisible; modeldef.txt draws the 3D model
		Stop;
	}

	// RE1 lighting: kept readable in dark rooms, like the pickups. The table is
	// big and dark, so it may be as bright as in Doom lighting (never brighter).
	override void Tick()
	{
		Super.Tick();
		lightlevel = re_dark ? RELightingHandler.Glow(self, 32, 128, 0) : -1;
	}

	// Doesn't block anything: there's room to walk past the table on at least
	// one side, both along and across the passage it stands in (48 units of
	// floor, the player is 32 wide), and it keeps clear of the item box and
	// of the player. Walls are traced above step height, so a low step
	// doesn't count as a wall.
	// Like LeavesRoom, but if the spot doesn't leave room, first slide the
	// table against the nearest wall (a narrow corridor) and try again.
	static bool FitAgainstWall(Actor tw)
	{
		if (LeavesRoom(tw)) return true;
		double bestDist = 1e9, bestAng = 0;
		for (int a = 0; a < 360; a += 45)
		{
			FLineTraceData t;
			tw.LineTrace(a, 128, 0, TRF_THRUACTORS, 32, data: t);
			if (t.HitType != TRACE_HitNone && t.Distance < bestDist) { bestDist = t.Distance; bestAng = a; }
		}
		if (bestDist >= 128) return false;
		Vector3 old = tw.pos;
		double move = bestDist - tw.radius - 2;
		if (move <= 0) return false;
		tw.SetOrigin((tw.Vec2Angle(move, bestAng), tw.pos.z), false);
		tw.SetZ(tw.floorz);
		if (tw.TestMobjLocation() && abs(tw.pos.z - old.z) <= 24 && LeavesRoom(tw)) return true;
		tw.SetOrigin(old, false);
		return false;
	}

	static bool LeavesRoom(Actor tw)
	{
		for (int axis = 0; axis < 2; axis++)
		{
			double best = 0;
			for (int side = 0; side < 2; side++)
			{
				FLineTraceData t;
				tw.LineTrace(tw.Angle + axis * 90 + side * 180, 256, 0, TRF_THRUACTORS, 32, data: t);
				double gap = (t.HitType == TRACE_HitNone ? 256 : t.Distance) - tw.radius;
				best = max(best, gap);
			}
			if (best < 48) return false;
		}
		let it = BlockThingsIterator.Create(tw, 96);
		while (it.Next())
		{
			let mo = it.thing;
			if (mo == tw) continue;
			if (mo is "REItemBoxActor" && tw.Distance2D(mo) < tw.radius + mo.radius + 8) return false;
			if (mo.player != null && tw.Distance2D(mo) < 64) return false;
		}
		return true;
	}
}

extend class RETankPlayer
{
	// E in front of a typewriter (called from OpenBoxAhead).
	bool UseTypewriterAhead()
	{
		Vector2 probe = pos.xy + AngleToVector(Angle, RE_ACTION_REACH);
		let it = BlockThingsIterator.Create(self, RE_ACTION_REACH + 48);
		while (it.Next())
		{
			let tw = RETypewriter(it.thing);
			if (tw == null) continue;
			if (min((tw.pos.xy - probe).Length(), Distance2D(tw)) > tw.radius + radius + 8) continue;
			let inv = REInventory(FindInventory("REInventory"));
			int ribbons = inv != null ? inv.CountItem(RE_ITEM_INK_RIBBON) : 0;
			EventHandler.SendInterfaceEvent(PlayerNumber(), "re_typewriter", ribbons);
			return true;
		}
		return false;
	}
}

// Game side: ribbons used / given back; F6 in the typewriter-only modes.
class RETypewriterHandler : EventHandler
{
	override void NetworkProcess(ConsoleEvent e)
	{
		if (e.Player < 0 || !playeringame[e.Player] || players[e.Player].mo == null) return;
		let pmo = players[e.Player].mo;
		let inv = REInventory(pmo.FindInventory("REInventory"));
		if (e.Name ~== "re_ribbon_use" && inv != null)
		{
			if (inv.UseOne(RE_ITEM_INK_RIBBON)) inv.ShowMessage("You used an INK RIBBON.");
		}
		else if (e.Name ~== "re_ribbon_refund" && inv != null)
		{
			if (inv.Store(RE_ITEM_INK_RIBBON, 1) == 0) inv.ShowMessage("You kept your INK RIBBON.");
		}
	}

	override void InterfaceProcess(ConsoleEvent e)
	{
		if (e.Name ~== "re_typewriter")
		{
			let st = RESaveState.Get();
			if (st != null) st.ribbonsNow = e.Args[0];
			Menu.SetMenu('RETypewriterMenu');
		}
	}

	// F6 is GZDoom's own quicksave (keys.cfg). In the Typewriter and Classic
	// save modes, a key bound to it says to find a typewriter instead.
	override bool InputProcess(InputEvent e)
	{
		if (e.Type != InputEvent.Type_KeyDown || gamestate != GS_LEVEL) return false;
		String b = Bindings.GetBinding(e.KeyScan);
		if (!(b ~== "quicksave") && !(b ~== "re_quicksave")) return false;
		if (!RETypewriter.TypewriterOnly())
		{
			// Normal saves: F6 saves; count it for the map's record (RE_Records.zs).
			// (The first time, F6 opens the save screen: that save isn't counted again.)
			if (Menu.GetCurrentMenu() == null)
			{
				EventHandler.SendNetworkEvent("re_record_save");
				let st = RESaveState.Get();
				if (st != null) { st.f6Counted = true; st.f6Time = MSTime(); st.f6Pending = true; }
			}
			return false;
		}
		Menu.StartMessage("You can only save at a typewriter.\n\nPress a key.", 1);
		return true;
	}
}

// Shared between the typewriter prompt and the save screen (UI side).
class RESaveState : StaticEventHandler
{
	ui bool fromTypewriter;   // the save screen was opened by a typewriter
	ui bool ribbonUsed;       // ... and that used an ink ribbon
	ui int ribbonsNow;        // ribbons carried, for the typewriter prompt
	ui bool f6Counted;        // F6 was just pressed and counted as a save (records)
	ui uint f6Time;           // ... when (MSTime)
	ui bool f6Pending;        // F6 pressed: a quicksave, unless it opens the save screen (which reports its own)

	static clearscope RESaveState Get()
	{
		return RESaveState(StaticEventHandler.Find("RESaveState"));
	}

	// F6 saved straight away (or after its "overwrite?" question): a save on
	// this level for Continue (RE_Continue.zs).
	override void UiTick()
	{
		if (!f6Pending || MSTime() - f6Time < 150 || Menu.GetCurrentMenu() != null) return;
		f6Pending = false;
		EventHandler.SendNetworkEvent("re_saved");
	}
}

// RE1-style prompt over RE1's own save-screen picture.
class RETypewriterMenu : GenericMenu
{
	int ribbons;
	bool yes;
	TextureID back;

	override void Init(Menu parent)
	{
		Super.Init(parent);
		let st = RESaveState.Get();
		ribbons = st != null ? st.ribbonsNow : 0;
		yes = true;
		back = TexMan.CheckForTexture("TYPEBACK", TexMan.Type_Any);
		MenuSound("menu/activate");
	}

	bool CanSave() { return !RETypewriter.NeedsRibbon() || ribbons > 0; }

	override bool OnUIEvent(UIEvent ev)
	{
		if (ev.Type == UIEvent.Type_KeyDown && (ev.KeyChar == 101 || ev.KeyChar == 69))   // e, E (Action) confirms like Enter
			return MenuEvent(MKEY_Enter, false);
		if (ev.Type == UIEvent.Type_RButtonDown) { yes = false; return MenuEvent(MKEY_Enter, false); }   // right-click: NO
		return Super.OnUIEvent(ev);
	}

	override bool MenuEvent(int mkey, bool fromcontroller)
	{
		if (CanSave() && (mkey == MKEY_Left || mkey == MKEY_Right || mkey == MKEY_Up || mkey == MKEY_Down))
		{
			yes = !yes;
			MenuSound("menu/cursor");
			return true;
		}
		if (mkey == MKEY_Enter)
		{
			Close();
			if (CanSave() && yes)
			{
				let st = RESaveState.Get();
				bool ribbon = RETypewriter.NeedsRibbon();
				if (st != null) { st.fromTypewriter = true; st.ribbonUsed = ribbon; }
				if (ribbon) EventHandler.SendNetworkEvent("re_ribbon_use");
				Menu.SetMenu('SaveGameMenu');
			}
			return true;
		}
		return Super.MenuEvent(mkey, fromcontroller);
	}

	// The mouse: hovering YES or NO picks it, a click answers. With no ribbon
	// to use, any click closes the message. Right-click is NO.
	override bool MouseEvent(int type, int x, int y)
	{
		// screen -> the 640x480 layout Words() draws on (fit to 4:3, centred)
		double s = min(Screen.GetWidth() / 640.0, Screen.GetHeight() / 480.0);
		double vy = (y - (Screen.GetHeight() - 480 * s) / 2) / s;
		if (!CanSave())
		{
			if (type == MOUSE_Release) MenuEvent(MKEY_Enter, false);
			return true;
		}
		int over = vy >= 372 && vy < 402 ? 1 : (vy >= 402 && vy < 434 ? 0 : -1);
		if (over < 0) return true;
		if ((over == 1) != yes) { yes = over == 1; MenuSound("menu/cursor"); }
		if (type == MOUSE_Release) MenuEvent(MKEY_Enter, false);
		return true;
	}

	void Words(int color, double y, String text, double size = 1.0)
	{
		Font f = BigFont;
		double w = f.StringWidth(text) * size;
		Screen.DrawText(f, color, (640 - w) / 2, y, text, DTA_VirtualWidth, 640, DTA_VirtualHeight, 480,
			DTA_FullscreenScale, FSMode_ScaleToFit43, DTA_ScaleX, size, DTA_ScaleY, size);
	}

	override void Drawer()
	{
		Screen.Dim(Color(255, 0, 0, 0), 1.0, 0, 0, Screen.GetWidth(), Screen.GetHeight());
		Screen.DrawTexture(back, false, 0, 0, DTA_VirtualWidth, 640, DTA_VirtualHeight, 480,
			DTA_FullscreenScale, FSMode_ScaleToFit43, DTA_DestWidth, 640, DTA_DestHeight, 480, DTA_ColorOverlay, Color(90, 0, 0, 0));
		if (!CanSave())
		{
			Words(Font.CR_WHITE, 340, "You need an INK RIBBON to save.", 0.8);
			Words(Font.CR_DARKGRAY, 400, "Press a key", 0.6);
			return;
		}
		String q = RETypewriter.NeedsRibbon() ? String.Format("Will you use an INK RIBBON?  (%d left)", ribbons) : "Save your progress?";
		Words(Font.CR_WHITE, 330, q, 0.8);
		Words(yes ? Font.CR_GOLD : Font.CR_DARKGRAY, 380, yes ? "> YES <" : "YES", 0.9);
		Words(!yes ? Font.CR_GOLD : Font.CR_DARKGRAY, 410, !yes ? "> NO <" : "NO", 0.9);
	}
}

// GZDoom's save screen, with the save modes: in Classic mode it only opens
// from a typewriter. A ribbon used for a save that never happened goes back.
class RESaveMenu : SaveMenu
{
	bool saved;
	bool blocked;
	bool countedByF6;   // opened by F6, which already counted this save (RE_Records.zs)

	override void Init(Menu parent, ListMenuDescriptor desc)
	{
		Super.Init(parent, desc);
		listboxRows = RESaveScreen.ROWS;
		hoverBtn = -1;
		let st = RESaveState.Get();
		if (st != null) { countedByF6 = st.f6Counted && MSTime() - st.f6Time < 1000; st.f6Counted = false; st.f6Pending = false; }   // (this screen reports its own save: re_saved)
		blocked = RETypewriter.TypewriterOnly() && (st == null || !st.fromTypewriter);
	}

	override void Ticker()
	{
		if (blocked)
		{
			blocked = false;
			Close();
			Menu.StartMessage("You can only save at a typewriter.\n\nPress a key.", 1);
			return;
		}
		if (mSaveName.Length() > 0 && !saved && !countedByF6) EventHandler.SendNetworkEvent("re_record_save");   // counted for the map's record (RE_Records.zs)
		if (mSaveName.Length() > 0 && !saved) EventHandler.SendNetworkEvent("re_saved");   // a save on this level: dying comes back here (RE_Continue.zs)
		if (mSaveName.Length() > 0) saved = true;   // the save happens in Super.Ticker
		Super.Ticker();
	}

	// Drawn and clicked in the RE1 style (RESaveScreen below).
	int hoverBtn;
	override void Drawer() { RESaveScreen.Draw(self, true, hoverBtn); }

	// Naming the save is done here, not in GZDoom's own text box (which can't
	// be backed out of with the mouse): type, Backspace, Enter or SAVE saves;
	// Esc, right-click or BACK goes back to the list.
	bool naming;
	String typed;
	const NAME_MAX = 28;

	void StartNaming()
	{
		int n = manager.SavegameCount();
		if (Selected < 0 || Selected >= n) return;
		naming = true;
		mEntering = true;
		typed = Selected != 0 ? manager.GetSavegame(Selected).SaveTitle : "";
		MenuSound("menu/choose");
	}

	void StopNaming(bool save)
	{
		naming = false;
		mEntering = false;
		if (!save) { MenuSound("menu/backup"); return; }
		if (typed.Length() == 0) typed = level.MapName;   // GZDoom needs a name
		mSaveName = typed;   // saved in SaveMenu.Ticker
	}

	override bool MenuEvent(int mkey, bool fromcontroller)
	{
		if (naming)
		{
			if (mkey == MKEY_Enter) StopNaming(true);
			else if (mkey == MKEY_Back) StopNaming(false);
			return true;   // the arrows do nothing while typing
		}
		if (mkey == MKEY_Enter && mSaveName.Length() == 0) { StartNaming(); return true; }
		return Super.MenuEvent(mkey, fromcontroller);
	}

	override bool MouseEvent(int type, int x, int y)
	{
		if (mSaveName.Length() > 0) return true;   // saving now: leave the list alone
		if (naming)
		{
			hoverBtn = RESaveScreen.ButtonAt(x, y);
			if (type == MOUSE_Release && hoverBtn == RESaveScreen.BTN_GO) StopNaming(true);
			else if (type == MOUSE_Release && hoverBtn == RESaveScreen.BTN_BACK) StopNaming(false);
			return true;
		}
		hoverBtn = RESaveScreen.Mouse(self, type, x, y, true);
		return true;
	}

	override bool OnUIEvent(UIEvent ev)
	{
		if (naming)
		{
			if (ev.Type == UIEvent.Type_RButtonDown) { StopNaming(false); return true; }
			if (ev.Type == UIEvent.Type_Char)
			{
				if (ev.KeyChar >= 32 && typed.CodePointCount() < NAME_MAX) typed.AppendCharacter(ev.KeyChar);
				return true;
			}
			if (ev.Type == UIEvent.Type_KeyDown && ev.KeyChar == UIEvent.Key_Backspace)
			{
				if (typed.Length() > 0) typed.DeleteLastCharacter();
				return true;
			}
			if (ev.Type == UIEvent.Type_KeyDown && ev.KeyChar != UIEvent.Key_Return && ev.KeyChar != UIEvent.Key_Escape) return true;
			return Super.OnUIEvent(ev);   // Enter and Esc become menu commands
		}
		if (ev.Type == UIEvent.Type_RButtonDown) return MenuEvent(MKEY_Back, false);   // right-click: back
		return Super.OnUIEvent(ev);
	}

	override void OnDestroy()
	{
		let st = RESaveState.Get();
		if (st != null && st.fromTypewriter)
		{
			if (st.ribbonUsed && !saved) EventHandler.SendNetworkEvent("re_ribbon_refund");
			st.fromTypewriter = false;
			st.ribbonUsed = false;
		}
		Super.OnDestroy();
	}
}

// GZDoom's load screen, in the same RE1 style (menudef.txt LoadGameMenu).
class RELoadMenu : LoadMenu
{
	int hoverBtn;
	override void Init(Menu parent, ListMenuDescriptor desc)
	{
		Super.Init(parent, desc);
		listboxRows = RESaveScreen.ROWS;
		hoverBtn = -1;
	}
	override void Drawer() { RESaveScreen.Draw(self, false, hoverBtn); }
	override bool MouseEvent(int type, int x, int y)
	{
		hoverBtn = RESaveScreen.Mouse(self, type, x, y, false);
		return true;
	}
	override bool OnUIEvent(UIEvent ev)
	{
		if (ev.Type == UIEvent.Type_RButtonDown) return MenuEvent(MKEY_Back, false);   // right-click: back
		return Super.OnUIEvent(ev);
	}
}

// The Save and Load screens in the RE1 style of the Records and Manual
// screens (REDraw's 640x400 canvas): the save's picture and details on the
// left, the list of saves on the right, SAVE / LOAD, DELETE and BACK buttons.
// GZDoom still does the saving, loading, name typing and the Delete question;
// only the look and the mouse are ours.
class RESaveScreen ui
{
	const ROWS = 14;
	const LIST_X = 280;
	const LIST_Y = 52;
	const LIST_W = 340;
	const ROW_H = 17;
	const PIC_X = 20;
	const PIC_Y = 52;
	const PIC_W = 240;
	const PIC_H = 180;
	const BTN_Y = 306;
	enum EButtons { BTN_GO, BTN_DELETE, BTN_BACK }
	static int BtnX(int b) { return b == BTN_GO ? 280 : (b == BTN_DELETE ? 390 : 540); }
	static int BtnW(int b) { return b == BTN_BACK ? 80 : 100; }

	// keep the chosen save in view
	static void Scroll(LoadSaveMenu m)
	{
		if (m.Selected >= 0 && m.Selected < m.TopItem) m.TopItem = m.Selected;
		if (m.Selected >= m.TopItem + ROWS) m.TopItem = m.Selected - ROWS + 1;
		m.TopItem = clamp(m.TopItem, 0, max(0, m.manager.SavegameCount() - ROWS));
	}

	static void Button(double x, double w, String text, bool on, bool usable)
	{
		REDraw.Box(x, BTN_Y, w, 20, on && usable ? Color(255, 60, 52, 10) : Color(255, 20, 20, 24), 0.9);
		REDraw.Frame(x, BTN_Y, w, 20, on && usable ? Color(255, 255, 220, 0) : Color(255, 110, 110, 110));
		REDraw.Text(x + (w - REDraw.TextWidth(text)) / 2, BTN_Y + 5, text, !usable ? Font.CR_DARKGRAY : (on ? Font.CR_GOLD : Font.CR_WHITE));
	}

	static bool CanDelete(LoadSaveMenu m, bool isSave)
	{
		int n = m.manager.SavegameCount();
		if (m.Selected < 0 || m.Selected >= n) return false;
		if (isSave && m.Selected == 0) return false;   // "<New Save Game>"
		return !m.manager.GetSavegame(m.Selected).bNoDelete;
	}

	static void Draw(LoadSaveMenu m, bool isSave, int hoverBtn)
	{
		Screen.Dim(Color(255, 0, 0, 0), 0.92, 0, 0, Screen.GetWidth(), Screen.GetHeight());
		if (gameaction == ga_loadgame || gameaction == ga_loadgamehidecon || gameaction == ga_savegame) return;
		Color gray = Color(255, 110, 110, 110), dark = Color(255, 20, 20, 24), selBox = Color(255, 60, 52, 10);
		REDraw.Text(20, 12, isSave ? "SAVE GAME" : "LOAD GAME", Font.CR_GOLD, 2.0);
		REDraw.Text(210, 20, isSave ? "pick a slot, then type a name" : "pick a save to continue from", Font.CR_DARKGRAY);
		int n = m.manager.SavegameCount();
		Scroll(m);

		// the picture
		REDraw.Box(PIC_X, PIC_Y, PIC_W, PIC_H, dark, 0.9);
		Vector2 tl = REDraw.ToScreen(PIC_X, PIC_Y);
		double s = REDraw.Scale();
		if (!m.manager.DrawSavePic(int(tl.x), int(tl.y), int(PIC_W * s), int(PIC_H * s)))
		{
			String none = n == 0 || m.Selected < 0 ? "" : (m.manager.GetSavegame(m.Selected).bOldVersion ? "Made with another version" : "No picture");
			if (isSave && m.Selected == 0) none = "A new save";
			REDraw.Text(PIC_X + (PIC_W - REDraw.TextWidth(none)) / 2, PIC_Y + PIC_H / 2 - 6, none, Font.CR_DARKGRAY);
		}
		REDraw.Frame(PIC_X, PIC_Y, PIC_W, PIC_H, gray);

		// its details (date, map, time played)
		REDraw.Box(PIC_X, 240, PIC_W, 56, dark, 0.9);
		REDraw.Frame(PIC_X, 240, PIC_W, 56, gray);
		Array<String> info;
		m.manager.SaveCommentString.Split(info, "\n");
		int line = 0;
		for (int i = 0; i < info.Size() && line < 3; i++)
		{
			if (info[i].Length() == 0) continue;
			REDraw.Text(PIC_X + 8, 246 + line * 15, info[i], line == 0 ? Font.CR_WHITE : Font.CR_GRAY, 0.85);
			line++;
		}

		// the list
		REDraw.Box(LIST_X, LIST_Y, LIST_W, ROWS * ROW_H + 6, dark, 0.9);
		REDraw.Frame(LIST_X, LIST_Y, LIST_W, ROWS * ROW_H + 6, Color(255, 255, 220, 0));
		if (n == 0) REDraw.Text(LIST_X + 12, LIST_Y + 10, "No saved games yet.", Font.CR_DARKGRAY);
		for (int r = 0; r < ROWS && m.TopItem + r < n; r++)
		{
			int j = m.TopItem + r;
			let node = m.manager.GetSavegame(j);
			double y = LIST_Y + 3 + r * ROW_H;
			bool sel = j == m.Selected;
			if (sel) REDraw.Box(LIST_X + 2, y, LIST_W - 4, ROW_H, m.mEntering ? Color(255, 90, 16, 12) : selBox, 0.95);
			String t = node.SaveTitle;
			int c = sel ? Font.CR_GOLD : Font.CR_WHITE;
			if (node.bOldVersion) c = Font.CR_RED;
			else if (node.bMissingWads) c = Font.CR_DARKGRAY;
			let sm = RESaveMenu(m);
			if (sel && sm != null && sm.naming) { t = sm.typed .. NewSmallFont.GetCursor(); c = Font.CR_WHITE; }
			else if (sel && m.mEntering && m.mInput != null) { t = m.mInput.GetText() .. NewSmallFont.GetCursor(); c = Font.CR_WHITE; }
			// keep long names inside the box
			while (t.Length() > 1 && REDraw.TextWidth(t, 0.9) > LIST_W - 20) t = sel && m.mEntering ? t.Mid(1) : t.Left(t.Length() - 1);
			REDraw.Text(LIST_X + 10, y + 3, t, c, 0.9);
		}
		if (m.TopItem > 0) REDraw.Text(LIST_X + LIST_W - 14, LIST_Y + 4, "^", Font.CR_GOLD);
		if (m.TopItem + ROWS < n) REDraw.Text(LIST_X + LIST_W - 14, LIST_Y + ROWS * ROW_H - 8, "v", Font.CR_GOLD);

		// buttons and help
		bool picked = m.Selected >= 0 && m.Selected < n;
		Button(BtnX(BTN_GO), BtnW(BTN_GO), isSave ? "SAVE" : "LOAD", hoverBtn == BTN_GO, picked);
		Button(BtnX(BTN_DELETE), BtnW(BTN_DELETE), "DELETE", hoverBtn == BTN_DELETE, CanDelete(m, isSave));
		Button(BtnX(BTN_BACK), BtnW(BTN_BACK), "BACK", hoverBtn == BTN_BACK, true);
		let nm = RESaveMenu(m);
		if (nm != null && nm.naming) REDraw.Text(20, 340, "TYPE A NAME    ENTER or SAVE saves    ESC, RIGHT-CLICK or BACK goes back to the list", Font.CR_GOLD, 0.85); else
		REDraw.Text(20, 340, isSave ? "UP/DOWN pick    ENTER save (type a name, ENTER again)    DEL delete    ESC back"
			: "UP/DOWN pick    ENTER load    DEL delete    ESC back", Font.CR_DARKGRAY, 0.85);
		REDraw.Text(20, 354, "MOUSE: click a save, then SAVE / LOAD, DELETE or BACK    WHEEL scrolls    RIGHT-CLICK back", Font.CR_DARKGRAY, 0.85);
	}

	// The button under the mouse (screen coordinates), -1 none.
	static int ButtonAt(int x, int y)
	{
		Vector2 p = RERecordsMenu.ToCanvas(x, y);
		for (int b = 0; b < 3; b++) if (RERecordsMenu.Inside(p, BtnX(b), BTN_Y, BtnW(b), 20)) return b;
		return -1;
	}

	// Returns the button under the mouse (-1 none).
	static int Mouse(LoadSaveMenu m, int type, int x, int y, bool isSave)
	{
		Vector2 p = RERecordsMenu.ToCanvas(x, y);
		int n = m.manager.SavegameCount();
		if (RERecordsMenu.Inside(p, LIST_X, LIST_Y + 3, LIST_W, ROWS * ROW_H))
		{
			int j = m.TopItem + int((p.y - LIST_Y - 3) / ROW_H);
			if (j >= n) return -1;
			if (j != m.Selected)
			{
				m.Selected = j;
				m.manager.UnloadSaveData();
				m.manager.ExtractSaveData(j);
				m.UpdateSaveComment();
				Menu.MenuSound("menu/cursor");
			}
			// a click on the chosen save saves / loads it, like Enter
			if (type == Menu.MOUSE_Release) m.MenuEvent(Menu.MKEY_Enter, false);
			return -1;
		}
		int over = -1;
		for (int b = 0; b < 3; b++) if (RERecordsMenu.Inside(p, BtnX(b), BTN_Y, BtnW(b), 20)) over = b;
		if (type != Menu.MOUSE_Release || over < 0) return over;
		if (over == BTN_GO && m.Selected >= 0 && m.Selected < n) m.MenuEvent(Menu.MKEY_Enter, false);
		else if (over == BTN_DELETE && CanDelete(m, isSave))
		{
			String ask = String.Format("%s%s%s%s?\n\n%s", Stringtable.Localize("$MNU_DELETESG"), TEXTCOLOR_WHITE, m.manager.GetSavegame(m.Selected).SaveTitle, TEXTCOLOR_NORMAL, Stringtable.Localize("$PRESSYN"));
			m.StartMessage(ask, 0);
		}
		else if (over == BTN_BACK) { m.Close(); Menu.MenuSound("menu/backup"); }
		return over;
	}
}
