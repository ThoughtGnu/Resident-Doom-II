// ---------------------------------------------------------------------------
// RE_InvClassic.zs - the "RE1 Classic" inventory style (Settings > Gameplay >
// Inventory style, re_invstyle 1): RE1's own status screen and item box
// screen, drawn with RE1's own pictures. Only the look: the menus
// (REInventoryMenu, REItemBoxMenu) keep every rule and just ask this file to
// draw and where things are for the mouse.
//
// The pictures come from the player's RE1 files, made by
// "re1convert statusart <RE1 USA> mod" (graphics/re1status, re1status.txt).
// Everything is placed on RE1's 320x240 screen, as RE1's MainMenu.cpp places
// it (reference/re1-decomp):
//   - the frame STFRAMEJ / STFRAMEC (menu_draw_inventory, built by the converter)
//   - the tabs MAP / FILE / RADIO / EXIT at (208,16) (256,16) (208,32) (256,32),
//     48x16 from STATUS.TIM (0, 0 / 32 / 16 / 48); RADIO blank (no radio here)
//   - the slots at g_inventorySlotsPos: Jill's 8 from (220,56), Chris's 6 from
//     (220,86), 40 apart across and 30 down; the blinking cursor frame 40x30
//     from (128 or 168, 224); the tab cursor 48x16 from (0, 80)
//   - the portrait at (22,146) (Statface.tim, Chris (0,0), Jill (32,0))
//   - the equipped weapon at (160,146)
//   - counts in RE1's digits (8x8 at u 128 green / 136 orange / 192 red)
//   - the command buttons at (144, 57 + 24n), 48x24 from (48, 0 EQUIP / 24 USE
//     / 48 CHECK / 72 COMBN), the chosen one framed by (48, 96)
//   - the ECG (menu_draw_health_bar): RE1's 20 wave shapes, its colours, the
//     sweeping line and its fading trail between x 84 and 131 around y 162,
//     and the condition word at (100,168) from STATUS.TIM (96, v)
// ---------------------------------------------------------------------------

class RE1Classic ui
{
	static bool On() { return re_invstyle == 1; }

	// --- RE1's 320x240 screen, fitted to the window (4:3, centred) -------------
	static double S() { return min(Screen.GetWidth() / 320.0, Screen.GetHeight() / 240.0); }
	static double OX() { return (Screen.GetWidth() - 320 * S()) / 2; }
	static double OY() { return (Screen.GetHeight() - 240 * S()) / 2; }
	static Vector2 ToLayout(int x, int y) { return ((x - OX()) / S(), (y - OY()) / S()); }
	static bool Inside(Vector2 p, double x, double y, double w, double h) { return p.x >= x && p.x < x + w && p.y >= y && p.y < y + h; }

	// A picture, or part of one (source rectangle sx, sy, w, h), at (x, y).
	static void Pic(String name, double x, double y, int sx = 0, int sy = 0, int w = 0, int h = 0, double alpha = 1.0, double dw = 0, double dh = 0)
	{
		TextureID t = TexMan.CheckForTexture(name, TexMan.Type_Any);
		if (!t.IsValid()) return;
		if (w <= 0) { int tw, th; [tw, th] = TexMan.GetSize(t); w = tw; h = th; }
		if (dw <= 0) { dw = w; dh = h; }
		double s = S();
		Screen.DrawTexture(t, false, OX() + x * s, OY() + y * s, DTA_SrcX, sx, DTA_SrcY, sy, DTA_SrcWidth, w, DTA_SrcHeight, h,
			DTA_DestWidthF, dw * s, DTA_DestHeightF, dh * s, DTA_Alpha, alpha, DTA_TopOffset, 0, DTA_LeftOffset, 0);
	}

	static void Fill(double x, double y, double w, double h, Color c, double alpha = 1.0)
	{
		double s = S();
		Screen.Dim(c, alpha, int(OX() + x * s), int(OY() + y * s), int(ceil(w * s)), int(ceil(h * s)));
	}

