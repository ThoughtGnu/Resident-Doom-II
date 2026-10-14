// ---------------------------------------------------------------------------
// RE_Records.zs - your best results per map, kept on this PC only.
//
// A map counts as finished the moment you trigger its exit (an exit line or
// switch, normal or secret), or for MAP30 when the Icon of Sin's brain dies
// (Level Select's Final Boss has its own record, BOSS). Starting a map,
// loading a game, dying or quitting never count. Then:
//   time (game time, tics), kills %, secrets %, items %, saves made on the
//   map and Ink Ribbons used (since you entered it, this session), the
//   character you control, the difficulty and the date.
// One record per map, per character, per difficulty: the fastest clear, with
// that run's other numbers. A run where a cheat was on at any time (our four,
// the JILLSANDWICH / INKRIBBON codes, or GZDoom's god, buddha, noclip,
// notarget) isn't saved; loading a save made before the cheat counts as clean.
//
// Kept in user settings re_rec_<map> (cvarinfo.txt), which GZDoom writes to
// its settings file when you quit: "J2|tics|kills|secrets|items|saves|ribbons|date"
// entries, ';' between them (J/C = Jill/Chris, then the difficulty 0-4).
// The level-end screen says NEW RECORD or "Cheats used, record not saved"
// (REStatusScreen, RE_Input.zs); MAP30 and the Final Boss, which have none,
// say it on screen when the boss dies. Main menu > Extras > Records shows them all.
// ---------------------------------------------------------------------------

// The run on the map you're in. Saved with the game, so loading a save made
// before a cheat was used makes the run clean again.
class RERecordRun : EventHandler
{
	bool cheated;
	bool finished;

	override void WorldLoaded(WorldEvent e)
	{
		let st = RERecordStats.Get();
		if (st != null) st.EnterMap(level.MapName, e.IsSaveGame);
		if (e.IsSaveGame) return;
		cheated = false;
		finished = false;
	}

	override void WorldTick()
	{
		if (!cheated && CheatsOn()) cheated = true;
	}

	static bool CheatsOn()
	{
		if (re_cheat_ammo || re_cheat_god || re_cheat_jump || re_cheat_weapons || re_cheat_jillflame) return true;
		for (int i = 0; i < MAXPLAYERS; i++)
		{
			if (!playeringame[i]) continue;
			if (players[i].cheats & (CF_GODMODE | CF_GODMODE2 | CF_NOCLIP | CF_NOCLIP2 | CF_BUDDHA | CF_BUDDHA2 | CF_NOTARGET)) return true;
		}
		return false;
	}

	// A cheat code was typed (RE_Cheats.zs).
	static void MarkCheated()
	{
		let r = RERecordRun(EventHandler.Find("RERecordRun"));
		if (r != null) r.cheated = true;
	}

	override void WorldLineActivated(WorldEvent e)
	{
		let l = e.ActivatedLine;
		if (l == null) return;
		int s = l.special;
		if (s == Exit_Normal || s == Exit_Secret || s == Teleport_EndGame || s == Teleport_NewMap) Finish();
	}

	override void WorldThingDied(WorldEvent e)
	{
		if (e.Thing is "BossBrain") Finish();   // MAP30: the Icon of Sin
	}

	void Finish()
	{
		if (finished) return;
		finished = true;
		let pmo = players[consoleplayer].mo;
		let st = RERecordStats.Get();
		if (pmo == null || st == null) return;

		let fb = REFinalBossHandler(EventHandler.Find("REFinalBossHandler"));
		String key = fb != null && fb.bossRun ? "BOSS" : level.MapName.MakeUpper();
		String who = pmo is "REChrisPlayer" ? "C" : "J";
		int sk = clamp(CVar.FindCVar('skill').GetInt(), 0, 4);
		int kills = Pct(level.killed_monsters, level.total_monsters);
		int secrets = Pct(level.found_secrets, level.total_secrets);
		int items = Pct(level.found_items, level.total_items);
		int tics = level.maptime;
		bool boss = key == "BOSS" || key == "MAP30";

		if (cheated)
		{
			st.SetResult(key, RERecordStats.RESULT_CHEATED, boss);
			return;
		}
		String entry = String.Format("%s%d|%d|%d|%d|%d|%d|%d", who, sk, tics, kills, secrets, items, st.saves, st.ribbons);
		int best = RERecordStats.BestTics(key, who, sk);
		bool beat = best < 0 || tics < best;
		st.SetResult(key, beat ? RERecordStats.RESULT_NEW : RERecordStats.RESULT_SLOWER, boss, beat ? entry : "", who .. sk);
	}

