// ---------------------------------------------------------------------------
// TankPlayer.zs - the player, with Resident Evil 1 tank controls.
//
//   Up / Down      walk forward / back up (in the direction you face)
//   Left / Right   turn
//   Run (hold)     run while walking forward
//   Aim (hold)     raise your weapon; Left/Right turn, Action fires
//   Action (E)     pick up the item in front of you, open doors
//   Jump (Space)   jump (not in RE1, added for Doom's maps)
//   V              switch to first-person view and back (RE_View.zs)
//
// The mouse and strafe keys are ignored on purpose: RE1 has neither.
// ---------------------------------------------------------------------------

class RETankPlayer : DoomPlayer
{
	bool bREAiming;       // aim held with a weapon equipped
	bool bREUseWasHeld;   // Action button state on the previous tic
	bool reBridge;        // level just started: still-held keys count (RE_Input.zs)
	bool reUseFromLoad;   // a level or a saved game just started: an Action key still held from before (the key that continued after dying, or skipped the intermission) doesn't count until let go
	int reAimDir;         // aiming: 0 straight, 1 up, 2 down (RE1: Up/Down while aiming)
	int reShownAimDir;    // the direction the model is showing
	bool reWasCrouched;   // crouch transitions (UpdateAnimation)
	bool reCrawling;      // crouched in a gap too low to kneel: crawling (UpdateAnimation)
	bool reKneeling;      // crouched and in the kneel (not the squat walk)
	int reStillTics;      // tics crouched without moving
	bool bREFirstPerson;  // V pressed: normal Doom controls and view (RE_View.zs)
	bool bREViewSet;      // Settings > Gameplay > Starting view: applied at every start (RE_View.zs)
	double reCrouchEye;   // first-person eye height while kneeling (crouched)
	property CrouchEye: reCrouchEye;

	// What the legs are doing this tic, set by MovePlayer (for animation).
	enum EREMove { MOVE_STILL, MOVE_WALK, MOVE_RUN, MOVE_BACK, MOVE_TURN }
	int reMove;

	// Animation state (see UpdateAnimation)
	Name reAnim;          // animation currently playing
	Name reModel;         // which model is loaded

	// Which RE1 character this is. Picks the models and first-person arms
	// (models/<char>/...), written by tools\re1convert.
	String reChar;
	int reSlots;          // item slots (RE1: Jill 8, Chris 6)
	double reAimTurn;     // turn speed while aiming
	property Character: reChar;
	property Slots: reSlots;
	property AimTurn: reAimTurn;
	int reAnimUntil;      // level.maptime when a one-shot animation ends
	int reFireUntil;
	int rePainUntil;
	bool reWasAiming;

	Default
	{
		Player.DisplayName "Jill";
		// First-person eye height: Jill's real eye level, from her RE1 model's
		// head (re1convert eyes: 45% of the way from the crown to the chin),
		// at the size the model is drawn (0.0249 map units per RE1 unit,
		// measured on screen). Standing 2539 RE1 units, kneeling 1923.
		Player.ViewHeight 63.2;
		RETankPlayer.CrouchEye 47.9;
		Health 96;              // RE1: Jill's max health (GameStart.cpp)
		RETankPlayer.Character "jill";
		RETankPlayer.Slots 8;
		RETankPlayer.AimTurn RE_TURN_AIMING;
		// Number keys (used with the All Weapons cheat, RE_Cheats.zs)
		Player.WeaponSlot 1, "REKnife";
		Player.WeaponSlot 2, "REHandgun";
		Player.WeaponSlot 3, "REShotgun";
		Player.WeaponSlot 4, "REMagnum";
		Player.WeaponSlot 5, "REGrenadeLauncher";
		Player.WeaponSlot 6, "RERocketLauncher";
		Player.WeaponSlot 7, "REFlamethrower";   // Jill: only ever with the re_jillflamer cheat
		Player.MaxHealth 96;
		+DECOUPLEDANIMATIONS    // model animation is chosen in code, not by states
		+ALLOWTHRUBITS          // walks through the AI partner (RE_Partner.zs)
		ThruBits 1;
	}

