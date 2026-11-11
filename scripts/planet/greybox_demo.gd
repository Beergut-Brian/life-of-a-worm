## The scripted `--demo` run: the grey-box loop in about 60 s, hands-free, for frames and soak.
## Dig a chamber and sleep (home), carry a pebble home (trophy), get eaten by the apex beetle,
## eat the grub trail (segments, diet stripes, Wriggle), outgrow and eat the beetle (stage-up),
## the red worm hatches, hold B to warp home, open the trait wall, then wander and eat forever.
## It drives the worms through Worm.autopilot only (a demo, not a player: no steering is ever
## added to a real player's worm). Logs each step as "demo: <step> t=<s>".
## --demo-quit=<s>: quit cleanly after s seconds (soak runs, exported-build checks).
class_name GreyboxDemo
extends Node

var level: PlanetLevel
var t := 0.0
var step := 0
var log_lines: Array[String] = []
var _step_t := 0.0
var _intent := {}
var _quit_at := -1.0
var _wander_a := 0.0
var _p2_a := 0.0
var _eaten := false
var _steps: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--demo-quit="):
			_quit_at = float(a.get_slice("=", 1))
	level.worm_spawned.connect(_on_spawned)
	level.beetle.ate_worm.connect(func(_p: int) -> void: _eaten = true)
	var S := level.spawn_point
	var ring: Array = []
	for i in 11:
		ring.append(S + Vector2.from_angle(TAU * i / 10.0) * 26.0)
	ring.append(S)
	var trail: Array = []
	for i in 10:
		trail.append(level.local_point(-28.0 - i * 1.6, 0))
	_steps = [
		["dig_chamber", _path(ring)],
		["sleep", _until(func(_w: Worm) -> bool: return level.burrow.has_home, {})],
		["carry_out", _go(level.local_point(7, 0), { "carry": true })],
		["carry_home", _until(func(w: Worm) -> bool: return w.carrying == null and not level.burrow.trophies.is_empty(),
			func(w: Worm) -> Dictionary: return _toward(w, level.burrow.home, { "carry": true }))],
		["meet_beetle", _go(level.local_point(-12, 0), {})],
		["eaten", _until(func(_w: Worm) -> bool: return _eaten, {})],
		["grub_trail", _path(trail)],
		["grow", _until(func(w: Worm) -> bool: return w.model.size_stage() >= 2, func(w: Worm) -> Dictionary: return _wander(w, 3.0))],
		["eat_apex", _until(func(_w: Worm) -> bool: return level.beetle.is_gone(),
			func(w: Worm) -> Dictionary: return _toward(w, level.beetle.position, { "burst": int(t * 2.0) % 3 == 0 }))],
		["red_hatches", _once(func(_w: Worm) -> void: Players.join_virtual(Players.P2))],
		["wander_off", _go(level.local_point(-30, -3), {})],
		["warp_home", _until(func(w: Worm) -> bool: return w.cam_position().distance_to(level.burrow.home) < 20.0, { "hold_b": true })],
		["trait_wall", _once(func(w: Worm) -> void: w.set_wall_open(true))],
		["look", _wait(2.5)],
		["wall_shut", _once(func(w: Worm) -> void: w.set_wall_open(false))],
		["soak", _until(func(_w: Worm) -> bool: return false, _orbit)],
	]
	_log("start")


func _on_spawned(w: Worm) -> void:
	if w.player == Players.P1:
		w.autopilot = _drive
	else:
		w.autopilot = _drive_p2


func _process(delta: float) -> void:
	t += delta
	if int(t / 5.0) != int((t - delta) / 5.0):
		var w := Worm.of(Players.P1)
		if w:
			print("demo-trace: t=%.0f step=%s segs=%d size=%d stage=%d bug=%d traits=%s tiles=%d" % [t,
				_steps[mini(step, _steps.size() - 1)][0], w.model.segments.size(), w.model.size_stage(),
				w.model.stage, w.model.flavour_count(&"bug"), w.model.earned, w.tiles_total])
	if _quit_at > 0.0 and t >= _quit_at:
		_quit_at = -1.0
		_log("quit")
		Game.quit()


func _drive(w: Worm) -> Dictionary:
	if step >= _steps.size():
		return {}
	_step_t += get_physics_process_delta_time()
	var r: Dictionary = _steps[step][1].call(w)
	if r.get("done", false):
		step += 1
		_step_t = 0.0
		if step < _steps.size():
			_log(_steps[step][0])
	return r


func _drive_p2(w: Worm) -> Dictionary:
	var p1 := Worm.of(Players.P1)
	if p1 == null:
		return {}
	_p2_a += get_physics_process_delta_time() * 1.4
	var target := p1.cam_position() + Vector2.from_angle(_p2_a) * 40.0
	return _toward(w, target, { "wiggle": int(t * 10.0) % 37 == 0 })


func _log(what: String) -> void:
	var line := "demo: %s t=%.1f" % [what, t]
	log_lines.append(line)
	print(line)


# --- step makers: each returns func(worm) -> intent (+ "done": true when finished) ---------------

func _toward(w: Worm, to: Vector2, extra: Dictionary) -> Dictionary:
	var d := to - w.cam_position()
	var out := extra.duplicate()
	out["move"] = d.normalized() if d.length() > 3.0 else Vector2.ZERO
	return out


func _go(to: Vector2, extra: Dictionary) -> Callable:
	return func(w: Worm) -> Dictionary:
		var out := _toward(w, to, extra)
		if w.cam_position().distance_to(to) < 8.0 or _step_t > 12.0:
			out["done"] = true
		return out


func _path(points: Array) -> Callable:
	var i := [0]
	return func(w: Worm) -> Dictionary:
		var to: Vector2 = points[i[0]]
		if w.cam_position().distance_to(to) < 7.0 or _step_t > 6.0:
			i[0] += 1
			_step_t = 0.0
		if i[0] >= points.size():
			return { "done": true }
		return _toward(w, points[i[0]], {})


func _until(cond: Callable, how) -> Callable:
	return func(w: Worm) -> Dictionary:
		var out: Dictionary = how.call(w) if how is Callable else (how as Dictionary).duplicate()
		if cond.call(w) or (_step_t > 20.0 and step < _steps.size() - 1):
			out["done"] = true
		return out


func _once(what: Callable) -> Callable:
	return func(w: Worm) -> Dictionary:
		what.call(w)
		return { "done": true }


func _wait(secs: float) -> Callable:
	return func(_w: Worm) -> Dictionary:
		return { "done": _step_t >= secs }


## Soak: a slow lap of the dirt ring with a wobble, so there is always fresh dirt to eat.
func _orbit(w: Worm) -> Dictionary:
	_wander_a += get_physics_process_delta_time()
	var here := w.cam_position()
	var a := here.angle() + 0.25
	var r := PlanetLevel.RADIUS * 16.0 * (0.68 + 0.06 * sin(_wander_a * 0.5))
	return _toward(w, Vector2.from_angle(a) * r, { "burst": int(_wander_a * 3.0) % 9 == 0 })


func _wander(w: Worm, radius_tiles: float) -> Dictionary:
	_wander_a += get_physics_process_delta_time() * 0.9
	var c := level.local_point(-36, 0) if step < 10 else level.burrow.home
	var r := radius_tiles * 16.0 * (1.0 + 0.5 * sin(_wander_a * 0.37))
	return _toward(w, c + Vector2.from_angle(_wander_a) * r, {})
