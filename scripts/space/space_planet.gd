## A drifting space planet: a RigidBody2D with a size stage, no gravity, and a sleepy face.
## Bumped by something smaller it wakes up for a moment (eyes pop open), then dozes off again.
class_name SpacePlanet
extends RigidBody2D

const OUTLINE := Color("2a1a14")
const THEMES := {
	&"ice": Color("bfe6f5"), &"jungle": Color("4fae5a"), &"junk": Color("8d8f96"),
	&"candy": Color("f39ac3"), &"clockwork": Color("d7a645"),
}

@export var size_stage := 6
@export var theme: StringName = &"ice"
@export var drift := Vector2.ZERO
var radius := 70.0
var eaten := false
var _awake := 0.0
var _t := 0.0


static func radius_for(stage: int) -> float:
	return 70.0 * pow(1.55, stage - 6)


func _ready() -> void:
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 0.5
	radius = radius_for(size_stage)
	mass = pow(radius / 70.0, 2.0)
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	shape.shape = c
	add_child(shape)
	linear_velocity = drift
	_t = randf() * 10.0


func color() -> Color:
	return THEMES.get(theme, Color.WHITE)


func wake() -> void:
	_awake = 1.2


func be_eaten(mouth: Node2D) -> void:
	if eaten:
		return
	eaten = true
	set_deferred("freeze", true)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	var tw := create_tween().set_parallel()
	tw.tween_method(func(k: float): global_position = global_position.lerp(mouth.global_position, k), 0.0, 0.6, 0.35)
	tw.tween_property(self, "scale", Vector2.ONE * 0.05, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)


func _process(delta: float) -> void:
	_t += delta
	_awake = maxf(0.0, _awake - delta)
	queue_redraw()


func _draw() -> void:
	var col := color()
	draw_circle(Vector2.ZERO, radius + 6.0, OUTLINE)
	draw_circle(Vector2.ZERO, radius, col)
	draw_circle(Vector2(radius * 0.2, radius * 0.25), radius * 0.72, col.darkened(0.12))
	draw_circle(Vector2(-radius * 0.05, -radius * 0.05), radius * 0.7, col)
	for i in 4:
		var a := i * 1.7 + 0.4
		draw_circle(Vector2.from_angle(a) * radius * 0.6, radius * 0.11, col.darkened(0.2))
	# face: counter-rotated so it stays upright while the planet tumbles
	draw_set_transform(Vector2.ZERO, -rotation)
	var ex := radius * 0.32
	var ey := -radius * 0.08
	var w := maxf(3.0, radius * 0.06)
	for sx in [-1.0, 1.0]:
		var e := Vector2(sx * ex, ey)
		if _awake > 0.0:
			draw_circle(e, radius * 0.16 + 3.0, OUTLINE)
			draw_circle(e, radius * 0.16, Color.WHITE)
			draw_circle(e, radius * 0.07, Color("1b1b2a"))
		else:
			draw_arc(e, radius * 0.13, 0.15, PI - 0.15, 10, OUTLINE, w)   # closed, sleepy
	var breathe := 1.0 + 0.15 * sin(_t * 1.6)
	if _awake > 0.0:
		draw_circle(Vector2(0, radius * 0.32), radius * 0.12, OUTLINE)
	else:
		draw_circle(Vector2(0, radius * 0.3), radius * 0.06 * breathe, OUTLINE)
	# sleep bubble
	if _awake <= 0.0:
		var b := Vector2(radius * 0.55, -radius * 0.75) + Vector2(0, -fmod(_t * 14.0, 30.0))
		draw_arc(b, radius * 0.1 * breathe, 0, TAU, 14, Color(1, 1, 1, 0.8), 3.0)
	draw_set_transform(Vector2.ZERO)
