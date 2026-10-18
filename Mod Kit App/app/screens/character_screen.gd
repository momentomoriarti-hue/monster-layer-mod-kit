extends Control

# One custom Lay or boss. The Lay stands in the middle in the game's own round
# scene (preview.gd).
#   top left:   Lay config (name, body, chance...), the animation to work on,
#               Animation config (its fields), Trigger (plays it as in the
#               game), Simulate fight and its settings (gear)
#   top right:  Save and exit, Cancel
#   bottom left: Hide interface
# Ctrl+S saves, Ctrl+Z / Ctrl+Y undo and redo.

const UI = preload("res://mlmk_app/ui.gd")
const Kit = preload("res://mlmk_app/kit.gd")
const Schema = preload("res://mlmk_app/schema.gd")
const EditState = preload("res://mlmk_app/edit_state.gd")
const ConfigDialog = preload("res://mlmk_app/config_dialog.gd")
const Preview = preload("res://mlmk_app/preview.gd")

const DOC = "cfg"
# The Portrait entry of the list: the picture in the Lay's profile on the "Choose
# your next Lay" screen, and base_species, whose portrait is used without one.
const PORTRAIT = "portrait"
const PORTRAIT_KEYS = ["portrait", "base_species"]

var app
var mod: String
var kind: String
var id: String
var is_new: bool
var state
var fields: Array
var kinds: Array
# What the list offers: the animations, then Portrait (Lays only; bosses have no
# profile screen).
var choices: Array
var preview
# The preview shows the config as it was when it was last prepared.
var prepared_text = ""
var waiting_action = ""

var panel: Control
var anim_select: OptionButton
var name_label: Label
var status: Label
var hide_button: Button
var sim_button: Button
var save_button: Button
var general_button: Button
var config_button: Button
var trigger_button: Button
var gear_button: Button
# During a fight only this button is shown, so the game's bars stay visible.
var stop_button: Button
var sim_settings = {"infinite_stamina": true, "infinite_pleasure": false, "stage": 0}


func _init(mod_: String, kind_: String, id_: String, is_new_ = false):
	mod = mod_
	kind = kind_
	id = id_
	is_new = is_new_


func _ready():
	state = EditState.new()
	state.add(DOC, app.kit.character_cfg(mod, kind, id))
	state.changed.connect(_on_changed)
	fields = app.kit.schema(kind)
	kinds = Schema.kinds_of(fields)
	choices = kinds.duplicate()
	if fields.any(func(f): return f["key"] == "portrait"):
		choices.append(PORTRAIT)

	preview = Preview.new(app)
	add_child(preview)
	preview.simulation_ended.connect(_on_simulation_ended)
	app.game_frame.visible = true
	# The Lay's moans are off while you edit it (the game's other sounds stay).
	app.set_moans(false)

	# Everything but Hide interface goes into panel, so it can be hidden at once.
	panel = UI.full_rect(Control.new())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var margin = UI.full_rect(UI.margin(Control.new(), 20))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)
	var area = margin.get_child(0)
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# The game's screen is in the middle (about 608 px wide); the buttons go on
	# both sides of it.
	var left = UI.vbox(14)
	left.position = Vector2(20, 20)
	left.custom_minimum_size.x = 560
	area.add_child(left)
	var general = UI.button(Kit.KINDS[kind]["one"].capitalize() + " config", 32, 84)
	general.tooltip_text = "Name, body, chance, sizes, traits, portrait, sounds"
	general.pressed.connect(func(): open_config("general"))
	left.add_child(general)
	general_button = general
	anim_select = OptionButton.new()
	anim_select.focus_mode = Control.FOCUS_NONE
	anim_select.custom_minimum_size = Vector2(560, 84)
	anim_select.add_theme_font_size_override("font_size", 32)
	for k in choices:
		anim_select.add_item(Schema.title(k))
	anim_select.item_selected.connect(func(_i): _on_choice_changed())
	anim_select.selected = max(kinds.find("idle"), 0)
	left.add_child(anim_select)
	var config = UI.button("Animation config", 32, 84)
	config.pressed.connect(func(): open_config(_selected_group()))
	left.add_child(config)
	config_button = config
	_update_config_button()
	var trigger = UI.button("Trigger", 32, 84)
	trigger.tooltip_text = "Plays the chosen animation the way it looks in the game"
	trigger.pressed.connect(_trigger)
	left.add_child(trigger)
	trigger_button = trigger
	_update_config_button()
	var sim_row = UI.hbox(8)
	sim_button = UI.button("Simulate fight", 32, 84)
	sim_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sim_button.pressed.connect(_simulate)
	sim_row.add_child(sim_button)
	var gear = UI.small_button("⚙", 38)
	gear.custom_minimum_size = Vector2(84, 84)
	gear.tooltip_text = "Fight settings"
	gear.pressed.connect(_sim_settings)
	sim_row.add_child(gear)
	gear_button = gear
	left.add_child(sim_row)

	var right = UI.vbox(14)
	right.custom_minimum_size.x = 560
	right.position = Vector2(1920 - 40 - 560 - 20, 20)
	area.add_child(right)
	save_button = UI.button("Save and exit", 32, 84)
	save_button.pressed.connect(_save_and_exit)
	right.add_child(save_button)
	var cancel = UI.button("Cancel", 32, 84)
	cancel.pressed.connect(_cancel)
	right.add_child(cancel)
	right.add_child(app.music_button(30, 84))
	name_label = UI.label("", 44)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(name_label)

	status = UI.label("", 30)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.position = Vector2(670, 460)
	status.size = Vector2(580, 0)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(status)

	stop_button = UI.button("Stop fight", 34, 96)
	stop_button.position = Vector2(1920 - 40 - 560, 1080 - 136)
	stop_button.size = Vector2(560, 96)
	stop_button.visible = false
	stop_button.pressed.connect(_simulate)
	add_child(stop_button)

	hide_button = UI.button("Hide interface", 30, 84)
	hide_button.position = Vector2(40, 1080 - 124)
	hide_button.size = Vector2(560, 84)
	hide_button.pressed.connect(_toggle_interface)
	add_child(hide_button)

	_on_changed()
	_refresh_preview()


