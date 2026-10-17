# Monster Layer Player Tools

**English** · [Русский](#русский)

Tools for players who want to try a Monster Layer mod made by someone else, safely. They work on Windows 10 and 11.

| File | What it does |
|---|---|
| `check-mod.bat` | Checks a mod's `.pck` for dangerous code **without running it**. |
| `build-mod.bat` | Builds a mod's `.pck` yourself from its **source zip**, so you know what's inside. |
| `play-in-sandbox.bat` | Plays a mod inside **Windows Sandbox**: no internet, your files out of its reach. |
| `build\` | The code `build-mod.bat` uses to build a mod. Readable PowerShell and GDScript files. |

**Why this matters.** A mod is a `.pck` file, and a `.pck` is not just pictures: it holds the whole game's code. Godot games have no sandbox, so a `.pck` can do anything a program can: run programs, use the internet, delete files. These tools let you see what a mod does, build it yourself, or keep it away from your PC.

**The game is never downloaded by these tools.** You always use your own copy of Monster Layer; the tools only ask where it is. A mod never needs its own `.exe`: never run an `.exe`, `.dll`, `.bat` or installer that came with a mod.

**Getting the tools.** Download the whole `Player Tools` folder, `build\` included: on the GitHub page of the Monster Layer Mod Kit press **Code → Download ZIP** (or take the Player Tools zip from Releases) and keep only the `Player Tools` folder, for example as `C:\Monster Layer Player Tools\`. `check-mod.bat` and `play-in-sandbox.bat` also work alone; `build-mod.bat` needs `build\` next to it. Drag files onto the `.bat` files, or run them from a command line.

## The safe path

If you trust the author of these tools and follow this README, you are **most likely** fine. The safest way to play someone else's mod is:

1. **Get the mod as a source zip** (`... (source).zip`, made with the Monster Layer Mod Kit). It holds **only** the mod's configs (`lay.cfg`, `boss.cfg`, `mod_settings.cfg`, plain text), its original videos, GIFs and pictures, and `mod_source.json`. No scripts, no programs, no game files.
2. **Check the zip.** Open it and look at the files; scan the whole zip with your antivirus or an online scanner (for example [VirusTotal](https://www.virustotal.com/)); if you like, ask an AI agent to read the configs.
3. **Build the `.pck` yourself** with `build-mod.bat`. It refuses everything in the zip that isn't a config, video or picture, and builds the mod with **the code in `build\`** (which you can read), the **official Godot 4.3** (downloaded from the Godot GitHub release and checked by its SHA-256) and **your own game**.
4. **Run your own, official `Monster Layer.exe`** with the `.pck` you built.

Why this is safe: the only things that come from the mod author are text configs and media files, and the build never runs anything from the zip. Every program that runs is official (Godot, GDRE Tools, FFmpeg, your game) or readable (`build\`). The remaining risk is small: a media file crafted to attack a bug in FFmpeg or Godot's image loader. The antivirus scan in step 2 and Windows Sandbox (below) cover it.

**If the mod comes only as a ready `.pck`,** you can't see its code as easily: check it with `check-mod.bat`, read the report, and prefer playing it in Windows Sandbox. Ask the author for a source zip.

**Being careful with other people's mods:**

- Download mods only from the place the author posted them (their f95zone thread, their page), not from re-uploads.
- Never run an `.exe`, `.bat`, `.dll`, `.ps1` or installer that came with a mod. A mod is a `.pck` or a source zip, nothing else. Use the `.bat` files from this folder, downloaded from the Mod Kit's own page.
- Don't skip a **DANGER** or **REFUSED**. A **WARNING** means "read the report first".
- Keep a backup of your original `Monster Layer.pck` and of your saves (`%APPDATA%\Godot\app_userdata\MonsterLayer`).
- A mod made with the Mod Kit can't contain hand-written game code in its source zip. If an author says "my mod needs a `.pck`, a source zip isn't enough", it means they changed the game's code by hand: be extra careful, use `check-mod.bat` and Windows Sandbox.

## check-mod.bat — check a .pck

Drag the mod's `.pck` onto `check-mod.bat`. The first time it offers to download GDRE Tools (see below) and asks for your **original** game: drag your original `Monster Layer.pck` (or the game folder) into the window and press Enter. It is remembered. If you already put a mod into the game folder, use a backup of the original `.pck`.

| Verdict | Meaning |
|---|---|
| **LOOKS SAFE** | No dangerous calls or files were found. |
| **WARNING** | Something couldn't be checked or looks unusual. Play it only if someone you trust has read the report. |
| **DANGER** | The mod does something a game mod never needs. **Don't run it.** |

The full report is saved next to the mod as `<mod name>.check.txt`. Command line: `check-mod.bat "mod.pck" "C:\Games\Monster Layer\Monster Layer.pck"`.

What it checks:

- It unpacks the mod and your original game with GDRE Tools into temporary folders. **Nothing of the mod is run.**
- It compares every script with your original game; scripts are compiled and decompiled again on both sides, so comments and formatting don't count as changes.
- In every new or changed line it looks for: running or stopping programs and opening links or files outside the game (`OS.execute`, `OS.shell_open`...); internet and network (`HTTPRequest`, TCP, UDP, WebSocket...); loading code or other packs at run time (`load_resource_pack`, `GDExtension`, `Expression`...); creating objects from data (`str_to_var`...); deleting, renaming or copying files and writing files outside the game and its save folder; paths to drives and network shares; and, as a warning, reading system folders or the environment and calling functions by a name made at run time.
- It flags programs, libraries and archives inside the `.pck`, scripts hidden inside scenes, objects inside config files and files pointing outside the game; checks that an `.exe` next to the mod is the original game `.exe`; and warns if your "original" game isn't a known official version.

It **can't prove** that a mod is safe: clever code can hide what it does. Changed scripts are normal for a mod and are listed in the report so a person can read them.

## build-mod.bat — build a mod from its source zip

Drag the source zip onto `build-mod.bat`. The first time it asks for your original game (like `check-mod.bat`) and offers to download GDRE Tools, Godot 4.3 and FFmpeg (see below).

What it does:

1. Reads the zip and **refuses it** (**REFUSED**, nothing is built) if it has anything but the allowed files (see [Security limits](#security-limits)).
2. Unpacks your original game with GDRE Tools (kept in `cache\`).
3. Adds the mod with `build\apply-mods.ps1`: checks the configs, converts the videos and GIFs with FFmpeg (converted files are kept in `cache\media\`), adds the Mod Kit's game code from `build\mod_kit\` and hooks it into the game with `build\hook-game.ps1`. This is the same code the Mod Kit uses, so you get the same `.pck` as the author.
4. Packs the `.pck` with Godot 4.3, using your own `Monster Layer.exe` as the export template.
5. Saves it as `<zip name> - built\Monster Layer.pck` next to the zip, and checks it with `check-mod.bat`.

Warns if the mod was made for another version of the game. Command line: `build-mod.bat "mod (source).zip" "C:\Games\Monster Layer\Monster Layer.pck"`.

### Security limits

**For now, for security, a mod can contain only configs plus pictures, GIFs and videos.** If development continues, we will try to find ways to add more features to the mod kit, one by one, without losing your trust.

`build-mod.bat` accepts only these files in a source zip:

| File | What it is |
|---|---|
| `mod_source.json` | Which game version the mod was made for (format 2). |
| `mod_settings.cfg` | Settings of the whole mod. |
| `Custom Lays\<name>\lay.cfg`, `Custom Bosses\<name>\boss.cfg` | Configs of each custom Lay and boss. |
| videos, GIFs and pictures in those folders | `.mp4 .m4v .webm .mov .mkv .avi .wmv .flv .mpg .mpeg .ogv .gif .png .jpg .jpeg .webp .bmp .tga` |

Everything else is refused, and in particular:

- **any script or code**: `.gd`, `.cs`, `.ps1`, `.bat`, scenes and resources (`.tscn`, `.tres`, `.res`) — scenes can hide scripts inside them;
- **`@tool` scripts and editor or export plugins** — Godot runs them on its own while it opens and builds a project, so they would run on your PC during the build;
- **`project.godot` and `override.cfg`** — they can turn on plugins and autoload scripts;
- **programs, libraries and archives**: `.exe`, `.dll`, `.so`, `.zip`, `.pck`...;
- **paths that leave the folder** (`..`, absolute paths, drives);
- **objects inside configs** (`Object(...)`, `Resource(...)`): Godot's config format can describe objects with scripts, a mod's config needs only text, numbers, true/false and lists.

## play-in-sandbox.bat — play inside Windows Sandbox

Drag the mod's `.pck` onto `play-in-sandbox.bat`; the first time it asks for your game folder (or `Monster Layer.exe`). It starts Windows Sandbox, a throw-away Windows inside your Windows, and runs the game with the mod in it:

- **no network** inside the sandbox;
- your game folder and the mod are shared **read-only**; nothing else of your PC is visible to the game;
- clipboard, printer, microphone and camera are off;
- the game's saves go to `sandbox\saves\` next to the `.bat` — separate from your real saves; it's the only folder the mod can write to;
- everything else is deleted when you close the sandbox window.

### Turning Windows Sandbox on

The script never changes Windows settings itself. Windows Sandbox exists on Windows 10 (1903 and newer) and 11 **Pro, Enterprise and Education**, not on Home.

1. Check that virtualization is on: Task Manager → Performance → CPU shows "Virtualization: Enabled". If not, turn it on in the BIOS/UEFI (called Intel VT-x, Intel Virtualization Technology, AMD-V or SVM).
2. Press Win+R, type `optionalfeatures`, press Enter.
3. Tick **Windows Sandbox**, press OK (administrator rights needed) and restart the PC.

Or in PowerShell run as administrator: `Enable-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM`, then restart. To turn it off later, untick it the same way.

### What it costs

- **Lower FPS.** The game gets a virtual graphics card that runs on your real GPU, but slower than normal. It only supports Direct3D 12 (no Vulkan or OpenGL), so `play-in-sandbox.bat` starts the game with Godot's Direct3D 12 driver and the Forward+ renderer: the game's own Mobile renderer hangs there on a black screen. The picture can differ slightly from normal play. Monster Layer is a light 2D game, so it stays playable.
- **The first start is slow:** the game compiles its shaders, which can take a minute with a black window. They are kept in `sandbox\saves\shader_cache\`, so later starts are faster.
- **Startup takes longer:** about 10–30 seconds for the sandbox to start, then the game is copied into it.
- **Memory:** the sandbox takes up to 4 GB of RAM while it runs.
- **One sandbox at a time,** and every start is a fresh Windows: settings made inside it are lost, only the saves in `sandbox\saves\` stay.
- While Windows Sandbox is turned on, some other virtualization programs (old VirtualBox or VMware versions) can run slower. Turning it off removes this.

**On Windows Home** there is no Windows Sandbox. Alternatives: [Sandboxie-Plus](https://sandboxie-plus.com/) (free, isolates programs, but less strict than a separate Windows), or a virtual machine (VirtualBox, VMware; strict, but you have to set it up). Otherwise, follow [the safe path](#the-safe-path) with source zips, and check `.pck` files with `check-mod.bat`.

## The tools they download

The scripts use three free, open-source programs. When one is missing, the script tells you why it's needed and asks before downloading it from the official GitHub release; the file's SHA-256 is checked before it is used, so a changed download is refused. Nothing is installed into Windows.

| Tool | Needed by | Why |
|---|---|---|
| GDRE Tools 2.7.4 | `check-mod.bat`, `build-mod.bat` | Unpacks `.pck` files (the mod and your original game). |
| Godot 4.3 | `build-mod.bat` | The official Godot editor, the version the game is made with; packs the `.pck`. |
| FFmpeg 9.0.2 | `build-mod.bat` | Converts the mod's videos and GIFs to the format the game plays (Ogg Theora). |

### Downloading the tools yourself

**GDRE Tools 2.7.4:** download `GDRE_tools-v2.7.4-windows.zip` from <https://github.com/GDRETools/gdsdecomp/releases/tag/v2.7.4>.
SHA-256: `AF24C563EEE501EFFB194D83595DE64696C32547B2246034DBFB891A24BFA0AD`

**Godot 4.3 (standard, not .NET):** download `Godot_v4.3-stable_win64.exe.zip` from <https://github.com/godotengine/godot/releases/tag/4.3-stable>.
SHA-256: `8F2C75B734BD956027AE3CA92C41F78B5D5A255DACC0F20E4E3C523C545AD410`

**FFmpeg 9.0.2 (full, shared):** download `ffmpeg-9.0.2-full_build-shared.zip` from <https://github.com/GyanD/codexffmpeg/releases/tag/9.0.2> (the Windows builds linked from ffmpeg.org).
SHA-256: `8D31E162F1616E37AAB3FA2DB991B97E1B8DBEB1C8465FD81A81BE16FF91B328`
From its `bin\` folder copy `ffmpeg.exe` and all the `.dll` files (`ffplay.exe` and `ffprobe.exe` aren't needed).

Check a download in PowerShell: `(Get-FileHash .\<file>.zip -Algorithm SHA256).Hash` must print the value above. Then unzip them so you get:

```
Player Tools\                       (the folder with the .bat files)
├── check-mod.bat
├── build-mod.bat
├── play-in-sandbox.bat
├── build\
└── tools\
    ├── GDRE_tools\
    │   ├── gdre_tools.exe
    │   └── (the other files from its zip)
    ├── Godot\
    │   ├── Godot_v4.3-stable_win64.exe
    │   └── Godot_v4.3-stable_win64_console.exe
    └── FFmpeg\
        ├── ffmpeg.exe
        └── (the .dll files from bin\)
```

Use exactly these versions. (Inside the Monster Layer Mod Kit the scripts also find the kit's `Tools\` folder.)

## Files they create

- `tools\` — GDRE Tools, Godot and FFmpeg.
- `cache\` — your original game, unpacked once (about 150 MB), and the converted videos of built mods. Delete it any time.
- `original_game.txt`, `game_folder.txt` — where your game is, so you aren't asked again.
- `sandbox\` — files shared with Windows Sandbox, and `sandbox\saves\` with the saves made there.
- `<mod name>.check.txt` next to each checked mod, and `<zip name> - built\` next to each built zip.

---

## Русский

Инструменты для игроков, которые хотят безопасно попробовать чужой мод для Monster Layer. Работают на Windows 10 и 11.

| Файл | Что делает |
|---|---|
| `check-mod.bat` | Проверяет `.pck` мода на опасный код, **не запуская его**. |
| `build-mod.bat` | Собирает `.pck` мода самостоятельно из его **zip с исходниками**, чтобы ты знал, что внутри. |
| `play-in-sandbox.bat` | Запускает мод внутри **Windows Sandbox**: без интернета, без доступа к твоим файлам. |
| `build\` | Код, которым `build-mod.bat` собирает мод. Обычные читаемые файлы PowerShell и GDScript. |

**Зачем это нужно.** Мод — это файл `.pck`, а `.pck` — не просто картинки: в нём весь код игры. В играх на Godot нет песочницы, поэтому `.pck` может делать всё, что может программа: запускать программы, ходить в интернет, удалять файлы. Эти инструменты позволяют увидеть, что делает мод, собрать его самому или держать его подальше от твоего ПК.

**Эти инструменты никогда не скачивают игру.** Всегда используется твоя собственная копия Monster Layer; инструменты только спрашивают, где она лежит. Моду никогда не нужен свой `.exe`: не запускай `.exe`, `.dll`, `.bat` или установщик, пришедшие с модом.

**Как получить инструменты.** Скачай всю папку `Player Tools` вместе с `build\`: на странице Monster Layer Mod Kit на GitHub нажми **Code → Download ZIP** (или возьми zip Player Tools из Releases) и оставь только папку `Player Tools`, например как `C:\Monster Layer Player Tools\`. `check-mod.bat` и `play-in-sandbox.bat` работают и по отдельности; `build-mod.bat` нужна папка `build\` рядом. Перетаскивай файлы на `.bat` или запускай их из командной строки.

## Безопасный путь

Если ты доверяешь автору этих инструментов и делаешь всё по этому README, то **скорее всего** всё будет хорошо. Самый безопасный способ играть в чужой мод:

1. **Возьми мод в виде zip с исходниками** (`... (source).zip`, сделан в Monster Layer Mod Kit). В нём лежат **только** конфиги мода (`lay.cfg`, `boss.cfg`, `mod_settings.cfg`, обычный текст), его оригинальные видео, GIF и картинки и `mod_source.json`. Никаких скриптов, программ и файлов игры.
2. **Проверь zip.** Открой его и посмотри файлы; проверь весь zip своим антивирусом или онлайн-сканером (например, [VirusTotal](https://www.virustotal.com/)); при желании попроси ИИ-агента прочитать конфиги.
3. **Собери `.pck` сам** через `build-mod.bat`. Он отказывается от всего в zip, что не конфиг, не видео и не картинка, и собирает мод **кодом из `build\`** (его можно прочитать), **официальным Godot 4.3** (скачанным с GitHub-релиза Godot и сверенным по SHA-256) и **твоей собственной игрой**.
4. **Запусти свой официальный `Monster Layer.exe`** с собранным тобой `.pck`.

Почему это безопасно: от автора мода приходят только текстовые конфиги и медиафайлы, а сборка никогда ничего не запускает из zip. Все запускаемые программы — официальные (Godot, GDRE Tools, FFmpeg, твоя игра) или читаемые (`build\`). Остаётся небольшой риск: медиафайл, специально сделанный под ошибку в FFmpeg или в загрузчике картинок Godot. От него защищают проверка антивирусом на шаге 2 и Windows Sandbox (ниже).

**Если мод есть только готовым `.pck`,** его код так просто не увидеть: проверь его через `check-mod.bat`, прочитай отчёт и лучше играй в Windows Sandbox. Попроси у автора zip с исходниками.

**Как быть осторожным с чужими модами:**

- Скачивай моды только там, где их выложил автор (его тема на f95zone, его страница), а не с перезаливов.
- Никогда не запускай `.exe`, `.bat`, `.dll`, `.ps1` или установщик, пришедший с модом. Мод — это `.pck` или zip с исходниками, и ничего больше. Используй `.bat` из этой папки, скачанные со страницы самого Mod Kit.
- Не игнорируй **DANGER** и **REFUSED**. **WARNING** значит «сначала прочитай отчёт».
- Держи резервную копию оригинального `Monster Layer.pck` и сохранений (`%APPDATA%\Godot\app_userdata\MonsterLayer`).
- Мод, сделанный в Mod Kit, не может содержать написанный руками код игры в zip с исходниками. Если автор говорит «моему моду нужен `.pck`, zip с исходниками не подойдёт», значит, он менял код игры руками: будь особенно осторожен, используй `check-mod.bat` и Windows Sandbox.

## check-mod.bat — проверка .pck

Перетащи `.pck` мода на `check-mod.bat`. В первый раз он предложит скачать GDRE Tools (см. ниже) и спросит твою **оригинальную** игру: перетащи в окно свой оригинальный `Monster Layer.pck` (или папку игры) и нажми Enter. Путь запомнится. Если ты уже положил мод в папку игры, используй резервную копию оригинального `.pck`.

| Вердикт | Значение |
|---|---|
| **LOOKS SAFE** | Опасных вызовов и файлов не найдено. |
| **WARNING** | Что-то не удалось проверить или выглядит необычно. Играй, только если отчёт прочитал тот, кому ты доверяешь. |
| **DANGER** | Мод делает то, что игровому моду никогда не нужно. **Не запускай его.** |

Полный отчёт сохраняется рядом с модом как `<имя мода>.check.txt`. Из командной строки: `check-mod.bat "mod.pck" "C:\Games\Monster Layer\Monster Layer.pck"`.

Что он проверяет:

- Распаковывает мод и твою оригинальную игру через GDRE Tools во временные папки. **Ничего из мода не запускается.**
- Сравнивает каждый скрипт с оригинальной игрой; скрипты с обеих сторон компилируются и декомпилируются заново, чтобы комментарии и форматирование не считались изменениями.
- В каждой новой или изменённой строке ищет: запуск и остановку программ, открытие ссылок и файлов вне игры (`OS.execute`, `OS.shell_open`...); интернет и сеть (`HTTPRequest`, TCP, UDP, WebSocket...); подгрузку кода или других пакетов во время игры (`load_resource_pack`, `GDExtension`, `Expression`...); создание объектов из данных (`str_to_var`...); удаление, переименование, копирование файлов и запись вне игры и её папки сохранений; пути к дискам и сетевым папкам; и, как предупреждение, чтение системных папок и переменных окружения и вызов функций по имени, собранному во время игры.
- Помечает программы, библиотеки и архивы внутри `.pck`, скрипты, спрятанные в сценах, объекты в конфигах и файлы, ссылающиеся за пределы игры; проверяет, что `.exe` рядом с модом — это оригинальный `.exe` игры; предупреждает, если твоя «оригинальная» игра не совпадает с известной официальной версией.

Он **не может доказать**, что мод безопасен: хитрый код может прятать, что делает. Изменённые скрипты для мода — норма, они перечислены в отчёте, чтобы человек мог их прочитать.

## build-mod.bat — сборка мода из zip с исходниками

Перетащи zip с исходниками на `build-mod.bat`. В первый раз он спросит твою оригинальную игру (как `check-mod.bat`) и предложит скачать GDRE Tools, Godot 4.3 и FFmpeg (см. ниже).

Что он делает:

1. Читает zip и **отказывается** от него (**REFUSED**, ничего не собирается), если в нём есть что-то кроме разрешённых файлов (см. [Ограничения безопасности](#ограничения-безопасности)).
2. Распаковывает твою оригинальную игру через GDRE Tools (хранится в `cache\`).
3. Добавляет мод через `build\apply-mods.ps1`: проверяет конфиги, конвертирует видео и GIF через FFmpeg (готовые файлы хранятся в `cache\media\`), добавляет код Mod Kit из `build\mod_kit\` и подключает его к игре через `build\hook-game.ps1`. Это тот же код, что использует Mod Kit, поэтому у тебя получается такой же `.pck`, как у автора.
4. Собирает `.pck` через Godot 4.3, используя твой собственный `Monster Layer.exe` как шаблон экспорта.
5. Сохраняет результат как `<имя zip> - built\Monster Layer.pck` рядом с zip и проверяет его через `check-mod.bat`.

Предупреждает, если мод сделан для другой версии игры. Из командной строки: `build-mod.bat "mod (source).zip" "C:\Games\Monster Layer\Monster Layer.pck"`.

### Ограничения безопасности

**Пока что в целях безопасности мод может содержать только конфиги и картинки, GIF и видео.** Если разработка продолжится, мы постараемся найти способы добавлять в Mod Kit новые возможности по одной, не теряя твоего доверия.

`build-mod.bat` принимает в zip с исходниками только такие файлы:

| Файл | Что это |
|---|---|
| `mod_source.json` | Для какой версии игры сделан мод (формат 2). |
| `mod_settings.cfg` | Настройки всего мода. |
| `Custom Lays\<имя>\lay.cfg`, `Custom Bosses\<имя>\boss.cfg` | Конфиги каждого кастомного Lay и босса. |
| видео, GIF и картинки в этих папках | `.mp4 .m4v .webm .mov .mkv .avi .wmv .flv .mpg .mpeg .ogv .gif .png .jpg .jpeg .webp .bmp .tga` |

Всё остальное отклоняется, в том числе:

- **любые скрипты и код**: `.gd`, `.cs`, `.ps1`, `.bat`, сцены и ресурсы (`.tscn`, `.tres`, `.res`) — в сценах можно спрятать скрипты;
- **`@tool`-скрипты и плагины редактора и экспорта** — Godot сам запускает их, когда открывает и собирает проект, то есть они выполнились бы на твоём ПК во время сборки;
- **`project.godot` и `override.cfg`** — они могут включать плагины и автозагружаемые скрипты;
- **программы, библиотеки и архивы**: `.exe`, `.dll`, `.so`, `.zip`, `.pck`...;
- **пути, выходящие из папки** (`..`, абсолютные пути, диски);
- **объекты в конфигах** (`Object(...)`, `Resource(...)`): формат конфигов Godot умеет описывать объекты со скриптами, а конфигу мода нужны только текст, числа, true/false и списки.

## play-in-sandbox.bat — игра внутри Windows Sandbox

Перетащи `.pck` мода на `play-in-sandbox.bat`; в первый раз он спросит папку игры (или `Monster Layer.exe`). Он запускает Windows Sandbox — одноразовую Windows внутри твоей Windows — и запускает в ней игру с модом:

- внутри песочницы **нет сети**;
- папка игры и мод подключены **только для чтения**; больше ничего с твоего ПК игре не видно;
- буфер обмена, принтер, микрофон и камера выключены;
- сохранения игры попадают в `sandbox\saves\` рядом с `.bat` — отдельно от твоих настоящих сохранений; это единственная папка, куда мод может писать;
- всё остальное удаляется, когда ты закрываешь окно песочницы.

### Как включить Windows Sandbox

Скрипт сам никогда не меняет настройки Windows. Windows Sandbox есть в Windows 10 (1903 и новее) и 11 **Pro, Enterprise и Education**, но не в Home.

1. Проверь, что виртуализация включена: Диспетчер задач → Производительность → ЦП показывает «Виртуализация: Включено». Если нет, включи её в BIOS/UEFI (называется Intel VT-x, Intel Virtualization Technology, AMD-V или SVM).
2. Нажми Win+R, введи `optionalfeatures`, нажми Enter.
3. Отметь **Windows Sandbox** (Песочница Windows), нажми OK (нужны права администратора) и перезагрузи ПК.

Или в PowerShell от имени администратора: `Enable-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM`, затем перезагрузка. Выключить потом можно там же, сняв галочку.

### Чем за это платишь

- **Ниже FPS.** Игра получает виртуальную видеокарту, которая работает на твоей настоящей видеокарте, но медленнее обычного. Она поддерживает только Direct3D 12 (без Vulkan и OpenGL), поэтому `play-in-sandbox.bat` запускает игру через драйвер Direct3D 12 Godot с рендерером Forward+: собственный рендерер игры Mobile там зависает на чёрном экране. Картинка может немного отличаться от обычной игры. Monster Layer — лёгкая 2D-игра, так что играть можно.
- **Первый запуск долгий:** игра компилирует шейдеры, это может занять минуту с чёрным окном. Они сохраняются в `sandbox\saves\shader_cache\`, так что следующие запуски быстрее.
- **Запуск дольше:** песочница стартует примерно 10–30 секунд, потом в неё копируется игра.
- **Память:** пока песочница работает, она занимает до 4 ГБ ОЗУ.
- **Одна песочница за раз,** и каждый запуск — чистая Windows: настройки внутри теряются, остаются только сохранения в `sandbox\saves\`.
- Пока Windows Sandbox включена, некоторые другие программы виртуализации (старые версии VirtualBox и VMware) могут работать медленнее. Если её выключить, это пройдёт.

**В Windows Home** песочницы Windows нет. Альтернативы: [Sandboxie-Plus](https://sandboxie-plus.com/) (бесплатно, изолирует программы, но не так строго, как отдельная Windows) или виртуальная машина (VirtualBox, VMware; строго, но нужно настраивать). Иначе иди [безопасным путём](#безопасный-путь) с zip с исходниками, а `.pck` проверяй через `check-mod.bat`.

## Какие программы они скачивают

Скрипты используют три бесплатные программы с открытым кодом. Если какой-то нет, скрипт объясняет, зачем она нужна, и спрашивает, прежде чем скачать её с официального релиза на GitHub; SHA-256 файла сверяется до использования, так что подменённый файл не пройдёт. В Windows ничего не устанавливается.

| Программа | Нужна для | Зачем |
|---|---|---|
| GDRE Tools 2.7.4 | `check-mod.bat`, `build-mod.bat` | Распаковывает `.pck` (мод и твою оригинальную игру). |
| Godot 4.3 | `build-mod.bat` | Официальный редактор Godot той версии, на которой сделана игра; собирает `.pck`. |
| FFmpeg 9.0.2 | `build-mod.bat` | Конвертирует видео и GIF мода в формат, который играет игра (Ogg Theora). |

### Как скачать программы самому

**GDRE Tools 2.7.4:** скачай `GDRE_tools-v2.7.4-windows.zip` со страницы <https://github.com/GDRETools/gdsdecomp/releases/tag/v2.7.4>.
SHA-256: `AF24C563EEE501EFFB194D83595DE64696C32547B2246034DBFB891A24BFA0AD`

**Godot 4.3 (обычная версия, не .NET):** скачай `Godot_v4.3-stable_win64.exe.zip` со страницы <https://github.com/godotengine/godot/releases/tag/4.3-stable>.
SHA-256: `8F2C75B734BD956027AE3CA92C41F78B5D5A255DACC0F20E4E3C523C545AD410`

**FFmpeg 9.0.2 (full, shared):** скачай `ffmpeg-9.0.2-full_build-shared.zip` со страницы <https://github.com/GyanD/codexffmpeg/releases/tag/9.0.2> (сборки для Windows, на которые ссылается ffmpeg.org).
SHA-256: `8D31E162F1616E37AAB3FA2DB991B97E1B8DBEB1C8465FD81A81BE16FF91B328`
Из его папки `bin\` скопируй `ffmpeg.exe` и все файлы `.dll` (`ffplay.exe` и `ffprobe.exe` не нужны).

Проверка в PowerShell: `(Get-FileHash .\<файл>.zip -Algorithm SHA256).Hash` должно вывести значение выше. Затем распакуй так, чтобы получилось:

```
Player Tools\                       (папка с .bat)
├── check-mod.bat
├── build-mod.bat
├── play-in-sandbox.bat
├── build\
└── tools\
    ├── GDRE_tools\
    │   ├── gdre_tools.exe
    │   └── (остальные файлы из архива)
    ├── Godot\
    │   ├── Godot_v4.3-stable_win64.exe
    │   └── Godot_v4.3-stable_win64_console.exe
    └── FFmpeg\
        ├── ffmpeg.exe
        └── (файлы .dll из bin\)
```

Нужны именно эти версии. (Внутри Monster Layer Mod Kit скрипты также находят папку `Tools\` самого кита.)

## Какие файлы они создают

- `tools\` — GDRE Tools, Godot и FFmpeg.
- `cache\` — твоя оригинальная игра, распакованная один раз (около 150 МБ), и сконвертированные видео собранных модов. Её можно удалить в любой момент.
- `original_game.txt`, `game_folder.txt` — где лежит твоя игра, чтобы не спрашивать снова.
- `sandbox\` — файлы для Windows Sandbox и `sandbox\saves\` с сохранениями, сделанными там.
- `<имя мода>.check.txt` рядом с каждым проверенным модом и `<имя zip> - built\` рядом с каждым собранным zip.
