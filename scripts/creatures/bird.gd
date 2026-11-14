## The topsoil bird (stage 3): pecks from above when a smaller worm (or a beetle) is near the top.
## Its shadow lands on the spot and grows for the whole telegraph (at least a full second, with a
## tweet), then the beak comes down on THAT spot, never a moved one. A worm still under it is
## gulped (one segment, out with stars); a worm that wriggled off makes the beak hit the ground with
## a boing and the bird flies off offended. It can never eat a worm at or above its own stage: the
## peck boings off. Once a worm has outgrown it (L-17, gap-close-41) it is food like any creature:
## it cowers, its shadow shrinks, and a worm whose mouth meets it swallows it (the outgrow sting and
## grin the first time). It only joins the food list while the worm nearest it can eat it, so a
## small worm under its shadow never bonks off it. RingsDirector counts an eaten bird off the
## topsoil's bird counter (eat the birds and the beetles boom).
class_name Bird
extends Creature

enum Peck { ARRIVE, SHADOW, DIVE, LEAVE }

const ARRIVE_TIME := 0.5
const DIVE_TIME := 0.18
const LEAVE_TIME := 1.4
const PECK_RADIUS := 18.0
const HOVER := 40.0     # px above the top of the ground while it aims

## The spot it pecks (world px, fixed when the shadow appears) and which way is up there.
var spot := Vector2.ZERO
var phase := Peck.ARRIVE
var caught := false
var _phase_t := 0.0
var _up := Vector2.UP
var _from := Vector2.ZERO
var _hover := Vector2.ZERO
## True once a worm swallowed it (not when it flew off): the director's counter loses one.
var eaten := false
## K-01: a bird the nearest worm has outgrown draws its shadow this much smaller: it no longer looms.
const OUTGROWN_SHADOW := 0.5


func _ready() -> void:
	super._ready()   # in group "food": is_available() says when a worm may eat it
	add_to_group(&"birds")
	z_index = 5   # its shadow falls over the worm


## Aim at a spot: the bird flies in from above it; the shadow (the telegraph) starts on arrival.
## ground_top: px from the core of the top of the ground (0 = hover just above the spot).
func aim(at: Vector2, up: Vector2, ground_top := 0.0) -> void:
	spot = at
	_up = up.normalized()
	var h := maxf(0.0, ground_top - at.dot(_up)) if ground_top > 0.0 else 0.0
	_hover = at + _up * (h + HOVER)
	_from = _hover + _up * 220.0 + _up.orthogonal() * 120.0
	position = _from
	phase = Peck.ARRIVE
	_phase_t = 0.0


## Food only while the worm nearest it has outgrown it (CreatureSense via _nearest_can_eat_me).
func is_available() -> bool:
	return not _gone and not _carried and _block <= 0.0 and _scared


func take() -> void:
	if _gone:
		return
	eaten = true
	super.take()


## Seconds the shadow has been on the spot (0 before it lands).
func shadow_time() -> float:
	return _phase_t if phase == Peck.SHADOW else (data.telegraph_time() if phase != Peck.ARRIVE else 0.0)


func step(delta: float) -> void:
	if _gone or data == null:
		return
	_t += delta
	_phase_t += delta
	_startle = maxf(0.0, _startle - delta)
	_block = maxf(0.0, _block - delta)   # just let go: not bitten again at once
	_scared = _nearest_can_eat_me()
	if _carried:   # in a worm's mouth (gentle bite): it rides along; let go, it flies off
		phase = Peck.LEAVE
		_phase_t = 0.0
		queue_redraw()
		return
	for w in _worms():   # remember it as a threat, so the first bite of an outgrown bird stings
		if Outgrown.of(w).note(data.id, react_to(w), w.head_position().distance_to(global_position)):
			_on_outgrown()
	var hover := _hover
	match phase:
		Peck.ARRIVE:
			position = _from.lerp(hover, minf(1.0, _phase_t / ARRIVE_TIME))
			if _phase_t >= ARRIVE_TIME:
				phase = Peck.SHADOW
				_phase_t = 0.0
				if data.bark != "":
					Audio.play(data.bark)
		Peck.SHADOW:
			position = hover + Vector2(sin(_t * 5.0) * 2.0, 0).rotated(_up.angle() + PI / 2.0)
			if _phase_t >= data.telegraph_time():
				phase = Peck.DIVE
				_phase_t = 0.0
				if data.windup_cue != "":
					Audio.play(data.windup_cue)
		Peck.DIVE:
			position = hover.lerp(spot + _up * 6.0, minf(1.0, _phase_t / DIVE_TIME))
			if _phase_t >= DIVE_TIME:
				_land()
		Peck.LEAVE:
			position += (_up * 160.0 - _up.orthogonal() * 90.0) * delta
			if _phase_t >= LEAVE_TIME:
				_gone = true
				taken.emit(self)
				queue_free()
	rotation = _up.angle() + PI / 2.0
	queue_redraw()


