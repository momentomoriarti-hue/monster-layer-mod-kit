extends Control

# The first screen: the logo on the left; on the right every mod in Mods as a
# button, with Add mod and Load mod pinned below the list.

const UI = preload("res://mlmk_app/ui.gd")
const Kit = preload("res://mlmk_app/kit.gd")
const ModScreen = preload("res://mlmk_app/screens/mod_screen.gd")
const ImportDialog = preload("res://mlmk_app/import_dialog.gd")

var app
var list: VBoxContainer
var add_button: Button
var load_button: Button
var tutorial_button: Button


func _ready():
	var root = UI.hbox(60)
	add_child(UI.full_rect(UI.margin(root, 40)))

	var left = UI.vbox(24)
	left.custom_minimum_size.x = 760
	root.add_child(left)
	left.add_child(UI.spacer(false))
	var logo = TextureRect.new()
	logo.texture = load(UI.LOGO)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(0, 420)
	left.add_child(logo)
	var title = UI.label("Mod Kit", 72)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 22)
	left.add_child(title)
	left.add_child(UI.spacer(false))
	tutorial_button = UI.button("Tutorial: make your first mod", 30, 80)
	tutorial_button.pressed.connect(func(): app.tutorial.start())
	left.add_child(tutorial_button)

	var right = UI.vbox(18)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(right)
	var top = UI.hbox()
	var heading = UI.label("Your mods", 44)
	top.add_child(heading)
	top.add_child(UI.spacer())
	var music = app.music_button(28, 72)
	music.custom_minimum_size.x = 220
	top.add_child(music)
	var exit = UI.button("Exit", 30, 72)
	exit.custom_minimum_size.x = 180
	exit.pressed.connect(func(): get_tree().quit())
	top.add_child(exit)
	right.add_child(top)
	list = UI.scroll_list(right)
	var row = UI.hbox(18)
	add_button = UI.button("Add mod", 40, 110)
	add_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_button.pressed.connect(_add_mod)
	row.add_child(add_button)
	load_button = UI.button("Load mod from file", 34, 110)
	load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_button.tooltip_text = "A mod's source zip or .pck: checked for safety, never run"
	load_button.pressed.connect(func(): ImportDialog.new(app, func(mod): refresh()))
	row.add_child(load_button)
	right.add_child(row)
	refresh()


func refresh():
	var changes = app.kit.upgrade_mods()
	if changes.size() > 0:
		UI.message(app.overlay(), "Mods updated", "Some mods were made with an older version of the Mod Kit and were updated:\n\n" + "\n".join(changes))
	for child in list.get_children():
		child.queue_free()
	var mods = app.kit.list_mods()
	if mods.is_empty():
		list.add_child(UI.text("No mods yet. Press Add mod to make one.", 30))
	for mod in mods:
		var b = UI.button(app.kit.mod_name(mod), 40, 110)
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.pressed.connect(func(): app.open(ModScreen.new(mod)))
		list.add_child(b)


func _add_mod():
	var name = Kit.unique_name("My Mod", app.kit.list_mods())
	app.kit.create_mod(name)
	app.open(ModScreen.new(name, true))
	app.tutorial.on_first_mod()