	static int Pct(int got, int total) { return total > 0 ? clamp(got * 100 / total, 0, 100) : 100; }
}

// Across maps and loaded games (not saved with them): saves and ribbons used
// on the current map this session, and a finished run waiting to be written
// (the date only exists on the UI side).
class RERecordStats : StaticEventHandler
{
	enum EResult { RESULT_NONE, RESULT_NEW, RESULT_CHEATED, RESULT_SLOWER }

	String runMap;
	int saves, ribbons;

	int result;            // for the level-end screen
	String resultMap;
	int resultTic;         // gametic of the result (an old one isn't shown)
	String pendKey, pendEntry, pendWho;
	int pendSerial;
	ui int doneSerial;

	static clearscope RERecordStats Get() { return RERecordStats(StaticEventHandler.Find("RERecordStats")); }

	// A new map run starts the counts; a loaded game of the same map keeps them.
	void EnterMap(String map, bool fromSave)
	{
		if (fromSave && map == runMap) return;
		runMap = map;
		saves = 0;
		ribbons = 0;
	}

	override void NetworkProcess(ConsoleEvent e)
	{
		if (e.Name ~== "re_record_save") saves++;
		else if (e.Name ~== "re_ribbon_use") ribbons++;   // RE_Typewriter.zs
	}

	void SetResult(String key, int kind, bool boss, String entry = "", String who = "")
	{
		result = kind;
		resultMap = key;
		resultTic = gametic;
		if (kind == RESULT_NEW) { pendKey = key; pendEntry = entry; pendWho = who; pendSerial++; }
		// MAP30 and the Final Boss have no level-end screen: say it now
		if (boss && kind == RESULT_NEW) Console.MidPrint(null, "\cfNEW RECORD");
		else if (boss && kind == RESULT_CHEATED) Console.MidPrint(null, "Cheats used, record not saved");
	}

	// What the level-end screen should say ("" = nothing).
	clearscope String EndMessage()
	{
		if (gametic - resultTic > 35 * 60) return "";
		if (result == RESULT_NEW) return "NEW RECORD";
		if (result == RESULT_CHEATED) return "Cheats used, record not saved";
		return "";
	}

	// --- the stored records ----------------------------------------------------

	static clearscope String CVarName(String key) { return "re_rec_" .. key; }

	static clearscope String Stored(String key)
	{
		let cv = CVar.FindCVar(CVarName(key));
		return cv != null ? cv.GetString() : "";
	}

	// The record for this character and difficulty ("" = none).
	static clearscope String Find(String key, String who, int sk)
	{
		Array<String> entries;
		Stored(key).Split(entries, ";", TOK_SKIPEMPTY);
		String tag = String.Format("%s%d|", who, sk);
		for (int i = 0; i < entries.Size(); i++) if (entries[i].Left(tag.Length()) == tag) return entries[i];
		return "";
	}

	static clearscope int BestTics(String key, String who, int sk)
	{
		String e = Find(key, who, sk);
		if (e.Length() == 0) return -1;
		Array<String> f;
		e.Split(f, "|");
		return f.Size() > 1 ? f[1].ToInt() : -1;
	}

	// Write a finished record (with today's date).
	ui void Commit()
	{
		if (pendSerial == doneSerial) return;
		doneSerial = pendSerial;
		let cv = CVar.FindCVar(CVarName(pendKey));
		if (cv == null) return;
		Array<String> entries;
		cv.GetString().Split(entries, ";", TOK_SKIPEMPTY);
		String tag = pendWho .. "|";
		String keep = "";
		for (int i = 0; i < entries.Size(); i++) if (entries[i].Left(tag.Length()) != tag) keep = keep .. entries[i] .. ";";
		cv.SetString(keep .. pendEntry .. "|" .. SystemTime.Format("%Y-%m-%d", SystemTime.Now()));
		let last = CVar.FindCVar("re_rec_last");
		if (last != null) last.SetString(pendWho);
	}

	override void UiTick() { Commit(); }

	static ui void ClearAll()
	{
		for (int i = 0; i < RERecordsMenu.keys.Size(); i++)
		{
			let cv = CVar.FindCVar(CVarName(RERecordsMenu.keys[i]));
			if (cv != null) cv.SetString("");
		}
	}
}

