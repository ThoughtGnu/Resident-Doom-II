// ---------------------------------------------------------------------------
// RE_CharSelect.zs - choose Jill, Chris or Both when you start a New Game.
//
// GZDoom asks for a "player class" when more than one is listed in
// mapinfo.txt (PlayerClasses). menudef.txt swaps its plain list for this
// RE1-style screen:
//   - the background is RE1's own character-select picture (SEL_BACK.PIX,
//     graphics/SELBACK.png)
//   - each character is drawn from their RE1 model (re1convert portrait,
//     graphics/SELJILL.png and SELCHRIS.png)
//   - Both is an animation from the models (re1convert bothanim,
//     graphics/SELBT00-24.png): selected, Jill and Chris turn back to back
//     and raise their guns, then hold the aim stance
//   - the selected character is bright, the others darkened
//
//   Left / Right or mouse over   choose
//   Enter / left-click   pick (Both then asks which one you control)
//   Esc                          back
// Last, the view to start in: Third person / First person, set to Settings >
// Gameplay > Starting view at first; picking one changes that setting.
// ---------------------------------------------------------------------------

class RECharSelectMenu : ListMenu
{
	int sel;          // 0 Jill, 1 Both, 2 Chris
	bool asking;      // Both chosen: asking which one you control
	int you;          // 0 Jill, 1 Chris (while asking)
	bool viewing;     // last step: Third person / First person (Settings > Gameplay > Starting view)
	int view;         // 0 third, 1 first (while viewing)
	int chosenClass;  // the player class picked before the view step
	int bothTics;     // how long Both has been selected (its animation)
	TextureID back;
	TextureID pics[2];          // Jill, Chris
	TextureID bothFrames[25];

	const BOTH_FRAMES = 25;
	const VW = 640;   // the screen's layout size, scaled to fit
	const VH = 480;

	static const String names[] = { "JILL VALENTINE", "BOTH", "CHRIS REDFIELD" };
	static const String notes[] = {
		"8 item slots. 96 health.",
		"Play one; the other follows you as an AI partner.",
		"6 item slots. 140 health. Turns faster while aiming."
	};
	// where each character stands (center x) on the main choice and on "which one"
	static const double slotX[] = { 105, 320, 535 };
	static const double askX[] = { 220, 420 };

	override void Init(Menu parent, ListMenuDescriptor desc)
	{
		Super.Init(parent, desc);
		back = TexMan.CheckForTexture("SELBACK", TexMan.Type_Any);
		pics[0] = TexMan.CheckForTexture("SELJILL", TexMan.Type_Any);
		pics[1] = TexMan.CheckForTexture("SELCHRIS", TexMan.Type_Any);
		for (int i = 0; i < BOTH_FRAMES; i++)
			bothFrames[i] = TexMan.CheckForTexture(String.Format("SELBT%02d", i), TexMan.Type_Any);
	}

	override void Ticker()
	{
		Super.Ticker();
		if (sel == 1 && !asking) bothTics++;
		else bothTics = 0;
	}

	void Choose(int s)
	{
		if (s == sel) return;
		sel = s;
		MenuSound("menu/cursor");
	}

