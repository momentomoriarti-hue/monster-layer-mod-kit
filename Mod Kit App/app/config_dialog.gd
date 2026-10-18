extends RefCounted

# A window in the middle of the screen with the fields of a config: one row per
# field, built from the field descriptions (schema.gd), with an info button that
# shows the field's full description. Changes go into an edit_state.gd, so they
# can be undone and are only written on save.
#
# sections: [{"title": "", "doc": state doc id, "fields": [field], "dir": folder
#             for media files (files fields copy the chosen files into it)}]
# invalid:  keys to mark red, with "Fill in the fields" at the top.

const UI = preload("res://mlmk_app/ui.gd")
const CfgDoc = preload("res://mlmk_app/cfg_doc.gd")
const Schema = preload("res://mlmk_app/schema.gd")
const TrimDialog = preload("res://mlmk_app/trim_dialog.gd")
const VIDEO_EXTENSIONS = ["mp4", "m4v", "webm", "mov", "mkv", "avi", "wmv", "flv", "mpg", "mpeg", "gif", "ogv"]

const MEDIA_FILTER = "*.mp4, *.m4v, *.webm, *.mov, *.mkv, *.avi, *.wmv, *.flv, *.mpg, *.mpeg, *.gif, *.ogv, *.png, *.jpg, *.jpeg, *.webp, *.bmp, *.tga ; Videos, GIFs and pictures"
const PICTURE_FILTER = "*.png, *.jpg, *.jpeg, *.webp, *.bmp, *.tga ; Pictures"

var app
var state
var sections: Array
var invalid: Array
var modal: Dictionary
var content: VBoxContainer
var scroll: ScrollContainer
var closed = false
var on_close


