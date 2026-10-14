// ---------------------------------------------------------------------------
// RE_Cheats.zs - the Cheats menu's Invincibility (main menu > Extras > Cheats).
//
// Infinite Ammo is in REGun (RE_Items.zs): with re_cheat_ammo on, a shot
// doesn't use a round. Invincibility uses Doom's own god mode, set on every
// player each tic while re_cheat_god is on; works for Jill and Chris alike.
// ---------------------------------------------------------------------------

class RECheatsHandler : EventHandler
{
	bool godSet;   // we switched god mode on (so we also switch it off)

	override void WorldTick()
	{
		bool want = re_cheat_god;
		if (!want && !godSet) return;
		for (int i = 0; i < MAXPLAYERS; i++)
		{
			if (!playeringame[i]) continue;
			if (want) players[i].cheats |= CF_GODMODE;
			else players[i].cheats &= ~CF_GODMODE;
		}
		godSet = want;
	}
}

// Cheats > All Weapons (re_cheat_weapons): every RE weapon, outside the item
// slots, switched with the number keys (RETankPlayer's weapon slots) and the
// mouse wheel. Each gun comes fully loaded and its rounds / fuel are used up as usual (REInventory.cheatRounds; only Infinite Ammo is endless). Switching it off
// leaves only the weapon equipped from the slots.
class REAllWeaponsHandler : EventHandler
{
	static const class<Weapon> all[] = { "REKnife", "REHandgun", "REShotgun", "REMagnum", "REGrenadeLauncher", "RERocketLauncher", "REFlamethrower" };
	bool wasOn;

	override void WorldTick()
	{
		bool on = re_cheat_weapons;
		if (!on && !wasOn) return;
		for (int p = 0; p < MAXPLAYERS; p++)
		{
			if (!playeringame[p]) continue;
			let pmo = players[p].mo;
			if (pmo == null || pmo.health <= 0) continue;
			let inv = REInventory(pmo.FindInventory("REInventory"));
			if (inv == null) continue;
			if (on)
			{
				// Never a switch to another weapon: what was in hand (or coming
				// up) stays; with nothing, the Beretta - the one from your slots
				// if one is equipped.
				Weapon before = players[p].PendingWeapon != WP_NOCHANGE ? players[p].PendingWeapon : players[p].ReadyWeapon;
				bool gave = false;
				for (int i = 0; i < all.Size(); i++)
				{
					if (pmo.FindInventory(all[i]) != null || (all[i] == "REFlamethrower" && !(pmo is "REChrisPlayer") && !re_cheat_jillflame)) continue;   // the flamethrower: Chris only, as in RE1
					pmo.GiveInventory(all[i], 1);
					inv.FillCheatGun(all[i]);   // a full load (used up like any other: only Infinite Ammo is endless)
					gave = true;
				}
				if (gave || !wasOn || level.maptime <= 1)
				{
					class<Weapon> keep = before != null ? before.GetClass() : null;
					if (keep == null && inv.equippedSlot >= 0) keep = REItemInfo.WeaponClass(inv.slotId[inv.equippedSlot]);
					if (keep == null) keep = "REHandgun";
					let w = Weapon(pmo.FindInventory(keep));
					if (w != null) players[p].PendingWeapon = players[p].ReadyWeapon == w ? WP_NOCHANGE : w;
				}
			}
			else
			{
				// Back to RE1 rules: only the equipped slot weapon, with its own rounds.
				class<Weapon> keep = null;
				if (inv.equippedSlot >= 0) keep = REItemInfo.WeaponClass(inv.slotId[inv.equippedSlot]);
				inv.TakeWeaponsExcept(keep);
				if (keep != null)
				{
					if (REItemInfo.IsGun(inv.slotId[inv.equippedSlot])) pmo.SetInventory("RELoadedRounds", inv.slotQty[inv.equippedSlot]);
					if (players[p].ReadyWeapon == null || players[p].ReadyWeapon.GetClass() != keep)
						players[p].PendingWeapon = Weapon(pmo.FindInventory(keep));
				}
				else pmo.SetInventory("RELoadedRounds", 0);
			}
		}
		wasOn = on;
	}
}

