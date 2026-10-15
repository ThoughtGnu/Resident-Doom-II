// ---------------------------------------------------------------------------
// RE_Controls.zs - Settings > Controls: every Resident Doom II action and the
// keys bound to it right now (read live from GZDoom's bindings, so a key
// changed in Customize Controls shows here straight away). Text in the
// Credits style: white labels, gray keys, gold section names.
// ---------------------------------------------------------------------------

class REControlsMenu : OptionMenu
{
	// One row per entry: "#Section" starts a section; otherwise
	// "label|command[,command...]" or "label|=fixed text". A "*" column
	// break starts the right-hand column.
	static const String rows[] = {
		"#TANK CONTROLS (fixed cameras)",
		"Walk forward|+forward",
		"Back up|+back",
		"Turn left|+left",
		"Turn right|+right",
		"Run (hold)|+speed",
		"#COMBAT",
		"Aim (hold)|+user1",
		"Fire (while aiming)|+use,+attack",
		"Aim up / down|+forward,+back",
		"Weapon slots (cheat)|slot 1,slot 2,slot 3,slot 4,slot 5,slot 6,slot 7",
		"Next / prev. weapon|weapnext,weapprev",
		"#ACTION",
		"Pick up / doors / use|+use",
		"Inventory screen|re_inventory",
		"Map screen|re_map,togglemap",
		"*",
		"#MOVEMENT",
		"Jump|+jump",
		"Crouch (hold)|+crouch",
		"#VIEW",
		"First / third person|re_view",
		"Look (first person)|=Mouse",
		"Strafe (first person)|+moveleft,+moveright",
		"#OTHER",
		"Lighting Doom / RE1|re_lights",
		"Quicksave|quicksave,re_quicksave",
		"Save / load menu|menu_save,menu_load",
		"Menu / pause|=Esc",
		"Console|toggleconsole"
	};

	// The keys for some commands, named as GZDoom names them ("W, UpArrow").
	// Keyboard and mouse first; gamepad buttons only if there is nothing
	// else. At most 3, or two per command (up to 6).
	String KeysFor(String cmds)
	{
		Array<String> parts;
		cmds.Split(parts, ",");
		Array<String> keysPc, keysPad;
		for (int i = 0; i < parts.Size(); i++)
		{
			Array<int> keys;
			Bindings.GetAllKeysForCommand(keys, parts[i]);
			for (int k = 0; k < keys.Size(); k++)
			{
				Array<int> one;
				one.Push(keys[k]);
				String keyName = Bindings.NameAllKeys(one, false);
				// the console key's name is a backtick, which the font draws as a dot
				if (keyName == "`" || keyName == "~") keyName = "Tilde (~)";
				if (keyName.Length() == 0 || keysPc.Find(keyName) < keysPc.Size() || keysPad.Find(keyName) < keysPad.Size()) continue;
				if (IsPad(keyName)) keysPad.Push(keyName); else keysPc.Push(keyName);
			}
		}
		Array<String> use;
		if (keysPc.Size() > 0) use.Copy(keysPc); else use.Copy(keysPad);
		int most = min(6, max(3, parts.Size() * 2));
		String all = "";
		for (int i = 0; i < use.Size() && i < most; i++) all = i > 0 ? all .. ", " .. use[i] : use[i];
		return all;
	}

	static bool IsPad(String name)
	{
		String l = name.MakeLower();
		return l.Left(3) == "joy" || l.Left(4) == "pad_" || l.IndexOf("shoulder") >= 0 || l.IndexOf("trigger") >= 0
			|| l.IndexOf("thumb") >= 0 || l.Left(4) == "dpad" || l.Left(3) == "pov" || l.Left(4) == "axis";
	}

	const TS = 0.72;      // text size on the 640x480 layout
	const LINE = 16;

	void Words(Font f, int color, double x, double y, String text, double s = TS)
	{
		Screen.DrawText(f, color, x, y, text, DTA_ScaleX, s, DTA_ScaleY, s,
			DTA_VirtualWidth, 640, DTA_VirtualHeight, 480, DTA_FullscreenScale, FSMode_ScaleToFit43);
	}

	// The widest label in one column (rows from..to), on the layout.
	double LabelWidth(Font f, int from, int to)
	{
		double w = 0;
		for (int i = from; i < to; i++)
		{
			String r = rows[i];
			int bar = r.IndexOf("|");
			if (bar > 0) w = max(w, f.StringWidth(r.Left(bar)) * TS);
		}
		return w;
	}

	override void Drawer()
	{
		Screen.Dim(Color(255, 0, 0, 0), 0.85, 0, 0, Screen.GetWidth(), Screen.GetHeight());
		Font f = NewSmallFont;
		String title = "CONTROLS";
		Words(BigFont, Font.CR_RED, 320 - BigFont.StringWidth(title) / 2, 14, title, 1);

		int split = 0;
		for (int i = 0; i < rows.Size(); i++) if (rows[i] == "*") split = i;
		double top = 54;
		double x = 28, y = top, keyX = x + LabelWidth(f, 0, split) + 14;
		for (int i = 0; i < rows.Size(); i++)
		{
			String r = rows[i];
			if (r == "*") { x = 336; y = top; keyX = x + LabelWidth(f, split, rows.Size()) + 14; continue; }
			if (r.Left(1) == "#")
			{
				if (y > top) y += 8;
				Words(f, Font.CR_GOLD, x, y, r.Mid(1));
				y += LINE;
				continue;
			}
			int bar = r.IndexOf("|");
			String label = r.Left(bar), cmd = r.Mid(bar + 1);
			String keys = cmd.Left(1) == "=" ? cmd.Mid(1) : KeysFor(cmd);
			Words(f, Font.CR_WHITE, x, y, label);
			if (keys.Length() == 0) Words(f, Font.CR_DARKGRAY, keyX, y, "(not set)");
			else Words(f, Font.CR_GRAY, keyX, y, keys);
			y += LINE;
		}
		String foot = "Change keys in Settings > Customize Controls (Resident Doom II section).   Esc back";
		Words(f, Font.CR_DARKGRAY, 320 - f.StringWidth(foot) * TS / 2, 448, foot);
	}}
