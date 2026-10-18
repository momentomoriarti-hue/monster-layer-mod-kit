extends RefCounted

# Load mod from file: picks a mod's source zip or .pck and loads it into Mods
# with Mod Kit App\import-mod.ps1, which checks it first (Windows Defender, the
# source zip checks or check-mod.bat) and never runs anything from it.

const UI = preload("res://mlmk_app/ui.gd")
const TaskDialog = preload("res://mlmk_app/task_dialog.gd")
const ModScreen = preload("res://mlmk_app/screens/mod_screen.gd")

var app
var on_loaded: Callable


func _init(app_, on_loaded_: Callable):
	app = app_
	on_loaded = on_loaded_
	var dialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.zip, *.pck ; Mods (source zip or .pck)"])
	dialog.title = "Load a mod (source zip or .pck)"
	app.overlay().add_child(dialog)
	# The dialog keeps this object alive until a file is chosen.
	dialog.set_meta("import", self)
	dialog.file_selected.connect(func(path):
		dialog.queue_free()
		_run(path, false))
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered_ratio(0.7)


func _run(path: String, accept: bool):
	var args = ["-Root", app.kit.root, "-File", path]
	if accept:
		args += ["-Accept", "yes"]
	var holder = {}
	holder["task"] = TaskDialog.new(app, "Load mod", [
		{"title": "Checking " + path.get_file() + " (nothing of it is run)", "script": app.kit.root + "/Mod Kit App/import-mod.ps1", "args": args},
	], func(ok):
		var task = holder["task"]
		var body: VBoxContainer = task.modal["body"]
		var row = UI.hbox(12)
		if ok:
			var mod = String(task.values.get("MOD", ""))
			on_loaded.call(mod)
			if mod != "":
				var open = UI.button("Open " + mod, 30, 76)
				open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				open.pressed.connect(func():
					task.modal["root"].queue_free()
					app.open(ModScreen.new(mod)))
				row.add_child(open)
		elif task.exit_code == 2:
			var anyway = UI.button("Load anyway", 30, 76)
			anyway.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			anyway.tooltip_text = "Only if you read the report and trust the mod"
			anyway.pressed.connect(func():
				task.modal["root"].queue_free()
				_run(path, true))
			row.add_child(anyway)
		if row.get_child_count() > 0:
			body.add_child(row)
			body.move_child(row, body.get_child_count() - 2))
