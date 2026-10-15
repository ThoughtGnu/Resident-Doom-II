# Putting Resident Doom II on GitHub (private)

Step by step, for a first-time GitHub user. You'll use **GitHub Desktop**, which
is already installed on this PC. The Resident-Doom folder is already prepared:
it's a git repository, and the `.gitignore` file lets in only our own work (the
list is in `docs/REPO_FILES.txt`, 133 files).

## 1. Sign in

1. Open **GitHub Desktop** (Start menu > GitHub Desktop).
2. Menu **File > Options > Accounts** > **Sign in** next to GitHub.com.
   Your browser opens: sign in as **ThoughtGnu** and click **Authorize**.
   Back in GitHub Desktop, close Options.
3. Menu **File > Options > Git**: set **Name** to `ThoughtGnu`. For **Email**,
   pick the address ending in `@users.noreply.github.com` if it's offered (that
   keeps your real email private), then **Save**.

## 2. Add the folder

1. Menu **File > Add local repository...**
2. Click **Choose...** and pick `C:\Users\Anyone\Documents\Resident-Doom`.
3. Click **Add repository**.

## 3. Check what will be uploaded

The **Changes** tab on the left lists every file that will go up. Compare it
with `docs/REPO_FILES.txt` (133 files). It must contain:
- `README.md`, `MANUAL.md`, `LICENSE`, `THIRD-PARTY-NOTICES.md`, `keys.cfg`
- `setup.bat`, `setup.command`, the `play*` files
- `docs/...`, `mod/zscript/...`, `mod/*.txt`, `mod/maps/...`,
  `mod/sprites/re/...` (blank placeholder pictures), `mod/graphics/M_DOOM.png`
- `tools/re1convert/*.cs`, `tools/setup/...`, `tools/pack_map.ps1`

It must **not** contain: `iwad/`, `doom2.wad`, `mod/models/`, `mod/sounds/`,
`mod/hires/`, any other `mod/graphics` pictures, `tools/gzdoom/`, `reference/`,
`manual_screenshots/`, `_dev/`, `_cleantest/`, screenshots (`.png` at the top),
`.ini` or save (`.zds`) files. **If you see any of these, stop and tell me.**

## 4. Commit (save this version)

1. At the bottom left, in **Summary**, type: `First version of Resident Doom II`
2. Click **Commit to main**.

## 5. Publish as a PRIVATE repository

1. Click **Publish repository** (top bar).
2. **Name:** `Resident-Doom`. **Description:** `Resident Evil 1 in DOOM II (GZDoom mod)`.
3. **Make sure "Keep this code private" is ticked.**
4. Leave **Organization** as **None** (so it goes under your account, ThoughtGnu).
5. Click **Publish repository**.

Check it: open https://github.com/ThoughtGnu/Resident-Doom in your browser. You
should see your files and a grey **Private** label next to the name.

## 6. Let your friend in

1. On the repository's page on github.com: **Settings** (top right of the
   repository) > **Collaborators** (left) > **Add people**.
2. Type your friend's GitHub username and click **Add**. They get an email and
   must accept the invitation.
3. Your friend then opens the repository, clicks **Code > Download ZIP**, and
   follows the README (they need their own GOG Resident Evil and DOOM II).

## Later: uploading changes

When files change, GitHub Desktop shows them under **Changes**. Type a short
summary, click **Commit to main**, then **Push origin** (top bar).
