// ---------------------------------------------------------------------------
// RE_Partner.zs - the AI partner (character select or Level Select "Both").
//
// You play Jill or Chris; the other one follows you as a friendly teammate:
//   - Following: the partner always walks the way you walked (a trail of
//     breadcrumbs, one every 32 units), never straight through a corner.
//     It cuts ahead along the trail only where the straight walk is clear
//     for its whole width, steers around corners and door frames when the
//     next step is blocked, and slides along walls.
//   - Last resort, after being stuck for 3 seconds, off camera for 8
//     seconds or very far behind: they catch up by stepping onto your trail
//     just behind you, but only while both they and that spot are out of
//     your view (the fixed camera's, or yours in first person).
//   - They never stand in a closing door, and you walk straight through each
//     other (ThruBits), so they can't block a doorway or a corridor.
//   - Fighting: they stop, face the nearest enemy they can see and fire their
//     own RE weapon with RE1's own damage (Jill's Beretta 9, Chris's shotgun
//     53). Their shots hit the enemy directly, so they can never hurt you.
//   - They don't take damage (enemies go after you, like Doom's usual
//     rules), and they don't count as monsters. Arachnotrons and the Spider
//     Mastermind can poison them (RE_Poison.zs): a purple glow and slower
//     firing, until you give them a blue herb or a blue mix.
//   - You can give them one of your guns from the inventory (GIVE TO ...,
//     RE_InventoryMenu.zs): they fight with it from then on (its RE1 damage,
//     sound, model and animations) and hand you their old weapon. The
//     rounds loaded in a gun travel with it; the partner's own shots don't
//     use them up (as before, the partner never runs out).
// re_partner: 0 none, 1 Jill follows you, 2 Chris follows you.
// ---------------------------------------------------------------------------

class REPartner : Actor
{
	String reChar;
	int weaponId;                  // the RE item id of the gun in their hands (RE_Items.zs)
	int rounds;                    // the rounds loaded in it (they travel with the gun)
	int spareAmmo;                 // ammo for it they picked up (Partner pickups); yours when you swap guns
	int damage;
	Sound fireSound;
	int raiseFrames, fireFrames;   // RE1 frames (30 a second)
	property Character: reChar;
	property WeaponId: weaponId;
	property Rounds: rounds;

	Array<double> trailX, trailY, trailZ;   // where the leader walked
	Actor enemy;
	int aimTics, cooldown, stuckTics, offCamTics, scanTics, fireUntil;
	int pumpAt;                    // level.maptime of the shotgun's pump (0 = none)
	Vector2 lastPos;
	double lastGoalDist;
	Name anim;
	bool partnerLightOn;
	bool poisonLightOn;
	bool released, holdSet;        // map start: standing still until the leader moves (TickMove)
	bool crouched;                 // crawling through a low gap (UpdateCrouch)
	int animLockUntil;             // a get-down / stand-up animation plays until then
	Vector2 holdLeader;

	const TRAIL_MAX = 96;
	const STAND_H = 56;            // Height
	const CROUCH_H = 28;           // crouched, like the player (half their height)
	const FOLLOW_DIST = 64;
	const FIGHT_RANGE = 900;

	Default
	{
		Radius 16;
		Height 56;
		Mass 400;
		MaxStepHeight 24;
		MaxDropOffHeight 64;
		+SOLID
		+FRIENDLY
		+NODAMAGE
		+DECOUPLEDANIMATIONS
		+ALLOWTHRUBITS
		ThruBits 1;         // the player has the same bit: you pass through each other
		+DONTSPLASH
		+NOTELEPORT
		+SLIDESONWALLS      // slide along a wall instead of stopping dead
		+NOBLOCKMONST       // Doom's "block monsters" lines (stair edges in MAP01) don't stop them: they go where you go
	}

	States
	{
	Spawn:
		PLAY A -1;          // the model (modeldef.txt) is drawn instead
		Stop;
	}

	static REPartner Find()
	{
		let it = ThinkerIterator.Create("REPartner");
		return REPartner(it.Next());
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		SetWeapon(weaponId, rounds);
		PlayAnim('idle', true);
		lastPos = pos.xy;
		// its light (RE1 lighting only) is set in Tick
	}

	void PlayAnim(Name a, bool loop)
	{
		// crouched (a low gap): on hands and knees, the same crawl as the player
		// (re1convert Crouch.Crawl); holding still on all fours otherwise
		if (crouched)
		{
			if (a == 'walk' || a == 'run') a = 'crawl';
			else { a = 'crawl_still'; loop = true; }
		}
		if (level.maptime < animLockUntil) return;   // getting down / standing up (UpdateCrouch)
		if (a == anim) return;
		anim = a;
		SetAnimation(a, -1, -1, -1, -1, 3, loop ? SAF_LOOP : 0);
	}

	static int Tics30(int frames) { return (frames * 35 + 29) / 30; }

	// --- the gun in their hands ----------------------------------------------

