# Applies a mod to a build folder (an unpacked game project) before it is packed.
# Used by the Mod Kit (Scripts\pack-moded.bat) and by the players' build-mod.bat,
# so a mod is built the same way on both sides. Safe to run many times.
#   -Source  folder with the mod: Custom Lays\, Custom Bosses\ and mod_settings.cfg
#   -Build   the game project to change
#   -Ffmpeg  ffmpeg.exe, to convert the mod's videos and GIFs
#   -Cache   folder for converted videos, so the next build is faster
#   1. Copies the mod kit's game scripts (mod_kit\ next to this file) into the build.
#   2. Copies Custom Lays and Custom Bosses into the build as res://custom_lays and
#      res://custom_bosses, converting sex videos/GIFs to Ogg Theora (.ogv) with FFmpeg.
#   3. Hooks the game code (hook-game.ps1): registers the ModSettings and
#      CustomLays autoloads, applies mod_settings.cfg (Pleasure speed-up), makes
#      Library.generateCutie() spawn custom Lays, Anim.gd show their media,
#      AudioManager mute native sounds and the Lay choice screen show portraits.

param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Build,
    [Parameter(Mandatory = $true)][string]$Ffmpeg,
    [Parameter(Mandatory = $true)][string]$Cache
)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$marker = '# [MLMK]'

# 0. Builds patched before the rename to Mod Kit: move them to the new names, so
#    their hooks are recognised and the scripts load from res://mod_kit.
$oldScripts = Join-Path $Build 'mod_manager'
if (Test-Path $oldScripts) {
    Write-Host 'Updating a build patched by the old Mod Manager...'
    Remove-Item $oldScripts -Recurse -Force
    foreach ($file in Get-ChildItem $Build -Recurse -File -Include '*.gd', 'project.godot' | Where-Object { $_.FullName -notmatch '\\\.godot\\' }) {
        $text = [IO.File]::ReadAllText($file.FullName, $utf8)
        $new = $text.Replace('# [MLMM]', $marker).Replace('res://mod_manager/', 'res://mod_kit/')
        if ($new -ne $text) { [IO.File]::WriteAllText($file.FullName, $new, $utf8) }
    }
}

# 1. Mod kit scripts.
Write-Host 'Copying mod kit scripts...'
Copy-Item -Path (Join-Path $PSScriptRoot 'mod_kit') -Destination $Build -Recurse -Force
# Settings for the whole mod; without one, every setting has its default.
$settings = Join-Path $Source 'mod_settings.cfg'
if (Test-Path -LiteralPath $settings) {
    Copy-Item -LiteralPath $settings (Join-Path $Build 'mod_kit\mod_settings.cfg') -Force
} else {
    $settings = Join-Path $Build 'mod_kit\mod_settings.cfg'
    [IO.File]::WriteAllText($settings, "[settings]`n", $utf8)
}

# 2. Custom Lays: lay.cfg + media prepared for Godot, raw source videos are not shipped.
Write-Host 'Preparing Custom Lays...'
$laysDst = Join-Path $Build 'custom_lays'
$laysSrc = Join-Path $Source 'Custom Lays'
$ffmpeg = $Ffmpeg
$cacheDir = $Cache
$inv = [Globalization.CultureInfo]::InvariantCulture
$imageExts = @('.png', '.jpg', '.jpeg', '.webp', '.bmp', '.tga')
$videoExts = @('.mp4', '.m4v', '.webm', '.mov', '.mkv', '.avi', '.wmv', '.flv', '.mpg', '.mpeg', '.gif', '.ogv')

. (Join-Path $PSScriptRoot 'cfg.ps1')

# Length in seconds of each game animation, used by auto_fit_<kind>_anim_length
# (from Scene\Anim.gd and the species scenes). Strokes, idle, free cum and losing are
# given at Pleasure 0; the orgasm always runs at full Pleasure (x1.5 speed): its
# 4.5 s animation ends the round after 3.0 s. Hypno has no fixed length.
$strokeLength = @{ 'thrust' = 1.0; 'pound' = 0.5; 'idle' = 2.0; 'free_cum' = 2.0; 'egg' = 2.0; 'lose' = 2.0; 'orgasm' = 3.0; 'intro' = 7.0 }
$settingsLines = [IO.File]::ReadAllLines($settings)
$noAcceleration = (Get-CfgValue $settingsLines 'disable_anim_acceleration_with_pleasure' 'false').ToLower() -eq 'true'
# Without the Pleasure speed-up (mod_settings.cfg) the orgasm runs at normal speed: 4.5 s.
if ($noAcceleration) { $strokeLength['orgasm'] = 4.5 }

