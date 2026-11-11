## The worm in space (stage 7): steerable, no gravity, a trail of segments, a crown of stars, and a
## mouth area that applies StageRule on contact. A placeholder for the real worm's space mode.
class_name SpaceWorm
extends CharacterBody2D

signal ate(player: int, what: StringName, growth: float)
signal touched(body: Node)

const OUTLINE := Color("2a1a14")

@export var player := 0
@export var size_stage := 7
@export var segments := 10
@export var seg_radius := 40.0
@export var max_speed := 420.0
@export var accel := 900.0
var steer := Vector2.ZERO        # set by the level each frame from the stick
var mouth_open := 0.0
var squash := 0.0
var _trail: PackedVector2Array = []
var _facing := Vector2.RIGHT

@onready var mouth: Area2D = $Mouth


func _ready() -> void:
	mouth.body_entered.connect(func(b): touched.emit(b))
	for i in 400:
		_trail.append(global_position - Vector2(i * 2.0, 0))


func body_color() -> Color:
	return Players.COLOR[player] if player in Players.COLOR else Color("3cc24a")


func _physics_process(delta: float) -> void:
	var want := steer.limit_length(1.0) * max_speed
	velocity = velocity.move_toward(want, accel * delta)
	move_and_slide()
	if velocity.length() > 20.0:
		_facing = _facing.slerp(velocity.normalized(), minf(1.0, delta * 8.0))
	mouth.position = _facing * seg_radius * 1.1
	if _trail.is_empty() or _trail[0].distance_to(global_position) > 2.0:
		_trail.insert(0, global_position)
		if _trail.size() > 600:
			_trail.resize(600)
	mouth_open = move_toward(mouth_open, 0.0, delta * 2.5)
	squash = move_toward(squash, 0.0, delta * 4.0)
	queue_redraw()


func add_segment() -> void:
	segments += 1
	squash = 1.0


func _draw() -> void:
	var col := body_color()
	var spacing := seg_radius * 0.95
	var dist := 0.0
	var idx := 0
	var points: Array[Vector2] = []
	for i in range(1, segments + 1):
		var need := i * spacing
		while idx < _trail.size() - 1 and dist + _trail[idx].distance_to(_trail[idx + 1]) < need:
			dist += _trail[idx].distance_to(_trail[idx + 1])
			idx += 1
		points.append(to_local(_trail[mini(idx + 1, _trail.size() - 1)]))
	for i in range(points.size() - 1, -1, -1):
		var r := seg_radius * (1.0 - 0.4 * float(i) / segments)
		draw_circle(points[i], r + 5.0, OUTLINE)
		draw_circle(points[i], r, col if i % 2 == 0 else col.darkened(0.08))
	var hr := seg_radius * 1.25 * (1.0 + squash * 0.15)
	draw_circle(Vector2.ZERO, hr + 5.0, OUTLINE)
	draw_circle(Vector2.ZERO, hr, col)
	var open := 0.1 + mouth_open * 0.7
	var poly: PackedVector2Array = [Vector2.ZERO]
	for s in 7:
		poly.append(_facing.rotated(lerpf(-open, open, s / 6.0)) * (hr + 3.0))
	draw_colored_polygon(poly, Color("5a1420"))
	var up := _facing.orthogonal() * (1.0 if _facing.x >= 0.0 else -1.0)   # screen-up side of the head
	var e := up * hr * 0.4 - _facing * hr * 0.1
	draw_circle(e, hr * 0.36 + 3.0, OUTLINE)
	draw_circle(e, hr * 0.36, Color.WHITE)
	draw_circle(e + _facing * hr * 0.12, hr * 0.16, Color("1b1b2a"))
	# stage 7 feature: a crown of stars
	for k in 3:
		var p := up * hr * (1.15 if k == 1 else 1.0) + _facing * (k - 1) * hr * 0.55
		_star(p, hr * (0.36 if k == 1 else 0.27))


func _star(c: Vector2, r: float) -> void:
	var pts: PackedVector2Array = []
	for i in 10:
		pts.append(c + Vector2.from_angle(-PI / 2.0 + i * PI / 5.0) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, Color("ffd94a"))
	pts.append(pts[0])
	draw_polyline(pts, OUTLINE, 3.0)