// Main menu > Extras > Records: every Level Select entry with your best for one
// character and difficulty (Left / Right on the top two lines), in the
// inventory screen's RE1 style. Clear Records at the bottom asks first.
class RERecordsMenu : GenericMenu
{
	static const String keys[] = { "MAP01", "MAP02", "MAP03", "MAP04", "MAP05", "MAP06", "MAP07", "MAP08", "MAP09", "MAP10",
		"MAP11", "MAP12", "MAP13", "MAP14", "MAP15", "MAP16", "MAP17", "MAP18", "MAP19", "MAP20",
		"MAP21", "MAP22", "MAP23", "MAP24", "MAP25", "MAP26", "MAP27", "MAP28", "MAP29", "MAP30",
		"MAP31", "MAP32", "REMAP01", "BOSS" };
	static const String skills[] = { "I'm too young to die", "Hey, not too rough", "Hurt me plenty", "Ultra-Violence", "Nightmare!" };

	const ROWS = 14;
	enum ECursor { CUR_CHAR, CUR_SKILL, CUR_TABLE, CUR_CLEAR, CUR_BACK }
	int cursor;
	int top;          // first table row shown
	int who;          // 0 Jill, 1 Chris
	int sk;
	int hoverRow;   // table row under the mouse (-1 none; set in Init)
	bool asking;    // the Clear Records question is up
	bool askYes;    // ... and YES is picked
	const ASK_X = 170;
	const ASK_Y = 150;
	const ASK_W = 300;
	const ASK_H = 100;
	const YES_X = 205;
	const NO_X = 345;
	const ANSWER_Y = 215;
	const ANSWER_W = 90;

	// Layout on the 640x400 canvas (REDraw)
	const SEL_X = 140;              // "< value >" starts here
	const CHAR_Y = 51;
	const SKILL_Y = 67;
	const TABLE_Y = 92;
	const ROW_Y = 113;
	const ROW_H = 15;
	const BUTTON_Y = 330;           // TABLE_Y + 22 + ROWS * ROW_H + 6
	const CLEAR_X = 20;
	const CLEAR_W = 150;
	const BACK_X = 180;
	const BACK_W = 80;

	override void Init(Menu parent)
	{
		Super.Init(parent);
		let st = RERecordStats.Get();
		if (st != null) st.Commit();
		// start on the character and difficulty you last finished a map with
		String last = "";
		let cv = CVar.FindCVar("re_rec_last");
		if (cv != null) last = cv.GetString();
		if (last.Length() >= 2) { who = last.Left(1) == "C" ? 1 : 0; sk = clamp(last.Mid(1, 1).ToInt(), 0, 4); }
		else { who = 0; sk = clamp(CVar.FindCVar('skill').GetInt(), 0, 4); }
		cursor = CUR_TABLE;
		hoverRow = -1;
		MenuSound("menu/activate");
	}

	void ChangeChar() { who = 1 - who; MenuSound("menu/change"); }
	void ChangeSkill(int d) { sk = (sk + d + 5) % 5; MenuSound("menu/change"); }
	void Scroll(int d) { top = clamp(top + d, 0, keys.Size() - ROWS); }
	void AskClear() { asking = true; askYes = false; MenuSound("menu/activate"); }   // NO picked first, to be safe

	void Answer(bool yes)
	{
		asking = false;
		if (yes) { RERecordStats.ClearAll(); MenuSound("menu/choose"); }
		else MenuSound("menu/backup");
	}

