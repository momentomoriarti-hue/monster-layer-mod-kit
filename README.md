# Monster Layer Mod Kit

**English** | [Русский](README.ru.md)

Make mods for **Monster Layer** (a Godot 4.3 game): your own opponents (Lays) and bosses from videos, GIFs and pictures, previewed right in the game. The **Mod Kit app** does it all in windows that look like the game; the scripts behind it can also be run by hand, and they can unpack the game into an editable Godot project for deeper mods.

Nothing has to be installed on your PC: everything uses tools built into Windows (cmd, PowerShell, robocopy) plus portable programs kept in the `Tools` folder.

## ⚡ Quick start: your first custom Lay

> The shortest way from nothing to playing your own opponent. Everything else in this README is details: read it later or search the page (Ctrl+F).

1. **Put the game in:** copy `Monster Layer.exe` and `Monster Layer.pck` from your game folder into `Original Packed`.
2. **Start the app:** run `Monster Layer Mod Kit.bat`. The first start sets everything up by itself (downloads the tools, unpacks your game), which takes a few minutes.
3. **Make a mod:** press **Add mod** and type its name. The first time, a tutorial leads you through every step below (you can start it again with the Tutorial button).
4. **Make the Lay:** press **Custom Lays → Add Lay**. Press **Lay config** and pick `genitals` and `chest`. Then choose **Thrust** in the animation list, press **Animation config → Add files...** and pick your video (GIFs and pictures work too). Turn on **Fit to the animation's length**: the whole video is squeezed or stretched to one thrust, **1.0 s** (the hit at 0.2 s), so a 3 s video plays 3× faster. Best results: cut the video to one stroke, with the deepest moment at 1/5 of its length. The video plays on every thrust and is also used for every other animation you don't set.
5. **Look at it:** your Lay stands in the middle of the screen in the game's own round. **Trigger** plays the chosen animation as in the game; **Simulate fight** starts a real fight with it (the gear sets infinite stamina, infinite Pleasure and the stage). Press **Save and exit** (or Ctrl+S).
6. **Play it:** on the mod's screen press **Pack and launch**. The game starts with your mod and a separate test save: your real saves aren't touched.
7. **Share it:** press **Pack** and upload the zip from `Moded Source` (see [Sharing your mod](#sharing-your-mod)). Never upload the `.exe`.

**A boss** (replaces the dragon) works the same way with **Custom Bosses**. To see your Lays or boss right away in the game, open the mod's **Config** and turn on `disable_default_lays` / `disable_default_boss`.

Every field is explained behind its **i** button, in the example configs and in [Custom Lays](#custom-lays), [Custom Bosses](#custom-bosses) and [Mod settings](#mod-settings).

**Mods from older versions of the kit** open in the app as they are: their folders are moved into `Mods` and their configs updated (for example the old `chance` field becomes `base_chance`). Source zips made with older versions load with **Load mod from file**.

## 🖥 The Mod Kit app

`Monster Layer Mod Kit.bat` starts it, in a 16:9 window (1280x720 at first, resize it as you like). It uses the game's own background, fonts and buttons; the game itself is shown in its own portrait screen in the middle, with the app's buttons on both sides.

- **Mods:** every mod in `Mods` as a button; **Add mod**, **Load mod from file** and **Exit**; **Tutorial: make your first mod** (it also starts by itself the first time you press Add mod).
- **Load mod from file:** loads someone else's mod (its source zip or `.pck`) into `Mods`, so you can open, play and change it. Nothing of it is ever run; first Windows Defender scans it, a source zip goes through the same checks as `Player Tools\build-mod.bat` (only configs, videos and pictures, every video and picture really one), and a `.pck` is checked with `check-mod.bat` (DANGER refuses it, WARNING asks you), after which only its custom Lays, bosses and settings are taken out of it with GDRE Tools; anything else in the `.pck` is left behind. See `Mod Kit App\import-mod.ps1`.
- **A mod:** its name (renaming it renames its folder), **Custom Lays**, **Custom Bosses**, and at the top right **Config** (how it is packed and the mod's game settings, `mod_settings.cfg`), **Pack** and **Pack and launch**.
- **Custom Lays / Custom Bosses:** the list, the eye button next to each one (in the mod / switched off, `active`), and **Add** below.
- **A Lay or boss:** on the left **Lay config** / **Boss config** (name, body, chance and the rest), the animation list (idle first; thrust, pound, free cum, egg, lose, orgasm, hypno, and intro for bosses; a Lay without an idle animation shows the first frame of its thrust; last, **Portrait**: the picture in its profile on the Choose your next Lay screen, with `base_species`, whose portrait is used without one), **Animation config** / **Portrait config**, **Trigger**, **Simulate fight** with its settings (gear); **Save and exit** and **Cancel** at the top right; **Hide interface** at the bottom left. **Save and exit** with a required field empty opens the config with that field in red.
- **Trimming:** after you add a video or GIF to an animation the app offers to trim it (and the ✂ button next to it does it later): a player with one slider to scrub through it, play / pause, stop and one frame back / forward; go to a frame and press **Set start here**, then **Set end here** at another, and the window also says how long that animation lasts in the game. **Trim** makes `<name>_trim.mp4` next to it with FFmpeg, cut exactly at those frames with its sound, and puts it in the field in place of the original (which stays in the folder).
- **Sound:** **Music: On / Off** on the first screen and on the Lay / boss screen switches the game's music (remembered); the Lay's moans are off while you edit it.
- **Ctrl+S** saves, **Ctrl+Z** undoes the last change, **Ctrl+Y** redoes it.
- Every field has an **i** button with its full description. The fields and descriptions come from the example configs in `Scripts\templates`, so a field added to the kit later shows up in the app by itself.
- **Pack** makes what the mod's config says (`pack_as`): the open source zip (default), a ready `.pck` (`Moded Packed\Release`) or both. **Pack and launch** also builds the game with the mod and starts it from `Moded Packed` with a separate test save (`%APPDATA%\MonsterLayer Mod Test`). **Cancel** in the packing window stops it and deletes the unfinished build.

**How it works, and why you can trust it.** The app isn't a ready-made program: it is the readable Godot project in `Mod Kit App\app` (GDScript), run with the official Godot 4.3 editor that `setup-tools.bat` downloads (checked by SHA-256). `Mod Kit App\prepare-workspace.ps1` builds its working copy, `Tools\app_workspace`: your unpacked game plus the kit's game code, with the app as the main scene and its own save folder (`%APPDATA%\MonsterLayer Mod Kit App`), so your real saves aren't touched. Previews run in the game's real scenes: a Lay is prepared with `Player Tools\build\apply-mods.ps1`, the same step as packing, and packing runs the same `Scripts\*.bat` you can run by hand. The app only reads and writes inside the kit folder.

## 💬 Contact and help

Stuck on something, found a bug, or need a new feature for your mod? **Write me — talking to you while you make a mod matters a lot, and I check every day:**

- email: **momento.moriarti@gmail.com**
- the Monster Layer thread on F95zone, where the kit is posted;
- a private message on F95zone.

I can explain how a feature works, fix bugs and add features to the kit.

## Roadmap

The kit will keep growing **only if people want to make mods with it**.

- **Planned:** custom opponents, bosses **and protagonists** rendered just like the default ones, so modders can draw separate body parts and other pieces instead of using videos.
- **Possible:** changing perks and mechanics and adding new ones, if that turns out to be possible within the [security limits](#security-limits).

## Folder structure

```
Monster Layer Mod Kit/
├── Original Packed/     the original game (Monster Layer.exe + Monster Layer.pck)
├── Original Unpacked/   the original game unpacked into a Godot project (do not edit)
├── Moded Unpacked/      your working copies: build_<date_time>/ folders, make changes here
├── Moded Packed/        the built modded game (.exe + .pck) for testing, and Release/ to share
├── Mods/                your mods, one folder per mod:
│   └── <mod name>/
│       ├── mod.cfg            the mod's name and how it is packed (not packed into the game)
│       ├── mod_settings.cfg   settings for the whole mod
│       ├── Custom Lays/       custom Lays (opponents), one folder per Lay
│       └── Custom Bosses/     custom bosses that can replace the dragon, one folder per boss
├── Monster Layer Mod Kit.bat  starts the Mod Kit app
├── Mod Kit App/         the app's source (GDScript) and prepare-workspace.ps1
├── Scripts/             the scripts described below
├── Player Tools/        tools for players: check, build and sandbox-play mods (+ README);
│                        build/ holds the code that adds the mod kit features to every build
├── Moded Source/        your mods as source zips (Pack)
└── Tools/               GDRE Tools, Godot 4.3, FFmpeg, and the app's working copy of the game
```

## Under the hood

The app does everything through these scripts and the readable code in `Mod Kit App`; you don't need to run them yourself. They are listed so you can see what runs.

| Script | What it does |
|---|---|
| `Monster Layer Mod Kit.bat` | Starts the app. The first time it runs `setup-tools.bat`, `unpack-original.bat` and `copy-unpacked.bat`, then `Mod Kit App\prepare-workspace.ps1`. |
| `Scripts\setup-tools.bat` | Downloads GDRE Tools, Godot 4.3 and FFmpeg into `Tools` (official releases, checked by SHA-256) and creates `Mods\Example Mod`. Custom Lays, Custom Bosses and `mod_settings.cfg` from older versions of the kit are moved into `Mods\My Mod`. |
| `Scripts\unpack-original.bat` | Unpacks `Original Packed\*.pck` into `Original Unpacked` with GDRE Tools. |
| `Scripts\copy-unpacked.bat` | Copies `Original Unpacked` into `Moded Unpacked\build_<time>`, the copy of the game mods are packed into. |
| `Scripts\pack-moded.bat` | **Pack and launch**, and **Pack** with `pack_as` = pck / both: builds the newest `Moded Unpacked\build_*` with one mod into `Moded Packed` (`.exe` + `.pck`, plus an `override.cfg` that gives that game a separate test save), adding the mod kit's features with `Player Tools\build\apply-mods.ps1`, then runs `make-release.bat`. |
| `Scripts\make-release.bat` | Makes `Moded Packed\Release` with only the files to share: the `.pck`, `SHA256.txt` and `HOW_TO_INSTALL.txt`, never the `.exe`. |
| `Scripts\pack-moded-source.bat` + `pack-source.ps1` | **Pack** (`pack_as` = zip / both): `Moded Source\<mod name> (source).zip` with only `mod_settings.cfg` and the configs and original videos, GIFs and pictures of every active Custom Lay and Custom Boss, plus `mod_source.json`. No scripts. |
| `Player Tools\build\apply-mods.ps1` | Used by packing, by the app's previews and by the players' `build-mod.bat`, so a mod is built by the same code everywhere: copies `build\mod_kit` and the mod's settings, Lays and bosses into the build, converts their videos with FFmpeg and hooks them into the game code with `hook-game.ps1` (the lines marked `# [MLMK]`). |
| `Mod Kit App\import-mod.ps1` | **Load mod from file**, with the checks described above. |
| `Scripts\_common.bat`, `_pick_mod.bat` | Shared paths, and which mod to pack. |

No Godot export templates are needed: the original game `.exe` is used as the template.

### Sharing your mod

If you also share a ready `.pck` (`pack_as` = pck or both), share only `Moded Packed\Release`: `Monster Layer.pck`, `SHA256.txt` and `HOW_TO_INSTALL.txt`. Never share `Monster Layer.exe` from `Moded Packed`, it's there only for testing:

- The `.exe` is the unchanged original game file. Players already have it, and it's copyrighted, so it must not be uploaded.
- A mod that comes with an `.exe` teaches players to run unknown programs. A mod for Monster Layer never needs one, so players can safely refuse any `.exe` that comes with a mod.

`HOW_TO_INSTALL.txt` tells players to back up their own `Monster Layer.pck`, put the mod's `.pck` next to their own `Monster Layer.exe`, and never run an `.exe` that came with a mod. Post the hash from `SHA256.txt` next to your download link, so players can check that the file wasn't changed.

**Sharing the source.** **Pack** in the app makes `Moded Source\<mod name> (source).zip`: only `mod_settings.cfg`, the `lay.cfg` / `boss.cfg` of every active Custom Lay and Custom Boss with the original videos, GIFs and pictures they use, and `mod_source.json` with the original game version it was made for. No scripts and no game files. Players can open every file, scan the whole zip with an antivirus or an online scanner, have an AI agent check it, and build the `.pck` themselves with `Player Tools\build-mod.bat`, which holds all the build code. Changes you made to the game's scripts by hand in `Moded Unpacked` are **not** in the source zip: such a mod can only be shared as a `.pck` (see [Security limits](#security-limits)).

## Safety

A Godot `.pck` is the whole game: all its scripts, scenes and settings. Godot has no sandbox, so a `.pck` can do anything a program can: run other programs, use the internet, delete your files. Mods made with this kit don't need any of that, so:

- **Mod authors:** publish the mod's source zip (**Pack** in the app) and/or only the `.pck` (the contents of `Moded Packed\Release`). Never publish an `.exe`, a `.dll` or an archive with programs inside.
- **Players:** use the [Player Tools](Player%20Tools/), and never run an `.exe` that came with a mod. A mod runs with your own `Monster Layer.exe`.

### Player Tools

[`Player Tools`](Player%20Tools/) is a standalone folder for players: three `.bat` files, the `build\` folder with the build code, and a README (English and Russian). Players don't need the rest of the kit, and the tools never download the game: they always use the player's own copy.

- `check-mod.bat` checks a `.pck` without running it and gives a verdict: `LOOKS SAFE`, `WARNING` or `DANGER`.
- `build-mod.bat` builds the `.pck` from a mod's source zip on top of the player's own game. It accepts only configs, videos and pictures, and refuses anything else before it starts Godot (see [Security limits](#security-limits)). The result is checked with `check-mod.bat`.
- `play-in-sandbox.bat` plays a `.pck` inside Windows Sandbox: no network, the game folder and the mod read-only, saves in a separate folder, everything else wiped on close.

They download GDRE Tools, Godot 4.3 and FFmpeg when needed, from the official releases, checked by SHA-256, or use copies the player puts next to them. See [Player Tools/README.md](Player%20Tools/README.md) for what each one checks and does.

In the kit, **Load mod from file** runs the same checks on other people's mods. To check or sandbox-play your own `.pck`, drag `Moded Packed\Release\Monster Layer.pck` onto `Player Tools\check-mod.bat` or `play-in-sandbox.bat`; inside the kit they use its `Tools\`.

### Security limits

These limits keep players safe. **For now, a mod can contain only configs plus pictures, GIFs and videos.** This also means that some features can't be added to the mod kit yet, so keep these limits in mind when you plan a mod or a new kit feature. If development continues, we will try to find ways to add more features to the mod kit, one by one, without losing the trust of players.

**What a source zip may contain.** `build-mod.bat` accepts only `mod_source.json`, `mod_settings.cfg`, `Custom Lays\<name>\lay.cfg`, `Custom Bosses\<name>\boss.cfg` and videos, GIFs and pictures in those folders. It refuses:

- scripts and code of any kind (`.gd`, `.cs`, `.ps1`, `.bat`...), and scenes and resources (`.tscn`, `.tres`, `.res`), which can hide scripts inside;
- `@tool` scripts, editor plugins and export or import plugins: the Godot editor runs them by itself when it opens or exports a project, so they would run on the player's PC during the build;
- `project.godot` and `override.cfg`, which can turn on plugins and autoloads;
- programs, libraries and archives (`.exe`, `.dll`, `.so`, `.zip`, `.pck`...);
- paths leaving the folder (`..`, absolute paths, drives);
- objects in configs (`Object(...)`, `Resource(...)`): a config holds only text, numbers, true/false and lists.

**What this means for modders and kit features:**

- Everything a mod changes has to be **data** (config fields and media files) read by the kit's own code in `Player Tools\build\mod_kit\`. A new feature is a new config field plus code in the kit, which every player gets with the Player Tools and can read.
- A mod can't bring its own scripts, scenes, shaders, plugins or native libraries in a source zip. Hand-edited game code (in `Moded Unpacked`) can only be shared as a `.pck`, which players have to trust or check with `check-mod.bat`.
- The kit's own code must stay checkable: no `@tool` scripts or editor plugins, no network (`HTTPRequest`, sockets), no running programs (`OS.execute`, `OS.shell_open`), no loading code or packs at run time (`load_resource_pack`, `GDExtension`, `Expression`, `str_to_var`), no file access outside `res://` and the game's own save folder. Such calls would make `check-mod.bat` report **DANGER** or **WARNING** on every mod.
- New media types can be added only as file extensions that FFmpeg or Godot read as media.

## Mod settings

`mod_settings.cfg` in the mod's folder (`Mods\<mod name>\`) holds settings for the whole mod; in the app it is **Config** on the mod's screen. A new mod gets it from `Scripts\templates\mod_settings.cfg`. Edit it, then run `pack-moded.bat`: the values are packed into the game.

| Setting | Default | What it does |
|---|---|---|
| `disable_anim_acceleration_with_pleasure` | `false` | `true` = the round doesn't speed up as Pleasure rises. |
| `anim_acceleration_steps` | `1` | How many sped-up copies auto-fitted videos get, to follow the speed-up. |
| `downgrade_all_animations_fps_to` | `60` | Highest frame rate of every converted video, 1-240. |
| `disable_default_lays` | `false` | `true` = only custom Lays appear (no normal Lays, no rare characters, a custom Lay in the tutorial). |
| `disable_default_boss` | `false` | `true` = a custom boss always replaces the dragon. |

**`disable_anim_acceleration_with_pleasure`.** In the original game everything in the round gets faster as Pleasure rises, up to 1.5× at full Pleasure: the models' animation, the time between strokes and hits, egg laying, and sound delays. Plaps also get up to 4 dB louder. All of that comes from one value (`animspeed` in `Anim.gd`). This setting keeps it at 1, so everything stays in sync and nothing breaks: a thrust always takes 1.0 s with the hit at 0.2 s, and a pound stroke always takes 0.5 s. The Lay's face still switches to its "high" expressions past 50% Pleasure. Custom Lay videos then always match the game's timings, and the orgasm lasts 4.5 s instead of 3.0 s (auto-fit takes this into account).

It does change the balance: late in a round you hit up to 1.5× less often, so rounds take longer and hearts have more time to hurt you.

**`anim_acceleration_steps`.** A video can't change its speed while it plays, but the game speeds up smoothly from ×1 at 0% Pleasure to ×1.5 at 100%. With `anim_acceleration_steps` above 1, `pack-moded.bat` converts every video that has `auto_fit_<kind>_anim_length=true` (thrust, pound, idle, free cum, egg, lose) that many times, each copy a bit faster, and the game plays the copy for the current Pleasure. Copy k (counting from 0) is used from k/steps to (k+1)/steps of Pleasure and plays at ×(1 + 0.5 × k / steps) of the fitted speed, which is the game's own speed at the start of that range. For example, with 4 steps:

| Pleasure | 0-25% | 25-50% | 50-75% | 75-100% |
|---|---|---|---|---|
| Speed | ×1 | ×1.125 | ×1.25 | ×1.375 |

A looping video switches to another copy only when it finishes a loop, never in the middle. One-shot videos pick their copy when they start. The setting is ignored with `disable_anim_acceleration_with_pleasure=true`, and it doesn't apply to videos without auto-fit, pictures, the orgasm (always at full Pleasure) or hypno.

> **Warning:** every step is a full extra copy of each of those videos inside the packed game, so 10 steps make them take about 10 times more space, and packing takes that much longer. There is no upper limit; 3-5 steps are usually enough.

**`disable_default_lays` and `disable_default_boss`.** With `disable_default_lays=true` the first Lay of a run and all 3 Lays you choose from are always custom Lays, and the rare characters Xerxes and Zephyr don't appear; the tutorial uses a custom Lay instead of its kobold too. With `disable_default_boss=true` a custom boss always replaces the dragon (Ero isn't affected). Custom ones share the slots by their `chance` and body sliders; if all their body sliders are at 0, the sliders are ignored so there is still a Lay or boss to pick. `pack-moded.bat` stops with an error if a setting is `true` and there are no active custom Lays or bosses (ones with `active=false` don't count).

**`downgrade_all_animations_fps_to`.** A converted video keeps its source frames, so its frame rate is the source frame rate times its speed: a 30 fps video at ×4 would be 120 fps. Any video that would come out above this value, including the sped-up copies, has frames dropped evenly down to it. Lower values make smaller files and smoother playback on weak PCs, at the cost of less smooth motion; 60 matches most monitors. Pictures aren't affected.

## Custom Lays

A Lay is your opponent. Each folder in the mod's `Custom Lays` (`Mods\<mod name>\Custom Lays`) with a `lay.cfg` is one custom Lay. `active=false` in `lay.cfg` switches a Lay off: it isn't packed and never appears. The example `Simplified_Anims_Custom_Lay_Example` is switched off this way. It is a Lay with simplified animations: videos or pictures replace the models in the round.

```
Custom Lays/
├── Simplified_Anims_Custom_Lay_Example/   example, active=false
│   └── lay.cfg
└── Mira/           a custom Lay, the folder name is its id
    ├── lay.cfg
    ├── sex.mp4     sex animation (optional): video, GIF or picture
    └── portrait.png  profile picture on the Lay choice screen (optional)
```

To add a Lay, press **Add Lay** in the app. You don't need to run `copy-unpacked.bat` again, because Custom Lays are added at pack time.

`lay.cfg`:

```ini
[lay]
name="Mira"            ; shown in the game, optional (folder name by default)
genitals="pussy"       ; "pussy" or "dick"
chest="boobs"          ; "boobs" (female) or "flat" (male)
;base_chance=""        ; empty = as likely as one species, or a percent of that
;chance_per_defeated=0 ; optional: added for every Lay defeated in the run
;max_chance=""         ; optional: the highest chance it can reach
;min_defeated=0        ; optional: in the pool only after this many defeated Lays
;max_defeated=""       ; optional: leaves the pool after this many defeated Lays
;boob_size="large"     ; optional: tiny, small, average, large, huge or a number 0.8-1.2
;dick_size="hefty"     ; optional: mini, little, average, hefty, massive or a number 0.8-1.5
;pronoun="(she/they)"  ; optional, by default (she/her) for boobs, (he/him) for flat
;base_species="kobold" ; optional, see below
;traits="pound+"       ; optional, 0-3 fixed traits, see "Traits" below
;portrait="portrait.png"       ; optional, picture in the profile on the Lay choice screen
;mute_native_plap_sound=false  ; true = no game plap sounds for this Lay
;mute_native_moan=false        ; true = no game moans for this Lay

; Sex animation, optional (see "Sex animation" below)
thrust_anim="sex.mp4"             ; file in this folder for thrust (click)
thrust_anim_speed_modifier=1.0    ; video speed, 0.01-10
auto_fit_thrust_anim_length=false ; true = fit the whole video into one thrust (1.0 s)
thrust_anim_reset_on_pause=false  ; true = rewind to the start after every thrust
pound_anim="sex.mp4"              ; file for pound (hold), thrust_anim if not set
pound_anim_speed_modifier=1.5
auto_fit_pound_anim_length=false  ; true = fit the whole video into one pound stroke (0.5 s)
;idle_anim="idle.mp4"            ; optional, other animations: see "Other animations" below
pound_anim_reset_on_pause=false   ; true = rewind to the start when pounding stops
```

### How the spawn chance works

The game picks a normal Lay's species evenly, 1 of 9, and then its body with the run start sliders. A custom Lay is simply one more species in this roll, with the weight

```
weight = chance / 100      (0 when the slider for its chest + genitals is at 0)
```

Every generated Lay (the first Lay of a run, and each of the 3 Lays you choose from after a win, separately) is a given custom Lay with probability weight / (9 + sum of the weights of all custom Lays); otherwise a normal Lay is generated as usual.

- With `base_chance` empty (the default, same as 100) a custom Lay is exactly as likely as any one species: with 9 species and N custom Lays, each of them gets 1 / (9 + N) of the slots. The app shows this number for your mod. `base_chance=200` makes it twice as likely, `50` half, `0` never. (Older versions of the kit called it `chance`; `chance=` still works.)
- If the slider for its body (chest + genitals) is at 0, it never appears.
- Normal Lays always stay possible. The more custom Lays there are, the rarer every species and every custom Lay gets, the same as adding species to the game.

The tutorial, bosses and the rare characters (rolled apart) are not affected.

**The chance during a run.** `chance` above is the chance in use for this roll:

```
chance = base_chance + chance_per_defeated × Lays defeated in this run   (between 0 and max_chance)
```

It is added, not multiplied. The Nth Lay of a run is rolled with N-1 defeated Lays, and endless mode keeps counting (10 Lays per loop; bosses don't count). With `min_defeated` and `max_defeated` the Lay is in the pool only while the defeated count is in that range, so it can appear only later in a run, or disappear. Example: `base_chance=0`, `chance_per_defeated=20`, `max_chance=200`, `min_defeated=3` — never among the first 3 Lays, then 60, 80, 100... up to 200.

### Sex animation

If `thrust_anim` or `pound_anim` is set, the rendered models of the protagonist and the Lay are hidden during the round, and the file is shown in their place. The background and the UI stay.

- **Videos and GIFs:** mp4, webm, mov, mkv, avi, wmv, flv, mpg, gif or ogv. Godot 4.3 can only play Ogg Theora, so `pack-moded.bat` converts them with FFmpeg (from `Tools\FFmpeg`). The speed modifier is applied during conversion, because Godot can't change video speed while playing. The video's sound is kept (sped up or slowed down with the video, without changing its pitch) and plays at the game's SFX volume. The frame rate stays as in the source (after the speed modifier), capped by `downgrade_all_animations_fps_to` in [Mod settings](#mod-settings) (60 fps by default). The size is capped at 720×1030. Converted files are cached in `Tools\media_cache`, so the next pack is faster. GIF transparency is lost, and transparent areas turn black.
- **Pictures:** png, jpg, jpeg, webp, bmp or tga. On every stroke the picture moves up and gets bigger, as if it moves closer, then goes back. A thrust zooms it in by 10%, and each pound stroke by 5% (pound is shallower). The motion follows the game's own stroke timing. The speed modifier and reset settings don't apply to pictures.
- Thrust and pound can use the same file or different files. When they use the same video, each one keeps its own position in it.
- **Several files.** Every `*_anim` field can list several files, comma-separated (`thrust_anim="sex1.mp4, sex2.mp4"`) or as an array (`thrust_anim=["sex1.mp4", "sex2.webm", "still.png"]`). One is picked at random every time the animation starts: each thrust (with `reset_on_pause`; otherwise when the video finishes), each loop of pound and idle, each free cum, egg laying, lose and orgasm, and each stroke for a picture. The speed modifier and auto-fit apply to each file separately.
- Looping videos are restarted by the mod when they finish, not by Godot's own looping: in Godot 4.3 that crashes the game or freezes the video on some files.
- **Auto-fit length.** With `auto_fit_thrust_anim_length=true`, the video is sped up or slowed down at pack time so that it lasts exactly one thrust, 1.0 s. With `auto_fit_pound_anim_length=true`, it lasts exactly one pound stroke, 0.5 s, and loops while you hold the button. The matching `*_anim_speed_modifier` is then ignored. This works best for a video of exactly one stroke, cut so that the deepest moment is at 1/5 of its length: the game counts the hit 0.2 s into both a thrust and each pound stroke. A long video is squeezed a lot: for example, 20 s becomes 1 s at ×20 speed. The lengths are for Pleasure 0. As Pleasure rises the game's strokes get up to 1.5× faster, but a video keeps its converted speed.

**Size on screen.** The player is centered in the area between the Pleasure bar and the Stamina bar. It always keeps the aspect ratio:

- it is scaled down to fit within 720×1030 (for pictures, 654×936, so the 10% zoom stays on screen);
- a small video or picture is scaled up until it reaches 540 wide or 770 tall;
- anything in between is shown at its own size.

**When the video plays.** It doesn't follow the mouse. It follows the moment the game itself counts you as fucking, which is what hearts check for extra stamina loss:

| What you do | What the game does | What the video does |
|---|---|---|
| Click (release within 0.2 s) | Thrust starts on release, lasts 1 s | Thrust video plays for 1 s, then pauses or rewinds |
| Hold the button | Pound starts 0.2 s after the press | Pound video starts 0.2 s after the press |
| Release after pounding | The current stroke and the exit stroke finish, 0.45-0.95 s | Keeps playing until the game goes back to idle |

All game timings get shorter as Pleasure rises (up to 1.5× faster). Picture strokes follow this, but videos keep their converted speed.

### Other animations

Besides thrust and pound, a Lay can have a file for every other moment of the round. All of them are optional, and each uses the same fields: `<kind>_anim`, `<kind>_anim_speed_modifier` and `auto_fit_<kind>_anim_length` (except hypno). A missing one falls back as shown, and finally to `thrust_anim`, so the default sex animation keeps playing. Pictures here are shown still, without bobbing.

| Field | When | Plays | Game length (auto-fit) | Falls back to |
|---|---|---|---|---|
| `thrust_anim` | a click, one deep stroke | from where it paused, or from the start with `reset_on_pause`; fitted videos always play to their end | 1.0 s, hit at 0.2 s | `pound_anim` |
| `pound_anim` | holding the button | loops | 0.5 s per stroke, hit at 0.2 s | `thrust_anim` |
| `idle_anim` | not fucking, between strokes | loops | none: plays at the video's own speed | first frame of the thrust/pound video |
| `free_cum_anim` | free cum perks turn a thrust into a cum shot | once, from the start | 2.0 s, cum at 0.7 s | `thrust_anim` |
| `egg_anim` | free cum when you play as Sylvia (1-3 eggs) | once, from the start | 2.0 s, eggs at 1.4 s / 1.3 + 1.6 s / 1.3 + 1.6 + 1.8 s | `free_cum_anim` |
| `lose_anim` | you run out of stamina and cum (game over) | once, from the start | 2.0 s, game over screen after 1.0 s | `egg_anim` (Sylvia), `free_cum_anim` |
| `orgasm_anim` | the Lay cums at full Pleasure, end of the round | once, from the start | 3.0 s until the screen starts fading to white (fully white at 4.0 s), Lay cum sound at 1.0 s | `thrust_anim` |
| `hypno_anim` | a Hypno trance perk is active | loops, **on top** of the others, fades in/out in 0.3 s | no fixed length | nothing shown |

Lengths are at 0 Pleasure; the game gets up to 1.5× faster as Pleasure rises, but videos keep their converted speed (see [Mod settings](#mod-settings) to turn the speed-up off). The orgasm always happens at full Pleasure, and its 3.0 s already include that (4.5 s with the speed-up off). `hypno_anim` works best as a png with transparency, because videos can't be transparent.

Other animations in the game that can't be replaced:

- **Pound entry and exit** (PoundEntry, PoundExit, 0.5 s each) are blended into the first and last pound strokes. They are covered by `pound_anim`.
- **Idle twitches** (IdleTwitch1-3) are variations of the idle loop. They are covered by `idle_anim`.
- **Facial expressions** (ExpressionAnim) change every 4 s on the models. They have no meaning without the models.
- **Squirting** (when the Lay has a pussy and high Pleasure) and the **cum sprite** are effects on the models, so they are hidden together with them.
- **Impregnation graphic, round transition (whiteout), game over screen** are part of the UI, not the scene, so they are still shown on top.

### Traits

`traits` gives a Lay 0-3 fixed traits, written like the game's own ids: a trait name with `+` (the Lay likes it) or `-` (doesn't), comma-separated or as an array: `traits="pound+, thrust-"`. The names are `thrust`, `pound`, `arousal`, `cum`, `lucky`, `heart`, `intimate`, `feral`, `hypno` and `sticky`; `Simplified_Anims_Custom_Lay_Example\lay.cfg` lists the profile text of each one (for example `pound+` is "I like getting fucked fast <3").

- The game still rolls how many traits a Lay has (1-3, more in later fights). The fixed traits fill the first slots, and any slots left get random traits that never repeat or contradict them.
- The first Lay of a run has no traits in the game, so it gets only the fixed ones.
- `intimate` (Jon, Ferro, Sylvia), `feral` (Barks, Oro), `hypno` (Drip) and `sticky` (Sylvia) exist only for some player characters. With another character such a trait is left out, like the game does.
- The same trait twice, a trait with its opposite (`pound+` and `pound-`), an unknown id or more than 3 traits make `pack-moded.bat` stop with an error that names the Lay.

### Boob and dick size

`boob_size` and `dick_size` set the size shown in the Lay's profile ("-Large tits", "-Hefty cock") and the size of the species' sprites when no sex animation is set. Use a word or the game's own number:

| boob_size | number | dick_size | number |
|---|---|---|---|
| tiny | 0.84 | mini | 0.87 |
| small | 0.92 | little | 1.01 |
| average | 1.0 | average | 1.15 |
| large | 1.08 | hefty | 1.29 |
| huge | 1.16 | massive | 1.43 |

Numbers are limited to 0.8-1.2 for boobs and 0.8-1.5 for dicks, the range the game's profile text uses. If a size isn't set, or is written wrong (`pack-moded.bat` doesn't check it, the game prints a warning), it is rolled like for normal Lays (boobs 0.9-1.2, dick 0.8-1.5), anew every time the Lay appears in the choice pool. The size only matters with the matching chest and genitals: `boob_size` for `chest="boobs"`, `dick_size` for `genitals="dick"`.

### Portrait and sounds

- `portrait` is the picture in the Lay's profile on the "Choose your next Lay" screen, instead of the species portrait. The frame is square (250×250 on screen): a square picture, for example 400×400 like the game's own, fits fully, and other shapes are scaled to fill the frame and cropped.
- `mute_native_plap_sound=true` turns off the game's plap sounds (on every thrust and pound hit, and on cum) while you fight this Lay.
- `mute_native_moan=true` turns off the game's moans of this Lay.

Use them when the sex video has its own sound. Other game sounds (hearts, cum, music) stay.

**Still from the normal species:** attacks and voice come from `base_species` (kobold, ratfolk, gnoll, kenku, hellhound, foxspirit, sahuagin, snakekin or cattails), or, if it isn't set, from a species picked once from the Lay's folder name. Without `thrust_anim`/`pound_anim`, the species' models are shown in the round as before. The custom Lay's name, chest, genitals and pronouns are used everywhere.

**One custom Lay always looks the same.** Its species, skin and eye color, voice pitch and bio are rolled from its folder name, so they never change between runs or slots. Its traits, heart damage and any size not set in `lay.cfg` are rolled anew each time it appears, like for normal Lays. Renaming the folder gives the Lay a new look.

## Custom Bosses

`Custom Bosses` works like `Custom Lays`, for the end boss of a run: the dragon, fought after the 10th won fight. Each folder with a `boss.cfg` is one custom boss that can appear instead of the dragon; `active=false` switches one off, as for Lays (the example boss is switched off). Copy `Simplified_Anims_Custom_Boss_Example`, rename the copy and edit `boss.cfg`; every field is described in it.

- **The fight is the dragon's.** It has the same attacks, the special hearts (guard, shield, speed), 3 rounds with stamina recovery between them, and the same game over screen. The boss's name, chest, genitals, sizes, sounds and animations come from `boss.cfg`. The animation fields are the same as for Lays. `orgasm_anim` plays at the end of each round.
- **Intro.** Before the fight the white intro screen says "To lay <name>" instead of "To lay the dragon", and `intro_anim` (a video or picture) is shown under the text until the screen fades out at 7-8 s.
- **Chance.** A custom boss has the weight `chance / 100` against the dragon's 1 (0 when the slider for its body is at 0). With `base_chance` empty (the default, same as 100) each of N custom bosses and the dragon are equally likely, 1 / (1 + N). `chance_per_defeated`, `max_chance`, `min_defeated` and `max_defeated` work as for Lays, but count only **bosses** defeated in the run: 0 for the first end boss, +1 for every loop of endless mode. For example `min_defeated=1` makes a boss appear only from the second loop on.
- **No traits.** The game's bosses have no traits, hidden or not, so `boss.cfg` has no `traits` field. It also has no portrait or pronouns: a boss has no profile screen.
- **Ero.** The optional post-game boss Ero (with its dialogue and credits) isn't replaced.

## Downloading the tools manually

If you don't want `setup-tools.bat` to download anything, you can get the tools yourself. Keep the folder and file names exactly as shown here so the scripts can find them.

Before extracting, check that each file is the genuine one: its SHA-256 hash must match the one listed below (`setup-tools.bat` checks this automatically). In PowerShell, in the folder with the file, run this (change the file name and the hash for each file); it must print `True`:

```powershell
(Get-FileHash .\GDRE_tools-v2.7.4-windows.zip -Algorithm SHA256).Hash -eq 'af24c563eee501effb194d83595de64696c32547b2246034dbfb891a24bfa0ad'
```

**GDRE Tools v2.7.4** (Godot RE Tools)

- Download `GDRE_tools-v2.7.4-windows.zip` from <https://github.com/GDRETools/gdsdecomp/releases/tag/v2.7.4>.
- SHA-256: `af24c563eee501effb194d83595de64696c32547b2246034dbfb891a24bfa0ad`
- Extract it so that you have `Tools\GDRE_tools\gdre_tools.exe`.

**Godot 4.3 stable** (the standard version, not .NET)

- Download `Godot_v4.3-stable_win64.exe.zip` from <https://github.com/godotengine/godot/releases/tag/4.3-stable> or <https://godotengine.org/download/archive/4.3-stable/>.
- SHA-256: `8f2c75b734bd956027ae3ca92c41f78b5d5a255dacc0f20e4e3c523c545ad410`
- Extract it so that you have:
  - `Tools\Godot\Godot_v4.3-stable_win64.exe`
  - `Tools\Godot\Godot_v4.3-stable_win64_console.exe`
- Optional: create an empty file `Tools\Godot\._sc_`. This keeps Godot's settings inside that folder instead of in AppData.

Use exactly Godot **4.3**, the version the game was made with. Other versions may break the project or the build.

**FFmpeg 9.0.2** (only needed for the videos and GIFs of Custom Lays and Custom Bosses)

- Download `ffmpeg-9.0.2-full_build-shared.zip` from <https://github.com/GyanD/codexffmpeg/releases/tag/9.0.2>. Use the **full** build: the "essentials" build can't encode Ogg Theora.
- SHA-256: `8d31e162f1616e37aab3fa2db991b97e1b8dbeb1c8465fd81a81be16ff91b328`
- From its `bin` folder, copy `ffmpeg.exe` and all `.dll` files so that you have `Tools\FFmpeg\ffmpeg.exe`.

## Notes

- `pack-moded.bat` prints many warnings like `invalid UID ... using text path`. They come from the unpacking step and are harmless: the resources are still found by their path.
- The full unpacking report is saved to `Original Unpacked\gdre_export.log`.
