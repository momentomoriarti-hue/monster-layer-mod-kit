@echo off
setlocal
chcp 65001 >nul
call "%~dp0Scripts\_common.bat"

rem Starts the Monster Layer Mod Kit app: make mods, preview your Lays in the game
rem and pack them, without the separate scripts. The first start sets everything
rem up (downloads the tools, unpacks your game), so put your game's Monster Layer.exe
rem and Monster Layer.pck into "Original Packed" first.
rem The app is the readable Godot project in "Mod Kit App", run with the official
rem Godot 4.3 editor; see Mod Kit App\prepare-workspace.ps1.

set "MLMK_NOPAUSE=1"

if not exist "%GODOT%" call "%~dp0Scripts\setup-tools.bat" || goto :fail
if not exist "%MODS%" call "%~dp0Scripts\setup-tools.bat" || goto :fail

if not exist "%ORIGINAL_UNPACKED%\project.godot" (
    if not defined ORIGINAL_PCK (
        echo [ERROR] Put your game's Monster Layer.exe and Monster Layer.pck into
        echo         "%ORIGINAL_PACKED%" and start this again.
        goto :fail
    )
    call "%~dp0Scripts\unpack-original.bat" || goto :fail
)

rem Packing works on a copy of the game in Moded Unpacked; make one if there is none.
dir /b /ad "%MODED_UNPACKED%\build_*" >nul 2>&1 || call "%~dp0Scripts\copy-unpacked.bat" || goto :fail

powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\Mod Kit App\prepare-workspace.ps1" -Root "%ROOT%" || goto :fail

start "" "%ROOT%\Tools\Godot\Godot_v4.3-stable_win64.exe" --path "%ROOT%\Tools\app_workspace" -- "--kit-root=%ROOT%"
exit /b 0

:fail
pause
exit /b 1
