@echo off
rem ==========================================================================
rem  Resident Doom - double-click this file to play.
rem
rem  A small menu comes first:
rem    1 (or just Enter)  Play: the Resident Doom title screen. Press Enter,
rem                       then New Game: pick Jill, Chris or Both (AI partner),
rem                       then Doom II's levels or the mansion.
rem    2  Host online co-op: you play Jill, a friend joins as Chris.
rem    3  Join online co-op: asks for the host's address; you play Chris.
rem  Online co-op is explained in README.md, "Online co-op".
rem
rem  Keys are set from keys.cfg every time (edit it to change them). Every key
rem  and option is explained in the game (Esc > Extras > Manual) and in MANUAL.md.
rem  With options (for example  play.bat +map MAP07) the menu is skipped.
rem
rem  Run setup.bat once first.
rem ==========================================================================
cd /d "%~dp0"
if not exist "tools\gzdoom\gzdoom.exe" goto nosetup
if not exist "iwad\doom2.wad" goto nosetup
if not exist "mod\models\jill\jill_unarmed.iqm" goto nosetup
if not "%~1"=="" goto play
:menu
echo.
echo  RESIDENT DOOM
echo.
echo    1  Play
echo    2  Host online co-op  (you play Jill)
echo    3  Join online co-op  (you play Chris)
echo.
set "CHOICE="
set /p "CHOICE=Type 1, 2 or 3 and press Enter (just Enter = Play): "
if "%CHOICE%"=="" goto play
if "%CHOICE%"=="1" goto play
if "%CHOICE%"=="2" goto host
if "%CHOICE%"=="3" goto join
echo  Please type 1, 2 or 3.
goto menu

:play
start "" "tools\gzdoom\gzdoom.exe" -iwad "iwad\doom2.wad" -file "mod" +exec "keys.cfg" %*
goto :eof

:host
set "MAP="
set /p "MAP=Which map? (just Enter = MAP01, or for example MAP07): "
if "%MAP%"=="" set "MAP=MAP01"
echo.
echo  Online co-op: you host as Jill on %MAP%.
echo.
echo  Your friend picks 3 (Join) in their play menu and types one of these:
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

:join
set "ADDR="
set /p "ADDR=Host's address (for example 192.168.1.20 or 100.64.0.5): "
if "%ADDR%"=="" goto menu
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
