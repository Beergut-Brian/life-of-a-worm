## D-16: every dirt and topsoil food has its own sound on top of the chomp, so a kid can hear what
## he ate (a grub squeaks, a pebble clacks, a seed pops). A child of the worm: listens to its `ate`
## and plays that food's `FoodData.eat_cue` from data/foods/*.tres. A food with no cue just chomps.
## Only real swallows sound: loading a tin (which hides eaten pickups with take()) never does.
class_name FoodVoice
extends Node

const DIR := "res://data/foods"

static var _cues := {}
static var _loaded := false

## Cues this worm's swallows played, oldest first (tests read it).
var played: Array[String] = []


## The cue for a food id ("" = none). data/foods is read once.
static func cue_for(id: StringName) -> String:
	if not _loaded:
		_loaded = true
		for f in DirAccess.get_files_at(DIR):
			var path := DIR.path_join(f.trim_suffix(".remap"))
			if not path.ends_with(".tres"):
				continue
			var d := load(path) as FoodData
			if d != null and d.eat_cue != "":
				_cues[d.id] = d.eat_cue
	return String(_cues.get(id, ""))


func _ready() -> void:
	var w := get_parent() as Worm
	if w != null:
		w.ate.connect(_on_ate)


func _on_ate(_player: int, what: StringName, _growth: float) -> void:
	var c := cue_for(what)
	if c == "":
		return
	Audio.play(c)
	played.append(c)
