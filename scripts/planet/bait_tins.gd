## Saves are bait tins: three per launcher profile, each a whole planet (seed + edits + both worms +
## the burrow). A tin is the profile's save slot "tin1".."tin3" (Save.use_slot), so each one is its
## own file user://saves/<profile>_tin<N>.json and the profile's own file keeps settings-free keys.
## The demo plays in its own slot ("demo") and never touches a real tin.
class_name BaitTins
extends RefCounted

const COUNT := 3
const DEMO := "demo"


static func slot_name(i: int) -> String:
	return "tin%d" % (i + 1)


static func open(i: int) -> void:
	Save.use_slot(slot_name(i))


static func open_demo() -> void:
	Save.use_slot(DEMO)
	Save.wipe()


## What the dock shows for tin i without opening it: {} = an empty tin (a new planet), else
## { stage, segments, minutes, worms, bodies }. `bodies` is the picture on the tin, one per worm in
## player order: { player, stage, segments: [flavour id per segment, "" = plain] }.
static func summary(i: int) -> Dictionary:
	var path := Save.path_for(slot_name(i))
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.has("planet"):
		return {}
	var worms: Dictionary = parsed.get("worms", {})
	var segs := 0
	var bodies: Array[Dictionary] = []
	for k in worms:
		var w: Dictionary = worms[k] if worms[k] is Dictionary else {}
		var list: Array = w.get("segments", [])
		segs = maxi(segs, list.size())
		bodies.append({ "player": int(k), "stage": int(w.get("stage", 1)),
			"segments": list.map(func(f): return String(f)) })
	bodies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.player < b.player)
	return { "stage": int(parsed.get("stage", 1)), "segments": segs,
		"minutes": int(float(parsed.get("played", 0.0)) / 60.0), "worms": worms.size(), "bodies": bodies }


# --- New and Restore (feel rule: start fresh from the menu, never lose a planet) ---------------
# "New world" on a played tin never deletes a planet: the tin's file is first copied whole to a
# new backup, user://saves/backups/<profile>_tin<N>--<UTC stamp>-<n>.json (the rule's
# <profile>--<stamp>-<n>.json, with the tin in the name since a Worm profile has three saves), the
# copy is read back, and only then does the tin open empty. A tin that cannot be backed up is
# never wiped. "Restore old world" copies the newest backup back; the planet in the tin at that
# moment is backed up first (so a second Restore undoes the first). Backups are never removed.

## Where backups live (beside the saves, so a test's scratch Save.dir keeps its backups too).
static func backup_dir() -> String:
	return Save.dir.path_join("backups")


static func _backup_prefix(i: int) -> String:
	return Save.path_for(slot_name(i)).get_file().trim_suffix(".json") + "--"


## Backups of tin i, oldest first (full paths).
static func backups(i: int) -> PackedStringArray:
	_adopt_old(i)
	var out := PackedStringArray()
	var d := DirAccess.open(backup_dir())
	if d == null:
		return out
	var prefix := _backup_prefix(i)
	var names := PackedStringArray()
	for f in d.get_files():
		if f.begins_with(prefix) and f.ends_with(".json"):
			names.append(f)
	names.sort()
	for f in names:
		out.append(backup_dir().path_join(f))
	return out


static func has_backup(i: int) -> bool:
	return not backups(i).is_empty()


## Every tin's backups, oldest first by their stamp (full paths).
static func all_backups() -> PackedStringArray:
	var list: Array[String] = []
	for i in COUNT:
		for p in backups(i):
			list.append(p)
	list.sort_custom(func(a: String, b: String) -> bool:
		return a.get_file().get_slice("--", 1) < b.get_file().get_slice("--", 1))
	return PackedStringArray(list)


## The newest backup of any tin ("" = none): what Settings > Restore old world brings back.
static func newest_backup() -> String:
	var list := all_backups()
	return list[list.size() - 1] if not list.is_empty() else ""


