// ---------------------------------------------------------------------------
// RE_Items.zs - the items: their RE1 ids, names, healing, combining, the
// pickups placed in the map, and Jill's weapons.
//
// Item ids, names and maximum quantities are RE1's own
// (reference/re1-decomp/src/game/Types.h, MenuData.cpp g_ItemMaxQty).
// ---------------------------------------------------------------------------

enum EREItemId
{
	RE_ITEM_NONE             = 0x00,
	RE_ITEM_KNIFE            = 0x01,
	RE_ITEM_BERETTA          = 0x02,
	RE_ITEM_SHOTGUN          = 0x03,
	RE_ITEM_PYTHON           = 0x05,   // Colt Python, magnum rounds
	RE_ITEM_FLAMETHROWER     = 0x06,   // Chris only; its fuel is its quantity
	RE_ITEM_BAZOOKA          = 0x07,   // grenade launcher with explosive rounds
	RE_ITEM_BAZOOKA_ACID     = 0x08,   //   ... with acid rounds
	RE_ITEM_BAZOOKA_FLAME    = 0x09,   //   ... with flame rounds
	RE_ITEM_ROCKET_LAUNCHER  = 0x0A,
	RE_ITEM_CLIP             = 0x0B,
	RE_ITEM_SHELLS           = 0x0C,
	RE_ITEM_MAGNUM_ROUNDS    = 0x0E,
	RE_ITEM_EXPLOSIVE_ROUNDS = 0x10,
	RE_ITEM_ACID_ROUNDS      = 0x11,
	RE_ITEM_FLAME_ROUNDS     = 0x12,
	RE_ITEM_INK_RIBBON       = 0x2F,   // for the typewriters (RE_Typewriter.zs)
	RE_ITEM_FIRST_AID_SPRAY  = 0x41,
	RE_ITEM_RED_HERB         = 0x43,
	RE_ITEM_GREEN_HERB       = 0x44,
	RE_ITEM_BLUE_HERB        = 0x45,
	RE_ITEM_MIX_GR           = 0x46,   // green + red
	RE_ITEM_MIX_GG           = 0x47,   // green + green
	RE_ITEM_MIX_GB           = 0x48,   // green + blue
	RE_ITEM_MIX_GRB          = 0x49,   // green + red + blue
	RE_ITEM_MIX_GGG          = 0x4A,   // green x 3
	RE_ITEM_MIX_GGB          = 0x4B,   // green x 2 + blue
}

// Facts about each item. Usable from both the game and the menu.
class REItemInfo
{
	// Names as RE1 shows them (MenuData.cpp item name table).
	clearscope static String GetName(int id)
	{
		switch (id)
		{
		case RE_ITEM_KNIFE:            return "KNIFE";
		case RE_ITEM_BERETTA:          return "BERETTA";
		case RE_ITEM_SHOTGUN:          return "SHOTGUN";
		case RE_ITEM_PYTHON:           return "COLT PYTHON";
		case RE_ITEM_FLAMETHROWER:     return "FLAMETHROWER";
		case RE_ITEM_BAZOOKA:
		case RE_ITEM_BAZOOKA_ACID:
		case RE_ITEM_BAZOOKA_FLAME:    return "BAZOOKA";
		case RE_ITEM_ROCKET_LAUNCHER:  return "R. LAUNCHER";
		case RE_ITEM_CLIP:             return "CLIP";
		case RE_ITEM_SHELLS:           return "SHELLS";
		case RE_ITEM_MAGNUM_ROUNDS:    return "MAGNUM ROUNDS";
		case RE_ITEM_EXPLOSIVE_ROUNDS: return "EXPLOSIVE R.";
		case RE_ITEM_ACID_ROUNDS:      return "ACID ROUNDS";
		case RE_ITEM_FLAME_ROUNDS:     return "FLAME ROUNDS";
		case RE_ITEM_INK_RIBBON:       return "INK RIBBON";
		case RE_ITEM_FIRST_AID_SPRAY:  return "FIRST AID SPRAY";
		case RE_ITEM_RED_HERB:         return "RED HERB";
		case RE_ITEM_GREEN_HERB:       return "GREEN HERB";
		case RE_ITEM_BLUE_HERB:        return "BLUE HERB";
		case RE_ITEM_MIX_GR:
		case RE_ITEM_MIX_GG:
		case RE_ITEM_MIX_GB:
		case RE_ITEM_MIX_GRB:
		case RE_ITEM_MIX_GGG:
		case RE_ITEM_MIX_GGB:          return "MIXED HERBS";
		}
		return "";
	}

	clearscope static String GetDescription(int id)
	{
		switch (id)
		{
		case RE_ITEM_KNIFE:            return "A combat knife. Weak, but it never runs out.";
		case RE_ITEM_BERETTA:          return "A 9mm handgun. Holds 15 rounds.";
		case RE_ITEM_SHOTGUN:          return "A pump-action shotgun. Holds 7 shells and hits a wide area.";
		case RE_ITEM_PYTHON:           return "A Colt Python .357 magnum. Holds 6 rounds. Very powerful.";
		case RE_ITEM_FLAMETHROWER:     return "Can throw flame for 9 sec. with max. fuel.";   // RE1's own text
		case RE_ITEM_BAZOOKA:          return "A grenade launcher, loaded with explosive rounds.";
		case RE_ITEM_BAZOOKA_ACID:     return "A grenade launcher, loaded with acid rounds.";
		case RE_ITEM_BAZOOKA_FLAME:    return "A grenade launcher, loaded with flame rounds.";
		case RE_ITEM_ROCKET_LAUNCHER:  return "A rocket launcher. Nothing survives a direct hit.";
		case RE_ITEM_CLIP:             return "9mm rounds. Combine with the Beretta to reload.";
		case RE_ITEM_SHELLS:           return "Shotgun shells. Combine with the shotgun to reload.";
		case RE_ITEM_MAGNUM_ROUNDS:    return "Magnum rounds. Combine with the Colt Python to reload.";
		case RE_ITEM_EXPLOSIVE_ROUNDS: return "Explosive rounds for the bazooka.";
		case RE_ITEM_ACID_ROUNDS:      return "Acid rounds for the bazooka.";
		case RE_ITEM_FLAME_ROUNDS:     return "Flame rounds for the bazooka.";
		case RE_ITEM_INK_RIBBON:       return "It's used with a typewriter. Each save uses one.";
		case RE_ITEM_FIRST_AID_SPRAY:  return "A medical spray. Restores all of your health.";
		case RE_ITEM_RED_HERB:         return "A red herb. Useless alone - mix it with a green herb.";
		case RE_ITEM_GREEN_HERB:       return "A green herb. Restores some health.";
		case RE_ITEM_BLUE_HERB:        return "A blue herb. Cures poison.";
		case RE_ITEM_MIX_GR:           return "Green and red herbs. Restores all of your health.";
		case RE_ITEM_MIX_GG:           return "Two green herbs. Restores a lot of health.";
		case RE_ITEM_MIX_GB:           return "Green and blue herbs. Restores some health and cures poison.";
		case RE_ITEM_MIX_GRB:          return "Green, red and blue herbs. Restores all health and cures poison.";
		case RE_ITEM_MIX_GGG:          return "Three green herbs. Restores all of your health.";
		case RE_ITEM_MIX_GGB:          return "Two green herbs and a blue herb. Restores a lot of health and cures poison.";
		}
		return "";
	}

	clearscope static bool IsWeapon(int id)
	{
		return id >= RE_ITEM_KNIFE && id <= RE_ITEM_ROCKET_LAUNCHER;
	}

	clearscope static bool IsGun(int id)
	{
		return IsWeapon(id) && id != RE_ITEM_KNIFE;
	}

	clearscope static bool IsBazooka(int id)
	{
		return id >= RE_ITEM_BAZOOKA && id <= RE_ITEM_BAZOOKA_FLAME;
	}

	clearscope static bool IsAmmo(int id)
	{
		return id == RE_ITEM_CLIP || id == RE_ITEM_SHELLS || id == RE_ITEM_MAGNUM_ROUNDS
			|| (id >= RE_ITEM_EXPLOSIVE_ROUNDS && id <= RE_ITEM_FLAME_ROUNDS);
	}

