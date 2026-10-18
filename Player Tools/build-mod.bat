<# : batch part. PowerShell reads this whole file as one script; cmd runs only these lines.
@echo off
setlocal
chcp 65001 >nul
rem Monster Layer: builds a mod's .pck from its source zip and your own copy of the game.
rem   drag the mod's source .zip onto this file, or run: build-mod.bat "mod (source).zip" ["your original Monster Layer.pck or game folder"]
rem Needs the "build" folder next to this file. See README.md.
set "MLMK_SELF=%~f0"
set "MLMK_ZIP=%~1"
set "MLMK_ORIGINAL=%~2"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([ScriptBlock]::Create([IO.File]::ReadAllText($env:MLMK_SELF)))"
set "RESULT=%errorlevel%"
if not defined MLMK_NOPAUSE pause
exit /b %RESULT%
#>

# ---------------------------------------------------------------------------
# Monster Layer mod builder. Everything below is PowerShell.
#
# A mod's source zip (made with the Monster Layer Mod Kit) holds ONLY the mod's
# own content: its configs (lay.cfg, boss.cfg, mod_settings.cfg) and its original
# videos, GIFs and pictures, plus mod_source.json. No scripts, no programs, no
# game files - so you can open every file and scan it with an antivirus or an AI
# agent. All the code that turns it into a .pck is here, next to this file:
#   build\apply-mods.ps1, build\hook-game.ps1, build\cfg.ps1  - the build steps
#   build\mod_kit\*.gd                                       - the game code a mod adds
# This script:
#   1. reads the zip and refuses any file that isn't a config, video or picture in
#      the expected place, or whose content isn't really a video or picture
#      (build\source-zip.ps1), so nothing in a mod source can run code;
#   2. unpacks your original game with GDRE Tools (kept in cache\);
#   3. adds the mod with build\apply-mods.ps1 (FFmpeg converts the videos);
#   4. packs the .pck with the official Godot 4.3, your own Monster Layer.exe being
#      the export template, and checks it with check-mod.bat if it is next to this file.
# The game is never downloaded: you always point to your own copy.
# Exit codes: 0 built, 3 refused (not a clean mod source), 1 failed.
# ---------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$here = Split-Path -Parent $env:MLMK_SELF
$engine = Join-Path $here 'build\apply-mods.ps1'

$tools = @{
    'GDRE Tools' = @{
        Exe = @('tools\GDRE_tools\gdre_tools.exe', '..\Tools\GDRE_tools\gdre_tools.exe'); Dest = 'tools\GDRE_tools'; Size = '44 MB'
        Url = 'https://github.com/GDRETools/gdsdecomp/releases/download/v2.7.4/GDRE_tools-v2.7.4-windows.zip'
        Sha = 'AF24C563EEE501EFFB194D83595DE64696C32547B2246034DBFB891A24BFA0AD'
        Why = 'unpacks your original game so the mod can be added to it'
    }
    'Godot 4.3' = @{
        Exe = @('tools\Godot\Godot_v4.3-stable_win64_console.exe', '..\Tools\Godot\Godot_v4.3-stable_win64_console.exe'); Dest = 'tools\Godot'; Size = '55 MB'
        Url = 'https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_win64.exe.zip'
        Sha = '8F2C75B734BD956027AE3CA92C41F78B5D5A255DACC0F20E4E3C523C545AD410'
        Why = 'packs the mod into a .pck (the official Godot editor, the version the game is made with)'
    }
    'FFmpeg' = @{
        Exe = @('tools\FFmpeg\ffmpeg.exe', '..\Tools\FFmpeg\ffmpeg.exe'); Dest = 'tools\FFmpeg'; Size = '100 MB'
        Url = 'https://github.com/GyanD/codexffmpeg/releases/download/9.0.2/ffmpeg-9.0.2-full_build-shared.zip'
        Sha = '8D31E162F1616E37AAB3FA2DB991B97E1B8DBEB1C8465FD81A81BE16FF91B328'
        Why = 'converts the mod''s videos and GIFs to the format the game can play'
        Bin = $true   # the zip has a versioned folder with bin\ inside
    }
}
$knownGame = @{
    'CDE1076072E08BCFB9E13EEE0195B5C50671F70302EDBFFE35A1C659E7287EC3' = 'Monster Layer.pck (Godot 4.3 release)'
    '4BA39FAF170B9F1A0A1E3F4C286B3E825BAB10282DDD802B1329922E5F68F40D' = 'Monster Layer.exe (Godot 4.3 release)'
}

