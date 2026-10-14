// ---------------------------------------------------------------------------
// RE_Input.zs - keeps tank controls working across level changes.
//
// When a level starts, GZDoom releases every held button. A key you are
// still holding (say, Up during the "Entering Underhalls" screen) then does
// nothing until you let go and press it again. With tank controls you hold
// Up a lot, so Jill would just stand there.
//
// This handler watches the physical keys bound to walk / back / turn / run /
// aim, including while the intermission screen is up (REStatusScreen). Right
// after a level starts, if one of them is still held, Jill gets it anyway
// (TankPlayer.zs, "bridge"), until you release it or the game sees a fresh
// press. If a menu opens, it lets go of everything, so nothing can get
// stuck.
// ---------------------------------------------------------------------------

class REInputBridge : StaticEventHandler
{
	// Buttons currently held on the keyboard (BT_* bits), as last reported.
	int heldButtons;

	ui int uiHeld;

	static const String commands[] = { "+forward", "+back", "+left", "+right", "+speed", "+user1" };
	static const int buttons[] = { BT_FORWARD, BT_BACK, BT_LEFT, BT_RIGHT, BT_SPEED, BT_USER1 };

	override bool InputProcess(InputEvent e)
	{
		TrackKey(e);
		if (ContinueKey(e)) return true;
		return false;   // let the game handle the key as usual
	}

	// The death screen: Space or E continue (RE_Continue.zs), read as the keys
	// themselves, so they work however the keys are bound; a key bound to
	// Action (+use) works too.
	const KEY_SPACE = 0x39;
	const KEY_E = 0x12;
	ui bool ContinueKey(InputEvent e)
	{
		if (e.Type != InputEvent.Type_KeyDown || gamestate != GS_LEVEL || Menu.GetCurrentMenu() != null) return false;
		let pl = players[consoleplayer];
		if (pl.mo == null || (pl.playerstate != PST_DEAD && pl.mo.health > 0)) return false;
		int u1, u2;
		[u1, u2] = Bindings.GetKeysForCommand("+use");
		if (e.KeyScan != KEY_SPACE && e.KeyScan != KEY_E && e.KeyScan != u1 && e.KeyScan != u2) return false;
		EventHandler.SendNetworkEvent("re_continue");
		return true;
	}

	// Called for every key event, including the ones the intermission screen
	// receives (REStatusScreen below), which never reach InputProcess.
	ui void TrackKey(InputEvent e)
	{
		if (e.Type != InputEvent.Type_KeyDown && e.Type != InputEvent.Type_KeyUp) return;
		int held = uiHeld;
		for (int i = 0; i < commands.Size(); i++)
		{
			int k1, k2;
			[k1, k2] = Bindings.GetKeysForCommand(commands[i]);
			if (e.KeyScan != k1 && e.KeyScan != k2) continue;
			if (e.Type == InputEvent.Type_KeyDown) held |= buttons[i];
			else held &= ~buttons[i];
		}
		Report(held);
	}

	ui bool wasInLevel;

	override void UiTick()
	{
		// Keys released while a menu is open never reach InputProcess, so
		// forget everything as soon as a menu is up.
		if (Menu.GetCurrentMenu() != null)
		{
			Report(0);
			return;
		}
		// When a level has just started, send the held keys again, so the
		// game side has them even if the last report was sent during the
		// intermission.
		bool inLevel = gamestate == GS_LEVEL;
		if (inLevel && !wasInLevel) Report(uiHeld, true);
		wasInLevel = inLevel;
	}

	ui void Report(int held, bool force = false)
	{
		if (held == uiHeld && !force) return;
		uiHeld = held;
		EventHandler.SendNetworkEvent("re_held", held);
	}

	override void NetworkProcess(ConsoleEvent e)
	{
		if (e.Name ~== "re_held")
		{
			heldButtons = e.Args[0];
			if (re_debugcams) Console.Printf("held keys: 0x%x", heldButtons);
		}
		// Toggle Run (CapsLock, keyconf.txt re_togglerun): the message for it
		else if (e.Name ~== "re_runmsg" && e.Player >= 0 && playeringame[e.Player] && players[e.Player].mo != null)
		{
			let inv = REInventory(players[e.Player].mo.FindInventory("REInventory"));
			if (inv != null) inv.ShowMessage(e.Args[0] ? "Always run: ON" : "Always run: OFF");
		}
	}

	static ui void NoteKey(InputEvent e)
	{
		let me = REInputBridge(StaticEventHandler.Find("REInputBridge"));
		if (me != null) me.TrackKey(e);
	}

	// A new level: let the player use keys that were already held.
	override void WorldLoaded(WorldEvent e)
	{
		for (int i = 0; i < MAXPLAYERS; i++)
		{
			if (!playeringame[i]) continue;
			let jill = RETankPlayer(players[i].mo);
			if (jill != null) { jill.reBridge = true; jill.reUseFromLoad = true; }
		}
	}
}

// Doom II's intermission / "Entering ..." screen, which also tells the bridge
// about movement keys (any key you press here skips the screen, and the key
// would otherwise be lost). Set in mapinfo.txt (statscreen_single).
class REStatusScreen : DoomStatusScreen
{
	override bool OnEvent(InputEvent evt)
	{
		REInputBridge.NoteKey(evt);
		return Super.OnEvent(evt);
	}

	// Records (RE_Records.zs): NEW RECORD, or why it wasn't saved, under the stats.
	override void Drawer()
	{
		Super.Drawer();
		let st = RERecordStats.Get();
		if (st == null) return;
		st.Commit();
		String msg = st.EndMessage();
		if (msg.Length() == 0) return;
		bool good = msg == "NEW RECORD";
		double h = Screen.GetHeight();
		Screen.Dim(Color(255, 0, 0, 0), 0.6, 0, int(h * 0.84), Screen.GetWidth(), int(h * 0.1));
		RECredits.Line(good ? BigFont : NewSmallFont, good ? Font.CR_GOLD : Font.CR_ORANGE, msg, h * 0.86, good ? 0.06 : 0.045);
	}
}
