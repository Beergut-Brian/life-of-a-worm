## The shared rotating camera: "down" (toward the core) stays at the bottom of the screen. Rotation
## follows the targets' mean up-direction at a capped rate; zoom is whole-pixel only (n or 1/n).
class_name PolarCamera
extends Camera2D

## Whole-pixel zoom steps, widest first: 1/16 shows the whole 1,000-tile disk on a 1080p screen.
const ZOOMS: Array[float] = [1.0 / 16.0, 1.0 / 8.0, 1.0 / 4.0, 1.0 / 2.0, 1.0, 2.0, 3.0, 4.0]

var targets: Array[Node2D] = []
## When set (a Vector2), the camera centres here instead of on the targets (the planet shot).
var centre_override = null
## Radians per second.
var max_turn_rate := 1.2
var follow := 6.0
var zoom_index := 5:
	set(v):
		zoom_index = clampi(v, 0, ZOOMS.size() - 1)
		zoom = Vector2.ONE * ZOOMS[zoom_index]


func _ready() -> void:
	ignore_rotation = false
	zoom_index = zoom_index


## Rotation that puts "up" (away from the core at `pos`) at the top of the screen. Godot's y is
## down, so this is pos.angle() + PI/2 (the plan's -position.angle() is the y-up form of it).
static func up_rotation(pos: Vector2) -> float:
	return pos.angle() + PI / 2.0


func snap() -> void:
	var c := _centre()
	position = c
	if c.length_squared() > 1.0:
		rotation = up_rotation(c)


func _process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if targets.is_empty():
		return
	var c := _centre()
	position = position.lerp(c, 1.0 - exp(-follow * delta))
	var up := Vector2.ZERO
	for t in targets:  # rotation always follows the worms, even in the planet shot
		if is_instance_valid(t):
			up += t.position.normalized()
	if up.length_squared() < 0.01:
		return  # targets on opposite sides: hold the current angle
	rotation = rotate_toward(rotation, up_rotation(up), max_turn_rate * delta)


func _centre() -> Vector2:
	if centre_override != null:
		return centre_override
	var s := Vector2.ZERO
	var n := 0
	for t in targets:
		if is_instance_valid(t):
			s += t.position
			n += 1
	return s / maxi(n, 1)
