// ---------------------------------------------------------------------------
// RE_Const.zs - Resident Evil 1's movement numbers, converted for GZDoom.
//
// Source: reference/re1-decomp/src/game/PlayerAnimations.cpp
//   player_ctrl_frame2          turn amounts per behaviour
//   player_ctrl_behavior_walk   walk speed 0x5D
//   player_ctrl_behavior_run    back-up speed 0x40 / 0x3C   (name is misleading)
//   player_behavior_0d_run      run speed 0xD2, run turn 0x30
//   player_behavior_13_gun_hold_input   aim turn: Jill 0x38, Chris 0x48
//   check_action_object         action probe 600 units ahead
// See docs/RE1_NOTES.md for the plain-English version.
//
// Conversion:
//   RE1 logic runs 30 times a second, GZDoom 35  -> multiply by 30/35
//   RE1 angles: 4096 = full circle               -> * 360/4096 for degrees
//   RE1 distances: ~1 mm; 1 Doom map unit ~= 32 RE1 units
//
//   turn  (degrees per Doom tic)   = RE value * 360/4096 * 30/35
//   speed (map units per Doom tic) = RE value / 32       * 30/35
// ---------------------------------------------------------------------------

// Turning, degrees per tic
const RE_TURN_IN_PLACE = 7.232142857;      // 0x60
const RE_TURN_WALKING  = 3.013392857;      // 0x28 (walking or backing up)
const RE_TURN_RUNNING  = 3.616071429;      // 0x30
const RE_TURN_AIMING   = 4.21875;          // 0x38 (Jill)

// Moving, map units per tic
const RE_SPEED_WALK         = 2.491071429; // 0x5D
const RE_CRAWL_BELOW        = 64;          // crouched under a ceiling lower than this: crawl on hands and knees (the models are ~88 tall; the kneel ~50-63)
const RE_SPEED_BACK         = 1.714285714; // 0x40
const RE_SPEED_BACK_GUARDED = 1.607142857; // 0x3C, enemy in front of you
const RE_SPEED_RUN          = 5.625;       // 0xD2

// "Enemy in front" test used when backing up: 45 degrees, 8000 RE1 units
const RE_GUARD_ANGLE    = 45.0;
const RE_GUARD_DISTANCE = 250.0;

// The action button looks for items this far in front of you (600 RE1 units)
const RE_ACTION_REACH = 18.75;

// Weapon hit areas (WeaponDamage.cpp, weapon_hit_detect_gun / _knife and
// checkEntityInRangeCone; weapons_ranges for Jill).
// Gun: the closest enemy in a band in front of you, at least 650 units
// ahead and within (enemy radius + 1300) to either side.
const RE_GUN_MIN_DEPTH  = 20.3125;   // 650 / 32
const RE_GUN_HALF_WIDTH = 40.625;    // Beretta range 1300 / 32
// Knife: the closest enemy within (enemy radius + 500) of the blade tip.
const RE_KNIFE_TIP   = 11.875;       // blade tip ~380 units ahead
const RE_KNIFE_REACH = 15.625;       // knife range 500 / 32

// The main player: the lowest player number in the game. In an online game
// it's the same player on every computer, unlike consoleplayer ("this
// computer's player"), so game decisions made for it (map-start layout, the
// partner's leader, the Final Boss start) never differ between the computers.
// In single player it is the one player.
class REMain
{
	static clearscope int Number()
	{
		for (int i = 0; i < MAXPLAYERS; i++) if (playeringame[i] && players[i].mo != null) return i;
		return 0;
	}

	static clearscope PlayerPawn Player()
	{
		int n = Number();
		return playeringame[n] ? players[n].mo : null;
	}

	// An online game (GZDoom's netgame), where some single-player features are off.
	static clearscope bool Online() { return multiplayer; }
}