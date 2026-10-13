// ---------------------------------------------------------------------------
// RE_Continue.zs - dying works like RE1's Game Over > Continue.
//
// On the death screen, Space or E (RE_Input.zs reads the keys themselves, so
// they work however keys are bound; a key bound to Action works too):
//   - saved on this level (any save mode: a Normal save, F6, a typewriter, a
//     Classic RE ribbon save) or loaded a game since you got here: back to
//     that most recent save (GZDoom keeps its file: its "last save");
//   - otherwise: the level starts again, and you have exactly what you had
//     when you entered it: item slots and their counts, the weapon in your
//     hands and its rounds, All Weapons' per-gun rounds, health, armor,
//     poison, the lighter / chemical time left, the partner's poison.
// Continuing never uses an Ink Ribbon. The AI partner comes back with you:
// as saved, or (a level restart) with the gun and spare ammo they had when
// you entered the level.
// In a network game (each player on their own PC) a game can't be reloaded
// for one player: a player who dies respawns at the start with their own
// entry snapshot.
//
// Not saved with games (a StaticEventHandler): it remembers across loading
// and level changes for this session.
// ---------------------------------------------------------------------------

class REEntrySnapshot
{
	bool valid;
	int health;
	int numSlots, equippedSlot;
	int slotId[8], slotQty[8];
	int cheatRounds[8];
	bool cheatFilled, partnerPoisoned;
	bool partnerGunKept;              // the partner's gun (RE_Inventory.zs partnerGun*)
	String partnerGunOf;
	int partnerGunId, partnerGunRounds, partnerSpare;
	int rounds;                       // RELoadedRounds
	class<Weapon> held;               // the weapon in hand
	Array<class<Weapon> > weapons;    // the RE weapons carried
	int poison;
	// BasicArmor
	int armorAmount, armorMax, armorMaxAbsorb, armorMaxFullAbsorb, armorBonus, armorActual;
	double armorSave;
	Name armorType;
	// powerups (the lighter, the chemical) and their time left
	Array<class<Inventory> > powerups;
	Array<int> powerupTics;
}

class REContinueHandler : StaticEventHandler
{
	bool savedThisVisit;   // saved or loaded a game since this level was entered
	bool restarting;       // the next level start is a Continue restart: put the snapshot back
	bool continuing;       // a Continue is under way (one press is enough)
	REEntrySnapshot snaps[MAXPLAYERS];

	static clearscope REContinueHandler Get() { return REContinueHandler(StaticEventHandler.Find("REContinueHandler")); }

	// The death screen's lines (RE_Hud.zs).
	static clearscope String DeathLine()
	{
		let me = Get();
		bool save = me != null && me.savedThisVisit && !multiplayer;
		return save ? "Press SPACE or E to continue from your last save" : "Press SPACE or E to continue from the start of this level";
	}

	override void WorldLoaded(WorldEvent e)
	{
		bool wasContinuing = continuing;
		continuing = false;
		if (e.IsSaveGame)
		{
			// a loaded game (from Load Game, or a Continue back to a save)
			savedThisVisit = true;
			restarting = false;
			// The on-screen message is saved with the game: one still showing
			// when the save was made ("You picked up the INK RIBBON.", "You used
			// an INK RIBBON.") would show again now, though nothing was picked up
			// or used. Loading starts with no message.
			for (int p = 0; p < MAXPLAYERS; p++)
			{
				if (!playeringame[p] || players[p].mo == null) continue;
				let inv = REInventory(players[p].mo.FindInventory("REInventory"));
				if (inv == null) continue;
				inv.message = "";
				inv.messageTics = 0;
				if (wasContinuing) inv.ShowMessage("Continue: your last save.");
			}
			return;
		}
		savedThisVisit = false;
		for (int p = 0; p < MAXPLAYERS; p++)
		{
			if (!playeringame[p] || players[p].mo == null) continue;
			if (restarting && snaps[p] != null && snaps[p].valid) Restore(p);
			else Take(p);
		}
		if (re_debugcams) Console.Printf("CONTINUE %s: %s", level.MapName, restarting ? "level restarted with the entry snapshot" : "entry snapshot taken");
		restarting = false;
	}

	override void NetworkProcess(ConsoleEvent e)
	{
		if (e.Name ~== "re_saved") { savedThisVisit = true; return; }   // RE_Typewriter.zs
		if (!(e.Name ~== "re_continue")) return;
		int p = e.Player;
		if (p < 0 || !playeringame[p] || players[p].mo == null) return;
		if (players[p].playerstate != PST_DEAD && players[p].mo.health > 0) return;
		if (multiplayer)
		{
			// each player on their own: respawn, then their snapshot (PlayerRespawned)
			players[p].playerstate = PST_REBORN;
			return;
		}
		if (continuing) return;
		continuing = true;
		if (savedThisVisit)
		{
			// GZDoom's restart loads its last save: the one made or loaded here
			if (re_debugcams) Console.Printf("CONTINUE %s: back to the last save", level.MapName);
			players[p].playerstate = PST_REBORN;
			return;
		}
		if (re_debugcams) Console.Printf("CONTINUE %s: restarting the level", level.MapName);
		restarting = true;
		level.ChangeLevel(level.MapName, 0, CHANGELEVEL_NOINTERMISSION | CHANGELEVEL_RESETINVENTORY | CHANGELEVEL_RESETHEALTH);
	}

