<# : batch part. PowerShell reads this whole file as one script; cmd runs only these lines.
@echo off
setlocal
chcp 65001 >nul
rem Monster Layer: plays a mod inside Windows Sandbox, away from your files and the internet.
rem   drag the mod's .pck onto this file, or run: play-in-sandbox.bat "mod.pck" ["your game folder or Monster Layer.exe"]
rem See README.md next to this file.
set "MLMK_SELF=%~f0"
set "MLMK_MOD=%~1"
set "MLMK_GAME=%~2"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([ScriptBlock]::Create([IO.File]::ReadAllText($env:MLMK_SELF)))"
set "RESULT=%errorlevel%"
if not defined MLMK_NOPAUSE pause
exit /b %RESULT%
#>

# ---------------------------------------------------------------------------
# Monster Layer sandbox launcher (standalone). Everything below is PowerShell.
#
# Windows Sandbox is a throw-away Windows inside your Windows (Windows 10/11 Pro,
# Enterprise, Education). This script starts the game with the mod in it:
#   - no network inside the sandbox;
#   - your game folder and the mod are shared READ-ONLY; nothing else of your PC
#     is visible to the game;
#   - clipboard, printer, microphone and camera are off;
#   - the saves go to sandbox\saves next to this file (not your real saves);
#   - everything else is deleted when you close the sandbox window.
# The script never turns Windows features on; you do that yourself, see README.md.
# Exit codes: 0 started, 1 failed or Windows Sandbox not available.
# ---------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$here = Split-Path -Parent $env:MLMK_SELF
function Stop-Launch([string]$message) { Write-Host ''; Write-Host "[ERROR] $message" -ForegroundColor Red; exit 1 }
function Clean-Path([string]$p) { return $p.Trim().Trim('"').Trim() }
function Get-Sha([string]$path) { return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
$knownExe = '4BA39FAF170B9F1A0A1E3F4C286B3E825BAB10282DDD802B1329922E5F68F40D'

# ---- Windows Sandbox available? ----------------------------------------------
$sandboxExe = Join-Path $env:windir 'System32\WindowsSandbox.exe'
if (-not (Test-Path -LiteralPath $sandboxExe) -and -not $env:MLMK_SANDBOX_DRYRUN) {
    Write-Host 'Windows Sandbox is not turned on on this PC.' -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'It comes with Windows 10/11 Pro, Enterprise and Education (not Home). To turn it on:'
    Write-Host '  1. Press Win+R, type  optionalfeatures  and press Enter.'
    Write-Host '  2. Tick "Windows Sandbox", press OK (needs administrator rights) and restart the PC.'
    Write-Host '  3. Virtualization must be on in the BIOS/UEFI; Task Manager > Performance > CPU shows it.'
    Write-Host 'This script never changes Windows settings itself. On Windows Home, check the mod with'
    Write-Host 'check-mod.bat, or see README.md for other ways to isolate the game.'
    exit 1
}

# ---- The mod and your game -------------------------------------------------
$mod = $env:MLMK_MOD
if (-not $mod) { $mod = Read-Host 'Drag the mod''s .pck into this window and press Enter' }
$mod = Clean-Path $mod
if (-not (Test-Path -LiteralPath $mod -PathType Leaf)) { Stop-Launch "File not found: $mod" }
$mod = (Resolve-Path -LiteralPath $mod).Path
if ([IO.Path]::GetExtension($mod).ToLower() -ne '.pck') { Stop-Launch 'Give the launcher the mod''s .pck file. Never run an .exe that came with a mod.' }

$remember = Join-Path $here 'game_folder.txt'
$game = $env:MLMK_GAME
if (-not $game -and (Test-Path -LiteralPath $remember)) { $game = ([IO.File]::ReadAllText($remember, $utf8)).Trim() }
if (-not $game -or -not (Test-Path -LiteralPath (Clean-Path $game))) {
    Write-Host ''
    Write-Host 'Drag your game folder (with Monster Layer.exe) or Monster Layer.exe into this window and press Enter.'
    $game = Read-Host 'Game'
}
$game = Clean-Path $game
if (Test-Path -LiteralPath $game -PathType Leaf) { $exe = Get-Item -LiteralPath $game }
else {
    if (-not (Test-Path -LiteralPath $game -PathType Container)) { Stop-Launch "Not found: $game" }
    $exe = Get-ChildItem -LiteralPath $game -Filter '*.exe' -File | Where-Object { (Get-Sha $_.FullName) -eq $knownExe } | Select-Object -First 1
    if (-not $exe) { $exe = Get-ChildItem -LiteralPath $game -Filter 'Monster Layer.exe' -File | Select-Object -First 1 }
    if (-not $exe) { Stop-Launch "No Monster Layer.exe in $game" }
}
if ($exe.Extension.ToLower() -ne '.exe') { Stop-Launch "Not an .exe: $($exe.FullName)" }
[IO.File]::WriteAllText($remember, $exe.DirectoryName, $utf8)
if ((Get-Sha $exe.FullName) -ne $knownExe) { Write-Host "[WARNING] $($exe.Name) isn't the official game .exe this launcher knows. Use the .exe from your own download of the game." -ForegroundColor Yellow }
if (Get-Process -Name 'WindowsSandbox', 'WindowsSandboxClient', 'WindowsSandboxRemoteSession' -ErrorAction SilentlyContinue) {
    Stop-Launch 'Windows Sandbox is already open. Only one can run at a time: close it and try again.'
}

# ---- Folders shared with the sandbox -----------------------------------------
# sandbox\launcher  start.cmd (read-only)          -> C:\Sandbox\Launcher
# sandbox\mod       a copy of the mod .pck (read-only) -> C:\Sandbox\Mod
# your game folder  read-only, only the .exe is used   -> C:\Sandbox\Game
# sandbox\saves     the game's saves (read-write)      -> C:\Sandbox\Saves
$box = Join-Path $here 'sandbox'
$launcher = Join-Path $box 'launcher'
$modDir = Join-Path $box 'mod'
$saves = Join-Path $box 'saves'
foreach ($d in @($launcher, $modDir)) { if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force } }
New-Item -ItemType Directory $launcher, $modDir, $saves -Force | Out-Null
$pckName = $exe.BaseName + '.pck'
Copy-Item -LiteralPath $mod -Destination (Join-Path $modDir $pckName)

