## Placeholder "giant worm" for the planet shot, drawn in code: a chain of segments on an orbit round the
## planet, head leading clockwise, a jaw that opens and snaps, one big eye (P1). Not the real worm
## (scripts/worm/ is another lane's); just enough shape to read "a worm the size of a world".
class_name GiantWorm
extends Node2D

const OUTLINE := Color("2a1a14")

@export var body_color := Color("3cc24a")   # P1 green (Players.COLOR[P1])
@export var segments := 16
@export var seg_radius := 46.0
@export var spacing := 0.17                  # radians between segments
var orbit := 480.0
var head_angle := -PI / 2.0
var mouth_open := 0.0                         # 0 shut .. 1 wide
var belly := 0.0                              # 0 .. 1, the swallowed planet bulging down the body
var belly_at := 0.35                          # 0 head .. 1 tail
var squash := 0.0                             # bite squash pulse
var eye_closed := 0.0


func head_position() -> Vector2:
	return Vector2.from_angle(head_angle) * orbit


func mouth_position() -> Vector2:
	return head_position() + Vector2.from_angle(head_angle + PI / 2.0) * seg_radius * 1.3


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var stripe := body_color.lightened(0.35)
	for i in range(segments - 1, 0, -1):
		var k := float(i) / segments
		var a := head_angle - i * spacing
		var r := seg_radius * (1.0 - 0.45 * k * k)
		r *= 1.0 + belly * 0.9 * exp(-pow((k - belly_at) * 5.0, 2.0))
		var p := Vector2.from_angle(a) * orbit
		draw_circle(p, r + 6.0, OUTLINE)
		draw_circle(p, r, body_color if i % 2 == 0 else body_color.darkened(0.08))
		draw_circle(p - p.normalized() * r * 0.45, r * 0.4, stripe)
	_draw_head()


func _draw_head() -> void:
	var c := head_position()
	var fwd := Vector2.from_angle(head_angle + PI / 2.0)
	var out := c.normalized()
	var r := seg_radius * 1.35 * (1.0 + squash * 0.12)
	draw_circle(c, r + 6.0, OUTLINE)
	draw_circle(c, r, body_color)
	# jaw: a wedge cut forward, teeth on both lips
	var open := clampf(mouth_open, 0.0, 1.0) * 0.75 + 0.06
	var mouth: PackedVector2Array = [c + fwd * r * 0.1]
	for s in 9:
		var t := lerpf(-open, open, s / 8.0)
		mouth.append(c + fwd.rotated(t) * (r + 4.0))
	draw_colored_polygon(mouth, Color("5a1420"))
	if open > 0.15:
		for lip: float in [-1.0, 1.0]:
			for t in 3:
				var dir := fwd.rotated(lip * open * (0.3 + 0.28 * t))
				var base := c + dir * r * 0.95
				var side := dir.orthogonal() * r * 0.07
				var tip := c + fwd.rotated(lip * open * (0.3 + 0.28 * t) * 0.55) * r * 0.78
				draw_colored_polygon(PackedVector2Array([base + side, base - side, tip]), Color.WHITE)
	# one big eye, up and back on the head, looking where it is going
	var e := c + out * r * 0.42 - fwd * r * 0.12
	draw_circle(e, r * 0.38 + 4.0, OUTLINE)
	draw_circle(e, r * 0.38, Color.WHITE)
	draw_circle(e + fwd * r * 0.12, r * 0.18, Color("1b1b2a"))
	draw_circle(e + fwd * r * 0.16 + out * r * 0.06, r * 0.06, Color.WHITE)
	if eye_closed > 0.0:
		# lid comes down from the outside of the head
		var lid: PackedVector2Array = []
		for s in 13:
			var t := lerpf(-PI / 2.0, PI / 2.0, s / 12.0)
			lid.append(e + out.rotated(t) * (r * 0.38 + 2.0))
		var depth := lerpf(1.0, -1.0, eye_closed)
		lid.append(e + out * r * 0.38 * depth)
		draw_colored_polygon(lid, body_color.darkened(0.15))
