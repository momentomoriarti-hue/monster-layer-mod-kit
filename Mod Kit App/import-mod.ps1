# Loads a mod someone else made into Mods\<name>\, so you can open, play and
# change it in the Mod Kit app. Called by the app (Load mod from file); it can
# also be run by hand:
#   import-mod.ps1 -Root <kit folder> -File <mod (source).zip or .pck> [-Accept yes]
#
# Nothing from the mod is ever run. The checks, in this order:
#   1. Windows Defender scans the file (when it is available).
#   2. A source zip goes through the same checks as Player Tools\build-mod.bat
#      (Player Tools\build\source-zip.ps1): only configs, videos and pictures of
#      Lays and bosses, every video and picture really one, no objects in
#      configs, no paths leaving the folder.
#   3. A .pck is checked with Player Tools\check-mod.bat against your original
#      game: DANGER refuses it, WARNING needs -Accept yes. Then only its custom
#      Lays, custom bosses and mod_settings.cfg are taken out of it with GDRE
#      Tools (the videos as the kit converted them, the pictures as they were);
#      anything else in the .pck (changed game code) is left behind.
# Exit codes: 0 loaded (prints MLMK_MOD=<name>), 1 failed, 2 a WARNING to accept
# first, 3 refused.

param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$File,
    [string]$Accept = ''
)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$Root = $Root.Replace('/', '\').TrimEnd('\')
$File = $File.Replace('/', '\')
. (Join-Path $Root 'Player Tools\build\source-zip.ps1')

$script:exitCode = 1
$script:target = ''
# Ends the import: prints the message, and on anything but success removes the
# half-made mod folder.
function Done([int]$code, [string]$message, [string]$color = 'Red') {
    if ($message) { Write-Host $message -ForegroundColor $color }
    $script:exitCode = $code
    throw 'MLMK_DONE'
}

$work = Join-Path ([IO.Path]::GetTempPath()) ('mlmk-import-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$target = ''
try {
if (-not (Test-Path -LiteralPath $File -PathType Leaf)) { Done 1 "[ERROR] File not found: $File" }
$ext = [IO.Path]::GetExtension($File).ToLower()
if ($ext -notin @('.zip', '.pck')) { Done 1 '[ERROR] A mod is a source .zip or a .pck. Never run an .exe or .bat that came with a mod.' }

# ---- 1. Antivirus ----
$defender = Join-Path $env:ProgramFiles 'Windows Defender\MpCmdRun.exe'
if (Test-Path -LiteralPath $defender) {
    Write-Host 'Scanning the file with Windows Defender...'
    & $defender -Scan -ScanType 3 -File $File -DisableRemediation | Out-Null
    if ($LASTEXITCODE -eq 2) { Done 3 'REFUSED: Windows Defender found a threat in this file. Delete it.' }
    if ($LASTEXITCODE -eq 0) { Write-Host '[OK] Windows Defender found nothing.' -ForegroundColor Green }
    else { Write-Host "WARNING: Windows Defender couldn't scan the file (code $LASTEXITCODE). Scan it with your antivirus." -ForegroundColor Yellow }
} else {
    Write-Host "WARNING: Windows Defender isn't available here. Scan the file with your antivirus." -ForegroundColor Yellow
}

# ---- Name of the new mod ----
$base = [IO.Path]::GetFileNameWithoutExtension($File) -replace '\s*\(source\)\s*$', ''
if ($base -eq '' -or $base -eq 'Monster Layer') { $base = 'Loaded mod' }
$base = ($base -replace '[\\/:*?"<>|]', '').Trim().TrimEnd('.')
$mods = Join-Path $Root 'Mods'
$name = $base
$n = 2
while (Test-Path -LiteralPath (Join-Path $mods $name)) { $name = "$base $n"; $n++ }
$target = Join-Path $mods $name
$script:target = $target

    if ($ext -eq '.zip') {
        # ---- 2. Source zip ----
        Write-Host 'Checking the source zip...'
        $problems = Expand-ModSource $File $work
        if ($problems.Count -gt 0) {
            foreach ($p in $problems) { Write-Host "  $p" -ForegroundColor Red }
            Done 3 "REFUSED: a mod source holds only configs, videos and pictures of its Lays and bosses. This one has other files, which could be dangerous. Don't use this mod."
        }
        Write-Host '[OK] Only configs, videos and pictures.' -ForegroundColor Green
        New-Item -ItemType Directory $target | Out-Null
        foreach ($folder in @('Custom Lays', 'Custom Bosses')) {
            $from = Join-Path $work $folder
            if (Test-Path -LiteralPath $from) { Copy-Item -LiteralPath $from -Destination $target -Recurse }
        }
        $settings = Join-Path $work 'mod_settings.cfg'
        if (Test-Path -LiteralPath $settings) { Copy-Item -LiteralPath $settings $target }
    } else {
        # ---- 3. Ready .pck ----
        $original = Get-ChildItem -LiteralPath (Join-Path $Root 'Original Packed') -Filter '*.pck' -File | Select-Object -First 1
        if (-not $original) { Done 1 "[ERROR] Your original game's .pck isn't in 'Original Packed'; it is needed to check the mod." }
        Write-Host 'Checking the .pck with check-mod.bat (nothing of it is run)...'
        $env:MLMK_NOPAUSE = '1'
        & cmd /c "`"$Root\Player Tools\check-mod.bat`" `"$File`" `"$($original.FullName)`""
        $verdict = $LASTEXITCODE
        if ($verdict -eq 3) { Done 3 "REFUSED: check-mod.bat found something dangerous (DANGER). Don't use this mod." }
        if ($verdict -eq 1) { Done 1 "[ERROR] The .pck couldn't be checked." }
        if ($verdict -eq 2 -and $Accept -ne 'yes') { Done 2 "WARNING: check-mod.bat found something unusual. Read the report (.check.txt next to the .pck) before you load it." 'Yellow' }

        Write-Host "Taking out the mod's Lays, bosses and settings..."
        $gdre = Join-Path $Root 'Tools\GDRE_tools\gdre_tools.exe'
        $raw = Join-Path $work 'raw'
        $includes = @('--include=res://custom_lays/**', '--include=res://custom_bosses/**', '--include=res://mod_kit/mod_settings.cfg')
        $log = Join-Path $work 'recover.log'
        New-Item -ItemType Directory $work -Force | Out-Null
        Start-Process -FilePath $gdre -ArgumentList (@('--headless', "`"--recover=$File`"", "`"--output=$raw`"") + $includes) -NoNewWindow -Wait -RedirectStandardOutput $log -RedirectStandardError "$log.err" | Out-Null
        # Pictures are stored imported; take them out again by their imported paths.
        $imported = @()
        foreach ($imp in Get-ChildItem -LiteralPath $raw -Recurse -File -Filter '*.import' -ErrorAction SilentlyContinue) {
            $m = Select-String -LiteralPath $imp.FullName -Pattern '^path="(res://\.godot/imported/[^"]+)"' | Select-Object -First 1
            if ($m) { $imported += "--include=$($m.Matches[0].Groups[1].Value)" }
        }
        if ($imported.Count -gt 0) {
            $raw2 = Join-Path $work 'raw2'
            Start-Process -FilePath $gdre -ArgumentList (@('--headless', "`"--recover=$File`"", "`"--output=$raw2`"", '--include=res://custom_lays/**', '--include=res://custom_bosses/**') + $imported) -NoNewWindow -Wait -RedirectStandardOutput "$log.2" -RedirectStandardError "$log.2.err" | Out-Null
            foreach ($pic in Get-ChildItem -LiteralPath $raw2 -Recurse -File | Where-Object { $_.FullName -notmatch '\\\.godot\\' -and $_.Extension -ne '.import' }) {
                $rel = $pic.FullName.Substring($raw2.Length)
                $dst = Join-Path $raw $rel
                New-Item -ItemType Directory (Split-Path $dst) -Force | Out-Null
                Copy-Item -LiteralPath $pic.FullName $dst -Force
            }
        }
        $count = 0
        New-Item -ItemType Directory $target | Out-Null
        foreach ($set in @(@('custom_lays', 'Custom Lays', 'lay.cfg'), @('custom_bosses', 'Custom Bosses', 'boss.cfg'))) {
            $from = Join-Path $raw $set[0]
            if (-not (Test-Path -LiteralPath $from)) { continue }
            foreach ($dir in Get-ChildItem -LiteralPath $from -Directory) {
                $cfg = Join-Path $dir.FullName $set[2]
                $media = Join-Path $dir.FullName 'media.cfg'
                if (-not (Test-Path -LiteralPath $cfg)) { continue }
                $to = Join-Path (Join-Path $target $set[1]) $dir.Name
                New-Item -ItemType Directory $to -Force | Out-Null
                $lines = [Collections.Generic.List[string]]([IO.File]::ReadAllLines($cfg))
                $section = ''
                $mediaLines = if (Test-Path -LiteralPath $media) { [IO.File]::ReadAllLines($media) } else { @() }
                foreach ($line in $mediaLines) {
                    if ($line -match '^\[(\w+)\]') { $section = $Matches[1]; continue }
                    $files = @([regex]::Matches($line, '"file":\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
                    if ($section -eq 'portrait' -and $line -match '^file="([^"]+)"') { $files = @($Matches[1]) }
                    if ($files.Count -eq 0) { continue }
                    foreach ($f in $files) {
                        $src = Join-Path $dir.FullName $f
                        if (-not (Test-Path -LiteralPath $src) -or -not (Test-MediaSignature $src)) { Done 3 "REFUSED: $($dir.Name)/$f isn't a real video or picture." }
                        Copy-Item -LiteralPath $src $to
                    }
                    # The videos are already converted (speed and length baked in).
                    $key = if ($section -eq 'portrait') { 'portrait' } else { "${section}_anim" }
                    $value = "$key=`"$($files -join ', ')`""
                    $index = -1
                    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match "^\s*;?$([regex]::Escape($key))\s*=") { $index = $i; if ($lines[$i] -notmatch '^\s*;') { break } } }
                    if ($index -ge 0) { $lines[$index] = $value } else { $lines.Add($value) }
                    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match "^\s*$([regex]::Escape($section))_anim_speed_modifier\s*=") { $lines[$i] = ';' + $lines[$i] } }
                }
                [IO.File]::WriteAllLines((Join-Path $to $set[2]), [string[]]$lines, $utf8)
                $count++
            }
        }
        $settings = Join-Path $raw 'mod_kit\mod_settings.cfg'
        if (Test-Path -LiteralPath $settings) { Copy-Item -LiteralPath $settings $target }
        if ($count -eq 0) {
            Remove-Item -LiteralPath $target -Recurse -Force
            Done 1 "This .pck has no custom Lays or bosses made with the Mod Kit; there is nothing to load. (You can still play it: check-mod.bat checked it.)" 'Yellow'
        }
        Write-Host "[OK] $count Lay(s) and boss(es) taken out; nothing else of the .pck is used." -ForegroundColor Green
    }

    # The new mod: its mod.cfg, and mod_settings.cfg if the mod had none.
    $modCfg = [IO.File]::ReadAllText((Join-Path $Root 'Scripts\templates\mod.cfg')) -replace ';name=""', ('name="' + $name + '"')
    [IO.File]::WriteAllText((Join-Path $target 'mod.cfg'), $modCfg, $utf8)
    if (-not (Test-Path -LiteralPath (Join-Path $target 'mod_settings.cfg'))) { Copy-Item -LiteralPath (Join-Path $Root 'Scripts\templates\mod_settings.cfg') $target }
    foreach ($folder in @('Custom Lays', 'Custom Bosses')) { New-Item -ItemType Directory (Join-Path $target $folder) -Force | Out-Null }
    Write-Host "Loaded as Mods\$name" -ForegroundColor Green
    Write-Output "MLMK_MOD=$name"
    $script:exitCode = 0
} catch {
    if ($_.Exception.Message -ne 'MLMK_DONE') { Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red; $script:exitCode = 1 }
} finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
    if ($script:exitCode -ne 0 -and (Test-Path -LiteralPath $target)) { Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue }
}
exit $script:exitCode
