## A drifting space planet: a RigidBody2D with a size stage, no gravity, and a sleepy face.
## Bumped by something smaller it wakes up for a moment (eyes pop open), then dozes off again.
## SpaceDrift (S-11) also uses it for a themed planet's foods, moons, comets and the sun (`kind`):
## a bump shows a ring and a squash where it hit, pips round a big planet count its meal, a ripe
## planet is pale and wide-eyed (it is food now), and a food carrying a star trait wears a twinkling
## star. Placeholder art only: tinted circles.
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
## &"planet" (a big themed one), &"food" (its foods), &"moon", &"comet" or &"sun".
var kind: StringName = &"planet"
var data: PlanetData
var food: FoodData
var star_trait: TraitData
## Colours and size when set (a = 0 / 0.0 means "from the theme / the size stage").
var tint := Color(0, 0, 0, 0)
var tint2 := Color(0, 0, 0, 0)
var radius_override := 0.0
## The meal round a big planet: `pips` dots, `pips_full` filled; pip_colors per dot (the sun's five).
var pips := 0
var pips_full := 0
var pip_colors: Array[Color] = []
var ripe := false
var radius := 70.0
var eaten := false
var _bump := 0.0
var _bump_at := Vector2.ZERO
var _ripen := 0.0
var _awake := 0.0
var _t := 0.0


static func radius_for(stage: int) -> float:
	return 70.0 * pow(1.55, stage - 6)


func _ready() -> void:
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 0.5
	radius = radius_override if radius_override > 0.0 else radius_for(size_stage)
	mass = pow(radius / 70.0, 2.0)
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	shape.shape = c
	add_child(shape)
	linear_velocity = drift
	_t = randf() * 10.0


func color() -> Color:
	return tint if tint.a > 0.0 else THEMES.get(theme, Color.WHITE)


func accent() -> Color:
	return tint2 if tint2.a > 0.0 else color().darkened(0.2)


func wake() -> void:
	_awake = 1.2


## A smaller worm hit it: eyes open, a ring and a squash at the spot (global position).
func bump(at: Vector2) -> void:
	wake()
	_bump = 1.0
	_bump_at = (at - global_position).rotated(-rotation).limit_length(radius)


func bump_showing() -> bool:
	return _bump > 0.0


## Its meal is eaten: it drops to a size the worm can eat, goes pale and wide-eyed, and wobbles.
func ripen(stage: int) -> void:
	size_stage = stage
	ripe = true
	pips_full = pips
	_ripen = 1.0


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
	_bump = maxf(0.0, _bump - delta * 1.6)
	_ripen = maxf(0.0, _ripen - delta * 0.8)
	queue_redraw()