	States
	{
	Aim:                        // "gun raised" pose (Doom's firing frame)
		PLAY E 1;
		Loop;
	// Doom's own attack frames (PlayAttacking / PlayAttacking2), but never
	// BRIGHT as Doom has them: the model would be drawn fully lit, a white
	// flash of the whole body at every shot or slash.
	Missile:
		PLAY E 12;
		Goto Spawn;
	Melee:
		PLAY F 6;
		Goto Missile;
	}

	// Doomguy normally starts with a pistol and fist. We give only the RE
	// inventory; it holds Jill's starting items (see RE_Inventory.zs).
	override void GiveDefaultInventory()
	{
		if (player == null) return;

		// Same armour setup as PlayerPawn.GiveDefaultInventory.
		GiveInventoryType(GetHexenArmorClass());
		let harmor = HexenArmor(FindInventory('HexenArmor', true));
		if (harmor != null)
		{
			harmor.Slots[4] = self.HexenArmor[0];
			for (int i = 0; i < 4; ++i)
			{
				harmor.SlotsIncrement[i] = self.HexenArmor[i + 1];
			}
		}
		GiveInventoryType(GetBasicArmorClass());

		GiveInventoryType("REInventory");
		let inv = REInventory(FindInventory("REInventory"));
		if (inv != null) inv.numSlots = reSlots;
		GiveInventoryType("REItemBox");   // the item boxes' shared contents (RE_ItemBox.zs)
	}

	// Runs once per tic before Doom's own player code. We rewrite the
	// buttons here so Doom only sees what RE1 allows.
	override void PlayerThink()
	{
		// The first tic after every start (a new game, a level start, a loaded
		// save, a Continue; RE_View.zs REViewHandler clears bREViewSet): the view
		// chosen in Settings > Gameplay > Starting view (re_start_view).
		if (!bREViewSet)
		{
			bREViewSet = true;
			bool fp = re_start_view == 1;
			if (bREFirstPerson != fp) SetFirstPerson(fp);
		}
		UserCmd cmd = player.cmd;
		int buttons = cmd.buttons;
		bool alive = player.playerstate != PST_DEAD && health > 0;

		// Right after a level starts, keys you were already holding still
		// count (RE_Input.zs), until you let go or press something fresh.
		if (reBridge)
		{
			let bridge = REInputBridge(StaticEventHandler.Find("REInputBridge"));
			int held = bridge != null ? bridge.heldButtons[PlayerNumber()] : 0;
			int fresh = buttons & (BT_FORWARD | BT_BACK | BT_LEFT | BT_RIGHT);
			// (the held-keys report can take a few tics to arrive)
			if (fresh != 0 || (held == 0 && level.maptime > 10)) reBridge = false;
			else
			{
				buttons |= held;
				cmd.buttons = buttons;
			}
		}

		// Action still held from before this level / saved game started: ignored
		// until it's let go (it would pick up the item next to you)
		if (reUseFromLoad)
		{
			if (buttons & BT_USE) { buttons &= ~BT_USE; cmd.buttons = buttons; }
			else reUseFromLoad = false;
		}

		bool useHeld = (buttons & BT_USE) != 0;
		bool usePressed = useHeld && !bREUseWasHeld;
		bREUseWasHeld = useHeld;

		bREAiming = alive && (buttons & BT_USER1) != 0 && player.ReadyWeapon is "REWeapon";

		// Aim up / down, like RE1: hold Up or Down while aiming. In first
		// person it follows where you look.
		reAimDir = 0;
		if (bREAiming)
		{
			if (bREFirstPerson) reAimDir = Pitch < -15 ? 1 : (Pitch > 15 ? 2 : 0);
			else if (buttons & BT_FORWARD) reAimDir = 1;
			else if (buttons & BT_BACK) reAimDir = 2;
		}

		if (alive && bREFirstPerson)
		{
			// First person: Doom's own movement and mouse look. Weapons work
			// like RE1: hold Aim to raise, Action (E) or the fire button shoots,
			// and she can't walk while aiming.
			int keep = buttons & ~(BT_TURN180 | BT_RELOAD | BT_ZOOM | BT_ATTACK | BT_ALTATTACK);
			if (bREAiming)
			{
				if (buttons & (BT_USE | BT_ATTACK)) keep |= BT_ATTACK;
				keep &= ~(BT_USE | BT_JUMP);
				cmd.forwardmove = 0;
				cmd.sidemove = 0;
			}
			else if (usePressed && TryPickUpAhead()) keep &= ~BT_USE;
			cmd.buttons = keep;
		}
		else if (alive)
		{
			// RE1 has no quick turn or free firing. Jumping and crouching (C)
			// are ours; no jumping while aiming.
			int keep = buttons & ~(BT_ATTACK | BT_ALTATTACK
				| BT_TURN180 | BT_RELOAD | BT_ZOOM);
			if (bREAiming) keep &= ~BT_JUMP;

			if (bREAiming)
			{
				// While aiming, Action (E) shoots.
				if (buttons & BT_USE) keep |= BT_ATTACK;
				keep &= ~BT_USE;
			}
			else if (usePressed && TryPickUpAhead())
			{
				keep &= ~BT_USE;   // the press was used for the item, not a door
			}
			cmd.buttons = keep;
		}
		else
		{
			// Dead: GZDoom's own "press Use to restart" is not used; Space or E
			// on the death screen continues RE1-style instead (RE_Continue.zs).
			cmd.buttons = buttons & ~(BT_USE | BT_ATTACK | BT_ALTATTACK | BT_JUMP);
		}

		Super.PlayerThink();

		// Hold the "gun raised" pose while aiming.
		State aimState = FindState("Aim");
		if (bREAiming)
		{
			if (!InStateSequence(CurState, MissileState)
				&& !InStateSequence(CurState, MeleeState)
				&& !InStateSequence(CurState, aimState))
			{
				SetState(aimState);
			}
		}
		else if (InStateSequence(CurState, aimState))
		{
			SetState(SpawnState);
		}

		UpdateAnimation();
	}