	// Network games: a player who respawned gets their entry snapshot.
	override void PlayerRespawned(PlayerEvent e)
	{
		if (multiplayer && snaps[e.PlayerNumber] != null && snaps[e.PlayerNumber].valid) Restore(e.PlayerNumber);
	}

	// --- the snapshot ------------------------------------------------------------

	void Take(int p)
	{
		let pmo = players[p].mo;
		let inv = REInventory(pmo.FindInventory("REInventory"));
		let s = new("REEntrySnapshot");
		snaps[p] = s;
		if (inv == null) return;
		s.valid = true;
		s.health = pmo.health;
		s.numSlots = inv.numSlots;
		s.equippedSlot = inv.equippedSlot;
		for (int i = 0; i < 8; i++) { s.slotId[i] = inv.slotId[i]; s.slotQty[i] = inv.slotQty[i]; s.cheatRounds[i] = inv.cheatRounds[i]; }
		s.cheatFilled = inv.cheatFilled;
		s.partnerPoisoned = inv.partnerPoisoned;
		s.partnerGunKept = inv.partnerGunKept; s.partnerGunOf = inv.partnerGunOf;
		s.partnerGunId = inv.partnerGunId; s.partnerGunRounds = inv.partnerGunRounds; s.partnerSpare = inv.partnerSpare;
		s.rounds = pmo.CountInv("RELoadedRounds");
		let w = players[p].PendingWeapon != WP_NOCHANGE ? players[p].PendingWeapon : players[p].ReadyWeapon;
		s.held = w != null ? w.GetClass() : null;
		s.poison = pmo.CountInv("REPoison");
		for (let it = pmo.Inv; it != null; it = it.Inv)
		{
			if (it is "REWeapon") s.weapons.Push((class<Weapon>)(it.GetClass()));
			let pw = Powerup(it);
			if (pw != null) { s.powerups.Push(pw.GetClass()); s.powerupTics.Push(pw.EffectTics); }
		}
		let ba = BasicArmor(pmo.FindInventory("BasicArmor"));
		if (ba != null)
		{
			s.armorAmount = ba.Amount; s.armorMax = ba.MaxAmount; s.armorSave = ba.SavePercent;
			s.armorMaxAbsorb = ba.MaxAbsorb; s.armorMaxFullAbsorb = ba.MaxFullAbsorb; s.armorBonus = ba.BonusCount;
			s.armorActual = ba.ActualSaveAmount; s.armorType = ba.ArmorType;
		}
	}

	void Restore(int p)
	{
		let s = snaps[p];
		let pmo = players[p].mo;
		let inv = REInventory(pmo.FindInventory("REInventory"));
		if (inv == null) return;
		// weapons: exactly the ones carried at the level's start
		for (let it = pmo.Inv; it != null; )
		{
			let next = it.Inv;
			if (it is "REWeapon" && s.weapons.Find((class<Weapon>)(it.GetClass())) == s.weapons.Size()) it.Destroy();
			it = next;
		}
		for (int i = 0; i < s.weapons.Size(); i++) if (pmo.FindInventory(s.weapons[i]) == null) pmo.GiveInventory(s.weapons[i], 1);
		// the item slots
		for (int i = 0; i < 8; i++) { inv.slotId[i] = s.slotId[i]; inv.slotQty[i] = s.slotQty[i]; inv.cheatRounds[i] = s.cheatRounds[i]; }
		inv.equippedSlot = s.equippedSlot;
		inv.cheatFilled = s.cheatFilled;
		inv.partnerPoisoned = s.partnerPoisoned;
		inv.partnerGunKept = s.partnerGunKept; inv.partnerGunOf = s.partnerGunOf;
		inv.partnerGunId = s.partnerGunId; inv.partnerGunRounds = s.partnerGunRounds; inv.partnerSpare = s.partnerSpare;
		// the partner may already be back (REPartnerHandler): give them that gun now
		let partner = REPartner.Find();
		if (partner != null && s.partnerGunKept && s.partnerGunOf == partner.reChar && REItemInfo.IsGun(s.partnerGunId))
		{
			partner.SetWeapon(s.partnerGunId, s.partnerGunRounds);
			partner.spareAmmo = s.partnerSpare;
		}
		pmo.SetInventory("RELoadedRounds", s.rounds);
		inv.heldClass = s.held;
		inv.heldRounds = s.rounds;
		if (s.held != null)
		{
			let w = Weapon(pmo.FindInventory(s.held));
			if (w != null) players[p].PendingWeapon = w;
		}
		// health, poison, armor, powerups
		pmo.health = players[p].health = s.health;
		pmo.SetInventory("REPoison", s.poison);
		let ba = BasicArmor(pmo.FindInventory("BasicArmor"));
		if (ba != null)
		{
			ba.Amount = s.armorAmount; ba.MaxAmount = s.armorMax; ba.SavePercent = s.armorSave;
			ba.MaxAbsorb = s.armorMaxAbsorb; ba.MaxFullAbsorb = s.armorMaxFullAbsorb; ba.BonusCount = s.armorBonus;
			ba.ActualSaveAmount = s.armorActual; ba.ArmorType = s.armorType;
		}
		for (int i = 0; i < s.powerups.Size(); i++)
		{
			pmo.GiveInventory(s.powerups[i], 1);
			let pw = Powerup(pmo.FindInventory(s.powerups[i]));
			if (pw != null) pw.EffectTics = s.powerupTics[i];
		}
		inv.ShowMessage("Continue: the start of this level.");
	}
}
