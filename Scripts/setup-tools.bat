@echo off
setlocal
chcp 65001 >nul

rem Sets up the mod kit from scratch. Downloads the tools the other scripts
rem need into the Tools folder and creates the Mods folder with an example mod:
rem   Tools\GDRE_tools - Godot RE Tools (unpacks the original .pck into a project)
rem   Tools\Godot      - Godot 4.3 editor (packs the modded project back into .pck)
rem   Tools\FFmpeg     - FFmpeg (converts Custom Lay and Boss videos/GIFs to Ogg Theora for Godot)
rem Uses only PowerShell, which is built into Windows.

set "ROOT=%~dp0.."
set "TOOLS=%ROOT%\Tools"
set "GDRE_DIR=%TOOLS%\GDRE_tools"
set "GODOT_DIR=%TOOLS%\Godot"
set "FFMPEG_DIR=%TOOLS%\FFmpeg"

rem Each download is checked against its pinned SHA-256 hash before it is unpacked.
rem GDRE Tools and FFmpeg: the SHA-256 digest GitHub publishes for the release asset.
set "GDRE_URL=https://github.com/GDRETools/gdsdecomp/releases/download/v2.7.4/GDRE_tools-v2.7.4-windows.zip"
set "GDRE_SHA256=af24c563eee501effb194d83595de64696c32547b2246034dbfb891a24bfa0ad"
rem Godot publishes only SHA-512 (SHA512-SUMS.txt in the release). This SHA-256 was computed
rem from a download whose SHA-512 matched the official one:
rem ad09b7e19949327700dfbe64e35880a2a08091c0751277f5cc21b915e5df9b4fe93fb43c50d6bdfb9d16b46168592491aa698e0d2dbe9f92132e163dd77b97e1
set "GODOT_URL=https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_win64.exe.zip"
set "GODOT_SHA256=8f2c75b734bd956027ae3ca92c41f78b5d5a255dacc0f20e4e3c523c545ad410"
rem The "full" build is needed: the "essentials" build has no Theora encoder.
set "FFMPEG_URL=https://github.com/GyanD/codexffmpeg/releases/download/9.0.2/ffmpeg-9.0.2-full_build-shared.zip"
set "FFMPEG_SHA256=8d31e162f1616e37aab3fa2db991b97e1b8dbeb1c8465fd81a81be16ff91b328"

if not exist "%TOOLS%" mkdir "%TOOLS%"

if exist "%GDRE_DIR%\gdre_tools.exe" (
    echo [OK] GDRE Tools already installed.
) else (
    echo Downloading GDRE Tools...
    call :download "%GDRE_URL%" "%GDRE_SHA256%" "%GDRE_DIR%" || goto :fail
)

if exist "%GODOT_DIR%\Godot_v4.3-stable_win64_console.exe" (
    echo [OK] Godot 4.3 already installed.
) else (
    echo Downloading Godot 4.3...
    call :download "%GODOT_URL%" "%GODOT_SHA256%" "%GODOT_DIR%" || goto :fail
)

if exist "%FFMPEG_DIR%\ffmpeg.exe" (
    echo [OK] FFmpeg already installed.
) else (
    echo Downloading FFmpeg...
    call :download "%FFMPEG_URL%" "%FFMPEG_SHA256%" "%TOOLS%\_ffmpeg_tmp" || goto :fail
    rem The zip has a versioned folder with bin\ inside; keep only ffmpeg.exe and its DLLs.
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "$ErrorActionPreference = 'Stop';" ^
        "$bin = (Get-ChildItem '%TOOLS%\_ffmpeg_tmp' -Recurse -Filter ffmpeg.exe)[0].DirectoryName;" ^
        "New-Item -ItemType Directory -Force '%FFMPEG_DIR%' | Out-Null;" ^
        "Get-ChildItem $bin | Where-Object { $_.Name -notin @('ffplay.exe', 'ffprobe.exe') } | Copy-Item -Destination '%FFMPEG_DIR%';" ^
        "Remove-Item '%TOOLS%\_ffmpeg_tmp' -Recurse -Force" || goto :fail
)

