@echo off
rem ==========================================================================
rem  Resident Doom setup - double-click this once before playing.
rem
rem  It finds your GOG Resident Evil and your doom2.wad (GOG or Steam), builds
rem  every model, picture and sound from them, and downloads GZDoom 4.14.2.
rem  Nothing is installed on your PC. Then double-click play.bat.
rem
rem  Options:  setup.bat -RE1 "<Resident Evil folder>" -DoomWad "<doom2.wad>"
rem            setup.bat -Force        (build everything again)
rem            setup.bat -NoCapture    (skip the Level Select pictures)
rem ==========================================================================
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\setup\setup.ps1" %*
echo.
pause
