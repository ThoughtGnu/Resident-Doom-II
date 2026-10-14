# Resident Doom: developer notes

How everything in Resident Doom works and is built, for whoever works on it
next. Players: see the [README](../README.md) and the
[Player Manual](../MANUAL.md) (also in the game: main menu > Extras > Manual).

Resident Doom is a Resident Evil 1-style game running in GZDoom: Jill's and
Chris's real RE1 models, tank controls, fixed camera angles, an RE-style
inventory and darker RE1 lighting. The rules are copied from the RE1 PC
decompilation (ecruells/resident-evil-pc-decomp, GPL-3.0; plain-English notes
in [RE1_NOTES.md](RE1_NOTES.md)).

## Building the game files

The repository holds only our own work. Every model, picture and sound made
from the player's RE1 and DOOM II files is built by `setup.bat` (Windows,
`tools/setup/setup.ps1`) or `setup.command` (macOS) with the converter in
`tools/re1convert`:

```
re1convert check <Resident Evil folder> <doom2.wad>       are these the right files?
re1convert all   <Resident Evil folder> <doom2.wad> mod   build everything into mod/
```

`tools/setup/manifest.txt` lists every file `all` builds; setup checks them.
The Level Select pictures are screenshots that setup takes with GZDoom (a
console alias chain of `map`, `wait 105`, `screenshot`, in `tools/setup/setup.ps1`
and `setup.command`), cut to 320x200 by `re1convert levelshots`. Missing ones
show a plain card (`RE_LevelSelect.zs` `Card`). The capture runs with its own settings
file (the alias chain lives in its `[Doom.ConsoleAliases]`, since aliases run at
startup only from there), `unbindall` so no key does anything, `use_mouse 0` so
the mouse isn't grabbed, and `i_pauseinbackground 0` so it keeps going behind
other windows. The Final Boss picture uses `netevent re_capbossview`
(`REFinalBossHandler`): the boss start's lift ride with its numbers fixed, so the
view is the same on every computer. `setup.bat -Pictures` /
`bash setup.command --pictures` takes only the pictures again.

The converter has no outside libraries: its pictures are `tools/re1convert/Img.cs`
(PNG write and read, scaling, a tiny pixel font for preview sheets), so the
same source builds with Windows' own C# compiler (`build.bat`, .NET Framework
4, C# 5) and with the .NET 8 SDK on a Mac (`re1convert.csproj`). Numbers in
written files always use a dot (InvariantCulture). Both builds produce the same
files (checked file by file; the .NET 8 build differs only by float rounding
in a few pixels).

## How to play