	override bool MenuEvent(int mkey, bool fromcontroller)
	{
		if (asking)
		{
			if (mkey == MKEY_Left || mkey == MKEY_Right || mkey == MKEY_Up || mkey == MKEY_Down) { askYes = !askYes; MenuSound("menu/cursor"); }
			else if (mkey == MKEY_Enter) Answer(askYes);
			else if (mkey == MKEY_Back) Answer(false);
			return true;
		}
		switch (mkey)
		{
		case MKEY_Up:
			if (cursor == CUR_TABLE && top > 0) top--;
			else if (cursor == CUR_TABLE) cursor = CUR_SKILL;
			else if (cursor == CUR_CLEAR || cursor == CUR_BACK) cursor = CUR_TABLE;
			else if (cursor == CUR_SKILL) cursor = CUR_CHAR;
			MenuSound("menu/cursor");
			return true;
		case MKEY_Down:
			if (cursor == CUR_CHAR) cursor = CUR_SKILL;
			else if (cursor == CUR_SKILL) cursor = CUR_TABLE;
			else if (cursor == CUR_TABLE && top + ROWS < keys.Size()) top++;
			else if (cursor == CUR_TABLE) cursor = CUR_CLEAR;
			MenuSound("menu/cursor");
			return true;
		case MKEY_PageUp:   Scroll(-ROWS); return true;
		case MKEY_PageDown: Scroll(ROWS); return true;
		case MKEY_Left:
		case MKEY_Right:
		{
			int d = mkey == MKEY_Right ? 1 : -1;
			if (cursor == CUR_CHAR || cursor == CUR_TABLE) ChangeChar();
			else if (cursor == CUR_SKILL) ChangeSkill(d);
			else if (cursor == CUR_CLEAR || cursor == CUR_BACK) { cursor = cursor == CUR_CLEAR ? CUR_BACK : CUR_CLEAR; MenuSound("menu/cursor"); }
			return true;
		}
		case MKEY_Enter:
			if (cursor == CUR_CLEAR) AskClear();
			else if (cursor == CUR_BACK) { Close(); MenuSound("menu/backup"); }
			else if (cursor == CUR_CHAR) ChangeChar();
			else if (cursor == CUR_SKILL) ChangeSkill(1);
			return true;
		case MKEY_MBYes:
			RERecordStats.ClearAll();
			MenuSound("menu/choose");
			return true;
		}
		return Super.MenuEvent(mkey, fromcontroller);
	}

	override bool OnUIEvent(UIEvent ev)
	{
		if (asking && ev.Type == UIEvent.Type_KeyDown)
		{
			if (ev.KeyChar == 121 || ev.KeyChar == 89) { Answer(true); return true; }    // Y
			if (ev.KeyChar == 110 || ev.KeyChar == 78) { Answer(false); return true; }   // N
		}
		if (asking && ev.Type == UIEvent.Type_RButtonDown) { Answer(false); return true; }
		if (ev.Type == UIEvent.Type_WheelUp) { Scroll(-2); return true; }
		if (ev.Type == UIEvent.Type_WheelDown) { Scroll(2); return true; }
		if (ev.Type == UIEvent.Type_RButtonDown) { Close(); MenuSound("menu/backup"); return true; }   // right-click: back
		return Super.OnUIEvent(ev);
	}

	// --- the mouse ---------------------------------------------------------------

	// Screen pixels -> the 640x400 canvas REDraw draws on.
	static Vector2 ToCanvas(int x, int y)
	{
		double s = REDraw.Scale();
		return ((x - (Screen.GetWidth() - 640 * s) / 2) / s, (y - (Screen.GetHeight() - 400 * s) / 2) / s);
	}

	static bool Inside(Vector2 p, double x, double y, double w, double h) { return p.x >= x && p.x < x + w && p.y >= y && p.y < y + h; }

	// The "<" and ">" of a "< value >" line: -1, +1, or 0 for the value itself.
	static int ArrowAt(Vector2 p, String value)
	{
		double w = REDraw.TextWidth("< " .. value .. " >");
		double arrow = REDraw.TextWidth("< ");
		if (p.x < SEL_X + arrow) return -1;
		if (p.x > SEL_X + w - arrow) return 1;
		return 0;
	}

	override bool MouseEvent(int type, int x, int y)
	{
		Vector2 p = ToCanvas(x, y);
		if (asking)
		{
			int b = Inside(p, YES_X, ANSWER_Y, ANSWER_W, 22) ? 1 : (Inside(p, NO_X, ANSWER_Y, ANSWER_W, 22) ? 0 : -1);
			if (b < 0) return true;
			if ((b == 1) != askYes) { askYes = b == 1; MenuSound("menu/cursor"); }
			if (type == MOUSE_Release) Answer(askYes);
			return true;
		}
		String whoName = who == 1 ? "CHRIS" : "JILL";
		int over = -1;
		hoverRow = -1;
		if (Inside(p, 20, CHAR_Y - 3, 600, 15)) over = CUR_CHAR;
		else if (Inside(p, 20, SKILL_Y - 2, 600, 15)) over = CUR_SKILL;
		else if (Inside(p, 20, TABLE_Y, 600, 22 + ROWS * ROW_H))
		{
			over = CUR_TABLE;
			int r = int((p.y - ROW_Y) / ROW_H);
			if (p.y >= ROW_Y && r < ROWS && top + r < keys.Size()) hoverRow = r;
		}
		else if (Inside(p, CLEAR_X, BUTTON_Y, CLEAR_W, 20)) over = CUR_CLEAR;
		else if (Inside(p, BACK_X, BUTTON_Y, BACK_W, 20)) over = CUR_BACK;
		if (over < 0) return true;
		if (over != cursor) { cursor = over; if (type == MOUSE_Move) MenuSound("menu/cursor"); }
		if (type != MOUSE_Release) return true;
		switch (over)
		{
		case CUR_CHAR:  if (Inside(p, SEL_X - 4, CHAR_Y - 3, REDraw.TextWidth("< " .. whoName .. " >") + 8, 15)) ChangeChar(); break;
		case CUR_SKILL:
		{
			if (!Inside(p, SEL_X - 4, SKILL_Y - 2, REDraw.TextWidth("< " .. skills[sk] .. " >") + 8, 15)) break;
			int a = ArrowAt(p, skills[sk]);
			ChangeSkill(a == 0 ? 1 : a);
			break;
		}
		case CUR_CLEAR: AskClear(); break;
		case CUR_BACK:  Close(); MenuSound("menu/backup"); break;
		}
		return true;
	}

