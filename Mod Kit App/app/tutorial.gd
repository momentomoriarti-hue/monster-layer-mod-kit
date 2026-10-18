extends CanvasLayer

# The first-mod tutorial: leads through making a mod step by step. Each step
# frames the button to press and says what to do in a bubble next to it; it
# moves on by itself once that is done (or with Next). It starts by itself the
# first time you press Add mod, and from the Tutorial button on the first screen.

const UI = preload("res://mlmk_app/ui.gd")
const DONE_FILE = "user://tutorial.cfg"

var app
var step = -1
var steps = []
var events = {}
var frame: Panel
var bubble: PanelContainer
var bubble_text: Label
var counter: Label


func _init(app_):
	app = app_
	layer = 60
	_make_steps()


func _ready():
	frame = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.0)
	style.set_border_width_all(6)
	style.border_color = Color("#ffd27d")
	style.set_corner_radius_all(14)
	frame.add_theme_stylebox_override("panel", style)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.visible = false
	add_child(frame)

	bubble = PanelContainer.new()
	var bstyle = UI.panel_style(0.97)
	bstyle.border_color = Color("#ffd27d")
	bubble.add_theme_stylebox_override("panel", bstyle)
	bubble.custom_minimum_size = Vector2(440, 0)
	bubble.theme = UI.make_theme()
	bubble.visible = false
	add_child(bubble)
	var box = UI.vbox(14)
	bubble.add_child(box)
	counter = UI.label("", 24)
	counter.add_theme_color_override("font_color", Color("#ffd27d"))
	box.add_child(counter)
	bubble_text = UI.text("", 26)
	bubble_text.custom_minimum_size.x = 390
	box.add_child(bubble_text)
	var row = UI.hbox(12)
	var next = UI.button("Next", 26, 60)
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next.pressed.connect(_next)
	row.add_child(next)
	var end = UI.button("End tutorial", 26, 60)
	end.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	end.pressed.connect(finish)
	row.add_child(end)
	box.add_child(row)


func is_done() -> bool:
	var cfg = ConfigFile.new()
	return cfg.load(DONE_FILE) == OK && cfg.get_value("tutorial", "done", false)


func start(from = 0):
	events.clear()
	step = from
	_show()


# Called by Add mod: the tutorial starts the first time, at the step after it.
func on_first_mod():
	if step < 0 && !is_done():
		start(1)


func event(name: String):
	events[name] = true


func finish():
	step = -1
	frame.visible = false
	bubble.visible = false
	var cfg = ConfigFile.new()
	cfg.set_value("tutorial", "done", true)
	cfg.save(DONE_FILE)


func _next():
	if step < 0:
		return
	step += 1
	if step >= steps.size():
		finish()
		return
	events.clear()
	_show()


func _show():
	bubble.visible = true
	counter.text = "Tutorial " + str(step + 1) + " / " + str(steps.size())
	bubble_text.text = steps[step]["text"]


func _process(_delta):
	if step < 0:
		return
	var s = steps[step]
	if s["done"].call():
		_next()
		return
	var target = s["target"].call()
	if target != null && is_instance_valid(target) && target.is_visible_in_tree():
		var rect: Rect2 = target.get_global_rect().grow(8)
		frame.position = rect.position
		frame.size = rect.size
		frame.visible = true
		_place_bubble(rect)
	else:
		# Nothing to point at (a fight is running, or the screen isn't open yet):
		# beside the game's screen, on the right.
		frame.visible = false
		bubble.position = Vector2(1440, 330)


# Buttons in the side columns get the bubble in the other column, so it covers
# neither them nor the game's screen; others get it below, above or beside them.
func _place_bubble(rect: Rect2):
	var size = bubble.size
	if rect.end.x < 700:
		bubble.position = Vector2(1440, 330)
		return
	if rect.position.x > 1220:
		bubble.position = Vector2(40, 560)
		return
	var pos = Vector2(rect.position.x, rect.end.y + 16)
	if pos.y + size.y > 1060:
		pos.y = rect.position.y - size.y - 16
	if pos.y < 20:
		pos = Vector2(rect.end.x + 16, rect.position.y)
		if pos.x + size.x > 1900:
			pos.x = rect.position.x - size.x - 16
	pos.x = clampf(pos.x, 20, 1900 - size.x)
	pos.y = clampf(pos.y, 20, 1060 - size.y)
	bubble.position = pos


# ---- What the steps look at ----

func _top(script_name: String):
	var screen = app.top_screen()
	if screen != null && String(screen.get_script().resource_path).ends_with(script_name):
		return screen
	return null


func _prop(screen_script: String, property: String):
	var screen = _top(screen_script)
	return screen.get(property) if screen != null else null


func _dialog():
	for child in app.overlay().get_children():
		if child.has_meta("dialog") && !child.is_queued_for_deletion():
			return child.get_meta("dialog")
	return null


# The Back button of the screen that is open (to get back to the mod's screen).
func _back_button():
	var screen = app.top_screen()
	if screen == null:
		return null
	for name in ["back_button"]:
		if screen.get(name) != null:
			return screen.get(name)
	return null


