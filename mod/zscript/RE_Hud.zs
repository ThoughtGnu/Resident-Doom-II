// ---------------------------------------------------------------------------
// RE_Hud.zs - what's drawn on top of the game.
//
// RE1 has no HUD during play: no health bar, no ammo counter. We only show
// short messages ("You picked up the CLIP.") and the death screen.
// ---------------------------------------------------------------------------

// Drawing helpers shared by the HUD and the inventory screen. Everything is
// laid out on a 640x400 canvas that is scaled to fit and centred on screen.
class REDraw ui
{
	static double Scale()
	{
		return min(Screen.GetWidth() / 640.0, Screen.GetHeight() / 400.0);
	}

	static Vector2 ToScreen(double x, double y)
	{
		double s = Scale();
		return ((Screen.GetWidth() - 640 * s) / 2 + x * s,
			(Screen.GetHeight() - 400 * s) / 2 + y * s);
	}

	static void Box(double x, double y, double w, double h, Color c, double alpha)
	{
		double s = Scale();
		Vector2 p = ToScreen(x, y);
		Screen.Dim(c, alpha, int(p.x), int(p.y), int(w * s), int(h * s));
	}

	static void Frame(double x, double y, double w, double h, Color c)
	{
		double s = Scale();
		Vector2 p = ToScreen(x, y);
		Screen.DrawLineFrame(c, int(p.x), int(p.y), int(w * s), int(h * s), max(1, int(s)));
	}

	static void Text(double x, double y, String text, int fontColor = Font.CR_WHITE, double size = 1.0)
	{
		double s = Scale() * size;
		Vector2 p = ToScreen(x, y);
		Screen.DrawText(NewSmallFont, fontColor, p.x, p.y, text, DTA_ScaleX, s, DTA_ScaleY, s);
	}

	static double TextWidth(String text, double size = 1.0)
	{
		return NewSmallFont.StringWidth(text) * size;
	}

	static void CenteredText(double y, String text, int fontColor = Font.CR_WHITE, double size = 1.0)
	{
		Text(320 - TextWidth(text, size) / 2, y, text, fontColor, size);
	}

	// RE1 status-screen condition (MainMenu.cpp):
	// status = (health - 1) / (max health / 4), capped at 3.
	static int ConditionLevel(int health, int maxHealth)
	{
		if (health <= 0) return 0;
		return min((health - 1) / max(1, maxHealth >> 2), 3);
	}

	static String ConditionName(int level)
	{
		static const String names[] = { "DANGER", "CAUTION", "CAUTION", "FINE" };
		return names[level];
	}

	static int ConditionFontColor(int level)
	{
		static const int colors[] = { Font.CR_RED, Font.CR_ORANGE, Font.CR_YELLOW, Font.CR_GREEN };
		return colors[level];
	}

	// Exact colours from RE1's table DAT_004b92c8.
	static Color ConditionColor(int level)
	{
		if (level == 0) return Color(255, 0xC0, 0x00, 0x00);
		if (level == 1) return Color(255, 0xFF, 0x7F, 0x00);
		if (level == 2) return Color(255, 0xD8, 0xD8, 0x00);
		return Color(255, 0x00, 0xFF, 0x00);
	}

	// Poisoned (RE_Poison.zs): RE1's purple.
	static Color PoisonColor()
	{
		return Color(255, 0xA0, 0x30, 0xE0);
	}
}

class REStatusBar : BaseStatusBar
{
	override void Init()
	{
		Super.Init();
		SetSize(0, 320, 200);
	}

	override void Draw(int state, double TicFrac)
	{
		Super.Draw(state, TicFrac);
		if (CPlayer == null || CPlayer.mo == null) return;

		if (CPlayer.mo.health <= 0)
		{
			REDraw.Box(0, 150, 640, 90, Color(255, 0, 0, 0), 0.6);
			REDraw.CenteredText(165, "YOU DIED", Font.CR_RED, 3.0);
			REDraw.CenteredText(210, REContinueHandler.DeathLine(), Font.CR_GRAY);
			return;
		}

		let inv = REInventory(CPlayer.mo.FindInventory("REInventory"));
		bool menuOpen = Menu.GetCurrentMenu() != null;
		if (!menuOpen) DrawPowerCues();
		if (!menuOpen && inv != null && inv.messageTics > 0 && inv.message.Length() > 0)
		{
			// one line, or two ("first\nsecond", e.g. giving the partner a gun)
			Array<String> lines;
			inv.message.Split(lines, "\n");
			double top = 340 - (lines.Size() - 1) * 24;
			REDraw.Box(40, top, 560, 34 + (lines.Size() - 1) * 24, Color(255, 0, 0, 0), 0.7);
			for (int i = 0; i < lines.Size(); i++) REDraw.CenteredText(top + 7 + i * 24, lines[i], Font.CR_WHITE, 1.5);
		}
	}

	// Power-ups that Doom shows with a screen tint only in first person, or not
	// at all: a small line each, top left, in both views, saying how long is
	// left; in the last 5 seconds it turns orange, blinks and warns.
	//   the Chemical (Doom's radiation suit)      CHEMICAL 0:57, green
	//   the Lighter (Doom's light amp visor)      LIGHTER 1:42, yellow
	const POWER_WARN = 35 * 5;
	void DrawPowerCues()
	{
		double y = 14;
		if (DrawPowerCue("PowerIronFeet", "CHEMICAL", "CHEMICAL WEARING OFF", Font.CR_GREEN, y)) y += 28;
		DrawPowerCue("PowerRELighter", "LIGHTER", "LIGHTER GOING OUT", Font.CR_YELLOW, y);
	}

	bool DrawPowerCue(class<Inventory> power, String name, String warning, int fontColor, double y)
	{
		let pw = Powerup(CPlayer.mo.FindInventory(power, true));
		if (pw == null || pw.EffectTics <= 0) return false;
		int secs = (pw.EffectTics + 34) / 35;
		bool ending = pw.EffectTics <= POWER_WARN;
		if (ending && (level.maptime / 8) % 2 == 1) return true;   // blink (keeps its place)
		String text = ending ? String.Format("%s  %d", warning, secs) : String.Format("%s  %d:%02d", name, secs / 60, secs % 60);
		REDraw.Box(16, y, REDraw.TextWidth(text, 1.3) + 16, 24, Color(255, 0, 0, 0), 0.6);
		REDraw.Text(24, y + 3, text, ending ? Font.CR_ORANGE : fontColor, 1.3);
		return true;
	}}
