// ---------------------------------------------------------------------------
// RE_Inventory.zs - Jill's 8 item slots and what you can do with them.
//
// RE1 keeps the inventory as a short list of (item id, quantity) pairs
// (reference/re1-decomp/src/game/BioCard.h). We do the same. This object is
// carried by the player; the inventory screen (RE_InventoryMenu.zs) and the
// item box screen (RE_ItemBox.zs) only read it, and ask for changes through
// REGameHandler below.
//
// For a gun, the quantity is the rounds loaded in it. While a gun is in her
// hands, those rounds live in the RELoadedRounds ammo item (RE_Items.zs).
// ---------------------------------------------------------------------------

class REInventory : Inventory
{
	int numSlots;
	int slotId[8];
	int slotQty[8];
	int equippedSlot;    // -1 = nothing equipped

	String message;      // last message, e.g. "You picked up the CLIP."
	int messageTics;     // how long the message stays on screen
	int messageId;       // goes up by one for every new message

	// The AI partner, as last reported by them (RE_Partner.zs), for the
	// inventory screen's GIVE TO ... command.
	String partnerName;  // "Jill" / "Chris"
	bool partnerNear;    // close enough to be handed a gun
	int partnerSeenTic;  // level.maptime of the last report
	bool partnerPoisoned; // the partner is poisoned (RE_Poison.zs); kept here so it carries over
	// The partner's gun, its rounds and their spare ammo (Partner pickups), kept
	// here too: a new partner appears at every map start (RE_Partner.zs
	// REPartnerHandler) and gets them back.
	bool partnerGunKept;
	String partnerGunOf;  // whose ("jill" / "chris")
	int partnerGunId, partnerGunRounds, partnerSpare;

	// All Weapons cheat: the rounds left in each of its guns that isn't the
	// one from your slots (they share RELoadedRounds while in your hands, so
	// each one's count is put away here when you switch). Index: CheatIndex.
	int cheatRounds[8];
	class<Weapon> heldClass;   // the weapon in hand at the last tic
	int heldRounds;            // its rounds then (while no switch was under way)
	bool cheatFilled;          // cheatRounds set up (a game saved before they existed has them all 0)

	Default
	{
		+INVENTORY.UNDROPPABLE
		+INVENTORY.UNTOSSABLE
		+INVENTORY.UNCLEARABLE
		Inventory.MaxAmount 1;
	}

	override void BeginPlay()
	{
		Super.BeginPlay();
		// RE1 SetInitialItems (GameStart.cpp): Jill has 8 slots and starts
		// with a knife, a Beretta with 15 rounds and a First Aid Spray.
		// Nothing is equipped yet.
		numSlots = 8;
		equippedSlot = -1;
		SetSlot(0, RE_ITEM_KNIFE, 0);
		SetSlot(1, RE_ITEM_BERETTA, 15);
		SetSlot(2, RE_ITEM_FIRST_AID_SPRAY, 1);
	}

	override void DoEffect()
	{
		Super.DoEffect();
		if (messageTics > 0) messageTics--;

		// Copy the rounds in her hands back so the slot stays right (with the
		// All Weapons cheat on, only while the gun in her hands is the one in
		// the slot).
		if (owner != null && IsEquippedGun(equippedSlot) && owner.player != null)
		{
			let w = owner.player.ReadyWeapon;
			if (!re_cheat_weapons || (w != null && w.GetClass() == REItemInfo.WeaponClass(slotId[equippedSlot])))
				slotQty[equippedSlot] = owner.CountInv("RELoadedRounds");
		}
		TrackCheatRounds();
	}

