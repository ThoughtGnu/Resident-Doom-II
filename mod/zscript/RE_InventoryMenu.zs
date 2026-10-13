// ---------------------------------------------------------------------------
// RE_InventoryMenu.zs - the RE1-style status screen (Tab or I).
//
//   Arrows        move between slots
//   Enter / click open the command list for the item: EQUIP or USE, CHECK,
//                 COMBINE, and for a gun with the AI partner around, GIVE TO
//                 JILL / CHRIS (grayed out when they're too far away)
//   Esc / Tab     back / close
//
// Like RE1, the game is paused while this screen is open.
// This file only draws and reads keys. Changes to the inventory are sent to
// REGameHandler (RE_Inventory.zs) as network events.
// ---------------------------------------------------------------------------

class REInventoryMenu : GenericMenu
{
	enum EMode
	{
		MODE_SLOTS,      // choosing a slot
		MODE_COMMANDS,   // choosing EQUIP/USE, CHECK or COMBINE
		MODE_COMBINE,    // choosing the second item to combine with
		MODE_CHECK,      // reading an item's description
	}

	int mode;
	int cursor;
	int cmdCursor;
	int combineFrom;
	Array<String> commands;

	int lastMessageId;
	int messageUntil;
	String shownMessage;

	override void Init(Menu parent)
	{
		Super.Init(parent);
		mode = MODE_SLOTS;
		cursor = 0;
		let inv = GetInv();
		lastMessageId = inv != null ? inv.messageId : 0;
		MenuSound("menu/activate");
	}

	REInventory GetInv()
	{
		let pmo = players[consoleplayer].mo;
		if (pmo == null) return null;
		return REInventory(pmo.FindInventory("REInventory"));
	}

	// --- keys -----------------------------------------------------------------

	override bool OnUIEvent(UIEvent ev)
	{
		if (ev.Type == UIEvent.Type_KeyDown)
		{
			if (ev.KeyChar == UIEvent.Key_Tab || ev.KeyChar == 105 || ev.KeyChar == 73) // Tab, i, I
			{
				Close();
				MenuSound("menu/clear");
				return true;
			}
		}
		if (ev.Type == UIEvent.Type_RButtonDown) return MenuEvent(MKEY_Back, false);   // right-click: back, like Esc
		return Super.OnUIEvent(ev);
	}

	// --- the mouse: hovering picks a slot or command, a click is Enter ---------

	override bool MouseEvent(int type, int x, int y)
	{
		let inv = GetInv();
		if (inv == null) return true;
		if (RE1Classic.On()) return ClassicMouse(inv, type, x, y);
		Vector2 p = RERecordsMenu.ToCanvas(x, y);
		if (mode == MODE_CHECK)
		{
			if (type == MOUSE_Release) MenuEvent(MKEY_Back, false);
			return true;
		}
		if (mode == MODE_COMMANDS)
		{
			double cx, cy, cw, ch;
			[cx, cy, cw, ch] = CommandBox();
			if (!RERecordsMenu.Inside(p, cx, cy, cw, ch))
			{
				if (type == MOUSE_Release) MenuEvent(MKEY_Back, false);   // a click outside the list closes it
				return true;
			}
			int i = clamp(int((p.y - cy - 4) / 18), 0, commands.Size() - 1);
			if (i != cmdCursor) { cmdCursor = i; MenuSound("menu/cursor"); }
			if (type == MOUSE_Release) RunCommand(inv, commands[cmdCursor]);
			return true;
		}
		// choosing a slot (or, from the item list, the EQUIPPED box)
		int over = -2;
		for (int s = 0; s < inv.numSlots; s++) if (RERecordsMenu.Inside(p, SlotX(s), SlotY(s), SLOT_W, SLOT_H)) over = s;
		if (over == -2 && mode == MODE_SLOTS && RERecordsMenu.Inside(p, 20, 192, 290, 58)) over = EQUIPPED_BOX;
		if (over == -2) return true;
		if (over != cursor) { cursor = over; MenuSound("menu/cursor"); }
		if (type == MOUSE_Release) MenuEvent(MKEY_Enter, false);
		return true;
	}

