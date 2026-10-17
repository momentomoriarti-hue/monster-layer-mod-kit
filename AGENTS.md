# Monster Layer Mod Kit — notes for AI agents

This file is for AI coding agents (Claude Code, Codex, Cursor and others) that a
user asks to review this repository or a mod made with it, especially for
security. Read it before changing or running anything. User-facing docs are
`README.md` (English) and `README.ru.md` (Russian).

## What the kit is

Windows scripts (cmd + PowerShell) that turn the Godot 4.3 game *Monster Layer*
into an editable project and pack a modded build back:

1. `Scripts/setup-tools.bat` downloads GDRE Tools, Godot 4.3 and FFmpeg into
   `Tools/` (pinned GitHub release URLs, each archive checked against a pinned
   SHA-256 before it is unpacked). It also creates `Custom Lays/`,
   `Custom Bosses/` and `mod_settings.cfg` from `Scripts/templates/`.
2. `Scripts/unpack-original.bat` unpacks the user's own game
   (`Original Packed/*.pck`) into `Original Unpacked/` with GDRE Tools.
3. `Scripts/copy-unpacked.bat` copies it into `Moded Unpacked/build_<time>/`,
   where mods are made.
4. `Scripts/pack-moded.bat` runs `Player Tools/build/apply-mods.ps1` (copies
   `Player Tools/build/mod_kit/*`, `mod_settings.cfg`, Custom Lays and Bosses
   into the build, converts their videos with FFmpeg, hooks the game via
   `Player Tools/build/hook-game.ps1`; config helpers in `cfg.ps1`). The same
   engine is used by the players' `build-mod.bat`. It exports the build with
   the bundled Godot (the original game `.exe` is the export template) and
   `Scripts/make-release.bat` puts only the `.pck`, its SHA-256 and install
   notes into `Moded Packed/Release/`.
5. `Scripts/pack-moded-source.bat` (+ `pack-source.ps1`) packs a mod as a
   source zip in `Moded Source/` instead (format 2): only `mod_settings.cfg`,
   the `lay.cfg` / `boss.cfg` of every active Custom Lay and Boss and the
   original media files they reference, plus `mod_source.json` (format,
   original .pck name and SHA-256, counts). No scripts, no game files; all
   build code lives in `Player Tools/build/`.
6. `Player Tools/` is a standalone folder for players, each tool one .bat with
   its PowerShell code inside, the `build/` engine and a bilingual README:
   - `check-mod.bat` inspects a `.pck` without running it (see below);
   - `build-mod.bat` builds a `.pck` from a source zip on top of the player's
     own game (GDRE Tools + FFmpeg + Godot 4.3, `build/apply-mods.ps1`, the
     player's `.exe` as export template). It whitelists zip entries (only
     `mod_source.json`, `mod_settings.cfg`, `Custom Lays/<n>/lay.cfg`,
     `Custom Bosses/<n>/boss.cfg` and media extensions in those folders; no
     `..`/absolute paths; no `Object(`/`Resource(` in configs) and refuses the
     whole zip otherwise;
   - `play-in-sandbox.bat` writes a Windows Sandbox `.wsb` (network off, game
     folder and mod read-only, saves in `sandbox/saves`) and starts it.
   `Scripts/check-mod.bat` and `Scripts/play-moded-in-sandbox.bat` run them for
   the kit's own build.

No script ever downloads the game: the user always provides their own copy.

The game itself, the tools, builds and the user's own Lays are not in git
(see `.gitignore`).

## Trust model — what to tell users

- **The `.exe` is the Godot engine; the `.pck` is the whole game.** It holds
  every script (compiled GDScript), scene, resource and the project settings,
  including autoloads that run at start. Replacing `Monster Layer.pck` replaces
  all game logic. GDScript has no sandbox: a `.pck` can run programs
  (`OS.execute`), use the network (`HTTPRequest`, sockets), read, write and
  delete files anywhere the user can, and load native code (GDExtension). So
  **a mod `.pck` must be treated like a program**, not like a data file.
- Mods made with this kit don't need any of those abilities. The kit's own
  game code (`Player Tools/build/mod_kit/`) only reads files inside the pack (`res://`):
  configs, videos and pictures. It doesn't touch the network, other processes
  or files outside the game.
- A mod should be published as a source zip (`Moded Source/`) and/or the
  `.pck` only (`Moded Packed/Release/`). An `.exe`, `.dll` or archive with
  programs that comes with a mod is a red flag.
- **Building from source runs the Godot editor**, and the editor executes
  `@tool` scripts, editor plugins (`addons/*/plugin.cfg`, `[editor_plugins]`)
  and export/import plugins of the project. That is why a source zip may hold
  only configs and media: `build-mod.bat` refuses any other file (scripts,
  scenes, resources, `project.godot`, `override.cfg`, programs, archives,
  unsafe zip paths) before Godot starts. Keep it that way: kit features must
  be config fields read by `Player Tools/build/mod_kit/`, never code shipped
  in a mod. Residual risk: crafted media exploiting FFmpeg or Godot's image
  importers; users should scan the zip with an antivirus.

## Auditing the kit itself

Everything that runs is plain text in this repository; there are no binaries
in git. Check, in this order:

1. **Downloads:** `Scripts/setup-tools.bat` and the Player Tools
   (`check-mod.bat`, `build-mod.bat`) download tools (`Invoke-WebRequest`), the
   Player Tools only after asking. Confirm every URL points to an official
   release (GDRETools/gdsdecomp, godotengine/godot, GyanD/codexffmpeg), that
   each download is checked against the pinned SHA-256 *before* it is unpacked,
   that a mismatch deletes the file and stops, and that nothing downloads the
   game.
