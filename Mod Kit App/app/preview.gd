extends Node

# Shows a Lay or boss in the game's own round scene, under the app's screen:
#   prepare()  puts the Lay (with your unsaved edits) into the running game with
#              Player Tools\build\apply-mods.ps1, the same step as packing, so the
#              videos are converted and fitted exactly as in the packed mod;
#   show_idle() the Lay standing in its round, nothing happens until you trigger;
#   trigger()  plays one animation the way the game plays it;
#   simulate() starts a real fight with it (the game's hearts, Pleasure, stamina),
#              optionally with infinite stamina / Pleasure and at a later stage.
# Everything runs in the app's own game copy with its own save folder.

const Kit = preload("res://mlmk_app/kit.gd")
const MAIN_SCENE = "res://Scene/main_scene.tscn"

signal simulation_ended

var app
var game: Node
var current = {}
var busy = false
var thread: Thread
var simulating = false
var sim = {"infinite_stamina": false, "infinite_pleasure": false, "stage": 0}
var sim_end_time = 0
var last_error = ""


func _init(app_):
	app = app_


# ---- Preparing ----

# Copies the mod's settings and this one Lay or boss (cfg_text = the edited
# config, switched on) into Tools\app_preview\source and runs apply-mods.ps1 on
# the app's game copy. done(ok: bool) is called when it finished.
func prepare(mod: String, kind: String, id: String, cfg_text: String, done: Callable):
	if busy:
		return
	busy = true
	# The shown videos keep their files open, and Windows can't replace open
	# files: close the round first.
	clear()
	for i in range(3):
		await get_tree().process_frame
	var kit = app.kit
	var source = kit.root + "/Tools/app_preview/source"
	_remove_dir(source)
	var info = Kit.KINDS[kind]
	var target = source + "/" + info["folder"] + "/" + id
	DirAccess.make_dir_recursive_absolute(target)
	Kit.copy_file(kit.mod_dir(mod) + "/mod_settings.cfg", source + "/mod_settings.cfg")
	var folder = kit.character_dir(mod, kind, id)
	var dir = DirAccess.open(folder)
	if dir:
		for f in dir.get_files():
			if f != info["cfg"]:
				Kit.copy_file(folder + "/" + f, target + "/" + f)
	var doc = Kit.CfgDoc.new().parse(cfg_text)
	doc.set_raw("active", "true")
	Kit.write_text(target + "/" + info["cfg"], doc.to_text())

	var args = ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", kit.root + "/Player Tools/build/apply-mods.ps1",
		"-Source", source, "-Build", ProjectSettings.globalize_path("res://").trim_suffix("/"),
		"-Ffmpeg", kit.root + "/Tools/FFmpeg/ffmpeg.exe", "-Cache", kit.root + "/Tools/media_cache"]
	thread = Thread.new()
	thread.start(func():
		var output = []
		var code = OS.execute("powershell.exe", args, output, true)
		_prepared.call_deferred(code, "\n".join(output), kind, id, done))


func _prepared(code: int, output: String, kind: String, id: String, done: Callable):
	thread.wait_to_finish()
	thread = null
	busy = false
	last_error = ""
	if code != 0:
		last_error = _errors_of(output)
		done.call(false)
		return
	ModSettings.reload()
	CustomLays.reloadAll()
	var found = CustomLays.getLay(id) if kind == "lay" else CustomLays.getBoss(id)
	if found.is_empty():
		last_error = "The game couldn't read it. Fill in the required fields (genitals and chest)."
		done.call(false)
		return
	current = {"kind": kind, "id": id}
	done.call(true)


static func _errors_of(output: String) -> String:
	var lines = []
	for line in output.split("\n"):
		var l = line.strip_edges()
		if l.contains("ERROR") || l.contains("Exception") || l.begins_with("WARNING") || l.contains("must be") || l.contains("not found"):
			lines.append(l)
	return "\n".join(lines.slice(0, 8)) if lines.size() > 0 else output.right(600)