	override bool MenuEvent(int mkey, bool fromcontroller)
	{
		let inv = GetInv();
		if (inv == null) return Super.MenuEvent(mkey, fromcontroller);

		switch (mode)
		{
		case MODE_SLOTS:
		case MODE_COMBINE:
			if (mkey == MKEY_Up)    { MoveCursor(inv, -2); return true; }
			if (mkey == MKEY_Down)  { MoveCursor(inv, 2);  return true; }
			if (mkey == MKEY_Left)  { MoveCursor(inv, -1); return true; }
			if (mkey == MKEY_Right) { MoveCursor(inv, 1);  return true; }
			if (mkey == MKEY_Enter)
			{
				if (mode == MODE_SLOTS && cursor <= TAB_BASE)
				{
					RunTab(TAB_BASE - cursor);
				}
				else if (mode == MODE_SLOTS)
				{
					OpenCommands(inv);
				}
				else
				{
					if (cursor != combineFrom && inv.slotId[cursor] != RE_ITEM_NONE)
					{
						EventHandler.SendNetworkEvent("re_combine", combineFrom, cursor);
						MenuSound("menu/choose");
					}
					else
					{
						MenuSound("menu/invalid");
					}
					mode = MODE_SLOTS;
				}
				return true;
			}
			if (mkey == MKEY_Back && mode == MODE_COMBINE)
			{
				mode = MODE_SLOTS;
				cursor = combineFrom;
				MenuSound("menu/backup");
				return true;
			}
			break;

		case MODE_COMMANDS:
			if (mkey == MKEY_Up || mkey == MKEY_Left)
			{
				cmdCursor = (cmdCursor + commands.Size() - 1) % commands.Size();
				MenuSound("menu/cursor");
				return true;
			}
			if (mkey == MKEY_Down || mkey == MKEY_Right)
			{
				cmdCursor = (cmdCursor + 1) % commands.Size();
				MenuSound("menu/cursor");
				return true;
			}
			if (mkey == MKEY_Enter)
			{
				RunCommand(inv, commands[cmdCursor]);
				return true;
			}
			if (mkey == MKEY_Back)
			{
				mode = MODE_SLOTS;
				MenuSound("menu/backup");
				return true;
			}
			break;

		case MODE_CHECK:
			if (mkey == MKEY_Enter || mkey == MKEY_Back)
			{
				mode = MODE_SLOTS;
				MenuSound("menu/backup");
				return true;
			}
			return true;
		}
		return Super.MenuEvent(mkey, fromcontroller);
	}

	// cursor -1 is the EQUIPPED box (Left from the left column; Right goes back)
	void MoveCursor(REInventory inv, int delta)
	{
		// RE1 Classic: the MAP / FILE / RADIO / EXIT tabs above the slots
		if (RE1Classic.On() && mode == MODE_SLOTS)
		{
			if (cursor <= TAB_BASE)
			{
				int t = TAB_BASE - cursor, col = t % 2, row = t / 2;
				if (delta == -1 || delta == 1) col = 1 - col;
				else if (delta == -2) row = 0;
				else if (delta == 2 && row == 0) row = 1;
				else if (delta == 2) { cursor = min(col, inv.numSlots - 1); MenuSound("menu/cursor"); return; }
				cursor = TAB_BASE - (row * 2 + col);
				MenuSound("menu/cursor");
				return;
			}
			if (delta == -2 && cursor >= 0 && cursor < 2) { cursor = TAB_BASE - (2 + cursor); MenuSound("menu/cursor"); return; }
		}
		if (cursor == EQUIPPED_BOX)
		{
			if (delta == 1 && mode == MODE_SLOTS) { cursor = 0; MenuSound("menu/cursor"); }
			return;
		}
		if (delta == -1 && cursor % 2 == 0 && mode == MODE_SLOTS) { cursor = EQUIPPED_BOX; MenuSound("menu/cursor"); return; }
		int next = cursor + delta;
		if (next < 0 || next >= inv.numSlots) return;
		cursor = next;
		MenuSound("menu/cursor");
	}

	const EQUIPPED_BOX = -1;
	const TAB_BASE = -10;   // RE1 Classic: -10 MAP, -11 FILE, -12 RADIO, -13 EXIT

	// RE1 Classic's tabs: MAP is our map screen, FILE the Manual (the mod's
	// "files"), EXIT closes; there's no radio (RE1 shows its tab blank then).
	void RunTab(int t)
	{
		switch (t)
		{
		case 0: MenuSound("menu/choose"); Menu.SetMenu('REMapMenu'); return;
		case 1: MenuSound("menu/choose"); Menu.SetMenu('REManualMenu'); return;
		case 3: Close(); MenuSound("menu/clear"); return;
		}
		MenuSound("menu/invalid");
	}

