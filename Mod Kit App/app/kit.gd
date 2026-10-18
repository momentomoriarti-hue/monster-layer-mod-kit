extends RefCounted

# The Mod Kit's files as the app sees them: mods in Mods\<name>\, their custom
# Lays and bosses, the example configs in Scripts\templates, and the kit's own
# scripts that pack mods. The app only reads and writes inside the kit folder.

const CfgDoc = preload("res://mlmk_app/cfg_doc.gd")
const Schema = preload("res://mlmk_app/schema.gd")

const KINDS = {
	"lay": {"folder": "Custom Lays", "cfg": "lay.cfg", "section": "lay", "template": "Simplified_Anims_Custom_Lay_Example", "new_name": "New Lay", "title": "Custom Lays", "one": "Lay"},
	"boss": {"folder": "Custom Bosses", "cfg": "boss.cfg", "section": "boss", "template": "Simplified_Anims_Custom_Boss_Example", "new_name": "New Boss", "title": "Custom Bosses", "one": "boss"},
}
const BAD_NAME_CHARS = "\\/:*?\"<>|"

var root: String
var mods_dir: String
var templates_dir: String
var _schemas = {}


func _init(kit_root: String):
	root = kit_root.replace("\\", "/").trim_suffix("/")
	mods_dir = root + "/Mods"
	templates_dir = root + "/Scripts/templates"


# ---- Files ----

static func read_text(path: String) -> String:
	if !FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path).trim_prefix(char(0xFEFF))


static func write_text(path: String, text: String) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


static func copy_file(from: String, to: String) -> bool:
	return DirAccess.copy_absolute(from, to) == OK


static func copy_dir(from: String, to: String):
	DirAccess.make_dir_recursive_absolute(to)
	var dir = DirAccess.open(from)
	if dir == null:
		return
	for f in dir.get_files():
		copy_file(from + "/" + f, to + "/" + f)
	for d in dir.get_directories():
		copy_dir(from + "/" + d, to + "/" + d)


static func load_doc(path: String):
	return CfgDoc.new().parse(read_text(path))


static func natural_sort(list: Array) -> Array:
	list.sort_custom(func(a, b): return String(a).naturalnocasecmp_to(String(b)) < 0)
	return list


static func dirs_in(path: String) -> Array:
	var dir = DirAccess.open(path)
	return natural_sort(Array(dir.get_directories())) if dir else []


# "" when the name can be a folder name, otherwise why not.
static func check_name(name: String) -> String:
	if name.strip_edges() == "":
		return "Enter a name."
	for c in BAD_NAME_CHARS:
		if name.contains(c):
			return "A name can't contain " + " ".join(BAD_NAME_CHARS.split("")) + "."
	if name.ends_with(".") || name != name.strip_edges():
		return "A name can't start or end with a space or end with a dot."
	return ""


# "My Mod", or "My Mod 2", "My Mod 3"... if that one is taken.
static func unique_name(base: String, taken: Array) -> String:
	var lower = taken.map(func(n): return String(n).to_lower())
	if !lower.has(base.to_lower()):
		return base
	var n = 2
	while lower.has((base + " " + str(n)).to_lower()):
		n += 1
	return base + " " + str(n)


# ---- Mods ----

func list_mods() -> Array:
	return dirs_in(mods_dir)


func mod_dir(mod: String) -> String:
	return mods_dir + "/" + mod


func mod_name(mod: String) -> String:
	var name = load_doc(mod_dir(mod) + "/mod.cfg").get_value("name")
	return mod if name == null || String(name).strip_edges() == "" else String(name)


func create_mod(name: String) -> String:
	var dir = mod_dir(name)
	DirAccess.make_dir_recursive_absolute(dir + "/Custom Lays")
	DirAccess.make_dir_recursive_absolute(dir + "/Custom Bosses")
	var doc = load_doc(templates_dir + "/mod.cfg")
	doc.set_text("name", name)
	write_text(dir + "/mod.cfg", doc.to_text())
	copy_file(templates_dir + "/mod_settings.cfg", dir + "/mod_settings.cfg")
	return name


# Renames the mod's folder and its name in mod.cfg. "" when it worked.
func rename_mod(mod: String, name: String) -> String:
	var problem = check_name(name)
	if problem != "":
		return problem
	if name != mod:
		var others = list_mods().filter(func(m): return m != mod)
		if others.map(func(m): return String(m).to_lower()).has(name.to_lower()):
			return "There is already a mod with this name."
		var err = DirAccess.rename_absolute(mod_dir(mod), mod_dir(name))
		if err != OK:
			return "Can't rename the mod's folder (is a file in it open in another program?)."
	var path = mod_dir(name) + "/mod.cfg"
	var doc = load_doc(path)
	doc.set_text("name", name)
	write_text(path, doc.to_text())
	return ""