# Runs inside the sandbox when it starts: copies the game .exe and the mod to the
# sandbox's own disk (the shared folders stay untouched), points the game's save
# folder to C:\Sandbox\Saves and starts the game. The sandbox's virtual GPU has
# Direct3D 12 only (no Vulkan, OpenGL or ANGLE), and Godot 4.3's Mobile renderer
# (the game's default) hangs on Direct3D 12 there, so the game is started with the
# Forward+ renderer on Direct3D 12.
$start = @"
@echo off
set "PLAY=%USERPROFILE%\Desktop\Monster Layer"
mkdir "%PLAY%" 2>nul
copy /y "C:\Sandbox\Game\$($exe.Name)" "%PLAY%\$($exe.Name)" >nul
copy /y "C:\Sandbox\Mod\$pckName" "%PLAY%\$pckName" >nul
mkdir "%APPDATA%\Godot\app_userdata" 2>nul
mklink /J "%APPDATA%\Godot\app_userdata\MonsterLayer" "C:\Sandbox\Saves" >nul
start "" /D "%PLAY%" "%PLAY%\$($exe.Name)" --rendering-driver d3d12 --rendering-method forward_plus --log-file "C:\Sandbox\Saves\logs\sandbox.log"
"@
[IO.File]::WriteAllText((Join-Path $launcher 'start.cmd'), $start.Replace("`n", "`r`n").Replace("`r`r`n", "`r`n"), $utf8)

function Esc([string]$s) { return [Security.SecurityElement]::Escape($s) }
$wsb = @"
<Configuration>
  <Networking>Disable</Networking>
  <vGPU>Enable</vGPU>
  <AudioInput>Disable</AudioInput>
  <VideoInput>Disable</VideoInput>
  <ClipboardRedirection>Disable</ClipboardRedirection>
  <PrinterRedirection>Disable</PrinterRedirection>
  <MemoryInMB>4096</MemoryInMB>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>$(Esc $exe.DirectoryName)</HostFolder>
      <SandboxFolder>C:\Sandbox\Game</SandboxFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
    <MappedFolder>
      <HostFolder>$(Esc $modDir)</HostFolder>
      <SandboxFolder>C:\Sandbox\Mod</SandboxFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
    <MappedFolder>
      <HostFolder>$(Esc $launcher)</HostFolder>
      <SandboxFolder>C:\Sandbox\Launcher</SandboxFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
    <MappedFolder>
      <HostFolder>$(Esc $saves)</HostFolder>
      <SandboxFolder>C:\Sandbox\Saves</SandboxFolder>
      <ReadOnly>false</ReadOnly>
    </MappedFolder>
  </MappedFolders>
  <LogonCommand>
    <Command>C:\Sandbox\Launcher\start.cmd</Command>
  </LogonCommand>
</Configuration>
"@
$wsbPath = Join-Path $box 'Monster Layer.wsb'
[IO.File]::WriteAllText($wsbPath, $wsb, $utf8)

if ($env:MLMK_SANDBOX_DRYRUN) { Write-Host "Dry run: configuration written to $wsbPath"; exit 0 }
Write-Host 'Starting Windows Sandbox... The game starts inside it after Windows there has loaded.'
Write-Host 'Close the sandbox window when you are done; everything in it is deleted, the saves stay in'
Write-Host "  $saves"
Start-Process -FilePath $sandboxExe -ArgumentList "`"$wsbPath`""
exit 0
