<# : batch part. PowerShell reads this whole file as one script; cmd runs only these lines.
@echo off
setlocal
chcp 65001 >nul
rem Monster Layer mod safety checker. Usage:
rem   drag a mod's .pck onto this file, or run: check-mod.bat "mod.pck" ["your original Monster Layer.pck or game folder"]
rem See README.md next to this file. The mod is never run.
set "MLMK_SELF=%~f0"
set "MLMK_MOD=%~1"
set "MLMK_ORIGINAL=%~2"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([ScriptBlock]::Create([IO.File]::ReadAllText($env:MLMK_SELF)))"
set "RESULT=%errorlevel%"
if not defined MLMK_NOPAUSE pause
exit /b %RESULT%
#>

# ---------------------------------------------------------------------------
# Monster Layer mod safety checker (standalone). Everything below is PowerShell.
#
# A Godot .pck is the whole game: scripts, scenes and settings. GDScript has no
# sandbox, so a mod .pck can do anything a program can. This checker unpacks the
# mod and your original game with GDRE Tools (nothing is run), compares every
# script, and looks for things a game mod never needs: running programs, network,
# writing or deleting files outside the game, loading code or native libraries.
#
# Verdicts and exit codes: 0 LOOKS SAFE, 2 WARNING (couldn't check something, or
# unusual), 3 DANGER (don't run it), 1 the check couldn't run.
# ---------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$here = Split-Path -Parent $env:MLMK_SELF

# GDRE Tools: the version the checker is made for, and its official download.
$gdreVersion = '2.7.4'
$gdreUrl = 'https://github.com/GDRETools/gdsdecomp/releases/download/v2.7.4/GDRE_tools-v2.7.4-windows.zip'
$gdreSha256 = 'AF24C563EEE501EFFB194D83595DE64696C32547B2246034DBFB891A24BFA0AD'
# Official Monster Layer files the checker knows (SHA-256).
$knownGame = @{
    'CDE1076072E08BCFB9E13EEE0195B5C50671F70302EDBFFE35A1C659E7287EC3' = 'Monster Layer.pck (Godot 4.3 release)'
    '4BA39FAF170B9F1A0A1E3F4C286B3E825BAB10282DDD802B1329922E5F68F40D' = 'Monster Layer.exe (Godot 4.3 release)'
}

function Stop-Check([string]$message) {
    Write-Host ''
    Write-Host "[ERROR] $message" -ForegroundColor Red
    exit 1
}

function Get-Sha([string]$path) { return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }

# Removes quotes and spaces that come with a dragged-in path.
function Clean-Path([string]$p) { return $p.Trim().Trim('"').Trim() }

# ---- GDRE Tools ----------------------------------------------------------
$gdreCandidates = @(
    (Join-Path $here 'tools\GDRE_tools\gdre_tools.exe'),
    (Join-Path $here '..\Tools\GDRE_tools\gdre_tools.exe')   # inside the Monster Layer Mod Kit
)
$Gdre = $gdreCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $Gdre) {
    Write-Host 'This checker needs GDRE Tools (Godot RE Tools) to unpack .pck files. It is not here yet.'
    Write-Host "It will be downloaded from the official GitHub release (GDRE Tools v$gdreVersion, about 44 MB):"
    Write-Host "  $gdreUrl"
    Write-Host 'and checked against its known SHA-256 before it is used. Or answer N and download it'
    Write-Host 'yourself, see README.md.'
    $answer = Read-Host 'Download GDRE Tools now? [Y/N]'
    if ($answer -notmatch '^[YyДд]') { Stop-Check 'GDRE Tools is needed. See README.md, section "Downloading GDRE Tools yourself".' }
    $zip = Join-Path ([IO.Path]::GetTempPath()) ('gdre-' + [Guid]::NewGuid().ToString('N') + '.zip')
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $ProgressPreference = 'SilentlyContinue'
        Write-Host 'Downloading...'
        Invoke-WebRequest -Uri $gdreUrl -OutFile $zip -UseBasicParsing
        $hash = Get-Sha $zip
        if ($hash -ne $gdreSha256) { Stop-Check "The download doesn't match the official file (SHA-256 $hash). It was deleted; nothing was installed." }
        $dest = Join-Path $here 'tools\GDRE_tools'
        New-Item -ItemType Directory $dest -Force | Out-Null
        Expand-Archive -LiteralPath $zip -DestinationPath $dest -Force
        Write-Host '[OK] GDRE Tools installed.' -ForegroundColor Green
    } finally {
        if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
    }
    $Gdre = Join-Path $here 'tools\GDRE_tools\gdre_tools.exe'
    if (-not (Test-Path -LiteralPath $Gdre)) { Stop-Check 'GDRE Tools could not be installed.' }
}