// Cheat codes, typed in the console (~); keyconf.txt makes each one a
// command, with or without a trailing period ("starsteam" or "starsteam.").
//   starsteam      invincibility on / off (re_cheat_god)
//   rocketman      all weapons (re_cheat_weapons on)
//   jillsandwich   full health
//   inkribbon      3 Ink Ribbons (in your item slots; dropped at your feet
//                  if there is no room)
class RECheatCodeHandler : EventHandler
{
	// re_jillflamer (keyconf.txt toggles re_cheat_jillflame, then sends this):
	// switched on, the flamethrower goes straight into your hands with a full
	// tank, in a free slot (or, with no room, the way All Weapons gives one).
	static void JillFlamer(int p)
	{
		if (p < 0 || !playeringame[p]) return;
		let pmo = players[p].mo;
		if (pmo == null || pmo.health <= 0) return;
		if (!re_cheat_jillflame) { Console.Printf("JILL FLAMETHROWER: off."); return; }
		RERecordRun.MarkCheated();
		let inv = REInventory(pmo.FindInventory("REInventory"));
		if (inv == null) return;
		int s = inv.FindGun(RE_ITEM_FLAMETHROWER);
		if (s < 0)
		{
			s = inv.FindFreeSlot();
			if (s >= 0) inv.SetSlot(s, RE_ITEM_FLAMETHROWER, 240);
		}
		else if (!inv.IsEquippedGun(s)) inv.SetSlot(s, RE_ITEM_FLAMETHROWER, 240);
		if (s >= 0)
		{
			if (inv.equippedSlot != s) inv.EquipSlot(s);
			else pmo.SetInventory("RELoadedRounds", 240);   // already in hand: refill
		}
		else
		{
			if (pmo.FindInventory("REFlamethrower") == null) pmo.GiveInventory("REFlamethrower", 1);
			pmo.SetInventory("RELoadedRounds", 240);
			players[p].PendingWeapon = Weapon(pmo.FindInventory("REFlamethrower"));
		}
		String msg = "JILL FLAMETHROWER: on. The flamethrower is in your hands.";
		Console.MidPrint(null, msg);
		Console.Printf("%s", msg);
	}
	override void NetworkProcess(ConsoleEvent e)
	{
		if (e.Name ~== "re_jillflamer") { JillFlamer(e.Player); return; }
		if (!(e.Name ~== "re_cheatcode") || e.Player < 0 || !playeringame[e.Player]) return;
		let pmo = players[e.Player].mo;
		if (pmo == null || pmo.health <= 0) return;
		RERecordRun.MarkCheated();   // a typed cheat code: this map's run isn't recorded (RE_Records.zs)
		let inv = REInventory(pmo.FindInventory("REInventory"));
		String msg = "";
		switch (e.Args[0])
		{
		case 0:
		{
			bool on = !re_cheat_god;
			CVar.FindCVar('re_cheat_god').SetBool(on);
			msg = on ? "S.T.A.R.S. TEAM: invincibility ON." : "S.T.A.R.S. TEAM: invincibility OFF.";
			break;
		}
		case 1:
			CVar.FindCVar('re_cheat_weapons').SetBool(true);
			msg = "ROCKET MAN: all weapons! (keys 1-7, mouse wheel; 7 = flamethrower for Chris)";
			break;
		case 2:
		{
			int full = pmo.GetMaxHealth(true);
			pmo.player.health = pmo.health = max(pmo.health, full);
			msg = "JILL SANDWICH: full health!";
			break;
		}
		case 3:
		{
			int left = inv != null ? inv.Store(RE_ITEM_INK_RIBBON, 3) : 3;
			msg = "INK RIBBON: you got 3 INK RIBBONS.";
			if (left > 0)
			{
				let drop = REPickup(Actor.Spawn("REInkRibbonPickup", pmo.pos));
				if (drop != null) drop.itemQty = left;
				msg = left < 3 ? "INK RIBBON: no room for all 3; the rest are at your feet." : "INK RIBBON: no room; 3 INK RIBBONS are at your feet.";
			}
			break;
		}
		}
		if (msg.Length() == 0) return;
		if (inv != null) inv.ShowMessage(msg);
		else Console.MidPrint(null, msg);
		Console.Printf("%s", msg);   // also at the top of the screen
		pmo.A_StartSound("menu/choose", CHAN_AUTO, CHANF_UI);
	}
}
// Main menu > Extras > Cheats > Cheat List: every cheat, what it does, and how to
// switch it from the console (~). Esc goes back.
class RECheatListMenu : OptionMenu
{
	static const String names[] = {
		"INFINITE AMMO", "INVINCIBILITY", "SUPER JUMP", "ALL WEAPONS",
		"FULL HEALTH", "INK RIBBONS", "JILL FLAMETHROWER", "LIGHTING", "SAVE MODE", "FINAL BOSS", "AI PARTNER" };
	static const String what[] = {
		"Guns never use rounds; an empty gun fires anyway.",
		"You take no damage.",
		"Jumps about six times higher (Space).",
		"Every RE weapon, full. Ammo runs out (only Infinite Ammo is endless). Keys 1-7 / wheel; 7 = flamethrower.",
		"Health back to full.",
		"3 Ink Ribbons for the typewriters (at your feet if your slots are full).",
		"Puts the flamethrower (full tank) in Jill's hands; she can pick them up too. Normally Chris only.",
		"Doom (default) or RE1-style darker lighting (key L, or Settings > Gameplay).",
		"Normal, Typewriter (typewriter only) or Classic RE (+ Ink Ribbon). Settings > Gameplay.",
		"Starts MAP30 in front of the Icon of Sin.",
		"Jill or Chris follows you (Both). Needs Settings > Gameplay > AI partner on." };
	static const String cmds[] = {
		"re_cheat_ammo 1   (0 = off)",
		"re_cheat_god 1   (0 = off)",
		"re_superjump   or   re_cheat_jump 1 / 0",
		"re_allweapons   or   re_cheat_weapons 1 / 0",
		"jillsandwich",
		"inkribbon",
		"re_jillflamer   or   re_cheat_jillflame 1 / 0",
		"re_lights   or   re_dark 0 (Doom) / 1 (RE1)",
		"re_save_classic 0 (normal) / 2 (typewriter) / 1 (classic)",
		"re_bossfight",
		"re_partner 1 (Jill) / 2 (Chris) / 0, then start a map" };
	// the console cheat codes ("" = none)
	static const String typedCodes[] = {
		"", "STARSTEAM", "", "ROCKETMAN", "JILLSANDWICH", "INKRIBBON", "", "", "", "", "" };