# Mods made with older versions of the kit: fixes what changed since, so they
# open in the app as they are. (Custom Lays, Custom Bosses and mod_settings.cfg
# from before the Mods folder are moved into Mods\My Mod by setup-tools.bat.)
#   - a mod without mod.cfg gets one;
#   - lay.cfg / boss.cfg: "chance" is now "base_chance" (same value).
# Returns what was changed, one line each.
func upgrade_mods() -> Array:
	var changes = []
	for mod in list_mods():
		var dir = mod_dir(mod)
		if !FileAccess.file_exists(dir + "/mod.cfg"):
			var doc = load_doc(templates_dir + "/mod.cfg")
			doc.set_text("name", mod)
			write_text(dir + "/mod.cfg", doc.to_text())
			changes.append(mod + ": added mod.cfg")
		if !FileAccess.file_exists(dir + "/mod_settings.cfg"):
			copy_file(templates_dir + "/mod_settings.cfg", dir + "/mod_settings.cfg")
			changes.append(mod + ": added mod_settings.cfg")
		for kind in KINDS:
			for id in dirs_in(kind_dir(mod, kind)):
				var path = character_cfg(mod, kind, id)
				if !FileAccess.file_exists(path):
					continue
				var doc = load_doc(path)
				var chance = doc.get_raw("chance")
				if chance != null && !doc.is_set("base_chance"):
					doc.set_raw("base_chance", chance)
					doc.remove("chance")
					write_text(path, doc.to_text())
					changes.append(mod + " / " + id + ": chance is now base_chance")
	return changes


# ---- Custom Lays and bosses ----

func kind_dir(mod: String, kind: String) -> String:
	return mod_dir(mod) + "/" + KINDS[kind]["folder"]


func character_dir(mod: String, kind: String, id: String) -> String:
	return kind_dir(mod, kind) + "/" + id


func character_cfg(mod: String, kind: String, id: String) -> String:
	return character_dir(mod, kind, id) + "/" + KINDS[kind]["cfg"]


# [{id, name, active}] of every folder with a lay.cfg / boss.cfg.
func list_characters(mod: String, kind: String) -> Array:
	var result = []
	for id in dirs_in(kind_dir(mod, kind)):
		var path = character_cfg(mod, kind, id)
		if !FileAccess.file_exists(path):
			continue
		var doc = load_doc(path)
		var name = doc.get_value("name")
		var active = doc.get_value("active")
		result.append({
			"id": id,
			"name": id if name == null || String(name).strip_edges() == "" else String(name),
			"active": active == null || String(active).to_lower() != "false",
		})
	return result


func set_active(mod: String, kind: String, id: String, active: bool):
	var path = character_cfg(mod, kind, id)
	var doc = load_doc(path)
	doc.set_raw("active", "true" if active else "false")
	write_text(path, doc.to_text())


# A new Lay or boss from the example config, switched on. Returns its folder name.
func create_character(mod: String, kind: String) -> String:
	var info = KINDS[kind]
	DirAccess.make_dir_recursive_absolute(kind_dir(mod, kind))
	var id = unique_name(info["new_name"], dirs_in(kind_dir(mod, kind)))
	var dir = character_dir(mod, kind, id)
	DirAccess.make_dir_recursive_absolute(dir)
	var doc = load_doc(templates_dir + "/" + info["template"] + "/" + info["cfg"])
	doc.set_raw("active", "true")
	doc.set_text("name", id)
	write_text(dir + "/" + info["cfg"], doc.to_text())
	return id


# Deleting moves the folder to the Recycle Bin, so it can be brought back.
func delete_character(mod: String, kind: String, id: String) -> bool:
	return OS.move_to_trash(character_dir(mod, kind, id).replace("/", "\\")) == OK


func delete_mod(mod: String) -> bool:
	return OS.move_to_trash(mod_dir(mod).replace("/", "\\")) == OK


# ---- Field descriptions ----

func schema(which: String) -> Array:
	if !_schemas.has(which):
		var path = {
			"lay": templates_dir + "/" + KINDS["lay"]["template"] + "/lay.cfg",
			"boss": templates_dir + "/" + KINDS["boss"]["template"] + "/boss.cfg",
			"mod_settings": templates_dir + "/mod_settings.cfg",
			"mod": templates_dir + "/mod.cfg",
		}[which]
		var fields = Schema.parse(read_text(path))
		for field in fields:
			field["owner"] = which
		_schemas[which] = Schema.with_groups(fields) if which in ["lay", "boss"] else fields
	return _schemas[which]


# ---- Running the kit's scripts ----

func script_path(name: String) -> String:
	return root + "/Scripts/" + name


func moded_packed_exe() -> String:
	var dir = DirAccess.open(root + "/Moded Packed")
	if dir:
		for f in dir.get_files():
			if f.get_extension().to_lower() == "exe":
				return root + "/Moded Packed/" + f
	return ""
