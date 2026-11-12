## Stages the look's evidence frames (only with --demo): `--look=<preset>` on the command line.
##   scripts/tools/shots.sh "" 6 .scratch/shots/x --demo --look=topsoil_day
## Presets: dirt, topsoil_day, topsoil_dusk, tunnel_both, shaft, chomp, rain, stress.
## It stops the demo autopilot, carves a stage with a stand-in eater (player 9, any stage), places
## the worms and fixes the time of day. Never part of play.
class_name LookFrames
extends Node

const EATER := 9

var look: LookDirector
var preset := ""
var _t := 0.0
var _chomp_t := 0.0


static func preset_arg() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--look="):
			return a.trim_prefix("--look=")
	return ""


func _ready() -> void:
	(func() -> void: _stage()).call_deferred()


func _level() -> Node2D:
	return look.level


func _point(depth_frac: float, along_tiles := 0.0) -> Vector2:
	var a := -PI / 2.0 + along_tiles * 16.0 / (look.surface_px * depth_frac)
	return Vector2.from_angle(a) * look.surface_px * depth_frac


func _carve_line(from: Vector2, to: Vector2, r: float) -> void:
	var w := look.world
	w.set_stage(EATER, 9)
	var n := int(from.distance_to(to) / 6.0) + 1
	for i in n + 1:
		w.eat_circle(from.lerp(to, float(i) / n), r, EATER)


func _place(p: int, at: Vector2) -> void:
	var w := Worm.of(p)
	if w == null:
		w = _level().spawn_worm(p)
	if w:
		w.warp_to(look.world.to_global(at))


func _stage() -> void:
	var lv := _level()
	var demo = lv.get(&"_demo")
	if demo is Node:
		demo.queue_free()
	look.fixed_phase = 0.3
	match preset:
		"topsoil_day", "topsoil_dusk", "shaft", "rain":
			var depth := 0.975
			_carve_line(_point(depth, -14), _point(depth, 14), 14.0)
			if preset != "topsoil_day":
				_carve_line(_point(depth, 4), _point(1.01, 4), 12.0)  # a hole up through the crust
			_place(0, _point(depth, -3))
			if preset == "topsoil_dusk":
				look.fixed_phase = 0.62
			if preset == "rain" and look.rings_director:
				look.rings_director.set(&"raining", true)
				look.wetness = 1.0
		"tunnel_both", "chomp", "dirt":
			var depth := 0.72
			_carve_line(_point(depth, -16), _point(depth, 16), 15.0)
			_carve_line(_point(depth, 6), _point(depth - 0.03, 12), 12.0)
			_place(0, _point(depth, -4))
			if preset == "tunnel_both":
				_place(1, _point(depth, 5))
				for i in 3:
					_food([&"crystal", &"honeydew", &"mushroom"][i], _point(depth, -12 + i * 4))
		"stress":
			for k in 6:
				var depth := 0.7 + k * 0.045
				_carve_line(_point(depth, -30), _point(depth, 30), 14.0)
				_carve_line(_point(depth, -20 + k * 6), _point(1.01, -20 + k * 6), 10.0)
				for i in 10:
					_food([&"crystal", &"honeydew", &"mushroom", &"droplet"][i % 4], _point(depth, -28 + i * 6))
			_place(0, _point(0.8, 0))
			if Worm.of(1) == null:
				_place(1, _point(0.85, 3))
	print("look frames: %s staged" % preset)


func _food(id: StringName, at: Vector2) -> void:
	var lv := _level()
	if lv.has_method(&"_add_food"):
		lv.call(&"_add_food", id, at)


func _process(delta: float) -> void:
	_t += delta
	if preset == "chomp":
		_chomp_t -= delta
		var w := Worm.of(0)
		if w and _chomp_t <= 0.0:
			_chomp_t = 0.5
			Juice.chomp(w.mouth_position(), Color("e8c890"), 2.2)
			Juice.debris(w.mouth_position() + Vector2(0, 6), Color("6c452c"), 8)
	if preset == "stress" and fmod(_t, 2.0) < delta:
		print("look stress: lights %s, sprites %d, look %.2f ms + sprites %.2f ms, fps %d, frame %.2f ms (process) %.2f ms (physics)" % [
			look.light_counts(), get_tree().get_nodes_in_group(&"food").size(),
			look.frame_usec / 1000.0, look.sprites_usec / 1000.0, Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
