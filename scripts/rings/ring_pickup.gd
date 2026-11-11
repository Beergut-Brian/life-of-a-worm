## A dirt or topsoil food on the planet (RingFood): the ArenaFood pickup protocol worms already eat
## and carry, drawn in its own shape (seed, root, mushroom, crumb, honeydew, egg, pebble). The face
## goes wide-eyed and trembles when a worm that can eat it comes near; smug when a small one bonks it.
## species != &"": a live body of a population counter (freed when eaten; the counter regrows it).
class_name RingPickup
extends ArenaFood

var species: StringName
## Statically placed: regrows where it was after RingFood.regrow_time planet seconds.
var gone_at := -1.0


func _draw() -> void:
	if data == null:
		return
	var rf := data as RingFood
	var look := rf.look if rf else RingFood.Look.BLOB
	var accent := rf.accent if rf else data.color.lightened(0.4)
	var r := data.radius
	var o := Vector2(0, sin(_t * 3.0) * 0.6)
	if _scared and not _carried:
		o.x = sin(_t * 40.0) * 0.7
	var face := o
	match look:
		RingFood.Look.SEED:
			_poly_ellipse(o, Vector2(r * 0.8, r) , data.color)
			draw_line(o + Vector2(0, -r), o + Vector2(r * 0.4, -r - 3), Color("6fbf4a"), 1.5)
		RingFood.Look.ROOT:
			draw_line(o + Vector2(-r * 0.2, -r * 1.2), o + Vector2(0, r * 0.2), INK, 4.0)
			draw_line(o + Vector2(-r * 0.2, -r * 1.2), o + Vector2(0, r * 0.2), data.color, 2.0)
			draw_line(o + Vector2(0, r * 0.2), o + Vector2(r * 0.6, r * 1.1), data.color, 1.0)
			draw_line(o + Vector2(0, r * 0.2), o + Vector2(-r * 0.5, r * 1.0), data.color, 1.0)
			draw_circle(o, r * 0.75 + 1.0, INK)
			draw_circle(o, r * 0.75, data.color)
		RingFood.Look.MUSHROOM:
			draw_rect(Rect2(o + Vector2(-r * 0.35, -r * 0.1), Vector2(r * 0.7, r * 1.0)), INK)
			draw_rect(Rect2(o + Vector2(-r * 0.25, -r * 0.1), Vector2(r * 0.5, r * 0.95)), Color("f3e7d0"))
			var cap := PackedVector2Array()
			for i in 13:
				var a := PI + PI * i / 12.0
				cap.append(o + Vector2(cos(a) * r * 1.15, sin(a) * r * 0.9))
			draw_colored_polygon(cap, INK)
			cap = PackedVector2Array()
			for i in 13:
				var a := PI + PI * i / 12.0
				cap.append(o + Vector2(cos(a) * r, sin(a) * r * 0.78 + 0.5))
			draw_colored_polygon(cap, data.color)
			draw_circle(o + Vector2(-r * 0.4, -r * 0.45), r * 0.16, accent)
			draw_circle(o + Vector2(r * 0.35, -r * 0.3), r * 0.12, accent)
			face = o + Vector2(0, r * 0.45)
		RingFood.Look.CRUMB:
			var pts := PackedVector2Array([o + Vector2(-r, -r * 0.6), o + Vector2(r * 0.9, -r * 0.8), o + Vector2(r, r * 0.7), o + Vector2(-r * 0.8, r * 0.8)])
			draw_colored_polygon(pts, INK)
			draw_colored_polygon(PackedVector2Array([pts[0] * 0.85, pts[1] * 0.85, pts[2] * 0.85, pts[3] * 0.85]), data.color)
			draw_line(pts[0] * 0.85, pts[1] * 0.85, accent, 1.5)
		RingFood.Look.HONEYDEW:
			var glow := 0.5 + 0.5 * sin(_t * 4.0)
			draw_circle(o, r + 3.0 + glow, Color(accent, 0.25))
			_drop(o, r, data.color)
			draw_circle(o + Vector2(-r * 0.3, -r * 0.1), r * 0.2, Color(1, 1, 1, 0.8))
		RingFood.Look.EGG:
			_poly_ellipse(o, Vector2(r * 0.75, r), data.color)
			draw_circle(o + Vector2(r * 0.2, r * 0.3), r * 0.15, accent)
			draw_circle(o + Vector2(-r * 0.3, -r * 0.3), r * 0.12, accent)
		_:
			draw_circle(o, r + 1.0, INK)
			draw_circle(o, r, data.color)
			draw_circle(o + Vector2(-r * 0.35, -r * 0.4), maxf(1.0, r * 0.25), accent)
	_face(face, r)


func _face(at: Vector2, r: float) -> void:
	var e := maxf(1.0, r * 0.22)
	for sx in [-1.0, 1.0]:
		var c := at + Vector2(sx * r * 0.36, -r * 0.05)
		if _scared or _carried:
			draw_circle(c, e + 1.0, Color.WHITE)
			draw_circle(c, e * 0.5, INK)
		elif _smug > 0.0:
			draw_line(c + Vector2(-e, 0), c + Vector2(e, 0), INK, 1.0)
		else:
			draw_circle(c, e * 0.6, INK)
	if _scared:
		draw_circle(at + Vector2(0, r * 0.35), maxf(1.0, r * 0.15), INK)   # little "o" mouth


func _poly_ellipse(at: Vector2, radii: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 18:
		var a := TAU * i / 18.0
		pts.append(at + Vector2(cos(a) * (radii.x + 1.0), sin(a) * (radii.y + 1.0)))
		inner.append(at + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, INK)
	draw_colored_polygon(inner, col)


func _drop(at: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		var k := 1.0 + 0.5 * maxf(0.0, -sin(a)) * absf(cos(a * 0.5))
		pts.append(at + Vector2(cos(a) * r, sin(a) * r * k - (r * 0.6 if sin(a) < -0.95 else 0.0)))
	draw_colored_polygon(pts, INK)
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(at + (p - at) * 0.85)
	draw_colored_polygon(inner, col)
