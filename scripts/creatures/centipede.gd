## The centipede (L-08, stage 3; data/creatures/centipede.tres, CentipedeData): a wavy chaser that
## gives up fast. Who it chases is CreatureSense alone (a worm smaller than it, AMBLE); a worm its
## own size is ignored, a bigger one makes it flee slowly and it is food (the eaten path is the
## shared Creature/Gulp one). It notices within `notice`, swings side to side toward the worm
## (`wave_amplitude`, `wave_rate`), and gives up after `chase_time` or as soon as the worm is past
## `give_up_distance`: it turns its head away, shuts its eyes and huffs a little cloud (cue
## `bird_offended`, the existing huffy 'hmph'), then sulks `rest_time` before it chases again.
## Close enough, it winds up for at least a second (swells, shakes, jaws open) and lunges; a caught
## worm is shown in its jaws (Creature._draw_gulp). A missed lunge is a give-up too.
## Placeholder art drawn in code: tinted circles for the segments, a sneaker on every foot (a
## coloured shape per leg; no 2D gear path exists for creatures). Never steers a worm.
class_name Centipede
extends Creature

const GIVE_UP_TIME := 1.2
const TRAIL_STEP := 4.0
const TRAIL_MAX := 24

## Seconds into the current chase.
var chase_t := 0.0
## Seconds left sulking (no new chase).
var rest := 0.0
## How many times it has given up (tests, report).
var give_ups := 0
var _phase := 0.0
var _trail: Array[Vector2] = []   # recent head positions (parent space), newest first
var _away := Vector2.ZERO


func _cd() -> CentipedeData:
	return data as CentipedeData


func _wave(delta: float, eater: Node2D, eater_d: float, prey: Node2D, prey_d: float) -> void:
	var cd := _cd()
	if cd == null:
		_trundle(delta, eater, eater_d, prey, prey_d)
		return
	rest = maxf(0.0, rest - delta)
	match mode:
		Mode.GIVE_UP:
			# The turn-away: head the other way, a slow amble off, eyes shut, a huff cloud.
			_amble(_away, data.speed * 0.4, delta, false)
			facing = _facing_of(_away)
			if _mode_t >= GIVE_UP_TIME:
				_set_mode(Mode.IDLE)
		Mode.IDLE, Mode.STALK, Mode.FLEE:
			# a bigger worm: flee slowly (a little hysteresis so it doesn't flicker at the edge)
			if eater != null and eater_d < SCARE_RANGE * (2.5 if mode == Mode.FLEE else 2.0):
				_set_mode(Mode.FLEE)
				_amble(global_position - eater.head_position(), data.speed * 0.45, delta)
			elif mode == Mode.STALK:
				chase_t += delta
				if prey == null or prey != target or prey_d > cd.give_up_distance or chase_t >= cd.chase_time:
					give_up()
				elif prey_d < data.strike + data.radius:
					_set_mode(Mode.WINDUP)
					if data.windup_cue != "":
						Audio.play(data.windup_cue)
				else:
					_wave_toward(prey.head_position(), delta)
			elif prey != null and prey_d < data.notice and rest <= 0.0:
				_set_mode(Mode.STALK)
				chase_t = 0.0
				target = prey
				if _barked <= 0.0:
					_barked = 4.0
					Audio.play(data.bark)
			else:
				_set_mode(Mode.IDLE)
				if global_position.distance_to(_wander_to) < 4.0:
					_wander_to = home + Vector2.from_angle(randf() * TAU) * randf() * WANDER
				_amble(_wander_to - global_position, data.speed * 0.4, delta)
		_:
			var was := mode
			_strike(delta)
			if was == Mode.LUNGE and mode == Mode.IDLE:
				give_up()   # missed: it does not try again straight away


## Stop chasing: turn away from the worm (visibly), huff, and sulk `rest_time`.
func give_up() -> void:
	var from := global_position + Vector2.from_angle(position.angle() + PI / 2.0) * facing
	if is_instance_valid(target):
		from = target.head_position()
	_away = global_position - from
	if _away.length() < 0.5:
		_away = Vector2.RIGHT
	facing = _facing_of(_away)
	target = null
	chase_t = 0.0
	rest = _cd().rest_time if _cd() else 3.0
	give_ups += 1
	_set_mode(Mode.GIVE_UP)
	Audio.play("bird_offended")   # existing huffy 'hmph'; no centipede cue yet


