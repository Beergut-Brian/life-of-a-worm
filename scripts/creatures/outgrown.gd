## Remembers, per worm, which creature species were once a threat to it (bigger, in sight), so the
## game can mark the two moments of outgrowing one:
## - flip: the first time that species is seen as food by that worm, close enough to see it
##   (the creature startles, goes pale and wide-eyed, `outgrown` cue). Exactly once per species.
## - first bite: the first time the worm eats one it outgrew: the "now I eat YOU" sting and the
##   grinning close-up (GrinCloseup). Exactly once per species.
## Kept in the tin (Save key `outgrown`: {"0": {"threat": [...], "flipped": [...], "bitten": [...]}})
## so the moments never repeat after a reload. Jarlings never enter it (never food, never a threat).
class_name Outgrown
extends RefCounted

const SAVE_KEY := "outgrown"
const META := &"outgrown_memory"
## px: a species is only noted (as a threat, or as flipped) within this distance: on screen.
const SIGHT := 260.0

signal flipped(species: StringName)
signal first_bite(species: StringName)

var threat: Array[StringName] = []
var flips: Array[StringName] = []
var bitten: Array[StringName] = []
var player := 0


## The memory of this worm (made on first use, read from the tin).
static func of(w: Node) -> Outgrown:
	if w.has_meta(META):
		return w.get_meta(META)
	var m := Outgrown.new()
	m.player = int(w.get("player"))
	var all: Dictionary = Save.get_value(SAVE_KEY, {})
	m.from_dict(all.get(str(m.player), {}))
	w.set_meta(META, m)
	return m


## A creature of `species` sees worm `w` react `r` at distance `d`. Returns true on the flip.
func note(species: StringName, r: CreatureSense.React, d: float) -> bool:
	if species == &"" or d > SIGHT or r == CreatureSense.React.FRIEND:
		return false
	if r == CreatureSense.React.AMBLE:
		if not species in threat:
			threat.append(species)
			_save()
		return false
	if species in threat and not species in flips:
		flips.append(species)
		_save()
		flipped.emit(species)
		return true
	return false


## The worm ate one. Returns true on the first bite of a species it outgrew.
func note_bite(species: StringName) -> bool:
	if species == &"" or not species in threat or species in bitten:
		return false
	if not species in flips:
		flips.append(species)
	bitten.append(species)
	_save()
	first_bite.emit(species)
	return true


func was_threat(species: StringName) -> bool:
	return species in threat


func to_dict() -> Dictionary:
	return {"threat": _strs(threat), "flipped": _strs(flips), "bitten": _strs(bitten)}


func from_dict(d: Dictionary) -> void:
	threat = _names(d.get("threat", []))
	flips = _names(d.get("flipped", []))
	bitten = _names(d.get("bitten", []))


func _save() -> void:
	var all: Dictionary = Save.get_value(SAVE_KEY, {})
	all = all.duplicate()
	all[str(player)] = to_dict()
	Save.set_value(SAVE_KEY, all)


static func _strs(a: Array[StringName]) -> Array:
	var out := []
	for s in a:
		out.append(String(s))
	return out


static func _names(a: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for s in a:
		out.append(StringName(s))
	return out
