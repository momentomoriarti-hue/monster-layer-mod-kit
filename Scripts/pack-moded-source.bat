@echo off
setlocal
chcp 65001 >nul
call "%~dp0_common.bat"

rem Packs a mod from Mods as SOURCE instead of a .pck (pack-moded-source.bat
rem "<mod name>", or choose from the list): a zip with only the mod's own content -
rem mod_settings.cfg and every active Custom Lay and boss (its config and the
rem original videos, GIFs and pictures it uses). No scripts, no game files.
rem Players can scan it with an antivirus or an AI agent and build the .pck with
rem "Player Tools\build-mod.bat", which holds all the code that builds it.
rem The zip goes to "Moded Source\<mod name> (source).zip".

if not defined ORIGINAL_PCK (
    echo [ERROR] No original game .pck in "%ORIGINAL_PACKED%".
    goto :fail
)
call "%~dp0_pick_mod.bat" "%~1" || goto :fail
set "OUT=%MODED_SOURCE%\%MOD% (source).zip"

echo Packing the mod's source...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pack-source.ps1" -ModDir "%MOD_DIR%" -OriginalPck "%ORIGINAL_PCK%" -OutZip "%OUT%"
if errorlevel 1 (
    echo [ERROR] Packing the source failed.
    goto :fail
)

echo.
echo Done: "%OUT%"
echo Players build it with "Player Tools\build-mod.bat" and their own copy of the game.
echo Only Custom Lays, Custom Bosses and mod_settings.cfg go into it: changes you made to
echo the game's scripts by hand in Moded Unpacked can only be shared as a .pck.
if not defined MLMK_NOPAUSE pause
exit /b 0

:fail
if not defined MLMK_NOPAUSE pause
exit /b 1
