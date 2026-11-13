## G-01: makes sure the world this worm tunnels in draws its castings (CastingsTrail, one per world)
## and shows its regrowth (RegrowWatch, one per world: sparkles and a soft sound, G-04).
## A child of worm.tscn, so every level that hands a worm a PolarWorld gets the trail without the
## level knowing about it.
extends Node

var _world: PolarWorld


func _physics_process(_delta: float) -> void:
	var w := get_parent() as Worm
	if w == null or w.world == _world:
		return
	_world = w.world
	CastingsTrail.ensure(_world)
	RegrowWatch.ensure(_world)
