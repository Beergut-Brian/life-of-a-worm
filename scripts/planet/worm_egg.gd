## Drop-in: the second worm hatches from an egg next to the first. The egg wobbles, cracks
## (`egg_crack`), and `hatched` fires; the level then adds the worm, which pops out (`hatch`).
class_name WormEgg
extends Node2D

signal hatched()

const WOBBLE := 1.2

var player := 1
var _t := 0.0
var _done := false


func _ready() -> void:
	Audio.play("egg_crack")


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if not _done and _t >= WOBBLE:
		_done = true
		Audio.play("egg_crack")
		hatched.emit()
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.4)
		tw.tween_callback(queue_free)


func _draw() -> void:
	var col: Color = Players.COLOR[player]
	var tilt := sin(_t * 18.0) * 0.25 * minf(1.0, _t)
	draw_set_transform(Vector2.ZERO, tilt, Vector2.ONE)
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(Vector2(cos(a) * 9.0, sin(a) * 12.0 - (2.0 if sin(a) < 0.0 else 0.0)))
	draw_colored_polygon(pts, Color("fff3dc"))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color("2a1a14"), 1.5)
	for i in 3:
		draw_circle(Vector2(-4 + i * 4, -2 + (i % 2) * 5), 1.6, col)   # spots in the slot colour
	if _t > WOBBLE * 0.6:
		draw_polyline(PackedVector2Array([Vector2(-9, -1), Vector2(-4, -4), Vector2(0, 0), Vector2(4, -4), Vector2(9, -1)]), Color("2a1a14"), 1.5)