2. **Programs started:** the scripts run only the downloaded tools
   (`Tools/GDRE_tools/gdre_tools.exe`, `Tools/Godot/Godot_v4.3-stable_win64*.exe`,
   `Tools/FFmpeg/ffmpeg.exe`, or the same under `Player Tools/tools/`) plus
   Windows built-ins (cmd, PowerShell, robocopy) and `WindowsSandbox.exe`. Search for anything else: `Start-Process`, `&` calls, `cmd /c`,
   `Invoke-Expression`, `iex`, `DownloadString`, `curl`, `bitsadmin`, `certutil`.
3. **Files touched:** the scripts write only inside the kit folder (`Tools/`,
   `Original Unpacked/`, `Moded Unpacked/`, `Moded Packed/`, `Custom *`,
   `mod_settings.cfg`, `Moded Source/`, `Player Tools/` subfolders), next to a
   checked or built mod (`.check.txt`, `<zip> - built/`) and the Windows temp
   folder (download archives, work folders). They delete folders only there (`rd /s /q`, `Remove-Item`):
   verify every delete target is built from the kit's own paths.
4. **Game code added to mods:** `Player Tools/build/mod_kit/*.gd` and the hook
   lines that `Player Tools/build/hook-game.ps1` inserts (each marked `# [MLMK]`). Grep them for
   `OS.`, `HTTP`, `StreamPeer`, `PacketPeer`, `WebSocket`, `TCPServer`,
   `UDPServer`, `load_resource_pack`, `GDExtension`, `Expression`,
   `str_to_var`, `bytes_to_var`, `call(` / `callv(` with computed names, and
   `FileAccess` / `DirAccess` with paths that aren't `res://` or `user://`.
   None are expected.
5. **Configs:** `lay.cfg`, `boss.cfg` and `mod_settings.cfg` are parsed with
   Godot's `ConfigFile`. Godot's text format can describe objects
   (`Object(...)`, `Resource(...)`), so a config is only safe while it holds
   plain values; the checker flags those constructs in packed `.cfg` files.

## Auditing a mod (.pck)

Never run an untrusted mod to "see what it does". Inspect it statically:

1. You need the user's original, unmodded `Monster Layer.pck` (the checker
   warns if its SHA-256 isn't a known official one).
2. Run `Player Tools/check-mod.bat "<mod .pck>" "<original .pck or game folder>"`
   (set `MLMK_NOPAUSE=1` to skip the final pause). It gets GDRE Tools v2.7.4
   (download checked by SHA-256, or `Player Tools/tools/GDRE_tools/` or the
   kit's `Tools/GDRE_tools/`), unpacks the original once into
   `Player Tools/cache/` and the mod into a temp folder, round-trips changed
   scripts through compile/decompile so formatting doesn't count, and scans
   new or changed lines. It writes `<name>.check.txt` next to the `.pck`.
   Exit codes: 0 `LOOKS SAFE`, 2 `WARNING`, 3 `DANGER`, 1 the check couldn't run.
3. Read the report's "Changed code" list as well as the findings: changed
   scripts are normal for a mod and only become findings when they contain a
   dangerous call. Expected mod changes are game logic and content; anything
   from the list in "Auditing the kit itself", point 4, needs a clear reason.
4. Also check what came *with* the `.pck`: any `.exe` (compare its SHA-256 with
   the user's original `Monster Layer.exe`), `.dll`, `.bat`, `.ps1`, `.vbs`,
   `.lnk`, archives or installers.
5. The checker can't prove a mod is safe (obfuscated or decompiled code can
   hide intent, and a mod made with another kit version shows the kit's
   scripts as changed). Report what you found and what you couldn't verify.

## Auditing a mod source zip

A source zip is meant to be read. List it: it must hold only
`mod_source.json` (format 2), `mod_settings.cfg`, `Custom Lays/<name>/lay.cfg`,
`Custom Bosses/<name>/boss.cfg` and videos, GIFs and pictures in those
folders. Any script, scene, resource, program or archive means it wasn't made
by this kit. Read the configs (plain `key=value`, no `Object(`/`Resource(`)
and check that media files really are media (headers, size). Then
`Player Tools/build-mod.bat "<zip>" "<original>"`
builds it (exit codes: 0 built, 3 refused, 1 failed) and checks the result with
`check-mod.bat`.

## Testing the sandbox launcher

`play-in-sandbox.bat` needs the Windows Sandbox feature; never turn Windows
features on for the user. Set `MLMK_SANDBOX_DRYRUN=1` to only write
`Player Tools/sandbox/Monster Layer.wsb` and `launcher/start.cmd` without
starting it, and check the `.wsb` (networking disabled, read-only game, mod and
launcher folders, only `saves` writable).

## Rules for agents working in this repository

- Never commit or upload the game (`Original Packed/`, any `.pck` / `.exe`),
  `Tools/`, builds or the user's own Lays; `.gitignore` covers them.
- If you run a build of the game for testing, isolate its save: put an
  `override.cfg` in the build with
  `application/config/use_custom_user_dir=true` and
  `application/config/custom_user_dir_name="MLMK_Test"`, delete it and
  `%APPDATA%\MLMK_Test` afterwards, and check that
  `%APPDATA%\Godot\app_userdata\MonsterLayer\savegame.save` didn't change.
  Godot's self-contained mode does not isolate a running project's `user://`.
- Godot 4.3's own Theora looping (`VideoStreamPlayer.loop = true`) crashes or
  freezes on some files; the kit loops videos by hand on `finished`. Keep it so.
- Keep `.bat` / `.ps1` files with CRLF line endings (`.gitattributes`).
- Config files follow a fixed comment format (name, Type, Description,
  Required, Default, the commented default line); keep new fields in it, and
  add new example fields to existing user configs without changing their values.