static func _remove_dir(path: String):
	var dir = DirAccess.open(path)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)
	for d in dir.get_directories():
		_remove_dir(path + "/" + d)
	DirAccess.remove_absolute(path)


# ---- Showing ----

func clear():
	simulating = false
	if game != null && is_instance_valid(game):
		game.queue_free()
	game = null
	GameManager.incombat = false


# The Lay standing in its round: the game's UI is hidden, clicks don't thrust and
# triggered strokes don't add Pleasure.
func show_idle():
	_start_scene()
	if Buss.ui != null:
		Buss.ui.visible = false
		Buss.ui.active = false
	await _wait_for_anim()
	if Buss.curanim != null:
		Buss.curanim.blocked = true


# The game's own main scene with its round loaded, as when you start a run: the
# game's sounds and end screens need it.
func _start_scene():
	clear()
	game = load(MAIN_SCENE).instantiate()
	app.game_viewport.add_child(game)
	game.loadLevel("game")
	GameManager.restart()
	GameManager.inrun = false
	if current["kind"] == "boss":
		CustomLays.pendingboss = CustomLays.getBoss(current["id"])
		GameManager.startBoss("dragon", true)
		# Not the end of a run while previewing: the game's end screens need the
		# game's main menu, which isn't loaded in the app.
		GameManager.endboss = false
	else:
		GameManager.currentcutieinfo = CustomLays.generate(CustomLays.getLay(current["id"]), true)
	GameManager.createAnimWithoutFight()


func _wait_for_anim():
	for i in range(30):
		if Buss.curanim != null && is_instance_valid(Buss.curanim) && Buss.curanim.is_inside_tree() && Buss.curanim.active:
			return
		await get_tree().process_frame


func anim():
	return Buss.curanim if Buss.curanim != null && is_instance_valid(Buss.curanim) else null


# Plays one animation the way the game plays it in a round.
func trigger(kind: String):
	var a = anim()
	if a == null:
		return
	match kind:
		"thrust":
			if a.activestate == "idle":
				a.Thrust()
		"pound":
			if a.activestate == "idle":
				a.Pound()
				await get_tree().create_timer(2.0).timeout
				if anim() == a:
					a.EndPound()
		"idle":
			a.returntoidle()
		"free_cum":
			a.freeCum()
		"orgasm":
			a.orgasm()
			# The round ends after the orgasm; show the Lay standing again.
			await get_tree().create_timer(5.0).timeout
			if anim() == a && !simulating:
				show_idle()
		"hypno":
			a.playHypnoAnim("Start")
			await get_tree().create_timer(4.0).timeout
			if anim() == a:
				a.playHypnoAnim("End")
		"intro":
			# The white intro screen with the boss's intro_anim, without starting
			# the fight that follows it in the game.
			var whiteout = Buss.ui.get_node_or_null("Whiteout") if Buss.ui != null else null
			if current["kind"] == "boss" && whiteout != null:
				var boss = CustomLays.getBoss(current["id"])
				var text = whiteout.get_node_or_null("VBoxContainer/Label2")
				if text != null:
					text.text = "To lay " + boss["name"]
				Buss.ui.visible = true
				whiteout.visible = true
				whiteout.modulate = Color.WHITE
				CustomLays.showBossIntro(boss)
				await get_tree().create_timer(CustomLays.INTRO_REMOVE_AFTER).timeout
				if is_instance_valid(whiteout) && !simulating:
					whiteout.visible = false
					Buss.ui.visible = false
		"portrait":
			show_portrait()
		_:
			# egg, lose and kinds added to the kit later: the media the game shows.
			CustomLays.onSpecial(a, kind)


# The Lay's portrait the way its profile on the "Choose your next Lay" screen
# shows it: a square frame the picture fills, cut at the edges (as
# CustomLays.applyPortrait() does). It stays until hide_portrait() or the next
# preview.
var portrait_layer: CanvasLayer


func hide_portrait():
	if portrait_layer != null && is_instance_valid(portrait_layer):
		portrait_layer.queue_free()
	portrait_layer = null