	// --- drawing -------------------------------------------------------------------

	static String TimeText(int tics)
	{
		int s = tics / 35;
		return s >= 3600 ? String.Format("%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60) : String.Format("%d:%02d", s / 60, s % 60);
	}

	static String MapName(String key)
	{
		if (key == "REMAP01") return "Mansion (no exit yet)";
		if (key == "BOSS") return "Final Boss";
		let info = LevelInfo.FindLevelInfo(key);
		String name = info != null ? info.LookupLevelName() : key;
		return name.Length() > 24 ? name.Left(23) .. "." : name;
	}

	void Button(double x, double w, String text, bool on)
	{
		Color gray = Color(255, 110, 110, 110), dark = Color(255, 20, 20, 24), sel = Color(255, 255, 220, 0);
		REDraw.Box(x, BUTTON_Y, w, 20, on ? Color(255, 60, 52, 10) : dark, 0.9);
		REDraw.Frame(x, BUTTON_Y, w, 20, on ? sel : gray);
		REDraw.Text(x + (w - REDraw.TextWidth(text)) / 2, BUTTON_Y + 5, text, on ? Font.CR_GOLD : Font.CR_WHITE);
	}

	override void Drawer()
	{
		Screen.Dim(Color(255, 0, 0, 0), 0.92, 0, 0, Screen.GetWidth(), Screen.GetHeight());
		Color gray = Color(255, 110, 110, 110), dark = Color(255, 20, 20, 24), sel = Color(255, 255, 220, 0);
		REDraw.Text(20, 12, "RECORDS", Font.CR_GOLD, 2.0);
		REDraw.Text(180, 20, "your best clear of each map, on this PC", Font.CR_DARKGRAY, 1.0);

		// character and difficulty (the line under the mouse or keys is gold)
		REDraw.Box(20, 46, 600, 40, dark, 0.9);
		REDraw.Frame(20, 46, 600, 40, gray);
		if (cursor == CUR_CHAR) REDraw.Box(22, CHAR_Y - 3, 596, 15, Color(255, 60, 52, 10), 0.9);
		if (cursor == CUR_SKILL) REDraw.Box(22, SKILL_Y - 2, 596, 15, Color(255, 60, 52, 10), 0.9);
		REDraw.Text(32, CHAR_Y, "CHARACTER", Font.CR_GRAY);
		REDraw.Text(SEL_X, CHAR_Y, String.Format("< %s >", who == 1 ? "CHRIS" : "JILL"), cursor == CUR_CHAR ? Font.CR_GOLD : Font.CR_WHITE);
		REDraw.Text(32, SKILL_Y, "DIFFICULTY", Font.CR_GRAY);
		REDraw.Text(SEL_X, SKILL_Y, String.Format("< %s >", skills[sk]), cursor == CUR_SKILL ? Font.CR_GOLD : Font.CR_WHITE);

		// the table
		static const int cx[] = { 26, 64, 262, 314, 364, 428, 480, 532 };
		static const String heads[] = { "MAP", "NAME", "TIME", "KILLS", "SECRETS", "ITEMS", "SAVES", "DATE" };
		REDraw.Box(20, TABLE_Y, 600, 22 + ROWS * ROW_H, dark, 0.9);
		REDraw.Frame(20, TABLE_Y, 600, 22 + ROWS * ROW_H, cursor == CUR_TABLE ? sel : gray);
		for (int c = 0; c < heads.Size(); c++) REDraw.Text(cx[c], TABLE_Y + 5, heads[c], Font.CR_GOLD, 0.85);
		String whoTag = who == 1 ? "C" : "J";
		for (int r = 0; r < ROWS && top + r < keys.Size(); r++)
		{
			String key = keys[top + r];
			double y = ROW_Y + r * ROW_H;
			if (r == hoverRow && cursor == CUR_TABLE) REDraw.Box(22, y - 2, 596, ROW_H, Color(255, 60, 52, 10), 0.9);   // the row under the mouse
			String e = RERecordStats.Find(key, whoTag, sk);
			REDraw.Text(cx[0], y, key == "REMAP01" ? "RE" : (key == "BOSS" ? "BOSS" : key.Mid(3)), Font.CR_GRAY, 0.85);
			REDraw.Text(cx[1], y, MapName(key), e.Length() > 0 ? Font.CR_WHITE : Font.CR_DARKGRAY, 0.85);
			if (e.Length() == 0)
			{
				for (int c = 2; c < 8; c++) REDraw.Text(cx[c], y, "---", Font.CR_DARKGRAY, 0.85);
				continue;
			}
			Array<String> f;
			e.Split(f, "|");
			if (f.Size() < 8) continue;
			REDraw.Text(cx[2], y, TimeText(f[1].ToInt()), Font.CR_GREEN, 0.85);
			REDraw.Text(cx[3], y, f[2] .. "%", Font.CR_WHITE, 0.85);
			REDraw.Text(cx[4], y, f[3] .. "%", Font.CR_WHITE, 0.85);
			REDraw.Text(cx[5], y, f[4] .. "%", Font.CR_WHITE, 0.85);
			int ribbons = f[6].ToInt();
			REDraw.Text(cx[6], y, ribbons > 0 ? String.Format("%s (%d)", f[5], ribbons) : f[5], Font.CR_WHITE, 0.85);
			REDraw.Text(cx[7], y, f.Size() > 7 ? f[7] : "", Font.CR_GRAY, 0.85);
		}
		// scroll marks
		if (top > 0) REDraw.Text(600, TABLE_Y + 5, "^", Font.CR_GOLD);
		if (top + ROWS < keys.Size()) REDraw.Text(600, TABLE_Y + 6 + ROWS * ROW_H, "v", Font.CR_GOLD);

		// buttons and notes
		Button(CLEAR_X, CLEAR_W, "CLEAR RECORDS", cursor == CUR_CLEAR);
		Button(BACK_X, BACK_W, "BACK", cursor == CUR_BACK);
		REDraw.Text(272, BUTTON_Y + 1, "SAVES: saves made on the map (Ink Ribbons used).", Font.CR_DARKGRAY, 0.85);
		REDraw.Text(272, BUTTON_Y + 11, "No record with cheats on. Kept when you quit.", Font.CR_DARKGRAY, 0.85);
		REDraw.Text(20, 362, "UP/DOWN move or scroll    LEFT/RIGHT change    ENTER select    ESC back", Font.CR_DARKGRAY);
		REDraw.Text(20, 376, "MOUSE: click < >, CLEAR RECORDS or BACK    WHEEL scrolls    RIGHT-CLICK back", Font.CR_DARKGRAY);

		// the Clear Records question, over the screen
		if (asking)
		{
			REDraw.Box(0, 0, 640, 400, Color(255, 0, 0, 0), 0.6);
			REDraw.Box(ASK_X, ASK_Y, ASK_W, ASK_H, Color(255, 30, 10, 10), 0.97);
			REDraw.Frame(ASK_X, ASK_Y, ASK_W, ASK_H, Color(255, 200, 40, 30));
			REDraw.CenteredText(ASK_Y + 14, "Clear all your records?", Font.CR_WHITE, 1.3);
			REDraw.CenteredText(ASK_Y + 36, "This can't be undone.", Font.CR_GRAY);
			AnswerButton(YES_X, "YES", askYes);
			AnswerButton(NO_X, "NO", !askYes);
		}
	}

	void AnswerButton(double x, String text, bool on)
	{
		REDraw.Box(x, ANSWER_Y, ANSWER_W, 22, on ? Color(255, 60, 52, 10) : Color(255, 20, 20, 24), 0.95);
		REDraw.Frame(x, ANSWER_Y, ANSWER_W, 22, on ? Color(255, 255, 220, 0) : Color(255, 110, 110, 110));
		REDraw.Text(x + (ANSWER_W - REDraw.TextWidth(text, 1.2)) / 2, ANSWER_Y + 5, text, on ? Font.CR_GOLD : Font.CR_WHITE, 1.2);
	}
}