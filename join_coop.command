#!/bin/bash
# ==========================================================================
#  Resident Doom online co-op for macOS: YOU JOIN your friend's game (you play
#  Chris). Your friend starts host_coop (.bat on Windows, .command on a Mac)
#  first. See "Online co-op" in README.md.
#  Double-click (it asks for the address), or type: bash join_coop.command 192.168.1.20
#  Both players need the same Resident Doom version and the same doom2.wad.
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
ADDR="$1"
if [ -z "$ADDR" ]; then
    read -r -p "Host's address (for example 192.168.1.20 or 100.64.0.5): " ADDR
fi
[ -z "$ADDR" ] && exit 0
# add the game's port unless one was typed
case "$ADDR" in *:*) ;; *) ADDR="$ADDR:5029" ;; esac
echo
echo " Joining $ADDR as Chris. GZDoom waits until it finds the host."
echo " If it keeps waiting: check the address, that the host started first,"
echo " and README.md, \"Online co-op\"."
echo
mkdir -p "$GZ_DIR/Save"
open -n -a "$GZ_DIR/GZDoom.app" --args -config "$GZ_DIR/gzdoom.ini" -savedir "$GZ_DIR/Save" -iwad "$GAME/iwad/doom2.wad" -file "$GAME/mod" \
    -join "$ADDR" +exec "$GAME/keys.cfg" +name Chris +playerclass Chris
exit 0