## Which tin a backup belongs to (-1 = not one of this profile's).
static func tin_of(backup: String) -> int:
	for i in COUNT:
		if backup.get_file().begins_with(_backup_prefix(i)):
			return i
	return -1


## Tin i's planet as it is now, copied to a new backup and read back. Returns the backup's path,
## "" if the tin is empty or the copy could not be made (then nothing has changed).
static func back_up(i: int) -> String:
	var path := Save.path_for(slot_name(i))
	if not FileAccess.file_exists(path):
		return ""
	var text := FileAccess.get_file_as_string(path)
	if text == "" and FileAccess.get_open_error() != OK:
		push_warning("BaitTins: could not read %s to back it up" % path)
		return ""
	DirAccess.make_dir_recursive_absolute(backup_dir())
	var stamp := Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "")
	var to := ""
	for n in 1000:
		to = backup_dir().path_join("%s%s-%03d.json" % [_backup_prefix(i), stamp, n])
		if not FileAccess.file_exists(to):
			break
	var f := FileAccess.open(to, FileAccess.WRITE)
	if f == null:
		push_warning("BaitTins: could not write the backup %s" % to)
		return ""
	f.store_string(text)
	f.close()
	if FileAccess.get_file_as_string(to) != text:
		push_warning("BaitTins: the backup %s did not read back whole" % to)
		return ""
	return to


## New world: tin i's planet is backed up, then the tin opens as a new planet. Returns the backup's
## path. "" = the tin was empty, or it could not be backed up and is left exactly as it was.
static func start_fresh(i: int) -> String:
	var path := Save.path_for(slot_name(i))
	if not FileAccess.file_exists(path):
		return ""
	var kept := back_up(i)
	if kept == "":
		push_warning("BaitTins: %s not backed up, so it is not wiped" % slot_name(i))
		return ""
	if DirAccess.remove_absolute(path) != OK:
		return ""
	print("tin: %s kept as %s, the tin is a new planet" % [slot_name(i), kept.get_file()])
	return kept


## Restore old world: a backup of tin i (default its newest) is copied back into the tin. A planet
## in the tin now is backed up first; if that fails nothing changes. False = no backup / failed.
static func restore(i: int, from := "") -> bool:
	if from == "":
		var list := backups(i)
		if list.is_empty():
			return false
		from = list[list.size() - 1]
	var text := FileAccess.get_file_as_string(from)
	if not JSON.parse_string(text) is Dictionary:
		push_warning("BaitTins: the backup %s does not read as a planet" % from)
		return false
	var path := Save.path_for(slot_name(i))
	if FileAccess.file_exists(path) and back_up(i) == "":
		return false
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	if DirAccess.rename_absolute(tmp, path) != OK:
		return false
	print("tin: %s restored from %s" % [slot_name(i), from.get_file()])
	return true


## Settings > Restore old world: the newest backup of any tin goes back into its own tin.
## Returns that tin, -1 if there was none or it failed.
static func restore_newest() -> int:
	var from := newest_backup()
	var i := tin_of(from)
	if i < 0 or not restore(i, from):
		return -1
	return i


# Backups made before they moved to backup_dir() (<profile>_tin<N>.old<k>.json beside the tin):
# moved into it, oldest first, stamped with their file time. Never removed.
static func _adopt_old(i: int) -> void:
	var base := Save.path_for(slot_name(i)).trim_suffix(".json")
	var k := 1
	while FileAccess.file_exists(base + ".old%d.json" % k):
		var old := base + ".old%d.json" % k
		DirAccess.make_dir_recursive_absolute(backup_dir())
		var t := Time.get_datetime_string_from_unix_time(FileAccess.get_modified_time(old))
		var to := backup_dir().path_join("%s%s-%03d.json" % [_backup_prefix(i),
			t.replace(":", "").replace("-", ""), k])
		if FileAccess.file_exists(to) or DirAccess.rename_absolute(old, to) != OK:
			return
		k += 1
