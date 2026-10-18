extends Node

# Custom Lays (custom opponents) added by Monster Layer Mod Kit.
# Every folder in res://custom_lays/ with a lay.cfg is one custom Lay, unless its
# lay.cfg says active=false (pack-moded.bat doesn't even pack those).
#
# Spawn chance: a custom Lay is one more species in the game's own roll.
# The game picks a normal Lay's species evenly (1 of 9; the body comes after,
# from the body preference sliders). A custom Lay has the weight
#   weight = chance / 100   (0 when the slider for its fixed body is at 0)
# and each generated Lay is a custom Lay with probability
#   weight / (number of species + sum of all custom weights).
# With chance=100 (the default) a custom Lay is exactly as likely as any one
# species: 1 / (9 + number of custom Lays); 200 = twice as likely, 50 = half.
# The more custom Lays, the rarer every species and every custom Lay. Normal
# Lays always stay possible; the rare characters are rolled apart.
# "chance" is getChance(): base_chance, changed by chance_per_defeated for every
# opponent defeated in the run, capped by max_chance, and only while the defeated
# count is within min_defeated..max_defeated (bosses count defeated bosses).
#
# Custom Bosses: every folder in res://custom_bosses/ with a boss.cfg can replace
# the dragon, the end boss of a run. They use the dragon's fight (attacks, special
# hearts, 3 rounds, game over) with their own name, body and media. A custom boss
# gets weight chance / 100 (0 when the slider for its body is at 0) against the
# dragon's 1: with chance=100 (the default) each of N custom bosses and the
# dragon are equally likely, 1 / (1 + N).

const LAYS_DIR = "res://custom_lays"
const CONFIG_NAME = "lay.cfg"
const BOSSES_DIR = "res://custom_bosses"
const BOSS_CONFIG_NAME = "boss.cfg"
# The dragon intro (ui "DragonStart"): a white screen with text; the boss spawns
# behind it at 6 s and the white fades out from 7 to 8 s.
const INTRO_REMOVE_AFTER = 8.5
const MEDIA_CONFIG_NAME = "media.cfg"
# Media kinds a Lay can have (lay.cfg: <kind>_anim), see custom_lay_media.gd.
const MEDIA_KINDS = ["thrust", "pound", "idle", "free_cum", "egg", "lose", "orgasm", "hypno", "intro"]
const MEDIA_SCRIPT = preload("res://mod_kit/custom_lay_media.gd")

const GENITALS_ALIASES = {"pussy": "pussy", "vagina": "pussy", "dick": "dick", "penis": "dick"}
const CHEST_ALIASES = {"boobs": "boobs", "female": "boobs", "flat": "flat", "male": "flat"}

# Size words map to the middle of the game's own size bands (Library.createTraitText()).
# Numbers are the game's scale and are clamped to the same range.
const BOOB_SIZES = {"min": 0.8, "max": 1.2, "words": {"tiny": 0.84, "small": 0.92, "average": 1.0, "large": 1.08, "huge": 1.16}}
const DICK_SIZES = {"min": 0.8, "max": 1.5, "words": {"mini": 0.87, "little": 1.01, "average": 1.15, "hefty": 1.29, "massive": 1.43}}

var lays = []
var bosses = []
# The boss chosen for the coming dragon fight: null = not chosen yet,
# {} = the dragon, otherwise a custom boss.
var pendingboss = null


func _ready() -> void :
	reloadAll()


# Also called by the Mod Kit app after it prepared a Lay for its preview.
func reloadAll():
	lays = loadAll(LAYS_DIR, CONFIG_NAME, "lay")
	bosses = loadAll(BOSSES_DIR, BOSS_CONFIG_NAME, "boss")
	pendingboss = null
	print("[CustomLays] Loaded " + str(lays.size()) + " custom Lay(s) and " + str(bosses.size()) + " custom boss(es).")


# Pictures are imported when the game is packed. The Mod Kit app shows pictures it
# has just copied, which aren't imported yet, so those are read from the file.
func loadTexture(path):
	if ResourceLoader.exists(path):
		return load(path)
	var image = Image.load_from_file(path)
	return null if image == null else ImageTexture.create_from_image(image)


func loadAll(basedir, configname, section):
	var result = []
	var dir = DirAccess.open(basedir)
	if dir == null:
		return result
	for folder in dir.get_directories():
		var lay = loadLay(basedir, folder, configname, section)
		if lay != null:
			result.append(lay)
	return result