func _exit_tree():
	if preview != null:
		preview.clear()
	app.game_frame.visible = false
	app.set_moans(true)


func _selected_group() -> String:
	return choices[anim_select.selected]


# Portrait has nothing to trigger: it is shown as soon as it is chosen.
func _update_config_button():
	var portrait = _selected_group() == PORTRAIT
	config_button.text = "Portrait config" if portrait else "Animation config"
	if trigger_button != null:
		trigger_button.visible = !portrait


func _on_choice_changed():
	_update_config_button()
	if _selected_group() == PORTRAIT:
		if preview.current.size() > 0 && !preview.busy && !preview.simulating:
			preview.show_portrait()
	else:
		preview.hide_portrait()


func group_fields(group: String) -> Array:
	if group == PORTRAIT:
		return fields.filter(func(f): return PORTRAIT_KEYS.has(f["key"]))
	var portrait_apart = choices.has(PORTRAIT)
	return fields.filter(func(f): return f["group"] == group && f["key"] != "active" && !(portrait_apart && PORTRAIT_KEYS.has(f["key"])))


func _on_changed():
	var name = state.get_value(DOC, "name")
	name_label.text = (id if name == null || String(name).strip_edges() == "" else String(name)) + (" *" if state.is_dirty() else "")


func _set_status(text: String):
	status.text = text


# ---- Config ----

func open_config(group: String, invalid: Array = []):
	var title = Kit.KINDS[kind]["one"].capitalize() + " config" if group == "general" else "Animation: " + Schema.title(group)
	if group == PORTRAIT:
		title = "Portrait (Choose your next Lay screen)"
	ConfigDialog.new(app, title, state, [
		{"title": "", "doc": DOC, "fields": group_fields(group), "dir": app.kit.character_dir(mod, kind, id), "placeholders": {"base_chance": _default_chance_text()}},
	], invalid, func(): _refresh_preview())


# What an empty base_chance means in this mod: as likely as one species (or the
# dragon), shared with every switched-on custom one (this one counts too).
func _default_chance_text() -> String:
	var others = app.kit.list_characters(mod, kind).filter(func(c): return c["active"] && c["id"] != id).size()
	var n = others + 1
	if kind == "boss":
		return "Empty: as likely as the dragon, 1 / (1 + %d) = %.1f%%" % [n, 100.0 / (1 + n)]
	return "Empty: like one species, 1 / (9 + %d) = %.1f%% of Lays" % [n, 100.0 / (9 + n)]


# ---- Preview ----