	// All Weapons cheat: switching between its guns (number keys, wheel),
	// each keeps its own rounds: the one put away keeps what it had, the one
	// taken out gets what it had.
	void TrackCheatRounds()
	{
		if (owner == null || owner.player == null) return;
		let w = owner.player.ReadyWeapon;
		class<Weapon> now = w != null ? w.GetClass() : null;
		// a game saved with All Weapons on before each gun kept its own rounds:
		// every cheat gun full, the one in hand too
		if (re_cheat_weapons && !cheatFilled)
		{
			for (int k = 0; k < 7; k++) cheatRounds[k] = 0;
			static const class<Weapon> guns[] = { "REKnife", "REHandgun", "REShotgun", "REMagnum", "REGrenadeLauncher", "RERocketLauncher", "REFlamethrower" };
			for (int k = 0; k < guns.Size(); k++) FillCheatGun(guns[k]);
			if (now != null && !IsSlotWeapon(now) && REItemInfo.IsGun(REItemInfo.IdForWeapon(now)) && owner.CountInv("RELoadedRounds") == 0)
				owner.SetInventory("RELoadedRounds", cheatRounds[CheatIndex(now)]);
			heldClass = now;
		}
		if (now != heldClass)
		{
			if (re_cheat_weapons)
			{
				int was = CheatIndex(heldClass);
				if (was >= 0 && !IsSlotWeapon(heldClass)) cheatRounds[was] = heldRounds;
				int k = CheatIndex(now);
				bool gun = REItemInfo.IsGun(REItemInfo.IdForWeapon(now));
				if (IsSlotWeapon(now)) { if (gun) owner.SetInventory("RELoadedRounds", slotQty[equippedSlot]); }
				else if (k >= 0 && gun) owner.SetInventory("RELoadedRounds", cheatRounds[k]);
			}
			heldClass = now;
		}
		if (now != null && owner.player.PendingWeapon == WP_NOCHANGE) heldRounds = owner.CountInv("RELoadedRounds");
	}

	// The weapon equipped from the item slots?
	bool IsSlotWeapon(class<Weapon> wc)
	{
		return wc != null && equippedSlot >= 0 && REItemInfo.WeaponClass(slotId[equippedSlot]) == wc;
	}

	static int CheatIndex(class<Weapon> wc)
	{
		static const class<Weapon> cheatGuns[] = { "REKnife", "REHandgun", "REShotgun", "REMagnum", "REGrenadeLauncher", "RERocketLauncher", "REFlamethrower" };
		for (int i = 0; i < cheatGuns.Size(); i++) if (cheatGuns[i] == wc) return i;
		return -1;
	}

	// A full load in one of the cheat's guns (when it's given).
	void FillCheatGun(class<Weapon> wc)
	{
		int k = CheatIndex(wc);
		if (k < 0) return;
		int id = REItemInfo.IdForWeapon(wc);
		cheatRounds[k] = REItemInfo.IsGun(id) ? REItemInfo.MaxQuantity(id) : 0;
		cheatFilled = true;
	}

	// --- small helpers -------------------------------------------------------

	bool IsEquippedGun(int s)
	{
		return s >= 0 && s == equippedSlot && REItemInfo.IsGun(slotId[s]);
	}

	void SetSlot(int s, int id, int qty)
	{
		slotId[s] = id;
		slotQty[s] = qty;
		if (owner != null && IsEquippedGun(s))
		{
			owner.SetInventory("RELoadedRounds", qty);
		}
	}

	void ClearSlot(int s)
	{
		if (s == equippedSlot) Unequip();
		slotId[s] = RE_ITEM_NONE;
		slotQty[s] = 0;
	}

	int FindFreeSlot()
	{
		for (int s = 0; s < numSlots; s++)
		{
			if (slotId[s] == RE_ITEM_NONE) return s;
		}
		return -1;
	}

	bool ValidSlot(int s)
	{
		return s >= 0 && s < numSlots && slotId[s] != RE_ITEM_NONE;
	}

	bool HasItem(int id)
	{
		for (int s = 0; s < numSlots; s++)
		{
			if (slotId[s] == id) return true;
		}
		return false;
	}

	// How many of an item she carries, over all slots.
	int CountItem(int id)
	{
		int n = 0;
		for (int s = 0; s < numSlots; s++) if (slotId[s] == id) n += slotQty[s];
		return n;
	}

	// Uses up one of a stackable item (an Ink Ribbon). False if there is none.
	bool UseOne(int id)
	{
		for (int s = numSlots - 1; s >= 0; s--)
		{
			if (slotId[s] != id) continue;
			if (slotQty[s] > 1) SetSlot(s, id, slotQty[s] - 1);
			else ClearSlot(s);
			return true;
		}
		return false;
	}

