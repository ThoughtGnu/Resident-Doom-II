@echo off
rem ==========================================================================
rem  Resident Doom online co-op: YOU HOST (you play Jill, your friend plays Chris).
rem  Your friend starts join_coop.bat (or join_coop.command on a Mac) with
rem  the address printed below. See "Online co-op" in README.md.
rem
rem  Starts on Doom II's MAP01. Another map:  host_coop.bat MAP07
rem  Both players need the same Resident Doom version and the same doom2.wad.
rem ==========================================================================
cd /d "%~dp0"
if not exist "tools\gzdoom\gzdoom.exe" goto nosetup
if not exist "iwad\doom2.wad" goto nosetup
if not exist "mod\models\jill\jill_unarmed.iqm" goto nosetup
set "MAP=MAP01"
if not "%~1"=="" set "MAP=%~1"
echo.
echo  Online co-op: you host as Jill on %MAP%.
echo.
echo  Your friend types one of these addresses in join_coop:
echo   - same house / same Wi-Fi: this PC's local address:
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4"') do echo        %%a
echo   - over the internet: your Tailscale address (100.x.x.x), or your public
echo     address if you forwarded UDP port 5029 on your router (README.md).
echo.
echo  If Windows Firewall asks about GZDoom, click Allow (Private networks).
echo  GZDoom waits until your friend has joined, then the level starts.
echo.
start "" "tools\gzdoom\gzdoom.exe" -iwad "iwad\doom2.wad" -file "mod" -host 2 -port 5029 -netmode 1 +exec "keys.cfg" +name Jill +playerclass Jill +map %MAP%
pause
goto :eof
:nosetup
echo Resident Doom isn't set up yet: double-click setup.bat first.
echo (It builds the game files from your own Resident Evil and DOOM II.)
pause
