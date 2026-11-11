## A trophy family (data/trophies/*.tres): the things that belong together on the shelf, and the
## small standing bonus each one gives every worm while it sits at home (capped). The bonus shows on
## the worm as a charm in the family's colour (TrophyCharms), one bead per trophy up to the cap.
## Worm code never names a family: the bonus is added to the worm's base stats (TrophyBonus).
class_name TrophyFamily
extends Resource

@export var id: StringName
## FoodData ids that count as this family when kept as a trophy.
@export var members: Array[StringName] = []
## stat -> added per trophy of this family on the shelf (only stats in WormRules.base_stats).
@export var per_trophy: Dictionary = {}
## At most this many trophies of the family count (more are just decoration).
@export var cap := 3
## Charm colour on the worm and the shelf tag.
@export var color := Color.WHITE
## Charm look on the worm: &"studs" (along the back), &"twinkle" (on the head), &"leaf" (tail).
@export var charm := &"studs"


const DIR := "res://data/trophies/"


static func load_all() -> Array[TrophyFamily]:
	var out: Array[TrophyFamily] = []
	for f in ResourceLoader.list_directory(DIR):
		if f.ends_with(".tres"):
			var r := load(DIR + f)
			if r is TrophyFamily:
				out.append(r)
	out.sort_custom(func(a: TrophyFamily, b: TrophyFamily) -> bool: return String(a.id) < String(b.id))
	return out


static func family_of(families: Array[TrophyFamily], food_id: StringName) -> TrophyFamily:
	for f in families:
		if f.members.has(food_id):
			return f
	return null