# Prepares the preview again when the config changed since the last time, then
# shows the Lay standing (or runs then_do: "trigger" / "simulate").
func _refresh_preview(then_do: String = ""):
	var text = state.docs[DOC].to_text()
	if text == prepared_text && preview.current.size() > 0:
		_after_prepare(then_do)
		return
	if preview.busy:
		waiting_action = then_do
		return
	var missing = ConfigDialog.missing_required(state, DOC, group_fields("general"))
	if missing.size() > 0:
		_set_status("Fill in " + ", ".join(missing) + " in " + Kit.KINDS[kind]["one"] + " config to see the preview.")
		preview.clear()
		return
	_set_status("Preparing the preview...")
	waiting_action = then_do
	preview.prepare(mod, kind, id, text, func(ok):
		if !is_inside_tree():
			return
		if !ok:
			prepared_text = ""
			_set_status("The preview couldn't be made:\n" + preview.last_error)
			preview.clear()
			return
		prepared_text = text
		_set_status("")
		_after_prepare(waiting_action)
		waiting_action = "")


func _after_prepare(then_do: String):
	match then_do:
		"trigger":
			if preview.anim() == null || preview.simulating:
				await preview.show_idle()
			preview.trigger(_selected_group())
		"simulate":
			_start_simulation()
		_:
			if !preview.simulating:
				preview.show_idle()
				if _selected_group() == PORTRAIT:
					preview.show_portrait()


func _trigger():
	app.tutorial.event("trigger")
	_refresh_preview("trigger")


func _simulate():
	if preview.simulating:
		preview.stop_simulation()
		return
	_refresh_preview("simulate")


func _start_simulation():
	sim_button.text = "Stop fight"
	_set_status("")
	panel.visible = false
	hide_button.visible = false
	stop_button.visible = true
	preview.simulate(sim_settings)


func _on_simulation_ended():
	app.tutorial.event("sim_ended")
	_set_status("")
	sim_button.text = "Simulate fight"
	stop_button.visible = false
	panel.visible = true
	hide_button.visible = true
	if _selected_group() == PORTRAIT:
		preview.show_portrait()


func _sim_settings():
	var m = UI.modal(app.overlay(), "Fight settings", 620)
	var body: VBoxContainer = m["body"]
	var stamina = CheckBox.new()
	stamina.text = "Infinite stamina (you can't lose)"
	stamina.button_pressed = sim_settings["infinite_stamina"]
	body.add_child(stamina)
	var pleasure = CheckBox.new()
	pleasure.text = "Infinite Pleasure (the " + Kit.KINDS[kind]["one"] + " never finishes)"
	pleasure.button_pressed = sim_settings["infinite_pleasure"]
	body.add_child(pleasure)
	var row = UI.hbox(12)
	var what = "bosses" if kind == "boss" else "Lays"
	var label = UI.text("Stage: " + what + " defeated before this one", 26)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var stage = SpinBox.new()
	stage.min_value = 0
	stage.max_value = 999
	stage.value = sim_settings["stage"]
	stage.custom_minimum_size = Vector2(160, 64)
	row.add_child(stage)
	body.add_child(row)
	var per_loop = "1 boss per loop of endless mode" if kind == "boss" else "10 Lays per loop of endless mode"
	var note = UI.text("The stage sets the " + Kit.KINDS[kind]["one"] + "'s Pleasure and your stamina use the way the game does at that point of a run (" + per_loop + "). Infinite stamina and Pleasure win over it.", 22)
	body.add_child(note)
	var done = UI.button("Done", 32, 80)
	done.pressed.connect(func():
		sim_settings = {"infinite_stamina": stamina.button_pressed, "infinite_pleasure": pleasure.button_pressed, "stage": int(stage.value)}
		m["root"].queue_free())
	body.add_child(done)


func _toggle_interface():
	panel.visible = !panel.visible
	hide_button.text = "Hide interface" if panel.visible else "Show interface"


# ---- Save, cancel ----

func shortcut_save() -> bool:
	if !state.save():
		UI.message(app.overlay(), "Can't save", "The config file couldn't be written.")
	_on_changed()
	return true


func shortcut_undo() -> bool:
	state.do_undo()
	return true


func shortcut_redo() -> bool:
	state.do_redo()
	return true


func _save_and_exit():
	var missing = ConfigDialog.missing_required(state, DOC, group_fields("general"))
	if missing.size() > 0:
		open_config("general", missing)
		return
	if !state.save():
		UI.message(app.overlay(), "Can't save", "The config file couldn't be written.")
		return
	app.back()


func _cancel():
	if !state.is_dirty() && !is_new:
		state.discard_copied_files()
		app.back()
		return
	var question = "Throw away this new " + Kit.KINDS[kind]["one"] + "?" if is_new else "Throw away your unsaved changes?"
	UI.message(app.overlay(), "Cancel", question, ["Throw away", "Keep editing"], func(i):
		if i != 0:
			return
		state.discard_copied_files()
		if is_new:
			app.kit.delete_character(mod, kind, id)
		app.back())
