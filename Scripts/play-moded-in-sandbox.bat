@echo off
setlocal
chcp 65001 >nul
call "%~dp0_common.bat"

rem Plays the modded game from Moded Packed inside Windows Sandbox, to test the mod
rem the way a careful player would: no network, your files out of reach. Uses
rem "Player Tools\play-in-sandbox.bat" with Moded Packed\*.pck and the original
rem game .exe from Original Packed. Run pack-moded.bat first.

set "PCK="
for %%F in ("%MODED_PACKED%\*.pck") do if not defined PCK set "PCK=%%~fF"
if not defined PCK (
    echo [ERROR] No .pck in "%MODED_PACKED%". Run pack-moded.bat first.
    goto :fail
)
if not defined ORIGINAL_EXE (
    echo [ERROR] No .exe file found in "%ORIGINAL_PACKED%".
    goto :fail
)

set "MLMK_NOPAUSE=1"
call "%ROOT%\Player Tools\play-in-sandbox.bat" "%PCK%" "%ORIGINAL_EXE%"
set "RESULT=%errorlevel%"
pause
exit /b %RESULT%

:fail
pause
exit /b 1
