## What the collection book lists, read straight from the data registries, and what has been found,
## read from the tin through the Save API. Nothing here owns either: the entries are whatever
## data/ defines (no invented ids), the found-set is the tackle log's (TackleLog, saved by the home
## slice under tin key "home_slice" -> "tackle" -> "found") plus the Story's own seen list.
##
## Sections and their sources:
##   foods      data/foods/*.tres        FoodData
##   creatures  data/creatures/*.tres    CreatureData, and data/pets/*.tres (PetData; a pet is met too),
##              data/apexes/*.tres (the ring apexes, ApexBeetle) and data/jarlings/*.tres (the Mole)
##   traits     data/traits/*.tres       TraitData (worm_rules.tres is not one and is skipped)
##   secrets    data/secrets/*.tres      SecretData
##   cutscenes  data/cutscenes/*.json    {"id": ...}, in Story.SCENES order
##   planets    data/planets/*.tres      PlanetData (S-18: one page per space planet type); found
##              when its whole planet is eaten in space (the tin's SpaceDrift "space" -> "done")
class_name BookCatalog
extends RefCounted

const SECTIONS: Array[StringName] = [&"foods", &"creatures", &"traits", &"secrets", &"cutscenes", &"planets"]
const DIRS := {
	&"foods": ["res://data/foods/"],
	&"creatures": ["res://data/creatures/", "res://data/pets/", "res://data/apexes/", "res://data/jarlings/"],
	&"traits": ["res://data/traits/"],
	&"secrets": ["res://data/secrets/"],
	&"cutscenes": ["res://data/cutscenes/"],
	&"planets": ["res://data/planets/"],
}
## Script class an entry must be (or extend); "" = any resource with an `id`.
const CLASSES := { &"foods": "FoodData", &"creatures": "", &"traits": "TraitData",
	&"secrets": "SecretData", &"cutscenes": "", &"planets": "PlanetData" }
## Where the tackle log sits in the tin (scripts/burrow/home_slice.gd, contracts "Home slice").
const TIN_KEY := "home_slice"
const LOG_KEY := "tackle"


## Every data file a section lists (the files the book reads), in directory order.
static func files(section: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	var ext := ".json" if section == &"cutscenes" else ".tres"
	for dir: String in DIRS.get(section, []):
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for f in ResourceLoader.list_directory(dir) if ext == ".tres" else DirAccess.get_files_at(dir):
			if f.ends_with(ext):
				out.append(dir + f)
	return out


## One section's entries: [{id: StringName, data: Resource or Dictionary, path: String}], sorted.
static func entries(section: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := {}
	for path in files(section):
		var e := _entry(section, path)
		if e.is_empty() or seen.has(e.id):
			continue
		seen[e.id] = true
		out.append(e)
	if section == &"cutscenes":
		out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _scene_rank(a.id) < _scene_rank(b.id))
	else:
		out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.id) < String(b.id))
	return out


## Every section at once.
static func all() -> Dictionary:
	var d := {}
	for s in SECTIONS:
		d[s] = entries(s)
	return d


static func _entry(section: StringName, path: String) -> Dictionary:
	if section == &"cutscenes":
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			push_warning("Book: %s is not a cutscene" % path)
			return {}
		var id := StringName(parsed.get("id", path.get_file().get_basename()))
		return { "id": id, "data": parsed, "path": path }
	var r := load(path)
	if r == null or not (&"id" in r) or StringName(r.id) == &"":
		return {}
	var cls: String = CLASSES.get(section, "")
	if cls != "" and not is_class_or_sub(r.get_script(), cls):
		return {}
	return { "id": StringName(r.id), "data": r, "path": path }


static func _scene_rank(id: StringName) -> int:
	var i := Story.SCENES.find(id)
	return i if i >= 0 else 1000 + hash(id) % 1000


## True when the script or any base script is the named global class (CreatureData extends FoodData).
static func is_class_or_sub(sc: Script, cls: String) -> bool:
	while sc != null:
		if sc.get_global_name() == cls:
			return true
		sc = sc.get_base_script()
	return false


# --- found ----------------------------------------------------------------------------------------

## section -> Array[StringName] found so far: the live tackle log if one is running (fresher than
## the last autosave), else the open tin's saved log; cutscenes also take Story's seen list.
static func found_set(tree: SceneTree = null) -> Dictionary:
	var raw: Dictionary = {}
	var log := live_log(tree)
	if log:
		raw = log.to_dict().get("found", {})
	else:
		raw = saved_found()
	var out := {}
	for s in SECTIONS:
		var have: Array[StringName] = []
		for id in raw.get(String(s), []):
			if not have.has(StringName(id)):
				have.append(StringName(id))
		out[s] = have
	var seen: Array = Save.get_value(Story.SAVE_KEY, [])
	var story := Story.find(tree) if tree else null
	if story:
		seen = seen + Array(story.seen)
	for id in seen:
		if not (out[&"cutscenes"] as Array).has(StringName(id)):
			(out[&"cutscenes"] as Array).append(StringName(id))
	for id in eaten_planets():
		if not (out[&"planets"] as Array).has(id):
			(out[&"planets"] as Array).append(id)
	return out


## Planet types eaten whole in space in the open tin (SpaceDrift saves them under "space" -> "done").
static func eaten_planets() -> Array[StringName]:
	var out: Array[StringName] = []
	var sp = Save.get_value(SpaceDrift.SAVE_KEY, {})
	if not sp is Dictionary:
		return out
	var done = sp.get("done", [])
	if not done is Array:
		return out
	for id in done:
		if not out.has(StringName(id)):
			out.append(StringName(id))
	return out


## The tin's saved found-set, as stored: {"foods": ["grub", ...], ...}.
static func saved_found() -> Dictionary:
	var tin = Save.get_value(TIN_KEY, {})
	if not tin is Dictionary:
		return {}
	var log = tin.get(LOG_KEY, {})
	if not log is Dictionary:
		return {}
	var f = log.get("found", {})
	return f if f is Dictionary else {}


static func live_log(tree: SceneTree) -> TackleLog:
	if tree == null or tree.root == null:
		return null
	for n in tree.root.find_children("TackleLog", "", true, false):
		if n is TackleLog:
			return n
	return null


## How many of a section's entries are in `found`.
static func count(list: Array, found: Array) -> int:
	var n := 0
	for e: Dictionary in list:
		if found.has(e.id):
			n += 1
	return n
