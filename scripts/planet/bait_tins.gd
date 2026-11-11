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
## { stage, segments, minutes, worms }.
static func summary(i: int) -> Dictionary:
	var path := Save.path_for(slot_name(i))
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.has("planet"):
		return {}
	var worms: Dictionary = parsed.get("worms", {})
	var segs := 0
	for k in worms:
		segs = maxi(segs, (worms[k].get("segments", []) as Array).size())
	return { "stage": int(parsed.get("stage", 1)), "segments": segs,
		"minutes": int(float(parsed.get("played", 0.0)) / 60.0), "worms": worms.size() }