	override bool MenuEvent(int mkey, bool fromcontroller)
	{
		if (viewing)
		{
			if (mkey == MKEY_Left || mkey == MKEY_Right || mkey == MKEY_Up || mkey == MKEY_Down)
			{
				view = 1 - view;
				MenuSound("menu/cursor");
				return true;
			}
			if (mkey == MKEY_Back)
			{
				viewing = false;   // back to the character (or "which one")
				MenuSound("menu/backup");
				return true;
			}
			if (mkey == MKEY_Enter)
			{
				MenuSound("menu/choose");
				// it sets Settings > Gameplay > Starting view, used at every start
				let sv = CVar.FindCVar('re_start_view');
				if (sv != null) sv.SetInt(view);
				viewing = false;
				asking = false;
				// The class number goes into GZDoom's normal New Game flow.
				Menu.SetMenu('EpisodeMenu', chosenClass);
				return true;
			}
			return true;
		}
		if (mkey == MKEY_Left || mkey == MKEY_Right)
		{
			int d = mkey == MKEY_Left ? -1 : 1;
			if (asking) you = clamp(you + d, 0, 1);
			else
			{
				sel = clamp(sel + d, 0, 2);
				// Settings > Gameplay > AI partner off: "Both" is skipped
				if (sel == 1 && !re_ai_partner) sel = d > 0 ? 2 : 0;
			}
			MenuSound("menu/cursor");
			return true;
		}
		if (mkey == MKEY_Back && asking)
		{
			asking = false;
			MenuSound("menu/backup");
			return true;
		}
		if (mkey == MKEY_Enter)
		{
			MenuSound("menu/choose");
			if (sel == 1 && !asking) { asking = true; you = 0; return true; }
			// The partner (RE_Partner.zs): 0 none, 1 Jill, 2 Chris.
			int cls = sel == 1 ? you : sel / 2;           // player class 0 Jill, 1 Chris
			let pv = CVar.FindCVar('re_partner');
			if (pv != null) pv.SetInt(sel == 1 ? (cls == 0 ? 2 : 1) : 0);
			// then the view to start in, defaulting to Settings > Gameplay > Starting view
			chosenClass = cls;
			view = clamp(re_start_view, 0, 1);
			viewing = true;
			return true;
		}
		return Super.MenuEvent(mkey, fromcontroller);
	}

	// --- the mouse ------------------------------------------------------------

	// Screen pixels -> a layout of vw x vh (the same fit the drawing uses:
	// DTA_FullscreenScale FSMode_ScaleToFit43, as GZDoom's own menus do).
	static ui Vector2 ToLayout(int x, int y, double vw, double vh)
	{
		double fx, fy, fw, fh;
		[fx, fy, fw, fh] = Screen.GetFullscreenRect(vw, vh, FSMode_ScaleToFit43);
		return ((x - fx) * vw / fw, (y - fy) * vh / fh);
	}

	// Which character is under the mouse (-1 none). The pictures and their names.
	int HitTest(Vector2 p)
	{
		if (p.y < 70 || p.y > 400) return -1;
		if (asking)
		{
			for (int i = 0; i < 2; i++) if (abs(p.x - askX[i]) < 86) return i;
			return -1;
		}
		if (abs(p.x - slotX[0]) < 86) return 0;
		if (abs(p.x - slotX[2]) < 86) return 2;
		if (re_ai_partner && abs(p.x - slotX[1]) < 110) return 1;
		return -1;
	}

	override bool MouseEvent(int type, int x, int y)
	{
		if (viewing)
		{
			// the two choices, left and right
			Vector2 p = ToLayout(x, y, VW, VH);
			if (p.y < 150 || p.y > 330) return true;
			int v = -1;
			for (int i = 0; i < 2; i++) if (abs(p.x - askX[i]) < 95) v = i;
			if (v < 0) return true;
			if (v != view) { view = v; MenuSound("menu/cursor"); }
			if (type == MOUSE_Release) MenuEvent(MKEY_Enter, false);
			return true;
		}
		int hit = HitTest(ToLayout(x, y, VW, VH));
		if (hit < 0) return true;
		if (asking)
		{
			if (hit != you) { you = hit; MenuSound("menu/cursor"); }
		}
		else Choose(hit);
		if (type == MOUSE_Release) MenuEvent(MKEY_Enter, false);
		return true;
	}

	// --- drawing --------------------------------------------------------------

	void Pic(TextureID tex, double x, double y, double w, double h, Color dim)
	{
		Screen.DrawTexture(tex, false, x, y,
			DTA_VirtualWidth, VW, DTA_VirtualHeight, VH, DTA_FullscreenScale, FSMode_ScaleToFit43,
			DTA_DestWidthF, w, DTA_DestHeightF, h, DTA_ColorOverlay, dim);
	}

