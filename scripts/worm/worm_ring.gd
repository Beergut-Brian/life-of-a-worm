## A one-shot ring that bursts outward and fades (trait reveal, stage up).
class_name WormRing
extends Node2D

var color := Color.WHITE
var life := 0.6
var max_radius := 40.0
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / life
	var r := lerpf(6.0, max_radius, ease(k, 0.4))
	var c := color
	c.a = 1.0 - k
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, c, 3.0)
	for i in 8:
		var a := TAU * i / 8.0
		draw_circle(Vector2.from_angle(a) * r * 1.15, 2.0, c)
