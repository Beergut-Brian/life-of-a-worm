## Planets in jars: before the stage-6 chomp the tin's save is copied to <dir>/<planet_id>.json, and a
## jar can be re-entered later as an ordinary planet with stage 6 disabled. Meant to become the autoload
## `Jars` (requested from Systems); until then a scene instances it as a node named "Jars".
## Uses only Save's public API: the copy is the save file itself, read after Save.flush().
class_name JarStore
extends Node

signal planet_jarred(planet_id: StringName)

const JAR_PROFILE_PREFIX := "jar_"

var dir := "user://jars"
var _return_profile := ""
var _open_id: StringName = &""


## Flush the current tin and copy it into the jar. Returns the jar's path, or "" on failure.
func snapshot(planet_id: StringName) -> String:
	var id := _safe(planet_id)
	if id == "":
		push_warning("Jars: bad planet id %s" % planet_id)
		return ""
	var jarred: Array = Save.get_value("jars", [])
	if not jarred.has(id):
		jarred = jarred.duplicate()
		jarred.append(id)
		Save.set_value("jars", jarred)
	Save.flush()
	var data := _read_save()
	data["jars"] = jarred   # the jar remembers it is one, even if flush had nothing new to write
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(id + ".json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Jars: could not write %s" % path)
		return ""
	f.store_string(JSON.stringify(data))
	f.close()
	planet_jarred.emit(StringName(id))
	return path


func list() -> Array[StringName]:
	var out: Array[StringName] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for file in d.get_files():
		if file.ends_with(".json"):
			out.append(StringName(file.get_basename()))
	out.sort()
	return out


func has_jar(planet_id: StringName) -> bool:
	return FileAccess.file_exists(dir.path_join(_safe(planet_id) + ".json"))


## Enter a jar: its copy becomes the save of profile "jar_<id>", flagged so stage 6 can't happen.
func open(planet_id: StringName) -> bool:
	var id := _safe(planet_id)
	if not has_jar(id):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(id + ".json")))
	if not parsed is Dictionary:
		return false
	if is_in_jar():
		close()
	_return_profile = Save.profile
	_open_id = StringName(id)
	Save.use_profile(JAR_PROFILE_PREFIX + id)
	Save.wipe()
	for key in parsed:
		Save.set_value(key, parsed[key])
	Save.set_value("jar", true)
	Save.set_value("stage6_disabled", true)
	Save.flush()
	return true


## Leave the jar: what was played inside goes back into the jar, then the tin that opened it loads.
func close() -> void:
	if not is_in_jar():
		return
	Save.flush()
	var data := _read_save()
	var path := dir.path_join(String(_open_id) + ".json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
		f.close()
	var jar_save := ProjectSettings.globalize_path("user://saves/%s.json" % Save.profile)
	Save.use_profile(_return_profile)
	DirAccess.remove_absolute(jar_save)
	_open_id = &""
	_return_profile = ""


func is_in_jar() -> bool:
	return _open_id != &""


static func stage6_allowed() -> bool:
	return not bool(Save.get_value("stage6_disabled", false))


## Remove every jar in dir (tests and the demo only).
func clear() -> void:
	for id in list():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(String(id) + ".json")))


func _read_save() -> Dictionary:
	var path := "user://saves/%s.json" % Save.profile
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func _safe(planet_id) -> String:
	var id := String(planet_id).strip_edges()
	return id if id.is_valid_identifier() else ""
