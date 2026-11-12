## The "why" picture over a worm that just staged up (no words): the apex creature it ate, a plus,
## and a little worm of the segments it grew. The part that finished it (the cause) bounces and
## glows; then both fly into the worm's head and burst.
class_name StageWhy
extends Node2D

var worm: Worm
var cause: StringName = &""
var segments := 6
var color := Color.WHITE
var life := 1.6
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
		var up := -worm.head_position().normalized() if worm.head_position().length() > 1.0 else Vector2.UP
		var k := clampf((_t - life * 0.7) / (life * 0.3), 0.0, 1.0)
		position = worm.head_position() + up * lerpf(44.0 * worm.size_factor(), 0.0, ease(k, 2.0))
		rotation = up.angle() + PI / 2.0
		scale = Vector2.ONE * lerpf(1.0, 0.2, k)


func _draw() -> void:
	var pop := minf(1.0, _t / 0.15)
	var s := ease(pop, -2.0)
	var bounce := 1.0 + 0.25 * absf(sin(_t * 9.0))
	var apex_k := bounce if cause == &"apex" else 1.0
	var seg_k := bounce if cause == &"segments" else 1.0
	# backing bubble
	draw_circle(Vector2.ZERO, 34.0 * s, Color(1, 1, 1, 0.85))
	draw_arc(Vector2.ZERO, 34.0 * s, 0.0, TAU, 40, color, 3.0)
	_beetle(Vector2(-15, 0) * s, 8.0 * s * apex_k, cause == &"apex")
	# plus
	draw_line(Vector2(-3, 0) * s, Vector2(3, 0) * s, Color(0.2, 0.15, 0.1), 2.0)
	draw_line(Vector2(0, -3) * s, Vector2(0, 3) * s, Color(0.2, 0.15, 0.1), 2.0)
	_mini_worm(Vector2(16, 0) * s, s * seg_k, cause == &"segments")


func _beetle(at: Vector2, r: float, glow: bool) -> void:
	if glow:
		draw_circle(at, r * 1.6, Color(1, 0.95, 0.4, 0.6))
	var ink := Color(0.16, 0.1, 0.08)
	for i in 3:
		var y := (i - 1) * r * 0.55
		draw_line(at + Vector2(-r * 0.3, y), at + Vector2(-r * 1.3, y + r * 0.2), ink, 1.5)
		draw_line(at + Vector2(r * 0.3, y), at + Vector2(r * 1.3, y + r * 0.2), ink, 1.5)
	draw_circle(at, r, Color(0.42, 0.26, 0.55))
	draw_circle(at + Vector2(0, -r * 0.9), r * 0.5, Color(0.3, 0.18, 0.4))
	draw_circle(at + Vector2(-r * 0.25, -r * 1.0), r * 0.15, Color.WHITE)
	draw_circle(at + Vector2(r * 0.25, -r * 1.0), r * 0.15, Color.WHITE)
	# eaten: a big tick over it
	draw_polyline(PackedVector2Array([at + Vector2(-r, 0), at + Vector2(-r * 0.2, r * 0.8), at + Vector2(r * 1.2, -r * 1.1)]), Color(0.2, 0.75, 0.25), 3.0)


func _mini_worm(at: Vector2, s: float, glow: bool) -> void:
	var n := clampi(segments, 1, 12)
	var step := 3.2 * s
	var start := at - Vector2(step * (n - 1) * 0.5, 0)
	if glow:
		draw_circle(at, 14.0 * s, Color(1, 0.95, 0.4, 0.6))
	for i in n:
		var p := start + Vector2(step * i, sin(_t * 10.0 + i) * 1.2 * s)
		draw_circle(p, 2.4 * s, color.darkened(0.25))
		draw_circle(p, 1.8 * s, color)
	draw_circle(start + Vector2(step * n, 0), 3.0 * s, color)