	// Items several of which share one slot (up to MaxQuantity).
	clearscope static bool IsStackable(int id)
	{
		return IsAmmo(id) || id == RE_ITEM_INK_RIBBON;
	}

	// RE1 only shows a number on guns, ammo and ink ribbons.
	clearscope static bool ShowsQuantity(int id)
	{
		return IsGun(id) || IsStackable(id);
	}

	// g_ItemMaxQty (MenuData.cpp): rounds a gun holds, rounds per ammo slot.
	clearscope static int MaxQuantity(int id)
	{
		switch (id)
		{
		case RE_ITEM_BERETTA:
		case RE_ITEM_CLIP:            return 15;
		case RE_ITEM_SHOTGUN:
		case RE_ITEM_SHELLS:          return 7;
		case RE_ITEM_ROCKET_LAUNCHER: return 4;
		case RE_ITEM_FLAMETHROWER:    return 240;   // a full tank (RE1's flamethrowers hold 240)
		case RE_ITEM_INK_RIBBON:      return 3;
		}
		if (IsGun(id) || IsAmmo(id)) return 6;   // Python, bazooka and their rounds
		return 1;
	}

	// The ammo a gun loads (weapon_ammo_item_id). The bazooka's rounds depend
	// on which kind is loaded; the rocket launcher can't be reloaded.
	clearscope static int AmmoFor(int gun)
	{
		switch (gun)
		{
		case RE_ITEM_BERETTA:       return RE_ITEM_CLIP;
		case RE_ITEM_SHOTGUN:       return RE_ITEM_SHELLS;
		case RE_ITEM_PYTHON:        return RE_ITEM_MAGNUM_ROUNDS;
		case RE_ITEM_BAZOOKA:       return RE_ITEM_EXPLOSIVE_ROUNDS;
		case RE_ITEM_BAZOOKA_ACID:  return RE_ITEM_ACID_ROUNDS;
		case RE_ITEM_BAZOOKA_FLAME: return RE_ITEM_FLAME_ROUNDS;
		}
		return RE_ITEM_NONE;
	}

	// The bazooka id for a kind of grenade round.
	clearscope static int BazookaFor(int rounds)
	{
		return RE_ITEM_BAZOOKA + (rounds - RE_ITEM_EXPLOSIVE_ROUNDS);
	}

	// g_ItemHealTable (MenuData.cpp). Low 4 bits: 1 = heal a third,
	// 2 = heal two thirds, 3 = heal fully. High 4 bits: cures poison.
	clearscope static int HealFlags(int id)
	{
		switch (id)
		{
		case RE_ITEM_FIRST_AID_SPRAY: return 0x03;
		case RE_ITEM_GREEN_HERB:      return 0x01;
		case RE_ITEM_BLUE_HERB:       return 0x20;
		case RE_ITEM_MIX_GR:          return 0x03;
		case RE_ITEM_MIX_GG:          return 0x02;
		case RE_ITEM_MIX_GB:          return 0x21;
		case RE_ITEM_MIX_GRB:         return 0x23;
		case RE_ITEM_MIX_GGG:         return 0x03;
		case RE_ITEM_MIX_GGB:         return 0x22;
		}
		return 0;   // includes the red herb: it does nothing on its own
	}

	// Herb recipes from g_ItemCombineData (MenuData.cpp). Order doesn't matter.
	// Returns the mixed herb, or RE_ITEM_NONE if these two don't mix.
	clearscope static int HerbMix(int a, int b)
	{
		if (a > b) { int t = a; a = b; b = t; }   // so we only list each pair once
		if (a == RE_ITEM_RED_HERB   && b == RE_ITEM_GREEN_HERB) return RE_ITEM_MIX_GR;
		if (a == RE_ITEM_RED_HERB   && b == RE_ITEM_MIX_GB)     return RE_ITEM_MIX_GRB;
		if (a == RE_ITEM_GREEN_HERB && b == RE_ITEM_GREEN_HERB) return RE_ITEM_MIX_GG;
		if (a == RE_ITEM_GREEN_HERB && b == RE_ITEM_BLUE_HERB)  return RE_ITEM_MIX_GB;
		if (a == RE_ITEM_GREEN_HERB && b == RE_ITEM_MIX_GG)     return RE_ITEM_MIX_GGG;
		if (a == RE_ITEM_GREEN_HERB && b == RE_ITEM_MIX_GB)     return RE_ITEM_MIX_GGB;
		if (a == RE_ITEM_BLUE_HERB  && b == RE_ITEM_MIX_GR)     return RE_ITEM_MIX_GRB;
		if (a == RE_ITEM_BLUE_HERB  && b == RE_ITEM_MIX_GG)     return RE_ITEM_MIX_GGB;
		return RE_ITEM_NONE;
	}

	// The item id of a weapon class (the bazooka: explosive rounds), or NONE.
	clearscope static int IdForWeapon(class<Weapon> wc)
	{
		static const int ids[] = { RE_ITEM_KNIFE, RE_ITEM_BERETTA, RE_ITEM_SHOTGUN, RE_ITEM_PYTHON, RE_ITEM_BAZOOKA, RE_ITEM_ROCKET_LAUNCHER, RE_ITEM_FLAMETHROWER };
		for (int i = 0; i < ids.Size(); i++) if (WeaponClass(ids[i]) == wc) return ids[i];
		return RE_ITEM_NONE;
	}

	clearscope static class<Weapon> WeaponClass(int id)
	{
		switch (id)
		{
		case RE_ITEM_KNIFE:           return "REKnife";
		case RE_ITEM_BERETTA:         return "REHandgun";
		case RE_ITEM_SHOTGUN:         return "REShotgun";
		case RE_ITEM_PYTHON:          return "REMagnum";
		case RE_ITEM_BAZOOKA:
		case RE_ITEM_BAZOOKA_ACID:
		case RE_ITEM_BAZOOKA_FLAME:   return "REGrenadeLauncher";
		case RE_ITEM_ROCKET_LAUNCHER: return "RERocketLauncher";
		case RE_ITEM_FLAMETHROWER:    return "REFlamethrower";
		}
		return null;
	}
}

// ---------------------------------------------------------------------------
// Items lying in the map. Walk up, face them and press Action.
// ---------------------------------------------------------------------------

class REPickup : Actor
{
	int itemId;
	int itemQty;
	property ItemId: itemId;
	property ItemQty: itemQty;

	Default
	{
		Radius 12;
		Height 16;
		REPickup.ItemQty 1;
		+COUNTITEM   // counts for items % when taken (RE_Inventory.zs TakePickup)
	}

	// Items %: one that goes away without being taken (thinned out, replaced,
	// or a test spot that didn't fit) leaves the total too.
	override void OnDestroy()
	{
		if (bCountItem) ClearCounters();
		Super.OnDestroy();
	}

	// Called when someone presses E at this item, before it goes into the
	// slots (whether or not it fits). The Megasphere gives its armor here.
	virtual void OnUse(Actor taker) {}

	// Items lie at an angle that looks random but comes from their spot, so
	// setting it while the map loads (REStartLayoutHandler) and again at the
	// first tic gives the same angle: nothing turns once the map is shown.
	static double FloorAngle(Actor a)
	{
		int h = int(a.pos.x) * 73856093 ^ int(a.pos.y) * 19349663;
		return (h & 0x7FFFFFFF) % 360;
	}

	// The glow most items have in RE1 lighting (their Tick), set now.
	static void PrimeGlow(Actor a, int add = 24, int least = 112, int below = 16)
	{
		a.lightlevel = re_dark ? RELightingHandler.Glow(a, add, least, below) : -1;
	}

	// A dropped weapon (a shotgun guy's shotgun, say) holds fewer rounds.
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		if (bDropped && REItemInfo.IsGun(itemId)) itemQty = max(1, itemQty / 2);
		if (bDropped && bCountItem) ClearCounters();   // a monster's drop isn't one of the map's items
	}
}

