# Testing Resident Doom on a Mac

A checklist for the first Mac test (MacBook Pro M2 Pro, or any Mac with macOS
10.15 or newer). It takes about 15 minutes plus download time.

## 1. On your Windows PC: copy the game files

Copy these to a USB stick, an external drive, or a cloud folder (iCloud Drive,
OneDrive, Google Drive):

- the whole **Resident Evil** folder:
  `C:\Program Files\GOG Galaxy\Games\Resident Evil` (copy the folder itself,
  with `ResidentEvil.exe` and `USA` inside; about 1 GB)
- from `C:\Program Files\GOG Galaxy\Games\DOOM + DOOM II`: **doom2.wad**,
  **doom.wad** and **id24res.wad**

## 2. On the Mac: get Resident Doom

1. Sign in on **github.com** as ThoughtGnu and open the private
   **Resident-Doom** repository.
2. Click the green **Code** button > **Download ZIP**.
3. Double-click the zip in Downloads to unzip it. Move the folder to
   **Documents** and rename it `Resident-Doom` (drop the `-main` ending GitHub adds).

## 3. Copy the game files onto the Mac

From the USB stick / cloud folder, copy:
- the **Resident Evil** folder to `Documents/Resident Evil`
- the three wads to a new folder `Documents/DOOM`

(Setup looks in Documents, Desktop and Downloads by itself; if it doesn't find
them, it asks you to drag them onto the Terminal window.)

## 4. Run setup

1. Open **Terminal** (Finder > Applications > Utilities > Terminal).
2. Type `cd ` (c, d, a space), drag the **Resident-Doom** folder from Finder onto
   the Terminal window, and press **Return**.
3. Type `bash setup.command` and press **Return**.
4. If setup asks for the Resident Evil folder or doom2.wad, drag it from Finder
   onto the Terminal window and press **Return**.
5. Setup downloads the .NET 8 SDK and GZDoom 4.14.2 into the game folder
   (about 250 MB), builds everything, then opens GZDoom for about 2 minutes to
   take the Level Select pictures. **Don't type in its window until it closes by itself**
   (your mouse stays free).
   If macOS asks whether GZDoom may access files in your Documents folder,
   click **OK**.
6. The last line should be: **Setup complete.**

## 5. Play

- Double-click **play.command** in the Resident-Doom folder. The first time,
  macOS may refuse to open it: right-click it > **Open** > **Open**. Or type
  `bash play.command` in Terminal.
- Check these:
  - [ ] the title screen (RESIDENT DOOM), Enter opens the menu
  - [ ] New Game > character select shows Jill and Chris
  - [ ] the start of MAP01: Jill walks (Up), turns (Left / Right), runs (Shift)
  - [ ] aim (hold **Ctrl**) and fire (**E**) after equipping the Beretta (**Tab** > Beretta > EQUIP)
  - [ ] **V** switches to first person and back
  - [ ] **CapsLock** shows "Always run: ON / OFF"
  - [ ] main menu > **Level Select** shows the map pictures
  - [ ] sound plays (gunshots)

## 6. Send me

- the file **setup-log.txt** from the Resident-Doom folder
- screenshots of anything wrong (**Cmd + Shift + 4**, then drag over the area;
  the picture lands on your Desktop)
- one line for each check above: works / doesn't work

## If something goes wrong

- **"permission denied"** when running a .command file: use `bash play.command`
  (or `chmod +x *.command` once in Terminal).
- **"GZDoom can't be opened because Apple cannot check it"**: setup normally
  avoids this. If it appears, open System Settings > Privacy & Security, scroll
  down and click **Open Anyway** for GZDoom.
- Run setup again with `bash setup.command --force` to rebuild everything.
- To take only the Level Select pictures again: `bash setup.command --pictures`.
