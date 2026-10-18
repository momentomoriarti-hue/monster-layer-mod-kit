extends RefCounted

# Runs the kit's own scripts (Scripts\*.bat) one after another in a window with
# their output, the same scripts you can run by hand. steps:
#   [{"title": "...", "script": full path of a .bat, "args": [...],
#     "cleanup": [files or folders the step makes, deleted when it is cancelled]}]
# on_done(ok: bool) is called when all steps finished, or one failed or was
# cancelled. Cancel stops the script with everything it started (Godot, FFmpeg).

const UI = preload("res://mlmk_app/ui.gd")

var app
var steps: Array
var on_done
var modal: Dictionary
var log_text: RichTextLabel
var status: Label
var close_button: Button
var thread: Thread
var exit_code = -1
var index = -1
var pid = -1
var cancelled = false
var cancel_button: Button
# Lines "MLMK_<NAME>=<value>" a script prints for the app: {"<NAME>": value}.
var values = {}


func _init(app_, title: String, steps_: Array, on_done_ = null):
	app = app_
	steps = steps_
	on_done = on_done_
	modal = UI.modal(app.overlay(), title, 1100)
	modal["root"].set_meta("task", self)
	status = UI.label("", 30)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal["body"].add_child(status)
	log_text = RichTextLabel.new()
	log_text.custom_minimum_size = Vector2(0, 560)
	log_text.scroll_following = true
	log_text.selection_enabled = true
	log_text.add_theme_font_override("normal_font", load(UI.TEXT_FONT))
	log_text.add_theme_font_override("bold_font", load(UI.BOLD_FONT))
	log_text.add_theme_font_size_override("normal_font_size", 20)
	log_text.add_theme_font_size_override("bold_font_size", 22)
	log_text.add_theme_color_override("default_color", Color(0.9, 0.9, 0.9))
	modal["body"].add_child(log_text)
	var row = UI.hbox(16)
	close_button = UI.button("Working...", 32, 80)
	close_button.disabled = true
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.pressed.connect(func(): modal["root"].queue_free())
	row.add_child(close_button)
	cancel_button = UI.button("Cancel", 32, 80)
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_button.add_theme_color_override("font_color", UI.RED)
	cancel_button.pressed.connect(cancel)
	row.add_child(cancel_button)
	modal["body"].add_child(row)
	_next()


func _next():
	index += 1
	if index >= steps.size():
		_finish(true)
		return
	var step = steps[index]
	status.text = step["title"] + "..."
	log_text.append_text("[b]" + step["title"] + "[/b]\n")
	# The scripts wait for a key at the end unless MLMK_NOPAUSE is set.
	OS.set_environment("MLMK_NOPAUSE", "1")
	var command = "& " + _ps_quote(step["script"])
	for arg in step.get("args", []):
		# "-Name" switches go as they are, everything else quoted.
		var a = str(arg)
		command += " " + (a if a.begins_with("-") && a.substr(1).is_valid_identifier() else _ps_quote(a))
	command += "; Write-Output ('MLMK_EXIT=' + $LASTEXITCODE)"
	var process = OS.execute_with_pipe("powershell.exe", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command])
	if process.is_empty():
		log_text.append_text("[color=#ff5c5c]Can't start PowerShell.[/color]\n")
		_finish(false)
		return
	exit_code = -1
	pid = process["pid"]
	thread = Thread.new()
	thread.start(_read.bind(process["stdio"]))


# Stops the running script and everything it started, then deletes what the
# step was making, so no half-made build is left.
func cancel():
	if cancelled || index >= steps.size():
		return
	cancelled = true
	cancel_button.disabled = true
	status.text = "Cancelling..."
	if pid > 0:
		OS.execute("taskkill", ["/PID", str(pid), "/T", "/F"], [], true)
	# The unfinished files are deleted once the script has stopped (_step_done).


static func _delete(path: String):
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		return
	var dir = DirAccess.open(path)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)
	for d in dir.get_directories():
		_delete(path + "/" + d)
	DirAccess.remove_absolute(path)


static func _ps_quote(s: String) -> String:
	return "'" + s.replace("\\", "/").replace("'", "''") + "'"


func _read(pipe: FileAccess):
	while true:
		var line = pipe.get_line()
		if pipe.get_error() != OK:
			break
		_line.call_deferred(line)
	_step_done.call_deferred()


func _line(line: String):
	line = line.strip_edges(false, true)
	if line.begins_with("MLMK_EXIT="):
		exit_code = int(line.substr(10))
		return
	if line.begins_with("MLMK_") && line.contains("="):
		values[line.substr(5, line.find("=") - 5)] = line.substr(line.find("=") + 1)
		return
	var color = ""
	if line.contains("[ERROR]") || line.contains("REFUSED") || line.contains("DANGER"):
		color = "#ff5c5c"
	elif line.contains("WARNING") || line.begins_with("WARNING"):
		color = "#ffd27d"
	elif line.contains("[OK]") || line.begins_with("Done"):
		color = "#7dff8a"
	var safe = line.replace("[", "[lb]")
	log_text.append_text(("[color=" + color + "]" + safe + "[/color]" if color != "" else safe) + "\n")


func _step_done():
	if thread != null:
		thread.wait_to_finish()
		thread = null
	if cancelled:
		for path in steps[index].get("cleanup", []):
			_delete(String(path))
		log_text.append_text("[color=#ffd27d]Cancelled; the unfinished files were deleted.[/color]\n")
		_finish(false)
	elif exit_code != 0:
		_finish(false)
	else:
		_next()


func _finish(ok: bool):
	cancel_button.visible = false
	if cancelled:
		status.text = "Cancelled."
	else:
		status.text = "Done." if ok else "Failed: see the messages below."
	status.add_theme_color_override("font_color", UI.GREEN if ok else UI.RED)
	close_button.text = "Close"
	close_button.disabled = false
	if on_done != null:
		on_done.call_deferred(ok)
