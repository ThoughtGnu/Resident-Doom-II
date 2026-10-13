// ---------------------------------------------------------------------------
// RE_DoomKeys.zs - Doom II's keys and power-ups as RE1 items (RE_DoomItems.zs
// does the swapping). Doom decides where and what they do, RE1 how they look:
// RE1's own item models (re1convert items, models/props/items), RE1 names.
//
//   blue keycard      ARMOR KEY (blue)       light amp visor   LIGHTER
//   yellow keycard    SWORD KEY (yellow)     radiation suit    CHEMICAL
//   red keycard       SHIELD KEY (red)       computer map      MAP
//   blue skull key    HELMET KEY (blue)      partial invisibility -> a Clip
//   yellow skull key  STAR CREST (yellow)    invulnerability   -> a First Aid Spray
//   red skull key     SUN CREST (red)
//
// The keys: picking one up gives you Doom's own key (behind the scenes), so
// every Doom door and lock works exactly as before. They're picked up by
// walking over them, like Doom's, and don't take an item slot. The models are
// tinted with the key's colour and give off a faint light in it.
// The power-ups keep Doom's effects and lengths exactly.
// ---------------------------------------------------------------------------

class REKeyPickup : Inventory
{
	class<Inventory> doomKey;
	Color keyColor;
	property DoomKey: doomKey;
	property KeyColor: keyColor;

	Default
	{
		Radius 12;
		Height 12;
		+NOTDMATCH
		+COUNTITEM   // items % (RE_Records.zs)
		Inventory.PickupSound "misc/k_pkup";
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		Angle = REPickup.FloorAngle(self);
		A_AttachLight('REKeyGlow', DynamicLight.PointLight, keyColor, 32, 32, 0, (0, 0, 8));
	}

	override void Tick()
	{
		Super.Tick();
		lightlevel = re_dark ? RELightingHandler.Glow(self, 24, 112) : -1;   // readable in RE1 lighting, like the pickups
	}

	override bool TryPickup(in out Actor toucher)
	{
		toucher.GiveInventory(doomKey, 1);
		GoAwayAndDie();
		return true;
	}
}

class REArmorKey : REKeyPickup
{
	Default { Tag "Armor Key (blue)"; Inventory.PickupMessage "You got the ARMOR KEY (blue)."; REKeyPickup.DoomKey "BlueCard"; REKeyPickup.KeyColor "40 70 255"; }
	States { Spawn: RKAR A -1; Stop; }
}
class RESwordKey : REKeyPickup
{
	Default { Tag "Sword Key (yellow)"; Inventory.PickupMessage "You got the SWORD KEY (yellow)."; REKeyPickup.DoomKey "YellowCard"; REKeyPickup.KeyColor "255 200 40"; }
	States { Spawn: RKSW A -1; Stop; }
}
class REShieldKey : REKeyPickup
{
	Default { Tag "Shield Key (red)"; Inventory.PickupMessage "You got the SHIELD KEY (red)."; REKeyPickup.DoomKey "RedCard"; REKeyPickup.KeyColor "255 50 30"; }
	States { Spawn: RKSH A -1; Stop; }
}
class REHelmetKey : REKeyPickup
{
	Default { Tag "Helmet Key (blue)"; Inventory.PickupMessage "You got the HELMET KEY (blue)."; REKeyPickup.DoomKey "BlueSkull"; REKeyPickup.KeyColor "40 70 255"; }
	States { Spawn: RKHE A -1; Stop; }
}
class REStarCrest : REKeyPickup
{
	Default { Tag "Star Crest (yellow)"; Inventory.PickupMessage "You got the STAR CREST (yellow)."; REKeyPickup.DoomKey "YellowSkull"; REKeyPickup.KeyColor "255 200 40"; }
	States { Spawn: RCST A -1; Stop; }
}
class RESunCrest : REKeyPickup
{
	Default { Tag "Sun Crest (red)"; Inventory.PickupMessage "You got the SUN CREST (red)."; REKeyPickup.DoomKey "RedSkull"; REKeyPickup.KeyColor "255 50 30"; }
	States { Spawn: RCSU A -1; Stop; }
}

// Doom's radiation suit: same protection, same length.
class REChemicalPickup : RadSuit
{
	Default { Tag "Chemical"; Inventory.PickupMessage "You got the CHEMICAL. It protects you from toxic floors for a while."; }
	States { Spawn: RCHM A -1; Stop; }
	override void PostBeginPlay() { Super.PostBeginPlay(); Angle = REPickup.FloorAngle(self); }
	override void Tick() { Super.Tick(); lightlevel = re_dark ? RELightingHandler.Glow(self, 24, 112) : -1; }
}

// Doom's light amplification visor: a LIGHTER that burns as long as the visor
// lasted (2 minutes). No green night vision: a small flame, a warm light
// that's bright a few metres around you and fades with distance (far corners
// and other rooms stay dark), the same in first person and with the fixed
// cameras, in both lighting modes. The status bar
// shows how long it has left (RE_Hud.zs).
class RELighterPickup : Infrared
{
	Default { Tag "Lighter"; Powerup.Type "PowerRELighter"; Inventory.PickupMessage "You got the LIGHTER. Its flame lights up the dark for a while."; }
	States { Spawn: RLTR A -1; Stop; }
	override void PostBeginPlay() { Super.PostBeginPlay(); Angle = REPickup.FloorAngle(self); }
	override void Tick() { Super.Tick(); lightlevel = re_dark ? RELightingHandler.Glow(self, 24, 112) : -1; }
}

// Doom's computer area map: the whole level shown on the map screen (key M, RE_Map.zs).
class REMapPickup : Allmap
{
	Default { Tag "Map"; Inventory.PickupMessage "You got the MAP. Press M to look at it."; }
	States { Spawn: RMAP A -1; Stop; }
	override void PostBeginPlay() { Super.PostBeginPlay(); Angle = REPickup.FloorAngle(self); }
	override void Tick() { Super.Tick(); lightlevel = re_dark ? RELightingHandler.Glow(self, 24, 112) : -1; }
}

// The Lighter burning: a small flickering orange-yellow light around the
// player, fading with distance (attenuated: bright close by, soft further out;
// about 3-4 metres - 32 map units are about a metre).
class PowerRELighter : Powerup
{
	Default { Powerup.Duration -120; }   // 2 minutes, like Doom's visor

	override void DoEffect()
	{
		Super.DoEffect();
		if (owner == null) return;
		// a flame: the size and warmth waver a little, a few times a second
		if (level.maptime % 3 == 0)
		{
			int r = 176 + random[flame](-10, 10);
			int g = 150 + random[flame](-12, 12);
			owner.A_AttachLight('RELighterFlame', DynamicLight.PointLight, Color(255, 255, g, 70), r, r, DynamicLight.LF_ATTENUATE, (0, 0, 40));
		}
	}

	override void EndEffect()
	{
		Super.EndEffect();
		if (owner != null) owner.A_RemoveLight('RELighterFlame');
	}
}
