## The sky's birds (W-07; GAME.md Rings: "Sky: clouds, birds, planes, balloons; no threats").
## A few flocks of little birds (placeholder, drawn in code) fly a V round the band of air above
## the grass. They are never food and never a threat: they never touch, push or steer a worm. A
## worm's head coming within SkyLife.flock_startle px startles a flock: a tweet, the birds burst
## apart and flap up, the flock turns away from the worm, and a moment later it settles back into
## its V. A child of RingsDirector (node "SkyFlock"), in the planet's frame; data in sky_life.tres.
class_name SkyFlock
extends Node2D

signal startled(flock: int)

const INK := Color("2a1a14")
const BEAK := Color("ffb03a")
## Seconds the birds spend bursting apart, then settling back into the V.
const SCATTER_TIME := 1.1
const SETTLE_TIME := 1.6
## Speed multiplier while a startled flock flees.
const FLEE_SPEED := 3.0
## Bird size in px (body radius); wings span about 3.5x this.
const BODY := 15.0
## V spacing between birds in px.
const GAP := 70.0

var director: RingsDirector
var sky: SkyLife
## How many times any flock was startled (tests count events through this and the signal).
var startles := 0

var _t := 0.0
## One entry per flock: angle (from start), depth (fraction of the radius), dir (+1 / -1 round the
## planet), scatter (seconds since startled, < 0 when calm), kicks (per-bird burst offsets).
var _flocks: Array[Dictionary] = []


## Places the flocks evenly round the planet at different heights in the band (seeded).
func setup(p_director: RingsDirector, p_sky: SkyLife, seed_value: int) -> void:
	director = p_director
	sky = p_sky
	_flocks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + 5
	for i in sky.flocks:
		_flocks.append({
			"angle": TAU * float(i) / float(maxi(1, sky.flocks)) + rng.randf_range(-0.2, 0.2),
			"depth": lerpf(sky.inner + 0.06, sky.outer - 0.08, rng.randf()),
			"dir": 1.0 if i % 2 == 0 else -1.0,
			"scatter": -1.0,
			"kicks": [],
		})


func flock_count() -> int:
	return _flocks.size()


func is_scattered(i: int) -> bool:
	return float(_flocks[i].scatter) >= 0.0


## The flock's lead bird, in the planet's frame.
func centre(i: int) -> Vector2:
	var f: Dictionary = _flocks[i]
	return director.polar(float(f.angle), float(f.depth))


## Puts flock i at (angle from start, depth). Tests and shots stage a flock with this.
func place(i: int, angle_from_start: float, depth: float) -> void:
	_flocks[i].angle = angle_from_start
	_flocks[i].depth = clampf(depth, sky.inner, sky.outer)


## Every bird of flock i, in the planet's frame (the lead first).
func bird_points(i: int) -> PackedVector2Array:
	var f: Dictionary = _flocks[i]
	var c := centre(i)
	var up := c.normalized() if c != Vector2.ZERO else Vector2.UP
	var fwd := up.orthogonal() * float(f.dir)
	var k := _kick_amount(float(f.scatter))
	var kicks: Array = f.kicks
	var out := PackedVector2Array()
	for b in sky.flock_birds:
		var row := int((b + 1) / 2)
		var side := -1.0 if b % 2 == 1 else 1.0
		var p := c - fwd * GAP * row + up * side * GAP * 0.55 * row
		p += up * sin(_t * 1.6 + b * 0.9) * BODY * 0.4
		if k > 0.0 and b < kicks.size():
			p += (kicks[b] as Vector2) * k
		out.append(p)
	return out


func _kick_amount(s: float) -> float:
	if s < 0.0:
		return 0.0
	if s < SCATTER_TIME:
		return ease(s / SCATTER_TIME, 0.4)
	return 1.0 - ease(clampf((s - SCATTER_TIME) / SETTLE_TIME, 0.0, 1.0), 2.0)


func _process(delta: float) -> void:
	step(delta)


