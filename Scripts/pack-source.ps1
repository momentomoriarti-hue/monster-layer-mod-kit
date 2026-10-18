# Packs a mod as source: a zip with only the mod's own content, no scripts and no
# game files. Called by pack-moded-source.bat. Players can open every file, scan it
# with an antivirus or an AI agent, and build the .pck themselves with
# "Player Tools\build-mod.bat", which holds all the code that builds it.
#
# Zip layout (format 2):
#   mod_source.json                format, the original game .pck it was made for
#   mod_settings.cfg               settings for the whole mod (if you have one)
#   Custom Lays\<name>\lay.cfg     every active custom Lay: its config and the
#   Custom Lays\<name>\...         original videos, GIFs and pictures it uses
#   Custom Bosses\<name>\boss.cfg  the same for custom bosses
#   Custom Bosses\<name>\...

param(
    [Parameter(Mandatory = $true)][string]$ModDir,
    [Parameter(Mandatory = $true)][string]$OriginalPck,
    [Parameter(Mandatory = $true)][string]$OutZip
)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
. (Join-Path $PSScriptRoot '..\Player Tools\build\cfg.ps1')

# Files of one Lay or boss: its config and every file its fields point to.
function Get-CharacterFiles([IO.DirectoryInfo]$dir, [string]$cfgName, [string[]]$kinds) {
    $cfg = Join-Path $dir.FullName $cfgName
    $lines = [IO.File]::ReadAllLines($cfg)
    if ((Get-CfgValue $lines 'active' 'true').Trim().ToLower() -eq 'false') { return $null }
    $files = New-Object Collections.Generic.List[string]
    $files.Add($cfgName)
    $names = @()
    foreach ($kind in $kinds) { $names += @(Get-CfgList $lines "${kind}_anim") }
    $names += @(Get-CfgValue $lines 'portrait')
    foreach ($name in $names | Where-Object { $_ } | Select-Object -Unique) {
        $full = [IO.Path]::GetFullPath((Join-Path $dir.FullName $name))
        if (-not $full.StartsWith($dir.FullName.TrimEnd('\') + '\')) { throw "$($dir.Name): '$name' points outside its folder." }
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { Write-Warning "$($dir.Name): file '$name' not found, skipped."; continue }
        $files.Add($full.Substring($dir.FullName.TrimEnd('\').Length + 1))
    }
    return , $files
}

Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
if (Test-Path -LiteralPath $OutZip) { Remove-Item -LiteralPath $OutZip -Force }
New-Item -ItemType Directory (Split-Path $OutZip) -Force | Out-Null
$zip = [IO.Compression.ZipFile]::Open($OutZip, [IO.Compression.ZipArchiveMode]::Create)
$counts = @{ 'Custom Lays' = 0; 'Custom Bosses' = 0 }
$fileCount = 0
try {
    # Written with .NET with "/" in paths: Windows PowerShell 5.1's Compress-Archive
    # stores backslashes, which other zip tools don't read as folders.
    function Add-Entry([string]$file, [string]$entry) {
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file, $entry.Replace('\', '/'), [IO.Compression.CompressionLevel]::Optimal)
    }
    foreach ($set in @(@('Custom Lays', 'lay.cfg', $mediaKinds), @('Custom Bosses', 'boss.cfg', ($mediaKinds + 'intro')))) {
        $base = Join-Path $ModDir $set[0]
        if (-not (Test-Path -LiteralPath $base)) { continue }
        foreach ($dir in Get-ChildItem -LiteralPath $base -Directory) {
            if (-not (Test-Path -LiteralPath (Join-Path $dir.FullName $set[1]))) { continue }
            if ($set[1] -eq 'lay.cfg') { Test-Traits $dir.Name ([IO.File]::ReadAllLines((Join-Path $dir.FullName $set[1]))) }
            $files = Get-CharacterFiles $dir $set[1] $set[2]
            if ($files -eq $null) { Write-Host "    $($dir.Name): active=false, skipped"; continue }
            foreach ($rel in $files) { Add-Entry (Join-Path $dir.FullName $rel) "$($set[0])\$($dir.Name)\$rel"; $fileCount++ }
            $counts[$set[0]]++
        }
    }
    $settings = Join-Path $ModDir 'mod_settings.cfg'
    if (Test-Path -LiteralPath $settings) { Add-Entry $settings 'mod_settings.cfg'; $fileCount++ }
    $manifest = [ordered]@{
        format = 2
        made_with = 'Monster Layer Mod Kit'
        godot_version = '4.3'
        original_pck = (Split-Path $OriginalPck -Leaf)
        original_pck_sha256 = (Get-FileHash -LiteralPath $OriginalPck -Algorithm SHA256).Hash
        created = (Get-Date -Format 'yyyy-MM-dd HH:mm')
        custom_lays = $counts['Custom Lays']
        custom_bosses = $counts['Custom Bosses']
    }
    $json = Join-Path ([IO.Path]::GetTempPath()) ('mlmk-manifest-' + [Guid]::NewGuid().ToString('N') + '.json')
    try {
        [IO.File]::WriteAllText($json, ($manifest | ConvertTo-Json), $utf8)
        Add-Entry $json 'mod_source.json'
    } finally { Remove-Item -LiteralPath $json -Force -ErrorAction SilentlyContinue }
} finally { $zip.Dispose() }
$size = [Math]::Round((Get-Item -LiteralPath $OutZip).Length / 1MB, 1)
Write-Host "  $($counts['Custom Lays']) custom Lay(s), $($counts['Custom Bosses']) custom boss(es), $fileCount file(s), $size MB"
