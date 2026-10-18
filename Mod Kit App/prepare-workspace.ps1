# Prepares the Mod Kit app's working copy of the game: Tools\app_workspace.
# Called by "Monster Layer Mod Kit.bat" before the app starts.
#
# The app is a Godot project built on top of your own unpacked game, so it can
# show your Lays with the game's real scenes, fonts and fight logic. Nothing of
# it is a ready-made program: it runs from the readable files in Mod Kit App\app
# with the official Godot 4.3 editor in Tools\Godot.
#   1. Original Unpacked is copied to Tools\app_workspace (again only when the
#      original game changes), and Godot imports it once.
#   2. The Mod Kit's game code is added with Player Tools\build\apply-mods.ps1,
#      the same step as when a mod is packed (with an empty mod here).
#   3. Mod Kit App\app is copied to res://mlmk_app, and override.cfg makes it the
#      main scene and gives the app its own save folder
#      (%APPDATA%\MonsterLayer Mod Kit App), so your real saves aren't touched.

param([Parameter(Mandatory = $true)][string]$Root)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$orig = Join-Path $Root 'Original Unpacked'
$ws = Join-Path $Root 'Tools\app_workspace'
$godot = Join-Path $Root 'Tools\Godot\Godot_v4.3-stable_win64_console.exe'
$ffmpeg = Join-Path $Root 'Tools\FFmpeg\ffmpeg.exe'
$engine = Join-Path $Root 'Player Tools\build\apply-mods.ps1'
$empty = Join-Path $Root 'Tools\app_preview\empty_mod'

$origProject = Join-Path $orig 'project.godot'
if (-not (Test-Path -LiteralPath $origProject)) { throw "No unpacked game in '$orig'. Run Scripts\unpack-original.bat." }
$stamp = [string](Get-Item -LiteralPath $origProject).LastWriteTimeUtc.Ticks
$stampFile = Join-Path $ws '.mlmk_original'
$fresh = -not (Test-Path -LiteralPath $stampFile) -or ([IO.File]::ReadAllText($stampFile).Trim() -ne $stamp)

if ($fresh) {
    Write-Host 'Copying your unpacked game for the Mod Kit app (only the first time)...'
    New-Item -ItemType Directory $ws -Force | Out-Null
    & robocopy $orig $ws /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw 'Copying the game failed.' }
}

Write-Host 'Adding the Mod Kit code...'
New-Item -ItemType Directory $empty -Force | Out-Null
& $engine -Source $empty -Build $ws -Ffmpeg $ffmpeg -Cache (Join-Path $Root 'Tools\media_cache') | Out-Null

& robocopy (Join-Path $PSScriptRoot 'app') (Join-Path $ws 'mlmk_app') /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw 'Copying the app failed.' }

$override = @'
[application]

config/name="Monster Layer Mod Kit"
run/main_scene="res://mlmk_app/main.tscn"
config/use_custom_user_dir=true
config/custom_user_dir_name="MonsterLayer Mod Kit App"

[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/window_width_override=1280
window/size/window_height_override=720
window/handheld/orientation=0
'@
[IO.File]::WriteAllText((Join-Path $ws 'override.cfg'), $override.Replace("`r`n", "`n"), $utf8)

if ($fresh) {
    Write-Host 'Importing the game into Godot (only the first time, it takes a few minutes)...'
    # Godot prints harmless warnings to stderr; Start-Process keeps PowerShell from
    # treating them as errors.
    $log = Join-Path $Root 'Tools\app_preview\import.log'
    Start-Process -FilePath $godot -ArgumentList @('--headless', '--path', "`"$ws`"", '--import') -NoNewWindow -Wait -RedirectStandardOutput $log -RedirectStandardError "$log.err" | Out-Null
    [IO.File]::WriteAllText($stampFile, $stamp, $utf8)
}
Write-Host 'Starting the Mod Kit app...'
