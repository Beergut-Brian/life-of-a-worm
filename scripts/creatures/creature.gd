## A living-ring creature, driven by its CreatureData (scenes/creatures/*.tscn). One rule:
## bigger eats smaller. To a worm at or above its size_stage it is food (group "food", the same
## duck-typed protocol as every pickup: it goes wide-eyed and scoots off). To a smaller worm a
## TRUNDLE creature is a threat: it notices, ambles closer, winds up for at least a full second
## (telegraph), then lunges; a caught worm pops out of its far end one segment shorter and dizzy.
## WIGGLE wiggles in place; MARCH walks its path back and forth (ants, tiny hats, digging a trail).
## Hunters eat live prey they bump into (beetles eat grubs): the visible side of the food chain.
## Never steers a worm. Placeholder art drawn in code (Art lane after D92).
class_name Creature
extends Node2D

signal taken(c: Creature)
signal ate_worm(player: int)
signal ate_creature(prey: Creature)

enum Mode { IDLE, STALK, WINDUP, LUNGE, FULL, FLEE }

const INK := Color("2a1a14")
const LUNGE_TIME := 0.35
const LUNGE_SPEED := 190.0
const BITE := 14.0
const FULL_TIME := 6.0
const SCARE_RANGE := 56.0
const WANDER := 70.0

@export var data: CreatureData
var world: PolarWorld
## Population id it counts toward (PopulationRule.id); &"" = not counted.
var species: StringName
var home := Vector2.ZERO
## MARCH: waypoints in world px, walked back and forth.
var path := PackedVector2Array()
var path_at := 0.0
var path_dir := 1.0
var mode := Mode.IDLE
var target: Node2D
var facing := 1.0
var _mode_t := 0.0
var _t := 0.0
var _gone := false
var _carried := false
var _block := 0.0
var _smug := 0.0
var _scared := false
var _barked := 0.0
var _lunge_to := Vector2.ZERO
var _wander_to := Vector2.ZERO
var _path_len := 0.0


func _ready() -> void:
	add_to_group(&"creatures")
	add_to_group(&"food")
	if home == Vector2.ZERO:
		home = position
	_wander_to = home
	_t = randf() * 10.0
	_path_len = _length(path)


# --- the food protocol (Worm._eat_and_carry) ---------------------------------------------------

func is_available() -> bool:
	return not _gone and not _carried and _block <= 0.0 and mode != Mode.LUNGE


func take() -> void:
	if _gone:
		return
	_gone = true
	remove_from_group(&"food")
	remove_from_group(&"creatures")
	taken.emit(self)
	queue_free()


func set_carried(on: bool, block := 0.0) -> void:
	_carried = on
	_block = block
	mode = Mode.IDLE
	z_index = 30 if on else 0
	if not on:
		home = position
		_wander_to = home


func drift_toward(p: Vector2, amount: float) -> void:
	global_position = global_position.move_toward(p, amount)


func hop_toward(p: Vector2, dist: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "global_position", global_position.move_toward(p, dist), 0.25)


func smug() -> void:
	_smug = 1.2
	if data and data.bark != "" and _barked <= 0.0:
		_barked = 2.0
		Audio.play(data.bark)


# --- rules -------------------------------------------------------------------------------------

## Is this worm (anything with model.stage) a threat to me? Bigger eats smaller.
func can_be_eaten_by(w: Node) -> bool:
	return w != null and w.model != null and w.can_eat(data)


func threatens(w: Node) -> bool:
	return w != null and w.model != null and data.is_threat_to(w.model.stage)


func _worms() -> Array:
	var out := []
	for w in get_tree().get_nodes_in_group(&"worms"):
		if w.is_inside_tree() and w.get("model") != null:
			out.append(w)
	return out


func _physics_process(delta: float) -> void:
	step(delta)


## One tick (tests call it with a fixed delta).
func step(delta: float) -> void:
	if _gone or data == null:
		return
	_t += delta
	_mode_t += delta
	_block = maxf(0.0, _block - delta)
	_smug = maxf(0.0, _smug - delta)
	_barked = maxf(0.0, _barked - delta)
	if _carried:
		queue_redraw()
		return
	var near_eater: Node2D = null
	var near_d := INF
	var prey_worm: Node2D = null
	var prey_d := INF
	for w in _worms():
		var d: float = w.head_position().distance_to(global_position)
		if can_be_eaten_by(w) and d < near_d:
			near_d = d
			near_eater = w
		elif threatens(w) and d < prey_d:
			prey_d = d
			prey_worm = w
	_scared = near_eater != null and near_d < SCARE_RANGE + data.radius
	match data.behaviour:
		CreatureData.Behaviour.WIGGLE:
			if _scared:
				_move(global_position - near_eater.head_position(), data.speed, delta)
		CreatureData.Behaviour.MARCH:
			_march(delta * (1.6 if _scared else 1.0))
		CreatureData.Behaviour.TRUNDLE:
			_trundle(delta, near_eater, near_d, prey_worm, prey_d)
	if data.hunts != &"" and mode != Mode.FULL and not _scared:
		_hunt()
	if world:
		rotation = (position.angle() + PI / 2.0)
	queue_redraw()