	// RE1's 8x8 font (fontus.tim: 32 characters a row from ' ').
	static void Text(double x, double y, String str, double alpha = 1.0)
	{
		for (int i = 0; i < str.Length(); i++)
		{
			int c = str.ByteAt(i);
			if (c < 32 || c > 127) c = 63;
			if (c != 32) Pic("REFONT", x + i * 8, y, ((c - 32) % 32) * 8, ((c - 32) / 32) * 8, 8, 8, alpha);
		}
	}
	static double TextWidth(String str) { return str.Length() * 8; }

	// Text wrapped to 'cols' characters a line; returns the lines used.
	static int Wrapped(double x, double y, String str, int cols, int maxLines = 3)
	{
		Array<String> words;
		str.Split(words, " ");
		String line = "";
		int n = 0;
		for (int i = 0; i <= words.Size() && n < maxLines; i++)
		{
			bool flush = i == words.Size();
			if (!flush && (line.Length() == 0 || line.Length() + 1 + words[i].Length() <= cols)) { line = line.Length() == 0 ? words[i] : line .. " " .. words[i]; continue; }
			Text(x, y + n * 10, line);
			n++;
			line = flush ? "" : words[i];
		}
		return n;
	}

	// --- item pictures (re1status.txt: RE1's item picture table) ----------------
	static int IconRow(int id)
	{
		let me = REClassicData.Get();
		return me != null && id > 0 && id < me.iconRow.Size() ? me.iconRow[id] : -1;
	}

	static void Icon(int id, double x, double y, double scale = 1)
	{
		int row = IconRow(id);
		if (row >= 0) Pic("REITEMS", x, y, 0, row * 30, 40, 30, 1.0, 40 * scale, 30 * scale);
	}

	// RE1's quantity digits under an item (display_item_qty).
	static void Count(int id, int qty, double x, double y)
	{
		if (!REItemInfo.ShowsQuantity(id)) return;
		int u = 128;   // green
		if (id == RE_ITEM_BAZOOKA_ACID || id == RE_ITEM_ACID_ROUNDS) u = 136;        // orange
		else if (id == RE_ITEM_BAZOOKA_FLAME || id == RE_ITEM_FLAME_ROUNDS) u = 192;  // red
		String s = String.Format("%d", clamp(qty, 0, 999));
		double dx = x + (id < RE_ITEM_CLIP ? 4 : 14) + (3 - s.Length()) * 8 * (id > RE_ITEM_ROCKET_LAUNCHER ? 1 : 0);
		for (int i = 0; i < s.Length(); i++)
			Pic("RESTATUS", dx + i * 8, y + 20, u, (s.ByteAt(i) - 48) * 8, 8, 8);
	}

	// --- the status screen's places ----------------------------------------------
	// g_inventorySlotsPos: 2 across (x 220 / 260), 30 down from y 56 (Jill) or 86 (Chris)
	static double SlotX(REInventory inv, int s) { return (s % 2) == 0 ? 220 : 260; }
	static double SlotY(REInventory inv, int s) { return 56 + (clamp(s, 0, 7) / 2) * 30 + (inv.numSlots <= 6 ? 30 : 0); }

	// tabs: 0 MAP, 1 FILE, 2 RADIO, 3 EXIT (RE1's order, g_MenuTabActions)
	static int TabX(int t) { return (t % 2) == 0 ? 208 : 256; }
	static int TabY(int t) { return t < 2 ? 16 : 32; }
	static int TabV(int t) { static const int v[] = { 0, 32, 16, 48 }; return v[clamp(t, 0, 3)]; }
	const EQUIP_X = 160;
	const EQUIP_Y = 146;
	const CMD_X = 144;
	const CMD_Y = 57;

	// The top of the command buttons: RE1's place for its three; with GIVE as a
	// fourth, one button higher, so all four stay inside the big window (above
	// the ECG and the equipped-weapon box).
	static int CmdY(int count) { return count > 3 ? CMD_Y - 28 : CMD_Y; }   // 29..125: inside the window's border (y 20..128)

	// Where a command's button is: in RESTATUS (u 48, v), or -1 for GIVE (REGIVE,
	// the converter's button made from RE1's own buttons).
	static int CommandV(String cmd)
	{
		if (cmd == "EQUIP") return 0;
		if (cmd == "USE") return 24;
		if (cmd == "CHECK") return 48;
		if (cmd == "COMBINE") return 72;
		return -1;   // GIVE TO ...
	}

