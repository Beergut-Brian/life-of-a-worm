## The topsoil and surface dressing near the camera (placeholder art, drawn in code): grass blades
## that sway along the top of the ground, big friendly mushrooms, the picnic sandwich whose crumbs
## fall into the topsoil, the anthill where the ant trail comes up, and rain (clouds and streaks
## falling toward the core) while RingsDirector.raining. Draws only the arc on screen.
class_name TopsoilDressing
extends Node2D

const INK := Color("2a1a14")
const GRASS := [Color("5f9e36"), Color("74b843"), Color("8bc94f")]
const RAIN := Color(0.62, 0.78, 1.0, 0.75)

var director: RingsDirector
var _t := 0.0
var _rain_k := 0.0
## The planet's eaten outline (W-12): no grass or mushroom stands where the rim has been eaten away.
var _edge: DiskEdge


func _process(delta: float) -> void:
	_t += delta
	_rain_k = move_toward(_rain_k, 1.0 if director and director.raining else 0.0, delta * 0.5)
	queue_redraw()


func _view() -> Dictionary:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return {}
	var c := cam.get_screen_center_position()
	var half := get_viewport_rect().size.length() * 0.5 / cam.zoom.x
	return { "c": c, "half": half }


func _draw() -> void:
	if director == null or director.world == null:
		return
	var v := _view()
	if v.is_empty():
		return
	var R := director.ground_top()
	var c: Vector2 = v.c
	if absf(c.length() - R) > v.half + 200.0:
		return
	var span: float = (v.half + 40.0) / R
	var a0 := c.angle() - span
	var a1 := c.angle() + span
	_edge = DiskEdge.of(director.world)
	_grass(R, a0, a1)
	_mushrooms(R, a0, a1)
	if _in(director.sandwich.angle(), a0, a1):
		_sandwich(director.sandwich)
	if _in(director.anthill.angle(), a0, a1):
		_anthill(director.anthill)
	if _rain_k > 0.01:
		_rain(R, a0, a1)


func _in(a: float, a0: float, a1: float) -> bool:
	var mid := (a0 + a1) * 0.5
	return absf(wrapf(a - mid, -PI, PI)) <= (a1 - a0) * 0.5


## False where the worm has eaten the ground away under this angle (DiskEdge).
func _ground_at(a: float, R: float) -> bool:
	return _edge == null or _edge.target_at(a) >= R - 2.0


func _grass(R: float, a0: float, a1: float) -> void:
	var step := 5.0 / R
	var a := floorf(a0 / step) * step
	while a < a1:
		if not _ground_at(a, R):
			a += step
			continue
		var i := int(round(a / step))
		var h := 5.0 + float(absi(i * 7919) % 6)
		var up := Vector2.from_angle(a)
		var side := up.orthogonal()
		var sway := sin(_t * 1.6 + a * 900.0) * 1.5
		var base := up * (R - 1.0)
		draw_line(base, base + up * h + side * sway, GRASS[absi(i) % 3], 2.0)
		a += step


func _mushrooms(R: float, a0: float, a1: float) -> void:
	var step := 0.011
	var a := floorf(a0 / step) * step
	while a < a1:
		var i := int(round(a / step))
		if absi(i * 31337) % 3 == 0 and _ground_at(a, R):
			var up := Vector2.from_angle(a + 0.002 * float(absi(i) % 5))
			var side := up.orthogonal()
			var base := up * R
			var h := 7.0 + float(absi(i) % 4)
			draw_line(base, base + up * h, INK, 5.0)
			draw_line(base, base + up * h, Color("f3e7d0"), 3.0)
			var cap := PackedVector2Array()
			for k in 11:
				var t := PI * k / 10.0
				cap.append(base + up * h + side * cos(t) * 8.0 + up * sin(t) * 6.0)
			draw_colored_polygon(cap, Color("d8483a") if i % 2 == 0 else Color("e9a23b"))
			draw_circle(base + up * (h + 3.0) + side * 2.5, 1.4, Color.WHITE)
			draw_circle(base + up * (h + 2.0) - side * 3.0, 1.1, Color.WHITE)
		a += step


func _sandwich(at: Vector2) -> void:
	var up := at.normalized()
	var s := up.orthogonal()
	var b := at + up * 1.0
	var layers := [[0.0, 5.0, Color("e8c07a")], [5.0, 2.5, Color("6fbf4a")], [7.5, 3.0, Color("d8483a")], [10.5, 2.5, Color("f2d24b")], [13.0, 6.0, Color("e8c07a")]]
	for l in layers:
		var lo: Vector2 = b + up * float(l[0])
		var pts := PackedVector2Array([lo - s * 26.0, lo + s * 18.0, lo + s * 18.0 + up * float(l[1]), lo - s * 26.0 + up * float(l[1])])
		draw_colored_polygon(pts, INK)
		var inner := PackedVector2Array([pts[0] + s + up * 0.5, pts[1] - s + up * 0.5, pts[2] - s - up * 0.5, pts[3] + s - up * 0.5])
		draw_colored_polygon(inner, l[2])
	# a bite out of the corner
	draw_circle(b + s * 18.0 + up * 15.0, 6.0, Color(0, 0, 0, 0))
	for i in 3:
		draw_circle(b + s * (14.0 + i * 2.0) + up * (18.0 - i * 3.0), 3.0, Color("0d1430"))


func _anthill(at: Vector2) -> void:
	var up := at.normalized()
	var s := up.orthogonal()
	var base := at.normalized() * director.ground_top()
	var mound := PackedVector2Array()
	for k in 13:
		var t := PI * k / 12.0
		mound.append(base + s * cos(t) * 26.0 + up * sin(t) * 13.0)
	draw_colored_polygon(mound, Color("9a6a3c"))
	draw_circle(base + up * 6.0, 3.5, INK)                 # the door
	draw_line(base + up * 13.0, base + up * 28.0, INK, 1.0)  # the flag
	draw_colored_polygon(PackedVector2Array([base + up * 28.0, base + up * 24.0 + s * 8.0, base + up * 20.0]), Color("d8483a"))


func _rain(R: float, a0: float, a1: float) -> void:
	var col := Color(RAIN, RAIN.a * _rain_k)
	var cloud := Color(0.55, 0.6, 0.7, 0.8 * _rain_k)
	var step := 0.006
	var a := floorf(a0 / step) * step
	while a < a1:
		var i := int(round(a / step))
		var up := Vector2.from_angle(a)
		draw_circle(up * (R + 230.0 + float(absi(i) % 3) * 6.0), 26.0 + float(absi(i * 13) % 10), cloud)
		a += step
	step = 9.0 / R
	a = floorf(a0 / step) * step
	while a < a1:
		var i := int(round(a / step))
		var up := Vector2.from_angle(a + 0.0005 * float(absi(i * 7) % 7))
		var fall := fmod(_t * 420.0 + float(absi(i * 7919) % 211), 230.0)
		var top := R + 215.0 - fall
		draw_line(up * top, up * (top - 9.0), col, 1.0)
		if fall > 214.0:
			draw_circle(up * R, 1.5, col)   # splash on the grass
		a += step