## The wave: straight at the worm, plus a side-to-side swing (the derivative of a sine, so the
## body sways `wave_amplitude` px either side of the line).
func _wave_toward(p: Vector2, delta: float) -> void:
	var cd := _cd()
	var to := p - global_position
	if to.length() < 0.5:
		return
	var dir := to.normalized()
	_phase += delta * TAU * cd.wave_rate
	var side := dir.orthogonal() * cos(_phase) * cd.wave_amplitude * TAU * cd.wave_rate
	var v := dir * data.speed + side
	if world and world.is_solid(world.shape.cell_at(position)):
		v *= 0.5
	position += v * delta
	facing = _facing_of(dir)
	_note_trail()
	_dig_here()


## Sideways offset of the head from its straight line (tests).
func sway() -> float:
	return sin(_phase) * (_cd().wave_amplitude if _cd() else 0.0)


func _amble(dir: Vector2, speed: float, delta: float, turn := true) -> void:
	var f := facing
	_move(dir, speed, delta)
	if not turn:
		facing = f
	_note_trail()


func _facing_of(v: Vector2) -> float:
	var tangent := Vector2.from_angle(position.angle() + PI / 2.0) if world else Vector2.RIGHT
	var d := v.dot(tangent)
	return facing if absf(d) < 0.01 else signf(d)


func _note_trail() -> void:
	if _trail.is_empty() or _trail[0].distance_to(global_position) >= TRAIL_STEP:
		_trail.push_front(global_position)
		var n := TRAIL_MAX
		if _trail.size() > n:
			_trail.resize(n)


## The body's points in my local space: head at o, then one every `gap` px back along the path
## the head really took (so the wave shows in the body), straight out behind where the trail ends.
func _body(r: float, o: Vector2, n: int) -> Array[Vector2]:
	var gap := r * 0.95
	var out: Array[Vector2] = [o]
	var path: Array[Vector2] = [o]
	if not _carried:
		for g in _trail:
			path.append(to_local(g) + o)
	var at := 0   # path segment index
	var prev := o
	for i in range(1, n + 1):
		var want := gap
		var p := prev
		while want > 0.0 and at < path.size() - 1:
			var to := path[at + 1]
			var d := p.distance_to(to)
			if d >= want:
				p = p + (to - p) / d * want
				want = 0.0
			else:
				want -= d
				p = to
				at += 1
		if want > 0.0:
			p += Vector2(-facing * want, 0.0)
			at = path.size()   # past the trail: the rest goes straight back
		p.y += sin(_t * 7.0 - i * 1.1) * r * 0.06
		out.append(p)
		prev = p
	return out


func _draw_wave(r: float, o: Vector2) -> void:
	var cd := _cd()
	var n := cd.segments if cd else 5
	var col := data.color
	if _scared or _startle > 0.0:
		col = col.lerp(Color.WHITE, 0.35)
	if mode == Mode.GIVE_UP:
		col = col.lerp(Color(0.55, 0.5, 0.5), 0.35)   # a little deflated
	var sr := r * 0.62
	var pts := _body(r, o, n)
	# legs and sneakers first, under the body: one pair per segment, marching in a ripple
	for i in range(n, -1, -1):
		var p: Vector2 = pts[i]
		var sz := sr if i > 0 else r * 0.75
		for side in [-1.0, 1.0]:
			var sw := sin(_t * 12.0 + i * 1.3 + side) * sz * 0.45
			var hip := p + Vector2(side * sz * 0.35, sz * 0.4)
			var foot := p + Vector2(side * sz * 0.35 + sw, sz + 4.0)
			draw_line(hip, foot, INK, 1.5)
			_draw_sneaker(foot, sz, cd)
	# body, tail first so the head sits on top
	for i in range(n, 0, -1):
		var p: Vector2 = pts[i]
		var s := sr * (1.0 - 0.05 * i)
		draw_circle(p, s + 1.2, INK)
		draw_circle(p, s, col if i % 2 == 0 else col.darkened(0.12))
		draw_circle(p + Vector2(-s * 0.3, -s * 0.4), s * 0.25, data.accent)
	_draw_head(o, r * 0.75, col)


