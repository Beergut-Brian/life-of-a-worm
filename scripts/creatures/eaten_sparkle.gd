## Rides on a worm's head after it is gulped: half a second of invulnerability, drawn as a ring of
## twinkling sparkles in the player's colour. While it lives no creature can eat that worm
## (Gulp.is_safe). Steps on its own clock; tests call step(dt).
class_name EatenSparkle
extends Node2D

const SAFE_TIME := 0.5
const NAME := &"EatenSparkle"

var left := SAFE_TIME
var tint := Color.WHITE
var _t := 0.0


func _init() -> void:
	name = NAME
	z_index = 40


func _process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	_t += delta
	left -= delta
	if left <= 0.0:
		left = 0.0
		if not is_queued_for_deletion():
			queue_free()
	queue_redraw()


func is_safe() -> bool:
	return left > 0.0 and not is_queued_for_deletion()


func _draw() -> void:
	var k := 0.5 + 0.5 * clampf(left / SAFE_TIME, 0.0, 1.0)
	for i in 8:
		var a := TAU * i / 8.0 + _t * 5.0
		var r := 13.0 + 3.0 * sin(_t * 18.0 + i)
		var p := Vector2.from_angle(a) * r
		var s := 3.5 * (0.6 + 0.4 * absf(sin(_t * 20.0 + i * 1.7))) * (0.5 + 0.5 * k)
		draw_line(p + Vector2(-s, 0), p + Vector2(s, 0), Color(1, 1, 1, k), 1.0)
		draw_line(p + Vector2(0, -s), p + Vector2(0, s), Color(1, 1, 1, k), 1.0)
		draw_circle(p, s * 0.45, Color(tint, k))
