#!/bin/bash
# ==========================================================================
#  Resident Doom for macOS - straight into our hand-made mansion map (REMAP01).
#  Double-click (or right-click > Open the first time), or type: bash play_mansion.command
#  Keys are set from keys.cfg every time (edit it to change them). Every key
#  and option is explained in the game (Esc > Extras > Manual) and in MANUAL.md.
#  Run setup.command once first.
# ==========================================================================
GAME="$(cd "$(dirname "$0")" && pwd)"
cd "$GAME" || exit 1
GZ_DIR="$GAME/tools/gzdoom-mac"
GZBIN="$GZ_DIR/GZDoom.app/Contents/MacOS/gzdoom"
if [ ! -x "$GZBIN" ] || [ ! -f "$GAME/iwad/doom2.wad" ] || [ ! -f "$GAME/mod/models/jill/jill_unarmed.iqm" ]; then
    echo "Resident Doom isn't set up yet: run setup.command first."
    echo "(It builds the game files from your own Resident Evil and DOOM II.)"
    read -r -p "Press Return to close." _
    exit 1
fi
mkdir -p "$GZ_DIR/Save"
# settings and saves stay in this folder (tools/gzdoom-mac), like on Windows;
# GZDoom starts as its own app (not from Terminal)
open -n -a "$GZ_DIR/GZDoom.app" --args -config "$GZ_DIR/gzdoom.ini" -savedir "$GZ_DIR/Save" -iwad "$GAME/iwad/doom2.wad" -file "$GAME/mod" \
    +exec "$GAME/keys.cfg" +playerclass Jill +map REMAP01 "$@"
exit 0