extends RefCounted

# A config file (lay.cfg, boss.cfg, mod_settings.cfg, mod.cfg) edited as text, so
# its comments stay exactly as they are. A field is "set" when it has an active
# line ("key=value"); a commented line (";key=value") means it isn't set and the
# game uses the default. Setting a field rewrites its active line, or uncomments
# its commented line; unsetting it comments the line out again.

var lines: Array = []
var newline = "\n"


func parse(text: String):
	text = text.trim_prefix(char(0xFEFF))
	newline = "\r\n" if text.contains("\r\n") else "\n"
	lines = Array(text.replace("\r\n", "\n").split("\n"))
	return self


func duplicate_doc():
	var copy = get_script().new()
	copy.lines = lines.duplicate()
	copy.newline = newline
	return copy


func to_text() -> String:
	return newline.join(PackedStringArray(lines))


func _line_key(line: String, commented: bool) -> String:
	var s = line.strip_edges()
	if commented:
		# Only ";key=value": the field's own default line. Examples inside the
		# descriptions are indented (";   key=...") and aren't fields.
		if !s.begins_with(";") || s.length() < 2 || s[1] == " " || s[1] == "	":
			return ""
		s = s.substr(1)
	elif s.begins_with(";") || s.begins_with("["):
		return ""
	var eq = s.find("=")
	if eq <= 0:
		return ""
	var key = s.substr(0, eq).strip_edges()
	# Only plain field names; comment text like "; Type: ..." has spaces or colons.
	for c in key:
		if !(c == "_" || (c >= "a" && c <= "z") || (c >= "0" && c <= "9")):
			return ""
	return key


func _find(key: String, commented: bool) -> int:
	for i in range(lines.size()):
		if _line_key(lines[i], commented) == key:
			return i
	return -1


func is_set(key: String) -> bool:
	return _find(key, false) >= 0


# The raw value text after "=" (quotes kept), or null when the field isn't set.
func get_raw(key: String):
	var i = _find(key, false)
	if i < 0:
		return null
	var s = String(lines[i]).strip_edges()
	return s.substr(s.find("=") + 1).strip_edges()


# The value without quotes, or null when the field isn't set.
func get_value(key: String):
	var raw = get_raw(key)
	if raw == null:
		return null
	return unquote(raw)


# The value of the commented line (";key=value"), without quotes, or null.
func get_commented_value(key: String):
	var i = _find(key, true)
	if i < 0:
		return null
	var s = String(lines[i]).strip_edges().substr(1)
	return unquote(s.substr(s.find("=") + 1).strip_edges())


func set_raw(key: String, raw: String):
	var line = key + "=" + raw
	var i = _find(key, false)
	if i < 0:
		i = _find(key, true)
	if i >= 0:
		lines[i] = line
		return
	# Not in the file at all: add it at the end of the file.
	while lines.size() > 0 && String(lines[-1]).strip_edges() == "":
		lines.pop_back()
	lines.append(line)
	lines.append("")


# Removes the field's active line.
func remove(key: String):
	var i = _find(key, false)
	if i >= 0:
		lines.remove_at(i)


func set_text(key: String, value: String):
	set_raw(key, quote(value))


func unset(key: String):
	var i = _find(key, false)
	if i < 0:
		return
	if _find(key, true) >= 0:
		# The commented default line is still there: drop the active one.
		lines.remove_at(i)
	else:
		lines[i] = ";" + String(lines[i]).strip_edges()


static func quote(value: String) -> String:
	return "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""


static func unquote(raw: String) -> String:
	if raw.length() >= 2 && raw.begins_with("\"") && raw.ends_with("\""):
		return raw.substr(1, raw.length() - 2).replace("\\\"", "\"").replace("\\\\", "\\")
	return raw
