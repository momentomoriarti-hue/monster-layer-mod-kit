@echo off
rem Picks the mod to work on, a folder in Mods. Called via:
rem   call "%~dp0_pick_mod.bat" "%~1"
rem %1 = the mod's folder name. Without it the only mod is used, or you choose one
rem from a list. Sets MOD (folder name) and MOD_DIR (full path); exit code 1 if
rem there is no such mod.

set "MOD=%~1"
if defined MOD goto :check

set "COUNT=0"
if exist "%MODS%" for /d %%D in ("%MODS%\*") do call :add "%%~nxD"
if "%COUNT%"=="0" (
    echo [ERROR] No mods in "%MODS%". Run setup-tools.bat, or add a mod in the Mod Kit app.
    exit /b 1
)
if "%COUNT%"=="1" (
    set "MOD=%MOD_1%"
    goto :check
)
echo Mods:
for /l %%N in (1,1,%COUNT%) do call echo   %%N. %%MOD_%%N%%
set "CHOICE="
set /p "CHOICE=Number of the mod: "
call set "MOD=%%MOD_%CHOICE%%%"

:check
set "MOD_DIR=%MODS%\%MOD%"
if not defined MOD goto :missing
if not exist "%MOD_DIR%\" goto :missing
echo Mod: %MOD%
exit /b 0

:missing
echo [ERROR] No mod "%MOD%" in "%MODS%".
exit /b 1

:add
set /a COUNT+=1
set "MOD_%COUNT%=%~1"
exit /b 0