# ---- Which files to check --------------------------------------------------
$mod = $env:MLMK_MOD
$orig = $env:MLMK_ORIGINAL
if (-not $mod) { $mod = Read-Host 'Drag the MOD .pck into this window and press Enter' }
$mod = Clean-Path $mod
if (-not (Test-Path -LiteralPath $mod -PathType Leaf)) { Stop-Check "File not found: $mod" }
$mod = (Resolve-Path -LiteralPath $mod).Path
if ([IO.Path]::GetExtension($mod).ToLower() -ne '.pck') {
    Stop-Check "Give the checker the mod's .pck file. A Monster Layer mod is only a .pck that runs with your own Monster Layer.exe; never run an .exe that came with a mod."
}

# Two .pck files dragged at once come in any order: the original is the known one.
if ($orig -and [IO.Path]::GetExtension((Clean-Path $orig)).ToLower() -eq '.pck' -and (Test-Path -LiteralPath (Clean-Path $orig))) {
    if ($knownGame.ContainsKey((Get-Sha $mod)) -and -not $knownGame.ContainsKey((Get-Sha (Clean-Path $orig)))) {
        $swap = $mod; $mod = (Resolve-Path -LiteralPath (Clean-Path $orig)).Path; $orig = $swap
    }
}

# The original game: given, remembered from last time, or asked for.
$remember = Join-Path $here 'original_game.txt'
if (-not $orig -and (Test-Path -LiteralPath $remember)) { $orig = ([IO.File]::ReadAllText($remember, $utf8)).Trim() }
if (-not $orig -or -not (Test-Path -LiteralPath (Clean-Path $orig))) {
    Write-Host ''
    Write-Host 'The mod is compared with your ORIGINAL, unmodded game. Drag your original'
    Write-Host 'Monster Layer.pck (or the game folder with it) into this window and press Enter.'
    Write-Host 'If you already put a mod into the game folder, use a backup of the original .pck.'
    $orig = Read-Host 'Original game'
}
$orig = Clean-Path $orig
if (Test-Path -LiteralPath $orig -PathType Container) {
    $found = Get-ChildItem -LiteralPath $orig -Filter '*.pck' -File | Select-Object -First 1
    if (-not $found) { Stop-Check "No .pck in $orig" }
    $orig = $found.FullName
}
if (-not (Test-Path -LiteralPath $orig -PathType Leaf)) { Stop-Check "File not found: $orig" }
$orig = (Resolve-Path -LiteralPath $orig).Path
$modHash = Get-Sha $mod
$origHash = Get-Sha $orig
if ($modHash -eq $origHash) { Stop-Check 'The mod and the original are the same file. Check the mod''s .pck against your original game''s .pck.' }
[IO.File]::WriteAllText($remember, $orig, $utf8)

