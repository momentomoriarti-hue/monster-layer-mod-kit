# Hooks the mod kit into the game code of a build: registers the ModSettings and
# CustomLays autoloads in project.godot and adds the lines marked # [MLMK] to the
# game scripts. Called by apply-mods.ps1. Safe to run many times.

param(
    [Parameter(Mandatory = $true)][string]$Build
)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$marker = '# [MLMK]'

# $done: text that is in the file once it is patched; the file is skipped then.
function Edit-GameFile([string]$relPath, [string]$done, [scriptblock]$change) {
    $path = Join-Path $Build $relPath
    $text = [IO.File]::ReadAllText($path, $utf8)
    if ($text.Contains($done)) { return }
    $newText = & $change $text
    if ($newText -eq $text) { throw "Could not patch $relPath, the game code is not as expected." }
    [IO.File]::WriteAllText($path, $newText, $utf8)
    Write-Host "  patched $relPath"
}

Edit-GameFile 'project.godot' 'ModSettings=' {
    param($t)
    $t -replace '(?s)(\[autoload\].*?)(\r?\n\r?\n\[)', "`$1`nModSettings=`"*res://mod_kit/mod_settings.gd`"`$2"
}
Edit-GameFile 'project.godot' 'CustomLays=' {
    param($t)
    # Added last, so the game's own autoloads (Library, Settings) are ready before it.
    $t -replace '(?s)(\[autoload\].*?)(\r?\n\r?\n\[)', "`$1`nCustomLays=`"*res://mod_kit/custom_lays.gd`"`$2"
}
Edit-GameFile 'Scripts\Singleton\Library.gd' $marker {
    param($t)
    $hook = "`$1`t$marker custom Lays`n`tif forcedspecies == `"`":`n`t`tvar customlay = CustomLays.pick()`n`t`tif customlay != null:`n`t`t`treturn CustomLays.generate(customlay, traitless)`n"
    $t -replace '(func generateCutie\(traitless = false, forcedspecies = ""\):\r?\n)', $hook
}
Edit-GameFile 'Scene\Anim.gd' $marker {
    param($t)
    $t = $t -replace '(\tBuss\.curanim = self\r?\n)', "`$1`tCustomLays.attachMedia(self) $marker custom Lay media`n"
    $t = $t -replace '(?m)^(\t+)(activestate = "thrust"\r?\n)', "`$1`$2`$1CustomLays.onStroke(self, `"thrust`")`n"
    $t -replace '(?m)^(\t+)(poundcounter \+= 1\r?\n)', "`$1`$2`$1CustomLays.onStroke(self, `"pound`")`n"
}
Edit-GameFile 'Scene\Anim.gd' 'CustomLays.onSpecial' {
    param($t)
    $t = $t -replace '(func freeCum\(\):\r?\n)', "`$1`tCustomLays.onSpecial(self, `"free_cum`") $marker custom Lay media`n"
    $t = $t -replace '(func orgasm\(\):\r?\n)', "`$1`tCustomLays.onSpecial(self, `"orgasm`") $marker custom Lay media`n"
    $t -replace '(func playHypnoAnim\(animname = "Start"\):\r?\n)', "`$1`tCustomLays.onHypno(self, animname) $marker custom Lay media`n"
}
Edit-GameFile 'Scene\Anim.gd' '"disable_anim_acceleration_with_pleasure"' {
    param($t)
    # Builds patched before the setting was renamed: just rename it there.
    if ($t.Contains('"disable_anim_accelerations_with_pleasure"')) {
        return $t.Replace('"disable_anim_accelerations_with_pleasure"', '"disable_anim_acceleration_with_pleasure"')
    }
    # Everything that depends on Pleasure speed (timers, hits, model animation, eggs,
    # sound delays and volume) reads animspeed, so keeping it at 1 keeps them in sync.
    $t -replace '(\tanimspeed = 1 \+ \(plesureper \* 0\.5\)\r?\n)', "`$1`tif ModSettings.getBool(`"disable_anim_acceleration_with_pleasure`"): $marker`n`t`tanimspeed = 1`n"
}
Edit-GameFile 'Scripts\Singleton\GameManager.gd' $marker {
    param($t)
    $t -replace '(\tGameManager\.currentcutieinfo = Library\.getBossCutie\(bossname\)\r?\n)', "`$1`tCustomLays.applyBoss(bossname) $marker custom bosses`n"
}
Edit-GameFile 'Scripts\Singleton\GameManager.gd' 'CustomLays.tutorialCutie' {
    param($t)
    $t -replace '(\tvar cutie = Library\.generateCutie\(true, "kobold"\)\r?\n)', "`$1`tcutie = CustomLays.tutorialCutie(cutie) $marker disable_default_lays`n"
}
Edit-GameFile 'Scene\tutorial_worker.gd' $marker {
    param($t)
    $t -replace '(\t+)(var text = Library\.erodialogue\["tutorial"\]\[progress\]\r?\n)', "`$1`$2`$1text = CustomLays.tutorialText(text) $marker custom bosses`n"
}
Edit-GameFile 'Scene\upgrade_ui.gd' $marker {
    param($t)
    $t -replace '(\t+)(Buss\.ui\.playAnim\("DragonStart"\)\r?\n)', "`$1CustomLays.onDragonStart() $marker custom bosses`n`$1`$2"
}
Edit-GameFile 'Scripts\Singleton\Library.gd' 'CustomLays.raresDisabled' {
    param($t)
    $t -replace '(func getAllAllowedRares\(\):\r?\n)', "`$1`tif CustomLays.raresDisabled(): $marker disable_default_lays`n`t`treturn {}`n"
}
Edit-GameFile 'Scripts\Singleton\AudioManager.gd' $marker {
    param($t)
    $t = $t -replace '(func plapSound\(\):\r?\n)', "`$1`tif CustomLays.isMuted(`"plap`"): $marker mute_native_plap_sound`n`t`treturn`n"
    $t -replace '(func Moan\(\):\r?\n)', "`$1`tif CustomLays.isMuted(`"moan`"): $marker mute_native_moan`n`t`treturn`n"
}
Edit-GameFile 'Scene\lay_choosing_ui.gd' $marker {
    param($t)
    $t -replace '(\r?\n)(\tvar catagory = workingdict\["traits"\]\.pick_random\(\))', "`$1`tCustomLays.applyPortrait(color, eye, lines, workingdict) $marker custom Lay portrait`n`$2"
}
