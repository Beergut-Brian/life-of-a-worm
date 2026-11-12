## Lantern cost in the R-a stress scene (scenes/levels/polar_stress.tscn): the same run with a
## Lantern injected before the level is ready, so its world gets the Lantern tiles and lights.
##   godot --path . res://art/tools/lantern_stress.tscn -- --seconds=20 --sim-minutes=1
## Add --lantern=off for the baseline. Prints polar_stress's JSON line plus "lantern:" lines with
## the most lights lit in a tick and the slowest pool reassignment.
extends Node

var lantern: Lantern
var _max_lights := 0
var _max_assign := 0
var _emitters := 0
var _t := 0.0


func _ready() -> void:
	var stress: Node = load("res://scenes/levels/polar_stress.tscn").instantiate()
	if not OS.get_cmdline_user_args().has("--lantern=off"):
		lantern = Lantern.new()
		lantern.name = "Lantern"
		stress.add_child(lantern)
	add_child(stress)
	if lantern:
		for e in stress.get(&"eaters"):
			lantern.follow.append(e)


func _process(delta: float) -> void:
	if lantern == null or not is_instance_valid(lantern):
		return
	_max_lights = maxi(_max_lights, lantern.active_lights)
	_max_assign = maxi(_max_assign, lantern.assign_usec)
	_emitters = maxi(_emitters, lantern.emitters.size())
	_t += delta
	if _t >= 2.0:
		_t = 0.0
		print("lantern: max_lights=%d pool=%d emitters_max=%d assign_usec_max=%d" % [_max_lights, lantern.max_lights, _emitters, _max_assign])