	// -----------------------------------------------------------------------
	// Jill's model animation. Names match the animations written by
	// tools\re1convert (RE1's own: see the Jill() comment in Program.cs).
	// RE1 animates at 30 frames a second; one-shot lengths below are in
	// Doom tics (frames * 35 / 30).
	// -----------------------------------------------------------------------

	static int Tics30(int frames) { return (frames * 35 + 29) / 30; }

	void PlayAnim(Name anim, bool loop, int lengthFrames = 0, int blendTics = 3)
	{
		if (anim == reAnim) return;
		reAnim = anim;
		SetAnimation(anim, -1, -1, -1, -1, blendTics, loop ? SAF_LOOP : 0);
		reAnimUntil = lengthFrames > 0 ? level.maptime + Tics30(lengthFrames) : 0;
	}

	// RE1 swaps the arm-with-weapon mesh when you equip a weapon
	// (LoadEquippedWeaponAnimation). We swap the whole model.
	void UpdateModelSet()
	{
		let w = REWeapon(player.ReadyWeapon);
		// With armor, the model with the matching vest (re1convert character):
		// _vest1 for light armor (green), _vest2 for heavy (blue).
		int vest = 0;
		let arm = BasicArmor(FindInventory("BasicArmor"));
		if (arm != null && arm.Amount > 0) vest = arm.SavePercent >= 0.5 ? 2 : 1;
		String armFile = w != null ? w.armName : "unarmed";
		String file = String.Format("%s_%s%s.iqm", reChar, armFile, vest > 0 ? String.Format("_vest%d", vest) : "");
		Name want = file;
		if (want == reModel) return;
		reModel = want;
		String path = "models/" .. reChar;
		// RE1 has no Jill with a flamethrower (re_jillflamer cheat): jill_flame is
		// Chris's RE1 flamethrower on her body (re1convert), with its own texture
		// (hers, and his for the flamethrower)
		String skin = armFile == "flame" && reChar != "chris" ? reChar .. "_flame.png" : reChar .. ".png";
		A_ChangeModel(GetClassName(), 0, path, want, 0, path, skin);
		reAnim = 'None';   // force the animation to restart on the new model
	}

