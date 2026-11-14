## The gardener's boot (stage 4): a big boot-shaped shadow slides over the surface above a worm, a
## slow rumble, it grows as it comes down, and halfway through its hang it STOMPS: the sole shows
## solid for a moment with dust puffs and a bonk. A worm smaller than the boot whose head is just
## under the sole (the top STOMP_DEPTH px of the ground) is squashed the one eaten way (Gulp: one
## segment shorter, dizzy, sparkles), never a stage or a trait. The warning is the shadow and the
## rumble, STOMP_AT s before the stomp. A boot the worm has outgrown stomps small and harmless.
## The gardener is never seen. Once a worm has outgrown it (L-17, gap-close-41) the boot is food for
## the moment it is down: from the stomp while the sole shows (STOMP_SHOW, longer for an outgrown
## boot: OUTGROWN_SHOW), a worm whose mouth meets it swallows it (the outgrow sting and grin the
## first time). Before the stomp it is only a shadow, so nothing can bite it.
class_name BootShadow
extends Creature

const FADE := 1.5
const HOLD := 2.0
## K-01: once the worm under it has outgrown the boot (data.size_stage), the shadow is drawn this
## small, so even at full strength (sole 1.3 r) it is under a stage-4 worm's head: a boot you have
## outgrown no longer looms. Bigger-than-me reads from size, never a colour or a number.
const OUTGROWN := 0.25
## Seconds after it arrives that it stomps (mid-hang): the shadow and rumble warn first (L-14).
const STOMP_AT := FADE + HOLD * 0.5
## Seconds the solid sole and dust show after the stomp.
const STOMP_SHOW := 0.5
## Seconds an outgrown boot stays down after its harmless stomp, so the worm under it can bite it.
const OUTGROWN_SHOW := 1.2
## px under the surface the stomp reaches (about three tiles): only a worm near the top is squashed.
const STOMP_DEPTH := 48.0
const STOMP_CUE := "bonk"   # existing file; a comic thump, never a pain sound

signal stomped(player: int)

var did_stomp := false
var _held := false   # a worm carried it: it stays where it was let go while it fades

var spot := Vector2.ZERO
var _up := Vector2.UP
var _life := 0.0


func _ready() -> void:
	super._ready()   # in group "food": is_available() says when a worm may eat it


## Food only while it is down (stomped, sole showing) and the worm nearest it has outgrown it.
func is_available() -> bool:
	return not _gone and not _carried and _block <= 0.0 and stomp_age() >= 0.0 and outgrown()


func pass_over(at: Vector2, up: Vector2) -> void:
	spot = at
	_up = up.normalized()
	position = spot
	_life = 0.0
	if data and data.bark != "":
		Audio.play(data.bark)


func strength() -> float:
	if _life < FADE:
		return _life / FADE
	if _life < FADE + HOLD:
		return 1.0
	return maxf(0.0, 1.0 - (_life - FADE - HOLD) / FADE)


func step(delta: float) -> void:
	if _gone:
		return
	_t += delta
	_life += delta
	_startle = maxf(0.0, _startle - delta)
	_block = maxf(0.0, _block - delta)   # just let go: not bitten again at once
	if data:
		for w in _worms():   # remember it as a threat, so the first bite of an outgrown boot stings
			if Outgrown.of(w).note(data.id, react_to(w), w.head_position().distance_to(global_position)):
				_on_outgrown()
	if _carried:   # in a worm's mouth (gentle bite): it rides along; let go, it is lifted away
		_held = true
		_life = maxf(_life - delta, FADE + HOLD)
		queue_redraw()
		return
	if not _held:
		position = spot + _up.orthogonal() * (_life - FADE - HOLD * 0.5) * 6.0
	rotation = _up.angle() + PI / 2.0
	if not did_stomp and _life >= STOMP_AT:
		stomp()
	if _life >= FADE * 2.0 + HOLD:
		_gone = true
		taken.emit(self)
		queue_free()
	queue_redraw()


## The stomp: thump, show the sole, squash every worm smaller than the boot that is under it.
func stomp() -> void:
	did_stomp = true
	Audio.play(STOMP_CUE)
	if not is_inside_tree():
		return
	for w in _worms():
		if threatens(w) and is_under(w.head_position()):
			if Gulp.eat(data.id if data else &"boot", w, w.head_position(), global_position):
				stomped.emit(w.player)


## Is a point (global px) under the sole: along the sole and within STOMP_DEPTH below the surface?
func is_under(p: Vector2) -> bool:
	var r := data.radius if data else 40.0
	var d := p - global_position
	var along := d.dot(_up.orthogonal())
	var down := -d.dot(_up)
	return absf(along) <= r * 1.3 and down >= -r * 0.5 and down <= STOMP_DEPTH


## Seconds since the stomp while the sole still shows, else -1.
func stomp_age() -> float:
	var a := _life - STOMP_AT
	return a if did_stomp and a <= show_time() else -1.0


## How long the sole stays down after the stomp: longer once outgrown, a moment to bite it.
func show_time() -> float:
	return OUTGROWN_SHOW if outgrown() else STOMP_SHOW


## True when the worm nearest the boot is big enough that the boot is no threat to it.
func outgrown() -> bool:
	if data == null or not is_inside_tree():
		return false
	var best: Node = null
	var best_d := INF
	for w in _worms():
		var d: float = w.head_position().distance_to(global_position)
		if d < best_d:
			best_d = d
			best = w
	return best != null and not data.is_threat_to(best.model.stage)


func _draw() -> void:
	var k := strength()
	var col := Color(0, 0, 0, 0.32 * k)
	var r := data.radius if data else 40.0
	var s := 0.7 + 0.3 * k   # gets bigger as it comes down
	if outgrown():
		s *= OUTGROWN
	# sole + heel, a boot from above
	var sole := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		sole.append(Vector2(cos(a) * r * 1.3, sin(a) * r * 0.32) * s + Vector2(r * 0.25, 0))
	draw_colored_polygon(sole, col)
	var heel := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		heel.append(Vector2(cos(a) * r * 0.45, sin(a) * r * 0.28) * s + Vector2(-r * 0.95, 0) * s)
	draw_colored_polygon(heel, col)
	var age := stomp_age()
	if age >= 0.0:   # the boot itself, for a moment: solid sole, ink outline, dust both sides
		var k2 := 1.0 - age / show_time()
		var boot := Color(data.color if data else Color(0.23, 0.16, 0.1), k2)
		draw_colored_polygon(sole, boot)
		draw_colored_polygon(heel, boot)
		sole.append(sole[0])
		draw_polyline(sole, Color(INK, k2), 2.0)
		for side in [-1.0, 1.0]:
			for i in 3:
				var c := Vector2(side * r * (1.4 + 0.25 * i + age), -r * 0.1 * i) * s
				draw_circle(c, r * (0.22 - 0.05 * i) * s * (1.0 + age), Color(0.85, 0.75, 0.6, 0.8 * k2))
