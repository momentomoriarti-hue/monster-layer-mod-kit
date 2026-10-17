extends Node

# Settings for the whole mod, from mod_settings.cfg in the mod kit folder.
# Scripts\apply-mods.ps1 copies it to res://mod_kit/mod_settings.cfg at pack time.

const PATH = "res://mod_kit/mod_settings.cfg"

var config = ConfigFile.new()


func _ready() -> void :
	# Parsed from text with the UTF-8 BOM removed, since some editors (Notepad) add one.
	var text = FileAccess.get_file_as_string(PATH).trim_prefix(char(0xFEFF))
	if text == "" || config.parse(text) != OK:
		push_warning("[ModSettings] Can't read mod_settings.cfg, defaults are used.")


func getBool(key, default = false):
	return str(config.get_value("settings", key, default)).to_lower() == "true"
