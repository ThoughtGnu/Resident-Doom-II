#!/bin/bash
# ==========================================================================
#  Resident Doom setup for macOS (Apple Silicon or Intel).
#
#  Run it once before playing: open Terminal, go to this folder and type
#      bash setup.command
#  (or right-click this file in Finder > Open).
#
#  It needs your own game files, copied from a Windows PC (GOG's games are
#  Windows-only, so they can't be installed on a Mac):
#    - the whole "Resident Evil" folder from GOG (ResidentEvil.exe + USA)
#    - doom2.wad (and doom.wad / id24res.wad if you have them) from GOG or
#      Steam DOOM II or DOOM + DOOM II
#  It downloads the .NET 8 SDK (to build the converter) and GZDoom 4.14.2
#  into this folder; nothing is installed on your Mac.
#
#  Options: --re1 <folder>  --doomwad <file>  --gzdoom <GZDoom.app>
#           --force (build everything again)  --nocapture (no Level Select pictures)
#           --pictures (only take the Level Select pictures again, after a full setup)
#           --yes (never ask; for scripted runs)
# ==========================================================================

GAME="$(cd "$(dirname "$0")" && pwd)"
cd "$GAME" || exit 1
LOG="$GAME/setup-log.txt"
exec > >(tee "$LOG") 2>&1

RE1=""; WAD=""; GZAPP=""; FORCE=0; NOCAP=0; YES=0; PICS=0
while [ $# -gt 0 ]; do
    case "$1" in
        --re1|-RE1) RE1="$2"; shift ;;
        --doomwad|-DoomWad) WAD="$2"; shift ;;
        --gzdoom|-GZDoom) GZAPP="$2"; shift ;;
        --force|-Force) FORCE=1 ;;
        --nocapture|-NoCapture) NOCAP=1 ;;
        --yes|-Yes) YES=1 ;;
        --pictures|-Pictures) PICS=1 ;;
        *) echo "Unknown option: $1" ;;
    esac
    shift
done

GZ_URL="https://github.com/ZDoom/gzdoom/releases/download/g4.14.2/gzdoom-4-14-2-macos.zip"
GZ_SHA256="0f2e638574ce2a2b5adec3613cf3fc1c66f63468019d412bb8dc8787ee78fb05"
GZ_DIR="$GAME/tools/gzdoom-mac"
APP="$GZ_DIR/GZDoom.app"
GZBIN="$APP/Contents/MacOS/gzdoom"
DOTNET_DIR="$GAME/tools/dotnet"

say()  { echo "$*"; }
step() { echo; echo "== $*"; }
fail() {
    echo
    echo "SETUP STOPPED: $*"
    echo "(Everything setup printed is also in setup-log.txt.)"
    exit 1
}

say "Resident Doom setup"
say "Game folder: $GAME"
[ "$(uname)" = "Darwin" ] || say "Note: this script is made for macOS; on Windows use setup.bat."

export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1 DOTNET_ROOT="$DOTNET_DIR"
DOTNET="$DOTNET_DIR/dotnet"
CONV=("$DOTNET" "$GAME/tools/re1convert/bin-mac/re1convert.dll")

if [ $PICS -eq 1 ]; then
    # --pictures: only the Level Select pictures again (everything else is kept)
    step "Taking only the Level Select pictures again"
    [ -x "$GZBIN" ] && [ -f "$GAME/tools/re1convert/bin-mac/re1convert.dll" ] && [ -x "$DOTNET" ] \
        && [ -f "$GAME/iwad/doom2.wad" ] && [ -f "$GAME/mod/models/jill/jill_unarmed.iqm" ] \
        || fail "Resident Doom isn't fully set up yet: run bash setup.command first (without --pictures)."
    FORCE=1
else

# --- 1. find the game files ------------------------------------------------
is_re1() {
    [ -n "$1" ] && [ -d "$1/USA/Players" ] && return 0
    [ -n "$1" ] && [ "$(basename "$1" | tr '[:upper:]' '[:lower:]')" = "usa" ] && [ -d "$1/Players" ] && return 0
    return 1
}

