@echo off
rem ==========================================================================
rem  Resident Doom II on Doom II's real levels - straight into MAP01.
rem  Cameras are placed automatically on these maps (AutoCamera.zs).
rem
rem  Starts as Jill. To play Chris:  play_doom2.bat +playerclass Chris
rem  Keys are set from keys.cfg every time (edit it to change them). Every key
rem  and option is explained in the game (Esc > Extras > Manual) and in MANUAL.md.
rem ==========================================================================
cd /d "%~dp0"
if not exist "tools\gzdoom\gzdoom.exe" goto nosetup
if not exist "iwad\doom2.wad" goto nosetup
if not exist "mod\models\jill\jill_unarmed.iqm" goto nosetup
start "" "tools\gzdoom\gzdoom.exe" -iwad "iwad\doom2.wad" -file "mod" +exec "keys.cfg" +playerclass Jill +map MAP01 %*
goto :eof
:nosetup
echo Resident Doom II isn't set up yet: double-click setup.bat first.
echo (It builds the game files from your own Resident Evil and DOOM II.)
pause
