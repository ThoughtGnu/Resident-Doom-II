// ---------------------------------------------------------------------------
// RE_Title.zs - the title screen (the picture before the main menu,
// mod/hires/TITLEPIC.png).
//
// GZDoom shows the picture by itself and opens the main menu on any key,
// and mods can't draw on it. So while the picture is up, a see-through
// screen of our own (RETitleMenu) sits on top of it. It writes PRESS ENTER
// TO PLAY with two small credit lines under it, and only Enter goes on to
// the main menu; every other key, Escape too, does nothing. Escape in the
// main menu comes back here.
// ---------------------------------------------------------------------------

class RETitleHandler : StaticEventHandler
{
	static clearscope bool OnTitle()
	{
		return gamestate == GS_DEMOSCREEN || gamestate == GS_TITLELEVEL;
	}

	ui int titleTics;

	// whenever the title picture has been up for a moment with no menu over
	// it, put our screen on it (the moment skips the split second between
	// choosing New Game and the level loading, which still counts as the title)
	override void UiTick()
	{
		if (!OnTitle() || Menu.GetCurrentMenu() != null) { titleTics = 0; return; }
		if (++titleTics >= 8) { titleTics = 0; Menu.SetMenu('RETitle'); }
	}
}

class RETitleMenu : ListMenu
{
	override void Init(Menu parent, ListMenuDescriptor desc)
	{
		Super.Init(parent, desc);
		DontDim = true;    // the picture stays as it is
		DontBlur = true;
	}

	override bool OnUIEvent(UIEvent ev)
	{
		return true;       // letters, mouse: nothing happens
	}

	// GZDoom turns Enter, Escape and the arrows into menu commands; only
	// Enter on the keyboard (not a gamepad's confirm button) goes on.
	override bool MenuEvent(int mkey, bool fromcontroller)
	{
		if (mkey == MKEY_Enter && !fromcontroller && RETitleHandler.OnTitle())
		{
			Menu.MenuSound("menu/activate");
			Menu.SetMenu('REMainMenuTitle');   // menudef.txt: without the small logo
		}
		return true;
	}
	override void Ticker()
	{
		if (!RETitleHandler.OnTitle()) { Close(); return; }   // a game started
		Super.Ticker();
	}

	// The text goes in the dark strip under the DOOM logo (the bottom ~10% of
	// the picture). Each line is sized from the screen height, but never wider
	// than 90% of the screen, so nothing runs off an edge at any resolution.
	override void Drawer()
	{
		int h = Screen.GetHeight();
		RECredits.Line(BigFont, Font.CR_RED, "PRESS ENTER TO PLAY", h * 0.900, 0.026);
		RECredits.Line(NewSmallFont, Font.CR_GRAY, "Made by ThoughtGnu with Claude Code", h * 0.931, 0.019);
		RECredits.Line(NewSmallFont, Font.CR_DARKGRAY, "Resident Evil © Capcom · DOOM II © id Software", h * 0.953, 0.019);
		RECredits.Line(NewSmallFont, Font.CR_DARKGRAY, "Fan-made, not affiliated", h * 0.975, 0.019);
	}
}

// Main menu > Extras > Credits: the whole screen under a see-through dark layer, and
// the credits in the title screen's text style (GZDoom's newer small font,
// white and gray), centered.
class RECreditsMenu : OptionMenu
{
	static const String lines[] = {
		"Made by ThoughtGnu with Claude Code",
		"Inspired by drelvak's RE1 x Doom mod",
		"RE1 decomp by ecruells (GPL-3.0)",
		"Built with GZDoom",
		"Resident Evil © Capcom, DOOM II © id Software",
		"Fan-made and not affiliated" };

	// right-click goes back, like the other screens
	override bool OnUIEvent(UIEvent ev)
	{
		if (ev.Type == UIEvent.Type_RButtonDown) { Close(); MenuSound("menu/backup"); return true; }
		return Super.OnUIEvent(ev);
	}

	override void Drawer()
	{
		int h = Screen.GetHeight();
		Screen.Dim(Color(255, 0, 0, 0), 0.78, 0, 0, Screen.GetWidth(), h);
		RECredits.Line(BigFont, Font.CR_RED, "CREDITS", h * 0.08, 0.05);
		for (int i = 0; i < lines.Size(); i++)
			RECredits.Line(NewSmallFont, i < 4 ? Font.CR_WHITE : Font.CR_GRAY, lines[i], h * (0.24 + i * 0.1), 0.034);
	}
}

