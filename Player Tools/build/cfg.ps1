# Shared helpers for reading Custom Lay / Custom Boss configs (lay.cfg, boss.cfg)
# and mod_settings.cfg. Dot-sourced by apply-mods.ps1 (building a mod) and by the
# Mod Kit's pack-source.ps1 (packing a mod's source zip).

# Media kinds a Lay can have (lay.cfg: <kind>_anim), see mod_kit\custom_lay_media.gd.
$mediaKinds = @('thrust', 'pound', 'idle', 'free_cum', 'egg', 'lose', 'orgasm', 'hypno')

# Reads key=value from the [lay] section of lay.cfg; quotes and ; comments are stripped.
function Get-CfgValue([string[]]$lines, [string]$key, [string]$default = '') {
    foreach ($line in $lines) {
        if ($line -match "^\s*$([regex]::Escape($key))\s*=\s*(?:`"([^`"]*)`"|([^;\s]*))") {
            if ($Matches[1] -ne $null) { return $Matches[1] }
            return $Matches[2]
        }
    }
    return $default
}

# Puts an unquoted value of a key=value line in quotes, so Godot's ConfigFile can
# read it; quoted text, arrays, numbers and true/false are kept as they are.
function ConvertTo-GodotCfgLine([string]$line) {
    if ($line -notmatch '^(\s*[A-Za-z_][\w]*\s*=\s*)([^;]*?)(\s*(;.*)?)$') { return $line }
    $value = $Matches[2]
    if ($value -eq '' -or $value -match '^(".*"|\[.*\]|true|false|-?[\d.]+)$') { return $line }
    return $Matches[1] + '"' + $value.Replace('"', '') + '"' + $Matches[3]
}

# Reads a list of files: key=["a.mp4", "b.mp4"], key="a.mp4, b.mp4" or key=a.mp4.
# Returns an empty array when the key isn't set.
function Get-CfgList([string[]]$lines, [string]$key) {
    foreach ($line in $lines) {
        if ($line -match "^\s*$([regex]::Escape($key))\s*=\s*(.*)$") {
            $value = $Matches[1].Trim()
            if ($value.StartsWith('[')) {
                # Array: every quoted string up to the closing bracket.
                $inner = $value.Substring(1)
                if ($inner.Contains(']')) { $inner = $inner.Substring(0, $inner.IndexOf(']')) }
                return @([regex]::Matches($inner, '"([^"]*)"') | ForEach-Object { $_.Groups[1].Value.Trim() } | Where-Object { $_ -ne '' })
            }
            if ($value -match '^"([^"]*)"') { $value = $Matches[1] } else { $value = ($value -split ';')[0] }
            return @($value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
        }
    }
    return @()
}

# Trait ids the game knows (Library.traittext); lay.cfg "traits" must use them.
$traitNames = @('thrust', 'pound', 'arousal', 'cum', 'lucky', 'heart', 'intimate', 'feral', 'hypno', 'sticky')

# Checks the "traits" list of a lay.cfg; a wrong list stops the pack with an error.
function Test-Traits([string]$lay, [string[]]$lines) {
    $seen = @()
    foreach ($trt in @(Get-CfgList $lines 'traits')) {
        $id = $trt.ToLower()
        if ($id -notmatch '^([a-z]+)[+-]$' -or $traitNames -notcontains $Matches[1]) {
            throw "${lay}: unknown trait '$trt' in traits. Use one of: $(($traitNames | ForEach-Object { "$_+, $_-" }) -join ', ')."
        }
        $opposite = if ($id.EndsWith('+')) { $id.TrimEnd('+') + '-' } else { $id.TrimEnd('-') + '+' }
        if ($seen -contains $id) { throw "${lay}: trait '$id' is listed twice in traits." }
        if ($seen -contains $opposite) { throw "${lay}: traits '$opposite' and '$id' contradict each other." }
        $seen += $id
    }
    if ($seen.Count -gt 3) { throw "${lay}: traits lists $($seen.Count) traits, 3 at most are allowed." }
}
