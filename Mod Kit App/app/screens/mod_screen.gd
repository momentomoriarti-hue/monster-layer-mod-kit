extends Control

# One mod: its name, its Custom Lays and Custom Bosses, its config (mod.cfg and
# mod_settings.cfg), and packing it.

const UI = preload("res://mlmk_app/ui.gd")
const Kit = preload("res://mlmk_app/kit.gd")
const CfgDoc = preload("res://mlmk_app/cfg_doc.gd")
const EditState = preload("res://mlmk_app/edit_state.gd")
const ConfigDialog = preload("res://mlmk_app/config_dialog.gd")
const TaskDialog = preload("res://mlmk_app/task_dialog.gd")
const ListScreen = preload("res://mlmk_app/screens/list_screen.gd")

var app
var mod: String
var is_new: bool
var state
var name_edit: LineEdit
var name_error: Label
var title: Label
var lays_button: Button
var bosses_button: Button
var back_button: Button
var config_button: Button
var pack_button: Button
var launch_button: Button


func _init(mod_: String, is_new_ = false):
	mod = mod_
	is_new = is_new_


func _ready():
	_load_state()
	var columns = UI.three_columns(self)
	var left: VBoxContainer = columns[0]
	var root: VBoxContainer = columns[1]
	var right: VBoxContainer = columns[2]

	back_button = UI.button("Back", 32, 84)
	back_button.pressed.connect(_back)
	left.add_child(back_button)
	left.add_child(UI.spacer(false))
	var delete = UI.button("Delete mod", 28, 72)
	delete.add_theme_color_override("font_color", UI.RED)
	delete.pressed.connect(func(): UI.confirm_delete(app.overlay(), "the mod " + mod, func():
		if app.kit.delete_mod(mod):
			app.back()
		else:
			UI.message(app.overlay(), "Can't delete", "The mod's folder couldn't be moved to the Recycle Bin (is a file in it open in another program?).")))
	left.add_child(delete)
	config_button = UI.button("Config", 32, 84)
	config_button.pressed.connect(_open_config)
	right.add_child(config_button)
	pack_button = UI.button("Pack", 32, 84)
	pack_button.pressed.connect(func(): _pack(false))
	right.add_child(pack_button)
	launch_button = UI.button("Pack and launch", 32, 84)
	launch_button.pressed.connect(func(): _pack(true))
	right.add_child(launch_button)

	title = UI.label("", 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_constant_override("outline_size", 18)
	root.add_child(title)

	root.add_child(UI.label("Mod name", 30))
	name_edit = LineEdit.new()
	name_edit.text = mod
	name_edit.custom_minimum_size = Vector2(0, 80)
	name_edit.add_theme_font_size_override("font_size", 36)
	name_edit.text_submitted.connect(func(_t): _rename())
	name_edit.focus_exited.connect(_rename)
	root.add_child(name_edit)
	name_error = UI.text("", 24)
	name_error.add_theme_color_override("font_color", UI.RED)
	root.add_child(name_error)

	root.add_child(UI.spacer(false))
	lays_button = UI.button("Custom Lays", 44, 140)
	lays_button.pressed.connect(func(): app.open(ListScreen.new(mod, "lay")))
	root.add_child(lays_button)
	bosses_button = UI.button("Custom Bosses", 44, 140)
	bosses_button.pressed.connect(func(): app.open(ListScreen.new(mod, "boss")))
	root.add_child(bosses_button)
	root.add_child(UI.spacer(false))
	var hint = UI.text("Ctrl+S saves the config, Ctrl+Z undoes a change.", 22)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)
	refresh()
	if is_new:
		name_edit.grab_focus.call_deferred()
		name_edit.select_all.call_deferred()


func _load_state():
	state = EditState.new()
	state.add("mod", app.kit.mod_dir(mod) + "/mod.cfg")
	state.add("mod_settings", app.kit.mod_dir(mod) + "/mod_settings.cfg")
	state.changed.connect(refresh)


func refresh():
	if !is_inside_tree():
		return
	title.text = mod + (" *" if state.is_dirty() else "")
	var lays = app.kit.list_characters(mod, "lay")
	var bosses = app.kit.list_characters(mod, "boss")
	lays_button.text = "Custom Lays (" + _count(lays) + ")"
	bosses_button.text = "Custom Bosses (" + _count(bosses) + ")"