# anim_acceleration_steps (mod_settings.cfg): auto-fitted videos of these kinds get
# that many copies, copy k at x(1 + 0.5 * k / steps), to follow the Pleasure speed-up.
$steppedKinds = @('thrust', 'pound', 'idle', 'free_cum', 'egg', 'lose')
$accelSteps = 1
if (-not [int]::TryParse((Get-CfgValue $settingsLines 'anim_acceleration_steps' '1'), [ref]$accelSteps) -or $accelSteps -lt 1) {
    Write-Warning "mod_settings.cfg: anim_acceleration_steps must be a whole number of 1 or more, 1 is used."
    $accelSteps = 1
}
if ($noAcceleration) { $accelSteps = 1 }

# downgrade_all_animations_fps_to (mod_settings.cfg): no converted video, original or
# sped-up copy, gets a higher frame rate than this.
$fpsLimit = 60
$fpsText = (Get-CfgValue $settingsLines 'downgrade_all_animations_fps_to' '60').Replace(',', '.')
if (-not [double]::TryParse($fpsText, [Globalization.NumberStyles]::Float, $inv, [ref]$fpsLimit)) {
    Write-Warning "mod_settings.cfg: downgrade_all_animations_fps_to '$fpsText' is not a number, 60 is used."
    $fpsLimit = 60
} elseif ($fpsLimit -lt 1 -or $fpsLimit -gt 240) {
    Write-Warning "mod_settings.cfg: downgrade_all_animations_fps_to must be 1-240, it is set to the nearest."
    $fpsLimit = [Math]::Min([Math]::Max($fpsLimit, 1), 240)
}

# Frame rate, sound and duration of a video, read from FFmpeg's stream info.
function Get-VideoInfo([string]$src) {
    if (-not (Test-Path $ffmpeg)) { throw "FFmpeg not found: $ffmpeg" }
    # FFmpeg prints it to stderr and exits with 1 (no output file), which isn't an error here.
    $ErrorActionPreference = 'Continue'
    $info = (& $ffmpeg -hide_banner -i $src 2>&1 | Out-String)
    $ErrorActionPreference = 'Stop'
    $result = @{ 'fps' = 30.0; 'audio' = ($info -match 'Audio:'); 'duration' = 0.0 }
    if ($info -match 'Video:.*?([\d.]+) fps') { $result['fps'] = [double]::Parse($Matches[1], $inv) }
    if ($info -match 'Duration: (\d+):(\d+):([\d.]+)') {
        $result['duration'] = [int]$Matches[1] * 3600 + [int]$Matches[2] * 60 + [double]::Parse($Matches[3], $inv)
    }
    return $result
}

# Converts a video/GIF to Ogg Theora with the speed modifier baked in (Godot 4.3 can't
# change video speed). Results are cached in Tools\media_cache.
function Convert-Video([string]$src, [double]$speed, [string]$dst) {
    if (-not (Test-Path $ffmpeg)) { throw "FFmpeg not found: $ffmpeg" }
    $speedText = $speed.ToString($inv)
    $hash = (Get-FileHash $src -Algorithm SHA256).Hash
    $key = (Get-FileHash -InputStream ([IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes("$hash|$speedText|fps$fpsLimit|v3"))) -Algorithm SHA256).Hash.Substring(0, 32)
    $cached = Join-Path $cacheDir "$key.ogv"
    if (-not (Test-Path $cached)) {
        if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory $cacheDir | Out-Null }
        Write-Host "    converting $(Split-Path $src -Leaf) (speed x$speedText)..."

        $info = Get-VideoInfo $src
        $fps = $info['fps']
        $hasAudio = $info['audio']
        # Keep the source's real frames: the output rate follows the speed, capped at
        # downgrade_all_animations_fps_to (frames above it are dropped evenly).
        $outFps = [Math]::Min([Math]::Max($fps * $speed, 1), $fpsLimit).ToString('0.###', $inv)

        $vfilter = "setpts=PTS/$speedText,fps=$outFps,scale='min(iw,720)':'min(ih,1030)':force_original_aspect_ratio=decrease,scale=trunc(iw/2)*2:trunc(ih/2)*2"
        $audioArgs = @('-an')
        if ($hasAudio) {
            # atempo changes speed without changing pitch; it accepts 0.5-100, so chain it for slower speeds.
            $tempos = @()
            $rest = $speed
            while ($rest -lt 0.5) { $tempos += 'atempo=0.5'; $rest = $rest / 0.5 }
            while ($rest -gt 100) { $tempos += 'atempo=100'; $rest = $rest / 100 }
            $tempos += "atempo=$($rest.ToString($inv))"
            $audioArgs = @('-map', '0:a:0', '-af', ($tempos -join ','), '-c:a', 'libvorbis', '-q:a', '5')
        }
        $tmp = "$cached.tmp.ogv"
        & $ffmpeg -hide_banner -loglevel error -y -i $src -map_metadata -1 -map 0:v:0 -vf $vfilter -pix_fmt yuv420p -c:v libtheora -q:v 7 -g 30 @audioArgs $tmp
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $tmp)) { throw "FFmpeg could not convert $src" }
        Move-Item $tmp $cached -Force
    }
    Copy-Item $cached $dst -Force
}