	// The slot holding this gun (the bazooka counts whatever it's loaded with).
	int FindGun(int id)
	{
		for (int s = 0; s < numSlots; s++)
		{
			int have = slotId[s];
			if (have == id || (REItemInfo.IsBazooka(have) && REItemInfo.IsBazooka(id))) return s;
		}
		return -1;
	}

	void ShowMessage(String text)
	{
		message = text;
		messageTics = 35 * 3;
		messageId++;
	}

	// --- picking up ----------------------------------------------------------

	// Puts 'qty' of an item into the slots. Ammo first tops up partly filled
	// stacks of the same kind (up to RE1's per-slot limit). Returns what
	// didn't fit.
	int Store(int id, int qty)
	{
		if (REItemInfo.IsStackable(id))
		{
			int cap = REItemInfo.MaxQuantity(id);
			for (int s = 0; s < numSlots && qty > 0; s++)
			{
				if (slotId[s] != id || slotQty[s] >= cap) continue;
				int add = min(qty, cap - slotQty[s]);
				SetSlot(s, id, slotQty[s] + add);
				qty -= add;
			}
			while (qty > 0)
			{
				int s = FindFreeSlot();
				if (s < 0) break;
				int add = min(qty, cap);
				SetSlot(s, id, add);
				qty -= add;
			}
			return qty;
		}
		int s = FindFreeSlot();
		if (s < 0) return max(qty, 1);
		SetSlot(s, id, qty);
		return 0;
	}

	// Items %: a map item taken counts as found (RE_Records.zs).
	void CountTaken(REPickup p)
	{
		if (!p.bCountItem) return;
		p.bCountItem = false;
		level.found_items++;
		if (owner != null && owner.player != null) owner.player.itemcount++;
	}

	void TakePickup(REPickup p)
	{
		if (owner != null) p.OnUse(owner);
		int id = p.itemId;
		int qty = p.itemQty;

		// A second flamethrower: its fuel tops up the one carried (RE1 swaps the
		// empty one for the full one; no fuel item exists to refill it).
		if (id == RE_ITEM_FLAMETHROWER && FindGun(id) >= 0)
		{
			int s = FindGun(id);
			int have = IsEquippedGun(s) && owner != null ? owner.CountInv("RELoadedRounds") : slotQty[s];
			if (have >= qty) { ShowMessage("You already have a full FLAMETHROWER."); return; }
			SetSlot(s, id, qty);
			ShowMessage("You refilled the FLAMETHROWER's fuel.");
			if (owner != null) owner.A_StartSound("misc/i_pkup", CHAN_ITEM);
			CountTaken(p);
			p.Destroy();
			return;
		}
		// A second knife is no use: it stays where it is.
		if (id == RE_ITEM_KNIFE && HasItem(RE_ITEM_KNIFE))
		{
			ShowMessage("You already have a KNIFE.");
			return;
		}
		// A second copy of a gun she already has is worth its rounds.
		if (REItemInfo.IsGun(id) && FindGun(id) >= 0)
		{
			int ammo = REItemInfo.AmmoFor(id);
			if (ammo == RE_ITEM_NONE)
			{
				ShowMessage(String.Format("You already have the %s.", REItemInfo.GetName(id)));
				return;
			}
			id = ammo;
		}

		int left = Store(id, qty);
		if (REItemInfo.IsStackable(id) ? left >= qty : left > 0)
		{
			ShowMessage("You can't carry any more items.");
			return;
		}
		ShowMessage(String.Format("You picked up the %s.", REItemInfo.GetName(id)));
		if (owner != null) owner.A_StartSound("misc/i_pkup", CHAN_ITEM);
		if (REItemInfo.IsStackable(id) && left > 0)
		{
			p.itemQty = left;   // the rest stays on the floor
			ShowMessage(String.Format("You picked up some %s. No room for the rest.", REItemInfo.GetName(id)));
			return;
		}
		CountTaken(p);
		p.Destroy();
	}