// Herbs: small 3D plants in clay pots, like RE1's (models/props/herb_*.iqm,
// made by "re1convert prop herbs"). Their sprites are invisible placeholders;
// modeldef.txt draws the model. They're kept a little brighter than the room
// so they stand out in the dark, like RE1's items.
class REHerbPickup : REPickup
{
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		Angle = REPickup.FloorAngle(self);
	}

	override void Tick()
	{
		Super.Tick();
		lightlevel = re_dark ? RELightingHandler.Glow(self, 24, 112) : -1;   // the glow: RE1 lighting only
	}
}

class REGreenHerb : REHerbPickup
{
	Default
	{
		Tag "Green Herb";
		REPickup.ItemId 0x44;   // RE_ITEM_GREEN_HERB
	}
	States
	{
	Spawn:
		HRBG A -1;
		Stop;
	}
}

class RERedHerb : REHerbPickup
{
	Default
	{
		Tag "Red Herb";
		REPickup.ItemId 0x43;   // RE_ITEM_RED_HERB
	}
	States
	{
	Spawn:
		HRBR A -1;
		Stop;
	}
}

class REBlueHerb : REHerbPickup
{
	Default
	{
		Tag "Blue Herb";
		REPickup.ItemId 0x45;   // RE_ITEM_BLUE_HERB
	}
	States
	{
	Spawn:
		HRBB A -1;
		Stop;
	}
}
// Ammo: RE1's own item models (models/props/items, re1convert items),
// coloured to match RE1's inventory pictures. Their sprites (AM..) are
// invisible placeholders; modeldef.txt draws the model. Kept a little brighter
// than the room, like the herbs.
class REAmmoPickup : REPickup
{
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		Angle = REPickup.FloorAngle(self);
	}
	override void Tick()
	{
		Super.Tick();
		lightlevel = re_dark ? RELightingHandler.Glow(self, 24, 112) : -1;   // the glow: RE1 lighting only
	}
}

class REClipPickup : REAmmoPickup
{
	Default
	{
		Tag "Clip";
		REPickup.ItemId 0x0B;   // RE_ITEM_CLIP
		REPickup.ItemQty 15;
	}
	States
	{
	Spawn:
		AMCL A -1;
		Stop;
	}
}

class REFirstAidSprayPickup : REPickup
{
	Default
	{
		Tag "First Aid Spray";
		REPickup.ItemId 0x41;   // RE_ITEM_FIRST_AID_SPRAY
	}
	States
	{
	Spawn:
		RSPR A -1;      // invisible; modeldef.txt draws RE1's spray model
		Stop;
	}
	override void Tick()
	{
		Super.Tick();
		lightlevel = re_dark ? RELightingHandler.Glow(self, 24, 112) : -1;   // the glow: RE1 lighting only
	}
}

// --- RE1 items that replace Doom II's (RE_DoomItems.zs). Each keeps the
// --- look of the Doom item it replaces, so you recognise it.

// A weapon lying on the floor: RE1's own item model of it (re1convert items,
// models/props/items/w_*.iqm; the sprites are invisible placeholders), at a
// random angle, kept a little brighter than the room in RE1 lighting.
class REWeaponPickup : REPickup
{
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		Angle = REPickup.FloorAngle(self);
	}
	override void Tick()
	{
		Super.Tick();
		lightlevel = re_dark ? RELightingHandler.Glow(self, 24, 112) : -1;   // the glow: RE1 lighting only
	}
}

class REKnifePickup : REWeaponPickup
{
	Default { Tag "Knife"; REPickup.ItemId 0x01; REPickup.ItemQty 0; }
	States { Spawn: RWKN A -1; Stop; }

	// Doom II's chainsaw spots: both characters start with a knife, so a second
	// one is never placed. It becomes ammo for a gun you carry instead (the
	// equipped one first), or a clip for the Beretta.
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		Convert();
	}

	// Also run while the map loads (REStartLayoutHandler), so the swap is never seen.
	void Convert()
	{
		if (bDestroyed || bDropped) return;   // a knife you dropped stays a knife
		class<Actor> ammo = "REClipPickup";
		let pmo = players[consoleplayer].mo;
		let inv = pmo != null ? REInventory(pmo.FindInventory("REInventory")) : null;
		if (inv != null)
		{
			int gun = inv.equippedSlot >= 0 && REItemInfo.IsGun(inv.slotId[inv.equippedSlot]) ? inv.slotId[inv.equippedSlot] : RE_ITEM_NONE;
			for (int s = 0; s < inv.numSlots && gun == RE_ITEM_NONE; s++) if (REItemInfo.IsGun(inv.slotId[s]) && inv.slotId[s] != RE_ITEM_FLAMETHROWER && inv.slotId[s] != RE_ITEM_ROCKET_LAUNCHER) gun = inv.slotId[s];
			switch (REItemInfo.AmmoFor(gun))
			{
			case RE_ITEM_SHELLS:           ammo = "REShellsPickup"; break;
			case RE_ITEM_MAGNUM_ROUNDS:    ammo = "REMagnumRoundsPickup"; break;
			case RE_ITEM_EXPLOSIVE_ROUNDS: ammo = "REExplosiveRoundsPickup"; break;
			case RE_ITEM_ACID_ROUNDS:      ammo = "REAcidRoundsPickup"; break;
			case RE_ITEM_FLAME_ROUNDS:     ammo = "REFlameRoundsPickup"; break;
			}
		}
		let a = Actor.Spawn(ammo, pos, ALLOW_REPLACE);
		if (a != null) { a.bCountItem = bCountItem; a.Angle = REPickup.FloorAngle(a); }
		if (re_debugcams) Console.Printf("chainsaw spot (%.0f, %.0f): %s", pos.x, pos.y, a != null ? a.GetClassName() : 'nothing');
		bCountItem = false;
		Destroy();
	}
}

class REBerettaPickup : REWeaponPickup
{
	Default { Tag "Beretta"; REPickup.ItemId 0x02; REPickup.ItemQty 15; }
	States { Spawn: RWBE A -1; Stop; }
}

class REShotgunPickup : REWeaponPickup
{
	Default { Tag "Shotgun"; REPickup.ItemId 0x03; REPickup.ItemQty 7; }
	States { Spawn: RWSG A -1; Stop; }
}

class REPythonPickup : REWeaponPickup
{
	Default { Tag "Colt Python"; REPickup.ItemId 0x05; REPickup.ItemQty 6; }
	States { Spawn: RWPY A -1; Stop; }
}

class REBazookaPickup : REWeaponPickup
{
	Default { Tag "Bazooka"; REPickup.ItemId 0x07; REPickup.ItemQty 6; }
	States { Spawn: RWBZ A -1; Stop; }
}

class REBazookaAcidPickup : REWeaponPickup
{
	Default { Tag "Bazooka"; REPickup.ItemId 0x08; REPickup.ItemQty 6; }
	States { Spawn: RWBA A -1; Stop; }
}

class RERocketLauncherPickup : REWeaponPickup
{
	Default { Tag "Rocket Launcher"; REPickup.ItemId 0x0A; REPickup.ItemQty 4; }
	States { Spawn: RWRL A -1; Stop; }
}

class REClipBoxPickup : REClipPickup {}
class REChaingunClipPickup : REClipPickup {}

class REShellsPickup : REAmmoPickup
{
	Default { Tag "Shells"; REPickup.ItemId 0x0C; REPickup.ItemQty 7; }
	States { Spawn: AMSH A -1; Stop; }
}

class REShellBoxPickup : REShellsPickup {}

class REMagnumRoundsPickup : REAmmoPickup
{
	Default { Tag "Magnum Rounds"; REPickup.ItemId 0x0E; REPickup.ItemQty 6; }
	States { Spawn: AMMG A -1; Stop; }
}

class REExplosiveRoundsPickup : REAmmoPickup
{
	Default { Tag "Explosive Rounds"; REPickup.ItemId 0x10; REPickup.ItemQty 6; }
	States { Spawn: AMEX A -1; Stop; }
}

class REExplosiveBoxPickup : REExplosiveRoundsPickup {}

class REAcidRoundsPickup : REAmmoPickup
{
	Default { Tag "Acid Rounds"; REPickup.ItemId 0x11; REPickup.ItemQty 6; }
	States { Spawn: AMAC A -1; Stop; }
}