function Stop-Build([string]$message) { Write-Host ''; Write-Host "[ERROR] $message" -ForegroundColor Red; exit 1 }
function Get-Sha([string]$path) { return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
function Clean-Path([string]$p) { return $p.Trim().Trim('"').Trim() }

if (-not (Test-Path -LiteralPath $engine)) { Stop-Build "The build folder is missing next to build-mod.bat ($engine). Download the whole Player Tools folder, see README.md." }
. (Join-Path $here 'build\source-zip.ps1')

# Finds a tool next to this file (or in the Mod Kit), or downloads its official,
# pinned release after asking, and checks its SHA-256 before unpacking it.
function Get-Tool([string]$name) {
    $t = $tools[$name]
    foreach ($rel in $t.Exe) { $p = Join-Path $here $rel; if (Test-Path -LiteralPath $p) { return (Resolve-Path -LiteralPath $p).Path } }
    Write-Host ''
    Write-Host "$name is needed: it $($t.Why)."
    Write-Host "It will be downloaded from its official GitHub release ($($t.Size)):"
    Write-Host "  $($t.Url)"
    Write-Host 'and checked against its known SHA-256 before it is used. Or answer N and download it'
    Write-Host 'yourself, see README.md.'
    $answer = Read-Host "Download $name now? [Y/N]"
    if ($answer -notmatch '^[Yy]') { Stop-Build "$name is needed. See README.md, section ""Downloading the tools yourself""." }
    $zip = Join-Path ([IO.Path]::GetTempPath()) ('mlmk-tool-' + [Guid]::NewGuid().ToString('N') + '.zip')
    $unpacked = "$zip.dir"
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $ProgressPreference = 'SilentlyContinue'
        Write-Host 'Downloading...'
        Invoke-WebRequest -Uri $t.Url -OutFile $zip -UseBasicParsing
        $hash = Get-Sha $zip
        if ($hash -ne $t.Sha) { Stop-Build "The download doesn't match the official file (SHA-256 $hash). It was deleted; nothing was installed." }
        $dest = Join-Path $here $t.Dest
        New-Item -ItemType Directory $dest -Force | Out-Null
        if ($t.Bin) {
            Expand-Archive -LiteralPath $zip -DestinationPath $unpacked -Force
            $bin = (Get-ChildItem -LiteralPath $unpacked -Recurse -Filter 'ffmpeg.exe' | Select-Object -First 1).DirectoryName
            Get-ChildItem -LiteralPath $bin | Where-Object { $_.Name -notin @('ffplay.exe', 'ffprobe.exe') } | Copy-Item -Destination $dest
        } else {
            Expand-Archive -LiteralPath $zip -DestinationPath $dest -Force
        }
        Write-Host "[OK] $name installed." -ForegroundColor Green
    } finally {
        if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
        if (Test-Path -LiteralPath $unpacked) { Remove-Item -LiteralPath $unpacked -Recurse -Force }
    }
    $p = Join-Path $here $t.Exe[0]
    if (-not (Test-Path -LiteralPath $p)) { Stop-Build "$name could not be installed." }
    return $p
}

# ---- The mod's source zip and your original game ---------------------------
$zipPath = $env:MLMK_ZIP
if (-not $zipPath) { $zipPath = Read-Host 'Drag the mod''s SOURCE .zip into this window and press Enter' }
$zipPath = Clean-Path $zipPath
if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) { Stop-Build "File not found: $zipPath" }
$zipPath = (Resolve-Path -LiteralPath $zipPath).Path
if ([IO.Path]::GetExtension($zipPath).ToLower() -ne '.zip') { Stop-Build 'Give the builder the mod''s source .zip (made with the Monster Layer Mod Kit). For a ready .pck use check-mod.bat.' }