static func _count(list: Array) -> String:
	var on = list.filter(func(c): return c["active"]).size()
	return str(list.size()) if on == list.size() else str(on) + " of " + str(list.size())


func _rename():
	var name = name_edit.text.strip_edges()
	if name == mod:
		name_error.text = ""
		return
	var problem = app.kit.rename_mod(mod, name)
	if problem != "":
		name_error.text = problem
		return
	name_error.text = ""
	mod = name
	# The files moved with the folder: read them from there.
	var dirty = state.is_dirty()
	if !dirty:
		_load_state()
	else:
		state.paths["mod"] = app.kit.mod_dir(mod) + "/mod.cfg"
		state.paths["mod_settings"] = app.kit.mod_dir(mod) + "/mod_settings.cfg"
		# The new name is already in the file on disk; keep it in the edits too.
		state.docs["mod"].set_text("name", mod)
	refresh()


func _open_config():
	ConfigDialog.new(app, "Mod config", state, [
		{"title": "Packing", "doc": "mod", "fields": app.kit.schema("mod").filter(func(f): return f["key"] != "name"), "dir": ""},
		{"title": "In the game", "doc": "mod_settings", "fields": app.kit.schema("mod_settings"), "dir": ""},
	])


func shortcut_save() -> bool:
	if state.save():
		refresh()
	else:
		UI.message(app.overlay(), "Can't save", "The config files couldn't be written.")
	return true


func shortcut_undo() -> bool:
	state.do_undo()
	return true


func shortcut_redo() -> bool:
	state.do_redo()
	return true


func _back():
	if !state.is_dirty():
		app.back()
		return
	UI.message(app.overlay(), "Unsaved changes", "Save the changes to the mod's config?", ["Save", "Don't save", "Cancel"], func(i):
		if i == 0:
			state.save()
			app.back()
		elif i == 1:
			app.back())


# Pack: what mod.cfg's pack_as says (the open source zip by default).
# Pack and launch: also builds the game with the mod and starts it from Moded
# Packed, which uses a separate test save.
func _pack(launch: bool):
	if launch:
		app.tutorial.event("pack")
	if state.is_dirty():
		state.save()
	var pack_as = String(state.get_value("mod", "pack_as") if state.get_value("mod", "pack_as") != null else "zip").to_lower()
	var steps = []
	if launch || pack_as in ["pck", "both"]:
		steps.append({"title": "Building the game with the mod", "script": app.kit.script_path("pack-moded.bat"), "args": [mod], "cleanup": [app.kit.root + "/Moded Packed"]})
	if pack_as in ["zip", "both"]:
		steps.append({"title": "Packing the source zip", "script": app.kit.script_path("pack-moded-source.bat"), "args": [mod], "cleanup": [app.kit.root + "/Moded Source/" + mod + " (source).zip"]})
	# The callback runs after the window exists; it finds it through the holder.
	var holder = {}
	holder["task"] = TaskDialog.new(app, ("Pack and launch " if launch else "Pack ") + mod, steps, func(ok):
		var task = holder["task"]
		if !ok:
			return
		var row = UI.hbox(12)
		if pack_as in ["zip", "both"]:
			var zip = UI.button("Open zip folder", 26, 70)
			zip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			zip.pressed.connect(func(): OS.shell_open(app.kit.root + "/Moded Source"))
			row.add_child(zip)
		if pack_as in ["pck", "both"]:
			var pck = UI.button("Open .pck folder", 26, 70)
			pck.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pck.pressed.connect(func(): OS.shell_open(app.kit.root + "/Moded Packed/Release"))
			row.add_child(pck)
		task.modal["body"].add_child(row)
		task.modal["body"].move_child(row, task.modal["body"].get_child_count() - 2)
		if launch:
			var exe = app.kit.moded_packed_exe()
			if exe != "":
				# Started from Moded Packed as its working folder: from the app's own
				# folder the game would find the app's project.godot and run the app.
				var quote = func(s): return "'" + String(s).replace("'", "''") + "'"
				OS.create_process("powershell.exe", ["-NoProfile", "-WindowStyle", "Hidden", "-Command",
					"Start-Process -FilePath " + quote.call(exe) + " -WorkingDirectory " + quote.call(exe.get_base_dir())])
				task.log_text.append_text("[color=#7dff8a]Started the game (test save, your real saves aren't touched).[/color]\n"))