class REFlameRoundsPickup : REAmmoPickup
{
	Default { Tag "Flame Rounds"; REPickup.ItemId 0x12; REPickup.ItemQty 6; }
	States { Spawn: AMFL A -1; Stop; }
}

class REInkRibbonPickup : REPickup
{
	Default { Tag "Ink Ribbon"; REPickup.ItemId 0x2F; REPickup.ItemQty 1; }
	// A small 3D ink ribbon case (models/props/ribbon.iqm, re1convert prop
	// ribbon); the sprite is an invisible placeholder. Kept a little brighter
	// than the room so it shows in the dark, like the herbs.
	States { Spawn: INKR A -1; Stop; }
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		Angle = REPickup.FloorAngle(self);
	}
	override void Tick()
	{
		Super.Tick();
		lightlevel = re_dark ? RELightingHandler.Glow(self, 24, 112) : -1;   // the glow: RE1 lighting only
	}
}

// Three ribbons, like RE1's ribbon packs (next to the mansion's typewriter).
class REInkRibbonPack : REInkRibbonPickup
{
	Default { REPickup.ItemQty 3; }
}

// Removes a Doom item that has no RE1 counterpart (the +1 health bonus).
class RENothing : Actor
{
	States { Spawn: TNT1 A 0; Stop; }
}

// ---------------------------------------------------------------------------
// Weapons. You only hold the one you equipped in the inventory screen.
// ---------------------------------------------------------------------------

// The rounds loaded in the equipped gun (only one gun is ever held). The
// inventory slot shows this number; RE_Inventory.zs keeps the two in step.
class RELoadedRounds : Ammo
{
	Default
	{
		Inventory.MaxAmount 255;
		Ammo.BackpackMaxAmount 255;
		+INVENTORY.IGNORESKILL
	}
}

// Every RE weapon. In first person you see Jill's own arms
// (re1convert viewarms, models/<char>/arm_<char>_<name>.*): the weapon lowered at their
// side, raised two-handed while you aim (Aim held), and RE1's own fire
// animation when you press Action. One action, A_REWeaponTick, runs every
// tic and picks the arm model's frame; the frame layout is read from
// models/<char>/arm_<char>_<name>.txt. The third-person model is
// models/<char>/<char>_<name>.iqm (TankPlayer.zs UpdateModelSet).
class REWeapon : Weapon
{
	String armName;    // knife, beretta, shotgun, ... (file names above)
	property Arm: armName;

	enum EArm { ARM_LOWERED, ARM_RAISING, ARM_AIMED, ARM_FIRING, ARM_LOWERING }
	int armState;
	int armTime;       // tics in the current arm state
	bool shotDone;
	bool pumpDone;     // the shotgun's pump after the shot

	// Frame layout (models/<char>/arm_<char>_<name>.txt)
	bool layoutRead;
	String sprPrefix;
	int raiseStart, raiseLen, holdFrame, fireStart, fireLen, shotTick;
	bool hasMuzzle;
	Vector3 muzzle;   // first person: the nozzle tip from the eyes (forward, left, up), --point-forward weapons

	Default
	{
		Weapon.SelectionOrder 9000;
		Weapon.BobRangeX 0.4;
		Weapon.BobRangeY 0.4;
		+WEAPON.AMMO_OPTIONAL      // stays in your hands when empty (RE1 just clicks)
		+WEAPON.NOAUTOFIRE
		+WEAPON.NO_AUTO_SWITCH
		+WEAPON.NOALERT
		+INVENTORY.UNDROPPABLE
	}

	States
	{
	Ready:
		TNT1 A 1 A_REWeaponTick;
		Loop;
	Deselect:
		TNT1 A 1 A_REWeaponLower;
		Loop;
	Select:
		TNT1 A 1 A_REWeaponRaise;
		Loop;
	Fire:
		TNT1 A 1 A_REWeaponTick;
		Goto Ready;
	}

	// --- what each weapon does (overridden below) ---------------------------

	virtual bool HasRound() { return true; }
	// A sound a little after the shot (the shotgun's pump); "" = none.
	virtual Sound AfterShotSound() { return ""; }
	const AFTER_SHOT_FRAMES = 12;   // RE1 frames (0.4 s)
	virtual void Shoot(Actor shooter) {}
	virtual void StartFire(Actor shooter) {}
	// Hold-to-fire weapons (the flamethrower): called every tic while firing,
	// and at the end of the fire motion - true loops it again.
	virtual void FiringTick(Actor shooter) {}
	virtual bool KeepFiring(Actor shooter) { return false; }
	virtual void StopFire(Actor shooter) {}

	// --- the arm state machine ------------------------------------------------

	action void A_REWeaponTick()
	{
		let w = REWeapon(invoker);
		if (w == null || player == null) return;
		w.ArmTick(self);
		A_WeaponReady(WRF_NOFIRE | (w.armState == ARM_LOWERED ? 0 : WRF_NOBOB | WRF_NOSWITCH));
		w.ShowFrame(player);
	}

	action void A_REWeaponRaise()
	{
		let w = REWeapon(invoker);
		if (w != null) w.armState = ARM_LOWERED;
		A_Raise(12);
		if (w != null && player != null) w.ShowFrame(player);
	}

	action void A_REWeaponLower()
	{
		let w = REWeapon(invoker);
		A_Lower(12);
		if (w != null && player != null) w.ShowFrame(player);
	}

	// RE1 animates at 30 frames a second, Doom at 35 tics.
	static int Frames30(int tics) { return tics * 30 / 35; }
	static int Tics35(int frames) { return (frames * 35 + 29) / 30; }

	void SetArm(int st)
	{
		armState = st;
		armTime = 0;
		shotDone = false;
		pumpDone = false;
	}

	void ArmTick(Actor shooter)
	{
		ReadLayout();
		let jill = RETankPlayer(shooter);
		bool aiming = jill != null && jill.bREAiming;
		bool firePressed = (shooter.player.cmd.buttons & BT_ATTACK) != 0;
		armTime++;

		switch (armState)
		{
		case ARM_LOWERED:
			if (aiming) SetArm(ARM_RAISING);
			break;

		case ARM_RAISING:
			if (!aiming) { armState = ARM_LOWERING; armTime = max(0, Tics35(raiseLen) - armTime); }
			else if (Frames30(armTime) >= raiseLen) SetArm(ARM_AIMED);
			break;

		case ARM_AIMED:
			if (!aiming) SetArm(ARM_LOWERING);
			else if (firePressed && armTime > 2)
			{
				if (!HasRound())
				{
					shooter.A_StartSound("weapons/re_dryfire", CHAN_WEAPON);
					armTime = -8;   // a short pause before the next click
				}
				else
				{
					SetArm(ARM_FIRING);
					if (jill != null) jill.REStartFire();
					StartFire(shooter);
				}
			}
			break;

		case ARM_FIRING:
		{
			int f = Frames30(armTime);
			if (!shotDone && f >= shotTick)
			{
				shotDone = true;
				Shoot(shooter);
			}
			if (shotDone && !pumpDone && f >= shotTick + AFTER_SHOT_FRAMES)
			{
				pumpDone = true;
				Sound s = AfterShotSound();
				if (s != "") shooter.A_StartSound(s, CHAN_7);
			}
			FiringTick(shooter);
			if (f >= fireLen)
			{
				if (aiming && KeepFiring(shooter))
				{
					// still held: the fire motion again, without a new shot
					armTime = 0;
					if (jill != null) jill.REStartFire();
				}
				else
				{
					StopFire(shooter);
					SetArm(aiming ? ARM_AIMED : ARM_LOWERING);
				}
			}
			break;
		}

		case ARM_LOWERING:
			if (aiming) { armState = ARM_RAISING; armTime = max(0, Tics35(raiseLen) - armTime); }
			else if (Frames30(armTime) >= raiseLen) SetArm(ARM_LOWERED);
			break;
		}
	}