	void Words(Font f, int color, double y, String text, double cx = 320)
	{
		Screen.DrawText(f, color, cx - f.StringWidth(text) / 2, y, text,
			DTA_VirtualWidth, VW, DTA_VirtualHeight, VH, DTA_FullscreenScale, FSMode_ScaleToFit43);
	}

	static Color Shade(bool on) { return on ? Color(0, 0, 0, 0) : Color(170, 0, 0, 0); }

	override void Drawer()
	{
		Screen.Dim(Color(255, 0, 0, 0), 1.0, 0, 0, Screen.GetWidth(), Screen.GetHeight());
		Pic(back, 0, 0, VW, VH, Color(120, 0, 0, 0));

		if (viewing)
		{
			Words(BigFont, Font.CR_RED, 14, "STARTING VIEW");
			// the character you picked, dim behind the two choices
			Pic(pics[chosenClass], 320 - 86, 70, 172, 300, Color(200, 0, 0, 0));
			static const String viewNames[] = { "THIRD PERSON", "FIRST PERSON" };
			for (int i = 0; i < 2; i++)
			{
				bool on = i == view;
				Words(on ? BigFont : SmallFont, on ? Font.CR_GOLD : Font.CR_DARKGRAY, 230, viewNames[i], askX[i]);
			}
			Words(SmallFont, Font.CR_WHITE, 300, view == 0 ? "RE1's fixed cameras and tank controls." : "Doom's own view: the mouse looks around.");
			Words(SmallFont, Font.CR_GRAY, 330, "Every start uses it (Settings > Gameplay > Starting view).");
			Words(SmallFont, Font.CR_GRAY, 348, "V switches views any time.");
			Words(SmallFont, Font.CR_DARKGRAY, 462, "LEFT / RIGHT or MOUSE choose    ENTER or CLICK start    ESC back");
			return;
		}

		if (asking)
		{
			Words(BigFont, Font.CR_RED, 14, "WHICH ONE DO YOU CONTROL?");
			for (int i = 0; i < 2; i++)
			{
				bool on = i == you;
				Pic(pics[i], askX[i] - 86, 70, 172, 300, Shade(on));
				Words(on ? BigFont : SmallFont, on ? Font.CR_GOLD : Font.CR_DARKGRAY, 384, i == 0 ? "JILL" : "CHRIS", askX[i]);
			}
			Words(SmallFont, Font.CR_WHITE, 420, you == 0 ? "You play Jill. Chris follows you with his shotgun." : "You play Chris. Jill follows you with her Beretta.");
			Words(SmallFont, Font.CR_DARKGRAY, 462, "LEFT / RIGHT or MOUSE choose    ENTER or CLICK start    ESC back");
			return;
		}

		Words(BigFont, Font.CR_RED, 14, "SELECT CHARACTER");
		// Both behind the other two (its picture is wide), then Jill and Chris
		int f = sel == 1 ? min(bothTics * 30 / 35, BOTH_FRAMES - 1) : 0;
		Pic(bothFrames[f], slotX[1] - 160, 70, 320, 300, Shade(sel == 1));
		Pic(pics[0], slotX[0] - 86, 70, 172, 300, Shade(sel == 0));
		Pic(pics[1], slotX[2] - 86, 70, 172, 300, Shade(sel == 2));
		for (int i = 0; i < 3; i++)
		{
			bool on = i == sel;
			String name = i == 1 && !re_ai_partner ? "AI PARTNER OFF" : names[i];
			Words(on ? BigFont : SmallFont, on ? Font.CR_GOLD : Font.CR_DARKGRAY, 384, name, slotX[i]);
		}
		Words(SmallFont, Font.CR_WHITE, 420, notes[sel]);
		Words(SmallFont, Font.CR_DARKGRAY, 462, "LEFT / RIGHT or MOUSE choose    ENTER or CLICK start    ESC back");
	}
}