func loadLay(basedir, folder, configname, section):
	var path = basedir + "/" + folder + "/" + configname
	var config = ConfigFile.new()
	# Parsed from text with the UTF-8 BOM removed, since some editors (Notepad) add one.
	var text = FileAccess.get_file_as_string(path).trim_prefix(char(0xFEFF))
	if text == "" || config.parse(text) != OK:
		push_warning("[CustomLays] " + folder + ": can't read " + configname + ", skipped.")
		return null
	# boss.cfg uses a [boss] section; the fields are the same as in lay.cfg.
	if section != "lay" && config.has_section(section):
		for key in config.get_section_keys(section):
			config.set_value("lay", key, config.get_value(section, key))
	# active=false switches a Lay or boss off (not set = true).
	if str(config.get_value("lay", "active", true)).strip_edges().to_lower() == "false":
		return null

	var genitals = str(config.get_value("lay", "genitals", "")).to_lower()
	var chest = str(config.get_value("lay", "chest", "")).to_lower()
	if !GENITALS_ALIASES.has(genitals):
		push_warning("[CustomLays] " + folder + ": genitals must be pussy or dick, skipped.")
		return null
	if !CHEST_ALIASES.has(chest):
		push_warning("[CustomLays] " + folder + ": chest must be boobs or flat, skipped.")
		return null

	var species = str(config.get_value("lay", "base_species", "")).to_lower()
	if species != "" && !Library.allspecies.has(species):
		push_warning("[CustomLays] " + folder + ": unknown base_species " + species + ", a random one is used.")
		species = ""

	# An empty name ("", the example's default) means the folder name.
	var layname = str(config.get_value("lay", "name", "")).strip_edges()
	if layname == "":
		layname = folder

	# Percent of one species' (or the dragon's) chance; empty or not set = 100.
	# "chance" is the old name of base_chance, still read for older mods.
	var basechance = maxf(getNumber(config, "base_chance", getNumber(config, "chance", 100.0)), 0)

	var lay = {
		"id": folder,
		"name": layname,
		"genitals": GENITALS_ALIASES[genitals],
		"chest": CHEST_ALIASES[chest],
		"base_chance": basechance,
		"chance_per_defeated": getNumber(config, "chance_per_defeated", 0.0),
		# -1 = no limit.
		"max_chance": getNumber(config, "max_chance", -1.0),
		"min_defeated": getNumber(config, "min_defeated", 0.0),
		"max_defeated": getNumber(config, "max_defeated", -1.0),
		"pronoun": str(config.get_value("lay", "pronoun", "")),
		"base_species": species,
		"media": loadMedia(basedir, folder, config),
		"portrait": loadPortrait(basedir, folder),
		"mute_plap": getBool(config, "mute_native_plap_sound"),
		"mute_moan": getBool(config, "mute_native_moan"),
		"boobsize": getSize(config, folder, "boob_size", BOOB_SIZES),
		"dicksize": getSize(config, folder, "dick_size", DICK_SIZES),
		"traits": getTraits(config, folder),
		"boss": section == "boss",
	}
	# The boss intro picture/video is shown by showBossIntro(), not in the round.
	lay["intro"] = lay["media"].get("intro", {})
	lay["media"].erase("intro")
	return lay


# Fixed traits from lay.cfg: traits="pound+, thrust-" or traits=["pound+"].
# Scripts\apply-mods.ps1 already refuses wrong lists when packing; this only
# skips what can't be used, so a hand-edited build doesn't break the game.
func getTraits(config, folder):
	var value = config.get_value("lay", "traits", "")
	var items = value if value is Array else str(value).split(",")
	var result = []
	for item in items:
		var trt = str(item).strip_edges().to_lower()
		if trt == "":
			continue
		if !Library.traittext.has(trt):
			push_warning("[CustomLays] " + folder + ": unknown trait " + trt + ", skipped.")
		elif result.has(trt) || result.has(oppositeTrait(trt)):
			push_warning("[CustomLays] " + folder + ": trait " + trt + " repeats or contradicts another one, skipped.")
		elif result.size() >= 3:
			push_warning("[CustomLays] " + folder + ": more than 3 traits, " + trt + " skipped.")
		else:
			result.append(trt)
	return result


func oppositeTrait(trt):
	return trt.replace("+", "-") if trt.ends_with("+") else trt.replace("-", "+")


