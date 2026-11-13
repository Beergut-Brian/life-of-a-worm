## The lawnmower's data (data/creatures/lawnmower.tres, L-12): a CreatureData plus what only the
## mower has: how hard its bump is, its engine cue, how far it drives either side of where it
## started, and the live body the surface ring's "lawnmower" counter spawns. surface_life.tres
## counts the mower with no body (live_max 0, read only for this lane); `give_body` hands that
## counter this body at run time, so the spawn list stays the ring's own.
class_name LawnmowerData
extends CreatureData

## px the worm is knocked (up off the grass and away along the mower's way), over about 0.4 s.
@export var bump := 90.0
## The engine, a loop the whole time it drives (very loud). An existing file in assets/audio/sfx/.
@export var cue := "boot_rumble"
## Played on every bump (with the shadow flash and the camera beat).
@export var bump_cue := "space_bump"
## Engine volume next to a worm, dB (it fades to quiet at `hear` px).
@export var loud_db := 6.0
@export var hear := 900.0
## px of surface it drives either side of where it spawned, then turns round.
@export var drive := 240.0
## Seconds between bumps of the same worm (never juggles one).
@export var bump_cooldown := 1.6
## The live body for the surface ring's counter.
@export_file("*.tscn") var scene := "res://scenes/creatures/lawnmower.tscn"
@export var live_max := 1
## Where the spawn picks a point (fractions of the planet radius); the mower then sits on the ground.
@export var spawn_depth := Vector2(0.97, 0.999)


## Gives the ecology's counter for this mower a live body: a copy of the ring's rule with the scene
## and live_max from here (the ring's own data is untouched). Returns the rule it now uses.
func give_body(ecology: RingEcology) -> PopulationRule:
	if ecology == null or not ecology.rules.has(id):
		return null
	var rule: PopulationRule = ecology.rules[id]
	if rule.live != "":
		return rule
	var r: PopulationRule = rule.duplicate()
	r.live = scene
	r.live_max = live_max
	r.live_scale = 1.0
	# spawn just under the grass (it drives up onto the ground line itself), in the surface's columns
	r.depth_min = spawn_depth.x
	r.depth_max = spawn_depth.y
	ecology.rules[id] = r
	return r
