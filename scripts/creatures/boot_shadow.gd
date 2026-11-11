## The gardener's boot (stage 4), seen only as a shadow for now: a big boot-shaped shadow slides
## over the surface above a worm, a slow rumble, it hangs there, and lifts away. It never stomps in
## the slice (a stage-4 threat later); the gardener is never seen. Not food, never eats.
class_name BootShadow
extends Creature

const FADE := 1.5
const HOLD := 2.0

var spot := Vector2.ZERO
var _up := Vector2.UP
var _life := 0.0


func _ready() -> void:
	super._ready()
	remove_from_group(&"food")


func is_available() -> bool:
	return false


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
	position = spot + _up.orthogonal() * (_life - FADE - HOLD * 0.5) * 6.0
	rotation = _up.angle() + PI / 2.0
	if _life >= FADE * 2.0 + HOLD:
		_gone = true
		taken.emit(self)
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := strength()
	var col := Color(0, 0, 0, 0.32 * k)
	var r := data.radius if data else 40.0
	var s := 0.7 + 0.3 * k   # gets bigger as it comes down
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