	// Puts a gun in their hands: RE1's damage and sound for it (the same as
	// the player's, RE_Items.zs), its model and its RE1 raise / fire timing
	// (read from the same files as the player's first-person arms).
	void SetWeapon(int id, int qty)
	{
		weaponId = id;
		rounds = qty;
		switch (id)
		{
		case RE_ITEM_BERETTA:         damage = 9;   fireSound = "re1/beretta"; break;
		case RE_ITEM_SHOTGUN:         damage = 53;  fireSound = "re1/shotgun"; break;
		case RE_ITEM_PYTHON:          damage = 130; fireSound = "re1/magnum"; break;
		case RE_ITEM_BAZOOKA:         damage = 201; fireSound = "re1/grenade"; break;
		case RE_ITEM_BAZOOKA_ACID:    damage = 95;  fireSound = "re1/acid"; break;
		case RE_ITEM_BAZOOKA_FLAME:   damage = 95;  fireSound = "re1/flame"; break;
		case RE_ITEM_ROCKET_LAUNCHER: damage = 900; fireSound = "re1/rocket"; break;
		}
		String arm = ArmName(id);
		raiseFrames = 13; fireFrames = 22;
		int lump = Wads.CheckNumForFullName(String.Format("models/%s/arm_%s_%s.txt", reChar, reChar, arm));
		if (lump >= 0)
		{
			Array<String> lines;
			Wads.ReadLump(lump).Split(lines, "\n");
			for (int i = 0; i < lines.Size(); i++)
			{
				Array<String> t;
				lines[i].Split(t, " ", TOK_SKIPEMPTY);
				if (t.Size() < 3) continue;
				if (t[0] == "raise") raiseFrames = t[2].ToInt();
				else if (t[0] == "fire") fireFrames = t[2].ToInt();
			}
		}
		String path = "models/" .. reChar;
		String skin = arm == "flame" && reChar != "chris" ? reChar .. "_flame.png" : reChar .. ".png";   // jill_flame: its own texture (TankPlayer.zs)
		A_ChangeModel(GetClassName(), 0, path, String.Format("%s_%s.iqm", reChar, arm), 0, path, skin);
		anim = 'None';
		aimTics = 0;
		fireUntil = 0;
		PlayAnim('idle', true);
	}

	static String ArmName(int id)
	{
		switch (id)
		{
		case RE_ITEM_SHOTGUN:         return "shotgun";
		case RE_ITEM_PYTHON:          return "magnum";
		case RE_ITEM_BAZOOKA:
		case RE_ITEM_BAZOOKA_ACID:
		case RE_ITEM_BAZOOKA_FLAME:   return "grenade";
		case RE_ITEM_ROCKET_LAUNCHER: return "rocket";
		}
		return "beretta";
	}

	// The blast a bazooka round or a rocket leaves on what it hits (only a
	// picture and a sound: it never hurts anyone).
	class<Actor> BlastClass()
	{
		if (weaponId == RE_ITEM_BAZOOKA_ACID) return "REAcidBlast";
		if (weaponId == RE_ITEM_BAZOOKA_FLAME) return "REFlameBlast";
		if (REItemInfo.IsBazooka(weaponId) || weaponId == RE_ITEM_ROCKET_LAUNCHER) return "REGrenadeBlast";
		return null;
	}

	// Poison (RE_Poison.zs). Kept in the player's inventory, so it carries
	// over to the next map and into saved games with them.
	REInventory LeaderInv()
	{
		let leader = REMain.Player();
		return leader != null ? REInventory(leader.FindInventory("REInventory")) : null;
	}
	bool IsPoisoned()
	{
		let inv = LeaderInv();
		return inv != null && inv.partnerPoisoned;
	}
	void Poison()
	{
		let inv = LeaderInv();
		if (inv == null || inv.partnerPoisoned) return;
		inv.partnerPoisoned = true;
		inv.ShowMessage(String.Format("%s has been poisoned!", GetTag()));
	}

	// An Arachnotron's plasma hitting them (it still bursts on them, harmless).
	override bool CanCollideWith(Actor other, bool passive)
	{
		if (passive && other.bMissile && REPoison.IsPoisoner(other.target)) Poison();
		return true;
	}

	// Tells the player's inventory screen who the partner is and whether
	// they're close enough to be handed a gun.
	const GIVE_RANGE = 128;
	void ReportToLeader(Actor leader, double dist)
	{
		let inv = REInventory(leader.FindInventory("REInventory"));
		if (inv == null) return;
		inv.partnerName = GetTag();
		inv.partnerNear = dist <= GIVE_RANGE && abs(leader.pos.z - pos.z) <= 32 && CheckSight(leader, SF_IGNOREVISIBILITY);
		inv.partnerSeenTic = level.maptime;
		// their gun goes with you to the next map (REPartnerHandler gives it back)
		inv.partnerGunKept = true;
		inv.partnerGunOf = reChar;
		inv.partnerGunId = weaponId;
		inv.partnerGunRounds = rounds;
		inv.partnerSpare = spareAmmo;
	}

	override void Tick()
	{
		Super.Tick();
		if (isFrozen()) return;
		if (pumpAt > 0 && level.maptime >= pumpAt) { pumpAt = 0; A_StartSound("re1/shotgunpump", CHAN_7); }
		let leader = REMain.Player();
		if (leader == null) return;

		UpdateLights();

		RecordTrail(leader);
		double dist = Distance2D(leader);
		ReportToLeader(leader, dist);
		TickMove(leader, dist);
	}

	// --- Partner pickups (Settings > Gameplay, RE5 style) ----------------------
	// Their own decision, when no enemy is in sight: ammo for the gun in their
	// hands, close to them and only a short way off your path (your trail, or
	// between them and you), that they can walk straight to. They walk over to
	// it, pick it up and go back to following. Never a gun, a herb, a spray, a
	// key, a ribbon, a map or anything else. It's kept as spare ammo, and comes
	// to you with their gun when you swap (RE_Inventory.zs).
	const AMMO_NOTICE = 192;     // how far from them they notice it
	const AMMO_OFF_PATH = 96;    // how far off your path they'll go for it
	const AMMO_GIVE_UP = 35 * 5; // tics before they give up on reaching it
	REPickup ammoTarget;
	int ammoTics;

