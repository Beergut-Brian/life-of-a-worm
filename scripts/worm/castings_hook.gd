## G-01: makes sure the world this worm tunnels in draws its castings (CastingsTrail, one per world).
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
