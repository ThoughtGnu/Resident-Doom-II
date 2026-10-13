// ---------------------------------------------------------------------------
// RE_Poison.zs - RE1-style poison.
//
// Arachnotrons and the Spider Mastermind are the poisonous enemies (RE1's
// spiders): when their attacks hurt you, you're poisoned. While poisoned:
//   - like RE1, you lose 2 health every 4 seconds (the first time after 5),
//     but poison alone never takes your last point (any hit after that can
//     still kill you)
//   - the status screen shows POISON in purple (RE_InventoryMenu.zs)
//   - it stays with you into the next map and into saved games
// A Blue Herb, or a mix with one in it (G+B, G+R+B, G+G+B), cures it
// (RE_Inventory.zs UseSlot, RE1's g_ItemHealTable).
//
// The AI partner can't be hurt, so for them poison means a purple glow and
// slower firing, until you GIVE them a blue herb or a blue mix (RE_Partner.zs).
// They're poisoned when an Arachnotron's plasma hits them, or when they stand
// in the Spider Mastermind's line of fire while it shoots.
// ---------------------------------------------------------------------------

// Carried by a poisoned player.
class REPoison : Inventory
{
	// RE1's poison drain (decomp PlayerAnimations.cpp, 0x004951e6): a timer
	// set to 150 frames when you're poisoned (Adder.cpp), then 120 after each
	// drain; each time it runs out you lose 2 health, but never the last point
	// (only RE1's separate fast drain, flag 0x40, can kill). RE1 runs at 30
	// frames a second: the first drain after about 5 seconds, then 2 health
	// every 4 seconds.
	const FIRST_TICS = 176;   // 151 RE1 frames
	const DRAIN_TICS = 141;   // 121 RE1 frames
	const DRAIN = 2;
	int timer;

	Default
	{
		+INVENTORY.UNDROPPABLE
		+INVENTORY.UNTOSSABLE
		Inventory.MaxAmount 1;
	}

	override void AttachToOwner(Actor other)
	{
		Super.AttachToOwner(other);
		timer = FIRST_TICS;
	}

	override void DoEffect()
	{
		Super.DoEffect();
		if (owner == null || owner.health <= 0) return;
		if (timer <= 0) timer = DRAIN_TICS;   // (a game saved before the timer existed)
		if (--timer > 0) return;
		timer = DRAIN_TICS;
		if (owner.health <= 1 || re_cheat_god) return;
		owner.health = max(1, owner.health - DRAIN);
		if (owner.player != null) owner.player.health = owner.health;
	}

	static bool IsPoisoner(Actor mo)
	{
		return mo != null && (mo is "Arachnotron" || mo is "SpiderMastermind");
	}

	static bool IsPoisoned(Actor mo)
	{
		return mo != null && mo.CountInv("REPoison") > 0;
	}
}

class REPoisonHandler : EventHandler
{
	// Testing: the console command re_poison poisons you.
	override void NetworkProcess(ConsoleEvent e)
	{
		if (!(e.Name ~== "re_poison") || e.Player < 0 || !playeringame[e.Player]) return;
		let pmo = players[e.Player].mo;
		if (pmo == null || pmo.health <= 0) return;
		let inv = REInventory(pmo.FindInventory("REInventory"));
		if (REPoison.IsPoisoned(pmo)) { if (inv != null) inv.ShowMessage("You're already poisoned."); return; }
		pmo.GiveInventory("REPoison", 1);
		if (inv != null) inv.ShowMessage("You've been poisoned!");
	}

	// The player: hurt by a poisonous enemy's attack.
	override void WorldThingDamaged(WorldEvent e)
	{
		let pmo = e.Thing;
		if (pmo == null || pmo.player == null || e.Damage <= 0 || pmo.health <= 0) return;
		if (!REPoison.IsPoisoner(e.DamageSource) || REPoison.IsPoisoned(pmo)) return;
		pmo.GiveInventory("REPoison", 1);
		let inv = REInventory(pmo.FindInventory("REInventory"));
		if (inv != null) inv.ShowMessage("You've been poisoned!");
	}

	// The partner, in the Spider Mastermind's line of fire while it shoots
	// (its bullets go through the untouchable partner, so check the line).
	override void WorldTick()
	{
		let partner = REPartner.Find();
		if (partner == null || partner.IsPoisoned()) return;
		let it = ThinkerIterator.Create("SpiderMastermind");
		Actor sp;
		while (sp = Actor(it.Next()))
		{
			if (sp.health <= 0 || sp.target == null || !sp.InStateSequence(sp.CurState, sp.ResolveState("Missile"))) continue;
			if (random[poison](0, 7) != 0) continue;   // not every bullet hits
			if (OnLine(partner, sp.pos.xy, sp.target.pos.xy) && sp.CheckSight(partner))
				partner.Poison();
		}
	}

	// Is the partner between the shooter and its target, close to the line?
	static bool OnLine(Actor who, Vector2 from, Vector2 to)
	{
		Vector2 d = to - from;
		double len = d.Length();
		if (len < 1) return false;
		double along = ((who.pos.xy - from) dot d) / len;
		if (along <= 0 || along >= len) return false;
		Vector2 closest = from + d / len * along;
		return (who.pos.xy - closest).Length() <= who.radius + 4;
	}
}