# Prepares one folder of custom characters (Custom Lays or Custom Bosses) in the
# build: the config with unquoted values quoted, the media (videos converted with
# FFmpeg, sped-up copies, pictures copied) and media.cfg. Raw sources aren't shipped.
function Prepare-Characters([string]$srcRoot, [string]$dstRoot, [string]$cfgName, [string[]]$kinds, [bool]$checkTraits) {
    if (Test-Path $dstRoot) { Remove-Item $dstRoot -Recurse -Force }
    New-Item -ItemType Directory $dstRoot | Out-Null
    $script:prepared = 0
    if (-not (Test-Path $srcRoot)) { return }
    foreach ($layDir in Get-ChildItem $srcRoot -Directory) {
        $cfgPath = Join-Path $layDir.FullName $cfgName
        if (-not (Test-Path $cfgPath)) { continue }
        $lines = [IO.File]::ReadAllLines($cfgPath)
        # active=false switches it off: nothing of it goes into the game.
        if ((Get-CfgValue $lines 'active' 'true').Trim().ToLower() -eq 'false') {
            Write-Host "    $($layDir.Name): active=false, skipped"
            continue
        }
        $script:prepared++
        $dst = Join-Path $dstRoot $layDir.Name
        New-Item -ItemType Directory $dst | Out-Null
        if ($checkTraits) { Test-Traits $layDir.Name $lines }
        [IO.File]::WriteAllLines((Join-Path $dst $cfgName), [string[]]($lines | ForEach-Object { ConvertTo-GodotCfgLine $_ }), $utf8)
        $media = New-Object Text.StringBuilder
        $thrustFiles = @(Get-CfgList $lines 'thrust_anim')
        foreach ($kind in $kinds) {
            # Several files per field are allowed; the game picks one at random each time.
            $files = @(Get-CfgList $lines "${kind}_anim")
            if ($files.Count -eq 0 -and $kind -eq 'pound') { $files = $thrustFiles }
            $clips = @()
            for ($i = 0; $i -lt $files.Count; $i++) {
                $file = $files[$i]
                $src = Join-Path $layDir.FullName $file
                if (-not (Test-Path $src -PathType Leaf)) {
                    Write-Warning "$($layDir.Name): ${kind}_anim file '$file' not found, skipped."
                    continue
                }
                $name = "${kind}_$i"
                $ext = [IO.Path]::GetExtension($src).ToLower()
                if ($imageExts -contains $ext) {
                    Copy-Item $src (Join-Path $dst "$name$ext")
                    $clips += "{`"type`": `"image`", `"file`": `"$name$ext`"}"
                } elseif ($videoExts -contains $ext) {
                    $speed = $null
                    $fitted = $false
                    if ($strokeLength.ContainsKey($kind) -and (Get-CfgValue $lines "auto_fit_${kind}_anim_length" 'false').ToLower() -eq 'true') {
                        # Auto-fit: one play-through of the video = one game animation; the speed modifier is ignored.
                        $duration = (Get-VideoInfo $src)['duration']
                        if ($duration -gt 0) {
                            $speed = [Math]::Min([Math]::Max($duration / $strokeLength[$kind], 0.01), 100.0)
                            $fitted = $true
                            Write-Host ("    {0}: {1}: {2:0.##} s video fitted to the {3} s {4} animation (speed x{5:0.###})" -f $layDir.Name, $file, $duration, $strokeLength[$kind], $kind, $speed)
                        } else {
                            Write-Warning "$($layDir.Name): can't read the length of '$file', auto_fit_${kind}_anim_length is ignored."
                        }
                    }
                    if ($speed -eq $null) {
                        $speedText = (Get-CfgValue $lines "${kind}_anim_speed_modifier" '1').Replace(',', '.')
                        $speed = 1.0
                        if (-not [double]::TryParse($speedText, [Globalization.NumberStyles]::Float, $inv, [ref]$speed)) {
                            Write-Warning "$($layDir.Name): ${kind}_anim_speed_modifier '$speedText' is not a number, 1.0 is used."
                            $speed = 1.0
                        }
                        $speed = [Math]::Min([Math]::Max($speed, 0.01), 10.0)
                    }
                    Convert-Video $src $speed (Join-Path $dst "$name.ogv")
                    $variants = @("`"$name.ogv`"")
                    if ($fitted -and $accelSteps -gt 1 -and $steppedKinds -contains $kind) {
                        # Copy k plays from k/steps of Pleasure on, at the game's speed there.
                        for ($k = 1; $k -lt $accelSteps; $k++) {
                            Convert-Video $src ($speed * (1 + 0.5 * $k / $accelSteps)) (Join-Path $dst "${name}_s$k.ogv")
                            $variants += "`"${name}_s$k.ogv`""
                        }
                    }
                    $clips += "{`"type`": `"video`", `"file`": `"$name.ogv`", `"variants`": [$($variants -join ', ')]}"
                } else {
                    Write-Warning "$($layDir.Name): '$file' is not a supported video or picture, skipped."
                }
            }
            if ($clips.Count -gt 0) {
                [void]$media.Append("[$kind]`nclips=[$($clips -join ', ')]`n`n")
            }
        }
        $portrait = Get-CfgValue $lines 'portrait'
        if ($portrait -ne '') {
            $src = Join-Path $layDir.FullName $portrait
            $ext = [IO.Path]::GetExtension($src).ToLower()
            if (-not (Test-Path $src -PathType Leaf)) {
                Write-Warning "$($layDir.Name): portrait file '$portrait' not found, skipped."
            } elseif ($imageExts -notcontains $ext) {
                Write-Warning "$($layDir.Name): portrait '$portrait' is not a supported picture, skipped."
            } else {
                Copy-Item $src (Join-Path $dst "portrait$ext")
                [void]$media.Append("[portrait]`nfile=`"portrait$ext`"`n`n")
            }
        }
        if ($media.Length -gt 0) {
            [IO.File]::WriteAllText((Join-Path $dst 'media.cfg'), $media.ToString(), $utf8)
        }
    }
}

Prepare-Characters $laysSrc $laysDst 'lay.cfg' $mediaKinds $true | Out-Null
$count = $script:prepared
Write-Host "  $count custom Lay(s)"

# Custom Bosses: the same, as res://custom_bosses, plus the intro media.
Write-Host 'Preparing Custom Bosses...'
Prepare-Characters (Join-Path $Source 'Custom Bosses') (Join-Path $Build 'custom_bosses') 'boss.cfg' ($mediaKinds + 'intro') $false | Out-Null
$bossCount = $script:prepared
Write-Host "  $bossCount custom boss(es)"

# disable_default_lays / disable_default_boss (mod_settings.cfg) need custom ones
# to replace them, otherwise the game would have no Lay or no end boss.
if ((Get-CfgValue $settingsLines 'disable_default_lays' 'false').ToLower() -eq 'true' -and $count -eq 0) {
    throw "mod_settings.cfg: disable_default_lays=true, but there are no custom Lays in 'Custom Lays' (ones with active=false don't count). Add or activate a custom Lay, or set it to false."
}
if ((Get-CfgValue $settingsLines 'disable_default_boss' 'false').ToLower() -eq 'true' -and $bossCount -eq 0) {
    throw "mod_settings.cfg: disable_default_boss=true, but there are no custom bosses in 'Custom Bosses' (ones with active=false don't count). Add or activate a custom boss, or set it to false."
}

# 3. Hooks.
Write-Host 'Hooking game code...'
& (Join-Path $PSScriptRoot 'hook-game.ps1') -Build $Build
