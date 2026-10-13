// ---------------------------------------------------------------------------
// RE_View.zs - V switches between the RE fixed cameras (the default) and a
// normal Doom first-person view.
//
// In first person Jill uses Doom's controls: mouse to look and turn, WASD /
// arrows to move and strafe, fire button to shoot. You see the equipped
// weapon in your hands; with nothing equipped, your hands are empty. Press V again to go back to tank controls and fixed cameras.
// (keys.cfg binds V to "re_view"; keyconf.txt defines it.)
// ---------------------------------------------------------------------------

class REViewHandler : EventHandler
{
	// Every map load (new game, level start, loaded save, Continue): back to the
	// Starting view on the next tic (TankPlayer.zs PlayerThink).
	override void WorldLoaded(WorldEvent e)
	{
		for (int i = 0; i < MAXPLAYERS; i++)
		{
			if (!playeringame[i]) continue;
			let jill = RETankPlayer(players[i].mo);
			if (jill != null) jill.bREViewSet = false;
		}
	}

	override void NetworkProcess(ConsoleEvent e)
	{
		if (!(e.Name ~== "re_view")) return;
		if (e.Player < 0 || !playeringame[e.Player]) return;
		let jill = RETankPlayer(players[e.Player].mo);
		if (jill == null || jill.health <= 0) return;
		jill.SetFirstPerson(!jill.bREFirstPerson);
	}
}

extend class RETankPlayer
{
	void SetFirstPerson(bool on)
	{
		bREFirstPerson = on;
		if (on)
		{
			player.camera = self;   // nothing is equipped for you: unarmed stays unarmed
		}
		else
		{
			A_SetPitch(0);
		}
	}
}

// Settings > Field of View (first person): GZDoom's own fov setting (75-120,
// kept in its settings file). GZDoom applies a change to the view only while
// the game runs, and the menu pauses it, so a change is sent to the player's
// view right away: the view behind the pause menu follows the slider. (The
// fixed cameras have their own field of view.)
class REFovHandler : StaticEventHandler
{
	ui double shownFov;

	override void UiTick()
	{
		let cv = CVar.FindCVar("fov");
		if (cv == null || gamestate != GS_LEVEL) return;
		double v = clamp(cv.GetFloat(), 75, 120);
		if (v == shownFov) return;
		shownFov = v;
		EventHandler.SendNetworkEvent("re_fov", int(v));
	}

	override void NetworkProcess(ConsoleEvent e)
	{
		if (!(e.Name ~== "re_fov") || e.Player < 0 || !playeringame[e.Player]) return;
		let p = players[e.Player];
		p.DesiredFOV = e.Args[0];
		p.FOV = e.Args[0];
	}
}