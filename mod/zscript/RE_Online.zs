// RE_Online.zs - Main menu > Online: host or join online co-op from inside the game.
//
// GZDoom sets up online games only when it starts (-host / -join), so Start hosting
// and Join (keyconf.txt re_online_host / re_online_join) save the choice
// (re_net_request, re_net_map, re_net_address in the settings file) and quit
// normally. play.bat / play.command wait for GZDoom to close, read the choice,
// clear it and start GZDoom again online; when that online game closes they start
// the normal game once more. re_launcher tells the game that one of them is
// waiting (they set it at every start; it's never remembered).

// The main-menu item: opens the Online page, or explains why it can't.
class ListMenuItemREOnlineItem : ListMenuItemTextItem
{
	override bool Activate()
	{
		if (multiplayer)
		{
			Menu.StartMessage("You're already in an online game.\n\nPress a key.", 1);
			return true;
		}
		if (!CVar.FindCVar('re_launcher').GetBool())
		{
			Menu.StartMessage("To play online, start the game with\nplay.bat (Mac: play.command).\n\nPress a key.", 1);
			return true;
		}
		return Super.Activate();
	}
}

// The Online page (menudef.txt REOnlineMenu). Start hosting and Join are GZDoom's
// own SafeCommand items: after their yes/no question they run keyconf.txt's
// re_online_host / re_online_join (set re_net_request, quit). That has to be a
// plain SafeCommand: GZDoom lets only that item quit the game. The page only stops
// Join with Enter while no address has been typed.
class REOnlineMenu : RETitleOptionMenu
{
	override bool MenuEvent(int mkey, bool fromcontroller)
	{
		if (mkey == MKEY_Enter && mDesc.mSelectedItem >= 0 && mDesc.mSelectedItem < mDesc.mItems.Size())
		{
			let item = mDesc.mItems[mDesc.mSelectedItem];
			if (item == GetItem('re_online_join') && CVar.FindCVar('re_net_address').GetString().Length() == 0)
			{
				Menu.StartMessage("Type the host's address first\n(Host's address, above Join).\n\nPress a key.", 1);
				return true;
			}
		}
		return Super.MenuEvent(mkey, fromcontroller);
	}
}

// "Friends type: 192.168.1.20": this computer's local address(es), which
// play.bat / play.command pass in at start (re_net_localip). Empty without them.
class OptionMenuItemREOnlineAddress : OptionMenuItemStaticText
{
	String prefix;

	OptionMenuItemREOnlineAddress Init(String label, int cr = -1)
	{
		Super.Init(label, cr);
		prefix = label;
		return self;
	}

	override int Draw(OptionMenuDescriptor desc, int y, int indent, bool selected)
	{
		String ip = CVar.FindCVar('re_net_localip').GetString();
		ip.StripLeftRight();
		if (ip.Length() == 0) return -1;
		mLabel = String.Format("%s: %s (same Wi-Fi)", prefix, ip);
		return Super.Draw(desc, y, indent, selected);
	}
}

// "7. Dead Simple": a Doom II level as players know it, for the Online page and
// its level picker (the Level Select screen, RE_LevelSelect.zs REHostLevelMenu).
// The name is the game's own (so it matches your DOOM II version), without a
// "level 7: " in front if the game has one.
class REOnlineNames ui
{
	static String LevelText(String map)
	{
		int num = map.Left(3) ~== "MAP" ? map.Mid(3).ToInt(10) : 0;   // base 10: "08" isn't octal
		let info = LevelInfo.FindLevelInfo(map);
		if (num <= 0 || info == null) return map;
		String title = info.LookupLevelName();
		int colon = title.IndexOf(": ");
		if (colon > 0 && title.Left(6) ~== "level ") title = title.Mid(colon + 2);
		return String.Format("%d. %s", num, title);
	}
}

// Online > Starting level: shows the host's first level by name and opens the
// picker (menudef.txt REHostLevelMenu) on Enter.
class OptionMenuItemREHostLevel : OptionMenuItemSubmenu
{
	override int Draw(OptionMenuDescriptor desc, int y, int indent, bool selected)
	{
		drawLabel(indent, y, selected ? OptionMenuSettings.mFontColorSelection : OptionMenuSettings.mFontColor);
		drawValue(indent, y, OptionMenuSettings.mFontColorValue, REOnlineNames.LevelText(CVar.FindCVar('re_net_map').GetString()), false, false);
		return indent;
	}
}