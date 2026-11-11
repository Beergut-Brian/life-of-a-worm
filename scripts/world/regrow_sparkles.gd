## A short twinkle where a tile grows back or a garden fills a cell, so regrowth is seen, not just
## noticed later. Capped; draws in world space.
class_name RegrowSparkles
extends Node2D

const LIFE := 0.8
const CAP := 240

var _items: Array[Vector3] = []  # x, y, time left


func add(pos: Vector2) -> void:
	if _items.size() < CAP:
		_items.append(Vector3(pos.x, pos.y, LIFE))


func _process(delta: float) -> void:
	if _items.is_empty():
		return
	for i in _items.size():
		_items[i].z -= delta
	_items = _items.filter(func(v: Vector3) -> bool: return v.z > 0.0)
	queue_redraw()


func _draw() -> void:
	for v in _items:
		var k := v.z / LIFE
		var s := 3.0 + 9.0 * (1.0 - k)
		var c := Color(1.0, 0.97, 0.7, k)
		var p := Vector2(v.x, v.y)
		draw_line(p - Vector2(s, 0), p + Vector2(s, 0), c, 2.0)
		draw_line(p - Vector2(0, s), p + Vector2(0, s), c, 2.0)