	// Lines are drawn on REDraw's 640x400 canvas (the whole canvas is always on
	// screen), 10 units tall, and any line too long for its space is shrunk to
	// fit, so nothing runs off the right edge at any resolution.
	const LEFT = 24;
	const RIGHT = 616;

	static double LineSize() { return 10.0 / NewSmallFont.GetHeight(); }

	// Draws text from x, at most maxW wide; returns its drawn width.
	static double Words(int color, double x, double y, String text, double maxW = RIGHT - LEFT)
	{
		double size = min(LineSize(), maxW / max(1, REDraw.TextWidth(text)));
		REDraw.Text(x, y, text, color, size);
		return REDraw.TextWidth(text, size);
	}

	override void Drawer()
	{
		Screen.Dim(Color(255, 0, 0, 0), 0.85, 0, 0, Screen.GetWidth(), Screen.GetHeight());
		REDraw.CenteredText(6, "CHEAT LIST", Font.CR_RED, 1.4);
		for (int i = 0; i < names.Size(); i++)
		{
			double y = 32 + i * 29;
			double nameW = Words(Font.CR_GOLD, LEFT, y, names[i]);
			if (typedCodes[i].Length() > 0)
			{
				// "TYPE IN CONSOLE (~):  CODE", right-aligned on the name's line
				String code = "TYPE IN CONSOLE (~):  " .. typedCodes[i];
				double room = RIGHT - LEFT - nameW - 16;
				double w = min(REDraw.TextWidth(code, LineSize()), room);
				Words(Font.CR_RED, RIGHT - w, y, code, room);
			}
			Words(Font.CR_WHITE, LEFT, y + 10, what[i]);
			Words(Font.CR_DARKGRAY, LEFT, y + 20, "Console:  " .. cmds[i]);
		}
		Words(Font.CR_DARKGRAY, LEFT, 360, "Cheats switch off when you quit; the Settings > Gameplay options are remembered.");
		Words(Font.CR_DARKGRAY, LEFT, 374, "Console: press the TILDE (~) KEY      ESC back");
	}
}