find_re1() {
    for d in "$HOME/Documents/Resident Evil" "$HOME/Games/Resident Evil" "$HOME/Desktop/Resident Evil" "$HOME/Downloads/Resident Evil" \
             "$HOME/Documents/RE1" "/Applications/Resident Evil"; do
        is_re1 "$d" && { echo "$d"; return; }
    done
    # anywhere in Documents, Desktop, Downloads (a few folders deep)
    local exe
    exe="$(find "$HOME/Documents" "$HOME/Desktop" "$HOME/Downloads" -maxdepth 4 -iname 'ResidentEvil.exe' 2>/dev/null | head -n 1)"
    if [ -n "$exe" ] && is_re1 "$(dirname "$exe")"; then echo "$(dirname "$exe")"; fi
}

find_wad() {
    find "$HOME/Documents" "$HOME/Desktop" "$HOME/Downloads" "$HOME/Games" -maxdepth 4 -iname 'doom2.wad' 2>/dev/null | head -n 1
}

# Asks in this Terminal window: drag the folder or file onto it and press Return.
# (No pop-up dialogs, so macOS never asks for any permission.)
ask_path() {
    [ $YES -eq 1 ] && return
    printf '%s\n> ' "$1" > /dev/tty
    local p
    IFS= read -r p < /dev/tty
    p="$(printf '%s' "$p" | sed -e 's/[[:space:]]*$//' -e "s/^'//" -e "s/'$//" -e 's/^"//' -e 's/"$//' -e 's/\\\(.\)/\1/g')"
    echo "${p%/}"
}

step "Finding your game files"
[ -z "$RE1" ] && RE1="$(find_re1)"
if [ -z "$RE1" ]; then
    say "Resident Evil was not found. Please pick the Resident Evil folder you copied from your Windows PC (it has ResidentEvil.exe and a USA folder in it)."
    RE1="$(ask_path 'Drag the Resident Evil folder (with ResidentEvil.exe and USA in it) onto this window, then press Return:')"
fi
[ -n "$RE1" ] || fail "No Resident Evil folder. RE1 can't be installed on a Mac: copy the whole Resident Evil folder from a Windows PC with GOG's Resident Evil (see README), then run setup again."
is_re1 "$RE1" || fail "This isn't the Resident Evil folder: $RE1. Pick the folder that contains ResidentEvil.exe and a USA folder."
[ "$(basename "$RE1" | tr '[:upper:]' '[:lower:]')" = "usa" ] && RE1="$(dirname "$RE1")"
say "Resident Evil: $RE1"

[ -z "$WAD" ] && WAD="$(find_wad)"
if [ -z "$WAD" ]; then
    say "doom2.wad was not found. Please pick it (copied from your GOG or Steam DOOM II)."
    WAD="$(ask_path 'Drag your doom2.wad onto this window, then press Return:')"
fi
[ -n "$WAD" ] || fail "No doom2.wad. Copy doom2.wad from your GOG or Steam DOOM II (or DOOM + DOOM II) to this Mac, then run setup again."
[ -f "$WAD" ] || fail "doom2.wad not found: $WAD"
say "DOOM II: $WAD"

# --- 2. the .NET 8 SDK and the converter -----------------------------------
step "Getting the .NET 8 SDK (to build the converter)"
if [ -x "$DOTNET" ] && "$DOTNET" --list-sdks 2>/dev/null | grep -q '^8\.'; then
    say ".NET 8 SDK is already there."
else
    mkdir -p "$GAME/tools/setup/download"
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$GAME/tools/setup/download/dotnet-install.sh" \
        || fail "Could not download Microsoft's .NET installer. Check your internet connection and run setup again."
    bash "$GAME/tools/setup/download/dotnet-install.sh" --channel 8.0 --install-dir "$DOTNET_DIR" --no-path \
        || fail "The .NET 8 SDK did not install (see the messages above). Run setup again."
fi

