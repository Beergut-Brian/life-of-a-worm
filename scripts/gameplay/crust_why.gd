## The "why" bubble over a worm that just broke through the crust (no words): a sun and sky over a
## strip of grass with a crack in it, the worm's head poking up through the crack. It pops, the head
## bobs, then it shrinks into the worm's head. Placeholder drawing, the final look is the Art lane's.
class_name CrustWhy
extends Node2D

var worm: Worm
var color := Color.WHITE
var life := 1.8
var _t := 0.0


func _ready() -> void:
	z_index = 45
	_follow()


func _process(delta: float) -> void:
	_t += delta
	if _t >= life or not is_instance_valid(worm):
		queue_free()
		return
	_follow()
	queue_redraw()


func _follow() -> void:
	if is_instance_valid(worm):
		var up := worm.head_position().normalized() if worm.head_position().length() > 1.0 else Vector2.UP
		var k := clampf((_t - life * 0.7) / (life * 0.3), 0.0, 1.0)
		position = worm.head_position() + up * lerpf(64.0 * worm.size_factor(), 0.0, ease(k, 2.0))
		rotation = up.angle() + PI / 2.0
		scale = Vector2.ONE * lerpf(1.6, 0.2, k)


func _draw() -> void:
	var s := ease(minf(1.0, _t / 0.15), -2.0)
	var bob := absf(sin(_t * 8.0)) * 4.0
	var r := 34.0 * s
	draw_circle(Vector2.ZERO, r, Color("9fd8f0"))          # sky
	draw_circle(Vector2(14, -14) * s, 7.0 * s, Color("ffe066"))   # sun
	# grass strip across the bottom of the bubble, split by the crack
	var g := Color("8bb04a")
	draw_rect(Rect2(Vector2(-30, 8) * s, Vector2(22, 12) * s), g)
	draw_rect(Rect2(Vector2(8, 8) * s, Vector2(22, 12) * s), g)
	draw_rect(Rect2(Vector2(-30, 18) * s, Vector2(60, 10) * s), Color("8a5a32"))
	# the worm's head coming up through the crack
	var head := Vector2(0, 6.0 - bob) * s
	draw_rect(Rect2(Vector2(-5, 6.0 - bob) * s, Vector2(10, 16.0 + bob) * s), color)
	draw_circle(head, 7.0 * s, color)
	draw_circle(head + Vector2(-2.5, -2) * s, 1.6 * s, Color(0.1, 0.08, 0.06))
	draw_circle(head + Vector2(2.5, -2) * s, 1.6 * s, Color(0.1, 0.08, 0.06))
	# crumbs flying out of the crack
	for i in 5:
		var a := -PI / 2.0 + (i - 2) * 0.45
		var d := (8.0 + fmod(_t * 30.0 + i * 5.0, 18.0)) * s
		draw_circle(Vector2(0, 8) * s + Vector2.from_angle(a) * d, 2.0 * s, Color("6b4423"))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color.WHITE, 3.0)
	draw_arc(Vector2.ZERO, r + 2.0, 0.0, TAU, 40, color, 2.0)