	// While the map loads (REStartLayoutHandler): the model for the weapon in
	// hand, the standing animation and the RE1-lighting look, so the first
	// picture of the map is the same as the ones after it.
	void PrimeLook()
	{
		UpdateAnimation();
		UpdateREPlayerLight();
		lightlevel = re_dark && re_char_minlight > 0 ? RELightingHandler.Glow(self, 16, re_char_minlight) : -1;
	}

	void UpdateAnimation()
	{
		UpdateModelSet();
		int now = level.maptime;

		if (health <= 0)
		{
			PlayAnim('death', false);
			return;
		}
		if (now < rePainUntil)
		{
			PlayAnim('pain', false);
			return;
		}

		// Jump, made from two of the run cycle's strides: one leg forward while
		// rising, the other while falling. Landing blends back to the usual
		// animation.
		if (!player.onground && player.jumpTics != 0 && !bREAiming)
		{
			Name pose = Vel.Z > 0 ? 'jump_up' : 'jump_down';
			if (pose != reAnim)
			{
				reAnim = pose;
				int f = pose == 'jump_up' ? 4 : 14;
				SetAnimation('run', 1, f, f, f + 1, 5, SAF_LOOP);
			}
			return;
		}

		bool armed = player.ReadyWeapon is "REWeapon";
		bool crouched = player.crouchfactor < 0.9;

		// Crouched (C), made by re1convert (Crouch.cs):
		//   standing still: a one-knee kneel (crouch_down into it, 0.5 s)
		//   moving: a deep squat walk (crouch_walk / crouch_back), never the kneel
		// Crouching while already moving goes straight into the squat walk
		// (crouch_walkin); stopping kneels only after a moment standing still
		// (crouch_settle); moving off from the kneel rises into the walk
		// (crouch_rise). Standing up reverses whichever one you were in.
		if (crouched)
		{
			bool moving = reMove != MOVE_STILL && !bREAiming;
			reStillTics = moving ? 0 : reStillTics + 1;
			// In a gap too low for the kneel or the squat walk (the ~88-unit model
			// would go through the ceiling): on hands and knees (Crouch.Crawl), the
			// same crawl as the AI partner. crawl_in from the squat walk, crawl_out
			// back to it once there's headroom again.
			bool lowSpace = ceilingz - floorz < RE_CRAWL_BELOW;
			if (lowSpace && !reCrawling)
			{
				reCrawling = true;
				reWasCrouched = true;
				reKneeling = false;
				PlayAnim('crawl_in', false, 9, 4);
				return;
			}
			if (reCrawling)
			{
				if (!lowSpace) { reCrawling = false; PlayAnim('crawl_out', false, 9, 4); return; }
				if (reAnim == 'crawl_in' && now < reAnimUntil) return;
				PlayAnim(moving ? 'crawl' : 'crawl_still', true, 0, 5);
				return;
			}
			if (reAnim == 'crawl_out' && now < reAnimUntil) return;
			bool busy = (reAnim == 'crouch_down' || reAnim == 'crouch_rise' || reAnim == 'crouch_settle' || reAnim == 'crouch_walkin') && now < reAnimUntil;
			if (!reWasCrouched)
			{
				reWasCrouched = true;
				reKneeling = !moving;
				PlayAnim(moving ? 'crouch_walkin' : 'crouch_down', false, moving ? 9 : 15, 4);
				return;
			}
			if (moving)
			{
				// going down into the kneel but moving off already: straight to the walk
				if (reKneeling && reAnim == 'crouch_down') { reKneeling = false; PlayAnim('crouch_walk', true, 0, 6); return; }
				if (busy && reAnim != 'crouch_settle') return;
				if (reKneeling && reAnim != 'crouch_rise') { PlayAnim('crouch_rise', false, 9, 5); return; }
				if (reAnim == 'crouch_rise' && now < reAnimUntil) return;
				reKneeling = false;
				PlayAnim(reMove == MOVE_BACK ? 'crouch_back' : 'crouch_walk', true, 0, 5);
				return;
			}
			if (busy) return;
			if (!reKneeling)
			{
				if (reStillTics < 6) { PlayAnim('crouch_walk', true, 0, 5); return; }   // a moment's pause: keep the squat
				if (reAnim != 'crouch_settle') { PlayAnim('crouch_settle', false, 9, 5); return; }
				reKneeling = true;
			}
			if (bREAiming && armed)
			{
				if (now < reFireUntil) PlayAnim('crouch_fire', false);
				else PlayAnim('crouch_aim', true);
				reWasAiming = true;
				return;
			}
			reWasAiming = false;
			PlayAnim('crouch', true, 0, 5);
			return;
		}
		if (reWasCrouched)
		{
			// standing up: the kneel in reverse, or straight up out of the squat walk
			// (or, still on all fours, the crawl's get-down in reverse)
			reWasCrouched = false;
			if (reCrawling) { reCrawling = false; reKneeling = false; PlayAnim('crawl_up', false, 24, 4); return; }
			PlayAnim(reKneeling ? 'crouch_up' : 'crouch_walkout', false, reKneeling ? 15 : 9, 4);
			reKneeling = false;
			return;
		}
		if ((reAnim == 'crouch_walkout') && now < reAnimUntil && reMove == MOVE_STILL && !bREAiming) return;		if (reAnim == 'crouch_up' && now < reAnimUntil && reMove == MOVE_STILL && !bREAiming) return;

		if (bREAiming && armed)
		{
			// RE1's aim directions: straight (raise / hold / fire), up and down
			// (into the pose / hold / fire), re1convert names *_up and *_down.
			if (now < reFireUntil) PlayAnim(reShownAimDir == 1 ? 'fire_up' : (reShownAimDir == 2 ? 'fire_down' : 'fire'), false);
			else if (!reWasAiming) { PlayAnim('aim_raise', false, CurrentWeapon() != null ? CurrentWeapon().RaiseLength() : 13); reShownAimDir = 0; }
			else if (reAnim == 'aim_raise' && now < reAnimUntil) {}
			else if (reAimDir != reShownAimDir)
			{
				reShownAimDir = reAimDir;
				if (reAimDir == 0) PlayAnim('aim_hold', true);
				else PlayAnim(reAimDir == 1 ? 'aim_up' : 'aim_down', false, 6);
			}
			else if (reAimDir == 0) PlayAnim('aim_hold', true);
			else if (now >= reAnimUntil) PlayAnim(reAimDir == 1 ? 'aim_up_hold' : 'aim_down_hold', true);
			reWasAiming = true;
			return;
		}
		reWasAiming = false;
		reShownAimDir = 0;

		switch (reMove)
		{
		case MOVE_WALK:
		case MOVE_TURN:  PlayAnim('walk', true); break;   // RE1 turns with the walk cycle
		case MOVE_RUN:   PlayAnim('run', true); break;
		case MOVE_BACK:  PlayAnim('back', true); break;
		default:         PlayAnim('idle', true); break;
		}
	}