# ---- Helpers ---------------------------------------------------------------
function Invoke-Gdre([string[]]$arguments, [string]$log) {
    $quoted = @('--headless') + ($arguments | ForEach-Object { "`"$_`"" })
    $p = Start-Process -FilePath $Gdre -ArgumentList $quoted -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err"
    return $p.ExitCode
}

# Lines of a script without blank lines and trailing spaces: comments become blank
# lines when a script is compiled, so blank lines can't be compared.
function Get-Lines([string]$text) {
    $n = 0
    $lines = New-Object Collections.Generic.List[object]
    foreach ($line in ($text -split '\r?\n')) {
        $n++
        $t = $line.TrimEnd()
        if ($t -ne '') { $lines.Add([pscustomobject]@{ N = $n; T = $t }) }
    }
    return , $lines
}

# Lines of $new that aren't in $old (Added) and lines of $old that aren't in $new
# (Removed), by longest common subsequence.
function Compare-Lines($old, $new) {
    $a = @($old | ForEach-Object { $_.T })
    $b = @($new | ForEach-Object { $_.T })
    $start = 0
    while ($start -lt $a.Count -and $start -lt $b.Count -and $a[$start] -ceq $b[$start]) { $start++ }
    $endA = $a.Count; $endB = $b.Count
    while ($endA -gt $start -and $endB -gt $start -and $a[$endA - 1] -ceq $b[$endB - 1]) { $endA--; $endB-- }
    $m = $endA - $start; $n = $endB - $start
    $added = New-Object Collections.Generic.List[object]
    $removed = New-Object Collections.Generic.List[object]
    if ($m * $n -gt 4000000) {
        $countA = @{}
        for ($i = $start; $i -lt $endA; $i++) { $countA[$a[$i]] = 1 + [int]$countA[$a[$i]] }
        $countB = @{}
        for ($j = $start; $j -lt $endB; $j++) { $countB[$b[$j]] = 1 + [int]$countB[$b[$j]] }
        for ($j = $start; $j -lt $endB; $j++) { if ($countA[$b[$j]] -gt 0) { $countA[$b[$j]]-- } else { $added.Add($new[$j]) } }
        for ($i = $start; $i -lt $endA; $i++) { if ($countB[$a[$i]] -gt 0) { $countB[$a[$i]]-- } else { $removed.Add($old[$i]) } }
        return @{ Added = $added; Removed = $removed }
    }
    $w = $n + 1
    $len = New-Object 'int[]' (($m + 1) * $w)
    for ($i = $m - 1; $i -ge 0; $i--) {
        for ($j = $n - 1; $j -ge 0; $j--) {
            if ($a[$start + $i] -ceq $b[$start + $j]) { $len[$i * $w + $j] = $len[($i + 1) * $w + $j + 1] + 1 }
            else {
                $down = $len[($i + 1) * $w + $j]
                $right = $len[$i * $w + $j + 1]
                $len[$i * $w + $j] = if ($down -ge $right) { $down } else { $right }
            }
        }
    }
    $i = 0; $j = 0
    while ($i -lt $m -and $j -lt $n) {
        if ($a[$start + $i] -ceq $b[$start + $j]) { $i++; $j++ }
        elseif ($len[($i + 1) * $w + $j] -ge $len[$i * $w + $j + 1]) { $removed.Add($old[$start + $i]); $i++ }
        else { $added.Add($new[$start + $j]); $j++ }
    }
    for (; $i -lt $m; $i++) { $removed.Add($old[$start + $i]) }
    for (; $j -lt $n; $j++) { $added.Add($new[$start + $j]) }
    return @{ Added = $added; Removed = $removed }
}

# Calls a game mod never needs. Danger: can harm the PC. Warning: unusual or can
# hide what the code does; a person should read it.
$rules = @(
    @{ Level = 'danger'; Why = 'runs or stops programs, or opens files and links outside the game'; Re = '\bOS\s*\.\s*(execute|execute_with_pipe|create_process|create_instance|shell_open|shell_show_in_file_manager|kill)\b' },
    @{ Level = 'danger'; Why = 'network access'; Re = '\b(HTTPRequest|HTTPClient|StreamPeerTCP|StreamPeerTLS|PacketPeerUDP|PacketPeerDTLS|WebSocketPeer|WebSocketMultiplayerPeer|TCPServer|UDPServer|DTLSServer|ENetConnection|ENetMultiplayerPeer|WebRTCPeerConnection|WebRTCMultiplayerPeer|JavaScriptBridge)\b|\bIP\s*\.\s*(resolve_hostname|get_local_addresses)' },
    @{ Level = 'danger'; Why = 'loads code or other packs at run time'; Re = '\bload_resource_pack\b|\bGDExtension(Manager)?\b|\bExpression\b|\bGDScript\s*\.\s*new\b|\bsource_code\b|\bCSharpScript\b|\bNativeExtension\b' },
    @{ Level = 'danger'; Why = 'creates objects from data (code can hide in it)'; Re = '\bstr_to_var\b|\bbytes_to_var_with_objects\b|\bdict_to_inst\b|\bget_var\s*\(\s*true|\ballow_objects\b|\bto_native\s*\([^)]*true' },
    @{ Level = 'danger'; Why = 'deletes, renames or copies files or folders'; Re = '\b(remove_absolute|rename_absolute|copy_absolute|erase_contents)\b|\bDirAccess\b.*\.\s*(remove|rename|copy)\s*\(|\bdir\w*\s*\.\s*(remove|rename|copy)\s*\(' },
    @{ Level = 'danger'; Why = 'path to a drive, a network share or up out of the game'; Re = '"(?:[A-Za-z]:[\\/]|\\\\|~[\\/])|(res|user)://[^"]*\.\.|"\.\.[\\/]' },
    @{ Level = 'danger'; Why = 'absolute file path'; Re = '(FileAccess|DirAccess|ResourceLoader|ResourceSaver|ConfigFile|Image)\s*\.\s*\w+\s*\(\s*"/' },
    @{ Level = 'danger'; Why = 'writes a file with a path made at run time'; Re = '\bFileAccess\s*\.\s*open\w*\s*\((?!\s*"(res|user)://)[^)]*\b(WRITE|READ_WRITE|WRITE_READ)\b' },
    @{ Level = 'warning'; Why = 'reads system folders, the environment or the command line'; Re = '\bOS\s*\.\s*(get_environment|set_environment|unset_environment|has_environment|get_executable_path|get_data_dir|get_config_dir|get_cache_dir|get_system_dir|get_cmdline_args|get_cmdline_user_args|move_to_trash|read_string_from_stdin)\b' },
    @{ Level = 'warning'; Why = 'calls functions or classes by a name made at run time (can hide what is called)'; Re = '\bEngine\s*\.\s*get_singleton\b|\bClassDB\s*\.\s*(instantiate|class_call_static)\b|\.\s*callv\s*\(|\.\s*call(_deferred)?\s*\(\s*[^"''\s)]|\bMarshalls\s*\.' }
)

function Find-Dangers($lines) {
    $hits = New-Object Collections.Generic.List[object]
    foreach ($line in $lines) {
        foreach ($rule in $rules) {
            if ($line.T -match $rule.Re) { $hits.Add([pscustomobject]@{ Level = $rule.Level; Text = "line $($line.N): $($rule.Why): $($line.T.Trim())" }) }
        }
    }
    return , $hits
}

function Get-Norm([string]$text) { return ((Get-Lines $text) | ForEach-Object { $_.T }) -join "`n" }
function Get-Rel([string]$base, [string]$full) { return $full.Substring($base.TrimEnd('\').Length + 1).Replace('\', '/') }

$findings = New-Object Collections.Generic.List[object]
$changedCode = New-Object Collections.Generic.List[string]
$info = New-Object Collections.Generic.List[string]
function Add-Finding([string]$level, [string]$title, [string[]]$details) {
    $findings.Add([pscustomobject]@{ Level = $level; Title = $title; Details = $details })
}

# ---- The original game, unpacked once and kept in cache\ -------------------
if (-not $knownGame.ContainsKey($origHash)) {
    Add-Finding 'warning' 'Your original game is not a version this checker knows' @(
        "$orig (SHA-256 $origHash)",
        'It may be another game version, or a .pck that was already modded. Changes that are',
        'already in it are not reported. Use the .pck from a fresh download of the game.')
} else { $info.Add("Original: $orig - $($knownGame[$origHash])") }
$original = Join-Path $here ("cache\original-" + $origHash.Substring(0, 16))
if (-not (Test-Path -LiteralPath (Join-Path $original 'project.godot'))) {
    Write-Host 'Unpacking your original game once (it is kept in the cache folder)...'
    if (Test-Path -LiteralPath $original) { Remove-Item -LiteralPath $original -Recurse -Force }
    New-Item -ItemType Directory $original -Force | Out-Null
    Invoke-Gdre @("--recover=$orig", "--output=$original") (Join-Path ([IO.Path]::GetTempPath()) 'mlmk-original-recover.log') | Out-Null
    if (-not (Test-Path -LiteralPath (Join-Path $original 'project.godot'))) { Stop-Check "GDRE Tools could not unpack the original game: $orig" }
}

$work = Join-Path ([IO.Path]::GetTempPath()) ('mlmk-check-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$pack = Join-Path $work 'pack'
$raw = Join-Path $work 'raw'
try {
    New-Item -ItemType Directory $pack | Out-Null
    Write-Host "Unpacking the mod: $mod"
    Invoke-Gdre @("--recover=$mod", "--output=$pack") (Join-Path $work 'recover.log') | Out-Null
    if (-not (Test-Path -LiteralPath (Join-Path $pack 'project.godot'))) { Stop-Check 'GDRE Tools could not unpack the mod. It may be damaged, encrypted or not a Godot .pck. Don''t run it.' }
    # The files exactly as they are in the .pck (the recovered project has
    # compiled scripts turned back into text and may hide a text copy next to them).
    Invoke-Gdre @("--extract=$mod", "--output=$raw") (Join-Path $work 'extract.log') | Out-Null
    $rawFiles = @(Get-ChildItem -LiteralPath $raw -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'gdre_export.log' })

    Write-Host 'Comparing scripts with the original game...'
    $origText = @{}
    foreach ($f in Get-ChildItem -LiteralPath $original -Recurse -File -Include '*.gd', 'project.godot' | Where-Object { $_.FullName -notmatch '\\\.(godot|autoconverted)\\' }) {
        $origText[(Get-Rel $original $f.FullName)] = [IO.File]::ReadAllText($f.FullName, $utf8)
    }
    $packFiles = @(Get-ChildItem -LiteralPath $pack -Recurse -File -Force)
    $candidates = @()
    foreach ($f in $packFiles | Where-Object { $_.Extension -eq '.gd' -and $_.FullName -notmatch '\\\.autoconverted\\' }) {
        $rel = Get-Rel $pack $f.FullName
        $text = [IO.File]::ReadAllText($f.FullName, $utf8)
        $exp = $origText[$rel]
        if ($exp -ne $null -and (Get-Norm $text) -ceq (Get-Norm $exp)) { continue }
        $candidates += [pscustomobject]@{ Rel = $rel; Name = $rel; Text = $text; Exp = $exp }
    }
    foreach ($f in $rawFiles | Where-Object { $_.Extension -eq '.gd' }) {
        $rel = Get-Rel $raw $f.FullName
        $text = [IO.File]::ReadAllText($f.FullName, $utf8)
        $recovered = Join-Path $pack $rel
        if ((Test-Path -LiteralPath $recovered) -and (Get-Norm $text) -ceq (Get-Norm ([IO.File]::ReadAllText($recovered, $utf8)))) { continue }
        $candidates += [pscustomobject]@{ Rel = $rel; Name = "$rel (text copy next to the compiled one)"; Text = $text; Exp = $origText[$rel] }
    }
    foreach ($f in $rawFiles | Where-Object { $_.Extension -eq '.remap' }) {
        $target = [regex]::Match([IO.File]::ReadAllText($f.FullName, $utf8), 'path="([^"]*)"').Groups[1].Value
        if ($target -notmatch '^res://') { Add-Finding 'danger' "Remap to a file outside the game: $(Get-Rel $raw $f.FullName)" @("It points to '$target'.") }
    }

    # Changed scripts are compiled and decompiled again on both sides, so comments,
    # formatting and the GDRE version don't count as changes.
    $rt = Join-Path $work 'roundtrip'
    New-Item -ItemType Directory "$rt\src", "$rt\gdc", "$rt\dec" | Out-Null
    $compile = @()
    for ($i = 0; $i -lt $candidates.Count; $i++) {
        if ($candidates[$i].Exp -eq $null) { continue }
        [IO.File]::WriteAllText("$rt\src\p$i.gd", $candidates[$i].Text, $utf8)
        [IO.File]::WriteAllText("$rt\src\e$i.gd", $candidates[$i].Exp, $utf8)
        $compile += "--compile=$rt\src\p$i.gd".Replace('\', '/'), "--compile=$rt\src\e$i.gd".Replace('\', '/')
    }
    for ($k = 0; $k -lt $compile.Count; $k += 40) {
        $group = @($compile[$k..([Math]::Min($k + 39, $compile.Count - 1))])
        Invoke-Gdre ($group + @('--bytecode=4.3.0', "--output=$rt\gdc".Replace('\', '/'))) (Join-Path $work "compile$k.log") | Out-Null
    }
    $decompile = @(Get-ChildItem "$rt\gdc" -Filter '*.gdc' | ForEach-Object { "--decompile=$($_.FullName)".Replace('\', '/') })
    for ($k = 0; $k -lt $decompile.Count; $k += 40) {
        $group = @($decompile[$k..([Math]::Min($k + 39, $decompile.Count - 1))])
        Invoke-Gdre ($group + @('--bytecode=4.3.0', "--output=$rt\dec".Replace('\', '/'))) (Join-Path $work "decompile$k.log") | Out-Null
    }
    function Get-RoundTrip([string]$name, [string]$fallback) {
        $path = "$rt\dec\$name.gd"
        if (Test-Path -LiteralPath $path) { return [IO.File]::ReadAllText($path, $utf8) }
        return $fallback
    }

    for ($i = 0; $i -lt $candidates.Count; $i++) {
        $c = $candidates[$i]
        $newLines = Get-Lines $c.Text
        if ($c.Exp -eq $null) {
            $what = 'New script'
            $added = $newLines
            $summary = "$($newLines.Count) lines, not in the original game"
        } else {
            $packRt = Get-RoundTrip "p$i" $null
            $expRt = Get-RoundTrip "e$i" $c.Exp
            if ($packRt -ne $null -and (Get-Norm $packRt) -ceq (Get-Norm $expRt)) { continue }
            if ($packRt -ne $null) { $newLines = Get-Lines $packRt }
            $diff = Compare-Lines (Get-Lines $expRt) $newLines
            $what = 'Changed script'
            $added = $diff.Added
            $summary = "$($diff.Added.Count) line(s) added or changed, $($diff.Removed.Count) removed"
        }
        $hits = Find-Dangers $added
        $changedCode.Add("$what - $($c.Name) - $summary")
        if ($hits.Count -gt 0) {
            $level = if (@($hits | Where-Object { $_.Level -eq 'danger' }).Count -gt 0) { 'danger' } else { 'warning' }
            $details = @("$summary.") + ($hits | ForEach-Object { "[$($_.Level)] $($_.Text)" }) + @('Added or changed lines:') + ($added | Select-Object -First 300 | ForEach-Object { "+ $($_.N): $($_.T)" })
            Add-Finding $level "${what}: $($c.Name)" $details
        }
    }

    foreach ($f in $packFiles | Where-Object { $_.Extension -eq '.gdc' }) {
        $rel = Get-Rel $pack $f.FullName
        $gd = ($rel -replace '^\.autoconverted/', '') -replace '\.gdc$', '.gd'
        if (-not (Test-Path -LiteralPath (Join-Path $pack $gd))) { Add-Finding 'warning' "Compiled script that could not be read: $gd" @("It can't be turned back into text, so it can't be checked.") }
    }

    # project.godot: autoloads (scripts that run at game start) and settings.
    $projOrig = @((Get-Lines $origText['project.godot']) | ForEach-Object { $_.T })
    $projNew = Get-Lines ([IO.File]::ReadAllText((Join-Path $pack 'project.godot'), $utf8))
    $projAdded = @($projNew | Where-Object { $projOrig -cnotcontains $_.T })
    if ($projAdded.Count -gt 0) {
        $info.Add("project.godot has $($projAdded.Count) added or changed line(s): $(($projAdded | Select-Object -First 15 | ForEach-Object { $_.T }) -join ' | ')")
    }

    Write-Host 'Checking the other files...'
    $nativeExts = @('.dll', '.so', '.dylib', '.gdextension', '.gdnlib', '.gdns', '.exe', '.com', '.scr', '.msi', '.bat', '.cmd', '.ps1', '.vbs', '.vbe', '.js', '.jse', '.wsf', '.hta', '.lnk', '.jar', '.cs', '.gde', '.pck', '.zip', '.7z', '.rar')
    $seen = @{}
    foreach ($f in @($rawFiles) + @($packFiles)) {
        $rel = if ($f.FullName.StartsWith($raw)) { Get-Rel $raw $f.FullName } else { Get-Rel $pack $f.FullName }
        if ($nativeExts -contains $f.Extension.ToLower() -and -not $seen[$rel]) {
            $seen[$rel] = $true
            Add-Finding 'danger' "Program, library or archive in the .pck: $rel" @('A game mod never needs one. Native libraries and programs can do anything on the PC.')
        }
    }
    foreach ($f in $rawFiles | Where-Object { $_.Extension -eq '.cfg' }) {
        $hits = @((Get-Lines ([IO.File]::ReadAllText($f.FullName, $utf8))) | Where-Object { $_.T -match '\b(Object|\w*Resource)\s*\(' })
        if ($hits.Count -gt 0) { Add-Finding 'danger' "Object in a config file: $(Get-Rel $raw $f.FullName)" (@('Config files of mods hold text and numbers; an object can carry code.') + ($hits | ForEach-Object { "line $($_.N): $($_.T)" })) }
    }
    $newOther = 0
    foreach ($f in $packFiles) {
        $rel = Get-Rel $pack $f.FullName
        $ext = $f.Extension.ToLower()
        if ($rel -eq 'gdre_export.log' -or $rel -match '^\.(autoconverted|godot)/' -or $ext -eq '.gd' -or $rel -eq 'project.godot') { continue }
        $origPath = Join-Path $original $rel
        $isNew = -not (Test-Path -LiteralPath $origPath -PathType Leaf)
        if ($isNew) { $newOther++ }
        if ($ext -ne '.tscn' -and $ext -ne '.tres') { continue }
        if (-not $isNew -and (Get-Sha $origPath) -eq (Get-Sha $f.FullName)) { continue }
        $lines = Get-Lines ([IO.File]::ReadAllText($f.FullName, $utf8))
        $embedded = @($lines | Where-Object { $_.T -match 'type="GDScript"|script/source|type="(GDExtension|CSharpScript)"' })
        $paths = @($lines | Where-Object { $_.T -match '^\[ext_resource.*path="(?!res://|uid://)' })
        if ($embedded.Count -gt 0 -or $paths.Count -gt 0) {
            $hits = Find-Dangers $lines
            $level = if ($paths.Count -gt 0 -or @($hits | Where-Object { $_.Level -eq 'danger' }).Count -gt 0) { 'danger' } else { 'warning' }
            Add-Finding $level "Script or outside path inside a scene: $rel" (@('Scenes can carry scripts inside them; read the script part.') + ($embedded + $paths | ForEach-Object { "line $($_.N): $($_.T)" }) + ($hits | ForEach-Object { "[$($_.Level)] $($_.Text)" }))
        }
    }
    if ($newOther -gt 0) { $info.Add("$newOther new file(s) besides scripts (pictures, videos, scenes, configs...).") }

    # Programs that came with the mod: an .exe next to the .pck must be the original game.
    foreach ($exe in Get-ChildItem -LiteralPath (Split-Path $mod) -Filter '*.exe' -File) {
        $h = Get-Sha $exe.FullName
        $origExe = Get-ChildItem -LiteralPath (Split-Path $orig) -Filter '*.exe' -File | Where-Object { (Get-Sha $_.FullName) -eq $h }
        if ($knownGame.ContainsKey($h) -or $origExe) { $info.Add("$($exe.Name) next to the mod is the original game .exe.") }
        else { Add-Finding 'danger' "$($exe.Name) next to the mod is not the original game .exe" @("SHA-256 $h. Don't run it: a mod is only a .pck that runs with your own Monster Layer.exe.") }
    }

    # ---- Report -----------------------------------------------------------
    $dangers = @($findings | Where-Object { $_.Level -eq 'danger' }).Count
    $warnings = @($findings | Where-Object { $_.Level -eq 'warning' }).Count
    if ($dangers -gt 0) { $verdict = "DANGER: $dangers dangerous finding(s). Don't run this mod."; $code = 3; $color = 'Red' }
    elseif ($warnings -gt 0) { $verdict = "WARNING: $warnings thing(s) to look at. Run the mod only if someone you trust has read them."; $code = 2; $color = 'Yellow' }
    else { $verdict = 'LOOKS SAFE: no dangerous calls or files found.'; $code = 0; $color = 'Green' }

    $report = New-Object Text.StringBuilder
    [void]$report.AppendLine('Monster Layer mod safety check')
    [void]$report.AppendLine("Mod:      $mod")
    [void]$report.AppendLine("SHA-256:  $modHash")
    [void]$report.AppendLine("Original: $orig")
    [void]$report.AppendLine("Date:     $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
    [void]$report.AppendLine('')
    [void]$report.AppendLine("VERDICT: $verdict")
    [void]$report.AppendLine('')
    [void]$report.AppendLine('== Findings ==')
    if ($findings.Count -eq 0) { [void]$report.AppendLine('  none') }
    $n = 0
    foreach ($f in $findings | Sort-Object { if ($_.Level -eq 'danger') { 0 } else { 1 } }) {
        $n++
        [void]$report.AppendLine("[$n] $($f.Level.ToUpper()): $($f.Title)")
        foreach ($d in $f.Details) { [void]$report.AppendLine("      $d") }
        [void]$report.AppendLine('')
    }
    [void]$report.AppendLine('== Changed code (scripts that differ from the original game) ==')
    if ($changedCode.Count -eq 0) { [void]$report.AppendLine('  none') }
    foreach ($c in $changedCode) { [void]$report.AppendLine("  $c") }
    if ($info.Count -gt 0) {
        [void]$report.AppendLine('')
        [void]$report.AppendLine('== Notes ==')
        foreach ($i in $info) { [void]$report.AppendLine("  $i") }
    }
    [void]$report.AppendLine('')
    [void]$report.AppendLine('== About this check ==')
    [void]$report.AppendLine('  The mod was unpacked and read, never run. Every script that differs from your original')
    [void]$report.AppendLine('  game was searched for things a mod never needs (programs, network, files outside the')
    [void]$report.AppendLine('  game, loading code). It can''t prove a mod is safe: clever code can hide what it does.')
    [void]$report.AppendLine('  Changed code is normal for a mod; read it if you can. Never run an .exe from a mod.')
    $reportPath = [IO.Path]::ChangeExtension($mod, '.check.txt')
    [IO.File]::WriteAllText($reportPath, $report.ToString(), $utf8)

    Write-Host ''
    foreach ($f in $findings | Sort-Object { if ($_.Level -eq 'danger') { 0 } else { 1 } }) {
        Write-Host "$($f.Level.ToUpper()): $($f.Title)" -ForegroundColor $(if ($f.Level -eq 'danger') { 'Red' } else { 'Yellow' })
        foreach ($d in ($f.Details | Select-Object -First 3)) { Write-Host "    $d" }
    }
    Write-Host "$($changedCode.Count) script(s) differ from the original game (normal for a mod)."
    Write-Host ''
    Write-Host "VERDICT: $verdict" -ForegroundColor $color
    Write-Host "Full report: $reportPath"
    exit $code
} finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
