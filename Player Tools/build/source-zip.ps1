# Reads a mod's source zip safely. Dot-sourced by Player Tools\build-mod.bat
# (building a mod) and by the Mod Kit app's import (Mod Kit App\import-mod.ps1).
# Nothing from the zip is run: it is only unpacked, and only when every file is
# allowed:
#   mod_source.json, mod_settings.cfg,
#   Custom Lays\<name>\lay.cfg, Custom Bosses\<name>\boss.cfg,
#   videos, GIFs and pictures in those folders;
# no absolute paths or "..", no objects in configs (Object(...), Resource(...)),
# and every video or picture must really be one (its first bytes are checked, so
# a program renamed to .mp4 is refused).

function Get-ModMediaExtensions { return @('.mp4', '.m4v', '.webm', '.mov', '.mkv', '.avi', '.wmv', '.flv', '.mpg', '.mpeg', '.gif', '.ogv', '.png', '.jpg', '.jpeg', '.webp', '.bmp', '.tga') }

function Test-Bytes([byte[]]$head, [int]$at, [byte[]]$expected) {
    if ($head.Length -lt $at + $expected.Length) { return $false }
    for ($i = 0; $i -lt $expected.Length; $i++) {
        if ($head[$at + $i] -ne $expected[$i]) { return $false }
    }
    return $true
}

function Test-Ascii([byte[]]$head, [int]$at, [string]$text) {
    return Test-Bytes $head $at ([Text.Encoding]::ASCII.GetBytes($text))
}

# $true when the file starts the way a file of its type does.
function Test-MediaSignature([string]$path) {
    $ext = [IO.Path]::GetExtension($path).ToLower()
    $stream = [IO.File]::OpenRead($path)
    try {
        $head = New-Object byte[] 16
        $read = $stream.Read($head, 0, 16)
    } finally { $stream.Dispose() }
    if ($read -lt 4) { return $false }
    switch ($ext) {
        { $_ -in '.mp4', '.m4v', '.mov' } {
            foreach ($box in @('ftyp', 'moov', 'mdat', 'wide', 'free', 'skip', 'pnot')) { if (Test-Ascii $head 4 $box) { return $true } }
            return $false
        }
        { $_ -in '.webm', '.mkv' } { return Test-Bytes $head 0 ([byte[]](0x1A, 0x45, 0xDF, 0xA3)) }
        '.avi' { return (Test-Ascii $head 0 'RIFF') -and (Test-Ascii $head 8 'AVI ') }
        '.wmv' { return Test-Bytes $head 0 ([byte[]](0x30, 0x26, 0xB2, 0x75)) }
        '.flv' { return Test-Ascii $head 0 'FLV' }
        { $_ -in '.mpg', '.mpeg' } {
            return (Test-Bytes $head 0 ([byte[]](0, 0, 1, 0xBA))) -or (Test-Bytes $head 0 ([byte[]](0, 0, 1, 0xB3))) -or ($head[0] -eq 0x47)
        }
        '.gif' { return Test-Ascii $head 0 'GIF8' }
        '.ogv' { return Test-Ascii $head 0 'OggS' }
        '.png' { return Test-Bytes $head 0 ([byte[]](0x89, 0x50, 0x4E, 0x47)) }
        { $_ -in '.jpg', '.jpeg' } { return Test-Bytes $head 0 ([byte[]](0xFF, 0xD8, 0xFF)) }
        '.webp' { return (Test-Ascii $head 0 'RIFF') -and (Test-Ascii $head 8 'WEBP') }
        '.bmp' { return Test-Ascii $head 0 'BM' }
        # TGA has no signature at its start; its header is 18 bytes.
        '.tga' { return (Get-Item -LiteralPath $path).Length -gt 18 }
    }
    return $false
}

# Unpacks the allowed files of the zip into $dest and returns the problems
# found (an empty list = a clean mod source). With problems, delete $dest and
# don't use the mod.
function Expand-ModSource([string]$zipPath, [string]$dest) {
    $problems = New-Object Collections.Generic.List[string]
    $mediaExtensions = Get-ModMediaExtensions
    New-Item -ItemType Directory $dest -Force | Out-Null
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        foreach ($e in $archive.Entries) {
            $name = $e.FullName.Replace('\', '/')
            if ($name.EndsWith('/')) { continue }
            $parts = $name -split '/'
            $ext = [IO.Path]::GetExtension($name).ToLower()
            # No absolute paths, drives or ".." (a zip could write files anywhere).
            if ($name -match '^(/|[A-Za-z]:)' -or $parts -contains '..' -or $parts -contains '.') { $problems.Add("Unsafe path: $name"); continue }
            $ok = $name -eq 'mod_source.json' -or $name -eq 'mod_settings.cfg'
            if (-not $ok -and $parts.Count -ge 3 -and ($parts[0] -eq 'Custom Lays' -or $parts[0] -eq 'Custom Bosses')) {
                $cfgName = if ($parts[0] -eq 'Custom Lays') { 'lay.cfg' } else { 'boss.cfg' }
                $ok = ($parts.Count -eq 3 -and $parts[2] -eq $cfgName) -or $mediaExtensions -contains $ext
            }
            if (-not $ok) { $problems.Add("Not a config, video or picture of a Lay or boss: $name"); continue }
            $target = Join-Path $dest ($name.Replace('/', '\'))
            New-Item -ItemType Directory (Split-Path $target) -Force | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $target, $true)
            if ($mediaExtensions -contains $ext -and -not (Test-MediaSignature $target)) {
                $problems.Add("Not really a $ext file (its content is something else): $name")
            }
        }
    } finally { $archive.Dispose() }
    # Configs are read by Godot's ConfigFile, whose format can also describe objects;
    # a mod's config only holds text, numbers, true/false and lists.
    foreach ($f in Get-ChildItem -LiteralPath $dest -Recurse -File -Filter '*.cfg') {
        $hit = Select-String -LiteralPath $f.FullName -Pattern '\b(Object|\w*Resource)\s*\(' | Select-Object -First 1
        if ($hit) { $problems.Add("Object inside a config: $($f.FullName.Substring($dest.Length + 1)) line $($hit.LineNumber)") }
    }
    return , $problems
}