	// True while they're on their way to ammo (this tic's movement is done).
	bool GoForAmmo(Actor leader, double dist, bool onground)
	{
		if (!re_partner_pickups || enemy != null) { ammoTarget = null; return false; }
		if (ammoTarget == null)
		{
			if (level.maptime % 8 != 0 || dist > 400) return false;
			ammoTarget = FindAmmo(leader);
			ammoTics = 0;
			if (ammoTarget == null) return false;
			if (re_debugcams) Console.Printf("PARTNER goes for ammo: %s x%d, %.0f away", REItemInfo.GetName(ammoTarget.itemId), ammoTarget.itemQty, Distance2D(ammoTarget));
		}
		if (ammoTarget.itemId != REItemInfo.AmmoFor(weaponId) || ammoTarget.itemQty <= 0 || dist > 500 || ++ammoTics > AMMO_GIVE_UP)
		{
			ammoTarget = null;   // gone, no longer theirs, you're getting away, or out of reach
			return false;
		}
		double d = Distance2D(ammoTarget);
		if (d <= radius + ammoTarget.radius + 6)
		{
			TakeAmmo(leader, ammoTarget);
			ammoTarget = null;
			return false;
		}
		if (onground)
		{
			UpdateCrouch((ammoTarget.pos.xy - pos.xy) / d);
			Vector2 dir = SteerAround((ammoTarget.pos.xy - pos.xy) / d, radius + 8);
			Turn(VectorAngle(dir.x, dir.y), 12);
			Vel.XY = dir * min(RE_SPEED_WALK * (crouched ? 0.5 : 1) * re_speedscale, d);
			PlayAnim('walk', true);
		}
		stuckTics = 0;
		return true;
	}

	REPickup FindAmmo(Actor leader)
	{
		int ammo = REItemInfo.AmmoFor(weaponId);
		if (ammo == RE_ITEM_NONE) return null;
		REPickup best = null;
		double bestD = AMMO_NOTICE;
		let it = BlockThingsIterator.Create(self, AMMO_NOTICE);
		while (it.Next())
		{
			let p = REPickup(it.thing);
			if (p == null || p.itemId != ammo || p.itemQty <= 0) continue;
			double d = Distance2D(p);
			if (d >= bestD || abs(p.pos.z - pos.z) > 24 || !CheckSight(p) || !ClearPath(p.pos.xy)) continue;
			if (OffPath(p.pos.xy, leader) > AMMO_OFF_PATH) continue;
			best = p;
			bestD = d;
		}
		return best;
	}

	// How far a point is from your path: the trail, from them along it to you.
	double OffPath(Vector2 at, Actor leader)
	{
		Vector2 prev = pos.xy;
		double best = 1e9;
		for (int i = 0; i <= trailX.Size(); i++)
		{
			Vector2 next = i < trailX.Size() ? (trailX[i], trailY[i]) : leader.pos.xy;
			best = min(best, SegDist(at, prev, next));
			prev = next;
		}
		return best;
	}

	static double SegDist(Vector2 p, Vector2 a, Vector2 b)
	{
		Vector2 ab = b - a;
		double len2 = ab dot ab;
		if (len2 < 1) return (p - a).Length();
		double t = clamp(((p - a) dot ab) / len2, 0, 1);
		return (p - (a + ab * t)).Length();
	}

	void TakeAmmo(Actor leader, REPickup p)
	{
		spareAmmo += p.itemQty;
		let inv = REInventory(leader.FindInventory("REInventory"));
		if (inv != null)
		{
			inv.CountTaken(p);   // Items %: the team found it
			inv.ShowMessage(String.Format("%s picked up the %s.", GetTag(), REItemInfo.GetName(p.itemId)));
		}
		A_StartSound("misc/i_pkup", CHAN_ITEM);
		if (re_debugcams) Console.Printf("PARTNER picked up %s x%d", REItemInfo.GetName(p.itemId), p.itemQty);
		p.Destroy();
	}

	// While the map loads (REStartLayoutHandler): their model, gun, standing
	// animation and lights, so they look the same in the first picture as
	// right after it.
	void PrimeLook()
	{
		SetWeapon(weaponId, rounds);
		UpdateLights();
	}

	void UpdateLights()
	{
		// readable in dark rooms, like the player (RE_Lighting.zs)
		lightlevel = re_dark && re_char_minlight > 0 ? RELightingHandler.Glow(self, 16, re_char_minlight) : -1;
		bool wantLight = re_dark;
		if (wantLight != partnerLightOn)
		{
			partnerLightOn = wantLight;
			if (wantLight) A_AttachLight('REPartnerLight', DynamicLight.PointLight, Color(255, 36, 32, 28), 48, 48, 0, (0, 0, 44));
			else A_RemoveLight('REPartnerLight');
		}
		// poisoned: a faint purple glow on them, in both lighting modes
		bool wantPoison = IsPoisoned();
		if (wantPoison != poisonLightOn)
		{
			poisonLightOn = wantPoison;
			if (wantPoison) A_AttachLight('REPoisonLight', DynamicLight.PointLight, Color(255, 110, 30, 140), 36, 36, 0, (0, 0, 40));
			else A_RemoveLight('REPoisonLight');
		}
	}

