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
## Zoom to fit: when on, each frame picks the closest whole-pixel zoom (never above max_fit_index,
## never below min_fit_index) that keeps every target's fit_rect on screen. Stages lower the cap.
var fit := false
var max_fit_index := 6
var min_fit_index := 3
## Screen margin kept round the fitted bodies, in screen pixels.
var fit_margin := 160.0
## Zoom steps wait this long between changes so the view never flickers between two steps.
var fit_hold := 0.4
## Shake: decays each frame; the stage-up sets it.
var shake := 0.0
var _fit_t := 0.0
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
			up += _tpos(t).normalized()
	if up.length_squared() < 0.01:
		return  # targets on opposite sides: hold the current angle
	rotation = rotate_toward(rotation, up_rotation(up), max_turn_rate * delta)
	if fit:
		_fit_t += delta
		var want := fit_index()
		if want != zoom_index and _fit_t >= fit_hold:
			_fit_t = 0.0
			zoom_index += signi(want - zoom_index)
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 2.5)
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 24.0 / zoom.x
	elif offset != Vector2.ZERO:
		offset = Vector2.ZERO


## The zoom step that fits every target (in the camera's rotated frame) under the cap.
func fit_index() -> int:
	var view := get_viewport_rect().size if is_inside_tree() else Vector2(1920, 1080)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var inv := Transform2D(-rotation, Vector2.ZERO)
	for t in targets:
		if not is_instance_valid(t):
			continue
		var pts: Array = [_tpos(t)]
		if t.has_method("fit_points"):
			pts = t.fit_points()
		for p: Vector2 in pts:
			var q: Vector2 = inv * (p - position)
			lo = lo.min(q)
			hi = hi.max(q)
	if lo.x == INF:
		return clampi(zoom_index, min_fit_index, max_fit_index)
	var half := Vector2(maxf(absf(lo.x), absf(hi.x)), maxf(absf(lo.y), absf(hi.y)))
	for i in range(max_fit_index, min_fit_index - 1, -1):
		var room := view * 0.5 / ZOOMS[i] - Vector2.ONE * fit_margin / ZOOMS[i]
		if half.x <= room.x and half.y <= room.y:
			return i
	return min_fit_index


## True when the point is on screen at the current zoom and rotation.
func sees(p: Vector2, margin := 40.0) -> bool:
	var view := get_viewport_rect().size if is_inside_tree() else Vector2(1920, 1080)
	var q: Vector2 = Transform2D(-rotation, Vector2.ZERO) * (p - position) * zoom.x
	return absf(q.x) <= view.x * 0.5 - margin and absf(q.y) <= view.y * 0.5 - margin


func _centre() -> Vector2:
	if centre_override != null:
		return centre_override
	var s := Vector2.ZERO
	var n := 0
	for t in targets:
		if is_instance_valid(t):
			s += _tpos(t)
			n += 1
	return s / maxi(n, 1)


## A target's point: its cam_position() if it has one (a Worm: its head), else its position.
static func _tpos(t: Node2D) -> Vector2:
	return t.cam_position() if t.has_method("cam_position") else t.position