* **`play.bat`**: opens at the Resident Doom title screen ("PRESS ENTER TO
  PLAY", with the credit lines under it). Only Enter opens the menu; other
  keys do nothing there, and Esc in the menu goes back to the title. New Game asks **Jill or Chris** (RE1's character-select desk, both
  drawn from their RE1 models), then Doom II's levels or "Mansion - (custom level)".
* **`play_mansion.bat`**: our hand-made RE1-style mansion map, "Mansion - (custom level)"
  (`REMAP01`).
* **`play_doom2.bat`**: Doom II's own levels, MAP01 onward, with cameras
  placed automatically. Doom's weapons, ammo, health items, armor, keys and
  power-ups become RE1's (table below), keeping what they do; Doom's monsters
  are still Doom's.
* On a Mac: `play.command`, `play_mansion.command`, `play_doom2.command`.

`play_mansion.bat` and `play_doom2.bat` start as Jill. To play Chris from them, add
`+playerclass Chris`, for example `play_doom2.bat +playerclass Chris`.

**Jill or Chris:** the same controls, with RE1's own differences:

| | Jill | Chris |
|---|---|---|
| Health | 96 | 140 |
| Item slots | 8 | 6 |
| Turning while aiming | normal | faster |

Both start with the knife, a Beretta (15 rounds) and a First Aid Spray. In
RE1 Chris has no Beretta, but here he gets one so he can survive Doom II's
MAP01.

| Key                  | What it does                                  |
|----------------------|-----------------------------------------------|
| Up / W               | walk forward                                  |
| Down / S             | back up                                       |
| Left, Right / A, D   | turn                                          |
| Shift (hold, with Up)| run                                           |
| CapsLock             | always run on / off (GZDoom's own switch, `cl_run`; says "Always run: ON / OFF"). When on, Up runs without Shift and Shift + Up walks, in both views |
| Ctrl or right mouse (hold) | aim (needs an equipped weapon)          |
| E                    | action: pick up items, open doors, fire while aiming |
| Space                | jump                                          |
| C (hold)             | crouch: fit under low spaces, crouch-walk, aim crouched |
| Up / Down while aiming | aim up / aim down (RE1's own poses)         |
| V                    | switch to first-person view and back          |
| L                    | lighting: Doom (default) / RE1                |
| 1–7, mouse wheel     | switch weapons (only with the All Weapons cheat; 7 is Chris's flamethrower) |
| F6                   | quicksave (only at a typewriter in Classic RE saves) |
| Tab / I              | inventory screen (pauses the game)            |
| M                    | map screen (pauses the game; M or Esc closes it; a MAP pickup shows the whole level) |
| Esc                  | the main menu (see **Main menu** below); its **Main Menu** item ends the game and returns to the title screen (asks first) |

**Crouching (C):** hold C to crouch. You're half as tall (28 units), so you fit
under low ceilings and through crawl spaces. Up and Down move you at half speed
(crouch-walk), and you can turn and aim. You stand up when you let go, once
there's room. RE1 has no crouch, so it's posed on each character's own RE1
skeleton:
- **The kneel:** the right knee is on the floor with that foot on its toes;
  the left foot is flat with the shin vertical. The torso is upright and the
  arms are in the crouched high-ready (below).
- **Going down (half a second):** the right foot steps straight back and the
  knee lowers to the floor. Standing up is the reverse.
- **Moving:** a deep squat walk, never the kneel. The hips stay low and level
  (about knee height, no bobbing), the knees are deeply bent and point forward,
  the feet are about shoulder-width apart and each stays on its own side (never crossing the middle), and the torso leans forward about 35
  degrees. The steps are short and shuffling, and the step length is calculated
  from the crouched speed (forward and backing up) so the planted foot doesn't
  slide.
- **Arms in every crouch (kneeling and squat-walking), the same for both
  characters:** a compressed high-ready. Both hands are together, a hand's
  width in front of the chest, between chest and chin, with the elbows bent
  and tucked down. The hands always use RE1's own two-handed pistol grip, so
  the left hand closes over the right in front of the chest. None of it
  comes from the RE1 idle pose.
  - **Any gun:** it points straight forward.
  - **Knife:** held in the same grip, turned so the blade points forward.
  - **Empty hands:** the same pose, with the hands together.

  Each weapon uses only its own model, so no gun appears with the knife or
  empty hands. Holding aim still uses RE1's aim pose. (Crouch.Arms in
  `tools/re1convert`; to preview, run `re1convert crouchsheet <jill|chris>
  <RE1 USA> <out.png> [unarmed|knife|beretta|shotgun|...]`.)
- **Kneeling only when stopped:** it kneels after you've stood still for a
  moment. Crouching while already moving goes straight into the squat walk,
  and standing up from the walk goes straight up.
- **Aiming while kneeling:** RE1's own aim pose, both hands forward at eye
  level.
- **Floor contact** is calculated for every frame, so feet and knee stay on the
  floor.
- **Crawling through low gaps:** crouch under a ceiling lower than 64 (a crawl
  space like MAP03's start) and you drop onto hands and knees and crawl, in
  third person. From standing it goes one knee down, then onto all fours, and
  getting up is the reverse; from the crouch walk you go straight to the crawl.
  The crawl is at most 28.3 units high and 55 wide with any weapon, so the
  model stays inside the gap; the gun stays in the gun hand. The AI partner
  uses the same crawl. (`Crouch.Crawl`; preview with `re1convert crawlsheet
  <jill|chris> <RE1 USA> <out.png> [weapon]`.)

`re1convert crouchsheet <jill|chris> <RE1 folder> <out.png>` draws side views
of all of it, for checking.

**Aiming up and down:** while aiming, hold **Up** to aim up or **Down** to aim
down, like RE1, using RE1's own poses:
- **Up** hits enemies well above you, on a ledge or flying.
- **Down** hits enemies below your knees, on a lower floor or small and
  low.
- **Straight** works as before.

In first person, the direction follows where you look. The AI partner aims up
or down by itself.

**First-person eye height:** each character sees from their own eye level,
measured from their RE1 model's head (`re1convert eyes`: 45% of the way down
from the crown to the chin) at the size the model is drawn in game:

| | Standing | Crouched (kneeling) |
|---|---|---|
| Jill | 63.2 | 47.9 |
| Chris | 66.6 | 51.3 |

So as Jill you look Chris in the chin, and as Chris you look slightly down at
Jill's face. Crouching moves the eye smoothly from standing to kneeling height.
(RE1's aim up / down rules keep the old reference eye height of 41.)

**Lighting (L):** two modes, in Settings > Gameplay > Lighting, the L key, or
the console (`re_lights`, `re_dark 0` / `re_dark 1`). Remembered between sessions.
- **Doom (default):** the levels lit exactly as Doom made them, with no extra lights
  or glow.
- **RE1:** darker than Doom everywhere, right around the player too. Rooms are
  darkened to 60% indoors and 70% outdoors, but none loses more than 32 brightness
  (so bright areas far down a corridor stay visible) and none goes below 64 (rooms
  already that dim stay as they are). A faint, small light follows the player (a smaller one the
  partner). Jill, Chris and the partner are drawn a little above their room (at
  least 104), herbs, ammo and Ink Ribbons at least 112, vests and patches at least
  120: just readable in dark rooms, but never as bright as in Doom lighting.
  Typewriters (big and dark) are drawn at least 128, up to their Doom brightness
  but never above it.

The muzzle flash when firing is the same in both: a small light at the barrel that lights the walls and floor only, never Jill, Chris, the partner or a monster (the knife gives no light). In a game saved before
lighting could be switched, the switch works from the next map on.

**AI partner (Both):** the character select screen has a third choice in the
middle, **BOTH**, which shows Jill with her Beretta and Chris with his shotgun.
Pick it and choose which one you control; the other follows you as a friendly
teammate:
- **At the start of a map:** they stand where they appear (just behind you, never on an item) until you move or an enemy shows up.
- **Following:** they always walk the way you walked (a trail of
  breadcrumbs), so they take the same stairs, doors and lifts and go round
  corners instead of into them. They cut ahead along the trail only where the
  straight walk is clear for their whole width, steer around corners and door
  frames when the next step is blocked, and slide along walls. Doom's
  "block monsters" lines (like MAP01's start stairs) don't stop them.
- **Doors:** if a normal door closed between you, they walk up to it, open
  it themselves (as you would with Action) and keep following. Only an
  door that opens just itself, from its front: no tag, or a tag that only
  this door's own sector has (most of Doom's doors are tagged like that). A
  key door only while you carry its key (they open it with your key, so it
  skips nothing); a secret door only once you've opened it yourself on this
  map (remembered in saved games too), so they never give a secret away.
  Never a switch (its tag opens something elsewhere), a lift or anything else
  that changes the level. A door they can't open is left to the catch-up
  below. They never stop to fight while
  standing in a doorway (the door could close on them); if a door does close
  on them, they open that same door again.
- **Crawling:** a low gap on their way that they can't stand up in (lower
  than 56, at least 28, like MAP03's start) and they get down (one knee,
  then onto all fours) and crawl through on hands and knees at half walking
  speed, then get up again once there's room. It's the same crawl you do
  when you crouch (C) into a gap that low. The crawl is built on each
  character's own RE1 skeleton by the converter (`Crouch.Crawl`): at most
  28.3 units high and 55 wide with any weapon, so the model stays inside even
  the lowest (32) and narrowest (64) gaps; RE1's own kneel (50-63 high, the
  models being ~88 tall) wouldn't fit any of them.
- **Ledges and props:** before cutting across to a later point of your trail, they
  also check the item box, typewriters and Doom's solid decorations, and
  check the floor along the way, so they don't walk into a ledge too high to
  step up (like the one beside MAP02's first corridor).
- **Catching up (last resort):** only when they aren't getting anywhere:
  stuck for 3 seconds, very far behind and stuck for a second, or off camera
  for 8 seconds without getting closer. Then they step onto your trail just behind you,
  but only while both they and that spot are out of your view (the fixed
  camera's picture, or what's in front of you in first person).
- **Fighting:** they stop, raise their own weapon at the nearest enemy they
  can see and fire with RE1's damage (Beretta 9, shotgun 53). Their shots hit
  the enemy directly, so they can never hurt you.
- **Never in the way:** they take no damage and you can walk through each
  other, so they never block a door or corridor. They also step out of a
  closing door.
- **Cameras:** they prefer views that show both of you. You always come
  first.
- **Giving them a gun:** in the inventory, a gun's command list has a 4th
  option, **GIVE TO JILL** / **GIVE TO CHRIS**, while the partner is in the
  level. They must be close by (about two steps, in sight); otherwise the
  option is grayed out with "Too far away." You can't give away your last
  weapon (it's grayed out too), and the knife can't be given (the partner
  fights from range).
  - The gun and the rounds loaded in it leave your inventory, and the
    partner fights with it from then on: its RE1 damage, sound and model,
    with their usual aiming. Their own shots don't use up the rounds (as
    before, the partner never runs out).
  - Their old weapon comes back to you in the same slot (equipped, if the
    gun you gave was). If you already carry that kind of gun, its rounds
    come back as ammo instead, like picking up a second copy. If there's no
    room, it's left at your feet.
  - A two-line message at the bottom says what happened, e.g. "You gave
    Chris the SHOTGUN." / "Chris gave you his BERETTA." (or "...his BERETTA's
    15 rounds." when you already have one). The partner carries one gun at a
    time; with none to hand back, only the first line shows. If they already
    hold that gun, nothing is swapped: "Jill already has a BERETTA."
  - Their gun (and its rounds) goes with them to the next level, and into a
    Continue from the level's start as it was when you entered.
- **Partner pickups** (Settings > Gameplay, off by default): RE5 style, their
  own decision. When no enemy is in sight and they notice ammo for the gun
  they hold (within about 190 units of them, and no more than about 100 off
  your path), they leave the trail, walk over, pick it up ("Jill picked up
  the CLIP.") and go back to following. They give up after 5 seconds, or if
  an enemy shows up or you get far away. Never anything else (guns, herbs,
  sprays, keys, ribbons, maps). They keep it as spare ammo
  (their own shots still never use any up), and it comes to you with their
  old gun when you swap: "Jill gave you her BERETTA and 30 CLIP." (or "...her
  BERETTA's 45 rounds." when you already have one).
  - The partner is always the AI: GZDoom has no split-screen, so there's no
    second human player on the same PC. They never offer you things on their
    own; their old weapon coming back is how they give you one.

Level Select has the same choice: Left/Right cycles **Jill → Both (you: Jill)
→ Both (you: Chris) → Chris**. From the console: `re_partner 1` (Jill follows)
or `re_partner 2` (Chris follows), then start a map.

With **Settings > Gameplay > AI partner** off (`re_ai_partner 0`), no partner ever
appears (one already in the level leaves), and the select screens skip Both.

**Mouse:** in every menu (main menu, Settings and its pages, Cheats, Level
Select, Select Character), moving the mouse over an item highlights it, the
same way the keyboard does, and left-click picks it. In Level Select the
wheel scrolls the list and clicking the character or ID card switches it.
(`keys.cfg` sets `m_use_mouse 1`, GZDoom's `hover` mode.)

**Select Character:** the character under the cursor or keyboard is bright,
the others dark. Selecting **Both** plays a short animation from their RE1
models: Jill and Chris turn back to back and raise their guns, then hold the
aim stance. Picking Both asks which one you control, on the same kind of
screen.

**Main menu** (Enter on the title screen, or Esc in game; in game it has the small
RESIDENT DOOM logo above the list, while over the title picture it doesn't need one), in this order:
New Game, Level Select, Load Game, Save Game, Settings, Extras, Quit Game. In
game, **Main Menu** is added at the end.

**Extras** (main menu > Extras): Manual, Records, Cheats, Credits and Back, laid
out like the in-game main menu (small logo, the same size and place). From the
title screen a dark layer hides the big title logo behind it. Back, Esc or
right-click returns to the menu you came from.

**Manual** (`mod/zscript/RE_Manual.zs`): the player manual in 9 pages, with a
tab for each section (Controls, Characters, Items, Weapons, Saving, Lighting,
Records, Cheats). Left / Right turn the page, Up / Down jump between sections,
Esc goes back. With the mouse, click a tab, PREV, NEXT or BACK, use the wheel to
turn pages, and right-click to go back. The same text is in
[MANUAL.md](../MANUAL.md), so change both together.

**Settings** (GZDoom's own Options menu can't be renamed by a mod, so this is
our own menu opening the same GZDoom pages):
- **Controls (every action and its keys)**: a list of every Resident Doom action
  (tank movement, run, aim, fire, action, inventory, first / third person,
  jump, crouch, lighting mode, quicksave, weapons, menus) with the keys bound
  to it right now. It reads GZDoom's bindings live, so a key changed in
  Customize Controls shows there at once (`mod/zscript/RE_Controls.zs`).
- **Gameplay**: Resident Doom's own settings, below.
- **Controls**: Customize Controls, Mouse, Gamepad.
- **Video**: Display Options, Set Video Mode.
- **Audio**: Sound Options.
- **Advanced**: the rest of GZDoom's pages (player setup, Doom's own gameplay
  options, compatibility, automap, HUD, miscellaneous, network) and
  reset / save settings / console.

**Settings > Gameplay** (all remembered between launches):

| Option | Choices | Console |
|---|---|---|
| Save mode | Normal (save anytime) / Typewriter (typewriter only) / Classic RE (typewriter + Ink Ribbon) | `re_save_classic 0 / 2 / 1` |
| Lighting | Doom (default) / RE1 (also key L) | `re_dark 0 / 1` |
| Inventory style | Resident Doom (default) / RE1 Classic: RE1's own status screen and item box screen (see below) | `re_invstyle 0 / 1` |
| AI partner | on / off: off = no partner, and no Both choice | `re_ai_partner 1 / 0` |
| Partner pickups | Off (default) / On (RE5 style): the AI partner picks up only ammo for the gun they hold, and hands it to you with that gun when you swap guns | `re_partner_pickups 0 / 1` |
| Starting view | Third person (default) / First person, at every start: a new game, a level start, a loaded save and Continue; V still switches any time. New Game also asks it once, after the character (and partner), starting on this setting; your pick changes it | `re_start_view 0 / 1` |
| Flat corpses | Off (Doom) / First person only (default) / Both views. A dead monster's last picture (its corpse or gibs) lies flat on the floor (a GZDoom flat sprite) instead of turning to face you, so you can walk around it; the death fall plays as before, live monsters are never touched, and one an Arch-Vile brings back stands up again. The map's ready-placed dead bodies too (they keep their placed angle). Each body lies along the killing hit, head end away from whoever or whatever killed it (you, the partner, another monster, a projectile's flight, or away from an explosion's centre); `RE_Corpses.zs HeadSide` says which end of each Doom corpse and gib picture is the head. The flat picture must lie fully on the floor (no part over a drop, a ledge, a lift, under a low ceiling or through a wall). On stairs with normal steps (none higher than 24 under it) it's tilted to follow the slope, resting on the step edges, so it lies draped over several steps. If it doesn't fit as the body fell, it's slid up to 32 units, then turned to the 8-way direction nearest the fall that fits; if nothing fits, that body stays an upright Doom corpse, pushed fully onto one step so nothing hangs over an edge. Flat bodies are re-checked all the time, so one beside a lift that goes down is moved or stood up. Switching the view (V) or the setting updates the bodies at once. The flat picture is stretched 1.5× lengthways so a body seen from eye height isn't a thin line (`re_flat_corpse_stretch`, console, 0.5-3; 1 = unstretched) (`RE_Corpses.zs`) | `re_flat_corpses 0 / 1 / 2` |
| Jump (Space) | on / off (the Super Jump cheat works either way) | `re_allow_jump 1 / 0` |
| Crouch (C) | on / off (off: a crouching player stands up once there's room) | `re_allow_crouch 1 / 0` |

**Credits** (over a see-through dark layer, in the title screen's white text): made by ThoughtGnu with Claude Code; inspired by Drelvak and
drelvak's RE1 x Doom mod; RE1 decomp by ecruells (GPL-3.0); built with GZDoom; Resident Evil ©
Capcom, DOOM II © id Software; fan-made and not affiliated.
**Level Select** (main menu > **Level Select**):
- **Up/Down:** pick a level. A picture of it shows on the right.
- **Left/Right:** Jill or Chris, shown with their S.T.A.R.S. ID card from
  RE1's own character-select screen.
- **Enter:** start that level with that character, as a fresh game at the
  current difficulty, straight into the level.

The list has every Doom II map (MAP01–MAP32), then "Mansion - (custom level)"
and **FINAL BOSS** at the bottom. Final Boss starts MAP30 standing on the arena's lift, raised
so the Icon of Sin's brain is in view. Aim at it and fire. The RE weapons can
destroy it even though they have no splash damage:
- 2 bazooka hits
- 1 rocket
- 5 shotgun blasts
- about 28 Beretta shots

From the console, `re_bossfight` starts the Final Boss directly.

**The ending cast call.** After the Icon of Sin, Doom II's cast call ends with
whoever played instead of Doomguy ("OUR HERO"): **CHRIS REDFIELD**, **JILL
VALENTINE**, or both one after the other (Chris, then Jill) when both played.
"Both" means you and the AI partner, or both characters in a network game. The
heroes walk with the Beretta, raise it, aim and fire when it's their turn, and
die with RE1's death animation and death scream (`Jill04` / `Chris04`, the
voice RE1 plays when the player dies) when you press fire. Every monster is
Doom II's own, unchanged, and the list loops back to the first monster after
the last hero. The rest of the ending (the level stats with Records, Doom II's
text) is as before.
- The cast call can only draw flat sprite pictures, not 3D models, so the
  heroes are pictures made from their RE1 models with RE1's own animations:
  `re1convert castsprites <RE1 USA> mod` writes `mod/graphics/cast` and
  `mod/textures.cast.txt`. Chris turns toward his side as he falls: RE1's fall
  is straight forward, which a front view can't show.
- The cast lists are in `mod/mapinfo.txt` (`RE_CastJill`, `RE_CastChris`,
  `RE_CastBoth`); `RE_Cast.zs` picks one when the Icon dies.
- From the console: `re_castcall` goes straight to the cast call for whoever
  is playing now (with the partner); `re_castcall_jill`, `re_castcall_chris`
  and `re_castcall_both` show one version.

**Inventory style "RE1 Classic"** (Settings > Gameplay, `re_invstyle 1`):
RE1's own status screen and item box screen, drawn with RE1's own pictures,
placed as RE1's code places them (`MainMenu.cpp` in the decomp). The menus'
rules don't change; only drawing and mouse areas switch (`RE_InvClassic.zs`).
- **Status screen:** the frame for Jill (8 slots) or Chris (6); the portrait;
  RE1's item pictures with counts in its green / orange / red digits; the
  equipped weapon; the blinking cursor frame; the EQUIP / USE / CHECK / COMBN
  buttons, and a GIVE button in the same style for the partner (RE1 has none:
  the converter builds it from RE1's own button letters; with four buttons the
  list starts one button higher). CHECK shows the item large
  in the big window, with its description below.
- **The ECG:** RE1's 20 wave shapes and colours sweeping across, with the
  blinking condition word (Fine, Caution, Danger, Poison), exactly as RE1's
  code does it: the line is green or yellow with "Fine", orange with
  "Caution", red with "Danger!"; while poisoned the line keeps its health
  colour and only the word turns purple ("Poison!").
- **The tabs:** MAP opens the map screen, FILE the Manual, EXIT closes. RADIO
  is blank, as RE1 shows it without a radio. Up from the top row of slots
  reaches them.
- **Item box:** RE1's 3-row box list in the big window (the middle row is the
  chosen box slot) with its picture and arrows, over the status screen.
- **The pictures are made from your RE1 files** by
  `re1convert statusart <RE1 USA> mod`, which writes
  `mod/graphics/re1status/*.png` and `mod/re1status.txt`. The frame is put
  together from STATUS.TIM pieces the way RE1's `menu_draw_inventory` does
  it. The other pictures are Statface.tim, BLUE.TIM, ITEM_ALL.PIX, ITEMBOXn.TIM
  and fontus.tim. `re1status.txt` is RE1's item picture table, read from your
  `ResidentEvil.exe`.
  (`re1convert timdump <file.tim> <folder>` writes every palette of a TIM, for
  looking.)

**MAP30's camera:** while the Icon of Sin lives, the third-person camera keeps
you and the face in the wall in the picture together, so the whole fight can be
played in third person (`BossTick` in `AutoCamera.zs`). It uses spots that
follow you, behind you on the far side from the face, so you stand large in
front and the face rises behind you, plus hand-placed spots high around the
arena. Each one is aimed between you and the face with a lens just wide enough
for both, preferring views where you don't cover the brain's hole and that also
show the partner. In the closed start room of a normal MAP30 game the face
can't be seen, so the usual cameras are used until you reach the arena.

**Cheats** (main menu > Extras > **Cheats**, from the title screen or Esc in-game). The
**Cheat List** at the top of that screen shows every cheat, what it does and its
console command:
- **Infinite Ammo**: guns never use rounds, and an empty gun fires anyway.
- **Invincibility**: no damage.
- **All Weapons**: every RE weapon outside your item slots, each fully loaded.
  Rounds and fuel are used up as usual (each gun keeps its own count when you
  switch); only Infinite Ammo makes them endless. It never switches your
  weapon for you: you keep what you had in your hands (the Beretta if you had
  nothing):

  | Key | Weapon |
  |---|---|
  | 1 | knife |
  | 2 | Beretta |
  | 3 | shotgun |
  | 4 | Colt Python |
  | 5 | bazooka |
  | 6 | rocket launcher |

  The mouse wheel also cycles through them. The status screen shows the gun in hand marked (ALL WEAPONS CHEAT); cheat
  weapons take no slots. Select the EQUIPPED box (Left from the left column of
  slots) and press Enter to give that gun to the AI partner (GIVE TO JILL /
  CHRIS, partner close by, otherwise grayed out "Too far away"). You keep it,
  the partner gets a fully loaded one, and their old weapon is not traded back. Switching it off leaves only the
  weapon equipped from your slots.
- **Super Jump**: much higher jumps, about 200 units instead of 32. Low
  ceilings still stop you, and the cameras keep you in view.

**Cheat codes** (type them in the console, `~`, with or without a trailing period,
e.g. `starsteam` or `starsteam.`; a short message shows when one works, in the
message box and as a line at the top left):

| Code | Does |
|---|---|
| `starsteam` | invincibility on / off |
| `rocketman` | all weapons (the All Weapons cheat) |
| `jillsandwich` | full health |
| `inkribbon` | 3 Ink Ribbons (at your feet if your slots are full) |
| `re_jillflamer` | Jill may use the flamethrower too: it goes straight into her hands with a full tank (in a free slot), chaingun spots stay flamethrowers for her (from the next map), and All Weapons gives her key 7. In third person she holds RE1's real flamethrower (Chris's model and pose on her body), and first person shows Chris's arms (RE1 has no Jill flamethrower). Its fuel runs down like Chris's unless Infinite Ammo is on. Counts as a cheat for Records. |

They are also on the Cheat List page.

Both work for Jill and Chris and switch off again when you quit. The console
settings are `re_cheat_ammo`, `re_cheat_god` and `re_cheat_jump` (e.g. `re_cheat_god 1`).
`re_superjump` switches Super Jump on and off, and `re_allweapons` switches All
Weapons (`re_cheat_weapons`).

**Saving: typewriters and Ink Ribbons.** Every map has an RE1 typewriter next
to the item box near the start (or beside you if there's no room by the box).
Long maps also get a second one about halfway to the exit: a quiet spot at
least 256 units from where any monster starts, never inside a new room. A
typewriter never blocks a way through: there is always at least 48 units of
floor to walk past it, and it keeps clear of the item box. 19
of Doom II's 32 maps have one. Face a typewriter and press E.

The **Save mode** option (Settings > Gameplay, console `re_save_classic`) decides
how saving works:
- **Typewriter (typewriter only)** (`re_save_classic 2`): saving only works at
  a typewriter, as in Classic, but no Ink Ribbon is needed ("Save your
  progress?"). The menu's Save Game and F6 say to find a typewriter.
- **Normal (save anytime)** (the default): the typewriter asks "Save your
  progress?" and needs no ribbon. The menu's Save Game and F6 work as
  usual.
- **Classic RE (typewriter only)** (`re_save_classic 1`), like RE1:
  - The typewriter asks "Will you use an INK RIBBON?", and each save uses
    one ribbon.
  - If you back out of the save screen without saving, you keep the ribbon.
    With no ribbon, there's no save.
  - The menu's Save Game and F6 only say to find a typewriter.
  - GZDoom's own automatic saves at the start of a map still happen.

**Dying (Continue, like RE1).** The death screen continues with **Space or E**.
These are read as the keys themselves (`REInputBridge.ContinueKey` in
`RE_Input.zs`), so they work however keys are bound, and a key bound to Action
works too. GZDoom's own "press Use to restart" is switched off. Where you
continue (`RE_Continue.zs`), and the screen says which:
- **Saved on this level** (Normal save, F6, a typewriter, a Classic RE ribbon
  save) **or loaded a game since you got here:** back to that most recent save.
  This uses GZDoom's own "last save", which is that save.
- **Not yet:** the level starts again, and you have exactly what you had when
  you entered it: item slots and counts, the weapon in your hands and its
  rounds, All Weapons' per-gun rounds, health, armor, poison, the lighter /
  chemical time left, and the partner's poison. The level itself (monsters,
  doors, items) starts fresh. A save on an earlier level doesn't count: you get
  this level's start.
- **No Ink Ribbon is used** by continuing.
- **The AI partner** comes back with you: as saved, or with the gun every level
  starts them with.
- **Loading a game** (by Continue or Load Game) starts with no message on screen. The message is saved with the game, so a leftover like "You picked up the INK RIBBON." used to show again though nothing was picked up. A Continue says "Continue: your last save." or "Continue: the start of this level.".
- **After continuing,** the Space or E you pressed doesn't count until you let
  go, so it can't pick up an item lying next to you. The same goes for an E
  held through the "Entering ..." screen.
- **Network games:** a game can't be reloaded for one player, so a player who
  dies respawns at the level start with their own entry snapshot.

Before this, dying (only E worked) loaded GZDoom's last save. That was the
arrival autosave after an exit, or a save made on the level. After Level
Select or New Game with no save, it restarted the level as a brand-new game:
knife, Beretta 15 and First Aid Spray only.

**Ink Ribbons** stack 3 to a slot, like RE1. Each one you find is a single ribbon:
- every map: one beside the typewriter at the start
- long maps (19): one beside the halfway typewriter
- MAP01: the start ribbon lies in the start room (where a green herb was), and a
  second one in the corner of the railed balcony

That is 53 in the whole game. A new game starts with none, in every save mode.
**The start of every map is decided before you see it.** While the map loads
(`REStartLayoutHandler` in `RE_ItemBox.zs`), the opening camera is chosen, the
item box, the typewriter a few steps from it, the start ribbon, Item Balance's
herbs and clip and the partner are put where the camera shows them, and every
item gets its angle and glow. So nothing moves, turns or jumps once the map is
shown (Doom's screen melt shows that same first picture). Nothing this mod
places goes in liquid, on a floor that hurts, or on or under Jill, Chris or the
partner; the partner also never stands between the camera and you, the box or
the typewriter, and waits where they appear until you move.

**Hand-placed starts** (`StartLayout` in `RE_ItemBox.zs`): MAP01's typewriter
stands in the front-left corner of the start room and MAP07's at the far end of
the start corridor; MAP03, MAP04, MAP06, MAP09, MAP17 and MAP29 have small start
areas where the box and typewriter are placed by hand (MAP03, MAP06, MAP09, MAP17
and MAP29 also with a hand-picked opening camera, and MAP06, MAP09, MAP17 and
MAP29 a spot for the partner). Every other map
places the typewriter a few steps from the item box, where the opening camera
sees both.

**Never in the way:** the item box and the typewriters (start and halfway)
never stand across a narrow corridor, in front of a narrow opening (a doorway
or a crawl gap with walls at both ends) without room to walk past, or right in
front of a door, even one that's only drawn on a wall (`BlocksWalkway` in
`RE_ItemBox.zs`). Every map's placements pass this; MAP03's typewriter, and
MAP04's and MAP06's boxes, were moved to the side for it.

**Item models.** Herbs, Ink Ribbons, every ammo pickup (clip, shells,
Magnum rounds, explosive / acid / flame grenade rounds), the First Aid Spray, the
keys and crests, the Chemical and the Lighter are RE1's own 3D item
models: the ones RE1 shows when you examine an item (`Item_m2\IxxV.IVM` in your
GOG folder), which its inventory pictures (`Data\ITEM_ALL.PIX`) were drawn
from. Each texture's brightness is matched to its inventory picture (RE1's
textures are unlit), with a small colour nudge towards it; the clip and the
ribbon tin lie flat, the rest stand as RE1 shows them, all about herb-sized and a
little brighter than the room. Doom's rocket ammo becomes explosive grenade
rounds (RE1 has no separate rocket ammo). Rebuild them with
`re1convert items "<RE1 USA folder>" mod\models\props\items`;
`re1convert itemsheet "<RE1 USA folder>" out.png` draws them next to RE1's pictures.
The keys and crests are made bigger than RE1's (16 units long) so you spot them
on the floor, and tinted with their Doom colour. RE1 has no map item model, so
the MAP is a sheet on the floor showing RE1's own map picture (`Item_m2\MAP00.TIM`),
written by the same command. Doom's other armor bonuses become small S.T.A.R.S. vest patches (the light
vest's model, a third the size), still +1 armor. Every weapon on the floor is RE1's
own item model of it too (knife `I05V`, Beretta `I00V`, shotgun `I02V`, Colt Python
`I04V`, bazooka `I08V`, rocket launcher `I07V`, flamethrower `I01V`), lying flat,
built by the same command.

**Item balance** (`mod/zscript/RE_Balance.zs`, every map start): too little
healing (under 2 herbs + sprays) adds green herbs by the item box; no clips adds
one; a gun lying in a map with no ammo for it gets one pickup beside it; 20+ of
one ammo kind is thinned to 15, 15+ herbs to 12 (green ones only; red and blue
are all kept), 20+ vest patches to 12, taking away evenly spread ones so the rest
stay in their Doom spots. Maps with Arachnotrons or the Spider Mastermind get
blue herbs (1 for 1-2 of them, 2 for 3-5, 3 for 6 or more, counted on the
difficulty you play), each set beside the green herb nearest one of those
enemies, so no healing is taken away (no green herb near: beside the nearest
other item). `re_debugcams 1` prints the counts before and after, and where
each blue herb went.

**Poison** (`mod/zscript/RE_Poison.zs`): Arachnotrons and the Spider
Mastermind are RE1's spiders. When their attacks hurt you, you're poisoned:
like RE1 (its poison timer: 150 frames, then 120), you lose 2 health about
5 seconds after being poisoned and then 2 every 4 seconds, and the status
screen shows **POISON** in purple with a purple bar. There's no health number
on screen, so the drain only shows as the condition drops (Caution after about
50 seconds from full health for Jill). Poison alone stops at 1 health and never kills you,
but any hit after that can. It carries over to the next map and into saved
games. A Blue Herb or a mix with one (Green+Blue, Green+Red+Blue,
Green+Green+Blue) cures it; like RE1, a herb is only used up if it did
something. The AI partner can't be hurt, so for them poison is a purple glow and
a second more between shots. An Arachnotron's plasma hitting them, or standing
in the Spider Mastermind's line of fire, poisons them. Cure them with GIVE TO and a
blue herb or blue mix (the command shows while they're poisoned).

**Secret areas:** each map's first secret (Doom's secret sectors, in map order)
gets a S.T.A.R.S. vest, light up to MAP20 and heavy from MAP21, unless it already
has armor; if it has no room, the next secret gets it (`RESecretVestHandler` in
`RE_Balance.zs`). The per-map list is in [secrets_per_map.md](secrets_per_map.md).

**First person never equips a weapon:** switching views, crouching, the
inventory, level changes and loading keep whatever you hold; unarmed, first
person shows no weapon.

**Armed idle:** standing still with a gun (not aiming), Jill and Chris (and the
AI partner) hold it low: the Beretta and Colt Python at the side in the right
hand pointing at the floor, the other arm relaxed; the shotgun and bazooka carried
diagonally across the front of the body, the single reference being Jill's RE1
forward walk with the shotgun: its arm and gun position goes on the standing
idle, the forward walk (also used to turn in place) and the backwards walk, for
Jill as it is and for Chris adjusted to his skeleton (`Crouch.Carry`; preview
with `re1convert carrysheet <jill|chris> <RE1 USA> out.png`); the legs keep
their own animation; the rocket launcher on the right
shoulder, four-barrel end forward and back end behind the shoulder, for standing,
walking forward, walking backwards and turning: each character's own RE1 aim
hold arms (Chris's has the launcher the right way round), turned so the tube
points straight ahead, lowered onto the shoulder and moved out, clear of the head. With the knife they stand knife-ready:
RE1's idle breathing with the arms of their own RE1 knife walk (knife low in the
right hand, blade turned forward and down, left arm at the side;
`Crouch.KnifeIdle`, preview `re1convert knifesheet`). Unarmed, Jill uses RE1's own idle (hand on her hip). Chris's own RE1 unarmed idle is a "thinking" pose (arm folded across his chest, gloved hand at his chin) that looked from the game cameras like him pulling out a shotgun a moment after every map started, so he keeps that idle's breathing with the arms of his RE1 unarmed walk, hanging at his sides (`Crouch.RelaxedIdle`). (`Crouch.ArmedIdle` in `tools/re1convert`;
`re1convert armedsheet <jill|chris> <RE1 USA> out.png` previews it.) Herbs are
drawn 1.3x their RE1 size so they show from the fixed cameras.

**First-person view (V):** Doom's movement and mouse look. Weapons work like
RE1:
- Not aiming, Jill holds the weapon lowered at her side (lower right).
- Hold Aim (right-click or Ctrl) to raise it into view in her own hands, both
  hands on it where RE1 uses a two-handed grip.
- E (or left-click) fires while aiming. She can't walk while aiming, but the
  mouse still turns.

If nothing is equipped when you switch, the Beretta is equipped for you. Press
V again to go back to the fixed cameras and tank controls, which is how every
game starts.

You start with **nothing equipped**. Open the inventory, pick the Beretta and
choose EQUIP.

In the inventory:
- Arrows move, Enter (or a left-click) opens the item's commands (EQUIP or USE, CHECK,
  COMBINE), Esc goes back, Tab closes.
- To reload, COMBINE ammo with its gun.
- COMBINE the bazooka with a different kind of round to switch rounds, like
  RE1.
- To mix herbs, COMBINE one herb with another (RE1's recipes: Green+Green,
  Green+Red, Green+Blue, then a third herb onto Green+Green, Green+Blue or
  Green+Red).

**Item boxes:** Jill has RE1's 8 slots. Picked-up ammo first tops up a
part-full stack of the same kind (clip 15, shells 7, magnum and bazooka rounds
6). When nothing fits, the item stays on the floor. Every map has an item box
near the start: RE1's own item box, a low wooden chest with RE1's real lid model,
built from your RE1 files (`re1convert itembox "<RE1 USA folder>" mod\models\props`,
which reads the lid from `Stage1\ROOM1000.RDT`; RE1 paints the box's body into its
backgrounds, so the body is made to match the lid). Face it and press E: like RE1,
the lid swings open first, then the box screen appears, and it closes again when
you leave.
All boxes share the same 48 slots, like RE1, so what you store on one map is
waiting in the next.

### Doom II's items become RE1's

| Doom II | RE1 |
|---|---|
| Shotgun | Shotgun (7 shells) |
| Super Shotgun | Colt Python (6 magnum rounds) |
| Rocket Launcher | Bazooka (grenade launcher), explosive rounds |
| Plasma Rifle | Bazooka, acid rounds |
| BFG9000 | Rocket launcher (4 rockets) - RE1's own super weapon (900 damage, no reload); RE1 has nothing like the BFG |
| Pistol | Beretta |
| Chaingun | Chris: Flamethrower (240 fuel). Jill, or dropped by a chaingunner: Clip |
| Chainsaw | Ammo for a gun you carry (the equipped one first), or a clip: both start with a knife |
| Clip, box of bullets | Clip (15) |
| Shells, box of shells | Shells (7) |
| Rocket, box of rockets | Explosive rounds (6) |
| Energy cell / cell pack | Acid rounds / flame rounds (6) |
| Backpack | Magnum rounds (6) |
| Stimpack, Medikit | Green Herb |
| Berserk | Red Herb (mix it with a green one) |
| Soulsphere | First Aid Spray |
| Megasphere | First Aid Spray + the heavy vest (200 blue armor), like Doom II's |
| Green armor | light S.T.A.R.S. vest (same armor: 100, 33%) |
| Blue armor | heavy S.T.A.R.S. vest (same armor: 200, 50%) |
| Blue keycard / yellow keycard / red keycard | Armor Key (blue) / Sword Key (yellow) / Shield Key (red) |
| Blue / yellow / red skull key | Helmet Key (blue) / Star Crest (yellow) / Sun Crest (red) |
| Radiation suit | Chemical (same protection from toxic floors, same length) |
| Light amplification visor | Lighter (2 minutes: a small flickering flame, a warm light bright a few metres around you that fades with distance, so far corners and other rooms stay dark; both views, both lighting modes; no green night vision) |
| Computer area map | Map (the whole level on the map screen, key M) |
| Partial invisibility | Clip (15) - RE1 has nothing like it |
| Invulnerability | First Aid Spray - RE1 has nothing like it |

**Field of view (first person):** Settings > Video > Field of View, 75-120
(default 90). It's GZDoom's own fov setting, so it's remembered between
sessions; changed from the pause menu, the view behind the menu follows at once
(`REFovHandler`, RE_View.zs). The fixed cameras keep their own view.

**Records** (`mod/zscript/RE_Records.zs`, main menu > Extras > Records): your best results
per map, kept only on this PC. A map counts as finished when you trigger its
exit (or kill the Icon of Sin on MAP30; Level Select's Final Boss has its own
record). Kept for each map, character and difficulty: the fastest clear time,
with that run's kills %, secrets %, items %, saves made on the map (Ink Ribbons
used) and the date. The level-end screen says **NEW RECORD** when you set or
beat one (MAP30 and the Final Boss say it on screen). A run where a cheat was
on at any time - Infinite Ammo, Invincibility, Super Jump, All Weapons, the
JILLSANDWICH / INKRIBBON codes, or GZDoom's god, buddha, noclip, notarget - isn't
saved: "Cheats used, record not saved". (GZDoom's `give` and `summon` can't be
detected.) Loading a save made before the cheat counts as clean. The Records
screen picks character and difficulty at the top (Left/Right, or click the
< > arrows), scrolls with Up/Down or the mouse wheel, highlights what's under
the mouse, and has CLEAR RECORDS (a YES / NO box, keys or mouse) and BACK
(or right-click). Records are
stored in GZDoom's settings file when you quit the game; a crash loses that
session's new ones. The Mansion has no exit yet, so it shows `---`.
F6 saves count when you press F6 (even if you then cancel an overwrite prompt).

**Items %** counts every RE pickup you take (herbs, ammo, guns, sprays, ribbons,
vests, keys, power-ups). Items the game removes (thinned out, replaced) and
drops from monsters or from you don't count, so 100% is reachable.

**Map screen** (`mod/zscript/RE_Map.zs`, key M): RE1-style, replacing Doom's
automap. A dark blue screen with the rooms filled in blue (the room you're in
brighter), walls in light blue, doors orange, locked doors in their key's colour,
the exit green, a pulsing red arrow for where you are and which way you face,
and a smaller pink arrow for the AI partner (north is up). Only doors you open
yourself are marked; switches and floor triggers that open a door elsewhere aren't. It shows the walls you've seen, and fills a room once you've
been in it or seen at least half its walls (a far-off glimpse doesn't fill it);
after the MAP pickup, the whole level (unvisited areas darker). The game pauses while it's open; M or Esc
closes it, +/- or the mouse wheel zoom, the arrow keys move. It looks the same in
both lighting modes. A key still bound to Doom's automap in your GZDoom settings
(from an older version) opens this screen too.

**Keys and power-ups** (`mod/zscript/RE_DoomKeys.zs`): picked up by walking over
them, like Doom's, and they don't take an item slot. A key gives you Doom's own
key behind the scenes, so every Doom door works as before; the message names
its colour ("You got the ARMOR KEY (blue)."). Doom's green screen tint while the
radiation suit (Chemical) protects you only shows in first person, so in both
views a small line top left shows the time left ("CHEMICAL 0:57"); the Lighter
has one too ("LIGHTER 1:42"). In their last 5 seconds they turn orange and blink.

**Flamethrower (Chris only, as in RE1):** RE1 gives it only to Chris (his
own flamethrower motions, `W05`; Jill has none). Doom's placed chainguns become
it when you play Chris (23 on normal difficulty, in 21 maps); playing Jill, or
dropped by a chaingunner, they stay clips. Its fuel is its number in the slot:
240, a full tank lasts 9 seconds of flame (RE1's own description). Hold Aim to
raise it, hold Action to flame: RE1's fire motion loops, RE1's flamethrower
sound plays, and RE1's fire bursts (from `Effspr\esp001.tim`) shoot out about 4
metres, 20 damage each (RE1's flame against a zombie), lighting up the area.
No refuelling (RE1 never places its FUEL item): another flamethrower tops
yours back up to 240. Empty, it clicks. A partner Jill can't take it. The All
Weapons cheat gives it to Chris. `summon REFlamethrowerPickup` puts one in front
of you.

**Vests (armor):** Doom's green and blue armor work exactly as before, but lie on
the floor as 3D S.T.A.R.S. vests. While you have armor, Jill or Chris wears the
matching vest, which moves with their RE1 animations:
- **Light (green armor):** navy, with pockets and a S.T.A.R.S. patch.
- **Heavy (blue armor):** olive plates with shoulder pads.

When your armor runs out, the vest disappears. This covers every source of
armor: map pickups, secrets, the Megasphere, and cheats.
| Health bonus | removed |
| Armor bonus | a small S.T.A.R.S. vest patch (+1 armor, picked up by walking over it) |

Picking up a gun you already have gives its ammo instead. Damage is RE1's own
against a zombie:

| Weapon | Damage |
|---|---|
| Knife | 8 |
| Beretta | 9 |
| Shotgun | 53, wider hit area |
| Colt Python | 130 |
| Bazooka | explosive 201, acid and flame 95 |
| Rocket launcher | 900 |

The sounds are RE1's, copied from your GOG folder into `mod/sounds/re1/`.
## What's in this folder

| Path                          | What it is |
|-------------------------------|------------|
| `play.bat`, `play_doom2.bat`  | start the game (our mansion / Doom II's levels) |
| `host_coop.bat`, `join_coop.bat` (`.command` on a Mac) | online co-op: host as Jill / join as Chris |
| `keys.cfg`                    | the key setup both launchers load (edit to change keys) |
| `MANUAL.md`, `mod/zscript/RE_Manual.zs` | the player manual, on GitHub and in the game (main menu > Extras > Manual) |
| `iwad/`                       | copies of `doom2.wad` and `id24res.wad` from your GOG install |
| `tools/gzdoom/`               | GZDoom 4.14.2, portable. Its settings and saves stay in this folder (`gzdoom_portable.ini`) |
| `tools/pack_map.ps1`          | rebuilds the mansion map file after you edit the map text |
| `tools/re1convert/`           | converts Jill and Chris from your RE1 files into GZDoom models (see below) |
| `mod/`                        | the mod itself (GZDoom loads this whole folder) |
| `mod/models/jill/`, `mod/models/chris/` | each character's models (one per weapon), first-person arms and texture |
| `mod/modeldef.txt`            | tells GZDoom which model draws each character and weapon |
| `mod/zscript/RE_CharSelect.zs`, `mod/menudef.txt` | the Jill / Chris select screen; the main menu with Cheats, and the Cheats screen |
| `mod/zscript/RE_Cheats.zs`    | Invincibility (Infinite Ammo is in `RE_Items.zs`) |
| `mod/zscript/RE_MidTypewriter.zs` | the halfway typewriter in long maps |
| `mod/language.txt`            | the "Return to the main menu?" question |
| `mod/zscript/RE_Typewriter.zs` | typewriters, Ink Ribbons, the save modes, F6 |
| `mod/models/props/vest_*.iqm`, `vest.png` | the vests on the floor (`re1convert prop vests mod\models\props`). The worn vests are inside each character's models (`<char>_<weapon>_vest1/2.iqm`, made by `re1convert character`; `Vest.cs`) |
| `mod/models/props/herb_*.iqm`, `herb.png` | the herbs on the ground: small plants in clay pots (green, red, blue), built by `re1convert prop herbs mod\models\props` |
| `mod/models/props/typewriter.iqm`, `typewriter.png` | the typewriter: a low-poly 3D typewriter on a small wooden table, built by `tools\re1convert\re1convert.exe prop typewriter mod\models\props` (`Prop.cs`) |
| `mod/graphics/TYPEBACK.png` | the save prompt's background, from RE1's `Data\TYPE00.TIM` |
| `mod/zscript/RE_Partner.zs`   | the AI partner (Both) |
| `mod/graphics/RELOGOHR.png`, `mod/textures.txt` | the RESIDENT DOOM logo above the in-game pause menu: RESIDENT cut from the title picture, DOOM from the original DOOM's `M_DOOM` (`re1convert titleart`, reading doom.wad next to your doom2.wad, or DOOM II's own logo without it) |
| `mod/graphics/SELBT00.png`–`SELBT24.png` | the Both animation on the select screen: Jill and Chris turn back to back and raise their guns (`re1convert bothanim`, from their RE1 models) |
| `mod/zscript/RE_LevelSelect.zs` | the Level Select screen and the Final Boss start |
| `mod/graphics/CARDJILL.png`, `CARDCHRS.png` | the ID cards on the Level Select screen, from RE1's `Data\Select_b.tim` |
| `mod/graphics/LV*.png`        | Level Select pictures: screenshots of each level from your own game (`LVBOSS`, `LVRE`, `LV01`–`LV32`) |
| `mod/graphics/SEL*.png`       | its pictures: RE1's select background (`SEL_BACK.PIX`) and the two characters |
| `mod/zscript/TankPlayer.zs`   | tank controls, aiming, action button, Jill's animations |
| `mod/zscript/FixedCamera.zs`  | hand-made fixed cameras and RE1's camera-switch rule |
| `mod/zscript/AutoCamera.zs`   | automatic cameras for maps without hand-made ones |
| `mod/recams.txt`              | the mansion's cameras and switch zones |
| `mod/zscript/RE_Lighting.zs`  | darker RE1-style lighting (switchable), and the light that follows the character |
| `mod/zscript/RE_Inventory.zs` | the 8 slots: pick up, use, equip, combine |
| `mod/zscript/RE_InventoryMenu.zs` | the inventory screen |
| `mod/zscript/RE_Items.zs`     | item ids, names, healing, herb recipes, pickups, weapons |
| `mod/zscript/RE_Poison.zs`    | poison from Arachnotrons and the Spider Mastermind |
| `mod/zscript/RE_DoomItems.zs` | turns Doom II's items into RE1's |
| `mod/zscript/RE_DoomKeys.zs`  | Doom's keys and power-ups as RE1 items |
| `mod/zscript/RE_Map.zs`       | the RE1-style map screen (key M) |
| `mod/zscript/RE_ItemBox.zs`  | the linked item boxes and the box screen |
| `mod/models/props/itembox.md3`, `itembox.png` | the item box model with its opening lid (`re1convert itembox`, `ItemBox.cs`) |
| `mod/sounds/re1/`             | RE1's weapon sounds |
| `mod/hires/TITLEPIC.png`     | the title screen: RE1's title art (`TITLE.PIX`) with the DOOM logo from the original DOOM's doom.wad (`M_DOOM`, without the "II"). Made from your own game files, for your own use. The text on it (PRESS ENTER TO PLAY, credits) and the Enter-only key are `mod/zscript/RE_Title.zs` |
| `mod/graphics/M_DOOM.png`     | an empty picture, so the main menu doesn't draw a second DOOM logo over the title |
| `mod/zscript/RE_Const.zs`     | RE1's speeds and turn rates, converted |
| `mod/maps/src/TEXTMAP.txt`    | the mansion map, as text |
| `mod/maps/REMAP01.wad`        | the packed mansion map GZDoom loads |
| (not in the repository)       | the RE1 decompilation source, used as a reference: github.com/ecruells/resident-evil-pc-decomp (GPL-3.0) |
| `docs/RE1_NOTES.md`           | plain-English notes on how RE1 does each mechanic |

## The characters' models

`tools\re1convert\re1convert.exe` reads Jill and Chris straight from your GOG
RE1 folder (read only) and writes `mod\models\jill\` and `mod\models\chris\`.
To rebuild:

```
tools\re1convert\build.bat
tools\re1convert\re1convert.exe character jill  "<RE1 USA folder>" mod\models\jill
tools\re1convert\re1convert.exe character chris "<RE1 USA folder>" mod\models\chris
tools\re1convert\re1convert.exe character chris "<RE1 USA folder>" mod\models\chris flame     (one weapon only)
tools\re1convert\re1convert.exe flamesprites "<RE1 USA folder>" mod\sprites\re     (RE1's fire frames RFLMA0-T0)
tools\re1convert\re1convert.exe portrait  jill  "<RE1 USA folder>" mod\graphics\SELJILL.png
tools\re1convert\re1convert.exe portrait  chris "<RE1 USA folder>" mod\graphics\SELCHRIS.png
tools\re1convert\re1convert.exe bothanim "<RE1 USA folder>" mod\graphics
```

Each character gets one model per weapon (`<char>_<weapon>.iqm`) with RE1's
own animations:
- idle, walk (also used for turning), run
- back up
- raise weapon, aim, fire
- hit, death

`re1convert sheet` draws a picture of every pose, for checking. These are
Capcom's assets from your own copy, so keep them to yourself.

| | Jill | Chris |
|---|---|---|
| Body file | `CHAR11.EMD` | `Char10.EMD` |
| Unarmed | W10 | W00 |
| Knife | W11 | W01 |
| Beretta | W12 | W02 |
| Shotgun | W13 | W03 |
| Colt Python | W14 | W04 |
| Bazooka | W16 | W06 |
| Rocket launcher | W17 | W07 |

These come from the decomp's `EntityModelLoader.cpp`. Every gun uses RE1
animations 1 idle, 2 walk, 3 run, 5 raise, 6 fire, 7 hold.

### First-person arms

In first person you see the character's own forearms, gloves and weapon, made
by `re1convert viewarms`. Each weapon's model has these frames, all RE1's own
animations seen from the character's eyes:
- **lowered**: the idle pose
- **raise**
- **hold**: aimed
- **fire**, one frame per tick: recoil, shotgun pump, knife slash

The converter places each weapon on screen by its size. The left hand only
shows while it's on the weapon, and the knife is turned to point forward.

To rebuild them all, run this for each character and weapon (`<RE1>` is the
RE1 USA folder):

```
tools\re1convert\re1convert.exe viewarms <RE1> mod jill  knife   JKN REKnife
tools\re1convert\re1convert.exe viewarms <RE1> mod jill  beretta JBR REHandgun
tools\re1convert\re1convert.exe viewarms <RE1> mod jill  shotgun JSG REShotgun 0 0 5
tools\re1convert\re1convert.exe viewarms <RE1> mod jill  magnum  JMG REMagnum
tools\re1convert\re1convert.exe viewarms <RE1> mod jill  grenade JGL REGrenadeLauncher
tools\re1convert\re1convert.exe viewarms <RE1> mod jill  rocket  JRL RERocketLauncher 0 0 0 38 -8 -17
tools\re1convert\re1convert.exe viewarms <RE1> mod chris knife   CKN REKnife --pose-from jill
tools\re1convert\re1convert.exe viewarms <RE1> mod chris beretta CBR REHandgun --pose-from jill
tools\re1convert\re1convert.exe viewarms <RE1> mod chris shotgun CSG REShotgun 0 0 5 --pose-from jill
tools\re1convert\re1convert.exe viewarms <RE1> mod chris magnum  CMG REMagnum --pose-from jill
tools\re1convert\re1convert.exe viewarms <RE1> mod chris grenade CGL REGrenadeLauncher --pose-from jill
tools\re1convert\re1convert.exe viewarms <RE1> mod chris rocket  CRL RERocketLauncher 0 0 0 38 -8 -17 --pose-from jill
tools\re1convert\re1convert.exe viewarms <RE1> mod chris flame   CFL REFlamethrower 0 0 0 4 -6 -4 --point-forward
```

The arguments are, in order:
1. the mod folder
2. the character
3. the weapon
4. a 3-letter sprite prefix (J.. for Jill, C.. for Chris)
5. the weapon class

After those come optional nudges, in map units (forward, left, up): first for
the lowered view, then for the aimed view.

`--pose-from jill` poses the arms with Jill's weapon animations while keeping
the character's own arms, gloves and weapons. Chris uses it, because his RE1
Beretta pose holds the gun across his body, which looks sideways from his
eyes. His third-person animations stay his own.

Each run writes, in `mod/models/<char>/`:
- `arm_<char>_<weapon>.md3`: the model
- `arm_<char>_<weapon>.txt`: the frame layout. The game reads it, including the
  raise and fire lengths used for third-person timing.
- `arm_<char>_<weapon>.mdl`: the MODELDEF block

It also writes invisible 1x1 placeholder sprites in `mod/sprites/viewarms/`.
GZDoom needs a picture for every frame a model replaces.

**Adding another RE weapon later:**
1. Add its EMW file to both characters' lists in `Program.Files` and its
   name to `Program.WeaponNames`.
2. Run `character` and `viewarms` for both characters.
3. Add both `#include` lines to `modeldef.txt`.
4. Add the sprite prefixes to `REArmSprites` in `RE_Items.zs`.
5. Write a short `REGun` subclass like `REMagnum` (`REWeapon.Arm`, damage,
   sound). Then give it an item id in `REItemInfo`.

**Adding another character** (Barry `CHAR12.EMD`, Rebecca `CHAR13.EMD`):
1. Add them to `Program.Files`.
2. Add a `RETankPlayer` subclass like `REChrisPlayer`, with a MODELDEF block.
3. Add their class to `PlayerClasses` in `mapinfo.txt` and to the select
   screen.
## Changing things

* **Mansion map:** edit `mod/maps/src/TEXTMAP.txt`, then run
  `powershell -ExecutionPolicy Bypass -File tools\pack_map.ps1`.
  (Or open `mod/maps/REMAP01.wad` in Ultimate Doom Builder.)
* **Mansion cameras:** edit `mod/recams.txt`. In the game, open the console
  (`~`) and type `re_debugcams 1` to see each camera cut. The zones are laid
  out so the active camera always shows Jill. As a safety net, if she's ever
  off screen or behind a wall for about 0.2 seconds, the view cuts to the
  camera that shows her best (the console then says "player out of view -
  rescue", which means a zone needs adjusting).
* **Doom II's levels:** any map without an entry in `recams.txt` gets
  automatic cameras. When the map loads, camera spots are placed just inside
  every wall. The active camera stays put but turns to keep Jill framed, and
  cuts to another spot as soon as a wall gets in the way. In a tight spot it
  allows closer shots with a wider lens. Tested on MAP01-MAP08: Jill was never
  off screen. The one exception is a lift shaft on MAP06 that is barely taller
  than she is, where she shows up cropped.
* **Darkness (RE1 lighting):** console settings `re_rooms_dark` (indoors, default
  0.6), `re_rooms_dark_sky` (outdoors, 0.7), `re_rooms_keep` (rooms this dim or
  dimmer are left alone, 64), `re_rooms_cut` (most any room is darkened by, 32), `re_char_minlight` (characters' least brightness,
  104) and `re_jill_light` (the light that follows her, on). They apply when a map
  starts.
* **Speed:** console command `re_speedscale 1.2` makes Jill's walking, running
  and backing up 20% faster (1.0 = RE1's speed).
* **Debug:** console command `netevent re_debug` prints your position, camera
  and inventory.

## Online co-op (netgames)

`host_coop` / `join_coop` start GZDoom's own netgame: `-host 2 -port 5029
-netmode 1` (packet server) and `-join <address>:5029`. Both computers run the
whole game tic by tic and exchange only key presses, so every decision in play
code must come out the same on both. The rules the code follows:

* **Never `consoleplayer` in play code.** "This computer's player" differs per
  computer. Map-start code uses `REMain.Player()` / `REMain.Number()` (the
  lowest player in the game, `RE_Const.zs`); per-player code uses the actor's
  own `PlayerNumber()`. Only screens (inventory, item box screen, map screen,
  death-screen key) read `consoleplayer`, and they change the game only through
  `EventHandler.SendNetworkEvent`.
* **Per-player state:** `REInputBridge.heldButtons[player]` (keys held, from
  the `re_held` event); the map screen's visited rooms (`REMapKeyHandler`,
  player p's rooms from `p * sector count`); the cameras.
* **Cameras:** `RECameraHandler` (`FixedCamera.zs`) keeps its fields for one
  player at a time. `WorldTick` runs `UsePlayer(i)` then `TickPlayer` for each
  player: `UsePlayer` stores the previous player's fields in the `p...` arrays
  and loads player i's (the first time: the map-start values, and player 2
  gets their own automatic camera actor). `SetView` gives the camera only to
  that player. In single player only player 0 exists, so nothing changes.
* **Off online** (`REMain.Online()`, which is `multiplayer`): the AI partner,
  saving (typewriter, F6, Save Game show "No saving in online co-op"), records,
  cheats (menu and codes), the custom cast call, Super Jump. Flat corpses'
  "first person only" counts as both views.
* **Dying:** `RE_Continue.zs` already handles netgames: `re_continue` sets
  `PST_REBORN` for that player, and `PlayerRespawned` restores their entry
  snapshot.
* **`map` is refused in a netgame** ("Use changemap instead"); `+map` on the
  command line works. Testing on one PC: two copies, each with its own
  `-config`, the joiner on `127.0.0.1:5029`; a desync shows as a "Consistency
  failure" / out-of-sync message in the console.

## Known limits

* Doom graphics still stand in for the zombie (a zombieman).
* On Doom II's levels, Doom's monsters are unchanged (all items are RE1's).
* Automatic cameras always keep Jill in view, but they turn to follow her and
  aren't as carefully composed as hand-made RE1 angles.
* Doom's flickering lights keep Doom's brightness in their sectors.
* Doors are Doom doors, not RE's black-screen door animation.
* Walking speed uses RE1's steady value; RE1 also dips slightly on each step.
* Gamepads: the d-pad works if bound to the same commands; analog sticks
  don't drive the tank controls.
* Online co-op: 2 players, no saving; Windows with Mac isn't guaranteed to
  stay in step (floating-point maths can differ), so the README asks for the
  same kind of computer.

The RE1 decomp is GPL-3.0. This mod copies its numbers and rules, not its
code.
