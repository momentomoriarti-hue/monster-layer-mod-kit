extends Control

# A mod's Custom Lays or Custom Bosses: one row per Lay or boss with its eye
# button (in the mod / switched off), and Add pinned below the list.

const UI = preload("res://mlmk_app/ui.gd")
const Kit = preload("res://mlmk_app/kit.gd")
const EyeToggle = preload("res://mlmk_app/eye_toggle.gd")
const CharacterScreen = preload("res://mlmk_app/screens/character_screen.gd")

var app
var mod: String
var kind: String
var list: VBoxContainer
var add_button: Button
var back_button: Button


func _init(mod_: String, kind_: String):
	mod = mod_
	kind = kind_


func _ready():
	var info = Kit.KINDS[kind]
	var columns = UI.three_columns(self)
	var root: VBoxContainer = columns[1]
	back_button = UI.button("Back", 32, 84)
	back_button.pressed.connect(func(): app.back())
	columns[0].add_child(back_button)
	var title = UI.label(info["title"], 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 18)
	root.add_child(title)
	var where = UI.text(mod, 26)
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(where)
	list = UI.scroll_list(root)
	add_button = UI.button("Add " + info["one"], 42, 116)
	add_button.pressed.connect(_add)
	root.add_child(add_button)
	refresh()


func refresh():
	if list == null:
		return
	for child in list.get_children():
		child.queue_free()
	var characters = app.kit.list_characters(mod, kind)
	if characters.is_empty():
		var empty = UI.text("Nothing here yet. Press Add " + Kit.KINDS[kind]["one"] + " to make one.", 28)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(empty)
	for c in characters:
		var row = UI.hbox(12)
		var b = UI.button(c["name"], 38, 104)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.modulate = Color.WHITE if c["active"] else Color(1, 1, 1, 0.55)
		var id = c["id"]
		b.pressed.connect(func(): app.open(CharacterScreen.new(mod, kind, id)))
		row.add_child(b)
		var eye = EyeToggle.new()
		eye.custom_minimum_size = Vector2(104, 104)
		eye.on = c["active"]
		eye.pressed.connect(func():
			app.kit.set_active(mod, kind, id, !eye.on)
			refresh())
		row.add_child(eye)
		var delete = UI.button("Delete", 24, 104)
		delete.custom_minimum_size.x = 130
		delete.add_theme_color_override("font_color", UI.RED)
		var title = c["name"]
		delete.pressed.connect(func(): UI.confirm_delete(app.overlay(), title, func():
			if !app.kit.delete_character(mod, kind, id):
				UI.message(app.overlay(), "Can't delete", "The folder couldn't be moved to the Recycle Bin (is a file in it open in another program?).")
			refresh()))
		row.add_child(delete)
		list.add_child(row)


func _add():
	var id = app.kit.create_character(mod, kind)
	app.open(CharacterScreen.new(mod, kind, id, true))