## One step: fly on round the band, startle near a worm, settle back.
func step(delta: float) -> void:
	if director == null or sky == null:
		return
	_t += delta
	var heads := _heads()
	for i in _flocks.size():
		var f: Dictionary = _flocks[i]
		var s := float(f.scatter)
		var speed := sky.flock_speed * (FLEE_SPEED if s >= 0.0 and s < SCATTER_TIME + SETTLE_TIME * 0.5 else 1.0)
		f.angle = wrapf(float(f.angle) + speed * float(f.dir) * delta, -PI, PI)
		if s >= 0.0:
			s += delta
			f.scatter = s if s < SCATTER_TIME + SETTLE_TIME else -1.0
			continue
		var c := centre(i)
		for h in heads:
			if h.distance_to(c) <= sky.flock_startle:
				_startle(i, h)
				break
	queue_redraw()


func _startle(i: int, head: Vector2) -> void:
	var f: Dictionary = _flocks[i]
	var c := centre(i)
	var up := c.normalized() if c != Vector2.ZERO else Vector2.UP
	var tangent := up.orthogonal()
	f.dir = 1.0 if (c - head).dot(tangent) >= 0.0 else -1.0   # fly on away from the worm
	f.scatter = 0.0
	var kicks: Array = []
	for b in sky.flock_birds:
		var a := TAU * float(b) / float(sky.flock_birds) + 0.4
		kicks.append(Vector2.from_angle(a) * GAP * 2.0 + up * GAP * 1.2)
	f.kicks = kicks
	startles += 1
	Audio.play(sky.flock_cue)
	startled.emit(i)


func _heads() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for w in director._worms():
		var p := w.head_position()
		if director.world:
			p = director.world.to_local(p)
		out.append(p)
	return out


func _draw() -> void:
	if director == null or sky == null:
		return
	for i in _flocks.size():
		var f: Dictionary = _flocks[i]
		var col: Color = sky.flock_colors[i % sky.flock_colors.size()] if not sky.flock_colors.is_empty() else Color("ffd23f")
		var c := centre(i)
		var up := c.normalized() if c != Vector2.ZERO else Vector2.UP
		var fwd := up.orthogonal() * float(f.dir)
		var pts := bird_points(i)
		var scared := float(f.scatter) >= 0.0 and float(f.scatter) < SCATTER_TIME + SETTLE_TIME * 0.5
		for b in pts.size():
			_bird(pts[b], up, fwd, col, _t * (16.0 if scared else 8.0) + b * 1.3, scared)


## One bird, side on: a round body, a tail, one wing flapping up and down on its back, a beak
## pointing where it flies, one eye (wide when startled).
func _bird(at: Vector2, up: Vector2, fwd: Vector2, col: Color, phase: float, scared: bool) -> void:
	var flap := sin(phase)
	var tail := PackedVector2Array([at - fwd * BODY * 0.7 + up * BODY * 0.2, at - fwd * BODY * 1.7 + up * BODY * 0.6,
			at - fwd * BODY * 1.6 - up * BODY * 0.1])
	_outlined(tail, col.darkened(0.15))
	draw_circle(at, BODY + 2.5, INK)
	draw_circle(at, BODY, col)
	draw_circle(at - up * BODY * 0.35 + fwd * BODY * 0.1, BODY * 0.55, col.lightened(0.45))   # belly
	var nose := at + fwd * BODY
	draw_colored_polygon(PackedVector2Array([nose + up * BODY * 0.35, nose + fwd * BODY * 0.8, nose - up * BODY * 0.35]), BEAK)
	var eye := at + fwd * BODY * 0.4 + up * BODY * 0.3
	draw_circle(eye, BODY * (0.36 if scared else 0.28), Color.WHITE)
	draw_circle(eye + fwd * BODY * 0.08, BODY * 0.14, INK)
	var wing := PackedVector2Array([at - fwd * BODY * 0.85 + up * BODY * 0.1, at + fwd * BODY * 0.05 + up * BODY * 0.15,
			at - fwd * BODY * 0.8 + up * BODY * (0.2 + 1.5 * flap)])
	_outlined(wing, col.lightened(0.2))


func _outlined(pts: PackedVector2Array, col: Color) -> void:
	# triangles drawn as primitives: no triangulation, so a wing mid-flap (flat) never errors
	var mid := (pts[0] + pts[1] + pts[2]) / 3.0
	var ol := PackedVector2Array()
	for q in pts:
		ol.append(q + (q - mid).normalized() * 2.5)
	draw_primitive(ol, PackedColorArray([INK, INK, INK]), PackedVector2Array())
	draw_primitive(pts, PackedColorArray([col, col, col]), PackedVector2Array())
