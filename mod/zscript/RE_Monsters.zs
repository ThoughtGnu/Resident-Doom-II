// ---------------------------------------------------------------------------
// RE_Monsters.zs - an RE1-style zombie built on Doom's zombieman sprites.
//
// Numbers from reference/re1-decomp/src/game/entities/Zombie.cpp:
//   zombie_health_tbl       starting health = table pick - random(0..21)
//   zombie_chase_walk       walks 45 RE1 units per tick (~1.2 map units/tic)
//   zombie_damage_hard_tbl  bite does 12, sometimes 9
// It never shoots: Doom's zombieman gun is removed.
// ---------------------------------------------------------------------------

class REZombie : ZombieMan
{
	static const int HealthTable[] = { 59, 59, 79, 59, 59, 39, 59, 79, 79, 99, 59, 79, 59, 59, 79, 59 };

	Default
	{
		Health 59;
		Speed 5;            // 5 units per 4-tic step ~= 1.25 map units per tic
		MeleeRange 44;
		PainChance 160;
		Obituary "%o was eaten by a zombie.";
		Tag "Zombie";
		DropItem "None";
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		health = HealthTable[random(0, 15)] - random(0, 21);
	}

	States
	{
	See:
		POSS AABBCCDD 4 A_Chase("Melee", null);   // null = no ranged attack
		Loop;
	Melee:
		POSS E 8 A_FaceTarget;
		POSS F 8 A_CustomMeleeAttack(random(0, 3) == 0 ? 9 : 12, "", "");
		POSS E 8;
		Goto See;
	}
}
