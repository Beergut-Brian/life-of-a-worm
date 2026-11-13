## A living-ring creature, driven by its CreatureData (scenes/creatures/*.tscn). One rule:
## bigger eats smaller. To a worm at or above its size_stage it is food (group "food", the same
## duck-typed protocol as every pickup: it goes wide-eyed and scoots off). To a smaller worm a
## TRUNDLE creature is a threat: it notices, ambles closer, winds up for at least a full second
## (telegraph), then lunges; a caught worm pops out of its far end one segment shorter and dizzy.
## WIGGLE wiggles in place; MARCH walks its path back and forth (ants, tiny hats, digging a trail).
## Hunters eat live prey they bump into (beetles eat grubs): the visible side of the food chain.
## How it reacts is size alone (CreatureSense, feature/worm-creatures-1): a worm bigger than it
## makes it flee slowly, a worm its own size is ignored (it is still food: Worm.can_eat), a smaller
## worm is ambled toward (TRUNDLE; others just carry on). A Jarling is never food or a threat and
## wears the friend outline. Outgrowing a species is marked once (Outgrown): the flip startles it
## pale and wide-eyed, the first bite plays `now_i_eat_you` and the grinning close-up. A gulped
## worm goes through Gulp (comic gulp drawn on this creature, out the far end, 0.5 s sparkle).
## BOUNCE (the lava blob) never chases or bites: a smaller worm that comes near makes it swell
## (the telegraph, `windup_cue`), and touching it squashes it flat and pushes the worm's head away
## (`CreatureData.bounce` px, a decaying knock over BOUNCE_TIME) with a boing and a burst at the
## contact point. A push, never a steer: the worm keeps its stick the whole time.
## Never steers a worm. Placeholder art drawn in code (Art lane after D92).
class_name Creature
extends Node2D

signal taken(c: Creature)
signal ate_worm(player: int)
signal ate_creature(prey: Creature)

## GIVE_UP: a chaser stopped chasing and turns away (the centipede), drawn so the cause shows.
enum Mode { IDLE, STALK, WINDUP, LUNGE, FULL, FLEE, GIVE_UP }

const INK := Color("2a1a14")
const LUNGE_TIME := 0.35
const LUNGE_SPEED := 190.0
const BITE := 14.0
const FULL_TIME := 6.0
const SCARE_RANGE := 56.0
const WANDER := 70.0
const GULP_TIME := 0.7
const STARTLE_TIME := 0.9
const FRIEND := Color(1.0, 0.93, 0.6, 0.55)
## BOUNCE: the knock (same shape as the lawnmower's bump: a decaying push added to the head).
const BOUNCE_DECAY := 8.0
const BOUNCE_TIME := 0.45
const SQUASH_TIME := 0.35
const BOUNCE_COOL := 0.8
## px past touching where a coming worm makes a bouncer swell (its warning).
const SWELL_RANGE := 48.0
const BOUNCE_CUE := "boing"   # existing file

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
var _gulp := 0.0
var _gulp_dir := Vector2.RIGHT
var _gulp_color := Color("f29aa0")
var _startle := 0.0
## BOUNCE state: knocks in flight ({worm, v, t}), per-player cooldown, the squash and its spot.
var _bounce_knocks: Array[Dictionary] = []
var _bounce_cool := {}
var _squash := 0.0
var _squash_at := Vector2.ZERO
var _swell := 0.0
## How many bounces it has given (tests, frames).
var bounces := 0


func _ready() -> void:
	add_to_group(&"creatures")
	if is_jarling():
		add_to_group(&"jarlings")
	else:
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
	_note_first_bite()
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

func is_jarling() -> bool:
	return CreatureSense.is_jarling(data)


## How I react to this worm: FLEE (it is bigger), IGNORE (my size), AMBLE (smaller), FRIEND.
func react_to(w: Node) -> CreatureSense.React:
	return CreatureSense.of(data, w)


## Can this worm eat me? Bigger (or equal) eats smaller; never a Jarling.
func can_be_eaten_by(w: Node) -> bool:
	return w != null and w.model != null and not is_jarling() and w.can_eat(data)


