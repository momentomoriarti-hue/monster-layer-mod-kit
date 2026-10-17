@echo off
setlocal
chcp 65001 >nul
call "%~dp0_common.bat"

rem Packs your mod as SOURCE instead of a .pck: a zip with only the mod's own
rem content - mod_settings.cfg and every active Custom Lay and boss (its config and
rem the original videos, GIFs and pictures it uses). No scripts, no game files.
rem Players can scan it with an antivirus or an AI agent and build the .pck with
rem "Player Tools\build-mod.bat", which holds all the code that builds it.
rem The zip goes to "Moded Source\<game name> mod (source).zip".

if not defined ORIGINAL_PCK (
    echo [ERROR] No original game .pck in "%ORIGINAL_PACKED%".
    goto :fail
)
for %%F in ("%ORIGINAL_PCK%") do set "GAME_NAME=%%~nF"
set "OUT=%ROOT%\Moded Source\%GAME_NAME% mod (source).zip"

echo Packing the mod's source...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pack-source.ps1" -Root "%ROOT%" -OriginalPck "%ORIGINAL_PCK%" -OutZip "%OUT%"
if errorlevel 1 (
    echo [ERROR] Packing the source failed.
    goto :fail
)

echo.
echo Done: "%OUT%"
echo Players build it with "Player Tools\build-mod.bat" and their own copy of the game.
echo Only Custom Lays, Custom Bosses and mod_settings.cfg go into it: changes you made to
echo the game's scripts by hand in Moded Unpacked can only be shared as a .pck.
pause
exit /b 0

:fail
pause
exit /b 1