	REWeapon CurrentWeapon() { return REWeapon(player.ReadyWeapon); }

	// Called by the weapons when they fire or slash.
	void REStartFire()
	{
		reFireUntil = level.maptime + Tics30(CurrentWeapon() != null ? CurrentWeapon().FireLength() : 20);
		reAnim = 'None';
	}

	override int DamageMobj(Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		int done = Super.DamageMobj(inflictor, source, damage, mod, flags, angle);
		if (done > 0 && health > 0) rePainUntil = level.maptime + Tics30(20);
		return done;
	}

	// Tank movement, replacing Doom's mouse-and-strafe movement.
	// Speeds are set fresh every tic like RE1: no acceleration, instant stop.
	override void MovePlayer()
	{
		if (bREFirstPerson)
		{
			Super.MovePlayer();   // Doom's mouse-look, strafing and movement
			return;
		}
		UserCmd cmd = player.cmd;
		player.onground = (pos.z <= floorz) || bOnMobj || bMBFBouncer || (player.cheats & CF_NOCLIP2);

		int buttons = cmd.buttons;
		int turn = 0;
		if (buttons & BT_LEFT)  turn++;
		if (buttons & BT_RIGHT) turn--;
		int move = 0;
		if (buttons & BT_FORWARD) move++;
		if (buttons & BT_BACK)    move--;
		bool run = (buttons & BT_SPEED) != 0;
		// Always run (CapsLock, GZDoom's cl_run): running without Shift, and
		// Shift walks instead (Doom does the same with it in first person)
		let alwaysRun = CVar.GetCVar('cl_run', player);
		if (alwaysRun != null && alwaysRun.GetBool()) run = !run;

		// Which RE1 behaviour are we in? (PlayerAnimations.cpp)
		double turnRate;
		double speed;
		bool crouched = player.crouchfactor < 0.9;
		if (bREAiming)
		{
			turnRate = reAimTurn;   // can't walk while aiming
			speed = 0;
		}
		else if (crouched)
		{
			// crouched: half-speed walk forward or back, no running
			turnRate = RE_TURN_WALKING;
			speed = move > 0 ? RE_SPEED_WALK * 0.5 : (move < 0 ? -RE_SPEED_BACK * 0.5 : 0);
			run = false;
		}
		else if (move > 0)
		{
			if (run)
			{
				turnRate = RE_TURN_RUNNING;
				speed = RE_SPEED_RUN;
			}
			else
			{
				turnRate = RE_TURN_WALKING;
				speed = RE_SPEED_WALK;
			}
		}
		else if (move < 0)
		{
			turnRate = RE_TURN_WALKING;   // backing up never runs
			speed = -(EnemyAhead() ? RE_SPEED_BACK_GUARDED : RE_SPEED_BACK);
		}
		else
		{
			turnRate = RE_TURN_IN_PLACE;
			speed = 0;
		}

		if (turn != 0)
		{
			A_SetAngle(Angle + turn * turnRate, SPF_INTERPOLATE);
		}

		if (speed > 0) reMove = run ? MOVE_RUN : MOVE_WALK;
		else if (speed < 0) reMove = MOVE_BACK;
		else if (turn != 0 && !bREAiming) reMove = MOVE_TURN;
		else reMove = MOVE_STILL;

		if (player.onground)
		{
			Vel = (AngleToVector(Angle, speed * re_speedscale), Vel.Z);
		}

		if (!(player.cheats & CF_PREDICTING))
		{
			if (speed != 0) PlayRunning();
			else if (!bREAiming) PlayIdle();
		}
	}