	// The gun in hand from the All Weapons cheat (not from a slot), or null.
	REWeapon CheatWeapon(REInventory inv)
	{
		let held = REWeapon(players[consoleplayer].ReadyWeapon);
		if (!re_cheat_weapons || held == null) return null;
		if (inv.equippedSlot >= 0 && REItemInfo.WeaponClass(inv.slotId[inv.equippedSlot]) == held.GetClass()) return null;
		return held;
	}

	void OpenCommands(REInventory inv)
	{
		if (cursor == EQUIPPED_BOX)
		{
			// a cheat gun (not the knife) with the partner around: give them one
			let cw = CheatWeapon(inv);
			if (cw == null || !REItemInfo.IsGun(REItemInfo.IdForWeapon(cw.GetClass())) || !PartnerHere(inv)) { MenuSound("menu/invalid"); return; }
			commands.Clear();
			commands.Push("GIVE TO " .. inv.partnerName.MakeUpper());
			cmdCursor = 0;
			mode = MODE_COMMANDS;
			MenuSound("menu/choose");
			return;
		}
		int id = inv.slotId[cursor];
		if (id == RE_ITEM_NONE)
		{
			MenuSound("menu/invalid");
			return;
		}
		commands.Clear();
		commands.Push(REItemInfo.IsWeapon(id) ? "EQUIP" : "USE");
		commands.Push("CHECK");
		commands.Push("COMBINE");
		// A gun, with the AI partner in the level: hand it to them.
		// (not the flamethrower: only Chris can use it, as in RE1, and the partner is then Jill)
		if (REItemInfo.IsGun(id) && id != RE_ITEM_FLAMETHROWER && PartnerHere(inv)) commands.Push("GIVE TO " .. inv.partnerName.MakeUpper());
		// A blue herb or a mix with one, and the partner is poisoned: cure them.
		else if ((REItemInfo.HealFlags(id) & 0xF0) != 0 && PartnerHere(inv) && inv.partnerPoisoned) commands.Push("GIVE TO " .. inv.partnerName.MakeUpper());
		cmdCursor = 0;
		mode = MODE_COMMANDS;
		MenuSound("menu/choose");
	}

	bool PartnerHere(REInventory inv)
	{
		return inv.partnerName.Length() > 0 && level.maptime - inv.partnerSeenTic <= 2;
	}

	// Why GIVE TO can't be used right now ("" = it can).
	String GiveBlocked(REInventory inv)
	{
		if (!inv.partnerNear) return "Too far away.";
		if (cursor == EQUIPPED_BOX) return "";   // the cheat's gun: you keep it anyway
		if (cursor >= 0 && !REItemInfo.IsGun(inv.slotId[cursor])) return "";   // a herb for the poisoned partner
		int weapons = 0;
		for (int s = 0; s < inv.numSlots; s++) if (REItemInfo.IsWeapon(inv.slotId[s])) weapons++;
		if (weapons <= 1) return "You can't give away your last weapon.";
		return "";
	}

	void RunCommand(REInventory inv, String cmd)
	{
		if (cmd.Left(8) == "GIVE TO ")
		{
			String why = GiveBlocked(inv);
			if (why.Length() > 0)
			{
				shownMessage = why;
				messageUntil = MenuTime() + 35 * 2;
				MenuSound("menu/invalid");
				return;
			}
			if (cursor == EQUIPPED_BOX) EventHandler.SendNetworkEvent("re_givecheat");
			else EventHandler.SendNetworkEvent("re_give", cursor);
			mode = MODE_SLOTS;
			MenuSound("menu/choose");
			return;
		}
		if (cmd == "EQUIP" || cmd == "USE")
		{
			EventHandler.SendNetworkEvent("re_use", cursor);
			mode = MODE_SLOTS;
		}
		else if (cmd == "CHECK")
		{
			mode = MODE_CHECK;
		}
		else if (cmd == "COMBINE")
		{
			combineFrom = cursor;
			mode = MODE_COMBINE;
			cursor = (cursor + 1) % inv.numSlots;
		}
		MenuSound("menu/choose");
	}