	// --- GIVE TO the partner ------------------------------------------------

	int CountWeapons()
	{
		int n = 0;
		for (int s = 0; s < numSlots; s++) if (REItemInfo.IsWeapon(slotId[s])) n++;
		return n;
	}

	// A blue herb or a mix with one cures a poisoned partner (used up).
	// Hands the gun in slot s (and its loaded rounds) to the AI partner, who
	// gives back the weapon they had: it goes into the same slot (equipped if
	// the gun you gave was), or at your feet if there's somehow no room.
	void GiveToPartner(int s)
	{
		if (!ValidSlot(s) || owner == null || owner.health <= 0) return;
		int id = slotId[s];
		let partner = REPartner.Find();
		if (partner == null) return;
		partner.ReportToLeader(owner, partner.Distance2D(owner));
		if (!partnerNear) { ShowMessage(String.Format("%s is too far away.", partnerName)); return; }
		// a blue herb (or a mix with one) for a poisoned partner: cures them
		if ((REItemInfo.HealFlags(id) & 0xF0) != 0)
		{
			if (!partnerPoisoned) { ShowMessage(String.Format("%s isn't poisoned.", partner.GetTag())); return; }
			partnerPoisoned = false;
			ClearSlot(s);
			ShowMessage(String.Format("You gave %s the %s.\nThe poison is gone.", partner.GetTag(), REItemInfo.GetName(id)));
			owner.A_StartSound("misc/i_pkup", CHAN_ITEM);
			return;
		}
		if (!REItemInfo.IsGun(id)) return;
		if (id == RE_ITEM_FLAMETHROWER) { ShowMessage(String.Format("%s can't use the flamethrower.", partner.GetTag())); return; }   // RE1: Chris only
		if (SameGun(partner.weaponId, id)) { ShowMessage(String.Format("%s already has a %s.", partner.GetTag(), REItemInfo.GetName(partner.weaponId))); return; }
		if (CountWeapons() <= 1) { ShowMessage("You can't give away your last weapon."); return; }

		bool wasEquipped = s == equippedSlot;
		if (IsEquippedGun(s)) slotQty[s] = owner.CountInv("RELoadedRounds");
		int qty = slotQty[s];
		int oldId = partner.weaponId, oldQty = partner.rounds;
		int spare = partner.spareAmmo;   // ammo she picked up for it (Partner pickups)
		int spareId = REItemInfo.AmmoFor(oldId);
		if (spareId == RE_ITEM_NONE) spare = 0;
		ClearSlot(s);
		partner.SetWeapon(id, qty);
		partner.spareAmmo = 0;   // the new gun takes other ammo

		// Two lines, like a pickup message: what you gave, and what they gave you back.
		// (The partner carries one gun at a time: REPartner.weaponId.)
		String who = partner.GetTag();
		String their = partner.reChar == "chris" ? "his" : "her";
		String msg = String.Format("You gave %s the %s.", who, REItemInfo.GetName(id));
		// No gun to hand back: just the first line.
		if (!REItemInfo.IsGun(oldId)) { }
		// Already carrying that kind of gun: its rounds come back as ammo, like
		// picking up a second copy (TakePickup).
		else if (FindGun(oldId) >= 0)
		{
			int ammo = REItemInfo.AmmoFor(oldId);
			int total = oldQty + spare;   // the rounds in it and her spare ones, together
			if (ammo != RE_ITEM_NONE && total > 0)
			{
				StoreOrDrop(ammo, total);
				msg = msg .. String.Format("\n%s gave you %s %s's %d rounds.", who, their, REItemInfo.GetName(oldId), total);
			}
		}
		else if (Store(oldId, oldQty) == 0)
		{
			if (spare > 0)
			{
				StoreOrDrop(spareId, spare);
				msg = msg .. String.Format("\n%s gave you %s %s and %d %s.", who, their, REItemInfo.GetName(oldId), spare, REItemInfo.GetName(spareId));
			}
			else msg = msg .. String.Format("\n%s gave you %s %s.", who, their, REItemInfo.GetName(oldId));
			// Store puts it in the first free slot; move it into the one just emptied.
			int got = FindGun(oldId);
			if (got >= 0 && got != s && slotId[s] == RE_ITEM_NONE)
			{
				slotId[s] = slotId[got]; slotQty[s] = slotQty[got];
				slotId[got] = RE_ITEM_NONE; slotQty[got] = 0;
				got = s;
			}
			if (wasEquipped && got >= 0) EquipSlot(got);
		}
		else
		{
			let drop = REPickup(Actor.Spawn(PickupClass(oldId), owner.pos));
			if (drop != null) { drop.itemId = oldId; drop.itemQty = oldQty; drop.ClearCounters(); drop.bDropped = true; }   // yours: not a map item
			if (spare > 0)
			{
				let ammoDrop = REPickup(Actor.Spawn("REClipPickup", owner.pos));
				if (ammoDrop != null) { ammoDrop.itemId = spareId; ammoDrop.itemQty = spare; ammoDrop.ClearCounters(); }
				msg = msg .. String.Format("\n%s dropped %s %s and %d %s at your feet.", who, their, REItemInfo.GetName(oldId), spare, REItemInfo.GetName(spareId));   // no room
			}
			else msg = msg .. String.Format("\n%s dropped %s %s at your feet.", who, their, REItemInfo.GetName(oldId));   // no room
		}
		ShowMessage(msg);
		owner.A_StartSound("misc/i_pkup", CHAN_ITEM);
	}