	// Following, fighting and keeping up, every tic (Tick).
	void TickMove(Actor leader, double dist)
	{
		bool onground = pos.z <= floorz + 1;

		// Map start: stand where they were put until the leader moves (or an
		// enemy shows up), so nothing shifts in the opening shot.
		if (!released)
		{
			if (!holdSet) { holdSet = true; holdLeader = leader.pos.xy; }
			if (--scanTics <= 0) { scanTics = 8; enemy = FindEnemy(); }
			if (enemy != null && (enemy.health <= 0 || !CheckSight(enemy))) enemy = null;
			if ((leader.pos.xy - holdLeader).Length() < 8 && enemy == null)
			{
				Vel.XY = (0, 0);
				PlayAnim('idle', true);
				return;
			}
			released = true;
		}

		// Catching up, the last resort: far away, stuck, or off camera for a
		// while, and only where you can't see it happen.
		// (Only when she isn't getting anywhere: while she's walking the trail and
		// opening doors she keeps going, however far behind or off camera.)
		if ((stuckTics > 35 * 3 || (dist > 1100 && stuckTics > 35) || offCamTics > 35 * 8) && !InLeaderView(leader))
		{
			String why = stuckTics > 35 * 3 ? "stuck" : (dist > 1100 ? "far" : "off camera");
			if (CatchUp(leader)) { if (re_debugcams) Console.Printf("PARTNER catch-up (%s, %.0f away)", why, dist); return; }
		}
		if (re_debugcams && level.maptime % 35 == 0 && dist > FOLLOW_DIST)
			Console.Printf("PARTNER state: %.0f away, trail %d, stuck %d, offcam %d, enemy %d | her %.0f %.0f, you %.0f %.0f", dist, trailX.Size(), stuckTics, offCamTics, enemy != null, pos.x, pos.y, leader.pos.x, leader.pos.y);
		CheckCamera(leader, dist);

		// Fighting comes first, unless the leader is getting away.
		if (--scanTics <= 0) { scanTics = 8; enemy = FindEnemy(); }
		if (enemy != null && (enemy.health <= 0 || !CheckSight(enemy))) enemy = null;
		// (never from a doorway: the door would close on them; they step through first)
		bool doorway = InDoorway();
		if (enemy != null && dist < 420 && !doorway)
		{
			Fight();
			return;
		}
		aimTics = 0;

		// Partner pickups: off the trail for a moment, to ammo for their gun
		if (GoForAmmo(leader, dist, onground)) return;

		// Following: the breadcrumb trail, cutting ahead only where the
		// straight walk is clear.
		Vector2 goal;
		bool moving = false;
		while (trailX.Size() > 0 && (Vec2To2(trailX[0], trailY[0])).Length() < 24) PopTrail();
		// You in a clear straight walk: the breadcrumbs left behind don't matter
		// (one could be back through a door that has closed again).
		if (trailX.Size() > 0 && trailX.Size() <= 8 && abs(leader.pos.z - pos.z) <= MaxStepHeight && ClearPath(leader.pos.xy))
		{
			trailX.Clear(); trailY.Clear(); trailZ.Clear();
		}
		for (int i = min(trailX.Size(), 8) - 1; i > 0; i--)
		{
			if (abs(trailZ[i] - pos.z) <= MaxStepHeight && ClearPath((trailX[i], trailY[i])))
			{
				for (int k = 0; k < i; k++) PopTrail();
				break;
			}
		}
		// (crouched: a few more steps out of the low gap, to stand up again)
		if (dist > FOLLOW_DIST || InClosingDoor() || doorway || (crouched && dist > 24))
		{
			if (trailX.Size() > 0) { goal = (trailX[0], trailY[0]); moving = true; }
			else if (ClearPath(leader.pos.xy)) { goal = leader.pos.xy; moving = true; }
		}

		if (re_debugcams && level.maptime % 35 == 0 && moving)
			Console.Printf("PARTNER goal %.0f %.0f (z %.0f, her z %.0f, %d trail points)", goal.x, goal.y, trailZ.Size() > 0 ? trailZ[0] : leader.pos.z, pos.z, trailX.Size());
		if (moving && onground)
		{
			Vector2 d = goal - pos.xy;
			double len = d.Length();
			double speed = (dist > 200 ? RE_SPEED_RUN : RE_SPEED_WALK) * re_speedscale;
			if (len > 1)
			{
				// Steer: if the way straight on is blocked (a corner, a door
				// frame), take the nearest free direction to either side.
				Vector2 dir = d / len;
				UpdateCrouch(dir);
				if (crouched) speed = RE_SPEED_WALK * 0.5 * re_speedscale;   // a crouch walk, like the player's
				if (level.maptime % 4 == 0) TryOpenDoor(goal);
				if (stuckTics > 17 && level.maptime % 8 == 0) UnwedgeFromDoor();   // a door closed on them
				dir = SteerAround(dir, max(radius + 4, speed * 2));
				Turn(VectorAngle(dir.x, dir.y), 12);
				Vel.XY = dir * min(speed, len);
			}
			PlayAnim(dist > 200 ? 'run' : 'walk', true);
			// stuck: not getting closer to where we're going
			if (len > lastGoalDist - 0.3) stuckTics++;
			else stuckTics = max(0, stuckTics - 2);
			lastGoalDist = len;
		}
		else
		{
			if (onground) Vel.XY = (0, 0);
			// far behind with no way to go (the trail ran out): that's stuck too
			if (dist > FOLLOW_DIST * 3) stuckTics++;
			else stuckTics = 0;
			lastGoalDist = 1e9;
			UpdateCrouch((0, 0));   // stand up again once there's room
			PlayAnim('idle', true);
		}
	}