func _draw_sneaker(at: Vector2, sz: float, cd: CentipedeData) -> void:
	var w := maxf(5.0, sz * 0.75)
	var h := maxf(3.0, sz * 0.4)
	var toe := facing
	var shoe := cd.sneaker if cd else Color.WHITE
	var stripe := cd.sneaker_stripe if cd else Color.RED
	var box := Rect2(at + Vector2(-w * 0.5 + toe * w * 0.15, -h), Vector2(w, h))
	var toe_at := box.position + Vector2(w if toe > 0.0 else 0.0, h * 0.55)
	draw_rect(box.grow(1.0), INK)
	draw_circle(toe_at, h * 0.55 + 1.0, INK)
	draw_rect(box, shoe)
	draw_circle(toe_at, h * 0.55, shoe)
	draw_rect(Rect2(box.position + Vector2(0, h - 1.2), Vector2(w, 1.2)), shoe.darkened(0.45))   # sole
	draw_line(box.position + Vector2(w * 0.3, h * 0.25), box.position + Vector2(w * 0.7, h * 0.75), stripe, 1.5)


func _draw_head(o: Vector2, hr: float, col: Color) -> void:
	draw_circle(o, hr + 1.2, INK)
	draw_circle(o, hr, col.darkened(0.2))
	var f := facing
	# antennae: forward and up while chasing, drooped when it gives up
	var droop := mode == Mode.GIVE_UP
	for k in [-1.0, 1.0]:
		var base := o + Vector2(f * hr * 0.3 + k * 2.0, -hr * 0.8)
		var tip := base + (Vector2(f * hr * 0.9, hr * 0.2) if droop else Vector2(f * hr * 0.8, -hr * 0.9))
		draw_line(base, tip, INK, 1.2)
		draw_circle(tip, 1.6, data.accent)
	var eye := o + Vector2(f * hr * 0.35, -hr * 0.15)
	if mode == Mode.GIVE_UP:
		for sx in [-1.0, 1.0]:   # eyes shut, nose in the air
			var c: Vector2 = eye + Vector2(sx * hr * 0.32, 0)
			draw_line(c + Vector2(-hr * 0.2, 0), c + Vector2(hr * 0.2, -hr * 0.08), INK, 1.2)
		var k := minf(1.0, _mode_t / GIVE_UP_TIME)
		for i in 3:   # the huff, puffing out behind the turned head
			var pc := o + Vector2(-f * hr * (1.2 + k * 1.4 + i * 0.5), -hr * (0.2 + i * 0.35))
			draw_circle(pc, hr * (0.22 + 0.12 * i) * (0.6 + k), Color(1, 1, 1, 0.75 * (1.0 - k * 0.6)))
	else:
		_eyes(eye, hr, hr * 0.32)
	var jaw := o + Vector2(f * hr * 0.85, hr * 0.25)
	if _gulp > 0.0:
		# jaws clamped on the worm, cheeks puffed
		draw_circle(jaw + Vector2(-f * hr * 0.3, 0), hr * 0.35, col.lightened(0.15))
		draw_line(jaw - Vector2(f * hr * 0.2, 0), jaw + Vector2(f * hr * 0.4, 0), INK, 1.5)
	elif mode == Mode.WINDUP or mode == Mode.LUNGE:
		var open := hr * (0.45 + 0.25 * sin(_t * 30.0))
		draw_line(jaw, jaw + Vector2(f * hr * 0.6, -open), INK, 2.0)
		draw_line(jaw, jaw + Vector2(f * hr * 0.6, open), INK, 2.0)
	elif mode == Mode.FULL:
		for i in 3:   # zzz
			var z := o + Vector2(4 + i * 4, -hr * 1.6 - i * 4 - fmod(_t * 6.0, 4.0))
			draw_line(z, z + Vector2(3, 0), Color.WHITE, 1.0)
			draw_line(z + Vector2(3, 0), z + Vector2(0, 3), Color.WHITE, 1.0)
			draw_line(z + Vector2(0, 3), z + Vector2(3, 3), Color.WHITE, 1.0)