func show_portrait():
	hide_portrait()
	var lay = CustomLays.getLay(current["id"]) if current.size() > 0 else {}
	if lay.is_empty() || game == null:
		return
	var holder = CanvasLayer.new()
	portrait_layer = holder
	holder.layer = 100
	game.add_child(holder)
	var veil = ColorRect.new()
	veil.color = Color(0, 0, 0, 0.75)
	veil.size = Vector2(720, 1280)
	holder.add_child(veil)
	var box = VBoxContainer.new()
	box.position = Vector2(110, 300)
	box.size = Vector2(500, 0)
	box.add_theme_constant_override("separation", 20)
	holder.add_child(box)
	var name = Label.new()
	name.text = lay["name"]
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_override("font", load("res://Reuse/UaCadet-2068.ttf"))
	name.add_theme_font_size_override("font_size", 48)
	box.add_child(name)
	var frame = Panel.new()
	frame.custom_minimum_size = Vector2(500, 500)
	frame.clip_contents = true
	box.add_child(frame)
	if String(lay["portrait"]).ends_with(".ogv"):
		var player = VideoStreamPlayer.new()
		var stream = VideoStreamTheora.new()
		stream.file = lay["portrait"]
		player.stream = stream
		player.expand = true
		player.size = Vector2(500, 500)
		frame.add_child(player)
		player.finished.connect(func():
			player.paused = false
			player.play())
		player.play()
	elif lay["portrait"] != "":
		var picture = TextureRect.new()
		picture.texture = CustomLays.loadTexture(lay["portrait"])
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.size = Vector2(500, 500)
		frame.add_child(picture)
	var note = Label.new()
	note.text = "Shown at 250x250 in the game; the picture or video fills the square, the edges are cut (a video loops)." if lay["portrait"] != "" else "No portrait: the game shows its base species' portrait."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_override("font", load("res://Reuse/Kalam-Regular.ttf"))
	note.add_theme_font_size_override("font_size", 26)
	note.custom_minimum_size.x = 500
	box.add_child(note)


# ---- Simulated fight ----

# stage: how many Lays (or, for a boss, bosses) were defeated before this one;
# the game sets the Lay's Pleasure and stamina from it. Infinite stamina and
# infinite Pleasure win over the stage.
func simulate(settings: Dictionary):
	sim = settings.duplicate()
	_start_scene()
	var stage = int(sim["stage"])
	if current["kind"] == "boss":
		GameManager.endlessloop = stage
		GameManager.currentcombat = 10
		GameManager.endboss = true
	else:
		GameManager.endlessloop = stage / 10
		GameManager.currentcombat = stage % 10
	Perks.restart()
	# The game's beginner hint about hearts would only get in the way here.
	Settings.heartswarning = false
	await _wait_for_anim()
	if Buss.ui != null:
		Buss.ui.visible = true
	GameManager.startCombat()
	if Buss.curanim != null:
		Buss.curanim.blocked = false
	simulating = true
	sim_end_time = 0


func stop_simulation():
	if !simulating:
		return
	simulating = false
	show_idle()
	simulation_ended.emit()


func _process(_delta):
	if !simulating || Buss.ui == null || !is_instance_valid(Buss.ui):
		return
	if sim["infinite_stamina"]:
		Buss.ui.debugnostamloss = true
		if Buss.ui.curstamina > 0:
			Buss.ui.curstamina = 0
			Buss.ui.stamina_bar.value = Buss.ui.maxstamina
	if sim["infinite_pleasure"] && GameManager.incombat:
		var limit = Buss.ui.maxpleasure * 0.9
		if Buss.ui.curpleasure > limit:
			Buss.ui.curpleasure = limit
			Buss.ui.pleasure_bar.value = limit
	# The fight is over (won or lost; a boss after its last round): show the end,
	# then the Lay again.
	var over = !GameManager.incombat && (current["kind"] != "boss" || GameManager.curround >= GameManager.roundlimit || Buss.ui.curstamina >= Buss.ui.maxstamina)
	if over:
		if sim_end_time == 0:
			sim_end_time = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - sim_end_time > 6000:
			stop_simulation()
	else:
		sim_end_time = 0
