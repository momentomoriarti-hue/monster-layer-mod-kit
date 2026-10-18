extends Node

# The Monster Layer Mod Kit app. Screens are stacked: the list of mods, one mod,
# its Lays or bosses, one Lay's editor. The window is 16:9 (1920x1080); for
# previews the game runs in its own portrait 720x1280 screen in the middle
# (game_viewport, shown by game_frame), with the app's buttons on the sides.
#
# Ctrl+S saves and Ctrl+Z / Ctrl+Y undo and redo on the screen that is open.

const UI = preload("res://mlmk_app/ui.gd")
const Kit = preload("res://mlmk_app/kit.gd")
const ModsScreen = preload("res://mlmk_app/screens/mods_screen.gd")
const Tutorial = preload("res://mlmk_app/tutorial.gd")

const GAME_SIZE = Vector2(720, 1280)
const SCREEN_SIZE = Vector2(1920, 1080)

var kit
# The game's scenes for previews and simulated fights go into game_viewport,
# shown scaled to the window's height by game_frame.
var game_viewport: SubViewport
var game_frame: SubViewportContainer
var layer: CanvasLayer
var ui_root: Control
var background: TextureRect
var screens: Control
var stack = []
var tutorial
# The app's own settings (music on/off), in its user folder.
const SETTINGS_FILE = "user://mlmk_app.cfg"
var settings = ConfigFile.new()


func _ready():
	var root = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kit-root="):
			root = arg.substr("--kit-root=".length())
	if root == "":
		# Started without the launcher: the workspace is <kit>\Tools\app_workspace.
		root = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	kit = Kit.new(root)
	get_window().title = "Monster Layer Mod Kit"

	# Background, then the game's portrait screen, then the app's UI on top.
	var back_layer = CanvasLayer.new()
	back_layer.layer = -10
	add_child(back_layer)
	background = TextureRect.new()
	background.texture = load(UI.BACKGROUND)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.size = SCREEN_SIZE
	back_layer.add_child(background)

	game_frame = SubViewportContainer.new()
	game_frame.name = "GameFrame"
	game_frame.size = GAME_SIZE
	var scale = SCREEN_SIZE.y / GAME_SIZE.y
	game_frame.scale = Vector2(scale, scale)
	game_frame.position = Vector2((SCREEN_SIZE.x - GAME_SIZE.x * scale) / 2, 0)
	game_frame.visible = false
	add_child(game_frame)
	game_viewport = SubViewport.new()
	game_viewport.size = GAME_SIZE
	game_viewport.handle_input_locally = true
	game_frame.add_child(game_viewport)

	layer = CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	ui_root = UI.full_rect(Control.new())
	ui_root.theme = UI.make_theme()
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui_root)
	screens = UI.full_rect(Control.new())
	screens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(screens)

	settings.load(SETTINGS_FILE)
	set_music(music_on())
	tutorial = Tutorial.new(self)
	add_child(tutorial)
	open(ModsScreen.new())
	if !DirAccess.dir_exists_absolute(kit.mods_dir):
		UI.message(ui_root, "No Mods folder", "Can't find " + kit.mods_dir + ". Start the app with \"Monster Layer Mod Kit.bat\" in the kit folder.")


# ---- Sound ----

func music_on() -> bool:
	return settings.get_value("app", "music", true)


# Mutes or unmutes the game's music bus, and remembers it.
func set_music(on: bool):
	var bus = AudioServer.get_bus_index("music")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, !on)
	settings.set_value("app", "music", on)
	settings.save(SETTINGS_FILE)


# A "Music: On / Off" button that switches the music.
func music_button(font_size = 28, height = 72) -> Button:
	var b = UI.button("", font_size, height)
	var update = func(): b.text = "Music: " + ("On" if music_on() else "Off")
	update.call()
	b.pressed.connect(func():
		set_music(!music_on())
		update.call())
	return b


func set_moans(on: bool):
	var bus = AudioServer.get_bus_index("moans")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, !on)


func open(screen: Control):
	if stack.size() > 0:
		stack[-1].visible = false
	screen.set("app", self)
	UI.full_rect(screen)
	stack.append(screen)
	screens.add_child(screen)


func back():
	var screen = stack.pop_back()
	screen.queue_free()
	var top = stack[-1]
	top.visible = true
	if top.has_method("refresh"):
		top.refresh()


func top_screen():
	return stack[-1] if stack.size() > 0 else null


# Where windows over the current screen go.
func overlay() -> Control:
	return ui_root


func _input(event):
	if !(event is InputEventKey) || !event.pressed || event.echo || !event.ctrl_pressed:
		return
	var screen = top_screen()
	if screen == null:
		return
	var handled = false
	match event.keycode:
		KEY_S:
			handled = screen.has_method("shortcut_save") && screen.shortcut_save()
		KEY_Z:
			if event.shift_pressed:
				handled = screen.has_method("shortcut_redo") && screen.shortcut_redo()
			else:
				handled = screen.has_method("shortcut_undo") && screen.shortcut_undo()
		KEY_Y:
			handled = screen.has_method("shortcut_redo") && screen.shortcut_redo()
	if handled:
		get_viewport().set_input_as_handled()