	// Space jumps. Doom's maps don't allow jumping by default, so Jill does
	// her own jump (same height as GZDoom's), in both views.
	override void CheckJump()
	{
		// Settings > Gameplay > Jump off: Space does nothing (Super Jump still works).
		bool superJump = re_cheat_jump && !REMain.Online();   // no cheats in online co-op
		if (!re_allow_jump && !superJump) return;
		if ((player.cmd.buttons & BT_JUMP) && player.onground && player.jumpTics == 0
			&& player.crouchoffset == 0 && waterlevel < 2 && !bNoGravity && health > 0)
		{
			// Cheats > Super Jump (re_cheat_jump): 2.5 times the speed, about 6 times
			// as high (roughly 200 units instead of 32).
			Vel.Z += JumpZ * 35 / TICRATE * (superJump ? 2.5 : 1.0);
			bOnMobj = false;
			player.jumpTics = -1;
			if (!(player.cheats & CF_PREDICTING)) A_StartSound("*jump", CHAN_BODY);
			return;
		}
		Super.CheckJump();
	}

	// Crouching (C) on every map: Doom's maps don't allow it by default.
	// GZDoom's own crouch, minus that check (it still waits for headroom
	// before standing up).
	override void CheckCrouch(bool totallyfrozen)
	{
		// Settings > Gameplay > Crouch off: C does nothing; a crouching player
		// stands up (once there's headroom).
		if (!re_allow_crouch) { player.cmd.buttons &= ~BT_CROUCH; player.crouching = 0; }
		UserCmd cmd = player.cmd;
		if (cmd.buttons & BT_JUMP) cmd.buttons &= ~BT_CROUCH;
		if (CanCrouch() && player.health > 0)
		{
			if (!totallyfrozen)
			{
				int crouchdir = player.crouching;
				if (crouchdir == 0) crouchdir = (cmd.buttons & BT_CROUCH) ? -1 : 1;
				else if (cmd.buttons & BT_CROUCH) player.crouching = 0;
				if (crouchdir == 1 && player.crouchfactor < 1 && pos.Z + height < ceilingz) CrouchMove(1);
				else if (crouchdir == -1 && player.crouchfactor > 0.5) CrouchMove(-1);
			}
		}
		else player.Uncrouch();
		player.crouchoffset = -(ViewHeight) * (1 - player.crouchfactor);

		// First-person eye: from standing to kneeling height (CrouchEye) as the
		// crouch goes from 1 (standing) to 0.5 (fully down), instead of GZDoom's
		// half of the standing height.
		double eye = ViewHeight - (ViewHeight - reCrouchEye) * (1 - player.crouchfactor) * 2;
		if (player.crouchviewdelta != eye - ViewHeight)
		{
			player.crouchviewdelta = eye - ViewHeight;
			player.viewheight = eye;
		}
	}

