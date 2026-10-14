// ---------------------------------------------------------------------------
// RE_Cast.zs - Doom II's ending cast call with the RE1 characters.
//
// After the Icon of Sin, Doom II's cast call ends with Doomguy, "OUR HERO".
// Here it ends with whoever played: CHRIS REDFIELD, JILL VALENTINE, or both
// (Chris, then Jill) when both played (you and the AI partner, or players
// in a network game). Every monster in it is Doom II's own, unchanged.
//
// The cast call draws flat sprite pictures, never models, so the heroes are
// pictures made from their RE1 models with RE1's own animations
// ("re1convert castsprites": graphics/cast, textures.cast.txt): the Beretta
// walk, its raise / aim / fire, and the RE1 death with the RE1 death scream.
//
// The three cast lists are in mapinfo.txt (RE_CastJill / RE_CastChris /
// RE_CastBoth, each looping back to its first monster like Doom II's). When
// the Icon of Sin dies, MAP30's next stop is pointed at the right one; the
// rest of the ending (the level stats with Records, Doom II's text) is as
// before. GZDoom only knows an ending by the map that leads to it, so each
// list has a map entry that is never played (RE_CASTJ / RE_CASTC / RE_CASTB),
// whose "next" names it.
//
// Console (for testing, straight to the cast call):
//   re_castcall          whoever is playing now (you, plus the partner)
//   re_castcall_jill / re_castcall_chris / re_castcall_both
// ---------------------------------------------------------------------------

class RECastJill : Actor
{
	Default { DeathSound "re1/jilldeath"; }
	States
	{
	Spawn:
	See:
		JCWK ABCDEFGH 4;
		Loop;
	Missile:
		JCAT ABCD 3;     // raise the Beretta (RE1 motion 5)
		JCAT E 6;        // aim (motion 7)
		JCAT F 3;        // fire (motion 6): the shot plays here (mapinfo.txt)
		JCAT GH 4;
		Goto See;
	Death:
		JCDE ABCDEFGHIJKLMNO 4;   // RE1's death (body motion 4)
		JCDE P -1;
		Stop;
	}
}

class RECastChris : Actor
{
	Default { DeathSound "re1/chrisdeath"; }
	States
	{
	Spawn:
	See:
		CCWK ABCDEFGH 4;
		Loop;
	Missile:
		CCAT ABCD 3;
		CCAT E 6;
		CCAT F 3;
		CCAT GH 4;
		Goto See;
	Death:
		CCDE ABCDEFGHIJKLMNO 4;
		CCDE P -1;
		Stop;
	}
}

class RECastHandler : EventHandler
{
	// 1 Jill, 2 Chris, 3 both: who played, as the game is now.
	static int WhoPlayed()
	{
		bool jill = false, chris = false;
		for (int i = 0; i < MAXPLAYERS; i++)
		{
			if (!playeringame[i] || players[i].mo == null) continue;
			if (players[i].mo is "REChrisPlayer") chris = true;
			else if (players[i].mo is "RETankPlayer") jill = true;
		}
		let pt = REPartner.Find();   // the AI partner can't die: they always reach the end
		if (pt is "REPartnerChris") chris = true;
		else if (pt is "REPartnerJill") jill = true;
		if (chris && jill) return 3;
		return chris ? 2 : 1;
	}

	static const Name endings[] = { 'RE_EndJill', 'RE_EndChris', 'RE_EndBoth' };
	static const String castMaps[] = { "RE_CASTJ", "RE_CASTC", "RE_CASTB" };

	// The Icon of Sin dies: MAP30 leads to the cast call of whoever played.
	override void WorldThingDied(WorldEvent e)
	{
		if (!(e.Thing is "BossBrain")) return;
		if (REMain.Online()) return;   // online co-op: Doom II's own ending
		let info = LevelInfo.FindLevelInfo(castMaps[WhoPlayed() - 1]);
		if (info == null || info.NextMap.Length() == 0) return;   // (then Doom II's own ending, unchanged)
		level.NextMap = info.NextMap;
		level.NextSecretMap = info.NextMap;
		if (re_debugcams) Console.Printf("ENDING: %s (%s)", castMaps[WhoPlayed() - 1], info.NextMap);
	}

	override void NetworkProcess(ConsoleEvent e)
	{
		if (!(e.Name ~== "re_castcall")) return;
		int who = e.Args[0] >= 1 && e.Args[0] <= 3 ? e.Args[0] : WhoPlayed();
		level.StartIntermission(endings[who - 1], FSTATE_EndingGame);
	}
}