## Am I a threat to this worm (bigger than it, and it is not still sparkling from a gulp)?
func threatens(w: Node) -> bool:
	return w != null and w.model != null and CreatureSense.is_threat(data, w) and not Gulp.is_safe(w)


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
	_gulp = maxf(0.0, _gulp - delta)
	_startle = maxf(0.0, _startle - delta)
	_squash = maxf(0.0, _squash - delta)
	_bounce_knock_step(delta)
	if _carried:
		queue_redraw()
		return
	var near_eater: Node2D = null
	var near_d := INF
	var prey_worm: Node2D = null
	var prey_d := INF
	for w in _worms():
		var d: float = w.head_position().distance_to(global_position)
		var r := react_to(w)
		if not is_jarling() and Outgrown.of(w).note(data.id, r, d):
			_on_outgrown()
		if r == CreatureSense.React.FLEE and d < near_d:
			near_d = d
			near_eater = w
		elif r == CreatureSense.React.AMBLE and threatens(w) and d < prey_d:
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
		CreatureData.Behaviour.WAVE:
			_wave(delta, near_eater, near_d, prey_worm, prey_d)
		CreatureData.Behaviour.BOUNCE:
			if _scared:
				_move(global_position - near_eater.head_position(), data.speed, delta)
			_bounce_step(delta)
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
					_face(prey.head_position() - global_position)
					if data.windup_cue != "":
						Audio.play(data.windup_cue)
				else:
					_move(prey.head_position() - global_position, data.speed, delta)
			else:
				_set_mode(Mode.IDLE)
				if global_position.distance_to(_wander_to) < 4.0:
					_wander_to = home + Vector2.from_angle(randf() * TAU) * randf() * WANDER
				_move(_wander_to - global_position, data.speed * 0.5, delta)
		_:
			_strike(delta)


## BOUNCE: smaller worms only (a worm its size or bigger eats it instead). Swells as one comes
## close, then on contact squashes and knocks it away.
func can_bounce(w: Node) -> bool:
	return w != null and w.get("model") != null and not is_jarling() \
			and CreatureSense.worm_size(w, data) < data.size_stage


func _bounce_step(delta: float) -> void:
	for k in _bounce_cool.keys():
		_bounce_cool[k] = maxf(0.0, _bounce_cool[k] - delta)
	var closest := INF
	for w in _worms():
		if not can_bounce(w):
			continue
		var d: float = w.head_position().distance_to(global_position) - data.radius
		closest = minf(closest, d)
		if d <= BITE and _bounce_cool.get(w.player, 0.0) <= 0.0:
			bounce(w)
	var near := closest < SWELL_RANGE
	if near and _swell <= 0.0 and data.windup_cue != "" and _barked <= 0.0:
		_barked = 3.0
		Audio.play(data.windup_cue)
	_swell = move_toward(_swell, 1.0 if near else 0.0, delta * 3.0)


## The bounce: push w's head straight away from me, squash flat, a boing and a burst where it
## touched. Returns the push (px over BOUNCE_TIME).
func bounce(w: Node) -> Vector2:
	var away: Vector2 = w.head_position() - global_position
	away = away.normalized() if away.length() > 0.5 else Vector2.UP
	var push := away * maxf(data.bounce, 1.0)
	_bounce_knocks.append({"worm": w, "v": push * BOUNCE_DECAY, "t": 0.0})
	_bounce_cool[w.player] = BOUNCE_COOL
	_squash = SQUASH_TIME
	_squash_at = (away * data.radius).rotated(-rotation)
	bounces += 1
	Audio.play(BOUNCE_CUE)
	return push


## The knock: a decaying push added to the head each tick (the worm still steers on top of it).
func _bounce_knock_step(delta: float) -> void:
	for i in range(_bounce_knocks.size() - 1, -1, -1):
		var k: Dictionary = _bounce_knocks[i]
		var w = k.worm
		k.t += delta
		if not is_instance_valid(w) or k.t > BOUNCE_TIME:
			_bounce_knocks.remove_at(i)
			continue
		w.head.global_position += k.v * delta
		k.v *= exp(-BOUNCE_DECAY * delta)


## WAVE chasers (Centipede) override this; a bare WAVE creature trundles.
func _wave(delta: float, eater: Node2D, eater_d: float, prey: Node2D, prey_d: float) -> void:
	_trundle(delta, eater, eater_d, prey, prey_d)


