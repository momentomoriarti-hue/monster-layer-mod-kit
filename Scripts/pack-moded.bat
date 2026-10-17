@echo off
setlocal
chcp 65001 >nul
call "%~dp0_common.bat"

rem Builds the latest modded project (Moded Unpacked\build_<time>) into Moded Packed
rem as .exe + .pck. Uses the bundled Godot 4.3 editor. The original game .exe is used
rem as the export template, so no separate Godot export templates are needed.
rem Then make-release.bat puts the files to share (.pck only, no .exe) into Moded Packed\Release.
rem WARNING: everything currently in Moded Packed is deleted first.

if not exist "%GODOT%" (
    echo [ERROR] Godot not found. Run setup-tools.bat first.
    goto :fail
)

rem Latest build = last build_* folder by name (names are timestamps).
set "BUILD="
if exist "%MODED_UNPACKED%" (
    for /f "delims=" %%D in ('dir /b /ad /o-n "%MODED_UNPACKED%\build_*" 2^>nul') do if not defined BUILD set "BUILD=%MODED_UNPACKED%\%%D"
)
if not defined BUILD (
    echo [ERROR] No build_* folders in "%MODED_UNPACKED%". Run copy-unpacked.bat first.
    goto :fail
)
if not exist "%BUILD%\project.godot" (
    echo [ERROR] "%BUILD%" has no project.godot.
    goto :fail
)
echo Packing latest build: "%BUILD%"
if not defined ORIGINAL_EXE (
    echo [ERROR] No .exe file found in "%ORIGINAL_PACKED%".
    goto :fail
)

for %%F in ("%ORIGINAL_EXE%") do set "GAME_NAME=%%~nF"
set "TEMPLATE=%ORIGINAL_EXE:\=/%"

echo Applying mod kit changes...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\Player Tools\build\apply-mods.ps1" -Source "%ROOT%" -Build "%BUILD%" -Ffmpeg "%ROOT%\Tools\FFmpeg\ffmpeg.exe" -Cache "%ROOT%\Tools\media_cache"
if errorlevel 1 (
    echo [ERROR] Applying mod kit changes failed.
    goto :fail
)

echo Writing export preset...
(
    echo [preset.0]
    echo.
    echo name="Windows Desktop"
    echo platform="Windows Desktop"
    echo runnable=true
    echo dedicated_server=false
    echo custom_features=""
    echo export_filter="all_resources"
    echo include_filter="custom_lays/*,custom_bosses/*,mod_kit/*.cfg"
    echo exclude_filter="gdre_export.log"
    echo export_path=""
    echo encryption_include_filters=""
    echo encryption_exclude_filters=""
    echo encrypt_pck=false
    echo encrypt_directory=false
    echo script_export_mode=2
    echo.
    echo [preset.0.options]
    echo.
    echo custom_template/debug="%TEMPLATE%"
    echo custom_template/release="%TEMPLATE%"
    echo debug/export_console_wrapper=0
    echo binary_format/embed_pck=false
    echo binary_format/architecture="x86_64"
    echo application/modify_resources=false
) > "%BUILD%\export_presets.cfg"

if exist "%MODED_PACKED%" (
    echo Clearing "%MODED_PACKED%"...
    rd /s /q "%MODED_PACKED%"
    if exist "%MODED_PACKED%" (
        echo [ERROR] Could not clear the folder. Close the game if it is running and try again.
        goto :fail
    )
)
mkdir "%MODED_PACKED%"

echo Importing resources...
"%GODOT%" --headless --path "%BUILD%" --import

echo Exporting "%GAME_NAME%"...
"%GODOT%" --headless --path "%BUILD%" --export-release "Windows Desktop" "%MODED_PACKED%\%GAME_NAME%.exe"

if not exist "%MODED_PACKED%\%GAME_NAME%.pck" (
    echo [ERROR] Export failed. See the messages above.
    goto :fail
)

call "%~dp0make-release.bat" nopause
if errorlevel 1 goto :fail

echo.
echo Done. The modded game is in "%MODED_PACKED%" ^(.exe + .pck, for testing^).
echo Share only "%MODED_PACKED%\Release": the .pck, SHA256.txt and HOW_TO_INSTALL.txt, never the .exe.
pause
exit /b 0

:fail
pause
exit /b 1