func _draw() -> void:
	var col := color()
	if ripe:
		col = col.lerp(Color.WHITE, 0.35)
	if kind == &"sun":
		for i in 12:
			var a := i * TAU / 12.0 + _t * 0.2
			var ray := PackedVector2Array([Vector2.from_angle(a - 0.12) * radius * 0.95,
					Vector2.from_angle(a) * radius * (1.32 + 0.05 * sin(_t * 3.0 + i)), Vector2.from_angle(a + 0.12) * radius * 0.95])
			draw_colored_polygon(ray, accent())
	if kind == &"comet":
		var back := -linear_velocity.normalized().rotated(-rotation) if linear_velocity.length() > 1.0 else Vector2.LEFT
		var side := back.orthogonal() * radius * 0.8
		draw_colored_polygon(PackedVector2Array([side, back * radius * 4.5, -side]), Color(col, 0.45))
	var squash := 1.0 - 0.12 * _bump + 0.08 * sin(_ripen * 18.0) * _ripen
	if squash != 1.0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 / squash, squash))
	draw_circle(Vector2.ZERO, radius + 6.0, OUTLINE)
	draw_circle(Vector2.ZERO, radius, col)
	draw_circle(Vector2(radius * 0.2, radius * 0.25), radius * 0.72, col.darkened(0.12))
	draw_circle(Vector2(-radius * 0.05, -radius * 0.05), radius * 0.7, col)
	for i in 4:
		var a := i * 1.7 + 0.4
		draw_circle(Vector2.from_angle(a) * radius * 0.6, radius * 0.11, accent() if kind != &"planet" else col.darkened(0.2))
	if kind == &"planet":
		for i in 3:
			draw_arc(Vector2.ZERO, radius * (0.35 + 0.18 * i), i * 1.3, i * 1.3 + 2.2, 18, accent(), maxf(4.0, radius * 0.05))
	# face: counter-rotated so it stays upright while the planet tumbles
	draw_set_transform(Vector2.ZERO, -rotation)
	var ex := radius * 0.32
	var ey := -radius * 0.08
	var w := maxf(3.0, radius * 0.06)
	for sx in [-1.0, 1.0]:
		var e := Vector2(sx * ex, ey)
		if _awake > 0.0 or ripe:
			draw_circle(e, radius * 0.16 + 3.0, OUTLINE)
			draw_circle(e, radius * 0.16, Color.WHITE)
			draw_circle(e, radius * 0.07, Color("1b1b2a"))
		else:
			draw_arc(e, radius * 0.13, 0.15, PI - 0.15, 10, OUTLINE, w)   # closed, sleepy
	var breathe := 1.0 + 0.15 * sin(_t * 1.6)
	if _awake > 0.0 or ripe:
		draw_circle(Vector2(0, radius * 0.32), radius * 0.12, OUTLINE)
	else:
		draw_circle(Vector2(0, radius * 0.3), radius * 0.06 * breathe, OUTLINE)
	# sleep bubble
	if _awake <= 0.0 and not ripe:
		var b := Vector2(radius * 0.55, -radius * 0.75) + Vector2(0, -fmod(_t * 14.0, 30.0))
		draw_arc(b, radius * 0.1 * breathe, 0, TAU, 14, Color(1, 1, 1, 0.8), 3.0)
	draw_set_transform(Vector2.ZERO)
	_draw_extras()


func _draw_extras() -> void:
	# the bump: a ring bursting out from where the worm hit
	if _bump > 0.0:
		var k := 1.0 - _bump
		draw_set_transform(Vector2.ZERO, 0.0)
		draw_arc(_bump_at, 30.0 + 90.0 * k, 0, TAU, 24, Color(1, 1, 1, _bump), 10.0 * _bump + 2.0)
		for i in 6:
			var a := i * TAU / 6.0 + 0.3
			draw_line(_bump_at + Vector2.from_angle(a) * (40.0 + 80.0 * k), _bump_at + Vector2.from_angle(a) * (70.0 + 110.0 * k),
					Color(1, 0.95, 0.6, _bump), 8.0)
	# the meal: pips round the planet, filled as its foods are eaten
	draw_set_transform(Vector2.ZERO, -rotation)
	for i in pips:
		var a := -PI / 2.0 + i * TAU / maxf(1.0, pips)
		var at := Vector2.from_angle(a) * (radius + 34.0)
		var pc: Color = pip_colors[i] if i < pip_colors.size() else color()
		draw_circle(at, 17.0, Color("fff6e0"))       # pale rim: empty pips read on dark space
		draw_circle(at, 13.0, OUTLINE)
		if i < pips_full:
			draw_circle(at, 10.0, pc)
	if ripe:
		draw_arc(Vector2.ZERO, radius + 58.0 + 6.0 * sin(_t * 5.0), 0, TAU, 48, Color(1, 1, 0.8, 0.7), 6.0)
	# a rare star trait rides on this one
	if star_trait != null:
		var at := Vector2.from_angle(_t * 1.5) * (radius + 26.0)
		_star(at, 20.0 + 4.0 * sin(_t * 8.0), Color("ffd94a"))
		draw_circle(at, 6.0, star_trait.color)
	draw_set_transform(Vector2.ZERO)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts: PackedVector2Array = []
	for i in 10:
		pts.append(c + Vector2.from_angle(-PI / 2.0 + i * PI / 5.0) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, OUTLINE, 3.0)