# Traits of a generated custom Lay. The fixed ones from lay.cfg come first (those
# the current player character can't get are left out, like for normal Lays).
# The game's own roll decides how many traits there are (1-3) and the sign of
# each random slot; random traits never repeat or contradict the fixed ones.
# The first Lay of a run (traitless) only gets the fixed ones.
func rollTraits(lay, traitless):
	var positive = DifficultyManager.positivetraits[Settings.playersprite]
	var negative = DifficultyManager.negitivetraits[Settings.playersprite]
	var result = []
	for trt in lay["traits"]:
		if positive.has(trt) || negative.has(trt):
			result.append(trt)
	if traitless:
		return result
	var rolled = DifficultyManager.rollTraits()
	for i in range(result.size(), rolled.size()):
		var pool = (negative if rolled[i].ends_with("-") else positive).duplicate()
		for trt in result:
			pool.erase(trt)
			pool.erase(oppositeTrait(trt))
		if pool.size() > 0:
			result.append(pool.pick_random())
	return result


# Returns the size from lay.cfg, or -1 when it isn't set (then it is rolled each time).
func getSize(config, folder, key, sizes):
	var value = str(config.get_value("lay", key, "")).strip_edges().to_lower()
	if value == "":
		return -1.0
	if sizes["words"].has(value):
		return sizes["words"][value]
	if value.is_valid_float():
		return clampf(value.to_float(), sizes["min"], sizes["max"])
	push_warning("[CustomLays] " + folder + ": " + key + " must be one of " + ", ".join(sizes["words"].keys()) + " or a number, a random size is used.")
	return -1.0


func getBool(config, key):
	return str(config.get_value("lay", key, false)).to_lower() == "true"


# media.cfg is written by Scripts\apply-mods.ps1 at pack time. It points to the
# prepared files (videos converted to .ogv with the speed modifier applied).
# Each kind has a list of clips (one per file in lay.cfg), one is picked at random
# on every playback: kind -> {"reset", "clips": [{"type", "variants": [paths]}]}.
# "variants" are the sped-up copies for anim_acceleration_steps, slowest first;
# pictures and videos without copies have one.
func loadMedia(basedir, folder, config):
	var result = {}
	var mediacfg = ConfigFile.new()
	if mediacfg.load(basedir + "/" + folder + "/" + MEDIA_CONFIG_NAME) != OK:
		return result
	var dir = basedir + "/" + folder + "/"
	for kind in MEDIA_KINDS:
		if !mediacfg.has_section(kind):
			continue
		var clips = []
		for clip in mediacfg.get_value(kind, "clips", []):
			var variants = []
			for file in clip.get("variants", [clip["file"]]):
				variants.append(dir + str(file))
			clips.append({"type": str(clip["type"]), "variants": variants})
		if clips.size() > 0:
			result[kind] = {"reset": getBool(config, kind + "_anim_reset_on_pause"), "fit": getBool(config, "auto_fit_" + kind + "_anim_length"), "clips": clips}
	return result


func loadPortrait(basedir, folder):
	var mediacfg = ConfigFile.new()
	if mediacfg.load(basedir + "/" + folder + "/" + MEDIA_CONFIG_NAME) != OK:
		return ""
	if !mediacfg.has_section("portrait"):
		return ""
	return basedir + "/" + folder + "/" + str(mediacfg.get_value("portrait", "file", ""))


# Returns {} when there is no custom Lay with this id.
func getLay(id) -> Dictionary:
	for lay in lays:
		if lay["id"] == id:
			return lay
	return {}


func getBoss(id) -> Dictionary:
	for boss in bosses:
		if boss["id"] == id:
			return boss
	return {}


# The custom Lay or custom boss of the current round, or {} for a normal one.
func getCurrentLay() -> Dictionary:
	if GameManager.currentcutieinfo.has("custom_boss"):
		return getBoss(GameManager.currentcutieinfo["custom_boss"])
	return getLay(GameManager.currentcutieinfo.get("custom", ""))


# Called from the patched AudioManager: kind is "plap" or "moan".
func isMuted(kind):
	var lay = getCurrentLay()
	return !lay.is_empty() && lay["mute_" + kind]