	// The same gun (any bazooka counts as the bazooka, whatever it's loaded with).
	static bool SameGun(int a, int b)
	{
		return a == b || (REItemInfo.IsBazooka(a) && REItemInfo.IsBazooka(b));
	}

	// Ammo into the slots; what doesn't fit is left at your feet.
	void StoreOrDrop(int id, int qty)
	{
		int left = Store(id, qty);
		if (left <= 0 || owner == null) return;
		let drop = REPickup(Actor.Spawn("REClipPickup", owner.pos));
		if (drop != null) { drop.itemId = id; drop.itemQty = left; drop.ClearCounters(); }   // yours: not a map item
	}

	// All Weapons cheat: the gun in hand (from the cheat, not a slot) goes to
	// the partner with a full load. You keep yours (with the rounds it has),
	// and the partner's old weapon is simply dropped (not traded back).
	void GiveCheatWeaponToPartner()
	{
		if (owner == null || owner.player == null || owner.health <= 0 || !re_cheat_weapons) return;
		let held = owner.player.ReadyWeapon;
		let partner = REPartner.Find();
		if (held == null || partner == null) return;
		int id = REItemInfo.IdForWeapon(held.GetClass());
		if (!REItemInfo.IsGun(id)) return;
		if (id == RE_ITEM_FLAMETHROWER) { ShowMessage(String.Format("%s can't use the flamethrower.", partner.GetTag())); return; }   // RE1: Chris only
		partner.ReportToLeader(owner, partner.Distance2D(owner));
		if (!partnerNear) { ShowMessage(String.Format("%s is too far away.", partnerName)); return; }
		if (SameGun(partner.weaponId, id)) { ShowMessage(String.Format("%s already has a %s.", partner.GetTag(), REItemInfo.GetName(partner.weaponId))); return; }
		// her spare ammo for the old gun (Partner pickups) comes to you
		int spareId = REItemInfo.AmmoFor(partner.weaponId), spare = partner.spareAmmo;
		partner.SetWeapon(id, REItemInfo.MaxQuantity(id));
		partner.spareAmmo = 0;
		if (spare > 0 && spareId != RE_ITEM_NONE)
		{
			StoreOrDrop(spareId, spare);
			ShowMessage(String.Format("You gave %s a %s. You keep yours.\n%s gave you %d %s.", partner.GetTag(), REItemInfo.GetName(id), partner.GetTag(), spare, REItemInfo.GetName(spareId)));
		}
		else ShowMessage(String.Format("You gave %s a %s.\nYou keep yours.", partner.GetTag(), REItemInfo.GetName(id)));
		owner.A_StartSound("misc/i_pkup", CHAN_ITEM);
	}

