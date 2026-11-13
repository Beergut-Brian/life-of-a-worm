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
# "New planet" on a played tin never deletes it: the tin's file is moved aside to a numbered backup
# (<profile>_tin<N>.old<k>.json, k counting up, never written over) and the tin opens empty.
# "Restore" brings the newest backup back; a planet in the tin at that moment becomes a backup
# itself first, so restoring can never lose one either.

## Backups of tin i, oldest first (absolute paths as Save.path_for gives them).
static func backups(i: int) -> PackedStringArray:
	var out := PackedStringArray()
	var k := 1
	while FileAccess.file_exists(_backup_path(i, k)):
		out.append(_backup_path(i, k))
		k += 1
	return out


static func has_backup(i: int) -> bool:
	return FileAccess.file_exists(_backup_path(i, 1))


## Move tin i's planet aside (a new backup) so the tin opens as a new planet. Returns the backup's
## path ("" = the tin was empty, nothing to keep). The tin must not be the open save slot.
static func start_fresh(i: int) -> String:
	var path := Save.path_for(slot_name(i))
	if not FileAccess.file_exists(path):
		return ""
	var to := _backup_path(i, backups(i).size() + 1)
	if DirAccess.rename_absolute(path, to) != OK:
		push_warning("BaitTins: could not keep %s as %s" % [path, to])
		return ""
	print("tin: %s kept as %s, the tin is a new planet" % [slot_name(i), to.get_file()])
	return to


## Bring tin i's newest backup back. A planet in the tin now is kept as a backup first, behind the
## one coming back (so a second Restore swaps them back). False = no backup.
static func restore(i: int) -> bool:
	var list := backups(i)
	if list.is_empty():
		return false
	var newest := list[list.size() - 1]
	var path := Save.path_for(slot_name(i))
	var hold := ""
	if FileAccess.file_exists(path):
		hold = path + ".swap"
		if DirAccess.rename_absolute(path, hold) != OK:
			return false
	if DirAccess.rename_absolute(newest, path) != OK:
		if hold != "":
			DirAccess.rename_absolute(hold, path)
		return false
	if hold != "":
		DirAccess.rename_absolute(hold, newest)   # the planet that was in the tin takes its place
	print("tin: %s restored from %s" % [slot_name(i), newest.get_file()])
	return true


static func _backup_path(i: int, k: int) -> String:
	return Save.path_for(slot_name(i)).trim_suffix(".json") + ".old%d.json" % k
