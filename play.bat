@echo off
rem ==========================================================================
rem  Resident Doom II - double-click this file to play.
rem
rem  Opens the Resident Doom II title screen. Press Enter, then New Game: pick
rem  Jill, Chris or Both (AI partner), then Doom II's levels or the mansion.
rem  Keys are set from keys.cfg every time (edit it to change them). Every key
rem  and option is explained in the game (Esc > Extras > Manual) and in MANUAL.md.
rem
rem  Run setup.bat once first.
rem ==========================================================================
cd /d "%~dp0"
if not exist "tools\gzdoom\gzdoom.exe" goto nosetup
if not exist "iwad\doom2.wad" goto nosetup
if not exist "mod\models\jill\jill_unarmed.iqm" goto nosetup
start "" "tools\gzdoom\gzdoom.exe" -iwad "iwad\doom2.wad" -file "mod" +exec "keys.cfg" %*
goto :eof
:nosetup
echo Resident Doom II isn't set up yet: double-click setup.bat first.
echo (It builds the game files from your own Resident Evil and DOOM II.)
pause
