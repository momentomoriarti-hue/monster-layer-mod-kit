@echo off
setlocal
chcp 65001 >nul
call "%~dp0_common.bat"

rem Checks a modded game .pck before you run it, with the standalone checker in
rem "Player Tools" (see Player Tools\README.md): compares it with your original game
rem and looks for calls and files a mod never needs. Nothing of the mod is run.
rem Drag a .pck onto this file, or pass its path. Without one, Moded Packed\*.pck is
rem checked. Your original game is Original Packed\*.pck. The report is saved next
rem to the .pck as <name>.check.txt.

set "PCK=%~1"
if not defined PCK for %%F in ("%MODED_PACKED%\*.pck") do if not defined PCK set "PCK=%%~fF"
if not defined PCK (
    echo [ERROR] No .pck given and none found in "%MODED_PACKED%".
    echo         Drag the mod's .pck onto check-mod.bat.
    goto :fail
)
if not defined ORIGINAL_PCK (
    echo [ERROR] No original game .pck in "%ORIGINAL_PACKED%".
    goto :fail
)

set "MLMK_NOPAUSE=1"
call "%ROOT%\Player Tools\check-mod.bat" "%PCK%" "%ORIGINAL_PCK%"
set "RESULT=%errorlevel%"
pause
exit /b %RESULT%

:fail
pause
exit /b 1
