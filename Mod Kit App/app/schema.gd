extends RefCounted

# The fields the app shows, read from the comments of the kit's own example
# configs (Scripts\templates): every field there is described in six lines
#   ; name / ; Type: ... / ; Description: ... / ; Required: ... / ; Default: ... / the field
# So a field added to the kit later shows up in the app by itself, with its
# description behind the info button.
#
# A field: {key, type, options, multi, integer, description, required, default, group}
#   type:  "bool", "enum" (options), "files" (multi = several files), "number"
#          (integer = whole number), "text"
#   group: for Lays and bosses the animation it belongs to ("thrust", "intro"...),
#          or "general"

const IMAGE_EXTENSIONS = ["png", "jpg", "jpeg", "webp", "bmp", "tga"]
const VIDEO_EXTENSIONS = ["mp4", "m4v", "webm", "mov", "mkv", "avi", "wmv", "flv", "mpg", "mpeg", "gif", "ogv"]


static func parse(text: String) -> Array:
	var fields = []
	var lines = Array(text.trim_prefix(char(0xFEFF)).replace("\r\n", "\n").split("\n"))
	var i = 0
	while i < lines.size() - 1:
		var key = comment_text(lines[i])
		var typeline = comment_text(lines[i + 1])
		if is_key(key) && typeline.begins_with("Type:"):
			var field = {"key": key, "description": "", "required": false, "default": ""}
			var j = i + 1
			var current = ""
			while j < lines.size() && String(lines[j]).begins_with(";"):
				var c = comment_text(lines[j])
				if c.begins_with("Type:"):
					current = "type"
					field["typetext"] = c.substr(5).strip_edges()
				elif c.begins_with("Description:"):
					current = "description"
					field["description"] = c.substr(12).strip_edges()
				elif c.begins_with("Required:"):
					current = ""
					field["required"] = c.substr(9).strip_edges().to_lower().begins_with("yes")
				elif c.begins_with("Default:"):
					current = "default"
					field["default"] = c.substr(8).strip_edges()
				elif _line_is_field(lines[j], key):
					break
				elif current == "description":
					field["description"] += " " + c
				elif current == "type":
					field["typetext"] += " " + c
				elif current == "default":
					field["default"] += " " + c
				j += 1
			_set_type(field)
			fields.append(field)
			i = j
		else:
			i += 1
	return fields


static func comment_text(line) -> String:
	var s = String(line).strip_edges()
	if !s.begins_with(";"):
		return ""
	return s.substr(1).strip_edges()


static func is_key(s: String) -> bool:
	if s == "":
		return false
	for c in s:
		if !(c == "_" || (c >= "a" && c <= "z") || (c >= "0" && c <= "9")):
			return false
	return true


# The field's own line: "key=..." or ";key=..." (examples in the descriptions are
# indented: ";   key=...").
static func _line_is_field(line, key) -> bool:
	var s = String(line).strip_edges()
	return s.begins_with(key + "=") || s.begins_with(";" + key + "=")


static func _set_type(field):
	var t = String(field.get("typetext", "")).to_lower()
	field["options"] = []
	field["multi"] = false
	field["integer"] = false
	field["free"] = false
	if t.begins_with("true or false"):
		field["type"] = "bool"
	elif t.begins_with("list of"):
		# traits: the ids are listed in the type text ("thrust+", "pound-"...).
		field["type"] = "list"
		var regex = RegEx.create_from_string("\\b([a-z]+[+-])(?=\\s)")
		for m in regex.search_all(field["typetext"] + " "):
			if !field["options"].has(m.get_string(1)):
				field["options"].append(m.get_string(1))
		var most = RegEx.create_from_string("0-(\\d+)").search(t)
		field["max"] = int(most.get_string(1)) if most else 0
	elif t.begins_with("one of"):
		field["type"] = "enum"
		# "one of "tiny", ..., or a number 0.8-1.2": a word or a number.
		field["free"] = t.contains("or a number")
		var regex = RegEx.create_from_string("\"([^\"]+)\"")
		for m in regex.search_all(field["typetext"]):
			field["options"].append(m.get_string(1))
	elif t.contains("file name"):
		field["type"] = "files"
		field["multi"] = t.contains("file name(s)") || t.contains("names")
	elif t.contains("whole number"):
		field["type"] = "number"
		field["integer"] = true
	elif t.begins_with("number"):
		field["type"] = "number"
	else:
		field["type"] = "text"


# The animation a Lay or boss field belongs to: "<kind>_anim...", or
# "auto_fit_<kind>_anim_length"; everything else is "general".
static func group_of(key: String, kinds: Array) -> String:
	for kind in kinds:
		if key.begins_with(kind + "_anim") || key == "auto_fit_" + kind + "_anim_length":
			return kind
	return "general"


# Animation kinds found in the fields, in their order: every "<kind>_anim" field.
static func kinds_of(fields: Array) -> Array:
	var kinds = []
	for field in fields:
		var key: String = field["key"]
		if key.ends_with("_anim") && field["type"] == "files":
			kinds.append(key.trim_suffix("_anim"))
	return kinds


static func with_groups(fields: Array) -> Array:
	var kinds = kinds_of(fields)
	for field in fields:
		field["group"] = group_of(field["key"], kinds)
	return fields


# "free_cum" -> "Free cum"
static func title(kind: String) -> String:
	return kind.replace("_", " ").capitalize()


# The field's default as a value: "Default: 100" -> "100", "none (...)" -> "".
static func default_value(field) -> String:
	var d: String = field["default"]
	if d.begins_with("\""):
		var end = d.find("\"", 1)
		return d.substr(1, end - 1) if end > 0 else d.trim_prefix("\"")
	var word = d.split(" ")[0] if d != "" else ""
	if word in ["none", "no", "the", "a", "an", "empty", "random"]:
		return ""
	return word