	static void CommandButton(String cmd, double y, double alpha = 1.0)
	{
		int v = CommandV(cmd);
		if (v >= 0) Pic("RESTATUS", CMD_X, y, 48, v, 48, 24, alpha);
		else Pic("REGIVE", CMD_X, y, 0, 0, 48, 24, alpha);
	}

	// The status screen without its cursor or commands: frame, tabs (dimmed),
	// portrait, equipped weapon and the item slots (the item box screen sits on it).
	static void DrawBase(REInventory inv, Actor pmo, int eid, int eqty)
	{
		let who = RETankPlayer(pmo);
		bool chris = who != null && who.reChar == "chris";
		Pic(inv.numSlots <= 6 ? "STFRAMEC" : "STFRAMEJ", 0, 0);
		for (int t = 0; t < 4; t++) Pic("RESTATUS", TabX(t), TabY(t), 0, t == 2 ? 64 : TabV(t), 48, 16, 0.6);
		Pic("REFACE", 22, 146, chris ? 0 : 32, 0, 30, 30);
		if (eid != RE_ITEM_NONE && IconRow(eid) >= 0) { Icon(eid, EQUIP_X, EQUIP_Y); Count(eid, eqty, EQUIP_X, EQUIP_Y); }
		else Pic("REBLUE", EQUIP_X, EQUIP_Y, 0, 0, 40, 30);
		for (int s = 0; s < inv.numSlots; s++)
		{
			double x = SlotX(inv, s), y = SlotY(inv, s);
			int id = inv.slotId[s];
			if (id != RE_ITEM_NONE && IconRow(id) >= 0) { Icon(id, x, y); Count(id, inv.slotQty[s], x, y); }
			else
			{
				Pic("REBLUE", x, y, 0, 0, 40, 30);
				if (id != RE_ITEM_NONE) Text(x + 2, y + 11, REItemInfo.GetName(id).Left(4));
			}
		}
	}

	// RE1's blinking item cursor frame.
	static void Cursor(double x, double y, int time) { Pic("RESTATUS", x, y, (time & 16) != 0 ? 128 : 168, 224, 40, 30); }

	// The text line under the panels (one line centred, or up to 3 wrapped; a
	// two-line message, "first\nsecond", as two centred lines).
	static void BottomLine(String line)
	{
		if (line.IndexOf("\n") >= 0)
		{
			Array<String> two;
			line.Split(two, "\n");
			for (int i = 0; i < min(two.Size(), 2); i++) Text(160 - TextWidth(two[i].Left(40)) / 2, 185 + i * 10, two[i].Left(40));
		}
		else if (line.Length() <= 40) Text(160 - TextWidth(line) / 2, 190, line);
		else Wrapped(4, 186, line, 39, 3);
	}

	// --- the item box (draw_itembox_menu, its tables s_itemboxFramePartsA / C) ---
	// The box list in the big window: 3 names (the middle one is the chosen box
	// slot), the chosen item's picture in its frame below, the arrows. The
	// pictures are ITEMBOXn.TIM.
	const BOX_LIST_X = 41;
	const BOX_LIST_Y = 34;
	const BOX_ROW_H = 15;
	const BOX_PIC_X = 92;
	const BOX_PIC_Y = 88;

	static void DrawBox(REItemBox box, int boxCursor, bool active, int time)
	{
		Pic("REBOXART", 41, 34, 0, 1, 128, 46);     // the list's inside and sides
		Pic("REBOXART", 41, 33, 0, 0, 128, 1);      // its top line
		Pic("REBOXART", 41, 80, 0, 47, 128, 1);     // its bottom line
		for (int r = -1; r <= 1; r++)
		{
			int b = boxCursor + r;
			double y = BOX_LIST_Y + 1 + (r + 1) * BOX_ROW_H;
			if (b < 0 || b >= REItemBox.BOX_SLOTS) continue;
			int id = box.boxId[b];
			String name = id != RE_ITEM_NONE ? REItemInfo.GetName(id) : "- - - - -";
			Text(49, y + 3, name, r == 0 ? 1.0 : 0.45);
		}
		if (boxCursor > 0) Pic("REBOXART", 175, 24, 72, 56, 8, 7);
		if (boxCursor < REItemBox.BOX_SLOTS - 1) Pic("REBOXART", 175, 83, 72, 64, 8, 7);
		Pic("REBOXART", 91, 87, 16, 48, 42, 32);    // the picture's frame
		int id = box.boxId[boxCursor];
		if (id != RE_ITEM_NONE && IconRow(id) >= 0) { Icon(id, BOX_PIC_X - 1, BOX_PIC_Y - 1); Count(id, box.boxQty[boxCursor], BOX_PIC_X - 1, BOX_PIC_Y - 1); }
		if (active) Cursor(BOX_PIC_X - 1, BOX_PIC_Y - 1, time);
		Text(176, 46, String.Format("%02d", boxCursor + 1), 0.6);
	}

