## A puddle (or any slow ground): worms inside move at 1 - drag * stats("drag/<kind>").
## Group "slow_zone": kind, drag, contains(point). Drawn as a rippling pool.
class_name SlowZone
extends Node2D

@export var kind: StringName = &"water"
@export var drag := 0.6
@export var size := Vector2(160, 100)
@export var color := Color(0.23, 0.53, 1.0, 0.55)
var _t := 0.0


func _ready() -> void:
	add_to_group("slow_zone")


func contains(p: Vector2) -> bool:
	return Rect2(global_position - size * 0.5, size).has_point(p)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	draw_rect(r, color)
	draw_rect(r, color.lightened(0.4), false, 2.0)
	for i in 6:
		var y := r.position.y + 10.0 + i * (size.y - 20.0) / 5.0
		var x := r.position.x + 12.0 + fmod(_t * 14.0 + i * 37.0, size.x - 40.0)
		draw_line(Vector2(x, y), Vector2(x + 14.0, y), Color(1, 1, 1, 0.45), 1.0)