	// --- drawing ----------------------------------------------------------------

	const SLOT_X = 330;
	const SLOT_Y = 70;
	const SLOT_W = 140;
	const SLOT_H = 46;
	const SLOT_GAP = 8;

	RE1Ecg ecg;

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
		let pmo = players[consoleplayer].mo;
		if (inv == null || pmo == null) return;

		// Pick up messages sent back by the game (e.g. "You used ...").
		if (inv.messageId != lastMessageId)
		{
			lastMessageId = inv.messageId;
			shownMessage = inv.message;
			messageUntil = MenuTime() + 35 * 3;
		}
		if (RE1Classic.On()) { DrawClassic(inv, pmo); return; }

		Color gray = Color(255, 110, 110, 110);
		Color dark = Color(255, 20, 20, 24);

		REDraw.Text(20, 18, "STATUS", Font.CR_GOLD, 2.0);

		// Condition (RE1's ECG panel, simplified to a coloured bar).
		int level = REDraw.ConditionLevel(pmo.health, pmo.GetMaxHealth(true));
		bool poisoned = pmo.CountInv("REPoison") > 0;   // RE1 shows POISON in purple instead
		REDraw.Box(20, 70, 290, 110, dark, 0.9);
		REDraw.Frame(20, 70, 290, 110, gray);
		let who = RETankPlayer(pmo);
		REDraw.Text(32, 80, who != null ? who.reChar.MakeUpper() : "JILL", Font.CR_GRAY, 1.2);
		REDraw.Text(32, 102, "CONDITION", Font.CR_GRAY);
		REDraw.Text(32, 118, poisoned ? "POISON" : REDraw.ConditionName(level), poisoned ? Font.CR_PURPLE : REDraw.ConditionFontColor(level), 2.2);
		int pulse = (MenuTime() / 3) % 20;
		REDraw.Box(32, 158, 266, 10, Color(255, 0, 0, 0), 1.0);
		REDraw.Box(32, 158, 266 * (level + 1) / 4, 10, poisoned ? REDraw.PoisonColor() : REDraw.ConditionColor(level), 0.5 + pulse * 0.02);

		// Equipped weapon.
		REDraw.Box(20, 192, 290, 58, dark, 0.9);
		REDraw.Frame(20, 192, 290, 58, cursor == EQUIPPED_BOX ? Color(255, 255, 220, 0) : gray);
		REDraw.Text(32, 200, "EQUIPPED", Font.CR_GRAY);
		// All Weapons cheat: the gun in hand may not be in any slot. Show it,
		// marked as the cheat's (it takes no slot), with the rounds it has left.
		let held = REWeapon(players[consoleplayer].ReadyWeapon);
		bool fromSlot = held != null && inv.equippedSlot >= 0 && REItemInfo.WeaponClass(inv.slotId[inv.equippedSlot]) == held.GetClass();
		if (re_cheat_weapons && held != null && !fromSlot)
		{
			String eq = held.GetTag().MakeUpper();
			if (REItemInfo.IsGun(REItemInfo.IdForWeapon(held.GetClass()))) eq = String.Format("%s   %d", eq, players[consoleplayer].mo.CountInv("RELoadedRounds"));
			REDraw.Text(32, 218, eq, Font.CR_WHITE, 1.5);
			REDraw.Text(112, 200, "(ALL WEAPONS CHEAT)", Font.CR_GOLD, 1.0);
		}
		else if (inv.equippedSlot >= 0)
		{
			int eid = inv.slotId[inv.equippedSlot];
			String eq = REItemInfo.GetName(eid);
			if (REItemInfo.ShowsQuantity(eid)) eq = String.Format("%s   %d", eq, inv.slotQty[inv.equippedSlot]);
			REDraw.Text(32, 218, eq, Font.CR_WHITE, 1.5);
		}
		else
		{
			REDraw.Text(32, 218, "NOTHING", Font.CR_DARKGRAY, 1.5);
		}