func _trundle(delta: float, eater: Node2D, eater_d: float, prey: Node2D, prey_d: float) -> void:
	match mode:
		Mode.IDLE, Mode.STALK, Mode.FLEE:
			if eater != null and eater_d < SCARE_RANGE * 2.0:
				_set_mode(Mode.FLEE)
				_move(global_position - eater.head_position(), data.speed * 0.9, delta)
			elif prey != null and prey_d < data.notice:
				if mode != Mode.STALK:
					_set_mode(Mode.STALK)
					if _barked <= 0.0:
						_barked = 4.0
						Audio.play("threat_near")
				target = prey
				if prey_d < data.strike + data.radius:
					_set_mode(Mode.WINDUP)
					if data.windup_cue != "":
						Audio.play(data.windup_cue)
				else:
					_move(prey.head_position() - global_position, data.speed, delta)
			else:
				_set_mode(Mode.IDLE)
				if global_position.distance_to(_wander_to) < 4.0:
					_wander_to = home + Vector2.from_angle(randf() * TAU) * randf() * WANDER
				_move(_wander_to - global_position, data.speed * 0.5, delta)
		Mode.WINDUP:
			# The telegraph: it swells and shakes, standing still, for a full second or more.
			if _mode_t >= data.telegraph_time():
				if is_instance_valid(target):
					_lunge_to = target.head_position()
				_set_mode(Mode.LUNGE)
				Audio.play("beetle_lunge")
		Mode.LUNGE:
			global_position = global_position.move_toward(_lunge_to, LUNGE_SPEED * delta)
			for w in _worms():
				if threatens(w) and w.head_position().distance_to(global_position) <= data.radius + BITE:
					_eat_worm(w)
					return
			if _mode_t >= LUNGE_TIME:
				_set_mode(Mode.IDLE)
		Mode.FULL:
			if _mode_t >= FULL_TIME:
				_set_mode(Mode.IDLE)


func _eat_worm(w: Node2D) -> void:
	var back: Vector2 = global_position - (w.head_position() - global_position).normalized() * (data.radius + 10.0)
	w.get_eaten(data.id, back)
	ate_worm.emit(w.player)
	_set_mode(Mode.FULL)
	target = null


func _hunt() -> void:
	for c in get_tree().get_nodes_in_group(&"creatures"):
		if c == self or not (c is Creature) or c.data == null or c.data.id != data.hunts:
			continue
		var d: float = c.global_position.distance_to(global_position)
		if d <= data.radius + c.data.radius + 2.0:
			ate_creature.emit(c)
			c.take()
			Audio.play("creature_munch")
			_set_mode(Mode.FULL)
			_mode_t = FULL_TIME * 0.5
			return
		if mode == Mode.IDLE and d < 80.0:
			_wander_to = c.global_position


func _march(delta: float) -> void:
	if path.size() < 2 or _path_len <= 0.0:
		return
	path_at += path_dir * data.speed * delta
	if path_at >= _path_len:
		path_at = _path_len
		path_dir = -1.0
	elif path_at <= 0.0:
		path_at = 0.0
		path_dir = 1.0
	var p := _point_at(path_at)
	var step_v := p - position
	if step_v.length() > 0.01:
		facing = signf(step_v.dot(Vector2.from_angle(position.angle() + PI / 2.0))) if world else signf(step_v.x)
	position = p
	_dig_here()


func _move(dir: Vector2, speed: float, delta: float) -> void:
	if dir.length() < 0.5:
		return
	var s := speed
	if world and world.is_solid(world.shape.cell_at(position)):
		s *= 0.5
	var v := dir.normalized() * s * delta
	position += v
	var tangent := Vector2.from_angle(position.angle() + PI / 2.0) if world else Vector2.RIGHT
	if absf(v.dot(tangent)) > 0.01:
		facing = signf(v.dot(tangent))
	_dig_here()


## Creatures leave little trails (ants keep theirs open by marching it). Only soft dirt-ring and
## topsoil tiles; they regrow at the plain rate like any non-worm edit.
func _dig_here() -> void:
	if world == null:
		return
	var cell := world.shape.cell_at(position)
	if world.is_solid(cell) and world.is_loaded(cell) and world.is_edible_by(2, cell) and world.ring_of(cell).id == data.ring:
		world.dig(cell)


func _set_mode(m: Mode) -> void:
	if m != mode:
		mode = m
		_mode_t = 0.0


func _point_at(dist: float) -> Vector2:
	var left := dist
	for i in path.size() - 1:
		var seg := path[i].distance_to(path[i + 1])
		if left <= seg:
			return path[i].lerp(path[i + 1], left / maxf(seg, 0.001))
		left -= seg
	return path[path.size() - 1]


static func _length(p: PackedVector2Array) -> float:
	var l := 0.0
	for i in p.size() - 1:
		l += p[i].distance_to(p[i + 1])
	return l


## Drawn size: smaller and cowering when something can eat it (bigger-than-me reads at a glance).
func draw_scale() -> float:
	var s := 1.0
	if _scared or _carried:
		s = 0.85
	if mode == Mode.WINDUP:
		s = 1.0 + 0.25 * minf(1.0, _mode_t / data.telegraph_time())
	return s


