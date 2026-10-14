#!/bin/bash
# ==========================================================================
#  Resident Doom for macOS - double-click to play.
#  Double-click (or right-click > Open the first time), or type: bash play.command
#  A small menu comes first:
#    1 (or just Return)  Play: the Resident Doom title screen
#    2  Host online co-op: you play Jill, a friend joins as Chris
#    3  Join online co-op: asks for the host's address; you play Chris
#  Online co-op is explained in README.md, "Online co-op".
#  Keys are set from keys.cfg every time (edit it to change them). Every key
#  and option is explained in the game (Esc > Extras > Manual) and in MANUAL.md.
#  With options (for example  bash play.command +map MAP07) the menu is skipped.
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
gzdoom() {
    open -n -a "$GZ_DIR/GZDoom.app" --args -config "$GZ_DIR/gzdoom.ini" -savedir "$GZ_DIR/Save" -iwad "$GAME/iwad/doom2.wad" -file "$GAME/mod" \
        +exec "$GAME/keys.cfg" "$@"
}

if [ $# -gt 0 ]; then gzdoom "$@"; exit 0; fi

while true; do
    echo
    echo " RESIDENT DOOM"
    echo
    echo "   1  Play"
    echo "   2  Host online co-op  (you play Jill)"
    echo "   3  Join online co-op  (you play Chris)"
    echo
    read -r -p "Type 1, 2 or 3 and press Return (just Return = Play): " CHOICE
    case "$CHOICE" in
        ""|1)
            gzdoom
            exit 0 ;;
        2)
            read -r -p "Which map? (just Return = MAP01, or for example MAP07): " MAP
            MAP="${MAP:-MAP01}"
            echo
            echo " Online co-op: you host as Jill on $MAP."
            echo
            echo " Your friend picks 3 (Join) in their play menu and types one of these:"
            echo "  - same house / same Wi-Fi: this Mac's local address:"
            for i in en0 en1; do ip="$(ipconfig getifaddr "$i" 2>/dev/null)"; [ -n "$ip" ] && echo "       $ip"; done
            echo "  - over the internet: your Tailscale address (100.x.x.x), or your public"
            echo "    address if you forwarded UDP port 5029 on your router (README.md)."
            echo
            echo " If macOS asks whether GZDoom may accept incoming connections, click Allow."
            echo " GZDoom waits until your friend has joined, then the level starts."
            echo
            gzdoom -host 2 -port 5029 -netmode 1 +name Jill +playerclass Jill +map "$MAP"
            exit 0 ;;
        3)
            read -r -p "Host's address (for example 192.168.1.20 or 100.64.0.5): " ADDR
            [ -z "$ADDR" ] && continue
            # add the game's port unless one was typed
            case "$ADDR" in *:*) ;; *) ADDR="$ADDR:5029" ;; esac
            echo
            echo " Joining $ADDR as Chris. GZDoom waits until it finds the host."
            echo " If it keeps waiting: check the address, that the host started first,"
            echo " and README.md, \"Online co-op\"."
            echo
            gzdoom -join "$ADDR" +name Chris +playerclass Chris
            exit 0 ;;
        *)
            echo " Please type 1, 2 or 3." ;;
    esac
done