		// The item slots, 2 per row like RE1.
		REDraw.Text(SLOT_X, 50, mode == MODE_COMBINE ? "COMBINE WITH WHICH ITEM?" : "ITEMS", Font.CR_GRAY);
		for (int s = 0; s < inv.numSlots; s++)
		{
			double x = SlotX(s);
			double y = SlotY(s);
			int id = inv.slotId[s];
			REDraw.Box(x, y, SLOT_W, SLOT_H, dark, 0.9);

			Color frame = gray;
			if (mode == MODE_COMBINE && s == combineFrom) frame = Color(255, 0, 200, 0);
			if (s == cursor) frame = Color(255, 255, 220, 0);
			REDraw.Frame(x, y, SLOT_W, SLOT_H, frame);

			if (id != RE_ITEM_NONE)
			{
				REDraw.Text(x + 8, y + 8, REItemInfo.GetName(id), Font.CR_WHITE);
				if (REItemInfo.ShowsQuantity(id))
				{
					REDraw.Text(x + 8, y + 26, String.Format("%d", inv.slotQty[s]), Font.CR_GREEN, 1.3);
				}
				if (s == inv.equippedSlot)
				{
					REDraw.Text(x + SLOT_W - 18, y + 26, "E", Font.CR_GOLD, 1.3);
				}
			}
		}

		// Text box at the bottom: description, game message, or item name.
		REDraw.Box(20, 300, 600, 64, dark, 0.9);
		REDraw.Frame(20, 300, 600, 64, gray);
		int curId = cursor >= 0 ? inv.slotId[cursor] : RE_ITEM_NONE;
		if (mode == MODE_CHECK && curId != RE_ITEM_NONE)
		{
			REDraw.Text(32, 308, REItemInfo.GetName(curId), Font.CR_GOLD, 1.2);
			REDraw.Text(32, 330, REItemInfo.GetDescription(curId), Font.CR_WHITE, 1.2);
		}
		else if (MenuTime() < messageUntil && shownMessage.Length() > 0)
		{
			// one line, or two ("first\nsecond", e.g. giving the partner a gun)
			Array<String> lines;
			shownMessage.Split(lines, "\n");
			for (int i = 0; i < lines.Size(); i++) REDraw.Text(32, (lines.Size() > 1 ? 310 : 320) + i * 22, lines[i], Font.CR_WHITE, 1.4);
		}
		else if (mode == MODE_COMMANDS && commands[cmdCursor].Left(8) == "GIVE TO " && GiveBlocked(inv).Length() > 0)
		{
			REDraw.Text(32, 320, GiveBlocked(inv), Font.CR_DARKGRAY, 1.4);
		}
		else if (curId != RE_ITEM_NONE)
		{
			REDraw.Text(32, 320, REItemInfo.GetName(curId), Font.CR_WHITE, 1.4);
		}
		else if (cursor == EQUIPPED_BOX)
		{
			let cw = CheatWeapon(inv);
			REDraw.Text(32, 320, cw != null ? (PartnerHere(inv) ? "ENTER: give it to " .. inv.partnerName .. " (you keep it)" : cw.GetTag().MakeUpper() .. " (All Weapons cheat)") : "EQUIPPED", Font.CR_WHITE, 1.4);
		}

		REDraw.Text(20, 376, "ARROWS move    ENTER select    ESC back    TAB close    MOUSE click    RIGHT-CLICK back", Font.CR_DARKGRAY, 0.85);

