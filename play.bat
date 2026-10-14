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
rem  Online co-op can also be started in the game: main menu > Online.
rem  It's explained in README.md, "Online co-op".
rem
rem  While you play, a small "Resident Doom launcher" window waits minimized in
rem  the taskbar: when you pick Online in the game, GZDoom closes and the launcher
rem  starts it again online; when the online game ends, it starts the normal game
rem  again. When you quit the normal game, it closes too.
rem
rem  Keys are set from keys.cfg every time (edit it to change them). Every key
rem  and option is explained in the game (Esc > Extras > Manual) and in MANUAL.md.
rem  With options (for example  play.bat +map MAP07) the menu is skipped.
rem
rem  Run setup.bat once first.
rem ==========================================================================
cd /d "%~dp0"
if "%~1"=="__watch" goto watch
if not exist "tools\gzdoom\gzdoom.exe" goto nosetup
if not exist "iwad\doom2.wad" goto nosetup
if not exist "mod\models\jill\jill_unarmed.iqm" goto nosetup
rem this PC's local address(es), for hosting (also shown on the in-game Online page)
set "RD_IPS="
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4"') do call :addip %%a
set "RD_EXTRA=%*"
set "RD_MODE=play"
if not "%~1"=="" goto launch
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
if "%CHOICE%"=="" goto launch
if "%CHOICE%"=="1" goto launch
if "%CHOICE%"=="2" goto host
if "%CHOICE%"=="3" goto join
echo  Please type 1, 2 or 3.
goto menu

:host
rem the first level (to start on another: main menu > Online in the game)
set "RD_MAP=MAP01"
set "RD_MODE=host"
echo.
echo  Online co-op: you host as Jill, starting at level 1 (Entryway).
echo  (To start on another level: Play, then main menu ^> Online in the game.)
echo.
echo  Your friend picks 3 (Join) in their play menu, or Online in the game's
echo  main menu, and types one of these:
echo   - same house / same Wi-Fi: this PC's local address:
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4"') do echo        %%a
echo   - over the internet: your Tailscale address (100.x.x.x), or your public
echo     address if you forwarded UDP port 5029 on your router (README.md).
echo.
echo  If Windows Firewall asks about GZDoom, click Allow (Private networks).
echo  GZDoom waits until your friend has joined, then the level starts.
echo  (You can close this window; it only shows the addresses.)
echo.
call :start_watch
pause
goto :eof

:join
set "RD_ADDR="
set /p "RD_ADDR=Host's address (for example 192.168.1.20 or 100.64.0.5): "
if "%RD_ADDR%"=="" goto menu
set "RD_MODE=join"
echo.
echo  Joining %RD_ADDR% as Chris. GZDoom waits until it finds the host.
echo  If it keeps waiting: check the address, that the host started first,
echo  and README.md, "Online co-op".
echo.
goto launch

:launch
call :start_watch
goto :eof

rem The launcher: a second copy of this file, minimized, that starts GZDoom and
rem waits for it (the settings above are passed along as environment variables).
:start_watch
start "Resident Doom launcher" /min cmd /c ""%~f0" __watch"
goto :eof

:watch
title Resident Doom launcher
rem GZDoom's settings file (RD_CONFIG: another one, for testing)
set "RD_INI=tools\gzdoom\gzdoom_portable.ini"
set "RD_CFG="
if defined RD_CONFIG set "RD_INI=%RD_CONFIG%"
if defined RD_CONFIG set RD_CFG=-config "%RD_CONFIG%"
rem an Online choice left over from before is never used
call :readreq clear
set RUNS=0
:wloop
set /a RUNS+=1
rem a safety net: never more than 10 starts from one double-click
if %RUNS% gtr 10 goto :eof
if /i "%RD_MODE%"=="host" goto run_host
if /i "%RD_MODE%"=="join" goto run_join
start "" /wait "tools\gzdoom\gzdoom.exe" %RD_CFG% -iwad "iwad\doom2.wad" -file "mod" +exec "keys.cfg" +set re_launcher 1 +set re_net_localip "%RD_IPS%" %RD_EXTRA%
goto after
:run_host
start "" /wait "tools\gzdoom\gzdoom.exe" %RD_CFG% -iwad "iwad\doom2.wad" -file "mod" -host 2 -port 5029 -netmode 1 +exec "keys.cfg" +name Jill +playerclass Jill +map %RD_MAP% +set re_launcher 1 +set re_net_localip "%RD_IPS%"
goto after
:run_join
rem add the game's port unless one was typed
echo %RD_ADDR%| find ":" >nul || set "RD_ADDR=%RD_ADDR%:5029"
start "" /wait "tools\gzdoom\gzdoom.exe" %RD_CFG% -iwad "iwad\doom2.wad" -file "mod" -join %RD_ADDR% +exec "keys.cfg" +name Chris +playerclass Chris +set re_launcher 1 +set re_net_localip "%RD_IPS%"
:after
rem GZDoom has closed. An Online choice made in the game starts it again online
rem (the choice is cleared first); after an online game, back to the normal game
rem once; otherwise done.
set "WAS=%RD_MODE%"
set "RD_MODE=play"
set "RD_EXTRA="
call :readreq
if /i "%REQ%"=="host" goto req_host
if /i "%REQ%"=="join" goto req_join
if /i not "%WAS%"=="play" goto wloop
goto :eof
:req_host
set "RD_MODE=host"
set "RD_MAP=%REQMAP%"
if "%RD_MAP%"=="" set "RD_MAP=MAP01"
goto wloop
:req_join
if "%REQADDR%"=="" goto wloop
set "RD_MODE=join"
set "RD_ADDR=%REQADDR%"
goto wloop

rem Reads (and clears) the Online choice in the settings file: REQ, REQMAP, REQADDR.
:readreq
set "REQ="
set "REQMAP="
set "REQADDR="
if "%~1"=="clear" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "tools\launcher\online.ps1" -Ini "%RD_INI%" -ClearOnly
    goto :eof
)
for /f "usebackq delims=" %%l in (`powershell -NoProfile -ExecutionPolicy Bypass -File "tools\launcher\online.ps1" -Ini "%RD_INI%"`) do set "%%l"
goto :eof

:addip
if defined RD_IPS (set "RD_IPS=%RD_IPS% %~1") else set "RD_IPS=%~1"
goto :eof

:nosetup
echo Resident Doom isn't set up yet: double-click setup.bat first.
echo (It builds the game files from your own Resident Evil and DOOM II.)
pause
