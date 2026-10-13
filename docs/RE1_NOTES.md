# How Resident Evil 1 really works (notes from the decomp)

These notes come from reading the RE1 PC decomp in `reference/re1-decomp`.
File paths below are inside that folder. "Tick" means one RE1 game-logic
frame; RE1 runs **30 ticks per second** (a 33 ms frame limiter, see
`docs/LINUX_PORT.md`). GZDoom runs **35 tics per second**, so every
per-tick number is multiplied by 30/35 when converted.

## Units

| Thing    | RE1                        | GZDoom           |
|----------|----------------------------|------------------|
| Angle    | 4096 = one full turn       | 360 degrees      |
| Distance | about 1 unit = 1 mm        | 1 map unit ≈ 32 RE1 units |

The "1 unit ≈ 1 mm" scale was checked against your own game files:
`USA/Stage1/ROOM1060.RDT` (the main hall) is about 32,400 × 28,600 units
across, and its cameras sit 1.2 m to 5 m above the floor (Y is negative =
up). Doom's player is 56 map units tall (about 1.8 m), so 1 map unit ≈ 32 mm.

## Tank controls (`src/game/PlayerAnimations.cpp`)

The D-pad is read once per tick by `player_input_to_behavior`. Each
direction picks a "behaviour", and `player_ctrl_frame2` applies the turn:

| Input              | Behaviour       | Turn per tick | Move speed per tick |
|--------------------|-----------------|---------------|---------------------|
| Left / Right only  | turn in place   | 0x60 (8.4°)   | 0                   |
| Up                 | walk            | –             | 0x5D (93)           |
| Up + Left/Right    | walk and turn   | 0x28 (3.5°)   | 0x5D (93)           |
| Up + Run           | run             | 0x30 (4.2°)   | 0xD2 (210)          |
| Down               | back up         | 0x28 (3.5°)   | 0x40 (64)           |
| Aim held           | gun raised      | Jill 0x38, Chris 0x48 | 0           |

Details worth keeping:
* Walking speed dips slightly on footfalls (a per-character table in
  `player_ctrl_behavior_walk`). We use the steady 0x5D for now.
* Running is "walk + hold the run button". Backing up can never run.
* Backing up is slightly slower (0x3C instead of 0x40) when a live enemy is
  within 45° of where you face and 8000 units away
  (`player_ctrl_behavior_run`).
* Speed is set fresh every tick, so there is no acceleration and you stop
  instantly when you let go.
* The action button checks a point **600 units in front of you** for an
  item or door (`check_action_object`).
* While aiming you can't walk; Left/Right turn you, Up/Down aim up/down, and
  the action button fires (`player_behavior_13_gun_hold_input`). With an
  empty gun, firing only plays a "click"; it doesn't reload by itself.

In GZDoom units (`mod/zscript/RE_Const.zs`):
turn = units × 360/4096 × 30/35, speed = units ÷ 32 × 30/35.

## Fixed cameras (`src/game/Room.cpp`, `src/game/Types.h`)

* Every room file (`.RDT`) holds a list of cameras. Each camera is a
  **position**, a **point it looks at**, and a **projection value**
  (`RDT_Camera`). The value 230 works out to about 70° wide and 207 to
  about 75° (2 × atan(160 / value)).
* The room also holds **switch zones** (`CAM_SWITCH_ZONE`): a 4-corner
  shape on the floor, plus "from camera" and "to camera".
* Every tick, `check_camera_switch` only tests the zones that belong to the
  **current** camera. The first zone the player is standing in switches to
  its "to" camera. The cut is instant.
* Because only the current camera's zones are tested, the zone that takes
  you from A to B can be placed differently from the one that takes you
  back from B to A. That gap stops the view flickering when you stand on
  the border.
* Each camera's zone list starts with a header entry (camera 9, covering the
  whole room) that is never tested.

We copy this exactly in `mod/zscript/FixedCamera.zs`, reading the cameras
and zones from `mod/recams.txt`.

## Inventory (`src/game/BioCard.h`, `MainMenu.cpp`, `MenuData.cpp`, `GameStart.cpp`)

* Jill carries **8** slots, Chris **6** (`DebugMenu.cpp`, `SetInitialItems`).
  The item box holds 48.
* Each slot is just two numbers: **item id** and **quantity**.
* Jill starts with a Knife, a Beretta with 15 rounds, and a First Aid Spray.
  Nothing is equipped at the start.
* Item ids used here (`Types.h`): Knife 0x01, Beretta 0x02, Clip 0x0B,
  First Aid Spray 0x41, Red/Green/Blue Herb 0x43/0x44/0x45, mixed herbs
  0x46–0x4B.
* Max quantity (`g_ItemMaxQty`): Beretta 15, Clip 15.

### Healing (`menu_item_use_heal`, `g_ItemHealTable`)

The low half of the table value is the heal amount, and the high half cures
poison:

| Item               | Heals           | Cures poison |
|--------------------|-----------------|--------------|
| First Aid Spray    | full            | no           |
| Green Herb         | 1/3 of max      | no           |
| Red Herb           | nothing (mix it)| no           |
| Blue Herb          | –               | yes          |
| Green+Red          | full            | no           |
| Green+Green        | 2/3 of max      | no           |
| Green+Blue         | 1/3 of max      | yes          |
| Green+Red+Blue     | full            | yes          |
| Green×3            | full            | no           |
| Green×2+Blue       | 2/3 of max      | yes          |

An item is **only used up if it did something**. A herb used at full health
stays in your inventory.

### Combining (`g_ItemCombineData`, `menu_item_check_combine`)