step "Building the converter"
"$DOTNET" build "$GAME/tools/re1convert/re1convert.csproj" -c Release -o "$GAME/tools/re1convert/bin-mac" -nologo -v quiet \
    || fail "The converter did not build (see the messages above)."
say "Converter built."

step "Checking your game files"
"${CONV[@]}" check "$RE1" "$WAD" || fail "Your game files did not pass the check (see PROBLEM lines above)."

mkdir -p "$GAME/iwad"
cp -f "$WAD" "$GAME/iwad/doom2.wad" || fail "Could not copy doom2.wad into the game folder."
ID24="$(find "$(dirname "$WAD")" -maxdepth 1 -iname 'id24res.wad' | head -n 1)"
if [ -n "$ID24" ]; then cp -f "$ID24" "$GAME/iwad/id24res.wad"; else rm -f "$GAME/iwad/id24res.wad"; fi

# --- 3. rebuild everything -------------------------------------------------
step "Building the models, pictures and sounds from your RE1 files"
"${CONV[@]}" all "$RE1" "$WAD" "$GAME/mod" || fail "Building the game files failed (the step that failed is named above)."
MISSING=0
while IFS= read -r f; do
    case "$f" in ''|'#'*) continue ;; esac
    f="${f%$'\r'}"
    if [ ! -e "$GAME/mod/$f" ]; then [ $MISSING -lt 5 ] && say "  not built: $f"; MISSING=$((MISSING + 1)); fi
done < "$GAME/tools/setup/manifest.txt"
[ $MISSING -eq 0 ] || fail "$MISSING game files were not built."
say "All game files built."

# --- 4. GZDoom 4.14.2 ---------------------------------------------------------
step "GZDoom 4.14.2"
gz_version() { /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$1/Contents/Info.plist" 2>/dev/null; }
if [ -n "$GZAPP" ]; then
    v="$(gz_version "$GZAPP")"
    [ -n "$v" ] || fail "That isn't a GZDoom app: $GZAPP"
    case "$v" in g4.14.2*|4.14.2*) ;; *) fail "That GZDoom is version $v; Resident Doom needs GZDoom 4.14.2. Run setup without --gzdoom to download it." ;; esac
    mkdir -p "$GZ_DIR"; rm -rf "$APP"; ditto "$GZAPP" "$APP" || fail "Could not copy GZDoom."
    say "Using your GZDoom ($v)."
elif [ $FORCE -eq 0 ] && case "$(gz_version "$APP")" in g4.14.2*|4.14.2*) true ;; *) false ;; esac; then
    say "GZDoom 4.14.2 is already there."
else
    mkdir -p "$GAME/tools/setup/download" "$GZ_DIR"
    ZIP="$GAME/tools/setup/download/gzdoom-4-14-2-macos.zip"
    say "Downloading $GZ_URL ..."
    curl -fL --progress-bar -o "$ZIP" "$GZ_URL" \
        || fail "Download failed. Check your internet connection and run setup again. Or download GZDoom 4.14.2 for macOS yourself from https://github.com/ZDoom/gzdoom/releases/tag/g4.14.2, unzip it, and run: bash setup.command --gzdoom <path to GZDoom.app>"
    sum="$(shasum -a 256 "$ZIP" | cut -d ' ' -f 1)"
    if [ "$sum" != "$GZ_SHA256" ]; then rm -f "$ZIP"; fail "The downloaded GZDoom doesn't match the official 4.14.2 file (fingerprint $sum). Run setup again."; fi
    rm -rf "$APP"
    ditto -x -k "$ZIP" "$GZ_DIR" || fail "GZDoom did not unpack. Run setup again."
    rm -f "$ZIP"
    say "GZDoom 4.14.2 downloaded and checked."
fi
xattr -dr com.apple.quarantine "$APP" 2>/dev/null
[ -x "$GZBIN" ] || fail "GZDoom is missing its program file ($GZBIN). Run setup again with --force."
mkdir -p "$GZ_DIR/Save"
touch "$GZ_DIR/gzdoom.ini"

fi   # end of the full setup (skipped with --pictures)