	// Which frame of the arm model to show now.
	int ArmFrame()
	{
		int f = Frames30(max(0, armTime));
		switch (armState)
		{
		case ARM_RAISING:  return raiseStart + min(f, raiseLen - 1);
		case ARM_AIMED:    return holdFrame;
		case ARM_FIRING:   return fireStart + min(f, fireLen - 1);
		case ARM_LOWERING: return raiseStart + max(0, raiseLen - 1 - f);
		}
		return 0;   // lowered
	}

	// Model frame k is drawn for sprite <prefix><k/26>, frame letter k%26
	// (the MODELDEF block written by re1convert).
	void ShowFrame(PlayerInfo pl)
	{
		ReadLayout();
		let psp = pl.GetPSprite(PSP_WEAPON);
		if (psp == null || sprPrefix.Length() == 0) return;
		int k = ArmFrame();
		psp.Sprite = GetSpriteIndex(String.Format("%s%d", sprPrefix, k / 26));
		psp.Frame = k % 26;
	}

	void ReadLayout()
	{
		if (layoutRead) return;
		layoutRead = true;
		String who = CharName();
		// Jill has no flamethrower arms in RE1 (re_jillflamer cheat): Chris's
		if (armName == "flame" && who != "chris") who = "chris";
		String file = String.Format("models/%s/arm_%s_%s.txt", who, who, armName);
		int lump = Wads.CheckNumForFullName(file);
		if (lump < 0)
		{
			Console.Printf("Resident Doom: %s not found (run re1convert viewarms).", file);
			return;
		}
		Array<String> lines;
		Wads.ReadLump(lump).Split(lines, "\n");
		for (int i = 0; i < lines.Size(); i++)
		{
			String line = lines[i];
			line.Substitute("\r", "");
			Array<String> t;
			line.Split(t, " ", TOK_SKIPEMPTY);
			if (t.Size() < 2 || t[0].Left(2) == "//") continue;
			if (t[0] == "sprite") sprPrefix = t[1];
			else if (t[0] == "raise" && t.Size() > 2) { raiseStart = t[1].ToInt(); raiseLen = t[2].ToInt(); }
			else if (t[0] == "hold") holdFrame = t[1].ToInt();
			else if (t[0] == "fire" && t.Size() > 2) { fireStart = t[1].ToInt(); fireLen = t[2].ToInt(); }
			else if (t[0] == "shot") shotTick = t[1].ToInt();
			else if (t[0] == "muzzle" && t.Size() > 3) { muzzle = (t[1].ToDouble(), t[2].ToDouble(), t[3].ToDouble()); hasMuzzle = true; }
		}
	}

	// Whose arms and models: the character holding this weapon.
	String CharName()
	{
		let pl = RETankPlayer(owner);
		return pl != null ? pl.reChar : "jill";
	}

	// Lengths of RE1's raise and fire animations (30 frames a second) for
	// this character, for the third-person timing.
	int RaiseLength() { ReadLayout(); return raiseLen > 0 ? raiseLen : 13; }
	int FireLength()  { ReadLayout(); return fireLen > 0 ? fireLen : 20; }

	// A short, small muzzle flash at the barrel when a gun fires. It lights
	// only the walls and floor near the barrel, never a character or monster
	// model (the whole-scene extralight lit the body up white). The knife gives
	// no light.
	void Flash(Actor shooter)
	{
		Vector3 at = shooter.Vec3Angle(36, shooter.Angle, 40);
		Actor.Spawn("REMuzzleFlash", at);
	}
}

// A gun: loaded rounds, RE1 damage, RE1's hit band (REAim).
class REGun : REWeapon
{
	int damage;
	double bandScale;
	Sound fireSound;
	property Damage: damage;
	property BandScale: bandScale;
	property FireSound: fireSound;

	Default
	{
		Weapon.AmmoType "RELoadedRounds";
		Weapon.AmmoUse 1;
		Weapon.AmmoGive 0;
		REGun.BandScale 1.0;
	}

	override bool HasRound()
	{
		if (Bottomless()) return true;
		return owner != null && owner.CountInv("RELoadedRounds") > 0;
	}

	// Only the Infinite Ammo cheat makes rounds and fuel last for ever. All
	// Weapons' guns start full and are used up like any other
	// (REInventory.cheatRounds keeps each one's rounds).
	bool Bottomless() { return re_cheat_ammo; }

	virtual int ShotDamage() { return damage; }
	virtual Sound ShotSound() { return fireSound; }

	override void Shoot(Actor shooter)
	{
		if (!HasRound()) return;
		if (!Bottomless()) shooter.TakeInventory("RELoadedRounds", 1);
		shooter.A_StartSound(ShotSound(), CHAN_WEAPON);
		Flash(shooter);
		if (shooter.player != null) shooter.player.mo.PlayAttacking2();

		Actor target = REAim.FindGunTarget(shooter, bandScale, REAim.AimDir(shooter));
		if (re_debugcams) Console.Printf("Shot aiming %s: %s", REAim.AimDir(shooter) == 1 ? "up" : (REAim.AimDir(shooter) == 2 ? "down" : "straight"), target ? target.GetClassName() : 'nothing');
		if (target != null) HitTarget(shooter, target);
		else Miss(shooter);
	}

	virtual void HitTarget(Actor shooter, Actor target)
	{
		REAim.Hit(shooter, target, ShotDamage());
	}

	// Nothing in the band: an ordinary bullet that can hit walls.
	virtual void Miss(Actor shooter)
	{
		int dir = REAim.AimDir(shooter);
		double pitch = dir == 1 ? -35 : (dir == 2 ? 35 : shooter.Pitch);
		if (RETankPlayer(shooter) != null && RETankPlayer(shooter).bREFirstPerson) pitch = shooter.Pitch;
		shooter.LineAttack(shooter.Angle, 2048, pitch, ShotDamage(), 'Hitscan', "BulletPuff");
	}
}

// Damage numbers: RE1's per-weapon damage against a zombie
// (WeaponDamage.cpp, first ENEMY_ZOMBIE block).

class REHandgun : REGun
{
	Default
	{
		Tag "Beretta";
		REWeapon.Arm "beretta";
		REGun.Damage 9;
		REGun.FireSound "re1/beretta";
	}
}

class REShotgun : REGun
{
	Default
	{
		Tag "Shotgun";
		REWeapon.Arm "shotgun";
		REGun.Damage 53;
		REGun.BandScale 2.0;       // the shotgun's wider aim fan
		REGun.FireSound "re1/shotgun";
	}
	override Sound AfterShotSound() { return "re1/shotgunpump"; }
}

class REMagnum : REGun
{
	Default
	{
		Tag "Colt Python";
		REWeapon.Arm "magnum";
		REGun.Damage 130;
		REGun.FireSound "re1/magnum";
	}
}

// The bazooka (RE1's grenade launcher). What it fires depends on the rounds
// loaded, which is the item id in its inventory slot (0x07 / 0x08 / 0x09).
class REGrenadeLauncher : REGun
{
	Default
	{
		Tag "Bazooka";
		REWeapon.Arm "grenade";
	}

	int LoadedKind()
	{
		let inv = owner != null ? REInventory(owner.FindInventory("REInventory")) : null;
		if (inv == null || inv.equippedSlot < 0) return RE_ITEM_BAZOOKA;
		int id = inv.slotId[inv.equippedSlot];
		return REItemInfo.IsBazooka(id) ? id : RE_ITEM_BAZOOKA;
	}

	override int ShotDamage() { return LoadedKind() == RE_ITEM_BAZOOKA ? 201 : 95; }

	override Sound ShotSound()
	{
		int k = LoadedKind();
		if (k == RE_ITEM_BAZOOKA_ACID) return "re1/acid";
		if (k == RE_ITEM_BAZOOKA_FLAME) return "re1/flame";
		return "re1/grenade";
	}

	class<Actor> BlastClass()
	{
		int k = LoadedKind();
		if (k == RE_ITEM_BAZOOKA_ACID) return "REAcidBlast";
		if (k == RE_ITEM_BAZOOKA_FLAME) return "REFlameBlast";
		return "REGrenadeBlast";
	}

	override void HitTarget(Actor shooter, Actor target)
	{
		Super.HitTarget(shooter, target);
		target.Spawn(BlastClass(), target.pos + (0, 0, target.Height * 0.5), ALLOW_REPLACE);
	}

