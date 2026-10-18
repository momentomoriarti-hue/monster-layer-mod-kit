extends RefCounted

# Unsaved edits of one or more config files, with undo and redo.
# Every change goes through set_field(), so Ctrl+Z undoes it; save() writes the
# files (Ctrl+S). Nothing is written to disk before save().

signal changed

const Kit = preload("res://mlmk_app/kit.gd")

var docs = {}
var paths = {}
var saved = {}
var undo = UndoRedo.new()
# Media files copied into a Lay's folder since the last save, deleted again on
# cancel when nothing uses them: {path: true}
var copied_files = {}


func add(id: String, path: String):
	docs[id] = Kit.load_doc(path)
	paths[id] = path
	saved[id] = docs[id].to_text()


func get_raw(id: String, key: String):
	return docs[id].get_raw(key)


func get_value(id: String, key: String):
	return docs[id].get_value(key)


# raw = the value text as written in the file (quoted for text), null = not set.
# Undo puts the whole file text back, so it is exactly as before.
func set_field(id: String, key: String, raw):
	if docs[id].get_raw(key) == raw:
		return
	var before = docs[id].to_text()
	var after_doc = docs[id].duplicate_doc()
	if raw == null:
		after_doc.unset(key)
	else:
		after_doc.set_raw(key, raw)
	# Typing into one field merges into one undo step.
	undo.create_action("Change " + key, UndoRedo.MERGE_ENDS)
	undo.add_do_method(_set_text.bind(id, after_doc.to_text()))
	undo.add_undo_method(_set_text.bind(id, before))
	undo.commit_action()


func _set_text(id: String, text: String):
	docs[id].parse(text)
	changed.emit()


func is_dirty() -> bool:
	for id in docs:
		if docs[id].to_text() != saved[id]:
			return true
	return false


func save() -> bool:
	var ok = true
	for id in docs:
		var text = docs[id].to_text()
		if text != saved[id]:
			if Kit.write_text(paths[id], text):
				saved[id] = text
			else:
				ok = false
	copied_files.clear()
	changed.emit()
	return ok


func do_undo() -> bool:
	var done = undo.undo()
	return done


func do_redo() -> bool:
	return undo.redo()


# Deletes media copied since the last save that no saved config uses.
func discard_copied_files():
	for path in copied_files:
		var name = String(path).get_file()
		var used = false
		for id in saved:
			if String(saved[id]).contains(name):
				used = true
		if !used:
			DirAccess.remove_absolute(path)
	copied_files.clear()