	static Color ConditionColor(int status)
	{
		// DAT_004b92c8
		switch (status)
		{
		case 0: return Color(255, 0xC0, 0x00, 0x00);
		case 1: return Color(255, 0xFF, 0x7F, 0x00);
		case 2: return Color(255, 0xD8, 0xD8, 0x00);
		}
		return Color(255, 0x00, 0xFF, 0x00);
	}
}

// RE1's item picture table and ECG waves, read once (play side, so the menus
// can reach it as clearscope data).
class REClassicData : StaticEventHandler
{
	Array<int> iconRow;
	bool loaded;

	static clearscope REClassicData Get() { return REClassicData(StaticEventHandler.Find("REClassicData")); }

	override void OnRegister()
	{
		iconRow.Clear();
		for (int i = 0; i < 0x50; i++) iconRow.Push(-1);
		int lump = Wads.CheckNumForFullName("re1status.txt");
		if (lump < 0) return;
		Array<String> lines;
		Wads.ReadLump(lump).Split(lines, "\n");
		for (int i = 0; i < lines.Size(); i++)
		{
			Array<String> t;
			lines[i].Split(t, " ", TOK_SKIPEMPTY);
			if (t.Size() >= 3 && t[0] == "icon")
			{
				int id = t[1].ToInt(), row = t[2].ToInt();
				if (id > 0 && id < iconRow.Size()) iconRow[id] = row;
			}
		}
		loaded = true;
	}
}

