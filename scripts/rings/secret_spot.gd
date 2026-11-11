## A ring's hidden place, drawn (placeholder): the ant city is a little town of ant domes with lit
## windows and doors, flags with tiny hats and a string of lights across the hall. The cavern itself
## is carved by RingsDirector and kept (a keep zone: it never regrows shut).
class_name SecretSpot
extends Node2D

const INK := Color("2a1a14")

var data: SecretData
var director: RingsDirector
var _t := 0.0


func _ready() -> void:
	z_index = -1


func _process(delta: float) -> void:
	_t += delta
	if get_viewport().get_camera_2d() and get_viewport().get_camera_2d().get_screen_center_position().distance_to(position) < 1400.0:
		queue_redraw()


func _draw() -> void:
	if data == null:
		return
	var up := position.normalized()
	var s := up.orthogonal()
	var r := data.radius_tiles * 16.0
	var floor_p := -up * (r * 0.62)
	# warm glow in the hall
	draw_circle(Vector2.ZERO, r * 0.9, Color(1.0, 0.8, 0.45, 0.08))
	# string of lights
	for i in 9:
		var t := float(i) / 8.0
		var p := s * lerpf(-r * 0.8, r * 0.8, t) + up * (r * 0.45 - sin(t * PI) * 14.0)
		var on := fmod(_t * 2.0 + i * 0.37, 1.0) > 0.25
		draw_circle(p, 2.5, Color("ffd36a") if on else Color("a8873a"))
	# domes along the floor
	var cols := [Color("c97b4a"), Color("b8693e"), Color("d68e57"), Color("a65e36")]
	for i in 4:
		var x := lerpf(-r * 0.65, r * 0.65, float(i) / 3.0)
		var base := floor_p + s * x
		var h := 16.0 + (i % 2) * 6.0
		var dome := PackedVector2Array()
		for k in 13:
			var t := PI * k / 12.0
			dome.append(base + s * cos(t) * 13.0 + up * sin(t) * h)
		draw_colored_polygon(dome, INK)
		var inner := PackedVector2Array()
		for k in 13:
			var t := PI * k / 12.0
			inner.append(base + s * cos(t) * 11.5 + up * (sin(t) * (h - 1.5)))
		draw_colored_polygon(inner, cols[i])
		draw_circle(base + up * 4.0, 3.5, INK)                                     # door
		var lit := 0.6 + 0.4 * sin(_t * 1.5 + i)
		draw_circle(base + up * (h * 0.6) + s * 5.0, 2.0, Color(1, 0.85, 0.4, lit))  # window
		# flag with a tiny hat on top
		var top := base + up * h
		draw_line(top, top + up * 10.0, INK, 1.0)
		draw_colored_polygon(PackedVector2Array([top + up * 10.0, top + up * 7.0 + s * 6.0, top + up * 4.0]), Color.from_hsv(0.1 * i, 0.7, 0.95))
