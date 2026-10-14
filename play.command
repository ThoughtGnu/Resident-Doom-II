#!/bin/bash
# ==========================================================================
#  Resident Doom for macOS - double-click to play.
#  Double-click (or right-click > Open the first time), or type: bash play.command
#  A small menu comes first:
#    1 (or just Return)  Play: the Resident Doom title screen
#    2  Host online co-op: you play Jill, a friend joins as Chris
#    3  Join online co-op: asks for the host's address; you play Chris
#  Online co-op can also be started in the game: main menu > Online.
#  It's explained in README.md, "Online co-op".
#  Keep this Terminal window open while you play: when you pick Online in the
#  game, GZDoom closes and this window starts it again online; when the online
#  game ends, it starts the normal game again. When you quit the normal game,
#  it's done.
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
# GZDoom's settings file (RD_CONFIG: another one, for testing)
INI="${RD_CONFIG:-$GZ_DIR/gzdoom.ini}"
# this Mac's local address(es), for hosting (also shown on the in-game Online page)
IPS=""
for i in en0 en1; do ip="$(ipconfig getifaddr "$i" 2>/dev/null)"; [ -n "$ip" ] && IPS="${IPS:+$IPS }$ip"; done

# settings and saves stay in this folder (tools/gzdoom-mac), like on Windows;
# GZDoom starts as its own app (not from Terminal); -W waits until it quits
gzdoom() {
    open -W -n -a "$GZ_DIR/GZDoom.app" --args -config "$INI" -savedir "$GZ_DIR/Save" -iwad "$GAME/iwad/doom2.wad" -file "$GAME/mod" \
        +exec "$GAME/keys.cfg" +set re_launcher 1 +set re_net_localip "$IPS" "$@"
}

# The Online choice saved in the settings file (main menu > Online, RE_Online.zs):
# read it, then clear it, so the same choice is never used twice.
read_request() {
    REQ=""; REQMAP=""; REQADDR=""
    [ -f "$INI" ] || return
    REQ="$(sed -n 's/^re_net_request=//p' "$INI" | head -n 1 | tr -cd 'a-z')"
    REQMAP="$(sed -n 's/^re_net_map=//p' "$INI" | head -n 1 | tr -cd 'A-Za-z0-9')"
    # only characters an address can have, so nothing typed can break the command
    REQADDR="$(sed -n 's/^re_net_address=//p' "$INI" | head -n 1 | tr -cd 'A-Za-z0-9.:[]-')"
    clear_request
}
clear_request() {
    [ -f "$INI" ] && grep -q '^re_net_request=.' "$INI" && sed -i '' 's/^re_net_request=.*/re_net_request=/' "$INI"
}

# Starts GZDoom ($MODE: play, host or join) and waits; afterwards an Online choice
# made in the game starts it again online; after an online game, back to the
# normal game once; otherwise done. Never more than 10 starts (a safety net).
run() {
    clear_request   # a choice left over from before is never used
    echo
    echo " Resident Doom is running. Keep this window open: it starts the game again"
    echo " for online co-op (main menu > Online). It's done when you quit the game."
    local runs=0 was
    while [ $runs -lt 10 ]; do
        runs=$((runs + 1))
        case "$MODE" in
            host) gzdoom -host 2 -port 5029 -netmode 1 +name Jill +playerclass Jill +map "$MAP" ;;
            join) case "$ADDR" in *:*) ;; *) ADDR="$ADDR:5029" ;; esac
                  gzdoom -join "$ADDR" +name Chris +playerclass Chris ;;
            *)    gzdoom "${EXTRA[@]}" ;;
        esac
        was="$MODE"; MODE=play; EXTRA=()
        read_request
        if [ "$REQ" = "host" ]; then MODE=host; MAP="${REQMAP:-MAP01}"; continue; fi
        if [ "$REQ" = "join" ] && [ -n "$REQADDR" ]; then MODE=join; ADDR="$REQADDR"; continue; fi
        [ "$was" = "play" ] && break
    done
    echo " Resident Doom has closed."
}

MODE=play; EXTRA=("$@")
if [ $# -gt 0 ]; then run; exit 0; fi

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
            run
            exit 0 ;;
        2)
            MAP=MAP01   # the first level (to start on another: main menu > Online in the game)
            echo
            echo " Online co-op: you host as Jill, starting at level 1 (Entryway)."
            echo " (To start on another level: Play, then main menu > Online in the game.)"
            echo
            echo " Your friend picks 3 (Join) in their play menu, or Online in the game's"
            echo " main menu, and types one of these:"
            echo "  - same house / same Wi-Fi: this Mac's local address:"
            for a in $IPS; do echo "       $a"; done
            echo "  - over the internet: your Tailscale address (100.x.x.x), or your public"
            echo "    address if you forwarded UDP port 5029 on your router (README.md)."
            echo
            echo " If macOS asks whether GZDoom may accept incoming connections, click Allow."
            echo " GZDoom waits until your friend has joined, then the level starts."
            MODE=host
            run
            exit 0 ;;
        3)
            read -r -p "Host's address (for example 192.168.1.20 or 100.64.0.5): " ADDR
            [ -z "$ADDR" ] && continue
            echo
            echo " Joining $ADDR as Chris. GZDoom waits until it finds the host."
            echo " If it keeps waiting: check the address, that the host started first,"
            echo " and README.md, \"Online co-op\"."
            MODE=join
            run
            exit 0 ;;
        *)
            echo " Please type 1, 2 or 3." ;;
    esac
done