# Called from the patched LayChoosingUi.populate() after it set the species portrait.
func applyPortrait(color, eye, lines, cutieinfo):
	lines.stretch_mode = TextureRect.STRETCH_SCALE
	# The profile is reused for the next Lay: drop a video portrait from before.
	var old = lines.get_node_or_null("CustomPortraitVideo")
	if old != null:
		old.queue_free()
	var lay = getLay(cutieinfo.get("custom", ""))
	if lay.is_empty() || lay["portrait"] == "":
		return
	color.texture = null
	eye.texture = null
	if String(lay["portrait"]).ends_with(".ogv"):
		# A video or GIF portrait, already cut to a square when packing; looped.
		lines.texture = null
		var player = VideoStreamPlayer.new()
		player.name = "CustomPortraitVideo"
		var stream = VideoStreamTheora.new()
		stream.file = lay["portrait"]
		player.stream = stream
		player.expand = true
		player.mouse_filter = Control.MOUSE_FILTER_IGNORE
		player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lines.add_child(player)
		player.finished.connect(func():
			player.paused = false
			player.play())
		player.play()
		return
	lines.texture = loadTexture(lay["portrait"])
	# Fills the square frame keeping the aspect ratio; the frame clips the edges.
	lines.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED


# Called from the patched Anim._ready(): replaces the models with the Lay's media.
func attachMedia(anim):
	var lay = getCurrentLay()
	if lay.is_empty() || lay["media"].size() == 0:
		return
	anim.get_node("Sprites").visible = false
	var node = MEDIA_SCRIPT.new()
	node.name = "CustomLayMedia"
	anim.add_child(node)
	node.setup(anim, lay)


# Called from the patched Anim.gd: kind is "free_cum" (also used when you lose and
# for Sylvia's egg laying) or "orgasm".
func onSpecial(anim, kind):
	var node = anim.get_node_or_null("CustomLayMedia")
	if node == null:
		return
	if kind == "free_cum":
		# ui.gameOver() deactivates the UI before it plays the free cum animation.
		if Buss.ui != null && !Buss.ui.active:
			kind = "lose"
		elif Settings.playersprite == "Sylvia":
			kind = "egg"
	node.onSpecial(kind)


# Called from the patched Anim.playHypnoAnim(): animname is "Start" or "End".
func onHypno(anim, animname):
	var node = anim.get_node_or_null("CustomLayMedia")
	if node != null:
		node.onHypno(animname)


# Called from the patched Anim.gd at the start of every thrust and pound stroke.
func onStroke(anim, kind):
	var node = anim.get_node_or_null("CustomLayMedia")
	if node != null:
		node.onStroke(kind)


# A number from lay.cfg; empty or not set = default.
func getNumber(config, key, default):
	var text = str(config.get_value("lay", key, "")).strip_edges()
	return default if text == "" else text.to_float()


# How many opponents of this kind the player has beaten in this run, counting
# every loop of endless mode: for a Lay all Lays (10 per loop, the same count the
# game's difficulty uses), for a boss the end bosses (1 per finished loop).
func getDefeated(lay):
	if lay["boss"]:
		return GameManager.endlessloop
	return mini(GameManager.currentcombat, 10) + 10 * GameManager.endlessloop


# min_defeated / max_defeated (lay.cfg): the Lay or boss is only in the pool
# while the defeated count is in that range.
func inPool(lay):
	var defeated = getDefeated(lay)
	return defeated >= lay["min_defeated"] && (lay["max_defeated"] < 0 || defeated <= lay["max_defeated"])


# The chance in use right now: base_chance plus chance_per_defeated for every
# defeated opponent (added, not multiplied), at most max_chance, at least 0;
# 0 outside the min_defeated..max_defeated range.
func getChance(lay):
	if !inPool(lay):
		return 0.0
	var chance = lay["base_chance"] + lay["chance_per_defeated"] * getDefeated(lay)
	if lay["max_chance"] >= 0:
		chance = minf(chance, lay["max_chance"])
	return maxf(chance, 0.0)


# Last resort when nothing else can be picked: every Lay or boss in the pool is
# equally likely, or all of them if none is in the pool.
func equalWeights(list):
	var pool = list.filter(func(lay): return inPool(lay))
	return list.map(func(lay): return 1.0 if pool.is_empty() || inPool(lay) else 0.0)


func getBodyType(lay):
	var bodytype = "boob" if lay["chest"] == "boobs" else "chest"
	return bodytype + lay["genitals"]


# Weight of every custom Lay in species units (1 = one species with that body).
func getWeights():
	var sliders = Settings.getWeightDict()
	var weights = []
	for lay in lays:
		var weight = 0.0
		if float(sliders[getBodyType(lay)]) > 0:
			weight = getChance(lay) / 100.0
		weights.append(weight)
	return weights