	// Explodes on the wall it hits; RE1's rounds don't hurt Jill.
	override void Miss(Actor shooter)
	{
		FLineTraceData t;
		shooter.LineTrace(shooter.Angle, 1024, shooter.Pitch, TRF_THRUACTORS, shooter.player.viewheight * 0.8, data: t);
		Actor.Spawn(BlastClass(), t.HitLocation - t.HitDir * 4, ALLOW_REPLACE);
	}
}

class RERocketLauncher : REGun
{
	Default
	{
		Tag "Rocket Launcher";
		REWeapon.Arm "rocket";
		REGun.Damage 900;
		REGun.FireSound "re1/rocket";
	}

	// The Icon of Sin's brain in the aim band (MAP30): the rocket is sent in
	// through the slit in the face, so its blast reaches the brain
	// (REAim.BrainSlitPitch), as Doom's own rocket does when it flies in level.
	override void HitTarget(Actor shooter, Actor target)
	{
		let rocket = shooter.SpawnPlayerMissile("RERocket");
		if (rocket == null || !(target is "BossBrain")) return;
		bool open;
		double pitch;
		// clearance: half the rocket, plus 4 for the height GZDoom checks it at before each 40-unit step
		[open, pitch] = REAim.BrainSlitPitch(shooter, target, rocket.pos.z - shooter.pos.z + rocket.Height / 2, rocket.Height / 2 + 4);
		if (!open) return;
		double ang = shooter.AngleTo(target);
		rocket.Angle = ang;
		rocket.Pitch = pitch;
		rocket.Vel3DFromAngle(rocket.Speed, ang, pitch);
	}

	// A fast rocket. Its blast never hurts Jill.
	override void Miss(Actor shooter)
	{
		shooter.SpawnPlayerMissile("RERocket");
	}
}

// RE1's flamethrower (Chris only, as in RE1). Its fuel is the number in its
// slot (240 full), held in RELoadedRounds while it's in his hands like a
// gun's rounds. Hold Aim to raise it (RE1's W05 raise), hold Action to flame:
// the fire motion loops while Action is held and there's fuel, a stream of
// RE1 fire bursts (REFlame) shoots out about 4 metres, and the flame lights
// up its surroundings. RE1's own description says a full tank lasts 9
// seconds, so it burns 3 fuel every 4 tics (240 in about 9 s). No refuelling
// (RE1 never places its FUEL item); a second flamethrower tops it up
// (RE_Inventory.zs TakePickup). Empty, it clicks like the guns.
class REFlamethrower : REGun
{
	int burnTics;
	bool flaming;

	Default
	{
		Tag "Flamethrower";
		REWeapon.Arm "flame";
		REGun.Damage 20;   // RE1's flame against a zombie, per flame that hits
	}

	const FP_FLAME_START = 18;   // first person: map units from the eyes, along the line to the drawn nozzle
	bool FireHeld(Actor shooter) { return shooter.player != null && (shooter.player.cmd.buttons & BT_ATTACK) != 0; }

	override void StartFire(Actor shooter)
	{
		flaming = true;
		burnTics = 0;
		shooter.A_StartSound("re1/flamethrower", CHAN_WEAPON, CHANF_LOOPING);
		shooter.A_AlertMonsters();
		if (shooter.player != null) shooter.player.mo.PlayAttacking2();
	}

	override void Shoot(Actor shooter) {}   // the flames do the damage (FiringTick)

	override void FiringTick(Actor shooter)
	{
		if (!flaming) return;
		if (!FireHeld(shooter) || !HasRound()) { StopFlame(shooter); return; }
		burnTics++;
		if (!Bottomless() && burnTics % 4 != 0) shooter.TakeInventory("RELoadedRounds", 1);   // 3 fuel every 4 tics
		if (burnTics % 3 == 1) SpawnFlame(shooter);
		// the flame's light, flickering, a little ahead of the nozzle
		int r = 120 + random[flame](-12, 12);
		shooter.A_AttachLight('REFlameLight', DynamicLight.PointLight, Color(255, 255, 140 + random[flame](-15, 15), 50), r, r, DynamicLight.LF_ATTENUATE | DynamicLight.LF_DONTLIGHTSELF, (40, 0, 36));   // never lights up the one holding it
	}

	override bool KeepFiring(Actor shooter) { return flaming && FireHeld(shooter) && HasRound(); }

	override void StopFire(Actor shooter) { StopFlame(shooter); }

	void StopFlame(Actor shooter)
	{
		if (!flaming) return;
		flaming = false;
		shooter.A_StopSound(CHAN_WEAPON);
		shooter.A_StartSound("re1/flamethrowerend", CHAN_7);
		shooter.A_RemoveLight('REFlameLight');
	}

	// A fire burst from the nozzle, straight ahead or up / down with RE1's aim.
	void SpawnFlame(Actor shooter)
	{
		int dir = REAim.AimDir(shooter);
		double pitch = dir == 1 ? -25 : (dir == 2 ? 25 : 0);
		let pl = RETankPlayer(shooter);
		bool fp = pl != null && pl.bREFirstPerson && shooter.player != null;
		Vector3 at;
		Vector3 dirv;
		ReadLayout();
		if (fp && hasMuzzle)
		{
			// first person: from the nozzle tip as it's drawn, toward the
			// middle of the screen (the crosshair), 160 ahead. The view model is
			// drawn nearer than its true size, so the flame starts on the line
			// from the eyes through the drawn nozzle (the same spot on screen),
			// close in.
			double a = shooter.Angle, p = shooter.Pitch;
			Vector3 fwd = (cos(a) * cos(p), sin(a) * cos(p), -sin(p));
			Vector3 left = (-sin(a), cos(a), 0);
			Vector3 up = (cos(a) * sin(p), sin(a) * sin(p), cos(p));
			Vector3 eye = (shooter.pos.x, shooter.pos.y, shooter.player.viewz);
			// (first-person models are drawn mirrored: the layout's second number is to the right)
			Vector3 tip = (fwd * muzzle.x - left * muzzle.y + up * muzzle.z).Unit();
			at = eye + tip * FP_FLAME_START;
			dirv = (eye + fwd * 160 - at).Unit();
		}
		else
		{
			// third person: from the nozzle at his right hip
			at = shooter.Vec3Angle(22, shooter.Angle - 8, shooter.Height * 0.55);
			dirv = (0, 0, 0);
		}
		let fl = Actor.Spawn("REFlame", at, ALLOW_REPLACE);
		if (fl == null) return;
		fl.target = shooter;
		if (fp && hasMuzzle)
		{
			fl.Scale = (0.25, 0.25);   // small at the nozzle, growing as it flies
			// a little spread around the aim line
			double ang = VectorAngle(dirv.x, dirv.y) + frandom[flame](-3, 3);
			double pit = -asin(clamp(dirv.z, -1, 1)) + frandom[flame](-2, 2);
			fl.Angle = ang;
			fl.Vel3DFromAngle(fl.Speed, ang, pit);
		}
		else
		{
			fl.Angle = shooter.Angle + frandom[flame](-4, 4);
			fl.Vel3DFromAngle(fl.Speed, fl.Angle, pitch + frandom[flame](-3, 3));
		}
		let me = REFlame(fl);
		if (me != null) me.damageDone = ShotDamage();
	}
}

// One burst of flame: RE1's fire frames (re1convert flamesprites, sprites
// RFLM A-T, from small and yellow to big and dark), growing as it flies. It
// burns the first monster it touches (the flamethrower's damage) and is gone;
// it never hurts the player or the partner.
class REFlame : Actor
{
	int damageDone;
	Default
	{
		Radius 8;
		Height 12;
		Speed 11;            // ~4 metres in its 12 tics
		Projectile;
		DamageFunction (20);   // GZDoom only applies a missile's damage if it has some (the real number: DoSpecialDamage)
		+NOGRAVITY
		+FORCEXYBILLBOARD
		+BRIGHT
		+DONTSPLASH
		+NOBLOCKMONST
		RenderStyle "Add";
		Alpha 0.95;
		Scale 0.7;
	}
	override int DoSpecialDamage(Actor victim, int damage, Name damagetype)
	{
		if (victim == null || victim.player != null || victim is "REPartner") return 0;
		return damageDone > 0 ? damageDone : 20;
	}
	override void Tick()
	{
		Super.Tick();
		if (!bMissile) return;
		Scale *= 1.07;      // the burst spreads as it goes
	}
	States
	{
	Spawn:
		RFLM ABCDEFGHIJKL 1 Bright;
		RFLM M 0 { bMissile = false; Vel = (0, 0, 0); }
		Goto Death;
	Death:
		RFLM NOPQRST 2 Bright A_FadeOut(0.12);
		Stop;
	}
}