	static class<Actor> PickupClass(int id)
	{
		switch (id)
		{
		case RE_ITEM_BERETTA:         return "REBerettaPickup";
		case RE_ITEM_SHOTGUN:         return "REShotgunPickup";
		case RE_ITEM_PYTHON:          return "REPythonPickup";
		case RE_ITEM_BAZOOKA_ACID:    return "REBazookaAcidPickup";
		case RE_ITEM_BAZOOKA:
		case RE_ITEM_BAZOOKA_FLAME:   return "REBazookaPickup";
		case RE_ITEM_ROCKET_LAUNCHER: return "RERocketLauncherPickup";
		case RE_ITEM_FLAMETHROWER:    return "REFlamethrowerPickup";
		}
		return "REKnifePickup";
	}

	// --- USE / EQUIP ---------------------------------------------------------

	void UseSlot(int s)
	{
		if (!ValidSlot(s) || owner == null || owner.health <= 0) return;
		int id = slotId[s];

		if (REItemInfo.IsWeapon(id))
		{
			EquipSlot(s);
			return;
		}

		int heal = REItemInfo.HealFlags(id);
		if (heal == 0)
		{
			ShowMessage("You can't use this on its own.");
			return;
		}

		// RE1 menu_item_use_heal (MainMenu.cpp): heal only if hurt, and the
		// item is only used up if it actually did something.
		bool used = false;
		int amount = heal & 0x0F;
		int maxHp = owner.GetMaxHealth(true);
		if (amount != 0 && owner.health < maxHp)
		{
			int gain = maxHp;
			if (amount == 1) gain = maxHp / 3;
			else if (amount == 2) gain = maxHp * 2 / 3;
			owner.GiveBody(gain, maxHp);
			used = true;
		}
		// The high bits cure poison (a blue herb or a mix with one in it).
		if ((heal & 0xF0) != 0 && owner.CountInv("REPoison") > 0)
		{
			owner.TakeInventory("REPoison", 1);
			used = true;
		}

		if (!used)
		{
			ShowMessage("You don't need to use it right now.");
			return;
		}
		ShowMessage(String.Format("You used the %s.", REItemInfo.GetName(id)));
		ClearSlot(s);
	}

	void EquipSlot(int s)
	{
		if (!ValidSlot(s) || owner == null || owner.player == null) return;
		int id = slotId[s];
		class<Weapon> wc = REItemInfo.WeaponClass(id);
		if (wc == null) return;

		// Remember the rounds left in the gun we're putting away.
		if (IsEquippedGun(equippedSlot))
		{
			slotQty[equippedSlot] = owner.CountInv("RELoadedRounds");
		}

		equippedSlot = s;
		if (REItemInfo.IsGun(id)) owner.SetInventory("RELoadedRounds", slotQty[s]);

		if (owner.FindInventory(wc) == null) owner.GiveInventory(wc, 1);
		owner.player.PendingWeapon = Weapon(owner.FindInventory(wc));
		if (!re_cheat_weapons) TakeWeaponsExcept(wc);   // you only hold the equipped weapon, like RE1

		ShowMessage(String.Format("You equipped the %s.", REItemInfo.GetName(id)));
	}

	// Puts the weapon away (it went into the item box, say).
	void Unequip()
	{
		if (IsEquippedGun(equippedSlot))
		{
			slotQty[equippedSlot] = owner.CountInv("RELoadedRounds");
		}
		equippedSlot = -1;
		if (owner != null)
		{
			owner.SetInventory("RELoadedRounds", 0);
			TakeWeaponsExcept(null);
		}
	}

	void TakeWeaponsExcept(class<Weapon> keep)
	{
		Array<class<Inventory> > drop;
		for (let item = owner.Inv; item != null; item = item.Inv)
		{
			if (item is "REWeapon" && item.GetClass() != keep) drop.Push(item.GetClass());
		}
		for (int i = 0; i < drop.Size(); i++) owner.TakeInventory(drop[i], 1);
	}