## The shared end of a chase: wind up (the telegraph), lunge, bite through Gulp, doze when full.
func _strike(delta: float) -> void:
	match mode:
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
	var dir: Vector2 = (w.head_position() - global_position)
	dir = dir.normalized() if dir.length() > 0.5 else Vector2.RIGHT
	var back: Vector2 = global_position - dir * (data.radius + 10.0)
	if not Gulp.eat(data.id, w, back, global_position):
		return
	var tangent := Vector2.from_angle(position.angle() + PI / 2.0) if world else Vector2.RIGHT
	if absf(dir.dot(tangent)) > 0.01:
		facing = signf(dir.dot(tangent))   # jaws on the side it bit; the worm leaves by the back
	_gulp = GULP_TIME
	_gulp_dir = dir
	_gulp_color = Players.COLOR.get(w.player, _gulp_color)
	Audio.play("creature_munch")  # existing file; creature_gulp had none (audio-1 has no gulp cue)
	ate_worm.emit(w.player)
	_set_mode(Mode.FULL)
	target = null


## Mid-gulp (drawn jaws shut, the worm a bulge going through): shows who ate the worm.
func is_gulping() -> bool:
	return _gulp > 0.0


## A worm just outgrew my species, in sight: I startle (hop, pale, wide eyes, sweat drop).
func _on_outgrown() -> void:
	_startle = STARTLE_TIME
	if mode == Mode.STALK or mode == Mode.WINDUP:
		_set_mode(Mode.IDLE)
	Audio.play("boing")  # existing file; outgrown startle (comic, not a pain sound)


## Eaten: if the worm eating me used to be chased by my kind, this is its first bite of one.
func _note_first_bite() -> void:
	if is_jarling() or data == null:
		return
	var eater: Node2D = null
	var best := INF
	for w in _worms():
		var d: float = w.mouth_position().distance_to(global_position) if w.has_method("mouth_position") else INF
		if d < best and can_be_eaten_by(w):
			best = d
			eater = w
	if eater == null or best > data.radius + 48.0:
		return
	if Outgrown.of(eater).note_bite(data.id):
		Audio.play("now_i_eat_you")
		GrinCloseup.show_for(eater, data)


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


## Turn to look along dir (the jaws on the side the prey is).
func _face(dir: Vector2) -> void:
	var tangent := Vector2.from_angle(position.angle() + PI / 2.0) if world else Vector2.RIGHT
	if absf(dir.dot(tangent)) > 0.01:
		facing = signf(dir.dot(tangent))


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
	if _gulp > 0.0:
		s = 1.0 + 0.3 * sin(PI * (1.0 - _gulp / GULP_TIME))
	if _swell > 0.0 and not _scared:
		s = 1.0 + 0.12 * _swell
	return s


func _draw() -> void:
	if data == null:
		return
	var r := data.radius * draw_scale()
	var shake := Vector2.ZERO
	if mode == Mode.WINDUP or (_scared and not _carried):
		shake.x = sin(_t * 45.0) * 0.8
	if _startle > 0.0:
		shake.y = -absf(sin(_startle / STARTLE_TIME * PI)) * r * 0.8
	if is_jarling():
		_draw_friend(r, shake)
	match data.behaviour:
		CreatureData.Behaviour.WIGGLE:
			_draw_grub(r, shake)
		CreatureData.Behaviour.MARCH:
			_draw_ant(r, shake)
		CreatureData.Behaviour.WAVE:
			_draw_wave(r, shake)
		CreatureData.Behaviour.BOUNCE:
			_draw_lava(r, shake)
		_:
			_draw_beetle(r, shake)
	if _gulp > 0.0:
		_draw_gulp(r, shake)
	if _startle > 0.0:
		var sd := shake + Vector2(r * 0.9, -r * 1.1 + (1.0 - _startle / STARTLE_TIME) * r * 0.6)
		draw_circle(sd, maxf(1.5, r * 0.18), Color(0.55, 0.8, 1.0))


## The friend outline: soft, warm and gently pulsing, the same look as the Mole's.
func _draw_friend(r: float, o: Vector2) -> void:
	var glow := 2.5 + 1.0 * sin(_t * 2.0)
	draw_circle(o, r * 1.25 + glow + 2.0, Color(FRIEND, FRIEND.a * 0.5))
	draw_circle(o, r * 1.25 + glow, FRIEND)