	// --- Crouching through low gaps ----------------------------------------------
	// Like the player (C): a gap lower than they stand (56) but not lower than
	// they crouch (28) ahead on their way: they crouch (height 28, a half-speed
	// crouch walk, the crouch animations) and stand up again once there's room.
	void UpdateCrouch(Vector2 dir)
	{
		bool lowAhead = (dir.x != 0 || dir.y != 0) && LowAhead(dir);
		if (!crouched)
		{
			if (!lowAhead) return;
			A_SetSize(-1, CROUCH_H);
			crouched = true;
			PlayTransition('crawl_down', 24);   // one knee down, then onto all fours
			if (re_debugcams) Console.Printf("PARTNER crouches at %.0f %.0f", pos.x, pos.y);
			return;
		}
		if (lowAhead || ceilingz - floorz < STAND_H) return;
		if (!A_SetSize(-1, STAND_H, true)) return;   // no room to stand yet
		crouched = false;
		PlayTransition('crawl_up', 24);   // back up onto one knee, then standing
		if (re_debugcams) Console.Printf("PARTNER stands up at %.0f %.0f", pos.x, pos.y);
	}

	// A get-down / stand-up animation, played through before anything else.
	void PlayTransition(Name a, int frames30)
	{
		anim = a;
		SetAnimation(a, -1, -1, -1, -1, 4, 0);
		animLockUntil = level.maptime + Tics30(frames30);
	}

	// A low gap (crouch height or more, below standing height) within 64 units ahead.
	bool LowAhead(Vector2 dir)
	{
		for (double k = 8; k <= 64; k += 8)
		{
			Vector2 p = pos.xy + dir * k;
			Sector s = level.PointInSector(p);
			double gap = s.ceilingplane.ZatPoint(p) - s.floorplane.ZatPoint(p);
			if (gap < STAND_H && gap >= CROUCH_H) return true;
		}
		return false;
	}

	Vector2 Vec2To2(double x, double y) { return (x, y) - pos.xy; }

	// Can the partner walk straight to this point? Three traces at knee height
	// (just above a step it can climb): through the middle and along both
	// sides of its body.
	bool ClearPath(Vector2 to)
	{
		Vector2 d = to - pos.xy;
		double len = d.Length();
		if (len < 1) return true;
		double ang = VectorAngle(d.x, d.y);
		for (int s = -1; s <= 1; s++)
		{
			if (LineTrace(ang, len, 0, TRF_THRUACTORS, MaxStepHeight + 1, 0, s * radius)) return false;
		}
		return FloorPathOK(to) && !PropInWay(to);
	}

	// A solid thing that isn't a character (the item box, a typewriter, Doom's
	// solid decorations) on the straight way: the traces pass through things,
	// so this checks them.
	bool PropInWay(Vector2 to)
	{
		Vector2 from = pos.xy, d = to - from;
		double len = d.Length();
		Vector2 mid = (from + to) / 2;
		let it = BlockThingsIterator.CreateFromPos(mid.x, mid.y, pos.z, Height, len / 2 + 64, false);
		while (it.Next())
		{
			let m = it.thing;
			if (m == self || !m.bSolid || m.bIsMonster || m.player != null || m is "REPartner") continue;
			if (m.pos.z >= pos.z + Height || m.pos.z + m.Height <= pos.z + MaxStepHeight) continue;   // above them, or low enough to step over
			if (SegDist(m.pos.xy, from, to) < m.radius + radius) return true;
		}
		return false;
	}

	// The floor along the way, every 8 units: no step up higher than they can
	// climb, no drop deeper than they can take, no ceiling too low to pass even
	// crouched (a ledge or a closed door the traces at knee height can miss).
	bool FloorPathOK(Vector2 to)
	{
		Vector2 d = to - pos.xy;
		int n = max(1, int(d.Length() / 8));
		double prev = floorz;
		for (int k = 1; k <= n; k++)
		{
			Vector2 p = pos.xy + d * k / n;
			Sector sec = level.PointInSector(p);
			double fz = sec.floorplane.ZatPoint(p);
			if (fz - prev > MaxStepHeight || prev - fz > MaxDropOffHeight) return false;
			if (sec.ceilingplane.ZatPoint(p) - fz < CROUCH_H) return false;   // lower than even crouching (a closed door)
			prev = fz;
		}
		return true;
	}

	// In a doorway: their body is over a door's sector (its ceiling can come down).
	bool InDoorway()
	{
		let it = BlockLinesIterator.Create(self, radius);
		while (it.Next())
		{
			Line l = it.curline;
			if (l.special != 0 && MayOpen(l) && l.backsector != null && Overlaps(l)) return true;
		}
		return false;
	}

	// Does their box touch this line?
	bool Overlaps(Line l)
	{
		Vector2 a = l.v1.p, ab = l.v2.p - l.v1.p;
		double t = clamp(((pos.xy - a) dot ab) / max(1, ab dot ab), 0, 1);
		return (pos.xy - (a + ab * t)).Length() < radius + 1;
	}

	// A door closed on them (they don't fit where they stand): open it again,
	// the same door, under the same rules as TryOpenDoor.
	void UnwedgeFromDoor()
	{
		let it = BlockLinesIterator.Create(self, radius + 8);
		while (it.Next())
		{
			Line l = it.curline;
			if (!MayOpen(l) || l.backsector == null || !Overlaps(l)) continue;
			Sector door = l.backsector;
			if (door.ceilingdata != null || door.CenterCeiling() - door.CenterFloor() >= Height) continue;
			if (re_debugcams) Console.Printf("PARTNER reopens the door she's in: line %d", l.Index());
			OpenDoor(l);
			return;
		}
	}