rem "._sc_" makes Godot self-contained: its settings stay in Tools\Godot instead of AppData.
if not exist "%GODOT_DIR%\._sc_" type nul > "%GODOT_DIR%\._sc_"

rem Mods: one folder per mod. Mods made before the Mods folder existed (Custom Lays,
rem Custom Bosses and mod_settings.cfg in the kit folder) are moved into Mods\My Mod.
set "MODS=%ROOT%\Mods"
if not exist "%MODS%" mkdir "%MODS%"
set "OLD_MOD="
if exist "%ROOT%\Custom Lays" set "OLD_MOD=1"
if exist "%ROOT%\Custom Bosses" set "OLD_MOD=1"
if exist "%ROOT%\mod_settings.cfg" set "OLD_MOD=1"
if defined OLD_MOD if not exist "%MODS%\My Mod" (
    mkdir "%MODS%\My Mod"
    copy "%~dp0templates\mod.cfg" "%MODS%\My Mod\mod.cfg" >nul
    if exist "%ROOT%\Custom Lays" move "%ROOT%\Custom Lays" "%MODS%\My Mod\Custom Lays" >nul
    if exist "%ROOT%\Custom Bosses" move "%ROOT%\Custom Bosses" "%MODS%\My Mod\Custom Bosses" >nul
    if exist "%ROOT%\mod_settings.cfg" move "%ROOT%\mod_settings.cfg" "%MODS%\My Mod\mod_settings.cfg" >nul
    echo [OK] Moved your Custom Lays, Custom Bosses and mod_settings.cfg into Mods\My Mod.
)

rem An example mod with an example Lay and boss, both switched off (active=false).
set "EXAMPLE=%MODS%\Example Mod"
if not exist "%EXAMPLE%" (
    mkdir "%EXAMPLE%"
    copy "%~dp0templates\mod.cfg" "%EXAMPLE%\mod.cfg" >nul
    copy "%~dp0templates\mod_settings.cfg" "%EXAMPLE%\mod_settings.cfg" >nul
    robocopy "%~dp0templates\Simplified_Anims_Custom_Lay_Example" "%EXAMPLE%\Custom Lays\Simplified_Anims_Custom_Lay_Example" /E /NFL /NDL /NJH /NJS /NP >nul
    robocopy "%~dp0templates\Simplified_Anims_Custom_Boss_Example" "%EXAMPLE%\Custom Bosses\Simplified_Anims_Custom_Boss_Example" /E /NFL /NDL /NJH /NJS /NP >nul
    echo [OK] Created Mods\Example Mod.
)

echo.
echo All tools are ready.
if not defined MLMK_NOPAUSE pause
exit /b 0

:download
rem %1 = url, %2 = expected SHA-256, %3 = destination folder
rem Exit code 2 = the downloaded file did not match the hash (it is deleted, nothing is unpacked).
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';" ^
    "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;" ^
    "$zip = Join-Path $env:TEMP ('mlmk_' + [guid]::NewGuid() + '.zip');" ^
    "try {" ^
    "  Invoke-WebRequest -Uri '%~1' -OutFile $zip;" ^
    "  $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash;" ^
    "  if ($hash -ne '%~2') {" ^
    "    Write-Host ('[ERROR] SHA-256 mismatch for %~nx1');" ^
    "    Write-Host ('  expected: %~2');" ^
    "    Write-Host ('  got:      ' + $hash.ToLower());" ^
    "    exit 2" ^
    "  }" ^
    "  New-Item -ItemType Directory -Force '%~3' | Out-Null;" ^
    "  Expand-Archive -Path $zip -DestinationPath '%~3' -Force" ^
    "} finally { Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue }"
exit /b %errorlevel%

:fail
if errorlevel 2 (
    echo.
    echo [ERROR] The downloaded file is not the expected one ^(it may be damaged or tampered with^).
    echo         It was deleted and nothing was installed. Try again later; if it keeps happening,
    echo         do not install it by hand - report it on the mod kit's GitHub page.
    if not defined MLMK_NOPAUSE pause
    exit /b 1
)
echo.
echo [ERROR] Download failed. Check your internet connection and try again.
if not defined MLMK_NOPAUSE pause
exit /b 1