// Main menu > Extras > Cheats: GZDoom's option menu over a dark layer, so the title
// logo doesn't show through the red text (menudef.txt RECheatsMenu).
class RECheatsOptionMenu : OptionMenu
{
	override void Drawer()
	{
		Screen.Dim(Color(255, 0, 0, 0), 0.96, 0, 0, Screen.GetWidth(), Screen.GetHeight());
		Super.Drawer();
	}
}

// Settings and its Gameplay / Advanced pages (menudef.txt): over the title
// picture a dark layer hides the big logo, so the labels are easy to read. In
// a game they stay see-through, like GZDoom's own option pages.
class RETitleOptionMenu : OptionMenu
{
	override void Drawer()
	{
		if (RETitleHandler.OnTitle()) Screen.Dim(Color(255, 0, 0, 0), 0.85, 0, 0, Screen.GetWidth(), Screen.GetHeight());
		Super.Drawer();
	}
}

// Every yes/no question (quit, end the game, delete a save, "only at a
// typewriter"): GZDoom's box over a dark layer, so it reads well anywhere
// (mapinfo.txt MessageBoxClass).
class REMessageBox : MessageBoxMenu
{
	override void Drawer()
	{
		Screen.Dim(Color(255, 0, 0, 0), 0.85, 0, 0, Screen.GetWidth(), Screen.GetHeight());
		Super.Drawer();
	}
}

class RECredits ui
{
	// One centered line: font height = size x screen height, but at most 90%
	// of the screen wide.
	static void Line(Font f, int color, String text, double y, double size)
	{
		double w = Screen.GetWidth(), h = Screen.GetHeight();
		double s = min(h * size / f.GetHeight(), w * 0.9 / max(1, f.StringWidth(text)));
		Screen.DrawText(f, color, (w - f.StringWidth(text) * s) / 2, y, text, DTA_ScaleX, s, DTA_ScaleY, s);
	}}

// The in-game main menu (with the small logo). If it is ever opened while the
// title picture is up (for example after Main Menu ends a game), it swaps
// itself for the title screen's copy without the logo.
class REMainMenu : ListMenu
{
	override void Ticker()
	{
		if (RETitleHandler.OnTitle())
		{
			Close();
			Menu.SetMenu('REMainMenuTitle');
			return;
		}
		Super.Ticker();
	}

	override void Drawer()
	{
		if (!RETitleHandler.OnTitle()) Super.Drawer();
	}
}

// Main menu > Extras (menudef.txt REExtrasMenu): a list like the in-game main
// menu. Over the title picture a dark layer hides the big logo, so the items
// (the same size and place as in game) are easy to read. Right-click goes back
// too, like the Records and Manual screens.
class REExtrasMenu : ListMenu
{
	override void Drawer()
	{
		if (!RETitleHandler.OnTitle()) { Super.Drawer(); return; }
		// Over the title picture: the dark layer, and no small logo (the
		// picture behind already has the big one). The logo is only hidden
		// while drawing, so the in-game Extras keeps it.
		Screen.Dim(Color(255, 0, 0, 0), 0.85, 0, 0, Screen.GetWidth(), Screen.GetHeight());
		Array<ListMenuItem> hidden;
		for (int i = 0; i < mDesc.mItems.Size(); i++)
		{
			let item = mDesc.mItems[i];
			if (item is "ListMenuItemStaticPatch" && item.mEnabled) { item.mEnabled = false; hidden.Push(item); }
		}
		Super.Drawer();
		for (int i = 0; i < hidden.Size(); i++) hidden[i].mEnabled = true;
	}

	override bool OnUIEvent(UIEvent ev)
	{
		if (ev.Type == UIEvent.Type_RButtonDown) { Close(); MenuSound("menu/backup"); return true; }
		return Super.OnUIEvent(ev);
	}
}

// Extras > Back: closes the Extras list, back to the menu it was opened from.
class ListMenuItemREBackItem : ListMenuItemTextItem
{
	override bool Activate()
	{
		let m = Menu.GetCurrentMenu();
		if (m != null) m.Close();
		return true;
	}
}