	// The direction to move in: straight on if free, otherwise the closest
	// free one turning up to 90 degrees either way.
	Vector2 SteerAround(Vector2 dir, double ahead)
	{
		static const int tries[] = { 0, 25, -25, 50, -50, 75, -75, 90, -90 };
		double base = VectorAngle(dir.x, dir.y);
		for (int i = 0; i < tries.Size(); i++)
		{
			Vector2 d = Actor.AngleToVector(base + tries[i], 1);
			if (CheckMove(pos.xy + d * ahead)) return d;
		}
		return dir;   // nothing free: push on and let it slide along the wall
	}

	// Could the player see the partner right now: on the fixed camera's
	// picture, or in front of them in first person?
	bool InLeaderView(Actor leader)
	{
		let cam = REFixedCamera(players[REMain.Number()].camera);
		if (cam != null) return cam.ViewScore(self) > 0;
		return abs(DeltaAngle(leader.Angle, leader.AngleTo(self))) < 70 && leader.CheckSight(self, SF_IGNOREVISIBILITY);
	}

	void RecordTrail(Actor leader)
	{
		if (leader.pos.z > leader.floorz + 1) return;   // only where they stood
		int n = trailX.Size();
		if (n > 0 && (leader.pos.xy - (trailX[n - 1], trailY[n - 1])).Length() < 32) return;
		trailX.Push(leader.pos.x); trailY.Push(leader.pos.y); trailZ.Push(leader.pos.z);
		if (trailX.Size() > TRAIL_MAX) PopTrail();
	}

	void PopTrail()
	{
		trailX.Delete(0); trailY.Delete(0); trailZ.Delete(0);
	}

	void Turn(double toward, double rate)
	{
		double da = DeltaAngle(Angle, toward);
		Angle += clamp(da, -rate, rate);
	}

	// --- Doors ---------------------------------------------------------------------
	// A plain door closed between them and where they're going (a door you
	// went through closed again): they open it, as a player would with Use.
	// Only a door that opens just itself (no tag, or a tag only its own door
	// sector has), from its front, by Use. A key door only while you carry its
	// key (you could open it anyway); a secret door only once you've opened it
	// yourself (REPartnerHandler remembers). Never a switch (its tag opens
	// something elsewhere), a lift or any other special.
	const DOOR_REACH = 48;

	static Actor Leader() { return REMain.Player(); }

	// The door's lock (0 none): Door_LockedRaise's arg 4, Generic_Door's arg 5.
	static int LockOf(Line l)
	{
		if (l.special == 13) return l.args[3];
		if (l.special == 202) return l.args[4];
		return 0;
	}

	// Open it as a player pressing Use would. A key door checks the key of the
	// one opening it: that's you (they open it with your key).
	void OpenDoor(Line l)
	{
		Actor by = LockOf(l) != 0 && Leader() != null ? Leader() : Actor(self);
		level.ExecuteSpecial(l.special, by, l, false, l.args[0], l.args[1], l.args[2], l.args[3], l.args[4]);
	}
	void TryOpenDoor(Vector2 goal)
	{
		Vector2 d = goal - pos.xy;
		if (d.Length() < 1) return;
		FLineTraceData t;
		if (!LineTrace(VectorAngle(d.x, d.y), DOOR_REACH, 0, TRF_THRUACTORS, Height * 0.5, data: t)) return;
		if (re_debugcams && t.HitLine != null && t.HitLine.special != 0) Console.Printf("PARTNER door check: line %d special %d side %d type %d", t.HitLine.Index(), t.HitLine.special, t.LineSide, t.HitType);
		if (t.HitType != TRACE_HitWall || t.HitLine == null || t.LineSide != Line.front) return;
		Line l = t.HitLine;
		if (!MayOpen(l)) return;
		Sector door = l.backsector;
		if (door == null || door.ceilingdata != null) return;                // already moving
		if (door.CenterCeiling() - door.CenterFloor() >= Height) return;   // already open
		if (re_debugcams) Console.Printf("PARTNER opens door: line %d special %d%s", l.Index(), l.special, LockOf(l) != 0 ? " (with your key)" : ((l.flags & Line.ML_SECRET) ? " (a secret door you found)" : ""));
		OpenDoor(l);
	}

	static bool MayOpen(Line l)
	{
		int s = l.special;
		// Door_Open, Door_Raise, Door_LockedRaise, Generic_Door (an opening kind)
		if (s != 11 && s != 12 && s != 13 && s != 202) return false;
		if (l.args[0] != 0 && !OnlyItsOwnDoor(l)) return false;   // tagged, and the tag reaches beyond this door
		if (s == 202 && (l.args[2] & 3) >= 2) return false;   // close-first kinds
		int lock = LockOf(l);
		let you = Leader();
		if (lock != 0 && (you == null || !you.CheckKeys(lock, false, true))) return false;   // a key door: only while you carry its key
		if (!(l.activation & SPAC_Use)) return false;         // only doors you open with Use
		if ((l.flags & Line.ML_SECRET) && !REPartnerHandler.SecretFound(l)) return false;   // looks like a wall: only once you've found it
		return true;
	}

	// Many doors in Doom's maps are tagged: the door line raises the sectors
	// with its tag. That's still just this door when the only sector with the
	// tag is the one right behind the line (the door itself). A tag that also
	// reaches any other sector would open something elsewhere: never.
	static bool OnlyItsOwnDoor(Line l)
	{
		if (l.backsector == null) return false;
		let it = level.CreateSectorTagIterator(l.args[0]);
		int n = 0, sec;
		while ((sec = it.Next()) >= 0)
		{
			if (level.sectors[sec] != l.backsector) return false;
			n++;
		}
		return n == 1;
	}