# --- 5. Level Select pictures -----------------------------------------------
LV="LVRE LVBOSS"; for i in $(seq -w 1 32); do LV="$LV LV$i"; done
have=0; total=0
for n in $LV; do total=$((total + 1)); [ -f "$GAME/mod/graphics/$n.png" ] && have=$((have + 1)); done
if [ $NOCAP -eq 1 ]; then
    echo; say "Skipping the Level Select pictures (--nocapture): Level Select shows plain cards."
elif [ $FORCE -eq 0 ] && [ $have -eq $total ]; then
    step "Level Select pictures"; say "Already there."
else
    step "Taking the Level Select pictures"
    say "GZDoom opens and visits the start of every map (about 2 minutes) and closes by itself."
    say "Please don't type in its window. Your mouse stays free (GZDoom doesn't grab it)."
    say "(If macOS asks whether GZDoom may use files in this folder, click OK.)"
    SHOTS="$GAME/tools/setup/shots"
    rm -rf "$SHOTS"; mkdir -p "$SHOTS"
    # GZDoom's "wait" only works inside a chain of console commands, an alias can't
    # be very long, and aliases run at startup only if they're already in the
    # settings file. So the capture gets its own settings file holding one short
    # alias per map, each calling the next, started with +rdcap. Screenshots go
    # to full paths (GZDoom started as its own app doesn't run in this folder).
    # unbindall: no key does anything during the capture.
    CAPINI="$GAME/tools/setup/capture.ini"
    { echo '[Doom.ConsoleAliases]'; echo 'Name=rdcap'; echo 'Command=unbindall; wait 70; rdcap0'
      k=0
      for i in $(seq -w 1 32); do
          echo "Name=rdcap$k"; echo "Command=map MAP$i; wait 105; screenshot \"$SHOTS/LV$i.png\"; wait 5; rdcap$((k + 1))"; k=$((k + 1))
      done
      echo "Name=rdcap$k"; echo "Command=map REMAP01; wait 105; screenshot \"$SHOTS/LVRE.png\"; wait 5; rdcap$((k + 1))"; k=$((k + 1))
      # the Final Boss picture: the same fixed view of the Icon of Sin on every computer
      echo "Name=rdcap$k"; echo "Command=map MAP30; wait 35; netevent re_capbossview; wait 105; screenshot \"$SHOTS/LVBOSS.png\"; wait 5; rdcap$((k + 1))"; k=$((k + 1))
      echo "Name=rdcap$k"; echo "Command=quit"
    } > "$CAPINI"
    # started as its own app (not from Terminal), mouse not grabbed, and it keeps
    # going if its window is in the background
    open -n -W -a "$APP" --args -config "$CAPINI" -iwad "$GAME/iwad/doom2.wad" -file "$GAME/mod" -nosound \
        +vid_fullscreen 0 +win_w 800 +win_h 500 +re_start_view 1 +screenblocks 12 +crosshair 0 +show_messages 0 \
        +re_cheat_god 1 +use_mouse 0 +use_joystick 0 +i_pauseinbackground 0 +vid_activeinbackground 1 +rdcap &
    pid=$!
    for s in $(seq 1 420); do kill -0 $pid 2>/dev/null || break; sleep 1; done
    if kill -0 $pid 2>/dev/null; then
        pkill -f "$GZBIN" 2>/dev/null; sleep 2; kill $pid 2>/dev/null
        say "GZDoom took too long; stopped it."
    fi
    rm -f "$CAPINI"
    got=$(ls "$SHOTS"/LV*.png 2>/dev/null | wc -l | tr -d ' ')
    if [ "$got" -gt 0 ]; then "${CONV[@]}" levelshots "$SHOTS" "$GAME/mod" >/dev/null || say "The Level Select pictures could not be converted; Level Select shows plain cards."; fi
    if [ "$got" -lt $total ]; then say "Took $got of $total Level Select pictures; the rest show a plain card. (Run setup again with --force to retry.)"
    else say "All Level Select pictures taken."; fi
fi

echo
echo "Setup complete. Double-click play.command to play Resident Doom (or type: bash play.command)."
exit 0