$remember = Join-Path $here 'original_game.txt'
$orig = $env:MLMK_ORIGINAL
if (-not $orig -and (Test-Path -LiteralPath $remember)) { $orig = ([IO.File]::ReadAllText($remember, $utf8)).Trim() }
if (-not $orig -or -not (Test-Path -LiteralPath (Clean-Path $orig))) {
    Write-Host ''
    Write-Host 'The mod is built on top of your ORIGINAL, unmodded game. Drag your original'
    Write-Host 'Monster Layer.pck (or the game folder with it) into this window and press Enter.'
    Write-Host 'If you already put a mod into the game folder, use a backup of the original .pck.'
    $orig = Read-Host 'Original game'
}
$orig = Clean-Path $orig
if (Test-Path -LiteralPath $orig -PathType Container) {
    $found = Get-ChildItem -LiteralPath $orig -Filter '*.pck' -File | Select-Object -First 1
    if (-not $found) { Stop-Build "No .pck in $orig" }
    $orig = $found.FullName
}
if (-not (Test-Path -LiteralPath $orig -PathType Leaf)) { Stop-Build "File not found: $orig" }
$orig = (Resolve-Path -LiteralPath $orig).Path
$origHash = Get-Sha $orig
[IO.File]::WriteAllText($remember, $orig, $utf8)

# Your game's .exe is the export template (it is the Godot runtime of the game).
$exe = Get-ChildItem -LiteralPath (Split-Path $orig) -Filter '*.exe' -File | Where-Object { $knownGame.ContainsKey((Get-Sha $_.FullName)) } | Select-Object -First 1
if (-not $exe) { $exe = Get-ChildItem -LiteralPath (Split-Path $orig) -Filter "$([IO.Path]::GetFileNameWithoutExtension($orig)).exe" -File | Select-Object -First 1 }
if (-not $exe) {
    $exeIn = Clean-Path (Read-Host 'Drag your original Monster Layer.exe into this window and press Enter')
    if (-not (Test-Path -LiteralPath $exeIn -PathType Leaf)) { Stop-Build "File not found: $exeIn" }
    $exe = Get-Item -LiteralPath $exeIn
}
if (-not $knownGame.ContainsKey($origHash)) { Write-Host "[WARNING] Your original .pck isn't a version this builder knows (SHA-256 $origHash). If it was already modded, the result will contain that mod too." -ForegroundColor Yellow }
if (-not $knownGame.ContainsKey((Get-Sha $exe.FullName))) { Write-Host "[WARNING] $($exe.Name) isn't the official game .exe this builder knows. Use the .exe from your own download of the game." -ForegroundColor Yellow }