	// Standing where a door is moving would keep it open (or get squashed).
	bool InClosingDoor()
	{
		return CurSector != null && CurSector.ceilingdata != null;
	}

	Actor FindEnemy()
	{
		Actor best = null;
		double bestDist = FIGHT_RANGE;
		let it = BlockThingsIterator.Create(self, FIGHT_RANGE);
		while (it.Next())
		{
			let mo = it.thing;
			if (mo == self || !mo.bIsMonster || mo.bFriendly || !mo.bShootable || mo.health <= 0) continue;
			double d = Distance2D(mo);
			if (d >= bestDist || !CheckSight(mo)) continue;
			best = mo;
			bestDist = d;
		}
		return best;
	}

	// RE1-style: stand still, raise the weapon, fire when it's up.
	void Fight()
	{
		if (pos.z <= floorz + 1) Vel.XY = (0, 0);
		stuckTics = 0;
		double toward = AngleTo(enemy);
		Turn(toward, 10);
		aimTics++;
		if (cooldown > 0) cooldown--;
		if (level.maptime < fireUntil) return;          // the fire animation is playing
		if (aimTics <= Tics30(raiseFrames)) { PlayAnim('aim_raise', false); return; }
		// RE1's aim up / down, picked from where the enemy is
		double dz = (enemy.pos.z + enemy.Height * 0.5) - (pos.z + 44);
		int dir = dz > 40 ? 1 : ((enemy.pos.z + enemy.Height < pos.z + 24 || enemy.Height <= 24) ? 2 : 0);
		PlayAnim(dir == 1 ? 'aim_up_hold' : (dir == 2 ? 'aim_down_hold' : 'aim_hold'), true);
		if (cooldown > 0 || abs(DeltaAngle(Angle, toward)) > 10) return;

		// The shot hits the enemy directly: it can never hit the player.
		A_StartSound(fireSound, CHAN_WEAPON);
		A_AlertMonsters();
		let leader = REMain.Player();
		REAim.Hit(self, enemy, damage);
		class<Actor> blast = BlastClass();
		if (blast != null && enemy != null) Spawn(blast, enemy.pos + (0, 0, enemy.Height * 0.5), ALLOW_REPLACE);
		// Doom's monsters go after the player, not the (untouchable) partner.
		if (enemy != null && enemy.health > 0 && leader != null) enemy.target = leader;
		anim = 'None';
		PlayAnim(dir == 1 ? 'fire_up' : (dir == 2 ? 'fire_down' : 'fire'), false);
		fireUntil = level.maptime + Tics30(fireFrames);
		if (weaponId == RE_ITEM_SHOTGUN) pumpAt = level.maptime + Tics30(12);   // the pump, like the player's
		cooldown = Tics30(fireFrames) + 2;
		if (IsPoisoned()) cooldown += 35;   // poisoned: a second more between shots
	}

	// Count the time the partner is off the player's camera.
	void CheckCamera(Actor leader, double dist)
	{
		let cam = REFixedCamera(players[REMain.Number()].camera);
		if (cam == null || dist < 384 || cam.ViewScore(self) > 0) offCamTics = 0;
		else if (stuckTics > 0) offCamTics++;            // off camera and not getting closer
		else offCamTics = max(0, offCamTics - 1);       // off camera but on her way: no hurry
	}

	// Step onto the player's trail just behind them (or right behind them),
	// only to a spot the player can't see. False if there is none.
	bool CatchUp(Actor leader)
	{
		stuckTics = 0; offCamTics = 0; lastGoalDist = 1e9;
		Vector3 old = pos;
		for (int i = trailX.Size() - 1; i >= 0; i--)
		{
			Vector3 p = (trailX[i], trailY[i], trailZ[i]);
			double d = (p.xy - leader.pos.xy).Length();
			if (d < 48 || d > 192 || abs(p.z - leader.pos.z) > 24) continue;
			if (TryTeleport(p, leader)) { while (trailX.Size() > i + 1) PopTrail(); return true; }
		}
		for (int a = 0; a < 360; a += 45)
		{
			Vector2 at = leader.pos.xy + Actor.AngleToVector(leader.Angle + 180 + a, 56);
			if (TryTeleport((at.x, at.y, leader.pos.z), leader)) return true;
		}
		SetOrigin(old, false);
		return false;
	}

	bool TryTeleport(Vector3 p, Actor leader)
	{
		SetOrigin(p, false);
		SetZ(floorz);
		if (abs(pos.z - leader.pos.z) > 24 || !TestMobjLocation() || !CheckSight(leader, SF_IGNOREVISIBILITY)) return false;
		if (InLeaderView(leader)) return false;   // never appear in front of the player
		Vel = (0, 0, 0);
		Angle = AngleTo(leader);
		trailX.Clear(); trailY.Clear(); trailZ.Clear();
		return true;
	}
}

class REPartnerJill : REPartner
{
	Default
	{
		Tag "Jill";
		REPartner.Character "jill";
		REPartner.WeaponId RE_ITEM_BERETTA;   // her Beretta, full (15)
		REPartner.Rounds 15;
	}
}

class REPartnerChris : REPartner
{
	Default
	{
		Tag "Chris";
		REPartner.Character "chris";
		REPartner.WeaponId RE_ITEM_SHOTGUN;   // his shotgun, full (7)
		REPartner.Rounds 7;
	}
}

// Every map start (not a loaded game): the partner appears just behind you.
// It also remembers the secret doors you've opened on this map (saved with
// the game): the partner may open those again (REPartner.MayOpen).
class REPartnerHandler : EventHandler
{
	Array<int> secretDoorsFound;   // the door sectors