// The flamethrower lying in the map: RE1's own item model (I01V, re1convert
// items), for Chris. Doom's placed chainguns become it (RE_DoomItems.zs);
// when you play Jill (RE1 gives her none) or a chaingunner dropped it, it's a
// clip instead, as before.
class REFlamethrowerPickup : REPickup
{
	Default { Tag "Flamethrower"; REPickup.ItemId 0x06; REPickup.ItemQty 240; }
	States { Spawn: RFTH A -1; Stop; }
	override void PostBeginPlay()
	{
		if (Convert()) return;
		Super.PostBeginPlay();
		Angle = REPickup.FloorAngle(self);
	}

	// Becomes a clip when it isn't for you; true if it did. Also run while the
	// map loads (REStartLayoutHandler), so the swap is never seen.
	bool Convert()
	{
		if (bDestroyed) return true;
		let pmo = players[consoleplayer].mo;
		if (!bDropped && (pmo == null || pmo is "REChrisPlayer" || re_cheat_jillflame)) return false;
		let clip = Actor.Spawn("REChaingunClipPickup", pos, ALLOW_REPLACE);
		if (clip != null) { clip.bDropped = bDropped; clip.Angle = REPickup.FloorAngle(clip); }
		Destroy();
		return true;
	}
	override void Tick()
	{
		Super.Tick();
		lightlevel = re_dark ? RELightingHandler.Glow(self, 24, 112) : -1;   // the glow: RE1 lighting only
	}
}
// A gun's muzzle flash (REWeapon.Flash): a small light at the barrel for 3
// tics that lights the walls and floor only, never Jill, Chris, the partner
// or a monster.
class REMuzzleFlash : Actor
{
	Default { +NOINTERACTION; +NOBLOCKMAP; +NOGRAVITY; RenderStyle "None"; }
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		A_AttachLight('REMuzzleLight', DynamicLight.PointLight, Color(255, 255, 210, 130), 48, 48,
			DynamicLight.LF_ATTENUATE | DynamicLight.LF_DONTLIGHTACTORS);
	}
	States { Spawn: TNT1 A 3; Stop; }
}

class REKnife : REWeapon
{
	Default
	{
		Tag "Knife";
		REWeapon.Arm "knife";
	}

	override void StartFire(Actor shooter)
	{
		shooter.A_StartSound("re1/knifeswing", CHAN_WEAPON);
		if (shooter.player != null) shooter.player.mo.PlayAttacking2();
	}

	// 8 damage per slash: RE1's knife vs. a zombie.
	override void Shoot(Actor shooter)
	{
		Actor target = REAim.FindKnifeTarget(shooter);
		if (target != null)
		{
			REAim.Hit(shooter, target, 8);
			shooter.A_StartSound("re1/knifehit", CHAN_7);
		}
	}
}

// GZDoom only knows a sprite name if some state uses it, and MODELDEF can
// only replace known sprites. The arm models' frames (A_REWeaponTick picks
// them in code) use these names: <prefix><0-2>, see the arm_*.mdl files.
// Add a new weapon's prefix here too.
class REArmSprites : Actor
{
	States
	{
	Spawn:
		// Jill: J.., Chris: C..   (knife, Beretta, shotgun, Python, bazooka, rocket launcher)
		JKN0 A 0; JKN1 A 0; JKN2 A 0; JBR0 A 0; JBR1 A 0; JBR2 A 0; JSG0 A 0; JSG1 A 0; JSG2 A 0;
		JMG0 A 0; JMG1 A 0; JMG2 A 0; JGL0 A 0; JGL1 A 0; JGL2 A 0; JRL0 A 0; JRL1 A 0; JRL2 A 0;
		CKN0 A 0; CKN1 A 0; CKN2 A 0; CBR0 A 0; CBR1 A 0; CBR2 A 0; CSG0 A 0; CSG1 A 0; CSG2 A 0;
		CMG0 A 0; CMG1 A 0; CMG2 A 0; CGL0 A 0; CGL1 A 0; CGL2 A 0; CRL0 A 0; CRL1 A 0; CRL2 A 0;
		CFL0 A 0; CFL1 A 0; CFL2 A 0;   // Chris's flamethrower
		Stop;
	}
}

// --- what the bazooka and rocket launcher leave behind ----------------------

class REGrenadeBlast : Actor
{
	Sound blastSound;
	property BlastSound: blastSound;
	Default
	{
		+NOINTERACTION
		RenderStyle "Add";
		REGrenadeBlast.BlastSound "re1/grenadeblast";
	}
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		A_StartSound(blastSound, CHAN_BODY);
	}
	States
	{
	Spawn:
		MISL B 8 Bright;
		MISL C 6 Bright;
		MISL D 4 Bright;
		Stop;
	}
}

class REAcidBlast : REGrenadeBlast
{
	Default { REGrenadeBlast.BlastSound "re1/acidblast"; }
	States
	{
	Spawn:
		APBX ABCDE 4 Bright;
		Stop;
	}
}

class REFlameBlast : REGrenadeBlast
{
	Default { REGrenadeBlast.BlastSound "re1/flameblast"; }
	States
	{
	Spawn:
		FBXP ABC 6 Bright;
		Stop;
	}
}

class RERocket : Actor
{
	Default
	{
		Radius 11;
		Height 8;
		Speed 40;
		DamageFunction 900;
		Projectile;
		+RANDOMIZE
		+ZDOOMTRANS
		DeathSound "re1/rocketblast";
		Obituary "%o was caught in a rocket blast.";
	}
	States
	{
	Spawn:
		MISL A 1 Bright;
		Loop;
	Death:
		MISL B 8 Bright A_Explode(150, 128, 0);   // flags 0: never hurts Jill
		MISL C 6 Bright;
		MISL D 4 Bright;
		Stop;
	}
}

// RE1's hit tests (WeaponDamage.cpp). Both pick the closest live enemy.
class REAim play
{
	// weapon_hit_detect_gun + checkEntityInRangeCone: the enemy must be at
	// least RE_GUN_MIN_DEPTH in front of you, and no further to the side than
	// its own radius + RE_GUN_HALF_WIDTH (times 'scale': 2 for the shotgun).
	// Walls block the shot.
	// The aim direction: 0 straight, 1 up, 2 down (TankPlayer.zs reAimDir).
	static int AimDir(Actor shooter)
	{
		let p = RETankPlayer(shooter);
		return p != null ? p.reAimDir : 0;
	}

	// RE1's aim directions pick different targets: up only hits enemies well
	// above your eyes (a ledge, a flyer), down only ones below your knees (a
	// lower floor, something crawling or small). Straight is RE1's usual band.
	static bool InAimDir(Actor shooter, Actor mo, int dir)
	{
		if (dir == 0) return true;
		// The aim rules keep the reference eye height they were made with (41),
		// whatever the first-person eye height is (TankPlayer.zs ViewHeight).
		double eye = shooter.pos.z + (shooter.player != null ? min(shooter.player.viewheight, 41.0) : shooter.Height * 0.75);
		if (dir == 1) return mo.pos.z + mo.Height * 0.5 > eye + 40;
		return mo.pos.z + mo.Height < shooter.pos.z + 24 || mo.Height <= 24;
	}

