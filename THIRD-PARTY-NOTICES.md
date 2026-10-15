# Third-party notices

Resident Doom II's own code (the GZDoom mod in `mod/`, the converter in
`tools/re1convert/`, the setup scripts and launchers) is © ThoughtGnu and
licensed under the GNU General Public License v3 (see [LICENSE](LICENSE)).

**This repository contains no files from Resident Evil or DOOM II.** Setup
builds the characters, items, pictures and sounds from the player's own copies
of the games, on the player's computer. Those built files are the player's to
keep, not to share.

## Projects Resident Doom II uses or builds on

| Project | How it's used | License |
|---|---|---|
| **GZDoom** 4.14.2, by the GZDoom team (Christoph Oelckers, Rachael Alexanderson and contributors), https://zdoom.org, https://github.com/ZDoom/gzdoom | The engine the game runs in. Not included: setup downloads the official release from GitHub and checks its SHA-256 fingerprint. Its own license files come with it (`licenses.zip` on Windows, inside `GZDoom.app` on a Mac). | GPL-3.0 (with parts under other free licenses, see GZDoom's licenses) |
| **Resident Evil PC decompilation**, by ecruells, https://github.com/ecruells/resident-evil-pc-decomp | Used as a reference for RE1's rules and numbers (speeds, turning, damage, poison, item and inventory logic) and its file formats; its logic is re-implemented in the mod and converter. Not included. | GPL-3.0 |
| **.NET Framework C# compiler** (Microsoft) | Builds the converter on Windows. Part of Windows, not included. | Microsoft .NET Framework license |
| **.NET 8 SDK** (Microsoft / .NET Foundation), https://dotnet.microsoft.com | Builds the converter on a Mac. Not included: setup downloads it into the game folder with Microsoft's official `dotnet-install.sh`. | MIT |
| **innoextract** (Daniel Scharrer), https://constexpr.org/innoextract | Optional, Mac only, installed by the player: unpacks GOG's Windows installers. Not included or required. | zlib |

## Games you need (not included)

| Game | Owner | Used for |
|---|---|---|
| **Resident Evil** (1996, PC, GOG release) | © Capcom | Jill's and Chris's models, animations and textures, item and prop models, pictures and sounds, built by setup from your copy |
| **DOOM II** (and DOOM's logo from `doom.wad`, if present) | © id Software / ZeniMax | The game data GZDoom runs on: levels, monsters, textures, sounds |

Resident Doom II is a fan-made, non-commercial project, not affiliated with or
endorsed by Capcom, id Software, ZeniMax, Bethesda or Microsoft.

## Inspiration

- **drelvak's RE1 x Doom mod**: the idea of playing Resident Evil 1 in Doom.
  No code or files from it are used.