	override void WorldLineActivated(WorldEvent e)
	{
		Line l = e.ActivatedLine;
		if (l == null || e.Thing == null || e.Thing.player == null) return;
		if (!(l.flags & Line.ML_SECRET) || l.backsector == null) return;
		int s = l.backsector.Index();
		if (secretDoorsFound.Find(s) == secretDoorsFound.Size()) secretDoorsFound.Push(s);
	}

	static bool SecretFound(Line l)
	{
		let me = REPartnerHandler(EventHandler.Find("REPartnerHandler"));
		return me != null && l.backsector != null && me.secretDoorsFound.Find(l.backsector.Index()) != me.secretDoorsFound.Size();
	}

	override void WorldLoaded(WorldEvent e)
	{
		if (e.IsSaveGame || re_partner == 0 || !re_ai_partner) return;
		if (REMain.Online()) return;   // online co-op: the second character is a real player, no AI partner
		let pmo = REMain.Player();
		if (pmo == null) return;
		bool youAreChris = pmo is "REChrisPlayer";
		class<Actor> who = null;
		if (re_partner == 1 && youAreChris) who = "REPartnerJill";
		if (re_partner == 2 && !youAreChris) who = "REPartnerChris";
		if (who == null) return;
		let p = REPartner(Actor.Spawn(who, pmo.pos));
		if (p == null) return;
		// the gun (and spare ammo) they had on the last map
		let inv = REInventory(pmo.FindInventory("REInventory"));
		if (inv != null && inv.partnerGunKept && inv.partnerGunOf == p.reChar && REItemInfo.IsGun(inv.partnerGunId))
		{
			p.weaponId = inv.partnerGunId;
			p.rounds = inv.partnerGunRounds;
			p.spareAmmo = inv.partnerSpare;
		}
		if (!Place(p, pmo)) p.Destroy();
	}

	// Just behind the player (then to either side, then a little further),
	// on the same floor, in sight of them, never standing on an item or in
	// liquid / on a hurting floor. With 'cam' (REStartLayoutHandler, once the
	// opening camera is chosen): also not right in front of its lens.
	static bool Place(Actor p, Actor pmo, Actor cam = null)
	{
		Vector3 old = p.pos;
		// pass 0: well clear of items; pass 1: just not on one (small rooms)
		for (int pass = 0; pass < 2; pass++)
		{
			// then more spots all round, a little further out each time (small rooms)
			for (int i = 0; i < 128; i++)
			{
				double dist, ang;
				if (i < 16) { dist = i < 8 ? 56 : 96; ang = pmo.Angle + 180 + (((i % 8) + 1) / 2) * 45 * ((i % 2) * 2 - 1); }
				else { int k = i - 16; dist = 44 + (k / 16) * 20; ang = pmo.Angle + 180 + (k % 16) * 22.5; }
				Vector2 at = pmo.pos.xy + Actor.AngleToVector(ang, dist);
				if (!level.IsPointInLevel((at.x, at.y, pmo.pos.z))) continue;
				p.SetOrigin((at.x, at.y, pmo.pos.z), false);
				p.SetZ(p.floorz);
				if (abs(p.pos.z - pmo.pos.z) <= 24 && p.TestMobjLocation() && p.CheckSight(pmo) && REItemBoxHandler.SafeSpot(p)
					&& !REItemBoxHandler.PickupNear(p.pos.xy, p.radius + (pass == 0 ? 16 : 4))
					&& (cam == null || (!NearLens(p, cam) && !HidesFromCamera(p, pmo, cam))))
				{
					p.Angle = pmo.Angle;
					p.ClearInterpolation();
					return true;
				}
			}
		}
		p.SetOrigin(old, false);
		return false;
	}

	// Standing between the camera and the player, the item box or a typewriter.
	static bool HidesFromCamera(Actor p, Actor pmo, Actor cam)
	{
		if (RECameraHandler.PartnerBlocks(p, cam.pos, pmo.pos + (0, 0, pmo.Height * 0.5), pmo)) return true;
		for (int k = 0; k < 2; k++)
		{
			let it = ThinkerIterator.Create(k == 0 ? 'REItemBoxActor' : 'RETypewriter');
			Actor a;
			while (a = Actor(it.Next()))
				if (a.Distance2D(pmo) < 400 && REItemBoxHandler.Between(p, cam, a)) return true;
		}
		return false;
	}

	// Right at the lens, or cut off at the edge of the picture: neither wholly
	// in the picture nor out of it (a big half figure in the corner).
	static bool NearLens(Actor p, Actor cam)
	{
		Vector3 d = p.pos + (0, 0, p.Height * 0.5) - cam.pos;
		double fwd = d.x * cos(cam.Angle) + d.y * sin(cam.Angle);
		if (fwd <= -p.radius) return false;                     // behind the camera
		if (d.Length() < 96) return true;
		let fc = REFixedCamera(cam);
		if (fc == null || fc.ViewScore(p) > 0) return false;   // wholly in the picture
		// the picture is wider than the 4:3 lens on a wide screen: a margin
		double side = abs(Actor.DeltaAngle(cam.Angle, VectorAngle(d.x, d.y)));
		return side < fc.CameraFOV * 0.5 * 1.4 + 12;
	}

	// Settings > Gameplay > AI partner off (re_ai_partner): a partner already
	// in the level leaves at once.
	override void WorldTick()
	{
		if (re_ai_partner || level.maptime % 8) return;
		let it = ThinkerIterator.Create("REPartner");
		Actor p;
		while (p = Actor(it.Next())) p.Destroy();
	}
}