## The comic gulp: the worm is a bulge sliding from my mouth to my back end, cheeks puffed.
## (Rotation-free: _gulp_dir is in my parent's space, so undo my rotation.)
func _draw_gulp(r: float, o: Vector2) -> void:
	var k := 1.0 - _gulp / GULP_TIME
	var dir := _gulp_dir.rotated(-rotation)
	var at := o + dir * r * lerpf(0.8, -1.0, k)
	draw_circle(at, r * 0.42 + 1.0, INK)
	draw_circle(at, r * 0.42, _gulp_color)
	draw_circle(at + dir * r * 0.15, r * 0.12, Color(1, 1, 1, 0.8))
	# "gulp" lines round the throat
	for i in 3:
		var a := dir.angle() + (i - 1) * 0.5
		var p := o + Vector2.from_angle(a) * r * (1.15 + 0.1 * sin(_t * 30.0))
		draw_line(p, p + Vector2.from_angle(a) * r * 0.35, Color.WHITE, 1.5)


func _eyes(at: Vector2, r: float, spread: float) -> void:
	var e := maxf(1.0, r * 0.24)
	for sx in [-1.0, 1.0]:
		var c: Vector2 = at + Vector2(sx * spread, 0)
		if _gulp > 0.0:
			draw_line(c + Vector2(-e, -e * 0.5), c + Vector2(e, e * 0.5), INK, 1.0)   # squeezed shut
		elif _scared or _carried or _startle > 0.0:
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


## WAVE creatures draw themselves (Centipede); a bare one looks like a beetle.
func _draw_wave(r: float, o: Vector2) -> void:
	_draw_beetle(r, o)


## The lava blob: a glowing, wobbling drop of lava with bubbles. On a bounce it squashes flat
## toward the worm and a white burst shows where they touched.
func _draw_lava(r: float, o: Vector2) -> void:
	var col := data.color
	if _scared or _startle > 0.0:
		col = col.lerp(Color.WHITE, 0.3)
	var sq := sin(PI * _squash / SQUASH_TIME) if _squash > 0.0 else 0.0
	var axis := _squash_at.normalized() if _squash_at.length() > 0.1 else Vector2.UP
	var glow := 0.5 + 0.5 * sin(_t * 3.0)
	draw_circle(o, r * 1.25 + glow * 2.0, Color(data.accent, 0.22))
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		var d := Vector2.from_angle(a)
		var k := 1.0 + 0.06 * sin(a * 3.0 + _t * 4.0)
		# squash: flatter along the contact axis, wider across it
		var along := d.dot(axis)
		var across := d - axis * along
		var p := axis * along * (1.0 - 0.35 * sq) + across * (1.0 + 0.25 * sq)
		outer.append(o + p * (r * k + 1.2))
		inner.append(o + p * r * k)
	draw_colored_polygon(outer, INK)
	draw_colored_polygon(inner, col)
	for i in 3:
		var b := o + Vector2(sin(_t * 1.3 + i * 2.1) * r * 0.45, r * 0.4 - fmod(_t * 0.4 + i * 0.33, 1.0) * r * 0.9)
		draw_circle(b, maxf(1.0, r * (0.12 + 0.04 * i)), data.accent)
	draw_circle(o + Vector2(-r * 0.4, -r * 0.45), r * 0.18, Color(1, 1, 1, 0.55))
	if sq > 0.0:
		var at := o + _squash_at
		for i in 6:
			var a := axis.angle() + (i - 2.5) * 0.45
			var p0 := at + Vector2.from_angle(a) * 3.0
			draw_line(p0, p0 + Vector2.from_angle(a) * r * 0.6 * sq, Color.WHITE, 2.0)
	_eyes(o + Vector2(r * 0.15 * facing, -r * 0.15), r, r * 0.3)


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
	if _scared or _startle > 0.0:
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
	if _gulp > 0.0:
		# jaws clamped shut on the worm, cheeks puffed
		draw_circle(head + Vector2(r * 0.25 * facing, r * 0.3), r * 0.28, col.lightened(0.15))
		draw_line(head + Vector2(r * 0.3 * facing, 0), head + Vector2(r * 0.75 * facing, 0), INK, 1.5)
		_eyes(head + Vector2(0, -r * 0.1), r * 0.48, r * 0.18)
	elif mode == Mode.FULL:
		for i in 3:   # zzz
			var z := head + Vector2(4 + i * 4, -r - 2 - i * 4 - fmod(_t * 6.0, 4.0))
			draw_line(z, z + Vector2(3, 0), Color.WHITE, 1.0)
			draw_line(z + Vector2(3, 0), z + Vector2(0, 3), Color.WHITE, 1.0)
			draw_line(z + Vector2(0, 3), z + Vector2(3, 3), Color.WHITE, 1.0)
	else:
		_eyes(head + Vector2(0, -r * 0.1), r * 0.48, r * 0.18)