	// --- COMBINE ---------------------------------------------------------------
	// "first" is the slot you chose COMBINE on, "second" the one you picked
	// after. RE1 g_ItemCombineData / menu_item_check_combine (MainMenu.cpp).

	void CombineSlots(int first, int second)
	{
		if (!ValidSlot(first) || !ValidSlot(second) || first == second) return;
		int a = slotId[first];
		int b = slotId[second];

		// Ammo + its gun (either order): reload.
		if (REItemInfo.IsGun(a) && REItemInfo.IsAmmo(b)) { LoadGun(first, second); return; }
		if (REItemInfo.IsAmmo(a) && REItemInfo.IsGun(b)) { LoadGun(second, first); return; }

		// Ammo + the same ammo: add them together (RE1 caps this at 250).
		if (REItemInfo.IsAmmo(a) && a == b)
		{
			int total = min(slotQty[first] + slotQty[second], 250);
			SetSlot(first, a, total);
			ClearSlot(second);
			ShowMessage(String.Format("You combined the %s.", REItemInfo.GetName(a)));
			return;
		}

		// Herbs: the mix goes where you started, the other slot empties.
		int mix = REItemInfo.HerbMix(a, b);
		if (mix != RE_ITEM_NONE)
		{
			SetSlot(first, mix, 1);
			ClearSlot(second);
			ShowMessage("You mixed the herbs.");
			return;
		}

		ShowMessage("These items can't be combined.");
	}

	void LoadGun(int gunSlot, int ammoSlot)
	{
		int gun = slotId[gunSlot];
		int ammo = slotId[ammoSlot];
		String name = REItemInfo.GetName(gun);

		// The bazooka takes any kind of grenade round. Loading a different
		// kind first takes the old rounds out, like RE1.
		if (REItemInfo.IsBazooka(gun) && ammo >= RE_ITEM_EXPLOSIVE_ROUNDS && ammo <= RE_ITEM_FLAME_ROUNDS
			&& REItemInfo.AmmoFor(gun) != ammo)
		{
			int oldRounds = REItemInfo.AmmoFor(gun);
			int oldQty = slotQty[gunSlot];
			int newQty = min(slotQty[ammoSlot], REItemInfo.MaxQuantity(gun));
			int rest = slotQty[ammoSlot] - newQty;
			if (oldQty > 0 && rest > 0 && FindFreeSlot() < 0)
			{
				ShowMessage("There's no room to unload the old rounds.");
				return;
			}
			SetSlot(gunSlot, REItemInfo.BazookaFor(ammo), newQty);
			if (rest > 0) SetSlot(ammoSlot, ammo, rest);
			else if (oldQty > 0) SetSlot(ammoSlot, oldRounds, oldQty);
			else ClearSlot(ammoSlot);
			if (rest > 0 && oldQty > 0) SetSlot(FindFreeSlot(), oldRounds, oldQty);
			ShowMessage(String.Format("You loaded the %s with %s.", name, REItemInfo.GetName(ammo)));
			return;
		}

		if (REItemInfo.AmmoFor(gun) != ammo)
		{
			ShowMessage("These items can't be combined.");
			return;
		}
		int maxRounds = REItemInfo.MaxQuantity(gun);
		int total = slotQty[gunSlot] + slotQty[ammoSlot];
		if (slotQty[gunSlot] >= maxRounds)
		{
			ShowMessage(String.Format("The %s is already full.", name));
			return;
		}
		if (total > maxRounds)
		{
			SetSlot(gunSlot, gun, maxRounds);
			SetSlot(ammoSlot, ammo, total - maxRounds);
		}
		else
		{
			SetSlot(gunSlot, gun, total);
			ClearSlot(ammoSlot);
		}
		ShowMessage(String.Format("You loaded the %s.", name));
	}
}