	// No looking up or down: the camera is fixed anyway.
	override void CheckPitch()
	{
		if (bREFirstPerson) Super.CheckPitch();
		else Pitch = 0;
	}

	// RE1 backs up slightly slower when a live enemy is in front of you.
	bool EnemyAhead()
	{
		let it = BlockThingsIterator.Create(self, RE_GUARD_DISTANCE);
		while (it.Next())
		{
			let mo = it.thing;
			if (mo == self || !mo.bIsMonster || mo.health <= 0) continue;
			if (Distance2D(mo) > RE_GUARD_DISTANCE) continue;
			if (abs(DeltaAngle(Angle, AngleTo(mo))) <= RE_GUARD_ANGLE) return true;
		}
		return false;
	}

	// RE1's action button checks a point just in front of you for an item
	// (check_action_object). We also accept an item you're standing on.
	bool TryPickUpAhead()
	{
		let inv = REInventory(FindInventory("REInventory"));
		if (inv == null) return false;

		Vector2 probe = pos.xy + AngleToVector(Angle, RE_ACTION_REACH);
		REPickup best = null;
		double bestDist = 0;

		let it = BlockThingsIterator.Create(self, RE_ACTION_REACH + 32);
		while (it.Next())
		{
			let p = REPickup(it.thing);
			if (p == null) continue;
			if (abs(p.pos.z - pos.z) > Height) continue;

			double d = min((p.pos.xy - probe).Length(), Distance2D(p));
			if (d > p.radius + 12) continue;
			if (best == null || d < bestDist)
			{
				best = p;
				bestDist = d;
			}
		}

		if (best == null) return OpenBoxAhead();
		inv.TakePickup(best);
		return true;
	}

	// An item box or a typewriter in front of you: open its screen
	// (RE_ItemBox.zs, RE_Typewriter.zs).
	bool OpenBoxAhead()
	{
		if (UseTypewriterAhead()) return true;
		Vector2 probe = pos.xy + AngleToVector(Angle, RE_ACTION_REACH);
		let it = BlockThingsIterator.Create(self, RE_ACTION_REACH + 48);
		while (it.Next())
		{
			let box = REItemBoxActor(it.thing);
			if (box == null) continue;
			if (min((box.pos.xy - probe).Length(), Distance2D(box)) > box.radius + radius + 8) continue;
			box.StartOpening(self);   // the lid opens, then the box screen appears
			return true;
		}
		return false;
	}
}

// Chris Redfield. Same controls; RE1's own differences (GameStart.cpp,
// PlayerAnimations.cpp): 140 health, 6 item slots, and he turns faster while
// aiming (0x48 against Jill's 0x38). He starts with the same items as Jill
// (knife, Beretta, First Aid Spray); in RE1 the Beretta goes to Rebecca.
class REChrisPlayer : RETankPlayer
{
	Default
	{
		Player.DisplayName "Chris";
		Player.ViewHeight 66.6;          // Chris's eye level, standing 2675 RE1 units
		RETankPlayer.CrouchEye 51.3;     // kneeling 2061
		Health 140;
		Player.MaxHealth 140;
		RETankPlayer.Character "chris";
		RETankPlayer.Slots 6;
		RETankPlayer.AimTurn 5.424107143;   // 0x48, converted like RE_TURN_AIMING
		Player.WeaponSlot 7, "REFlamethrower";   // his RE1 flamethrower: key 7 with the All Weapons cheat (Jill has none)
	}
}
