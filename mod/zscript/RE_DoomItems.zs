// ---------------------------------------------------------------------------
// RE_DoomItems.zs - Doom II's items become RE1's.
//
// Every Doom weapon, ammo and health item (placed in the map or dropped by a
// monster) is swapped for an RE1 item, picked up with Action into Jill's
// slots. Keys and power-ups become RE1 items too (RE_DoomKeys.zs), keeping
// Doom's effects; partial invisibility and invulnerability, which RE1 has
// nothing like, become a clip and a First Aid Spray.
// ---------------------------------------------------------------------------

class REDoomItemHandler : EventHandler
{
	override void CheckReplacement(ReplaceEvent e)
	{
		Name n = e.Replacee.GetClassName();
		Name to = 'None';
		switch (n)
		{
		// weapons
		case 'Chainsaw':      to = 'REKnifePickup'; break;            // only if she lost her knife
		case 'Pistol':        to = 'REBerettaPickup'; break;
		case 'Shotgun':       to = 'REShotgunPickup'; break;
		case 'SuperShotgun':  to = 'REPythonPickup'; break;           // rare and powerful
		case 'Chaingun':      to = 'REFlamethrowerPickup'; break;     // Chris: RE1's flamethrower (240 fuel); Jill, or dropped by a chaingunner: a clip (it swaps itself)
		case 'RocketLauncher':to = 'REBazookaPickup'; break;          // explosive rounds
		case 'PlasmaRifle':   to = 'REBazookaAcidPickup'; break;      // acid rounds
		case 'BFG9000':       to = 'RERocketLauncherPickup'; break;

		// ammo
		case 'Clip':          to = 'REClipPickup'; break;
		case 'ClipBox':       to = 'REClipBoxPickup'; break;
		case 'Shell':         to = 'REShellsPickup'; break;
		case 'ShellBox':      to = 'REShellBoxPickup'; break;
		case 'RocketAmmo':    to = 'REExplosiveRoundsPickup'; break;
		case 'RocketBox':     to = 'REExplosiveBoxPickup'; break;
		case 'Cell':          to = 'REAcidRoundsPickup'; break;
		case 'CellPack':      to = 'REFlameRoundsPickup'; break;
		case 'Backpack':      to = 'REMagnumRoundsPickup'; break;

		// health
		case 'Stimpack':
		case 'Medikit':       to = 'REGreenHerb'; break;
		case 'Berserk':       to = 'RERedHerb'; break;                // mix with a green one
		case 'Soulsphere':    to = 'REFirstAidSprayPickup'; break;
		case 'Megasphere':    to = 'REMegaspherePickup'; break;       // + the heavy vest

		// armor: S.T.A.R.S. vests (same armor values)
		case 'GreenArmor':    to = 'REVestLightPickup'; break;
		case 'BlueArmor':     to = 'REVestHeavyPickup'; break;
		case 'HealthBonus':   to = 'RENothing'; break;                // RE1 has nothing that small

		// armor bonus: a small S.T.A.R.S. vest patch (still +1 armor). Ink Ribbons
		// come in stacks of 3 placed by the typewriters (RE_ItemBox.zs).
		case 'ArmorBonus':    to = 'REVestPatch'; break;

		// keys: RE1 keys and crests (Doom's own key is given on pickup)
		case 'BlueCard':      to = 'REArmorKey'; break;
		case 'YellowCard':    to = 'RESwordKey'; break;
		case 'RedCard':       to = 'REShieldKey'; break;
		case 'BlueSkull':     to = 'REHelmetKey'; break;
		case 'YellowSkull':   to = 'REStarCrest'; break;
		case 'RedSkull':      to = 'RESunCrest'; break;

		// power-ups
		case 'RadSuit':       to = 'REChemicalPickup'; break;         // same protection
		case 'Infrared':      to = 'RELighterPickup'; break;          // same light-amp
		case 'Allmap':        to = 'REMapPickup'; break;              // same full automap
		case 'BlurSphere':    to = 'REClipPickup'; break;             // RE1 has no invisibility
		case 'InvulnerabilitySphere': to = 'REFirstAidSprayPickup'; break;   // ... nor invulnerability
		}
		if (to != 'None') e.Replacement = to;
	}
}