func _character():
	return _top("character_screen.gd")


func _value(key: String):
	var c = _character()
	return c.state.get_value(c.DOC, key) if c != null else null


func _make_steps():
	steps = [
		{"text": "Welcome! Let's make your first mod. Press Add mod.",
			"target": func(): return _prop("mods_screen.gd", "add_button"),
			"done": func(): return _top("mod_screen.gd") != null},
		{"text": "This is your new mod. Type its name here (you can change it any time), then press Next.",
			"target": func(): return _prop("mod_screen.gd", "name_edit"),
			"done": func(): return _top("list_screen.gd") != null},
		{"text": "Press Custom Lays: the opponents of your mod. (Custom Bosses can replace the dragon; they work the same way.)",
			"target": func(): return _prop("mod_screen.gd", "lays_button"),
			"done": func(): return _top("list_screen.gd") != null},
		{"text": "Press Add Lay to make your first opponent.",
			"target": func(): return _prop("list_screen.gd", "add_button"),
			"done": func(): return _character() != null},
		{"text": "This is your Lay, standing in the game's own round. Press Lay config to choose its body.",
			"target": func(): return _prop("character_screen.gd", "general_button"),
			"done": func(): return _dialog() != null},
		{"text": "Choose genitals and chest; that's all a Lay needs. Every other field is optional, and its i button explains it. Then press Done.",
			"target": func(): return _dialog().modal["panel"] if _dialog() != null else null,
			"done": func(): return _dialog() == null && _value("genitals") != null && _value("chest") != null},
		{"text": "Now its animation. Choose Thrust in this list: it plays on every thrust, and is used for every animation you don't set.",
			"target": func(): return _prop("character_screen.gd", "anim_select"),
			"done": func(): return _character() != null && _character()._selected_group() == "thrust"},
		{"text": "Press Animation config.",
			"target": func(): return _prop("character_screen.gd", "config_button"),
			"done": func(): return _dialog() != null},
		{"text": "Press Add files... and pick your video, GIF or picture. The app then offers to trim it: cut off its start and end frame by frame (the scissors button next to a file does it later too). Turn on Fit the whole video to the animation's length: it then plays in one thrust (1 second). Then press Done at the bottom.",
			"target": func(): return _dialog().modal["panel"] if _dialog() != null else null,
			"done": func(): return _dialog() == null && _value("thrust_anim") != null},
		{"text": "Press Trigger to see your animation the way it looks in the game.",
			"target": func(): return _prop("character_screen.gd", "trigger_button"),
			"done": func(): return events.has("trigger")},
		{"text": "Press Simulate fight for a real fight with your Lay; the gear next to it gives you infinite stamina or Pleasure. Press Stop fight when you're done.",
			"target": func(): return _prop("character_screen.gd", "sim_button"),
			"done": func(): return events.has("sim_ended")},
		{"text": "Now its portrait, shown in its profile on the Choose your next Lay screen. Choose Portrait in this list (or press Next to skip it): it is shown right away.",
			"target": func(): return _prop("character_screen.gd", "anim_select"),
			"done": func(): return _character() != null && _character()._selected_group() == "portrait"},
		{"text": "Press Portrait config, then Choose file... and pick a picture, GIF or video: a square one fits best (others are cut at the edges, videos loop). When you're done, press Done at the bottom of the window: the portrait is shown here as the game shows it.",
			"target": func(): return _dialog().modal["panel"] if _dialog() != null else _prop("character_screen.gd", "config_button"),
			"done": func(): return _dialog() == null && _value("portrait") != null},
		{"text": "Happy with it? Press Save and exit (Ctrl+S saves too, Ctrl+Z undoes a change).",
			"target": func(): return _prop("character_screen.gd", "save_button"),
			"done": func(): return _top("list_screen.gd") != null},
		{"text": "Your Lay is in the mod: the eye button switches it on and off. Press Back.",
			"target": func(): return _prop("list_screen.gd", "back_button"),
			"done": func(): return _top("mod_screen.gd") != null},
		{"text": "To see your Lay at once in the game, without waiting for it among the normal Lays: press Config, turn on Only custom Lays appear, then Done. (Turn it off again before you share the mod, if you like; Next skips this.)",
			"target": func(): return _dialog().modal["panel"] if _dialog() != null else _prop("mod_screen.gd", "config_button"),
			"done": func(): return _dialog() == null && _top("mod_screen.gd") != null && String(_top("mod_screen.gd").state.get_value("mod_settings", "disable_default_lays")) == "true"},
		{"text": "Now play it. On your mod's screen (press Back until you're there), press Pack and launch: the game starts with your mod, with a separate test save, so your real saves are safe.",
			"target": func(): return _prop("mod_screen.gd", "launch_button") if _top("mod_screen.gd") != null else _back_button(),
			"done": func(): return events.has("pack")},
		{"text": "Done! To share your mod, press Pack: it makes an open source zip in Moded Source that players can check and build themselves. Have fun, and tell me what you made!",
			"target": func(): return _prop("mod_screen.gd", "pack_button"),
			"done": func(): return false},
	]
