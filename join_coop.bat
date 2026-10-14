@echo off
rem ==========================================================================
rem  Resident Doom online co-op: YOU JOIN your friend's game (you play Chris).
rem  Your friend starts host_coop.bat (or host_coop.command on a Mac) first.
rem  See "Online co-op" in README.md.
rem
rem  Asks for the host's address, or give it:  join_coop.bat 192.168.1.20
rem  Both players need the same Resident Doom version and the same doom2.wad.
rem ==========================================================================
cd /d "%~dp0"
if not exist "tools\gzdoom\gzdoom.exe" goto nosetup
if not exist "iwad\doom2.wad" goto nosetup
if not exist "mod\models\jill\jill_unarmed.iqm" goto nosetup
set "ADDR=%~1"
if "%ADDR%"=="" set /p "ADDR=Host's address (for example 192.168.1.20 or 100.64.0.5): "
if "%ADDR%"=="" goto :eof
rem add the game's port unless one was typed
echo %ADDR%| find ":" >nul || set "ADDR=%ADDR%:5029"
echo.
echo  Joining %ADDR% as Chris. GZDoom waits until it finds the host.
echo  If it keeps waiting: check the address, that the host started first,
echo  and README.md, "Online co-op".
echo.
start "" "tools\gzdoom\gzdoom.exe" -iwad "iwad\doom2.wad" -file "mod" -join %ADDR% +exec "keys.cfg" +name Chris +playerclass Chris
goto :eof
:nosetup
echo Resident Doom isn't set up yet: double-click setup.bat first.
echo (It builds the game files from your own Resident Evil and DOOM II.)
pause