	static Actor FindGunTarget(Actor shooter, double scale = 1.0, int dir = 0)
	{
		Actor best = null;
		double bestDist = 0;
		Vector2 fwd = Actor.AngleToVector(shooter.Angle);
		let it = BlockThingsIterator.Create(shooter, 2048);
		while (it.Next())
		{
			let mo = it.thing;
			if (mo == shooter || !mo.bShootable || mo.health <= 0) continue;
			// Monsters, and the Icon of Sin's brain (not a "monster" in Doom,
			// so RE1's rule would never pick it).
			if (!mo.bIsMonster && !(mo is "BossBrain")) continue;
			Vector2 d = shooter.Vec2To(mo);
			double depth = d dot fwd;
			double side = abs(d.x * fwd.y - d.y * fwd.x);
			if (depth < RE_GUN_MIN_DEPTH) continue;
			if (side > mo.radius + RE_GUN_HALF_WIDTH * scale) continue;
			if (!InAimDir(shooter, mo, dir) && !(mo is "BossBrain")) continue;
			if (mo is "BossBrain")
			{
				double eye = shooter.player != null ? min(shooter.player.viewheight, 41.0) : shooter.Height * 0.75;   // see AimDir
				bool open;
				double slitPitch;
				[open, slitPitch] = BrainSlitPitch(shooter, mo, eye);
				if (!open) continue;
			}
			else if (!shooter.CheckSight(mo)) continue;
			double dist = d.Length();
			if (best == null || dist < bestDist)
			{
				best = mo;
				bestDist = dist;
			}
		}
		return best;
	}

	// weapon_hit_detect_knife: within the enemy's radius + RE_KNIFE_REACH of
	// the blade tip.
	static Actor FindKnifeTarget(Actor slasher)
	{
		Vector2 tip = slasher.pos.xy + Actor.AngleToVector(slasher.Angle, RE_KNIFE_TIP);
		Actor best = null;
		double bestDist = 0;
		let it = BlockThingsIterator.Create(slasher, 128);
		while (it.Next())
		{
			let mo = it.thing;
			if (mo == slasher || !mo.bIsMonster || !mo.bShootable || mo.health <= 0) continue;
			double dist = (mo.pos.xy - tip).Length();
			if (dist > mo.radius + RE_KNIFE_REACH) continue;
			if (best == null || dist < bestDist)
			{
				best = mo;
				bestDist = dist;
			}
		}
		return best;
	}

	// The Icon of Sin's brain sits low in its alcove, hidden behind the
	// steps in front of the wall; only a slit near the alcove's ceiling is
	// open to the arena. In Doom, rockets fly in there and their splash
	// reaches the brain. RE1's weapons have no splash, so a shot counts when
	// it could reach that slit, just above the brain.
	static bool BrainOpenFrom(Actor from, Actor brain, double eyeZ)
	{
		Vector3 eye = from.pos + (0, 0, eyeZ);
		Vector3 slit = (brain.pos.x, brain.pos.y, brain.CurSector.ceilingplane.ZAtPoint(brain.pos.xy) - 12);
		Vector3 d = slit - eye;
		double dist = d.Length();
		if (dist < 1) return true;
		double pitch = -VectorAngle(d.xy.Length(), d.z);
		FLineTraceData t;
		from.LineTrace(VectorAngle(d.x, d.y), dist, pitch, TRF_THRUACTORS, eyeZ, data: t);
		bool open = t.HitType == TRACE_HitNone || t.Distance >= dist - 24;
		if (re_debugcams && from.player != null)
			Console.Printf("Icon brain: %s (trace %.0f of %.0f, brain health %d)", open ? "in reach" : "blocked", t.Distance, dist, brain.health);
		return open;
	}

	// The same slit, for shots: a straight line from 'from' (zOfs above its feet)
	// that goes in through the slit and ends within a rocket blast of the brain.
	// In Doom that's the only way to hurt it: a rocket that flies in level while
	// the lift rises past the slit, then explodes just behind the brain. From
	// the top of the lift a level rocket hits the wall above the slit, so the
	// line may tilt (12 degrees up to 12 down, in quarter degrees); the one
	// ending closest to the brain wins. 'clearance' (half a rocket's height)
	// keeps the whole rocket inside the slit. Returns the pitch.
	const BRAIN_BLAST_REACH = 112;   // a rocket's 128 (Doom's old splash measure, as the brain uses), with a margin

	static bool, double BrainSlitPitch(Actor from, Actor brain, double zOfs, double clearance = 0)
	{
		double ang = from.AngleTo(brain);
		double range = from.Distance2D(brain) + 256;
		// every pitch that works; the shot takes the middle one, furthest from
		// the slit's edges
		Array<double> good;
		for (double pitch = -12; pitch <= 12; pitch += 0.25)
		{
			bool ok = true;
			for (int k = -1; k <= 1 && ok; k++)
			{
				if (k != 0 && clearance <= 0) continue;
				FLineTraceData t;
				from.LineTrace(ang, range, pitch, TRF_THRUACTORS, zOfs + k * clearance, data: t);
				Vector2 d = t.HitLocation.xy - brain.pos.xy;
				if (max(abs(d.x), abs(d.y)) - brain.radius > BRAIN_BLAST_REACH) ok = false;
			}
			if (ok) good.Push(pitch);
		}
		bool found = good.Size() > 0;
		double best = found ? good[good.Size() / 2] : 0;
		if (re_debugcams && from.player != null)
			Console.Printf("Icon brain: %s", found ? String.Format("shot through the slit at pitch %.2f (%.2f to %.2f work)", best, good[0], good[good.Size() - 1]) : "no way through the slit");
		return found, best;
	}

	static void Hit(Actor attacker, Actor target, int damage)
	{
		if (re_debugcams && target is "BossBrain") Console.Printf("Icon brain hit for %d", damage);
		target.SpawnBlood(target.pos + (0, 0, target.Height * 0.6), attacker.AngleTo(target) + 180, damage);
		target.DamageMobj(attacker, attacker, damage, 'Hitscan');
	}
}

// --- armor: S.T.A.R.S. tactical vests --------------------------------------
// Doom's green and blue armor, unchanged (same armor values, walk over them),
// shown as 3D vests (models/props/vest_*.iqm, re1convert prop vests). While
// you have armor, Jill or Chris wears the matching vest (TankPlayer.zs).

class REVestLightPickup : GreenArmor
{
	Default { Tag "Light Vest"; Inventory.PickupMessage "You put on a S.T.A.R.S. vest."; }
	States { Spawn: VSTL A -1; Stop; }
	override void PostBeginPlay() { Super.PostBeginPlay(); Angle = REPickup.FloorAngle(self); }
	// a little brighter than the room, so it stands out in the dark (like the herbs)
	override void Tick() { Super.Tick(); lightlevel = re_dark ? RELightingHandler.Glow(self, 32, 120) : -1; }
}

// Doom's armor bonus (+1 armor, picked up by walking over it, as in Doom):
// a small S.T.A.R.S. vest patch - the light vest's model, about a third the size.
class REVestPatch : ArmorBonus
{
	Default { Tag "Vest Patch"; Inventory.PickupMessage "You picked up a S.T.A.R.S. vest patch."; }
	States { Spawn: VSTP A -1; Stop; }
	override void PostBeginPlay() { Super.PostBeginPlay(); Angle = REPickup.FloorAngle(self); }
	override void Tick() { Super.Tick(); lightlevel = re_dark ? RELightingHandler.Glow(self, 32, 120) : -1; }
}

class REVestHeavyPickup : BlueArmor
{
	Default { Tag "Heavy Vest"; Inventory.PickupMessage "You put on a heavy S.T.A.R.S. vest."; }
	States { Spawn: VSTH A -1; Stop; }
	override void PostBeginPlay() { Super.PostBeginPlay(); Angle = REPickup.FloorAngle(self); }
	// a little brighter than the room, so it stands out in the dark (like the herbs)
	override void Tick() { Super.Tick(); lightlevel = re_dark ? RELightingHandler.Glow(self, 32, 120) : -1; }
}

// Doom II's Megasphere gives health and blue armor: here a First Aid Spray
// (picked up with E) and the heavy vest. The armor is given even if the spray
// doesn't fit in your slots (then the spray stays on the floor).
class REMegaspherePickup : REFirstAidSprayPickup
{
	bool armorGiven;
	override void OnUse(Actor taker)
	{
		if (armorGiven) return;
		armorGiven = true;
		taker.GiveInventory("BlueArmor", 1);
	}
}