// The ECG on the status screen, as RE1's menu_draw_health_bar animates it.
class RE1Ecg ui
{
	// RE1's 20 wave shapes (MenuData.cpp ekg_wave_00..19, 5 conditions x 4):
	// records of {x from, x to, y at 'x from', slope}, x 0..47 left of the panel.
	static const int waves[] = {
		28,47,0,0, 27,28,-1,1, 26,27,-3,2, 25,26,0,-3, 24,25,2,-2, 23,24,1,1, 22,23,-1,2, 21,22,-4,3, 20,21,0,-4, 19,20,2,-2, 18,19,0,2, 0,18,0,0, 99,0,0,0,
		28,47,0,0, 27,28,-1,1, 26,27,-3,2, 24,26,1,-2, 23,24,0,1, 21,23,-4,2, 20,21,-1,-3, 19,20,1,2, 18,19,0,1, 0,18,0,0, 99,0,0,0,
		28,47,0,0, 27,28,-2,2, 25,27,2,-2, 24,25,1,1, 23,24,-1,2, 22,23,-4,3, 20,22,2,-3, 19,20,0,2, 0,19,0,0, 99,0,0,0,
		28,47,0,0, 27,28,-1,1, 26,27,-3,2, 24,26,1,-2, 23,24,-1,2, 22,23,-4,3, 21,22,-1,-3, 20,21,1,-2, 19,20,0,1, 0,19,0,0, 99,0,0,0,
		29,47,0,0, 28,29,-1,1, 27,28,-3,2, 26,27,0,-3, 25,26,2,-2, 24,25,1,1, 23,24,-1,2, 21,23,-7,3, 20,21,-3,-4, 19,20,0,-3, 18,19,2,-2, 17,18,0,2, 0,17,0,0, 99,0,0,0,
		28,47,0,0, 27,28,-1,1, 26,27,-3,2, 24,26,1,-2, 23,24,-1,2, 21,23,-7,3, 19,21,1,-4, 18,19,0,1, 0,18,0,0, 99,0,0,0,
		29,47,0,0, 27,29,-4,2, 25,27,2,-3, 24,25,1,1, 23,24,-1,2, 21,23,-7,3, 18,21,2,-3, 17,18,0,2, 0,17,0,0, 99,0,0,0,
		29,47,0,0, 28,29,-1,1, 27,28,-3,2, 25,27,1,-2, 24,25,-1,2, 22,24,-7,3, 20,22,-1,-3, 19,20,1,-2, 18,19,0,1, 0,18,0,0, 99,0,0,0,
		31,47,0,0, 29,31,-4,2, 28,29,-1,-3, 26,28,3,-2, 25,26,2,1, 21,25,-10,3, 20,21,-5,-5, 18,20,3,-3, 17,18,1,2, 16,17,0,1, 0,16,0,0, 99,0,0,0,
		31,47,0,0, 30,31,-2,2, 29,30,-5,3, 28,29,-2,-3, 26,28,2,-2, 23,26,-4,2, 21,23,-10,3, 17,21,2,-3, 16,17,0,2, 0,16,0,0, 99,0,0,0,
		31,47,0,0, 30,31,-1,1, 29,30,-2,2, 26,29,3,-2, 25,26,2,1, 24,25,0,2, 21,24,-9,3, 18,21,3,-4, 17,18,1,2, 16,17,0,1, 0,16,0,0, 99,0,0,0,
		31,47,0,0, 29,31,-2,2, 26,29,2,-2, 25,26,1,1, 24,25,-1,2, 21,24,-10,3, 17,21,2,-3, 16,17,0,2, 0,16,0,0, 99,0,0,0,
		32,47,0,0, 29,32,-6,2, 26,29,3,-3, 25,26,2,1, 21,25,-14,4, 19,21,-4,-5, 18,19,0,-4, 17,18,3,-3, 16,17,1,2, 15,16,0,1, 0,15,0,0, 99,0,0,0,
		32,47,0,0, 30,32,-6,3, 29,30,-4,-2, 26,29,2,-3, 24,26,-2,2, 21,24,-14,4, 17,21,2,-4, 16,17,0,2, 0,16,0,0, 99,0,0,0,
		31,47,0,0, 29,31,-4,2, 27,29,0,-2, 26,27,3,-3, 25,26,2,1, 24,25,-1,3, 21,24,-13,4, 19,21,-3,-5, 17,19,3,-3, 16,17,1,2, 15,16,0,1, 0,15,0,0, 99,0,0,0,
		32,47,0,0, 30,32,-4,2, 27,30,2,-2, 26,27,1,1, 21,26,-14,3, 17,21,2,-4, 16,17,0,2, 0,16,0,0, 99,0,0,0,
		38,47,0,0, 36,38,-6,3, 34,36,4,-5, 33,34,0,4, 30,33,-15,5, 27,30,3,-6, 26,27,1,2, 25,26,0,1, 22,25,0,0, 20,22,-4,2, 18,20,4,-4, 14,18,-12,4, 11,14,3,-5, 10,11,1,2, 9,10,0,1, 0,9,0,0, 99,0,0,0,
		38,47,0,0, 36,38,-4,2, 34,36,4,-4, 30,34,-12,4, 27,30,3,-5, 26,27,1,2, 25,26,0,1, 22,25,0,0, 20,22,-6,3, 18,20,4,-5, 17,18,0,4, 14,17,-15,5, 11,14,3,-6, 10,11,1,2, 9,10,0,1, 0,9,0,0, 99,0,0,0,
		37,47,0,0, 36,37,-1,1, 34,36,-7,3, 31,34,5,-4, 27,31,-15,5, 24,27,3,-6, 23,24,0,3, 21,23,0,0, 20,21,-2,2, 19,20,-5,3, 17,19,3,-4, 14,17,-12,5, 11,14,3,-5, 10,11,0,3, 0,10,0,0, 99,0,0,0,
		37,47,0,0, 36,37,-2,2, 35,36,-5,3, 33,35,3,-4, 30,33,-12,5, 27,30,3,-5, 26,27,0,3, 24,26,0,0, 23,24,-1,1, 21,23,-7,3, 18,21,5,-4, 14,18,-15,5, 11,14,3,-6, 10,11,0,3, 0,10,0,0, 99,0,0,0
	};
	int head, trail;          // DAT_00ae9f38 / DAT_00ae9f3c
	int status;               // 0 danger .. 3 fine, 4 poisoned
	int wave, trailWave, lastPick;
	Color col, trailCol;
	bool started;