// The inventory and box screens run in the "UI" part of the engine, which
// may not change the game directly. They send small network events instead,
// and this handler applies them on the game side.
class REGameHandler : EventHandler
{
	override void NetworkProcess(ConsoleEvent e)
	{
		if (e.Player < 0 || e.Player >= MAXPLAYERS || !playeringame[e.Player]) return;
		let pmo = players[e.Player].mo;
		if (pmo == null) return;
		let inv = REInventory(pmo.FindInventory("REInventory"));
		if (inv == null) return;

		if (e.Name ~== "re_use")
		{
			inv.UseSlot(e.Args[0]);
		}
		else if (e.Name ~== "re_combine")
		{
			inv.CombineSlots(e.Args[0], e.Args[1]);
		}
		else if (e.Name ~== "re_give")
		{
			inv.GiveToPartner(e.Args[0]);
		}
		else if (e.Name ~== "re_givecheat")
		{
			inv.GiveCheatWeaponToPartner();
		}
		else if (e.Name ~== "re_boxput" || e.Name ~== "re_boxtake")
		{
			let box = REItemBox(pmo.FindInventory("REItemBox"));
			if (box == null) return;
			if (e.Name ~== "re_boxput") box.PutIn(inv, e.Args[0]);
			else box.TakeOut(inv, e.Args[0]);
		}
		else if (e.Name ~== "re_synccheck")
		{
			// "netevent re_synccheck": a summary of the game that every computer in an
			// online game prints the same way; different lines in two logs = out of step.
			String s = String.Format("SYNC %s t=%d", level.MapName, level.maptime);
			for (int p = 0; p < MAXPLAYERS; p++)
			{
				if (!playeringame[p] || players[p].mo == null) continue;
				let m = players[p].mo;
				s = s .. String.Format(" p%d=(%.2f,%.2f,%.2f a%.2f h%d s%d)", p, m.pos.x, m.pos.y, m.pos.z, m.Angle, m.health, REInventory(m.FindInventory("REInventory")) != null ? REInventory(m.FindInventory("REInventory")).numSlots : -1);
			}
			int mons = 0, hp = 0;
			double sum = 0;
			let it = ThinkerIterator.Create("Actor");
			Actor a;
			while ((a = Actor(it.Next())) != null)
			{
				if (!a.bIsMonster) continue;
				mons++; hp += a.health; sum += a.pos.x + a.pos.y;
			}
			Console.Printf("%s monsters=%d hp=%d possum=%.2f", s, mons, hp, sum);
		}
		else if (e.Name ~== "re_debug")
		{
			// Type "netevent re_debug" in the console to print the player state.
			let cams = RECameraHandler(EventHandler.Find("RECameraHandler"));
			Console.Printf("pos=(%.1f, %.1f) angle=%.1f health=%d camera=%d weapon=%s god=%d",
				pmo.pos.x, pmo.pos.y, pmo.Angle, pmo.health,
				cams != null ? cams.currentCam : -1,
				pmo.player.ReadyWeapon != null ? pmo.player.ReadyWeapon.GetClassName() : 'none',
				(pmo.player.cheats & CF_GODMODE) != 0);
			for (int s = 0; s < inv.numSlots; s++)
			{
				Console.Printf("  slot %d: %s x%d%s", s, REItemInfo.GetName(inv.slotId[s]),
					inv.slotQty[s], s == inv.equippedSlot ? " (equipped)" : "");
			}
			let it = ThinkerIterator.Create("REItemBoxActor");
			Actor box;
			while (box = Actor(it.Next()))
				Console.Printf("  item box at (%.0f, %.0f), %.0f away", box.pos.x, box.pos.y, pmo.Distance2D(box));
			let arm = BasicArmor(pmo.FindInventory("BasicArmor"));
			let rp = RETankPlayer(pmo);
			Console.Printf("  armor %d (%.0f%%), model %s", arm ? arm.Amount : 0, arm ? arm.SavePercent * 100 : 0, rp ? String.Format("%s", rp.reModel) : "-");
			let partner = REPartner.Find();
			if (partner != null) Console.Printf("  partner %s, %.0f away", partner.GetTag(), pmo.Distance2D(partner));
			let tit = ThinkerIterator.Create("RETypewriter");
			Actor tw;
			while (tw = Actor(tit.Next()))
				Console.Printf("  typewriter at (%.0f, %.0f), %.0f away", tw.pos.x, tw.pos.y, pmo.Distance2D(tw));
		}
	}
}
