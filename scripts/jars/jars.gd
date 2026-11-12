## Planets in jars: before the stage-6 chomp the tin's save is copied to <dir>/<planet_id>.json, and a
## jar can be re-entered later as an ordinary planet with stage 6 disabled. Meant to become the autoload
## `Jars` (requested from Systems); until then a scene instances it as a node named "Jars".
## Uses only Save's public API: the copy is the open tin's save file (profile + slot), read after
## Save.flush(), minus what belongs to the tin rather than the planet (TIN_ONLY): Old Reel's tackle box
## (the found-set) stays with the tin; inside a jar it is lent in on open() and handed back on close(),
## so finds made in a jar still count. Settings are per install (settings.json) and never in a save.
class_name JarStore
extends Node

signal planet_jarred(planet_id: StringName)

const JAR_PROFILE_PREFIX := "jar_"
## The found-set: Old Reel's tackle box. Each is [key] or [key, sub_key]: "tackle" is TackleLog's own
## key, "home_slice"."tackle" the tackle box inside the home slice. Lent into a jar, never stored in it.
const FOUND_SET := [["tackle"], ["home_slice", "tackle"]]
## Save keys that belong to the tin, never to the jar file: the found-set, plus "solo" and "settings"
## (session / per install), stripped in case anything ever writes them into a save.
const TIN_ONLY := FOUND_SET + [["solo"], ["settings"]]

var dir := "user://jars"
var _return_profile := ""
var _return_slot := ""
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
	var data := strip_tin_only(_read_save())
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
	Save.flush()
	var lent := found_set_of(_read_save())   # the tin's tackle box comes along into the jar
	_return_profile = Save.profile
	_return_slot = Save.slot
	_open_id = StringName(id)
	Save.use_profile(JAR_PROFILE_PREFIX + id)
	Save.wipe()
	var planet := strip_tin_only(parsed)
	for key in planet:
		Save.set_value(key, planet[key])
	_put_found_set(lent)
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
	var found := found_set_of(data)          # handed back to the tin, not kept in the jar
	var path := dir.path_join(String(_open_id) + ".json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(strip_tin_only(data)))
		f.close()
	var jar_save := ProjectSettings.globalize_path(Save.path_for(""))
	Save.use_profile(_return_profile)
	Save.use_slot(_return_slot)
	DirAccess.remove_absolute(jar_save)
	_put_found_set(found)
	Save.flush()
	_open_id = &""
	_return_profile = ""
	_return_slot = ""


func is_in_jar() -> bool:
	return _open_id != &""


## The jar's planet without opening it (the shelf and the jar-open picture read this). {} if none.
func peek(planet_id: StringName) -> Dictionary:
	if not has_jar(planet_id):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(_safe(planet_id) + ".json")))
	return parsed if parsed is Dictionary else {}


## The jar id for the open tin: <profile>[_<slot>]_<seed>, so tins of one profile never share a jar.
static func current_planet_id(seed_value: int) -> StringName:
	var who := Save.profile if Save.slot == "" else "%s_%s" % [Save.profile, Save.slot]
	return StringName("%s_%d" % [who, seed_value])


## A copy of a save without the tin's own keys (TIN_ONLY).
static func strip_tin_only(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	for k in TIN_ONLY:
		if k.size() == 1:
			out.erase(k[0])
		elif out.get(k[0]) is Dictionary:
			(out[k[0]] as Dictionary).erase(k[1])
	return out


## Just the found-set of a save, as {"tackle": v, "home_slice/tackle": v} (only those present).
static func found_set_of(data: Dictionary) -> Dictionary:
	var out := {}
	for k in FOUND_SET:
		if k.size() == 1:
			if data.has(k[0]):
				out[k[0]] = data[k[0]]
		elif data.get(k[0]) is Dictionary and (data[k[0]] as Dictionary).has(k[1]):
			out["%s/%s" % [k[0], k[1]]] = data[k[0]][k[1]]
	return out


static func stage6_allowed() -> bool:
	return not bool(Save.get_value("stage6_disabled", false))


## Remove every jar in dir (tests and the demo only).
func clear() -> void:
	for id in list():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(String(id) + ".json")))


func _put_found_set(values: Dictionary) -> void:
	for key in values:
		var parts: PackedStringArray = String(key).split("/")
		if parts.size() == 1:
			Save.set_value(parts[0], values[key])
		else:
			var outer = Save.get_value(parts[0], {})
			outer = (outer as Dictionary).duplicate() if outer is Dictionary else {}
			outer[parts[1]] = values[key]
			Save.set_value(parts[0], outer)


## The open save's file: the tin's slot, not just the profile (Worm's tins are slots).
func _read_save() -> Dictionary:
	var path := Save.path_for(Save.slot)
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func _safe(planet_id) -> String:
	var id := String(planet_id).strip_edges()
	return id if id.is_valid_identifier() else ""