func _land() -> void:
	caught = false
	for w in _worms():
		if w.head_position().distance_to(spot) <= PECK_RADIUS * w.size_factor() and threatens(w):
			if not Gulp.eat(data.id, w, spot - _up * 14.0, spot):
				continue
			ate_worm.emit(w.player)
			caught = true
			Audio.play("bird_gulp")
			break
	if not caught and data.hunts != &"":
		for c in get_tree().get_nodes_in_group(&"creatures"):
			if c is Creature and not (c is Bird) and c.data and c.data.id == data.hunts \
					and c.global_position.distance_to(spot) <= PECK_RADIUS + c.data.radius:
				ate_creature.emit(c)
				c.take()
				caught = true
				Audio.play("bird_gulp")
				break
	if not caught:
		Audio.play("boing")
		Audio.play("bird_offended")
	phase = Peck.LEAVE
	_phase_t = 0.0


func _draw() -> void:
	if data == null:
		return
	# The shadow on the spot: grows over the telegraph so the kid sees it coming.
	if phase == Peck.SHADOW or phase == Peck.DIVE:
		var k := minf(1.0, _phase_t / data.telegraph_time()) if phase == Peck.SHADOW else 1.0
		var at := to_local(spot)
		var w := PECK_RADIUS * (0.9 + 0.9 * k) * (OUTGROWN_SHADOW if _scared else 1.0)
		_ellipse(at, Vector2(w, w * 0.55), Color(0, 0, 0, 0.22 + 0.3 * k))
		_ellipse(at, Vector2(w, w * 0.55) * 0.5, Color(0, 0, 0, 0.2 * k))
		# a pulsing target ring, so the spot shows even with a worm on it
		var ring_r := w + 3.0 + sin(_t * 14.0) * 1.5
		draw_arc(at, ring_r, 0.0, TAU, 28, Color(1, 1, 1, 0.35 + 0.4 * k), 1.5)
		# and the bird's shadow on the grass above
		var ground := to_local(_hover - _up * HOVER)
		_ellipse(ground, Vector2(w * 0.8, w * 0.3), Color(0, 0, 0, 0.3))
	var r := data.radius * draw_scale()   # cowers (0.85x) when the nearest worm could eat it
	var flap := sin(_t * (18.0 if phase != Peck.SHADOW else 9.0)) * r * 0.6
	var col := data.color
	# wings
	draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.2, -r * 0.2), Vector2(-r * 1.6, -r * 0.3 - flap), Vector2(-r * 0.4, r * 0.3)]), INK)
	draw_colored_polygon(PackedVector2Array([Vector2(r * 0.2, -r * 0.2), Vector2(r * 1.6, -r * 0.3 - flap), Vector2(r * 0.4, r * 0.3)]), INK)
	draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.2, -r * 0.1), Vector2(-r * 1.4, -r * 0.3 - flap), Vector2(-r * 0.4, r * 0.2)]), data.accent)
	draw_colored_polygon(PackedVector2Array([Vector2(r * 0.2, -r * 0.1), Vector2(r * 1.4, -r * 0.3 - flap), Vector2(r * 0.4, r * 0.2)]), data.accent)
	draw_circle(Vector2.ZERO, r + 1.2, INK)
	draw_circle(Vector2.ZERO, r, col)
	draw_circle(Vector2(0, r * 0.3), r * 0.55, col.lightened(0.4))
	# beak points at the ground (local +y is toward the core)
	var beak_len := r * (1.3 if phase == Peck.DIVE else 0.8)
	draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.3, r * 0.6), Vector2(r * 0.3, r * 0.6), Vector2(0, r * 0.6 + beak_len)]), Color("f2a33a"))
	var e := r * 0.22
	for sx in [-1.0, 1.0]:
		var c := Vector2(sx * r * 0.38, -r * 0.1)
		if phase == Peck.LEAVE and not caught:
			# offended: eyes shut tight, nose in the air
			draw_line(c + Vector2(-e, -1), c + Vector2(e, 1), INK, 1.2)
		else:
			draw_circle(c, e + 1.0, Color.WHITE)
			draw_circle(c, e * 0.5, INK)


## K-01: bigger-than-me reads from size. When the worm nearest the bird is big enough to eat it, the
## bird cowers (draws smaller than that worm's head) instead of looming over it.
func _nearest_can_eat_me() -> bool:
	var best: Node = null
	var best_d := INF
	for w in _worms():
		var d: float = w.head_position().distance_to(global_position)
		if d < best_d:
			best_d = d
			best = w
	return best != null and not data.is_threat_to(best.model.stage)


func _ellipse(at: Vector2, radii: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(at + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, col)