	// One shape's height at x (0..47), or -1000 if the shape list ran out.
	int WaveY(int w, int x)
	{
		int i = 0;
		for (int k = 0; k < w; k++) { while (waves[i] != 99) i += 4; i += 4; }   // skip to shape w
		if (i >= waves.Size()) return 0;
		while (waves[i] != 99)
		{
			if (x >= waves[i] && x <= waves[i + 1]) return (x - waves[i]) * waves[i + 3] + waves[i + 2];
			i += 4;
		}
		return 0;
	}

	int Shapes()
	{
		int n = 0;
		for (int i = 0; i < waves.Size(); i += 4) if (waves[i] == 99) n++;
		return n;
	}

	void Tick(Actor pmo)
	{
		if (!started) { started = true; head = 0x84; trail = 0x84; }
		if (++head > 0x83)
		{
			head = 0x35;
			int mx = max(1, pmo.GetMaxHealth(true) >> 2);
			status = pmo.health <= 0 ? 0 : clamp((pmo.health - 1) / mx, 0, 3);
			bool poisoned = pmo.CountInv("REPoison") > 0;
			col = RE1Classic.ConditionColor(status);   // RE1: the health colour, poisoned or not
			int shapeStatus = status;
			if (poisoned && (Random[ecg]() & 1)) shapeStatus = 4;
			int pick = Random[ecg]() & 3;
			if ((lastPick & 3) == pick) pick = (pick + 1) & 3;
			lastPick = pick;
			wave = min(pick | (shapeStatus << 2), Shapes() - 1);
		}
		if (++trail > 0x83) { trail = head - 0x1f; trailWave = wave; trailCol = col; }
		if (pmo.CountInv("REPoison") > 0) status = 4;
	}

	void Draw()
	{
		// the trail: fading out over 32 pixels behind its head
		for (int x = max(trail, 0x54); x < min(trail + 0x1f, 0x83); x++)
		{
			double f = 1.0 - (trail + 0x1f - x) / 32.0;
			if (f > 0) Seg(trailWave, x, Color(255, int(trailCol.r * f), int(trailCol.g * f), int(trailCol.b * f)));
		}
		// the bright line
		for (int x = max(head, 0x54); x < min(head + 0x0f, 0x83); x++) Seg(wave, x, col);
		// the condition word (blinking for Caution / Danger / Poison, as RE1)
		int sweep = head - 0x35;
		int v = -1;
		static const int cautionAt[] = { 0x0C, 0x11, 0x14, 0x3C, 0x3F, 0x44, 0x50, 255 };
		static const int cautionV[] = { 0, 3, 2, 1, 2, 3, 0, 0 };
		static const int dangerAt[] = { 0x03, 0x07, 0x21, 0x25, 0x2B, 0x2F, 0x49, 0x4D, 0x50, 255 };
		static const int dangerV[] = { 0, 2, 1, 2, 0, 2, 1, 2, 0, 0 };
		int k = 0;
		switch (status)
		{
		case 2: case 3: v = 0; break;   // RE1: "Fine" over the green and the yellow line
		case 1: while (cautionAt[k] <= sweep) k++; v = cautionV[min(k, 7)] != 0 ? cautionV[min(k, 7)] * 8 + 0x18 : -1; break;
		case 0: while (dangerAt[k] <= sweep) k++; v = dangerV[min(k, 9)] != 0 ? dangerV[min(k, 9)] * 8 + 0x30 : -1; break;
		case 4: while (dangerAt[k] <= sweep) k++; v = dangerV[min(k, 9)] != 0 ? dangerV[min(k, 9)] * 8 + 0x40 : -1; break;
		}
		if (v >= 0) RE1Classic.Pic("RESTATUS", 100, 168, 96, v, 32, 8);
	}

	// one pixel column of the wave, joined to the next one
	void Seg(int w, int x, Color c)
	{
		int y0 = WaveY(w, x - 0x54) + 0xa2, y1 = WaveY(w, x + 1 - 0x54) + 0xa2;
		RE1Classic.Fill(x, min(y0, y1), 1, abs(y1 - y0) + 1, c);
	}
}