* Herbs: Red+Green, Red+(Green+Blue), Green+Green, Green+Blue,
  Green+(Green+Green), Green+(Green+Blue), Blue+(Green+Red),
  Blue+(Green+Green). The result goes into the slot you started from and the
  other slot is emptied.
* Clip + Beretta: moves rounds into the gun, up to 15. Leftover rounds stay
  in the clip, and an empty clip disappears.
* Clip + Clip: adds them together (the original caps this at 250).

### Condition display (`MainMenu.cpp`, `DAT_004b92c8`)

`status = (health − 1) ÷ (max health ÷ 4)`, capped at 3:

| Status | Shows   | Colour                |
|--------|---------|-----------------------|
| 3      | Fine    | green  (00 FF 00)     |
| 2      | Caution | yellow (D8 D8 00)     |
| 1      | Caution | orange (FF 7F 00)     |
| 0      | Danger  | red    (C0 00 00)     |

Max health: Jill 96, Chris 140 (`GameStart.cpp`).

## Weapon hit areas (`src/game/WeaponDamage.cpp`)

RE1 doesn't fire a bullet along one exact line. Each shot picks the
**closest** live enemy inside an area in front of you:

* **Gun** (`weapon_hit_detect_gun`, `checkEntityInRangeCone`): working
  through the cross-product checks (x = forward, the same axis the action
  button uses), the area is a band in front of you. The enemy must be more
  than 650 units ahead and no further to the side than its own size plus
  the weapon's range. Jill's Beretta range is 1300 (`weapons_ranges`), so the
  band is wide and aiming is forgiving.
* **Knife** (`weapon_hit_detect_knife`): the enemy must be within its own
  size plus 500 of the blade tip.

This is my reading of the decomp's math, not a comment the decomp makes
itself. In-game tests confirm 9 damage per Beretta round and 8 per knife
slash.

## Zombie (`src/game/entities/Zombie.cpp`, `WeaponDamage.cpp`)

* Health: a random pick from `zombie_health_tbl` (mostly 59, sometimes 39,
  79 or 99) minus a random 0–21.
* Walking chase speed: 45 units per tick (about 1.2 map units per tic).
* Bite damage (`zombie_damage_hard_tbl`): 12, sometimes 9.
* Damage dealt to a zombie on the first playthrough: Knife 8, Beretta 9 per
  shot.

## Weapons, ammo and the item box (added for the Doom II items)

- **Weapon files** (EntityModelLoader.cpp, g_weaponPathTable, indexed by item
  id): Jill W10 unarmed, W11 knife, W12 Beretta, W13 shotgun, W14 Colt Python,
  W15 flamethrower, W16 bazooka (grenade launcher, items 7-9), W17 rocket
  launcher.
- **Animations** (PlayerAnimations.cpp, player_behavior_13_gun_hold_input):
  - Guns: 5 raise, 6 fire, 7 hold, aiming straight ahead. Aim down is 8-10
    and aim up is 11-13, from attackAnim = dir * 3 + 5.
  - Knife: 5 raise, 9 hold, 6 slash.
- **Damage vs. a zombie** (WeaponDamage.cpp, first ENEMY_ZOMBIE block):

  | Weapon | Damage |
  |---|---|
  | Knife | 8 |
  | Beretta | 9 |
  | Shotgun | 53 |
  | Python, DumDum rounds | 50 |
  | Python, magnum rounds | 130 |
  | Flamethrower | 20 |
  | Bazooka, explosive rounds | 201 |
  | Bazooka, acid rounds | 95 |
  | Bazooka, flame rounds | 95 |
  | Rocket launcher | 900 |

  The shotgun's aim fan is twice as wide (PlayerAnimations.cpp, isShotgun).
- **Max quantity** (MenuData.cpp g_ItemMaxQty, byte at id*4):

  | Item | Max |
  |---|---|
  | Beretta, clip | 15 |
  | Shotgun, shells | 7 |
  | Python, magnum rounds | 6 |
  | Bazooka, each kind of round | 6 |
  | Rocket launcher | 4 |
  | Flamethrower, fuel | 240 |

- **Names** (MenuData.cpp): COMBAT KNIFE, BERETTA, SHOTGUN, COLT PYTHON,
  BAZOOKA, R. LAUNCHER, CLIP, SHELLS, MAGNUM ROUNDS, EXPLOSIVE R., ACID
  ROUNDS, FLAME ROUNDS.
- **Item box:** one box shared by every room, 48 slots (BioCard.h
  itemboxSlots[48]).
- **Sounds** (SFXIds.h): each weapon has a sound bank. The shot is entry 7:
  gun01, shot01, magnum01, rocket01. The bazooka rounds use grbomb02 /
  gracid02 / grfire02, with explosions grbomb03 / gracid03 / grfire03 /
  rocket03.

## Chris vs. Jill (added for Chris)

- **Model:** Char10.EMD. Same layout as Jill's CHAR11.EMD (15 joints, 35
  animations).
- **Weapon files:** W00 unarmed, W01 knife, W02 Beretta, W03 shotgun,
  W04 Python, W05 flamethrower, W06 bazooka, W07 rocket launcher
  (g_weaponPathTable, Chris block).
- **Health** (GameStart.cpp): Chris 140, Jill 96, from
  (id & 1) * -44 + 140.
- **Items** (GameStart.cpp SetInitialItems): Chris has 6 slots, Jill 8.
  Chris starts with knife + First Aid Spray; the Beretta (15) goes to Rebecca.
- **Aiming turn speed** (PlayerAnimations.cpp): (id & 1) * -0x10 + 0x48,
  so Chris 0x48 and Jill 0x38.
- **Character-select background** is Data\SEL_BACK.PIX.
  JILL01/Jill02/CLIS01/Chris02.PIX are ending pictures.