		// Command list next to the chosen slot (drawn last so it's on top).
		if (mode == MODE_COMMANDS)
		{
			double cx, cy, cw, ch;
			[cx, cy, cw, ch] = CommandBox();
			REDraw.Box(cx, cy, cw, ch, Color(255, 0, 0, 0), 0.95);
			REDraw.Frame(cx, cy, cw, ch, Color(255, 255, 220, 0));
			bool giveOff = GiveBlocked(inv).Length() > 0;
			for (int i = 0; i < commands.Size(); i++)
			{
				int col = (i == cmdCursor) ? Font.CR_GOLD : Font.CR_GRAY;
				if (commands[i].Left(8) == "GIVE TO " && giveOff) col = Font.CR_DARKGRAY;   // too far away
				REDraw.Text(cx + 12, cy + 6 + i * 18, (i == cmdCursor ? "> " : "  ") .. commands[i], col, 1.2);
			}
		}
	}

	// Where the command list is drawn (x, y, width, height on the canvas).
	double, double, double, double CommandBox()
	{
		double cx = cursor >= 0 ? SlotX(cursor) + 40 : 60;
		double cy = cursor >= 0 ? SlotY(cursor) + SLOT_H - 4 : 246;
		double ch = 8 + commands.Size() * 18;
		double cw = commands.Size() > 3 ? 172 : 110;   // GIVE TO CHRIS is wider
		if (cx + cw > 620) cx = 620 - cw;
		return cx, cy, cw, ch;
	}

	double SlotX(int s) { return SLOT_X + (s % 2) * (SLOT_W + SLOT_GAP); }
	double SlotY(int s) { return SLOT_Y + (s / 2) * (SLOT_H + SLOT_GAP); }

	// --- RE1 Classic (RE_InvClassic.zs): the same screen in RE1's own look -------

	// The item in the equipped box: the slot's, or the All Weapons cheat's gun.
	int, int EquippedShown(REInventory inv)
	{
		let cw = CheatWeapon(inv);
		if (cw != null) return REItemInfo.IdForWeapon(cw.GetClass()), players[consoleplayer].mo.CountInv("RELoadedRounds");
		if (inv.equippedSlot >= 0) return inv.slotId[inv.equippedSlot], inv.slotQty[inv.equippedSlot];
		return RE_ITEM_NONE, 0;
	}

	void DrawClassic(REInventory inv, Actor pmo)
	{
		let who = RETankPlayer(pmo);
		bool chris = who != null && who.reChar == "chris";
		RE1Classic.Pic(inv.numSlots <= 6 ? "STFRAMEC" : "STFRAMEJ", 0, 0);

		// the tabs; RADIO is blank, as RE1 shows it without a radio
		for (int t = 0; t < 4; t++)
		{
			bool sel = cursor == TAB_BASE - t && mode == MODE_SLOTS;
			RE1Classic.Pic("RESTATUS", RE1Classic.TabX(t), RE1Classic.TabY(t), 0, t == 2 ? 64 : RE1Classic.TabV(t), 48, 16, sel ? 1.0 : 0.6);
		}
		// the portrait
		RE1Classic.Pic("REFACE", 22, 146, chris ? 0 : 32, 0, 30, 30);
		// the equipped weapon
		int eid, eqty;
		[eid, eqty] = EquippedShown(inv);
		if (eid != RE_ITEM_NONE && RE1Classic.IconRow(eid) >= 0)
		{
			RE1Classic.Icon(eid, RE1Classic.EQUIP_X, RE1Classic.EQUIP_Y);
			RE1Classic.Count(eid, eqty, RE1Classic.EQUIP_X, RE1Classic.EQUIP_Y);
		}
		else RE1Classic.Pic("REBLUE", RE1Classic.EQUIP_X, RE1Classic.EQUIP_Y, 0, 0, 40, 30);
		// the slots
		for (int s = 0; s < inv.numSlots; s++)
		{
			double x = RE1Classic.SlotX(inv, s), y = RE1Classic.SlotY(inv, s);
			int id = inv.slotId[s];
			if (id != RE_ITEM_NONE && RE1Classic.IconRow(id) >= 0)
			{
				RE1Classic.Icon(id, x, y);
				RE1Classic.Count(id, inv.slotQty[s], x, y);
			}
			else
			{
				RE1Classic.Pic("REBLUE", x, y, 0, 0, 40, 30);
				if (id != RE_ITEM_NONE) RE1Classic.Text(x + 2, y + 11, REItemInfo.GetName(id).Left(4));   // (no RE1 picture)
			}
		}
		// the cursor: RE1's blinking frame (and a steady one on the first item to combine)
		bool blink = (MenuTime() & 16) != 0;
		if (mode == MODE_COMBINE) RE1Classic.Pic("RESTATUS", RE1Classic.SlotX(inv, combineFrom), RE1Classic.SlotY(inv, combineFrom), 168, 224, 40, 30);
		if (cursor <= TAB_BASE) { int t = TAB_BASE - cursor; RE1Classic.Pic("RESTATUS", RE1Classic.TabX(t), RE1Classic.TabY(t), 0, 80, 48, 16, 0.4); }   // (RE1 blends it over the tab)
		else if (cursor == EQUIPPED_BOX) RE1Classic.Pic("RESTATUS", RE1Classic.EQUIP_X, RE1Classic.EQUIP_Y, blink ? 128 : 168, 224, 40, 30);
		else if (cursor >= 0) RE1Classic.Pic("RESTATUS", RE1Classic.SlotX(inv, cursor), RE1Classic.SlotY(inv, cursor), blink ? 128 : 168, 224, 40, 30);
		// the ECG
		if (ecg != null) ecg.Draw();

		// the big window: the item, larger, while you CHECK it
		int curId = cursor >= 0 ? inv.slotId[cursor] : RE_ITEM_NONE;
		if (mode == MODE_CHECK && curId != RE_ITEM_NONE) RE1Classic.Icon(curId, 52, 34, 3);

		// the command buttons (RE1's EQUIP / USE / CHECK / COMBN, and GIVE in the same style)
		if (mode == MODE_COMMANDS)
		{
			bool giveOff = GiveBlocked(inv).Length() > 0;
			double top = RE1Classic.CmdY(commands.Size());
			for (int i = 0; i < commands.Size(); i++)
				RE1Classic.CommandButton(commands[i], top + i * 24, commands[i].Left(8) == "GIVE TO " && giveOff ? 0.45 : 1.0);
			RE1Classic.Pic("RESTATUS", RE1Classic.CMD_X, top + cmdCursor * 24, 48, 96, 48, 24);
		}

		// the text line under the panels: the item's name, a message, its description
		String line = "";
		if (mode == MODE_CHECK && curId != RE_ITEM_NONE) line = REItemInfo.GetDescription(curId);
		else if (MenuTime() < messageUntil && shownMessage.Length() > 0) line = shownMessage;
		else if (mode == MODE_COMMANDS && commands[cmdCursor].Left(8) == "GIVE TO " && GiveBlocked(inv).Length() > 0) line = GiveBlocked(inv);
		else if (mode == MODE_COMMANDS && commands[cmdCursor].Left(8) == "GIVE TO ") line = commands[cmdCursor];
		else if (mode == MODE_COMBINE) line = "Combine with which item?";
		else if (cursor <= TAB_BASE) { static const String tabName[] = { "MAP", "FILE", "", "EXIT" }; line = tabName[TAB_BASE - cursor]; }
		else if (curId != RE_ITEM_NONE) line = REItemInfo.GetName(curId);
		else if (cursor == EQUIPPED_BOX)
		{
			let cw = CheatWeapon(inv);
			line = cw != null ? (PartnerHere(inv) ? "ENTER: give it to " .. inv.partnerName .. " (you keep it)" : cw.GetTag().MakeUpper() .. " (All Weapons cheat)") : (eid != RE_ITEM_NONE ? REItemInfo.GetName(eid) : "");
		}
		RE1Classic.BottomLine(line);
	}

	bool ClassicMouse(REInventory inv, int type, int x, int y)
	{
		Vector2 p = RE1Classic.ToLayout(x, y);
		if (mode == MODE_CHECK)
		{
			if (type == MOUSE_Release) MenuEvent(MKEY_Back, false);
			return true;
		}
		if (mode == MODE_COMMANDS)
		{
			double top = RE1Classic.CmdY(commands.Size());
			if (!RE1Classic.Inside(p, RE1Classic.CMD_X, top, 48, commands.Size() * 24))
			{
				if (type == MOUSE_Release) MenuEvent(MKEY_Back, false);
				return true;
			}
			int i = clamp(int((p.y - top) / 24), 0, commands.Size() - 1);
			if (i != cmdCursor) { cmdCursor = i; MenuSound("menu/cursor"); }
			if (type == MOUSE_Release) RunCommand(inv, commands[cmdCursor]);
			return true;
		}
		int over = -100;
		for (int s = 0; s < inv.numSlots; s++) if (RE1Classic.Inside(p, RE1Classic.SlotX(inv, s), RE1Classic.SlotY(inv, s), 40, 30)) over = s;
		if (mode == MODE_SLOTS)
		{
			if (RE1Classic.Inside(p, RE1Classic.EQUIP_X, RE1Classic.EQUIP_Y, 40, 30)) over = EQUIPPED_BOX;
			for (int t = 0; t < 4; t++) if (RE1Classic.Inside(p, RE1Classic.TabX(t), RE1Classic.TabY(t), 48, 16)) over = TAB_BASE - t;
		}
		if (over == -100) return true;
		if (over != cursor) { cursor = over; MenuSound("menu/cursor"); }
		if (type == MOUSE_Release) MenuEvent(MKEY_Enter, false);
		return true;
	}
}