# disable_default_lays (mod_settings.cfg): only custom Lays are generated, and
# the rare characters (Xerxes, Zephyr) don't appear either. Only with custom
# Lays to replace them (pack-moded.bat refuses the setting without any).
func defaultLaysDisabled():
	return lays.size() > 0 && ModSettings.getBool("disable_default_lays")


# Called from the patched Library.getAllAllowedRares().
func raresDisabled():
	return defaultLaysDisabled()


# Called from the patched GameManager.startTutorial(): with normal Lays disabled
# the tutorial's kobold is replaced by a custom Lay, picked like any other one
# (by chance and body sliders). The tutorial itself doesn't depend on the Lay.
# Called from the patched tutorial_worker.gd for every line Ero says. With at
# least one custom boss the end boss may not be the dragon, so "The Dragon"
# becomes "THEY".
func tutorialText(text):
	if bosses.size() > 0:
		return text.replace("The Dragon", "THEY")
	return text


func tutorialCutie(cutie):
	if !defaultLaysDisabled():
		return cutie
	var lay = pick()
	return cutie if lay == null else generate(lay, true)


# Weight of the normal species together: 1 per species, 0 when they're disabled.
func getDefaultWeight():
	return 0.0 if defaultLaysDisabled() else float(Library.allspecies.size())


# Weights for picking a Lay. When normal Lays are disabled and every custom Lay's
# body slider is at 0, the sliders are ignored (chance only, then all equal), so
# there is always a Lay to generate.
func getPickWeights():
	var weights = getWeights()
	if getDefaultWeight() == 0 && sumOf(weights) <= 0:
		weights = lays.map(func(lay): return getChance(lay) / 100.0)
		if sumOf(weights) <= 0:
			weights = equalWeights(lays)
	return weights


func sumOf(values):
	var total = 0.0
	for value in values:
		total += value
	return total


# Chance in percent of every custom Lay, and of a normal Lay ("default"), for
# one generated Lay.
func getChances():
	var weights = getPickWeights()
	var total = getDefaultWeight() + sumOf(weights)
	var chances = {"default": getDefaultWeight() / total * 100.0}
	for i in range(lays.size()):
		chances[lays[i]["id"]] = weights[i] / total * 100.0
	return chances


# Returns a custom Lay to spawn, or null when a normal Lay should be generated.
func pick():
	if lays.size() == 0:
		return null
	var weights = getPickWeights()
	var rand = randf_range(0, getDefaultWeight() + sumOf(weights))
	for i in range(lays.size()):
		if rand < weights[i]:
			return lays[i]
		rand -= weights[i]
	return null


# Builds the cutie info for a custom Lay on top of a normal Lay of its base species.
# The look (species, skin and eye color, voice pitch, bio) is the same every time
# for one Lay: it is rolled with a random seed made from the Lay's id.
# Sizes come from lay.cfg (boob_size, dick_size); unset ones are rolled anew every
# time, like heart damage. Traits are the fixed ones from lay.cfg plus random
# ones (rollTraits()).
func generate(lay, traitless):
	seed(hash("CustomLay:" + lay["id"]))
	var species = lay["base_species"]
	if species == "":
		species = Library.allspecies[randi() % Library.allspecies.size()]
	var cutieinfo = Library.generateCutie(true, species)

	cutieinfo["custom"] = lay["id"]
	cutieinfo["name"] = lay["name"]
	cutieinfo["chest"] = lay["chest"]
	cutieinfo["bits"] = lay["genitals"]
	if lay["pronoun"] != "":
		cutieinfo["pronoun"] = lay["pronoun"]
	elif lay["chest"] == "boobs":
		cutieinfo["pronoun"] = "(she/her)"
	else:
		cutieinfo["pronoun"] = "(he/him)"
	cutieinfo["bio"] = Library.generatebio(cutieinfo)

	randomize()
	cutieinfo["traits"] = rollTraits(lay, traitless)
	# Same ranges as Library.generateCutie() for normal Lays.
	cutieinfo["boobsize"] = lay["boobsize"] if lay["boobsize"] >= 0 else randf_range(0.9, 1.2)
	cutieinfo["dicksize"] = lay["dicksize"] if lay["dicksize"] >= 0 else randf_range(0.8, 1.5)
	cutieinfo["heartdamage"] = DifficultyManager.getHeartDamage()
	return cutieinfo


# ---- Custom bosses ----