func _draw() -> void:
	if data == null:
		return
	var r := data.radius * draw_scale()
	var shake := Vector2.ZERO
	if mode == Mode.WINDUP or (_scared and not _carried):
		shake.x = sin(_t * 45.0) * 0.8
	match data.behaviour:
		CreatureData.Behaviour.WIGGLE:
			_draw_grub(r, shake)
		CreatureData.Behaviour.MARCH:
			_draw_ant(r, shake)
		_:
			_draw_beetle(r, shake)


func _eyes(at: Vector2, r: float, spread: float) -> void:
	var e := maxf(1.0, r * 0.24)
	for sx in [-1.0, 1.0]:
		var c: Vector2 = at + Vector2(sx * spread, 0)
		if _scared or _carried:
			draw_circle(c, e + 1.0, Color.WHITE)
			draw_circle(c, e * 0.5, INK)
		elif _smug > 0.0 or mode == Mode.STALK:
			draw_line(c + Vector2(-e, 0), c + Vector2(e, 0), INK, 1.0)
		else:
			# blinks a lot
			if fmod(_t, 2.6) < 0.12:
				draw_line(c + Vector2(-e, 0), c + Vector2(e, 0), INK, 1.0)
			else:
				draw_circle(c, e * 0.7, INK)


func _draw_grub(r: float, o: Vector2) -> void:
	var col := data.color
	for i in 3:
		var p := o + Vector2((i - 1) * r * 0.7, sin(_t * 6.0 + i) * 1.2)
		draw_circle(p, r * (0.8 - absf(i - 1) * 0.15) + 1.0, INK)
		draw_circle(p, r * (0.8 - absf(i - 1) * 0.15), col)
	_eyes(o + Vector2(r * 0.7 * facing, -r * 0.15), r * 0.7, r * 0.22)


func _draw_ant(r: float, o: Vector2) -> void:
	var bob := Vector2(0, -absf(sin(_t * 10.0)) * 1.2)
	var col := data.color
	var f := facing
	for i in 3:
		var p := o + bob + Vector2((i - 1) * r * 0.8 * f, 0)
		draw_circle(p, r * 0.45 + 1.0, INK)
		draw_circle(p, r * 0.45, col)
	# legs marching
	for i in 3:
		var lx := (i - 1) * r * 0.6
		var sw := sin(_t * 14.0 + i * 2.0) * r * 0.25
		draw_line(o + bob + Vector2(lx, 0), o + Vector2(lx + sw, r * 0.8), INK, 1.0)
	var head := o + bob + Vector2(r * 0.8 * f, 0)
	_eyes(head + Vector2(0, -r * 0.05), r * 0.45, r * 0.16)
	if data.hat.a > 0.0:
		var hb := head + Vector2(0, -r * 0.45)
		draw_rect(Rect2(hb + Vector2(-r * 0.45, -1), Vector2(r * 0.9, 1.5)), INK)
		draw_rect(Rect2(hb + Vector2(-r * 0.28, -r * 0.55), Vector2(r * 0.56, r * 0.55)), data.hat)


func _draw_beetle(r: float, o: Vector2) -> void:
	var col := data.color
	if _scared:
		col = col.lerp(Color.WHITE, 0.35)
	var walk := sin(_t * 8.0) * 1.2
	for i in 3:
		var lx := (i - 1) * r * 0.55
		draw_line(o + Vector2(lx, r * 0.5), o + Vector2(lx + walk, r * 1.05), INK, 1.5)
	draw_circle(o, r + 1.2, INK)
	draw_circle(o, r, col)
	draw_line(o + Vector2(0, -r), o + Vector2(0, r * 0.9), INK, 1.0)
	draw_circle(o + Vector2(-r * 0.4, -r * 0.45), r * 0.22, data.accent)
	var head := o + Vector2(r * 0.9 * facing, -r * 0.1)
	draw_circle(head, r * 0.48 + 1.0, INK)
	draw_circle(head, r * 0.48, col.darkened(0.25))
	if mode == Mode.WINDUP or mode == Mode.LUNGE:
		draw_line(head + Vector2(r * 0.4 * facing, -2), head + Vector2(r * 0.9 * facing, -r * 0.4), INK, 1.5)
		draw_line(head + Vector2(r * 0.4 * facing, 2), head + Vector2(r * 0.9 * facing, r * 0.4), INK, 1.5)
	if mode == Mode.FULL:
		for i in 3:   # zzz
			var z := head + Vector2(4 + i * 4, -r - 2 - i * 4 - fmod(_t * 6.0, 4.0))
			draw_line(z, z + Vector2(3, 0), Color.WHITE, 1.0)
			draw_line(z + Vector2(3, 0), z + Vector2(0, 3), Color.WHITE, 1.0)
			draw_line(z + Vector2(0, 3), z + Vector2(3, 3), Color.WHITE, 1.0)
	else:
		_eyes(head + Vector2(0, -r * 0.1), r * 0.48, r * 0.18)
