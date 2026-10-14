#!/bin/bash
# ==========================================================================
#  Resident Doom online co-op for macOS: YOU HOST (you play Jill, your friend
#  plays Chris). Your friend starts join_coop (.bat on Windows, .command on a
#  Mac) with the address printed below. See "Online co-op" in README.md.
#  Double-click (or right-click > Open the first time), or type: bash host_coop.command
#  Another map:  bash host_coop.command MAP07
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
MAP="${1:-MAP01}"
echo
echo " Online co-op: you host as Jill on $MAP."
echo
echo " Your friend types one of these addresses in join_coop:"
echo "  - same house / same Wi-Fi: this Mac's local address:"
for i in en0 en1; do ip="$(ipconfig getifaddr "$i" 2>/dev/null)"; [ -n "$ip" ] && echo "       $ip"; done
echo "  - over the internet: your Tailscale address (100.x.x.x), or your public"
echo "    address if you forwarded UDP port 5029 on your router (README.md)."
echo
echo " If macOS asks whether GZDoom may accept incoming connections, click Allow."
echo " GZDoom waits until your friend has joined, then the level starts."
echo
mkdir -p "$GZ_DIR/Save"
open -n -a "$GZ_DIR/GZDoom.app" --args -config "$GZ_DIR/gzdoom.ini" -savedir "$GZ_DIR/Save" -iwad "$GAME/iwad/doom2.wad" -file "$GAME/mod" \
    -host 2 -port 5029 -netmode 1 +exec "$GAME/keys.cfg" +name Jill +playerclass Jill +map "$MAP"
exit 0