# Picks the end boss: the dragon (weight 1) or a custom boss (chance / 100).
# With disable_default_boss (mod_settings.cfg) the dragon's weight is 0; if then
# every custom boss's weight is 0 too, the sliders are ignored (chance only, then
# all equal), so there is always a boss.
func pickBoss() -> Dictionary:
	var sliders = Settings.getWeightDict()
	var weights = []
	for boss in bosses:
		var weight = 0.0
		if float(sliders[getBodyType(boss)]) > 0:
			weight = getChance(boss) / 100.0
		weights.append(weight)
	var dragon = 1.0
	if bosses.size() > 0 && ModSettings.getBool("disable_default_boss"):
		dragon = 0.0
		if sumOf(weights) <= 0:
			weights = bosses.map(func(boss): return getChance(boss) / 100.0)
			if sumOf(weights) <= 0:
				weights = equalWeights(bosses)
	var total = dragon + sumOf(weights)
	var rand = randf_range(0, total)
	for i in range(bosses.size()):
		if rand < weights[i]:
			return bosses[i]
		rand -= weights[i]
	return {}


# Called from the patched upgrade_ui.gd right before the dragon intro starts.
# Chooses the boss, and for a custom boss changes the intro text and shows its
# intro_anim on the white intro screen.
func onDragonStart():
	pendingboss = pickBoss()
	var boss = pendingboss
	# The intro animation sets its texts every frame from its own keys, so the
	# key itself is changed (and set back for the dragon).
	setIntroText("To lay the dragon" if boss.is_empty() else "To lay " + boss["name"])
	if !boss.is_empty():
		showBossIntro(boss)


func setIntroText(text):
	var player = Buss.ui.get_node_or_null("AnimationPlayer")
	if player == null || !player.has_animation("DragonStart"):
		return
	var animation = player.get_animation("DragonStart")
	var track = animation.find_track(NodePath("Whiteout/VBoxContainer/Label2:text"), Animation.TYPE_VALUE)
	if track >= 0 && animation.track_get_key_count(track) > 0:
		animation.track_set_key_value(track, 0, text)


func showBossIntro(boss):
	var whiteout = Buss.ui.get_node_or_null("Whiteout")
	if whiteout == null || boss["intro"].is_empty():
		return
	var clips = boss["intro"]["clips"]
	var clip = clips[randi() % clips.size()]
	var path = clip["variants"][0]
	var node
	var native = Vector2.ZERO
	if clip["type"] == "video":
		node = VideoStreamPlayer.new()
		var stream = VideoStreamTheora.new()
		stream.file = path
		node.stream = stream
		node.expand = true
		node.bus = "sfx"
	else:
		node = TextureRect.new()
		node.texture = loadTexture(path)
		node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		native = node.texture.get_size()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Below the intro text, inside the white screen, so it fades out with it.
	whiteout.add_child(node)
	if node is VideoStreamPlayer:
		node.play()
		for i in range(2):
			await get_tree().process_frame
		if !is_instance_valid(node):
			return
		if node.get_video_texture() != null:
			native = node.get_video_texture().get_size()
	var size = fitIntro(native)
	node.size = size
	node.position = Vector2(360 - size.x / 2, 1180 - size.y)
	await get_tree().create_timer(INTRO_REMOVE_AFTER).timeout
	if is_instance_valid(node):
		node.queue_free()


# The lower part of the white intro screen, under the text: 640x600 at most,
# scaled up to 480 wide or 450 tall if smaller, keeping the aspect ratio.
func fitIntro(native: Vector2) -> Vector2:
	var maxsize = Vector2(640, 600)
	var minsize = Vector2(480, 450)
	if native.x <= 0 || native.y <= 0:
		return minsize
	var maxscale = min(maxsize.x / native.x, maxsize.y / native.y)
	var minscale = min(minsize.x / native.x, minsize.y / native.y)
	return native * clampf(1.0, minscale, maxscale)


# Called from the patched GameManager.startBoss() after the boss cutie is made.
func applyBoss(bossname):
	if bossname != "dragon":
		return
	if pendingboss == null:
		pendingboss = pickBoss()
	var boss = pendingboss
	pendingboss = null
	if boss.is_empty():
		return
	var cutie = GameManager.currentcutieinfo
	cutie["custom_boss"] = boss["id"]
	cutie["name"] = boss["name"]
	cutie["chest"] = boss["chest"]
	cutie["bits"] = boss["genitals"]
	cutie["boobsize"] = boss["boobsize"] if boss["boobsize"] >= 0 else randf_range(0.9, 1.2)
	cutie["dicksize"] = boss["dicksize"] if boss["dicksize"] >= 0 else randf_range(0.8, 1.5)
