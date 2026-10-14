# Resident Doom

**Resident Evil 1, played through DOOM II.** Jill Valentine and Chris Redfield,
with their real models and animations from the 1996 PC game, explore DOOM II's
levels with tank controls, fixed camera angles, RE1's inventory, herbs, ink
ribbons and typewriters. There's also a hand-made RE1-style mansion map.

- Jill or Chris, each with RE1's own health, item slots and weapons
  (Beretta, shotgun, Colt Python, bazooka, rocket launcher, Chris's flamethrower)
- an **AI partner** (choose **Both**): the other character follows you, fights,
  opens doors and crawls through low gaps
- RE1's rules, taken from the RE1 PC decompilation: walking and turning speeds,
  aiming up and down, damage, poison, healing and herb mixing
- three save modes, from "save any time" to Classic RE (typewriter + Ink Ribbon)
- optional first-person view, RE1-style darker lighting, RE1 Classic inventory screen

Fan-made, free and **not affiliated with Capcom or id Software**. This
repository contains **no** Capcom or id Software files: setup builds everything
from **your own copies** of the games.

## What you need

| | |
|---|---|
| **Resident Evil** (1996) | the **GOG** version (gog.com, "Resident Evil"). Other versions (Director's Cut, PlayStation copies) aren't supported. |
| **DOOM II** | from **GOG** or **Steam**: "DOOM II" or "DOOM + DOOM II" (the 2024 re-release, which also includes DOOM). |
| **A computer** | **Windows 10 or 11** (the main version), or a **Mac** with macOS 10.15 or newer (Apple Silicon or Intel; see [Mac](#on-a-mac)). |
| **Internet** | for the first setup only (it downloads GZDoom 4.14.2, about 22 MB; on a Mac also the .NET 8 SDK, about 200 MB). |

## Install on Windows

1. **Install both games** from GOG / Steam as usual (if they aren't already).
2. **Get Resident Doom:** on the repository's GitHub page, click the green
   **Code** button > **Download ZIP**. **Don't double-click the zip** (that
   opens it like a folder and hides the Unblock box). Instead, in Downloads,
   right-click the zip > **Properties** > tick **Unblock** if you see it > OK.
   Then right-click the zip > **Extract All** to a simple folder, for example
   `C:\Games\Resident-Doom`. (Not inside `Program Files`, which Windows protects.)
   The files end up one folder deeper, for example
   `C:\Games\Resident-Doom\Resident-Doom-main`; `setup.bat` is inside that folder.
3. **Double-click `setup.bat`** in that folder. It:
   - finds your Resident Evil and doom2.wad by itself. If it can't, it asks you
     to pick them: the **Resident Evil folder** (the one with `ResidentEvil.exe`
     and `USA` in it) and the file **doom2.wad**;
   - checks they're the right files and says exactly what's wrong if not;
   - builds every character model, picture and sound from your RE1 files
     (a few seconds);
   - downloads GZDoom 4.14.2 into the game folder and checks it is the official file;
   - takes the Level Select pictures: GZDoom opens for about 2 minutes, visits
     every map and closes by itself. Please leave it alone until then.

   Nothing is installed on your PC, and your game folders are only read.
   Everything setup prints is also saved in `setup-log.txt`.
4. **Double-click `play.bat`** to play.

If Windows says "Windows protected your PC" for `setup.bat` or `play.bat`,
click **More info** > **Run anyway** (that message appears for any downloaded
batch file).

## On a Mac

GOG's Resident Evil and DOOM II are Windows games: they can't be installed on a
Mac. So the game files come from a Windows PC where they're installed:

1. **On the Windows PC**, copy these to a USB stick or a cloud folder:
   - the whole **Resident Evil** folder (by default
     `C:\Program Files (x86)\GOG Galaxy\Games\Resident Evil`, or
     `C:\Program Files\...`). The whole folder, not just `USA`: setup needs
     `ResidentEvil.exe` too.
   - **doom2.wad**, plus **doom.wad** and **id24res.wad** if they're next to it
     (DOOM + DOOM II has all three).
2. **On the Mac**, download Resident Doom (green **Code** button > **Download
   ZIP**) and unzip it, for example into your Documents folder.
3. Copy the files from step 1 onto the Mac, for example `Documents/Resident Evil`
   and `Documents/DOOM`.
4. Open **Terminal** (Applications > Utilities), type `cd ` (with a space),
   drag the Resident Doom folder onto the Terminal window, press Return, then type:

   ```
   bash setup.command
   ```

   It does the same as on Windows. If it can't find the Resident Evil folder
   or doom2.wad by itself, it asks you to drag them onto the Terminal window
   (no pop-up windows, no permissions needed). It also downloads the .NET 8 SDK into the game folder to build
   the converter. If macOS asks whether GZDoom may use files in your Documents
   folder, click **OK**.
5. To play: double-click **`play.command`** (the first time: right-click >
   **Open**), or type `bash play.command` in Terminal.

The first time, macOS may ask to let GZDoom control your computer using
accessibility features. Click **Deny**; the game doesn't need it. macOS
remembers and won't ask again.

**Mac: hold Control to aim and press E to fire. On a trackpad, a two-finger click also aims.**

**No Windows PC?** You can try unpacking GOG's offline Windows installers
(downloadable from your GOG library) with **innoextract**
(`brew install innoextract`, from Homebrew). GOG's newer installers may need
its development version (`brew install --HEAD innoextract`). This is untested
and may not work.

## Playing

| | |
|---|---|
| `play.bat` / `play.command` | the title screen. Press **Enter**, then **New Game**: pick Jill, Chris or Both (AI partner), then Doom II's levels or "Mansion - (custom level)". |
| `play_doom2.bat` / `.command` | straight into Doom II's MAP01, as Jill |
| `play_mansion.bat` / `.command` | straight into the mansion map, as Jill |

Add `+playerclass Chris` to start the last two as Chris (for example
`play_doom2.bat +playerclass Chris`).

**The [Player Manual](MANUAL.md)** explains everything: controls, characters,
items, weapons, saving, lighting, records and cheats. It's also in the game:
**main menu > Extras > Manual**.

### Controls

| Key | What it does |
|---|---|
| Up / W, Down / S | walk forward, back up |
| Left, Right / A, D | turn |
| Shift (hold) | run; **CapsLock** switches always-run on / off |
| Ctrl or right mouse (hold) | aim; **E** fires; Up / Down aims up / down |
| E | pick up, open doors, typewriters and the item box |
| Tab / I | inventory (equip, use, combine, give to your partner) |
| M | map screen |
| V | first person (mouse to look, Q / R to step sideways) / fixed cameras |
| L | lighting: Doom / RE1 |
| Space / C (hold) | jump / crouch (crawl in low gaps) |
| F6 | quicksave (Normal save mode) |
| Esc | main menu |

Keys come from `keys.cfg` every time the game starts; edit it to change them.

### Settings (main menu > Settings > Gameplay)

- **Save mode:** Normal (save any time), Typewriter (only at typewriters), or
  Classic RE (typewriters, and each save uses an Ink Ribbon)
- **Lighting:** Doom or RE1 (darker)
- **Inventory style:** Resident Doom, or RE1 Classic (RE1's own status screen)
- **AI partner** and **Partner pickups** (RE5 style: they pick up ammo for their gun)
- **Starting view:** third person (fixed cameras) or first person
- **Flat corpses:** dead monsters lie flat on the floor (first person only, both views, or off)
- **Jump** and **Crouch** on / off

Field of view: Settings > Video > Field of View.

### Co-op: the AI partner

On the character select screen, **Both** gives you a partner: pick who you play,
and the other one follows you and fights. They can't be hurt and never run out
of ammo. They open normal doors, key doors while you carry the key, and secret
doors you've found. Give them a better gun with **GIVE TO** in the inventory.
(There's no online co-op: the partner is the computer.)

### Cheats

Main menu > Extras > **Cheats** (Infinite Ammo, Invincibility, Super Jump, All
Weapons), or console codes (~): `starsteam`, `rocketman`, `jillsandwich`,
`inkribbon`, `re_jillflamer`. A run with a cheat on sets no record.

## Known limits

- **Resident Evil:** only the GOG version is supported.
- **DOOM II:** tested with the 2024 DOOM + DOOM II re-release. The classic DOOM
  II (1.9) works too. The title screen uses the original DOOM logo when
  `doom.wad` is next to your `doom2.wad` (DOOM + DOOM II has it); otherwise it
  shows DOOM II's logo.
- Doom II's monsters are still Doom's monsters (with RE1-style corpses and poison).
- The mansion map has no exit yet (so no record for it).
- Online co-op: not available yet. Single player only; the "co-op" is the AI partner.
- **Mac:** the game files must come from a Windows install (see above).
  CapsLock (always run) may behave differently, F6 may need the **fn** key,
  and on a trackpad, aim with a two-finger click or Ctrl.
- Saved games may not load after a big Resident Doom update.

## If something goes wrong

- Read the last lines of `setup-log.txt`: setup says what's wrong and what to do.
- Run setup again; it's safe. `setup.bat -Force` (or `bash setup.command --force`)
  rebuilds everything.
- `setup.bat -NoCapture` skips the Level Select pictures (plain cards are shown instead).
- `setup.bat -Pictures` (Mac: `bash setup.command --pictures`) takes only the Level Select pictures again.
- Your settings and saves live in `tools\gzdoom` (Mac: `tools/gzdoom-mac`);
  setup never deletes them.

## Credits

- **Made by ThoughtGnu** (with Claude Code)
- Inspired by **drelvak's RE1 x Doom mod**
- **Resident Evil** © Capcom: the game whose files you use (not included)
- **DOOM II** © id Software: the game whose files you use (not included)
- **RE1 PC decompilation** by ecruells
  ([resident-evil-pc-decomp](https://github.com/ecruells/resident-evil-pc-decomp), GPL-3.0):
  RE1's rules, numbers and file formats
- **GZDoom** by the GZDoom team ([zdoom.org](https://zdoom.org), GPL-3.0): the engine

## License

Resident Doom's own code is free software under the **GNU General Public
License v3** ([LICENSE](LICENSE)). Other projects it uses or builds on are listed
in [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md). For how everything works
inside, see [docs/DEVELOPER.md](docs/DEVELOPER.md).