func _init(app_, title: String, state_, sections_: Array, invalid_: Array = [], on_close_ = null):
	app = app_
	state = state_
	sections = sections_
	invalid = invalid_
	on_close = on_close_
	modal = UI.modal(app.overlay(), title, 960)
	# The window keeps this object alive while it is open.
	modal["root"].set_meta("dialog", self)
	if invalid.size() > 0:
		var warning = UI.label("Fill in the fields", 32)
		warning.add_theme_color_override("font_color", UI.RED)
		warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		modal["body"].add_child(warning)
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 600)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content = UI.vbox(22)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	modal["body"].add_child(scroll)
	var hint = UI.text("Ctrl+Z undoes a change. Changes are kept when you close this window; save them with Ctrl+S.", 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal["body"].add_child(hint)
	var done = UI.button("Done", 34, 84)
	done.pressed.connect(close)
	modal["body"].add_child(done)
	state.changed.connect(_rebuild)
	_rebuild()


func close():
	if closed:
		return
	closed = true
	state.changed.disconnect(_rebuild)
	modal["root"].queue_free()
	if on_close != null:
		on_close.call()


func _rebuild():
	if closed:
		return
	var at = scroll.scroll_vertical
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	for section in sections:
		if section.get("title", "") != "":
			var head = UI.label(section["title"], 36)
			head.add_theme_color_override("font_color", Color("#ffd27d"))
			content.add_child(head)
		for field in section["fields"]:
			content.add_child(_row(section, field))
	await app.get_tree().process_frame
	if !closed:
		scroll.scroll_vertical = at


# ---- Rows ----

func _row(section: Dictionary, field: Dictionary) -> Control:
	var key: String = field["key"]
	var raw = state.get_raw(section["doc"], key)
	var value = null if raw == null else CfgDoc.unquote(raw)
	var box = UI.vbox(8)
	var head = UI.hbox(10)
	var name = UI.label(field_title(field), 28)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.tooltip_text = key
	name.mouse_filter = Control.MOUSE_FILTER_PASS
	if invalid.has(key):
		name.add_theme_color_override("font_color", UI.RED)
	head.add_child(name)
	if raw != null && !field["required"]:
		var reset = UI.small_button("Default", 20)
		reset.custom_minimum_size = Vector2(110, 52)
		reset.tooltip_text = "Use the default: " + str(field["default"])
		reset.pressed.connect(func(): state.set_field(section["doc"], key, null))
		head.add_child(reset)
	var info = UI.info_button()
	info.pressed.connect(func(): show_info(app, field))
	head.add_child(info)
	box.add_child(head)
	box.add_child(_editor(section, field, value))
	if invalid.has(key) && (value == null || String(value).strip_edges() == ""):
		var need = UI.text("Fill in this field", 22)
		need.add_theme_color_override("font_color", UI.RED)
		box.add_child(need)
	return box


# Plain-language names of the fields; the key in the config file is shown on the
# name's tooltip and in the info window. {who} = "opponent" or "boss".
const TITLES = {
	"active": "Switched on in the mod",
	"name": "Name shown in the game",
	"genitals": "Genitals",
	"chest": "Chest",
	"base_chance": "Chance to appear (empty = like any other {kind})",
	"chance_per_defeated": "Additional chance to appear per previously defeated {who}",
	"max_chance": "Highest chance it can reach",
	"min_defeated": "Appears only after this many defeated {who}s",
	"max_defeated": "Disappears after this many defeated {who}s",
	"boob_size": "Boob size",
	"dick_size": "Dick size",
	"pronoun": "Pronouns shown in its profile",
	"base_species": "Species it is based on (voice, attacks; portrait when none is set)",
	"portrait": "Portrait picture",
	"traits": "Fixed traits (up to 3)",
	"mute_native_plap_sound": "Mute the game's plap sounds",
	"mute_native_moan": "Mute the game's moans",
	"disable_anim_acceleration_with_pleasure": "Don't speed up the round as Pleasure rises",
	"anim_acceleration_steps": "Sped-up copies of each video (smoother speed-up, bigger mod)",
	"downgrade_all_animations_fps_to": "Highest frame rate of the videos (fps)",
	"disable_default_lays": "Only custom Lays appear (no normal Lays or rare characters)",
	"disable_default_boss": "A custom boss always replaces the dragon",
	"pack_as": "What Pack makes",
}
const KIND_TITLES = {
	"anim": "Videos, GIFs or pictures (one is picked at random each time)",
	"anim_speed_modifier": "Playback speed (1 = normal; ignored when fitted)",
	"auto_fit_anim_length": "Fit the whole video to the animation's length",
	"anim_reset_on_pause": "Start from the beginning on every stroke",
}


static func field_title(field: Dictionary) -> String:
	var key: String = field["key"]
	var group: String = field.get("group", "general")
	if group != "general":
		var part = "auto_fit_anim_length" if key == "auto_fit_" + group + "_anim_length" else key.replace(group + "_", "")
		if KIND_TITLES.has(part):
			return KIND_TITLES[part]
	if TITLES.has(key):
		var boss = field.get("owner", "") == "boss"
		return TITLES[key].replace("{who}", "boss" if boss else "opponent").replace("{kind}", "boss (as likely as the dragon)" if boss else "species")
	return key.replace("_", " ").capitalize()


static func show_info(app_, field: Dictionary):
	var text = String(field["description"])
	text = text.left(1).to_upper() + text.substr(1)
	text += "\n\nDefault: " + String(field["default"])
	if field["required"]:
		text += "\nRequired."
	var m = UI.message(app_.overlay(), field_title(field), text)
	var key = UI.text("In the config file: " + String(field["key"]), 20)
	key.modulate = Color(1, 1, 1, 0.7)
	m["body"].add_child(key)
	m["body"].move_child(key, 1)


func _editor(section: Dictionary, field: Dictionary, value) -> Control:
	match field["type"]:
		"bool":
			return _bool_editor(section, field, value)
		"enum":
			return _free_editor(section, field, value) if field["free"] else _enum_editor(section, field, value)
		"files":
			return _files_editor(section, field, value)
		"list":
			return _list_editor(section, field, value)
		_:
			return _line_editor(section, field, value)


func _bool_editor(section, field, value) -> Control:
	var check = CheckButton.new()
	var current = value if value != null else Schema.default_value(field)
	check.button_pressed = String(current).to_lower() == "true"
	check.text = "Yes" if check.button_pressed else "No"
	check.add_theme_font_override("font", load(UI.TEXT_FONT))
	check.add_theme_font_size_override("font_size", 26)
	check.focus_mode = Control.FOCUS_NONE
	check.toggled.connect(func(on): state.set_field(section["doc"], field["key"], "true" if on else "false"))
	return check


func _enum_editor(section, field, value) -> Control:
	var option = OptionButton.new()
	option.focus_mode = Control.FOCUS_NONE
	# Long items (defaults like "one species picked from...") mustn't widen the window.
	option.fit_to_longest_item = false
	option.clip_text = true
	option.add_theme_font_override("font", load(UI.TEXT_FONT))
	option.add_theme_font_size_override("font_size", 28)
	var offset = 0
	if !field["required"]:
		var d = String(field["default"])
		option.add_item("Default (" + d + ")" if d.length() <= 24 else "Default (see i)")
		offset = 1
	elif value == null:
		option.add_item("Choose...")
		offset = 1
	for o in field["options"]:
		option.add_item(o)
	var index = field["options"].find(value) if value != null else -1
	option.selected = index + offset if index >= 0 else 0
	option.item_selected.connect(func(i):
		if i < offset:
			if !field["required"]:
				state.set_field(section["doc"], field["key"], null)
		else:
			state.set_field(section["doc"], field["key"], CfgDoc.quote(field["options"][i - offset])))
	return option


# A word from the list or a number (sizes).
func _free_editor(section, field, value) -> Control:
	var row = UI.hbox(8)
	var edit = _make_line(field, value)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	var pick = MenuButton.new()
	pick.text = "Pick"
	pick.flat = false
	pick.add_theme_font_size_override("font_size", 26)
	for o in field["options"]:
		pick.get_popup().add_item(o)
	pick.get_popup().id_pressed.connect(func(i): state.set_field(section["doc"], field["key"], CfgDoc.quote(field["options"][i])))
	row.add_child(pick)
	var convert = func(text):
		text = text.strip_edges()
		if text == "":
			return null if !field["required"] else ""
		return text if text.is_valid_float() else CfgDoc.quote(text)
	_connect_commit(edit, convert, section, field)
	return row


func _line_editor(section, field, value) -> Control:
	var edit = _make_line(field, value)
	# A placeholder the screen worked out (base_chance: the chance in this mod).
	if section.get("placeholders", {}).has(field["key"]):
		edit.placeholder_text = section["placeholders"][field["key"]]
	var convert
	if field["type"] == "number":
		convert = func(text):
			text = text.strip_edges()
			if text == "":
				return null
			if field["integer"] && !text.is_valid_int():
				return false
			if !text.is_valid_float():
				return false
			return text
	else:
		convert = func(text):
			if text.strip_edges() == "" && !field["required"]:
				return null
			return CfgDoc.quote(text)
	_connect_commit(edit, convert, section, field)
	return edit


func _make_line(field, value) -> LineEdit:
	var edit = LineEdit.new()
	edit.text = "" if value == null else String(value)
	edit.placeholder_text = "Default: " + String(field["default"])
	edit.custom_minimum_size = Vector2(0, 64)
	edit.select_all_on_focus = true
	return edit


# convert(text) returns the raw value, null to unset, or false when the text
# isn't valid (the field turns red and nothing changes).
func _connect_commit(edit: LineEdit, convert: Callable, section, field):
	var commit = func(_text = ""):
		if closed || !is_instance_valid(edit):
			return
		var raw = convert.call(edit.text)
		if raw is bool && raw == false:
			edit.add_theme_color_override("font_color", UI.RED)
			return
		edit.remove_theme_color_override("font_color")
		state.set_field(section["doc"], field["key"], raw)
	edit.text_submitted.connect(commit)
	edit.focus_exited.connect(commit)


func _files_editor(section, field, value) -> Control:
	var box = UI.vbox(8)
	var files = split_list(value)
	for file in files:
		var row = UI.hbox(8)
		var name = UI.text(file, 24)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		if VIDEO_EXTENSIONS.has(file.get_extension().to_lower()):
			var cut = UI.small_button("✂", 26)
			cut.tooltip_text = "Trim this video or GIF"
			cut.pressed.connect(func(): open_trim(section, field, file))
			row.add_child(cut)
		var remove = UI.small_button("X", 24)
		remove.tooltip_text = "Remove from this field (the file stays in the folder)"
		remove.pressed.connect(func():
			var rest = files.filter(func(f): return f != file)
			state.set_field(section["doc"], field["key"], null if rest.is_empty() else CfgDoc.quote(", ".join(rest))))
		row.add_child(remove)
		box.add_child(row)
	var add = UI.button("Add files..." if field["multi"] else "Choose file...", 28, 70)
	add.pressed.connect(func(): _pick_files(section, field, files))
	box.add_child(add)
	return box


func _pick_files(section, field, files: Array):
	var dialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES if field["multi"] else FileDialog.FILE_MODE_OPEN_FILE
	var pictures_only = String(field["typetext"]).contains("picture") && !String(field["typetext"]).contains("video")
	dialog.filters = PackedStringArray([PICTURE_FILTER if pictures_only else MEDIA_FILTER])
	dialog.title = "Choose " + ("pictures" if pictures_only else "videos, GIFs or pictures")
	app.overlay().add_child(dialog)
	var done = func(paths):
		var names = files.duplicate() if field["multi"] else []
		var added = []
		for path in paths:
			var copied = copy_into(section["dir"], path)
			if copied != "" && !names.has(copied):
				names.append(copied)
				added.append(copied)
		dialog.queue_free()
		if names.size() > 0:
			state.set_field(section["doc"], field["key"], CfgDoc.quote(", ".join(names)))
		# Offer to trim each new video or GIF, one after another.
		offer_trim(section, field, added.filter(func(f): return VIDEO_EXTENSIONS.has(String(f).get_extension().to_lower())))
	dialog.files_selected.connect(done)
	dialog.file_selected.connect(func(path): done.call([path]))
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered_ratio(0.8)


func offer_trim(section, field, files: Array):
	if files.is_empty() || closed:
		return
	var file = files[0]
	var rest = files.slice(1)
	UI.message(app.overlay(), "Trim the video?", "Do you want to trim " + file + "? You can cut off its start and end, frame by frame.", ["Trim", "No"], func(i):
		if i == 0:
			open_trim(section, field, file, func(): offer_trim(section, field, rest))
		else:
			offer_trim(section, field, rest))


# Opens the trimmer; a trimmed copy takes the file's place in the field.
func open_trim(section, field, file: String, then = null):
	var on_trimmed = func(new_name):
		if new_name != "" && !closed:
			state.copied_files[section["dir"] + "/" + new_name] = true
			var list = split_list(state.get_value(section["doc"], field["key"]))
			var i = list.find(file)
			if i >= 0:
				list[i] = new_name
			else:
				list.append(new_name)
			state.set_field(section["doc"], field["key"], CfgDoc.quote(", ".join(list)))
		if then != null:
			then.call()
	var trim = TrimDialog.new(app, section["dir"] + "/" + file, on_trimmed, game_length_text(section, field))
	app.overlay().add_child(trim)


# How long the animation of a files field lasts in the game, for the trimmer:
# from the "fitted length" in the description of its auto_fit field.
static func game_length_text(section, field) -> String:
	var group = String(field.get("group", "general"))
	var title = Schema.title(group)
	if group == "idle":
		return "The idle has no fixed length in the game: it plays at the video's own speed, looped."
	for f in section["fields"]:
		if f["key"] == "auto_fit_" + group + "_anim_length":
			var d = String(f["description"])
			var i = d.find("fitted length:")
			if i >= 0:
				d = d.substr(i + "fitted length:".length()).strip_edges()
				var end = d.find(". true")
				d = d.left(end if end > 0 else 160)
				return "In the game, " + title + " lasts " + d + ". With \"Fit the whole video to the animation's length\" on, the part you keep is squeezed or stretched to it."
	if group != "general":
		return title + " has no fixed length in the game: it plays at the video's own speed."
	return ""


# Copies a chosen file into the Lay's folder (files must be in it) and returns
# the name it has there. A different file with the same name gets " (2)".
func copy_into(dir: String, path: String) -> String:
	path = path.replace("\\", "/")
	if path.get_base_dir().simplify_path() == dir.simplify_path():
		return path.get_file()
	var name = path.get_file()
	var target = dir + "/" + name
	var n = 2
	while FileAccess.file_exists(target):
		if FileAccess.get_file_as_bytes(target).size() == FileAccess.get_file_as_bytes(path).size() && FileAccess.get_md5(target) == FileAccess.get_md5(path):
			return target.get_file()
		name = path.get_file().get_basename() + " (" + str(n) + ")." + path.get_extension()
		target = dir + "/" + name
		n += 1
	if DirAccess.copy_absolute(path, target) != OK:
		UI.message(app.overlay(), "Can't copy the file", path)
		return ""
	state.copied_files[target] = true
	return name


func _list_editor(section, field, value) -> Control:
	var grid = GridContainer.new()
	grid.columns = 3
	var chosen = split_list(value)
	# The game's own words for each id, from the field's description: thrust+ "...".
	var says = {}
	for m in RegEx.create_from_string("([a-z]+[+-])\\s+\"([^\"]+)\"").search_all(String(field["typetext"])):
		says[m.get_string(1)] = m.get_string(2)
	for o in field["options"]:
		var check = Button.new()
		check.toggle_mode = true
		check.button_pressed = chosen.has(o)
		check.text = ("✓ " if check.button_pressed else "") + o
		check.custom_minimum_size = Vector2(250, 56)
		check.focus_mode = Control.FOCUS_NONE
		check.add_theme_font_override("font", load(UI.TEXT_FONT))
		check.add_theme_font_size_override("font_size", 26)
		if check.button_pressed:
			check.add_theme_color_override("font_color", UI.GREEN)
			check.add_theme_color_override("font_pressed_color", UI.GREEN)
		check.tooltip_text = says.get(o, "")
		check.disabled = !check.button_pressed && field["max"] > 0 && chosen.size() >= field["max"]
		check.toggled.connect(func(on):
			var list = chosen.duplicate()
			if on:
				list.append(o)
			else:
				list.erase(o)
			state.set_field(section["doc"], field["key"], null if list.is_empty() else CfgDoc.quote(", ".join(list))))
		grid.add_child(check)
	return grid


static func split_list(value) -> Array:
	if value == null:
		return []
	var text = String(value).strip_edges().trim_prefix("[").trim_suffix("]")
	var result = []
	for part in text.split(","):
		var p = part.strip_edges().trim_prefix("\"").trim_suffix("\"").strip_edges()
		if p != "":
			result.append(p)
	return result


# Keys of required fields that have no value yet.
static func missing_required(state_, doc: String, fields: Array) -> Array:
	var missing = []
	for field in fields:
		if !field["required"]:
			continue
		var value = state_.get_value(doc, field["key"])
		if value == null || String(value).strip_edges() == "":
			missing.append(field["key"])
	return missing