# ---- Read the zip: only configs, videos and pictures -------------------------
$work = Join-Path ([IO.Path]::GetTempPath()) ('mlmk-build-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$src = Join-Path $work 'source'
$proj = Join-Path $work 'project'
try {
    Write-Host "Reading $zipPath"
    # Only configs, videos and pictures are unpacked (build\source-zip.ps1).
    $problems = Expand-ModSource $zipPath $src
    if ($problems.Count -gt 0) {
        Write-Host ''
        foreach ($p in $problems) { Write-Host "  $p" -ForegroundColor Red }
        Write-Host ''
        Write-Host 'REFUSED: a mod source holds only configs, videos and pictures of its Lays and bosses.' -ForegroundColor Red
        Write-Host 'This one has other files, which could be dangerous. It was not built. Don''t use this mod.' -ForegroundColor Red
        exit 3
    }
    $manifestPath = Join-Path $src 'mod_source.json'
    if (-not (Test-Path -LiteralPath $manifestPath)) { Stop-Build 'This zip has no mod_source.json: it isn''t a mod source made with the Monster Layer Mod Kit.' }
    $manifest = [IO.File]::ReadAllText($manifestPath, $utf8) | ConvertFrom-Json
    if ($manifest.format -ne 2) { Stop-Build "Unknown mod source format '$($manifest.format)'. This builder reads format 2 (Monster Layer Mod Kit with sources made of configs and media only)." }
    if ($manifest.original_pck_sha256 -and $manifest.original_pck_sha256 -ne $origHash) {
        Write-Host "[WARNING] The mod was made for another version of the game (its original .pck has SHA-256 $($manifest.original_pck_sha256))." -ForegroundColor Yellow
        if ((Read-Host 'Build it anyway? [Y/N]') -notmatch '^[Yy]') { exit 1 }
    }

    # ---- Tools and your original game, unpacked once into cache\ -----------
    $gdre = Get-Tool 'GDRE Tools'
    $godot = Get-Tool 'Godot 4.3'
    $ffmpeg = Get-Tool 'FFmpeg'
    $godotDir = Split-Path $godot
    if ($godotDir.StartsWith($here) -and -not (Test-Path -LiteralPath (Join-Path $godotDir '._sc_'))) {
        # Self-contained mode: Godot keeps its settings next to it, not in AppData.
        [IO.File]::WriteAllText((Join-Path $godotDir '._sc_'), '', $utf8)
    }
    $original = Join-Path $here ('cache\original-' + $origHash.Substring(0, 16))
    if (-not (Test-Path -LiteralPath (Join-Path $original 'project.godot'))) {
        Write-Host 'Unpacking your original game once (it is kept in the cache folder)...'
        if (Test-Path -LiteralPath $original) { Remove-Item -LiteralPath $original -Recurse -Force }
        New-Item -ItemType Directory $original -Force | Out-Null
        $log = Join-Path $work 'recover.log'
        Start-Process -FilePath $gdre -ArgumentList @('--headless', "`"--recover=$orig`"", "`"--output=$original`"") -NoNewWindow -Wait -RedirectStandardOutput $log -RedirectStandardError "$log.err" | Out-Null
        if (-not (Test-Path -LiteralPath (Join-Path $original 'project.godot'))) { Stop-Build "GDRE Tools could not unpack the original game: $orig" }
    }

    # ---- The mod on top of the original --------------------------------------
    Write-Host 'Copying your original game...'
    New-Item -ItemType Directory $proj -Force | Out-Null
    # With Godot's import cache of the original, so only the mod's files are imported again.
    & robocopy $original $proj /E /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { Stop-Build 'Copying the original game failed.' }
    Write-Host 'Adding the mod (the same build steps as the Mod Kit)...'
    & $engine -Source $src -Build $proj -Ffmpeg $ffmpeg -Cache (Join-Path $here 'cache\media')
    $template = $exe.FullName.Replace('\', '/')
    $preset = @"
[preset.0]

name="Windows Desktop"
platform="Windows Desktop"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="custom_lays/*,custom_bosses/*,mod_kit/*.cfg"
exclude_filter="gdre_export.log"
export_path=""
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]

custom_template/debug="$template"
custom_template/release="$template"
debug/export_console_wrapper=0
binary_format/embed_pck=false
binary_format/architecture="x86_64"
application/modify_resources=false
"@
    [IO.File]::WriteAllText((Join-Path $proj 'export_presets.cfg'), $preset, $utf8)

    # ---- Build ---------------------------------------------------------------
    $outDir = Join-Path (Split-Path $zipPath) ("$([IO.Path]::GetFileNameWithoutExtension($zipPath)) - built")
    New-Item -ItemType Directory $outDir -Force | Out-Null
    $outPck = Join-Path $outDir ($exe.BaseName + '.pck')
    if (Test-Path -LiteralPath $outPck) { Remove-Item -LiteralPath $outPck -Force }
    Write-Host 'Importing resources...'
    $log = Join-Path $work 'godot.log'
    Start-Process -FilePath $godot -ArgumentList @('--headless', '--path', "`"$proj`"", '--import') -NoNewWindow -Wait -RedirectStandardOutput $log -RedirectStandardError "$log.err" | Out-Null
    Write-Host 'Packing the .pck...'
    Start-Process -FilePath $godot -ArgumentList @('--headless', '--path', "`"$proj`"", '--export-pack', '"Windows Desktop"', "`"$outPck`"") -NoNewWindow -Wait -RedirectStandardOutput "$log.2" -RedirectStandardError "$log.2.err" | Out-Null
    if (-not (Test-Path -LiteralPath $outPck)) { Stop-Build 'Godot could not pack the mod.' }
    Write-Host ''
    Write-Host "[OK] Built: $outPck" -ForegroundColor Green
    Write-Host "Back up your own $($exe.BaseName).pck, then put this one next to your $($exe.Name) (or play it in Windows Sandbox with play-in-sandbox.bat)."
} finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}

# ---- Check the result ----------------------------------------------------------
$checker = Join-Path $here 'check-mod.bat'
if (Test-Path -LiteralPath $checker) {
    Write-Host ''
    Write-Host 'Checking the built .pck with check-mod.bat...'
    $env:MLMK_NOPAUSE = '1'
    & cmd /c "`"$checker`" `"$outPck`" `"$orig`""
}
exit 0
